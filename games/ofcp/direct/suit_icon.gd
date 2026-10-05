extends Control
## Draws a card suit pip with primitives, so no font needs the ♥♦♣♠ glyphs
## (Godot's built-in web font lacks them).

var suit := "s"
var color := Color.BLACK


func _init(p_suit: String = "s", p_color: Color = Color.BLACK) -> void:
	suit = p_suit
	color = p_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match suit:
		"d":
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.0), p.call(0.88, 0.5),
				p.call(0.5, 1.0), p.call(0.12, 0.5)]), color)
		"h":
			draw_circle(p.call(0.29, 0.32), s * 0.25, color)
			draw_circle(p.call(0.71, 0.32), s * 0.25, color)
			draw_colored_polygon(PackedVector2Array([p.call(0.05, 0.42), p.call(0.95, 0.42),
				p.call(0.5, 0.98)]), color)
		"s":
			draw_circle(p.call(0.29, 0.58), s * 0.23, color)
			draw_circle(p.call(0.71, 0.58), s * 0.23, color)
			draw_colored_polygon(PackedVector2Array([p.call(0.07, 0.5), p.call(0.5, 0.0),
				p.call(0.93, 0.5)]), color)
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.6), p.call(0.68, 1.0),
				p.call(0.32, 1.0)]), color)
		"c":
			draw_circle(p.call(0.5, 0.26), s * 0.22, color)
			draw_circle(p.call(0.26, 0.6), s * 0.22, color)
			draw_circle(p.call(0.74, 0.6), s * 0.22, color)
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.45), p.call(0.68, 1.0),
				p.call(0.32, 1.0)]), color)
