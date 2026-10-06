extends Node2D
## Game1.drawPreview: the level's physics shapes drawn flat at 1/3 scale, in
## dark green (0x042105) with light green outlines (0x8CE796). The original drew
## the physaxe world with phx.FlashDraw. This draws the same shapes from the
## parsed SVG: walls, doors, spinners, crates, fuses, and each pocket as its
## 15px circle plus the 60x60 debug "zone" square.

const Levels := preload("res://games/shep/direct/shep_levels.gd")
const FILL := Color("#042105")
const LINE := Color("#8CE796")

var level: Dictionary = {}


func show_level(n: int) -> void:
	level = Levels.parse_level(n)
	queue_redraw()


func _draw() -> void:
	if level.is_empty():
		return
	for it in level["items"]:
		match it["kind"]:
			Levels.WALL_RECT, Levels.DOOR:
				_rect(it["rect"])
			Levels.WALL_POLY, Levels.FLOATER:
				var pts := PackedVector2Array()
				for p in it["points"]:
					pts.append(p + it["center"])
				_poly(pts)
			Levels.SPINNER:
				var s: Vector2 = Levels.SPINNER_SIZE
				if it["horizontal"]:
					s = Vector2(s.y, s.x)
				_rect(Rect2(it["pos"] - s / 2.0, s))
			Levels.POCKET:
				var z := Levels.POCKET_ZONE
				_rect(Rect2(it["pos"] - Vector2(z, z) / 2.0, Vector2(z, z)))
				_circle(it["pos"], Levels.POCKET_RADIUS)
			Levels.FUSE:
				_circle(it["pos"], Levels.FUSE_RADIUS)


func _rect(r: Rect2) -> void:
	draw_rect(r, FILL)
	draw_rect(r, LINE, false, 1.0)


func _poly(pts: PackedVector2Array) -> void:
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		draw_colored_polygon(pts, FILL)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, LINE, 1.0)


func _circle(c: Vector2, r: float) -> void:
	draw_circle(c, r, FILL)
	draw_arc(c, r, 0, TAU, 24, LINE, 1.0)
