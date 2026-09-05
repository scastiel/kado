#!/usr/bin/env bash
#
# Refreshes the marketing site's screenshots from the App Store captures.
#
#   Scripts/site-screenshots.sh
#
# getkado.app ships the same pictures the listing does, but unframed and at the canvas its CSS
# was written against. Resizing them out of docs/app-store/screenshots/ rather than keeping a
# second set by hand is what stops the site and the listing drifting apart — which they had,
# quietly, for several releases.
#
# Run by `make screenshots` and `make frames`. Pushing the result redeploys the site: the Pages
# workflow watches this exact folder.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CONFIG="docs/app-store/config.json"
CAPTURES="docs/app-store/screenshots"
SITE="docs/screenshots/iphone-67-appstore"
# Not the capture's own 1320x2868. The site's layout was built against the older 6.7" canvas,
# and both are the same 19.5:9 aspect, so this is a clean downscale with nothing cropped.
WIDTH=1284
HEIGHT=2778

config() {
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))
for key in sys.argv[2:]: d = d[key]
print(d)' "$CONFIG" "$@"
}

written=0
for language in en fr; do
  locale="$(config languages "$language" locale)"
  source_dir="$CAPTURES/$locale/iphone-6.9"
  if [[ ! -d "$source_dir" ]]; then
    echo "no captures in $source_dir — run make screenshots first" >&2
    exit 1
  fi

  rm -rf "${SITE:?}/$language"
  mkdir -p "$SITE/$language"
  for shot in "$source_dir"/*.png; do
    # `-z height width`, in that order, which is the one thing about sips nobody remembers.
    sips -z "$HEIGHT" "$WIDTH" "$shot" --out "$SITE/$language/$(basename "$shot")" > /dev/null
    written=$((written + 1))
  done
  echo "  $SITE/$language  ${WIDTH}x${HEIGHT}  $(ls "$SITE/$language" | wc -l | tr -d ' ') files"
done

if [[ $written -eq 0 ]]; then
  echo "there was nothing to resize" >&2
  exit 1
fi
