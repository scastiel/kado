#!/usr/bin/env bash
#
# Refreshes the marketing site's screenshots from the App Store captures.
#
#   Scripts/site-screenshots.sh
#
# getkado.app ships the same pictures the listing does, but unframed — the site draws its own
# device bezels in CSS, so they follow the page's light and dark mode and stay sharp at any
# size. Resizing them out of docs/app-store/screenshots/ rather than keeping a second set by
# hand is what stops the site and the listing drifting apart — which they had, quietly, for
# several releases.
#
# Each device is resized to a fixed width, roughly twice the widest it is drawn on the page,
# keeping its aspect: the captures are 3x (2x on the iPad) and three times wider than any
# browser shows them, which is megabytes the page would download for nothing.
#
# Run by `make screenshots` and `make frames`. Pushing the result redeploys the site: the Pages
# workflow watches this exact folder.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CONFIG="docs/app-store/config.json"
CAPTURES="docs/app-store/screenshots"
SITE="docs/screenshots/site"

# capture folder : site folder : width in pixels
DEVICES=(
  "iphone-6.9:iphone:660"
  "iphone-duo:iphone-duo:700"
  "ipad-13:ipad:1290"
)

config() {
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))
for key in sys.argv[2:]: d = d[key]
print(d)' "$CONFIG" "$@"
}

written=0
for entry in "${DEVICES[@]}"; do
  IFS=: read -r capture device width <<< "$entry"
  for language in en fr; do
    locale="$(config languages "$language" locale)"
    source_dir="$CAPTURES/$locale/$capture"
    if [[ ! -d "$source_dir" ]]; then
      echo "no captures in $source_dir — run make screenshots first" >&2
      exit 1
    fi

    out="$SITE/$device/$language"
    rm -rf "${out:?}"
    mkdir -p "$out"
    for shot in "$source_dir"/*.png; do
      sips --resampleWidth "$width" "$shot" --out "$out/$(basename "$shot")" > /dev/null
      written=$((written + 1))
    done
    echo "  $out  ${width}px wide  $(ls "$out" | wc -l | tr -d ' ') files"
  done
done

# The link preview (og:image): the listing's 16:9 creative, at the 1200px width link previews
# are drawn at. A tall phone screenshot there gets cropped to a strip of status bar.
mkdir -p "$SITE/social"
for language in en fr; do
  locale="$(config languages "$language" locale)"
  creative="docs/app-store/marketing/$locale/creative/universal.png"
  if [[ -f "$creative" ]]; then
    sips --resampleWidth 1200 "$creative" --out "$SITE/social/$language.png" > /dev/null
    written=$((written + 1))
  fi
done
echo "  $SITE/social  1200px wide  $(ls "$SITE/social" | wc -l | tr -d ' ') files"

if [[ $written -eq 0 ]]; then
  echo "there was nothing to resize" >&2
  exit 1
fi
