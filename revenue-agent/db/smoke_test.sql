-- ============================================================================
-- Smoke test: walk one failed payment from decline to recovered revenue.
--
-- This doubles as the readable answer to "how do these tables fit together?".
-- Run against a database that has had 0001_init.sql applied:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f smoke_test.sql
-- It rolls back at the end, so it leaves no data behind.
-- ============================================================================

begin;

-- --- 1. Tenancy: a white-label partner, their customer, one gym -------------
insert into partners (id, name, slug, brand_name, revenue_share_bps)
values ('11111111-1111-1111-1111-111111111111', 'Acme Gym Software', 'acme',
        'Acme Front Desk', 2000);

insert into organizations (id, partner_id, name, status)
values ('22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111', 'Iron House Fitness', 'active');

insert into locations (id, organization_id, partner_id, name, timezone, phone_number_e164)
values ('33333333-3333-3333-3333-333333333333',
        '22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111',
        'Iron House - Downtown', 'America/Denver', '+15551230000');

insert into agent_configs (id, location_id, version, is_active, system_prompt)
values ('44444444-4444-4444-4444-444444444444',
        '33333333-3333-3333-3333-333333333333', 1, true,
        'You are the front desk for Iron House Downtown.');

-- --- 2. A member, reachable on two channels ---------------------------------
insert into contacts (id, location_id, first_name, last_name, lifecycle_stage, consent_sms_at)
values ('55555555-5555-5555-5555-555555555555',
        '33333333-3333-3333-3333-333333333333', 'Dana', 'Reyes', 'member', now());

insert into contact_identities (contact_id, location_id, kind, value, is_primary) values
  ('55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333',
   'phone', '+15557654321', true),
  ('55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333',
   'email', 'dana@example.com', true);

insert into memberships (id, location_id, contact_id, plan_name, price_cents,
                         billing_interval, status, started_on, last_visit_at)
values ('66666666-6666-6666-6666-666666666666',
        '33333333-3333-3333-3333-333333333333',
        '55555555-5555-5555-5555-555555555555',
        'Unlimited Monthly', 14900, 'monthly', 'past_due',
        date '2025-03-01', now() - interval '2 days');

-- --- 3. Stripe says the card was declined -----------------------------------
insert into webhook_events (location_id, provider, event_type, provider_event_id,
                            payload, signature_verified, status, processed_at)
values ('33333333-3333-3333-3333-333333333333', 'stripe', 'invoice.payment_failed',
        'evt_test_0001', '{"amount_due":14900,"failure_code":"expired_card"}'::jsonb,
        true, 'processed', now());

insert into payment_attempts (id, location_id, membership_id, contact_id, amount_cents,
                              status, failure_code, failure_message, provider,
                              provider_payment_id, attempted_at)
values ('77777777-7777-7777-7777-777777777777',
        '33333333-3333-3333-3333-333333333333',
        '66666666-6666-6666-6666-666666666666',
        '55555555-5555-5555-5555-555555555555',
        14900, 'failed', 'expired_card', 'Your card has expired.',
        'stripe', 'pi_test_0001', now() - interval '3 days');

-- --- 4. The agent opens a case and works it ---------------------------------
insert into recovery_cases (id, location_id, contact_id, kind, status,
                            amount_at_risk_cents, membership_id, payment_attempt_id,
                            next_action_at)
values ('88888888-8888-8888-8888-888888888888',
        '33333333-3333-3333-3333-333333333333',
        '55555555-5555-5555-5555-555555555555',
        'failed_payment', 'open', 14900,
        '66666666-6666-6666-6666-666666666666',
        '77777777-7777-7777-7777-777777777777',
        now() - interval '3 days');

insert into conversations (id, location_id, contact_id, channel, agent_config_id, intent)
values ('99999999-9999-9999-9999-999999999999',
        '33333333-3333-3333-3333-333333333333',
        '55555555-5555-5555-5555-555555555555',
        'sms', '44444444-4444-4444-4444-444444444444', 'billing');

insert into messages (id, conversation_id, location_id, direction, author_type, body,
                      provider, provider_message_id, status, sent_at) values
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '99999999-9999-9999-9999-999999999999', '33333333-3333-3333-3333-333333333333',
   'outbound', 'agent',
   'Hi Dana - Iron House here. Your card on file expired so this month did not go through. Update it here: {link}',
   'twilio', 'SM_test_0001', 'delivered', now() - interval '3 days'),
  ('aaaaaaaa-0000-0000-0000-000000000002',
   '99999999-9999-9999-9999-999999999999', '33333333-3333-3333-3333-333333333333',
   'inbound', 'contact', 'oh whoops - just updated it, thanks!',
   'twilio', 'SM_test_0002', 'received', now() - interval '2 days');

update recovery_cases
   set status = 'working', first_touch_at = now() - interval '3 days', outbound_count = 1,
       conversation_id = '99999999-9999-9999-9999-999999999999'
 where id = '88888888-8888-8888-8888-888888888888';

insert into recovery_case_events (recovery_case_id, location_id, event_type,
                                  from_status, to_status, message_id, actor_type) values
  ('88888888-8888-8888-8888-888888888888', '33333333-3333-3333-3333-333333333333',
   'opened', null, 'open', null, 'system'),
  ('88888888-8888-8888-8888-888888888888', '33333333-3333-3333-3333-333333333333',
   'message_sent', 'open', 'working', 'aaaaaaaa-0000-0000-0000-000000000001', 'agent'),
  ('88888888-8888-8888-8888-888888888888', '33333333-3333-3333-3333-333333333333',
   'reply_received', 'working', 'working', 'aaaaaaaa-0000-0000-0000-000000000002', 'contact');

-- --- 5. The retry succeeds. Close the case, freeze the attribution ----------
insert into payment_attempts (location_id, membership_id, contact_id, amount_cents,
                              status, provider, provider_payment_id, attempted_at)
values ('33333333-3333-3333-3333-333333333333',
        '66666666-6666-6666-6666-666666666666',
        '55555555-5555-5555-5555-555555555555',
        14900, 'succeeded', 'stripe', 'pi_test_0002', now() - interval '2 days');

update memberships set status = 'active'
 where id = '66666666-6666-6666-6666-666666666666';

update recovery_cases
   set status = 'won', amount_recovered_cents = 14900, resolved_at = now() - interval '2 days',
       resolution = 'card_updated', attributed = true,
       attribution_basis = 'agent_touched_then_paid', next_action_at = null
 where id = '88888888-8888-8888-8888-888888888888';

insert into recovery_case_events (recovery_case_id, location_id, event_type,
                                  from_status, to_status, amount_cents, actor_type)
values ('88888888-8888-8888-8888-888888888888', '33333333-3333-3333-3333-333333333333',
        'payment_succeeded', 'working', 'won', 14900, 'system');


-- ============================================================================
-- Assertions: the constraints that protect the model must actually bite.
-- Each block expects a specific failure, and fails the test loudly if the
-- bad write is allowed through.
-- ============================================================================

-- A second identity with the same phone at the same gym must be rejected --
-- this is the deduplication guarantee the whole contact model rests on.
do $$
begin
  insert into contact_identities (contact_id, location_id, kind, value)
  values ('55555555-5555-5555-5555-555555555555',
          '33333333-3333-3333-3333-333333333333', 'phone', '+15557654321');
  raise exception 'ASSERTION FAILED: duplicate contact identity was allowed';
exception when unique_violation then
  raise notice 'ok: duplicate phone identity rejected';
end;
$$;

-- A location-scoped role with no location must be rejected.
do $$
begin
  insert into staff_users (id, email) values
    ('bbbbbbbb-0000-0000-0000-000000000001', 'coach@ironhouse.example');
  insert into staff_roles (staff_user_id, role)
  values ('bbbbbbbb-0000-0000-0000-000000000001', 'location_manager');
  raise exception 'ASSERTION FAILED: unscoped location_manager role was allowed';
exception when check_violation then
  raise notice 'ok: role/scope mismatch rejected';
end;
$$;

-- Two active agent configs at one location must be rejected.
do $$
begin
  insert into agent_configs (location_id, version, is_active, system_prompt)
  values ('33333333-3333-3333-3333-333333333333', 2, true, 'second brain');
  raise exception 'ASSERTION FAILED: two active agent configs were allowed';
exception when unique_violation then
  raise notice 'ok: second active agent config rejected';
end;
$$;

-- A replayed provider webhook must not create a second payment row.
do $$
begin
  insert into payment_attempts (location_id, contact_id, amount_cents, status,
                                provider, provider_payment_id, attempted_at)
  values ('33333333-3333-3333-3333-333333333333',
          '55555555-5555-5555-5555-555555555555', 14900, 'failed',
          'stripe', 'pi_test_0001', now());
  raise exception 'ASSERTION FAILED: duplicate provider payment was allowed';
exception when unique_violation then
  raise notice 'ok: replayed payment webhook rejected';
end;
$$;

-- Negative money must be rejected.
do $$
begin
  insert into memberships (location_id, contact_id, plan_name, price_cents,
                           billing_interval, status)
  values ('33333333-3333-3333-3333-333333333333',
          '55555555-5555-5555-5555-555555555555', 'Broken', -100, 'monthly', 'active');
  raise exception 'ASSERTION FAILED: negative price was allowed';
exception when check_violation then
  raise notice 'ok: negative price rejected';
end;
$$;


-- ============================================================================
-- THE QUERY THAT CLOSES THE SALE
--
-- Everything above exists so that this is short. One gym, last 30 days,
-- money recovered broken out by type. This is the dashboard, the monthly
-- invoice, and the renewal conversation.
-- ============================================================================
select
  kind,
  count(*)                                              as cases,
  count(*) filter (where status = 'won')                as won,
  round(100.0 * count(*) filter (where status = 'won')
        / nullif(count(*), 0), 1)                       as win_rate_pct,
  sum(amount_at_risk_cents)   / 100.0                   as at_risk_usd,
  sum(amount_recovered_cents) filter (where attributed)
                              / 100.0                   as recovered_usd
from recovery_cases
where location_id = '33333333-3333-3333-3333-333333333333'
  and opened_at >= now() - interval '30 days'
group by kind
order by recovered_usd desc nulls last;

-- The single headline number, the one that goes in the renewal email.
select
  coalesce(sum(amount_recovered_cents) filter (where attributed), 0) / 100.0
    as recovered_usd_last_30d
from recovery_cases
where location_id = '33333333-3333-3333-3333-333333333333'
  and resolved_at >= now() - interval '30 days';

-- The agent's work queue: what is due right now, most money first.
select c.first_name, c.last_name, rc.kind, rc.amount_at_risk_cents / 100.0 as at_risk_usd
from recovery_cases rc
join contacts c on c.id = rc.contact_id
where rc.location_id = '33333333-3333-3333-3333-333333333333'
  and rc.status in ('open', 'working')
  and rc.next_action_at <= now()
  and c.opted_out_at is null            -- never contact someone who opted out
order by rc.amount_at_risk_cents desc
limit 50;

rollback;
