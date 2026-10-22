extends Control
## Squirrel Command Direct: Godot 4 port of the Claude artifact Missile-Command-style
## garden defense (source/squirrel_command.html). The artifact page (HUD row,
## 680x440 canvas, hint line) is one 712x544 stage, self-scaled into the window.
## Click/tap the field to fire; Restart button top-right. Esc is left for PauseOverlay.

const Logic := preload("res://games/squirrel_command/direct/squirrel_logic.gd")

const STAGE := Vector2(712, 544)
const FIELD := Vector2(16, 62)  # canvas top-left on the page (16px body margin)
const RESTART := Rect2(602, 16, 94, 33)
const PAGE := Color("#FCFCFB")
const TEXT := Color("#0b0b0b")
const TEXT2 := Color("#5f5e5a")
const MUTED := Color("#8a8984")
const BORDER := Color(0.043, 0.043, 0.043, 0.15)

var state: Logic = Logic.new()
var _font: Font = _thin(ThemeDB.fallback_font)
var _scale := 1.0
var _origin := Vector2.ZERO


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	state.rng.randomize()
	state.reset()
	call_deferred("grab_focus")


func _process(delta: float) -> void:
	state.step(delta)
	for q in state.squirrels:  # drawSquirrel advances the leg cycle every frame
		q.leg += 0.4
	queue_redraw()


## The artifact draws in a regular-weight system sans; thin the bolder fallback font.
static func _thin(f: Font) -> Font:
	var v := FontVariation.new()
	v.base_font = f
	v.variation_embolden = -0.35
	return v


## Window position -> stage position.
func to_stage(p: Vector2) -> Vector2:
	return (p - _origin) / _scale


func _gui_input(event: InputEvent) -> void:
	var pos: Vector2
	if event is InputEventMouseButton and event.pressed:
		pos = to_stage(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		pos = to_stage(event.position)
	else:
		return
	if RESTART.has_point(pos):
		state.reset()
		accept_event()
	elif Rect2(FIELD, Vector2(Logic.W, Logic.H)).has_point(pos):
		var f := pos - FIELD
		state.fire(f.x, f.y)
		accept_event()


# --- canvas 2D helpers (ctx.ellipse / arc paths) ---------------------------

func _ellipse(c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col, 0.6, true)


func _disc(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col, true, -1.0, true)


## One canvas path of full arcs: fill = the discs plus the polygon through each
## arc's start point (canvas joins sub-arcs with straight lines).
func _arcs(arcs: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for a in arcs:
		_disc(Vector2(a[0], a[1]), a[2], col)
		pts.append(Vector2(a[0] + a[2], a[1]))
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)


func _text(s: String, x: float, y: float, sz: int, col: Color) -> void:
	draw_string(_font, Vector2(x - 300, y), s, HORIZONTAL_ALIGNMENT_CENTER, 600, sz, col)


func _at(base: Transform2D, p: Vector2) -> void:
	draw_set_transform_matrix(base * Transform2D(0.0, p))


# --- drawing ---------------------------------------------------------------

func _draw_squirrel(base: Transform2D, q: Dictionary) -> void:
	_at(base, Vector2(q.x, q.y))
	var fur := Color("#7A5230")
	_ellipse(Vector2(-2, -11), 4, 7, sin(q.ph) * 0.25, fur)
	_ellipse(Vector2.ZERO, 7, 9, 0, fur)
	_disc(Vector2(0, 9), 4.5, fur)
	for i in [-1, 0, 1]:
		_disc(Vector2(i * 3, -1), 0.9, Color("#EDE3CF"))
		_disc(Vector2(i * 3, 4), 0.9, Color("#EDE3CF"))
	_disc(Vector2(-2.4, 10), 0.9, Color("#3a2a18"))
	_disc(Vector2(2.4, 10), 0.9, Color("#3a2a18"))
	var l: float = sin(q.leg) * 3.0
	draw_line(Vector2(-5, 6), Vector2(-7, 10 + l), Color("#5c3d22"), 1.6, true)
	draw_line(Vector2(5, 6), Vector2(7, 10 - l), Color("#5c3d22"), 1.6, true)


func _draw_crop(base: Transform2D, cr: Dictionary) -> void:
	_at(base, Vector2(cr.x, cr.y))
	_ellipse(Vector2(0, 14), 30, 8, 0, Color("#8a6a42"))
	if cr.alive:
		_arcs([[-12, 4, 9], [0, 0, 11], [12, 4, 9]], Color("#4c7a2c"))
		_arcs([[-10, 6, 3.4], [4, 3, 3.4], [13, 8, 3]], Color("#c4522e"))
	else:
		draw_line(Vector2(-8, 8), Vector2(-4, -2), Color("#6d5233"), 2.0, true)
		draw_line(Vector2(2, 10), Vector2(6, 0), Color("#6d5233"), 2.0, true)


func _draw() -> void:
	_scale = minf(size.x / STAGE.x, size.y / STAGE.y)
	if _scale <= 0.0:
		return
	_origin = (size - STAGE * _scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), PAGE)
	var page := Transform2D(0.0, Vector2(_scale, _scale), 0.0, _origin)
	draw_set_transform_matrix(page)
	_draw_hud()
	var base := page * Transform2D(0.0, FIELD)
	draw_set_transform_matrix(base)
	_draw_field(base)
	draw_set_transform_matrix(page)
	_round_corners()
	draw_set_transform(Vector2.ZERO)


func _draw_hud() -> void:
	var x := 16.0
	for pair in [["Score", state.score], ["Wave", state.wave], ["Crops", state.alive_crops().size()]]:
		var lab: String = pair[0] + " "
		draw_string(_font, Vector2(x, 38), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT2)
		x += _font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var val := str(pair[1])
		draw_string(_font, Vector2(x, 38), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
		x += _font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.anti_aliasing = true
	draw_style_box(sb, RESTART)
	# ti-refresh: an open circular arrow
	var c := RESTART.position + Vector2(24, 17)
	draw_arc(c, 4.5, -0.6, 4.4, 16, TEXT, 1.3, true)
	var tip := c + Vector2(cos(-0.6), sin(-0.6)) * 4.5
	draw_line(tip, tip + Vector2(0, -3.2), TEXT, 1.3, true)
	draw_line(tip, tip + Vector2(-3.2, 0), TEXT, 1.3, true)
	draw_string(_font, RESTART.position + Vector2(34, 22), "Restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	draw_string(_font, Vector2(16, FIELD.y + Logic.H + 23),
		"Click or tap the field to fire. Shots explode where you aim - lead the runners. Lose all five crops and it's over.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)


func _draw_field(base: Transform2D) -> void:
	var W := Logic.W
	var H := Logic.H
	var S := state
	draw_rect(Rect2(0, 0, W, H), Color("#E9DAB4"))
	for i in 6:
		draw_rect(Rect2(0, 60 + i * 60, W, 26), Color("#E2D0A4"))
	draw_rect(Rect2(0, 0, W, 42), Color("#C9B384"))
	for m in S.mounds:
		_ellipse(Vector2(m.x, m.y), 16, 8, 0, Color("#a9834f"))
		_ellipse(Vector2(m.x, m.y + 1), 8, 4, 0, Color("#5c4426"))
	for cr in S.crops:
		_draw_crop(base, cr)
	draw_set_transform_matrix(base)
	draw_rect(Rect2(W / 2 - 10, H - 26, 20, 14), Color("#6b6b66"))
	draw_rect(Rect2(W / 2 - 3, H - 34, 6, 10), Color("#4a4a46"))
	for sh in S.shots:
		draw_line(Vector2(sh.px, sh.py), Vector2(sh.x, sh.y), Color("#b0552c"), 2.5, true)
		draw_line(Vector2(sh.tx - 5, sh.ty), Vector2(sh.tx + 5, sh.ty), Color("#333333"), 1.0, true)
		draw_line(Vector2(sh.tx, sh.ty - 5), Vector2(sh.tx, sh.ty + 5), Color("#333333"), 1.0, true)
	for q in S.squirrels:
		_draw_squirrel(base, q)
	draw_set_transform_matrix(base)
	for b in S.booms:
		var a: float = 0.85 if b.t < 0.6 else 0.85 * (1.0 - (b.t - 0.6) / 0.35)
		if b.r > 0.0:
			_disc(Vector2(b.x, b.y), b.r, Color8(196, 166, 116, int(a * 255)))
			draw_arc(Vector2(b.x, b.y), b.r, 0, TAU, 48, Color8(120, 90, 50, int(a * 255)), 2.0, true)
	for p in S.pops:
		var pa: float = 1.0 - p.t / 0.8
		_text("chomp!" if p.eat else "+%d" % p.v, p.x, p.y - 6 - p.t * 24, 14, Color8(60, 40, 20, int(pa * 255)))
	if S.wave_msg > 0.0 and not S.over:
		_text("Wave %d" % S.wave, W / 2, H / 2 - 40, 26, Color8(60, 40, 20, int(minf(1.0, S.wave_msg) * 255)))
	if S.over:
		draw_rect(Rect2(0, 0, W, H), Color8(40, 28, 14, 191))
		var fg := Color("#f2e6cc")
		_text("The squirrels win", W / 2, H / 2 - 20, 30, fg)
		_text("Final score: %d - Wave %d" % [S.score, S.wave], W / 2, H / 2 + 14, 17, fg)
		_text("Click to play again", W / 2, H / 2 + 44, 17, fg)


## CSS border-radius:12px + 0.5px border on the canvas: mask the corners, then outline.
func _round_corners() -> void:
	var r := 12.0
	var rect := Rect2(FIELD, Vector2(Logic.W, Logic.H))
	var corners := [[rect.position, PI], [Vector2(rect.end.x, rect.position.y), 1.5 * PI],
		[rect.end, 0.0], [Vector2(rect.position.x, rect.end.y), 0.5 * PI]]
	for k in corners:
		var p: Vector2 = k[0]
		var a0: float = k[1]
		var inward := Vector2(-cos(a0 + PI / 4) , -sin(a0 + PI / 4)) * r * sqrt(2.0)
		var cc := p + inward  # arc centre, r inside both edges
		var pts := PackedVector2Array([p])
		for i in 9:
			var a := a0 + (PI / 2) * i / 8.0
			pts.append(cc + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, PAGE)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(r))
	sb.anti_aliasing = true
	draw_style_box(sb, rect)
