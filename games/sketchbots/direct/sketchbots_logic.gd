extends RefCounted
## SketchBots — Direct edition simulation.
## GDScript port of GameSketchLib course w01 `SketchBots.pde`, extended to two players:
## orange (WASD / Dvorak ,aoe) and blue (arrow keys). Original PDE only moved orange;
## blue was fixed at bottom-centre (teaching note: "for the adventurous, make orange
## and blue guys into sprites").
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
## Sprite size from orangeguy-*.png / blueguy-*.png (50×50).
var orange_w := 50
var orange_h := 50

var blue_heading := 0
var blue_x := 0
var blue_y := 0
var blue_face: int = Face.D
var blue_w := 50
var blue_h := 50


func _init() -> void:
	# setup(): mOrangeGuyImage = mOrangeGuyL; centered
	orange_face = Face.L
	orange_x = int(W / 2) - int(orange_w / 2)
	orange_y = int(H / 2) - int(orange_h / 2)
	# Blue starts where the original drew him fixed: bottom-centre, facing down.
	blue_face = Face.D
	blue_x = int(W / 2) - int(blue_w / 2)
	blue_y = H - blue_h


## Processing keyPressed / keyReleased. `pressed` true on press, false on release.
## Orange: lowercase letter / punctuation (WASD + Dvorak ,aoe / <).
## Blue: "up" / "down" / "left" / "right" (arrow keys).
func handle_key(key: String, pressed: bool) -> void:
	var bit := 0
	var face := -1
	var for_blue := false
	match key:
		",", "<", "w":
			bit = NORTH
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
		"up":
			bit = NORTH
			face = Face.U
			for_blue = true
		"down":
			bit = SOUTH
			face = Face.D
			for_blue = true
		"left":
			bit = WEST
			face = Face.L
			for_blue = true
		"right":
			bit = EAST
			face = Face.R
			for_blue = true
		_:
			return
	if for_blue:
		if pressed:
			blue_heading |= bit
			if face >= 0:
				blue_face = face
		else:
			# Original uses ^= (XOR), not &= ~bit — keep per player.
			blue_heading ^= bit
	else:
		if pressed:
			heading |= bit
			if face >= 0:
				orange_face = face
		else:
			heading ^= bit


func _advance(h: int, x: int, y: int, spr_h: int) -> Vector2i:
	match h:
		NORTH:
			y -= SPEED
		EAST:
			x += SPEED
		SOUTH:
			y += SPEED
		WEST:
			x -= SPEED
		NORTH | EAST:
			y -= SPEED
			x += SPEED
		NORTH | WEST:
			y -= SPEED
			x -= SPEED
		SOUTH | EAST:
			y += SPEED
			x += SPEED
		SOUTH | WEST:
			y += SPEED
			x -= SPEED
		_:
			pass
	# Only bottom edge is clamped in the original.
	if y + spr_h > H:
		y = H - spr_h
	return Vector2i(x, y)


## One Processing draw() frame: move both guys by heading, clamp bottom.
func step() -> void:
	var o := _advance(heading, orange_x, orange_y, orange_h)
	orange_x = o.x
	orange_y = o.y
	var b := _advance(blue_heading, blue_x, blue_y, blue_h)
	blue_x = b.x
	blue_y = b.y
