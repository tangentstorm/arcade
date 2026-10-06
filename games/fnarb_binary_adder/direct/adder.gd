extends Control
## fnarbmlyx demos/binary_adder/Adder.gd. Changes from the original:
## - `await _await[0].await[1]` (a broken Godot 3 → 4 conversion of `yield(obj, signal)`) is now
##   `await Signal(_await[0], _await[1])`. The 4.1 original died on the first step.
## - no `@tool`, and the debug `print`s are removed.
## - Carriage column position is owned by the scene/script, not the `init` animation. In Godot 4
##   AnimationMixer, leaving an anim that keyed `carriage:position` reset it to (0,0) and the
##   gold highlight sat in the wrong place instead of over the bits being added.

@onready var _script = make_script()

const O : Color = Color('222')
const I : Color = Color('eee')

## Top-left of the LSB column (bit0): cursor local (32,40) then covers a/b at x=800.
const CARRIAGE_ORIGIN := Vector2(768, 280)

@export var a : int = 0: set = set_a
@export var b : int = 1: set = set_b

@onready var sm = $AnimationTree['parameters/playback']

func set_a(val):
	a = val
	if is_inside_tree(): $a.bits = a

func set_b(val):
	b = val;
	if is_inside_tree(): $b.bits = b

func _ready():
	# Keep column origin stable across AnimationTree state changes (see file header).
	$carriage.position = CARRIAGE_ORIGIN
	$AnimationTree.active = true
	play()

func set_bit(reg, i, val):
	var np = reg + '/bit' + str(i)
	return ['sync',
		['set', np, 'color', I if val else O],
		['set', np, 'line_color', Color.BLACK]]

func make_script():
	var res = [
		['sync',
			['set', 'a', 'bits', a],
			['set', 'b', 'bits', b],
			['travel', 'add_2']]]
	var ci = 0
	for i in range(4):
		var ai = 1 & (a >> i)
		var bi = 1 & (b >> i)
		var ri = 1 & (ai + bi + ci)
		ci = (2 & (ai + bi + ci)) >> 1
		if i: res.append(['sync',  ['travel', 'add_3_result']])  # ['move_carriage_left']
		else: res.append(['travel', 'add_2_result'])
		res.append_array([set_bit('r', i, ri), ['travel', 'carry'], set_bit('c', i+1, ci)])
		if i < 3: res.append_array([ ['travel', 'descend'], ['travel', 'add_3'] ])
	return res


var _await # [object, signal] pair for yield
func play():
	for step in _script:
		do_step(step)
		await Signal(_await[0], _await[1])


func do_step(step):
	_await = [$Timer,'timeout']
	# print(step)
	match step.pop_front():
		'sync':
			for s in step: do_step(s)
		'set': callv('set_node_prop', step)
		'travel':
			sm.travel(step[0])
		'move_carriage_left': move_carriage_left()

func set_node_prop(nodepath, prop, value):
	get_node(nodepath).set(prop, value)

func move_carriage_left():
	$carriage.position += 32 * Vector2.LEFT
