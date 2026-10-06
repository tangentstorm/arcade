# ofcp

Status: **Direct = playable** thin WebSocket client (`direct/`) · **Enhanced = playable** presentation shell (`enhanced/`) · offline rules engine in `shared/`.

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


## Direct edition — thin client over live WSS

`direct/` is a **thin client**: the server at `wss://ofcp.tangentcode.com/ws`
deals, validates, scores and plays the AI. No rules engine or AI weights are
in the public build.

| File | Role |
|------|------|
| `direct/game.tscn` / `game.gd` | Table UI (built in code), lobby overlay, scores, Back to Arcade |
| `direct/ofcp_ws.gd` | `WebSocketPeer` JSON transport |
| `direct/ofcp_table.gd` | View model: latest `game_state`, tentative placements, builds `place_*` messages |
| `direct/suit_icon.gd` | Suit pips drawn with primitives (the web build's font has no ♥♦♣♠) |

**MVP:** heads-up vs 1 AI, cash/normal by default (windfall / progressive selectable
in the lobby). Deal 5 → place on top/middle/bottom → 4 pineapple streets (place 2,
the unplaced 3rd card is discarded) → per-row breakdown + running score → New Hand.
Fantasyland (14 cards → place 13, discard rest) is handled the same way.

Controls: click a hand card, then a row button (or `1`/`2`/`3`, `T`/`M`/`B`).
Click a pending (yellow) card to take it back. `Enter` confirm, `H` hint
(server AI suggestion, applied as pending placements), `Backspace` clear,
`N` new hand. `Esc` = arcade pause.

### Protocol (subset used)

Client → server: `start_vs_ai {aiCount:1, mode:"normal"|"windfall"|"progressive"}`,
`start_game`, `place_initial {placements[, discard]}`, `place_pineapple {placements[2], discard}`,
`get_hint`, `new_hand`.
Server → client: `connected {playerId, sessionId}`, `waiting`, `ready {players, mode, profile}`,
`game_state {phase, currentPlayerIndex, round, you{index,board,hand,fantasyland}, opponents[], scores[], breakdowns?}`,
`hint {placements, discard}`, `flagged`, `error {message}`.
Card = `{"rank":"2".."9"|"T"|"J"|"Q"|"K"|"A","suit":"h"|"d"|"c"|"s"}`; rows `top|middle|bottom`.

### Origin / where it works

The server only accepts WebSocket upgrades whose `Origin` is
`https://tangentstorm.github.io` (any path, e.g. `/arcade/`) or `http://localhost[:port]` /
`http://127.0.0.1[:port]`. Anything else (or no Origin) gets **HTTP 403**.

- **Pages (production):** https://tangentstorm.github.io/arcade/ → OFCP → **Direct** → *Play vs AI*.
  Only works once this branch is merged to `main` and the Pages workflow has deployed.
- **Local web build:** export, then serve from localhost (allowed origin):
  ```bash
  /workspace/tools/godot4 --headless --path . --export-release "Web" build/web/index.html
  cd build/web && python3 -m http.server 8000   # open http://localhost:8000/
  ```
  Opening the page from any other host (LAN IP, other domain, `file://`) → 403.
- **Godot editor / desktop / headless:** native `WebSocketPeer` sends no Origin by
  default, which the server rejects with 403. `ofcp_ws.gd` therefore sends
  `Origin: http://localhost` on non-web platforms (a dev origin the server allows).
  If the server's allowlist ever drops localhost, native runs will 403 and only the
  github.io build will connect. Headless runs of the scene (smoke tests) do **not** connect.

### Tests

```bash
# offline view-model tests (part of tools/smoke_headless.sh)
/workspace/tools/godot4 --headless --path . --script res://tools/test_ofcp_direct.gd
# MANUAL: play one full hand vs the live server (not in CI — hits production)
/workspace/tools/godot4 --headless --path . --script res://tools/ofcp_live_probe.gd
```

## Enhanced edition — presentation over Direct

`enhanced/` instances Direct `game.tscn` in a 1280×720 SubViewport (`stretch=false` +
scale to a 1024×576 field). Same live client / server — visual juice only (felt chrome,
side HUD, place/score/Fantasyland bursts). Mode labels: cash/normal, windfall, progressive.
Title card + Start + Back to Arcade (`FOCUS_NONE`); Esc → PauseOverlay.
See `PORT.md`. Offline tests use `apply_mock` (no live socket).

```bash
/workspace/tools/godot4 --headless --path . --script res://tools/test_ofcp_enhanced.gd
```

### Public export

`export_presets.cfg` now **includes** `games/ofcp/direct/` and still excludes
`games/ofcp/shared/*` (offline rules), `games/ofcp/tests/*` (golden vectors),
`games/ofcp/*.md`, and any `ai/`, `*champion*`, `*weights*`, `*.json` under `games/ofcp/`.
