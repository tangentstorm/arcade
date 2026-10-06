extends RigidBody2D
## The teleporter device. Hold the interact key on it for TRIGGER seconds.

signal teleport

var interacting: bool = false
const TRIGGER = 3 # seconds
var time = 0
var _fired := false


func _ready():
	# Port: in Godot 4 a body that starts `sleeping = true` is woken as soon
	# as it enters the physics space, so the teleporter would drop at once
	# instead of hanging in the air until room0 releases it. Freeze it
	# instead; room0 unfreezes it where the original set sleeping = false.
	if sleeping:
		freeze = true


func on_interact_begin():
	interacting = true
	$particles.emitting = true
	time = 0


func on_interact_end():
	interacting = false
	$particles.emitting = false
	# Godot 3 set amount = 0; Godot 4 requires amount >= 1.
	$particles.amount = 1


func _process(delta):
	if interacting:
		time += delta
		if time > TRIGGER and not _fired:
			_fired = true  # Godot 3 re-emitted every frame; once is enough.
			teleport.emit()
		if $particles.amount < 64:
			$particles.amount += 1
