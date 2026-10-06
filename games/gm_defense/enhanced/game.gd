extends Node2D
## GM Defense (Enhanced). Presentation makeover of the Direct GameMaker toy.
## Rules are Direct's gmd_world.gd (preloaded, not copied), stepped at the same
## fixed 60 steps/s with the same Key Press edges (Left / Right). The ship still
## launches on frame one, never stops, can leave the room, and the squid is
## still inert. This file owns the 1280x720 letterbox shell: a deep-space room
## with parallax stars and a horizon grid, ship glow / exhaust / afterimages, a
## banking flip on turns, a glowing squid, an off-room locator, a radar strip,
## side HUD panels and Back to Arcade. Esc is handled by the PauseOverlay
## autoload. No Alchementrix IP.

const World := preload("res://games/gm_defense/direct/gmd_world.gd")
const DIR := "res://games/gm_defense/direct/assets/"
const SHIP_TEX := preload(DIR + "s_ship0_0.png")
const SQUID_TEX := [
	preload(DIR + "s_squid_0.png"), preload(DIR + "s_squid_1.png"),
	preload(DIR + "s_squid_2.png"), preload(DIR + "s_squid_3.png"),
]

const STAGE := Vector2(1280, 720)
const PX := 0.75  ## r_main 1024x768 -> 768x576 field
const FIELD := Vector2(World.W, World.H) * PX
const FIELD_POS := Vector2((STAGE.x - FIELD.x) * 0.5, 84.0)
const SPRITE_PX := 1.0  ## sprites drawn 1:1 (crisp 50 px) at their scaled room position
const STEP_SEC := 1.0 / World.SPEED
const RADAR := Rect2(FIELD_POS.x, 672, FIELD.x, 34)
const RADAR_SPAN := 3.0  ## radar shows one room either side of r_main

const BG_TOP := Color("#060a1a")
const BG_BOTTOM := Color("#120a24")
const PANEL := Color(0.06, 0.08, 0.17, 0.92)
const FRAME := Color("#3fd0ff")
const INK := Color("#e8f3ff")
const MUTED := Color("#7f8db3")
const CYAN := Color("#59e1ff")
const MAGENTA := Color("#ff4fb0")
const GOLD := Color("#ffd166")
const RED := Color("#ff5a6e")
const GRID := Color("#b04cff")

var world = World.new()
var _acc := 0.0
var _time := 0.0
var _left_pressed := false
var _right_pressed := false
var _fx_rng := RandomNumberGenerator.new()  ## juice only; the Direct world has no rng
var _stars: Array[Dictionary] = []
var _particles: Array[Dictionary] = []  ## field-space
var _floaters: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []     ## afterimages {pos, flip, life}
var _rings: Array[Dictionary] = []
var _bank := 1.0        ## displayed x-scale, eases toward world.ship.image_xscale
var _drift := 0.0       ## star drift (follows heading, presentation only)
var _turns := 0
var _exits := 0
var _intro := 1.0       ## intro banner alpha
var _prev := {}

var _field: Control      ## clipped canvas for the room (r_main) view
var _cv: CanvasItem
var _ui: CanvasLayer
var _font: Font
var _panel_style := StyleBoxFlat.new()
var _heading_label: Label
var _pos_label: Label
var _status_label: Label
var _time_label: Label
var _turns_label: Label
var _dist_label: Label
var _exits_label: Label
var _banner: Control
var _sfx := {}


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_fx_rng.randomize()
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.4)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_seed_stars()
	_field = Control.new()
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.position = FIELD_POS
	_field.size = FIELD
	_field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_field)
	_cv = _field
	_field.draw.connect(_draw_field)
	_build_ui()
	_build_audio()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_snap_prev()
	_refresh_hud()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5
	if _ui:  # HUD layer follows the same letterbox transform as the stage
		_ui.transform = Transform2D(0.0, scale, 0.0, position)


# --- loop ----------------------------------------------------------------------

## Same as Direct: GM Key Press events fire once per press and are queued
## until the next step, so a tap between steps is never lost.
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_LEFT:
		_left_pressed = true
	elif k.keycode == KEY_RIGHT:
		_right_pressed = true


func _process(delta: float) -> void:
	_time += delta
	_acc = minf(_acc + delta, 0.25)
	while _acc >= STEP_SEC:
		_acc -= STEP_SEC
		world.step({"left_pressed": _left_pressed, "right_pressed": _right_pressed})
		_left_pressed = false
		_right_pressed = false
		_on_world_step()
	_animate(delta)
	_refresh_hud()
	queue_redraw()


func _snap_prev() -> void:
	_prev = {
		"xscale": world.ship.image_xscale,
		"on": world.ship_on_screen(),
		"frame": int(world.squid.image_index),
	}


## Juice from Direct state deltas (presentation only; never writes the world).
func _on_world_step() -> void:
	var s = world.ship
	var sp := ship_field()
	if s.image_xscale != float(_prev.xscale):
		_turns += 1
		_intro = minf(_intro, 0.6)
		_rings.append({"pos": sp, "life": 0.45, "max": 0.45, "color": CYAN})
		_burst(sp, CYAN, 14, 160.0)
		_float(sp + Vector2(0, -38), "< TURN" if s.image_xscale < 0 else "TURN >", CYAN)
		_play("turn")
	var on: bool = world.ship_on_screen()
	if not on and bool(_prev.on):
		_exits += 1
		_float(_edge_point() + Vector2(-20 * signf(s.x - World.W * 0.5), -30), "OUT OF ROOM", RED)
		_play("exit")
	elif on and not bool(_prev.on):
		_burst(_edge_point(), GOLD, 16, 140.0)
		_float(_edge_point() + Vector2(20 * signf(s.x - World.W * 0.5) * -1, -30), "BACK!", GOLD)
		_play("back")
	if int(world.squid.image_index) != int(_prev.frame) and _fx_rng.randf() < 0.5:
		var q := squid_field()
		_particles.append({
			"pos": q + Vector2(_fx_rng.randf_range(-14, 14), 18), "vel": Vector2(_fx_rng.randf_range(-6, 6), -_fx_rng.randf_range(18, 34)),
			"life": 1.4, "max": 1.4, "color": Color(MAGENTA, 0.7), "size": _fx_rng.randf_range(1.5, 3.0), "grav": 0.0,
		})
	# Exhaust out of the rear while the ship is in (or near) the room.
	if world.steps % 2 == 0:
		var rear := sp + Vector2(-s.image_xscale * 22.0, _fx_rng.randf_range(-3, 3))
		_particles.append({
			"pos": rear, "vel": Vector2(-s.image_xscale * _fx_rng.randf_range(40, 90), _fx_rng.randf_range(-14, 14)),
			"life": 0.4, "max": 0.4, "color": Color(0.45, 0.85, 1.0, 0.9) if _fx_rng.randf() < 0.7 else Color(GOLD, 0.9),
			"size": _fx_rng.randf_range(1.5, 3.5), "grav": 0.0,
		})
	if world.steps % 4 == 0:
		_ghosts.append({"pos": sp, "flip": _bank, "life": 0.3, "max": 0.3})
	_snap_prev()


func _animate(delta: float) -> void:
	_bank = move_toward(_bank, float(world.ship.image_xscale), delta * 10.0)
	_drift += -float(world.ship.image_xscale) * delta
	if world.steps > World.SPEED * 3:
		_intro = move_toward(_intro, 0.0, delta * 1.2)
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.95
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 26.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	for g in _ghosts:
		g.life -= delta
	_ghosts = _ghosts.filter(func(g): return g.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r): return r.life > 0.0)
	if _banner:
		_banner.modulate.a = _intro


# --- helpers ---------------------------------------------------------------------

func to_field(p: Vector2) -> Vector2:
	return FIELD_POS + p * PX


func ship_field() -> Vector2:
	return to_field(Vector2(world.ship.x, world.ship.y))


func squid_field() -> Vector2:
	return to_field(Vector2(world.squid.x, world.squid.y))


## Where the ship crosses (or would cross) the field edge on its row.
func _edge_point() -> Vector2:
	var sp := ship_field()
	return Vector2(clampf(sp.x, FIELD_POS.x + 18, FIELD_POS.x + FIELD.x - 18), sp.y)


## Room pixels between the ship sprite and the nearest room edge (0 if on screen).
func off_distance() -> float:
	var x: float = world.ship.x
	if x - 25 >= World.W:
		return x - 25 - World.W
	if x + 25 <= 0:
		return -(x + 25)
	return 0.0


func _seed_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2017
	for i in 150:
		var depth := rng.randf()
		_stars.append({"p": Vector2(rng.randf() * FIELD.x, rng.randf() * FIELD.y * 0.78),
				"d": depth, "tw": rng.randf() * TAU})


func _burst(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var a := _fx_rng.randf() * TAU
		_particles.append({
			"pos": at, "vel": Vector2(cos(a), sin(a)) * _fx_rng.randf_range(speed * 0.3, speed),
			"life": _fx_rng.randf_range(0.3, 0.6), "max": 0.6, "color": color,
			"size": _fx_rng.randf_range(1.5, 3.5), "grav": 0.0,
		})


func _float(at: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": at, "life": 1.0, "max": 1.0, "text": text, "color": color})


# --- drawing ---------------------------------------------------------------------

func _draw() -> void:
	# Stage backdrop.
	var bands := 24
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, STAGE.y * t, STAGE.x, STAGE.y / bands + 1), BG_TOP.lerp(BG_BOTTOM, t))
	var fr := Rect2(FIELD_POS, FIELD)
	draw_rect(fr.grow(8), Color(0.01, 0.02, 0.05))
	draw_rect(fr.grow(3), Color(FRAME, 0.35), false, 2.0)
	_draw_brackets(fr.grow(8))
	_draw_radar()
	_field.queue_redraw()


func _draw_field() -> void:
	_cv.draw_set_transform(-FIELD_POS)
	var fr := Rect2(FIELD_POS, FIELD)
	# Space gradient + nebula (the original room is plain black; this is the makeover).
	var bands := 32
	for i in bands:
		var t := float(i) / bands
		var c := Color("#03040c").lerp(Color("#0d0826"), t)
		_cv.draw_rect(Rect2(FIELD_POS.x, FIELD_POS.y + FIELD.y * t, FIELD.x, FIELD.y / bands + 1), c)
	for n in [[Vector2(0.22, 0.25), 150.0, Color(0.35, 0.15, 0.6)], [Vector2(0.78, 0.18), 120.0, Color(0.1, 0.3, 0.6)],
			[Vector2(0.55, 0.45), 190.0, Color(0.55, 0.1, 0.4)]]:
		var c: Vector2 = FIELD_POS + FIELD * (n[0] as Vector2)
		for k in 6:
			_cv.draw_circle(c, float(n[1]) * (1.0 - k * 0.15), Color(n[2], 0.035))
	# Parallax stars, drifting against the heading.
	for s in _stars:
		var d: float = s.d
		var x := fposmod(s.p.x + _drift * (6.0 + 40.0 * d), FIELD.x)
		var tw := 0.5 + 0.5 * sin(_time * (1.5 + d * 2.0) + float(s.tw))
		var col := Color(0.8, 0.9, 1.0, (0.25 + 0.6 * d) * (0.6 + 0.4 * tw))
		var r := 0.6 + 1.2 * d
		_cv.draw_rect(Rect2(FIELD_POS + Vector2(x, s.p.y), Vector2(r, r) * 1.4), col)
	_draw_horizon()

	# Squid: glow, shadow, Direct animation frame.
	var q := squid_field()
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	for k in 5:
		_cv.draw_circle(q, 34.0 + k * 9.0 + pulse * 4.0, Color(MAGENTA, 0.05))
	_cv.draw_set_transform(q + Vector2(0, 46) - FIELD_POS, 0.0, Vector2(1.0, 0.25))
	_cv.draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.45))
	_cv.draw_set_transform(-FIELD_POS)
	var qtex: Texture2D = SQUID_TEX[int(world.squid.image_index) % SQUID_TEX.size()]
	_cv.draw_texture_rect(qtex, Rect2(q - Vector2(25, 25) * SPRITE_PX, Vector2(50, 50) * SPRITE_PX), false)

	# Afterimages, rings, ship glow + ship (with banking flip).
	for g in _ghosts:
		var a: float = g.life / g.max
		_draw_ship(g.pos, g.flip, Color(0.4, 0.85, 1.0, a * 0.28))
	for r in _rings:
		var t: float = 1.0 - r.life / r.max
		_cv.draw_arc(r.pos, 18.0 + 46.0 * t, 0.0, TAU, 40, Color(r.color, 1.0 - t), 3.0)
	var sp := ship_field()
	if fr.grow(40).has_point(sp):
		for k in 4:
			_cv.draw_circle(sp, 22.0 + k * 8.0, Color(CYAN, 0.045))
		_cv.draw_set_transform(Vector2(sp.x, FIELD_POS.y + FIELD.y - 6) - FIELD_POS, 0.0, Vector2(1.0, 0.2))
		_cv.draw_circle(Vector2.ZERO, 22.0, Color(CYAN, 0.18))
		_cv.draw_set_transform(-FIELD_POS)
		_draw_ship(sp, _bank, Color.WHITE)
	_draw_particles()
	_draw_floaters()

	# Scanlines + frame (cover anything that strayed past the room edge).
	for y in range(0, int(FIELD.y), 3):
		_cv.draw_rect(Rect2(FIELD_POS.x, FIELD_POS.y + y, FIELD.x, 1), Color(0, 0, 0, 0.12))
	if off_distance() > 0.0:
		_draw_locator()


## Synthwave horizon along the bottom of the room (decor only; nothing collides).
func _draw_horizon() -> void:
	var hy := FIELD_POS.y + FIELD.y * 0.8
	var bottom := FIELD_POS.y + FIELD.y
	for k in 6:
		_cv.draw_rect(Rect2(FIELD_POS.x, hy - 3 - k * 4, FIELD.x, 4), Color(GRID, 0.06 - k * 0.008))
	_cv.draw_rect(Rect2(FIELD_POS.x, hy, FIELD.x, bottom - hy), Color(0.06, 0.02, 0.12))
	_cv.draw_line(Vector2(FIELD_POS.x, hy), Vector2(FIELD_POS.x + FIELD.x, hy), Color(GRID, 0.9), 2.0)
	var scroll := fposmod(_time * 0.6, 1.0)
	for i in 8:
		var t := pow((i + scroll) / 8.0, 2.0)
		var y := hy + (bottom - hy) * t
		_cv.draw_line(Vector2(FIELD_POS.x, y), Vector2(FIELD_POS.x + FIELD.x, y), Color(GRID, 0.15 + 0.45 * t), 1.0)
	var cx := FIELD_POS.x + FIELD.x * 0.5
	for i in range(-12, 13):
		var x0 := cx + i * 22.0
		var x1 := cx + i * 110.0
		_cv.draw_line(Vector2(x0, hy), Vector2(x1, bottom), Color(GRID, 0.35), 1.0)


func _draw_ship(at: Vector2, flip: float, mod: Color) -> void:
	var w := 50.0 * SPRITE_PX
	var xs := flip if absf(flip) > 0.08 else 0.08 * signf(flip + 0.0001)
	_cv.draw_set_transform(at - FIELD_POS, 0.0, Vector2(xs, 1.0))
	_cv.draw_texture_rect(SHIP_TEX, Rect2(Vector2(-w, -w) * 0.5, Vector2(w, w)), false, mod)
	_cv.draw_set_transform(-FIELD_POS)


func _draw_brackets(r: Rect2) -> void:
	var L := 22.0
	var col := Color(FRAME, 0.9)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		draw_line(corner, corner + Vector2(L * sx, 0), col, 3.0)
		draw_line(corner, corner + Vector2(0, L * sy), col, 3.0)


## Edge chevron + distance while the ship is outside r_main (Direct has no wrap).
func _draw_locator() -> void:
	var right: bool = world.ship.x > World.W * 0.5
	var ep := _edge_point()
	var pulse := 0.6 + 0.4 * sin(_time * 8.0)
	var dir := 1.0 if right else -1.0
	var tip := ep + Vector2(dir * 10, 0)
	var pts := PackedVector2Array([tip, tip + Vector2(-dir * 18, -12), tip + Vector2(-dir * 18, 12)])
	_cv.draw_colored_polygon(pts, Color(RED, pulse))
	_cv.draw_circle(ep, 26.0, Color(RED, 0.08 * pulse))
	var txt := "%d px" % int(off_distance())
	var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var tx := ep.x - dir * (28 + (tw if right else 0.0))
	_cv.draw_string(_font, Vector2(tx, ep.y + 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(INK, 0.9))
	var hint := "press < to come back" if right else "press > to come back"
	var heading_away: bool = (world.ship.image_xscale > 0) == right
	if heading_away:
		var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var hx := ep.x - dir * (28 + (hw if right else 0.0))
		_cv.draw_string(_font, Vector2(hx, ep.y + 24), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(MUTED, pulse))


## Radar strip under the field: one room either side of r_main.
func _draw_radar() -> void:
	draw_rect(RADAR.grow(3), Color(0, 0, 0, 0.6))
	draw_rect(RADAR, Color(0.03, 0.05, 0.12, 0.95))
	var span := World.W * RADAR_SPAN
	var sf := RADAR.size.x / span
	var x0 := -float(World.W)
	var room := Rect2(RADAR.position.x + (0 - x0) * sf, RADAR.position.y + 2, World.W * sf, RADAR.size.y - 4)
	draw_rect(room, Color(FRAME, 0.10))
	draw_rect(room, Color(FRAME, 0.7), false, 1.5)
	var qy: float = RADAR.position.y + 2 + (world.squid.y / World.H) * (RADAR.size.y - 4)
	draw_rect(Rect2(RADAR.position.x + (world.squid.x - x0) * sf - 2, qy - 2, 5, 5), MAGENTA)
	var sx: float = world.ship.x - x0
	var clipped := sx < 0 or sx > span
	sx = clampf(sx, 0, span)
	var sy: float = RADAR.position.y + 2 + (world.ship.y / World.H) * (RADAR.size.y - 4)
	var col := RED if clipped else CYAN
	draw_rect(Rect2(RADAR.position.x + sx * sf - 3, sy - 2, 6, 5), col)
	draw_line(Vector2(RADAR.position.x + sx * sf + world.ship.image_xscale * 4, sy + 0.5),
			Vector2(RADAR.position.x + sx * sf + world.ship.image_xscale * 12, sy + 0.5), Color(col, 0.7), 2.0)
	draw_string(_font, RADAR.position + Vector2(6, 14), "RADAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	if clipped:
		draw_string(_font, Vector2(RADAR.end.x - 120, RADAR.position.y + 14), "beyond radar", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RED)
	draw_rect(RADAR, Color(FRAME, 0.5), false, 1.0)


func _draw_particles() -> void:
	for p in _particles:
		var a := clampf(p.life / maxf(float(p.max), 0.001), 0.0, 1.0)
		_cv.draw_circle(p.pos, float(p.size) * (0.4 + 0.6 * a), Color(p.color, p.color.a * a))


func _draw_floaters() -> void:
	for f in _floaters:
		var a := clampf(f.life / maxf(float(f.max), 0.001), 0.0, 1.0)
		var tw := _font.get_string_size(str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_cv.draw_string(_font, f.pos + Vector2(-tw * 0.5, 0), str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(f.color, a))


# --- HUD -------------------------------------------------------------------------

func _refresh_hud() -> void:
	var s = world.ship
	_heading_label.text = "< LEFT" if s.image_xscale < 0 else "RIGHT >"
	_pos_label.text = "x %d   y %d" % [int(s.x), int(s.y)]
	var on: bool = world.ship_on_screen()
	_status_label.text = "IN ROOM" if on else "OFF %d px" % int(off_distance())
	_status_label.add_theme_color_override("font_color", CYAN if on else RED)
	var secs: int = world.steps / World.SPEED
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	_turns_label.text = str(_turns)
	_dist_label.text = "%d px" % int(world.steps * World.SHIP_SPEED)
	_exits_label.text = str(_exits)


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
	root.size = STAGE
	_ui.add_child(root)

	var title := _label("GM DEFENSE", 30, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, title, Rect2(0, 8, STAGE.x, 38))
	var sub := _label("Enhanced  |  GameMaker Studio 2 Defender-clone toy (2017)", 14, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, sub, Rect2(0, 44, STAGE.x, 22))

	var back := _button("Back to Arcade", Color(0.18, 0.28, 0.6))
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)

	var lw := FIELD_POS.x - 40
	var lp := _panel(root, Rect2(16, FIELD_POS.y, lw, FIELD.y))
	_add(lp, _label("HEADING", 14, MUTED), Rect2(18, 16, lw - 36, 20))
	_heading_label = _add(lp, _label("RIGHT >", 30, CYAN), Rect2(18, 36, lw - 36, 40)) as Label
	_add(lp, _label("POSITION", 14, MUTED), Rect2(18, 96, lw - 36, 20))
	_pos_label = _add(lp, _label("", 20, INK), Rect2(18, 116, lw - 36, 30)) as Label
	_add(lp, _label("STATUS", 14, MUTED), Rect2(18, 166, lw - 36, 20))
	_status_label = _add(lp, _label("IN ROOM", 24, CYAN), Rect2(18, 186, lw - 36, 34)) as Label
	_add(lp, _label("TIME", 14, MUTED), Rect2(18, 246, lw - 36, 20))
	_time_label = _add(lp, _label("0:00", 30, INK), Rect2(18, 266, lw - 36, 40)) as Label
	_add(lp, _label("TURNS", 14, MUTED), Rect2(18, 326, lw - 36, 20))
	_turns_label = _add(lp, _label("0", 30, GOLD), Rect2(18, 346, lw - 36, 40)) as Label
	_add(lp, _label("FLOWN", 14, MUTED), Rect2(18, 406, lw - 36, 20))
	_dist_label = _add(lp, _label("0 px", 24, INK), Rect2(18, 426, lw - 36, 34)) as Label
	_add(lp, _label("ROOM EXITS", 14, MUTED), Rect2(18, 486, lw - 36, 20))
	_exits_label = _add(lp, _label("0", 30, RED), Rect2(18, 506, lw - 36, 40)) as Label

	var rx := FIELD_POS.x + FIELD.x + 24
	var rw := STAGE.x - rx - 16
	var rp := _panel(root, Rect2(rx, FIELD_POS.y, rw, FIELD.y))
	_add(rp, _label("TURN", 14, MUTED), Rect2(18, 16, rw - 36, 20))
	_add(rp, _label("<- / ->", 26, INK), Rect2(18, 36, rw - 36, 36))
	_add(rp, _label("PAUSE", 14, MUTED), Rect2(18, 92, rw - 36, 20))
	_add(rp, _label("Esc", 26, INK), Rect2(18, 112, rw - 36, 36))
	var notes := _label("The ship never stops:\narrows only turn it.\n\nThere's no wrap, so\nit can fly out of the\nroom. Turn around to\nbring it back.\n\nThe squid just floats\nthere. It's a toy.\n\nSame rules as Direct.\nPresentation only.", 14, MUTED)
	_add(rp, notes, Rect2(18, 176, rw - 36, 300))

	# Non-blocking intro banner (Direct has no title screen; the ship launches at once).
	var bc := CenterContainer.new()
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, bc, Rect2(FIELD_POS + Vector2(0, 40), Vector2(FIELD.x, 120)))
	var bp := PanelContainer.new()
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.05, 0.06, 0.16, 0.85)
	bs.border_color = CYAN
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(16)
	bs.shadow_color = Color(CYAN, 0.25)
	bs.shadow_size = 14
	bs.set_content_margin_all(18)
	bp.add_theme_stylebox_override("panel", bs)
	bc.add_child(bp)
	var bv := VBoxContainer.new()
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp.add_child(bv)
	var b1 := _label("LAUNCH!", 30, GOLD)
	b1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(b1)
	var b2 := _label("<- / -> turn the ship  |  Esc pauses", 16, INK)
	b2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(b2)
	_banner = bc


# --- audio -----------------------------------------------------------------------

func _build_audio() -> void:
	_sfx_add("turn", [[520.0, 900.0, 0.07]], 0.22)
	_sfx_add("exit", [[420.0, 220.0, 0.16]], 0.2, true)
	_sfx_add("back", [[660.0, 660.0, 0.06], [990.0, 990.0, 0.12]], 0.22)


func _sfx_add(key: String, segs: Array, vol: float, tri := false) -> void:
	var rate := 22050
	var data := PackedByteArray()
	var phase := 0.0
	for seg in segs:
		var n := int(rate * float(seg[2]))
		for i in n:
			var t := float(i) / n
			phase += lerpf(seg[0], seg[1], t) / rate
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
	wav.data = data
	var p := AudioStreamPlayer.new()
	p.stream = wav
	add_child(p)
	_sfx[key] = p


func _play(key: String) -> void:
	var p: AudioStreamPlayer = _sfx.get(key)
	if p and p.is_inside_tree():
		p.play()
