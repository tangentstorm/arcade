extends RefCounted
## Client-side view model for one OFCP seat. Holds the latest server
## game_state, the player's tentative placements, and builds the outgoing
## place_initial / place_pineapple messages. No rules engine: the server is
## authoritative and validates every move.
##
## Wire encoding (see games/ofcp/RULES-SPEC.md): a card is
## {"rank": "2".."9"|"T"|"J"|"Q"|"K"|"A", "suit": "h"|"d"|"c"|"s"};
## rows are "top" (3), "middle" (5), "bottom" (5).

const ROWS := ["top", "middle", "bottom"]
const ROW_CAP := {"top": 3, "middle": 5, "bottom": 5}
const PHASE_INITIAL := "INITIAL_PLACE"
const PHASE_PINEAPPLE := "PINEAPPLE_PLACE"
const PHASE_GAME_OVER := "GAME_OVER"
const SUIT_GLYPH := {"h": "♥", "d": "♦", "c": "♣", "s": "♠"}

var state: Dictionary = {}
## Tentative placements for the current turn: [{card, row}], in click order.
var pending: Array = []


static func card_str(c: Dictionary) -> String:
	return "%s%s" % [c.get("rank", "?"), c.get("suit", "?")]


static func card_label(c: Dictionary) -> String:
	var r: String = c.get("rank", "?")
	if r == "T":
		r = "10"
	return r + SUIT_GLYPH.get(c.get("suit", ""), "?")


static func is_red(c: Dictionary) -> bool:
	return c.get("suit", "") in ["h", "d"]


static func card_eq(a: Dictionary, b: Dictionary) -> bool:
	return a.get("rank") == b.get("rank") and a.get("suit") == b.get("suit")


static func wire_card(c: Dictionary) -> Dictionary:
	return {"rank": String(c.get("rank", "")), "suit": String(c.get("suit", ""))}


## Store a new game_state. Pending placements survive only if the hand is unchanged.
func apply_state(msg: Dictionary) -> void:
	var old_hand := hand()
	state = msg
	var new_hand := hand()
	if not _same_cards(old_hand, new_hand) or not is_my_turn():
		pending.clear()


func phase() -> String:
	return String(state.get("phase", ""))


func you() -> Dictionary:
	return state.get("you", {})


func hand() -> Array:
	return you().get("hand", [])


func board() -> Dictionary:
	return you().get("board", {"top": [], "middle": [], "bottom": []})


func opponents() -> Array:
	return state.get("opponents", [])


func scores() -> Array:
	return state.get("scores", [])


func my_index() -> int:
	return int(you().get("index", 0))


func my_score() -> int:
	var s := scores()
	var i := my_index()
	return int(s[i]) if i >= 0 and i < s.size() else 0


func is_fantasyland() -> bool:
	return bool(you().get("fantasyland", false))


func is_game_over() -> bool:
	return phase() == PHASE_GAME_OVER


func is_my_turn() -> bool:
	var ph := phase()
	if ph != PHASE_INITIAL and ph != PHASE_PINEAPPLE:
		return false
	return int(state.get("currentPlayerIndex", -1)) == my_index() and hand().size() > 0


## How many cards the player must place this turn (rest are discarded).
func need_place() -> int:
	if not is_my_turn():
		return 0
	if phase() == PHASE_PINEAPPLE:
		return 2
	if is_fantasyland() and hand().size() >= 14:
		return 13 - board_count()
	return hand().size()


func board_count() -> int:
	var b := board()
	var n := 0
	for r in ROWS:
		n += (b.get(r, []) as Array).size()
	return n


func row_cards(row: String) -> Array:
	return board().get(row, [])


func pending_in_row(row: String) -> Array:
	var out: Array = []
	for p in pending:
		if p.row == row:
			out.append(p.card)
	return out


func row_space(row: String) -> int:
	return ROW_CAP[row] - row_cards(row).size() - pending_in_row(row).size()


func is_pending(c: Dictionary) -> bool:
	for p in pending:
		if card_eq(p.card, c):
			return true
	return false


## Hand cards not yet tentatively placed.
func unplaced() -> Array:
	var out: Array = []
	for c in hand():
		if not is_pending(c):
			out.append(c)
	return out


func place(c: Dictionary, row: String) -> bool:
	if not is_my_turn() or not ROW_CAP.has(row):
		return false
	if is_pending(c) or not _in_hand(c):
		return false
	if pending.size() >= need_place() or row_space(row) <= 0:
		return false
	pending.append({"card": c, "row": row})
	return true


func unplace(c: Dictionary) -> bool:
	for i in pending.size():
		if card_eq(pending[i].card, c):
			pending.remove_at(i)
			return true
	return false


func clear_pending() -> void:
	pending.clear()


func can_submit() -> bool:
	return is_my_turn() and pending.size() == need_place()


## Message for the current turn, or {} if not ready.
func build_submit() -> Dictionary:
	if not can_submit():
		return {}
	var placements: Array = []
	for p in pending:
		placements.append({"card": wire_card(p.card), "row": p.row})
	var rest: Array = []
	for c in unplaced():
		rest.append(wire_card(c))
	if phase() == PHASE_PINEAPPLE:
		return {"type": "place_pineapple", "placements": placements, "discard": rest[0]}
	var msg := {"type": "place_initial", "placements": placements}
	if rest.size() == 1:
		msg["discard"] = rest[0]
	elif rest.size() > 1:
		msg["discard"] = rest
	return msg


## Replace pending placements with a server hint. Returns true if applied.
func apply_hint(msg: Dictionary) -> bool:
	if not is_my_turn():
		return false
	var hint_pl: Array = msg.get("placements", [])
	clear_pending()
	for p in hint_pl:
		if not (p is Dictionary) or not p.has("card"):
			continue
		var c := _find_in_hand(p.card)
		if c.is_empty() or not place(c, String(p.get("row", ""))):
			clear_pending()
			return false
	return true


## Last hand's breakdown vs opponent i (only present at GAME_OVER).
func breakdown(i: int = 0) -> Dictionary:
	var b: Array = state.get("breakdowns", [])
	return b[i] if i >= 0 and i < b.size() else {}


## Auto-placement used by headless probes: first free rows bottom→top.
func auto_fill() -> void:
	clear_pending()
	for c in unplaced():
		if pending.size() >= need_place():
			break
		for r in ["bottom", "middle", "top"]:
			if place(c, r):
				break


func _in_hand(c: Dictionary) -> bool:
	return not _find_in_hand(c).is_empty()


func _find_in_hand(c) -> Dictionary:
	if not (c is Dictionary):
		return {}
	for h in hand():
		if card_eq(h, c):
			return h
	return {}


static func _same_cards(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not card_eq(a[i], b[i]):
			return false
	return true
