extends CanvasLayer
## Autoload "PauseOverlay": Esc inside any game pauses and shows this overlay.
## Esc again (or "Back to Arcade") returns to the arcade hub.

@onready var _panel: Control = $Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_panel.visible = false
	%ResumeButton.pressed.connect(_resume)
	%ArcadeButton.pressed.connect(_to_arcade)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if GameRegistry.in_arcade():
		return
	get_viewport().set_input_as_handled()
	if _panel.visible:
		_to_arcade()
	else:
		_panel.visible = true
		get_tree().paused = true
		%ResumeButton.grab_focus()


func _resume() -> void:
	_panel.visible = false
	get_tree().paused = false


func _to_arcade() -> void:
	_panel.visible = false
	GameRegistry.return_to_arcade()
