extends RefCounted
class_name TetraminexRoom
## Grid puzzle room: 16×16 cells of 30px. Faithful rewrite of AS3 Room + PlayState
## grab/push/pull/cage/paint/exit rules (no Flixel).

const LevelData := preload("res://games/tetraminex/direct/level_data.gd")

const N := 3
const S := 0
const W := 2
const E := 1

const DIR_VEC := [
	Vector2i(0, 1),   # S
	Vector2i(1, 0),   # E
	Vector2i(-1, 0),  # W
	Vector2i(0, -1),  # N
]

const KIND_EMPTY := ""
const KIND_WALL := "Wall"
const KIND_HERO := "Hero"
const KIND_BLOCK := "Block"
const KIND_DOOR := "Door"
const KIND_TEDDY := "Teddy"
const KIND_IVAN := "Ivan"
const KIND_BILLBOARD := "Billboard"
const KIND_TELEPORTER := "Teleporter"

const TILE_NONE := 0
const TILE_EXIT := 1
const TILE_PAINT := 2
const TILE_CAGE := 3


class Cell:
	var kind: String = ""
	var color: int = -1
	var locked: bool = false
	var immovable: bool = false
	var solid: bool = false
	var held: bool = false
	var face: int = S
	var is_vertical: bool = false
	var visible: bool = true
	## Decorative / non-grid (Billboard sits on tiles but isn't in mSprites in AS3…
	## Billboard extends FlxSprite not GridSprite — not in room grid. We keep it out.)
	var decorative: bool = false

	func duplicate_cell() -> Cell:
		var c := Cell.new()
		c.kind = kind
		c.color = color
		c.locked = locked
		c.immovable = immovable
		c.solid = solid
		c.held = held
		c.face = face
		c.is_vertical = is_vertical
		c.visible = visible
		c.decorative = decorative
		return c


class FloorTile:
	var kind: int = TILE_NONE
	var color: int = -1
	var open: bool = false  ## for exit
	var door_pos: Vector2i = Vector2i(-1, -1)


## One grabber hand (N/S/E/W).
class Grabber:
	var dir: int = S
	var active: bool = false
	var key_held: bool = false
	var content_pos: Vector2i = Vector2i(-1, -1)  ## grid pos of held content, or (-1,-1)


var room_w: int = LevelData.ROOM_W
var room_h: int = LevelData.ROOM_H
var gravity: bool = false
var level_id: int = 0

var sprites: Array = []  ## Array of Array of Cell (or null)
var floors: Array = []   ## Array of Array of FloorTile
var wall_visual: Array = []  ## int tile codes for drawing fence
var floor_visual: Array = [] ## int tile codes for drawing tiles.png

var hero_pos: Vector2i = Vector2i.ZERO
var hero_face: int = S
var hand_count: int = 2
var grab_count: int = 0
var grabbers: Array = []  ## 4 Grabber

var cages_left: int = 0
var exit_pos: Vector2i = Vector2i(-1, -1)
var in_setup: bool = true
var solved: bool = false
var exited: bool = false

## Decor sprites not on the collision grid: [{kind, gx, gy, ...}]
var decor: Array = []

signal cage_filled(remaining: int)
signal room_solved
signal hero_exited
signal stepped


func _init() -> void:
	for i in 4:
		var g := Grabber.new()
		g.dir = i
		grabbers.append(g)


func load_level(id: int) -> void:
	assert(id >= 0 and id < LevelData.ROOMS.size())
	var data: Dictionary = LevelData.ROOMS[id]
	level_id = id
	gravity = data["gravity"]
	cages_left = 0
	solved = false
	exited = false
	in_setup = true
	exit_pos = Vector2i(-1, -1)
	decor.clear()
	grab_count = 0
	for g in grabbers:
		g.active = false
		g.key_held = false
		g.content_pos = Vector2i(-1, -1)

	sprites.clear()
	floors.clear()
	wall_visual = data["walls"]
	floor_visual = data["tiles"]
	for y in room_h:
		var srow: Array = []
		var frow: Array = []
		for x in room_w:
			srow.append(null)
			frow.append(FloorTile.new())
		sprites.append(srow)
		floors.append(frow)

	# Walls from CSV (collide index >= 4)
	for y in room_h:
		for x in room_w:
			var code: int = int(wall_visual[y][x])
			if code >= LevelData.COLLIDE_INDEX:
				var w := Cell.new()
				w.kind = KIND_WALL
				w.solid = true
				w.immovable = true
				w.visible = false
				sprites[y][x] = w

	# Floor tiles (exit / paint / cage semantics)
	for y in room_h:
		for x in room_w:
			var code: int = int(floor_visual[y][x])
			var ft: FloorTile = floors[y][x]
			if code > 0 and code < 5:
				ft.kind = TILE_EXIT
				exit_pos = Vector2i(x, y)
			elif code >= 8 and code < 16:
				ft.kind = TILE_PAINT
				ft.color = code - 8
			elif code >= 16 and code < 32:
				ft.kind = TILE_CAGE
				ft.color = code - 16
				cages_left += 1

	# Sprites from DAME placement
	for s in data["sprites"]:
		var kind: String = s["kind"]
		var gx := int(s["x"]) / LevelData.CELL
		var gy := int(s["y"]) / LevelData.CELL
		if kind == KIND_BILLBOARD:
			decor.append({"kind": kind, "gx": gx, "gy": gy})
			continue
		if kind == KIND_TELEPORTER:
			decor.append({"kind": kind, "gx": gx, "gy": gy})
			continue
		var cell := Cell.new()
		cell.kind = kind
		match kind:
			KIND_HERO:
				cell.solid = true
				cell.immovable = false
				cell.face = S
				hero_pos = Vector2i(gx, gy)
				hero_face = S
			KIND_BLOCK:
				cell.solid = true
				cell.immovable = false
				cell.color = int(LevelData.COLOR_NAMES.get(s.get("color", "gray"), 7))
			KIND_DOOR:
				cell.solid = true
				cell.immovable = true
				cell.is_vertical = bool(s.get("isVertical", false))
				cell.face = E if cell.is_vertical else S
				# Link door to exit tile if overlapping exit
				if floors[gy][gx].kind == TILE_EXIT:
					floors[gy][gx].door_pos = Vector2i(gx, gy)
			KIND_TEDDY, KIND_IVAN:
				cell.solid = true
				cell.immovable = true
				cell.face = S
			_:
				cell.solid = true
				cell.immovable = true
		_put_cell(cell, gx, gy)
		_on_put(gx, gy)

	# After doors placed, link exit→door by scanning
	if exit_pos.x >= 0:
		var c: Cell = sprites[exit_pos.y][exit_pos.x]
		if c != null and c.kind == KIND_DOOR:
			floors[exit_pos.y][exit_pos.x].door_pos = exit_pos

	done_building()


func done_building() -> void:
	if cages_left == 0 and exit_pos.x >= 0:
		_open_exit()
	in_setup = false


func get_cell(gx: int, gy: int) -> Cell:
	gx = posmod(gx, room_w)
	gy = posmod(gy, room_h)
	var c = sprites[gy][gx]
	return c


func is_empty(gx: int, gy: int) -> bool:
	return get_cell(gx, gy) == null


func neighbor(pos: Vector2i, dir: int) -> Vector2i:
	var d: Vector2i = DIR_VEC[dir]
	return Vector2i(posmod(pos.x + d.x, room_w), posmod(pos.y + d.y, room_h))


func _put_cell(cell: Cell, gx: int, gy: int) -> void:
	gx = posmod(gx, room_w)
	gy = posmod(gy, room_h)
	sprites[gy][gx] = cell


func _clear(gx: int, gy: int) -> void:
	gx = posmod(gx, room_w)
	gy = posmod(gy, room_h)
	sprites[gy][gx] = null


func holding_at(pos: Vector2i) -> bool:
	for g in grabbers:
		if g.active and g.content_pos == pos:
			return true
	return false


func _hero_holding(pos: Vector2i) -> bool:
	return holding_at(pos)


func can_move_cell(pos: Vector2i, dir: int) -> bool:
	var c: Cell = get_cell(pos.x, pos.y)
	if c == null:
		return true
	if c.immovable:
		return false
	var npos := neighbor(pos, dir)
	var n: Cell = get_cell(npos.x, npos.y)
	if n != null and n.solid:
		return false
	return true


func hero_can_move(dir: int) -> bool:
	# Can't hold the floor and move under gravity
	if gravity:
		var below := neighbor(hero_pos, S)
		if _hero_holding(below):
			return false
	for g in grabbers:
		if not _grabber_can_move(g, dir):
			return false
	var npos := neighbor(hero_pos, dir)
	var n: Cell = get_cell(npos.x, npos.y)
	if n != null and n.solid:
		if _hero_holding(npos):
			return true
		return can_move_cell(npos, dir)
	return true


func _grabber_can_move(g: Grabber, dir: int) -> bool:
	if not g.active or g.content_pos.x < 0:
		return true
	var c: Cell = get_cell(g.content_pos.x, g.content_pos.y)
	if c == null:
		return true
	var npos := neighbor(g.content_pos, dir)
	if npos == hero_pos:
		return not c.immovable
	return can_move_cell(g.content_pos, dir)


func nudge_hero(dir: int) -> bool:
	if not hero_can_move(dir):
		return false
	_nudge(hero_pos, dir)
	hero_face = dir
	var h: Cell = get_cell(hero_pos.x, hero_pos.y)
	if h != null:
		h.face = dir
	stepped.emit()
	return true


func _nudge(pos: Vector2i, dir: int) -> void:
	var c: Cell = get_cell(pos.x, pos.y)
	if c == null:
		return
	if c.kind == KIND_HERO:
		if not hero_can_move(dir):
			return
	elif not can_move_cell(pos, dir):
		return

	var npos := neighbor(pos, dir)
	var n: Cell = get_cell(npos.x, npos.y)
	if n == null or (c.kind == KIND_HERO and _hero_holding(npos)):
		pass
	else:
		_nudge(npos, dir)

	_clear(pos.x, pos.y)
	var new_pos := neighbor(pos, dir)
	if c.kind == KIND_HERO:
		# Match AS3: moved()/grabber reposition BEFORE put, so a pulled
		# block vacates the cell the hero is entering.
		hero_pos = new_pos
		_reposition_grabbers()
		_put_cell(c, new_pos.x, new_pos.y)
	else:
		_put_cell(c, new_pos.x, new_pos.y)
	_on_put(new_pos.x, new_pos.y)


func _reposition_grabbers() -> void:
	for g in grabbers:
		if not g.active:
			continue
		var gpos := neighbor(hero_pos, g.dir)
		if g.content_pos.x < 0:
			continue
		var content: Cell = get_cell(g.content_pos.x, g.content_pos.y)
		if content == null:
			g.content_pos = Vector2i(-1, -1)
			continue
		# Move content to grabber cell relative to hero
		if g.content_pos != gpos:
			_clear(g.content_pos.x, g.content_pos.y)
			_put_cell(content, gpos.x, gpos.y)
			g.content_pos = gpos
			_on_put(gpos.x, gpos.y)


func set_grab(dir: int, pressed: bool) -> void:
	var g: Grabber = grabbers[dir]
	if pressed:
		if g.key_held:
			return
		g.key_held = true
		if grab_count < hand_count:
			g.active = true
			var gpos := neighbor(hero_pos, dir)
			var c: Cell = get_cell(gpos.x, gpos.y)
			if c != null:
				c.held = true
				g.content_pos = gpos
			else:
				g.content_pos = Vector2i(-1, -1)
		grab_count += 1
	else:
		if not g.key_held:
			return
		g.key_held = false
		if g.active:
			if g.content_pos.x >= 0:
				var c: Cell = get_cell(g.content_pos.x, g.content_pos.y)
				if c != null:
					c.held = false
			g.content_pos = Vector2i(-1, -1)
			g.active = false
		grab_count = maxi(grab_count - 1, 0)


func tick_gravity() -> void:
	if not gravity:
		return
	for y in range(room_h - 1, 0, -1):
		for x in room_w:
			if get_cell(x, y) != null:
				continue
			var up: Cell = get_cell(x, y - 1)
			if up == null:
				continue
			if up.held:
				continue
			if up.kind == KIND_HERO:
				if not _hero_supported():
					_nudge(Vector2i(x, y - 1), S)
			elif not up.immovable:
				_nudge(Vector2i(x, y - 1), S)


func _hero_supported() -> bool:
	for g in grabbers:
		if not g.active or g.content_pos.x < 0:
			continue
		var c: Cell = get_cell(g.content_pos.x, g.content_pos.y)
		if c == null:
			continue
		if c.immovable:
			return true
		var below := neighbor(g.content_pos, S)
		var b: Cell = get_cell(below.x, below.y)
		if b != null and b.solid:
			return true
	return false


func _on_put(gx: int, gy: int) -> void:
	var c: Cell = get_cell(gx, gy)
	if c == null:
		return
	var ft: FloorTile = floors[gy][gx]
	if ft.kind == TILE_PAINT and c.kind == KIND_BLOCK:
		c.color = ft.color
		c.locked = false
		c.immovable = false
	elif ft.kind == TILE_CAGE and c.kind == KIND_BLOCK:
		if c.color == ft.color and not c.locked:
			c.locked = true
			c.immovable = true
			_cage_filled()
	elif ft.kind == TILE_EXIT and ft.open and c.kind == KIND_HERO:
		exited = true
		hero_exited.emit()


func _cage_filled() -> void:
	cages_left -= 1
	if not in_setup:
		cage_filled.emit(cages_left)
		if cages_left == 0:
			_solve_room()


func _solve_room() -> void:
	if solved:
		return
	solved = true
	_open_exit()
	room_solved.emit()


func _open_exit() -> void:
	if exit_pos.x < 0:
		return
	var ft: FloorTile = floors[exit_pos.y][exit_pos.x]
	ft.open = true
	var dp := ft.door_pos
	if dp.x < 0:
		# door may sit on exit cell
		var c: Cell = get_cell(exit_pos.x, exit_pos.y)
		if c != null and c.kind == KIND_DOOR:
			dp = exit_pos
	if dp.x >= 0:
		var door: Cell = get_cell(dp.x, dp.y)
		if door != null and door.kind == KIND_DOOR:
			door.solid = false
			door.visible = false
			_clear(dp.x, dp.y)


## Debug / script helpers
func force_solve() -> void:
	cages_left = 0
	_solve_room()
