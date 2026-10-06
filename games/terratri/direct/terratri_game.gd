extends RefCounted
## Immutable game snapshot, port of src/shared/Game.ts. Everything is derived
## from the step string; apply_step() returns a new snapshot.

const Rules := preload("res://games/terratri/direct/terratri_rules.gd")

var steps: String
var grid: Array
var board: String
var whose_turn: String     ## 'r', 'b', or '' once there is a winner
var winner: String         ## 'r', 'b', or ''
var red_banked: int
var blue_banked: int
var red_supply: int
var blue_supply: int
var valid_steps: Dictionary
var history: Array


func _init(p_steps: String = "") -> void:
	steps = p_steps
	grid = Rules.after(steps)
	board = Rules.grid_to_board(grid)
	winner = Rules.winner(grid)
	whose_turn = "" if winner != "" else Rules.whose_turn(steps)
	red_banked = Rules.banked_moves("r", steps)
	blue_banked = Rules.banked_moves("b", steps)
	red_supply = Rules.fort_supply("r", grid, steps)
	blue_supply = Rules.fort_supply("b", grid, steps)
	valid_steps = Rules.valid_steps(whose_turn, grid, steps) if whose_turn != "" else {}
	history = Rules.nice_history(steps)


## New snapshot with step appended ('|' added when the turn is over).
## Like the TS original this does not validate; callers check valid_steps.
func apply_step(step: String) -> RefCounted:
	var new_steps := steps + step
	if Rules.is_turn_over(new_steps):
		new_steps += "|"
	return get_script().new(new_steps)


## State after the first n atomic steps (characters, skipping '|').
static func at_step(full_steps: String, n: int) -> RefCounted:
	var count := 0
	var end := 0
	var i := 0
	while i < full_steps.length() and count < n:
		if full_steps[i] != "|":
			count += 1
		end = i + 1
		i += 1
	# Include any trailing '|' delimiter
	while end < full_steps.length() and full_steps[end] == "|":
		end += 1
	return load("res://games/terratri/direct/terratri_game.gd").new(full_steps.substr(0, end))


## Atomic step count (characters other than '|').
func step_count() -> int:
	return steps.length() - steps.count("|")


func banked(side: String) -> int:
	return red_banked if side == "r" else blue_banked


func supply(side: String) -> int:
	return red_supply if side == "r" else blue_supply


func forts_on_board(side: String) -> int:
	return Rules.count_forts_on_board(side, grid)


## Index of the step within the current turn (0 = first action).
func step_index() -> int:
	return Rules.segment(steps).length()
