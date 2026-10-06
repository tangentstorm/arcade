extends Node2D
## Port of silly-game/bullets.gd: duplicate the template bullet into a pool of 51.

func _ready() -> void:
	var bullet = get_node("bullet")
	for i in range(50):
		var dupe = bullet.duplicate()
		dupe.name = "bullet%d" % i
		add_child(dupe)
