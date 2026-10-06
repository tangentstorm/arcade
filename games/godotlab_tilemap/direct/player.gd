extends CharacterBody2D
## Arcade addition (not in the source): Kenney "Platformer Deluxe" p1 alien,
## from the same CC0 pack the original tilemap test vendored, so the test
## level can be walked. Frame rects come from assets/p1_spritesheet.txt.

const WALK_SPEED := 360.0
const JUMP_VELOCITY := -900.0
const GRAVITY := 2400.0
const FALL_LIMIT := 1400.0   ## below this y the player respawns

const FRAMES := {
	"stand": Rect2(67, 196, 66, 92),
	"jump": Rect2(438, 93, 67, 94),
	"walk01": Rect2(0, 0, 72, 97),
	"walk02": Rect2(73, 0, 72, 97),
	"walk03": Rect2(146, 0, 72, 97),
	"walk04": Rect2(0, 98, 72, 97),
	"walk05": Rect2(73, 98, 72, 97),
	"walk06": Rect2(146, 98, 72, 97),
	"walk07": Rect2(219, 0, 72, 97),
	"walk08": Rect2(292, 0, 72, 97),
	"walk09": Rect2(219, 98, 72, 97),
	"walk10": Rect2(365, 0, 72, 97),
	"walk11": Rect2(292, 98, 72, 97),
}
const WALK_FPS := 20.0

@onready var sprite: Sprite2D = $Sprite
var spawn := Vector2.ZERO
var respawns := 0
var _walk_t := 0.0


func _ready() -> void:
	spawn = position
	_show("stand")


func _show(frame_name: String) -> void:
	var r: Rect2 = FRAMES[frame_name]
	sprite.region_rect = r
	# Anchor the frame bottom-centre on the body origin (the feet).
	sprite.offset = Vector2(0, -r.size.y / 2.0)


func _axis() -> float:
	var x := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		x += 1.0
	return x


func _jump_pressed() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP) \
		or Input.is_physical_key_pressed(KEY_W)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	var dir := _axis()
	velocity.x = dir * WALK_SPEED
	if is_on_floor() and _jump_pressed():
		velocity.y = JUMP_VELOCITY
	move_and_slide()

	if dir != 0.0:
		sprite.flip_h = dir < 0.0
	if not is_on_floor():
		_show("jump")
	elif dir != 0.0:
		_walk_t += delta
		_show("walk%02d" % (int(_walk_t * WALK_FPS) % 11 + 1))
	else:
		_walk_t = 0.0
		_show("stand")

	if position.y > FALL_LIMIT:
		respawn()


func respawn() -> void:
	position = spawn
	velocity = Vector2.ZERO
	respawns += 1
