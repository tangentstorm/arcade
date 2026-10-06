extends RefCounted
## KeyboardTestWorkaround: a line-for-line port of
## course/w02_InvaderSketch/keyboard_tests/KeyboardTestWorkaround/KeyboardTestWorkaround.pde.
## Two 4-key pads: WASD (plus Dvorak ,AOE) on the left and the arrow keys on the right. A key
## lights up while it's held. Each keyPressed *and* keyReleased XOR-toggles the key's bit, so
## OS key-repeat (extra keyPressed events) makes a held key flicker. That's the original's
## behaviour, and the reason the HashMap version exists.
## This version fixes the Buggy one by testing `key == CODED` with an `if` instead of a
## `switch(key) case CODED`.
## Keys arrive as Processing (key, keyCode) pairs; key is CODED for arrows/modifiers.

const W := 300
const H := 300
const FPS := 60
const CODED := "CODED"
const UP := 38
const DOWN := 40
const LEFT := 37
const RIGHT := 39

const N := 1
const S := 2
const E := 4
const WEST := 8   # `W` in the original; renamed so it doesn't shadow the width.

const K_KEY_SIZE := 25

var arrows := 0
var wasd := 0


func step() -> void:
	pass


func render() -> Array:
	var out: Array = [["bg", Color.BLACK]]
	# wasd on the left:
	_draw_key(out, 50, 100, wasd & N)
	_draw_key(out, 25, 125, wasd & WEST)
	_draw_key(out, 50, 125, wasd & S)
	_draw_key(out, 75, 125, wasd & E)
	# arrows on the right:
	_draw_key(out, 225, 100, arrows & N)
	_draw_key(out, 200, 125, arrows & WEST)
	_draw_key(out, 225, 125, arrows & S)
	_draw_key(out, 250, 125, arrows & E)
	return out


func key_pressed(key: String, key_code: int) -> void:
	_toggle_bits(key, key_code)


func key_released(key: String, key_code: int) -> void:
	_toggle_bits(key, key_code)


func _toggle_bits(key: String, key_code: int) -> void:
	if key == CODED:
		match key_code:
			UP: arrows ^= N
			LEFT: arrows ^= WEST
			DOWN: arrows ^= S
			RIGHT: arrows ^= E
	else:
		match key:
			# wasd + dvorak equivalents:
			"w", "W", ",", "<": wasd ^= N
			"a", "A": wasd ^= WEST
			"s", "S", "o", "O": wasd ^= S
			"d", "D", "e", "E": wasd ^= E


func _draw_key(out: Array, x: int, y: int, bit_mask: int) -> void:
	var is_down := bit_mask != 0
	out.append(["rect", Rect2(x + 2, y + 2, K_KEY_SIZE - 2, K_KEY_SIZE - 2),
		Color8(255, 255, 255) if is_down else Color8(128, 128, 128)])
