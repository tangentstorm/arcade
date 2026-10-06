extends Control
## Tetraminex Episode 0 — Direct edition (Godot 4).
## Grid move, grab/push-pull, cages, paint, exits. Esc → PauseOverlay.
## Talk UI mirrors AS3 TalkWindow (talkWindow.png + portrait + Enter to advance).

const LevelData := preload("res://games/tetraminex/direct/level_data.gd")
const RoomLogic := preload("res://games/tetraminex/direct/room.gd")

const CELL := 30
const TICK := 0.10
const PLAY_W := 480
const PLAY_H := 480
const VIEW_W := 640
const VIEW_H := 480

const ASSETS := "res://games/tetraminex/direct/assets/"

## Speaker text colors from AS3 TalkWindow.talk / teddy / ernie / ivan.
const SPEAKER_COLOR := {
	"Teddy": Color(1.0, 0.4, 1.0),
	"Ernie": Color(1.0, 1.0, 0.4),
	"Ivan": Color(0.4, 1.0, 1.0),
}

var room: TetraminexRoom
var level_num: int = 0
var unlocked: int = 1  ## AS3 starts with room 0 unlocked; exit unlocks the next

var _tick_acc := 0.0
var _grab_prev := [false, false, false, false]  # S E W N
var _move_held := {RoomLogic.E: false, RoomLogic.W: false, RoomLogic.N: false, RoomLogic.S: false}
var _just_faced := false

var _tex_tiles: Texture2D
var _tex_walls: Texture2D
var _tex_blocks: Texture2D
var _tex_hero: Texture2D
var _tex_hands: Texture2D
var _tex_door: Texture2D
var _tex_teddy: Texture2D
var _tex_ivan: Texture2D
var _tex_billboard: Texture2D
var _tex_cages: Texture2D
var _tex_paints: Texture2D
var _tex_talk: Texture2D

@onready var _viewport: SubViewport = %GameViewport
@onready var _world: Node2D = %World
@onready var _floor_layer: Node2D = %FloorLayer
@onready var _wall_layer: Node2D = %WallLayer
@onready var _sprite_layer: Node2D = %SpriteLayer
@onready var _hand_layer: Node2D = %HandLayer
@onready var _decor_layer: Node2D = %DecorLayer
@onready var _hud_title: Label = %HudTitle
@onready var _hud_help: Label = %HudHelp
@onready var _level_box: VBoxContainer = %LevelButtons
@onready var _talk_overlay: ColorRect = %TalkOverlay
@onready var _talk_panel: Control = %TalkPanel
@onready var _talk_label: Label = %TalkLabel
@onready var _talk_name: Label = %TalkName
@onready var _talk_portrait: TextureRect = %TalkPortrait
@onready var _talk_hint: Label = %TalkHint
@onready var _status: Label = %StatusLabel

var _talk_queue: Array[Dictionary] = []
var _scripts_enabled := true


func _ready() -> void:
	_load_textures()
	_build_level_buttons()
	_hide_talk()
	# Never let HUD buttons steal arrows / Space / Enter from gameplay or chat.
	get_viewport().gui_release_focus()
	load_level(0)
	_hud_help.text = "Arrows move · WASD/,AOE grab · R restart · 0-9 debug jump"


func _load_textures() -> void:
	_tex_tiles = load(ASSETS + "tiles.png")
	_tex_walls = load(ASSETS + "fenceGray.png")
	_tex_blocks = load(ASSETS + "blocks.png")
	_tex_hero = load(ASSETS + "hero.png")
	_tex_hands = load(ASSETS + "hands.png")
	_tex_door = load(ASSETS + "door.png")
	_tex_teddy = load(ASSETS + "MrT.png")
	_tex_ivan = load(ASSETS + "Ivan.png")
	_tex_billboard = load(ASSETS + "billboard.png")
	_tex_cages = load(ASSETS + "cages.png")
	_tex_paints = load(ASSETS + "paints.png")
	_tex_talk = load(ASSETS + "talkWindow.png")


func load_level(num: int) -> void:
	level_num = clampi(num, 0, LevelData.ROOMS.size() - 1)
	# Visiting a room (exit or debug jump) unlocks it for the replay buttons.
	unlocked = maxi(unlocked, level_num + 1)
	_talk_queue.clear()
	_hide_talk()
	_tick_acc = 0.0
	for i in 4:
		_grab_prev[i] = false
	for k in _move_held.keys():
		_move_held[k] = false
	room = RoomLogic.new()
	room.cage_filled.connect(_on_cage_filled)
	room.room_solved.connect(_on_room_solved)
	room.hero_exited.connect(_on_hero_exited)
	room.stepped.connect(_on_stepped)
	room.load_level(level_num)
	_rebuild_world()
	_refresh_level_buttons()
	_hud_title.text = "TETRAMINEX:\nEpisode 00\nRoom %d" % level_num
	_status.text = _status_for_room()
	get_viewport().gui_release_focus()
	_run_room_intro()


func _status_for_room() -> String:
	if room.cages_left > 0:
		return "Cages left: %d" % room.cages_left
	if room.solved or room.cages_left == 0:
		return "Exit open — walk in"
	return ""


func _build_level_buttons() -> void:
	for c in _level_box.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "Replay:"
	_level_box.add_child(lbl)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_level_box.add_child(grid)
	for i in 10:
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.name = "Lev%d" % i
		# Mouse-only: Space/Enter must advance chat, arrows must move the hero.
		# (Godot Buttons default to FOCUS_ALL and consume ui_accept / ui_* arrows.)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(load_level.bind(i))
		grid.add_child(b)
	_refresh_level_buttons()


func _refresh_level_buttons() -> void:
	var grid: GridContainer = null
	for c in _level_box.get_children():
		if c is GridContainer:
			grid = c
			break
	if grid == null:
		return
	for i in mini(10, grid.get_child_count()):
		var b: Button = grid.get_child(i)
		var locked := i >= unlocked and i != level_num
		b.disabled = locked
		b.text = "-" if locked else str(i)
		if i == level_num:
			b.modulate = Color(1.0, 1.0, 0.6)
		else:
			b.modulate = Color.WHITE


func _rebuild_world() -> void:
	for layer in [_floor_layer, _wall_layer, _sprite_layer, _hand_layer, _decor_layer]:
		for c in layer.get_children():
			c.queue_free()
	# Floor visuals (tiles / cages / paints / exit)
	for y in room.room_h:
		for x in room.room_w:
			var code: int = int(room.floor_visual[y][x])
			if code <= 0:
				continue
			var spr := Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(x * CELL, y * CELL)
			spr.texture = _atlas_tile(code)
			_floor_layer.add_child(spr)
	# Wall fence visuals
	for y in room.room_h:
		for x in room.room_w:
			var code: int = int(room.wall_visual[y][x])
			if code <= 0:
				continue
			var spr := Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(x * CELL, y * CELL)
			spr.texture = _atlas_wall(code)
			_wall_layer.add_child(spr)
	# Decor
	for d in room.decor:
		var spr := Sprite2D.new()
		spr.centered = false
		spr.position = Vector2(d["gx"] * CELL, d["gy"] * CELL)
		if d["kind"] == RoomLogic.KIND_BILLBOARD:
			spr.texture = _tex_billboard
		_decor_layer.add_child(spr)
	_sync_sprites()


func _atlas_tile(code: int) -> AtlasTexture:
	## AS3 draws exit/paint/cage from tiles.png (8×3). cages.png has a blank
	## leading frame so idx*30 shifted every cage color by +1 — that made paint
	## look broken (block color no longer matched the cage graphic).
	var at := AtlasTexture.new()
	at.atlas = _tex_tiles
	var cols := 8
	at.region = Rect2((code % cols) * CELL, int(code / cols) * CELL, CELL, CELL)
	return at


func _atlas_wall(code: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = _tex_walls
	var cols := 4
	at.region = Rect2((code % cols) * CELL, (code / cols) * CELL, CELL, CELL)
	return at


func _atlas_block(color: int, locked: bool) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = _tex_blocks
	var row := 1 if locked else 0
	at.region = Rect2(color * CELL, row * CELL, CELL, CELL)
	return at


func _atlas_hero(face: int) -> AtlasTexture:
	# AS3: D=0 R=1 L=2 U=3
	var at := AtlasTexture.new()
	at.atlas = _tex_hero
	at.region = Rect2(face * CELL, 0, CELL, CELL)
	return at


func _atlas_hand(dir: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = _tex_hands
	at.region = Rect2(dir * CELL, 0, CELL, CELL)
	return at


func _atlas_door(vertical: bool) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = _tex_door
	# vertical frame 0, horizontal frame 3 (row0)
	var frame := 0 if vertical else 3
	at.region = Rect2((frame % 3) * CELL, (frame / 3) * CELL, CELL, CELL)
	return at


func _atlas_avatar(tex: Texture2D, face: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(face * CELL, 0, CELL, CELL)
	return at


func _sync_sprites() -> void:
	for c in _sprite_layer.get_children():
		c.queue_free()
	for c in _hand_layer.get_children():
		c.queue_free()
	for y in room.room_h:
		for x in room.room_w:
			var cell: TetraminexRoom.Cell = room.get_cell(x, y)
			if cell == null or not cell.visible:
				continue
			if cell.kind == RoomLogic.KIND_WALL:
				continue
			var spr := Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(x * CELL, y * CELL)
			match cell.kind:
				RoomLogic.KIND_HERO:
					spr.texture = _atlas_hero(cell.face)
				RoomLogic.KIND_BLOCK:
					spr.texture = _atlas_block(cell.color, cell.locked)
				RoomLogic.KIND_DOOR:
					spr.texture = _atlas_door(cell.is_vertical)
				RoomLogic.KIND_TEDDY:
					spr.texture = _atlas_avatar(_tex_teddy, cell.face)
				RoomLogic.KIND_IVAN:
					spr.texture = _atlas_avatar(_tex_ivan, cell.face)
				_:
					continue
			_sprite_layer.add_child(spr)
	# Grabber hands
	for g in room.grabbers:
		if not g.active:
			continue
		var gpos := room.neighbor(room.hero_pos, g.dir)
		var spr := Sprite2D.new()
		spr.centered = false
		spr.position = Vector2(gpos.x * CELL, gpos.y * CELL)
		spr.texture = _atlas_hand(g.dir)
		spr.z_index = 10
		_hand_layer.add_child(spr)


func _process(delta: float) -> void:
	if _talk_overlay.visible:
		return
	_tick_acc += delta
	while _tick_acc >= TICK:
		_tick_acc -= TICK
		_on_tick()


func _on_tick() -> void:
	var moved := false
	if _move_held[RoomLogic.E]:
		moved = room.nudge_hero(RoomLogic.E)
	elif _move_held[RoomLogic.W]:
		moved = room.nudge_hero(RoomLogic.W)
	elif _move_held[RoomLogic.N]:
		moved = room.nudge_hero(RoomLogic.N)
	elif _move_held[RoomLogic.S]:
		moved = room.nudge_hero(RoomLogic.S)
	room.tick_gravity()
	_update_grabs()
	_sync_sprites()
	if moved:
		pass


func _update_grabs() -> void:
	# WASD or ,AOE (dvorak)
	var keys := [
		Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_O),  # S
		Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_E),  # E
		Input.is_key_pressed(KEY_A),  # W
		Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_COMMA),  # N
	]
	for dir in 4:
		if keys[dir] and not _grab_prev[dir]:
			room.set_grab(dir, true)
		elif _grab_prev[dir] and not keys[dir]:
			room.set_grab(dir, false)
		_grab_prev[dir] = keys[dir]


## Modal talk: handle Space/Enter in _input (before GUI) so focused Controls
## cannot steal them for ui_accept / button activation / level reload.
func _input(event: InputEvent) -> void:
	if not _talk_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_X]:
			_advance_talk()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _talk_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		match k.keycode:
			KEY_R:
				load_level(level_num)
				get_viewport().set_input_as_handled()
			KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				# Debug jump (AS3 CONFIG::debug): any room 0-9, does not gate on unlock.
				var n := k.keycode - KEY_0
				if n < LevelData.ROOMS.size():
					load_level(n)
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				room.hero_face = RoomLogic.W
				_move_held[RoomLogic.W] = true
				_face_hero(RoomLogic.W)
			KEY_RIGHT:
				_move_held[RoomLogic.E] = true
				_face_hero(RoomLogic.E)
			KEY_UP:
				_move_held[RoomLogic.N] = true
				_face_hero(RoomLogic.N)
			KEY_DOWN:
				_move_held[RoomLogic.S] = true
				_face_hero(RoomLogic.S)
	if event is InputEventKey and not event.pressed:
		match event.keycode:
			KEY_LEFT:
				_move_held[RoomLogic.W] = false
			KEY_RIGHT:
				_move_held[RoomLogic.E] = false
			KEY_UP:
				_move_held[RoomLogic.N] = false
			KEY_DOWN:
				_move_held[RoomLogic.S] = false


func _face_hero(dir: int) -> void:
	room.hero_face = dir
	var h: TetraminexRoom.Cell = room.get_cell(room.hero_pos.x, room.hero_pos.y)
	if h != null:
		h.face = dir
	_sync_sprites()


func _on_cage_filled(remaining: int) -> void:
	_status.text = "Cages left: %d" % remaining
	if level_num == 1 and remaining == 3:
		_queue_talk("Teddy", "Exactly!\n\nGo ahead and do the others.")


func _on_room_solved() -> void:
	_status.text = "Exit open — walk in"
	match level_num:
		1:
			_queue_talk("Teddy",
				"Excellent work! I knew hiring you was a smart\nchoice.\n\nRight this way, and we'll move on to something\nmore interesting.")
		2:
			_queue_talk("Teddy", "Ernie, you're a natural!\n\nRight this way for lesson three.")
		3:
			_queue_talk("Teddy", "Nice work! Onward.")
		4:
			_queue_talk("Teddy",
				"Perfect!\n\nThat's pretty much all there is to it.\n\nLet's get the final exam out of the way so\nyou can start your new career!")
		5:
			_queue_talk("Teddy", "You passed! Onward.")


func _on_hero_exited() -> void:
	var nxt := level_num + 1
	if nxt >= LevelData.ROOMS.size():
		nxt = 0
	unlocked = maxi(unlocked, nxt + 1)
	load_level(nxt)


func _on_stepped() -> void:
	if level_num == 0:
		# After 3 steps, show Ivan/Teddy intro (simplified one-shot)
		pass


var _room0_steps := 0

func _run_room_intro() -> void:
	_room0_steps = 0
	if not _scripts_enabled:
		return
	match level_num:
		0:
			_queue_talk("Ernie",
				"What a beautiful day to start my new job!\n\nI should put my arrow keys to use and go inside.")
		1:
			_queue_talk("Teddy",
				"Okay Ernie. Let's start with the basics:\n\nAt Tetraminex, we makes tetraminos.\nYour job is to assemble them.\n\nTry it now! Use your arrow keys to push these\nblocks into their matching cages.")
		2:
			_queue_talk("Teddy",
				"Anyone can push blocks around, Ernie, but\nat Tetraminex, we do more than push blocks!\n\nThat's right! We PULL them too!\n\nUse your [WASD] or [,AOE] keys to grab these\nblocks and drag them into place.")
		3:
			_queue_talk("Teddy",
				"Sometimes you need both hands.\nPush and pull the blocks into the cages.")
		4:
			_queue_talk("Teddy",
				"Color plays a very important role in the\ntetramino industry.\n\nSometimes blocks are the wrong color, but it's\nnothing a little paint can't fix.\n\nDrag these blocks through the white-edged tiles\nto repaint them.")
		5:
			_queue_talk("Teddy",
				"Final exam time! Use everything you've learned.")
		6:
			_queue_talk("Teddy",
				"Careful — this room has gravity.")


func _queue_talk(who: String, text: String) -> void:
	_talk_queue.append({"who": who, "text": text})
	if not _talk_overlay.visible:
		_advance_talk()


func _hide_talk() -> void:
	_talk_overlay.visible = false


func _speaker_portrait(who: String) -> Texture2D:
	match who:
		"Teddy":
			return _atlas_avatar(_tex_teddy, RoomLogic.S)
		"Ivan":
			return _atlas_avatar(_tex_ivan, RoomLogic.S)
		"Ernie":
			return _atlas_hero(RoomLogic.S)
		_:
			return _atlas_hero(RoomLogic.S)


func _advance_talk() -> void:
	if _talk_queue.is_empty():
		_hide_talk()
		# Clear any move holds so a held arrow during chat doesn't lurch on dismiss.
		for k in _move_held.keys():
			_move_held[k] = false
		get_viewport().gui_release_focus()
		return
	var item: Dictionary = _talk_queue.pop_front()
	var who := str(item["who"])
	_talk_name.text = who
	_talk_label.text = str(item["text"])
	_talk_label.add_theme_color_override("font_color", SPEAKER_COLOR.get(who, Color(0.6, 0.6, 0.6)))
	_talk_portrait.texture = _speaker_portrait(who)
	_talk_hint.text = "[press enter]"
	_talk_overlay.visible = true
	get_viewport().gui_release_focus()
