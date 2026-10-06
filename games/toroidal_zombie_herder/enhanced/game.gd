extends Node2D
## Toroidal Zombie Herder (Enhanced). Visual/UI makeover of the GameMaker
## maze-herding toy. Room, hero movement (MoveHero.gml), zombie chase
## (mp_potential_step), wrap, coins, traps and room_restart are the Direct
## tzh_world.gd (preloaded, not copied). This file owns the 1280x720 letterbox
## shell: crypt-stone maze over a foggy flagstone floor, glowing spinning
## coins, pulsing trap runes, shambling zombies with chase arrows, a lantern-lit
## hero, wrap-around ghosts + edge portals, pickup / trap / caught juice, HUD
## panels (score, coins, zombies, caught, minimap, danger meter), title card and
## Back to Arcade. Esc is handled by the PauseOverlay autoload.
## No win state and score survives being caught: same as the 2017 source.
## No Alchementrix IP.

const World := preload("res://games/toroidal_zombie_herder/direct/tzh_world.gd")
const Room0 := preload("res://games/toroidal_zombie_herder/direct/room0.gd")
const HERO_TEX := preload("res://games/toroidal_zombie_herder/direct/assets/spr_hero_0.png")
const ZOMBIE_TEX := preload("res://games/toroidal_zombie_herder/direct/assets/spr_zombie_0.png")
const TRAP_TEX := preload("res://games/toroidal_zombie_herder/direct/assets/spr_trap_0.png")

const STAGE := Vector2(1280, 720)
const RS := 0.8125  ## room0 1024x768 -> 832x624 field
const ROOM := Vector2(World.W, World.H)
const FIELD := ROOM * RS
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 72.0)
const STEP_SEC := 1.0 / Room0.SPEED
const CELL := 32.0
const DANGER_RANGE := 192.0  ## room px: danger meter / vignette start

## obj_score draw colour 16777088 (BGR $FFFF80 -> RGB 128,255,255), kept for score.
const SCORE_COLOR := Color8(128, 255, 255)
const BG_TOP := Color(0.03, 0.05, 0.05)
const BG_BOTTOM := Color(0.07, 0.04, 0.09)
const FLOOR_A := Color(0.075, 0.09, 0.095)
const FLOOR_B := Color(0.085, 0.10, 0.105)
const STONE := Color(0.33, 0.35, 0.40)
const STONE_HI := Color(0.55, 0.58, 0.64)
const STONE_LO := Color(0.16, 0.17, 0.21)
const MOSS := Color(0.32, 0.55, 0.28)
const PANEL := Color(0.05, 0.08, 0.08, 0.92)
const FRAME := Color(0.45, 0.85, 0.55)
const INK := Color(0.92, 0.96, 0.92)
const MUTED := Color(0.58, 0.70, 0.62)
const TOXIC := Color(0.55, 1.0, 0.35)
const GOLD := Color(1.0, 0.82, 0.30)
const LANTERN := Color(1.0, 0.78, 0.45)
const BLOOD := Color(1.0, 0.25, 0.25)
const PORTAL := Color(0.55, 0.45, 1.0)

var world = World.new()
var playing := false
var _acc := 0.0
var _time := 0.0
var _shake := 0.0
var _shake_vec := Vector2.ZERO
var _flash := 0.0          ## red screen flash when caught
var _walls := {}           ## Vector2i cell -> true (room0 walls never move)
var _wall_cells: Array[Vector2i] = []
var _portals: Array[Dictionary] = []   ## open room-edge cells (wrap doors)
var _coin_total := 0
var _prev := {}            ## instance id -> pre-step position (interpolation)
var _hero_moving := false
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _splats: Array[Dictionary] = []    ## trapped-zombie goo (cleared on restart)
var _fog: Array[Dictionary] = []
var _pickups := 0          ## coins taken this run (stats only)
var _trapped := 0          ## zombies trapped this run
var _caught := 0           ## times caught (room_restart) this run
var _wraps := 0            ## hero wraps through an edge
var _last_restarts := 0
var _banner_time := 0.0

var _field: Control
var _ui: Control
var _gauges: Control
var _cards := {}
var _score_label: Label
var _coins_label: Label
var _zombies_label: Label
var _traps_label: Label
var _caught_label: Label
var _time_label: Label
var _wraps_label: Label
var _danger_label: Label
var _status_label: Label
var _banner: Label
var _font: Font
var _mono: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_mono = sf
	_scan_room()
	_seed_fog()
	_build_field()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_last_restarts = world.restarts
	_show_card("title")
	_refresh_hud()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = ((size - STAGE * s) * 0.5).floor()


## Static room facts read from the generated room0 table (walls never change).
func _scan_room() -> void:
	_coin_total = 0
	for row in Room0.INSTANCES:
		if row[0] == "obj_wall":
			var c := Vector2i(roundi(row[1] / CELL), roundi(row[2] / CELL))
			if not _walls.has(c):
				_walls[c] = true
				_wall_cells.append(c)
		elif row[0] == "obj_coin":
			_coin_total += 1
	# wrap doors: an edge cell row/column with no wall on either side of the seam
	var cols := int(World.W / CELL)
	var rows := int(World.H / CELL)
	for y in range(1, rows):
		if not _walls.has(Vector2i(0, y)) and not _walls.has(Vector2i(cols, y)):
			_portals.append({"a": Vector2(0, y * CELL), "b": Vector2(World.W, y * CELL), "n": Vector2.RIGHT})
	for x in range(1, cols):
		if not _walls.has(Vector2i(x, 0)) and not _walls.has(Vector2i(x, rows)):
			_portals.append({"a": Vector2(x * CELL, 0), "b": Vector2(x * CELL, World.H), "n": Vector2.DOWN})


func is_wall(c: Vector2i) -> bool:
	return _walls.has(c)


func start() -> void:
	playing = true
	_acc = 0.0
	_show_card("")


## R: a fresh run (new Direct world, score 0) and a clean shell.
func new_run() -> void:
	world = World.new()
	_last_restarts = 0
	_pickups = 0
	_trapped = 0
	_caught = 0
	_wraps = 0
	_prev.clear()
	_particles.clear()
	_floaters.clear()
	_rings.clear()
	_splats.clear()
	_banner_time = 0.0
	start()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	if not playing and k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		start()
		get_viewport().set_input_as_handled()
	elif playing and k == KEY_R:
		new_run()
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


## One Direct step plus the presentation hooks that observe it.
func tick(input: Dictionary) -> void:
	var hero_before := Vector2(world.hero.x, world.hero.y)
	var coins: Array = world.of_kind(World.COIN)
	var zombies: Array = world.of_kind(World.ZOMBIE)
	var traps: Array = world.of_kind(World.TRAP)
	var score_before: int = world.score
	_prev.clear()
	_prev[world.hero.get_instance_id()] = hero_before
	for z in zombies:
		_prev[z.get_instance_id()] = Vector2(z.x, z.y)
	world.step(input)
	_on_world_step(hero_before, coins, zombies, traps, score_before)


# --- input (Direct keys + WASD) ----------------------------------------------

func _held(arrow: Key, letter: Key) -> bool:
	return Input.is_key_pressed(arrow) or Input.is_physical_key_pressed(letter)


func _read_input() -> Dictionary:
	return {
		"up": _held(KEY_UP, KEY_W),
		"down": _held(KEY_DOWN, KEY_S),
		"left": _held(KEY_LEFT, KEY_A),
		"right": _held(KEY_RIGHT, KEY_D),
		"mouse_down": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"mouse": room_mouse(),
	}


## Mouse in room0 coordinates (the field Control is the room, scaled).
func room_mouse() -> Vector2:
	return _field.get_local_mouse_position()


# --- presentation hooks (observe Direct state; never write it) ----------------

func _hero() -> Vector2:
	return Vector2(world.hero.x, world.hero.y)


## Interpolated draw position between the last two Direct steps.
func _lerp_pos(i) -> Vector2:
	var cur := Vector2(i.x, i.y)
	if not playing:
		return cur
	var p: Vector2 = _prev.get(i.get_instance_id(), cur)
	if p.distance_to(cur) > 64.0:  # wrapped or respawned: no smear across the room
		return cur
	return p.lerp(cur, clampf(_acc / STEP_SEC, 0.0, 1.0))


func nearest_zombie_distance() -> float:
	var h := _hero()
	var best := INF
	for z in world.of_kind(World.ZOMBIE):
		best = minf(best, h.distance_to(Vector2(z.x, z.y)))
	return best


func _on_world_step(hero_before: Vector2, coins: Array, zombies: Array, traps: Array, score_before: int) -> void:
	var hero := _hero()
	if world.restarts != _last_restarts:
		_last_restarts = world.restarts
		_on_caught(hero_before)
		return
	# coins: hero+coin destroyed them this step
	var got := 0
	for c in coins:
		if not c.alive:
			got += 1
			_pickups += 1
			var p := Vector2(c.x, c.y)
			for k in 5:
				_particles.append({"pos": p, "vel": Vector2.from_angle(randf() * TAU) * randf_range(40, 140),
					"life": 0.45, "max": 0.45, "color": GOLD, "size": randf_range(1.5, 3.5)})
			_rings.append({"pos": p, "life": 0.3, "max": 0.3, "r": 18.0, "color": GOLD})
	if got > 0:
		_floaters.append({"pos": hero + Vector2(0, -22), "text": "+%d" % (world.score - score_before),
			"life": 0.8, "max": 0.8, "color": SCORE_COLOR})
	# traps: zombie+trap destroyed both
	for z in zombies:
		if not z.alive:
			_trapped += 1
			var p := Vector2(z.x, z.y)
			_splats.append({"pos": p, "rot": randf() * TAU, "seed": randi()})
			for k in 14:
				_particles.append({"pos": p, "vel": Vector2.from_angle(randf() * TAU) * randf_range(60, 220),
					"life": 0.7, "max": 0.7, "color": TOXIC if k % 2 else Color(0.25, 0.6, 0.2), "size": randf_range(2.0, 5.0)})
			_rings.append({"pos": p, "life": 0.5, "max": 0.5, "r": 46.0, "color": TOXIC})
			_floaters.append({"pos": p + Vector2(0, -26), "text": "TRAPPED!", "life": 1.1, "max": 1.1, "color": TOXIC})
			_shake = minf(_shake + 0.25, 0.6)
			_say("Zombie herded onto a trap!", TOXIC)
	# wrap: the hero jumped across the room (MoveHero's manual wrap)
	var d := hero - hero_before
	if absf(d.x) > World.W * 0.5 or absf(d.y) > World.H * 0.5:
		_wraps += 1
		_rings.append({"pos": hero_before, "life": 0.45, "max": 0.45, "r": 36.0, "color": PORTAL})
		_rings.append({"pos": hero, "life": 0.45, "max": 0.45, "r": 36.0, "color": PORTAL})
	_hero_moving = d.length() > 0.5
	if _hero_moving and world.steps % 3 == 0:
		_particles.append({"pos": hero + Vector2(randf_range(-6, 6), 12), "vel": Vector2(randf_range(-12, 12), -10),
			"life": 0.4, "max": 0.4, "color": Color(0.6, 0.62, 0.6, 0.6), "size": randf_range(2.0, 4.0)})


func _on_caught(at: Vector2) -> void:
	_caught += 1
	_prev.clear()
	_splats.clear()
	for k in 24:
		_particles.append({"pos": at, "vel": Vector2.from_angle(randf() * TAU) * randf_range(80, 280),
			"life": 0.8, "max": 0.8, "color": BLOOD if k % 3 else LANTERN, "size": randf_range(2.0, 5.0)})
	_rings.append({"pos": at, "life": 0.6, "max": 0.6, "r": 70.0, "color": BLOOD})
	_flash = 1.0
	_shake = 1.0
	_say("CAUGHT!  The room restarts: coins respawn, score kept.", BLOOD)


func _say(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_time = 2.4


func _animate(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 2.0)
	_flash = move_toward(_flash, 0.0, delta * 1.8)
	_banner_time = maxf(_banner_time - delta, 0.0)
	_banner.visible = _banner_time > 0.0
	_banner.modulate.a = clampf(_banner_time / 0.4, 0.0, 1.0)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.9
	_particles = _particles.filter(func(p): return p.life > 0.0)
	if _particles.size() > 500:
		_particles = _particles.slice(_particles.size() - 500)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 34.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r): return r.life > 0.0)
	for g in _fog:
		g.p = Vector2(fposmod(g.p.x + g.v.x * delta, World.W), fposmod(g.p.y + g.v.y * delta, World.H))


func _seed_fog() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2017
	for i in 9:
		_fog.append({
			"p": Vector2(rng.randf() * World.W, rng.randf() * World.H),
			"v": Vector2(rng.randf_range(6, 16), rng.randf_range(-4, 4)),
			"r": rng.randf_range(90, 170),
		})


## Offsets at which a sprite near a seam is redrawn so it shows on both sides.
func wrap_offsets(p: Vector2, margin := 24.0) -> Array[Vector2]:
	var xs: Array[float] = [0.0]
	var ys: Array[float] = [0.0]
	if p.x < margin: xs.append(World.W)
	elif p.x > World.W - margin: xs.append(-World.W)
	if p.y < margin: ys.append(World.H)
	elif p.y > World.H - margin: ys.append(-World.H)
	var out: Array[Vector2] = []
	for x in xs:
		for y in ys:
			out.append(Vector2(x, y))
	return out


# --- stage background ---------------------------------------------------------

func _draw() -> void:
	var bands := 24
	for i in bands:
		var t := float(i) / (bands - 1)
		draw_rect(Rect2(0, STAGE.y * i / bands, STAGE.x, STAGE.y / bands + 1), BG_TOP.lerp(BG_BOTTOM, t))
	for g in [[Vector2(220, 600), 280.0, Color(0.2, 0.5, 0.25)], [Vector2(1080, 160), 260.0, Color(0.35, 0.2, 0.5)]]:
		for k in 6:
			draw_circle(g[0], g[1] * (1.0 - k * 0.15), Color(g[2], 0.03))
	var fr := Rect2(FIELD_POS, FIELD)
	for k in 4:
		draw_rect(fr.grow(4 + k * 3), Color(FRAME, 0.09 - k * 0.02), false, 3.0)
	draw_rect(fr.grow(3), Color(FRAME, 0.5), false, 1.5)


# --- field (room coordinates; clipped to room0) -------------------------------

func _build_field() -> void:
	_field = Control.new()
	_field.name = "Room"
	_field.clip_contents = true
	_field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.size = ROOM
	_field.scale = Vector2(RS, RS)
	_field.position = FIELD_POS
	_field.draw.connect(_draw_field)
	add_child(_field)


func _draw_field() -> void:
	var f := _field
	var amp := 6.0 * _shake * _shake
	_shake_vec = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amp
	f.draw_set_transform(_shake_vec)
	_draw_floor(f)
	_draw_portals(f)
	_draw_splats(f)
	_draw_wall_shadows(f)
	_draw_walls(f)
	_draw_coins(f)
	_draw_traps(f)
	_draw_zombies(f)
	_draw_hero(f)
	_draw_rings(f)
	_draw_particles(f)
	_draw_floaters(f)
	f.draw_set_transform(Vector2.ZERO)
	_draw_danger(f)
	if _flash > 0.0:
		f.draw_rect(Rect2(Vector2.ZERO, ROOM), Color(BLOOD, 0.35 * _flash))
	# obj_score: "score: N" at (16,16) in the original colour, on a dim chip.
	var txt := "score: " + str(world.score)
	var fs := 18
	f.draw_rect(Rect2(10, 10, _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14, 26), Color(0, 0, 0, 0.55))
	f.draw_string(_font, Vector2(17, 16 + _font.get_ascent(fs)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SCORE_COLOR)


func _draw_floor(f: Control) -> void:
	f.draw_rect(Rect2(Vector2.ZERO, ROOM), FLOOR_A)
	var cols := int(World.W / CELL) + 1
	var rows := int(World.H / CELL) + 1
	for y in rows:
		for x in cols:
			if (x + y) % 2 == 0 and not _walls.has(Vector2i(x, y)):
				f.draw_rect(Rect2(x * CELL - 16, y * CELL - 16, CELL, CELL), FLOOR_B)
	# drifting graveyard fog (wraps with the room)
	for g in _fog:
		for off in wrap_offsets(g.p, g.r):
			for k in 4:
				f.draw_circle(g.p + off, g.r * (1.0 - k * 0.2), Color(0.55, 0.75, 0.6, 0.018))
	# lantern pool around the hero
	var h := _lerp_pos(world.hero)
	for k in 6:
		f.draw_circle(h, 170.0 - k * 26.0, Color(LANTERN, 0.022))


## Wrap doors: open seams on the room edge glow and drift particles inward.
func _draw_portals(f: Control) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	for p in _portals:
		var n: Vector2 = p.n
		var t: Vector2 = n.orthogonal()
		for e in [[p.a, n], [p.b, -n]]:
			var c: Vector2 = e[0]
			var inward: Vector2 = e[1]
			var quad := PackedVector2Array([c - t * 14, c + t * 14, c + t * 14 + inward * 18, c - t * 14 + inward * 18])
			f.draw_colored_polygon(quad, Color(PORTAL, 0.10 + 0.08 * pulse))
			f.draw_line(c - t * 14 + inward * 2, c + t * 14 + inward * 2, Color(PORTAL, 0.55 + 0.35 * pulse), 3.0)
			var dot := c + inward * (4.0 + fposmod(_time * 14.0 + c.x * 0.3 + c.y * 0.7, 16.0))
			f.draw_circle(dot, 1.8, Color(PORTAL.lightened(0.4), 0.7))


func _draw_splats(f: Control) -> void:
	for s in _splats:
		var rng := RandomNumberGenerator.new()
		rng.seed = s.seed
		var c: Vector2 = s.pos
		f.draw_circle(c, 15.0, Color(0.20, 0.42, 0.15, 0.55))
		for k in 7:
			var a: float = s.rot + k * TAU / 7.0 + rng.randf_range(-0.3, 0.3)
			f.draw_circle(c + Vector2.from_angle(a) * rng.randf_range(12, 22), rng.randf_range(3, 7), Color(0.25, 0.5, 0.18, 0.5))


func _draw_wall_shadows(f: Control) -> void:
	for c in _wall_cells:
		if not _walls.has(c + Vector2i(0, 1)) or not _walls.has(c + Vector2i(1, 0)):
			f.draw_rect(Rect2(c.x * CELL - 16 + 5, c.y * CELL - 16 + 7, CELL, CELL), Color(0, 0, 0, 0.35))


## Crypt-stone blocks: neighbouring walls merge into one mass; only the outer
## faces get the bevel and the faint moss rim.
func _draw_walls(f: Control) -> void:
	for c in _wall_cells:
		var r := Rect2(c.x * CELL - 16, c.y * CELL - 16, CELL, CELL)
		var shade := 0.92 + 0.08 * float(absi(hash(c)) % 100) / 100.0
		f.draw_rect(r, Color(STONE.r * shade, STONE.g * shade, STONE.b * shade))
	for c in _wall_cells:
		var r := Rect2(c.x * CELL - 16, c.y * CELL - 16, CELL, CELL)
		var up := not _walls.has(c + Vector2i(0, -1))
		var down := not _walls.has(c + Vector2i(0, 1))
		var left := not _walls.has(c + Vector2i(-1, 0))
		var right := not _walls.has(c + Vector2i(1, 0))
		# mortar seams between merged blocks
		if not up:
			f.draw_line(r.position + Vector2(3, 0), r.position + Vector2(CELL - 3, 0), Color(STONE_LO, 0.55), 1.0)
		if not left:
			f.draw_line(r.position + Vector2(0, 3), r.position + Vector2(0, CELL - 3), Color(STONE_LO, 0.55), 1.0)
		if up:
			f.draw_rect(Rect2(r.position, Vector2(CELL, 4)), STONE_HI)
			f.draw_line(r.position + Vector2(0, 0.5), r.position + Vector2(CELL, 0.5), Color(MOSS, 0.85), 1.5)
		if left:
			f.draw_rect(Rect2(r.position, Vector2(3, CELL)), STONE_HI.darkened(0.1))
		if down:
			f.draw_rect(Rect2(r.position + Vector2(0, CELL - 5), Vector2(CELL, 5)), STONE_LO)
		if right:
			f.draw_rect(Rect2(r.position + Vector2(CELL - 4, 0), Vector2(4, CELL)), STONE_LO.lightened(0.05))
		# moss specks
		var hsh := absi(hash(c))
		if hsh % 5 == 0:
			f.draw_circle(r.position + Vector2(6 + hsh % 19, 6 + (hsh >> 5) % 19), 2.5, Color(MOSS, 0.7))


func _draw_coins(f: Control) -> void:
	for c in world.of_kind(World.COIN):
		var p := Vector2(c.x, c.y)
		var ph: float = (c.x + c.y) * 0.045
		var w := 0.25 + 0.75 * absf(cos(_time * 3.2 + ph))
		var bob := sin(_time * 2.6 + ph) * 1.5
		var s: float = c.sx
		f.draw_circle(p, 9.0 * s, Color(GOLD, 0.10))
		f.draw_set_transform(_shake_vec + p + Vector2(0, bob), 0.0, Vector2(w, 1.0) * s)
		f.draw_circle(Vector2.ZERO, 5.0, GOLD.darkened(0.35))
		f.draw_circle(Vector2.ZERO, 4.0, GOLD)
		f.draw_circle(Vector2(-1.2, -1.2), 1.4, Color(1, 1, 0.85, 0.9))
		f.draw_set_transform(_shake_vec)


func _draw_traps(f: Control) -> void:
	for t in world.of_kind(World.TRAP):
		var p := Vector2(t.x, t.y)
		var pulse := 0.5 + 0.5 * sin(_time * 4.0 + p.x * 0.01)
		f.draw_circle(p, 17.0, Color(0.25, 0.02, 0.04, 0.85))
		f.draw_arc(p, 19.0 + 3.0 * pulse, 0, TAU, 32, Color(BLOOD, 0.35 + 0.3 * pulse), 2.0)
		var rot := _time * 1.5
		for k in 8:
			var a := rot + k * TAU / 8.0
			var d := Vector2.from_angle(a)
			f.draw_colored_polygon(PackedVector2Array([p + d * 22.0, p + d * 15.0 + d.orthogonal() * 3.0,
				p + d * 15.0 - d.orthogonal() * 3.0]), Color(BLOOD, 0.75))
		f.draw_texture_rect(TRAP_TEX, Rect2(p - Vector2(16, 16), Vector2(32, 32)), false, Color(1, 0.85 + 0.15 * pulse, 0.85 + 0.15 * pulse))


func _draw_zombies(f: Control) -> void:
	var hero := _hero()
	for z in world.of_kind(World.ZOMBIE):
		var base := _lerp_pos(z)
		var near := clampf(1.0 - hero.distance_to(Vector2(z.x, z.y)) / DANGER_RANGE, 0.0, 1.0)
		var ph := float(z.get_instance_id() % 97)
		for off in wrap_offsets(base):
			var p: Vector2 = base + off
			f.draw_set_transform(_shake_vec + p + Vector2(0, 14), 0.0, Vector2(1.0, 0.4))
			f.draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.4))
			f.draw_set_transform(_shake_vec)
			var aura := TOXIC.lerp(BLOOD, near)
			for k in 3:
				f.draw_circle(p, 22.0 - k * 4.0, Color(aura, 0.06 + 0.05 * near))
			# chase arrow: the GM direction the zombie last stepped in
			var d := Vector2(cos(deg_to_rad(z.direction)), -sin(deg_to_rad(z.direction)))
			var tip := p + d * 27.0
			f.draw_colored_polygon(PackedVector2Array([tip, p + d * 20.0 + d.orthogonal() * 5.0, p + d * 20.0 - d.orthogonal() * 5.0]),
				Color(aura, 0.75))
			var wob := sin(_time * 5.0 + ph) * 0.12
			var bob := absf(sin(_time * 5.0 + ph)) * -2.0
			f.draw_set_transform(_shake_vec + p + Vector2(0, bob), wob, Vector2.ONE)
			f.draw_texture_rect(ZOMBIE_TEX, Rect2(-16, -16, 32, 32), false, Color(0.9, 1.0, 0.9))
			f.draw_set_transform(_shake_vec)


func _draw_hero(f: Control) -> void:
	var base := _lerp_pos(world.hero)
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	var sq := Vector2(1.0 + 0.08 * sin(_time * 18.0), 1.0 - 0.08 * sin(_time * 18.0)) if _hero_moving and playing else Vector2.ONE
	for off in wrap_offsets(base):
		var p: Vector2 = base + off
		f.draw_set_transform(_shake_vec + p + Vector2(0, 14), 0.0, Vector2(1.0, 0.4))
		f.draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.45))
		f.draw_set_transform(_shake_vec)
		for k in 4:
			f.draw_circle(p, 24.0 - k * 4.0 + pulse * 2.0, Color(LANTERN, 0.07))
		f.draw_set_transform(_shake_vec + p, 0.0, sq)
		f.draw_texture_rect(HERO_TEX, Rect2(-16, -16, 32, 32), false)
		f.draw_set_transform(_shake_vec)


func _draw_rings(f: Control) -> void:
	for r in _rings:
		var t: float = 1.0 - r.life / r.max
		f.draw_arc(r.pos, 6.0 + r.r * t, 0, TAU, 40, Color(r.color, 1.0 - t), 3.0 * (1.0 - t) + 1.0)


func _draw_particles(f: Control) -> void:
	for p in _particles:
		var t: float = p.life / p.max
		f.draw_circle(p.pos, p.size * (0.4 + 0.6 * t), Color(p.color, p.color.a * t))


func _draw_floaters(f: Control) -> void:
	for fl in _floaters:
		var t: float = fl.life / fl.max
		var fs := 22
		var w := _font.get_string_size(fl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at: Vector2 = fl.pos - Vector2(w * 0.5, 0)
		f.draw_string(_font, at + Vector2(2, 2), fl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * t))
		f.draw_string(_font, at, fl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fl.color, t))


## Red vignette as the nearest zombie closes in.
func _draw_danger(f: Control) -> void:
	if not playing:
		return
	var d := nearest_zombie_distance()
	var k := clampf(1.0 - d / DANGER_RANGE, 0.0, 1.0)
	if k <= 0.0:
		return
	var a := k * (0.25 + 0.1 * sin(_time * 10.0))
	for i in 5:
		var inset := 6.0 + i * 12.0
		f.draw_rect(Rect2(Vector2.ONE * inset, ROOM - Vector2.ONE * inset * 2), Color(BLOOD, a * (1.0 - i * 0.2)), false, 12.0)


# --- gauges (coin bar, zombie pips, minimap, danger meter) -------------------

const LEFT := Rect2(16, 72, 192, 624)
const RIGHT := Rect2(1072, 72, 192, 624)
const MAP := Rect2(1088, 106, 160, 120)


func _draw_gauges() -> void:
	var g := _gauges
	# coin bar
	var left: int = world.of_kind(World.COIN).size()
	var bar := Rect2(LEFT.position.x + 16, LEFT.position.y + 138, 160, 10)
	var t := 1.0 - float(left) / maxf(_coin_total, 1)
	g.draw_rect(bar, Color(0, 0, 0, 0.5))
	g.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), GOLD)
	g.draw_rect(bar, Color(FRAME, 0.4), false, 1.0)
	# zombie pips: 6 at room start
	var zl: int = world.of_kind(World.ZOMBIE).size()
	for i in 6:
		var c := Vector2(LEFT.position.x + 28 + i * 26, LEFT.position.y + 188)
		if i < zl:
			g.draw_texture_rect(ZOMBIE_TEX, Rect2(c - Vector2(10, 10), Vector2(20, 20)), false)
		else:
			g.draw_circle(c, 8.0, Color(0.25, 0.5, 0.2, 0.5))
			g.draw_line(c - Vector2(6, 6), c + Vector2(6, 6), Color(BLOOD, 0.8), 2.0)
			g.draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), Color(BLOOD, 0.8), 2.0)
	# minimap: the whole torus
	var m := MAP
	var sc := m.size.x / World.W
	g.draw_rect(m, Color(0.02, 0.04, 0.04, 0.95))
	for c in _wall_cells:
		var p := m.position + (Vector2(c) * CELL - Vector2(16, 16)) * sc
		var r := Rect2(p, Vector2(CELL, CELL) * sc).intersection(m)
		if r.has_area():
			g.draw_rect(r, Color(STONE_HI, 0.7))
	for c in world.of_kind(World.COIN):
		g.draw_rect(Rect2(m.position + Vector2(c.x, c.y) * sc - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), Color(GOLD, 0.85))
	for tr in world.of_kind(World.TRAP):
		g.draw_circle(m.position + Vector2(tr.x, tr.y) * sc, 2.6, BLOOD)
	for z in world.of_kind(World.ZOMBIE):
		g.draw_circle(m.position + Vector2(z.x, z.y) * sc, 2.8, TOXIC)
	var hp := m.position + _hero() * sc
	g.draw_circle(hp, 4.0 + absf(sin(_time * 5.0)) * 1.5, Color(LANTERN, 0.35))
	g.draw_circle(hp, 3.0, LANTERN)
	for p in _portals:
		var n: Vector2 = p.n
		for c in [p.a, p.b]:
			var q: Vector2 = m.position + c * sc
			g.draw_line(q - n.orthogonal() * 2.0, q + n.orthogonal() * 2.0, PORTAL, 2.0)
	g.draw_rect(m, Color(FRAME, 0.5), false, 1.5)
	# danger meter
	var d := nearest_zombie_distance()
	var k := clampf(1.0 - d / DANGER_RANGE, 0.0, 1.0)
	var db := Rect2(RIGHT.position.x + 16, RIGHT.position.y + 230, 160, 12)
	g.draw_rect(db, Color(0, 0, 0, 0.5))
	g.draw_rect(Rect2(db.position, Vector2(db.size.x * k, db.size.y)), TOXIC.lerp(BLOOD, k))
	g.draw_rect(db, Color(FRAME, 0.4), false, 1.0)


# --- HUD / cards --------------------------------------------------------------

func _refresh_hud() -> void:
	var coins_left: int = world.of_kind(World.COIN).size()
	var zl: int = world.of_kind(World.ZOMBIE).size()
	_score_label.text = str(world.score)
	_coins_label.text = "%d / %d" % [_coin_total - coins_left, _coin_total]
	_zombies_label.text = "%d left · %d trapped" % [zl, _trapped]
	_traps_label.text = str(world.of_kind(World.TRAP).size())
	_caught_label.text = str(_caught)
	var secs: int = world.steps / Room0.SPEED
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	_wraps_label.text = str(_wraps)
	var d := nearest_zombie_distance()
	_danger_label.text = "nearest %d px" % int(d) if d < INF else "no zombies"
	var st := ""
	if coins_left == 0 and zl == 0:
		st = "Room cleared! No win state in\nthe original: wander the torus."
	elif coins_left == 0:
		st = "All coins taken. Getting caught\nrespawns them (score kept)."
	elif zl == 0:
		st = "Every zombie herded!\nCoins are yours."
	_status_label.text = st


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
	s.border_color = Color(FRAME, 0.4)
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

	var title := _label("TOROIDAL ZOMBIE HERDER", 30, TOXIC)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(_ui, title, Rect2(0, 6, STAGE.x, 38))
	var sub := _label("Enhanced  ·  GameMaker maze herder (2017)  ·  the maze wraps around", 14, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(_ui, sub, Rect2(0, 42, STAGE.x, 22))
	var back := _button("Back to Arcade", Color(0.18, 0.36, 0.26))
	back.position = Vector2(16, 14)
	back.pressed.connect(GameRegistry.return_to_arcade)
	_ui.add_child(back)

	# left: score + room stats
	var lp := _panel(_ui, LEFT)
	_score_label = _stat(lp, 14, "SCORE", 36, SCORE_COLOR)
	_coins_label = _stat(lp, 84, "COINS", 22, GOLD)
	_add(lp, _label("ZOMBIES", 13, MUTED), Rect2(16, 156, 160, 18))
	_zombies_label = _add(lp, _label("", 14, TOXIC, _mono), Rect2(16, 202, 170, 22)) as Label
	_traps_label = _stat(lp, 236, "TRAPS ARMED", 22, BLOOD)
	_caught_label = _stat(lp, 292, "CAUGHT", 22, BLOOD.lightened(0.25))
	_time_label = _stat(lp, 348, "TIME", 22, INK)
	_wraps_label = _stat(lp, 404, "EDGE WRAPS", 22, PORTAL.lightened(0.3))
	_status_label = _add(lp, _label("", 12, LANTERN), Rect2(16, 470, 170, 60)) as Label
	_add(lp, _label("Score survives being caught\n(GM's global score), as in\nthe original. No win state.", 11, MUTED),
			Rect2(16, 556, 170, 56))

	# right: minimap, danger, controls
	var rp := _panel(_ui, RIGHT)
	_add(rp, _label("TORUS MAP", 13, MUTED), Rect2(16, 12, 160, 18))
	_add(rp, _label("purple ticks = wrap doors", 11, Color(PORTAL.lightened(0.3), 0.9)), Rect2(16, 158, 170, 14))
	_add(rp, _label("DANGER", 13, MUTED), Rect2(16, 208, 160, 18))
	_danger_label = _add(rp, _label("", 14, INK, _mono), Rect2(16, 244, 170, 22)) as Label
	_add(rp, _label("CONTROLS", 13, MUTED), Rect2(16, 300, 160, 18))
	_add(rp, _label("Arrows / WASD  move\nHold click  nudge (as GM)\nR  new run\nEsc  pause", 13, INK),
			Rect2(16, 320, 170, 84))
	_add(rp, _label("HOW TO PLAY", 13, MUTED), Rect2(16, 420, 160, 18))
	_add(rp, _label("Grab coins (+10). Zombies\nshamble after you: lure\nthem onto the red traps.\nIf one touches you, the\nroom restarts. Walk off an\nedge to come back on the\nopposite side.", 11, MUTED),
			Rect2(16, 440, 170, 130))
	_add(rp, _label("Same rules as Direct.", 11, Color(FRAME, 0.9)), Rect2(16, 588, 170, 16))

	_gauges = Control.new()
	_gauges.name = "Gauges"
	_gauges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauges.size = STAGE
	_gauges.draw.connect(_draw_gauges)
	_ui.add_child(_gauges)

	_banner = _label("", 18, INK)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.visible = false
	_add(_ui, _banner, Rect2(FIELD_POS.x, FIELD_POS.y + FIELD.y - 40, FIELD.x, 28))

	# title card
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_ui, holder, Rect2(Vector2.ZERO, STAGE))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(holder, cc, Rect2(FIELD_POS, FIELD))
	var pc := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.04, 0.07, 0.06, 0.94)
	ts.border_color = TOXIC
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(18)
	ts.shadow_color = Color(TOXIC, 0.18)
	ts.shadow_size = 18
	ts.set_content_margin_all(28)
	pc.add_theme_stylebox_override("panel", ts)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	for row in [["TOROIDAL ZOMBIE HERDER", 40, TOXIC], ["Enhanced edition", 18, LANTERN],
			["Collect coins and herd the shambling zombies onto traps.\nThe maze is a torus: leave one edge, enter the opposite one.\nGet caught and the room restarts (your score stays).", 15, MUTED],
			["Press Space or click Start", 18, GOLD]]:
		var l := _label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	var start_btn := _button("Start", Color(0.2, 0.45, 0.22), 20)
	start_btn.name = "StartButton"
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(start)
	vb.add_child(start_btn)
	_cards["title"] = holder
