#!/usr/bin/env bash
# Regenerate games/kiwi_soccer/direct/{img,sfx,freesansbold.ttf} from a sabren/blaze checkout.
# Usage: tools/convert_assets.sh /path/to/blaze   (needs ffmpeg, pyftsubset, pygame's font)
set -euo pipefail
S="${1:?blaze checkout}/pyweek"
D="$(cd "$(dirname "$0")/.." && pwd)/direct"
mkdir -p "$D/img" "$D/sfx"
cp "$S"/menu_img.png "$S"/help.png "$S"/credits.png "$S"/high_scores.png "$D/img/"
cp "$S"/data/game.png "$S"/data/statustxt.png "$S"/rooms/outside-back.png "$D/img/"
cp "$S"/data/kiwi/left.png "$D/img/kiwi_left.png"
cp "$S"/data/kiwi/right.png "$D/img/kiwi_right.png"
cp "$S"/data/sounds/bip.ogg "$D/sfx/"
ffmpeg -v error -y -i "$S"/data/music/1takeimprov.ogg -ac 1 -ar 22050 -c:a libvorbis -q:a 1 "$D/sfx/1takeimprov.ogg"
FONT="${PYGAME_FONT:-$(python3 -c 'import pygame,os;print(os.path.join(os.path.dirname(pygame.__file__),"freesansbold.ttf"))')}"
pyftsubset "$FONT" --unicodes="U+0020-007E" --output-file="$D/freesansbold.ttf"
