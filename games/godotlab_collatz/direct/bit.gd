extends Sprite2D
## Port of godotlab/collatz/bit.gd: a clickable bit.
## Frames of bit.svg: 0 = dark (0), 1 = light (1), 2 = faded (unset).
## A click (on release) sets an unset bit to 1, otherwise flips it.

signal toggled(bit: Sprite2D)


func _ready() -> void:
	get_node("Area2D").input_event.connect(_on_Area2D_input_event)


func _on_Area2D_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and not event.pressed):
		frame = 1 if frame == 2 else 1 - frame
		toggled.emit(self)
