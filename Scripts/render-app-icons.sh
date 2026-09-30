#!/bin/bash
# Renders the alternate app icons from their SVG masters in
# branding/app-icons/ into Kado/Resources/Assets.xcassets:
#
#   AppIcon<Name>.appiconset   Light, Dark and Tinted 1024 masters
#   AppIconPreviews/…imageset  60pt @3x Light / Dark, for the picker
#
# The masters come from the Claude Design canvas linked in #114. The
# default icon's Light and Dark PNGs are the shipped ones and are not
# re-rendered; it only gains the shared Tinted master and a preview.
#
# App Store icons must be opaque, so every PNG is flattened to RGB.
# Needs rsvg-convert and ImageMagick (brew install librsvg imagemagick).
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=branding/app-icons
ASSETS=Kado/Resources/Assets.xcassets
PREVIEWS=$ASSETS/AppIconPreviews
ALTERNATES=(Ura Sakura Momiji Yuyake Umi Hotaru Fuji)

render() { # svg, size, out
    rsvg-convert -w "$2" -h "$2" "$1" \
        | magick - -background black -alpha remove -alpha off -type TrueColor "PNG24:$3"
}

appiconset_json() { # base name
    cat <<EOF
{
  "images" : [
    {
      "filename" : "$1.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "$1-Dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "$1-Tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
}

imageset_json() { # base name
    cat <<EOF
{
  "images" : [
    {
      "filename" : "$1.png",
      "idiom" : "universal",
      "scale" : "3x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "$1-Dark.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
}

group_json() {
    cat <<EOF
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
}

mkdir -p "$PREVIEWS"
group_json > "$PREVIEWS/Contents.json"

# The default icon: shared Tinted master, plus its picker preview.
render "$SRC/AppIcon-Tinted.svg" 1024 "$ASSETS/AppIcon.appiconset/AppIcon-Tinted.png"
appiconset_json AppIcon > "$ASSETS/AppIcon.appiconset/Contents.json"
set_dir="$PREVIEWS/AppIconPreviewKado.imageset"
mkdir -p "$set_dir"
render "$SRC/AppIconKado.svg" 180 "$set_dir/AppIconPreviewKado.png"
render "$SRC/AppIconKado-Dark.svg" 180 "$set_dir/AppIconPreviewKado-Dark.png"
imageset_json AppIconPreviewKado > "$set_dir/Contents.json"

for name in "${ALTERNATES[@]}"; do
    base="AppIcon$name"
    set_dir="$ASSETS/$base.appiconset"
    mkdir -p "$set_dir"
    render "$SRC/$base.svg" 1024 "$set_dir/$base.png"
    render "$SRC/$base-Dark.svg" 1024 "$set_dir/$base-Dark.png"
    render "$SRC/AppIcon-Tinted.svg" 1024 "$set_dir/$base-Tinted.png"
    appiconset_json "$base" > "$set_dir/Contents.json"

    preview="AppIconPreview$name"
    set_dir="$PREVIEWS/$preview.imageset"
    mkdir -p "$set_dir"
    render "$SRC/$base.svg" 180 "$set_dir/$preview.png"
    render "$SRC/$base-Dark.svg" 180 "$set_dir/$preview-Dark.png"
    imageset_json "$preview" > "$set_dir/Contents.json"
done

echo "Rendered ${#ALTERNATES[@]} alternates and $(( ${#ALTERNATES[@]} + 1 )) previews."
