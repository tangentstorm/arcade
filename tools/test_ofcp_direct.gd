extends SceneTree
## Offline tests for the OFCP Direct thin client view model (no network).
## Run: godot --headless --path . --script res://tools/test_ofcp_direct.gd

const OfcpTable := preload("res://games/ofcp/direct/ofcp_table.gd")

var fails := 0
var checks := 0


func _initialize() -> void:
	_run()
	print("ofcp direct: %d/%d checks passed" % [checks - fails, checks])
	if fails:
		print("SMOKE FAIL: ofcp direct client tests")
	quit(1 if fails else 0)


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL: ", what)


func c(s: String) -> Dictionary:
	return {"rank": s[0], "suit": s[1]}


func cards(list: Array) -> Array:
	return list.map(func(s): return c(s))


func state(phase: String, hand: Array, brd := {}, cur := 0, fl := false) -> Dictionary:
	var b := {"top": [], "middle": [], "bottom": []}
	for k in brd:
		b[k] = cards(brd[k])
	return {"type": "game_state", "phase": phase, "currentPlayerIndex": cur, "round": 0,
		"mode": "normal", "profile": "normal",
		"you": {"index": 0, "board": b, "hand": cards(hand), "fantasyland": fl},
		"opponents": [{"index": 1, "board": {"top": [], "middle": [], "bottom": []}, "handSize": 5}],
		"scores": [3, -3]}


func _run() -> void:
	var t := OfcpTable.new()
	# not my turn
	t.apply_state(state("INITIAL_PLACE", ["As", "Kd", "Tc", "2h", "9s"], {}, 1))
	ok(not t.is_my_turn(), "AI's turn is not mine")
	ok(not t.place(c("As"), "top"), "cannot place on AI turn")
	ok(t.my_score() == 3, "my score from scores[you.index]")

	# initial 5
	t.apply_state(state("INITIAL_PLACE", ["As", "Kd", "Tc", "2h", "9s"]))
	ok(t.is_my_turn(), "my initial turn")
	ok(t.need_place() == 5, "need 5 initially")
	ok(t.place(c("As"), "top") and t.place(c("Kd"), "top") and t.place(c("Tc"), "top"), "3 to top")
	ok(not t.place(c("2h"), "top"), "top full at 3")
	ok(t.row_space("top") == 0, "top space 0")
	ok(not t.can_submit(), "not submittable at 3/5")
	ok(t.place(c("2h"), "bottom") and t.place(c("9s"), "middle"), "remaining 2")
	ok(t.can_submit(), "submittable at 5/5")
	var m := t.build_submit()
	ok(m.type == "place_initial" and m.placements.size() == 5 and not m.has("discard"), "place_initial msg")
	ok(m.placements[0] == {"card": {"rank": "A", "suit": "s"}, "row": "top"}, "wire encoding")
	ok(t.unplace(c("Kd")) and not t.can_submit(), "unplace")
	ok(not t.place(c("Qh"), "middle"), "cannot place card not in hand")

	# same hand re-sent keeps pending; new hand clears it
	t.apply_state(state("INITIAL_PLACE", ["As", "Kd", "Tc", "2h", "9s"]))
	ok(t.pending.size() == 4, "pending survives identical state")
	t.apply_state(state("PINEAPPLE_PLACE", ["Qh", "Qc", "3d"], {"top": ["As"], "middle": ["Kd", "Tc"], "bottom": ["2h", "9s"]}))
	ok(t.pending.is_empty(), "new hand clears pending")
	ok(t.need_place() == 2, "pineapple needs 2")
	ok(t.place(c("Qh"), "middle") and t.place(c("Qc"), "middle"), "pineapple place 2")
	ok(not t.place(c("3d"), "bottom"), "third card cannot be placed")
	m = t.build_submit()
	ok(m.type == "place_pineapple" and m.placements.size() == 2, "place_pineapple msg")
	ok(m.discard == {"rank": "3", "suit": "d"}, "pineapple discard is unplaced card")

	# hint
	t.clear_pending()
	ok(t.apply_hint({"type": "hint", "placements": [
		{"card": {"rank": "3", "suit": "d"}, "row": "bottom"},
		{"card": {"rank": "Q", "suit": "c"}, "row": "top"}], "discard": {"rank": "Q", "suit": "h"}}), "hint applies")
	ok(t.can_submit() and t.build_submit().discard == {"rank": "Q", "suit": "h"}, "hint → discard")
	ok(not t.apply_hint({"placements": [{"card": {"rank": "A", "suit": "c"}, "row": "top"}]}) and t.pending.is_empty(), "bad hint rejected")

	# auto-fill respects capacity
	t.apply_state(state("PINEAPPLE_PLACE", ["4c", "5c", "6c"], {"top": ["As", "Ks", "Qs"], "middle": ["2c", "3c", "4d", "5d"], "bottom": ["2d", "3d", "4h", "5h"]}))
	t.auto_fill()
	ok(t.can_submit(), "auto_fill fills 2")
	ok(t.row_space("bottom") == 0 and t.row_space("middle") == 0, "auto_fill uses free rows")

	# fantasyland: 14 cards → place 13, discard 1
	var fl := ["As", "Ah", "Ad", "Kc", "Kd", "Ks", "Qc", "Qd", "Qs", "Jc", "Jd", "Js", "Tc", "2d"]
	t.apply_state(state("INITIAL_PLACE", fl, {}, 0, true))
	ok(t.need_place() == 13, "FL needs 13")
	t.auto_fill()
	m = t.build_submit()
	ok(m.placements.size() == 13 and m.discard == {"rank": "2", "suit": "d"}, "FL discard single card")

	# game over
	var go := state("GAME_OVER", [], {"top": ["As", "Ks", "Qs"]})
	go["breakdowns"] = [{"netScore": 6, "rowWins": {"A": 3, "B": 0}, "scoop": "A"}]
	t.apply_state(go)
	ok(t.is_game_over() and not t.is_my_turn(), "game over")
	ok(int(t.breakdown(0).netScore) == 6, "breakdown accessor")
	ok(t.build_submit().is_empty(), "no submit after game over")
	ok(OfcpTable.card_label(c("Th")) == "10♥" and OfcpTable.is_red(c("Th")), "card label")
	ok(OfcpTable.suit_color(c("Ah")) == Color(0.78, 0.08, 0.1), "hearts red")
	ok(OfcpTable.suit_color(c("Ad")) == Color(0.12, 0.35, 0.85), "diamonds blue")
	ok(OfcpTable.suit_color(c("Ac")) == Color(0.08, 0.55, 0.28), "clubs green")
	ok(OfcpTable.suit_color(c("As")) == Color(0.08, 0.08, 0.1), "spades black")
