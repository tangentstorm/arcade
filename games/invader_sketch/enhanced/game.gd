extends Node2D
## Invader Sketch (Enhanced). Visual/UI makeover of the Direct GameSketchLib
## w02 InvaderSketch port. Simulation is Direct invader_logic.gd (preloaded,
## not copied): Menu / Play / GameOver / Win, fleet, shields, 3-bullet ammo,
## Ship / Spin / Jell invaders. This file owns the 1280×720 letterbox shell:
## starfield stage, glowing sprites from the Direct sheet, shoot / kill /
## shield / invasion juice, clearer HUD, title / over / win cards, Back to
## Arcade. Esc is handled by the PauseOverlay autoload. No Alchementrix IP.
## No new core mechanics.

const Logic := preload("res://games/invader_sketch/direct/invader_logic.gd")
const SHEET := preload("res://games/invader_sketch/direct/assets/invaders.png")

const STAGE := Vector2(1280, 720)
const PX := 1.5  ## 640×480 → 960×720 field (fills height; 160 px gutters)
const FIELD := Vector2(Logic.W, Logic.H) * PX
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 0.0)
const STEP_SEC := 1.0 / Logic.FPS

const BG_TOP := Color(0.02, 0.03, 0.08)
const BG_BOTTOM := Color(0.05, 0.04, 0.12)
const PANEL := Color(0.07, 0.09, 0.18, 0.94)
const FRAME := Color(0.45, 0.82, 1.0)
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const CYAN := Color(0.35, 0.92, 1.0)
const GREEN := Color(0.42, 0.95, 0.58)
const HOT := Color(1.0, 0.48, 0.28)
const RED := Color(1.0, 0.34, 0.38)
const SHIELD_GLOW := Color(0.55, 0.95, 0.65, 0.35)
const HERO_GLOW := Color(0.45, 0.85, 1.0, 0.40)
var world = Logic.new(Logic.MENU)
var _acc := 0.0
var _just: Array = []
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _muzzle := 0.0

var _prev_invaders := 0
var _prev_shields := 0
var _prev_shield_hp := 0
var _prev_alive_bullets := 0
var _prev_enemy_bullets := 0
var _prev_state := Logic.MENU
var _kills := 0
var _started_play := false

var _field: Control
var _ui: CanvasLayer
var _cards := {}
var _inv_label: Label
var _shield_label: Label
var _ammo_label: Label
var _kill_label: Label
var _state_label: Label
var _time_label: Label
var _over_body: Label
var _win_body: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()
var _link_rect := Rect2()
var _link_hover := false


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	world = Logic.new(Logic.MENU, Time.get_ticks_usec())
	_seed_stars()
	_snap_prev()
	_build_field()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_card("title")
	_refresh_hud()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = ((size - STAGE * s) * 0.5).floor()


## One presentation step over Direct world.step (tests call this for parity).
func tick(input: Dictionary) -> void:
	world.step(input)
	_observe()


func _snap_prev() -> void:
	_prev_invaders = world.invaders.size() if world.state == Logic.PLAY else 0
	_prev_shields = world.shields.size() if world.state == Logic.PLAY else 0
	_prev_shield_hp = _shield_hp()
	_prev_alive_bullets = _alive_count(world.hero_bullets) if world.state == Logic.PLAY else 0
	_prev_enemy_bullets = world.enemy_bullets.size() if world.state == Logic.PLAY else 0
	_prev_state = world.state


func _shield_hp() -> int:
	if world.state != Logic.PLAY:
		return 0
	var hp := 0
	for s in world.shields:
		hp += int(s.health)
	return hp


func _alive_count(group: Array) -> int:
	var n := 0
	for o in group:
		if o.alive:
			n += 1
	return n


func _observe() -> void:
	if world.state == Logic.PLAY:
		# Kill juice when the fleet shrinks.
		if world.invaders.size() < _prev_invaders:
			var n: int = _prev_invaders - world.invaders.size()
			_kills += n
			for i in n:
				var at := _hero_field() + Vector2(randf_range(-80, 80), randf_range(-220, -80))
				_burst(at, HOT, 12, 2.6)
				_burst(at, GOLD, 6, 1.8)
				_float_text("+1", at + Vector2(0, -12), GOLD)
			_shake = maxf(_shake, 0.22)
		# Shield damage / destroy.
		var hp := _shield_hp()
		if hp < _prev_shield_hp:
			_burst(Vector2(Logic.W * 0.5, Logic.H - 125) * PX + FIELD_POS, GREEN, 8, 1.6)
			if world.shields.size() < _prev_shields:
				_float_text("SHIELD DOWN", FIELD_POS + Vector2(FIELD.x * 0.5 - 60, FIELD.y - 160), HOT)
				_shake = maxf(_shake, 0.35)
		# Hero muzzle when a new bullet goes live.
		var ab := _alive_count(world.hero_bullets)
		if ab > _prev_alive_bullets:
			_muzzle = 0.18
			_burst(_hero_field() + Vector2(0, -18), CYAN, 5, 1.4)
			_shake = maxf(_shake, 0.12)
		# Enemy shot spawn puff.
		if world.enemy_bullets.size() > _prev_enemy_bullets:
			_burst(FIELD_POS + Vector2(FIELD.x * 0.5, 80), RED, 4, 1.2)
	# State transitions → cards / juice.
	if world.state == Logic.PLAY and _prev_state != Logic.PLAY:
		_show_card("")
		_started_play = true
		_kills = 0
	elif world.state == Logic.GAMEOVER and _prev_state != Logic.GAMEOVER:
		_shake = 1.0
		_flash = 0.9
		_flash_color = RED
		_burst(_hero_field(), RED, 22, 3.2)
		_burst(_hero_field(), HOT, 12, 2.4)
		_update_over_card()
		_show_card("over")
	elif world.state == Logic.WIN and _prev_state != Logic.WIN:
		_flash = 0.75
		_flash_color = GOLD
		_burst(FIELD_POS + FIELD * 0.5, GOLD, 28, 2.8)
		_burst(FIELD_POS + FIELD * 0.5, CYAN, 16, 2.2)
		_update_win_card()
		_show_card("win")
	elif world.state == Logic.MENU and _prev_state != Logic.MENU:
		_show_card("title")
		_started_play = false
		_kills = 0
	_snap_prev()


func _process(delta: float) -> void:
	_time += delta
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		tick(_read_input())
		_just.clear()
		stepped = true
	_animate(delta)
	_update_link_hover()
	_refresh_hud()
	if stepped or _shake > 0.0 or _flash > 0.0 or not _particles.is_empty() or not _floaters.is_empty() or _muzzle > 0.0:
		_field.queue_redraw()
		queue_redraw()


func _read_input() -> Dictionary:
	return {
		"just": _just.duplicate(),
		"left": Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A),
		"right": Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
				or Input.is_key_pressed(KEY_E),
	}


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_just.append("space")
		KEY_R:
			_just.append("r")
		_:
			return
	get_viewport().set_input_as_handled()


func _hero_field() -> Vector2:
	if world.state == Logic.PLAY and world.hero != null:
		return FIELD_POS + Vector2(world.hero.x + Logic.CELL * 0.5, world.hero.y + Logic.CELL * 0.5) * PX
	return FIELD_POS + Vector2(FIELD.x * 0.5, FIELD.y - 60)


func _animate(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.6)
	_flash = maxf(0.0, _flash - delta * 1.9)
	_muzzle = maxf(0.0, _muzzle - delta)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.95
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos += f.vel * delta
		f.vel.y -= 16.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	if _field != null:
		var shake_off := Vector2.ZERO
		if _shake > 0.0:
			shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 7.0
		_field.position = FIELD_POS + shake_off


func _burst(at: Vector2, col: Color, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		_particles.append({
			"pos": at,
			"vel": Vector2(cos(a), sin(a)) * randf_range(24.0, 80.0) * speed,
			"r": randf_range(1.6, 3.8),
			"life": randf_range(0.25, 0.55),
			"max": 0.55,
			"col": col,
		})


func _float_text(text: String, at: Vector2, col: Color) -> void:
	_floaters.append({
		"text": text,
		"pos": at,
		"vel": Vector2(randf_range(-10.0, 10.0), -42.0),
		"life": 0.95,
		"max": 0.95,
		"col": col,
	})


func _seed_stars() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	for i in 110:
		_stars.append({
			"pos": Vector2(rng.randf() * Logic.W, rng.randf() * Logic.H),
			"r": rng.randf_range(0.6, 1.8),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.2, 3.4),
		})


func _draw() -> void:
	for i in 16:
		var t := float(i) / 15.0
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 16.0 + 1.0), BG_TOP.lerp(BG_BOTTOM, t))
	# Gutters beside the field.
	draw_rect(Rect2(0, 0, FIELD_POS.x - 6, STAGE.y), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(FIELD_POS.x + FIELD.x + 6, 0, STAGE.x - (FIELD_POS.x + FIELD.x + 6), STAGE.y), Color(0, 0, 0, 0.28))
	# Neon frame around the playfield.
	draw_rect(Rect2(FIELD_POS, FIELD).grow(5), Color(FRAME, 0.35), false, 2.0)
	if _flash > 0.0:
		var fc := _flash_color
		fc.a = _flash * 0.42
		draw_rect(Rect2(Vector2.ZERO, STAGE), fc)
	# Stage-space particles / floaters (already in stage coords).
	for part in _particles:
		var a: float = clampf(part.life / maxf(part.max, 0.01), 0.0, 1.0)
		var pc: Color = part.col
		pc.a *= a
		draw_circle(part.pos, part.r, pc)
	for f in _floaters:
		var a2: float = clampf(f.life / maxf(f.max, 0.01), 0.0, 1.0)
		var fc2: Color = f.col
		fc2.a = a2
		draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, fc2)


func _build_field() -> void:
	_field = Control.new()
	_field.name = "Field"
	_field.position = FIELD_POS
	_field.size = FIELD
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.draw.connect(_draw_field)
	_field.gui_input.connect(_on_field_gui)
	add_child(_field)


func _on_field_gui(event: InputEvent) -> void:
	# Menu link hover/click (click still does nothing — faithful to Direct).
	if event is InputEventMouseMotion:
		_update_link_hover()


func _update_link_hover() -> void:
	if _field == null:
		return
	var hover: bool = world.state == Logic.MENU and _cards.get("title", null) != null \
			and not _cards["title"].visible \
			and _link_rect.has_point(_field.get_local_mouse_position())
	# Enhanced keeps the Direct menu off-screen behind the title card; link is on the title card credit only.
	if hover != _link_hover:
		_link_hover = hover
		_field.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover else Control.CURSOR_ARROW


func _cell_rect(i: int) -> Rect2:
	return Rect2((i % 4) * Logic.CELL, (i / 4) * Logic.CELL, Logic.CELL, Logic.CELL)


func _draw_sprite(o, glow: Color = Color(0, 0, 0, 0)) -> void:
	if not o.visible:
		return
	var src := _cell_rect(o.sheet_cell())
	var dest := Rect2(Vector2(o.x, o.y) * PX, Vector2(Logic.CELL, Logic.CELL) * PX)
	if glow.a > 0.0:
		var pulse := 0.65 + 0.35 * sin(_time * 5.0 + o.x * 0.02)
		var gc := glow
		gc.a *= pulse
		_field.draw_circle(dest.get_center(), Logic.CELL * PX * 0.55, gc)
	if o.degrees == 0:
		_field.draw_texture_rect_region(SHEET, dest, src)
	else:
		var half := Vector2(o.w, o.h) * 0.5 * PX
		_field.draw_set_transform(Vector2(o.x, o.y) * PX + half, deg_to_rad(o.degrees))
		_field.draw_texture_rect_region(SHEET, Rect2(-half, Vector2(Logic.CELL, Logic.CELL) * PX), src)
		_field.draw_set_transform(Vector2.ZERO)


func _draw_field() -> void:
	# Deep space wash.
	for i in 12:
		var t := float(i) / 11.0
		_field.draw_rect(Rect2(0, FIELD.y * t, FIELD.x, FIELD.y / 12.0 + 1.0),
				Color(0.01, 0.02, 0.06).lerp(Color(0.04, 0.05, 0.12), t))
	# Stars.
	for s in _stars:
		var tw := 0.4 + 0.6 * absf(sin(_time * s.speed + s.phase))
		_field.draw_circle(s.pos * PX, s.r, Color(0.85, 0.95, 1.0, tw * 0.75))
	# Soft horizon glow near the hero row.
	_field.draw_rect(Rect2(0, FIELD.y - 90, FIELD.x, 90), Color(0.08, 0.18, 0.32, 0.22))
	match world.state:
		Logic.MENU:
			# Quiet starfield under the title card (title card covers this).
			pass
		Logic.PLAY:
			_draw_play()
		Logic.GAMEOVER, Logic.WIN:
			# Keep last play frozen visually if groups still exist; otherwise stars only.
			if world.hero != null:
				_draw_play()
	# Danger vignette when the fleet is low.
	if world.state == Logic.PLAY and not world.invaders.is_empty():
		var lowest := 0.0
		for g in world.invaders:
			lowest = maxf(lowest, g.y)
		if lowest > 250.0:
			var danger := clampf((lowest - 250.0) / 130.0, 0.0, 1.0)
			_field.draw_rect(Rect2(0, FIELD.y - 120, FIELD.x, 120), Color(RED.r, RED.g, RED.b, 0.18 * danger))


func _draw_play() -> void:
	# Draw order matches Direct: hero bullets, enemy bullets, hero, shields, invaders.
	for g in world.render_groups():
		for o in g:
			if not o.exists:
				continue
			match o.kind:
				"hero":
					_draw_sprite(o, HERO_GLOW)
					if _muzzle > 0.0:
						_field.draw_circle(Vector2(o.x + Logic.CELL * 0.5, o.y) * PX, 10.0 * _muzzle / 0.18,
								Color(CYAN.r, CYAN.g, CYAN.b, _muzzle / 0.18 * 0.7))
				"shield":
					_draw_sprite(o, SHIELD_GLOW)
				"bullet":
					if o.alive:
						var c := Vector2(o.x + 25, o.y + 25) * PX
						_field.draw_circle(c, 7.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.28))
						_draw_sprite(o)
					else:
						# Ammo rack ghosts along the bottom.
						_draw_sprite(o)
				"enemy_bullet":
					var c2 := Vector2(o.x + 25, o.y + 25) * PX
					_field.draw_circle(c2, 8.0, Color(HOT.r, HOT.g, HOT.b, 0.30))
					_draw_sprite(o)
				"ship":
					_draw_sprite(o, Color(1.0, 0.55, 0.25, 0.32))
				"spin":
					_draw_sprite(o, Color(0.55, 0.75, 1.0, 0.28))
				"jell":
					_draw_sprite(o, Color(0.45, 1.0, 0.65, 0.28))
				_:
					_draw_sprite(o)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	# Left gutter panel.
	var left := _panel(Rect2(8, 40, 144, 640))
	_ui.add_child(left)
	var title := _label("INVADER\nSKETCH", 22, GOLD)
	title.position = Vector2(12, 12)
	title.size = Vector2(120, 64)
	left.add_child(title)
	var sub := _label("Enhanced", 13, MUTED)
	sub.position = Vector2(12, 78)
	sub.size = Vector2(120, 20)
	left.add_child(sub)
	_state_label = _label("MENU", 16, CYAN)
	_state_label.position = Vector2(12, 110)
	_state_label.size = Vector2(120, 24)
	left.add_child(_state_label)
	_time_label = _label("0:00", 18, INK)
	_time_label.position = Vector2(12, 140)
	_time_label.size = Vector2(120, 24)
	left.add_child(_time_label)
	var hint := _label("←/→ A/D  move\nSpace     shoot\nEsc       pause\n\nClear the fleet.\nShields take 3 hits.\n3 bullets at once.", 13, INK)
	hint.position = Vector2(12, 190)
	hint.size = Vector2(120, 280)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	var back := _button("Back to Arcade", Color(0.22, 0.30, 0.58), 14)
	back.position = Vector2(10, 560)
	back.size = Vector2(124, 56)
	back.pressed.connect(GameRegistry.return_to_arcade)
	left.add_child(back)
	# Right gutter panel.
	var right := _panel(Rect2(STAGE.x - 152, 40, 144, 640))
	_ui.add_child(right)
	_inv_label = _label("INV  —", 20, INK)
	_inv_label.position = Vector2(12, 16)
	_inv_label.size = Vector2(120, 28)
	right.add_child(_inv_label)
	_shield_label = _label("SHD  —", 20, GREEN)
	_shield_label.position = Vector2(12, 56)
	_shield_label.size = Vector2(120, 28)
	right.add_child(_shield_label)
	_ammo_label = _label("AMMO —", 20, CYAN)
	_ammo_label.position = Vector2(12, 96)
	_ammo_label.size = Vector2(120, 28)
	right.add_child(_ammo_label)
	_kill_label = _label("KILLS 0", 20, HOT)
	_kill_label.position = Vector2(12, 136)
	_kill_label.size = Vector2(120, 28)
	right.add_child(_kill_label)
	var tip := _label("Same rules as Direct.\nPresentation only.\n\nCC-BY 3.0 course\nart + GameSketchLib.", 12, MUTED)
	tip.position = Vector2(12, 200)
	tip.size = Vector2(120, 160)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)
	# Cards.
	_cards["title"] = _make_card("INVADER SKETCH",
			"GameSketchLib course week 2\nSpace Invaders clone\n\nArrows / A,D move · Space shoot\n\nSpace / Enter to start",
			true, GOLD, "title")
	_cards["over"] = _make_card("GAME OVER", "the fleet got through\n\nSpace to return to menu", false, RED, "over")
	_cards["win"] = _make_card("YOU WON!", "fleet cleared\n\nSpace to return to menu", false, GOLD, "win")


func _panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _panel_style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if _font:
		l.add_theme_font_override("font", _font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, col: Color, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = col.lightened(0.12)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	return b


func _make_card(heading: String, body: String, with_start: bool, accent: Color, key: String) -> Control:
	var wrap := Control.new()
	wrap.visible = false
	wrap.position = FIELD_POS
	wrap.size = FIELD
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(wrap)
	var dim := ColorRect.new()
	dim.size = FIELD
	dim.color = Color(0.02, 0.03, 0.08, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dim)
	var box := _panel(Rect2((FIELD.x - 420) * 0.5, (FIELD.y - 300) * 0.5, 420, 300))
	wrap.add_child(box)
	var h := _label(heading, 30, accent)
	h.position = Vector2(20, 22)
	h.size = Vector2(380, 40)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var b := _label(body, 16, INK)
	b.name = "Body"
	b.position = Vector2(28, 78)
	b.size = Vector2(364, 140)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(b)
	if key == "over":
		_over_body = b
	elif key == "win":
		_win_body = b
	if with_start:
		var start_btn := _button("Start", Color(0.18, 0.55, 0.42), 18)
		start_btn.position = Vector2(120, 230)
		start_btn.size = Vector2(180, 44)
		start_btn.pressed.connect(_start_from_title)
		box.add_child(start_btn)
		var credit := _label("www.GameSketchLib.org", 13, Color("#9999FF"))
		credit.position = Vector2(20, 200)
		credit.size = Vector2(380, 20)
		credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(credit)
	return wrap


func _start_from_title() -> void:
	# Feed Space into Direct so Menu → Play (same path as keyboard).
	if world.state == Logic.MENU:
		_just.append("space")


func _show_card(key: String) -> void:
	for k in _cards.keys():
		_cards[k].visible = (k == key)


func _update_over_card() -> void:
	if _over_body:
		_over_body.text = "kills %d  ·  invaders left %d\n\nSpace to return to menu" % [
				_kills, world.invaders.size()]


func _update_win_card() -> void:
	if _win_body:
		var secs: int = world.frames_played / int(Logic.FPS)
		_win_body.text = "fleet cleared in %d:%02d\nkills %d\n\nSpace to return to menu" % [
				secs / 60, secs % 60, _kills]


func _refresh_hud() -> void:
	var state_names := {Logic.MENU: "MENU", Logic.PLAY: "PLAY", Logic.GAMEOVER: "OVER", Logic.WIN: "WIN"}
	_state_label.text = state_names.get(world.state, "?")
	if world.state == Logic.PLAY:
		var secs: int = world.frames_played / int(Logic.FPS)
		_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
		_inv_label.text = "INV  %d" % world.invaders.size()
		_shield_label.text = "SHD  %d" % world.shields.size()
		_ammo_label.text = "AMMO %d" % world.bullets_left
		_kill_label.text = "KILLS %d" % _kills
	elif world.state == Logic.MENU:
		_time_label.text = "—"
		_inv_label.text = "INV  —"
		_shield_label.text = "SHD  —"
		_ammo_label.text = "AMMO —"
		_kill_label.text = "KILLS %d" % _kills
	# Title start via Space / Enter also queues Direct space.
	# (handled in _unhandled_key_input via _just)
