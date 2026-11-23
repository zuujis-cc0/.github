#!/usr/bin/env bash
# Card pictures (800x450) for the zuujis-cc0 profile README, drawn from the packs' own files.
# Usage: scripts/make-cards.sh WORK
#   WORK holds fga/ (a clone of zuujis-cc0/free-game-assets) and packrepos/<name>/ (clones of the
#   free-game-assets-* pack repositories and zuujis-game-scripts). Writes profile/images/*.webp here.
# Needs ImageMagick 7 (magick) and bash 3.2 or later. FONT may point to another .ttf.
set -euo pipefail
S=${1:?usage: scripts/make-cards.sh WORK (folder with fga/ and packrepos/)}
S=$(cd "$S" && pwd)
R=$S/packrepos
P=$S/fga/previews
O=$(cd "$(dirname "$0")/.." && pwd)/profile/images
FONT=${FONT:-/Users/user/RustWebsites/games.zuujis.com/assets/fonts/InstrumentSans-Bold.ttf}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
BG=(-size 800x450 radial-gradient:'#2b2f45'-'#14161f')
fin() { magick "$1" -strip -quality 82 "$O/$2.webp"; }

# Aircraft: the four renders of the hub's hero picture, two by two.
for i in 0 1 2 3; do magick "$S/fga/preview-aircraft.png" -crop "360x270+$((i * 360))+0" +repage -fuzz 6% -trim +repage -resize 330x170 "$T/a$i.png"; done
magick montage -font "$FONT" "$T"/a0.png "$T"/a1.png "$T"/a2.png "$T"/a3.png -tile 2x2 -geometry 360x200+10+6 -background none "$T/planes.png"
magick "${BG[@]}" "$T/planes.png" -gravity center -composite "$T/aircraft.png"; fin "$T/aircraft.png" aircraft

# From the Ground Up: a row of buildings.
cd "$R/free-game-assets-from-the-ground-up/sprites/buildings"
b=(); while IFS= read -r l; do b+=("$l"); done < <(ls | grep -- '-3\.webp$' | awk 'NR%5==2' | head -8)
magick montage -font "$FONT" "${b[@]}" -tile 4x2 -geometry 190x200+4+4 -background none "$T/b.png"
magick "${BG[@]}" "$T/b.png" -gravity center -composite "$T/ftgu.png"; fin "$T/ftgu.png" from-the-ground-up

# Backgrounds: one composited scene, full width.
magick "$P/backgrounds/scenes/forest-dusk.webp" -resize 800x450^ -gravity center -extent 800x450 "$T/bg.png"; fin "$T/bg.png" backgrounds

# Icons: 24 icons in a grid.
cd "$R/free-game-assets-icons"
ic=(); while IFS= read -r l; do ic+=("$l"); done < <(git ls-files '*.png' | grep -v / | grep -v atlas | awk 'NR%5==1' | head -24)
magick montage -font "$FONT" "${ic[@]}" -tile 8x3 -geometry 84x84+8+16 -background none "$T/ic.png"
magick "${BG[@]}" "$T/ic.png" -gravity center -composite "$T/icons.png"; fin "$T/icons.png" icons

# Effects: one frame from each of 12 effects, scaled up crisp.
cd "$R/free-game-assets-effects"
fx=(); while IFS= read -r l; do fx+=("$l"); done < <(git ls-files '*spritesheet.png' | awk 'NR%4==1' | head -12)
args=()
i=0
for f in "${fx[@]}"; do
  h=$(magick identify -format '%h' "$f"); w=$(magick identify -format '%w' "$f")
  n=$(( w / h )); [ $n -lt 1 ] && n=1
  magick "$f" -crop "${h}x${h}+$(( (n / 2) * h ))+0" +repage -filter point -resize 110x110 "$T/fx$i.png"; args+=("$T/fx$i.png"); i=$((i+1))
done
magick montage -font "$FONT" "${args[@]}" -tile 6x2 -geometry 110x110+10+20 -background none "$T/fx.png"
magick "${BG[@]}" "$T/fx.png" -gravity center -composite "$T/effects.png"; fin "$T/effects.png" effects

# Covenant Hall: the hall growing, four levels.
cd "$R/free-game-assets-covenant-hall/Sprites"
ch=(); while IFS= read -r l; do ch+=("$l"); done < <(ls | sort -V | awk 'NR==1||NR==10||NR==20||NR==30')
magick montage -font "$FONT" "${ch[@]}" -tile 4x1 -geometry 196x260+2+2 -background none "$T/ch.png"
magick "${BG[@]}" "$T/ch.png" -gravity center -composite "$T/ch2.png"; fin "$T/ch2.png" covenant-hall

# Tarot: five cards side by side.
cd "$R/free-game-assets-tarot/RWS Deck/Low Res"
tc=(); while IFS= read -r l; do tc+=("$l"); done < <(ls major_00_fool.jpg major_01_magician.jpg major_10_wheel_of_fortune.jpg major_17_star.jpg major_19_sun.jpg)
magick montage -font "$FONT" "${tc[@]}" -tile 5x1 -geometry 140x240+8+8 -background none "$T/tc.png"
magick "${BG[@]}" "$T/tc.png" -gravity center -composite "$T/tarot.png"; fin "$T/tarot.png" tarot

# Game scripts: the starters sheet.
magick "$P/game-scripts/starters.webp" -resize 800x450^ -gravity center -extent 800x450 "$T/gs.png"; fin "$T/gs.png" game-scripts

# Banner: all eight, 4x2.
cd "$O"
magick montage -font "$FONT" aircraft.webp from-the-ground-up.webp backgrounds.webp icons.webp effects.webp covenant-hall.webp tarot.webp game-scripts.webp \
  -tile 4x2 -geometry 400x225+3+3 -background '#0d1117' -strip -quality 80 banner.webp
