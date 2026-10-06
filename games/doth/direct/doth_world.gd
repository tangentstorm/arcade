extends RefCounted
## Doth Direct — core grid simulation from doth_a.pas (Kroz-like engine).
##
## Faithful MVP: 70×20 room, walls block, hero walks N/S/E/W (and diagonals via
## keypad), pickups (coin/gem/heart/ammo) award cash/magic/health/ammo as in
## heroobj.handle message constants. Boulders are pushable once into empty floor.
## No .WLD/.ROO loader this turn — levels come from doth_levels.gd.

const Levels := preload("res://games/doth/direct/doth_levels.gd")

const MAP_W := 70
const MAP_H := 20
const HP_START := 30
const HP_MAX := 100
const CASH_START := 0
const MAGIC_START := 0
const AMMO_START := 0

enum Kind { EMPTY, WALL, FLOOR, HERO, COIN, GEM, HEART, AMMO, BOULDER }

enum State { TITLE, PLAY, WIN }

const DIR8 := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

var state := State.TITLE
var cells: PackedInt32Array = PackedInt32Array()  # MAP_W * MAP_H
var hero := Vector2i(1, 1)
var name_str := "Hero"
var rank_str := "Apprentice"
var cash := CASH_START
var magic := MAGIC_START
var health := HP_START
var health_max := HP_MAX
var ammo := AMMO_START
var message := "DOTH - Quest for the Empire"
var level_id := "overworld"
var picks_left := 0
var moves := 0


func _init() -> void:
	cells.resize(MAP_W * MAP_H)
	reset_title()


func reset_title() -> void:
	state = State.TITLE
	message = "DOTH - Quest for the Empire"
	cash = CASH_START
	magic = MAGIC_START
	health = HP_START
	ammo = AMMO_START
	moves = 0
	load_level("overworld")


func idx(x: int, y: int) -> int:
	return y * MAP_W + x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < MAP_W and p.y < MAP_H


func get_cell(p: Vector2i) -> int:
	if not in_bounds(p):
		return Kind.WALL
	return cells[idx(p.x, p.y)]


func set_cell(p: Vector2i, k: int) -> void:
	if in_bounds(p):
		cells[idx(p.x, p.y)] = k


func load_level(which: String) -> void:
	level_id = which
	var rows: Array
	match which:
		"starter":
			rows = Levels.STARTER
		_:
			rows = Levels.OVERWORLD
			level_id = "overworld"
	_apply_rows(rows)


func _apply_rows(rows: Array) -> void:
	picks_left = 0
	for y in MAP_H:
		var row: String = rows[y] if y < rows.size() else "#".repeat(MAP_W)
		for x in MAP_W:
			var ch: String = row[x] if x < row.length() else "#"
			var k := Kind.FLOOR
			match ch:
				"#":
					k = Kind.WALL
				"@", "H":
					k = Kind.FLOOR
					hero = Vector2i(x, y)
				"$":
					k = Kind.COIN
					picks_left += 1
				"*":
					k = Kind.GEM
					picks_left += 1
				"+":
					k = Kind.HEART
					picks_left += 1
				"a", "A":
					k = Kind.AMMO
					picks_left += 1
				"B", "O":
					k = Kind.BOULDER
				".":
					k = Kind.FLOOR
				_:
					k = Kind.FLOOR
			set_cell(Vector2i(x, y), k)
	set_cell(hero, Kind.HERO)


func start_play(which: String = "overworld") -> void:
	cash = CASH_START
	magic = MAGIC_START
	health = HP_START
	ammo = AMMO_START
	moves = 0
	message = "Arrows/WASD move  1=starter  Esc=pause"
	load_level(which)
	state = State.PLAY


func try_move(dx: int, dy: int) -> bool:
	if state != State.PLAY:
		return false
	if dx == 0 and dy == 0:
		return false
	var dest := hero + Vector2i(dx, dy)
	if not in_bounds(dest):
		message = "You can't leave the map."
		return false
	var k := get_cell(dest)
	match k:
		Kind.WALL:
			message = "You can't walk through walls."
			return false
		Kind.BOULDER:
			var beyond := dest + Vector2i(dx, dy)
			if get_cell(beyond) != Kind.FLOOR:
				message = "The boulder won't budge."
				return false
			set_cell(beyond, Kind.BOULDER)
			set_cell(dest, Kind.FLOOR)
			_step_onto(dest)
			return true
		Kind.COIN, Kind.GEM, Kind.HEART, Kind.AMMO, Kind.FLOOR, Kind.HERO:
			_step_onto(dest)
			return true
		_:
			return false


func _step_onto(dest: Vector2i) -> void:
	var k := get_cell(dest)
	match k:
		Kind.COIN:
			cash += 1
			picks_left = maxi(0, picks_left - 1)
			message = "You found a gold coin!"
		Kind.GEM:
			magic = mini(100, magic + 5)
			picks_left = maxi(0, picks_left - 1)
			message = "Gems give you magic!"
		Kind.HEART:
			health = mini(health_max, health + 5)
			picks_left = maxi(0, picks_left - 1)
			message = "Hearts give you health points!"
		Kind.AMMO:
			ammo = mini(100, ammo + 5)
			picks_left = maxi(0, picks_left - 1)
			message = "Ammunition - 5 shots!"
		_:
			pass
	set_cell(hero, Kind.FLOOR)
	hero = dest
	set_cell(hero, Kind.HERO)
	moves += 1
	if picks_left <= 0 and state == State.PLAY:
		state = State.WIN
		message = "Room cleared! Score %d  (Enter for title)" % score()


func score() -> int:
	return cash * 10 + magic * 5 + ammo * 2 + health + moves


func handle_title_key(code: int) -> void:
	if state == State.TITLE:
		if code == KEY_ENTER or code == KEY_SPACE or code == KEY_2:
			start_play("overworld")
		elif code == KEY_1:
			start_play("starter")
	elif state == State.WIN:
		if code == KEY_ENTER or code == KEY_SPACE:
			reset_title()
