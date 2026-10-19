extends CanvasLayer
## Autoload "PauseOverlay": Esc inside any game pauses and shows this overlay.
## Esc again (or "Back to Arcade") returns to the arcade hub.
## Browser Back / Android Back skip the panel and return in one step (see ArcadeHistory).
## "Switch to Original/Enhanced" restarts the game in its other edition; ArcadeHistory
## replaces the play URL (game -> game), so Back still lands on the gallery.

const EDITION_LABEL := {"direct": "Original", "enhanced": "Enhanced"}

@onready var _panel: Control = $Panel
var _other = null  ## GameEntry for the running game's other edition, or null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_panel.visible = false
	%ResumeButton.pressed.connect(_resume)
	%ArcadeButton.pressed.connect(_to_arcade)
	%EditionButton.pressed.connect(_switch_edition)
	# Browser Back / Android Back / in-game "Back" buttons return without going through us.
	GameRegistry.returned_to_arcade.connect(_hide)
	GameRegistry.launched.connect(_on_launched)


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


func _hide() -> void:
	_panel.visible = false
	_other = null


func _on_launched(entry) -> void:
	_hide()
	var ed := "enhanced" if entry.edition == "direct" else "direct"
	var other = GameRegistry.get_entry(entry.id, ed)
	_other = other if other != null and other.is_playable() else null
	%EditionButton.visible = _other != null
	if _other != null:
		%EditionButton.text = "Switch to %s" % EDITION_LABEL[ed]


func _switch_edition() -> void:
	if _other != null:
		GameRegistry.launch(_other)


func _resume() -> void:
	_panel.visible = false
	get_tree().paused = false


func _to_arcade() -> void:
	_panel.visible = false
	GameRegistry.return_to_arcade()
