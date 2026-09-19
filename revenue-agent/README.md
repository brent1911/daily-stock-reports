# Revenue Agent

An AI front desk for gyms and fitness studios that recovers money the business
is already losing: missed inbound enquiries, failed card payments, and members
drifting toward cancellation.

Sold direct first to prove the numbers, then white-labelled to gym software
vendors and franchise groups.

> **Status: data model only.** No application code yet. The schema is designed,
> applied against Postgres 16, and proven by a smoke test. Read
> [`docs/data-model.md`](docs/data-model.md) before anything else.

## Why this product

The pitch is one sentence with a number in it: *"we recovered $8,400 last
month and we cost $400."* Everything in the schema exists to make that sentence
true, auditable, and queryable in a single `SELECT`.

Three jobs, all pointed at money that already exists and is leaking:

1. **Missed inbound** — calls, texts, web forms and DMs answered in seconds,
   24/7, qualified and booked into a trial.
2. **Failed payment recovery** — declined cards worked automatically, with the
   message matched to the decline reason.
3. **Churn winback** — members who stopped showing up, contacted before they
   cancel rather than after.

## Layout

```
revenue-agent/
  db/
    migrations/0001_init.sql          the schema, annotated with every WHY
    migrations/0002_attribution_rule.sql  when we may claim we recovered money
    smoke_test.sql                    one scenario end to end + five assertions
    attribution_test.sql              six attribution scenarios, four refused
  docs/
    data-model.md              the map, the arguments, the open questions
    attribution.md             the recovery rule, written for a customer
```

## Quick start

Requires Postgres 13 or newer.

```bash
createdb revagent
export DB="postgresql://localhost/revagent"

for f in db/migrations/*.sql; do psql "$DB" -v ON_ERROR_STOP=1 -f "$f"; done
psql "$DB" -v ON_ERROR_STOP=1 -f db/smoke_test.sql
psql "$DB" -v ON_ERROR_STOP=1 -f db/attribution_test.sql
```

Both test files roll back, so they are safe to run repeatedly.

## What comes next

In order, smallest first:

1. **Telephony in** — one phone number that forwards missed calls, writing
   `calls` and `conversations` rows.
2. **The agent loop** — read `agent_configs`, reply over SMS, book into
   `appointments`, escalate when it should.
3. **Stripe webhooks in** — `webhook_events` → `payment_attempts` →
   open a `recovery_case`.
4. **The dashboard** — three numbers, read from `v_recovered_revenue` and
   `v_agent_activity`: conversations handled, trials booked, revenue
   recovered.

Nothing else until three gyms that you do not own are paying.
