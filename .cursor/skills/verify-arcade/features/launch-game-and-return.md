# Launch a game and return

Clicking a playable card opens that game in the selected edition with its own scale policy
(letterbox or expand). Inside any game, Esc pauses and shows the shared overlay (`Paused`,
`Resume`, `Back to Arcade (Esc)`); Resume continues, and Back to Arcade — or Esc a second
time — returns to the gallery unpaused.

## Sub-features

- `launch-click` left-click on a playable card changes scene to `res://games/<id>/<edition>/game.tscn`.
- `launch-keyboard` focused card + Enter (`ui_accept`) launches the same scene.
- `launch-blocked` clicking a `Coming soon` card does nothing.
- `pause-open` Esc in a game shows the overlay and pauses the tree.
- `pause-resume` `Resume` hides the overlay and unpauses; still in the game.
- `pause-back-button` `Back to Arcade (Esc)` returns to the gallery, unpaused, gallery scale restored.
- `pause-back-esc` Esc while paused returns to the gallery.

## How to get to it (user POV)

- Click a card screenshot in the gallery (Original mode: 30 playable at a88963e, e.g. `Tetraminex`, `Brickslayer`, `OFCP`).
- Tab to a card and press Enter.
- In game: press Esc; then click `Resume` / `Back to Arcade (Esc)` or press Esc again.

## Driving it with flow.sh (helpers/drive_flow.gd)

Preconditions:

- `$H/launch.sh` and `$H/doctor.sh` OK. Pick a card title that is playable in Original mode.

- **Launch by click.** Run `$H/flow.sh "Brickslayer"` (or `--headless`). Log:
  `step ok: clicked 'Brickslayer' -> res://games/brickslayer/direct/game.tscn`; `03-game.png` shows the game.
- **Pause.** Same run: `step ok: Esc shows pause overlay + pauses tree`; `04-paused.png` shows `Paused` + both buttons.
- **Resume.** `step ok: Resume hides overlay, game continues`.
- **Back via Esc Esc.** `step ok: Esc, Esc returns to gallery`.
- **Back via button.** Card clicked again, then `step ok: Esc shows pause overlay again` and
  `step ok: Back to Arcade returns to gallery, unpaused`; `05-back.png` shows the gallery.
- **Real-window click (manual).** `$H/launch.sh --gui`; `source .cursor/skills/verify-arcade/evidence/.godot-gui.pid`;
  `DISPLAY=$DISPLAY xdotool mousemove 170 220 sleep 0.3 click 1` (Tetraminex, top-left card at 1280×720);
  `$H/shot.sh launched` shows the Tetraminex room; `DISPLAY=$DISPLAY xdotool key Escape`, `$H/shot.sh paused`.
- **Keyboard launch (manual).** Same session: `DISPLAY=$DISPLAY xdotool key Tab` until a card has the
  bright focus border (`$H/shot.sh focus` to check), then `xdotool key Return`; `$H/shot.sh launched-kbd`.
- **Every title.** `$H/smoke.sh` instantiates every playable scene once (`ok: res://games/…`);
  it does not exercise the pause overlay.
- **Proof.** `flow-<Title>.log` with all `step ok:` lines + `VERIFY DONE: 0 failure(s)`, and the five PNGs.

## Gotchas

- `PauseOverlay` reads Esc in `_unhandled_input`; a game that consumes `ui_cancel` itself breaks
  pausing for that title only — run `flow.sh` with that game's title, not just the default.
- Cards below the fold must be scrolled into view before a click lands; the driver uses
  `%Scroll.ensure_control_visible`. Raw xdotool clicks need a scroll first.
- `OFCP` connects to `wss://ofcp.tangentcode.com/ws` on launch; offline behavior of the card is unverified — expect a network-dependent screen.
- Letterbox titles switch the window to KEEP + INTEGER stretch; returning must restore EXPAND +
  FRACTIONAL — check `05-back.png` fills the window, not just the scene path.
- In a `--gui` session, clicks sent right after the window maps are dropped; `launch.sh --gui` waits 2 s before reporting ready, keep a `sleep 0.3` between `mousemove` and `click`.
- The tree stays paused if a run aborts mid-overlay; each helper run is a fresh process, so just rerun.
