extends RefCounted
## GM Defense — GameMaker Studio 2 room simulation (no rendering).
##
## gm2-defense is a toy "defender clone" start: one room (r_main, 1024x768,
## black, no views) with two instances:
##   o_ship0 at (320,416): Create `speed = 5` (direction defaults to 0, so it
##       flies right at once). Key Press Left: direction = 180, image_xscale = -1.
##       Key Press Right: direction = 0, image_xscale = 1.
##   o_squid at (352,288): no events. It just plays s_squid (4 frames, 5 fps).
## There is no Outside Room event, so the ship can fly off-screen and keep going
## until you press the opposite arrow.
##
## step() runs one GM step at the GMS2 default game speed (60 steps/s):
##   1. key press events (o_ship0)
##   2. built-in motion: x += lengthdir_x(speed, direction)
##   3. sprite animation: image_index += sprite fps / game fps

const W := 1024
const H := 768
const SPEED := 60          ## GMS2 default game frames per second
const SHIP_SPEED := 5.0    ## o_ship0 Create_0.gml
const SQUID_FRAMES := 4    ## s_squid frames
const SQUID_FPS := 5.0     ## s_squid playbackSpeed (type 0 = frames per second)


class Inst:
	var x: float
	var y: float
	var speed := 0.0
	var direction := 0.0   ## degrees, GM convention (counter-clockwise, 0 = right)
	var image_xscale := 1.0
	var image_index := 0.0

	func _init(px: float, py: float) -> void:
		x = px; y = py


var ship: Inst
var squid: Inst
var steps := 0


func _init() -> void:
	room_start()


## r_main creation order: o_ship0 then o_squid.
func room_start() -> void:
	ship = Inst.new(320, 416)
	ship.speed = SHIP_SPEED          # o_ship0 Create_0.gml: speed=5
	squid = Inst.new(352, 288)
	steps = 0


## input: {"left_pressed": bool, "right_pressed": bool} (key *press* edges, as GM's
## Key Press events). If both arrive in the same step, left is applied first
## (key code 37 before 39), so right wins.
func step(input: Dictionary = {}) -> void:
	if input.get("left_pressed", false):   # KeyPress_37.gml
		ship.direction = 180
		ship.image_xscale = -1
	if input.get("right_pressed", false):  # KeyPress_39.gml
		ship.direction = 0
		ship.image_xscale = 1
	for i in [ship, squid]:
		var r := deg_to_rad(i.direction)
		i.x += cos(r) * i.speed
		i.y -= sin(r) * i.speed
	squid.image_index = fmod(squid.image_index + SQUID_FPS / SPEED, SQUID_FRAMES)
	steps += 1


func ship_on_screen() -> bool:
	return ship.x + 25 > 0 and ship.x - 25 < W
