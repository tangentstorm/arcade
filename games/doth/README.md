# Doth

Status: **Direct playable** (faithful core MVP), **Enhanced playable** (torchlit presentation
makeover over the same Direct world + SvA-like tiles).

Source: [tangentstorm/silverware](https://github.com/tangentstorm/silverware) — Turbo Pascal
"Quest for the Empire" / Doth-A Kroz-like adventure (Sterling Silverware, 1992–1996).
See [PORT.md](PORT.md) for version reconcile, fidelity notes, and deferred work.

- `direct/game.tscn` — SvA-like pixel tiles (procedural 16×16 atlas), title screen,
  overworld from decoded `dmap1.pic`, starter chamber, movement, walls, pickups, boulder push.
  Esc opens the arcade pause / Back to Arcade.
- `enhanced/game.tscn` — 1280×720 letterbox shell over Direct `doth_world.gd` + `doth_tiles.gd`
  (no rules/tile copy): torchlit chrome, pickup pulse / collect juice, bottom stats HUD,
  title / win cards, Back to Arcade. Esc → PauseOverlay. No Alchementrix IP.

Controls: arrows / WASD / numpad (incl. diagonals) · `1` starter · `2` / Enter / Space overworld ·
Esc pause / Back to Arcade.
