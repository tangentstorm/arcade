# typing.deck — port notes

| | |
|---|---|
| Source | https://tangentstorm.github.io/decks/typing.html (Decker) |
| Author | tangentstorm |
| Pitch | Falling-words typer: type letters before words hit the bottom |
| Issue | #109 |

## Direct edition (`direct/`) — playable

- Soft stage **512×342** (Decker card size), letterboxed, nearest-neighbor UI.
- Home: poem, Play (or Enter), word-list picker, keyboard layout picker.
- Game: start word `go`; letter-by-letter input; correct advances, wrong flashes nope; complete word → score + next falling word.
- Words fall only after first success; speed starts 0, +1 every 5 scored words (`LVL_WORDS`); win at 15 (`WIN_WORDS` from game.0 — welcome text says 50).
- Fail when word reaches bottom; in-game pause toggle; score + speed HUD.
- Esc → arcade PauseOverlay (not stolen).

### Files

- `direct/typing_logic.gd` — pure state / rules
- `direct/words.gd` — word lists + keyboard layouts
- `direct/typing_gfx.gd` — Arne-ish palette helpers
- `direct/game.gd` / `game.tscn` — Control UI

### Enhanced

`"enhanced": "planned"` only — no enhanced scene in this PR.

## Out of scope (MVP)

- Full Decker config editor UI (itemlist CRUD)
- Scores card / high-score table persistence
- YouTube embed
- Pixel-perfect progressWord outline shader (simple per-letter colors OK)
