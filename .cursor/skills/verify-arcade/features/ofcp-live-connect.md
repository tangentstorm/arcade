# OFCP live connect

OFCP (Pineapple Open-Face Chinese Poker) Direct is a thin client: the game talks to
`wss://ofcp.tangentcode.com/ws` and plays against the server's AI. A user sees a table, places
cards, and gets a score at game over.

## Sub-features

- `ofcp-connect` the client opens the websocket and receives `game_state`.
- `ofcp-play` placements (`place_initial`, pineapple rounds) are accepted until `GAME_OVER`.
- `ofcp-view-model` the offline view model parses and renders states (no network).

## How to get to it (user POV)

- Gallery (Original) → click the `OFCP` card.
- Pages site → same card (browser origin `tangentstorm.github.io`).

## Driving it with tools/ofcp_live_probe.gd + tools/test_ofcp_direct.gd

Preconditions:

- `$H/launch.sh` OK; network to `ofcp.tangentcode.com` (live server, not ours).

- **Offline model.** `/workspace/tools/godot4 --headless --path . --script res://tools/test_ofcp_direct.gd > "$(cat .cursor/skills/verify-arcade/evidence/.current)/ofcp-offline.log" 2>&1; echo $?` → exit 0, no `SMOKE FAIL`.
- **Live hand.** `timeout 120 /workspace/tools/godot4 --headless --path . --script res://tools/ofcp_live_probe.gd > "$(cat .cursor/skills/verify-arcade/evidence/.current)/ofcp-live.log" 2>&1; echo $?` → ends with
  `<< game_state GAME_OVER`, `hand over: scores=[…]`, `LIVE OK`, exit 0 (≈25 s).
- **In the arcade.** `$H/flow.sh OFCP` proves the card launches and pause/return work (`03-game.png` shows the table).
- **Proof.** `ofcp-offline.log`, `ofcp-live.log`, `flow-OFCP/`.

## Gotchas

- The probe hits a production server; run it once per verification, not in loops, and never in CI.
- Native Godot sends `Origin: http://localhost`; the browser build sends the Pages origin — a live-probe pass does not prove the web origin is allowed.
- Scores vary per hand; assert `LIVE OK` / `GAME_OVER`, not values.
