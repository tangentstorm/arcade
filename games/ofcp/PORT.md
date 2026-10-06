# OFCP — port notes

| | |
|---|---|
| Live server | `wss://ofcp.tangentcode.com/ws` (rules + AI authoritative) |
| Direct | Thin Godot 4 client under `direct/` |
| Offline rules | `shared/` + golden vectors in `tests/golden/` (not in public export) |
| License | Arcade tree MIT; no Alchementrix IP |

## Direct edition (`direct/`) — playable

Thin WebSocket client: lobby overlay, 4-color deck (red hearts, blue diamonds,
green clubs, black spades), placement UI, hint / confirm / clear / new hand.
Modes: **cash/normal**, **windfall**, **progressive** (no poker-site brand names).
Esc → PauseOverlay. Headless smoke does **not** open the live socket.

See `README.md` for protocol, Origin allowlist, and export excludes
(`shared/`, golden tests, AI weights stay out of the public wasm).

## Enhanced edition (`enhanced/`) — playable

A visual/UI makeover of the same thin client. **Nothing is re-implemented:**
`enhanced/game.gd` preloads Direct `game.tscn` and instances it in a 1280×720
SubViewport (shared `ofcp_ws.gd` / `ofcp_table.gd` / `suit_icon.gd`), so dealing,
validation, scoring and the AI stay on the server. Enhanced owns the chrome.

### Visuals / UI
- 1280×720 designed stage, self-fitted to the window (title `scale_mode` stays
  `expand`); felt gradient + suit-colour dust; gold neon frame around the table
- Direct Control fills a native 1280×720 SubViewport, shown at **0.8×**
  (1024×576 field) via `SubViewportContainer.scale` with **`stretch=false`**
  (do not use `stretch=true` to fake half-size — that broke Overlap #78)
- Side HUD: mode (cash/normal · windfall · progressive), phase, score, pending,
  Fantasyland status; 4-color legend
- Juice from Direct table deltas: place sparks, confirm flash, score burst,
  Fantasyland celebration banner
- Title card (Start / Enter / Space, Back to Arcade) and HUD Back to Arcade.
  All buttons `FOCUS_NONE`. **Esc** → PauseOverlay

### Behaviour notes
- Keys and clicks still go to Direct inside the SubViewport.
- Juice only observes Direct: `table.pending`, `phase()`, `my_score()`,
  `is_fantasyland()`, `is_game_over()`, and `profile`.
- Offline / tests: `apply_mock(msg)` feeds a server-shaped dict into Direct's
  `_on_message` (no live socket). Direct already skips connect under headless.
- No Alchementrix IP. No `_enhanced` preview yet (gallery can use the Direct shot).

Tests: `tools/test_ofcp_enhanced.gd` (run by `tools/smoke_headless.sh`): no-rules
copy, launch / title / FOCUS_NONE, SubViewport stretch=false + scale, offline
mock parity vs a bare Direct twin, juice on place / Fantasyland / score, Esc.
