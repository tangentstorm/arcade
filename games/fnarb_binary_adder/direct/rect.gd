extends ColorRect
## fnarbmlyx demos/binary_adder/Rect.gd (no `@tool`/`class_name`).

@export var line_color : Color = Color.BLACK
@export var line_width  : float = 1.0

func _ready():
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), line_color, false, line_width)
