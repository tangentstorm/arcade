# Source pointers

Canonical Turbo Pascal tree: https://github.com/tangentstorm/silverware

Local box checkout used for this port: `/workspace/src-inventory/silverware/`

| File | Why |
|---|---|
| `work/doth_a.pas` | Chosen engine root (see ../PORT.md Step 0) |
| `other/dmap1.pic` | Overworld TheDraw screen → `direct/doth_levels.gd` |
| `other/dplay1.pic` / `dplay1.cel` | HUD layout reference |
| `other/dtitle.cel` | Title brick / chrome colour reference |

Nothing under `source/` is loaded at runtime.
