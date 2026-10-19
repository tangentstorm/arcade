class_name TetraminexTimedFx
extends Node
## Timed effects from the SWF, shared by Direct and Enhanced. All driven by
## _process delta (no Timers / Tweens), so they pause with the arcade overlay.
##   - teletype talk text   (GsTeleType: about one char per frame at 30 fps)
##   - fade curtain         (FadeToBlackScript fast: 15 steps, 2 per 0.10 s tick)
##   - teleporter glow loop (Teleporter "glow" [1,2,3,4,3,2] at 8 fps)

signal faded_out

const TICK := 0.10
const FADE_STEPS := 15
const FADE_FAST := 2
const TYPE_CPS := 30.0
const GLOW_FPS := 8.0
const GLOW_FRAMES := [1, 2, 3, 4, 3, 2]

var curtain := ColorRect.new()
var label: Label
var hint: Control
var glow: Sprite2D  ## texture must be an AtlasTexture over Teleporter.png
var fade_step := 0
var fade_dir := 0  ## -1 fading in, +1 fading out, 0 idle

var _fade_acc := 0.0
var _type_t := 0.0
var _glow_t := 0.0


func setup(world: Node, size: Vector2, talk_label: Label, talk_hint: Control) -> void:
	curtain.size = size
	curtain.color = Color(0, 0, 0, 0)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.z_index = 100
	world.add_child(curtain)
	label = talk_label
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	hint = talk_hint


func fade_in() -> void:
	_start_fade(FADE_STEPS, -1)


func fade_out() -> void:
	_start_fade(fade_step, 1)


func fading_out() -> bool:
	return fade_dir > 0


func type_text(text: String) -> void:
	label.text = text
	label.visible_characters = 0
	hint.modulate.a = 0.0
	_type_t = 0.0


func typing() -> bool:
	return label.visible_characters >= 0


func skip_typing() -> void:
	label.visible_characters = -1
	hint.modulate.a = 1.0


func _start_fade(step: int, dir: int) -> void:
	fade_step = step
	fade_dir = dir
	_fade_acc = 0.0
	curtain.color.a = float(fade_step) / FADE_STEPS


func _process(delta: float) -> void:
	if typing():
		_type_t += delta
		var n := int(_type_t * TYPE_CPS)
		if n >= label.text.length():
			skip_typing()
		else:
			label.visible_characters = n
	if is_instance_valid(glow):
		_glow_t += delta
		var f: int = GLOW_FRAMES[int(_glow_t * GLOW_FPS) % GLOW_FRAMES.size()]
		(glow.texture as AtlasTexture).region.position.x = f * glow.texture.get_height()
	if fade_dir != 0:
		_fade_acc += delta
		while _fade_acc >= TICK and fade_dir != 0:
			_fade_acc -= TICK
			fade_step = clampi(fade_step + fade_dir * FADE_FAST, 0, FADE_STEPS)
			curtain.color.a = float(fade_step) / FADE_STEPS
			if fade_step == 0 or fade_step == FADE_STEPS:
				var was_out := fade_dir > 0
				fade_dir = 0
				if was_out:
					faded_out.emit()
