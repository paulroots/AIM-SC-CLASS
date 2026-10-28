#!/usr/bin/env bash
# Instructor only. Refreshes the vendored Lumen design system files in web/shared/lumen/
# from the private byc-product/lumen-design-system repo. Requires `gh auth login`.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

REPO="byc-product/lumen-design-system"
DEST="web/shared/lumen"
mkdir -p "$DEST"

fetch() {
  gh api "repos/$REPO/contents/$1" --jq '.content' | base64 -d > "$DEST/$2"
  ok "$2"
}

fetch system/tokens.css tokens.css
fetch system/byc.css byc.css
fetch VERSION VERSION
fetch brands/assets/logos/lumen-full-black.png lumen-full-black.png
fetch brands/assets/logos/lumen-full-white.png lumen-full-white.png

echo "Lumen design system $(cat "$DEST/VERSION") vendored into $DEST"
