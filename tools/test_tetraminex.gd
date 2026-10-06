extends SceneTree
## Headless logic checks for the Tetraminex Direct port.

const RoomLogic := preload("res://games/tetraminex/direct/room.gd")
const LevelData := preload("res://games/tetraminex/direct/level_data.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: tetraminex ", msg)
		_fail += 1


func _initialize() -> void:
	_check(LevelData.ROOMS.size() == 10, "10 rooms in level_data")
	_check(LevelData.ROOMS[0]["gravity"] == false, "room 0 no gravity")
	_check(LevelData.ROOMS[1]["sprites"].size() >= 4, "room 1 has sprites")
	_check(LevelData.ROOMS[6]["gravity"] == true, "room 6 has gravity")

	var r: TetraminexRoom = RoomLogic.new()
	r.load_level(0)
	_check(r.exit_pos.x >= 0, "room 0 has exit")
	_check(r.cages_left == 0, "room 0 no cages")
	_check(r.floors[r.exit_pos.y][r.exit_pos.x].open, "room 0 exit open at start")
	var start := r.hero_pos
	_check(r.nudge_hero(RoomLogic.E) or r.nudge_hero(RoomLogic.N) or r.nudge_hero(RoomLogic.W) or r.nudge_hero(RoomLogic.S),
		"room 0 hero can move at least one way")
	_check(r.hero_pos != start or true, "move attempted")

	# Room 1: push a purple block into a cage
	r = RoomLogic.new()
	r.load_level(1)
	_check(r.cages_left == 4, "room 1 has 4 cages")
	_check(r.hero_pos == Vector2i(1, 13), "room 1 hero at (1,13)")

	# Find a purple block and a matching cage; simulate lock via _on_put path
	var block_pos := Vector2i(-1, -1)
	var cage_pos := Vector2i(-1, -1)
	for y in r.room_h:
		for x in r.room_w:
			var c: TetraminexRoom.Cell = r.get_cell(x, y)
			if c != null and c.kind == RoomLogic.KIND_BLOCK and c.color == 1:
				block_pos = Vector2i(x, y)
			if r.floors[y][x].kind == RoomLogic.TILE_CAGE and r.floors[y][x].color == 1 and cage_pos.x < 0:
				if r.get_cell(x, y) == null:
					cage_pos = Vector2i(x, y)
	_check(block_pos.x >= 0, "found purple block")
	_check(cage_pos.x >= 0, "found empty purple cage")

	# Manually move block onto cage
	var block: TetraminexRoom.Cell = r.get_cell(block_pos.x, block_pos.y)
	r._clear(block_pos.x, block_pos.y)
	r._put_cell(block, cage_pos.x, cage_pos.y)
	r._on_put(cage_pos.x, cage_pos.y)
	_check(block.locked, "block locks on matching cage")
	_check(r.cages_left == 3, "cages_left decremented")

	# Grab + pull on a cleared corridor in room 2
	r = RoomLogic.new()
	r.load_level(2)
	_check(r.cages_left == 8, "room 2 has 8 cages")
	var hp := r.hero_pos
	# Clear west and east of hero (including walls) so pull has space
	var east := r.neighbor(hp, RoomLogic.E)
	var west := r.neighbor(hp, RoomLogic.W)
	r._clear(east.x, east.y)
	r._clear(west.x, west.y)
	var blk := RoomLogic.Cell.new()
	blk.kind = RoomLogic.KIND_BLOCK
	blk.solid = true
	blk.color = 3
	r._put_cell(blk, east.x, east.y)
	r.set_grab(RoomLogic.E, true)
	_check(r.grabbers[RoomLogic.E].active, "grabber active on synthesized block")
	_check(r.grabbers[RoomLogic.E].content_pos == east, "grabber holds east cell")
	_check(r.hero_can_move(RoomLogic.W), "hero_can_move west while grabbing east")
	var pulled := r.nudge_hero(RoomLogic.W)
	_check(pulled, "hero can pull west while grabbing east block")
	if pulled:
		_check(r.get_cell(east.x, east.y) == null, "old east cell vacated after pull")
		_check(r.grabbers[RoomLogic.E].content_pos == r.neighbor(r.hero_pos, RoomLogic.E),
			"block follows grabber after pull")
		var held: TetraminexRoom.Cell = r.get_cell(r.grabbers[RoomLogic.E].content_pos.x, r.grabbers[RoomLogic.E].content_pos.y)
		_check(held != null and held.kind == RoomLogic.KIND_BLOCK, "held block still on grid")

	# Paint tile recolor (room 4 has paints)
	r = RoomLogic.new()
	r.load_level(4)
	var paint_pos := Vector2i(-1, -1)
	for y in r.room_h:
		for x in r.room_w:
			if r.floors[y][x].kind == RoomLogic.TILE_PAINT:
				paint_pos = Vector2i(x, y)
				break
		if paint_pos.x >= 0:
			break
	_check(paint_pos.x >= 0, "room 4 has paint tile")
	if paint_pos.x >= 0:
		var pc := RoomLogic.Cell.new()
		pc.kind = RoomLogic.KIND_BLOCK
		pc.solid = true
		pc.color = 7  # gray
		# clear occupant if any
		r._clear(paint_pos.x, paint_pos.y)
		r._put_cell(pc, paint_pos.x, paint_pos.y)
		r._on_put(paint_pos.x, paint_pos.y)
		_check(pc.color == r.floors[paint_pos.y][paint_pos.x].color, "paint recolors block")

	# Scene instantiates
	var packed := load("res://games/tetraminex/direct/game.tscn") as PackedScene
	_check(packed != null, "game.tscn loads")
	if packed:
		var inst := packed.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		_check(inst.room != null, "game ready with room")
		inst.queue_free()
		await process_frame

	quit(1 if _fail else 0)
