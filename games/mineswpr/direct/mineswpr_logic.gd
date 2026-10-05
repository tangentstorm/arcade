extends RefCounted
## mineswpr — the game words from mineswpr.org (Retro Forth 11, 2013), in GDScript.
##
## Each section below names the org heading it ports. Cells are bitsets exactly
## as in the original: enum| ·mine ·cover ·flag | -> bits 0,1,2, with the armed
## neighbor count stored from bit 8 up ($100 per armed neighbor).

# ** variables ---------------------------------------------------------------
const MINE := 0    ## ·mine
const COVER := 1   ## ·cover
const FLAG := 2    ## ·flag

var game_over := false   ## gameOver?
var flag_count := 0      ## flagCount
var active_cell := -1    ## active-cell (0 in the original = none; here -1)
var flood_cursor := -1   ## flood-cursor (debug)

# ** grid-setup ----------------------------------------------------------------
const W := 16
const H := 16
const MINE_COUNT := 24   ## mineCount

var grid := PackedInt32Array()
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	grid.resize(W * H)
	game_new()


static func grid_size() -> int:
	return W * H


# ** point-methods ---------------------------------------------------------------
## nn ss ee ww ... as (dx, dy) offsets
const CARDINAL := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const NEIGHBORS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                   Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)]


## cell ( xy-a ): index of the cell (the original returned an address).
static func cell(x: int, y: int) -> int:
	return y * W + x


## inbounds? ( xy-f )
static func inbounds(x: int, y: int) -> bool:
	return y >= 0 and y <= H - 1 and x >= 0 and x <= W - 1


## c>xy ( c-xy )
static func c2xy(c: int) -> Vector2i:
	return Vector2i(c % W, c / W)


# ** cell methods ----------------------------------------------------------------
## has? ( ce-? )
func has(c: int, e: int) -> bool:
	return (grid[c] >> e) & 1 == 1


func _incl(c: int, e: int) -> void:
	grid[c] |= 1 << e


func _excl(c: int, e: int) -> void:
	grid[c] &= ~(1 << e)


## uncover ( c- )
func uncover(c: int) -> void:
	_excl(c, COVER)


## armed-neighbor-count ( c-n )
func armed_neighbor_count(c: int) -> int:
	return grid[c] >> 8


## armed-neighbor-add ( c- )
func armed_neighbor_add(c: int) -> void:
	grid[c] += 0x100


## randcell ( -a ):  W randint H randint cell
func randcell() -> int:
	var x := rng.randi_range(0, W - 1)
	var y := rng.randi_range(0, H - 1)
	return cell(x, y)


# ** floodfill ---------------------------------------------------------------------
## needs-visit? ( c-f )
func needs_visit(c: int) -> bool:
	return has(c, COVER)


## keep-going? ( c-f )
func keep_going(c: int) -> bool:
	return armed_neighbor_count(c) == 0


## flood ( xy- ): uncover from (x,y); spread through *cardinal* neighbors of
## zero-count cells only. Like the original, it does not stop at flags: a flagged
## cell gets uncovered but keeps its ·flag bit (and so still draws as a flag).
func flood(x: int, y: int) -> void:
	# iterative version of the original's recursion; same visiting rule.
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if not inbounds(p.x, p.y):
			continue
		var c := cell(p.x, p.y)
		flood_cursor = c
		if not needs_visit(c):
			continue
		uncover(c)  # flood-visit
		if keep_going(c):
			# cardinal-neighbors-do pushes n,w,e,s; push reversed to visit in that order
			for i in range(CARDINAL.size() - 1, -1, -1):
				stack.push_back(p + CARDINAL[i])
	flood_cursor = -1


# ** event handlers ------------------------------------------------------------------
## «dead» ( a- )
func dead() -> void:
	game_over = true


# ** user actions ----------------------------------------------------------------------
## flaggable? ( a-f )
func flaggable(c: int) -> bool:
	return not has(c, FLAG) and has(c, COVER)


## flag+ ( a- )
func flag_add(c: int) -> void:
	if flaggable(c):
		_incl(c, FLAG)
		flag_count += 1


## flag- ( a- )
func flag_remove(c: int) -> void:
	if has(c, FLAG):
		_excl(c, FLAG)
		flag_count -= 1


## prod ( c- ): removes any flag first, then detonates or floods.
func prod(c: int) -> void:
	flag_remove(c)
	if has(c, MINE):
		dead()
	else:
		var p := c2xy(c)
		flood(p.x, p.y)


# ** minefield words -------------------------------------------------------------------
## hints-create ( - )
func hints_create() -> void:
	for c in grid_size():
		if has(c, MINE):
			var p := c2xy(c)
			for d in NEIGHBORS:
				var q: Vector2i = p + d
				if inbounds(q.x, q.y):
					armed_neighbor_add(cell(q.x, q.y))


## mine-add ( - ): a mine in a random cell that doesn't yet have one
func mine_add() -> void:
	var c := randcell()
	while has(c, MINE):
		c = randcell()
	_incl(c, MINE)


## game-new ( - )
func game_new() -> void:
	grid.fill(1 << COVER)  # ·cover as-bit grid .fill
	for i in MINE_COUNT:
		mine_add()
	hints_create()
	flag_count = 0
	game_over = false
	active_cell = -1


## Test helper: replace the minefield with mines at the given cells.
func load_mines(cells: Array) -> void:
	grid.fill(1 << COVER)
	for c in cells:
		_incl(int(c), MINE)
	hints_create()
	flag_count = 0
	game_over = false
	active_cell = -1


## Not in the original (it has no win check): every safe cell is uncovered.
func cleared() -> bool:
	for c in grid_size():
		if not has(c, MINE) and has(c, COVER):
			return false
	return true


func covered_count() -> int:
	var n := 0
	for c in grid_size():
		if has(c, COVER):
			n += 1
	return n
