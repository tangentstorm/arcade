@tool
extends Node2D
## Port of godotlab/collatz/register.gd: a red bar `width` bits wide (32 px per bit).

@export var width: int = 8:
	set(v):
		width = v
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, width * 32, 32), Color.RED, true)
