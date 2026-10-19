extends RefCounted
## cardinalrule Direct — hero motion, a line-for-line port of spritetest.pas.
## One step() = one Flash onEnterFrame at 32 fps. Units are stage pixels.

const STAGE_W := 512
const STAGE_H := 448
const FPS := 32
const HERO := 64  ## cardinal-r.png is 32x32, onLoadInit scales it x2
const MIN_X := 0
const MIN_Y := 0
const MAX_X := STAGE_W - HERO
const MAX_Y := STAGE_H - HERO
const GRAVITY := 0.2

var pos := Vector2(STAGE_W / 2, STAGE_H / 2)  ## top-left of the clip, as in onLoadInit
var dx := 0.0
var dy := 0.0


## onKeyDown: each press (and each OS key repeat) is an impulse that stays.
func key(keycode: int) -> void:
	match keycode:
		KEY_UP: dy -= 4
		KEY_DOWN: dy += 4
		KEY_LEFT: dx -= 2
		KEY_RIGHT: dx += 2


## onEnterFrame: move, clamp, then gravity (or land and stop falling).
func step() -> void:
	pos.x += dx
	pos.y += dy
	if pos.y < MIN_Y:
		pos.y = MIN_Y
	if pos.x < MIN_X:
		pos.x = MIN_X
	if pos.x > MAX_X:
		pos.x = MAX_X
	if pos.y > MAX_Y:
		pos.y = MAX_Y
		dy = 0.0
	else:
		dy += GRAVITY
