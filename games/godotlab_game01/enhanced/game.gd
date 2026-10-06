extends Node2D
## GodotLab Game 01 (Enhanced). Presentation makeover of the Direct top-down
## hero + mouse-crosshair sketch. The playfield is Direct `game.tscn` (shared
## `hero.gd` / `crosshair.gd` and the original art), instanced in its native
## 1280×720 SubViewport, so 10 px/frame movement, crosshair drift/clamp and the
## face-the-crosshair rotation all stay Direct. Enhanced owns the 1280×720
## letterbox chrome, frames the viewport with stretch=false + scale (not
## stretch=true), and derives juice by observing the Direct sprites: aim laser,
## crosshair rings, footstep dust + trail, fireball flicker/embers, off-field
## locator, HUD. Esc → PauseOverlay. No Alchementrix IP.

const DIRECT := preload("res://games/godotlab_game01/direct/game.tscn")
const HeroScript := preload("res://games/godotlab_game01/direct/hero.gd")
const CrosshairScript := preload("res://games/godotlab_game01/direct/crosshair.gd")

const STAGE := Vector2(1280, 720)
## Direct runs in the arcade's 1280×720 window (its `Scene` node is scaled 2×).
const VP_SIZE := Vector2(1280, 720)
## Framed at ¾ with stretch=false + scale (Overlap #78: never fake this with stretch=true).
const FIELD := Vector2(960, 540)
const FIELD_POS := Vector2(160, 72)
const VIEW_K := FIELD.x / VP_SIZE.x  ## 0.75
const SPAWN_HERO := Vector2(261.065, 176.083)   ## Direct game.tscn positions (Scene space)
const SPAWN_XHAIR := Vector2(260.562, 122.484)

const BG_TOP := Color(0.05, 0.06, 0.10)
const BG_BOT := Color(0.12, 0.06, 0.08)
const FLOOR_A := Color(0.10, 0.11, 0.15)
const FLOOR_B := Color(0.12, 0.13, 0.18)
const PANEL := Color(0.09, 0.09, 0.16, 0.94)
const FRAME := Color(1.0, 0.62, 0.35)
const INK := Color(0.95, 0.94, 1.0)
const MUTED := Color(0.66, 0.62, 0.78)
const GOLD := Color(1.0, 0.84, 0.32)
const ACCENT := Color(0.45, 0.92, 0.80)
const HOT := Color(1.0, 0.45, 0.25)
const LASER := Color(1.0, 0.30, 0.30)

const TRAIL_LEN := 24
const HERO_R := 17.0  ## hero.png is 34×34 (Scene space)

enum { TITLE, PLAY }

var state := TITLE
var demo: Node2D = null
var scene_root: Node2D = null
var hero: Sprite2D = null
var crosshair: Sprite2D = null
var fireball: Sprite2D = null

## View-only presentation state (derived from Direct).
var _time := 0.0
var _flash := 0.0
var _flash_c := GOLD
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _banner := ""
var _banner_t := 0.0
var _prev_hero := Vector2.ZERO
var _prev_xhair := Vector2.ZERO
var _prev_rot := 0.0
var _have_prev := false
var _dust_acc := 0.0
var _ember_acc := 0.0
var _was_off := false
var distance := 0.0      ## hero path length (Scene px)
var steps := 0           ## physics frames the hero moved
var aim_travel := 0.0    ## crosshair path length (Scene px)
var turns := 0           ## sharp turns (> 45° in one frame)
var exits := 0           ## times the hero walked out of the field

var _clip: Control
var _vp_box: SubViewportContainer
var _viewport: SubViewport
var _fx: Node2D
var _ui: CanvasLayer
var _hud: Control
var _cards := {}
var _pos_label: Label
var _face_label: Label
var _aim_label: Label
var _dist_label: Label
var _turn_label: Label
var _exit_label: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.55)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_build_stage()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_set_state(TITLE)


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5
	if _ui:
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


func _set_state(s: int) -> void:
	state = s
	_cards["title"].visible = s == TITLE
	_hud.visible = s == PLAY
	_clip.visible = s == PLAY
	if s == PLAY and demo == null:
		_load_demo()
	if s == PLAY:
		_banner = "WASD / ARROWS MOVE  ·  MOUSE AIMS"
		_banner_t = 2.2


func _load_demo() -> void:
	demo = DIRECT.instantiate() as Node2D
	_viewport.add_child(demo)
	scene_root = demo.get_node("Scene") as Node2D
	hero = demo.get_node("Scene/hero") as Sprite2D
	crosshair = demo.get_node("Scene/crosshair") as Sprite2D
	fireball = demo.get_node("Scene/fireball") as Sprite2D
	# Enhanced draws its own chrome; hide Direct's plain hint label.
	demo.get_node("Hud").visible = false
	_clear_telemetry()
	_frame_view()
	_refresh_hud()


func _frame_view() -> void:
	## stretch=false + explicit scale (do not use stretch=true to fake a smaller view).
	_vp_box.stretch = false
	_vp_box.size = VP_SIZE
	_vp_box.scale = Vector2(VIEW_K, VIEW_K)
	_vp_box.position = Vector2.ZERO


func _clear_telemetry() -> void:
	_trail.clear()
	_have_prev = false
	distance = 0.0
	steps = 0
	aim_travel = 0.0
	turns = 0
	exits = 0
	_was_off = false


# --- coordinate helpers (Direct Scene space → stage) ---------------------------

## Direct viewport (canvas) point → stage point.
func vp_to_stage(p: Vector2) -> Vector2:
	return FIELD_POS + p * VIEW_K


## Direct `Scene`-local point → stage point (Scene is scaled 2× inside the viewport).
func scene_to_stage(p: Vector2) -> Vector2:
	if scene_root == null:
		return FIELD_POS
	return vp_to_stage(scene_root.get_global_transform() * p)


## Stage point → Direct viewport (window) point.
func stage_to_vp(p: Vector2) -> Vector2:
	return (p - FIELD_POS) / VIEW_K


func hero_stage_pos() -> Vector2:
	return scene_to_stage(hero.position) if hero else Vector2.ZERO


func crosshair_stage_pos() -> Vector2:
	return scene_to_stage(crosshair.position) if crosshair else Vector2.ZERO


## Stage-space hero radius: 17 px × Scene 2× × VIEW_K.
func hero_stage_r() -> float:
	var k: float = scene_root.scale.x if scene_root else 2.0
	return HERO_R * k * VIEW_K


## Unit vector the hero's nose points along (art faces −x; Direct rotation is
## the angle of hero − crosshair, so the nose is the opposite way).
func nose_dir() -> Vector2:
	return -Vector2.from_angle(hero.rotation) if hero else Vector2.UP


func hero_in_field() -> bool:
	return Rect2(FIELD_POS, FIELD).has_point(hero_stage_pos())


# --- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	if state == TITLE:
		if e.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_set_state(PLAY)
			get_viewport().set_input_as_handled()
		return
	# Direct hero.gd / crosshair.gd poll input themselves; Enhanced only adds a soft reset.
	if e.keycode == KEY_R:
		reset_spawn()
		get_viewport().set_input_as_handled()


## Presentation reset: put the Direct sprites back at their game.tscn spots.
func reset_spawn() -> void:
	if hero == null:
		return
	hero.position = SPAWN_HERO
	crosshair.position = SPAWN_XHAIR
	_clear_telemetry()
	_banner = "RESET"
	_banner_t = 1.0
	_flash = 0.3
	_flash_c = ACCENT
	_burst(hero_stage_pos(), GOLD, 12, 150.0)


# --- tick: observe Direct -----------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.4)
	_banner_t = maxf(0.0, _banner_t - delta)
	if state == PLAY and hero != null:
		_observe(delta)
		_refresh_hud()
		_update_cursor()
	_animate_fx(delta)
	queue_redraw()
	_fx.queue_redraw()


func _observe(delta: float) -> void:
	var hp: Vector2 = hero.position
	var cp: Vector2 = crosshair.position
	if _have_prev:
		var step := hp.distance_to(_prev_hero)
		if step > 40.0:
			_trail.clear()  # teleport (e.g. R reset), not a walk
		elif step > 0.01:
			distance += step
			steps += 1
			_trail.append(hp)
			while _trail.size() > TRAIL_LEN:
				_trail.pop_front()
			_dust_acc += delta
			if _dust_acc > 0.06:
				_dust_acc = 0.0
				var back := (_prev_hero - hp).normalized()
				_burst(scene_to_stage(hp + back * HERO_R * 0.7), Color(0.75, 0.70, 0.62, 0.7), 2, 40.0)
		elif not _trail.is_empty() and randf() < delta * 6.0:
			_trail.pop_front()
		# Crosshair drift that the hero caused is not "aim"; count only the rest.
		var aim_move := (cp - _prev_xhair) - (hp - _prev_hero)
		aim_travel += aim_move.length()
		var dr := absf(wrapf(hero.rotation - _prev_rot, -PI, PI))
		if dr > PI / 4.0:
			turns += 1
			_burst(hero_stage_pos() + nose_dir() * hero_stage_r(), ACCENT, 5, 110.0)
	else:
		_have_prev = true
	_prev_hero = hp
	_prev_xhair = cp
	_prev_rot = hero.rotation
	# Off-field locator juice.
	var off := not hero_in_field()
	if off and not _was_off:
		exits += 1
		_banner = "HERO OFF-FIELD  ·  R TO RESET"
		_banner_t = 1.4
		_flash = 0.35
		_flash_c = HOT
	elif not off and _was_off:
		_floater("BACK", hero_stage_pos() + Vector2(-20, -40), ACCENT)
	_was_off = off
	# Fireball: Direct keeps it a static prop; Enhanced only adds embers.
	_ember_acc += delta
	if fireball and fireball.visible and _ember_acc > 0.08:
		_ember_acc = 0.0
		var fp := scene_to_stage(fireball.position)
		_particles.append({
			"pos": fp + Vector2(randf_range(-10, 10), randf_range(-6, 6)),
			"vel": Vector2(randf_range(-12, 12), randf_range(-60, -30)),
			"life": randf_range(0.4, 0.8), "max": 0.8,
			"color": Color(1.0, randf_range(0.45, 0.8), 0.2, 0.8), "size": randf_range(1.5, 3.0),
		})


## Show the OS cursor over the chrome (so the HUD buttons are usable), hide it
## over the field where the Direct crosshair stands in for it.
func _update_cursor() -> void:
	if DisplayServer.get_name() == "headless" or get_tree().paused:
		return
	var inside := Rect2(FIELD_POS, FIELD).has_point(get_local_mouse_position())
	var want := Input.MOUSE_MODE_HIDDEN if inside else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _refresh_hud() -> void:
	if hero == null:
		return
	var hp: Vector2 = hero.position
	var deg := fposmod(rad_to_deg(nose_dir().angle()) + 90.0, 360.0)  ## 0 = up, clockwise
	_pos_label.text = "pos  (%.0f, %.0f)" % [hp.x, hp.y]
	_face_label.text = "facing  %03.0f°  %s" % [deg, _compass(deg)]
	_aim_label.text = "aim range  %.0f px" % hp.distance_to(crosshair.position)
	_dist_label.text = "walked  %.0f px  (%d steps)" % [distance, steps]
	_turn_label.text = "snap turns  %d" % turns
	_exit_label.text = "off-field  %d%s" % [exits, "  ← R" if _was_off else ""]


func _compass(deg: float) -> String:
	const NAMES := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return NAMES[int(round(deg / 45.0)) % 8]


# --- draw ---------------------------------------------------------------------

func _draw() -> void:
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / 24.0 + 1.0), BG_TOP.lerp(BG_BOT, t))
	for i in 30:
		var x := fmod(i * 97.3 + _time * (4.0 + i % 5), STAGE.x)
		var y := fmod(i * 53.1 + sin(_time * 0.4 + i) * 10.0 + 200.0, STAGE.y)
		draw_circle(Vector2(x, y), 1.0 + (i % 3) * 0.5, Color(1.0, 0.7, 0.5, 0.06 + 0.03 * (i % 3)))
	if state != PLAY:
		return
	var fr := Rect2(FIELD_POS - Vector2(10, 10), FIELD + Vector2(20, 20))
	draw_rect(fr, Color(0.04, 0.04, 0.08, 0.95))
	# Checker floor under the (transparent) Direct viewport: 32 Scene px tiles.
	var tile := 32.0 * 2.0 * VIEW_K
	var cols := int(ceil(FIELD.x / tile))
	var rows := int(ceil(FIELD.y / tile))
	for gy in rows:
		for gx in cols:
			var r := Rect2(FIELD_POS + Vector2(gx, gy) * tile, Vector2(tile, tile))
			r = r.intersection(Rect2(FIELD_POS, FIELD))
			draw_rect(r, FLOOR_A if (gx + gy) % 2 == 0 else FLOOR_B)
	draw_rect(fr.grow(-4), Color(FRAME, 0.5), false, 2.0)
	draw_rect(fr.grow(2), Color(FRAME, 0.18), false, 1.5)


func _draw_fx() -> void:
	if state == PLAY and hero != null:
		var field := Rect2(FIELD_POS, FIELD)
		var hp := hero_stage_pos()
		var cp := crosshair_stage_pos()
		var r := hero_stage_r()
		# Fireball flicker glow (static Direct prop).
		if fireball and fireball.visible:
			var fp := scene_to_stage(fireball.position)
			var fl := 0.5 + 0.5 * sin(_time * 11.0) * sin(_time * 7.3)
			_fx.draw_circle(fp, 34.0 + 6.0 * fl, Color(1.0, 0.45, 0.15, 0.10 + 0.06 * fl))
			_fx.draw_circle(fp, 22.0 + 3.0 * fl, Color(1.0, 0.70, 0.25, 0.14 + 0.08 * fl))
		# Hero trail (Direct Scene positions → stage).
		if _trail.size() >= 2:
			for i in _trail.size() - 1:
				var t := float(i + 1) / float(_trail.size())
				_fx.draw_line(scene_to_stage(_trail[i]), scene_to_stage(_trail[i + 1]),
						Color(GOLD, 0.10 + 0.35 * t), 2.0 + 5.0 * t)
		if field.has_point(hp):
			# Aim laser: dashed from the nose to the crosshair.
			var nose := hp + nose_dir() * r
			var to := cp - nose
			var len := to.length()
			if len > 4.0:
				var dir := to / len
				var d := fmod(_time * 60.0, 16.0)
				while d < len:
					var a := nose + dir * d
					var b := nose + dir * minf(d + 9.0, len)
					_fx.draw_line(a, b, Color(LASER, 0.55), 2.0)
					d += 16.0
				_fx.draw_circle(nose, 3.0, Color(LASER, 0.9))
			# Hero shadow ring.
			_fx.draw_arc(hp, r + 4.0 + 1.5 * sin(_time * 3.0), 0, TAU, 36, Color(GOLD, 0.35), 1.5)
		else:
			_draw_locator(hp)
		# Crosshair rings + rotating ticks.
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_fx.draw_arc(cp, 18.0 + 4.0 * pulse, 0, TAU, 36, Color(LASER, 0.35 + 0.3 * pulse), 2.0)
		for k in 4:
			var ang := _time * 1.6 + k * TAU / 4.0
			var u := Vector2.from_angle(ang)
			_fx.draw_line(cp + u * 26.0, cp + u * 33.0, Color(LASER, 0.7), 2.0)
	for part in _particles:
		var col: Color = part.color
		col.a *= clampf(part.life / part.max, 0.0, 1.0)
		_fx.draw_circle(part.pos, part.size, col)
	for f in _floaters:
		var col: Color = f.color
		col.a *= clampf(f.life / f.max, 0.0, 1.0)
		_fx.draw_string(_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if _flash > 0.0:
		_fx.draw_rect(Rect2(FIELD_POS, FIELD), Color(_flash_c, _flash * 0.16))
	if _banner_t > 0.0 and _banner != "":
		var a := clampf(_banner_t, 0.0, 1.0)
		var r2 := Rect2(STAGE.x * 0.5 - 240, FIELD_POS.y + 12, 480, 32)
		_fx.draw_rect(r2, Color(0.05, 0.04, 0.10, 0.8 * a))
		_fx.draw_string(_font, r2.position + Vector2(0, 23), _banner, HORIZONTAL_ALIGNMENT_CENTER,
				r2.size.x, 16, Color(GOLD, a))


## Arrow on the field edge pointing at a hero who walked off the Direct screen.
func _draw_locator(hp: Vector2) -> void:
	var field := Rect2(FIELD_POS, FIELD).grow(-14.0)
	var c := field.get_center()
	var p := Vector2(clampf(hp.x, field.position.x, field.end.x), clampf(hp.y, field.position.y, field.end.y))
	var dir := (hp - c).normalized()
	var side := dir.orthogonal()
	var pulse := 0.6 + 0.4 * sin(_time * 8.0)
	_fx.draw_colored_polygon(PackedVector2Array([p + dir * 10.0, p - dir * 8.0 + side * 9.0, p - dir * 8.0 - side * 9.0]),
			Color(HOT, pulse))
	_fx.draw_string(_font, p - dir * 30.0 + Vector2(-20, 5), "%.0f" % hp.distance_to(p),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(HOT, 0.9))


# --- FX helpers ---------------------------------------------------------------

func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_particles.append({
			"pos": at, "vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.25, 0.55), "max": 0.55,
			"color": color, "size": randf_range(1.5, 3.5),
		})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"pos": at, "life": 0.9, "max": 0.9, "text": text, "color": color})


func _animate_fx(delta: float) -> void:
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.93
		if p.life <= 0.0:
			_particles.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _floaters.size():
		var f: Dictionary = _floaters[i]
		f.life -= delta
		f.pos.y -= 28.0 * delta
		if f.life <= 0.0:
			_floaters.remove_at(i)
		else:
			i += 1


# --- build --------------------------------------------------------------------

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DirectVP"
	_viewport.size = Vector2i(VP_SIZE)
	_viewport.transparent_bg = true  ## Enhanced paints the floor under Direct's sprites
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

	_vp_box = SubViewportContainer.new()
	_vp_box.name = "DemoView"
	_vp_box.size = VP_SIZE
	_vp_box.stretch = false
	_vp_box.scale = Vector2(VIEW_K, VIEW_K)
	## Mouse motion must reach the SubViewport: Direct crosshair.gd follows it.
	_vp_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_vp_box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vp_box.add_child(_viewport)

	_clip = Control.new()
	_clip.name = "Field"
	_clip.position = FIELD_POS
	_clip.size = FIELD
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.visible = false
	add_child(_clip)
	_clip.add_child(_vp_box)

	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)

	_hud = Control.new()
	_hud.name = "Hud"
	_hud.size = STAGE
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hud)

	var top := _panel(Rect2(40, 14, 1200, 48))
	_hud.add_child(top)
	top.add_child(_label("GODOTLAB GAME 01", 22, GOLD, Vector2(16, 10)))
	top.add_child(_label("Enhanced", 13, ACCENT, Vector2(280, 16)))
	top.add_child(_label("top-down hero · faces the mouse crosshair · Direct hero.gd + crosshair.gd", 13, MUTED, Vector2(380, 16)))
	var back := _btn("Back to Arcade", Vector2(1056, 8), Vector2(128, 32))
	back.pressed.connect(GameRegistry.return_to_arcade)
	top.add_child(back)

	var stats := _panel(Rect2(40, 624, 760, 80))
	_hud.add_child(stats)
	stats.add_child(_label("TELEMETRY", 11, MUTED, Vector2(14, 8)))
	_pos_label = _label("pos  —", 14, INK, Vector2(14, 28))
	stats.add_child(_pos_label)
	_face_label = _label("facing  —", 15, GOLD, Vector2(14, 52))
	stats.add_child(_face_label)
	_aim_label = _label("aim range  —", 14, Color(1.0, 0.55, 0.55), Vector2(250, 28))
	stats.add_child(_aim_label)
	_dist_label = _label("walked  0", 14, INK, Vector2(250, 52))
	stats.add_child(_dist_label)
	_turn_label = _label("snap turns  0", 14, ACCENT, Vector2(540, 28))
	stats.add_child(_turn_label)
	_exit_label = _label("off-field  0", 14, HOT, Vector2(540, 52))
	stats.add_child(_exit_label)

	var keys := _panel(Rect2(820, 624, 420, 80))
	_hud.add_child(keys)
	keys.add_child(_label("CONTROLS", 11, MUTED, Vector2(14, 8)))
	keys.add_child(_label("WASD (Dvorak ,AOE) / arrows  move    mouse  aim", 13, INK, Vector2(14, 30)))
	keys.add_child(_label("R  reset spawn    Esc  pause / arcade", 13, MUTED, Vector2(14, 52)))

	var card := _panel(Rect2(STAGE.x * 0.5 - 310, STAGE.y * 0.5 - 170, 620, 340))
	card.name = "TitleCard"
	_ui.add_child(card)
	_cards["title"] = card
	card.add_child(_label("GODOTLAB GAME 01", 32, GOLD, Vector2(36, 30)))
	card.add_child(_label("Enhanced edition", 16, ACCENT, Vector2(36, 78)))
	card.add_child(_label(
		"The Direct top-down hero sketch, framed with chrome:\nWASD / arrows still walk 10 px a frame via Direct hero.gd,\nthe mouse crosshair still drifts with the hero, and the\nhero still turns to face it — Enhanced only adds the aim\nlaser, dust trail, fireball glow, locator and telemetry.",
		14, INK, Vector2(36, 114)))
	var start := _btn("Start", Vector2(36, 236), Vector2(120, 40))
	start.pressed.connect(func(): _set_state(PLAY))
	card.add_child(start)
	card.add_child(_label("Enter / Space  to begin", 14, MUTED, Vector2(180, 246)))
	var title_back := _btn("Back to Arcade", Vector2(36, 290), Vector2(160, 34))
	title_back.pressed.connect(GameRegistry.return_to_arcade)
	card.add_child(title_back)


func _panel(r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", _panel_style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _notification(what: int) -> void:
	# Direct crosshair.gd also restores the cursor on exit; this covers the title card.
	if what == NOTIFICATION_EXIT_TREE and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _btn(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	for stn in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		var base := Color(0.30, 0.16, 0.14)
		s.bg_color = base.lightened(0.15) if stn == "hover" else base.darkened(0.15) if stn == "pressed" else base
		s.border_color = FRAME
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 4
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(stn, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b
