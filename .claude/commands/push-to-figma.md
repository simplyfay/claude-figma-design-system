Publish the token system and components to the connected Figma file.

Reads from: `tokens/system/primitives.json`, `tokens/system/semantic.json`, `components/*.tsx`
Requires: Figma MCP server connected, Figma file URL as argument or in CLAUDE.md

## Pre-flight

1. Load the `figma:figma-use` skill — **mandatory before any `use_figma` call**
2. Read `tokens/system/primitives.json` and `tokens/system/semantic.json` from disk
3. If no Figma file URL is available, ask for it before proceeding
4. Run one inspection `use_figma` call to discover existing pages, variable collections, and rightmost x position — never skip this step

---

## Phase 1 — Pages

Create missing pages only (skip if they already exist):
- `Tokens` — holds the Token Reference frame
- `Components` — holds all component sets

---

## Phase 2 — Variables

Work in **two separate `use_figma` calls**. Never combine — scripts are atomic and errors become unrecoverable at scale.

### Call A — Primitives collection

- Collection name: `"Primitives"`, single mode renamed `"Value"`
- Source: every entry under `color` in `primitives.json`
- Variable name mirrors the JSON path with `/` as separator: e.g. `color/lime/500`, `color/midnight`
- `scopes = ["ALL_SCOPES"]` on every primitive
- **Return** the full `{ name → id }` map — needed in Call B

### Call B — Design Tokens collection

- Collection name: `"Design Tokens"`, two modes: `"Light"` and `"Dark"`
- Source: every leaf entry under `color` in `semantic.json`
- Variable name mirrors the JSON path: e.g. `color/background/default`, `color/text/link`
- Values are **aliases** to primitives: `{ type: "VARIABLE_ALIAS", id: primitiveId }`
- Resolve primitive IDs from the map returned by Call A — never hardcode IDs
- Set scopes by token category:
  - `background/*`, `surface/*` → `["FRAME_FILL", "SHAPE_FILL"]`
  - `text/*` → `["TEXT_FILL"]`
  - `interactive/*` that are backgrounds → `["FRAME_FILL", "SHAPE_FILL"]`
  - `interactive/*` that are text colours → `["TEXT_FILL"]`
  - `interactive/focus-ring` → `["FRAME_FILL", "SHAPE_FILL", "STROKE_COLOR"]`
  - `border/*` → `["STROKE_COLOR"]`
  - `accent/*` → `["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"]`
- Infer whether a token is a fill, text, or stroke colour from its name — don't guess, read the name

---

## Phase 3 — Text Styles

Run a single `use_figma` call. Load all fonts before touching any text node.

**Font discovery:** read `typography.fontFamily` from `primitives.json` for the brand font name. Use `listAvailableFontsAsync()` to verify which weight styles are actually available under that family before calling `loadFontAsync`. Fall back to `"Inter"` if the brand font is unavailable.

Map numeric weights to Figma style strings:
`100→"Thin"`, `200→"Extra Light"`, `300→"Light"`, `400→"Regular"`, `500→"Medium"`, `600→"Semi Bold"`, `700→"Bold"`, `800→"Extra Bold"`, `900→"Black"`

**Style creation:** derive the type scale from `primitives.json → typography.fontSize`. For each size key, create styles covering the weights that appear in the components (at minimum: Regular, Medium, Semibold/Semi Bold). Name them `{Scale}/{Weight}`, e.g. `Display/Black`, `Body/Regular`, `Label/Semibold`, `Caption/Regular`. Convert rem values to px (1rem = 16px). Set line height as a pixel value derived from the size × a multiplier that decreases as size grows (display ~1.1, heading ~1.2, body ~1.5, label/caption ~1.4).

---

## Phase 4 — Token Reference frame

Switch to the `Tokens` page. Create a frame named `"Token Reference"`:
- Vertical auto-layout, 48px padding all sides, 48px gap between sections
- Fixed width (1200px), hug height: `resize(1200, 100)` → `primaryAxisSizingMode = "AUTO"` → `counterAxisSizingMode = "FIXED"`
- Background: bound to `color/background/default` via `setBoundVariableForPaint`

### No hardcoded colours — ever

Every colour in this frame must come from a variable binding. Never pass `{ r, g, b }` directly to a fill or stroke.

**Primitive swatches:** bind to the Primitive variable (e.g. `"color/lime/500"`). The variable holds the raw value; Figma resolves it.

**Semantic chips:** bind to the Design Token variable (e.g. `"color/background/default"`). This makes swatches automatically reflect whichever mode is active in Figma.

**UI chrome** (labels, chip names, frame backgrounds): bind to the nearest appropriate token — `color/text/default`, `color/text/muted`, `color/background/default`, etc.

**Variable binding helper (use everywhere):**
```js
const allVars = await figma.variables.getLocalVariablesAsync();
const V = {};
for (const v of allVars) V[v.name] = v;

function boundFill(varName) {
  // Placeholder colour is immediately overridden by the binding — it is never shown
  let fill = { type: "SOLID", color: { r: 0, g: 0, b: 0 } };
  return figma.variables.setBoundVariableForPaint(fill, "color", V[varName]);
}
```

### Section A — Primitive palettes

Iterate `primitives.json → color` and render one subsection per palette:
- Palette name label bound to `color/text/default`
- Horizontal row of swatch cells, hug both axes
- Each cell: vertical auto-layout, hug both axes
  - Colour box (80px wide, 64px tall, both axes FIXED): fill bound to the Primitive variable for that step
  - Step label text (small, Regular) below: bound to `color/text/muted`, content is the step key (e.g. `"500"`)

### Section B — Semantic token chips

Iterate `semantic.json → color` grouped by category (background, surface, text, interactive, brand, border, accent). For each group:
- Group name label (small, Semibold, uppercased): bound to `color/text/subtle`
- Wrapping chip row (`layoutWrap = "WRAP"`, horizontal auto-layout, hug both axes, 8px gaps)
- Each chip (288px wide, 36px tall, both axes FIXED, horizontal auto-layout):
  - Left swatch (24px wide, fill height): fill bound to the **Design Token** variable
  - Label (fill width, fill height): token name text bound to `color/text/default`
  - Right swatch (24px wide, fill height): same variable — this slot shows the alternate mode value when the collection mode is switched in Figma

---

## Phase 5 — Components

**Source of truth: `components/*.tsx`** — read the files, don't invent the spec.

Glob `components/*.tsx` and read every file before writing any `use_figma` code. Extract the component API from source. Do not assume which components exist or what their variants are.

### Step 5.1 — Extract component specs from source files

**Variant properties** — find exported union type aliases:
```ts
export type ButtonVariant = 'primary' | 'secondary' | 'ghost'
export type ButtonSize    = 'sm' | 'md' | 'lg'
```
Each union type becomes one Figma property. The suffix of the type name (`Variant`, `Size`, `State`) becomes the property name. Values become the options.

**Per-variant styles** — find `Record<TypeName, React.CSSProperties>` objects:
```ts
const variantStyles: Record<ButtonVariant, React.CSSProperties> = {
  primary: { background: 'var(--color-interactive-primary)', ... },
}
```
These are the source of truth for fills, strokes, text colours, padding, border-radius, and font size per variant.

**CSS var → Figma variable name:** strip `var(--` and `)`, replace `-` separators with `/`:
- `var(--color-interactive-primary)` → `color/interactive/primary` — bind via `boundFill`
- `var(--primitive-radius-full)` → not a token; resolve its px value from `primitives.json → radius`
- `var(--primitive-font-size-sm)` → not a token; resolve its px value from `primitives.json → typography.fontSize` (1rem = 16px)

**Layout values** — read directly from style objects:
- `padding: '8px 16px'` → paddingTop/Bottom = 8, paddingLeft/Right = 16
- `borderRadius: '9999px'` → cornerRadius = 9999
- `fontSize: '0.875rem'` → 14px

**Component structure** — read the JSX in the component function to understand child hierarchy and order.

### Step 5.2 — Create one Figma component set per source file

Switch to the `Components` page. **One `use_figma` call per component file.**

#### No hardcoded colours — ever

Every fill, stroke, and text colour must be bound to a Design Token variable via `boundFill`. This includes colours that appear neutral or white/black — bind to `color/background/default`, `color/text/default`, etc. Never assign `{ r, g, b }` directly to a fill or stroke on a component.

#### Sizing: hug height by default

| Frame type | Width | Height |
|---|---|---|
| Outer component frame | FIXED (from parsed value) or AUTO | **AUTO** (hug) |
| Inner layout frame | FILL or FIXED | **AUTO** (hug) |
| Text nodes | FILL | AUTO — text always hugs |
| Explicit fixed-height element (divider, icon, swatch) | FIXED or FILL | **FIXED** |

**How to set hug height:**
```js
frame.resize(targetWidth, 100);       // resize() FIRST — it resets both axes to FIXED
frame.primaryAxisSizingMode = "AUTO"; // hug in the stacking direction
frame.counterAxisSizingMode = "FIXED";// fixed in the cross direction

parent.appendChild(child);            // append FIRST
child.layoutSizingHorizontal = "FILL";// then set sizing — errors if set before append
// Note: layoutSizingVertical = "HUG" is only valid on auto-layout frames and text nodes.
// For plain frames used as children, use "FIXED" instead.
```

#### Building variant frames

For each combination of variant property values:
1. `createComponent()`, configure auto-layout direction, padding, gap, corner radius from parsed values
2. Assign `fills` / `strokes` — all via `boundFill()`, never raw RGB
3. Create child nodes in the order they appear in the source JSX
4. `parent.appendChild(child)` first, then set `layoutSizingHorizontal` / `layoutSizingVertical`
5. `resize(w, 100)` → `primaryAxisSizingMode = "AUTO"` → `counterAxisSizingMode = "FIXED"` (or both AUTO if width also hugs)

#### After `combineAsVariants`

Children always stack at (0, 0) — reposition every child manually:
- **1D set** (one property): single row, 12–16px gaps, all `y = 0`
- **2D set** (two properties): grid — one property per axis, 16px row gap, 20px col gap
- Resize the set frame: `width = maxChildRight + 48`, `height = maxChildBottom + 48`
- Stack sets on the page: each 48px below the previous, `x = 64`

---

## Phase 6 — Validate

After each phase, call `get_screenshot` on the relevant page or node. Check for:
- Overlapping / zero-size nodes (resize or appendChild ordering wrong)
- Fills that look hardcoded (any swatch showing the same colour in both modes)
- Clipped text (line-height too tight for the container)

If broken: write a targeted fix script touching only the affected nodes. Do not recreate from scratch.

---

## Absolute rules

**Colours — no exceptions:**
- Frame fills, strokes, and text fills in components and the Token Reference must use `setBoundVariableForPaint`
- The `{ r: 0, g: 0, b: 0 }` placeholder inside `boundFill` is fine — it is overridden immediately

**Layout — no exceptions:**
- `resize()` before setting `primaryAxisSizingMode` / `counterAxisSizingMode`
- `layoutSizingHorizontal` / `layoutSizingVertical` only after `parent.appendChild(child)`
- Default to hug height (`AUTO`); use `FIXED` height only when explicitly required
- `layoutSizingVertical = "HUG"` only on auto-layout frames and text nodes — use `"FIXED"` on plain frames

**IDs and names — no exceptions:**
- Never hardcode variable IDs across calls — look up by name with `getLocalVariablesAsync()`
- Never hardcode page node IDs — use `figma.root.children.find(p => p.name === "...")`
- If pages or collections already exist, delete and recreate — do not silently duplicate
