extends Control
## Tetraminex Episode 0 — Enhanced edition (Godot 4).
## Same grid rules / rooms as Direct; modern UI + procedural tile art.
## Esc → PauseOverlay. Space/Enter advances dialog.

const LevelData := preload("res://games/tetraminex/direct/level_data.gd")
const RoomLogic := preload("res://games/tetraminex/direct/room.gd")

const CELL := 30
const TICK := 0.10
const PLAY_W := 480
const PLAY_H := 480

const ASSETS := "res://games/tetraminex/direct/assets/"

## Readable speaker accents on a light dialog card (not NES muddy pastels).
const SPEAKER_COLOR := {
	"Teddy": Color(0.72, 0.18, 0.62),
	"Ernie": Color(0.55, 0.42, 0.05),
	"Ivan": Color(0.08, 0.45, 0.55),
}

const BLOCK_COLORS := [
	Color(0.91, 0.30, 0.24),  # red
	Color(0.61, 0.35, 0.71),  # purple
	Color(0.20, 0.60, 0.86),  # blue
	Color(0.18, 0.80, 0.44),  # green
	Color(0.95, 0.77, 0.06),  # yellow
	Color(0.10, 0.74, 0.61),  # cyan
	Color(0.90, 0.49, 0.13),  # orange
	Color(0.58, 0.65, 0.65),  # gray
]

var room: TetraminexRoom
var level_num: int = 0
var unlocked: int = 1

var _tick_acc := 0.0
var _grab_prev := [false, false, false, false]
var _move_held := {RoomLogic.E: false, RoomLogic.W: false, RoomLogic.N: false, RoomLogic.S: false}

var _tex_hero: Texture2D
var _tex_hands: Texture2D
var _tex_door: Texture2D
var _tex_teddy: Texture2D
var _tex_ivan: Texture2D
var _tex_billboard: Texture2D

## Procedural atlases generated at boot.
var _tex_floor_plain: Texture2D
var _tex_exit: Texture2D
var _tex_paints: Array = []  # 8 ImageTextures
var _tex_cages: Array = []
var _tex_blocks: Array = []  # 8 unlocked
var _tex_blocks_locked: Array = []
var _tex_wall: Texture2D

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
var _room0_steps := 0


func _ready() -> void:
	_build_proc_art()
	_load_textures()
	_build_level_buttons()
	_hide_talk()
	get_viewport().gui_release_focus()
	load_level(0)
	_hud_help.text = "Arrows move | WASD/,AOE grab | R restart | 0-9 debug jump"


func _load_textures() -> void:
	_tex_hero = load(ASSETS + "hero.png")
	_tex_hands = load(ASSETS + "hands.png")
	_tex_door = load(ASSETS + "door.png")
	_tex_teddy = load(ASSETS + "MrT.png")
	_tex_ivan = load(ASSETS + "Ivan.png")
	_tex_billboard = load(ASSETS + "billboard.png")


func _img_tex(img: Image) -> ImageTexture:
	var t := ImageTexture.create_from_image(img)
	return t


func _fill_rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)


func _build_proc_art() -> void:
	# Plain floor cell: soft slate with subtle inner border.
	var floor_img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	floor_img.fill(Color(0.12, 0.15, 0.22, 1))
	_fill_rect(floor_img, Rect2i(1, 1, CELL - 2, CELL - 2), Color(0.16, 0.19, 0.28, 1))
	_tex_floor_plain = _img_tex(floor_img)

	# Exit: warm gold glow.
	var exit_img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	exit_img.fill(Color(0.45, 0.32, 0.08, 1))
	_fill_rect(exit_img, Rect2i(3, 3, CELL - 6, CELL - 6), Color(0.95, 0.78, 0.25, 1))
	_fill_rect(exit_img, Rect2i(8, 8, CELL - 16, CELL - 16), Color(1.0, 0.92, 0.55, 1))
	_tex_exit = _img_tex(exit_img)

	# Wall: cool blue-gray panel with edge highlight.
	var wall_img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	wall_img.fill(Color(0.22, 0.28, 0.40, 1))
	_fill_rect(wall_img, Rect2i(0, 0, CELL, 2), Color(0.40, 0.48, 0.62, 1))
	_fill_rect(wall_img, Rect2i(0, CELL - 2, CELL, 2), Color(0.12, 0.16, 0.24, 1))
	_tex_wall = _img_tex(wall_img)

	_tex_paints.clear()
	_tex_cages.clear()
	_tex_blocks.clear()
	_tex_blocks_locked.clear()
	for i in 8:
		var col: Color = BLOCK_COLORS[i]
		# Paint: saturated fill + thick white rim (readable vs Direct muddy tiles).
		var pimg := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		pimg.fill(Color(1, 1, 1, 1))
		_fill_rect(pimg, Rect2i(3, 3, CELL - 6, CELL - 6), col)
		_tex_paints.append(_img_tex(pimg))
		# Cage: hollow colored frame on slate.
		var cimg := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		cimg.fill(Color(0.12, 0.15, 0.22, 1))
		_fill_rect(cimg, Rect2i(2, 2, CELL - 4, CELL - 4), col.darkened(0.15))
		_fill_rect(cimg, Rect2i(6, 6, CELL - 12, CELL - 12), Color(0.12, 0.15, 0.22, 1))
		_tex_cages.append(_img_tex(cimg))
		# Block unlocked: rounded-ish solid with highlight.
		var bimg := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		bimg.fill(Color(0, 0, 0, 0))
		_fill_rect(bimg, Rect2i(2, 2, CELL - 4, CELL - 4), col.darkened(0.25))
		_fill_rect(bimg, Rect2i(4, 4, CELL - 8, CELL - 8), col)
		_fill_rect(bimg, Rect2i(5, 5, CELL - 14, 4), col.lightened(0.25))
		_tex_blocks.append(_img_tex(bimg))
		# Locked: dimmer + check mark-ish inset.
		var limg := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		limg.fill(Color(0, 0, 0, 0))
		_fill_rect(limg, Rect2i(2, 2, CELL - 4, CELL - 4), col.darkened(0.45))
		_fill_rect(limg, Rect2i(4, 4, CELL - 8, CELL - 8), col.darkened(0.2))
		_fill_rect(limg, Rect2i(10, 10, 10, 10), Color(1, 1, 1, 0.85))
		_tex_blocks_locked.append(_img_tex(limg))


func load_level(num: int) -> void:
	level_num = clampi(num, 0, LevelData.ROOMS.size() - 1)
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
	_hud_title.text = "TETRAMINEX Enhanced\nEpisode 00\nRoom %d" % level_num
	_status.text = _status_for_room()
	get_viewport().gui_release_focus()
	_run_room_intro()


func _status_for_room() -> String:
	if room.cages_left > 0:
		return "Cages left: %d" % room.cages_left
	if room.solved or room.cages_left == 0:
		return "Exit open - walk in"
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
	# Always draw a plain floor under everything so empty cells aren't black voids.
	for y in room.room_h:
		for x in room.room_w:
			var base := Sprite2D.new()
			base.centered = false
			base.position = Vector2(x * CELL, y * CELL)
			base.texture = _tex_floor_plain
			_floor_layer.add_child(base)
			var ft: TetraminexRoom.FloorTile = room.floors[y][x]
			var overlay: Texture2D = null
			match ft.kind:
				RoomLogic.TILE_EXIT:
					overlay = _tex_exit
				RoomLogic.TILE_PAINT:
					if ft.color >= 0 and ft.color < _tex_paints.size():
						overlay = _tex_paints[ft.color]
				RoomLogic.TILE_CAGE:
					if ft.color >= 0 and ft.color < _tex_cages.size():
						overlay = _tex_cages[ft.color]
			if overlay:
				var spr := Sprite2D.new()
				spr.centered = false
				spr.position = Vector2(x * CELL, y * CELL)
				spr.texture = overlay
				_floor_layer.add_child(spr)
	for y in room.room_h:
		for x in room.room_w:
			var code: int = int(room.wall_visual[y][x])
			if code <= 0:
				continue
			var spr := Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(x * CELL, y * CELL)
			spr.texture = _tex_wall
			_wall_layer.add_child(spr)
	for d in room.decor:
		var spr := Sprite2D.new()
		spr.centered = false
		spr.position = Vector2(d["gx"] * CELL, d["gy"] * CELL)
		if d["kind"] == RoomLogic.KIND_BILLBOARD:
			spr.texture = _tex_billboard
			spr.modulate = Color(0.85, 0.9, 1.0)
		_decor_layer.add_child(spr)
	_sync_sprites()


func _atlas_hero(face: int) -> AtlasTexture:
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
	var frame := 0 if vertical else 3
	at.region = Rect2((frame % 3) * CELL, (frame / 3) * CELL, CELL, CELL)
	return at


func _atlas_avatar(tex: Texture2D, face: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(face * CELL, 0, CELL, CELL)
	return at


func _block_tex(color: int, locked: bool) -> Texture2D:
	var idx := clampi(color, 0, 7)
	return _tex_blocks_locked[idx] if locked else _tex_blocks[idx]


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
					spr.modulate = Color(1.05, 1.05, 0.95)
				RoomLogic.KIND_BLOCK:
					spr.texture = _block_tex(cell.color, cell.locked)
				RoomLogic.KIND_DOOR:
					spr.texture = _atlas_door(cell.is_vertical)
					spr.modulate = Color(0.9, 0.95, 1.1)
				RoomLogic.KIND_TEDDY:
					spr.texture = _atlas_avatar(_tex_teddy, cell.face)
				RoomLogic.KIND_IVAN:
					spr.texture = _atlas_avatar(_tex_ivan, cell.face)
				_:
					continue
			_sprite_layer.add_child(spr)
	for g in room.grabbers:
		if not g.active:
			continue
		var gpos := room.neighbor(room.hero_pos, g.dir)
		var spr := Sprite2D.new()
		spr.centered = false
		spr.position = Vector2(gpos.x * CELL, gpos.y * CELL)
		spr.texture = _atlas_hand(g.dir)
		spr.modulate = Color(1.2, 1.1, 0.6)
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
	if _move_held[RoomLogic.E]:
		room.nudge_hero(RoomLogic.E)
	elif _move_held[RoomLogic.W]:
		room.nudge_hero(RoomLogic.W)
	elif _move_held[RoomLogic.N]:
		room.nudge_hero(RoomLogic.N)
	elif _move_held[RoomLogic.S]:
		room.nudge_hero(RoomLogic.S)
	room.tick_gravity()
	_update_grabs()
	_sync_sprites()


func _update_grabs() -> void:
	var keys := [
		Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_O),
		Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_E),
		Input.is_key_pressed(KEY_A),
		Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_COMMA),
	]
	for dir in 4:
		if keys[dir] and not _grab_prev[dir]:
			room.set_grab(dir, true)
		elif _grab_prev[dir] and not keys[dir]:
			room.set_grab(dir, false)
		_grab_prev[dir] = keys[dir]


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
	_status.text = "Exit open - walk in"
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
		pass


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
				"Careful - this room has gravity.")


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
		for k in _move_held.keys():
			_move_held[k] = false
		get_viewport().gui_release_focus()
		return
	var item: Dictionary = _talk_queue.pop_front()
	var who := str(item["who"])
	_talk_name.text = who
	_talk_label.text = str(item["text"])
	var accent: Color = SPEAKER_COLOR.get(who, Color(0.25, 0.25, 0.28))
	_talk_name.add_theme_color_override("font_color", accent)
	# Body text stays near-black for contrast on the light card.
	_talk_label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.18))
	_talk_portrait.texture = _speaker_portrait(who)
	_talk_hint.text = "Space / Enter"
	_talk_overlay.visible = true
	get_viewport().gui_release_focus()
