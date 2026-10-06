extends RefCounted
## Shared flat palette (kept close to the original client's orange/blue sides).

const BG := Color("14141c")
const GRID_BG := Color("1e1e2a")
const CELL := Color("2c2c3a")
const LINE := Color("0c0c12")
const TEXT := Color("e8e4dc")
const DIM := Color("8a8698")

const RED := Color("e08040")         # original client .red
const RED_LAND := Color("6e3a1e")
const BLUE := Color("4070c0")        # original client .blue
const BLUE_LAND := Color("1f3560")


static func side_color(side: String) -> Color:
	return RED if side == "r" else BLUE


static func land_color(side: String) -> Color:
	return RED_LAND if side == "r" else BLUE_LAND


static func side_name(side: String) -> String:
	return "Red" if side == "r" else "Blue"
