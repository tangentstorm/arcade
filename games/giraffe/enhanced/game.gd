extends Node2D
## Giraffe (Enhanced). Presentation makeover of the Direct Pico-8 platformer.
## Movement, gravity, jump, walk animation, map collision and the fall reset
## are Direct's giraffe_logic.gd + map_data.gd (preloaded, not copied), stepped
## at the same fixed 30 Hz. This file owns the 1280x720 letterbox shell: a
## savanna-dusk backdrop, 5x field with smooth hero interpolation,
## squash/stretch, dust and landing juice, a ledge tracker, side HUD, title
## card and Back to Arcade. Esc is handled by the PauseOverlay autoload.

const Logic := preload("res://games/giraffe/direct/giraffe_logic.gd")
const MapData := preload("res://games/giraffe/direct/map_data.gd")

enum { TITLE, PLAY }

const STAGE := Vector2(1280, 720)
const PX := 5.0  ## 128x128 Pico room -> 640x640 field
const FIELD := Vector2(Logic.W, Logic.H) * PX
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 64.0)
const STEP_SEC := 1.0 / Logic.FPS
const DECOR_ROW := 8  ## tile-17 strip (drawn, not solid)

const BG := Color(0.06, 0.04, 0.09)
const PANEL := Color(0.11, 0.07, 0.12, 0.92)
const FRAME := Color(1.0, 0.66, 0.30)
const INK := Color(1.0, 0.95, 0.88)
const MUTED := Color(0.78, 0.66, 0.62)
const GOLD := Color(1.0, 0.84, 0.32)
const LEAF := Color(0.55, 0.85, 0.40)
const DUST := Color(0.93, 0.78, 0.55)
const RED := Color(1.0, 0.42, 0.38)
const SKY := [Color(0.13, 0.09, 0.30), Color(0.42, 0.18, 0.42), Color(0.92, 0.42, 0.32), Color(1.0, 0.72, 0.42)]

var world = Logic.new()
var state := TITLE
var _sprites := {}
var _acc := 0.0
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _squash := Vector2.ONE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _flies: Array[Vector3] = []

## Presentation-only stats derived from Direct state deltas.
var play_frames := 0
var jumps := 0
var falls := 0
var air_frames := 0
var best_air := 0
var ledges: Array = []        ## Array of Array[Vector2i] (contiguous tile-16 runs)
var visited := {}             ## ledge index -> true
var all_time := -1            ## frames when every ledge was first visited
var best_all := -1

var _prev_hx := Logic.OX
var _prev_hy := 16.0
var _prev_dy := 0.0
var _draw_prev := Vector2(Logic.OX, 16.0)  ## render interpolation
var _draw_cur := Vector2(Logic.OX, 16.0)

var _ui: CanvasLayer
var _cards := {}
var _time_label: Label
var _jumps_label: Label
var _falls_label: Label
var _ledge_label: Label
var _air_label: Label
var _best_label: Label
var _toast: Label
var _toast_t := 0.0
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	for sid in [1, 2, 3, 16, 17]:
		_sprites[sid] = load("res://games/giraffe/direct/assets/spr_%d.png" % sid)
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_find_ledges()
	_seed_scenery()
	_snap_prev()
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
		# CanvasLayer ignores the Node2D transform; mirror the letterbox fit.
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


func _find_ledges() -> void:
	ledges.clear()
	for my in MapData.H:
		var run: Array[Vector2i] = []
		for mx in MapData.W + 1:
			if mx < MapData.W and MapData.mget(mx, my) == Logic.GROUND:
				run.append(Vector2i(mx, my))
			elif not run.is_empty():
				ledges.append(run)
				run = []


func ledge_at(cell: Vector2i) -> int:
	for i in ledges.size():
		if (ledges[i] as Array).has(cell):
			return i
	return -1


func _seed_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_clouds.clear()
	for i in 5:
		_clouds.append({"x": rng.randf() * 160.0 - 16.0, "y": rng.randf_range(6, 34),
			"w": rng.randf_range(14, 28), "v": rng.randf_range(1.0, 3.0)})
	_flies.clear()
	for i in 14:
		_flies.append(Vector3(rng.randf() * 128.0, rng.randf_range(80, 124), rng.randf() * TAU))


# --- input / stepping ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if state != TITLE or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_SPACE, KEY_Z, KEY_X, KEY_ENTER, KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
		start()
		get_viewport().set_input_as_handled()


func start() -> void:
	state = PLAY
	_show_card("")
	_burst(_feet_screen(), GOLD, 14, 90.0)


func _process(delta: float) -> void:
	_time += delta
	if state == PLAY:
		_acc = minf(_acc + delta, 0.25)
		while _acc >= STEP_SEC:
			_acc -= STEP_SEC
			tick(_read_input())
	_animate(delta)
	_refresh_hud()
	queue_redraw()


func _read_input() -> Dictionary:
	# Same mapping as Direct: arrows/A,D walk; Space/Z/X = Pico ❎.
	return {
		"left": Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A),
		"right": Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D),
		"jump": Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_Z)
				or Input.is_key_pressed(KEY_X),
	}


## One Pico frame: Direct step, then read-only juice from the state delta.
func tick(btn: Dictionary) -> void:
	_draw_prev = Vector2(world.hx, world.hy)
	world.step(btn)
	_draw_cur = Vector2(world.hx, world.hy)
	_on_world_step()


func _snap_prev() -> void:
	_prev_hx = world.hx
	_prev_hy = world.hy
	_prev_dy = world.dy


func _on_world_step() -> void:
	play_frames += 1
	if _prev_hy > float(Logic.H):
		# Direct init(): fell off the bottom and respawned.
		falls += 1
		air_frames = 0
		_draw_prev = _draw_cur  # no interpolation across the teleport
		_flash = 0.6
		_flash_color = Color(0.35, 0.2, 0.5)
		_float(FIELD_POS + Vector2(FIELD.x * 0.5 - 40, FIELD.y - 40), "WHOOPS!", RED)
		_burst(_feet_screen() + Vector2(0, -20), GOLD, 18, 70.0, 0.0)
		_squash = Vector2(0.6, 1.4)
		_snap_prev()
		return

	# Reproduce Direct's snap condition from the pre-step state (read-only).
	var snapped: bool = world.on_ground and _prev_dy + 1.0 > 0.0
	var jumped: bool = snapped and world.dy < 0.0
	if snapped:
		if air_frames > 0:
			_on_land(_prev_dy)
		var cell := Vector2i(int(floor(_prev_hx / Logic.CELL)), int(floor(_prev_hy / Logic.CELL)) + 1)
		_visit(ledge_at(cell))
	if jumped:
		jumps += 1
		_squash = Vector2(0.72, 1.32)
		_dust(_feet_screen(), 8, 60.0)
	if snapped and not jumped:
		air_frames = 0
	else:
		air_frames += 1
		best_air = maxi(best_air, air_frames)
	# Walk dust on each Direct walk-frame flip while grounded.
	if snapped and not jumped and world.moving and world.tm % 5 == 0:
		_dust(_feet_screen() + Vector2(-world.dx * 6.0, 0), 3, 25.0)
	_snap_prev()


func _on_land(impact: float) -> void:
	var k := clampf(impact / 6.0, 0.3, 1.6)
	_squash = Vector2(1.0 + 0.35 * k, 1.0 - 0.3 * k)
	_dust(_feet_screen(), int(6 + 6 * k), 50.0 + 40.0 * k)
	if impact >= 5.0:
		_shake = minf(1.0, 0.25 * k)


func _visit(idx: int) -> void:
	if idx < 0 or visited.has(idx):
		return
	visited[idx] = true
	var run: Array = ledges[idx]
	var mid := Vector2(0, 0)
	for c in run:
		mid += Vector2(c) + Vector2(0.5, 0)
	mid = FIELD_POS + mid / run.size() * Logic.CELL * PX
	_burst(mid, GOLD, 14, 80.0)
	_float(mid + Vector2(-30, -30), "LEDGE %d/%d" % [visited.size(), ledges.size()], GOLD)
	if visited.size() == ledges.size() and all_time < 0:
		all_time = play_frames
		if best_all < 0 or all_time < best_all:
			best_all = all_time
		_show_toast("ALL LEDGES!  %.1fs" % (all_time / float(Logic.FPS)))
		_flash = 0.5
		_flash_color = GOLD


func _animate(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	_flash = move_toward(_flash, 0.0, delta * 1.8)
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
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
		f.pos.y -= 30.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	for c in _clouds:
		c.x += c.v * delta
		if c.x > 140.0:
			c.x = -c.w - 8.0


# --- juice helpers ---------------------------------------------------------------

func _hero_pos() -> Vector2:
	## Interpolated hero world pos (sprite top-left + ox) for smooth rendering.
	if state != PLAY:
		return _draw_cur
	return _draw_prev.lerp(_draw_cur, clampf(_acc / STEP_SEC, 0.0, 1.0))


func _feet_screen() -> Vector2:
	var p := _hero_pos()
	return FIELD_POS + Vector2(p.x - Logic.OX + 4.0, p.y + 8.0) * PX


func _dust(at: Vector2, n: int, speed: float) -> void:
	for i in n:
		var a := randf_range(PI * 1.05, PI * 1.95)
		_particles.append({
			"pos": at + Vector2(randf_range(-8, 8), 0), "vel": Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed),
			"life": randf_range(0.25, 0.55), "max": 0.55, "color": DUST,
			"size": randf_range(3.0, 6.0), "grav": 30.0,
		})


func _burst(at: Vector2, color: Color, n: int, speed: float, grav := 60.0) -> void:
	for i in n:
		var a := randf() * TAU
		_particles.append({
			"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed),
			"life": randf_range(0.35, 0.8), "max": 0.8, "color": color,
			"size": randf_range(2.0, 5.0), "grav": grav,
		})


func _float(at: Vector2, text: String, color: Color) -> void:
	at.x = clampf(at.x, FIELD_POS.x + 6.0, FIELD_POS.x + FIELD.x - 150.0)
	_floaters.append({"pos": at, "life": 1.1, "max": 1.1, "text": text, "color": color})


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.0


# --- drawing --------------------------------------------------------------------

func _w(p: Vector2) -> Vector2:
	return FIELD_POS + p * PX


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * _shake * _shake
	var fr := Rect2(FIELD_POS, FIELD)
	draw_rect(fr.grow(8), Color(0.02, 0.01, 0.03))
	draw_rect(fr.grow(5), Color(FRAME, 0.4), false, 2.0)
	draw_set_transform(shake)
	_draw_backdrop()
	_draw_map()
	_draw_hero()
	_draw_particles()
	_draw_floaters()
	draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		draw_rect(fr, Color(_flash_color, _flash * 0.45))
	# Mask anything (clouds, particles, shake) that strays outside the field.
	var o := fr.grow(8)
	draw_rect(Rect2(0, 0, STAGE.x, o.position.y), BG)
	draw_rect(Rect2(0, o.end.y, STAGE.x, STAGE.y - o.end.y), BG)
	draw_rect(Rect2(0, o.position.y, o.position.x, o.size.y), BG)
	draw_rect(Rect2(o.end.x, o.position.y, STAGE.x - o.end.x, o.size.y), BG)
	draw_rect(Rect2(o.position, Vector2(o.size.x, 3)), Color(0.02, 0.01, 0.03))
	draw_rect(Rect2(o.position.x, o.end.y - 3, o.size.x, 3), Color(0.02, 0.01, 0.03))
	draw_rect(Rect2(o.position, Vector2(3, o.size.y)), Color(0.02, 0.01, 0.03))
	draw_rect(Rect2(o.end.x - 3, o.position.y, 3, o.size.y), Color(0.02, 0.01, 0.03))
	draw_rect(fr.grow(5), Color(FRAME, 0.4), false, 2.0)


func _draw_backdrop() -> void:
	var horizon := float(DECOR_ROW * Logic.CELL)  # 64: the décor strip
	# Dusk sky: banded gradient down to the strip.
	var bands := 32
	for i in bands:
		var t := float(i) / (bands - 1)
		var c: Color
		if t < 0.45:
			c = SKY[0].lerp(SKY[1], t / 0.45)
		elif t < 0.8:
			c = SKY[1].lerp(SKY[2], (t - 0.45) / 0.35)
		else:
			c = SKY[2].lerp(SKY[3], (t - 0.8) / 0.2)
		draw_rect(Rect2(_w(Vector2(0, horizon * i / bands)), Vector2(FIELD.x, horizon * PX / bands + 1)), c)
	# Stars in the upper sky.
	for i in 24:
		var sp := Vector2(fmod(i * 37.0, 128.0), fmod(i * 13.0, 26.0) + 2.0)
		var tw := 0.4 + 0.6 * absf(sin(_time * 1.7 + i))
		draw_circle(_w(sp), 1.5, Color(1, 0.95, 0.85, tw * 0.6))
	# Sun sinking behind the hills, slight parallax with the hero.
	var par := (_hero_pos().x - 64.0)
	var sun := Vector2(92.0 - par * 0.03, 50.0)
	draw_circle(_w(sun), 22.0 * PX, Color(1.0, 0.65, 0.35, 0.10))
	draw_circle(_w(sun), 14.0 * PX, Color(1.0, 0.75, 0.40, 0.18))
	draw_circle(_w(sun), 9.0 * PX, Color(1.0, 0.86, 0.55, 0.95))
	# Clouds.
	for c in _clouds:
		var cp := Vector2(c.x - par * 0.05, c.y)
		var col := Color(1.0, 0.70, 0.62, 0.35)
		draw_circle(_w(cp), c.w * 0.35 * PX, col)
		draw_circle(_w(cp + Vector2(c.w * 0.35, 1.5)), c.w * 0.28 * PX, col)
		draw_circle(_w(cp + Vector2(-c.w * 0.35, 2.0)), c.w * 0.22 * PX, col)
	# Far and near hills with acacia silhouettes.
	_draw_hills(horizon, 46.0, 7.0, 0.06, par * 0.08, Color(0.36, 0.16, 0.30))
	_draw_hills(horizon, 54.0, 5.0, 0.11, par * 0.16, Color(0.22, 0.09, 0.20))
	for tx in [14.0, 58.0, 104.0]:
		_draw_acacia(Vector2(tx - par * 0.16, horizon - 4.0), Color(0.16, 0.06, 0.15))
	# Below the strip: a misty chasm (falling past y=128 resets, as in Direct).
	var depth := float(Logic.H) - horizon
	for i in 16:
		var t := float(i) / 15.0
		var c := Color(0.20, 0.08, 0.18).lerp(Color(0.03, 0.01, 0.05), t)
		draw_rect(Rect2(_w(Vector2(0, horizon + depth * i / 16.0)), Vector2(FIELD.x, depth * PX / 16.0 + 1)), c)
	for f in _flies:
		var fp := Vector2(f.x + sin(_time * 0.7 + f.z) * 4.0, f.y + cos(_time * 0.9 + f.z) * 3.0)
		var a := 0.3 + 0.7 * absf(sin(_time * 2.3 + f.z))
		draw_circle(_w(fp), 4.0, Color(1.0, 0.85, 0.4, a * 0.25))
		draw_circle(_w(fp), 1.6, Color(1.0, 0.92, 0.6, a))
	# Bottom danger glow.
	for i in 6:
		draw_rect(Rect2(_w(Vector2(0, 128.0 - i * 2.0 - 2.0)), Vector2(FIELD.x, 2.0 * PX)),
				Color(0.85, 0.2, 0.3, 0.05 * (6 - i)))


func _draw_hills(base: float, top: float, amp: float, freq: float, shift: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(_w(Vector2(0, base)))
	for i in 33:
		var x := i * 4.0
		var y := top - amp * (0.6 * sin((x + shift) * freq) + 0.4 * sin((x + shift) * freq * 2.3 + 1.0))
		pts.append(_w(Vector2(x, minf(y, base))))
	pts.append(_w(Vector2(128, base)))
	draw_colored_polygon(pts, col)


func _draw_acacia(at: Vector2, col: Color) -> void:
	draw_line(_w(at), _w(at + Vector2(0.5, -9.0)), col, 1.2 * PX)
	draw_line(_w(at + Vector2(0.3, -6.0)), _w(at + Vector2(3.0, -10.0)), col, 0.7 * PX)
	var crown := at + Vector2(0.5, -11.0)
	for k in 5:
		var o := Vector2((k - 2) * 2.4, absf(k - 2) * 0.5)
		draw_circle(_w(crown + o), 2.6 * PX, col)


func _draw_map() -> void:
	var glow := 0.5 + 0.5 * sin(_time * 3.0)
	for my in MapData.H:
		for mx in MapData.W:
			var tid: int = MapData.TILES[my][mx]
			if tid == 0:
				continue
			var tex: Texture2D = _sprites.get(tid)
			var at := _w(Vector2(mx, my) * Logic.CELL)
			var dest := Rect2(at, Vector2(Logic.CELL, Logic.CELL) * PX)
			if tid == Logic.GROUND:
				# Drop shadow under the 4px-tall ledge art.
				draw_rect(Rect2(at + Vector2(PX, 4.0 * PX), Vector2(Logic.CELL * PX, 2.0 * PX)), Color(0, 0, 0, 0.30))
				draw_texture_rect(tex, dest, false)
				var li := ledge_at(Vector2i(mx, my))
				if visited.has(li):
					draw_rect(Rect2(at + Vector2(0, -PX), Vector2(Logic.CELL * PX, PX)), Color(GOLD, 0.35 + 0.35 * glow))
				else:
					draw_rect(Rect2(at, Vector2(Logic.CELL * PX, 1.0 * PX)), Color(1, 1, 1, 0.10))
			else:
				# Décor strip (tile 17): ember shimmer behind the Direct art.
				draw_rect(Rect2(at - Vector2(0, 2.0 * PX), Vector2(Logic.CELL * PX, 12.0 * PX)),
						Color(1.0, 0.45, 0.25, 0.10 + 0.06 * sin(_time * 2.0 + mx)))
				draw_texture_rect(tex, dest, false)


func _draw_hero() -> void:
	var hp := _hero_pos()
	var mx := int(floor(hp.x / Logic.CELL))
	var feet_x := hp.x - Logic.OX + 4.0
	# Soft shadow on the first ledge below.
	for r in range(maxi(0, int(floor(hp.y / Logic.CELL)) + 1), MapData.H):
		if MapData.mget(mx, r) == Logic.GROUND:
			var gy := float(r * Logic.CELL)
			var d := clampf((gy - (hp.y + 8.0)) / 48.0, 0.0, 1.0)
			var w := (4.5 - 2.0 * d) * PX
			_ellipse(_w(Vector2(feet_x, gy + 0.5)), Vector2(w, w * 0.28), Color(0, 0, 0, 0.35 * (1.0 - d * 0.7)))
			break
	var hero: Texture2D = _sprites.get(world.frame)
	if hero == null:
		return
	var feet := _w(Vector2(feet_x, hp.y + 8.0))
	draw_circle(feet + Vector2(0, -4.0 * PX), 7.0 * PX, Color(1.0, 0.85, 0.5, 0.08))
	var fx := -1.0 if world.flip_x else 1.0
	draw_set_transform(feet, 0.0, Vector2(PX * _squash.x * fx, PX * _squash.y))
	draw_texture(hero, Vector2(-4, -8))
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _draw_particles() -> void:
	for p in _particles:
		var a := clampf(p.life / maxf(float(p.max), 0.001), 0.0, 1.0)
		draw_circle(p.pos, float(p.size) * (0.5 + 0.5 * a), Color(p.color, a * 0.85))


func _draw_floaters() -> void:
	for f in _floaters:
		var a := clampf(f.life / maxf(float(f.max), 0.001), 0.0, 1.0)
		var col: Color = f.color
		col.a = a
		draw_string(_font, f.pos + Vector2(2, 2), str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, a * 0.6))
		draw_string(_font, f.pos, str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)


# --- HUD / cards ------------------------------------------------------------------

func _secs(frames: int) -> String:
	return "%.1fs" % (frames / float(Logic.FPS))


func _refresh_hud() -> void:
	var secs := play_frames / Logic.FPS
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	_jumps_label.text = str(jumps)
	_falls_label.text = str(falls)
	_ledge_label.text = "%d / %d" % [visited.size(), ledges.size()]
	_ledge_label.modulate = GOLD if visited.size() == ledges.size() else Color.WHITE
	_air_label.text = _secs(best_air)
	_best_label.text = _secs(best_all) if best_all >= 0 else "—"


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


func _stat(parent: Control, y: float, name: String, color: Color, big := 34) -> Label:
	_add(parent, _label(name, 14, MUTED), Rect2(20, y, 220, 20))
	return _add(parent, _label("0", big, color), Rect2(20, y + 20, 220, 44)) as Label


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = STAGE
	_ui.add_child(root)

	var title := _label("GIRAFFE", 30, FRAME.lightened(0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, title, Rect2(0, 6, STAGE.x, 36))
	var sub := _label("Enhanced  ·  pico-games giraffe.p8", 14, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, sub, Rect2(0, 40, STAGE.x, 22))

	var back := _button("Back to Arcade", Color(0.45, 0.22, 0.30), 18)
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)

	var lp := _panel(root, Rect2(24, 64, 272, 640))
	_time_label = _stat(lp, 18, "TIME", INK, 32)
	_jumps_label = _stat(lp, 98, "JUMPS", LEAF)
	_falls_label = _stat(lp, 178, "FALLS", RED)
	_ledge_label = _stat(lp, 258, "LEDGES VISITED", GOLD)
	_air_label = _stat(lp, 338, "BEST AIR TIME", Color(0.6, 0.85, 1.0), 30)
	_best_label = _stat(lp, 418, "BEST ALL-LEDGES RUN", GOLD, 30)
	_add(lp, _label("Land on every ledge\nto light it gold.", 14, MUTED), Rect2(20, 520, 232, 60))

	var rp := _panel(root, Rect2(STAGE.x - 296, 64, 272, 640))
	_add(rp, _label("WALK", 14, MUTED), Rect2(20, 18, 232, 20))
	_add(rp, _label("Arrows  or  A / D", 18, INK), Rect2(20, 40, 232, 28))
	_add(rp, _label("JUMP", 14, MUTED), Rect2(20, 92, 232, 20))
	_add(rp, _label("Space  /  Z  /  X", 18, INK), Rect2(20, 114, 232, 28))
	_add(rp, _label("Hold jump to bunny-hop\nthe moment you land.", 14, MUTED), Rect2(20, 146, 232, 44))
	_add(rp, _label("PAUSE", 14, MUTED), Rect2(20, 214, 232, 20))
	_add(rp, _label("Esc", 18, INK), Rect2(20, 236, 232, 28))
	_add(rp, _label("Fall into the chasm and\nyou're back at the start.", 14, MUTED), Rect2(20, 300, 232, 44))
	_add(rp, _label("Same rules as Direct.\nPresentation only.", 13, MUTED), Rect2(20, 560, 232, 44))

	_toast = _label("", 30, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_add(root, _toast, Rect2(FIELD_POS.x, FIELD_POS.y + 16, FIELD.x, 40))

	# Title card
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, holder, Rect2(Vector2.ZERO, STAGE))
	var tc := CenterContainer.new()
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(holder, tc, Rect2(FIELD_POS, FIELD))
	var tp := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.12, 0.06, 0.14, 0.94)
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
	for row in [["GIRAFFE", 46, GOLD], ["Enhanced edition", 18, FRAME],
			["Hop across the savanna ledges at dusk.", 15, MUTED],
			["Walk: Arrows / A,D    Jump: Space / Z / X", 15, INK],
			["Press Space or an arrow to start", 20, LEAF]]:
		var l := _label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(l)
	_cards["title"] = holder
