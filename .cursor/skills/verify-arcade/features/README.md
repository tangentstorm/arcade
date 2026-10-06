# tangentstorm arcade verification map

This directory is the maintained source for verifying the user-facing behavior of the
tangentstorm arcade: the Godot 4 gallery hub, the shared pause overlay, and the GitHub Pages
build. Read this index before driving the app, then use the matching feature file as the recipe.

## Baseline preconditions

- Work in the checkout you are verifying (`/workspace/arcade` or a `/workspace/wt-*` worktree).
  `H=.cursor/skills/verify-arcade/helpers`.
- Run `$H/launch.sh` (new evidence run + import), then `$H/doctor.sh` and require `doctor: OK`.
- Godot is `/workspace/tools/godot4` 4.7.2. The gallery opens in **Original** mode unless
  `user://arcade_prefs.cfg` says otherwise; the flow driver backs up and restores that file.
- Never drive a Godot window or browser profile this run did not start.

## Driving conventions

- Start every recipe from a fresh gallery (each helper boots its own Godot process).
- Locate controls by unique name (`%Scroll`, `%GameList`, `%ModeDirect`, `%ModeEnhanced`,
  `%ModeHint`, `%ResumeButton`, `%ArcadeButton`) and cards by their visible title
  (`GameRegistry.TITLES` display names). Coordinates only in a `launch.sh --gui` session.
- Act through real input: the scripted drivers inject mouse clicks and key presses via
  `Viewport.push_input`; never call `_set_edition()` or `GameRegistry.launch()` as "proof".
- Treat every command as literal; card titles are case- and punctuation-sensitive.

## Proof and skip reporting

- Capture the action and the resulting state: a `step ok:` / `ok:` log line per step plus PNGs
  (Xvfb) for anything visual.
- Godot frequently exits 0 after `ERROR:` lines; a pass needs exit 0 AND a clean log (the
  helpers check both).
- Record the run dir (`evidence/<run>/`), helper, and card title with every artifact.
- Headless runs prove layout math and scene flow, not rendering. Say so if no PNG was taken.
- Report an unreachable path with the attempted command and the unmet precondition; do not
  report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible
behavior, then exactly four H2s in order: `Sub-features`, `How to get to it (user POV)`,
`Driving it with <harness>` (starting with `Preconditions:`), and `Gotchas`.

## Features

- [Gallery browse & layout](./gallery-browse-layout.md) — card grid fits the window at any size, wraps columns, vertical scroll only.
- [Edition toggle](./edition-toggle.md) — Original / Enhanced segmented control switches every card.
- [Launch a game and return](./launch-game-and-return.md) — click a card, Esc pause, Resume, Back to Arcade / Esc Esc.
- [Pages deploy smoke](./pages-deploy-smoke.md) — the live site serves the latest `main` build; cache-bust proof; `pages_doctor.sh --require` refuses "fixed" without etag/stamp.
- [OFCP live connect](./ofcp-live-connect.md) — the OFCP Direct thin client plays a hand against the live wss server.

Whole-repo regression (not a single feature): `$H/smoke.sh` wraps `tools/smoke_headless.sh`.
