# Edition toggle

A segmented control in the gallery header switches every card between the **Original** (Direct
port) and **Enhanced** editions. The hint line updates, cards whose selected edition is not
built show a `Coming soon` overlay and dimmed title, and the choice persists across launches.

## Sub-features

- `edition-enhanced` clicking `Enhanced` presses that pill and the hint reads `Showing Enhanced editions — click a screenshot to play.`
- `edition-original` clicking `Original` restores `Showing Original editions — …` and the playable Direct cards (30 of 33 at a88963e).
- `edition-cards` every card re-evaluates playability for the chosen edition (0 Enhanced playable today; `_template` is hidden).
- `edition-persist` the choice is saved to `user://arcade_prefs.cfg` (`[gallery] edition=`) and reloaded at startup.

## How to get to it (user POV)

- Click the `Original` or `Enhanced` pill at the top right of the gallery.
- Tab to a pill and press Enter/Space (pills take focus).
- Relaunch the arcade: it opens in the last chosen edition.

## Driving it with flow.sh (helpers/drive_flow.gd)

Preconditions:

- `$H/launch.sh` and `$H/doctor.sh` OK. No other `flow.sh` running (shared prefs file).

- **Switch to Enhanced.** Run `$H/flow.sh` (Xvfb, PNGs) or `$H/flow.sh --headless`. Log shows
  `step ok: Enhanced hint: Showing Enhanced editions …`, `step ok: Enhanced pill pressed`,
  `info: enhanced playable cards: 0`; `flow-<Title>/02-enhanced.png` shows `Coming soon` on every card.
- **Switch back.** Same run: `step ok: Original hint: Showing Original editions …` and
  `info: original playable cards: N` (30 at a88963e).
- **Persistence (manual).** `$H/launch.sh --gui`; `source .cursor/skills/verify-arcade/evidence/.godot-gui.pid`; click the
  Enhanced pill (`DISPLAY=$DISPLAY xdotool mousemove 1198 52 sleep 0.3 click 1` — window is 1280×720; confirm with `$H/shot.sh before`);
  `cat ~/.local/share/godot/app_userdata/"tangentstorm arcade"/arcade_prefs.cfg` shows
  `edition="enhanced"`; `$H/cleanup.sh`, `$H/launch.sh --gui`, `$H/shot.sh reopened` shows Enhanced pressed.
  Then restore the file (delete it, or set `edition="direct"`).
- **Proof.** `flow-<Title>.log` + `01-gallery.png` / `02-enhanced.png`.

## Gotchas

- Clicking the already-active pill is a no-op (state stays, nothing saved).
- `flow.sh` restores `arcade_prefs.cfg`; a manual GUI session does not — restore it yourself, or
  later runs (and the user's desktop arcade) start in Enhanced.
- The prefs file is shared by every checkout/worktree (same project name → same `user://`).
- Enhanced playable count is 0 until some `games/<id>/enhanced/game.tscn` exists and its
  `TITLES` status for `enhanced` is not `planned`; don't report that as a toggle bug.
