extends RefCounted
## typing.deck rules — pure state, no UI.
## Source of truth: Decker game.0 (WIN_WORDS=15, LVL_WORDS=5).

const Words := preload("res://games/typing/direct/words.gd")

const STAGE_W := 512
const STAGE_H := 342
const WIN_WORDS := 15
const LVL_WORDS := 5
const START_WORD := "go"
const WORD_MIN_X := 24
const WORD_W := 160
const BOTTOM_Y := 280
const NEW_WORD_DELAY := 0.2

enum Mode { HOME, PLAY, WON }

var mode: int = Mode.HOME
var word_list_name := "letters"
var layout_name := "qwerty"
var words: PackedStringArray = PackedStringArray()

var score := 0
var speed := 0
var paused := false
var word := START_WORD
var progress := 0
var word_x := 220.0
var word_y := 130.0
var falling := false
var show_welcome := true

var flash_kind := ""
var flash_msg := ""
var flash_ttl := 0.0

var _rng := RandomNumberGenerator.new()
var _step_acc := 0.0
var _new_word_wait := -1.0

const NOPE_MSGS := ["try again", "whoops", "nope", "sorry", "nah", "wrong"]
const FAIL_MSGS := [">8(", "FAIL"]


func _init() -> void:
	_rng.randomize()
	words = Words.word_list(word_list_name)


func set_word_list(name: String) -> void:
	word_list_name = name
	words = Words.word_list(name)


func set_layout(name: String) -> void:
	layout_name = name


func start_play() -> void:
	mode = Mode.PLAY
	score = 0
	speed = 0
	paused = false
	falling = false
	show_welcome = true
	flash_kind = ""
	flash_msg = ""
	flash_ttl = 0.0
	_step_acc = 0.0
	_new_word_wait = -1.0
	word = START_WORD
	progress = 0
	word_x = 220.0
	word_y = 130.0


func go_home() -> void:
	mode = Mode.HOME
	flash_kind = ""
	flash_msg = ""
	flash_ttl = 0.0


func toggle_pause() -> void:
	if mode != Mode.PLAY:
		return
	paused = not paused


func type_key(ch: String) -> void:
	if mode != Mode.PLAY or paused:
		return
	if _new_word_wait >= 0.0:
		return
	if ch.length() != 1:
		return
	ch = ch.to_lower()
	if ch < "a" or ch > "z":
		return
	if progress >= word.length():
		return
	var expect := word.substr(progress, 1)
	if ch == expect:
		progress += 1
		if progress >= word.length():
			_on_good()
	else:
		_flash("nope", NOPE_MSGS[_rng.randi() % NOPE_MSGS.size()])


func _on_good() -> void:
	score += 1
	var old_speed := speed
	if score >= WIN_WORDS:
		mode = Mode.WON
		_flash("win", "you won!")
		_new_word_wait = -1.0
		return
	if score % LVL_WORDS == 0:
		speed += 1
		_flash("level", "level %d" % speed)
	# After first word: hide welcome and begin falling.
	# Decker keeps speed at 0 until the first level-up; we start fall at
	# effective speed 1 so the loop matches the poem (words fall).
	if old_speed == 0:
		show_welcome = false
		falling = true
		if speed == 0:
			speed = 1
	_new_word_wait = NEW_WORD_DELAY


func _new_word() -> void:
	if words.is_empty():
		word = "a"
	else:
		word = words[_rng.randi() % words.size()]
	progress = 0
	var max_x := float(STAGE_W - WORD_W)
	word_x = float(_rng.randi_range(WORD_MIN_X, maxi(WORD_MIN_X, int(max_x))))
	word_y = 0.0


func _flash(kind: String, msg: String) -> void:
	flash_kind = kind
	flash_msg = msg
	flash_ttl = 0.6


func tick(delta: float) -> void:
	if flash_ttl > 0.0:
		flash_ttl = maxf(0.0, flash_ttl - delta)
		if flash_ttl <= 0.0 and flash_kind != "win":
			flash_kind = ""
			flash_msg = ""
	if mode != Mode.PLAY:
		return
	if _new_word_wait >= 0.0:
		_new_word_wait -= delta
		if _new_word_wait <= 0.0:
			_new_word_wait = -1.0
			_new_word()
		return
	if paused or not falling or speed <= 0:
		return
	# Decker: timer every 100ms/speed → y += 1
	var interval := 0.1 / float(speed)
	_step_acc += delta
	while _step_acc >= interval:
		_step_acc -= interval
		word_y += 1.0
		if word_y >= BOTTOM_Y:
			_on_fail()
			break


func _on_fail() -> void:
	_flash("fail", FAIL_MSGS[_rng.randi() % FAIL_MSGS.size()])
	_new_word()


func force_word(w: String, x: float = 220.0, y: float = 0.0) -> void:
	word = w
	progress = 0
	word_x = x
	word_y = y
	_new_word_wait = -1.0
