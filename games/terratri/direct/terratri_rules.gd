extends RefCounted
## Pure Terratri rules, a line-by-line port of tangentstorm/terratri
## src/shared/terratri.ts (commit 7c20663). Every function is static and
## side-effect free except move()/fortify(), which edit a grid in place
## exactly like the TS originals.
##
## Step notation
##   History is a string of steps separated by '|' turn delimiters.
##   lowercase = red, uppercase = blue
##   n/N s/S e/E w/W = move, f/F = fort, x/X = pass/end turn, k/K = bank
##
## Board notation
##   5x5 grid as a 25-char String (board) or Array of 5 Arrays of 1-char Strings (grid).
##   ' ' unclaimed
##   '.' red territory, 'r' red pawn, 'R' red fort, 'E' red fort+pawn
##   '_' blue territory, 'b' blue pawn, 'B' blue fort, 'L' blue fort+pawn

const SIZE := 5
const FORTS_TO_WIN := 5

const START_BOARD := (
	"  b  " +
	"     " +
	"     " +
	"     " +
	"  r  ")

const DIRS := ["n", "s", "e", "w"]
const K_ROWS := "abcde"   # x -> file letter (TS calls these kRows)
const K_COLS := "54321"   # y -> rank digit  (TS calls these kCols)


static func board_to_grid(board: String) -> Array:
	var rows: Array = []
	for i in SIZE:
		var row: Array = []
		for ch in board.substr(i * SIZE, SIZE):
			row.append(ch)
		rows.append(row)
	return rows


static func grid_to_board(grid: Array) -> String:
	var s := ""
	for row in grid:
		s += "".join(row)
	return s


static func start_grid() -> Array:
	return board_to_grid(START_BOARD)


static func pipe_count(steps: String) -> int:
	return steps.count("|")


static func whose_turn(steps: String) -> String:
	return "r" if pipe_count(steps) % 2 == 0 else "b"


static func pawn_and_fort(pawn: String) -> String:
	return "E" if pawn == "r" else "L"


## {x, y, has_fort} or {} when the pawn is missing (TS: undefined).
static func find_pawn(pawn: String, grid: Array) -> Dictionary:
	var fort_pawn := pawn_and_fort(pawn)
	for y in SIZE:
		for x in SIZE:
			var c: String = grid[y][x]
			if c == pawn or c == fort_pawn:
				return {"x": x, "y": y, "has_fort": c == fort_pawn}
	return {}


static func relative(dir: String, x: int, y: int) -> Vector2i:
	match dir:
		"n": return Vector2i(x, y - 1)
		"s": return Vector2i(x, y + 1)
		"e": return Vector2i(x + 1, y)
		"w": return Vector2i(x - 1, y)
	push_error("relative() expected [nsew], got '%s'" % dir)
	return Vector2i(x, y)


## Edits grid in place.
static func move(pawn: String, dir: String, grid: Array) -> void:
	var found := find_pawn(pawn, grid)
	var p := relative(dir, found.x, found.y)
	# move pawn to the new square
	if grid[p.y][p.x] == pawn.to_upper():
		grid[p.y][p.x] = pawn_and_fort(pawn)
	else:
		grid[p.y][p.x] = pawn
	# repaint the old square
	if found.has_fort:
		grid[found.y][found.x] = pawn.to_upper()
	else:
		grid[found.y][found.x] = "." if pawn == "r" else "_"


## Edits grid in place.
static func fortify(pawn: String, grid: Array) -> void:
	var found := find_pawn(pawn, grid)
	if found.has_fort:
		push_error("already a fort at (%d,%d)" % [found.x, found.y])
		return
	grid[found.y][found.x] = pawn_and_fort(pawn)


## Replay a step string to produce the resulting grid.
## (Case-sensitive: 'E' here is *blue east*, not the red fort+pawn board char.)
static func after(steps: String) -> Array:
	var grid := start_grid()
	for s in steps:
		match s:
			"n", "s", "e", "w": move("r", s, grid)
			"f": fortify("r", grid)
			"N", "S", "E", "W": move("b", s.to_lower(), grid)
			"F": fortify("b", grid)
			_: pass   # x X k K | have no board effect
	return grid


static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE


static func enemies_of(side: String) -> Array:
	return ["b", "B", "L"] if side == "r" else ["r", "R", "E"]


## (x, y) -> square name, e.g. (2,4) -> 'c1'
static func sq(x: int, y: int) -> String:
	return K_ROWS[x] + K_COLS[y]


## 'c1' -> (2,4); (-1,-1) for anything that isn't a square ('end', 'bank').
static func sq_to_xy(name: String) -> Vector2i:
	if name.length() != 2:
		return Vector2i(-1, -1)
	var x := K_ROWS.find(name[0])
	var y := K_COLS.find(name[1])
	if x < 0 or y < 0:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


## Unoccupied territory (no pawn, no fort) claimed by side.
static func square_count(side: String, grid: Array) -> int:
	var want := "." if side == "r" else "_"
	var n := 0
	for y in SIZE:
		for x in SIZE:
			if grid[y][x] == want:
				n += 1
	return n


static func opposite(dir: String) -> String:
	match dir:
		"n": return "s"
		"s": return "n"
		"e": return "w"
		"w": return "e"
	return ""


static func count_forts_on_board(side: String, grid: Array) -> int:
	var fort := "R" if side == "r" else "B"
	var fort_pawn := pawn_and_fort(side)
	var n := 0
	for y in SIZE:
		for x in SIZE:
			if grid[y][x] == fort or grid[y][x] == fort_pawn:
				n += 1
	return n


## Side whose turn segment index turn_idx is ('|'-split index).
static func _turn_side(turn_idx: int) -> String:
	return "r" if turn_idx % 2 == 0 else "b"


## Bonus actions consumed by side (steps at index >= 2 that aren't passes).
static func spent_moves(side: String, steps: String) -> int:
	var spent := 0
	var turns := steps.split("|")
	for turn_idx in turns.size():
		var turn: String = turns[turn_idx]
		if turn.is_empty() or _turn_side(turn_idx) != side:
			continue
		for i in range(2, turn.length()):
			if turn[i] != "x" and turn[i] != "X":
				spent += 1
	return spent


## Banked-move count for side, derived from history. Blue starts with 1.
static func banked_moves(side: String, steps: String) -> int:
	var bank := 1 if side == "b" else 0
	var turns := steps.split("|")
	for turn_idx in turns.size():
		var turn: String = turns[turn_idx]
		if turn.is_empty() or _turn_side(turn_idx) != side:
			continue
		for i in turn.length():
			var ch: String = turn[i]
			if ch == "k" or ch == "K":
				bank += 1
			elif i >= 2 and ch != "x" and ch != "X":
				bank -= 1   # spending
	return bank


## Unused forts: neither on the board nor sitting in the bank.
static func fort_supply(side: String, grid: Array, steps: String) -> int:
	return FORTS_TO_WIN - count_forts_on_board(side, grid) - banked_moves(side, steps)


## Current (possibly empty) turn segment: everything after the last '|'.
static func segment(steps: String) -> String:
	var last_pipe := steps.rfind("|")
	return steps if last_pipe == -1 else steps.substr(last_pipe + 1)


## Is the current turn segment complete?
static func is_turn_over(steps: String) -> bool:
	var seg := segment(steps)
	if seg.length() < 2:
		return false
	if "xXkK".contains(seg[seg.length() - 1]):
		return true
	# Turn is also over if the player has no bank remaining.
	return banked_moves(whose_turn(steps), steps) <= 0


static func _fix_case(side: String, s: String) -> String:
	return s.to_lower() if side == "r" else s.to_upper()


## Legal next steps for side: {step: target}. Target is a square name for
## moves/fortify, or 'end' / 'bank'. Insertion order matches the TS object
## (end, bank, n, s, e, w, f) because GDScript Dictionaries keep order.
static func valid_steps(side: String, grid: Array, steps: String) -> Dictionary:
	var res := {}
	var last_pipe := steps.rfind("|")
	var seg := segment(steps)
	var step_index := seg.length()

	# Pass / end-turn / bank options
	if step_index == 1:
		# Second step: pass is always available
		res[_fix_case(side, "x")] = "end"
		# Bank if supply > 0
		if fort_supply(side, grid, steps) > 0:
			res[_fix_case(side, "k")] = "bank"
	elif step_index >= 2:
		# End turn (free): blocked if board unchanged from turn start
		var turn_start_steps := "" if last_pipe == -1 else steps.substr(0, last_pipe + 1)
		if grid_to_board(grid) != grid_to_board(after(turn_start_steps)):
			res[_fix_case(side, "x")] = "end"

	# Direction moves
	var enemies := enemies_of(side)
	var found := find_pawn(side, grid)
	if found.is_empty():
		return res
	var x: int = found.x
	var y: int = found.y
	for step in DIRS:
		var p := relative(step, x, y)
		# Anti-reversal: block opposite direction if it undoes the previous step
		if step_index >= 1:
			var last_step := seg[seg.length() - 1]
			if step == opposite(last_step.to_lower()):
				var before_last := after(steps.substr(0, steps.length() - 1))
				var after_this := after(steps + _fix_case(side, step))
				if grid_to_board(before_last) == grid_to_board(after_this):
					continue
		if in_bounds(p.x, p.y) and not enemies.has(grid[p.y][p.x]):
			res[_fix_case(side, step)] = sq(p.x, p.y)

	# Fortify: requires supply > 0 (forts only come from supply, never bank)
	if not found.has_fort and square_count(side, grid) >= 5 and fort_supply(side, grid, steps) > 0:
		res[_fix_case(side, "f")] = sq(x, y)
	return res


## 'r', 'b', or '' (TS: null).
static func winner(grid: Array) -> String:
	var r := 0
	var b := 0
	for y in SIZE:
		for x in SIZE:
			var c: String = grid[y][x]
			if c == "R" or c == "E": r += 1
			if c == "B" or c == "L": b += 1
	if r == FORTS_TO_WIN: return "r"
	if b == FORTS_TO_WIN: return "b"
	return ""


static func nice_history(steps: String) -> Array:
	var turns: Array = []
	for t in steps.split("|"):
		if not t.is_empty():
			turns.append(t)
	var result: Array = []
	for i in range(0, turns.size(), 2):
		var red: String = turns[i]
		var blue: String = turns[i + 1] if i + 1 < turns.size() else ""
		result.append((red + " " + blue).strip_edges())
	return result
