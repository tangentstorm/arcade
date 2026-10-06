extends Sprite2D
## Port of godotlab/game01/crosshair.gd: a hidden-mouse crosshair that follows
## mouse *motion* (so it also drifts along with the hero, see hero.gd).

var oldmouse = Vector2()


func _ready() -> void:
	_hide_mouse(true)
	oldmouse = _mouse()


func _mouse() -> Vector2:
	# Original: get_global_mouse_position() / 2 (the scene root is scaled 2x).
	return get_parent().get_local_mouse_position()


func _process(_delta: float) -> void:
	var newmouse = _mouse()
	if newmouse != oldmouse:
		position += (newmouse - oldmouse)
	oldmouse = newmouse
	# Arcade addition: keep the crosshair on screen (the original let it drift off).
	var parent := get_parent() as Node2D
	var vr := get_viewport_rect()
	var tl: Vector2 = parent.get_global_transform().affine_inverse() * vr.position
	var br: Vector2 = parent.get_global_transform().affine_inverse() * vr.end
	position = position.clamp(tl, br)


# The arcade's pause menu and hub need the OS cursor back.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			_hide_mouse(false)
		NOTIFICATION_UNPAUSED:
			_hide_mouse(true)
			oldmouse = _mouse()
		NOTIFICATION_EXIT_TREE:
			_hide_mouse(false)


func _hide_mouse(hide: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
