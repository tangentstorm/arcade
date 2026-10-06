extends Node2D
## oK Defender (Enhanced). Presentation makeover of the Direct Defender clone.
## Rules, terrain, aliens, phasers, scoring and win/lose are Direct's
## ok_defender_logic.gd (preloaded, not copied). This file owns the 1280x720
## letterbox shell, ship/terrain/HUD juice, restyled title / game-over cards,
## and Back to Arcade. Esc is handled by the PauseOverlay autoload.
## No Alchementrix IP.

const Logic := preload("res://games/ok_defender/direct/ok_defender_logic.gd")
const SHIP_STOP := preload("res://games/ok_defender/direct/sprites/ship-stop-r.png")
const SHIP_THRUST := preload("res://games/ok_defender/direct/sprites/ship-thrust-r.png")
const ALIEN := preload("res://games/ok_defender/direct/sprites/alien0.png")
const BEAM := preload("res://games/ok_defender/direct/sprites/beam.png")
const HUMAN := preload("res://games/ok_defender/direct/sprites/human.png")
const HUMAN_ASH := preload("res://games/ok_defender/direct/sprites/human-ash.png")

const STAGE := Vector2(1280, 720)
const PX := 3.0  ## 320x200 -> 960x600 field
const FIELD := Vector2(Logic.W, Logic.H) * PX
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 72.0)
const STEP_SEC := 1.0 / Logic.FPS

const BG_TOP := Color(0.03, 0.05, 0.10)
const BG_BOTTOM := Color(0.06, 0.03, 0.12)
const PANEL := Color(0.08, 0.10, 0.20, 0.92)
const FRAME := Color(0.35, 0.78, 0.95)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const GREEN := Color(0.45, 0.95, 0.55)
const RED := Color(1.0, 0.35, 0.42)
const ORANGE := Color(1.0, 0.62, 0.28)
const PHASER_COLORS := [Color("#ff4d5a"), Color("#ff8aa0"), Color("#ffb04a"), Color("#ffe66d")]

var world = Logic.new(Logic.TITLE)
var _acc := 0.0
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _stars: Array[Vector2] = []
var _prev := {"kills": 0, "saved": 0, "carried": 0, "lost": 0, "crashed": false, "state": Logic.TITLE, "ph": 0, "al": 0}

var _ui: CanvasLayer
var _cards := {}
var _time_label: Label
var _kills_label: Label
var _saved_label: Label
var _lost_label: Label
var _humans_label: Label
var _carry_label: Label
var _score_label: Label
var _over_why: Label
var _over_score: Label
var _over_detail: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_seed_stars()
	_snap_prev()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_hud()
	_show_card("title" if world.state == Logic.TITLE else "")


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5


func _process(delta: float) -> void:
	_time += delta
	_acc = minf(_acc + delta, 0.25)
	var stepped := false
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step(_read_input())
		stepped = true
	if stepped:
		_on_world_step()
	_animate(delta)
	_refresh_hud()
	queue_redraw()


func _read_input() -> Dictionary:
	var dx := int(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) \
			- int(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	var dy := int(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) \
			- int(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W))
	return {"dx": dx, "dy": dy, "fire": Input.is_key_pressed(KEY_SPACE)}


func _snap_prev() -> void:
	_prev.kills = world.kills
	_prev.saved = world.saved
	_prev.carried = world.carried
	_prev.lost = world.lost
	_prev.crashed = world.crashed
	_prev.state = world.state
	_prev.ph = world.ph.size()
	_prev.al = world.al.size()


func _on_world_step() -> void:
	# Juice from Direct state deltas (presentation only).
	if world.kills > int(_prev.kills):
		var n: int = world.kills - int(_prev.kills)
		for i in n:
			_burst(_ship_screen(), GREEN, 14, 90.0)
		_float(_ship_screen() + Vector2(0, -24), "+KILL", GREEN)
	if world.carried > int(_prev.carried):
		_burst(_ship_screen(), GOLD, 10, 60.0)
		_float(_ship_screen() + Vector2(0, -18), "CAUGHT", GOLD)
	if world.saved > int(_prev.saved):
		var n2: int = world.saved - int(_prev.saved)
		_burst(_ship_screen() + Vector2(0, 20), ORANGE, 12 + n2 * 4, 70.0)
		_float(_ship_screen() + Vector2(0, 28), "SAVED +%d" % n2, ORANGE)
	if world.lost > int(_prev.lost):
		_float(_ship_screen() + Vector2(0, -12), "LOST", RED)
	if world.crashed and not bool(_prev.crashed):
		_shake = 1.0
		_flash = 0.85
		_flash_color = RED
		_burst(_ship_screen(), RED, 28, 140.0)
	if world.state == Logic.PLAY and int(_prev.state) != Logic.PLAY:
		_show_card("")
		_trail.clear()
	if world.state == Logic.GAMEOVER and int(_prev.state) != Logic.GAMEOVER:
		_show_gameover()
	if world.thrust:
		var sp := _ship_screen() + Vector2(-world.sh_d * 18.0, 8.0)
		_particles.append({
			"pos": sp, "vel": Vector2(-world.sh_d * randf_range(20, 60), randf_range(-20, 20)),
			"life": 0.35, "max": 0.35, "color": Color(0.4, 0.85, 1.0, 0.9),
			"size": randf_range(2.0, 4.0), "grav": 0.0,
		})
		_trail.append(_ship_screen() + Vector2(Logic.SHIP_W * 0.5 * PX * 0.0, Logic.SHIP_H * 0.35 * PX * 0.0))
		if _trail.size() > 18:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	_snap_prev()


func _animate(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 2.8)
	_flash = move_toward(_flash, 0.0, delta * 2.2)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.94
		p.vel.y += float(p.get("grav", 0.0)) * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 28.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)


func _ship_screen() -> Vector2:
	return FIELD_POS + Vector2(_sx(world.sh.x) + Logic.SHIP_W * 0.5, world.sh.y + Logic.SHIP_H * 0.5) * PX


func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(speed * 0.3, speed)
		_particles.append({
			"pos": at, "vel": Vector2(cos(a), sin(a)) * sp,
			"life": randf_range(0.3, 0.7), "max": 0.7,
			"color": color, "size": randf_range(2.0, 5.0), "grav": 40.0,
		})


func _float(at: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": at, "life": 1.0, "max": 1.0, "text": text, "color": color})


func _seed_stars() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 80:
		_stars.append(Vector2(rng.randf() * Logic.W, rng.randf() * (Logic.H * 0.55)))


# --- screen-space helpers (world -> field) ------------------------------------

func _sx(x: float) -> float:
	return fposmod(x - world.cam_x, world.world_w)


func _to_field(p: Vector2) -> Vector2:
	return FIELD_POS + Vector2(_sx(p.x), p.y) * PX


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake * _shake
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	# vignette-ish bottom wash
	draw_rect(Rect2(0, STAGE.y * 0.55, STAGE.x, STAGE.y * 0.45), BG_BOTTOM)

	draw_set_transform(shake)
	_draw_field()
	_draw_particles()
	_draw_floaters()
	draw_set_transform(Vector2.ZERO)

	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, STAGE), Color(_flash_color, _flash * 0.45))


func _draw_field() -> void:
	var fr := Rect2(FIELD_POS, FIELD)
	# Clip to field with a frame.
	draw_rect(fr.grow(6), Color(0.02, 0.03, 0.06))
	draw_rect(fr.grow(4), Color(FRAME, 0.35), false, 2.0)

	# Sky bands (Direct SKY) with soft starfield over the upper half.
	for i in Logic.SKY.size():
		var y0 := FIELD_POS.y + 30.0 * i * PX
		var band := Rect2(FIELD_POS.x, y0, FIELD.x, 30.0 * PX)
		draw_rect(band, Logic.SKY[i])
		# slight top highlight for depth
		draw_rect(Rect2(band.position, Vector2(band.size.x, 2)), Color(1, 1, 1, 0.03))
	for s in _stars:
		var tw := 0.45 + 0.55 * absf(sin(_time * 2.0 + s.x * 0.1))
		draw_circle(FIELD_POS + s * PX, 1.2, Color(0.85, 0.95, 1.0, tw * 0.7))

	# Ship thrust trail (screen-space points already).
	for i in _trail.size():
		var t := float(i) / maxf(float(_trail.size()), 1.0)
		draw_circle(_trail[i], lerpf(1.5, 5.0, t), Color(0.35, 0.85, 1.0, t * 0.45))

	# Sprites in Direct draw order, scaled.
	for h in world.hu:
		_blit(HUMAN, h)
	for a in world.ash:
		_blit(HUMAN_ASH, a.pos)
	for h in world.fh:
		_blit_falling(h.pos)
	for a in world.al:
		if a.be:
			_blit(BEAM, Vector2(a.x, a.y) + Logic.BM_OFS)
			# beam glow
			var bp := _to_field(Vector2(a.x, a.y) + Logic.BM_OFS + Vector2(Logic.BEAM_W * 0.5, Logic.BEAM_H * 0.5))
			draw_circle(bp, 10.0 + 3.0 * sin(_time * 10.0), Color(0.3, 1.0, 0.55, 0.22))
	for a in world.al:
		_blit(ALIEN, Vector2(a.x, a.y))
	if world.state != Logic.GAMEOVER or not world.crashed or (world.f / 4) % 2 == 0:
		var tex: Texture2D = SHIP_THRUST if world.thrust else SHIP_STOP
		_blit(tex, world.sh, world.sh_d < 0)
		if world.thrust:
			var sp := _to_field(world.sh + Vector2(Logic.SHIP_W * 0.5, Logic.SHIP_H * 0.45))
			draw_circle(sp, 14.0, Color(0.4, 0.9, 1.0, 0.18))
	for p in world.ph:
		for i in 4:
			_rect_world(p.pos + Vector2(i, 0), Vector2(1, 1), PHASER_COLORS[i])
		# phaser streak
		var tip := _to_field(p.pos + Vector2(2, 0.5))
		draw_circle(tip, 3.5, Color(1.0, 0.9, 0.4, 0.55))

	# Ground over sprites (Direct quirk), with lit ridge.
	for i in world.gnd_w.size():
		var top := world.ground_top_i(i)
		var base := Color(world.gnd_c[i])
		_rect_world(Vector2(world.gnd_x[i], top), Vector2(world.gnd_w[i], world.gnd_h[i]), base)
		_rect_world(Vector2(world.gnd_x[i], top), Vector2(world.gnd_w[i], 2), base.lightened(0.35))
		_rect_world(Vector2(world.gnd_x[i], top + world.gnd_h[i] - 4), Vector2(world.gnd_w[i], 4), base.darkened(0.25))

	_draw_minimap()
	# Field inner frame on top
	draw_rect(fr, Color(FRAME, 0.55), false, 2.0)


func _blit(tex: Texture2D, p: Vector2, flip := false) -> void:
	var sx := _sx(p.x)
	var sz := tex.get_size()
	for ox in [sx, sx - world.world_w]:
		if ox > Logic.W or ox + sz.x < 0:
			continue
		var at := FIELD_POS + Vector2(ox, p.y) * PX
		var dest := Rect2(at, sz * PX)
		if flip:
			draw_set_transform(at + Vector2(dest.size.x, 0) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 0.0,
					0.0, Vector2(-1, 1))
			draw_texture_rect(tex, Rect2(Vector2.ZERO, dest.size), false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(tex, dest, false)


func _blit_falling(p: Vector2) -> void:
	var rot: int = world.fall_rot
	var offs := [Vector2(0, 0), Vector2(Logic.HUMAN_H, 0), Vector2(Logic.HUMAN_W, Logic.HUMAN_H), Vector2(0, Logic.HUMAN_W)]
	var sx := _sx(p.x)
	for ox in [sx, sx - world.world_w]:
		if ox > Logic.W or ox + Logic.HUMAN_H < 0:
			continue
		var origin: Vector2 = FIELD_POS + (Vector2(ox, p.y) + offs[rot]) * PX
		draw_set_transform(origin, rot * PI * 0.5, Vector2(PX, PX))
		draw_texture(HUMAN, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)


func _rect_world(p: Vector2, sz: Vector2, c: Color) -> void:
	var sx := _sx(p.x)
	for ox in [sx, sx - world.world_w]:
		if ox > Logic.W or ox + sz.x < 0:
			continue
		draw_rect(Rect2(FIELD_POS + Vector2(ox, p.y) * PX, sz * PX), c)


func _draw_minimap() -> void:
	var map_w := 280.0
	var map_h := 36.0
	var map_x := FIELD_POS.x + (FIELD.x - map_w) * 0.5
	var map_y := FIELD_POS.y + 10.0
	var sf: float = map_w / world.world_w
	draw_rect(Rect2(map_x - 2, map_y - 2, map_w + 4, map_h + 4), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(map_x, map_y, map_w, map_h), Color(0.02, 0.04, 0.08, 0.92))
	for h in world.hu:
		_blip(map_x, map_y, map_h, sf, h.x, 1.0 + (h.y / Logic.H) * (map_h - 4), ORANGE)
	for h in world.fh:
		_blip(map_x, map_y, map_h, sf, h.pos.x, 1.0 + clampf(h.pos.y / Logic.H, 0, 1) * (map_h - 4), ORANGE)
	for a in world.al:
		_blip(map_x, map_y, map_h, sf, a.x + Logic.ALIEN_W * 0.5,
				1.0 + clampf(a.y / Logic.H, 0, 1) * (map_h - 4), GREEN)
	_blip(map_x, map_y, map_h, sf, world.sh.x + Logic.SHIP_W * 0.5,
			1.0 + (world.sh.y + 16) / Logic.H * (map_h - 4), Color.WHITE, 3.0)
	var cw: float = sf * Logic.W
	var co: float = sf * world.cam_x
	var cy := map_y + 2
	var ch := map_h - 4
	if world.cam_x + Logic.W > world.world_w:
		draw_rect(Rect2(map_x, cy, cw - (map_w - co), ch), Color(FRAME, 0.7), false, 1.5)
		draw_rect(Rect2(map_x + co, cy, map_w - co, ch), Color(FRAME, 0.7), false, 1.5)
	else:
		draw_rect(Rect2(map_x + co, cy, cw, ch), Color(FRAME, 0.7), false, 1.5)
	draw_rect(Rect2(map_x, map_y, map_w, map_h), Color.WHITE, false, 1.5)


func _blip(map_x: float, map_y: float, map_h: float, sf: float, x: float, y: float, c: Color, size := 2.0) -> void:
	draw_rect(Rect2(map_x + floor(fposmod(x, world.world_w) * sf), map_y + floor(y), size, size), c)


func _draw_particles() -> void:
	for p in _particles:
		var a := clampf(p.life / maxf(float(p.max), 0.001), 0.0, 1.0)
		draw_circle(p.pos, float(p.size) * (0.5 + 0.5 * a), Color(p.color, a))


func _draw_floaters() -> void:
	for f in _floaters:
		var a := clampf(f.life / maxf(float(f.max), 0.001), 0.0, 1.0)
		var fs := 18
		var col: Color = f.color
		col.a = a
		draw_string(_font, f.pos + Vector2(-40, 0), str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# --- HUD / cards --------------------------------------------------------------

func _refresh_hud() -> void:
	var secs: int = world.f / Logic.FPS
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	_kills_label.text = str(world.kills)
	_saved_label.text = str(world.saved)
	_lost_label.text = str(world.lost)
	_humans_label.text = str(maxi(0, world.humans_left() - world.carried))
	_carry_label.text = str(world.carried)
	_score_label.text = str(world.score()) if world.state != Logic.TITLE else "—"
	_carry_label.modulate = GOLD if world.carried > 0 else MUTED


func _show_card(key: String) -> void:
	for k in _cards:
		_cards[k].visible = (k == key and key != "")


func _show_gameover() -> void:
	var secs: int = world.f / Logic.FPS
	_over_why.text = "You crashed into an alien" if world.crashed else "Every human is gone"
	_over_score.text = "SCORE %d" % world.score()
	_over_detail.text = "time %ds  ·  kills %d  ·  saved %d  ·  lost %d" % [
			secs, world.kills, world.saved, world.lost]
	_show_card("over")


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


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = STAGE
	_ui.add_child(root)

	var title := _label("oK DEFENDER", 28, FRAME.lightened(0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, title, Rect2(0, 8, STAGE.x, 36))
	var sub := _label("Enhanced  ·  Ludum Dare 49 Defender clone", 14, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, sub, Rect2(0, 40, STAGE.x, 22))

	var back := _button("Back to Arcade", Color(0.25, 0.32, 0.65), 18)
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)

	# Left stats
	var lp := _panel(root, Rect2(16, 72, 132, 600))
	_add(lp, _label("TIME", 14, MUTED), Rect2(16, 16, 100, 20))
	_time_label = _add(lp, _label("0:00", 32, INK), Rect2(16, 36, 100, 40)) as Label
	_add(lp, _label("KILLS", 14, MUTED), Rect2(16, 90, 100, 20))
	_kills_label = _add(lp, _label("0", 36, GREEN), Rect2(16, 110, 100, 44)) as Label
	_add(lp, _label("SAVED", 14, MUTED), Rect2(16, 170, 100, 20))
	_saved_label = _add(lp, _label("0", 36, ORANGE), Rect2(16, 190, 100, 44)) as Label
	_add(lp, _label("LOST", 14, MUTED), Rect2(16, 250, 100, 20))
	_lost_label = _add(lp, _label("0", 36, RED), Rect2(16, 270, 100, 44)) as Label
	_add(lp, _label("HUMANS", 14, MUTED), Rect2(16, 330, 100, 20))
	_humans_label = _add(lp, _label("0", 36, INK), Rect2(16, 350, 100, 44)) as Label
	_add(lp, _label("CARRY", 14, MUTED), Rect2(16, 410, 100, 20))
	_carry_label = _add(lp, _label("0", 36, MUTED), Rect2(16, 430, 100, 44)) as Label
	_add(lp, _label("SCORE", 14, MUTED), Rect2(16, 500, 100, 20))
	_score_label = _add(lp, _label("—", 28, GOLD), Rect2(16, 520, 100, 40)) as Label

	# Right help
	var rp := _panel(root, Rect2(STAGE.x - 148, 72, 132, 600))
	_add(rp, _label("FLY", 14, MUTED), Rect2(14, 16, 104, 20))
	_add(rp, _label("Arrows\nor WASD", 15, INK), Rect2(14, 38, 104, 48))
	_add(rp, _label("FIRE", 14, MUTED), Rect2(14, 100, 104, 20))
	_add(rp, _label("Hold\nSpace", 15, INK), Rect2(14, 122, 104, 48))
	_add(rp, _label("SAVE", 14, MUTED), Rect2(14, 186, 104, 20))
	_add(rp, _label("Catch falls,\nfly low to\nset down", 14, MUTED), Rect2(14, 208, 104, 70))
	_add(rp, _label("PAUSE", 14, MUTED), Rect2(14, 300, 104, 20))
	_add(rp, _label("Esc", 18, INK), Rect2(14, 322, 104, 28))
	_add(rp, _label("Same rules\nas Direct.\nPresentation\nonly.", 13, MUTED), Rect2(14, 380, 104, 90))

	# Title card
	var title_holder := Control.new()
	title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, title_holder, Rect2(Vector2.ZERO, STAGE))
	var tc := CenterContainer.new()
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(title_holder, tc, Rect2(FIELD_POS, FIELD))
	var tp := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.07, 0.08, 0.18, 0.94)
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
	var t1 := _label("oK DEFENDER", 42, GOLD)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t1)
	var t2 := _label("Enhanced edition", 18, FRAME)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t2)
	var t3 := _label("Shoot carriers · catch falling humans · fly low to set them down", 15, MUTED)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t3)
	var t4 := _label("Press Space to start", 20, GREEN)
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t4)
	_cards["title"] = title_holder

	# Game over card
	var over_holder := Control.new()
	over_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_holder.visible = false
	_add(root, over_holder, Rect2(Vector2.ZERO, STAGE))
	var oc := CenterContainer.new()
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(over_holder, oc, Rect2(FIELD_POS, FIELD))
	var op := PanelContainer.new()
	var os := ts.duplicate()
	os.border_color = RED
	op.add_theme_stylebox_override("panel", os)
	oc.add_child(op)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 10)
	op.add_child(ov)
	var o1 := _label("GAME OVER", 40, RED)
	o1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(o1)
	_over_why = _label("", 18, INK)
	_over_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_over_why)
	_over_score = _label("SCORE 0", 28, GOLD)
	_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_over_score)
	_over_detail = _label("", 14, MUTED)
	_over_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_over_detail)
	var o5 := _label("Press Space to play again", 18, GREEN)
	o5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(o5)
	_cards["over"] = over_holder
