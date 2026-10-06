# Marigold Homestead — port notes

| | |
|---|---|
| Source | Claude Design artifact [BjKJn834](https://claude.ai/artifact/BjKJn834yqz9cjMfgVi1py) (React/DC mock) + issue #105 |
| License | Original mock for arcade; Godot port by GodotBot / tangentstorm |
| Pitch | Starflight II × Farming Simulator — pixel “homestead OS” |

## Mock origin

Pixel UI mock (dark purple / amber / cyan terminal OS) with six screens: Cockpit, Homestead, Survey, Market, Ship & Crew, Ledger. **Screens are provisional** — Michal likes the pixel aesthetic; layouts are swappable. Data tables (crops, commodities, crew, 6 systems + scan, start state, palette, sprites) transcribed from the artifact `source.js` / `notes.json`.

## Direct edition (`direct/`) — playable

- Soft stage **1280×720**, letterboxed, nearest-neighbor UI.
- Shared chrome: top bar (credits / fuel / hold / date), left nav, END DAY, bottom LOG.
- **Homestead is not the mock’s click-grid.** It is a Starflight-II-style **fractal/procedural planet surface** (64×64 tiles, fBm height + moisture → water / rock / grass / arable soil). You **drive a tractor** (WASD / arrows); the selected tool/seed applies **under the wheels** (and a one-tile trail). Seed locker = tool picker (plant seed / WATER / HARVEST). WATER ALL / HARVEST ALL remain as convenience. Space applies tool without moving.
- Cockpit: sector chart of Marigold Reach, select system, PLOT COURSE (2 fuel + 1 day; stations charge 150 docking), REFUEL +1 (30cr).
- Market: buy commodities / sell harvest when docked at a trade station (Havenport, Drift Market).
- Survey / Ship & Crew / Ledger: live numbers from shared state (income statement + balance sheet).
- Month end (day 28→1): crew wages + life support billed.

### Files

- `direct/marigold_logic.gd` — state & rules
- `direct/marigold_gfx.gd` — palette + char-grid sprites + procedural planets
- `direct/game.gd` / `game.tscn` — chrome + six screens
- `direct/fonts/nokiafc22.ttf` — pixel mono (same as Spiders vs Aliens)

### Enhanced

Stub later (`enhanced/` planned). Same rules can wrap denser chrome.

## Out of scope for this PR

- Alchementrix
- Full Starflight landing / fractal zoom levels
- Audio, CRT overlay, multiplayer
