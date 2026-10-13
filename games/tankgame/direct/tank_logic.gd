extends RefCounted
## tankgame Direct — terrain logic (port of game_view.js.rb Sand/Grid).
## Random-walk heightfield on an (MW+1)x(MH+1) bit grid, rendered as
## marching-squares tiles indexed into sprites/msquares.png.

const MW := 80
const MH := 60
const TW := 10
const TH := 10
const NTANKS := 2
const STAGE_W := 800
const STAGE_H := 600

var grid: PackedByteArray  ## (MW+1)*(MH+1), 1 = sand
var rng := RandomNumberGenerator.new()


func generate(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	grid = PackedByteArray()
	grid.resize((MW + 1) * (MH + 1))
	var level := MH / 2
	for x in MW + 1:
		level += rng.randi_range(-1, 1)  # rand(3)-1, once per column
		for y in MH + 1:
			grid[y * (MW + 1) + x] = 0 if y < level else 1


func get_bit(x: int, y: int) -> int:
	return grid[y * (MW + 1) + x]


## Marching-squares tile 0..15 from the 4 corner bits (TL<<3 | TR<<2 | BR<<1 | BL).
func msquare(x: int, y: int) -> int:
	return (get_bit(x, y) << 3) | (get_bit(x + 1, y) << 2) \
		| (get_bit(x + 1, y + 1) << 1) | get_bit(x, y + 1)


## Original sprite placement: gun at (i*200+225, 303), tank at (i*200+200, 300).
static func tank_pos(i: int) -> Vector2:
	return Vector2(i * 200 + 200, 300)


static func gun_pos(i: int) -> Vector2:
	return Vector2(i * 200 + 225, 303)
