extends Node2D
## Doth (Enhanced). Presentation makeover of the Direct Doth-A MVP.
## Grid sim, pickups, boulder push and level data are Direct's doth_world.gd
## (which loads doth_levels.gd). Tiles are the Direct SvA-like procedural
## 16x16 atlas from doth_tiles.gd — preloaded, not copied. This file owns the
## 1280x720 letterbox shell: torchlit dungeon chrome, hero glow / pickup pulse,
## collect juice, side + bottom HUD, title / win cards, Back to Arcade.
## Esc is handled by the PauseOverlay autoload. No Alchementrix IP.

const World := preload("res://games/doth/direct/doth_world.gd")
const Tiles := preload("res://games/doth/direct/doth_tiles.gd")

enum { TITLE, PLAY, WIN }

const STAGE := Vector2(1280, 720)
const TILE := Tiles.TILE  ## 16 — same Direct atlas
const MAP_W := World.MAP_W
const MAP_H := World.MAP_H
const FIELD := Vector2(MAP_W * TILE, MAP_H * TILE)  ## 1120 x 320
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 88.0)  ## x=80, y=88

const BG := Color(0.04, 0.03, 0.08)
const PANEL := Color(0.09, 0.07, 0.16, 0.92)
const FRAME := Color(0.45, 0.62, 1.0)
const INK := Color(0.92, 0.94, 1.0)
const MUTED := Color(0.62, 0.66, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const MAGIC := Color(0.72, 0.45, 1.0)
const HEART := Color(1.0, 0.42, 0.48)
const AMMO_C := Color(0.95, 0.70, 0.35)
const LEAF := Color(0.45, 0.90, 0.55)
const TORCH := Color(1.0, 0.72, 0.35)

var world = World.new()
var state := TITLE
var _atlas: ImageTexture
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _squash := Vector2.ONE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _bob := {}  ## cell key -> phase offset for pickup pulse

## Presentation-only counters derived from Direct state deltas.
var coins_taken := 0
var gems_taken := 0
var hearts_taken := 0
var ammo_taken := 0
var pushes := 0
var bumps := 0
var _prev_cash := 0
var _prev_magic := 0
var _prev_health := 0
var _prev_ammo := 0
var _prev_hero := Vector2i(-1, -1)
var _prev_msg := ""
var _prev_picks := 0

var _ui: CanvasLayer
var _cards := {}
var _cash_label: Label
var _magic_label: Label
var _health_label: Label
var _ammo_label: Label
var _moves_label: Label
var _picks_label: Label
var _score_label: Label
var _map_label: Label
var _msg_label: Label
var _toast: Label
var _toast_t := 0.0
var _font: Font
var _panel_style := StyleBoxFlat.new()
var _health_bar: ProgressBar


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	_atlas = Tiles.build_atlas()
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_seed_embers()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_hud()
	_show_card("title")


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5
	if _ui:
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


func _seed_embers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1996
	_embers.clear()
	for i in 28:
		_embers.append({
			"x": rng.randf() * FIELD.x,
			"y": rng.randf() * FIELD.y,
			"z": rng.randf() * TAU,
			"s": rng.randf_range(0.6, 1.6),
		})


# --- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE, KEY_2]:
			start("overworld")
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_1:
			start("starter")
			get_viewport().set_input_as_handled()
		return
	if state == WIN:
		if e.keycode in [KEY_ENTER, KEY_SPACE]:
			_to_title()
			get_viewport().set_input_as_handled()
		return
	# PLAY
	if e.keycode == KEY_1:
		start("starter")
		get_viewport().set_input_as_handled()
		return
	if e.keycode == KEY_2:
		start("overworld")
		get_viewport().set_input_as_handled()
		return
	var d := _dir_from_key(e)
	if d != Vector2i.ZERO:
		try_move(d.x, d.y)
		get_viewport().set_input_as_handled()


func _dir_from_key(e: InputEventKey) -> Vector2i:
	match e.keycode:
		KEY_UP, KEY_W, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_A, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D, KEY_KP_6:
			return Vector2i(1, 0)
		KEY_KP_7, KEY_HOME:
			return Vector2i(-1, -1)
		KEY_KP_9, KEY_PAGEUP:
			return Vector2i(1, -1)
		KEY_KP_1, KEY_END:
			return Vector2i(-1, 1)
		KEY_KP_3, KEY_PAGEDOWN:
			return Vector2i(1, 1)
		_:
			pass
	match e.physical_keycode:
		KEY_W:
			return Vector2i(0, -1)
		KEY_S:
			return Vector2i(0, 1)
		KEY_A:
			return Vector2i(-1, 0)
		KEY_D:
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO


func start(which: String = "overworld") -> void:
	world.start_play(which)
	state = PLAY
	coins_taken = 0
	gems_taken = 0
	hearts_taken = 0
	ammo_taken = 0
	pushes = 0
	bumps = 0
	_snap_prev()
	_show_card("")
	_burst(_cell_center(world.hero), GOLD, 16, 90.0)
	_refresh_hud()


func _to_title() -> void:
	world.reset_title()
	state = TITLE
	_show_card("title")
	_refresh_hud()


## Public for tests: one Direct try_move + presentation delta.
func try_move(dx: int, dy: int) -> bool:
	if state != PLAY:
		return false
	_snap_prev()
	var ok: bool = world.try_move(dx, dy)
	_on_world_step(ok)
	_refresh_hud()
	return ok


func _snap_prev() -> void:
	_prev_cash = world.cash
	_prev_magic = world.magic
	_prev_health = world.health
	_prev_ammo = world.ammo
	_prev_hero = world.hero
	_prev_msg = world.message
	_prev_picks = world.picks_left


func _on_world_step(moved: bool) -> void:
	if not moved:
		bumps += 1
		_shake = minf(0.55, _shake + 0.25)
		_squash = Vector2(1.18, 0.82)
		return
	var feet := _cell_center(world.hero)
	_squash = Vector2(0.82, 1.18)
	# Detect boulder push: hero advanced and a boulder now sits beyond.
	var delta: Vector2i = world.hero - _prev_hero
	if delta != Vector2i.ZERO:
		var beyond: Vector2i = world.hero + delta
		if world.in_bounds(beyond) and world.get_cell(beyond) == World.Kind.BOULDER:
			pushes += 1
			_burst(_cell_center(beyond), Color(0.7, 0.65, 0.55), 10, 50.0)
	if world.cash > _prev_cash:
		coins_taken += world.cash - _prev_cash
		_burst(feet, GOLD, 14, 80.0)
		_float(feet + Vector2(-20, -18), "+GOLD", GOLD)
	if world.magic > _prev_magic:
		gems_taken += 1
		_burst(feet, MAGIC, 14, 80.0)
		_float(feet + Vector2(-24, -18), "+MAGIC", MAGIC)
	if world.health > _prev_health:
		hearts_taken += 1
		_burst(feet, HEART, 14, 80.0)
		_flash = 0.35
		_flash_color = HEART
		_float(feet + Vector2(-28, -18), "+HEALTH", HEART)
	if world.ammo > _prev_ammo:
		ammo_taken += 1
		_burst(feet, AMMO_C, 12, 70.0)
		_float(feet + Vector2(-20, -18), "+AMMO", AMMO_C)
	if world.state == World.State.WIN and state == PLAY:
		state = WIN
		_show_card("win")
		_flash = 0.7
		_flash_color = GOLD
		_burst(feet, GOLD, 28, 120.0, 40.0)
		_show_toast("ROOM CLEARED!  score %d" % world.score())


func _process(delta: float) -> void:
	_time += delta
	_animate(delta)
	queue_redraw()


func _animate(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	_flash = move_toward(_flash, 0.0, delta * 1.8)
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * 14.0))
	_toast_t = maxf(0.0, _toast_t - delta)
	if _toast:
		_toast.visible = _toast_t > 0.0
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.92
		p.vel.y += float(p.get("grav", 0.0)) * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 28.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)


# --- juice helpers ------------------------------------------------------------

func _cell_center(cell: Vector2i) -> Vector2:
	return FIELD_POS + Vector2(cell.x + 0.5, cell.y + 0.5) * TILE


func _burst(at: Vector2, color: Color, n: int, speed: float, grav := 60.0) -> void:
	for i in n:
		var a := randf() * TAU
		_particles.append({
			"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed),
			"life": randf_range(0.35, 0.8), "max": 0.8, "color": color,
			"size": randf_range(2.0, 5.0), "grav": grav,
		})


func _float(at: Vector2, text: String, color: Color) -> void:
	at.x = clampf(at.x, FIELD_POS.x + 6.0, FIELD_POS.x + FIELD.x - 120.0)
	_floaters.append({"pos": at, "life": 1.0, "max": 1.0, "text": text, "color": color})


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.2


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake * _shake
	var fr := Rect2(FIELD_POS, FIELD)
	draw_rect(fr.grow(10), Color(0.02, 0.015, 0.04))
	draw_rect(fr.grow(6), Color(FRAME, 0.35), false, 2.0)
	draw_set_transform(shake)
	_draw_backdrop()
	_draw_map()
	_draw_torch_glow()
	_draw_particles()
	_draw_floaters()
	draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		draw_rect(fr, Color(_flash_color, _flash * 0.4))
	# Mask anything that strays outside the field.
	var o := fr.grow(10)
	draw_rect(Rect2(0, 0, STAGE.x, o.position.y), BG)
	draw_rect(Rect2(0, o.end.y, STAGE.x, STAGE.y - o.end.y), BG)
	draw_rect(Rect2(0, o.position.y, o.position.x, o.size.y), BG)
	draw_rect(Rect2(o.end.x, o.position.y, STAGE.x - o.end.x, o.size.y), BG)


func _draw_backdrop() -> void:
	# Deep dungeon wash behind the tiles (visible in floor grit / empty edges).
	var top := Color(0.08, 0.06, 0.16)
	var bot := Color(0.04, 0.05, 0.10)
	for i in 16:
		var t := i / 16.0
		var c := top.lerp(bot, t)
		draw_rect(Rect2(FIELD_POS + Vector2(0, FIELD.y * t), Vector2(FIELD.x, FIELD.y / 16.0 + 1)), c)
	for e in _embers:
		var a := 0.15 + 0.35 * absf(sin(_time * 1.7 + e.z))
		var p := FIELD_POS + Vector2(e.x + sin(_time * 0.4 + e.z) * 6.0,
				e.y + cos(_time * 0.55 + e.z) * 4.0)
		draw_circle(p, 1.2 * e.s, Color(TORCH, a * 0.35))


func _tile_id(kind: int) -> int:
	match kind:
		World.Kind.WALL:
			return Tiles.Id.WALL
		World.Kind.HERO:
			return Tiles.Id.HERO
		World.Kind.COIN:
			return Tiles.Id.COIN
		World.Kind.GEM:
			return Tiles.Id.GEM
		World.Kind.HEART:
			return Tiles.Id.HEART
		World.Kind.AMMO:
			return Tiles.Id.AMMO
		World.Kind.BOULDER:
			return Tiles.Id.BOULDER
		_:
			return Tiles.Id.FLOOR


func _draw_map() -> void:
	# On title, show Direct overworld under the card for atmosphere.
	for y in MAP_H:
		for x in MAP_W:
			var k: int = world.cells[world.idx(x, y)]
			var tid := _tile_id(k)
			var at := FIELD_POS + Vector2(x, y) * TILE
			var dest := Rect2(at, Vector2(TILE, TILE))
			# Floor under entities.
			if tid != Tiles.Id.FLOOR and tid != Tiles.Id.WALL:
				draw_texture_rect_region(_atlas, dest, Tiles.src(Tiles.Id.FLOOR))
			if tid == Tiles.Id.WALL:
				# Soft drop shadow under brick faces.
				draw_rect(Rect2(at + Vector2(1, 2), Vector2(TILE, TILE)), Color(0, 0, 0, 0.22))
				draw_texture_rect_region(_atlas, dest, Tiles.src(tid))
			elif tid == Tiles.Id.HERO and state != TITLE:
				# Hero drawn with squash after the map loop.
				pass
			elif tid in [Tiles.Id.COIN, Tiles.Id.GEM, Tiles.Id.HEART, Tiles.Id.AMMO]:
				var key := y * MAP_W + x
				if not _bob.has(key):
					_bob[key] = randf() * TAU
				var bob := sin(_time * 3.2 + float(_bob[key])) * 1.5
				var glow_c := GOLD
				match tid:
					Tiles.Id.GEM:
						glow_c = MAGIC
					Tiles.Id.HEART:
						glow_c = HEART
					Tiles.Id.AMMO:
						glow_c = AMMO_C
				draw_circle(at + Vector2(TILE * 0.5, TILE * 0.5 + bob), 7.0,
						Color(glow_c, 0.12 + 0.08 * absf(sin(_time * 4.0 + float(_bob[key])))))
				draw_texture_rect_region(_atlas,
						Rect2(at + Vector2(0, bob), Vector2(TILE, TILE)), Tiles.src(tid))
			elif tid == Tiles.Id.BOULDER:
				draw_rect(Rect2(at + Vector2(2, 3), Vector2(TILE - 2, TILE - 2)), Color(0, 0, 0, 0.28))
				draw_texture_rect_region(_atlas, dest, Tiles.src(tid))
			else:
				draw_texture_rect_region(_atlas, dest, Tiles.src(tid))
	if state != TITLE and world.get_cell(world.hero) == World.Kind.HERO:
		_draw_hero()


func _draw_hero() -> void:
	var at := FIELD_POS + Vector2(world.hero) * TILE
	var feet := at + Vector2(TILE * 0.5, TILE - 1.0)
	# Ground shadow + soft torch glow under feet.
	draw_circle(feet + Vector2(0, 1), 7.0, Color(0, 0, 0, 0.35))
	draw_circle(feet + Vector2(0, -6), 14.0, Color(TORCH, 0.10))
	draw_set_transform(feet, 0.0, _squash)
	draw_texture_rect_region(_atlas, Rect2(Vector2(-TILE * 0.5, -TILE + 1.0), Vector2(TILE, TILE)),
			Tiles.src(Tiles.Id.HERO))
	draw_set_transform(Vector2.ZERO)


func _draw_torch_glow() -> void:
	if state == TITLE:
		return
	var c := _cell_center(world.hero)
	var pulse := 0.55 + 0.45 * sin(_time * 5.0)
	draw_circle(c, 70.0, Color(TORCH, 0.04 * pulse))
	draw_circle(c, 36.0, Color(TORCH, 0.07 * pulse))


func _draw_particles() -> void:
	for p in _particles:
		var a := clampf(p.life / maxf(float(p.max), 0.001), 0.0, 1.0)
		draw_circle(p.pos, float(p.size) * (0.5 + 0.5 * a), Color(p.color, a * 0.85))


func _draw_floaters() -> void:
	for f in _floaters:
		var a := clampf(f.life / maxf(float(f.max), 0.001), 0.0, 1.0)
		var col: Color = f.color
		col.a = a
		draw_string(_font, f.pos + Vector2(2, 2), str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, a * 0.55))
		draw_string(_font, f.pos, str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)


# --- HUD / cards --------------------------------------------------------------

func _refresh_hud() -> void:
	_cash_label.text = "%04d" % world.cash
	_magic_label.text = "%03d" % world.magic
	_health_label.text = "%03d / %03d" % [world.health, world.health_max]
	_ammo_label.text = "%03d" % world.ammo
	_moves_label.text = str(world.moves)
	_picks_label.text = str(world.picks_left)
	_score_label.text = str(world.score()) if world.state != World.State.TITLE else "—"
	_map_label.text = world.level_id
	_msg_label.text = world.message
	if _health_bar:
		_health_bar.max_value = world.health_max
		_health_bar.value = world.health


func _show_card(key: String) -> void:
	for k in _cards:
		_cards[k].visible = (k == key and key != "")


func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.15) if st == "hover" else color.darkened(0.15) if st == "pressed" else color
		s.border_color = color.lightened(0.45)
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 6
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(st, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


func _panel(root: Control, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _panel_style.duplicate())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = rect.position
	p.size = rect.size
	root.add_child(p)
	return p


func _add(parent: Control, c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	parent.add_child(c)
	return c


func _stat(parent: Control, y: float, name: String, color: Color, big := 28) -> Label:
	_add(parent, _label(name, 12, MUTED), Rect2(16, y, 200, 18))
	return _add(parent, _label("0", big, color), Rect2(16, y + 16, 200, 36)) as Label


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = STAGE
	_ui.add_child(root)

	var title := _label("DOTH", 28, FRAME.lightened(0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, title, Rect2(0, 8, STAGE.x, 32))
	var sub := _label("Enhanced  ·  Quest for the Empire", 13, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, sub, Rect2(0, 40, STAGE.x, 20))

	var back := _button("Back to Arcade", Color(0.35, 0.22, 0.48), 17)
	back.position = Vector2(14, 10)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)

	# Bottom HUD strip under the 1120x320 field (field ends ~ y=408).
	var bp := _panel(root, Rect2(80, 430, 1120, 260))
	var cols := [
		[16, "GOLD", GOLD], [200, "MAGIC", MAGIC], [400, "HEALTH", HEART],
		[640, "AMMO", AMMO_C], [800, "MOVES", INK], [960, "PICKS LEFT", LEAF],
	]
	var vals: Array[Label] = []
	for col in cols:
		_add(bp, _label(col[1], 12, MUTED), Rect2(col[0], 12, 150, 18))
		var vl := _add(bp, _label("0", 28 if col[1] != "HEALTH" else 24, col[2]),
				Rect2(col[0], 28, 150, 36)) as Label
		vals.append(vl)
	_cash_label = vals[0]
	_magic_label = vals[1]
	_health_label = vals[2]
	_ammo_label = vals[3]
	_moves_label = vals[4]
	_picks_label = vals[5]

	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.max_value = World.HP_MAX
	_health_bar.value = World.HP_START
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.15, 0.08, 0.12)
	hs.set_corner_radius_all(6)
	var hf := StyleBoxFlat.new()
	hf.bg_color = HEART
	hf.set_corner_radius_all(6)
	_health_bar.add_theme_stylebox_override("background", hs)
	_health_bar.add_theme_stylebox_override("fill", hf)
	_add(bp, _health_bar, Rect2(400, 68, 200, 14))

	_add(bp, _label("SCORE", 12, MUTED), Rect2(16, 90, 120, 18))
	_score_label = _add(bp, _label("—", 24, GOLD), Rect2(16, 106, 160, 32)) as Label
	_add(bp, _label("MAP", 12, MUTED), Rect2(200, 90, 120, 18))
	_map_label = _add(bp, _label("overworld", 20, FRAME.lightened(0.2)), Rect2(200, 106, 220, 32)) as Label

	_msg_label = _add(bp, _label("", 15, MUTED), Rect2(16, 160, 720, 50)) as Label
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_add(bp, _label("MOVE", 12, MUTED), Rect2(780, 90, 300, 18))
	_add(bp, _label("Arrows / WASD / numpad (diagonals OK)", 14, INK), Rect2(780, 108, 320, 22))
	_add(bp, _label("1 starter chamber   ·   2 overworld", 14, INK), Rect2(780, 132, 320, 22))
	_add(bp, _label("Esc — pause / Back to Arcade", 13, MUTED), Rect2(780, 160, 320, 22))
	_add(bp, _label("Same Direct doth_world rules.\nSvA-like tiles shared from Direct.", 13, MUTED),
			Rect2(780, 200, 320, 48))

	_toast = _label("", 26, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_add(root, _toast, Rect2(FIELD_POS.x, FIELD_POS.y + 12, FIELD.x, 36))

	_cards["title"] = _make_card(root, [
		["DOTH", 46, GOLD],
		["Enhanced edition", 18, FRAME],
		["Quest for the Empire — torchlit makeover of the Direct MVP.", 14, MUTED],
		["Same walls, pickups, boulder push. Direct SvA-like pixels.", 14, MUTED],
		["Enter / Space / 2  —  overworld (dmap1)", 16, INK],
		["1  —  starter chamber", 16, INK],
	])
	_cards["win"] = _make_card(root, [
		["ROOM CLEARED!", 40, GOLD],
		["Every pickup claimed.", 16, MUTED],
		["Enter / Space — title", 18, LEAF],
	])


func _make_card(root: Control, rows: Array) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, holder, Rect2(Vector2.ZERO, STAGE))
	var tc := CenterContainer.new()
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(holder, tc, Rect2(FIELD_POS, FIELD))
	var tp := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.08, 0.06, 0.14, 0.94)
	ts.border_color = FRAME
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(18)
	ts.shadow_color = Color(FRAME, 0.25)
	ts.shadow_size = 16
	ts.set_content_margin_all(28)
	tp.add_theme_stylebox_override("panel", ts)
	tc.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	tp.add_child(tv)
	for row in rows:
		var l := _label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(l)
	holder.visible = false
	return holder
