extends Sprite2D
## Port of godotlab/game00/icon.gd: arrow keys push the sprite, friction slows it.
## Logic is unchanged; it runs on the fixed 60 Hz physics tick so the
## per-frame impulse/friction feel matches the original 60 fps vsync build.

const SPEED = 50

const R = Vector2(+1, 0)
const L = Vector2(-1, 0)
const U = Vector2(0, -1)
const D = Vector2(0, +1)

var velocity = Vector2(0, 0)
var friction = 0.975   # should be <0, scales velocity at each step

## Arcade addition: wrap at the viewport edges so the sprite can't be lost.
var wrap := true


func _physics_process(delta: float) -> void:
	position += delta * velocity

	if Input.is_action_pressed("ui_right"):
		velocity += R * SPEED
	if Input.is_action_pressed("ui_left"):
		velocity += L * SPEED
	if Input.is_action_pressed("ui_up"):
		velocity += U * SPEED
	if Input.is_action_pressed("ui_down"):
		velocity += D * SPEED

	velocity *= friction

	if wrap:
		var r := get_viewport_rect()
		position.x = wrapf(position.x, r.position.x, r.end.x)
		position.y = wrapf(position.y, r.position.y, r.end.y)
