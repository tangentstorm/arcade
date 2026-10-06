extends Control
## mineswpr_b4 — arcade host for the b4 TermGrid cart (issue #45 Phase 4).
## Vendors a minimal b4 runtime + mineswpr-logic/play carts from b4-gd; reuses
## mineswpr Direct's TermGrid + Noto font. Esc falls through to PauseOverlay;
## typed `q` returns to the arcade (mineswpr-exit-hook).
##
## Play: hex mswp' commands at the ok prompt (`5 C ?`, `a b +`, `r`, `q`), or
## click (left = `?`, right = `+` / `-`). F2 boots a fresh cart.
## Hover: the host inks the brackets of the board cell under the mouse Y (11),
## like Direct's hover. It is an overlay, not a cart draw: a full redraw costs
## ~90 ms, too slow for every mouse move. It is lifted before each cart call
## and put back after, so the cart never sees it and its draws never wipe it.

const Cart := preload("res://games/mineswpr_b4/direct/b4/MineswprCart.gd")
const BOARD_ROW := 3
const BOARD_COL := 4
const HOVER_INK := 11 ## Y: Direct's mouse-hover bracket color

@onready var term_grid: Control = %TermGrid

var cart = Cart.new()
var seed_value := -1
var halted := false
var _blink := 0.0
var hover := Vector2i(-1, -1) ## board cell under the mouse, or (-1, -1)
var _lit := [] ## [col, row, fg] of each bracket inked Y, to restore


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--seed":
			seed_value = int(args[i + 1])
	term_grid.cell_clicked.connect(_on_cell_clicked)
	term_grid.cell_hovered.connect(_on_cell_hovered)
	_boot()


func _exit_tree() -> void:
	cart.dispose()


func _boot() -> void:
	halted = false
	_unlight()
	var err: String = cart.boot(term_grid, seed_value)
	if err:
		push_error("mineswpr_b4 boot: " + err)
	_light()


func _process(delta: float) -> void:
	if halted:
		return
	_blink += delta
	if _blink >= 0.5:
		_blink = 0.0
		_unlight()
		_after(cart.call_word("blink"))


func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if e == null or not e.pressed:
		return
	if e.keycode == KEY_F2:
		_boot()
		get_viewport().set_input_as_handled()
		return
	# Esc etc. fall through to PauseOverlay (do not handle KEY_ESCAPE).
	if halted:
		return
	var code := 0
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			code = Cart.KEY_ENTER
		KEY_BACKSPACE:
			code = Cart.KEY_BACKSPACE
		_:
			if e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
				return
			if e.unicode < 32 or e.unicode > 126:
				return
			code = e.unicode
	cart.push_key(code)
	_unlight()
	_after(cart.call_word("keys"))
	_blink = 0.0
	get_viewport().set_input_as_handled()


## Terminal col/row -> board cell (each cell is 4 chars, `[g] `), or (-1, -1).
func _board_cell(col: int, row: int) -> Vector2i:
	var gx := (col - BOARD_COL) / 4
	var gy := row - BOARD_ROW
	if col < BOARD_COL or gx >= 16 or gy < 0 or gy >= 16:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)


func _on_cell_hovered(col: int, row: int) -> void:
	var c := _board_cell(col, row)
	if c != hover:
		_unlight()
		hover = c
		_light()


## Ink the hovered cell's `[` and `]` Y, saving their colors first.
func _light() -> void:
	if hover.x < 0 or halted:
		return
	var y := BOARD_ROW + hover.y
	for x in [BOARD_COL + 4 * hover.x, BOARD_COL + 4 * hover.x + 2]:
		_lit.append([x, y, term_grid.fg_at(x, y)])
		term_grid.put(x, y, term_grid.char_at(x, y), HOVER_INK, _bg_at(x, y))


func _unlight() -> void:
	for s: Array in _lit:
		term_grid.put(s[0], s[1], term_grid.char_at(s[0], s[1]), s[2], _bg_at(s[0], s[1]))
	_lit.clear()


## Direct's TermGrid has no bg_at; read its BGB buffer.
func _bg_at(x: int, y: int) -> int:
	return term_grid.BGB[y * term_grid.grid_wh.x + x]


func _on_cell_clicked(col: int, row: int, button: int) -> void:
	if halted:
		return
	var c := _board_cell(col, row)
	if c.x < 0:
		return
	var gx := c.x
	var gy := c.y
	var op := "?"
	if button == MOUSE_BUTTON_RIGHT:
		op = "-" if cart.is_flagged(gx, gy) else "+"
	elif button != MOUSE_BUTTON_LEFT:
		return
	_unlight()
	_after(cart.exec_line("%X %X %s" % [gx, gy, op]))


func _after(err: String) -> void:
	if cart.vm.ds.size() > 0:
		err = "cart left %s on the data stack" % cart.vm.ds
		cart.vm.ds.clear()
	if err:
		push_warning("mineswpr_b4: " + err)
	if cart.quit_requested():
		halted = true
		GameRegistry.return_to_arcade.call_deferred()
	_light()
