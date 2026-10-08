-- ============================================================================
-- Attribution rule v1 -- test cases
--
-- Six scenarios: two that must be counted as recovered revenue, and four that
-- must NOT. The rejections are the point. A rule that only ever says yes is
-- not a conservative rule, it is a marketing number.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f attribution_test.sql
--
-- Rolls back at the end. Leaves nothing behind.
-- ============================================================================

begin;

-- --- Fixtures ---------------------------------------------------------------

insert into partners (id, name, slug)
values ('11111111-0000-0000-0000-000000000001', 'Test Partner', 'test-partner');

insert into organizations (id, partner_id, name)
values ('22222222-0000-0000-0000-000000000001',
        '11111111-0000-0000-0000-000000000001', 'Test Org');

insert into locations (id, organization_id, partner_id, name)
values ('33333333-0000-0000-0000-000000000001',
        '22222222-0000-0000-0000-000000000001',
        '11111111-0000-0000-0000-000000000001', 'Test Gym');

-- Every scenario shares this timeline:
--   case opens        30 days ago
--   agent first texts 29 days ago
--   window closes     15 days ago  (29 - 14)
do $$
declare
  loc  uuid := '33333333-0000-0000-0000-000000000001';
  opened   timestamptz := now() - interval '30 days';
  touched  timestamptz := now() - interval '29 days';
  kinds record;
begin
  -- Six contacts, one per scenario.
  for kinds in
    select * from (values
      ('a', 'Ada',  'Qualifies'),
      ('b', 'Ben',  'StaffFirst'),
      ('c', 'Cleo', 'LatePayment'),
      ('d', 'Dev',  'NeverPaid'),
      ('e', 'Eve',  'LeadJoined'),
      ('f', 'Fox',  'LeadNoShow')
    ) as t(slot, first_name, last_name)
  loop
    insert into contacts (id, location_id, first_name, last_name, lifecycle_stage, consent_sms_at)
    values (('55555555-0000-0000-0000-00000000000' || kinds.slot)::uuid,
            loc, kinds.first_name, kinds.last_name, 'member', opened);

    insert into conversations (id, location_id, contact_id, channel)
    values (('99999999-0000-0000-0000-00000000000' || kinds.slot)::uuid,
            loc, ('55555555-0000-0000-0000-00000000000' || kinds.slot)::uuid, 'sms');
  end loop;

  -- Memberships for the four payment-recovery scenarios.
  for kinds in select unnest(array['a','b','c','d']) as slot loop
    insert into memberships (id, location_id, contact_id, plan_name, price_cents,
                             billing_interval, status)
    values (('66666666-0000-0000-0000-00000000000' || kinds.slot)::uuid,
            loc, ('55555555-0000-0000-0000-00000000000' || kinds.slot)::uuid,
            'Unlimited Monthly', 14900, 'monthly', 'past_due');

    insert into recovery_cases (id, location_id, contact_id, kind, status,
                                amount_at_risk_cents, membership_id,
                                opened_at, first_touch_at)
    values (('88888888-0000-0000-0000-00000000000' || kinds.slot)::uuid,
            loc, ('55555555-0000-0000-0000-00000000000' || kinds.slot)::uuid,
            'failed_payment', 'working', 14900,
            ('66666666-0000-0000-0000-00000000000' || kinds.slot)::uuid,
            opened, touched);
  end loop;
end;
$$;

-- (a) QUALIFIES -- paid one day after the agent made contact.
insert into payment_attempts (location_id, membership_id, contact_id, amount_cents,
                              status, provider, attempted_at)
values ('33333333-0000-0000-0000-000000000001',
        '66666666-0000-0000-0000-00000000000a',
        '55555555-0000-0000-0000-00000000000a',
        14900, 'succeeded', 'stripe', now() - interval '28 days');

-- (b) REJECTED -- a coach texted them before the agent did. Credit is theirs.
insert into messages (conversation_id, location_id, direction, author_type, body, created_at)
values ('99999999-0000-0000-0000-00000000000b',
        '33333333-0000-0000-0000-000000000001',
        'outbound', 'staff', 'Hey Ben, card bounced - can you pop in?',
        now() - interval '29 days 12 hours');
insert into payment_attempts (location_id, membership_id, contact_id, amount_cents,
                              status, provider, attempted_at)
values ('33333333-0000-0000-0000-000000000001',
        '66666666-0000-0000-0000-00000000000b',
        '55555555-0000-0000-0000-00000000000b',
        14900, 'succeeded', 'stripe', now() - interval '28 days');

-- (c) REJECTED -- paid, but 19 days after contact. Outside the 14-day window.
insert into payment_attempts (location_id, membership_id, contact_id, amount_cents,
                              status, provider, attempted_at)
values ('33333333-0000-0000-0000-000000000001',
        '66666666-0000-0000-0000-00000000000c',
        '55555555-0000-0000-0000-00000000000c',
        14900, 'succeeded', 'stripe', now() - interval '10 days');

-- (d) REJECTED -- never paid. Only failures on the record.
insert into payment_attempts (location_id, membership_id, contact_id, amount_cents,
                              status, failure_code, provider, attempted_at)
values ('33333333-0000-0000-0000-000000000001',
        '66666666-0000-0000-0000-00000000000d',
        '55555555-0000-0000-0000-00000000000d',
        14900, 'failed', 'insufficient_funds', 'stripe', now() - interval '28 days');

-- (e) QUALIFIES -- agent booked a trial, they showed up, then they joined.
insert into appointments (location_id, contact_id, kind, status, starts_at, booked_by)
values ('33333333-0000-0000-0000-000000000001',
        '55555555-0000-0000-0000-00000000000e',
        'trial_class', 'attended', now() - interval '20 days', 'agent');
insert into memberships (location_id, contact_id, plan_name, price_cents,
                         billing_interval, status)
values ('33333333-0000-0000-0000-000000000001',
        '55555555-0000-0000-0000-00000000000e',
        'Unlimited Monthly', 14900, 'monthly', 'active');

-- (f) REJECTED -- booked a trial and did not show. Activity, not revenue.
insert into appointments (location_id, contact_id, kind, status, starts_at, booked_by)
values ('33333333-0000-0000-0000-000000000001',
        '55555555-0000-0000-0000-00000000000f',
        'trial_class', 'no_show', now() - interval '20 days', 'agent');

insert into recovery_cases (id, location_id, contact_id, kind, status,
                            amount_at_risk_cents, opened_at, first_touch_at)
select ('88888888-0000-0000-0000-00000000000' || slot)::uuid,
       '33333333-0000-0000-0000-000000000001',
       ('55555555-0000-0000-0000-00000000000' || slot)::uuid,
       'unconverted_lead', 'working', 14900,
       now() - interval '30 days', now() - interval '29 days'
from unnest(array['e','f']) as slot;


-- ============================================================================
-- Assert: every scenario returns the expected verdict.
-- ============================================================================

do $$
declare
  expected record;
  got      record;
  failures integer := 0;
begin
  for expected in
    select * from (values
      ('a', true,  'paid 1 day after contact'),
      ('b', false, 'staff texted first'),
      ('c', false, 'paid 19 days later, outside window'),
      ('d', false, 'never paid'),
      ('e', true,  'attended trial then joined'),
      ('f', false, 'booked trial but no-showed')
    ) as t(slot, should_qualify, label)
  loop
    select * into got from evaluate_attribution(
      ('88888888-0000-0000-0000-00000000000' || expected.slot)::uuid);

    if got.qualifies is distinct from expected.should_qualify then
      failures := failures + 1;
      raise warning 'FAIL [%] %: expected qualifies=%, got % (%)',
        expected.slot, expected.label, expected.should_qualify,
        got.qualifies, got.reason;
    else
      raise notice 'ok  [%] % -> % (%)',
        expected.slot,
        rpad(expected.label, 34),
        case when got.qualifies then 'COUNTED' else 'not counted' end,
        coalesce(got.basis, got.reason);
    end if;
  end loop;

  if failures > 0 then
    raise exception '% attribution test(s) failed', failures;
  end if;
  raise notice '--- all 6 attribution scenarios behaved as specified ---';
end;
$$;

-- The constraint must refuse an attributed case with no basis on the record.
do $$
begin
  update recovery_cases
     set attributed = true, amount_recovered_cents = 14900, attribution_basis = null
   where id = '88888888-0000-0000-0000-00000000000d';
  raise exception 'ASSERTION FAILED: attributed case without a basis was allowed';
exception when check_violation then
  raise notice 'ok: attributed case with no basis rejected';
end;
$$;

rollback;
