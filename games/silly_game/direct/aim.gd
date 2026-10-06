extends Sprite2D
## Port of silly-game/aim.gd: hidden-mouse crosshair that tracks the cursor.

func _ready() -> void:
	_hide_mouse(true)


func _process(_delta: float) -> void:
	position = get_global_mouse_position()


# Arcade pause / hub need the OS cursor back.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			_hide_mouse(false)
		NOTIFICATION_UNPAUSED:
			_hide_mouse(true)
		NOTIFICATION_EXIT_TREE:
			_hide_mouse(false)


func _hide_mouse(hide: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
