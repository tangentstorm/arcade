# gamesketchlib

Source: https://github.com/tangentstorm/GameSketchLib (`master` @ `6b0de14`, 2020-11-16). Course: CC-BY 3.0 © Michal J. Wallace;
library: MIT. These are Processing sketches from 2011. GameSketchLib is a flixel-like library for
Processing / processing.js, and the course is a video tutorial series built on it. Each sketch
is its own gallery tile:

| Tile | Folder | Source | Kind | Status |
|---|---|---|---|---|
| SketchBots | [`../sketchbots/`](../sketchbots/PORT.md) | `course/w01_SketchBots/demos/SketchBots` | input demo | Direct playable |
| Invader Sketch | [`../invader_sketch/`](../invader_sketch/PORT.md) | `course/w02_InvaderSketch/demos/InvaderSketch` | full game | Direct playable |
| Overlap Demo | [`../overlap_demo/`](../overlap_demo/PORT.md) | `course/w02_InvaderSketch/demos/OverlapDemo` | tech demo | Direct playable |
| Overlap Demo (Live) | [`../overlap_demo_live/`](../overlap_demo_live/PORT.md) | `course/w02_InvaderSketch/live/OverlapDemoLive` | tech demo | Direct playable |
| Bullet Demo | [`../bullet_demo/`](../bullet_demo/PORT.md) | `course/w02_InvaderSketch/demos/BulletDemo` | tech demo | Direct playable |
| Bullet Demo (Live) | [`../bullet_demo_live/`](../bullet_demo_live/PORT.md) | `course/w02_InvaderSketch/live/BulletDemoLive` | tech demo | Direct playable |
| GameSketchLib Demo | [`../gamesketchlib_demo/`](../gamesketchlib_demo/PORT.md) | `course/w02_InvaderSketch/demos/GameSketchLibDemo` | tech demo | Direct playable |
| Keyboard Test (Workaround) | [`../keyboard_test_workaround/`](../keyboard_test_workaround/PORT.md) | `course/w02_InvaderSketch/keyboard_tests/KeyboardTestWorkaround` | input test | Direct playable |
| Keyboard Test (Buggy) | [`../keyboard_test_buggy/`](../keyboard_test_buggy/PORT.md) | `course/w02_InvaderSketch/keyboard_tests/KeyboardTestBuggy` | input test | Direct playable |
| Keyboard Test (HashMap) | [`../keyboard_test_hashmap/`](../keyboard_test_hashmap/PORT.md) | `course/w02_InvaderSketch/keyboard_tests/KeyboardTestHashMap` | input test | Direct playable |

Every `.pde` under `course/` now has a tile. Not ported: `source/` (the standalone library,
partly inlined into Invader Sketch as `BaseGame.pde`) and `Browse.java`. Neither is a sketch.

Tests: `tools/test_sketchbots.gd`, `tools/test_invader_sketch.gd`, `tools/test_gsl_demos.gd`.
