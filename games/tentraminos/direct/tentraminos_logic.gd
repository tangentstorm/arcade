extends RefCounted
## Faithful GDScript port of the game logic in tentraminos.ts
## (tangentstorm/tentraminos @ 9be2266, Ludum Dare 27, 2013, MIT).
##
## Function names and the step() state machine mirror the original so the two
## can be read side by side. Rendering and input live in game.gd.
##
## The original only repainted the board inside step() (via redraw()), so tile
## rotations made while paused or after game over stayed invisible until the
## next repaint. We keep that behaviour: the renderer draws the `shown_*`
## snapshot that redraw() takes, not the live matrix.

const SECONDS := 1000  # times are in milliseconds, like the original
const TICK_MS := 100   # window.setInterval(tick, 100)

const GW := 9  # grid width: can't have 10 in a row, for obvious reasons :)
const GH := 9  # grid height
const NUMCELLS := GW * GH

# Original state ids (values kept identical).
const NEWGAME := 0
const PLAYING := 1
const PAUSED := 2
const TIMEUP := 3
const THEEND := 4
const NEXTROUND := 5
const CASCADE := 6
const CHECK4END := 7

const COLORS: Array[Color] = [
	Color("#292929"),  # 0 almost black
	Color("#a40000"),  # 1 dark red
	Color("#4e9a06"),  # 2 dark green
	Color("#c4a000"),  # 3 dark yellow
	Color("#204a87"),  # 4 dark blue
	Color("#66355f"),  # 5 dark purple
	Color("#00a4a2"),  # 6 dark cyan
	Color("#ce5c00"),  # 7 dark orange
	Color("#888a85"),  # 8 light gray

	Color("#3e4446"),  # 9 dark gray
	Color("#cc0000"),  # 10 light red
	Color("#73d216"),  # 11 light green
	Color("#edd400"),  # 12 light yellow
	Color("#3465a4"),  # 13 light blue
	Color("#8b608b"),  # 14 light purple
	Color("#16d2bd"),  # 15 light cyan
	Color("#f57900"),  # 16 light orange
	Color("#cccccc"),  # 17 almost white
]

# state = { clock, score, paused, gameOver, next }
var clock := 0
var score := 0
var paused := false
var game_over := false
var next := NEWGAME

var matrix := PackedInt32Array()
var hold := PackedInt32Array()
var cursor_x := 3
var cursor_y := 7

# Snapshot taken by redraw(); this is what the player sees.
var shown_matrix := PackedInt32Array()
var shown_hold := PackedInt32Array()
var shown_clock := 0
var shown_score := 0

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	new_game()


## Reset everything (the original said "refresh page to restart").
func new_game() -> void:
	clock = 0
	score = 0
	paused = false
	game_over = false
	next = NEWGAME
	cursor_x = 3
	cursor_y = 7
	matrix.resize(NUMCELLS)
	matrix.fill(0)
	hold.resize(GW)
	for i in GW:
		hold[i] = rand_cell()
	redraw()


func rand_cell() -> int:
	return 1 + rng.randi_range(0, 7)


func redraw() -> void:
	shown_matrix = matrix.duplicate()
	shown_hold = hold.duplicate()
	shown_clock = clock
	shown_score = score


# -- cursor movement / codes -------------------------------------------------

## Apply one of the original command codes: ^ v < > ( ) p
func code(c: String) -> void:
	match c:
		"^": cursor_y = clampi(cursor_y - 1, 0, 7)
		"v": cursor_y = clampi(cursor_y + 1, 0, 7)
		"<": cursor_x = clampi(cursor_x - 1, 0, 7)
		">": cursor_x = clampi(cursor_x + 1, 0, 7)
		"(":
			var cxy := cursor_y * GW + cursor_x
			var tmp := matrix[cxy]
			matrix[cxy] = matrix[cxy + 1]                # <
			matrix[cxy + 1] = matrix[cxy + GW + 1]       # ^
			matrix[cxy + GW + 1] = matrix[cxy + GW]      # >
			matrix[cxy + GW] = tmp                       # v
		")":
			var cxy := cursor_y * GW + cursor_x
			var tmp := matrix[cxy]
			matrix[cxy] = matrix[cxy + GW]               # ^
			matrix[cxy + GW] = matrix[cxy + GW + 1]      # <
			matrix[cxy + GW + 1] = matrix[cxy + 1]       # v
			matrix[cxy + 1] = tmp                        # >
		"p": paused = not paused


# -- gravity -----------------------------------------------------------------

func release() -> void:
	for i in GW:
		matrix[i] = hold[i]
		hold[i] = 0


func refill() -> void:
	for i in GW:
		hold[i] = rand_cell()


## Returns the number of "holes" encountered (tiles that moved).
func run_gravity() -> int:
	var block := GW * (GH - 2) + GW - 1
	var below := block + GW
	var cxy := cursor_y * GW + cursor_x
	var result := 0
	for y in range(GH - 2, -1, -1):
		for x in range(GW - 1, -1, -1):
			# the cursor can hold blocks in the air
			if block == cxy or block == cxy + 1 or block == cxy + GW or block == cxy + GW + 1:
				pass
			elif matrix[below] == 0:
				if matrix[block] != 0:
					result += 1
				matrix[below] = matrix[block]
				matrix[block] = 0
			block -= 1
			below -= 1
	return result


# -- floodfind ---------------------------------------------------------------

func xy2i(x: int, y: int) -> int:
	return y * GW + x


func _floodfind(groups: PackedInt32Array, x: int, y: int, shape: Array[int],
		color: int, group: int) -> void:
	var i := xy2i(x, y)
	if groups[i] == 0 and matrix[i] == color:
		groups[i] = group
		shape.append(i)
		if x > 0: _floodfind(groups, x - 1, y, shape, color, group)
		if x < GW - 1: _floodfind(groups, x + 1, y, shape, color, group)
		if y > 0: _floodfind(groups, x, y - 1, shape, color, group)
		if y < GH - 1: _floodfind(groups, x, y + 1, shape, color, group)


func findshapes() -> Array:
	var result := []
	var groups := PackedInt32Array()
	groups.resize((GH + 2) * (GW + 2))
	var count := 1
	for y in GH:
		for x in GW:
			var i := xy2i(x, y)
			if matrix[i] != 0 and matrix[i] < 9 and groups[i] == 0:
				var shape: Array[int] = []
				_floodfind(groups, x, y, shape, matrix[i], count)
				count += 1
				result.append(shape)
	return result


## Light up (color + 9) every group of 4+; returns all groups.
func markshapes() -> Array:
	for i in matrix.size():
		if matrix[i] > 8:
			matrix[i] -= 9
	var shapes := findshapes()
	for shape in shapes:
		if shape.size() >= 4:
			for xy in shape:
				if matrix[xy] < 9:
					matrix[xy] += 9
	return shapes


func clearshapes() -> void:
	var shapes := markshapes()
	for shape in shapes:
		var n: int = shape.size()
		if n >= 4:
			# 10 * 2^(n-4); capped so a (practically impossible) 63+ group can't overflow.
			score += 10 * (1 << mini(n - 4, 58))
			for xy in shape:
				matrix[xy] = 0


# -- game over ---------------------------------------------------------------

func check_game_over() -> bool:
	var result := false
	for i in GW:
		if matrix[i] != 0:
			result = true
	game_over = result
	return result


# -- state machine -----------------------------------------------------------

func step(dt: int) -> int:
	match next:
		NEWGAME:
			refill()
			release()
			redraw()
			return CASCADE
		NEXTROUND:
			refill()
			redraw()
			clock = 10 * SECONDS
			return PLAYING
		PLAYING:
			clock -= dt
			run_gravity()
			markshapes()
			redraw()
			if paused:
				return PAUSED
			return TIMEUP if clock <= 0 else PLAYING
		PAUSED:
			return PAUSED if paused else PLAYING
		TIMEUP:
			clock = 0
			release()
			clearshapes()
			redraw()
			return CASCADE
		CASCADE:
			var count := run_gravity()
			redraw()
			return CASCADE if count else CHECK4END
		CHECK4END:
			return THEEND if check_game_over() else NEXTROUND
		THEEND:
			return THEEND
	return next


func tick(dt: int = TICK_MS) -> void:
	next = step(dt)
