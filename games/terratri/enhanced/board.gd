extends Control
## Terratri Enhanced: tabletop board renderer. Draws the 5x5 field, territory,
## forts, pawns and move hints from the live Direct snapshot on the owning
## game.gd (`g`), plus g's purely visual animation state. Reports cell clicks.
## No rules here: legal targets come from the snapshot's valid_steps.

signal cell_clicked(cell: Vector2i)

const Rules := preload("res://games/terratri/direct/terratri_rules.gd")
const In := preload("res://games/terratri/direct/terratri_input.gd")

const N := 5
const CELL := 100.0
const MARGIN := 30.0
const GRID := CELL * N
const BOARD := Vector2(GRID + MARGIN * 2.0, GRID + MARGIN * 2.0)
const ORIGIN := Vector2(MARGIN, MARGIN)
const INSET := 5.0

const EMPTY := Color("262c44")
const EMPTY_HI := Color("323a58")
const WELL := Color("0d1020")
const INK := Color("f2eee6")
const DIM := Color("7d82a0")

var g  ## game.gd
var hover := Vector2i(-1, -1)

var _box := StyleBoxFlat.new()
var _font: Font


static func cell_center(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


static func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = BOARD
	size = BOARD
	_font = ThemeDB.fallback_font
	_box.anti_aliasing = true
	mouse_exited.connect(func() -> void: hover = Vector2i(-1, -1))


func cell_at(pos: Vector2) -> Vector2i:
	var rel := (pos - ORIGIN) / CELL
	var c := Vector2i(int(floor(rel.x)), int(floor(rel.y)))
	return c if Rules.in_bounds(c.x, c.y) else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = cell_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := cell_at(event.position)
		if c.x >= 0:
			cell_clicked.emit(c)
			accept_event()


# -- primitives ---------------------------------------------------------------

func _rrect(r: Rect2, col: Color, radius: float, border := Color(0, 0, 0, 0), bw := 0,
		shadow := Color(0, 0, 0, 0), shadow_size := 0, shadow_off := Vector2.ZERO) -> void:
	_box.bg_color = col
	_box.draw_center = col.a > 0.0
	_box.set_corner_radius_all(int(radius))
	_box.border_color = border
	_box.set_border_width_all(bw)
	_box.shadow_color = shadow
	_box.shadow_size = shadow_size
	_box.shadow_offset = shadow_off
	draw_style_box(_box, r)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO)


static func ease_back(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)


static func owner_of(ch: String) -> String:
	if ".rRE".contains(ch):
		return "r"
	if "_bBL".contains(ch):
		return "b"
	return ""


static func is_fort(ch: String) -> bool:
	return ch == "R" or ch == "E" or ch == "B" or ch == "L"


# -- draw ---------------------------------------------------------------------

func _draw() -> void:
	if g == null or g.game == null:
		return
	var game = g.game
	var t: float = g.time
	var turn: String = game.whose_turn
	var accent: Color = g.glow_color
	# tabletop slab
	_rrect(Rect2(Vector2.ZERO, BOARD), Color("161a2c"), 22, Color(accent, 0.55), 2,
		Color(0, 0, 0, 0.5), 24, Vector2(0, 8))
	_rrect(Rect2(ORIGIN - Vector2(6, 6), Vector2(GRID + 12, GRID + 12)), WELL, 14)

	for y in N:
		for x in N:
			_draw_cell(Vector2i(x, y), game.grid[y][x], t)

	_draw_targets(game, turn, t)

	# forts first (pawns may hop over them), then pawns
	for y in N:
		for x in N:
			var ch: String = game.grid[y][x]
			if is_fort(ch):
				var i := y * N + x
				_draw_fort(cell_center(Vector2i(x, y)), owner_of(ch), g.fort_t[i], t, 1.0)
	for side in ["r", "b"]:
		_draw_pawn_at(side, game, t)

	# coordinates: files a-e below, ranks 5-1 at left (original square names)
	for i in N:
		var file := Rules.K_ROWS[i]
		var rank := Rules.K_COLS[i]
		draw_string(_font, Vector2(ORIGIN.x + i * CELL, BOARD.y - 9), file, HORIZONTAL_ALIGNMENT_CENTER,
			CELL, 15, DIM)
		draw_string(_font, Vector2(4, ORIGIN.y + i * CELL + CELL * 0.5 + 6), rank, HORIZONTAL_ALIGNMENT_CENTER,
			MARGIN - 8, 15, DIM)


func _draw_cell(c: Vector2i, ch: String, t: float) -> void:
	var i := c.y * N + c.x
	var r := cell_rect(c).grow(-INSET)
	var side := owner_of(ch)
	# empty tile with a soft top light
	_rrect(r, EMPTY, 12, Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0.35), 3, Vector2(0, 3))
	_rrect(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, 3)), Color(EMPTY_HI, 0.8), 2)
	if side == "":
		draw_circle(r.get_center(), 3.0, Color(DIM, 0.18))
		return
	var ct: float = g.claim_t[i]
	var from: String = g.claim_from[i]
	if ct < 1.0 and from != "" and from != side:
		_draw_land(r, from, 1.0, t, c)  # captured: old colour shrinks under the new
	var k := ease_back(ct) if ct < 1.0 else 1.0
	_draw_land(r, side, k, t, c)
	if ct < 1.0:
		# claim ring expanding out of the tile
		var ring := r.grow(18.0 * ct)
		_rrect(ring, Color(0, 0, 0, 0), 14, Color(g.side_color(side).lightened(0.4), 1.0 - ct), 3)


func _draw_land(r: Rect2, side: String, k: float, t: float, c: Vector2i) -> void:
	if k <= 0.01:
		return
	var rr := Rect2(r.get_center() - r.size * 0.5 * k, r.size * k)
	var base: Color = g.land_color(side)
	var hi: Color = g.side_color(side)
	_rrect(rr, base, 12 * k, Color(hi, 0.55), 2)
	# woven field pattern: two staggered rows of soft diamonds
	if k >= 0.95:
		var ph := 0.5 + 0.5 * sin(t * 1.6 + (c.x + c.y) * 0.8)
		var cc := rr.get_center()
		for d in [Vector2(-22, -18), Vector2(22, -18), Vector2(0, 0), Vector2(-22, 18), Vector2(22, 18)]:
			var p: Vector2 = cc + d
			var s := 4.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0),
				p + Vector2(0, s), p + Vector2(-s, 0)]), Color(hi, 0.16 + 0.08 * ph))
		_rrect(Rect2(rr.position + Vector2(8, 5), Vector2(rr.size.x - 16, 3)), Color(hi.lightened(0.3), 0.35), 2)


func _draw_targets(game, turn: String, t: float) -> void:
	if turn == "" or not g.interactive():
		return
	var targets: Dictionary = In.clickable_cells(game.valid_steps)
	var col: Color = g.side_color(turn)
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	var pawn := Rules.find_pawn(turn, game.grid)
	var pc := Vector2i(pawn.x, pawn.y) if not pawn.is_empty() else Vector2i(-1, -1)
	for cell in targets:
		var step: String = targets[cell]
		var r := cell_rect(cell).grow(-INSET - 3.0)
		var fort := step.to_lower() == "f"
		var hot: bool = cell == hover
		if hot:
			_rrect(r, Color(col, 0.22), 10)
		_rrect(r, Color(0, 0, 0, 0), 10, Color(col.lightened(0.25), 0.45 + 0.45 * pulse), 3)
		if fort:
			_draw_fort(cell_center(cell) + Vector2(0, -6), turn, 1.0, t, 0.35 + (0.35 if hot else 0.2) * pulse, true)
		else:
			# chevron pointing away from the pawn, at the near edge
			var dir := Vector2(cell - pc).normalized()
			var tip := cell_center(cell) - dir * (CELL * 0.30 - 4.0 * pulse)
			var side_v := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([tip + dir * 9.0, tip - dir * 5.0 + side_v * 10.0,
				tip - dir * 1.0, tip - dir * 5.0 - side_v * 10.0]), Color(col.lightened(0.3), 0.75))
			if hot:
				_draw_pawn(cell_center(cell), turn, 0.0, t, 0.45, false, false)
		var key := step.to_upper()
		draw_string(_font, r.position + Vector2(r.size.x - 22, 20), key, HORIZONTAL_ALIGNMENT_CENTER, 16, 14,
			Color(col.lightened(0.35), 0.9))


## Castle: two towers and a keep with crenels, door arch and a flag.
## rise 0..1 (build animation), alpha for ghosts.
func _draw_fort(c: Vector2, side: String, rise: float, t: float, alpha: float, ghost := false) -> void:
	var col: Color = g.side_color(side)
	var k := ease_back(rise)
	var s := CELL * 0.78
	var base_y := c.y + s * 0.34
	if not ghost:
		_ellipse(Vector2(c.x, base_y + 2), s * 0.46 * clampf(rise * 1.5, 0.0, 1.0), s * 0.10,
			Color(0, 0, 0, 0.35 * alpha))
	draw_set_transform(Vector2(c.x, base_y), 0.0, Vector2(1.0 + (1.0 - k) * 0.25, maxf(k, 0.02)))
	var body := Color(col.lightened(0.10), alpha)
	var dark := Color(col.darkened(0.35), alpha)
	var hi := Color(col.lightened(0.45), alpha)
	var tw := s * 0.22
	var th := s * 0.66
	var kw := s * 0.40
	var kh := s * 0.50
	var parts := [
		Rect2(-s * 0.46, -th, tw, th), Rect2(s * 0.46 - tw, -th, tw, th), Rect2(-kw * 0.5, -kh, kw, kh)]
	if ghost:
		for rr in parts:
			draw_rect(rr, Color(hi, alpha), false, 2.0)
	else:
		for rr in parts:
			draw_rect(rr, body)
			draw_rect(Rect2(rr.position + Vector2(rr.size.x * 0.68, 0), Vector2(rr.size.x * 0.32, rr.size.y)), dark)
			draw_rect(Rect2(rr.position, Vector2(rr.size.x, 3)), hi)
		# crenels
		var cw := tw / 3.0
		for tx in [-s * 0.46, s * 0.46 - tw]:
			for j in [0, 2]:
				draw_rect(Rect2(tx + cw * j, -th - 7, cw, 7), body)
		for j in [0, 2, 4]:
			draw_rect(Rect2(-kw * 0.5 + kw / 5.0 * j, -kh - 6, kw / 5.0, 6), body)
		# door
		draw_rect(Rect2(-6, -16, 12, 16), Color(0.05, 0.05, 0.1, alpha))
		draw_circle(Vector2(0, -16), 6, Color(0.05, 0.05, 0.1, alpha))
		# flag
		var pole := Vector2(0, -kh - 6)
		draw_line(pole, pole + Vector2(0, -18), Color(INK, alpha), 2.0)
		var wave := sin(t * 4.0 + c.x * 0.05) * 3.0
		draw_colored_polygon(PackedVector2Array([pole + Vector2(1, -18), pole + Vector2(15, -14 + wave),
			pole + Vector2(1, -10)]), Color(col.lightened(0.55), alpha))
	draw_set_transform(Vector2.ZERO)


func _draw_pawn_at(side: String, game, t: float) -> void:
	var found := Rules.find_pawn(side, game.grid)
	if found.is_empty():
		return
	var p: Vector2 = g.pawn_draw_pos(side)
	var hop: float = g.pawn_hop(side)
	var on_fort: bool = found.has_fort
	var active: bool = game.whose_turn == side and g.interactive()
	_draw_pawn(ORIGIN + (p + Vector2(0.5, 0.5)) * CELL, side, hop, t, 1.0, on_fort, active)


## Round token with a rim, top highlight and ground shadow. lift = hop height (px).
func _draw_pawn(c: Vector2, side: String, lift: float, t: float, alpha: float, on_fort: bool, active: bool) -> void:
	var col: Color = g.side_color(side)
	var rad := CELL * 0.24
	var seat := c + Vector2(0, -CELL * 0.30 if on_fort else 0.0)
	var bob := sin(t * 3.0) * 2.5 if active else 0.0
	var top := seat + Vector2(0, -lift - bob - 4.0)
	_ellipse(seat + Vector2(0, rad * 0.55), rad * (1.0 - minf(lift / 120.0, 0.4)), rad * 0.35,
		Color(0, 0, 0, 0.4 * alpha))
	if active:
		draw_arc(seat + Vector2(0, rad * 0.55), rad * 1.25, 0, TAU, 40, Color(col.lightened(0.4), 0.35 + 0.25 * sin(t * 5.0)), 2.0)
	if on_fort:
		_rrect(Rect2(seat + Vector2(-rad * 0.95, rad * 0.05), Vector2(rad * 1.9, rad * 0.6)), Color(0.05, 0.05, 0.1, 0.85 * alpha), 6)
	draw_circle(top + Vector2(0, 6), rad, Color(col.darkened(0.45), alpha))
	draw_circle(top, rad, Color(col, alpha))
	draw_arc(top, rad * 0.68, 0, TAU, 32, Color(col.lightened(0.35), alpha), 3.0)
	draw_circle(top, rad * 0.30, Color(INK, 0.9 * alpha))
	draw_circle(top + Vector2(-rad * 0.38, -rad * 0.42), rad * 0.18, Color(1, 1, 1, 0.35 * alpha))
