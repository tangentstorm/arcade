extends RefCounted
## KeyboardTestHashMap: a line-for-line port of
## course/w02_InvaderSketch/keyboard_tests/KeyboardTestHashMap/KeyboardTestHashMap.pde.
## Tracks every key in a HashMap (pressed + just-pressed), so key-repeat no longer flickers.
## Three pads: WASD/Dvorak on the left (isAnyDown), "either" in the middle (arrows OR letters),
## and the arrows on the right (isKeyDown). Space picks a random background colour (justPressed).
## Keys arrive as Processing (key, keyCode) pairs; key is CODED for arrows/modifiers.
## Java's HashMap keeps `char` and `int` keys apart. Here chars are Strings and codes are ints.
## The char tables are case-sensitive, as in the original. North is only 'W', ',' and '<', so a
## plain lowercase `w` does NOT light north.

const W := 300
const H := 300
const FPS := 60
const CODED := "CODED"
const UP := 38
const DOWN := 40
const LEFT := 37
const RIGHT := 39

const WASD_N := ["W", ",", "<"]
const WASD_W := ["A", "a"]
const WASD_S := ["S", "s", "O", "o"]
const WASD_E := ["D", "d", "E", "e"]

const K_KEY_SIZE := 25

var pressed_keys := {}
var just_pressed_keys := {}
var bg_color := Color(0, 0, 0)
var rng := RandomNumberGenerator.new()
var _frame: Array = []


func _init() -> void:
	rng.randomize()


func key_pressed(key: String, key_code: int) -> void:
	_set_key_down(key, key_code, true)


func key_released(key: String, key_code: int) -> void:
	_set_key_down(key, key_code, null)


func is_key_down(code) -> bool:
	return pressed_keys.get(code) != null


func just_pressed(code) -> bool:
	return just_pressed_keys.get(code) != null


func _set_key_down(key: String, key_code: int, value) -> void:
	var k = key_code if key == CODED else key
	just_pressed_keys[k] = null if is_key_down(k) else true
	pressed_keys[k] = value


func is_any_down(keys: Array) -> bool:
	for k in keys:
		if is_key_down(k):
			return true
	return false


## draw(): the frame is built here (background is painted *before* Space changes the colour,
## so the new colour shows one frame later), then justPressed is cleared.
func step() -> void:
	var input_n := is_key_down(UP) or is_any_down(WASD_N)
	var input_w := is_key_down(LEFT) or is_any_down(WASD_W)
	var input_s := is_key_down(DOWN) or is_any_down(WASD_S)
	var input_e := is_key_down(RIGHT) or is_any_down(WASD_E)

	_frame = [["bg", bg_color]]

	if just_pressed(" "):
		# color(random(255), random(255), random(255)): floats truncate to 0..254
		bg_color = Color8(int(rng.randf() * 255), int(rng.randf() * 255), int(rng.randf() * 255))

	# wasd on the left:
	_draw_key(50, 75, is_any_down(WASD_N))
	_draw_key(25, 100, is_any_down(WASD_W))
	_draw_key(50, 100, is_any_down(WASD_S))
	_draw_key(75, 100, is_any_down(WASD_E))
	# "either" in the middle
	_draw_key(135, 175, input_n)
	_draw_key(110, 200, input_w)
	_draw_key(135, 200, input_s)
	_draw_key(160, 200, input_e)
	# arrows on the right:
	_draw_key(225, 75, is_key_down(UP))
	_draw_key(200, 100, is_key_down(LEFT))
	_draw_key(225, 100, is_key_down(DOWN))
	_draw_key(250, 100, is_key_down(RIGHT))

	just_pressed_keys.clear()


func render() -> Array:
	if _frame.is_empty():
		step()
	return _frame


func _draw_key(x: int, y: int, is_down: bool) -> void:
	_frame.append(["rect", Rect2(x + 2, y + 2, K_KEY_SIZE - 2, K_KEY_SIZE - 2),
		Color8(255, 255, 255) if is_down else Color8(128, 128, 128)])
