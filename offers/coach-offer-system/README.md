# The Coach Offer System — $197

A standalone paid digital product for online fitness coaches and gym owners.
Built to profit on its own, not to act as a loss-leader.

**Live:** https://claude.ai/artifact/5TLq8gVHLgW5KQGJke2AUM
*(private — share from the page's Share menu before selling access)*

## Why this product

Across twenty recorded sales calls, the same move appears every time: the
pricing and offer structure get fixed *before* anything is spent on ads.
That diagnosis is the most valuable thing delivered on a call, it is
repeated almost verbatim each time, and it does not require being in the
room. So it is sellable.

The IP already existed as a byproduct of client work. Marginal cost of a
sale is a Stripe fee.

## The finding the product is built on

At a realistic $100–400 per booked call, and a competent 70% show / 30% close,
each structure can absorb only so much traffic cost before the 3:1 rule breaks:

| Structure | Lifetime value | Ceiling per booked call |
|---|---|---|
| Month-to-month $150 | $450 | **$32** — cannot run paid ads at all |
| Minimum Commitment $600×4 | $2,400 | $168 |
| Recurring Renewal $2k/6mo | $3,000 | $210 |
| Deposit Hybrid $2,500 + $300×6 | $4,300 | **$301** |
| PIF Intensive $6,000 | $6,000 | **$420** |

Only the last two carry the top of the range. This is the whole argument for
premium structure, and it is arithmetic rather than opinion — which is what makes
it survive a prospect who has been burned by an agency before.

The recoup guarantee is the multiplier: lifting close rate from 30% to 40% raises
every ceiling above by about a third, because it cuts the booked calls needed per
signed client from 4.8 to 3.6.

## What is inside

| Module | What it does |
|---|---|
| 01 — Price Floor | Live calculator. Takes price, commitment, retention, show rate, close rate and cost per booked call. Headlines the **ceiling** — the most a booked call can cost before the offer breaks — then shows the verdict across the whole $100–400 range, not at one guessed number. Solves for the price *or* the retention that would fix it. |
| 02 — Five structures that hold | Five field-tested structures, each carrying its ceiling, so they rank by the traffic cost they can actually absorb. |
| 03 — Qualifying on money, early | Five-beat call script that surfaces budget inside the first ten minutes. |
| 04 — Ad-readiness check | Nine-item gate with saved state. Tracking, portfolio hygiene, follow-up, creative, starting budget. |

## The goal model (corrected)

The first version computed `clients needed x cost per client` and labelled the
result "monthly ad spend required". That is the **one-time cost to build the
client base**, not a recurring bill, and presenting it as monthly made the
output absurd — it implied spending six figures every month to hold $10k/mo.
It also ignored churn, which is the number that actually decides the business.

The model is now steady-state, via Little's law: holding N clients at M months
average retention requires replacing N/M of them every month. So the page shows
three separate figures instead of one conflated one:

- **One-time build cost** — `N x CAC`, spent once across the ramp
- **Ongoing monthly spend** — `(N / M) x CAC`, the churn treadmill
- **Monthly profit or loss** — `goal - ongoing`, which is the only
  apples-to-apples comparison on the page and is now the headline

Worked, to add $10,000/month:

| Offer | Build once | Monthly spend | Monthly P/L | LTV:CAC |
|---|---|---|---|---|
| Month-to-month $150, 3mo retention | $111,111 | $37,037 | **−$27,037** | 0.27 |
| $600 x 4mo commitment, 5mo retention | $15,873 | $3,175 | **+$6,825** | 3.15 |
| $6,000 PIF over 2mo | $4,762 | $2,381 | **+$7,619** | 4.20 |

The page also flags when months-to-repay exceeds retention — at which point the
client leaves before covering their own acquisition and no volume of spend ever
turns profitable.

## Pricing and economics

**$197, one time.** Positioned on the arithmetic: one correct pricing change
on a single client returns the cost many times over.

- Warm traffic (existing audience, past clients, client audiences): acquisition
  cost is effectively zero, so roughly **$191 net per sale** after card fees.
- Cold paid traffic: expect a materially higher cost per purchase for a $197
  information product. Treat cold as a **buyer-acquisition channel** that
  roughly washes its face, not as the profit engine.

**Sell warm first.** It both produces the profit and generates the testimonials
that make cold traffic viable later.

## Ascension

The product ends on the honest limit of what a document can do: repricing takes
an afternoon, building the acquisition machine does not. That is the $5–6k
engagement, and the buyer has now pre-qualified themselves by paying.

## Before launch

1. Replace the `#book` placeholder in the CTA with the real booking link.
2. Cost per booked call is now a user input defaulting to $200, with $100–400
   stated as the realistic range. If the blended figure from managed accounts is
   tighter than that, narrow the `BAND` constant in the script — an observed
   range is more defensible than a borrowed one.
3. Decide on the guarantee. A plain 30-day refund is standard at this price and
   rarely abused on a product that delivers in one sitting.
