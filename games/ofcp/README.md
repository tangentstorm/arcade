# ofcp

Status: **rules engine** (shared GDScript port; no UI / WSS yet).

Pineapple Open Face Chinese Poker rules engine under `shared/`, verified against
golden vectors in `tests/golden/`.

## Shared modules

| File | Role |
|------|------|
| `shared/types.gd` | Cards, boards, categories, helpers |
| `shared/deck.gd` | createDeck / shuffle / deal |
| `shared/hand_eval.gd` | evaluate5 / evaluate3 / compareHands |
| `shared/scoring.gd` | foul, royalties, HU / multi scoring, FL entry |
| `shared/play_profile.gd` | cash/normal, windfall, progressive FL stay & card counts |
| `shared/game.gd` | Pineapple deal / place / score flow |
| `shared/rng_mulberry32.gd` | Seeded mulberry32 + Fisher–Yates (game_flow vectors) |

## Golden suite

```bash
/workspace/tools/godot4 --headless --path . --script res://games/ofcp/tests/run_golden.gd
```

Exit non-zero on any assertion failure. Spec: `RULES-SPEC.md`.

Profile labels only: **cash** (aka **normal**), **windfall**, **progressive**.

`export_presets.cfg` excludes `games/ofcp/*` from the public wasm build.
