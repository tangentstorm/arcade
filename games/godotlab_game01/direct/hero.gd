extends Sprite2D
## Port of godotlab/game01/hero.gd: top-down hero that always faces the crosshair.

const SPEED = 10

# The original polled the Dvorak keys , A O E (the W A S D positions on a
# Dvorak board). Polling the *physical* W A S D positions keeps that layout for
# Dvorak typists and makes it usable on QWERTY too; arrows are an arcade extra.
const K_UP = KEY_W  # dvorak ,
const K_LF = KEY_A  # dvorak a
const K_DN = KEY_S  # dvorak o
const K_RT = KEY_D  # dvorak e


func _pressed(phys: Key, arrow: Key) -> bool:
	return Input.is_physical_key_pressed(phys) or Input.is_key_pressed(arrow)


# Original ran in _process at the 60 fps vsync rate; the fixed 60 Hz physics
# tick keeps SPEED (pixels per frame) the same on any refresh rate.
func _physics_process(_delta: float) -> void:
	var diff = Vector2()

	# vertical:
	if _pressed(K_UP, KEY_UP):
		diff.y -= SPEED
	elif _pressed(K_DN, KEY_DOWN):
		diff.y += SPEED
	# horizontal
	if _pressed(K_LF, KEY_LEFT):
		diff.x -= SPEED
	elif _pressed(K_RT, KEY_RIGHT):
		diff.x += SPEED

	position += diff

	var crosshair = get_parent().get_node("crosshair")
	if diff != Vector2.ZERO:
		crosshair.position += diff

	# even if we don't move, look at the mouse.
	# Godot 3's a.angle_to_point(b) was the angle of (a - b); the art faces -x,
	# so the nose points at the crosshair.
	rotation = (position - crosshair.position).angle()
