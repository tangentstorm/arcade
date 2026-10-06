extends Control
## Five fort slots for one side: placed (solid), banked (hatched), supply (outline).

const P := preload("res://games/terratri/direct/palette.gd")

var side := "r"
var placed := 0:
	set(v): placed = v; queue_redraw()
var banked := 0:
	set(v): banked = v; queue_redraw()


func _draw() -> void:
	var col := P.side_color(side)
	var s := floorf(minf(size.y, (size.x - 4 * 8) / 5.0))
	for i in 5:
		var r := Rect2(Vector2(i * (s + 8), 0), Vector2(s, s))
		if i < placed:
			draw_rect(r, col)
		elif i < placed + banked:
			draw_rect(r, P.land_color(side))
			draw_rect(r.grow(-s / 4.0), col)
		else:
			draw_rect(r, P.CELL)
			draw_rect(r, P.DIM, false, 2)
