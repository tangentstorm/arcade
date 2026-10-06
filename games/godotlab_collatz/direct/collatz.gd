extends Node2D
## godotlab/collatz Direct edition.
##
## The original (collatz.gd/collatz.tscn, 2020) only got as far as a red
## Register bar, a clickable bit (bit.tscn) and an unfinished "adder". This
## port wires `width` of those clickable bits onto the Register and finishes the
## obvious intent: a Collatz stepper on a bit register.
##   even n -> n >> 1        odd n -> 3n + 1  ( = (n << 1) + n + 1 )
## Click bits to enter n, Space/Enter steps, R runs to 1, C clears.

const BIT_SCENE := preload("res://games/godotlab_collatz/direct/bit.tscn")
const RUN_DELAY := 0.25

@onready var register: Node2D = $World/Register
@onready var info: Label = %Info
@onready var trail: Label = %Trail

var bits: Array[Sprite2D] = []   ## bits[0] is the least significant bit (rightmost)
var steps := 0
var peak := 0
var history: Array[int] = []
var running := false
var _run_t := 0.0
var _had_picking := false


func _ready() -> void:
	# Godot 4 turns physics picking off by default; bit.gd relies on Area2D input_event.
	_had_picking = get_viewport().physics_object_picking
	get_viewport().physics_object_picking = true
	var w: int = register.width
	for i in w:
		var b: Sprite2D = BIT_SCENE.instantiate()
		b.scale = Vector2(0.5, 0.5)  # 64 px svg frame -> one 32 px register cell
		b.position = Vector2((w - 1 - i) * 32 + 16, 16)
		b.toggled.connect(_on_bit_toggled)
		register.add_child(b)
		bits.append(b)
	%StepButton.pressed.connect(step)
	%RunButton.pressed.connect(toggle_run)
	%ClearButton.pressed.connect(clear)
	_restart_from_bits()


func _exit_tree() -> void:
	get_viewport().physics_object_picking = _had_picking


## Current register value; unset (faded) bits read as 0.
func value() -> int:
	var n := 0
	for i in bits.size():
		if bits[i].frame == 1:
			n |= 1 << i
	return n


func set_value(n: int) -> void:
	for i in bits.size():
		bits[i].frame = (n >> i) & 1


func max_value() -> int:
	return (1 << bits.size()) - 1


func clear() -> void:
	running = false
	for b in bits:
		b.frame = 2
	_restart_from_bits()


func toggle_run() -> void:
	running = not running and value() > 1
	_run_t = 0.0
	_refresh()


## One Collatz step. Returns false when there's nothing to do (n <= 1 or overflow).
func step() -> bool:
	var n := value()
	if n <= 1:
		running = false
		_refresh()
		return false
	var nxt := n >> 1 if n % 2 == 0 else 3 * n + 1
	if nxt > max_value():
		running = false
		_refresh("overflow: 3·%d+1 = %d needs more than %d bits" % [n, nxt, bits.size()])
		return false
	set_value(nxt)
	steps += 1
	peak = maxi(peak, nxt)
	history.append(nxt)
	if nxt == 1:
		running = false
	_refresh()
	return true


func _on_bit_toggled(_b: Sprite2D) -> void:
	running = false
	_restart_from_bits()


func _restart_from_bits() -> void:
	var n := value()
	steps = 0
	peak = n
	history.clear()
	if n > 0:
		history.append(n)
	_refresh()


func _refresh(extra := "") -> void:
	var n := value()
	var msg := "n = %d   steps = %d   peak = %d" % [n, steps, peak]
	if n == 0:
		msg = "Click the bits to enter a number."
	elif n == 1 and steps > 0:
		msg += "   — reached 1!"
	if extra != "":
		msg += "\n" + extra
	info.text = msg
	var shown := history.slice(maxi(0, history.size() - 24))
	trail.text = ("… " if history.size() > 24 else "") + " → ".join(shown.map(func(v): return str(v)))
	%RunButton.text = "Stop" if running else "Run"


func _process(delta: float) -> void:
	if not running:
		return
	_run_t += delta
	if _run_t >= RUN_DELAY:
		_run_t = 0.0
		step()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT:
			step()
		KEY_R:
			toggle_run()
		KEY_C, KEY_BACKSPACE:
			clear()
		_:
			return
	get_viewport().set_input_as_handled()
