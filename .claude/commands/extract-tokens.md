Extract design tokens from a live webpage.

Usage: /extract-tokens <url>

## Phase 1 — Run extraction script

```bash
bash .claude/scripts/extract-tokens.sh <url>
```

The script fetches raw HTML and CSS bundles via `curl`, preserving all element `class=` attributes (unlike WebFetch which strips them). It outputs structured sections for each token type.

After the script, if `=== GOOGLE_FONTS ===` shows URLs, fetch them via WebFetch to get the exact font families and weight ranges.

**Determine site type from output:**

- `framework: astro/nextjs` or CSS bundle contains Tailwind utility class rules → **Tailwind site** → Phase 2B
- `framework: unknown` and CSS bundle contains `--variable-name:` declarations → **Traditional CSS** → Phase 2A

---

## Phase 2A — Traditional CSS site

Fetch each CSS bundle URL with WebFetch. Parse for:

- CSS custom properties (`--variable-name: value`)
- Color values (hex, rgb, hsl, oklch)
- `font-family`, `font-size`, `font-weight`, `line-height`
- `border-radius`, `box-shadow` / `filter: drop-shadow()`
- Repeated `padding`/`margin`/`gap` values (spacing scale)

---

## Phase 2B — Tailwind site

All color data comes from the script output. No additional fetches needed unless a value is missing.

**Interactive element colors:**

- `BG_CLASSES_ON_BUTTONS_AND_ANCHORS` → primary/secondary CTA backgrounds
- `TEXT_CLASSES_ON_BUTTONS_AND_ANCHORS` → button text colors
- `FULL_CTA_TAGS` → complete class strings; confirms gradient, shape, hover states

**Color resolution — CSS bundle is the source of truth:**

- Class found in `CSS_BUNDLE_CUSTOM_COLORS` → use the rgb/hex value from the bundle (may differ from standard Tailwind defaults; the bundle wins)
- Class NOT in the bundle → use standard Tailwind v3 values:
  - slate: 900→#0f172a, 800→#1e293b, 700→#334155, 500→#64748b, 300→#cbd5e1, 200→#e2e8f0
  - white→#ffffff, black→#000000, red-500→#ef4444, blue-600→#2563eb

**Heading colors:** default black (light) / white (dark) unless a color class appears on h1/h2.

---

## Phase 3 — Visual fallback

**Only run if Phase 2B found fewer than 3 non-neutral brand colors.**

Fetch `/features/`, `/products/`, or `/platform/` to find CDN image URLs (Cloudinary, imgix, HubSpot CDN). Priority: UI/product screenshots > OG image > hero backgrounds.

Fetch each image with WebFetch. If the response says the file is binary/saved to disk, use the `Read` tool on that path — Claude reads images directly.

In screenshots: filled pill/rectangular buttons = primary color. Avatar/icon fills ≠ button backgrounds.

---

## Phase 4 — Write `tokens/raw.json`

```json
{
  "source": "<url>",
  "extractedAt": "<ISO timestamp>",
  "techStack": "Astro + Tailwind CSS | etc.",
  "extractionMethod": "compiled-tailwind | css-custom-properties | mixed",
  "colors": {
    "raw": ["#hex", "..."],
    "cssVars": {},
    "tailwindCustom": { "color-name-scale": "#hex" },
    "tailwindMapped": { "bg-class": "#hex" }
  },
  "typography": {
    "fontFamilies": [],
    "fontSizes": [],
    "fontWeights": [],
    "lineHeights": [],
    "cssVars": {}
  },
  "components": {
    "buttonPrimary": {
      "background": "",
      "textColor": "",
      "borderRadius": "",
      "extractedFrom": "curl class attr | css bundle | visual"
    }
  },
  "spacing": { "raw": [] },
  "radii": [],
  "shadows": [],
  "effects": {},
  "modes": { "light": {}, "dark": {} },
  "notes": ""
}
```

Always populate `components.buttonPrimary.extractedFrom` noting which method found the value.

---

## Phase 5 — Print summary

Table of found values grouped by category, then flag:

- Custom Tailwind colors that differ from standard defaults
- Any values still missing (font sizes, spacing scale)
- Colors within 5% perceptual distance that may collapse to one token
