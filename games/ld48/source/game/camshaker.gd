extends Node2D

var shake : int = 0

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()

# TODO: Add in some sort of rotation reset.
func _process(_delta):
	if shake > 0:
		position += Vector2((rng.randf()-0.5)*shake, (rng.randf()-0.5)*shake)
		shake -= 1
	elif shake == 0:
		if position == Vector2.ZERO: shake = -1
		else: position *= Vector2(0.95,0.95)
			
		
