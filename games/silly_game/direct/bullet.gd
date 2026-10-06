extends Sprite2D
## Port of silly-game/bullet.gd: frame-stepped velocity (not delta-scaled).

var velocity := Vector2.ZERO


func _physics_process(_delta: float) -> void:
	position += velocity
