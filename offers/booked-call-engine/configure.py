#!/usr/bin/env python3
"""Fill every placeholder across the site in one go.

    python3 configure.py --pixel 123456789012345 \
        --webhook https://services.leadconnectorhq.com/hooks/XXXX \
        --calendly https://calendly.com/you/60min \
        --entity "Chabfit Inc." --address "Halifax, NS, Canada" \
        --jurisdiction "Nova Scotia, Canada"

Every flag is optional — pass what you have, run it again when you have more.
Run with no flags to see what's still outstanding.
"""
import argparse, pathlib, re, sys

HERE = pathlib.Path(__file__).parent
FILES = ["sales.html", "access.html", "access-bundle.html", "privacy.html", "terms.html"]

MAP = {
    "pixel":        ("YOUR_PIXEL_ID",                "Meta pixel ID"),
    "webhook":      ("YOUR_GHL_INBOUND_WEBHOOK_URL", "GoHighLevel inbound webhook"),
    "email":        ("YOUR_EMAIL",                   "support email"),
    "entity":       ("YOUR_LEGAL_ENTITY",            "legal entity"),
    "address":      ("YOUR_BUSINESS_ADDRESS",        "business address"),
    "jurisdiction": ("YOUR_JURISDICTION",            "governing law"),
}

OLD_CALENDLY = "https://calendly.com/brentlongevityphysiquegroup/30min"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    for k, (_, help_) in MAP.items():
        ap.add_argument(f"--{k}", help=help_)
    ap.add_argument("--calendly", help="60-minute Calendly booking URL")
    args = ap.parse_args()

    changed = {}
    for name in FILES:
        p = HERE / name
        if not p.exists():
            continue
        text = original = p.read_text()

        for key, (token, _) in MAP.items():
            val = getattr(args, key)
            if val:
                n = text.count(token)
                if n:
                    text = text.replace(token, val)
                    changed.setdefault(name, []).append(f"{token} x{n}")

        if args.calendly and OLD_CALENDLY in text:
            n = text.count(OLD_CALENDLY)
            text = text.replace(OLD_CALENDLY, args.calendly)
            changed.setdefault(name, []).append(f"calendly x{n}")

        if text != original:
            p.write_text(text)

    if changed:
        print("Updated:")
        for f, items in changed.items():
            print(f"  {f}: {', '.join(items)}")
        print()

    # report what's left
    left = {}
    for name in FILES:
        p = HERE / name
        if not p.exists():
            continue
        for tok in re.findall(r"YOUR_[A-Z_]+", p.read_text()):
            left.setdefault(tok, set()).add(name)
    if OLD_CALENDLY in (HERE / "access-bundle.html").read_text():
        left["30-MINUTE CALENDLY (offer says 60)"] = {"access-bundle.html"}

    if left:
        print("Still outstanding:")
        flag = {v[0]: k for k, v in MAP.items()}
        for tok in sorted(left):
            f = flag.get(tok)
            print(f"  {tok:32} {', '.join(sorted(left[tok]))}"
                  + (f"   --{f}" if f else "   (fix in Calendly, then --calendly)"))
        return 1

    print("No placeholders left. Ready to deploy.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
