extends RefCounted
## Giraffe — Pico-8 cart simulation (giraffe.p8 _update).
## One step() == one Pico-8 frame at 30 Hz.

const MapData := preload("res://games/giraffe/direct/map_data.gd")

const W := 128
const H := 128
const FPS := 30
const CELL := 8
const GROUND := 16
const OX := 2.5  ## sprite x offset (spr draws at hx - ox)

## Pico sprite frames: idle=1, walk=2/3 (wf toggles).
const SPR_IDLE := 1


var hx: float = OX
var hy: float = 16.0
var dx: float = 0.0
var dy: float = 0.0
var mx: int = 0
var my: int = 0
var tm: int = 0
var wf: int = 1
var moving: bool = false
var flip_x: bool = false
var on_ground: bool = false
var frame: int = SPR_IDLE


func _init() -> void:
	reset()


func reset() -> void:
	hx = OX
	hy = 16.0
	dx = 0.0
	dy = 0.0
	tm = 0
	wf = 1
	moving = false
	flip_x = false
	on_ground = false
	frame = SPR_IDLE
	_update_map_cell()


func _update_map_cell() -> void:
	mx = int(floor(hx / float(CELL)))
	my = int(floor(hy / float(CELL)))


## btn: {left, right, jump} held this frame (Pico btn, not btnp).
func step(btn: Dictionary) -> void:
	# if hy > 128 then init()
	if hy > float(H):
		reset()
		return

	_update_map_cell()

	# og = mget(mx, my+1) == ground
	on_ground = MapData.mget(mx, my + 1) == GROUND
	dy += 1.0  # gravity
	if on_ground and dy > 0.0:
		dy = 0.0
		hy = float(my * CELL)
		if btn.get("jump", false):
			dy = -6.0  # jump

	# horizontal acceleration
	if btn.get("left", false):
		dx -= 0.4
	if btn.get("right", false):
		dx += 0.4
	dx *= 0.8
	if absf(dx) < 0.1:
		dx = 0.0

	# walk animation
	moving = absf(dx) > 0.2
	tm += 1
	if tm % 5 == 0:
		wf = 1 - wf

	hx += dx
	hy += dy

	_update_map_cell()
	if moving:
		frame = 2 + wf
	else:
		frame = SPR_IDLE
	flip_x = dx < 0.0
