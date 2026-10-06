# Gallery browse & layout

The arcade opens on a full-bleed gallery: a header (logo, title, Original/Enhanced pills), a
mode hint line, and a grid of cards (screenshot + title) that wraps into as many columns as fit
the window. Only the grid scrolls, vertically; nothing ever clips or scrolls sideways.

## Sub-features

- `layout-fit` header, scroll area and grid stay inside the window at every size.
- `layout-wrap` column count follows the *logical* width: in the headless test 1280→4, 1024→3, 800→2, 600→2, 1920→6; in a real window (`canvas_items` + `expand`, base 1280×720) the logical width never drops below 1280, so real windows show ≥4 columns, and wide aspect ratios add columns (2560×800 → logical 2304 → 8).
- `layout-vscroll` the vertical scrollbar has room reserved; no horizontal scrollbar ever.
- `layout-resize-back` shrinking then growing the window reflows back (last size repeats 1280×800).
- `layout-cards` one card per registered title except `_template` (33 at a88963e; `flow.sh` prints `gallery shows N cards (want N)` from the registry); unplayable titles show `Coming soon` / `Not working yet`.

## How to get to it (user POV)

- Start the arcade (desktop `godot --path .` or the Pages site); the gallery is the main scene.
- Resize the window (desktop) or the browser tab (Pages).
- Return from any game via the pause overlay (lands back on the gallery).

## Driving it with layout.sh (tools/test_gallery_layout.gd + helpers/gallery_shots.gd)

Preconditions:

- `$H/launch.sh` succeeded (import done) and `$H/doctor.sh` reports `doctor: OK`.
- For `--shots`: `xvfb-run` available (doctor lists it).

- **Fit at six sizes.** Run `$H/layout.sh`. `layout.log` has six lines like
  `ok: gallery fits (1280.0, 800.0) (4 cols, grid 1232 / scroll 1240)` and no `SMOKE FAIL`;
  helper prints `layout: PASS`. Grid width + scrollbar ≤ scroll width at each size.
- **See it render.** Run `$H/layout.sh --shots`. `shots.log` has one
  `shot: …/gallery-<W>x<H>.png window=(W, H) logical=(…) cols=N grid_w=… scroll_w=… fits` per size
  (1280x800 1024x570 800x600 600x800 1920x1080 2560x800; one Godot process per size via
  `--resolution`). Open the PNGs: no card cut at the right edge, scrollbar visible at right,
  header pills fully visible; `gallery-2560x800.png` shows 8 columns.
- **Custom sizes.** `VERIFY_SIZES="390x844 3440x1440" $H/layout.sh --shots` (Xvfb screen is 2560×1600; larger sizes are clamped).
- **Interactive.** `$H/launch.sh --gui`, `source $EVID/.godot-gui.pid` (EVID = `.cursor/skills/verify-arcade/evidence`), `DISPLAY=$DISPLAY xdotool search --name "tangentstorm arcade" windowsize 800 600`, `sleep 1.5`, then `$H/shot.sh gui-800x600` — the PNG is the whole 1280×720 Xvfb screen with the 800×600 window top-left, scaled-down gallery, still 4 columns.
- **Proof.** Keep `layout.log`, `shots.log`, `gallery-*.png` from the run dir.

## Gotchas

- Without an import (`.godot/` missing) the test logs `No loader found for resource ...avatar.png`
  but still prints `ok:` lines and exits 0. `layout.sh` fails on that; raw runs won't.
- The headless test resizes a host `Control`, not the OS window; only `--shots` exercises real
  window resizes and content-scale (`canvas_items` / `expand`).
- Layout invariants (regressions came from each): `%Scroll` `horizontal_scroll_mode = 3`
  (SHOW_NEVER), not 0 (DISABLED — it lets the grid's min width widen the whole layout);
  `_reflow_columns()` must subtract the v-scrollbar width; never bump `cell_w` up to
  `CARD_MIN_W` (forces overflow on narrow windows); keep `%GameList.custom_minimum_size` at 0;
  the root's `grow_horizontal = 2` (both) clips on both sides when content is wider than the window.
- `DisplayServer.window_set_size()` from a `--script` does not resize the window under bare Xvfb (no WM); use `--resolution` (what `layout.sh` does) or `xdotool windowsize` on a `--gui` session.
- Narrow portrait windows (600×800, phones on Pages) get 4 tiny columns, because of the 1280-wide logical floor — fits, but small text; that is current design, not an overflow.
- Screenshots under Xvfb need the non-headless binary path (`--path`, no `--headless`); `--headless` gives empty textures.
