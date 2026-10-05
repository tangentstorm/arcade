extends RefCounted
## Renders the mineswpr screen into a TermGrid — the `draw` / `show` / `(x,y)`
## words from mineswpr.org ("draw the cells", "draw the playing field").
## Colors are the vt' helpers: |k |r |g |y |b |m |c |w = ANSI 0..7 and the
## uppercase |K |R |G |Y |B |M |C |W = bright 8..15 (cf. tangentlabs/forth/kvm.4th).

const k := 0
const r := 1
const g := 2
const y := 3
const b := 4
const m := 5
const c := 6
const w := 7
const K := 8
const R := 9
const G := 10
const Y := 11
const B := 12
const M := 13
const C := 14
const WW := 15  ## |W

const DASHES := "-------------------------------------------------------------------"
const HEADER := "     0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   "
const BOARD_ROW := 3   ## screen row of grid row 0
const BOARD_COL := 4   ## screen column of grid column 0's '['
const SIDE_COL := 69   ## side panel (not in the original)
const PROMPT_ROW := 24


## Map a screen cell to a minefield point, or (-1,-1).
static func board_point(col: int, row: int) -> Vector2i:
	var gy := row - BOARD_ROW
	var gx := (col - BOARD_COL) / 4
	if col < BOARD_COL or gx >= 16 or gy < 0 or gy >= 16:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)


## A tiny cursor over the TermGrid so the code reads like the Forth (putc/puts).
class Pen:
	var t
	var x := 0
	var row := 0
	var fg := 7

	func _init(term) -> void:
		t = term

	func ink(color: int) -> Pen:
		fg = color
		return self

	func s(text: String) -> Pen:  ## puts / $
		x = t.puts(x, row, text, fg)
		return self

	func cr() -> Pen:
		x = 0
		row += 1
		return self

	func at(col: int, line: int) -> Pen:
		x = col
		row = line
		return self


## view keys: active (cell shown with |m brackets), hover (cell or -1),
## input (prompt text), cursor (bool), last (last command), cleared (bool),
## error (String).
static func render(term, game, shell, view: Dictionary) -> void:
	term.cscr(w, k)
	var p := Pen.new(term)
	# : draw clear gameOver? @ .ifso |R "GAME OVER!" .else |Y "MINESWPR.RXE" .then
	if game.game_over:
		p.ink(R).s("                              GAME OVER! ")
	else:
		p.ink(Y).s("                            MINESWPR.RXE")
	p.ink(b).cr().s(DASHES).ink(w)
	_show(p, game, view)
	p.cr().ink(g).s("type cmd at '").ink(w).s("ok").ink(g).s("':  ") \
		.ink(Y).s("+").ink(c).s(" = flag  ") \
		.ink(Y).s("-").ink(c).s(" = unflag  ") \
		.ink(Y).s("?").ink(c).s(" = prod for mine ") \
		.ink(Y).s("q").ink(c).s(" = quit")
	p.cr().ink(g).s("cmd format: ").ink(Y).s("x y ").ink(c).s("[").ink(Y).s("+-?") \
		.ink(c).s("]").s("   ").ink(g).s("examples: ").ink(w).s("5 C +") \
		.ink(y).s(" a b -").ink(WW).s(" 2 9 ?").ink(R).s(" q") \
		.ink(Y).s("   r ").ink(c).s("= restart ")
	p.ink(b).cr().s(DASHES).ink(K)
	# .s  (on its own line here; see PORT.md)
	p.cr().s(shell.stack_text())
	var err: String = view.get("error", "")
	if err != "":
		p.s("  ").ink(r).s(err)
	if game.game_over:
		p.s("  ").ink(R).s("game over.").ink(r).s(" type ").ink(y).s("r") \
			.ink(r).s("  to restart")
	p.cr().ink(WW).s("ok ").ink(w).s(view.get("input", ""))
	if view.get("cursor", false):
		term.put(p.x, p.row, " ", w, w)
	_side_panel(term, game, view)


## : show  -- header + 16 rows of cells
static func _show(p: Pen, game, view: Dictionary) -> void:
	p.cr().ink(C).s(HEADER).cr()
	for gy in game.H:
		p.s("  ").ink(w if gy % 2 == 1 else C).s("%X" % gy).s(" ")
		for gx in game.W:
			_cell(p, game, gx, gy, view)
		p.cr()


## : (x,y)  -- one cell as "[?] "
static func _cell(p: Pen, game, gx: int, gy: int, view: Dictionary) -> void:
	var cell: int = game.cell(gx, gy)
	var bracket := K if gy % 2 == 1 else c   # make-striped
	if cell == game.flood_cursor:
		bracket = M                          # show-flood-cursor
	var glyph := "-"
	var ink := w
	var hide := false
	if game.has(cell, game.MINE) and game.game_over:
		hide = true; glyph = "X"; ink = r      # mine-draw
	elif game.has(cell, game.FLAG):
		glyph = "!"; ink = R                   # flag-draw
	elif game.has(cell, game.COVER):
		glyph = "-"; ink = w                   # cover-draw (allHints? off)
	else:
		hide = true                            # hint-draw
		var n: int = game.armed_neighbor_count(cell)
		if n == 0:
			glyph = "-"; ink = b
		else:
			glyph = str(n); ink = B
	if hide:
		bracket = k                            # hide-brackets
	if cell == view.get("active", -1):
		bracket = m                            # show-active-cell
	if cell == view.get("hover", -1):
		bracket = Y                            # mouse hover (not in the original)
	p.ink(bracket).s("[").ink(ink).s(glyph).ink(bracket).s("]").s(" ")


## Mouse help + counters, right of the board. Not in the original.
static func _side_panel(term, game, view: Dictionary) -> void:
	var x := SIDE_COL
	term.puts(x, 3, "mouse:", g)
	term.puts(x, 4, "L", Y); term.puts(x + 2, 4, "? prod", c)
	term.puts(x, 5, "R", Y); term.puts(x + 2, 5, "+/- flag", c)
	term.puts(x, 7, "flags", g); term.puts(x + 6, 7, str(game.flag_count), WW)
	term.puts(x, 8, "mines", g); term.puts(x + 6, 8, str(game.MINE_COUNT), WW)
	var last: String = view.get("last", "")
	if last != "":
		term.puts(x, 10, "last:", g)
		term.puts(x, 11, last, w)
	if view.get("cleared", false) and not game.game_over:
		term.puts(x, 13, "ALL CLEAR", G)
	term.puts(x, 18, "Esc", Y); term.puts(x + 4, 18, "menu", c)
