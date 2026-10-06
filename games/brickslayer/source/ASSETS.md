# Brickslayer assets: mirror of the live site + Wayback recovery

Scraped from https://javascriptgamer.com/ on 2026-10-05 (ET).
Missing gameplay sprites recovered from the Wayback Machine on 2026-10-06 (ET)
from the 2007 `javascriptgamer.com/brickslayer/` captures (Michal's own content).

## How the site was searched
- **WordPress media library.** `GET /wp-json/wp/v2/media?per_page=100` lists 7 items in total (`X-WP-Total: 7`). All are under `wp-content/uploads/2023/10/`. The audio query (`?media_type=audio`) returns `[]`.
- **Sitemaps.** `sitemap_index.xml` points to `page-sitemap.xml`. That sitemap lists the same 4 images (`1.png`–`4.png`) as `image:loc` entries.
- **Page links.** Every `href` and `src` in the home, `/brickslayer/`, `/brickslayer/trail/`, all 11 lesson pages, `/forum/`, and the `wp/v2/pages` JSON was checked.
- **Asset paths from the lesson code.** The lesson code refers to `../../sprites/*.png`, `../sprites/*.png`, `../sounds/*.mp3`, `../../soundmanager2.swf`, and `brickslayer.css`/`.js`.
  These names were requested under 16 base paths: `/`, `/brickslayer/`, `/brickslayer/trail/`, `/brickslayer/trail/NN/`, `/brickslayer/play/`, `/brickslayer/game/`, `/play/`, `/games/brickslayer/`, `/media/`, `/brickslayer/media/`, `/static/`, `/assets/`, and `/wp-content/uploads/...`.
  That was 384 URLs. Every one returned 404, except `wp-content/uploads/**`. There the host's firewall returns a 403 for any `.mp3`, `.ogg`, `.swf`, `.js`, or `.html` URL, and for any path outside `YYYY/MM/`, whether or not the file exists.
- **Thumbnails.** WordPress-generated thumbnails (`1-300x64.png` etc.) exist. They are downscaled copies of the files below, so they were not vendored.
- **Wayback Machine (2026-10-06 follow-up).** The 2007 HTML at
  `https://web.archive.org/web/20070901022944/http://javascriptgamer.com/brickslayer/`
  references `/brickslayer/sprites/{brickslayerlogo,highscores,paused,levelclear,congrats,gameover}.png`
  and CSS/JS under `/brickslayer/`. Direct `im_` fetches recovered the five gameplay sprites
  that were absent from the live WordPress rehost. Sound URLs under
  `/brickslayer/sounds/*.mp3` returned 404 / empty / Wayback HTML stubs — not vendored.

## Vendored (`source/assets/`)

### From live WordPress rehost

| File | Live URL | Original game path | Size | px | sha256 |
|---|---|---|---|---|---|
| `sprites/brickslayerlogo.png` | `/wp-content/uploads/2023/10/1.png` | `sprites/brickslayerlogo.png` (title screen) | 46751 | 346×74 | `d1439d03b44ac52ffe73bc8c068a8873bb00612d9cc916a4ff81e9fb3041536b` |
| `sprites/paused.png` | `/wp-content/uploads/2023/10/2.png` | `sprites/paused.png` (pause screen) | 41308 | 202×74 | `04964e124781599086d9ff9ef9034a5149e8c53eba2d75b7b794486816aa6b95` |
| `sprites/levelclear.png` | `/wp-content/uploads/2023/10/3.png` | `sprites/levelclear.png` (level clear) | 43081 | 362×74 | `8c8af6eea29ac4176ae011b6040855e605c8e4e815b6d7b2047f6f11c9f162fc` |
| `sprites/congrats.png` | `/wp-content/uploads/2023/10/4.png` | `sprites/congrats.png` (enter-name screen) | 52050 | 410×62 | `e16c731aec768eb76e7ab78ede1b59741f2e4fb48f00ebd3d142a4591a0f4bc0` |
| `site/logo.png` | `/wp-content/uploads/2023/10/logo.png` | (site header, "Javascript Gamer") | 65329 | 364×69 | `34862004af49187dd4a30b2f9448774339caf8031dd9c4ade3168132400c1abc` |
| `site/favicon.png` | `/wp-content/uploads/2023/10/favicon.png` | (site icon) | 13760 | 512×512 | `5dfdba3c740ccc5a2182ad74361d8d405589bcd93ef465d79960df7ea8b3721d` |
| `site/cropped-favicon.png` | `/wp-content/uploads/2023/10/cropped-favicon.png` | (site icon) | 12566 | 512×512 | `7e2a4b85137950d1576c111f57486e82f71d8b722f27b3bae20dca7181ba55fe` |

The logo/paused/levelclear/congrats sprite files were renamed from `1.png`–`4.png` to the names the 2007 HTML uses. The match was made by reading the images.
`site/` holds a `.gdignore`, so Godot doesn't import those files or export them.

### From Wayback (2007 brickslayer captures)

| File | Wayback URL (example) | Original game path | Size | px | sha256 |
|---|---|---|---|---|---|
| `sprites/paddle.png` | `…/20070901022944im_/…/brickslayer/sprites/paddle.png` | `sprites/paddle.png` | 375 | 64×16 | `813659eac5e4c0f68525d053af3f4d93e9b631066c01b535b3027a40a94cda14` |
| `sprites/ball.png` | `…/20070901022944im_/…/brickslayer/sprites/ball.png` | `sprites/ball.png` | 366 | 16×16 | `f470eba99962fb0ef63e889b478421d11bea33c6e28a3d37b9fd89338d90d765` |
| `sprites/dimgray.png` | `…/20071011063803im_/…/brickslayer/sprites/dimgray.png` | `sprites/dimgray.png` (`.overlay` bg) | 220 | 64×64 | `ecf580e87107e2021a0e64ae59061fd82b3b937d990b70b182d9114e01bc58c3` |
| `sprites/gameover.png` | `…/20070901022944im_/…/brickslayer/sprites/gameover.png` | `sprites/gameover.png` | 44347 | 300×79 | `60658f92361416b9e405390ff60a19150a3cca367614982a0bbbf869c9a5b28b` |
| `sprites/highscores.png` | `…/20090120190635im_/…/brickslayer/sprites/highscores.png` | `sprites/highscores.png` | 40795 | 326×74 | `6d44ab0acfb66b92514ec3dd1c9fbc6759f26d3308f6c08bad7dcbf798aa03fb` |

`direct/game.gd` loads these when present (paddle/ball draw, dimgray tiled overlay, gameover/highscores titles).

## Still missing (not on live site or Wayback as recoverable binaries)

| Path in lesson code | Used for | What the port does |
|---|---|---|
| `../sounds/whish.mp3` `plopp.mp3` `glass2.mp3` `boing.mp3` `deepsplosh.mp3` | serve / hit / break / bounce / fall | silent. `direct/game.gd` loads each from `source/assets/sounds/` if the file is ever vendored |
| `../../soundmanager2.swf`, `soundmanager2.js` | Flash audio bridge | not needed (Godot audio) |
| `prototype-1.5.1.js`, `gameconsole.js`, `brickslayer.js`, `brickslayer.css` | runtime | rebuilt from the lesson listings in `source/lesson-code/` |

URLs checked for the mp3s (all failed: 404, empty body, or Wayback HTML stub):
- `https://javascriptgamer.com/brickslayer/sounds/{whish,plopp,glass2,boing,deepsplosh}.mp3`
- `https://javascriptgamer.com/brickslayer/trail/sounds/whish.mp3`
- `https://javascriptgamer.com/wp-content/uploads/2023/10/whish.mp3` (403 firewall)
- `https://web.archive.org/web/20070901022944im_/http://javascriptgamer.com/brickslayer/sounds/*.mp3`
- `https://web.archive.org/web/20070901022944oe_/http://javascriptgamer.com/brickslayer/sounds/whish.mp3`
- GitHub code search for the filenames (`deepsplosh`, `whish.mp3`, etc.): no hits
- Lesson 07 "where to get sounds" is plain bold text on the rehost (no outbound link)

The bricks and the lake were never images. They are CSS-colored `div`s (`#bricks .shadeN`, `#lake`), and the port draws them from those exact colors.
