extends Control
## 5x5 Terratri board: draws a game snapshot and reports cell clicks.
## No rules here; valid targets come from the snapshot's valid_steps.

signal cell_clicked(cell: Vector2i)

const Rules := preload("res://games/terratri/direct/terratri_rules.gd")
const Input2 := preload("res://games/terratri/direct/terratri_input.gd")
const P := preload("res://games/terratri/direct/palette.gd")

var game: RefCounted:
	set(v):
		game = v
		queue_redraw()
var hover := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	mouse_exited.connect(func() -> void:
		hover = Vector2i(-1, -1)
		queue_redraw())


## Integer cell size + top-left of the grid (room left for rank/file labels).
func layout() -> Dictionary:
	var label_room := 28.0
	var avail := minf(size.x - label_room * 2.0, size.y - label_room * 2.0)
	var cell := maxi(16, int(floor(avail / Rules.SIZE)))
	var grid_px := cell * Rules.SIZE
	var origin := Vector2(floor((size.x - grid_px) / 2.0), floor((size.y - grid_px) / 2.0))
	return {"cell": cell, "origin": origin}


func cell_at(pos: Vector2) -> Vector2i:
	var l := layout()
	var rel: Vector2 = (pos - l.origin) / float(l.cell)
	var c := Vector2i(int(floor(rel.x)), int(floor(rel.y)))
	return c if Rules.in_bounds(c.x, c.y) else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != hover:
			hover = c
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := cell_at(event.position)
		if c.x >= 0:
			cell_clicked.emit(c)
			accept_event()


func _draw() -> void:
	if game == null:
		return
	var l := layout()
	var cell: int = l.cell
	var o: Vector2 = l.origin
	var font := get_theme_default_font()
	var fs := maxi(12, cell / 6)
	var gap := maxi(2, cell / 24)
	draw_rect(Rect2(o - Vector2(gap, gap), Vector2(cell * Rules.SIZE + gap * 2, cell * Rules.SIZE + gap * 2)), P.LINE)

	var targets: Dictionary = Input2.clickable_cells(game.valid_steps)
	var turn: String = game.whose_turn
	for y in Rules.SIZE:
		for x in Rules.SIZE:
			var r := Rect2(o + Vector2(x * cell + gap, y * cell + gap), Vector2(cell - gap * 2, cell - gap * 2))
			_draw_cell(r, game.grid[y][x])
			var c := Vector2i(x, y)
			if targets.has(c):
				var col := P.side_color(turn)
				if c == hover:
					draw_rect(r, Color(col, 0.28))
				_outline(r.grow(-gap), col, maxi(2, cell / 20))
				var key: String = String(targets[c]).to_upper()
				var ks := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
				draw_string(font, r.position + Vector2(r.size.x - ks.x - gap * 3, fs + gap * 2), key,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			elif c == hover:
				_outline(r, Color(P.DIM, 0.5), 1)

	# file letters (a-e) below, rank digits (5-1) at left: original square names
	for i in Rules.SIZE:
		var file := Rules.K_ROWS[i]
		var fsz := font.get_string_size(file, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, o + Vector2(i * cell + (cell - fsz.x) / 2.0, cell * Rules.SIZE + fs + gap * 3), file,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, P.DIM)
		var rank := Rules.K_COLS[i]
		draw_string(font, o + Vector2(-fs - gap * 2, i * cell + (cell + fs) / 2.0 - 2), rank,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, P.DIM)


func _draw_cell(r: Rect2, ch: String) -> void:
	var side := ""
	if ".rRE".contains(ch): side = "r"
	elif "_bBL".contains(ch): side = "b"
	draw_rect(r, P.CELL if side == "" else P.land_color(side))
	if ch == "R" or ch == "E" or ch == "B" or ch == "L":
		_draw_fort(r, P.side_color(side))
	if ch == "r" or ch == "E" or ch == "b" or ch == "L":
		_draw_pawn(r, side, ch == "E" or ch == "L")


## Fort: a blocky keep with three crenels, snapped to whole pixels.
func _draw_fort(r: Rect2, col: Color) -> void:
	var u := floorf(r.size.x / 10.0)
	var base := Rect2(r.position + Vector2(u, u * 3), Vector2(r.size.x - u * 2, r.size.y - u * 4))
	draw_rect(base, col)
	var cw := floorf((base.size.x) / 5.0)
	for i in [0, 2, 4]:
		draw_rect(Rect2(Vector2(base.position.x + cw * i, r.position.y + u), Vector2(cw, u * 2)), col)
	draw_rect(Rect2(base.position + Vector2(base.size.x / 2.0 - u, base.size.y - u * 3), Vector2(u * 2, u * 3)),
		col.darkened(0.55))


## Pawn: a square token; on a fort it sits on a dark plinth so it stays readable.
func _draw_pawn(r: Rect2, side: String, on_fort: bool) -> void:
	var u := floorf(r.size.x / 10.0)
	var t := Rect2(r.position + Vector2(u * 3, u * 3), Vector2(u * 4, u * 4))
	draw_rect(t.grow(u if on_fort else u * 0.5), P.LINE)
	draw_rect(t, P.TEXT if on_fort else P.side_color(side).lightened(0.25))
	draw_rect(t.grow(-u), P.side_color(side))


func _outline(r: Rect2, col: Color, w: int) -> void:
	draw_rect(r, col, false, w)
