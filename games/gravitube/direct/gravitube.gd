extends Node3D
## One gravitube drum (source gravitube.gd): spins about its X axis at `speed` deg/s.

@export var speed: int = 0


func _process(delta: float) -> void:
	rotation_degrees.x += speed * delta
