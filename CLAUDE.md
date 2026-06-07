# Workshop: Claude × Figma Design System

## Goal

Extract design tokens from a live webpage, build a structured token system with proper naming and modes (light/dark), generate React components, preview them locally, and publish to Figma via MCP.

## Workflow

1. **Extract** — scrape a URL for raw color, spacing, and typography values
2. **Structure** — apply token naming conventions and define light/dark modes
3. **Preview** — render components in the Vite gallery (`/preview`)
4. **Publish** — push tokens and components to Figma canvas via MCP
## Figma files

Source (read): https://www.figma.com/design/lveo4BahYddeYgjfnlxZ3X/Linear-Design-System--Community-
Destination (write): https://www.figma.com/design/gsgS0WXliIwOOEfR3WOSii/Q-%E2%80%94-Priority-Under-Pressure-%C2%B7-Design-System?node-id=0-1&t=kZd7qE9E4kVUIl6n-1

## Commands

| Command                | What it does                                                      |
| ---------------------- | ----------------------------------------------------------------- |
| `/extract-tokens`      | Scrape a URL and output raw design tokens to `tokens/raw.json`    |
| `/build-token-system`  | Convert raw tokens into a structured system with naming and modes |
| `/generate-components` | Scaffold React components from the token system                   |
| `/push-to-figma`       | Publish tokens and components to the connected Figma file         |

## Stack

- **Preview**: Vite + React (no Storybook — keep it lean)
- **Tokens**: JSON → CSS custom properties
- **Figma**: Figma MCP server (`plugin:figma:figma`)

## Token Naming Convention

See `docs/token-conventions.md` — to be filled in after token extraction.

## Figma File

<!-- Add your Figma file URL here once connected -->

## Notes

<!-- Running decisions, gotchas, URLs go here -->
