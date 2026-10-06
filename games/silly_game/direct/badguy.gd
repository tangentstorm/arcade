extends Sprite2D
## Port of silly-game/badguy.gd: flips to frame 12 when a bullet body overlaps.

func _physics_process(_delta: float) -> void:
	var collisions = $CharacterBody2D.move_and_collide(Vector2.ZERO)
	if collisions:
		frame = 12
