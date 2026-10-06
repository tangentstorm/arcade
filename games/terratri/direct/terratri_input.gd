extends RefCounted
## Pure input mapping for the hotseat UI: cells / actions -> step letters.
## Nothing here touches nodes, so the UI stays a thin shell over the rules.

const Rules := preload("res://games/terratri/direct/terratri_rules.gd")

## Abstract actions the keyboard/buttons can ask for.
const ACTIONS := ["n", "s", "e", "w", "f", "x", "k"]


## Step in valid whose target is cell (x, y): a move onto it, or fortify
## when it is the pawn's own square. '' when nothing applies.
static func step_for_cell(valid: Dictionary, cell: Vector2i) -> String:
	var name := Rules.sq(cell.x, cell.y) if Rules.in_bounds(cell.x, cell.y) else ""
	if name == "":
		return ""
	for k in valid:
		if valid[k] == name:
			return k
	return ""


## Step in valid for an abstract action ('n'..'k'), case-insensitive.
static func step_for_action(valid: Dictionary, action: String) -> String:
	for k in valid:
		if String(k).to_lower() == action:
			return k
	return ""


## Board cells (Vector2i) that a click can act on, keyed to their step.
static func clickable_cells(valid: Dictionary) -> Dictionary:
	var out := {}
	for k in valid:
		var p := Rules.sq_to_xy(valid[k])
		if p.x >= 0:
			out[p] = k
	return out


## Human label for a step letter.
static func describe(step: String) -> String:
	match step.to_lower():
		"n": return "north"
		"s": return "south"
		"e": return "east"
		"w": return "west"
		"f": return "fortify"
		"x": return "end turn"
		"k": return "bank"
	return step
