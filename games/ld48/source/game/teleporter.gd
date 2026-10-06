extends RigidBody2D

signal teleport

var interacting: bool = false
const TRIGGER = 3 # seconds
var time = 0

func on_interact_begin():
	interacting = true
	$particles.emitting = true
	time = 0
	
func on_interact_end():
	interacting = false
	$particles.emitting = false
	$particles.amount = 0


func _process(delta):
	if interacting:
		time += delta
		if time > TRIGGER:
			emit_signal("teleport")
		if $particles.amount < 64:
			$particles.amount += 1
