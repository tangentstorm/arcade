extends RefCounted
## KeyboardTestBuggy: a line-for-line port of
## course/w02_InvaderSketch/keyboard_tests/KeyboardTestBuggy/KeboardTestBuggy.pde (first copy).
## It's meant to light up WASD (plus Dvorak ,AOE) on the left and the arrow keys on the right.
## But the original's `switch(key) { ... case(CODED): switch(keyCode) ... }` never matched
## in processing-js, the runtime the sketch was published on (studio.sketchpad.cc). So only the
## left pad works and the arrow pad stays dark. The port keeps that bug on purpose
## (EMULATE_PJS_BUG); KeyboardTestWorkaround is the fix.
## Each keyPressed *and* keyReleased XOR-toggles a bit, so OS key-repeat makes a held key flicker.
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

## processing-js never took the `case(CODED)` branch, so arrow keys did nothing.
const EMULATE_PJS_BUG := true

var probe := "PROBE"   # set by the (dead) arrow branch; never displayed, as in the original

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
	match key:
		# wasd + dvorak equivalents:
		"w", "W", ",", "<": wasd ^= N
		"a", "A": wasd ^= WEST
		"s", "S", "o", "O": wasd ^= S
		"d", "D", "e", "E": wasd ^= E
		CODED:
			if EMULATE_PJS_BUG:
				return
			match key_code:
				UP:
					arrows ^= N
					probe = "probeUP"
				LEFT:
					arrows ^= WEST
					probe = "probeLeft"
				DOWN:
					arrows ^= S
					probe = "probeDown"
				RIGHT:
					arrows ^= E
					probe = "probeRight"


func _draw_key(out: Array, x: int, y: int, bit_mask: int) -> void:
	var is_down := bit_mask != 0
	out.append(["rect", Rect2(x + 2, y + 2, K_KEY_SIZE - 2, K_KEY_SIZE - 2),
		Color8(255, 255, 255) if is_down else Color8(128, 128, 128)])
