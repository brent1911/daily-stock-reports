# Deploy to chabassolgrowth

Everything in this folder is a static site. No build step, no server, no
dependencies. Upload the contents and it works.

## What's here

| File | Serves at | What it is |
|---|---|---|
| `index.html` | `/` | The landing page |
| `access.html` | `/access.html` | Where guide buyers land after checkout |
| `access-bundle.html` | `/access-bundle.html` | Where bundle buyers land — Calendly above the download |
| `privacy.html` | `/privacy.html` | Required by Meta to run ads |
| `terms.html` | `/terms.html` | Refund terms, licence, liability |
| `app/` | `/app/` | The 48-page guide as an installable web app |
| `Booked-Call-Engine.pdf` | `/Booked-Call-Engine.pdf` | The guide as a PDF |
| `img/` | `/img/` | Founder photo + 5 Ads Manager proof screenshots |

All links between pages are relative. Nothing needs rewriting.

## Deploying

**Cloudflare Pages or Netlify**, either is fine and both are free.

1. Upload this folder (or connect the repo and point it at this directory)
2. Add `chabassolgrowth.com` as a custom domain
3. Point the domain's DNS at the host as it instructs
4. Confirm HTTPS is on — **the web app's offline mode requires it**

**Do not** serve this from a subdirectory like `/offers/`. The app's service
worker is scoped to `./`, and the manifest's `start_url` assumes `/app/`.
Root or a dedicated subdomain (`get.chabassolgrowth.com`) both work.

## After the domain is live

### 1. Whop post-purchase redirects

| Product | Redirect to |
|---|---|
| `the-booked-call-engine` | `https://chabassolgrowth.com/access.html` |
| `the-booked-call-engine-1-1-call` | `https://chabassolgrowth.com/access-bundle.html` |

Without these a buyer pays and lands on a bare receipt.

### 2. Placeholders still in the HTML

Search the files for `YOUR_` — six values remain:

| Placeholder | In | Where it comes from |
|---|---|---|
| `YOUR_PIXEL_ID` | index.html ×2 | Meta Events Manager |
| `YOUR_GHL_INBOUND_WEBHOOK_URL` | index.html | GHL → Workflows → Inbound Webhook |
| `YOUR_LEGAL_ENTITY` | privacy, terms | The business |
| `YOUR_BUSINESS_ADDRESS` | privacy, terms | The business |
| `YOUR_JURISDICTION` | terms | e.g. Nova Scotia, Canada |

The support email (`brent@chabfit.co`) is already filled in. Change it if the
public-facing address should differ.

### 3. One defect to fix before selling the bundle

`access-bundle.html` embeds a **30-minute** Calendly event. The bundle sells
**60 minutes**. Create a 60-minute event type and replace the three
occurrences of:

```
https://calendly.com/brentlongevityphysiquegroup/30min
```

This is the only thing in the build that short-changes a paying buyer.

## Blocking everything else: the ad account

**Meta ad account 147465286 has no Facebook Page and no pixel attached.**
Verified 8 Oct 2026 — pages: 0, pixels: 0, ad library assets: 0.

No Meta ad can be created without a Page. The account shows $15,449 of spend
through 27 August and nothing since, which fits a Page or portfolio
restriction rather than a simple pause.

Check account quality in Business Suite first. If restricted, appeal once —
do not create a second account while an appeal is open.

The site can go live today regardless. The ads cannot.

## Facts an incoming conversation will need

- **Products:** $197 guide · $896 bundle (or 2×$448) · $699 hour alone
- **Checkout:** Whop, store `sales-ascent`
- **Guarantee:** 30 days, conditional on completing Sections 1–2
- **Pixel events already wired:** `ViewContent` ($197), `InitiateCheckout`
  ($197 or $896 depending on which link), `Lead` (opt-in)
- **Opt-in posts** name, email, source, tag `bce-section-1`, and
  `utm_source` / `utm_medium` / `utm_campaign` / `utm_content` / `fbclid`
- **Target pipeline in GHL:** CGGos
- **Real account benchmarks:** $250 per booked call, 72.4% show, 32.7% close,
  3.79× return on $19k spend. Five ad sets ranged $6.44–$100.65 per booked
  call, blended $72 across $1,804.
- **Compliance:** keep income figures off ad creative. Fine on this site,
  restricted in Meta ad copy.

## Known issues carried forward

- The PDF quotes $60–200 per booked call and 45–65% show rate. The real
  account runs $250 and 72.4%. The landing page was corrected; the PDF was
  not.
- No student results exist yet — all proof is from accounts the business
  runs. Any claim about buyer outcomes would be unsupported.
- Four identities appear across one purchase: `sales-ascent` (store),
  `brentlongevityphysiquegroup` (calendar), Brent Chabassol (pages),
  `chabfit.co` (email).
