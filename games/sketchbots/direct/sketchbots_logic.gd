extends RefCounted
## SketchBots — Direct edition simulation.
## Faithful GDScript port of GameSketchLib course w01 `SketchBots.pde`.
## One step() == one Processing draw() frame at frameRate(30).

const W := 300
const H := 300
const FPS := 30.0
const SPEED := 10

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

## Sprite face ids matching the loaded PNGs.
enum Face { L, R, U, D }

var heading := 0
var orange_x := 0
var orange_y := 0
var orange_face: int = Face.L
## Sprite size from orangeguy-*.png / blueguy-D.png (50×50).
var orange_w := 50
var orange_h := 50
var blue_w := 50
var blue_h := 50


func _init() -> void:
	# setup(): mOrangeGuyImage = mOrangeGuyL; centered
	orange_face = Face.L
	orange_x = int(W / 2) - int(orange_w / 2)
	orange_y = int(H / 2) - int(orange_h / 2)


func blue_x() -> int:
	return int(W / 2) - int(blue_w / 2)


func blue_y() -> int:
	return H - blue_h


## Processing keyPressed / keyReleased. `pressed` true on press, false on release.
## `key` is a lowercase letter / punctuation string, or "up" for KEY_UP.
func handle_key(key: String, pressed: bool) -> void:
	var bit := 0
	var face := -1
	match key:
		",", "<", "w", "up":
			bit = NORTH
			if key != "up":
				face = Face.U
		"e", "d":
			bit = EAST
			face = Face.R
		"o", "s":
			bit = SOUTH
			face = Face.D
		"a":
			bit = WEST
			face = Face.L
		_:
			return
	if pressed:
		heading |= bit
		if face >= 0:
			orange_face = face
	else:
		# Original uses ^= (XOR), not &= ~bit.
		heading ^= bit


## One Processing draw() frame: move by heading, clamp bottom, leave drawing to caller.
func step() -> void:
	match heading:
		NORTH:
			orange_y -= SPEED
		EAST:
			orange_x += SPEED
		SOUTH:
			orange_y += SPEED
		WEST:
			orange_x -= SPEED
		NORTH | EAST:
			orange_y -= SPEED
			orange_x += SPEED
		NORTH | WEST:
			orange_y -= SPEED
			orange_x -= SPEED
		SOUTH | EAST:
			orange_y += SPEED
			orange_x += SPEED
		SOUTH | WEST:
			orange_y += SPEED
			orange_x -= SPEED
		_:
			pass
	# Only bottom edge is clamped in the original.
	if orange_y + orange_h > H:
		orange_y = H - orange_h
