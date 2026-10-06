extends SceneTree
## Headless checks for the mineswpr direct port (rules from mineswpr.org).
## Run: godot --headless --path . --script res://tools/test_mineswpr.gd

const Logic := preload("res://games/mineswpr/direct/mineswpr_logic.gd")
const Shell := preload("res://games/mineswpr/direct/mswp_shell.gd")
const Screen := preload("res://games/mineswpr/direct/mineswpr_screen.gd")
const TermGrid := preload("res://games/_shared/term_grid.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: mineswpr ", msg)
		_fail += 1


func _initialize() -> void:
	# -- game-new: 16x16, 24 mines, everything covered, hints consistent
	var g = Logic.new(1234)
	var mines := 0
	var hints_ok := true
	for i in Logic.W * Logic.H:
		if g.has(i, Logic.MINE): mines += 1
		var p := Logic.c2xy(i)
		var n := 0
		for d in Logic.NEIGHBORS:
			var q: Vector2i = p + d
			if Logic.inbounds(q.x, q.y) and g.has(Logic.cell(q.x, q.y), Logic.MINE): n += 1
		if g.armed_neighbor_count(i) != n: hints_ok = false
	_check(mines == 24, "game-new places 24 mines (%d)" % mines)
	_check(g.covered_count() == 256, "all 256 cells start covered")
	_check(hints_ok, "armed-neighbor-count matches the 8 neighbors for every cell")
	_check(not g.game_over and g.flag_count == 0, "fresh game: not over, no flags")

	# -- floodfill spreads through cardinal neighbors of zero cells only
	var f = Logic.new(1)
	f.load_mines([Logic.cell(2, 2)])
	f.prod(Logic.cell(0, 0))
	_check(f.has(Logic.cell(2, 2), Logic.COVER), "flood never uncovers the mine")
	_check(not f.has(Logic.cell(15, 15), Logic.COVER), "flood reaches far corner")
	# (1,1) touches the mine diagonally from (2,2): it's a hint cell next to zeros, revealed
	_check(not f.has(Logic.cell(1, 1), Logic.COVER), "hint cell next to a zero cell is uncovered")
	_check(f.covered_count() == 1, "one mine on the board: everything else uncovered (%d covered)" % f.covered_count())
	_check(f.cleared(), "cleared() true when only mines are covered")

	# cardinal-only: mines at (1,0) and (0,1). (2,2) is a zero cell, but (1,1)
	# (count 2) is only its *diagonal* neighbor, so the original flood never
	# reaches it (classic Minesweeper would uncover it).
	var d = Logic.new(1)
	d.load_mines([Logic.cell(1, 0), Logic.cell(0, 1), Logic.cell(5, 5)])
	d.prod(Logic.cell(10, 10))
	_check(d.has(Logic.cell(0, 0), Logic.COVER), "(0,0) behind cardinal mine wall stays covered")
	_check(not d.has(Logic.cell(2, 2), Logic.COVER) and d.has(Logic.cell(1, 1), Logic.COVER),
		"diagonal hint (1,1) of zero cell (2,2) stays covered (cardinal-only flood)")

	# hint cell prod uncovers just that cell
	var h = Logic.new(1)
	h.load_mines([Logic.cell(3, 3)])
	h.prod(Logic.cell(3, 4))
	_check(h.covered_count() == 255, "prodding a hint cell uncovers only it")
	_check(h.armed_neighbor_count(Logic.cell(3, 4)) == 1, "hint value 1")

	# flags: flag+ / flag- / prod removes the flag; flood uncovers flagged cells but keeps the flag
	var fl = Logic.new(1)
	fl.load_mines([Logic.cell(8, 8)])
	fl.flag_add(Logic.cell(0, 5))
	fl.flag_add(Logic.cell(0, 5))
	_check(fl.flag_count == 1, "flag+ twice counts once")
	fl.prod(Logic.cell(0, 0))
	_check(not fl.has(Logic.cell(0, 5), Logic.COVER) and fl.has(Logic.cell(0, 5), Logic.FLAG),
		"flood uncovers a flagged cell but keeps the flag bit")
	fl.flag_add(Logic.cell(0, 6))
	_check(fl.flag_count == 1, "can't flag an uncovered cell")
	fl.flag_remove(Logic.cell(0, 5))
	_check(fl.flag_count == 0, "flag- removes it")
	fl.flag_add(Logic.cell(8, 8))
	fl.prod(Logic.cell(8, 8))
	_check(fl.game_over and not fl.has(Logic.cell(8, 8), Logic.FLAG) and fl.flag_count == 0,
		"prod on a flagged mine removes the flag and detonates")

	# -- the mswp' command parser
	var s = Logic.new(7)
	s.load_mines([Logic.cell(15, 15)])
	var sh = Shell.new(s)
	sh.eval_line("5 C +")
	_check(s.has(Logic.cell(5, 12), Logic.FLAG) and s.flag_count == 1, "'5 C +' flags (5,12)")
	_check(s.active_cell == Logic.cell(5, 12), "command sets active-cell")
	sh.eval_line("5 c -")
	_check(s.flag_count == 0, "'5 c -' unflags (lowercase c word = $C)")
	sh.eval_line("a b +")
	_check(s.has(Logic.cell(10, 11), Logic.FLAG), "'a b +' flags (10,11)")
	sh.eval_line("10 0 ?")
	_check(sh.stack.is_empty() and s.covered_count() == 256, "out of bounds x=$10 is dropped")
	sh.eval_line("3")
	sh.eval_line("4 ?")
	_check(not s.has(Logic.cell(3, 4), Logic.COVER), "stack persists across lines ('3' then '4 ?')")
	sh.eval_line("2 +")
	_check(sh.stack == [2], "command with one number does nothing, leaves it on the stack")
	sh.eval_line("reset")
	_check(sh.stack.is_empty(), "reset clears the stack")
	sh.eval_line("zz")
	_check(sh.last_error == "zz ?", "unknown word reports 'zz ?'")
	sh.eval_line("F F ?")
	_check(s.game_over, "'F F ?' hits the mine: game over")
	sh.eval_line("r")
	_check(not s.game_over and s.covered_count() == 256, "'r' starts a new game")
	var quits := [0]
	sh.quit_requested.connect(func() -> void: quits[0] += 1)
	sh.eval_line("q")
	_check(quits[0] == 1, "'q' requests quit")
	_check(Shell.parse_hex("1F") == 31 and Shell.parse_hex("-2") == -2 and Shell.parse_hex("xyz") == null,
		"hex number parsing")

	# -- screen layout matches the original draw/show words
	var t = TermGrid.new()
	var v = Logic.new(3)
	v.load_mines([Logic.cell(0, 0)])
	var vs = Shell.new(v)
	vs.eval_line("1 0 ?")
	var active: int = v.active_cell
	Screen.render(t, v, vs, {"active": active})
	_check(t.row_text(0).strip_edges() == "MINESWPR.RXE", "title row")
	_check(t.row_text(1).begins_with(Screen.DASHES), "dash row")
	_check(t.row_text(2).begins_with("     0   1   2"), "hex header row")
	_check(t.row_text(3).begins_with("  0 [-] [1] [-]"), "row 0 cells: '%s'" % t.row_text(3).left(20))
	_check(t.fg_at(5, 3) == Screen.w and t.fg_at(9, 3) == Screen.B, "covered '-' gray, hint digit bright blue")
	_check(t.fg_at(8, 3) == Screen.m, "active cell gets magenta brackets")
	_check(t.fg_at(12, 3) == Screen.c and t.fg_at(12, 4) == Screen.K, "striped brackets: even rows cyan, odd dark gray")
	_check(t.row_text(18).begins_with("  F "), "last row label F")
	_check(t.row_text(20).begins_with("type cmd at 'ok':  + = flag"), "help row")
	_check(t.row_text(24).begins_with("ok "), "ok prompt row")
	vs.eval_line("0 0 ?")
	Screen.render(t, v, vs, {})
	_check(t.row_text(0).strip_edges() == "GAME OVER!", "GAME OVER title")
	_check(t.char_at(5, 3) == "X" and t.fg_at(5, 3) == Screen.r and t.fg_at(4, 3) == Screen.k,
		"mine shown as red X with hidden brackets after game over")
	_check(t.row_text(23).contains("game over. type r  to restart"), "game over hint row")
	var pt: Vector2i = Screen.board_point(4 + 4 * 5 + 1, 3 + 12)
	_check(pt == Vector2i(5, 12), "screen -> board point mapping")
	_check(Screen.board_point(2, 5) == Vector2i(-1, -1), "row label isn't a cell")
	t.free()
	quit(1 if _fail else 0)
