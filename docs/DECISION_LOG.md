# tangentstorm arcade — Decision Log

**Project:** `tangentstorm/arcade`  
**Plan home:** `/workspace/tangentgames-plan/`  
**Rule:** Append-only. One row per decision. Link evidence; do not rewrite history — add a superseding row instead.

| date | decision | alternatives | why | evidence path |
|------|----------|--------------|-----|---------------|
| | | | | |

<!--
Column guide
- date: America/New_York calendar day (YYYY-MM-DD)
- decision: what we chose (imperative, one line)
- alternatives: what we considered and rejected (short)
- why: falsifiable reason tied to constraints or measurements
- evidence path: repo- or plan-relative path (export log, screenshot, curl output, PR URL)

Seed topics to log when implementation starts:
- Godot patch pin (e.g. 4.7.2)
- First Phase C slug
- Manifest format (.tres vs JSON)
- Commit vs CI-regenerate .import files
- Pages deploy method (Actions artifact vs gh-pages branch)
- KEY gzip size gate number
- Custom slim web template yes/no + module allowlist
- License for arcade repo and per-vendored title
-->

| 2026-10-05 | Drop flappy-clone entirely | Recreate classic Flappy / hunt alternate source | Operator: "do not create a new flappy bird." No dedicated source repo. | chat t2u |
| 2026-10-05 | Add OFCP via ofcp bot coordination | Port alone without ofcp bot | Operator asked to coordinate with @ofcp bot for playable OFCP in arcade | chat t1u |
| 2026-10-05 | Create public repo tangentstorm/tangentgames now | Wait until inventory complete | Operator full-autonomy grant; empty repo + scaffold in parallel with inventory | https://github.com/tangentstorm/tangentgames |
| 2026-10-05 | Target Godot 4.7.2.stable | Stay on 4.2 to match b4-gd | Box has 4.7.2; b4-gd migrates forward; latest stable matches "latest version of godot" | /workspace/tools/godot4 --version |
| 2026-10-05 | Restore flappy from unitylabs | Stay dropped / recreate | Operator: flappyclone is in https://github.com/tangentstorm/unitylabs — port that, do not invent | chat t3u |
| 2026-10-05 | Pure GDScript OFCP port + golden vectors; Pages gated on explicit OK | JS bridge / ship to Pages immediately | ofcp bot inventory; private repo secrecy | ofcp bot message |
| 2026-10-05 | Expand multi-game repos into per-game gallery tiles | One tile per repo | Operator: GameSketchLib, gamemaker-stuff, etc. contain multiple games | chat t10u |
| 2026-10-05 | Rename repo tangentstorm/tangentgames → tangentstorm/arcade; display name "tangentstorm arcade"; Pages base path /tangentgames/ → /arcade/ | Keep "Tangent Games" name | Company-name conflict (operator). History preserved via in-place GitHub rename (old URLs redirect); gh-pages branch + legacy Pages source carried over; local checkout moved to /workspace/arcade with /workspace/tangentgames symlink | https://github.com/tangentstorm/arcade · https://tangentstorm.github.io/arcade/ |
| 2026-10-05 | Add Brickslayer (javascriptgamer.com) as planned; build a clean Godot trail system modeled on platform CodeTrail | 1:1 port of the Prototype.js code + tinderblaze HTML trail | Live site is Michal's rehosted original; the only game evidenced is Brickslayer; operator asked for a trail like the original but non-terrible code | /workspace/javascriptgamer-inventory.md |
