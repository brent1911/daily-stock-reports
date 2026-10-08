# Go live

Everything in this folder deploys as one unit. Nine steps, roughly an hour.

## 1. Fill in the placeholders

Find and replace across the folder:

| Placeholder | What it is | Appears in |
|---|---|---|
| `YOUR_EMAIL` | Support address buyers write to | sales, access ×2, privacy, terms |
| `YOUR_PIXEL_ID` | Meta pixel ID (Events Manager) | sales.html ×2 |
| `YOUR_GHL_INBOUND_WEBHOOK_URL` | GHL inbound webhook | sales.html |
| `YOUR_LEGAL_ENTITY` | Trading name or company | privacy, terms |
| `YOUR_BUSINESS_ADDRESS` | Registered/trading address | privacy, terms |
| `YOUR_JURISDICTION` | e.g. Nova Scotia, Canada | terms.html |

```bash
grep -rn "YOUR_" --include="*.html" .
```

## 2. Deploy

Drag this folder onto [netlify.com/drop](https://app.netlify.com/drop). HTTPS is
automatic, which the service worker needs. You get:

```
/sales.html          the landing page
/access.html         guide buyers land here
/access-bundle.html  call buyers land here
/app/                the guide as an installable app
/privacy.html  /terms.html
/Booked-Call-Engine.pdf
```

Point a real domain at it when ready. `sales.html` can be renamed `index.html`
to sit at the root.

## 3. Whop redirects

In each product's settings, set the post-purchase redirect:

| Product | Redirect to |
|---|---|
| the-booked-call-engine | `/access.html` |
| the-booked-call-engine-1-1-call | `/access-bundle.html` |

Without this a buyer pays and lands on a bare receipt, which is where refund
requests come from.

## 4. Calendly — fix the duration first

The link in `access-bundle.html` is a **30-minute** event. Everything sold says
**60 minutes**. Create a 60-minute event type and swap the URL in three places
in that file, or change the offer.

## 5. GoHighLevel

Automation → Workflows → Create → trigger **Inbound Webhook**. Copy the URL into
`sales.html`. In the same workflow:

1. Create/Update Contact — maps `firstName`, `email`
2. Add Tag — `bce-section-1`
3. Create Opportunity — pipeline **CGGos**
4. Send the email with Section 1

The form posts `utm_source`, `utm_medium`, `utm_campaign`, `utm_content` and
`fbclid`, so store those on the contact — otherwise you can't tell which ad
produced a lead.

## 6. Buyers into GHL

Separate from the above, and more important. Whop → GHL via their webhook or
Zapier, on purchase. Your buyers are who you'd ascend to the agency; right now
they'd never reach your CRM.

## 7. Meta pixel

Events Manager → copy the pixel ID into `sales.html`. Already wired:

| Event | Fires when | Value |
|---|---|---|
| `PageView` | page loads | — |
| `ViewContent` | page loads | $197 |
| `InitiateCheckout` | any checkout link clicked | $197 or $896 |
| `Lead` | opt-in submitted | $0 |

Verify each with the Meta Pixel Helper before spending anything. Then add the
Conversions API through Whop or a server-side tool — browser-only tracking
loses a meaningful share of conversions, exactly as Section 5 says.

## 8. Test the whole path

- [ ] Page loads on a phone, both themes
- [ ] Toggle switches between $197 and $896, button link changes
- [ ] Opt-in submits and the contact lands in CGGos
- [ ] Buy the guide yourself — redirect lands on `access.html`
- [ ] PDF downloads, app opens, add-to-home-screen works
- [ ] Buy the bundle — redirect lands on `access-bundle.html`, Calendly loads
- [ ] Refund yourself to confirm the refund path works
- [ ] Pixel Helper shows all four events

## 9. Then traffic

Start at $20/day. The product's own Section 3 applies to selling the product:
a call funnel under $70/day never leaves the learning phase.

**Keep the income figures out of ad creative.** They're fine on your own page;
in Meta ad copy they're restricted and routinely rejected.

---

## Still missing, and worth having

**Proof from buyers.** There is none yet — the figures on the page are an
account you run, not a student result. Give it free to five coaches you know
in exchange for a documented outcome, then rebuild the top of the page around
those.

**Your face.** No photo of you anywhere, on a page selling access to your
expertise and an hour of your time. A single honest headshot near the $699
offer is one of the cheapest trust additions available.

**One name.** The store is `sales-ascent`, Calendly is
`brentlongevityphysiquegroup`, the pages are signed Brent Chabassol. That's
three identities across one purchase.

**The PDF's benchmarks disagree with your own account** — it says $60–200 per
booked call and 45–65% show rate; your dashboard shows $250 and 72.4%. The
sales page was corrected; the guide still carries the older ranges.
