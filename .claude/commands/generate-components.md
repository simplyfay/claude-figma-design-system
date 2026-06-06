Generate React components from the token system and add them to the Vite preview gallery.

Reads from: `tokens/system/semantic.json`, `tokens/system/tokens.css`
Writes to: `components/` and `preview/`

## Steps

### 1 — Read tokens
Read `tokens/system/semantic.json` to understand available roles, and `tokens/system/tokens.css` to confirm CSS var names and resolved hex values for both modes.

### 2 — Scaffold `preview/` (skip files that already exist)

| File | Notes |
|------|-------|
| `preview/package.json` | deps: `react`, `react-dom`; devDeps: `vite`, `@vitejs/plugin-react`, `@types/react`, `@types/react-dom`, `typescript` |
| `preview/vite.config.ts` | `defineConfig({ plugins: [react()] })` |
| `preview/tsconfig.json` | See tsconfig note below |
| `preview/index.html` | Load the project's font via `<link>`; mount `<div id="root">`; `<script type="module" src="/main.tsx">` |
| `preview/main.tsx` | `import '../tokens/system/tokens.css'` then render `<Gallery />` |
| `preview/Gallery.tsx` | See Gallery spec below |

**tsconfig note** — `components/` lives outside `preview/`, so TypeScript can't find React types via normal node_modules traversal. Add `baseUrl` and `paths` to fix it:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "baseUrl": ".",
    "paths": {
      "react": ["./node_modules/@types/react"],
      "react-dom": ["./node_modules/@types/react-dom"],
      "react/jsx-runtime": ["./node_modules/@types/react/jsx-runtime"]
    }
  },
  "include": [".", "../components"]
}
```

After creating all files, run `npm install` from `preview/`.

### 3 — Generate components
Infer a base set from the token system (Button, Badge, Card, Input, Text) unless the user specifies others.

For each component:
- Create `components/<Name>.tsx`
- Use only `var(--token-name)` CSS custom properties — no hardcoded colors or sizes
- Check contrast before writing (see Accessibility below)
- Export default component + named `<Name>Preview` export

### 4 — Gallery
`Gallery.tsx` must include, in order:
1. **Primitives section** — color swatches for each palette (48×48 divs, `background: var(--primitive-color-*)`)
2. **Semantic tokens section** — chips per group (Background / Text / Interactive) showing swatch + token name; they must visually flip when the mode toggles because they use `var(--color-*)` directly
3. **One section per component** — renders `<NamePreview />` showing all variants

The sticky header contains the theme toggle. Clicking it sets `data-theme="dark"` or `data-theme="light"` on `document.documentElement`.

---

## Component conventions

- Functional components, TypeScript, inline `style` prop
- No external UI library — token vars only
- Cast CSS vars where TypeScript expects a specific type: `'var(--font-weight-bold)' as React.CSSProperties['fontWeight']`
- Hover state: `useState` + `onMouseEnter`/`onMouseLeave`
- Focus state: `useState` + `onFocus`/`onBlur`; set `outline: none` on the element and render an equivalent visible ring via `box-shadow` or `outline` on a wrapper

---

## Accessibility

Apply before writing each component. Dark mode needs special attention because the reduced luminance range compresses contrast headroom.

### Contrast minimums (WCAG 2.1 AA)
- Normal text (< 18px regular / < 14px bold): **4.5:1**
- Large text (≥ 18px regular / ≥ 14px bold): **3:1**
- UI components and focus indicators: **3:1**

### How to check
Look up the resolved hex values for both the text token and its background token in `tokens.css`. Compute relative luminance and contrast ratio before deciding which token to use. Do not infer lightness from a token name alone — `text-on-brand` in dark mode may resolve to a dark value if the token was never updated for the dark theme.

**If contrast fails on a named-surface text token** (e.g. `text-on-X` where `X` resolves dark in dark mode): fix the token in `semantic.json` + `tokens.css` — choose a palette step with opposite lightness to the background. Don't work around it in the component.

**If contrast fails on an interactive surface** (e.g. a button whose dark-mode background is a medium-luminance step): fall back to `--color-text-default` for that element's text and add a comment explaining why.

### Always
- Error states: pair color with an icon or text — never color alone.
- Disabled elements: exempt from contrast requirements but must look visually distinct from enabled.
- Never suppress `outline` without providing an equivalent visible focus indicator.
- Focus ring glow: `box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-focus-ring-default) 30%, transparent)` — verify the solid ring itself meets 3:1 against the page background in both modes.
