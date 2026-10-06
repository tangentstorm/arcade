extends Node2D
## Kill 'Em All (Enhanced). Visual/UI makeover of the GameMaker twin-stick
## prototype. Thrust, inertia, aim, fire, kickback and bullet motion are the
## Direct ka_world.gd (preloaded, not copied), and the key map is Direct
## game.gd's KEYS / LITERAL_KEYS. This file owns the 1280x720 letterbox shell:
## neon arena, ship glow / thrust flame / wake, bullet tracers + muzzle flash,
## room-edge pings, reticle, off-room pointer, HUD panels (speed, vector dial,
## radar, stats), title card and Back to Arcade. Esc is handled by the
## PauseOverlay autoload. No enemies, no score: same as the 2017 source.
## No Alchementrix IP.

const World := preload("res://games/killem_all/direct/ka_world.gd")
const Direct := preload("res://games/killem_all/direct/game.gd")
const GMFont := preload("res://games/killem_all/direct/ka_font.gd")
const SHIP_TEX := preload("res://games/killem_all/direct/assets/sprite1_0.png")
const BLAST_TEX := preload("res://games/killem_all/direct/assets/sprite0_0.png")
const FONT_TEX := preload("res://games/killem_all/direct/assets/fntConsolas.png")
const SHIP_ORIGIN := Vector2(32, 32)

const STAGE := Vector2(1280, 720)
const RS := 0.8125  ## room0 1024x768 -> 832x624 field
const ROOM := Vector2(World.W, World.H)
const FIELD := ROOM * RS
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 72.0)
const STEP_SEC := 1.0 / World.SPEED
const MAX_SPEED := World.MAXSPEED * 1.41421356  ## both axes clamped to 10
const RADAR_SPAN := 3.0  ## radar shows a 3x3-room neighbourhood around room0
const EDGE_WARN := 96.0

## room0 colour 1835008 (BGR $1C0000 -> RGB 0,0,28), kept as the arena base.
const ROOM_COLOR := Color8(0, 0, 28)
const BG_TOP := Color(0.02, 0.02, 0.07)
const BG_BOTTOM := Color(0.05, 0.02, 0.10)
const PANEL := Color(0.05, 0.06, 0.16, 0.92)
const FRAME := Color(0.36, 0.72, 1.0)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.56, 0.62, 0.82)
const CYAN := Color(0.38, 0.92, 1.0)
const GOLD := Color(1.0, 0.82, 0.32)
const HOT := Color(1.0, 0.45, 0.25)
const MAGENTA := Color(1.0, 0.36, 0.78)
const RED := Color(1.0, 0.32, 0.38)
const GREEN := Color(0.45, 0.95, 0.6)

var world = World.new()
var playing := false
var _acc := 0.0
var _time := 0.0
var _shake := 0.0
var _shake_vec := Vector2.ZERO  ## this frame's field offset
var _kick := 0.0           ## reticle bloom while firing
var _distance := 0.0       ## room px travelled (stats only)
var _top_speed := 0.0
var _prev_fired := 0
var _shot_steps: Array[int] = []  ## world.steps of recent shots (rate meter)
var _particles: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _wake: Array[Vector2] = []
var _inside := {}          ## bullet instance id -> was inside room last step
var _pings := 0            ## bullets that crossed the room edge (stats only)
var _stars: Array[Dictionary] = []

var _field: Control
var _ui: Control
var _gauges: Control
var _cards := {}
var _time_label: Label
var _speed_label: Label
var _fired_label: Label
var _flight_label: Label
var _rate_label: Label
var _dist_label: Label
var _pos_label: Label
var _out_banner: Label
var _font: Font
var _mono: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_mono = sf
	_seed_stars()
	_build_field()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_prev_fired = world.fired
	_show_card("title")
	_refresh_hud()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = ((size - STAGE * s) * 0.5).floor()


func start() -> void:
	playing = true
	_acc = 0.0
	_show_card("")


## R: restart room0 (Direct room_start = init.gml) and clear the shell's FX.
func restart_room() -> void:
	world.room_start()
	_prev_fired = 0
	_distance = 0.0
	_top_speed = 0.0
	_pings = 0
	_shot_steps.clear()
	_particles.clear()
	_flashes.clear()
	_wake.clear()
	_inside.clear()
	start()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	if not playing and k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		start()
		get_viewport().set_input_as_handled()
	elif playing and k == KEY_R:
		restart_room()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	if playing:
		_acc = minf(_acc + delta, 0.25)
		while _acc >= STEP_SEC:
			_acc -= STEP_SEC
			tick(_read_input())
	_animate(delta)
	_refresh_hud()
	_field.queue_redraw()
	_gauges.queue_redraw()
	queue_redraw()


## One Direct step plus the presentation hooks that observe it.
func tick(input: Dictionary) -> void:
	var before := Vector2(world.ship_x, world.ship_y)
	world.step(input)
	_on_world_step(before)


# --- input (Direct key map) ---------------------------------------------------

func _dir_held(name: String) -> bool:
	for k in Direct.KEYS[name]:
		if Input.is_physical_key_pressed(k):
			return true
	return Input.is_key_pressed(Direct.LITERAL_KEYS[name])


func _read_input() -> Dictionary:
	return {
		"left": _dir_held("left"),
		"right": _dir_held("right"),
		"up": _dir_held("up"),
		"down": _dir_held("down"),
		"fire": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"mouse": room_mouse(),
	}


## Mouse in room0 coordinates (the field Control is the room, scaled).
func room_mouse() -> Vector2:
	return _field.get_local_mouse_position()


# --- presentation hooks (observe Direct state; never write it) ----------------

func _ship() -> Vector2:
	return Vector2(world.ship_x, world.ship_y)


func _aim_dir() -> Vector2:
	var r := deg_to_rad(world.blast_angle)
	return Vector2(cos(r), -sin(r))


func _on_world_step(before: Vector2) -> void:
	var ship := _ship()
	var v := Vector2(world.dx, world.dy)
	_distance += ship.distance_to(before)
	_top_speed = maxf(_top_speed, v.length())
	# wake
	_wake.append(ship)
	if _wake.size() > 28:
		_wake.pop_front()
	# thrust flame sparks, opposite the held heading
	if world.hx != 0 or world.hy != 0:
		var h := Vector2(world.hx, world.hy).normalized()
		for i in 2:
			var a := randf_range(-0.35, 0.35)
			_particles.append({
				"pos": ship - h * 26.0, "vel": (-h).rotated(a) * randf_range(90, 200) + v * 20.0,
				"life": 0.32, "max": 0.32, "color": CYAN if i == 0 else Color(0.6, 0.5, 1.0),
				"size": randf_range(2.5, 5.0),
			})
	# new shots: muzzle flash + sparks + reticle bloom
	var new_shots: int = world.fired - _prev_fired
	if new_shots > 0:
		var d := _aim_dir()
		var tip := ship + d * World.GUN_RADIUS
		_flashes.append({"pos": tip, "dir": d, "life": 0.09, "max": 0.09})
		for i in 3:
			_particles.append({
				"pos": tip, "vel": d.rotated(randf_range(-0.7, 0.7)) * randf_range(80, 260),
				"life": 0.22, "max": 0.22, "color": GOLD, "size": randf_range(1.5, 3.0),
			})
		for i in new_shots:
			_shot_steps.append(world.steps)
		_kick = minf(_kick + 0.35, 1.0)
		_shake = minf(_shake + 0.08, 0.35)
	_prev_fired = world.fired
	while not _shot_steps.is_empty() and world.steps - _shot_steps[0] >= World.SPEED:
		_shot_steps.pop_front()
	# room-edge pings: a bullet leaving room0 sparks on the edge it crossed
	var seen := {}
	for b in world.bullets:
		var id: int = b.get_instance_id()
		var inside: bool = b.x >= 0 and b.x <= World.W and b.y >= 0 and b.y <= World.H
		if _inside.get(id, true) and not inside:
			_ping(Vector2(clampf(b.x, 0, World.W), clampf(b.y, 0, World.H)), b.direction)
		seen[id] = inside
	_inside = seen


func _ping(at: Vector2, direction: float) -> void:
	_pings += 1
	var r := deg_to_rad(direction)
	var d := Vector2(cos(r), -sin(r))
	_flashes.append({"pos": at, "dir": d, "life": 0.18, "max": 0.18, "ring": true})
	for i in 4:
		_particles.append({
			"pos": at, "vel": (-d).rotated(randf_range(-1.2, 1.2)) * randf_range(60, 180),
			"life": 0.35, "max": 0.35, "color": MAGENTA, "size": randf_range(1.5, 3.0),
		})


func _animate(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 1.6)
	_kick = move_toward(_kick, 0.0, delta * 2.5)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.92
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _flashes:
		f.life -= delta
	_flashes = _flashes.filter(func(f): return f.life > 0.0)
	if _particles.size() > 600:
		_particles = _particles.slice(_particles.size() - 600)


func _seed_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2017
	for i in 140:
		_stars.append({
			"p": Vector2(rng.randf() * World.W, rng.randf() * World.H),
			"depth": rng.randf_range(0.02, 0.12),
			"size": rng.randf_range(0.8, 2.2),
			"phase": rng.randf() * TAU,
		})


# --- stage background ---------------------------------------------------------

func _draw() -> void:
	var bands := 24
	for i in bands:
		var t := float(i) / (bands - 1)
		draw_rect(Rect2(0, STAGE.y * i / bands, STAGE.x, STAGE.y / bands + 1), BG_TOP.lerp(BG_BOTTOM, t))
	# nebula glows behind the field
	for g in [[Vector2(260, 180), 260.0, Color(0.35, 0.15, 0.6)], [Vector2(1040, 560), 300.0, Color(0.1, 0.35, 0.6)]]:
		for k in 6:
			draw_circle(g[0], g[1] * (1.0 - k * 0.15), Color(g[2], 0.035))
	# field frame + glow
	var fr := Rect2(FIELD_POS, FIELD)
	for k in 4:
		draw_rect(fr.grow(4 + k * 3), Color(FRAME, 0.10 - k * 0.022), false, 3.0)
	draw_rect(fr.grow(2), Color(0.01, 0.01, 0.03))
	draw_rect(fr.grow(3), Color(FRAME, 0.55), false, 1.5)


# --- field (room coordinates; clipped to room0) -------------------------------

func _build_field() -> void:
	_field = Control.new()
	_field.name = "Room"
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.size = ROOM
	_field.scale = Vector2(RS, RS)
	_field.position = FIELD_POS
	_field.draw.connect(_draw_field)
	add_child(_field)


func _draw_field() -> void:
	var f := _field
	var ship := _ship()
	var amp := 4.0 * _shake * _shake
	_shake_vec = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amp
	f.draw_rect(Rect2(Vector2.ZERO, ROOM), ROOM_COLOR)
	# soft radial wash toward the centre
	for k in 8:
		f.draw_circle(ROOM * 0.5, 620.0 - k * 70.0, Color(0.08, 0.10, 0.35, 0.05))
	f.draw_set_transform(_shake_vec)
	# parallax starfield (moves gently against the ship)
	var off := ship - ROOM * 0.5
	for s in _stars:
		var p: Vector2 = s.p - off * float(s.depth)
		p = Vector2(fposmod(p.x, World.W), fposmod(p.y, World.H))
		var tw := 0.45 + 0.55 * absf(sin(_time * 1.7 + float(s.phase)))
		f.draw_circle(p, float(s.size), Color(0.8, 0.9, 1.0, 0.35 + 0.45 * tw))
	_draw_grid(f, ship)
	_draw_edges(f, ship)
	_draw_wake(f)
	_draw_bullets(f)
	_draw_ship(f, ship)
	_draw_particles(f)
	_draw_flashes(f)
	if playing:
		_draw_reticle(f, ship)
	f.draw_set_transform(Vector2.ZERO)
	_draw_offroom(f, ship)
	# events Draw -> mousepos.gml, the original debug readout, in fntConsolas.
	var txt := "x:%d, y:%d" % [floori(world.mouse.x), floori(world.mouse.y)]
	f.draw_rect(Rect2(4, 6, _text_width(txt) + 12, 26), Color(0, 0, 0, 0.35))
	_draw_gm_text(f, Vector2(10, 10), txt, Color(0.85, 0.95, 1.0, 0.85))


func _draw_grid(f: Control, ship: Vector2) -> void:
	var step := 64
	var pulse := 0.5 + 0.5 * sin(_time * 1.3)
	for x in range(0, World.W + 1, step):
		var near := clampf(1.0 - absf(x - ship.x) / 220.0, 0.0, 1.0)
		f.draw_line(Vector2(x, 0), Vector2(x, World.H), Color(0.3, 0.45, 1.0, 0.12 + 0.04 * pulse + 0.22 * near), 1.5)
	for y in range(0, World.H + 1, step):
		var near := clampf(1.0 - absf(y - ship.y) / 220.0, 0.0, 1.0)
		f.draw_line(Vector2(0, y), Vector2(World.W, y), Color(0.3, 0.45, 1.0, 0.12 + 0.04 * pulse + 0.22 * near), 1.5)
	# floor glow under the ship
	for k in 5:
		f.draw_circle(ship, 140.0 - k * 26.0, Color(0.25, 0.55, 1.0, 0.025))


## Room edges glow; they heat up as the ship nears one (there are no walls).
func _draw_edges(f: Control, ship: Vector2) -> void:
	var d := minf(minf(ship.x, World.W - ship.x), minf(ship.y, World.H - ship.y))
	var heat := clampf(1.0 - d / EDGE_WARN, 0.0, 1.0)
	var c := Color(FRAME, 0.35).lerp(Color(HOT, 0.85), heat)
	for k in 3:
		f.draw_rect(Rect2(Vector2.ONE * (2 + k * 4), ROOM - Vector2.ONE * (4 + k * 8)),
				Color(c, c.a * (1.0 - k * 0.35)), false, 3.0 - k)


func _draw_wake(f: Control) -> void:
	var n := _wake.size()
	for i in range(1, n):
		var t := float(i) / n
		f.draw_line(_wake[i - 1], _wake[i], Color(0.4, 0.8, 1.0, t * 0.22), 1.5 + t * 5.0)


func _draw_bullets(f: Control) -> void:
	for b in world.bullets:
		var r := deg_to_rad(b.direction)
		var d := Vector2(cos(r), -sin(r))
		var p := Vector2(b.x, b.y)
		f.draw_line(p - d * 34.0, p, Color(HOT, 0.25), 7.0)
		f.draw_line(p - d * 22.0, p, Color(GOLD, 0.7), 3.0)
		f.draw_circle(p, 6.0, Color(GOLD, 0.25))
		f.draw_circle(p, 3.0, Color(1.0, 0.97, 0.85))


func _draw_ship(f: Control, ship: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	# halo
	for k in 5:
		f.draw_circle(ship, 52.0 - k * 7.0, Color(CYAN, 0.035 + 0.015 * pulse))
	# thrust flame opposite the held heading
	if playing and (world.hx != 0 or world.hy != 0):
		var h := Vector2(world.hx, world.hy).normalized()
		var n := h.orthogonal()
		var flick := randf_range(0.8, 1.2)
		var base := ship - h * 22.0
		f.draw_colored_polygon(PackedVector2Array([
			base + n * 12.0, base - h * 46.0 * flick, base - n * 12.0]), Color(0.45, 0.55, 1.0, 0.55))
		f.draw_colored_polygon(PackedVector2Array([
			base + n * 6.0, base - h * 28.0 * flick, base - n * 6.0]), Color(0.85, 0.97, 1.0, 0.9))
	# drop shadow + original disc sprite, tinted
	f.draw_texture(SHIP_TEX, ship - SHIP_ORIGIN + Vector2(5, 7), Color(0, 0, 0, 0.45))
	f.draw_texture(SHIP_TEX, ship - SHIP_ORIGIN, Color(0.78, 0.9, 1.0))
	f.draw_arc(ship, 31.0, 0.0, TAU, 48, Color(CYAN, 0.6 + 0.3 * pulse), 2.0)
	# core
	f.draw_circle(ship, 7.0, Color(CYAN, 0.9))
	f.draw_circle(ship, 3.0, Color.WHITE)
	# gun arc: Direct objBlast sprite rotated (GM CCW -> Godot CW), gold with glow
	f.draw_set_transform(ship + _shake_vec, -deg_to_rad(world.blast_angle), Vector2(1.08, 1.08))
	f.draw_texture(BLAST_TEX, -SHIP_ORIGIN, Color(HOT, 0.35))
	f.draw_set_transform(ship + _shake_vec, -deg_to_rad(world.blast_angle))
	f.draw_texture(BLAST_TEX, -SHIP_ORIGIN, GOLD)
	f.draw_set_transform(_shake_vec)


func _draw_particles(f: Control) -> void:
	for p in _particles:
		var a := clampf(p.life / maxf(float(p.max), 0.001), 0.0, 1.0)
		f.draw_circle(p.pos, float(p.size) * (0.4 + 0.6 * a), Color(p.color, a))


func _draw_flashes(f: Control) -> void:
	for fl in _flashes:
		var a := clampf(fl.life / maxf(float(fl.max), 0.001), 0.0, 1.0)
		if fl.get("ring", false):
			f.draw_arc(fl.pos, 6.0 + 26.0 * (1.0 - a), 0.0, TAU, 24, Color(MAGENTA, a), 2.5)
		else:
			var d: Vector2 = fl.dir
			var n := d.orthogonal()
			f.draw_circle(fl.pos, 14.0 * a + 4.0, Color(1.0, 0.9, 0.5, 0.5 * a))
			f.draw_colored_polygon(PackedVector2Array([
				fl.pos + n * 7.0, fl.pos + d * 30.0, fl.pos - n * 7.0]), Color(1.0, 0.95, 0.7, a))


func _draw_reticle(f: Control, ship: Vector2) -> void:
	var m := world.mouse as Vector2
	# aim guide: dotted line from the gun tip to the reticle
	var d := _aim_dir()
	var tip := ship + d * (World.GUN_RADIUS + 8.0)
	var guide := maxf(0.0, tip.distance_to(m) - 18.0)
	var dot := 0.0
	while dot < guide:
		f.draw_circle(tip + d * dot, 1.6, Color(GOLD, 0.35))
		dot += 14.0
	var r := 14.0 + 8.0 * _kick
	var spin := _time * 1.5
	f.draw_arc(m, r, 0.0, TAU, 32, Color(GOLD, 0.8), 1.5)
	for i in 4:
		var a := spin + i * PI * 0.5
		var u := Vector2(cos(a), sin(a))
		f.draw_line(m + u * (r - 5.0), m + u * (r + 7.0), Color(GOLD, 0.95), 2.0)
	f.draw_circle(m, 2.0, Color.WHITE)


func ship_out_of_room() -> bool:
	return world.ship_x < 0 or world.ship_x > World.W or world.ship_y < 0 or world.ship_y > World.H


## Off-room pointer: the room has no walls, so show where the ship went.
func _draw_offroom(f: Control, ship: Vector2) -> void:
	if not ship_out_of_room():
		return
	var c := ROOM * 0.5
	var dir := (ship - c).normalized()
	# clamp the pointer to an inset rectangle along the ray to the ship
	var inset := ROOM * 0.5 - Vector2(40, 40)
	var t := minf(inset.x / maxf(absf(dir.x), 0.0001), inset.y / maxf(absf(dir.y), 0.0001))
	var p := c + dir * t
	var n := dir.orthogonal()
	var blink := 0.6 + 0.4 * sin(_time * 8.0)
	f.draw_colored_polygon(PackedVector2Array([p + dir * 22.0, p - dir * 10.0 + n * 16.0, p - dir * 10.0 - n * 16.0]),
			Color(HOT, blink))
	var dist := ship.distance_to(Vector2(clampf(ship.x, 0, World.W), clampf(ship.y, 0, World.H)))
	f.draw_string(_font, p - dir * 40.0 + Vector2(-30, 6), "%d px" % int(dist),
			HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Color(HOT, 0.95))


## draw_text with fntConsolas (Direct's glyph table), tinted.
func _draw_gm_text(f: Control, at: Vector2, text: String, tint: Color) -> void:
	var pen := at.x
	for i in text.length():
		var g: Array = GMFont.GLYPHS.get(text.unicode_at(i), GMFont.GLYPHS[32])
		f.draw_texture_rect_region(FONT_TEX, Rect2(pen + g[5], at.y, g[2], g[3]),
				Rect2(g[0], g[1], g[2], g[3]), tint)
		pen += g[4]


func _text_width(text: String) -> float:
	var w := 0.0
	for i in text.length():
		w += float(GMFont.GLYPHS.get(text.unicode_at(i), GMFont.GLYPHS[32])[4])
	return w


# --- gauges (speed bar, vector dial, radar) -----------------------------------

const LEFT := Rect2(16, 72, 192, 624)
const RIGHT := Rect2(1072, 72, 192, 624)
const DIAL_C := Vector2(96, 370)  ## vector dial centre, LEFT-panel local
const RADAR := Rect2(1088, 116, 160, 160)


func _draw_gauges() -> void:
	var g := _gauges
	var v := Vector2(world.dx, world.dy)
	# speed bar
	var bar := Rect2(LEFT.position.x + 16, LEFT.position.y + 132, 160, 12)
	var t := clampf(v.length() / MAX_SPEED, 0.0, 1.0)
	g.draw_rect(bar, Color(0, 0, 0, 0.5))
	g.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), CYAN.lerp(HOT, t))
	var tm := clampf(_top_speed / MAX_SPEED, 0.0, 1.0)
	g.draw_line(bar.position + Vector2(bar.size.x * tm, -3), bar.position + Vector2(bar.size.x * tm, bar.size.y + 3), GOLD, 2.0)
	g.draw_rect(bar, Color(FRAME, 0.5), false, 1.0)
	# vector dial: velocity arrow, held heading, aim
	var c := LEFT.position + DIAL_C
	var rad := 56.0
	g.draw_circle(c, rad, Color(0, 0, 0, 0.45))
	g.draw_arc(c, rad, 0, TAU, 48, Color(FRAME, 0.5), 1.5)
	g.draw_arc(c, rad * 0.5, 0, TAU, 32, Color(FRAME, 0.2), 1.0)
	g.draw_line(c - Vector2(rad, 0), c + Vector2(rad, 0), Color(FRAME, 0.15), 1.0)
	g.draw_line(c - Vector2(0, rad), c + Vector2(0, rad), Color(FRAME, 0.15), 1.0)
	var aim := _aim_dir()
	g.draw_line(c + aim * (rad - 10), c + aim * (rad + 4), GOLD, 3.0)
	if world.hx != 0 or world.hy != 0:
		var h := Vector2(world.hx, world.hy).normalized()
		g.draw_circle(c + h * (rad - 4), 5.0, CYAN)
	var tip := c + v / MAX_SPEED * rad
	g.draw_line(c, tip, Color.WHITE, 2.5)
	g.draw_circle(tip, 3.5, Color.WHITE)
	# radar: room0 inside a 3x3-room neighbourhood
	var rr := RADAR
	var sc := rr.size.x / (World.W * RADAR_SPAN)
	var origin := rr.position + rr.size * 0.5 - ROOM * 0.5 * sc
	g.draw_rect(rr, Color(0.0, 0.03, 0.06, 0.9))
	for k in 3:
		g.draw_arc(rr.get_center(), rr.size.x * (0.17 + k * 0.165), 0, TAU, 40, Color(GREEN, 0.12), 1.0)
	var sweep := fposmod(_time * 1.8, TAU)
	g.draw_line(rr.get_center(), rr.get_center() + Vector2(cos(sweep), sin(sweep)) * rr.size.x * 0.5, Color(GREEN, 0.25), 2.0)
	g.draw_rect(Rect2(origin, ROOM * sc), Color(FRAME, 0.8), false, 1.5)
	for b in world.bullets:
		var bp := origin + Vector2(b.x, b.y) * sc
		if rr.has_point(bp):
			g.draw_rect(Rect2(bp, Vector2(1.5, 1.5)), GOLD)
	var sp := origin + _ship() * sc
	var inside := rr.grow(-3).has_point(sp)
	sp = Vector2(clampf(sp.x, rr.position.x + 3, rr.end.x - 3), clampf(sp.y, rr.position.y + 3, rr.end.y - 3))
	g.draw_line(sp, sp + v * sc * 6.0, Color(CYAN, 0.8), 1.5)
	g.draw_circle(sp, 3.5 if inside else 2.5 + 1.5 * absf(sin(_time * 8.0)), CYAN if inside else HOT)
	g.draw_rect(rr, Color(GREEN, 0.5), false, 1.5)


# --- HUD / cards --------------------------------------------------------------

func _refresh_hud() -> void:
	var secs: int = world.steps / World.SPEED
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	_speed_label.text = "%.1f px/step" % Vector2(world.dx, world.dy).length()
	_fired_label.text = str(world.fired)
	_flight_label.text = str(world.bullets.size())
	_rate_label.text = "%d/s" % _shot_steps.size()
	_dist_label.text = "%.1f rooms" % (_distance / World.W)
	_pos_label.text = "%d, %d" % [roundi(world.ship_x), roundi(world.ship_y)]
	_out_banner.visible = playing and ship_out_of_room()


func _show_card(key: String) -> void:
	for k in _cards:
		_cards[k].visible = (k == key and key != "")


func _label(text: String, size: int, color := INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 18) -> Button:
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


func _panel(parent: Control, rect: Rect2) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = Color(FRAME, 0.45)
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 8
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	return p


func _add(parent: Control, c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	parent.add_child(c)
	return c


func _stat(parent: Control, y: float, caption: String, size: int, color: Color) -> Label:
	_add(parent, _label(caption, 13, MUTED), Rect2(16, y, 160, 18))
	return _add(parent, _label("", size, color, _mono), Rect2(16, y + 18, 168, size + 10)) as Label


func _build_ui() -> void:
	_ui = Control.new()
	_ui.name = "UI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.size = STAGE
	add_child(_ui)

	var title := _label("KILL 'EM ALL", 30, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(_ui, title, Rect2(0, 6, STAGE.x, 38))
	var sub := _label("Enhanced  ·  GameMaker twin-stick prototype (2017)", 14, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(_ui, sub, Rect2(0, 42, STAGE.x, 22))
	var back := _button("Back to Arcade", Color(0.22, 0.28, 0.62))
	back.position = Vector2(16, 14)
	back.pressed.connect(GameRegistry.return_to_arcade)
	_ui.add_child(back)

	# left: flight stats
	var lp := _panel(_ui, LEFT)
	_time_label = _stat(lp, 16, "TIME", 30, INK)
	_speed_label = _stat(lp, 76, "SPEED", 20, CYAN)
	_add(lp, _label("gold tick = top speed", 11, Color(GOLD, 0.8)), Rect2(16, 150, 170, 14))
	_add(lp, _label("VECTOR", 13, MUTED), Rect2(16, 254, 160, 18))
	_add(lp, _label("white velocity · gold aim\ncyan thrust", 11, MUTED), Rect2(16, 268, 170, 30))
	_pos_label = _stat(lp, 470, "POSITION", 20, INK)
	_dist_label = _stat(lp, 530, "TRAVELLED", 20, INK)

	# right: radar, gun stats, controls
	var rp := _panel(_ui, RIGHT)
	_add(rp, _label("RADAR", 13, MUTED), Rect2(16, 14, 160, 18))
	_fired_label = _stat(rp, 216, "FIRED", 26, GOLD)
	_flight_label = _stat(rp, 270, "IN FLIGHT", 22, GOLD.lightened(0.2))
	_rate_label = _stat(rp, 320, "RATE", 22, HOT)
	_add(rp, _label("CONTROLS", 13, MUTED), Rect2(16, 384, 160, 18))
	_add(rp, _label("WASD / arrows  thrust\nMouse  aim\nHold click  fire\nR  restart room\nEsc  pause", 13, INK),
			Rect2(16, 404, 170, 100))
	_add(rp, _label("Same rules as Direct.\nNo enemies yet, true to\nthe 2017 prototype.\nNo walls: drift at will.", 11, MUTED),
			Rect2(16, 528, 170, 80))

	_gauges = Control.new()
	_gauges.name = "Gauges"
	_gauges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauges.size = STAGE
	_gauges.draw.connect(_draw_gauges)
	_ui.add_child(_gauges)

	_out_banner = _label("OUT OF ROOM  ·  no walls in the original, thrust back", 16, HOT)
	_out_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_out_banner.visible = false
	_add(_ui, _out_banner, Rect2(FIELD_POS.x, FIELD_POS.y + FIELD.y - 34, FIELD.x, 24))

	# title card
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_ui, holder, Rect2(Vector2.ZERO, STAGE))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(holder, cc, Rect2(FIELD_POS, FIELD))
	var pc := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.05, 0.15, 0.93)
	ts.border_color = GOLD
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(18)
	ts.shadow_color = Color(GOLD, 0.2)
	ts.shadow_size = 18
	ts.set_content_margin_all(28)
	pc.add_theme_stylebox_override("panel", ts)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	for row in [["KILL 'EM ALL", 46, GOLD], ["Enhanced edition", 18, CYAN],
			["Thrust a drifting disc, aim with the mouse, hose bullets.\nNobody to kill yet: the 2017 prototype never got enemies.", 15, MUTED],
			["Press Space or click Start", 18, GREEN]]:
		var l := _label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	var start_btn := _button("Start", Color(0.15, 0.5, 0.3), 20)
	start_btn.name = "StartButton"
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(start)
	vb.add_child(start_btn)
	_cards["title"] = holder
