extends Control
## Tentraminos Enhanced: board renderer. Draws the hold tray, 9×9 grid, tiles, cursor and juice
## from the live Direct rules state on the owning game.gd (`g`). Purely visual.

const Logic := preload("res://games/tentraminos/direct/tentraminos_logic.gd")

const CELL := 60.0
const PAD := 14.0
const TRAY_GAP := 18.0
const INSET := 3.0
const TRAY_ORIGIN := Vector2(PAD, PAD)
const GRID_ORIGIN := Vector2(PAD, PAD + CELL + TRAY_GAP)
const BOARD_SIZE := Vector2(9 * CELL + 2 * PAD, 2 * PAD + CELL + TRAY_GAP + 9 * CELL)

var g  # game.gd

var _tile_styles := {}
var _shine: StyleBoxFlat
var _panel: StyleBoxFlat
var _tray: StyleBoxFlat
var _slot: StyleBoxFlat
var _cursor: StyleBoxFlat


static func cell_vec(i: int) -> Vector2:
	return Vector2(i % Logic.GW, i / Logic.GW) * CELL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = _box(Color("#1a1f2e"), 18, Color("#2c3550"), 2)
	_panel.shadow_color = Color(0, 0, 0, 0.45)
	_panel.shadow_size = 18
	_tray = _box(Color("#12161f"), 12, Color("#2c3550"), 1)
	_slot = _box(Color("#222838"), 8)
	_cursor = _box(Color(0, 0, 0, 0), 14, Color.WHITE, 5)
	_cursor.draw_center = false
	_cursor.shadow_color = Color(1, 1, 1, 0.25)
	_cursor.shadow_size = 10
	_shine = _box(Color(1, 1, 1, 0.16), 8)
	_shine.corner_radius_bottom_left = 2
	_shine.corner_radius_bottom_right = 2
	for b in range(1, 9):
		for lit in [false, true]:
			var fill: Color = Logic.COLORS[b + 9] if lit else Logic.COLORS[b].lightened(0.06)
			var border: Color = Color(1, 1, 1, 0.85) if lit else Logic.COLORS[b].darkened(0.35)
			var st := _box(fill, 9, border, 3 if lit else 2)
			if lit:
				st.shadow_color = Color(Logic.COLORS[b + 9], 0.55)
				st.shadow_size = 9
			else:
				st.shadow_color = Color(0, 0, 0, 0.35)
				st.shadow_size = 3
				st.shadow_offset = Vector2(0, 2)
			_tile_styles[b * 2 + int(lit)] = st


func _box(bg: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = true
	return s


func _draw() -> void:
	if g == null or g.game == null:
		return
	draw_set_transform(g.shake_offset())
	var game = g.game
	var t: float = g.time
	# frame + tray + grid wells
	draw_style_box(_panel, Rect2(Vector2.ZERO, BOARD_SIZE))
	draw_style_box(_tray, Rect2(TRAY_ORIGIN - Vector2(4, 4), Vector2(9 * CELL + 8, CELL + 8)))
	var hidden: bool = g.started and game.paused and game.next != Logic.THEEND
	var danger: Array[int] = g.danger_columns()
	_draw_tray(game, danger, t, hidden)
	_draw_slots(t)
	if hidden:
		_draw_pause_veil()
	else:
		_draw_bridges(game)
		_draw_tiles(game, t)
		_draw_flashes()
		_draw_cursor(t)
	_draw_particles()
	_draw_popups()


func _draw_tray(game, danger: Array[int], t: float, hidden: bool) -> void:
	var font := get_theme_default_font()
	var pop: float = g.hold_pop
	for x in Logic.GW:
		var r := Rect2(TRAY_ORIGIN + Vector2(x * CELL, 0), Vector2(CELL, CELL))
		if x in danger:
			var a := 0.35 + 0.25 * sin(t * 8.0)
			draw_rect(r.grow(-2), Color(0.9, 0.1, 0.1, a))
		var v: int = game.hold[x]
		if v == 0 or hidden:
			continue
		var s := 0.82 * (1.0 - 0.6 * pop)
		s += 0.03 * sin(t * 2.5 + x * 0.7)
		_draw_tile(r.get_center(), v, s, Vector2.ONE, 0.75)
		if x in danger:
			draw_string(font, r.position + Vector2(0, CELL * 0.62), "!", HORIZONTAL_ALIGNMENT_CENTER,
					CELL, 30, Color.WHITE)


func _draw_slots(t: float) -> void:
	for i in Logic.NUMCELLS:
		var r := Rect2(GRID_ORIGIN + cell_vec(i), Vector2(CELL, CELL)).grow(-INSET)
		draw_style_box(_slot, r)
		if i < Logic.GW:
			draw_rect(r.grow(-2), Color(0.9, 0.15, 0.15, 0.10 + 0.03 * sin(t * 2.0)))


## Same-colour neighbours get a band across the gap so groups read as one blob.
func _draw_bridges(game) -> void:
	var m: PackedInt32Array = game.matrix
	for i in Logic.NUMCELLS:
		var v := m[i]
		if v == 0 or g.offsets[i].length_squared() > 1.0:
			continue
		var b := _base(v)
		var c := GRID_ORIGIN + cell_vec(i) + Vector2.ONE * CELL * 0.5
		for d in [1, Logic.GW]:
			if d == 1 and i % Logic.GW == Logic.GW - 1:
				continue
			var j: int = i + d
			if j >= Logic.NUMCELLS or m[j] == 0 or _base(m[j]) != b or g.offsets[j].length_squared() > 1.0:
				continue
			var lit := v > 8 and m[j] > 8
			var col: Color = Logic.COLORS[b + 9] if lit else Logic.COLORS[b].lightened(0.06)
			var w := CELL * (0.5 if lit else 0.36)
			var r: Rect2
			if d == 1:
				r = Rect2(c + Vector2(0, -w * 0.5), Vector2(CELL, w))
			else:
				r = Rect2(c + Vector2(-w * 0.5, 0), Vector2(w, CELL))
			draw_rect(r, col)


func _draw_tiles(game, t: float) -> void:
	var m: PackedInt32Array = game.matrix
	var over: bool = game.next == Logic.THEEND
	for i in Logic.NUMCELLS:
		var v := m[i]
		if v == 0:
			continue
		var center: Vector2 = GRID_ORIGIN + cell_vec(i) + Vector2.ONE * CELL * 0.5 + g.offsets[i]
		var sq: float = g.squash[i]
		var stretch := Vector2(1.0 + 0.14 * sq, 1.0 - 0.16 * sq)
		var s := 1.0
		if v > 8:
			s = 1.0 + 0.035 * sin(t * 7.0 + (i % 9) * 0.5 + (i / 9) * 0.3)
		_draw_tile(center + Vector2(0, CELL * 0.5 * (1.0 - stretch.y)), v, s, stretch,
				0.55 if over else 1.0)


func _draw_tile(center: Vector2, v: int, s: float, stretch: Vector2, alpha := 1.0) -> void:
	var b := _base(v)
	var lit := v > 8
	var size := Vector2.ONE * (CELL - 2 * INSET)
	draw_set_transform(center + g.shake_offset(), 0.0, stretch * s)
	var r := Rect2(-size * 0.5, size)
	var st: StyleBoxFlat = _tile_styles[b * 2 + int(lit)]
	if alpha < 1.0:
		st = st.duplicate()
		st.bg_color.a = alpha
	draw_style_box(st, r)
	draw_style_box(_shine, Rect2(r.position + Vector2(5, 4), Vector2(size.x - 10, size.y * 0.3)))
	if g.show_glyphs:
		_draw_glyph(b, Color(0, 0, 0, 0.42) if lit else Color(1, 1, 1, 0.5))
	draw_set_transform(g.shake_offset())


## A small shape per colour so tiles don't rely on hue alone.
func _draw_glyph(b: int, col: Color) -> void:
	var k := CELL * 0.17
	match b:
		1:
			draw_circle(Vector2.ZERO, k, col)
		2:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -k * 1.15), Vector2(k * 1.1, k * 0.8),
					Vector2(-k * 1.1, k * 0.8)]), col)
		3:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -k * 1.2), Vector2(k * 1.2, 0),
					Vector2(0, k * 1.2), Vector2(-k * 1.2, 0)]), col)
		4:
			draw_rect(Rect2(-Vector2.ONE * k * 0.9, Vector2.ONE * k * 1.8), col)
		5:
			draw_rect(Rect2(-k * 1.1, -k * 0.35, k * 2.2, k * 0.7), col)
			draw_rect(Rect2(-k * 0.35, -k * 1.1, k * 0.7, k * 2.2), col)
		6:
			draw_arc(Vector2.ZERO, k * 0.9, 0.0, TAU, 24, col, k * 0.5, true)
		7:
			draw_line(Vector2(-k, -k), Vector2(k, k), col, k * 0.6, true)
			draw_line(Vector2(-k, k), Vector2(k, -k), col, k * 0.6, true)
		8:
			draw_rect(Rect2(-k * 1.1, -k * 0.8, k * 2.2, k * 0.5), col)
			draw_rect(Rect2(-k * 1.1, k * 0.3, k * 2.2, k * 0.5), col)


func _draw_flashes() -> void:
	for f in g.flashes:
		var r := Rect2(GRID_ORIGIN + cell_vec(f.cell), Vector2(CELL, CELL)).grow(-INSET + 4.0 * (1.0 - f.life))
		draw_rect(r, Color(1, 1, 1, 0.85 * f.life))


func _draw_cursor(t: float) -> void:
	var game = g.game
	if not g.started or game.next == Logic.THEEND:
		return
	var p: Vector2 = GRID_ORIGIN + g.cursor_px + g.cursor_nudge
	var r := Rect2(p, Vector2(CELL, CELL) * 2.0).grow(1.0)
	var pulse := 0.75 + 0.25 * sin(t * 5.0)
	_cursor.border_color = Color(1, 1, 1, pulse)
	draw_style_box(_cursor, r)
	var rf: Dictionary = g.rot_flash
	if rf.life > 0.0:
		var c := r.get_center()
		var a0 := -PI * 0.5
		var sweep := PI * 1.2 * float(rf.dir)
		var col := Color(1, 1, 1, 0.8 * rf.life)
		draw_arc(c, CELL * 0.42, a0, a0 + sweep, 24, col, 4.0, true)
		var tip := c + Vector2(cos(a0 + sweep), sin(a0 + sweep)) * CELL * 0.42
		var tangent := Vector2(-sin(a0 + sweep), cos(a0 + sweep)) * float(rf.dir)
		var nrm := Vector2(cos(a0 + sweep), sin(a0 + sweep))
		draw_colored_polygon(PackedVector2Array([tip + tangent * 10.0, tip - tangent * 2.0 + nrm * 8.0,
				tip - tangent * 2.0 - nrm * 8.0]), col)


func _draw_pause_veil() -> void:
	var r := Rect2(GRID_ORIGIN, Vector2(9, 9) * CELL)
	draw_rect(r, Color(0.05, 0.06, 0.1, 0.92))
	var font := get_theme_default_font()
	draw_string_outline(font, r.position + Vector2(0, r.size.y * 0.47), "PAUSED",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56, 8, Color(0, 0, 0, 0.6))
	draw_string(font, r.position + Vector2(0, r.size.y * 0.47), "PAUSED",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56, Color.WHITE)
	draw_string(font, r.position + Vector2(0, r.size.y * 0.47 + 44), "press P to resume",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1, 1, 1, 0.7))


func _draw_particles() -> void:
	for p in g.particles:
		var c: Color = p.color
		c.a *= clampf(p.life * 1.5, 0.0, 1.0)
		var s: float = p.size * (0.4 + 0.6 * p.life)
		draw_set_transform(p.pos + g.shake_offset(), p.rot, Vector2.ONE)
		draw_rect(Rect2(-Vector2.ONE * s * 0.5, Vector2.ONE * s), c)
	draw_set_transform(g.shake_offset())


func _draw_popups() -> void:
	var font := get_theme_default_font()
	for p in g.popups:
		var a := clampf(p.life * 2.0, 0.0, 1.0)
		var grow := 1.0 + 0.25 * maxf(0.0, p.life - 0.8) * 5.0
		var fs := int(p.size * grow)
		var w := 400.0
		var pos: Vector2 = p.pos + Vector2(-w * 0.5, fs * 0.35)
		draw_string_outline(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 8, Color(0, 0, 0, 0.7 * a))
		var col: Color = p.color.lightened(0.25)
		col.a = a
		draw_string(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)


static func _base(v: int) -> int:
	return v - 9 if v > 8 else v
