extends SceneTree
## Headless checks for the terratri direct port.
## Mirrors src/shared/terratri.test.ts + Game.test.ts (tangentstorm/terratri@7c20663)
## and replays golden playouts recorded from the original TS Game class
## (tools/golden/terratri_playouts.json, generator: games/terratri/source/gen_golden.mjs).
## Run: godot --headless --path . --script res://tools/test_terratri.gd

const R := preload("res://games/terratri/direct/terratri_rules.gd")
const Game := preload("res://games/terratri/direct/terratri_game.gd")
const In := preload("res://games/terratri/direct/terratri_input.gd")
const GOLDEN := "res://tools/golden/terratri_playouts.json"

var _fail := 0
var _pass := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("ok: ", msg)
	else:
		_fail += 1
		print("SMOKE FAIL: terratri ", msg)


func _eq(got, want, msg: String) -> void:
	_check(got == want, "%s (got %s, want %s)" % [msg, var_to_str(got), var_to_str(want)] if got != want else msg)


## Ordered "k:v k:v" rendering, same as the golden generator.
func _vs(d: Dictionary) -> String:
	var parts: Array = []
	for k in d:
		parts.append("%s:%s" % [k, d[k]])
	return " ".join(parts)


func _initialize() -> void:
	_unit_terratri()
	_unit_game()
	_unit_input()
	_golden()
	_fort_win_ui_scene.call_deferred()


func _unit_terratri() -> void:
	# whoseTurn uses | delimiters
	for c in [["", "r"], ["n", "r"], ["ns|", "b"], ["ns|S", "b"], ["ns|SS|", "r"]]:
		_eq(R.whose_turn(c[0]), c[1], "whoseTurn('%s')" % c[0])

	var b := "  __ " + "  bB " + " r   " + " .   " + " R.  "
	var g := [[" ", " ", "_", "_", " "], [" ", " ", "b", "B", " "], [" ", "r", " ", " ", " "],
		[" ", ".", " ", " ", " "], [" ", "R", ".", " ", " "]]
	_eq(R.board_to_grid(b), g, "boardToGrid")
	_eq(R.grid_to_board(g), b, "gridToBoard")

	var start := R.start_grid()
	_eq(R.find_pawn("b", start), {"x": 2, "y": 0, "has_fort": false}, "findPawn b at start")
	_eq(R.find_pawn("r", start), {"x": 2, "y": 4, "has_fort": false}, "findPawn r at start")

	_eq(R.after("nn|EF|fe|SF|"), R.board_to_grid("  _B " + "   L " + "  Rr " + "  .  " + "  .  "),
		"after skips | (nn|EF|fe|SF|)")
	_eq(R.after("nk|"), R.after("nx|"), "k has no board effect")

	_eq(_vs(R.valid_steps("r", R.start_grid(), "")), "n:c2 e:d1 w:b1", "validSteps first move")
	_eq(R.valid_steps("r", R.after("n"), "n"),
		{"n": "c3", "e": "d2", "w": "b2", "s": "c1", "x": "end", "k": "bank"},
		"validSteps second step includes bank")
	_eq(R.valid_steps("b", R.after("ns|"), "ns|"), {"S": "c4", "E": "d5", "W": "b5"},
		"validSteps blue first move")
	_eq(R.valid_steps("r", R.after("ns|SN|"), "ns|SN|"), {"n": "c2", "e": "d1", "w": "b1"},
		"validSteps red second turn")
	_eq(R.valid_steps("r", R.after("ns|SN|n"), "ns|SN|n"),
		{"n": "c3", "e": "d2", "w": "b2", "x": "end", "k": "bank"},
		"validSteps anti-reversal blocks return to start")

	_eq(R.banked_moves("b", ""), 1, "bankedMoves blue starts with 1")
	_eq(R.banked_moves("r", ""), 0, "bankedMoves red starts with 0")
	_eq(R.banked_moves("r", "nk|"), 1, "bankedMoves nk|")
	_eq(R.banked_moves("r", "nk|SN|nk|"), 2, "bankedMoves banks twice")
	_eq(R.banked_moves("b", "ns|SWN|"), 0, "bankedMoves blue spends bonus")
	_eq(R.banked_moves("b", "ns|SWX|"), 1, "bankedMoves pass at step 2 is free")

	_eq(R.spent_moves("r", ""), 0, "spentMoves empty")
	_eq(R.spent_moves("b", "ns|SWN|"), 1, "spentMoves SWN")
	_eq(R.spent_moves("b", "ns|SWX|"), 0, "spentMoves SWX")

	_eq(R.fort_supply("r", R.start_grid(), ""), 5, "fortSupply red start")
	_eq(R.fort_supply("b", R.start_grid(), ""), 4, "fortSupply blue start (1 banked)")
	_eq(R.fort_supply("b", R.after("ns|SWN|"), "ns|SWN|"), 5, "fortSupply after spending bank")

	_eq(R.is_turn_over(""), false, "isTurnOver ''")
	_eq(R.is_turn_over("n"), false, "isTurnOver n")
	_eq(R.is_turn_over("nx"), true, "isTurnOver nx")
	_eq(R.is_turn_over("nk"), true, "isTurnOver nk")
	_eq(R.is_turn_over("ns"), true, "isTurnOver ns (red no bank)")
	_eq(R.is_turn_over("ns|SW"), false, "isTurnOver blue with bank continues")
	_eq(R.is_turn_over("ns|SWN"), true, "isTurnOver blue bank depleted")
	_eq(R.is_turn_over("ns|SWX"), true, "isTurnOver pass during bonus")

	var gf := R.after("nn|EF|fe|SF|")
	_eq(R.count_forts_on_board("r", gf), 1, "countFortsOnBoard r")
	_eq(R.count_forts_on_board("b", gf), 2, "countFortsOnBoard b")

	_eq(R.valid_steps("b", R.after("ns|S"), "ns|S").get("X"), "end", "blue 2nd step has X")
	var vs3 := R.valid_steps("b", R.after("ns|SW"), "ns|SW")
	_eq(vs3.get("X"), "end", "blue bonus step has X")
	_check(not vs3.has("K"), "no bank option at step index >= 2")
	if R.grid_to_board(R.after("ns|S")) == R.grid_to_board(R.after("ns|SWE")):
		_check(not vs3.has("E"), "anti-reversal during bonus actions")
	if R.grid_to_board(R.after("ns|")) == R.grid_to_board(R.after("ns|SWE")):
		_check(not R.valid_steps("b", R.after("ns|SWE"), "ns|SWE").has("X"),
			"end blocked if board unchanged during bonus")

	_eq(R.nice_history(""), [], "niceHistory ''")
	_eq(R.nice_history("nx|"), ["nx"], "niceHistory nx|")
	_eq(R.nice_history("nx|SW|"), ["nx SW"], "niceHistory nx|SW|")
	_eq(R.nice_history("nx|SW|en|"), ["nx SW", "en"], "niceHistory 3 turns")
	_eq(R.nice_history("nx|SW|en|SE|"), ["nx SW", "en SE"], "niceHistory 4 turns")
	_eq(R.nice_history("nx|SW|en"), ["nx SW", "en"], "niceHistory incomplete")

	# Extras (not in the TS suite): square names, fort winner.
	_eq(R.sq(2, 4), "c1", "sq(2,4) == c1")
	_eq(R.sq_to_xy("d5"), Vector2i(3, 0), "sq_to_xy d5")
	_eq(R.sq_to_xy("end"), Vector2i(-1, -1), "sq_to_xy end")
	_eq(R.winner(R.board_to_grid("RRRRE" + "     " + "  b  " + "     " + "     ")), "r", "winner r with 5 forts")
	_eq(R.winner(R.board_to_grid("BBBBL" + "     " + "  r  " + "     " + "     ")), "b", "winner b with 5 forts")
	_eq(R.winner(R.board_to_grid("RRRR " + "     " + "  b  " + "     " + "  r  ")), "", "4 forts: no winner")


func _unit_game() -> void:
	var g := Game.new()
	_eq(g.steps, "", "Game() steps")
	_eq(g.board, R.START_BOARD, "Game() board")
	_eq(g.whose_turn, "r", "Game() whoseTurn")
	_eq(g.winner, "", "Game() winner null")
	_eq([g.red_banked, g.blue_banked, g.red_supply, g.blue_supply], [0, 1, 5, 4], "Game() banks/supplies")
	_eq(g.history, [], "Game() history")

	var g2 := Game.new("ns|")
	_eq(g2.whose_turn, "b", "Game('ns|') whoseTurn")
	_eq(g2.history, ["ns"], "Game('ns|') history")

	var g1 = g.apply_step("n")
	_eq(g1.steps, "n", "applyStep n")
	_eq(g1.whose_turn, "r", "applyStep mid-turn")
	_eq(g.steps, "", "applyStep does not mutate original")
	_eq(g.board, R.START_BOARD, "original board untouched")
	var g3 = g.apply_step("n").apply_step("s")
	_eq(g3.steps, "ns|", "applyStep appends | when turn over")
	_eq(g3.whose_turn, "b", "blue after ns|")
	var g4 = g3.apply_step("S").apply_step("N")
	_eq(g4.steps, "ns|SN", "blue with bank continues after SN")
	_eq(g4.whose_turn, "b", "still blue mid-bonus")
	_eq(g4.history, ["ns SN"], "history ns SN")
	_check(g.valid_steps.has("n"), "validSteps populated")

	var won := Game.new("nn|EF|fe|SF|")
	_check(won.winner == "" and not won.valid_steps.is_empty(), "no winner -> has valid steps")

	_eq(Game.at_step("ns|SN|", 0).steps, "", "atStep 0")
	_eq(Game.at_step("ns|SN|", 0).board, R.START_BOARD, "atStep 0 board")
	_eq(Game.at_step("ns|SN|", 1).steps, "n", "atStep 1")
	_eq(Game.at_step("ns|SN|", 2).steps, "ns|", "atStep 2")
	_eq(Game.at_step("ns|SN|", 3).steps, "ns|S", "atStep 3")
	_eq(Game.at_step("ns|SN|", 4).steps, "ns|SN|", "atStep 4")
	var gk = Game.at_step("nk|SN|", 2)
	_eq(gk.steps, "nk|", "atStep with bank")
	_eq(gk.red_banked, 1, "atStep with bank -> redBanked 1")


func _unit_input() -> void:
	var v := R.valid_steps("r", R.after("n"), "n")
	_eq(In.step_for_cell(v, Vector2i(2, 2)), "n", "click c3 -> n")
	_eq(In.step_for_cell(v, Vector2i(2, 4)), "s", "click c1 -> s")
	_eq(In.step_for_cell(v, Vector2i(0, 0)), "", "click far cell -> nothing")
	_eq(In.step_for_action(v, "k"), "k", "bank action")
	var vb := R.valid_steps("b", R.after("ns|S"), "ns|S")
	_eq(In.step_for_action(vb, "x"), "X", "blue end action is uppercase")
	_eq(In.step_for_action(vb, "f"), "", "no fortify yet")
	_eq(In.clickable_cells(v).size(), 4, "4 clickable cells after n")


func _golden() -> void:
	var f := FileAccess.open(GOLDEN, FileAccess.READ)
	if f == null:
		_check(false, "golden file opens")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var wins := {"r": 0, "b": 0}
	var banked_seen := false
	for game in data.games:
		var g := Game.new()
		var bad := ""
		var states: Array = game.states
		for i in states.size():
			var s: Dictionary = states[i]
			if i > 0:
				var step: String = String(s.steps).replace("|", "").substr(g.step_count(), 1)
				if not g.valid_steps.has(step):
					bad = "step %d '%s' not in validSteps {%s}" % [i, step, _vs(g.valid_steps)]
					break
				g = g.apply_step(step)
			var got := {"steps": g.steps, "board": g.board, "turn": g.whose_turn, "winner": g.winner,
				"rb": g.red_banked, "bb": g.blue_banked, "rs": g.red_supply, "bs": g.blue_supply,
				"valid": _vs(g.valid_steps), "history": ",".join(g.history)}
			for k in got:
				var want = s[k]
				if want is float:
					want = int(want)
				if got[k] != want:
					bad = "state %d field %s: got %s want %s" % [i, k, var_to_str(got[k]), var_to_str(want)]
					break
			if g.red_banked > 0:
				banked_seen = true
			if bad != "":
				break
		_check(bad == "", "golden seed %d: %d states, winner %s %s" % [game.seed, states.size(), game.winner, bad])
		_check(g.winner == game.winner and g.steps == game.final, "golden seed %d final steps + winner" % game.seed)
		if g.winner != "":
			wins[g.winner] += 1
	_check(wins.r > 0 and wins.b > 0, "goldens include fort wins for both sides (%s)" % [wins])
	_check(banked_seen, "goldens exercise red banking")


## Drive the real scene: replay a golden win through the UI's step handler.
func _fort_win_ui_scene() -> void:
	var packed := load("res://games/terratri/direct/game.tscn") as PackedScene
	var ui := packed.instantiate()
	root.add_child(ui)
	await process_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var final: String = data.games[0].final
	for ch in final.replace("|", ""):
		ui.play_step(ch)
	await process_frame
	_eq(ui.game.winner, data.games[0].winner, "UI replay reaches golden winner")
	_check(ui.get_node("%Banner").visible, "win banner shown")
	ui.restart()
	_eq(ui.game.steps, "", "Restart clears steps")
	_check(not ui.get_node("%Banner").visible, "banner hidden after restart")
	ui.play_step("n")
	ui.undo()
	_eq(ui.game.steps, "", "undo first step")
	ui.queue_free()
	await process_frame
	print("terratri: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail else 0)
