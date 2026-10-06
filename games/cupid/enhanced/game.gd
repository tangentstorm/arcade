extends Node2D
## Cupid (Enhanced). Presentation makeover of the Direct matchmaking game.
## Rules (cupid flight, arrows, walkers, symbols, matching, storm, win) are
## Direct's cupid_logic.gd, preloaded and stepped at the same fixed 90 Hz with
## the same inputs. This file owns the 1280x720 letterbox shell: a duotone city
## that warms from storm to sunset as the Direct storm loses clouds, tinted
## walkers, crisp thought bubbles, a drop guide under the bow, match / no-match
## juice, a street radar, a couples HUD and restyled title / win cards.
## Esc is handled by the PauseOverlay autoload. No Alchementrix IP.

const Logic := preload("res://games/cupid/direct/cupid_logic.gd")
const DIR := "res://games/cupid/direct/"
const CUPID := preload(DIR + "sprites/cupid.png")
const ARROW := preload(DIR + "sprites/arrow.png")
const PEOPLE := preload(DIR + "sprites/pixel-people-standins-gray.png")
const SYMBOLS := preload(DIR + "sprites/symbols.png")
const GOOD_ICON := preload(DIR + "sprites/HEART-Symbol-animated.png")
const BAD_ICON := preload(DIR + "sprites/heart-breaking.png")
const RAIN := preload(DIR + "sprites/heavy-rain.png")
const CURSOR := preload(DIR + "sprites/crosshair-heart-1.png")
const BG := [
	preload(DIR + "sprites/bg-00.png"), preload(DIR + "sprites/bg-01.png"),
	preload(DIR + "sprites/bg-02.png"), preload(DIR + "sprites/bg-03.png"),
	preload(DIR + "sprites/bg-04.png"),
]
const RAIN_LOOP := preload(DIR + "audio/rain.mp3")

const STAGE := Vector2(1280, 720)
const W := Logic.STAGE_W
const H := Logic.STAGE_H
const PX := 1.75  ## 656x350 Flash stage -> 1148x612 field
const FIELD := Vector2(W, H) * PX
const FIELD_POS := Vector2(66, 62)
const STRIP := Rect2(66, 682, 1148, 32)
const BEST_PATH := "user://cupid_enhanced.cfg"
const SUN_X_Y := Vector2(520, 70)  ## where the sun settles once the storm is gone

# --- palette -----------------------------------------------------------------
const BG_TOP := Color("#140f22")
const BG_BOTTOM := Color("#24162e")
const PANEL := Color(0.10, 0.07, 0.15, 0.92)
const FRAME := Color("#ff7aa8")
const INK := Color("#fff3ea")
const MUTED := Color("#b9a6c4")
const PINK := Color("#ff6f9f")
const ROSE := Color("#ffb3c9")
const GOLD := Color("#ffd27a")
const SKYBLUE := Color("#9fc4ff")
const SLATE := Color("#7d8299")
const PLUM := Color("#3b1f4d")

## Storm (no couples yet) -> clear sunset (Direct storm out of clouds).
const SKY_STORM := {"top": Color("#1f2539"), "bottom": Color("#465068"),
		"cdark": Color("#353c52"), "clight": Color("#8d97ae"), "camt": 0.92}
const SKY_CLEAR := {"top": Color("#5a3f99"), "bottom": Color("#ffbf80"),
		"cdark": Color("#c97a9c"), "clight": Color("#ffe6cf"), "camt": 0.28}
## Skyline layers bg-01..bg-04, far -> near: [shadow, light].
const LAYER_STORM := [
	[Color("#1b2134"), Color("#3a4560")], [Color("#161b2b"), Color("#4b5672")],
	[Color("#12161f"), Color("#69728c")], [Color("#0f121a"), Color("#a3abbf")],
]
const LAYER_CLEAR := [
	[Color("#5a3470"), Color("#c287b5")], [Color("#47285a"), Color("#d99ab4")],
	[Color("#3a2042"), Color("#f2bfc0")], [Color("#33203a"), Color("#fff0e0")],
]
const LAYER_FOG := [0.42, 0.26, 0.12, 0.0]
## One soft tint per walker sprite (people sheet frame i), so they read apart.
const PERSON_TINTS := [
	Color("#ffb3c7"), Color("#a8d8ff"), Color("#c9f2a5"), Color("#ffe0a3"), Color("#d9b8ff"),
	Color("#9ff0e0"), Color("#ffc8a8"), Color("#bfc8ff"), Color("#f5f0a0"), Color("#ffb0e8"),
]

const DUOTONE := """
shader_type canvas_item;
uniform vec4 shadow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 light : source_color = vec4(1.0);
uniform vec4 fog : source_color = vec4(0.5);
uniform float fog_amt = 0.0;
uniform float gamma = 1.0;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = pow(dot(t.rgb, vec3(0.299, 0.587, 0.114)), gamma);
	vec3 c = mix(shadow.rgb, light.rgb, l);
	c = mix(c, fog.rgb, fog_amt);
	COLOR = vec4(c * vcol.rgb, t.a * vcol.a);
}
"""

const SKY_SHADER := """
shader_type canvas_item;
uniform vec4 top : source_color;
uniform vec4 bottom : source_color;
uniform vec4 cloud_dark : source_color;
uniform vec4 cloud_light : source_color;
uniform float cloud_amt = 1.0;
uniform vec2 sun_pos = vec2(470.0, 300.0);
uniform float sun_amt = 0.0;
uniform vec4 sun_col : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform float flash = 0.0;
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float gy = clamp(local.y / 350.0, 0.0, 1.0);
	vec3 sky = mix(top.rgb, bottom.rgb, gy);
	float d = distance(local, sun_pos);
	sky += sun_col.rgb * sun_amt * (0.85 * exp(-d * d / 4200.0) + 0.35 * exp(-d * d / 52000.0));
	sky = mix(sky, vec3(1.0, 0.97, 0.88), sun_amt * smoothstep(30.0, 26.0, d));
	float l = t.r;
	vec3 cl = mix(cloud_dark.rgb, cloud_light.rgb, smoothstep(0.26, 0.46, l));
	float ca = cloud_amt * (0.6 + 0.4 * smoothstep(0.28, 0.44, l));
	vec3 c = mix(sky, cl, ca) + vec3(flash);
	COLOR = vec4(c, 1.0);
}
"""

var world = Logic.new(Logic.TITLE)
var _acc := 0.0
var _time := 0.0
var _clear := 0.0  ## displayed sky clearing 0..1, eases toward the Direct storm
var _click := false
var _start := false
var _next := false
var _fx_rng := RandomNumberGenerator.new()  ## juice only; never touches world.rng
var _particles: Array[Dictionary] = []  ## world coords (x along the street, y on stage)
var _floaters: Array[Dictionary] = []   ## world coords; drawn in screen space
var _ghosts: Array[Dictionary] = []     ## matched couples dissolving upward
var _pops := {}                         ## Person -> seconds since its bubble appeared
var _arrow_trail: Array[Vector2] = []
var _icon_t := {"good": -1.0, "bad": -1.0}
var _heart_pop := 0.0
var _lightning := 0.0
var _next_bolt := 5.0
var _shake := 0.0
var _arrows := 0
var _misses := 0
var _won_time := 0.0
var _best := 0.0
var _new_best := false
var _prev := {}

var _field: Control
var _sky: Node2D
var _layers: Array[Node2D] = []
var _actors: Node2D
var _glow: Node2D
var _walkers: Node2D
var _over: Node2D
var _fx: Node2D
var _sky_mat: ShaderMaterial
var _layer_mats: Array[ShaderMaterial] = []
var _walker_mat: ShaderMaterial

var _ui: CanvasLayer
var _cards := {}
var _hearts: Control
var _radar: Control
var _time_label: Label
var _arrows_label: Label
var _sky_label: Label
var _best_label: Label
var _win_detail: Label
var _win_best: Label
var _title_cupid: TextureRect
var _font: Font
var _panel_style := StyleBoxFlat.new()

var _rain: AudioStreamPlayer
var _sfx := {}


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_fx_rng.randomize()
	_load_best()
	_build_stage()
	_build_ui()
	_build_audio()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_snap_prev()
	_refresh_hud()
	_show_card("title" if world.state == Logic.TITLE else "")


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	# The heart crosshair replaces the OS cursor only while play is live,
	# so the PauseOverlay buttons stay clickable.
	if what == NOTIFICATION_PAUSED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5


# --- loop ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_start = true
		elif event.keycode == KEY_N:
			_next = true


func stage_mouse() -> Vector2:
	return (get_local_mouse_position() - FIELD_POS) / PX


func _process(delta: float) -> void:
	_time += delta
	_acc = minf(_acc + delta, 0.25)
	var m := stage_mouse()
	while _acc >= Logic.DT:
		_acc -= Logic.DT
		world.step({"stage_x": m.x, "stage_y": m.y, "click": _click, "start": _start, "next_level": _next})
		_click = false
		_start = false
		_next = false
		_on_world_step()
	_animate(delta)
	_update_audio()
	_update_cursor(m)
	_refresh_hud()
	_redraw()


func _redraw() -> void:
	queue_redraw()
	_sky.queue_redraw()
	for l in _layers:
		l.queue_redraw()
	_glow.queue_redraw()
	_actors.queue_redraw()
	_walkers.queue_redraw()
	_over.queue_redraw()
	_fx.queue_redraw()
	_hearts.queue_redraw()
	_radar.queue_redraw()


func _update_cursor(m: Vector2) -> void:
	var inside := m.x >= 0 and m.y >= 0 and m.x < W and m.y < H
	var want := Input.MOUSE_MODE_HIDDEN if (world.state == Logic.PLAY and inside) else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


# --- juice from Direct state deltas (read-only) ---------------------------------

func _snap_prev() -> void:
	var marked: Array[bool] = []
	var exists: Array[bool] = []
	for p in world.people:
		marked.append(p.marked)
		exists.append(p.exists)
	_prev = {
		"wid": world.get_instance_id(), "state": world.state, "f": world.f,
		"arrow": world.arrow_exists, "ax": world.ax, "ay": world.ay,
		"marked": marked, "exists": exists, "timers": world.timers.duplicate(),
		"clouds": world.clouds_left, "couples": world.couples_left,
	}


func _on_world_step() -> void:
	var started: bool = world.state == Logic.PLAY and int(_prev.get("state", -1)) != Logic.PLAY
	if started or world.get_instance_id() != int(_prev.get("wid", 0)) or world.f < int(_prev.get("f", 0)) \
			or world.people.size() != (_prev.marked as Array).size():
		if started:
			_begin_play()
		_snap_prev()
		return

	var events := 0
	# Arrow fired (also catches a re-fire in the same frame the old one landed).
	var refired: bool = world.arrow_exists and bool(_prev.arrow) and world.ay < float(_prev.ay)
	if world.arrow_exists and (not bool(_prev.arrow) or refired):
		_arrows += 1
		_arrow_trail.clear()
		_play("shoot")
		_burst(Vector2(world.ax + 3, world.ay), ROSE, 6, 40.0, 0.0)

	# New marks: bubble pops in over a stopped walker.
	for i in world.people.size():
		var p = world.people[i]
		if p.marked and not bool(_prev.marked[i]):
			events += 1
			_pops[p] = 0.0
			_burst(Vector2(p.x + 50, p.y + 10), PINK, 14, 70.0, 30.0)
			_play("pop")
			if world.last_hit == p:
				_float(Vector2(p.mark_x + 50, p.y - 64), "1 of 2", ROSE)

	# A second hit opened a Direct match timer: MATCH or NO MATCH.
	for t in world.timers:
		var known := false
		for o in _prev.timers:
			if is_same(o, t):
				known = true
		if known:
			continue
		events += 1
		var mid := Vector2((t.p1.x + t.p2.x) * 0.5 + 50, t.p1.y - 70)
		if t.good:
			_icon_t.good = 0.0
			_float(mid, "MATCH!", GOLD, 30)
			for q in [t.p1, t.p2]:
				_hearts_burst(Vector2(q.x + 50, q.y + 20), 12)
			_shake = 0.35
			_play("match")
		else:
			_icon_t.bad = 0.0
			_float(mid, "no match", SLATE, 22)
			for q in [t.p1, t.p2]:
				_burst(Vector2(q.x + 50, q.y - 20), SLATE, 10, 60.0, 120.0)
			_play("nomatch")

	# Arrow gone without a new mark or timer: it hit the street (or a stopped walker).
	var ended: bool = bool(_prev.arrow) and (not world.arrow_exists or refired)
	if ended and events == 0:
		_misses += 1
		var at := Vector2(float(_prev.ax) + 3, minf(float(_prev.ay) + 26, H - 4))
		_burst(at, SKYBLUE, 10, 50.0, 160.0)
		_play("miss")

	# Matched couples dissolve (Direct sets exists = false after its 1.5 s timer).
	for i in world.people.size():
		var p = world.people[i]
		if bool(_prev.exists[i]) and not p.exists:
			_ghosts.append({"x": p.x, "y": p.y, "image": p.image, "right": p.right, "life": 1.4})
			_hearts_burst(Vector2(p.x + 50, p.y + 30), 8)
			_pops.erase(p)
	if world.couples_left < int(_prev.couples):
		_heart_pop = 1.0
		_play("couple")

	if world.state == Logic.WON and int(_prev.state) != Logic.WON:
		_on_win()

	if world.arrow_exists:
		_arrow_trail.append(Vector2(world.ax + 3, world.ay))
		if _arrow_trail.size() > 10:
			_arrow_trail.pop_front()
	elif not _arrow_trail.is_empty():
		_arrow_trail.pop_front()
	_snap_prev()


func _begin_play() -> void:
	_particles.clear()
	_floaters.clear()
	_ghosts.clear()
	_pops.clear()
	_arrow_trail.clear()
	_icon_t = {"good": -1.0, "bad": -1.0}
	_arrows = 0
	_misses = 0
	_new_best = false
	_show_card("")


func _on_win() -> void:
	_won_time = float(world.f) / Logic.FPS
	_new_best = _best <= 0.0 or _won_time < _best
	if _new_best:
		_best = _won_time
		_save_best()
	for i in 40:
		_particles.append({
			"pos": Vector2(-world.scroll_x + _fx_rng.randf() * W, -10 - _fx_rng.randf() * 120),
			"vel": Vector2(_fx_rng.randf_range(-15, 15), _fx_rng.randf_range(30, 70)),
			"life": 4.0, "max": 4.0, "color": [PINK, ROSE, GOLD][i % 3],
			"size": _fx_rng.randf_range(4, 7), "grav": 0.0, "heart": true,
		})
	_play("win")
	_show_win()


func _animate(delta: float) -> void:
	var target := clampf(float(Logic.NUM_COUPLES - world.clouds_left) / Logic.NUM_COUPLES, 0.0, 1.0)
	if world.state == Logic.TITLE:
		target = 0.0
	_clear = move_toward(_clear, target, delta * 0.4)
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	_heart_pop = move_toward(_heart_pop, 0.0, delta * 2.0)
	_lightning = move_toward(_lightning, 0.0, delta * 3.0)
	if world.state != Logic.WON and _clear < 0.45:
		_next_bolt -= delta
		if _next_bolt <= 0.0:
			_lightning = 1.0
			_next_bolt = _fx_rng.randf_range(6.0, 12.0)
	for k in _icon_t:
		if _icon_t[k] >= 0.0:
			_icon_t[k] += delta
			if _icon_t[k] > 1.6:
				_icon_t[k] = -1.0
	for p in _pops:
		_pops[p] += delta
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel.y += float(p.grav) * delta
		p.vel *= 0.985
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 22.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	for g in _ghosts:
		g.life -= delta
		g.y -= 26.0 * delta
	_ghosts = _ghosts.filter(func(g): return g.life > 0.0)


func _burst(at: Vector2, color: Color, n: int, speed: float, grav: float) -> void:
	for i in n:
		var a := _fx_rng.randf() * TAU
		var sp := _fx_rng.randf_range(speed * 0.3, speed)
		_particles.append({
			"pos": at, "vel": Vector2(cos(a), sin(a)) * sp, "life": _fx_rng.randf_range(0.35, 0.8),
			"max": 0.8, "color": color, "size": _fx_rng.randf_range(1.0, 2.4), "grav": grav, "heart": false,
		})


func _hearts_burst(at: Vector2, n: int) -> void:
	for i in n:
		_particles.append({
			"pos": at + Vector2(_fx_rng.randf_range(-20, 20), _fx_rng.randf_range(-10, 10)),
			"vel": Vector2(_fx_rng.randf_range(-30, 30), _fx_rng.randf_range(-70, -30)),
			"life": _fx_rng.randf_range(0.9, 1.5), "max": 1.5, "color": [PINK, ROSE, GOLD][i % 3],
			"size": _fx_rng.randf_range(3.0, 6.0), "grav": -10.0, "heart": true,
		})


func _float(at: Vector2, text: String, color: Color, size := 20) -> void:
	_floaters.append({"pos": at, "life": 1.3, "max": 1.3, "text": text, "color": color, "size": size})


# --- stage nodes ---------------------------------------------------------------

func _layer_node(parent: Node, draw_fn: Callable, mat: Material = null) -> Node2D:
	var n := Node2D.new()
	n.material = mat
	n.draw.connect(draw_fn.bind(n))
	parent.add_child(n)
	return n


func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_stage() -> void:
	_field = Control.new()
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_field.position = FIELD_POS
	_field.size = Vector2(W, H)
	_field.scale = Vector2(PX, PX)
	add_child(_field)
	_sky_mat = _shader(SKY_SHADER)
	_sky = _layer_node(_field, _draw_sky, _sky_mat)
	var duo := Shader.new()
	duo.code = DUOTONE
	for i in 4:
		var m := ShaderMaterial.new()
		m.shader = duo
		_layer_mats.append(m)
		_layers.append(_layer_node(_field, _draw_layer.bind(i + 1), m))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = _layer_node(_field, _draw_glow, add)
	_field.move_child(_glow, 3)  # sky, far, mid-far, [sun glow], mid-near, near
	_actors = _layer_node(_field, _draw_actors)
	_walker_mat = ShaderMaterial.new()
	_walker_mat.shader = duo
	_walker_mat.set_shader_parameter("shadow", Color("#1d1830"))
	_walker_mat.set_shader_parameter("light", Color("#fff6ec"))
	_walkers = _layer_node(_field, _draw_walkers, _walker_mat)
	_over = _layer_node(_field, _draw_over)
	_fx = _layer_node(self, _draw_fx)
	_update_palette()


func _update_palette() -> void:
	var c := _clear
	_sky_mat.set_shader_parameter("top", SKY_STORM.top.lerp(SKY_CLEAR.top, c))
	_sky_mat.set_shader_parameter("bottom", SKY_STORM.bottom.lerp(SKY_CLEAR.bottom, c))
	_sky_mat.set_shader_parameter("cloud_dark", SKY_STORM.cdark.lerp(SKY_CLEAR.cdark, c))
	_sky_mat.set_shader_parameter("cloud_light", SKY_STORM.clight.lerp(SKY_CLEAR.clight, c))
	_sky_mat.set_shader_parameter("cloud_amt", lerpf(SKY_STORM.camt, SKY_CLEAR.camt, c))
	_sky_mat.set_shader_parameter("sun_amt", smoothstep(0.15, 1.0, c))
	_sky_mat.set_shader_parameter("sun_pos", SUN_X_Y + Vector2(0, lerpf(170, 0, c)))
	_sky_mat.set_shader_parameter("flash", _lightning * 0.35)
	var fog: Color = SKY_STORM.bottom.lerp(SKY_CLEAR.bottom, c)
	for i in 4:
		var m := _layer_mats[i]
		m.set_shader_parameter("shadow", LAYER_STORM[i][0].lerp(LAYER_CLEAR[i][0], c))
		m.set_shader_parameter("light", LAYER_STORM[i][1].lerp(LAYER_CLEAR[i][1], c))
		m.set_shader_parameter("fog", fog)
		m.set_shader_parameter("fog_amt", LAYER_FOG[i])
		m.set_shader_parameter("gamma", lerpf(1.0, 0.8, c))


## Camera x used for drawing: Direct's scroll in play; a slow pan behind the title.
func _scroll() -> float:
	if world.state == Logic.TITLE:
		return -(0.5 - 0.5 * cos(_time * 0.06)) * float(Logic.GAME_W - W)
	return world.scroll_x


func _scr(x: float, y: float, sf := 1.0) -> Vector2:
	return Vector2(floorf(x) + floorf(_scroll() * sf), floorf(y))


func _frame(n: CanvasItem, tex: Texture2D, frame: int, fw: int, fh: int, at: Vector2,
		flip := false, mod := Color.WHITE) -> void:
	var src := Rect2(frame * fw, 0, fw, fh)
	var dst := Rect2(at, Vector2(fw, fh))
	if flip:
		dst = Rect2(at + Vector2(fw, 0), Vector2(-fw, fh))
	n.draw_texture_rect_region(tex, dst, src, mod)


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	_update_palette()
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(STAGE.x, 0), STAGE, Vector2(0, STAGE.y)])
	draw_polygon(pts, PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var fr := Rect2(FIELD_POS, FIELD)
	draw_rect(fr.grow(7), Color(0.03, 0.02, 0.05))
	draw_rect(fr.grow(5), Color(FRAME, 0.28 + 0.5 * _heart_pop), false, 2.0)


func _draw_sky(n: Node2D) -> void:
	n.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * _shake * _shake
	n.draw_texture(BG[0], Vector2.ZERO)


func _draw_layer(n: Node2D, i: int) -> void:
	n.position = _sky.position
	n.draw_texture(BG[i], Vector2(floorf(_scroll() * Logic.BG_SCROLL[i]), 0))


## Warm light that bleeds over the far skyline as the sun comes out (additive).
func _draw_glow(n: Node2D) -> void:
	n.position = _sky.position
	var amt := smoothstep(0.15, 1.0, _clear)
	if amt <= 0.0:
		return
	var at := SUN_X_Y + Vector2(0, lerpf(170, 0, _clear))
	for k in 10:
		n.draw_circle(at, 230.0 - k * 20.0, Color(1.0, 0.62, 0.38, 0.018 * amt))


func _draw_actors(n: Node2D) -> void:
	n.position = _sky.position
	if world.state == Logic.TITLE:
		return
	# Selection rings at the feet of stopped walkers.
	for p in world.people:
		if not p.exists or not p.marked:
			continue
		var c := _mark_color(p)
		var at := _scr(p.mark_x + 50, p.y + 95)
		var r := 30.0 + 3.0 * sin(_time * 6.0)
		n.draw_set_transform(at, 0.0, Vector2(1.0, 0.28))
		n.draw_circle(Vector2.ZERO, r, Color(c, 0.22))
		n.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(c, 0.85), 4.0)
		n.draw_set_transform(Vector2.ZERO)
	# Cupid with a soft rosy halo.
	var cp := _scr(world.cx, world.cy)
	var center := cp + Vector2(Logic.CUPID_W, Logic.CUPID_H) * 0.5
	for k in 8:
		n.draw_circle(center, 36.0 - k * 3.5, Color(1.0, 0.78, 0.88, 0.025))
	_frame(n, CUPID, world.cupid_anim.caf, Logic.CUPID_W, Logic.CUPID_H, cp, not world.c_right)


func _draw_walkers(n: Node2D) -> void:
	n.position = _sky.position
	for g in _ghosts:
		var a := clampf(g.life / 1.4, 0.0, 1.0)
		var at := _scr(g.x, g.y)
		_frame(n, PEOPLE, g.image, Logic.PERSON_W, Logic.PERSON_H, at, not g.right,
				Color(1.4, 1.0, 1.2, a * a))
	for p in world.people:
		if not p.exists:
			continue
		var at := _scr(p.x, p.y)
		if at.x > W or at.x + Logic.PERSON_W < 0:
			continue
		var mod: Color = PERSON_TINTS[p.image % PERSON_TINTS.size()]
		if p.marked:
			mod = mod.lerp(Color(1.3, 1.15, 1.25), 0.6)
		_frame(n, PEOPLE, p.image, Logic.PERSON_W, Logic.PERSON_H, at, not p.right, mod)


func _mark_color(p) -> Color:
	for t in world.timers:
		if t.p1 == p or t.p2 == p:
			return GOLD if t.good else SLATE
	return PINK


func _draw_over(n: Node2D) -> void:
	n.position = _sky.position
	if world.state == Logic.TITLE:
		_draw_rain(n)
		return
	_draw_drop_guide(n)
	# Thought bubbles: crisp card + tail, symbol from the Direct sheet, pop-in.
	for p in world.people:
		if not p.exists or not p.marked:
			continue
		var c := _mark_color(p)
		var t: float = _pops.get(p, 1.0)
		var s := 1.0 - exp(-t * 12.0) * cos(t * 22.0) if t < 0.8 else 1.0
		var base := _scr(p.mark_x, p.y - Logic.BUBBLE_HEIGHT)
		var pivot := base + Vector2(32, 40)
		n.draw_set_transform(pivot, 0.0, Vector2(s, s))
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 0.98, 0.96, 0.96)
		box.border_color = c
		box.set_border_width_all(2)
		box.set_corner_radius_all(9)
		n.draw_style_box(box, Rect2(Vector2(-29, -40), Vector2(58, 38)))
		n.draw_circle(Vector2(2, 5), 5.0, Color(1, 0.98, 0.96, 0.95))
		n.draw_arc(Vector2(2, 5), 5.0, 0, TAU, 20, c, 1.5)
		n.draw_circle(Vector2(8, 13), 2.5, Color(1, 0.98, 0.96, 0.95))
		_frame(n, SYMBOLS, p.symbol, 30, 30, Vector2(-15, -36), false, PLUM)
		n.draw_set_transform(Vector2.ZERO)
	# Arrow with a rosy trail and a bright tip.
	var ox := floorf(_scroll())
	for i in _arrow_trail.size():
		var k := float(i + 1) / float(_arrow_trail.size())
		var q := _arrow_trail[i] + Vector2(ox, 0)
		n.draw_rect(Rect2(q.x - 1.5 * k, q.y, 3.0 * k, 10), Color(1.0, 0.55, 0.75, 0.35 * k))
	if world.arrow_exists:
		var ap := _scr(world.ax, world.ay)
		n.draw_texture(ARROW, ap)
		n.draw_circle(ap + Vector2(3, Logic.ARROW_H - 2), 3.5, Color(1.0, 0.9, 0.6, 0.5))
	_draw_rain(n)
	for p in _particles:
		var a := clampf(p.life / maxf(float(p.max), 0.001), 0.0, 1.0)
		var at: Vector2 = p.pos + Vector2(ox, 0)
		var col: Color = p.color
		col.a = a
		if p.heart:
			n.draw_colored_polygon(_heart_pts(at, float(p.size)), col)
		else:
			n.draw_circle(at, float(p.size) * (0.5 + 0.5 * a), col)
	# Match icons (Direct's HUD hearts), 2x at stage centre, fading after they play.
	for k in ["good", "bad"]:
		var t2: float = _icon_t[k]
		if t2 < 0.0:
			continue
		var icon = world.good_icon if k == "good" else world.bad_icon
		var a2 := clampf((1.6 - t2) / 0.5, 0.0, 1.0)
		var sz := 80.0
		var at2 := Vector2((W - sz) * 0.5, (H - sz) * 0.5 - 40)
		n.draw_texture_rect_region(GOOD_ICON if k == "good" else BAD_ICON,
				Rect2(at2, Vector2(sz, sz)), Rect2(icon.anim.caf * 40, 0, 40, 40), Color(1, 1, 1, a2))
	if _lightning > 0.0:
		n.draw_rect(Rect2(0, 0, W, H), Color(0.85, 0.9, 1.0, _lightning * 0.18))


func _draw_rain(n: Node2D) -> void:
	var rx: float = floorf(_scroll() * Logic.RAIN_SCROLL_FACTOR)
	var rs := Logic.RAIN_SIZE
	var col := Color(0.78, 0.86, 1.0, lerpf(0.6, 0.35, _clear))
	for i in world.rain_alive.size():
		if world.rain_alive[i] == 0:
			continue
		var px: float = floorf(world.rain_x[i]) + rx
		if px > W or px + rs < 0:
			continue
		n.draw_texture_rect_region(RAIN, Rect2(px, floorf(world.rain_y[i]), rs, rs),
				Rect2(world.rain_frame[i] * rs, 0, rs, rs), col)


## Where the next arrow will fall: straight down from the bow (Direct ignores
## the click position). Dim when Direct won't fire (arrow in flight / icon up).
func _draw_drop_guide(n: Node2D) -> void:
	if world.state != Logic.PLAY:
		return
	var ready: bool = not world.arrow_exists and not world.icon_showing
	var bx: float = world.cx + Logic.ARROW_START_XOFF if world.c_right else world.cx + Logic.CUPID_W - Logic.ARROW_START_XOFF
	var top := _scr(int(bx) + Logic.ARROW_W * 0.5, world.cy + Logic.ARROW_START_YOFF + Logic.ARROW_H)
	var bottom := Vector2(top.x, H - 6)
	var col := Color(1.0, 0.55, 0.75, 0.55) if ready else Color(0.7, 0.72, 0.8, 0.18)
	n.draw_dashed_line(top, bottom, col, 1.5, 6.0)
	n.draw_set_transform(bottom, 0.0, Vector2(1.0, 0.35))
	n.draw_arc(Vector2.ZERO, 9.0, 0, TAU, 24, col, 2.0)
	n.draw_set_transform(Vector2.ZERO)


func _heart_pts(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y) * s / 16.0)
	return pts


func _to_screen(p: Vector2) -> Vector2:
	return FIELD_POS + Vector2(p.x + floorf(_scroll()), p.y) * PX


func _draw_fx(n: Node2D) -> void:
	for f in _floaters:
		var a := clampf(f.life / maxf(float(f.max), 0.001), 0.0, 1.0)
		var fs: int = f.size
		var at := _to_screen(f.pos)
		var wdt := _font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		at.x -= wdt * 0.5
		var col: Color = f.color
		col.a = a
		n.draw_string_outline(_font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.1, 0.04, 0.12, a * 0.8))
		n.draw_string(_font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Pending first pick: a pill naming the symbol you need a second of.
	if world.state == Logic.PLAY and world.last_hit != null:
		var txt := "Find the other"
		var fs2 := 18
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var pw := tw + 66.0
		var pr := Rect2(FIELD_POS.x + (FIELD.x - pw) * 0.5, FIELD_POS.y + 12, pw, 38)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 0.97, 0.94, 0.94)
		box.border_color = PINK
		box.set_border_width_all(2)
		box.set_corner_radius_all(19)
		n.draw_style_box(box, pr)
		n.draw_string(_font, pr.position + Vector2(16, 25), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, PLUM)
		n.draw_texture_rect_region(SYMBOLS, Rect2(pr.position + Vector2(tw + 22, 4), Vector2(30, 30)),
				Rect2(world.last_hit.symbol * 30, 0, 30, 30), PLUM)
	# Heart crosshair, centred on the mouse while it's over the field.
	if world.state == Logic.PLAY:
		var m := stage_mouse()
		if m.x >= 0 and m.y >= 0 and m.x < W and m.y < H:
			var sp := FIELD_POS + m * PX
			n.draw_texture_rect(CURSOR, Rect2(sp - Vector2(22, 22), Vector2(44, 44)), false)


# --- HUD / cards ---------------------------------------------------------------

func _refresh_hud() -> void:
	if _time_label == null:
		return
	var secs: int = int(_won_time) if world.state == Logic.WON else world.f / Logic.FPS
	if world.state == Logic.TITLE:
		secs = 0
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	_arrows_label.text = str(_arrows)
	_sky_label.text = "%d%% clear" % int(round(_clear * 100.0))
	_best_label.text = _fmt_time(_best) if _best > 0.0 else "-"
	if _title_cupid != null and _cards.get("title") and _cards.title.visible:
		var at := _title_cupid.texture as AtlasTexture
		at.region = Rect2((int(_time * 12.0) % 10) * Logic.CUPID_W, 0, Logic.CUPID_W, Logic.CUPID_H)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


func _draw_hearts(n: Control) -> void:
	var made: int = Logic.NUM_COUPLES - world.couples_left if world.state != Logic.TITLE else 0
	for i in Logic.NUM_COUPLES:
		var at := Vector2(i * 38.0, 2)
		var filled := i < made
		var s := 1.0
		if filled and i == made - 1:
			s = 1.0 + 0.35 * _heart_pop
		var sz := 34.0 * s
		var r := Rect2(at + Vector2(17, 17) - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
		var mod := Color.WHITE if filled else Color(0.35, 0.28, 0.42, 0.75)
		n.draw_texture_rect_region(GOOD_ICON, r, Rect2(0, 0, 40, 40), mod)


func _draw_radar(n: Control) -> void:
	var sz := n.size
	var sf := sz.x / Logic.GAME_W
	n.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.03, 0.08, 0.9))
	n.draw_line(Vector2(0, sz.y - 5), Vector2(sz.x, sz.y - 5), Color(MUTED, 0.35), 1.0)
	if world.state == Logic.TITLE:
		n.draw_rect(Rect2(Vector2.ZERO, sz), Color(FRAME, 0.35), false, 1.0)
		return
	var cam: float = -world.scroll_x * sf
	n.draw_rect(Rect2(cam, 1, W * sf, sz.y - 2), Color(FRAME, 0.12))
	n.draw_rect(Rect2(cam, 1, W * sf, sz.y - 2), Color(FRAME, 0.6), false, 1.0)
	for p in world.people:
		if not p.exists:
			continue
		var x: float = (p.x + 50) * sf
		var col: Color = PERSON_TINTS[p.image % PERSON_TINTS.size()]
		if p.marked:
			n.draw_circle(Vector2(x, sz.y - 11), 6.0, Color(_mark_color(p), 0.85))
		n.draw_rect(Rect2(x - 2, sz.y - 16, 4, 10), col)
	var cx: float = (world.cx + Logic.CUPID_W * 0.5) * sf
	n.draw_colored_polygon(_heart_pts(Vector2(cx, 9), 6.0), PINK)
	n.draw_rect(Rect2(Vector2.ZERO, sz), Color(FRAME, 0.35), false, 1.0)


func _show_card(key: String) -> void:
	for k in _cards:
		_cards[k].visible = (k == key and key != "")


func _show_win() -> void:
	_win_detail.text = "time %s  |  arrows %d  |  misses %d" % [_fmt_time(_won_time), _arrows, _misses]
	_win_best.text = "NEW BEST TIME!" if _new_best else "best %s" % _fmt_time(_best)
	_win_best.add_theme_color_override("font_color", GOLD if _new_best else MUTED)
	_show_card("win")


func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(BEST_PATH) == OK:
		_best = float(cf.get_value("best", "time", 0.0))


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("best", "time", _best)
	cf.save(BEST_PATH)


func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
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
		s.content_margin_top = 5
		s.content_margin_bottom = 7
		b.add_theme_stylebox_override(st, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


func _add(parent: Control, c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	parent.add_child(c)
	return c


func _centered(text: String, size: int, color: Color) -> Label:
	var l := _label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _card(root: Control, key: String, border: Color) -> VBoxContainer:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	_add(root, holder, Rect2(Vector2.ZERO, STAGE))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(holder, cc, Rect2(FIELD_POS, FIELD))
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.06, 0.15, 0.93)
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(20)
	st.shadow_color = Color(border, 0.28)
	st.shadow_size = 18
	st.set_content_margin_all(30)
	pc.add_theme_stylebox_override("panel", st)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	_cards[key] = holder
	return v


func _build_ui() -> void:
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.4)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(10)
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = STAGE
	_ui.add_child(root)

	var back := _button("Back to Arcade", Color("#5a3a7a"))
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)
	_add(root, _centered("CUPID", 30, PINK), Rect2(0, 4, STAGE.x, 36))
	_add(root, _centered("Enhanced  |  rainy-day matchmaker (AS3/Flixel, 2010)", 13, MUTED), Rect2(0, 38, STAGE.x, 20))
	_add(root, _label("COUPLES", 12, MUTED), Rect2(STAGE.x - 14 - 38 * 5 - 70, 22, 66, 18))
	_hearts = Control.new()
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts.draw.connect(func(): _draw_hearts(_hearts))
	_add(root, _hearts, Rect2(STAGE.x - 14 - 38 * 5, 12, 38 * 5, 38))

	# Bottom strip: time / arrows | street radar | sky / best.
	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel", _panel_style)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, strip, STRIP)
	_add(strip, _label("TIME", 12, MUTED), Rect2(14, 9, 40, 16))
	_time_label = _add(strip, _label("0:00", 18, INK), Rect2(52, 4, 60, 24)) as Label
	_add(strip, _label("ARROWS", 12, MUTED), Rect2(126, 9, 60, 16))
	_arrows_label = _add(strip, _label("0", 18, ROSE), Rect2(186, 4, 50, 24)) as Label
	_add(strip, _label("STREET", 12, MUTED), Rect2(330, 9, 60, 16))
	_radar = Control.new()
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(func(): _draw_radar(_radar))
	_add(strip, _radar, Rect2(392, 4, 420, 24))
	_add(strip, _label("SKY", 12, MUTED), Rect2(850, 9, 30, 16))
	_sky_label = _add(strip, _label("0% clear", 16, GOLD), Rect2(882, 5, 100, 22)) as Label
	_add(strip, _label("BEST", 12, MUTED), Rect2(1010, 9, 40, 16))
	_best_label = _add(strip, _label("-", 18, INK), Rect2(1050, 4, 80, 24)) as Label

	# Title card.
	var tv := _card(root, "title", FRAME)
	var tc := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = CUPID
	atlas.region = Rect2(0, 0, Logic.CUPID_W, Logic.CUPID_H)
	tc.texture = atlas
	tc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tc.custom_minimum_size = Vector2(Logic.CUPID_W, Logic.CUPID_H) * 1.75
	tc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(tc)
	_title_cupid = tc
	tv.add_child(_centered("CUPID", 54, PINK))
	tv.add_child(_centered("Enhanced edition", 18, ROSE))
	tv.add_child(_centered("Steer with the mouse | click to drop an arrow straight down", 16, INK))
	tv.add_child(_centered("Hit two walkers who think the same symbol to make a couple.", 16, INK))
	tv.add_child(_centered("Every couple clears the storm a little. Five couples wins.", 16, MUTED))
	tv.add_child(_centered("Click or press Space to start", 22, GOLD))
	tv.add_child(_centered("Esc: pause", 13, MUTED))

	# Win card.
	var wv := _card(root, "win", GOLD)
	wv.add_child(_centered("TRUE LOVE WINS", 46, GOLD))
	wv.add_child(_centered("All five couples matched. The storm has passed.", 18, INK))
	_win_detail = _centered("", 16, MUTED)
	wv.add_child(_win_detail)
	_win_best = _centered("", 18, GOLD)
	wv.add_child(_win_best)
	wv.add_child(_centered("Press Space to play again", 20, PINK))


# --- audio ---------------------------------------------------------------------

func _build_audio() -> void:
	var loop: AudioStreamMP3 = RAIN_LOOP.duplicate()
	loop.loop = true
	_rain = AudioStreamPlayer.new()
	_rain.stream = loop
	add_child(_rain)
	_sfx_add("shoot", [[880.0, 440.0, 0.09]], 0.25, true)
	_sfx_add("pop", [[660.0, 990.0, 0.07]], 0.25)
	_sfx_add("miss", [[260.0, 160.0, 0.10]], 0.22, true)
	_sfx_add("match", [[784.0, 784.0, 0.10], [988.0, 988.0, 0.10], [1175.0, 1175.0, 0.22]], 0.28)
	_sfx_add("nomatch", [[392.0, 392.0, 0.12], [311.0, 300.0, 0.22]], 0.25, true)
	_sfx_add("couple", [[1568.0, 1568.0, 0.06], [2093.0, 2093.0, 0.14]], 0.16)
	_sfx_add("win", [[523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12], [1047.0, 1047.0, 0.4]], 0.3)


## Tiny synthesized blips (sine, or triangle when `soft` is false-ish buzzy).
func _sfx_add(key: String, segs: Array, vol: float, tri := false) -> void:
	var rate := 22050
	var data := PackedByteArray()
	var phase := 0.0
	for seg in segs:
		var n := int(rate * float(seg[2]))
		for i in n:
			var t := float(i) / n
			var fr: float = lerpf(seg[0], seg[1], t)
			phase += fr / rate
			var w := sin(phase * TAU)
			if tri:
				w = 2.0 * absf(2.0 * (phase - floorf(phase + 0.5))) - 1.0
			var env := minf(1.0, t * 40.0) * pow(1.0 - t, 1.6)
			var v := int(clampf(w * env * vol, -1.0, 1.0) * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	var pl := AudioStreamPlayer.new()
	pl.stream = wav
	pl.max_polyphony = 3
	add_child(pl)
	_sfx[key] = pl


func _play(key: String) -> void:
	var pl: AudioStreamPlayer = _sfx.get(key)
	if pl != null and pl.is_inside_tree():
		pl.play()


func _update_audio() -> void:
	if world.state == Logic.TITLE:
		if _rain.playing:
			_rain.stop()
		return
	var gain: float = world.rain_gain()
	if not _rain.playing:
		_rain.play()
	_rain.volume_db = linear_to_db(gain) if gain > 0.001 else -80.0
