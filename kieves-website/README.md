# Still Studio — website mockup

A single-file, dependency-free website mockup for **Still Studio**, the interior styling
and moodboard practice of Kieve Bourgeois (`@stillstudio.curated`).

## Run it

Open `index.html` in any browser. No build step, no npm install, no server required.

## What's in the page

| Section | Purpose |
| --- | --- |
| Hero | Positioning line + a "specimen card" — live paint codes, textile weight, light temperature |
| Selected rooms | Four project tiles with spec metadata (sq ft, palette, timeline) |
| Services | Three priced tiers, middle tier flagged as the lead offer |
| Process | Four approval stages: Intake → Direction → Sourcing → Install |
| Material library | Standing palette of six materials with trade specs |
| About | Founder bio and credentials |
| Inquiry | Qualifying form (service, room, problem) with a confirmation state |

## Design notes

- **Palette** — chalk-green neutrals with a verdigris accent (`#43604B` light / `#9CBCA0` dark),
  deliberately avoiding the stock cream-and-terracotta interiors look.
- **Type** — Fraunces (display), Karla (body), IBM Plex Mono (spec data), via Google Fonts.
- **Imagery** — all room and material tiles are CSS gradients, not photos. They are standing in
  for a real shoot; replace each `.art`/`.mat i` background with an `<img>` when photography exists.
- **Themes** — light and dark are both defined at token level and follow the visitor's OS setting.
- **Responsive** — three-column down to one column at phone width, with a collapsing nav.

## Placeholders to replace before launch

- Prices ($450 / $1,600 / from $4,800) are plausible market-rate placeholders, not quoted rates.
- Project names, square footage and timelines are illustrative.
- `hello@stillstudio.co` is a placeholder address.
- The inquiry form is client-side only — it shows a confirmation but sends nothing.
  Wire it to an inbox, a form service, or a CRM to capture leads.
