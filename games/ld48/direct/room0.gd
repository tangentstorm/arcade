# script for room 0 ("Previously...")
extends Node
## Port of ld48 `scenes/room0.gd`.
##
## The Godot 3 original drove its dialog with a hand-rolled coroutine: each
## line did `sleep(n); yield()`, and a 0.25 s Timer called `co.resume()` once
## the sleep counter ran out. Godot 4 has no GDScriptFunctionState.resume(),
## so `wait(n)` sets the same counter and awaits the next Timer step that
## finds it expired — same pacing, same "0 skips the wait" debug key.

signal wakeup()
signal speak(who, msg)
signal helptext(msg)
signal stepped()  # Port: the Timer tick that used to call co.resume()

const NEXT_ROOM := "res://games/ld48/direct/ivan_office.tscn"

var sleepFor = 0.0
var sleptFor = 0.0


func _ready():
	$sprites/ernie.has_teleporter = false
	run_script.call_deferred()  # Port: Godot 3 called script() here; deferred one frame.


func _on_step():
	if sleepFor <= 0:
		stepped.emit()


func _process(delta):
	if sleepFor > 0:
		sleepFor -= delta
		if sleepFor <= 0:
			wakeup.emit()
	on_frame(delta)


## Godot 3: `sleep(seconds); yield()`
func wait(seconds):
	sleepFor = seconds
	await stepped
	sleepFor = 0


func find(node_name):
	return $sprites.get_node(node_name)


func shake(frames=300):
	$"../camshaker".shake = frames


func shaking():
	return $"../camshaker".shake > 0


func teddy(msg):
	speak.emit("teddy", msg)


func ernie(msg):
	speak.emit("ernie", msg)


## Godot 3 named this `helptext`, the same as the signal; Godot 4 forbids that.
func show_help(msg):
	helptext.emit(msg)


func on_frame(_delta):
	if Input.is_key_pressed(KEY_0):
		shake(0)
		sleepFor = 0


func _on_ernie_reach_object(_body):
	show_help('Press E to Interact')


func _on_ernie_leave_object(_body):
	show_help('')


# --------------------------------------
# logic specific to this room
# --------------------------------------
signal showchat(flag)


## Godot 3 named this `script()`, which shadows Object.script in Godot 4.
func run_script():
	showchat.emit(false)
	shake()
	while shaking():
		await wait(1)
	showchat.emit(true)
	await wait(2)
	teddy("Unnnnnnnghh... My poor head."); await wait(4)
	ernie("Was that an earthquake?"); await wait(2)
	teddy("Ernie! Are you okay?"); await wait(4)
	ernie("I... uh... Yeah, I think I can move now.")
	show_help("Use W/A/S/D (or ,/A/O/E) keys to move")
	await wait(10)
	teddy("Ernie, that wasn't an earthquake."); await wait(2)
	find("teddy").rotation_degrees = 0
	teddy("I'm afraid I've placed you, me, and everyone we know in terrible, terrible danger."); await wait(4)
	teddy("I need you to get back outside at once, and let Ivan know what happened!"); await wait(4)
	ernie("But... I don't know what happened. Plus... well... I think I'm stuck in this hole."); await wait(4)
	teddy("Tell Ivan it was the [b]Gravitron Generator[/b]. He'll know what has to be done."); await wait(4)
	var teleporter = find("teleporter")
	teleporter.visible = true
	teleporter.sleeping = false
	teleporter.freeze = false  # Port: Godot 4 stand-in for the scene's sleeping = true
	teddy("Now be quick! Grab hold of this device and DO NOT LET go!"); await wait(2)
	teddy("Hurry, Ernie! The entire town might be at stake!")


func _on_teleporter_teleport():
	get_tree().change_scene_to_file.call_deferred(NEXT_ROOM)
