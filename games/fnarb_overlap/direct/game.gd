extends Control
## Fnarbmlyx Overlap Demo: Direct edition.
## fnarbmlyx `demos/overlap_demo` (Godot 4.1, 2023) running unchanged in its native 1920×1080 viewport.
## The demo sits in a 1920×1080 SubViewport, so get_viewport() sizes and mouse positions match
## the original window exactly. This script scales that stage to fit the arcade window.
## Esc is handled globally by the PauseOverlay autoload.

const STAGE := Vector2(1920, 1080)

@onready var _stage: SubViewportContainer = %Stage


func _ready() -> void:
	_stage.size = STAGE
	resized.connect(_fit_stage)
	_fit_stage()


func _fit_stage() -> void:
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	_stage.scale = Vector2(s, s)
	_stage.position = ((size - STAGE * s) * 0.5).round()
