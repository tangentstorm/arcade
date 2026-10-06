extends VBoxContainer
## Chess Coach — Direct edition.
## Tiny FEN board + trays from tangentstorm/gd-chesscoach (Godot 4.3).
## Esc is handled globally by the PauseOverlay autoload (do not quit).

@onready var _board: Panel = $board
@onready var _player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	%BackButton.pressed.connect(GameRegistry.return_to_arcade)
	%ReplayButton.pressed.connect(_replay)
	%ResetButton.pressed.connect(_reset)


func _reset() -> void:
	if _player.is_playing():
		_player.stop()
	_board.setup_board(_board.INIT_FEN)


func _replay() -> void:
	_reset()
	# Let layout settle so animation square positions match the fresh FEN.
	await get_tree().process_frame
	await get_tree().process_frame
	if _player.has_animation("fool's mate"):
		_player.play("fool's mate")
