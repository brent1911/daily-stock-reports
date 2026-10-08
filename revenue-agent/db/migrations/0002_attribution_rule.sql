-- ============================================================================
-- Attribution rule v1 -- "conservative"
--
-- Settles open question #1 from docs/data-model.md: when may we claim we
-- recovered the money?
--
-- The governing principle: under-claim and be trusted. A gym owner who spot
-- checks one case and finds we credited ourselves for something we did not
-- cause will cancel, and tell the other gym owners. Every rule below is
-- deliberately set so that the answer is defensible out loud.
--
-- The rule is versioned. Cases keep the version they were judged under, so
-- tightening the rule later never silently restates a past invoice.
-- ============================================================================

begin;

-- --- Freeze the rule onto each case -----------------------------------------

alter table recovery_cases
  add column attribution_rule_version integer not null default 1,
  add column attribution_window_days  integer not null default 14,
  -- WHY store the reason even when we DON'T attribute: "why didn't you count
  -- this one?" is a question you want a stored answer to, both for debugging
  -- the rule and for showing a customer you are not quietly inflating.
  add column attribution_reason       text,
  add column attribution_evaluated_at timestamptz;

alter table recovery_cases
  add constraint recovery_cases_attribution_basis_valid check (
    attribution_basis is null or attribution_basis in (
      'agent_touched_then_paid',   -- failed_payment: they paid after we asked
      'agent_saved_then_paid',     -- at_risk / cancellation: they paid again
      'agent_booked_then_joined',  -- lead / missed_call: showed up, then joined
      'manual_override'            -- a human overrode the rule, on the record
    )
  );

-- An attributed case must carry its receipt.
alter table recovery_cases
  add constraint recovery_cases_attributed_has_basis check (
    not attributed or (attribution_basis is not null and amount_recovered_cents > 0)
  );

comment on column recovery_cases.attributed is
  'Frozen at resolution time by evaluate_attribution(). Never recompute on read.';


-- ============================================================================
-- evaluate_attribution(case_id)
--
-- Returns whether this case may be counted as recovered revenue, the basis,
-- and a plain-English reason either way. Call it when a case resolves, then
-- WRITE THE RESULT to the case. Do not call it from the dashboard -- the
-- dashboard reads the frozen columns.
-- ============================================================================

create or replace function evaluate_attribution(p_case_id uuid)
returns table (qualifies boolean, basis text, reason text)
language plpgsql stable as $$
declare
  c              recovery_cases%rowtype;
  v_window       integer;
  v_staff_first  boolean;
  v_paid_at      timestamptz;
  v_appt_at      timestamptz;
  v_joined       boolean;
begin
  select * into c from recovery_cases where id = p_case_id;
  if not found then
    return query select false, null::text, 'case not found'; return;
  end if;

  v_window := coalesce(c.attribution_window_days, 14);

  -- Gate 1: we must actually have done something. A case nobody worked is
  -- never ours, however it resolved.
  if c.first_touch_at is null then
    return query select false, null::text,
      'the agent never contacted this person'; return;
  end if;

  -- Gate 2: staff must not have got there first. If a coach already called
  -- them about this, the credit is the coach's. This is the rule that keeps
  -- us honest with the customer paying the bill.
  select exists (
    select 1
      from messages m
      join conversations cv on cv.id = m.conversation_id
     where cv.contact_id = c.contact_id
       and m.direction   = 'outbound'
       and m.author_type = 'staff'
       and m.created_at >= c.opened_at
       and m.created_at <  c.first_touch_at
  ) into v_staff_first;

  if v_staff_first then
    return query select false, null::text,
      'gym staff contacted this person before the agent did'; return;
  end if;

  -- ---- failed_payment: paid within the window of our first contact --------
  if c.kind = 'failed_payment' then
    select min(pa.attempted_at) into v_paid_at
      from payment_attempts pa
     where pa.contact_id = c.contact_id
       and pa.status     = 'succeeded'
       and pa.attempted_at >= c.first_touch_at
       and pa.attempted_at <  c.first_touch_at + make_interval(days => v_window)
       and (c.membership_id is null or pa.membership_id = c.membership_id);

    if v_paid_at is null then
      return query select false, null::text, format(
        'no successful payment in the %s days after the agent made contact',
        v_window); return;
    end if;

    return query select true, 'agent_touched_then_paid', format(
      'agent contacted %s, payment cleared %s',
      c.first_touch_at::date, v_paid_at::date);
    return;

  -- ---- at_risk / cancellation_save: they stayed AND paid again ------------
  -- WHY "paid again" and not "did not cancel": a member who stays on the
  -- books but never pays is not recovered revenue. Waiting for real money
  -- makes this lag by up to a billing cycle. That lag is the price of a
  -- number nobody can argue with.
  elsif c.kind in ('at_risk_member', 'cancellation_save') then
    select min(pa.attempted_at) into v_paid_at
      from payment_attempts pa
     where pa.contact_id = c.contact_id
       and pa.status     = 'succeeded'
       and pa.attempted_at > c.first_touch_at
       and (c.membership_id is null or pa.membership_id = c.membership_id);

    if v_paid_at is null then
      return query select false, null::text,
        'member has not made a payment since the agent reached out'; return;
    end if;

    return query select true, 'agent_saved_then_paid', format(
      'agent reached out %s, member paid again %s',
      c.first_touch_at::date, v_paid_at::date);
    return;

  -- ---- unconverted_lead / missed_call: attended, then actually joined -----
  -- WHY the bar is this high: a booked trial is activity, not revenue, and a
  -- no-show is worth nothing. We report trials booked as a separate count.
  -- Dollars are only ever claimed when somebody actually started paying.
  elsif c.kind in ('unconverted_lead', 'missed_call') then
    select min(a.starts_at) into v_appt_at
      from appointments a
     where a.contact_id = c.contact_id
       and a.booked_by  = 'agent'
       and a.status     = 'attended'
       and a.starts_at >= c.first_touch_at;

    if v_appt_at is null then
      return query select false, null::text,
        'no agent-booked appointment was attended'; return;
    end if;

    select exists (
      select 1 from memberships ms
       where ms.contact_id = c.contact_id
         and ms.status in ('active', 'past_due')
         and ms.created_at >= v_appt_at
         and ms.created_at <  v_appt_at + interval '30 days'
    ) into v_joined;

    if not v_joined then
      return query select false, null::text,
        'attended a trial but did not start a membership within 30 days'; return;
    end if;

    return query select true, 'agent_booked_then_joined', format(
      'agent booked a trial attended %s, membership started within 30 days',
      v_appt_at::date);
    return;
  end if;

  return query select false, null::text,
    format('no attribution rule defined for kind %s', c.kind);
end;
$$;

comment on function evaluate_attribution(uuid) is
  'Attribution rule v1 (conservative). Call at case resolution and store the '
  'result on the case; never call it from a reporting query.';


-- ============================================================================
-- Reporting views
--
-- WHY views: so that "recovered revenue" has exactly one definition in the
-- whole system. Dashboard, monthly invoice and partner revenue share all read
-- the same view. The day someone writes their own slightly different SUM is
-- the day two screens disagree in front of a customer.
-- ============================================================================

-- Hard dollars. Only ever counts cases the rule approved.
create view v_recovered_revenue as
select
  location_id,
  date_trunc('month', resolved_at) as month,
  kind,
  count(*)                                as cases_won,
  sum(amount_recovered_cents)             as recovered_cents
from recovery_cases
where status = 'won'
  and attributed
  and resolved_at is not null
group by 1, 2, 3;

-- Activity, reported separately and never converted to dollars.
create view v_agent_activity as
select
  location_id,
  date_trunc('month', created_at) as month,
  count(*) filter (where status = 'attended')  as trials_attended,
  count(*) filter (where status = 'no_show')   as trials_no_show,
  count(*)                                     as trials_booked
from appointments
where booked_by = 'agent'
group by 1, 2;

commit;
