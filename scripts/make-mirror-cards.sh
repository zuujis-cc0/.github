#!/usr/bin/env bash
# Card pictures (800x450) for the mirrors part of the profile README, drawn from the previews the mirror
# repositories already hold (copies of the sources' own CC0 previews).
# Usage: scripts/make-mirror-cards.sh NAME REPO[:N] REPO[:N] ...
#   Takes the Nth preview (default 1) of each repository, eight in all, and writes profile/images/NAME.webp.
#   Example: scripts/make-mirror-cards.sh polyhaven polyhaven-models-furniture:2 polyhaven-textures-stone-5 ...
# FONT may point to a .ttf (montage needs one). Needs ImageMagick 7 (magick), gh (signed in, or GH_TOKEN) and curl. bash 3.2 or later.
set -euo pipefail
ORG=${MIRROR_ORG:-zuujis-cc0}
NAME=${1:?usage: scripts/make-mirror-cards.sh NAME REPO[:N] ...}; shift
O=$(cd "$(dirname "$0")/.." && pwd)/profile/images
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
i=0
for spec in "$@"; do
  repo=${spec%%:*}; n=1; [ "$spec" != "$repo" ] && n=${spec##*:}
  file=$(gh api "repos/$ORG/$repo/contents/previews" --jq ".[$((n - 1))].name")
  curl -sfL --retry 4 --retry-all-errors "https://raw.githubusercontent.com/$ORG/$repo/main/previews/$file" -o "$T/src$i"
  magick "$T/src$i" -resize 172x172 -background white -gravity center -extent 180x180 \
    \( +clone -alpha extract -fill black -colorize 100 -fill white -draw 'roundrectangle 0,0,179,179,14,14' \) \
    -alpha off -compose CopyOpacity -composite "$T/t$i.png"
  i=$((i + 1))
done
magick montage -font "${FONT:-/Users/user/RustWebsites/games.zuujis.com/assets/fonts/InstrumentSans-Bold.ttf}" "$T"/t*.png -tile 4x2 -geometry 180x180+8+8 -background none "$T/grid.png"
magick -size 800x450 radial-gradient:'#2b2f45'-'#14161f' "$T/grid.png" -gravity center -composite \
  -strip -quality 82 "$O/$NAME.webp"
echo "$O/$NAME.webp"
