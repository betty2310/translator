#!/bin/sh
# Builds the app icon and the footer mascot from design/mascot.png (D38).
# Needs ImageMagick 7 (`brew install imagemagick`). Run from the repo root.
set -eu

src=design/mascot.png
assets=Translator/Resources/Assets.xcassets
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# macOS icon grid: an 824 pt rounded square centered on a 1024 canvas.
magick -size 824x824 gradient:'#8EC5FF-#3B5BDB' -alpha set \
  \( -size 824x824 xc:none -fill white -draw 'roundrectangle 0,0 823,823 185,185' \) \
  -compose DstIn -composite \
  -fill none -stroke 'rgba(255,255,255,0.35)' -strokewidth 4 \
  -draw 'roundrectangle 2,2 821,821 183,183' "$tmp/tile.png"

magick "$src" -resize 740x "$tmp/cat.png"
magick "$tmp/cat.png" \( +clone -background 'rgba(10,20,80,0.35)' -shadow 100x10+0+12 \) \
  +swap -background none -layers merge +repage "$tmp/cat-shadow.png"

magick -size 1024x1024 xc:none \
  \( "$tmp/tile.png" \( +clone -background 'rgba(0,0,0,0.3)' -shadow 100x12+0+10 \) \
     +swap -background none -layers merge +repage \) -gravity center -composite \
  "$tmp/cat-shadow.png" -gravity center -geometry +0+24 -composite \
  "$tmp/icon.png"

for s in 16 32 128 256 512; do
  magick "$tmp/icon.png" -resize ${s}x${s} "$assets/AppIcon.appiconset/icon_${s}x${s}@1x.png"
  magick "$tmp/icon.png" -resize $((s * 2))x$((s * 2)) "$assets/AppIcon.appiconset/icon_${s}x${s}@2x.png"
done

# Footer mascot: no background, 18 pt tall. The outlines are thickened first,
# or they shrink to faint 1 px lines at that size.
magick "$src" -channel RGB -morphology Erode Disk:7 +channel -resize x108 \
  "$assets/Mascot.imageset/mascot.png"
