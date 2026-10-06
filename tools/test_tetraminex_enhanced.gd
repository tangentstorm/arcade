extends SceneTree
## Headless checks for Tetraminex Enhanced (presentation + reused Direct logic).

const RoomLogic := preload("res://games/tetraminex/direct/room.gd")
const LevelData := preload("res://games/tetraminex/direct/level_data.gd")

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: tetraminex_enhanced ", msg)
		_fail += 1


func _initialize() -> void:
	_check(LevelData.ROOMS.size() == 10, "10 rooms available via Direct level_data")

	# Rooms 0-9 load through shared RoomLogic
	for i in 10:
		var rr: TetraminexRoom = RoomLogic.new()
		rr.load_level(i)
		_check(rr.hero_pos.x >= 0 or i in [7, 8], "room %d loads" % i)

	# Paint interaction (room 4)
	var r: TetraminexRoom = RoomLogic.new()
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
		pc.color = 7
		r._clear(paint_pos.x, paint_pos.y)
		r._put_cell(pc, paint_pos.x, paint_pos.y)
		r._on_put(paint_pos.x, paint_pos.y)
		_check(pc.color == r.floors[paint_pos.y][paint_pos.x].color, "paint recolors block")

	# Movement on room 0
	r = RoomLogic.new()
	r.load_level(0)
	var start := r.hero_pos
	var moved := r.nudge_hero(RoomLogic.E) or r.nudge_hero(RoomLogic.N) or r.nudge_hero(RoomLogic.W) or r.nudge_hero(RoomLogic.S)
	_check(moved, "room 0 hero can move")
	_check(r.hero_pos != start or not moved, "hero position updates on move")

	# Enhanced scene boot + chat + movement
	var packed := load("res://games/tetraminex/enhanced/game.tscn") as PackedScene
	_check(packed != null, "enhanced game.tscn loads")
	if packed:
		var inst := packed.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		_check(inst.room != null, "enhanced ready with room")
		_check(inst.get_node("%TalkOverlay") != null, "TalkOverlay present")
		_check(inst.get_node("%TalkPortrait") != null, "TalkPortrait present")
		_check(inst.get_node("%TalkOverlay").visible, "intro talk visible on room 0")
		# Level buttons FOCUS_NONE
		var focus_ok := true
		var lb: VBoxContainer = inst.get_node("%LevelButtons")
		for c in lb.get_children():
			if c is GridContainer:
				for b in c.get_children():
					if b is BaseButton and b.focus_mode != Control.FOCUS_NONE:
						focus_ok = false
		_check(focus_ok, "level buttons FOCUS_NONE")
		# Procedural art built
		_check(inst._tex_floor_plain != null, "procedural floor texture")
		_check(inst._tex_paints.size() == 8, "8 procedural paint textures")
		_check(inst._tex_blocks.size() == 8, "8 procedural block textures")
		# Space advances chat
		var before_level: int = inst.level_num
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = true
		inst._input(ev)
		await process_frame
		_check(inst.level_num == before_level, "Space advances talk, does not reload")
		_check(not inst.get_node("%TalkOverlay").visible, "talk dismissed after Space")
		# Movement tick
		var start_pos: Vector2i = inst.room.hero_pos
		inst._move_held[RoomLogic.E] = true
		inst._on_tick()
		_check(inst.room.hero_pos != start_pos or inst.room.hero_can_move(RoomLogic.E) == false,
			"tick applies held move when chat closed")
		# Jump to paint room and verify paint floor overlay path exists
		inst.load_level(4)
		await process_frame
		_check(inst.level_num == 4, "debug jump to room 4")
		var has_paint := false
		for y in inst.room.room_h:
			for x in inst.room.room_w:
				if inst.room.floors[y][x].kind == RoomLogic.TILE_PAINT:
					has_paint = true
		_check(has_paint, "enhanced room 4 exposes paint floors")
		inst.queue_free()
		await process_frame

	# Registry: enhanced playable
	var registry = root.get_node_or_null("GameRegistry")
	if registry == null:
		# Autoloads may be missing when run as --script SceneTree; load registry logic lightly
		_check(ResourceLoader.exists("res://games/tetraminex/enhanced/game.tscn"), "enhanced scene path exists")
	else:
		var entry = registry.get_entry("tetraminex", "enhanced")
		_check(entry != null and entry.is_playable(), "registry tetraminex/enhanced playable")
		var d = registry.get_entry("tetraminex", "direct")
		_check(d != null and d.is_playable(), "registry tetraminex/direct still playable")

	quit(1 if _fail else 0)
