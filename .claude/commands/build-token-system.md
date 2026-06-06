Convert raw extracted tokens into a structured design token system with proper naming conventions and light/dark modes.

Reads from: `tokens/raw.json`
Writes to: `tokens/system/` directory

## Architecture

Three-tier system:

**Tier 1 — Primitives** (`tokens/system/primitives.json`)
Named raw values. No semantic meaning. Source of truth.

- If `raw.json` has named palettes (e.g. `arctic`, `indigo`) → mirror those names directly into primitives.
- If `raw.json` has only unnamed hex values → assign the closest standard scale step (50/100/.../900).
- Include typography, spacing, radius, and shadow as separate top-level keys.

**Tier 2 — Semantic tokens** (`tokens/system/semantic.json`)
Reference primitives via `{color.name.step}` syntax. Carry meaning. Define light/dark modes as sibling keys.

```json
{
  "color": {
    "background": {
      "default": {
        "light": "{color.neutral.0}",
        "dark": "{color.neutral.950}"
      },
      "subtle": { "light": "{color.neutral.50}", "dark": "{color.neutral.900}" }
    },
    "text": {
      "default": {
        "light": "{color.neutral.900}",
        "dark": "{color.neutral.50}"
      },
      "muted": { "light": "{color.neutral.500}", "dark": "{color.neutral.400}" }
    },
    "interactive": {
      "primary": { "light": "{color.brand.500}", "dark": "{color.brand.700}" },
      "primary-hover": {
        "light": "{color.brand.400}",
        "dark": "{color.brand.400}"
      }
    }
  }
}
```

**Tier 3 — Component tokens** (deferred — generated per component later)

## Steps

1. Read `tokens/raw.json`
2. Build `tokens/system/primitives.json` — named palette + typography + spacing + radius + shadow
3. Infer semantic roles from usage context in `raw.json` (check `components`, `modes`, `tailwindMapped`) or from perceptual lightness:
   - Very light → background/surface candidates
   - Very dark → text/foreground candidates
   - Mid-range saturated → interactive/accent candidates
4. Identify ambiguous mode assignments (fewer than 2 data points to confirm a dark-mode value). Collect them and ask the user in a single `AskUserQuestion` call before writing anything.
5. Write all three output files using confirmed values:
   - `tokens/system/primitives.json`
   - `tokens/system/semantic.json`
   - `tokens/system/tokens.css` — three blocks: primitives in `:root`, light semantic in `:root, [data-theme="light"]`, dark semantic in `[data-theme="dark"]`
6. **Contrast audit** — before writing any file, check every dark-mode text/background pairing in `semantic.json`:
   - Resolve each token's dark value to its primitive hex.
   - For each `text.*` token, identify which `background.*` it is intended to sit on (e.g. `text-on-brand` → `background-brand` or `background-brand-subtle`).
   - If the background resolves to a dark hex, the text must resolve to a light hex — and vice versa. Flag any pair where both are dark or both are light.
   - Fix flagged tokens before writing output. A token name like `text-on-brand` encodes _context_, not appearance; its dark-mode value must flip when the surface it sits on flips.
7. Update `docs/token-conventions.md` with palette tables, semantic token reference, and a decisions/rationale section.
8. Print a summary table of all semantic tokens with their light/dark resolved hex values.

## CSS output structure

```css
/* Primitives — static, no modes */
:root {
  --primitive-color-brand-500: #hex;
  --primitive-font-size-base: 1rem;
}

/* Semantic — light (default) */
:root,
[data-theme="light"] {
  --color-background-default: var(--primitive-color-neutral-0);
  --color-text-default: var(--primitive-color-neutral-900);
  --color-interactive-primary: var(--primitive-color-brand-500);
}

/* Semantic — dark */
[data-theme="dark"] {
  --color-background-default: var(--primitive-color-neutral-950);
  --color-text-default: var(--primitive-color-neutral-50);
  --color-interactive-primary: var(--primitive-color-brand-700);
}
```
