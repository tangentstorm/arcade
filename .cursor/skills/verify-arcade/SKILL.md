---
name: verify-arcade
description: "Drive and prove tangentstorm arcade (Godot 4 monorepo) behavior the way a player does: the gallery UI in arcade/main.tscn (card grid layout, Original/Enhanced toggle, launch a game, Esc pause, Back to Arcade), the headless GDScript smokes in tools/, and the live GitHub Pages build at https://tangentstorm.github.io/arcade/. Use after changing arcade/, games/, export or CI, before claiming a gallery/layout/pause fix works, or to check what Pages is actually serving."
---

# verify-arcade

Helpers live in `.cursor/skills/verify-arcade/helpers/` (all paths below are relative to the
checkout root; helpers find the root themselves, so they work in any worktree, e.g.
`/workspace/arcade` → `/workspace/tangentgames` or `/workspace/wt-*`). Feature recipes are in
[`features/`](features/README.md) — read the matching file before driving.

```bash
H=.cursor/skills/verify-arcade/helpers
$H/launch.sh            # new evidence run + headless import
$H/doctor.sh            # read-only health check
$H/layout.sh --shots    # drive gallery-browse-layout
$H/cleanup.sh           # stop what launch started; evidence stays
```

Godot binary: `/workspace/tools/godot4` (4.7.2, matches CI `GODOT_VERSION`). Override with `GODOT=`.

## Merge gate

Invoked as `/verify-arcade` or `@verify-arcade` (the Grok Bot / Cursor skill wraps this project skill).

Minimum merge-gate run: `launch` → `doctor` → `layout.sh --shots` → `flow.sh` → `cleanup`.

Before claiming PASS or merging: send at least one evidence PNG (or short video) to the user in chat. **PASS + media** is standing OK to squash-merge related open arcade PRs covering the verified tip; **no media = no merge**.

## Launch

- **Headless (default, enough for every mapped feature):** `$H/launch.sh`. Creates
  `evidence/<YYYYmmdd-HHMMSS>/`, records it in `evidence/.current`, writes `build.txt`
  (HEAD + dirty files) and runs `godot --headless --path . --import` → `import.log`.
  Ready = exit 0 and prints `VERIFY_RUN=<dir>`. A fresh checkout/worktree **must** import
  first: without `.godot/` every scene load fails with `No loader found for resource ...avatar.png`
  while `test_gallery_layout.gd` still exits 0.
- **Interactive window:** `$H/launch.sh --gui`. Also starts a private `Xvfb :91+`
  (1280×720) and the arcade (`godot --audio-driver Dummy --path .`, main scene = gallery).
  Ready = prints `launch: GUI ready on DISPLAY=:N` (xdotool found the window titled
  `tangentstorm arcade`). Pids + display go to `evidence/.godot-gui.pid`. Only ONE GUI run at a
  time; launch refuses if that pidfile exists.
- Interactive on the user's real desktop instead: `/workspace/tools/godot4 --path /workspace/arcade`
  — only if asked; never drive a window you did not start.
- Teardown: `$H/cleanup.sh` (see Cleanup).

## Doctor

`$H/doctor.sh` — read-only, exit 0 = worth driving. Checks: Godot is 4.7.2.x; `project.godot`
is `tangentstorm arcade`; git HEAD/branch/dirty count; `.godot/imported` exists; harness files
`tools/test_gallery_layout.gd`, `tools/smoke_headless.sh`, `tools/smoke_scenes.gd`, `tools/lint_ascii_ui.sh` (runs the ASCII UI lint); xvfb-run,
Xvfb, xdotool, ffmpeg, curl (warn only); current run dir; if a GUI pidfile exists, the pid is
alive AND owns a `tangentstorm arcade` window (else FAIL: stale → cleanup); Pages URL → 200 (warn).
Run it first, and again whenever anything looks off.

## Drive

Prefer the repo's own harnesses; the helpers are thin wrappers that tee into the run dir.
Every helper prints `PASS`/`FAIL` and exits non-zero on failure; logs are also scanned for
`SCRIPT ERROR|Parse Error|ERROR:|SMOKE FAIL|VERIFY FAIL` because Godot often exits 0 anyway.

| Feature | Command | What it does |
|---|---|---|
| gallery-browse-layout | `$H/layout.sh [--shots]` | `tools/test_gallery_layout.gd` at 6 sizes (needs 6 `ok: gallery fits` lines); `--shots` adds a real-window PNG per size (one Xvfb Godot per `--resolution`, `helpers/gallery_shots.gd`) |
| edition-toggle, launch-game-and-return | `$H/flow.sh [--headless] ["Card Title"]` | `helpers/drive_flow.gd`: real injected mouse/keys — click `%ModeEnhanced`, `%ModeDirect`, click the card (default `Tetraminex`), Esc → `%ResumeButton`, Esc Esc → gallery, click card again, Esc → `%ArcadeButton`; asserts scene/pause state each step, PNG per step unless `--headless`. Restores `user://arcade_prefs.cfg` |
| pages-deploy-smoke | `$H/pages.sh [sha]` | curl `?nocache=` index + HEAD of index.{html,pck,wasm,js} (etag/last-modified/age), compares gh-pages commit `Deploy <sha>` to `origin/main` |
| ofcp-live-connect | see `features/ofcp-live-connect.md` | existing `tools/ofcp_live_probe.gd`, plays one hand vs the live server |
| whole-repo regression | `$H/smoke.sh` | `tools/smoke_headless.sh` (import, boot, visit every playable scene, every `tools/test_*.gd`) → `smoke.log` |

Interactive window (after `launch.sh --gui`): `source evidence/.godot-gui.pid` then
`DISPLAY=$DISPLAY xdotool mousemove X Y click 1` / `xdotool key Escape`; screenshot with
`$H/shot.sh <name>`. Coordinates are a last resort — the scripted drivers locate controls by
unique name (`%Scroll`, `%GameList`, `%ModeDirect`, `%ModeEnhanced`, `%ModeHint`,
`PauseOverlay/%ResumeButton`, `PauseOverlay/%ArcadeButton`) and cards by their title label
(the `GameRegistry.TITLES` display names, e.g. `Tetraminex`, `Brickslayer`, `OFCP`).

Browser proof of the live site (optional, needs a browser-capable agent): open
`https://tangentstorm.github.io/arcade/?nocache=<epoch>` in a fresh/Incognito profile and wait for
the gallery canvas; Pages sends `cache-control: max-age=600`, so a normal reload can show the
previous build for up to 10 minutes.

Isolation: headless helpers (`layout.sh`, `flow.sh`, `smoke.sh`, `pages.sh`) can run in
parallel, each Xvfb run uses `xvfb-run -a` (its own display). They share Godot's
`user://` dir (`~/.local/share/godot/app_userdata/tangentstorm arcade/`), so do not run two
`flow.sh` at once (both touch `arcade_prefs.cfg`). One `launch.sh --gui` window and one browser
profile at a time.

## Evidence

Location: `.cursor/skills/verify-arcade/evidence/<run>/` in the checkout being verified
(gitignored; override the base with `VERIFY_ARCADE_EVIDENCE=`). Per run:

- `build.txt` — git HEAD + dirty files the run tested
- `import.log`, `layout.log` (`ok: gallery fits (W, H) (N cols, grid G / scroll S)` per size),
  `shots.log` + `gallery-<W>x<H>.png` (window vs logical size + columns per shot)
- `flow-<Title>.log` (`step ok:` lines) + `flow-<Title>/01-gallery.png … 05-back.png`
- `pages-index.html`, `pages-index.headers`, `pages-headers.txt`, `pages-deploy.txt`
- `smoke.log`, `gui.log`, any `shot.sh` PNGs

Proof standards: drive the real user path (rendered gallery, injected clicks/keys), not
`_set_edition()` or `GameRegistry.launch()` directly; capture the action and the resulting state
(log line per step + before/after PNGs), not only the end screen; verify side effects (the
current scene path, `get_tree().paused`, prefs file restored, gh-pages commit sha). A headless
pass proves layout math and scene flow, not pixels — attach `--shots`/Xvfb PNGs for visual
claims. Report the run dir path and helper exit codes.

## Cleanup

`$H/cleanup.sh` — kills only the process groups recorded in `evidence/.godot-gui.pid`
(Godot + its Xvfb), removes that pidfile and `evidence/.current`, lists evidence. It never
deletes `evidence/<run>/`, never kills by process name. Headless helpers exit on their own;
`drive_flow.gd` restores `user://arcade_prefs.cfg` itself. Run cleanup after failed
iterations too. Delete old evidence manually only when asked.

## Helpers

All in `.cursor/skills/verify-arcade/helpers/`, executable, run from anywhere:

- `launch.sh [--gui]` — new run + import; `--gui` starts Xvfb + arcade window.
- `doctor.sh` — read-only health check.
- `layout.sh [--shots]` — gallery-browse-layout driver.
- `flow.sh [--headless] ["Card Title"]` — edition toggle + launch/pause/return driver.
- `pages.sh [expected-sha]` — live Pages + deploy-sha check.
- `smoke.sh` — wraps `tools/smoke_headless.sh`.
- `shot.sh <name>` — PNG of the `--gui` window.
- `cleanup.sh` — teardown.
- `lib.sh` — sourced settings (`GODOT`, `ROOT`, `EVID`, `run_dir`, `log_clean`).
- `drive_flow.gd`, `gallery_shots.gd` — SceneTree scripts used by `flow.sh` / `layout.sh`
  (`godot --path . --script res://.cursor/skills/verify-arcade/helpers/<x>.gd`).

Keep `features/` honest when the app changes (`/maintain-verification-skill`).
