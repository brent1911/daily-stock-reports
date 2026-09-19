-- ============================================================================
-- Revenue Agent - initial schema
--
-- Postgres 13+. Run: psql "$DATABASE_URL" -f 0001_init.sql
--
-- Reading guide: the tables are grouped into five domains, in dependency
-- order. Every comment marked WHY explains a decision that would be
-- expensive to reverse later -- those are the ones worth arguing about.
-- ============================================================================

begin;

-- gen_random_uuid() is built in on PG13+. pgcrypto is only needed on older.
create extension if not exists pgcrypto;

-- Keeps updated_at honest without the application having to remember.
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================================
-- 1. TENANCY
--
-- WHY three levels (partner -> organization -> location) and not two:
-- the white-label endgame is selling through franchise groups and gym
-- software vendors. A partner brands the product; an organization is the
-- business that pays; a location is one gym with one phone number, one
-- timezone and one set of members. A four-gym group needs shared billing
-- with separate phone numbers -- that is organization vs location.
-- Adding a tenancy level later means rewriting every query and every
-- permission check in the product. Adding it now costs one table.
-- ============================================================================

create table partners (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  slug               text not null unique,
  status             text not null default 'active'
                       check (status in ('active', 'suspended')),

  -- White-label presentation. Null means the product shows our own brand.
  brand_name         text,
  brand_domain       text,
  brand_logo_url     text,
  brand_primary_hex  text,

  -- WHY basis points and not a decimal percentage: integers never drift.
  -- 1500 bps = 15.00%. Same reason every money column below is in cents.
  revenue_share_bps  integer not null default 0
                       check (revenue_share_bps between 0 and 10000),

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table organizations (
  id             uuid primary key default gen_random_uuid(),
  partner_id     uuid not null references partners(id) on delete restrict,
  name           text not null,
  billing_email  text,
  status         text not null default 'trial'
                   check (status in ('trial', 'active', 'past_due', 'churned')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index organizations_partner_idx on organizations (partner_id);

create table locations (
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references organizations(id) on delete restrict,

  -- WHY partner_id is duplicated here: every tenant-scoped query and every
  -- row-level-security policy needs to answer "which partner owns this row?"
  -- without a three-table join. This is deliberate denormalization; keep it
  -- correct with the trigger-or-check of your choice when locations move.
  partner_id         uuid not null references partners(id) on delete restrict,

  name               text not null,

  -- WHY timezone is not optional: the agent sends outbound messages. Texting
  -- a member at 3am is how you lose an account on day two. Quiet hours are
  -- meaningless without this, and a chain can span timezones.
  timezone           text not null default 'America/New_York',

  -- The agent's number for this gym. E.164 (+15551234567) everywhere, always.
  phone_number_e164  text unique,

  address_line1      text,
  address_line2      text,
  city               text,
  region             text,
  postal_code        text,
  country            text not null default 'US',

  -- [{"day":1,"open":"05:00","close":"21:00"}, ...]
  business_hours     jsonb not null default '[]'::jsonb,

  -- WHY this flag: call recording consent law varies by state. Some require
  -- all parties to consent. This drives the disclosure the agent reads.
  recording_requires_consent boolean not null default true,

  status             text not null default 'active'
                       check (status in ('onboarding', 'active', 'paused', 'churned')),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index locations_org_idx on locations (organization_id);
create index locations_partner_idx on locations (partner_id);

create table staff_users (
  id                uuid primary key default gen_random_uuid(),
  email             text not null unique,   -- store lowercased
  full_name         text,
  -- WHY no password_hash: authentication belongs to an identity provider.
  -- Storing a pointer means a breach here leaks nothing that logs anyone in.
  auth_provider     text not null default 'email_link',
  auth_provider_uid text,
  phone_e164        text,
  status            text not null default 'active'
                      check (status in ('invited', 'active', 'disabled')),
  last_seen_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- WHY a separate roles table instead of a role column on staff_users: one
-- person is often staff at two gyms, or a partner admin who also manages a
-- location. A single column forces duplicate user accounts.
create table staff_roles (
  id              uuid primary key default gen_random_uuid(),
  staff_user_id   uuid not null references staff_users(id) on delete cascade,
  role            text not null check (role in (
                    'platform_admin', 'partner_admin', 'org_admin',
                    'location_manager', 'location_staff')),
  partner_id      uuid references partners(id) on delete cascade,
  organization_id uuid references organizations(id) on delete cascade,
  location_id     uuid references locations(id) on delete cascade,
  created_at      timestamptz not null default now(),

  -- The database refuses to store a role scoped to the wrong thing. Cheaper
  -- than trusting every code path to get it right.
  constraint staff_roles_scope_matches_role check (
       (role = 'platform_admin'
          and partner_id is null and organization_id is null and location_id is null)
    or (role = 'partner_admin'
          and partner_id is not null and organization_id is null and location_id is null)
    or (role = 'org_admin'
          and organization_id is not null and location_id is null)
    or (role in ('location_manager', 'location_staff')
          and location_id is not null)
  )
);
create index staff_roles_user_idx on staff_roles (staff_user_id);
create index staff_roles_location_idx on staff_roles (location_id);


-- ============================================================================
-- 2. PEOPLE
-- ============================================================================

-- WHY one contacts table and not leads + members: a lead becomes a member,
-- a member cancels and becomes a lead again. Two tables means copying rows
-- between them and losing the conversation history at exactly the moment it
-- matters most -- the winback. Lifecycle is a column, not a table.
create table contacts (
  id               uuid primary key default gen_random_uuid(),
  location_id      uuid not null references locations(id) on delete cascade,
  first_name       text,
  last_name        text,

  lifecycle_stage  text not null default 'lead' check (lifecycle_stage in (
                     'lead', 'trial', 'member', 'former_member', 'do_not_contact')),

  source           text,  -- inbound_call | web_form | instagram | walk_in | import
  timezone         text,  -- falls back to the location's

  -- WHY consent is modelled explicitly, with timestamps: US SMS marketing is
  -- governed by the TCPA, and statutory damages are per message. "Did this
  -- person agree, and when, and have they since opted out?" must be a column
  -- you can prove in a deposition, not an inference from message history.
  consent_sms_at     timestamptz,
  consent_email_at   timestamptz,
  consent_source     text,        -- where the opt-in came from
  opted_out_at       timestamptz,
  opted_out_channel  text,

  first_seen_at    timestamptz not null default now(),
  last_contacted_at timestamptz,
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index contacts_location_stage_idx on contacts (location_id, lifecycle_stage);
create index contacts_location_updated_idx on contacts (location_id, updated_at desc);

-- WHY identities are their own table: one person is a phone number, an email,
-- an Instagram handle and an ID in the gym's CRM. Columns on contacts would
-- cap you at one of each and give you no way to merge duplicates. The unique
-- index below is the actual deduplication mechanism -- an inbound text from
-- a known number resolves to an existing contact instead of creating a twin.
create table contact_identities (
  id           uuid primary key default gen_random_uuid(),
  contact_id   uuid not null references contacts(id) on delete cascade,
  location_id  uuid not null references locations(id) on delete cascade,
  kind         text not null check (kind in (
                 'phone', 'email', 'instagram', 'facebook', 'external_id')),
  -- Normalize before writing: E.164 for phone, lowercase for email.
  value        text not null,
  is_primary   boolean not null default false,
  verified_at  timestamptz,
  created_at   timestamptz not null default now()
);
create unique index contact_identities_unique
  on contact_identities (location_id, kind, value);
create index contact_identities_contact_idx on contact_identities (contact_id);


-- ============================================================================
-- 3. CONVERSATIONS
-- ============================================================================

-- Declared before conversations because conversations reference it.
create table agent_configs (
  id             uuid primary key default gen_random_uuid(),
  location_id    uuid not null references locations(id) on delete cascade,

  -- WHY versioned and immutable-by-convention: when a gym owner asks "why did
  -- your bot say that?", you need the exact configuration that produced the
  -- message, not whatever is live today. Conversations pin a config id.
  version        integer not null,
  is_active      boolean not null default false,

  persona_name   text not null default 'Front Desk',
  greeting       text,
  system_prompt  text not null,
  voice_id       text,

  -- WHY guardrails live in data, not in the prompt: "you may offer a 7-day
  -- free trial, never a discount over 20%" must be enforceable and auditable.
  allowed_offers  jsonb not null default '[]'::jsonb,
  escalation_rules jsonb not null default '{}'::jsonb,
  quiet_hours     jsonb not null default '{"start":"21:00","end":"08:00"}'::jsonb,
  max_outbound_per_case integer not null default 4 check (max_outbound_per_case >= 0),

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index agent_configs_version_unique on agent_configs (location_id, version);
-- At most one active config per location, enforced by the database.
create unique index agent_configs_one_active on agent_configs (location_id) where is_active;

create table conversations (
  id                     uuid primary key default gen_random_uuid(),
  location_id            uuid not null references locations(id) on delete cascade,
  contact_id             uuid not null references contacts(id) on delete cascade,
  channel                text not null check (channel in (
                           'voice', 'sms', 'web_chat', 'instagram', 'email')),
  status                 text not null default 'open' check (status in (
                           'open', 'waiting_on_contact', 'needs_human', 'closed')),
  assigned_staff_user_id uuid references staff_users(id) on delete set null,
  agent_config_id        uuid references agent_configs(id) on delete set null,
  intent                 text,  -- new_member_inquiry | billing | cancellation | schedule
  last_message_at        timestamptz,
  escalated_at           timestamptz,
  escalation_reason      text,
  closed_at              timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index conversations_location_status_idx
  on conversations (location_id, status, last_message_at desc);
create index conversations_contact_idx on conversations (contact_id, created_at desc);

create table messages (
  id                    uuid primary key default gen_random_uuid(),
  conversation_id       uuid not null references conversations(id) on delete cascade,
  location_id           uuid not null references locations(id) on delete cascade,
  direction             text not null check (direction in ('inbound', 'outbound')),
  author_type           text not null check (author_type in (
                          'contact', 'agent', 'staff', 'system')),
  author_staff_user_id  uuid references staff_users(id) on delete set null,
  body                  text,
  media_urls            jsonb not null default '[]'::jsonb,

  provider              text,   -- twilio | meta | postmark
  provider_message_id   text,
  status                text not null default 'queued' check (status in (
                          'queued', 'sent', 'delivered', 'failed', 'received')),
  failure_reason        text,

  sent_at               timestamptz,
  delivered_at          timestamptz,
  created_at            timestamptz not null default now()
);
create index messages_conversation_idx on messages (conversation_id, created_at);
-- WHY this partial unique index: providers retry webhooks. Without it, one
-- network hiccup becomes a member receiving the same text four times.
create unique index messages_provider_unique
  on messages (provider, provider_message_id)
  where provider_message_id is not null;

create table calls (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid references conversations(id) on delete set null,
  location_id      uuid not null references locations(id) on delete cascade,
  contact_id       uuid references contacts(id) on delete set null,
  direction        text not null check (direction in ('inbound', 'outbound')),
  from_e164        text,
  to_e164          text,

  provider         text,
  provider_call_id text,

  answered_by      text check (answered_by in ('agent', 'staff', 'voicemail', 'none')),

  -- WHY outcome is a column and not derived from the transcript: this is the
  -- number on the dashboard. It has to be queryable, correctable by a human,
  -- and stable even if you change models later.
  outcome          text check (outcome in (
                     'booked', 'info_provided', 'escalated', 'voicemail',
                     'abandoned', 'spam', 'wrong_number')),

  duration_seconds integer check (duration_seconds >= 0),
  recording_url    text,
  recording_consent_given boolean,
  transcript       text,

  started_at       timestamptz,
  ended_at         timestamptz,
  created_at       timestamptz not null default now()
);
create index calls_location_started_idx on calls (location_id, started_at desc);
create unique index calls_provider_unique
  on calls (provider, provider_call_id)
  where provider_call_id is not null;

create table appointments (
  id               uuid primary key default gen_random_uuid(),
  location_id      uuid not null references locations(id) on delete cascade,
  contact_id       uuid not null references contacts(id) on delete cascade,
  conversation_id  uuid references conversations(id) on delete set null,
  kind             text not null default 'trial_class' check (kind in (
                     'trial_class', 'tour', 'consult', 'makeup_class')),
  status           text not null default 'scheduled' check (status in (
                     'scheduled', 'confirmed', 'attended', 'no_show', 'cancelled')),
  starts_at        timestamptz not null,
  ends_at          timestamptz,
  booked_by        text not null default 'agent' check (booked_by in (
                     'agent', 'staff', 'contact')),
  -- Id of this booking inside the gym's own scheduling system.
  external_ref     text,
  cancelled_reason text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index appointments_location_start_idx on appointments (location_id, starts_at);
create index appointments_contact_idx on appointments (contact_id, starts_at desc);


-- ============================================================================
-- 4. MONEY
--
-- This is the product. Everything above exists to feed these four tables,
-- because "we recovered $8,400 last month" is the entire sales pitch.
-- ============================================================================

create table memberships (
  id                  uuid primary key default gen_random_uuid(),
  location_id         uuid not null references locations(id) on delete cascade,
  contact_id          uuid not null references contacts(id) on delete cascade,
  plan_name           text not null,

  -- WHY integer cents, never a float: 0.1 + 0.2 != 0.3 in binary floating
  -- point. Money in floats produces invoices that are off by a penny and
  -- reports that do not reconcile. This is not a style preference.
  price_cents         integer not null check (price_cents >= 0),
  currency            text not null default 'USD',
  billing_interval    text not null check (billing_interval in (
                        'weekly', 'monthly', 'quarterly', 'annual')),

  status              text not null check (status in (
                        'active', 'past_due', 'paused', 'cancelled')),
  started_on          date,
  cancelled_at        timestamptz,
  cancellation_reason text,

  -- WHY this lives here: it is the churn signal. A member who has not
  -- scanned in for three weeks is the at-risk case you want to open
  -- before they call to cancel.
  last_visit_at       timestamptz,
  visits_last_30      integer not null default 0,

  external_ref        text,   -- id in the gym CRM or Stripe
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index memberships_location_status_idx on memberships (location_id, status);
create index memberships_contact_idx on memberships (contact_id);
create index memberships_at_risk_idx
  on memberships (location_id, last_visit_at)
  where status = 'active';

create table payment_attempts (
  id                  uuid primary key default gen_random_uuid(),
  location_id         uuid not null references locations(id) on delete cascade,
  membership_id       uuid references memberships(id) on delete set null,
  contact_id          uuid not null references contacts(id) on delete cascade,

  amount_cents        integer not null check (amount_cents >= 0),
  currency            text not null default 'USD',
  status              text not null check (status in (
                        'succeeded', 'failed', 'pending', 'refunded')),

  -- insufficient_funds | expired_card | do_not_honor | ...
  -- WHY store the code separately from the message: the code decides the
  -- playbook. An expired card needs a new card; insufficient funds needs a
  -- retry on payday. Same failure to the gym, completely different message.
  failure_code        text,
  failure_message     text,

  provider            text not null,  -- stripe | gym_crm
  provider_payment_id text,

  attempted_at        timestamptz not null,
  created_at          timestamptz not null default now()
);
create index payment_attempts_location_idx
  on payment_attempts (location_id, attempted_at desc);
create index payment_attempts_membership_idx on payment_attempts (membership_id);
create unique index payment_attempts_provider_unique
  on payment_attempts (provider, provider_payment_id)
  where provider_payment_id is not null;

-- ----------------------------------------------------------------------------
-- recovery_cases: the centerpiece of the whole schema.
--
-- WHY one table for all five kinds of at-risk money, rather than separate
-- failed_payments / winbacks / missed_leads tables: the number the gym owner
-- cares about is a single sum across all of them. One table makes the
-- dashboard one query, makes the work queue one query, and means a new
-- recovery type is a new value in a check constraint instead of a new
-- subsystem. The cost is nullable foreign keys -- worth it.
-- ----------------------------------------------------------------------------
create table recovery_cases (
  id                     uuid primary key default gen_random_uuid(),
  location_id            uuid not null references locations(id) on delete cascade,
  contact_id             uuid not null references contacts(id) on delete cascade,

  kind                   text not null check (kind in (
                           'failed_payment',    -- card declined
                           'at_risk_member',    -- stopped showing up
                           'cancellation_save', -- asked to cancel
                           'unconverted_lead',  -- enquired, never booked
                           'missed_call')),     -- rang, nobody answered

  status                 text not null default 'open' check (status in (
                           'open', 'working', 'won', 'lost',
                           'abandoned', 'suppressed')),

  amount_at_risk_cents   integer not null default 0 check (amount_at_risk_cents >= 0),
  amount_recovered_cents integer not null default 0 check (amount_recovered_cents >= 0),
  currency               text not null default 'USD',

  -- Exactly which of these is set depends on kind. Enforce in application
  -- code; a check constraint here would fight you every time you add a kind.
  membership_id          uuid references memberships(id) on delete set null,
  payment_attempt_id     uuid references payment_attempts(id) on delete set null,
  conversation_id        uuid references conversations(id) on delete set null,
  call_id                uuid references calls(id) on delete set null,
  appointment_id         uuid references appointments(id) on delete set null,

  -- Work queue: the agent asks "what is due now?" and this answers it.
  playbook_id            uuid,
  current_step           integer not null default 0,
  next_action_at         timestamptz,
  outbound_count         integer not null default 0,

  opened_at              timestamptz not null default now(),
  first_touch_at         timestamptz,
  resolved_at            timestamptz,
  resolution             text,  -- card_updated | rebooked | reactivated | no_response

  -- WHY attribution is a stored boolean and not computed at read time: the
  -- ROI number on the invoice must not change when you later tweak the
  -- attribution rule. You freeze the decision at resolution time, record
  -- the basis, and the historical number stays defensible.
  attributed             boolean not null default false,
  attribution_basis      text,  -- agent_touched_then_paid | agent_booked | manual

  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
-- The work queue index: "open cases at this gym that are due".
create index recovery_cases_queue_idx
  on recovery_cases (location_id, next_action_at)
  where status in ('open', 'working');
-- The reporting index: "everything resolved this month, by type".
create index recovery_cases_reporting_idx
  on recovery_cases (location_id, kind, resolved_at desc);
create index recovery_cases_contact_idx on recovery_cases (contact_id);

-- WHY an append-only event log per case: when a skeptical gym owner says
-- "prove you recovered that", this is the receipt -- every message sent,
-- every reply, the payment that landed, and when. Never update these rows.
create table recovery_case_events (
  id                   bigserial primary key,
  recovery_case_id     uuid not null references recovery_cases(id) on delete cascade,
  location_id          uuid not null references locations(id) on delete cascade,
  event_type           text not null,  -- opened | message_sent | reply_received
                                       -- | call_placed | payment_succeeded
                                       -- | status_changed | suppressed
  from_status          text,
  to_status            text,
  message_id           uuid references messages(id) on delete set null,
  call_id              uuid references calls(id) on delete set null,
  amount_cents         integer,
  actor_type           text not null default 'system' check (actor_type in (
                         'agent', 'staff', 'contact', 'system')),
  actor_staff_user_id  uuid references staff_users(id) on delete set null,
  metadata             jsonb not null default '{}'::jsonb,
  occurred_at          timestamptz not null default now()
);
create index recovery_case_events_case_idx
  on recovery_case_events (recovery_case_id, occurred_at);


-- ============================================================================
-- 5. PLUMBING
-- ============================================================================

-- Outreach cadence. Thin on purpose -- expect to rework this once you have
-- watched real cases run. It is here so recovery_cases has something to point
-- at, not because the design is settled.
create table playbooks (
  id           uuid primary key default gen_random_uuid(),
  -- Exactly one of these: a location's own playbook, or a partner template.
  location_id  uuid references locations(id) on delete cascade,
  partner_id   uuid references partners(id) on delete cascade,
  kind         text not null check (kind in (
                 'failed_payment', 'at_risk_member', 'cancellation_save',
                 'unconverted_lead', 'missed_call')),
  name         text not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint playbooks_one_owner check (
    (location_id is not null and partner_id is null)
    or (location_id is null and partner_id is not null)
  )
);

create table playbook_steps (
  id             uuid primary key default gen_random_uuid(),
  playbook_id    uuid not null references playbooks(id) on delete cascade,
  step_number    integer not null check (step_number > 0),
  delay_minutes  integer not null default 0 check (delay_minutes >= 0),
  channel        text not null check (channel in ('sms', 'email', 'voice', 'staff_task')),
  template       text,
  stop_on_reply  boolean not null default true,
  created_at     timestamptz not null default now(),
  unique (playbook_id, step_number)
);

create table integrations (
  id               uuid primary key default gen_random_uuid(),
  location_id      uuid not null references locations(id) on delete cascade,
  kind             text not null check (kind in (
                     'gym_crm', 'payments', 'calendar', 'telephony', 'messaging')),
  provider         text not null,  -- pushpress | zenplanner | stripe | twilio
  status           text not null default 'pending' check (status in (
                     'pending', 'connected', 'error', 'disconnected')),

  -- WHY a reference and not the credential: this column holds a pointer into
  -- a secrets manager (AWS Secrets Manager, Vault, Doppler). API keys must
  -- never sit in the application database -- a read-only SQL injection or a
  -- leaked backup would otherwise hand over every customer's payment system.
  credentials_ref  text,

  config           jsonb not null default '{}'::jsonb,
  last_sync_at     timestamptz,
  last_error       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index integrations_unique on integrations (location_id, kind, provider);

-- WHY raw webhooks are stored before they are processed: third-party APIs
-- deliver twice, out of order, and occasionally not at all. Writing the raw
-- payload first gives you idempotency (the unique index), a replay button
-- when a bug ate an event, and evidence when a provider insists they sent it.
create table webhook_events (
  id                 bigserial primary key,
  location_id        uuid references locations(id) on delete set null,
  provider           text not null,
  event_type         text,
  provider_event_id  text,
  payload            jsonb not null,
  signature_verified boolean not null default false,
  status             text not null default 'received' check (status in (
                       'received', 'processed', 'failed', 'ignored')),
  error              text,
  received_at        timestamptz not null default now(),
  processed_at       timestamptz
);
create unique index webhook_events_provider_unique
  on webhook_events (provider, provider_event_id)
  where provider_event_id is not null;
create index webhook_events_unprocessed_idx
  on webhook_events (received_at)
  where status in ('received', 'failed');


-- ============================================================================
-- updated_at triggers
-- ============================================================================

do $$
declare t text;
begin
  foreach t in array array[
    'partners', 'organizations', 'locations', 'staff_users', 'contacts',
    'agent_configs', 'conversations', 'appointments', 'memberships',
    'recovery_cases', 'playbooks', 'integrations'
  ] loop
    execute format(
      'create trigger %I_set_updated_at before update on %I
         for each row execute function set_updated_at()', t, t);
  end loop;
end;
$$;

commit;
