extends Control
## Terratri direct edition: hotseat 2P shell over terratri_game.gd.
## All rules live in terratri_rules.gd; this script only maps input to step
## letters and copies snapshot fields into labels.
## Esc is handled globally by the PauseOverlay autoload.

const Game := preload("res://games/terratri/direct/terratri_game.gd")
const In := preload("res://games/terratri/direct/terratri_input.gd")
const P := preload("res://games/terratri/direct/palette.gd")

const KEYS := {
	KEY_UP: "n", KEY_W: "n", KEY_DOWN: "s", KEY_S: "s",
	KEY_RIGHT: "e", KEY_D: "e", KEY_LEFT: "w", KEY_A: "w",
	KEY_F: "f", KEY_SPACE: "x", KEY_ENTER: "x", KEY_KP_ENTER: "x", KEY_X: "x",
	KEY_K: "k", KEY_B: "k",
}

var game: RefCounted = Game.new()


func _ready() -> void:
	%RedTray.side = "r"
	%BlueTray.side = "b"
	%Board.cell_clicked.connect(_on_cell)
	%EndButton.pressed.connect(_action.bind("x"))
	%BankButton.pressed.connect(_action.bind("k"))
	%FortButton.pressed.connect(_action.bind("f"))
	%UndoButton.pressed.connect(undo)
	%RestartButton.pressed.connect(restart)
	%BannerRestart.pressed.connect(restart)
	%BackButton.pressed.connect(GameRegistry.return_to_arcade)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if KEYS.has(k.keycode):
		_action(KEYS[k.keycode])
	elif k.keycode == KEY_BACKSPACE or k.keycode == KEY_U or k.keycode == KEY_Z:
		undo()
	elif k.keycode == KEY_R:
		restart()
	else:
		return
	get_viewport().set_input_as_handled()


## Apply step if legal. Returns whether it was played.
func play_step(step: String) -> bool:
	if not game.valid_steps.has(step):
		return false
	game = game.apply_step(step)
	_refresh()
	return true


func undo() -> void:
	if game.step_count() > 0:
		game = Game.at_step(game.steps, game.step_count() - 1)
		_refresh()


func restart() -> void:
	game = Game.new()
	_refresh()


func _action(action: String) -> void:
	play_step(In.step_for_action(game.valid_steps, action))


func _on_cell(cell: Vector2i) -> void:
	play_step(In.step_for_cell(game.valid_steps, cell))


func _refresh() -> void:
	%Board.game = game
	var turn: String = game.whose_turn
	var v: Dictionary = game.valid_steps
	if game.winner != "":
		%Status.text = "%s wins with 5 forts" % P.side_name(game.winner)
		%Status.modulate = P.side_color(game.winner)
	elif v.is_empty():
		%Status.text = "%s has no legal step: Undo or Restart" % P.side_name(turn)
		%Status.modulate = P.side_color(turn)
	else:
		var idx: int = game.step_index()
		var what := "action %d" % (idx + 1) if idx < 2 else "bonus action (spends bank)"
		%Status.text = "%s to move: %s" % [P.side_name(turn), what]
		%Status.modulate = P.side_color(turn)
	%EndButton.disabled = In.step_for_action(v, "x") == ""
	%BankButton.disabled = In.step_for_action(v, "k") == ""
	%FortButton.disabled = In.step_for_action(v, "f") == ""
	%UndoButton.disabled = game.step_count() == 0
	for side in ["r", "b"]:
		var tray = %RedTray if side == "r" else %BlueTray
		tray.placed = game.forts_on_board(side)
		tray.banked = game.banked(side)
		var stats: Label = %RedStats if side == "r" else %BlueStats
		stats.text = "forts %d / 5\nbank %d\nsupply %d" % [
			game.forts_on_board(side), game.banked(side), game.supply(side)]
		var name_label: Label = %RedName if side == "r" else %BlueName
		name_label.text = ("> " if side == turn else "  ") + P.side_name(side).to_upper()
	var lines: Array = []
	var hist: Array = game.history
	for i in hist.size():
		lines.append("%d. %s" % [i + 1, hist[i]])
	%History.text = "\n".join(lines.slice(maxi(0, lines.size() - 12)))
	%Banner.visible = game.winner != ""
	if game.winner != "":
		%BannerLabel.text = "%s WINS" % P.side_name(game.winner).to_upper()
		%BannerLabel.add_theme_color_override("font_color", P.side_color(game.winner))
