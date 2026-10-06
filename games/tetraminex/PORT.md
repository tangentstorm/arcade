# Tetraminex: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/tetraminex |
| Source commit | `5da0d9e` (`master`, 2011-10-22) |
| Engine | ActionScript 3 + Flixel 2.x, 640×480 @ 30 fps, DAME levels |
| License | The repo has no license. It's Michal's own work. FranklinGothicDemiCond.ttf is a commercial font and is **not** bundled. |
| Tracking | GitHub issue #3 (wave-2) |

## Layout

- `source/` (`.gdignore`d) holds level CSVs and `Level_RoomN.as` sprite placements. PNGs live in `direct/assets/` (salvaged from `src/assets/images/`).
- `tools/extract_levels.py` regenerates `direct/level_data.gd` from those AS/CSV files.
- `direct/` is a **GDScript rewrite** of the grid rules (not a 1:1 Flixel port). Art and level data are salvaged.

## Direct edition (`direct/`): playable

| Original | Port |
|---|---|
| `Room.as` / `PlayState.as` nudge, grab, gravity tick | `room.gd` |
| `Level_RoomN.as` + `mapCSV_RoomN_{Tiles,Walls}.csv` | `level_data.gd` (generated) |
| Hero / Block / Grabber / Door / CageTile / PaintTile / ExitTile | `room.gd` cell + floor tile model |
| `PlayState` HUD + level buttons | `game.gd` + `game.tscn` (640×480 play SubViewport scaled in a 720² frame + side HUD) |
| Room scripts (talk) | Simplified talk queue for rooms 0–3 intros / solve lines |
| Esc | Arcade `PauseOverlay` autoload |

### How to play
- **Arrows** — move on the 10 Hz tick (same as Flixel `ScriptManager.tickInterval = 0.10`).
- **WASD** or **Dvorak ,AOE** — grab adjacent cells (two hands). Hold and move to push/pull.
- **R** — restart room. **0–9** — jump to an unlocked room.
- Fill matching **cages** with colored blocks (paint tiles recolor). When all cages are filled the exit door opens; walk onto the exit to advance.

### Kept rules
- 16×16 rooms, 30 px cells, wraparound `get`/`put`.
- Walls from Walls CSV with `collideIndex >= 4`.
- Floor codes: exit `1–4`, paint `8–15`, cage `16–31` (same as `GridTile.fromMap`).
- Grab hand limit 2; grabbers reposition before the hero occupies the entered cell (pull).
- Cage lock on matching color; paint recolors unlocked blocks.
- Gravity rooms (6, 8) run the south-nudge tick; hold-floor blocks movement.

### Gaps / deferred
- Full `Script` / `TalkWindow` teletype, fade curtain, Teddy walk-in on room 0 step 3.
- Teleporter end scene (room 8), machines/keys, billboard interaction beyond decor.
- Gravity jump (`dgy`) polish; room 6+ not tuned as a surge focus.
- Commercial Franklin Gothic font omitted (UI uses the default theme font).
- No sounds (source had none).

### MVP claim for this PR
Rooms **0–3** are the intended tutorial slice (walk → push into cages → grab/pull). All 10 rooms load from salvaged data; later rooms are reachable via unlock/debug keys but may need script polish.
