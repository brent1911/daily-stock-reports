# What counts as recovered revenue

**Attribution rule v1 — conservative.** Settled 2026-09-19.

This document is written to be readable by a customer. If a gym owner asks
*"how do you decide you recovered that money?"*, hand them this page.

---

## The principle

**Under-claim and be trusted.**

A gym owner who spot-checks one case and finds we credited ourselves for
something we did not cause will cancel — and tell every other gym owner they
know. The cost of claiming too little is some revenue we could have billed for.
The cost of claiming too much is the business.

So every rule below is set where we can defend it out loud, not where it
produces the biggest number.

---

## The rules

### Failed payment — the 14-day rule

We count it when **all three** are true:

1. The agent contacted the member about the failed payment, **and**
2. the payment cleared **within 14 days** of that contact, **and**
3. **no gym staff member contacted them first** about it.

If a coach already called them, the credit is the coach's. If the payment
cleared three weeks later, we assume they would have got there anyway.

### At-risk member and cancellation save

We count it when the agent reached out **and the member subsequently made a
real payment.**

Not "they didn't cancel" — a member who stays on the books but never pays is
not recovered revenue. This means a save can take up to a billing cycle to
show up on the dashboard. That lag is the price of a number nobody can argue
with.

### New leads and missed calls

We count dollars only when the agent booked an appointment, **the person
actually showed up**, and they **started a paying membership within 30 days.**

A booked trial is activity, not revenue. A no-show is worth nothing. Trials
booked and attended are reported as their own count, on a separate line, and
are never converted into a dollar figure.

---

## What this deliberately gives up

Honest accounting of what the rule costs us:

- A member who gets our text, ignores it, and updates their card on day 19 is
  **not counted**, even though we probably caused it.
- A save where the member's next bill is five weeks out sits uncounted until
  that bill clears.
- A lead who attends a trial, loves it, and joins two months later is **not
  counted**.

All three are real recovery we do not bill for. That is the trade, made on
purpose.

---

## How it is enforced

The rule is not a policy document that code is trusted to follow. It is a
database function, `evaluate_attribution(case_id)`, defined in
[`../db/migrations/0002_attribution_rule.sql`](../db/migrations/0002_attribution_rule.sql).

It returns a verdict, a basis, and a plain-English reason — **including when
the answer is no**, because "why didn't you count this one?" deserves a stored
answer too.

Six scenarios are tested in
[`../db/attribution_test.sql`](../db/attribution_test.sql). Four of them assert
that the rule **refuses** to count something:

```
ok  [a] paid 1 day after contact           -> COUNTED (agent_touched_then_paid)
ok  [b] staff texted first                 -> not counted (gym staff contacted this person before the agent did)
ok  [c] paid 19 days later, outside window -> not counted (no successful payment in the 14 days after the agent made contact)
ok  [d] never paid                         -> not counted (no successful payment in the 14 days after the agent made contact)
ok  [e] attended trial then joined         -> COUNTED (agent_booked_then_joined)
ok  [f] booked trial but no-showed         -> not counted (no agent-booked appointment was attended)
```

Reporting reads two views, so the definition exists in exactly one place:

- `v_recovered_revenue` — hard dollars, attributed cases only
- `v_agent_activity` — trials booked / attended / no-showed, never in dollars

The day someone writes their own slightly different `SUM` is the day two
screens disagree in front of a customer.

---

## Changing the rule later

The rule is **versioned**, and each case stores the version it was judged
under (`attribution_rule_version`, `attribution_window_days`).

When you tighten or loosen it, you bump the version and apply it to new cases
only. **Past invoices never restate.** A customer who exports their numbers in
March and again in June must see the same figure for March.

---

## Known limitation

We only see staff contact that happens **inside the system**. If a coach calls
a member from their personal phone, we have no record of it and rule (3) above
cannot catch it — we would count that recovery as ours.

Mitigations, cheapest first: ask gyms to log outreach, pull call logs from
their phone system if they have one, and let staff mark a case as
`manual_override` with a reason. Worth revisiting once there is a real customer
to ask about it.
