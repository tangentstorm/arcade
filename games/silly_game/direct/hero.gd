extends Sprite2D
## Port of silly-game/hero.gd: WASD aardvark walk + click-to-shoot bullet pool.
## Esc is handled by the arcade PauseOverlay (original quit-on-Esc removed).

var speed := 8
var bullet_round := 1
const BULLET_SPEED := 16
const AMMO_DELAY := 0.2
var ammo_delta := AMMO_DELAY
var bullets: Node2D


func _ready() -> void:
	bullets = get_node("../bullets")


# Original ran in _process at vsync (~60). Fixed physics tick keeps SPEED
# (pixels per frame) stable across refresh rates.
func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_D):
		frame = 0
		position.x += speed
	if Input.is_key_pressed(KEY_A):
		frame = 2
		position.x -= speed
	if Input.is_key_pressed(KEY_W):
		frame = 3
		position.y -= speed
	if Input.is_key_pressed(KEY_S):
		frame = 1
		position.y += speed

	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()

	ammo_delta += delta
	if ammo_delta > AMMO_DELAY and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var b: Node2D = bullets.get_child(bullet_round)
		b.position = position
		b.velocity = (get_global_mouse_position() - position).normalized() * BULLET_SPEED
		bullet_round += 1
		bullet_round %= bullets.get_child_count()
		ammo_delta = 0
