#!/usr/bin/env bash
# .claude/scripts/extract-tokens.sh <url> [additional-url ...]
# Fetches raw HTML + CSS bundles and outputs structured design token data.
# Run via: bash .claude/scripts/extract-tokens.sh https://example.com/

URL="${1:?Usage: $0 <url>}"
ORIGIN=$(printf '%s' "$URL" | grep -oE 'https?://[^/]+')
HTML=/tmp/et_site.html

# ── Download ───────────────────────────────────────────────────────────────────
curl -sL "$URL" -o "$HTML"

echo "=== SITE ==="
echo "url: $URL"
echo "size: $(wc -c < "$HTML") bytes"
if grep -q '_astro/' "$HTML" 2>/dev/null; then
  echo "framework: astro"
elif grep -q '_next/static' "$HTML" 2>/dev/null; then
  echo "framework: nextjs"
else
  echo "framework: unknown"
fi

# ── CSS bundle URLs ────────────────────────────────────────────────────────────
echo ""
echo "=== CSS_BUNDLES ==="
CSS_URLS=$(grep -oE 'href="[^"]*\.css[^"]*"' "$HTML" 2>/dev/null \
  | grep -v 'fonts\.google' \
  | sed 's/href="//;s/"//' \
  | while IFS= read -r p; do
      [[ "$p" == http* ]] && echo "$p" || echo "${ORIGIN}${p}"
    done)
[ -n "$CSS_URLS" ] && echo "$CSS_URLS" || echo "none"

# ── Interactive element classes ────────────────────────────────────────────────
echo ""
echo "=== BG_CLASSES_ON_BUTTONS_AND_ANCHORS ==="
grep -oE '<(a|button)[^>]+>' "$HTML" 2>/dev/null \
  | grep -oE 'class="[^"]*"' | tr ' ' '\n' | grep '^bg-' | sort -u || echo "none"

echo ""
echo "=== TEXT_CLASSES_ON_BUTTONS_AND_ANCHORS ==="
grep -oE '<(a|button)[^>]+>' "$HTML" 2>/dev/null \
  | grep -oE 'class="[^"]*"' | tr ' ' '\n' | grep '^text-' | sort -u || echo "none"

echo ""
echo "=== FULL_CTA_TAGS ==="
grep -oE '<a[^>]+>' "$HTML" 2>/dev/null \
  | grep 'bg-' | grep -v 'bg-transparent\|bg-white\|bg-black' | head -5 || echo "none"

# ── CSS vars from inline <style> tags ─────────────────────────────────────────
echo ""
echo "=== CSS_VARS ==="
grep -oE '--[a-z][a-z-]*:[^;<>"]+' "$HTML" 2>/dev/null | sort -u | head -20 || echo "none"

# ── Google Fonts ───────────────────────────────────────────────────────────────
echo ""
echo "=== GOOGLE_FONTS ==="
grep -oE 'https://fonts\.googleapis\.com/css2[^"& ]+' "$HTML" 2>/dev/null | head -3 || echo "none"

# ── Custom colors from CSS bundles ────────────────────────────────────────────
echo ""
echo "=== CSS_BUNDLE_CUSTOM_COLORS ==="
if [ -n "$CSS_URLS" ]; then
  while IFS= read -r css_url; do
    [ -z "$css_url" ] && continue
    echo "# $css_url"
    curl -sL --compressed "$css_url" 2>/dev/null \
      | grep -oE '\.[a-z][a-z0-9-]*[^{]*\{[^}]*(background-color|color):[^}]+\}' \
      | grep -vE '(slate|gray|zinc|neutral|stone)[-/][0-9]|\.bg-white[{ /]|\.bg-black[{ /]|\.text-white[{ /]|\.text-black[{ /]|bg-transparent|text-current|text-inherit' \
      | sort -u
  done <<< "$CSS_URLS"
else
  echo "no CSS bundles found"
fi
