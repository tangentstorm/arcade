extends Control
## mineswpr_b4 — arcade host for the b4 TermGrid cart (issue #45 Phase 4).
## Vendors a minimal b4 runtime + mineswpr-logic/play carts from b4-gd; reuses
## mineswpr Direct's TermGrid + Noto font. Esc falls through to PauseOverlay;
## typed `q` returns to the arcade (mineswpr-exit-hook).
##
## Play: hex mswp' commands at the ok prompt (`5 C ?`, `a b +`, `r`, `q`), or
## click (left = `?`, right = `+` / `-`). F2 boots a fresh cart.

const Cart := preload("res://games/mineswpr_b4/direct/b4/MineswprCart.gd")
const BOARD_ROW := 3
const BOARD_COL := 4

@onready var term_grid: Control = %TermGrid

var cart = Cart.new()
var seed_value := -1
var halted := false
var _blink := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--seed":
			seed_value = int(args[i + 1])
	term_grid.cell_clicked.connect(_on_cell_clicked)
	_boot()


func _exit_tree() -> void:
	cart.dispose()


func _boot() -> void:
	halted = false
	var err: String = cart.boot(term_grid, seed_value)
	if err:
		push_error("mineswpr_b4 boot: " + err)


func _process(delta: float) -> void:
	if halted:
		return
	_blink += delta
	if _blink >= 0.5:
		_blink = 0.0
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
	_after(cart.call_word("keys"))
	_blink = 0.0
	get_viewport().set_input_as_handled()


func _on_cell_clicked(col: int, row: int, button: int) -> void:
	if halted:
		return
	var gx := (col - BOARD_COL) / 4
	var gy := row - BOARD_ROW
	if col < BOARD_COL or gx >= 16 or gy < 0 or gy >= 16:
		return
	var op := "?"
	if button == MOUSE_BUTTON_RIGHT:
		op = "-" if cart.is_flagged(gx, gy) else "+"
	elif button != MOUSE_BUTTON_LEFT:
		return
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
