extends Node2D
## Silly Game (Enhanced). Presentation makeover of the Direct Godot 4 port.
## The island, aardvark walk, bullet pool, badguy hit and R-reset are the
## Direct scene and scripts (instanced, not copied): `direct/game.tscn` with
## hero.gd / aim.gd / bullet(s).gd / badguy.gd / world.gd. This file only adds
## an animated ocean backdrop, shadows, bullet trails, muzzle flash, hit
## bursts, camera shake, a minimap + stats HUD, a title card and Back to
## Arcade. Esc is handled by the PauseOverlay autoload. No Alchementrix IP.

const DIRECT := preload("res://games/silly_game/direct/game.tscn")
const TileData3 := preload("res://games/silly_game/direct/tile_data.gd")

const CELL := 64
const HIT_RADIUS := 30.0      ## view-only hit counter radius around the badguy
const HERO_CENTER := Vector2.ZERO  ## Sprite2D is centred; hero.position is the body

const PANEL := Color(0.05, 0.10, 0.16, 0.86)
const FRAME := Color(0.40, 0.85, 0.90)
const INK := Color(0.94, 0.97, 1.0)
const MUTED := Color(0.62, 0.74, 0.82)
const SAND := Color(0.98, 0.86, 0.55)
const CORAL := Color(1.0, 0.45, 0.42)
const LIME := Color(0.60, 0.95, 0.55)

const OCEAN_SHADER := """
shader_type canvas_item;
uniform vec2 cam = vec2(0.0);
void fragment() {
	vec2 p = (FRAGCOORD.xy + cam) * 0.006;
	float t = TIME * 0.35;
	float w = sin(p.x * 3.0 + t * 2.0) * 0.5 + sin(p.y * 4.0 - t * 1.5 + p.x) * 0.5;
	float c = sin((p.x + p.y) * 9.0 + w * 2.0 + t * 3.0);
	vec3 deep = vec3(0.03, 0.16, 0.30);
	vec3 shallow = vec3(0.07, 0.36, 0.52);
	vec3 col = mix(deep, shallow, 0.5 + 0.25 * w);
	col += vec3(0.55, 0.85, 0.95) * smoothstep(0.93, 1.0, c) * 0.25;
	COLOR = vec4(col, 1.0);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.8)));
	COLOR = vec4(0.0, 0.03, 0.08, v * 0.55);
}
"""

enum { TITLE, PLAY }

## Set when R is pressed in play: Direct hero.gd reloads the current scene,
## and the fresh Enhanced instance should skip the title card.
static var _resume_play := false

var state := TITLE
var direct: Node2D = null
var hero: Sprite2D = null
var aim: Sprite2D = null
var badguy: Sprite2D = null
var heart: Sprite2D = null
var bullets: Node2D = null
var camera: Camera2D = null
var layer: TileMapLayer = null

## View-only stats (Direct has no score).
var shots := 0
var hits := 0
var play_time := 0.0
var distance := 0.0
var badguy_down := false

var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _muzzle := 0.0
var _prev_hero := Vector2.ZERO
var _prev_badguy_frame := -1
var _bullet_vel := {}       ## bullet -> last velocity (detect new shots)
var _bullet_hit := {}       ## bullet -> already counted for its current shot
var _trails := {}           ## bullet -> Array[Vector2]
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _sparkles: Array[Dictionary] = []

var _under: Node2D          ## world-space FX below sprites (shadows, sparkles)
var _over: Node2D           ## world-space FX above sprites (trails, bursts)
var _ocean: ColorRect
var _ocean_mat: ShaderMaterial
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _stat_labels := {}
var _where_label: Label
var _minimap: Control
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.5)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(12)
	_build_backdrop()
	_build_ui()
	if _resume_play:
		_resume_play = false
		_set_state(PLAY)
	else:
		_set_state(TITLE)


func _set_state(s: int) -> void:
	state = s
	_cards["title"].visible = s == TITLE
	_hud.visible = s == PLAY
	if s == PLAY and direct == null:
		_load_direct()


func _load_direct() -> void:
	direct = DIRECT.instantiate()
	add_child(direct)
	hero = direct.get_node("hero")
	aim = direct.get_node("aim")
	badguy = direct.get_node("badguy")
	heart = direct.get_node("heart")
	bullets = direct.get_node("bullets")
	camera = hero.get_node("Camera2D")
	layer = direct.get_node("TileMap")
	# Enhanced owns the HUD.
	direct.get_node("Hud").visible = false
	_under = Node2D.new()
	_under.name = "EnhancedUnder"
	_under.draw.connect(_draw_under)
	direct.add_child(_under)
	direct.move_child(_under, layer.get_index() + 1)
	_over = Node2D.new()
	_over.name = "EnhancedOver"
	_over.z_index = 10
	_over.draw.connect(_draw_over)
	direct.add_child(_over)
	# Presentation-only tints (rules untouched).
	aim.modulate = Color(1.0, 0.95, 0.7)
	_prev_hero = hero.position
	_prev_badguy_frame = badguy.frame
	for b in bullets.get_children():
		_bullet_vel[b] = b.velocity
		_bullet_hit[b] = true
		_trails[b] = []


func _physics_process(_delta: float) -> void:
	if state != PLAY or direct == null:
		return
	# Direct hero.gd reloads the scene on R; land straight back in play.
	if Input.is_key_pressed(KEY_R):
		_resume_play = true


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	_flash = maxf(0.0, _flash - delta * 3.0)
	_muzzle = maxf(0.0, _muzzle - delta * 8.0)
	_animate_fx(delta)
	if state == PLAY and direct != null:
		play_time += delta
		_track_hero()
		_track_bullets()
		_track_badguy()
		_spawn_sparkles(delta)
		# Gentle idle bobs via Sprite2D.offset (position stays Direct's).
		heart.offset = Vector2(0, sin(_time * 3.0) * 3.0)
		heart.scale = Vector2.ONE * (1.0 + 0.06 * sin(_time * 6.0))
		if not badguy_down:
			badguy.offset = Vector2(0, sin(_time * 2.2) * 2.0)
		else:
			badguy.offset = Vector2.ZERO
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 22.0 * _shake * _shake
		camera.offset = shake
		_ocean_mat.set_shader_parameter("cam", camera.get_screen_center_position() * camera.zoom)
		_under.queue_redraw()
		_over.queue_redraw()
		_update_hud()
	_minimap.queue_redraw()
	queue_redraw()


# ---- tracking (read-only over Direct state) ----------------------------------

func _track_hero() -> void:
	var d := hero.position - _prev_hero
	if d.length() > 0.5 and d.length() < 200.0:
		distance += d.length()
		if randf() < 0.45:
			var at := hero.position + HERO_CENTER + Vector2(randf_range(-14, 14), 26)
			var c := Color(0.95, 0.85, 0.6, 0.8) if _ground_kind(hero.position + HERO_CENTER) == "sand" \
				else Color(0.75, 0.92, 1.0, 0.8)
			_dust(at, c)
	_prev_hero = hero.position


func _track_bullets() -> void:
	for b in bullets.get_children():
		var v: Vector2 = b.velocity
		if v != _bullet_vel.get(b, Vector2.ZERO):
			# Direct hero.gd just fired this pooled bullet.
			shots += 1
			_bullet_hit[b] = false
			_trails[b] = []
			_muzzle = 1.0
			_burst(b.position, Color(1.0, 0.9, 0.5), 6, 120.0)
		_bullet_vel[b] = v
		if v == Vector2.ZERO:
			continue
		var tr: Array = _trails.get(b, [])
		tr.append(b.position)
		if tr.size() > 8:
			tr.pop_front()
		_trails[b] = tr
		if not _bullet_hit.get(b, true) and b.position.distance_to(badguy.position) < HIT_RADIUS:
			_bullet_hit[b] = true
			hits += 1
			_burst(badguy.position, CORAL, 14, 220.0)
			_floater("HIT!", badguy.position + Vector2(0, -40), CORAL)
			_shake = maxf(_shake, 0.35)


func _track_badguy() -> void:
	if badguy.frame != _prev_badguy_frame:
		if badguy.frame == 12 and not badguy_down:
			# Direct badguy.gd flipped to its hit frame.
			badguy_down = true
			_flash = 1.0
			_shake = 0.8
			_burst(badguy.position, SAND, 30, 320.0)
			_floater("BONK!", badguy.position + Vector2(0, -64), SAND)
		_prev_badguy_frame = badguy.frame


func _ground_kind(world_pos: Vector2) -> String:
	if layer == null:
		return "void"
	var cell := layer.local_to_map(layer.to_local(world_pos))
	var atlas := layer.get_cell_atlas_coords(cell)
	if atlas == Vector2i(-1, -1):
		return "void"
	if atlas == Vector2i(8, 5):
		return "water"
	return "sand"


func _spawn_sparkles(delta: float) -> void:
	if randf() > delta * 18.0:
		return
	var half := get_viewport_rect().size * 0.5 / camera.zoom
	var c := camera.get_screen_center_position()
	var p := c + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
	if _ground_kind(p) != "water":
		return
	_sparkles.append({"p": p, "life": 0.9, "r": randf_range(3.0, 7.0)})


# ---- particles ---------------------------------------------------------------

func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		_particles.append({
			"p": at,
			"v": Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed),
			"life": randf_range(0.3, 0.7), "max": 0.7, "c": color,
			"r": randf_range(3.0, 7.0), "g": 0.0,
		})


func _dust(at: Vector2, color: Color) -> void:
	_particles.append({
		"p": at, "v": Vector2(randf_range(-30, 30), randf_range(-50, -15)),
		"life": randf_range(0.3, 0.55), "max": 0.55, "c": color,
		"r": randf_range(3.0, 6.0), "g": 60.0,
	})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"t": text, "p": at, "life": 1.0, "c": color})


func _animate_fx(delta: float) -> void:
	var nxt: Array[Dictionary] = []
	for p in _particles:
		p.life -= delta
		if p.life > 0.0:
			p.p += p.v * delta
			p.v *= 0.92
			p.v.y += p.g * delta
			nxt.append(p)
	_particles = nxt
	var fn: Array[Dictionary] = []
	for f in _floaters:
		f.life -= delta
		if f.life > 0.0:
			f.p.y -= 60.0 * delta
			fn.append(f)
	_floaters = fn
	var sn: Array[Dictionary] = []
	for s in _sparkles:
		s.life -= delta
		if s.life > 0.0:
			sn.append(s)
	_sparkles = sn


# ---- drawing -----------------------------------------------------------------

func _draw_under() -> void:
	# Tint Direct's flat water tiles toward the animated ocean, with a slow swell.
	for row in TileData3.rows():
		if row[2] != 1:
			continue
		var cell := Vector2(row[0], row[1])
		var w := 0.5 + 0.5 * sin(_time * 1.6 + cell.x * 0.7 + cell.y * 0.45)
		var r := Rect2(layer.position + cell * CELL, Vector2(CELL, CELL))
		_under.draw_rect(r, Color(0.05, 0.28 + 0.05 * w, 0.46 + 0.05 * w, 0.8))
	for s in _sparkles:
		var a: float = sin(clampf(s.life / 0.9, 0.0, 1.0) * PI)
		var r: float = s.r
		_under.draw_line(s.p - Vector2(r, 0), s.p + Vector2(r, 0), Color(1, 1, 1, 0.6 * a), 2.0)
		_under.draw_line(s.p - Vector2(0, r), s.p + Vector2(0, r), Color(1, 1, 1, 0.6 * a), 2.0)
	# Soft drop shadows under the aardvark, badguy and heart.
	_shadow(hero.position + HERO_CENTER + Vector2(0, 28), 26.0)
	_shadow(badguy.position + Vector2(0, 26), 22.0)
	_shadow(heart.position + Vector2(0, 26), 14.0 - sin(_time * 3.0) * 2.0)


func _shadow(at: Vector2, w: float) -> void:
	_under.draw_set_transform(at, 0.0, Vector2(1.0, 0.35))
	_under.draw_circle(Vector2.ZERO, w, Color(0, 0.05, 0.1, 0.32))
	_under.draw_circle(Vector2.ZERO, w * 0.65, Color(0, 0.05, 0.1, 0.22))
	_under.draw_set_transform(Vector2.ZERO)


func _draw_over() -> void:
	# Bullet trails + glow.
	for b in _trails:
		var tr: Array = _trails[b]
		for i in range(1, tr.size()):
			var a := float(i) / tr.size()
			_over.draw_line(tr[i - 1], tr[i], Color(1.0, 0.85, 0.4, a * 0.75), 4.0 + a * 12.0, true)
		if tr.size() > 0:
			_over.draw_circle(tr[-1], 20.0, Color(1.0, 0.9, 0.5, 0.25))
	# Muzzle flash.
	if _muzzle > 0.0:
		var m := hero.position + HERO_CENTER
		_over.draw_circle(m, 34.0 * _muzzle, Color(1.0, 0.95, 0.6, 0.45 * _muzzle))
	# Aim guide + rotating crosshair ring.
	var from := hero.position + HERO_CENTER
	var to := aim.position
	var dir := to - from
	var n := int(dir.length() / 28.0)
	for i in range(1, n):
		_over.draw_circle(from + dir * (float(i) / n), 2.5, Color(1, 1, 1, 0.18))
	var spin := _time * 2.0
	for k in 4:
		var a0 := spin + k * TAU / 4.0
		_over.draw_arc(to, 26.0, a0, a0 + 0.9, 10, Color(SAND, 0.85), 3.0, true)
	# Particles & floaters.
	for p in _particles:
		var a := clampf(p.life / p.max, 0.0, 1.0)
		_over.draw_circle(p.p, p.r * a, Color(p.c, a))
	for f in _floaters:
		var a := clampf(f.life, 0.0, 1.0)
		_over.draw_string(_font, f.p + Vector2(-30, 2), f.t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0, 0, 0, a * 0.5))
		_over.draw_string(_font, f.p + Vector2(-32, 0), f.t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(f.c, a))


func _draw_minimap() -> void:
	var sz := _minimap.size
	_minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.10, 0.18, 0.9))
	# Map bounds from Direct tile_data: x -14..20, y -15..4.
	var cells := Vector2(35, 20)
	var px := minf(sz.x / cells.x, sz.y / cells.y)
	var org := (sz - cells * px) * 0.5
	for row in TileData3.rows():
		var c := Vector2(row[0] + 14, row[1] + 15)
		var col := Color(0.15, 0.45, 0.65) if row[2] == 1 else SAND
		_minimap.draw_rect(Rect2(org + c * px, Vector2(px, px)), col)
	if direct == null:
		return
	var to_map := func(w: Vector2) -> Vector2:
		var cell := (w - layer.position) / CELL
		return org + (cell + Vector2(14, 15)) * px
	var view_half := get_viewport_rect().size * 0.5 / camera.zoom / CELL * px
	var vc: Vector2 = to_map.call(camera.get_screen_center_position())
	var vr := Rect2(vc - view_half, view_half * 2.0).intersection(Rect2(Vector2.ZERO, sz).grow(-1.0))
	if vr.has_area():
		_minimap.draw_rect(vr, Color(1, 1, 1, 0.5), false, 1.0)
	_minimap.draw_circle(to_map.call(heart.position), 2.5, CORAL)
	_minimap.draw_circle(to_map.call(badguy.position), 3.0, MUTED if badguy_down else Color(0.75, 0.4, 1.0))
	var hp: Vector2 = to_map.call(hero.position + HERO_CENTER)
	_minimap.draw_circle(hp, 4.0 + sin(_time * 6.0), Color(1, 1, 1, 0.35))
	_minimap.draw_circle(hp, 3.0, LIME)


func _draw() -> void:
	# Screen flash drawn in the HUD layer; nothing in root world space.
	pass


# ---- HUD ---------------------------------------------------------------------

func _update_hud() -> void:
	_stat_labels["shots"].text = str(shots)
	_stat_labels["hits"].text = str(hits)
	_stat_labels["acc"].text = ("%d%%" % roundi(100.0 * hits / shots)) if shots > 0 else "—"
	_stat_labels["time"].text = "%d:%02d" % [int(play_time) / 60, int(play_time) % 60]
	_stat_labels["dist"].text = "%d m" % int(distance / CELL)
	var kind := _ground_kind(hero.position + HERO_CENTER)
	_where_label.text = {"sand": "On the beach", "water": "Wading", "void": "Off the map!"}[kind]
	_where_label.add_theme_color_override("font_color",
		{"sand": SAND, "water": FRAME, "void": CORAL}[kind])
	_stat_labels["foe"].text = "BONKED" if badguy_down else "lurking"
	_stat_labels["foe"].add_theme_color_override("font_color", LIME if badguy_down else MUTED)


func _build_backdrop() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	_ocean = ColorRect.new()
	_ocean.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ocean.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = OCEAN_SHADER
	_ocean_mat = ShaderMaterial.new()
	_ocean_mat.shader = sh
	_ocean.material = _ocean_mat
	bg.add_child(_ocean)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = VIGNETTE_SHADER
	var vm := ShaderMaterial.new()
	vm.shader = vs
	vig.material = vm
	root.add_child(vig)

	var flash := _FlashRect.new()
	flash.owner_game = self
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)

	# Top-left: title + back.
	var back := _button("Back to Arcade", Color(0.12, 0.42, 0.55), 16)
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)
	var t := _label("SILLY GAME", 24, SAND)
	t.position = Vector2(180, 10)
	_hud.add_child(t)
	var st := _label("Enhanced  ·  aardvark island", 13, MUTED)
	st.position = Vector2(182, 40)
	_hud.add_child(st)

	# Top-right: stats + minimap.
	var sp := _panel(Vector2(236, 290))
	sp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sp.position = Vector2(-252, 14)
	sp.offset_left = -252
	sp.offset_right = -16
	sp.offset_top = 14
	sp.offset_bottom = 304
	_hud.add_child(sp)
	_where_label = _label("—", 18, SAND)
	_where_label.position = Vector2(14, 10)
	sp.add_child(_where_label)
	_minimap = Control.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.position = Vector2(14, 40)
	_minimap.size = Vector2(208, 120)
	_minimap.draw.connect(_draw_minimap)
	sp.add_child(_minimap)
	var rows := [["shots", "SHOTS"], ["hits", "HITS"], ["acc", "ACCURACY"],
		["time", "TIME"], ["dist", "WALKED"], ["foe", "BADGUY"]]
	for i in rows.size():
		var y := 170 + i * 19
		var k := _label(rows[i][1], 12, MUTED)
		k.position = Vector2(14, y)
		sp.add_child(k)
		var v := _label("0", 14, INK)
		v.position = Vector2(110, y - 2)
		v.size = Vector2(112, 18)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sp.add_child(v)
		_stat_labels[rows[i][0]] = v

	# Bottom: controls strip.
	var cp := _panel(Vector2(0, 34))
	cp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cp.offset_left = -330
	cp.offset_right = 330
	cp.offset_top = -50
	cp.offset_bottom = -14
	_hud.add_child(cp)
	var ctl := _label("WASD walk  ·  mouse aim  ·  click shoot  ·  R reset  ·  Esc pause", 15, INK)
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cp.add_child(ctl)

	# Title card.
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	_cards["title"] = holder
	var tp := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.04, 0.11, 0.18, 0.95)
	ts.border_color = SAND
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(18)
	ts.content_margin_left = 40
	ts.content_margin_right = 40
	ts.content_margin_top = 28
	ts.content_margin_bottom = 28
	tp.add_theme_stylebox_override("panel", ts)
	holder.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	tp.add_child(tv)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = preload("res://games/silly_game/direct/assets/aardvark.png")
	var aw: float = at.atlas.get_width() / 4.0
	at.region = Rect2(0, 0, aw, at.atlas.get_height())
	icon.texture = at
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tv.add_child(icon)
	for spec in [["SILLY GAME", 38, SAND], ["An Enhanced makeover of the little aardvark's island.", 15, MUTED],
			["Same walk, bullets and badguy as Direct.", 14, MUTED]]:
		var l := _label(spec[0], spec[1], spec[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(l)
	var play := _button("Press Space to begin", Color(0.10, 0.50, 0.62), 20)
	play.pressed.connect(func(): _set_state(PLAY))
	tv.add_child(play)
	var t4 := _label("WASD walk · mouse aim · click shoot · Esc pause", 12, MUTED)
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t4)


func _unhandled_input(event: InputEvent) -> void:
	if state == TITLE and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_set_state(PLAY)
		get_viewport().set_input_as_handled()


func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for stn in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.15) if stn == "hover" else color.darkened(0.15) if stn == "pressed" else color
		s.border_color = color.lightened(0.45)
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 6
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(stn, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


func _panel(sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _panel_style.duplicate())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = sz
	return p


## Full-screen flash overlay for the badguy "BONK".
class _FlashRect extends Control:
	var owner_game: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f: float = owner_game._flash
		if f > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.95, 0.8, f * 0.35))
