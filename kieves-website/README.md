# Still Studio — website mockup

A single-file, dependency-free portfolio site for **Still Studio**, the interior styling
practice of Kieve Bourgeois (`@stillstudio.curated`).

## Run it

Open `index.html` in any browser. No build step, no dependencies, no server.

## Page structure

| Section | Purpose |
| --- | --- |
| Opening | Positioning line, then a full-bleed light study with an editorial caption |
| Statement | The studio's point of view and its material range |
| Selected work | Four projects in an asymmetric grid; each opens a case-study overlay |
| Services | Three tiers set as an editorial fee index, not pricing cards |
| Process | Four stages: Intake → Direction → Sourcing → Install |
| Material library | Six standing materials with trade specs |
| Studio | Founder letter, signature, and three figures |
| From the studio | Instagram-style strip of five tiles |
| Inquiry | Qualifying form with a confirmation state |

## Design notes

- **Palette** — layered beige: sand `#E7E0D4`, bone `#F3EFE7`, shell `#DCD3C4`, clay `#C6B8A3`,
  umber `#2C2621`. There is deliberately **no accent color**; the imagery and the warm near-black
  carry all the contrast.
- **Type** — Cormorant Garamond at light weight for display, Jost at 300 for body, wide-tracked
  uppercase Jost for labels. Loaded from Google Fonts with real fallback stacks.
- **Imagery** — every room scene is rendered in CSS: layered gradients, blurred light shapes and
  an SVG film-grain overlay. They are art-directed placeholders for a real shoot — swap each
  `.scene` block for an `<img>` when photography exists.
- **Single theme by design** — this commits to one warm printed-catalogue world rather than
  inverting to dark mode; every color is painted explicitly.
- **Motion** — restrained: a slow image scale on hover, nothing that animates in on scroll.
  `prefers-reduced-motion` is respected.
- **Accessibility** — visible focus rings, labelled form controls, `aria-expanded` on the menu,
  `role="img"` with descriptions on the scenes, Esc and scrim close on the case-study overlay.

## Placeholder content to replace before launch

- Prices ($450 / $1,600 / from $4,800) are plausible market-rate placeholders, not quoted rates.
- Project names, square footage, timelines and case-study copy are illustrative.
- `hello@stillstudio.co` is a placeholder address.
- The inquiry form is client-side only — it renders a confirmation but sends nothing. Wire it to
  an inbox, a form service, or a CRM to capture leads.
