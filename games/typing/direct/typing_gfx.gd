extends RefCounted
## Arne-ish palette helpers for typing.deck flashes.

# Approximate Decker Arne theme indices used in game.0:
# WHT:32 BLK:47 RED:34 GRN:42 — and DONE uses blue.
const WHT := Color("#ffffff")
const BLK := Color("#1a1c2c")
const RED := Color("#e43b44")
const GRN := Color("#3e8948")
const BLU := Color("#0099db")
const GRAY := Color("#8b9bb4")
const PANEL := Color("#262b44")
const STAGE := Color("#c0cbdc")
const INK := Color("#1a1c2c")
const TYPED := Color("#3e8948")
const CUR := Color("#f77522")
const KEY_BG := Color("#5a6988")
const KEY_HL := Color("#f9c22b")


static func flash_colors(kind: String) -> Dictionary:
	## Returns {fg, bg} for screen flash overlays.
	match kind:
		"nope":
			return {"fg": BLK, "bg": RED}
		"fail":
			return {"fg": WHT, "bg": BLK}
		"level":
			return {"fg": BLK, "bg": GRN}
		"win":
			return {"fg": WHT, "bg": BLU}
		_:
			return {"fg": INK, "bg": STAGE}
