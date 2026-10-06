# Shep: port notes

| | |
|---|---|
| Source | https://github.com/tangentstorm/shep |
| Source commit | `6865ae0` (`master`, 2020-02-29, "add flashplayer 10 debugger so i can see trace()") |
| Engine | Haxe 2.07 → Flash 9 (800×575 @ 24 fps), physaxe physics, feffects tweens, Flex 3 shell (`console.mxml`) |
| Credits | Michal J Wallace (programming, levels) and Sean D Siem (art, sound), as robocognito |
| License | The repo has no license. It's Michal's own work. The vendored physaxe and feffects code is **not** ported or vendored. |
| Tracking | GitHub issue #3 |

## Layout

- `source/` (`.gdignore`d) holds a verbatim copy of `code/*.hx`, `console.mxml`, `Help.mxml`, `flex.css`, `GameCanvas.as`, `levels/*.svg`, `assets/assets.swfml`, the three Flash clips (`fuse-blue.swf`, `fuse-red.swf`, `socket.swf`), the `Makefile`, and `pack.py`.
- `source/gen_level_pack.py` is the GDScript twin of `pack.py`. It writes `direct/level_pack.gd` with the raw SVG of every level. Loose `.svg` files would be imported by Godot as textures, so the levels are embedded instead, the way `LevelPack.hx` did for the Flex build. Its output was checked byte-for-byte against `LevelPack.hx`.
- `direct/assets/` holds the PNGs, MP3s, and TTFs that the game uses, copied unchanged from `assets/`.

## Direct edition (`direct/`): playable

| Original | Port |
|---|---|
| `Game1.parseSVG` / `addPolyXml` / `addPocket` / `addDoor` / `addSpinner` | `shep_levels.gd` `parse_svg()`. It uses the same color code: green circle is the start, red circles are plain fuses (code 0), other circles are red fuses (code 1), green and cyan rects are sockets (code 0 and 1), dark-cyan rects are doors, blue rects are spinners, magenta polygons float (8 vertices make a cargo box, otherwise a hex crate), and everything else is a wall. Only direct children of `<svg>` are read, as with `elementsNamed`, so the border `<line>`s and `<polyline>`s are ignored. |
| `Game1` world, `updateWorld`, `checkForWin`, `checkForLoss`, `openDoor`, `drawWorld`, sounds, `onKeyDown`, `kick` | `shep_world.gd` |
| `console.mxml` (Title, Help, Credits, LevelSelect, Game, Pause, Victory, Defeat) | `game.gd`. The screens use the original PNGs and button positions. |
| `ordLevel`, `getLevelName`, `getLevelText`, `unlockLevels`, `showLevelInfo`, `drawPreview` | `shep_levels.gd` and `level_preview.gd` |
| `FlashClock` (120 s, MM:SS, red alert at ≤30 s with alert1/2/3 and alert3 ×2 at ≤5 s) | `shep_levels.gd` and `_update_clock` |
| `SharedObject("shep_scores")` `level_N` = seconds left | `user://shep_scores.cfg`, section `shep_scores` |
| `SoundManager` (11 SFX + `wah-danube.mp3`, mute toggle at 696,552) | `game.gd` |
| `StarField` (5×100 stars, 24 fps) | `star_field.gd` |

### Physics mapping (physaxe → Godot 2D)
- Each level runs in its own `SubViewport`, so it has its own physics space. All bodies use `gravity_scale = 0`, and the project's gravity isn't touched. The in-game pause and the win/lose states stop the space, the way Game1 just stopped calling `world.step`.
- Game1 called `world.step(1, …)` once per 24 fps frame, so its speeds are in px/frame. The port multiplies speeds by 24 and raises the per-frame factors to `24·delta`. Bot and fuses use `0.985 × 0.999` (Game1 friction plus physaxe's default property damping). Crates use `0.999`. Angular damping is `0.999`. A click kick is `calcVector(50)`, which is √50 px/frame toward the mouse.
- Mass is area × density (shep 20, fuse 15, floaty 100). Walls, sockets, and spinners are immovable. Spinners are `AnimatableBody2D`s turning at 0.03 rad/frame.
- **Restitution:** physaxe uses max(e1, e2) and Godot uses e1 + e2. Walls get bounce 0.65 and bodies 0.25, which gives wall-vs-body 0.9 and body-vs-body 0.5, matching the original pairs. Friction keeps the source coefficients, but Godot combines them with min where physaxe used √(f1·f2).
- **Pocket "arbiter":** a fuse or Shep counts as touching a socket when Godot reports the contact, or when it's within r + 15 + 1.5 px. The 60×60 pocket "zone" box was debug-only in the original (as a static body with zero density, its shape never updated), so it's drawn only in the P debug view and in the previews.

### Kept quirks
- Red sockets open `doors[0]` no matter which door (`@TODO: multiple colored doors?`). The debug `o` key opens a door and then clears the door list.
- The level-select trophy shows when svg 9 (menu Level 4) has a score, because `raw_score(9)` isn't the last level.
- `FlashClock.resume` restarts from the ceiling of the remaining time, so pausing gives back the fractional second.
- `calcVector` returns `(0, rise)` when the mouse is exactly above or below the bot.
- Negative wall-hit blur is clamped to 0, as in Flash, so only some hits blur.
- Debug keys work during play: `0`–`9` jump to svg N (including the off-menu 0008 "debug level"), `p` toggles the physics view, `r`/`e`/`d` set the clock to 30/20/10, `t` gives a random bg tint, `x` stamps the level preview, and `b` blurs.

### Deviations and gaps
- **Flash clips:** `fuse-blue.swf`, `fuse-red.swf`, and `socket.swf` are vector animations. The port uses the PNG renders in `assets/` instead (`ball.png`, `red-ball.png`, `pocket.png`, `red-pocket.png`). `PocketClip.swallow`/`openWide` become a squeeze tween and a pulsing glow. The glow filters (`redGlow`, `cyanGlow`) are left out, except for a light tint on doors.
- **Keyboard:** Game1's `keyboardControl` branch (←/→ turn 15°, ↑ thrusts 5 px/frame) was never switched on in the original. Here the arrows switch it on and moving the mouse switches it off. Keyboard thrust also plays the thrust sound and glow.
- **Any-key restart dropped:** the original restarted the level on any key it didn't recognize. Use Pause → Restart Level instead. Keys only reach the game in the Game state, not in menus.
- **Wall-hit lurch:** the contact point is estimated from Shep's velocity, since Godot doesn't hand the contact to `body_entered`. Contact sounds fire once per new contact instead of on every updated contact.
- **Blur:** `BlurFilter` is replaced by a 9-tap box-blur shader (`blur.gdshader`).
- **Credits:** the robocognito.com, sculptedpixel.org, and withoutane.com link buttons are left out. The Kongregate API, the site lock, and the unused `Help.mxml` popup aren't ported.
- **Flex Halo buttons** are approximated with flat light-gray styleboxes. The level buttons use the original `button_bg_*` skins, `fake_receipt.ttf`, and `lil-padlock.png`.
- **The original was unfinished:** there are no level names past 9, there's no enhanced design, and the level art for 0003, 0008, and 0009 has a blank foreground. Nothing new was invented.
- **Size:** the vendored art and music add about 4.2 MB to the pck. `wah-danube.mp3` alone is 0.96 MB, and the backgrounds are imported lossless.

Tests: `tools/test_shep.gd` (run by `tools/smoke_headless.sh`). It covers SVG parsing for all 10 levels, menu order, unlocks, scores, the clock, steering math, and a headless physics run: a kicked fuse sinks into its socket and docking wins, a red fuse opens the door, the clock running out loses, and pause holds the clock.

## Enhanced edition (`enhanced/`): playable

A presentation makeover of the same zero-g fuse puzzler. **No rules are duplicated:**
`enhanced/game.gd` preloads `direct/shep_world.gd`, `direct/shep_levels.gd`,
`direct/star_field.gd`, `direct/level_preview.gd`, and the Direct assets. Physics,
SVG parsing, win/lose, the 120 s clock, unlocks, and scores are the Direct code.
Enhanced adds only read-only presentation and juice, so a rules fix in Direct lands
in both editions. No Alchementrix IP.

| File | Role |
|---|---|
| `enhanced/game.gd` + `game.tscn` | 1280×720 letterbox shell: menus, HUD, overlay, juice, Esc → PauseOverlay |

### What changed (presentation only)
- **View:** fixed 1280×720 stage (letterbox). The Direct 800×575 world runs in a centered
  SubViewport so it keeps its own physics space. Side panels hold the objective, fuse
  legend, and controls.
- **Clearer fuse / ship UI:** cyan and red rings around fuses and sockets (code 0 / code 1),
  velocity whiskers on live fuses, a pulsing ring on Shep, and a glowing aim line with
  chevrons. A fuse counter (`set / total`) and an objective line track progress. When the
  last fuse docks, a "Dock Shep" hint pulses over the field.
- **Juice:** thrust sparks on kick, pocket bursts + "FUSED" floaters, door-open banner,
  Shep thrust trail, screen shake on wall hits, win flash. Direct SFX and music still play.
- **Screens:** restyled title, level select (same unlock rules + preview + trophy), pause,
  victory, defeat, help, and credits. In-game Pause still freezes the Direct world the way
  the Flex pause did. Esc opens the arcade PauseOverlay (tree pause). "Back to Arcade" is
  top-left and never takes keyboard focus.
- **Scores:** shared `user://shep_scores.cfg` with Direct so unlocks and best times carry over.
- Direct's in-field LED clock is hidden; the Enhanced HUD shows the same `secs_left()` text.

### Deltas vs Direct

| | Direct | Enhanced |
|---|---|---|
| Rules / physics | `shep_world.gd` | same instance class (preload), no copy |
| Levels / unlocks | `shep_levels.gd` + SharedObject scores | same |
| Stage | 800×575 Flex shell | 1280×720 chrome around the same 800×575 field |
| Fuse / ship readouts | Flash clips / PNGs only | color rings, aim assist, fuse counter, dock hint |
| Menus | original screen PNGs + Halo buttons | procedural cards |
| Juice | blur / glow / pocket squeeze | trails, sparks, floaters, shake (on top of Direct) |

### Deferred
- No re-drawn sprites or new audio assets.
- No touch / gamepad controls beyond what Direct already accepts.
- No dedicated Enhanced gallery preview in this PR (card can use the Direct shot).

Tests: `tools/test_shep_enhanced.gd` (run by `tools/smoke_headless.sh`): registry entry,
scene launch + letterbox, Direct world ownership, title → level select → play, Pause freezes
the world, pocket/kick juice, Esc → PauseOverlay → Back to Arcade, and a shared-World physics
win on the Direct test room SVG.
