# Squirrel Command — port notes

| | |
|---|---|
| Source | Single-file HTML game a Claude artifact made for Michal (shared in chat 2026-10-22), kept verbatim as [`source/squirrel_command.html`](source/squirrel_command.html) |
| Tracking | arcade issue #123 |
| License | Original artifact for Michal; Godot port by GodotBot / tangentstorm |
| Pitch | Missile Command in a garden: dust-blast ground squirrels before they eat five crops |

## Original

~6 KB inline `<script>` (the other ~80 KB of the file is Claude artifact CSS):
680x440 `<canvas>`, Score / Wave / Crops HUD + Restart button above it, one hint line below.
`reset / startWave / spawn / fire / loop / drawSquirrel / drawCrop`, all procedural `ctx` drawing.

## Direct edition (`direct/`) — playable

- `squirrel_logic.gd` — the simulation half of `loop()` plus `reset/startWave/spawn/fire`,
  line for line: same numbers everywhere (dt cap 0.05, 5+3*wave squirrels, first spawn 0.6 s,
  spawn gap `max(0.25, 1.4-0.08*wave) * (0.6..1.4)`, runner chance `0.12+0.02*wave`, speed
  `(46+7*wave) * 1.7 if runner`, sideways wobble `sin(ph)*22`, eat radius 14, shot 430 px/s,
  cooldown 0.35 s, blast radius 0→44 over 0.25 s / hold to 0.6 s / 0 by 0.95 s, kill while
  `t<0.6` within `r+6`, 10 / 25 points, wave clear +25 per crop left, click while over restarts).
- `game.gd` — the drawing half: the whole artifact page (16 px margin, HUD, rounded 12 px
  canvas, hint) is one **712x544 stage**, self-scaled into the letterboxed window (like
  tankgame), so no `fit_stage` is needed. Canvas paths are drawn the way the browser fills
  them: a multi-`arc()` path also fills the polygon through each arc's start point, which is
  why the tomatoes have the little red wedge between them in the original too.
- Input: left click / tap on the field fires at canvas coordinates; the drawn Restart button
  resets. Esc stays with the arcade PauseOverlay.

### Deviations

- Text uses Godot's built-in fallback sans (thinned with `FontVariation.variation_embolden`)
  instead of the artifact's system/"anthropic-sans" stack; sizes match (14/13/26/30/17 px).
- ASCII-only UI (`ascii-ui-lint`): `Final score: N · Wave N` → `Final score: N - Wave N`,
  hint `aim — lead` → `aim - lead`.
- The Restart button's tabler `ti-refresh` icon is a drawn arc + arrowhead.
- `drawSquirrel` advanced `leg += 0.4` per rendered frame; the port does it per `_process`
  frame (same thing at display rate).

### Enhanced

Planned (registry: Coming soon).
