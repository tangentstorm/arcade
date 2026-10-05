# Brickslayer assets: mirror of the live site

Scraped from https://javascriptgamer.com/ on 2026-10-05 (ET).

## How the site was searched
- **WordPress media library.** `GET /wp-json/wp/v2/media?per_page=100` lists 7 items in total (`X-WP-Total: 7`). All are under `wp-content/uploads/2023/10/`. The audio query (`?media_type=audio`) returns `[]`.
- **Sitemaps.** `sitemap_index.xml` points to `page-sitemap.xml`. That sitemap lists the same 4 images (`1.png`–`4.png`) as `image:loc` entries.
- **Page links.** Every `href` and `src` in the home, `/brickslayer/`, `/brickslayer/trail/`, all 11 lesson pages, `/forum/`, and the `wp/v2/pages` JSON was checked.
- **Asset paths from the lesson code.** The lesson code refers to `../../sprites/*.png`, `../sprites/*.png`, `../sounds/*.mp3`, `../../soundmanager2.swf`, and `brickslayer.css`/`.js`.
  These names were requested under 16 base paths: `/`, `/brickslayer/`, `/brickslayer/trail/`, `/brickslayer/trail/NN/`, `/brickslayer/play/`, `/brickslayer/game/`, `/play/`, `/games/brickslayer/`, `/media/`, `/brickslayer/media/`, `/static/`, `/assets/`, and `/wp-content/uploads/...`.
  That was 384 URLs. Every one returned 404, except `wp-content/uploads/**`. There the host's firewall returns a 403 for any `.mp3`, `.ogg`, `.swf`, `.js`, or `.html` URL, and for any path outside `YYYY/MM/`, whether or not the file exists.
- **Thumbnails.** WordPress-generated thumbnails (`1-300x64.png` etc.) exist. They are downscaled copies of the files below, so they were not vendored.

## Vendored (`source/assets/`)

| File | Live URL | Original game path | Size | px | sha256 |
|---|---|---|---|---|---|
| `sprites/brickslayerlogo.png` | `/wp-content/uploads/2023/10/1.png` | `sprites/brickslayerlogo.png` (title screen) | 46751 | 346×74 | `d1439d03b44ac52ffe73bc8c068a8873bb00612d9cc916a4ff81e9fb3041536b` |
| `sprites/paused.png` | `/wp-content/uploads/2023/10/2.png` | `sprites/paused.png` (pause screen) | 41308 | 202×74 | `04964e124781599086d9ff9ef9034a5149e8c53eba2d75b7b794486816aa6b95` |
| `sprites/levelclear.png` | `/wp-content/uploads/2023/10/3.png` | `sprites/levelclear.png` (level clear) | 43081 | 362×74 | `8c8af6eea29ac4176ae011b6040855e605c8e4e815b6d7b2047f6f11c9f162fc` |
| `sprites/congrats.png` | `/wp-content/uploads/2023/10/4.png` | `sprites/congrats.png` (enter-name screen) | 52050 | 410×62 | `e16c731aec768eb76e7ab78ede1b59741f2e4fb48f00ebd3d142a4591a0f4bc0` |
| `site/logo.png` | `/wp-content/uploads/2023/10/logo.png` | (site header, "Javascript Gamer") | 65329 | 364×69 | `34862004af49187dd4a30b2f9448774339caf8031dd9c4ade3168132400c1abc` |
| `site/favicon.png` | `/wp-content/uploads/2023/10/favicon.png` | (site icon) | 13760 | 512×512 | `5dfdba3c740ccc5a2182ad74361d8d405589bcd93ef465d79960df7ea8b3721d` |
| `site/cropped-favicon.png` | `/wp-content/uploads/2023/10/cropped-favicon.png` | (site icon) | 12566 | 512×512 | `7e2a4b85137950d1576c111f57486e82f71d8b722f27b3bae20dca7181ba55fe` |

The sprite files were renamed from `1.png`–`4.png` to the names the 2007 HTML uses. The match was made by reading the images.
`site/` holds a `.gdignore`, so Godot doesn't import those files or export them.

## Referenced by the lesson code but not on the live site

| Path in lesson code | Used for | What the port does |
|---|---|---|
| `../../sprites/paddle.png` (64×16) | paddle | gray box at the CSS size |
| `../../sprites/ball.png` (16×16) | ball and spare balls | gray box at the CSS size |
| `../../sprites/dimgray.png` | `.overlay` background | 50% dim gray fill |
| `../sprites/gameover.png` | game-over screen | its `alt` text, "game over", as a browser would show it |
| `../sprites/highscores.png` | high-score screen | its `alt` text, "high scores" |
| `../sounds/whish.mp3` `plopp.mp3` `glass2.mp3` `boing.mp3` `deepsplosh.mp3` | serve / hit / break / bounce / fall | silent. `direct/game.gd` loads each from `source/assets/sounds/` if the file is ever vendored |
| `../../soundmanager2.swf`, `soundmanager2.js` | Flash audio bridge | not needed (Godot audio) |
| `prototype-1.5.1.js`, `gameconsole.js`, `brickslayer.js`, `brickslayer.css` | runtime | rebuilt from the lesson listings in `source/lesson-code/` |

The bricks and the lake were never images. They are CSS-colored `div`s (`#bricks .shadeN`, `#lake`), and the port draws them from those exact colors.
