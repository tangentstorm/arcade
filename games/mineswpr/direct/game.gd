extends Control
## mineswpr — Direct edition. Native GDScript port of tangentstorm's
## mineswpr.org (Minesweeper for Retro Forth 11, 2013), drawn on an 80x25
## terminal grid with the original's vt' colors.
##
## Play it the classic way by typing Forth-style commands at the `ok` prompt
## (hex coordinates: `5 C ?`, `a b +`, `r`, `q`), or click: left = `?` (prod),
## right = `+` / `-` (flag toggle). Each click runs the equivalent command.
## Esc is handled globally by the PauseOverlay autoload.

const Logic := preload("res://games/mineswpr/direct/mineswpr_logic.gd")
const Shell := preload("res://games/mineswpr/direct/mswp_shell.gd")
const Screen := preload("res://games/mineswpr/direct/mineswpr_screen.gd")

const MAX_INPUT := 70

var game = Logic.new()
var shell = Shell.new(game)
var input := ""
var last_cmd := ""
var _active := -1      ## active-cell as shown by the last full draw
var _hover := -1
var _error := ""
var _cursor_on := true
var _blink := 0.0

@onready var term: Control = %Term


func _ready() -> void:
	shell.quit_requested.connect(_quit)
	term.cell_clicked.connect(_on_cell_clicked)
	term.cell_hovered.connect(_on_cell_hovered)
	draw_screen()


func _process(delta: float) -> void:
	_blink += delta
	if _blink >= 0.5:
		_blink = 0.0
		_cursor_on = not _cursor_on
		_render()


## Run a command line, then `draw` (the original's `ok` was revectored to draw).
func run(line: String) -> void:
	shell.eval_line(line)
	_error = shell.last_error
	if line.strip_edges() != "":
		last_cmd = line.strip_edges()
	draw_screen()


## Full redraw: like show-active-cell, the active cell is highlighted by this
## draw and then forgotten.
func draw_screen() -> void:
	_active = game.active_cell
	game.active_cell = -1
	_render()


func _render() -> void:
	Screen.render(term, game, shell, {
		"active": _active, "hover": _hover, "input": input,
		"cursor": _cursor_on, "last": last_cmd.left(11),
		"cleared": game.cleared(), "error": _error,
	})


func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if e == null or not e.pressed:
		return
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			var line := input
			input = ""
			run(line)
		KEY_BACKSPACE:
			input = input.left(-1) if input != "" else ""
			_render()
		_:
			if e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
				return
			if e.unicode < 32 or e.unicode > 126:
				return  # Esc etc. fall through to the PauseOverlay
			if input.length() < MAX_INPUT:
				input += char(e.unicode)
			_render()
	_cursor_on = true
	_blink = 0.0
	get_viewport().set_input_as_handled()


func _on_cell_clicked(col: int, row: int, button: int) -> void:
	var pt: Vector2i = Screen.board_point(col, row)
	if pt.x < 0:
		return
	var op := "?"
	if button == MOUSE_BUTTON_RIGHT:
		op = "-" if game.has(game.cell(pt.x, pt.y), game.FLAG) else "+"
	elif button != MOUSE_BUTTON_LEFT:
		return
	run("%X %X %s" % [pt.x, pt.y, op])


func _on_cell_hovered(col: int, row: int) -> void:
	var pt: Vector2i = Screen.board_point(col, row)
	var h: int = game.cell(pt.x, pt.y) if pt.x >= 0 else -1
	if h != _hover:
		_hover = h
		_render()


func _quit() -> void:
	# `q` -> mineswpr-exit-hook (back to the Retro shell; here, the arcade)
	GameRegistry.return_to_arcade.call_deferred()
