extends Control
## Kiwi Soccer Direct — Godot 4 port of Team Trailblazer's PyWeek #1 entry
## (sabren/blaze pyweek/, Aug 2005; pygame + pyODE). 640x480 stage, letterboxed.
## States follow states.py: Menu -> LevelList -> Game, plus Help, Credits, Scores.
## Esc is left for the arcade PauseOverlay; X quits the game state like the original.

const Logic := preload("res://games/kiwi_soccer/direct/kiwi_logic.gd")
const IMG_MENU := preload("res://games/kiwi_soccer/direct/img/menu_img.png")
const IMG_HELP := preload("res://games/kiwi_soccer/direct/img/help.png")
const IMG_CREDITS := preload("res://games/kiwi_soccer/direct/img/credits.png")
const IMG_SCORES := preload("res://games/kiwi_soccer/direct/img/high_scores.png")
const IMG_GAME := preload("res://games/kiwi_soccer/direct/img/game.png")
const IMG_BACK := preload("res://games/kiwi_soccer/direct/img/outside-back.png")
const IMG_STATUS_TXT := preload("res://games/kiwi_soccer/direct/img/statustxt.png")
const IMG_KIWI_LEFT := preload("res://games/kiwi_soccer/direct/img/kiwi_left.png")
const IMG_KIWI_RIGHT := preload("res://games/kiwi_soccer/direct/img/kiwi_right.png")
const IMG_SOCCER := preload("res://games/kiwi_soccer/direct/img/soccer.png")  ## IMAGE.SOCCER
const FONT := preload("res://games/kiwi_soccer/direct/freesansbold.ttf")  ## pygame Font(None, n)
const MUSIC := preload("res://games/kiwi_soccer/direct/sfx/1takeimprov.ogg")
const BIP := preload("res://games/kiwi_soccer/direct/sfx/bip.ogg")
const SCORES_PATH := "user://kiwi_soccer_scores.json"
const ROOMS: Array[String] = ["outside", "joe1"]  ## LevelList.roomList (hard-coded in states.py)

enum St { MENU, LEVELS, GAME, HELP, CREDITS, SCORES, SCORE_ENTRY }

var state := St.MENU
var selected := 0               ## LevelList.selected
var scores: Array = []          ## [[initials, score], ...] best first
var entry_score := 0            ## Scores(display, score) from the hidden 1/2 menu keys
var entry_text := ""

# Game state
var health: Logic
var controls: Logic.Controller
var world: Logic.World          ## null outside the Game state
var facing_left := false
var ticks := 0
var _acc := 0.0
var _music: AudioStreamPlayer
var _bip: AudioStreamPlayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	var reg := get_node_or_null("/root/GameRegistry")
	if reg:
		reg.fit_stage(Logic.SCREEN)
	_music = AudioStreamPlayer.new()
	var m: AudioStreamOggVorbis = MUSIC.duplicate()
	m.loop = true  # Soundtrack: music.play(-1), volume 1.0
	_music.stream = m
	add_child(_music)
	# Soundtrack starts the music at boot. A 0.1 s delay keeps a scene that is opened and
	# closed within a frame (smoke_scenes) from quitting with a live Vorbis playback.
	get_tree().create_timer(0.1).timeout.connect(_music.play)
	_bip = AudioStreamPlayer.new()
	_bip.stream = BIP
	_bip.max_polyphony = 8  # SoundManager.Play(wait=0): overlapping bips
	add_child(_bip)
	_load_scores()
	resized.connect(queue_redraw)
	call_deferred("grab_focus")


func _exit_tree() -> void:
	_music.stop()
	_bip.stop()


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo or k.keycode == KEY_ESCAPE:
		return
	if k.pressed:
		_key_down(k.keycode)
	else:
		_key_up(k.keycode)
	accept_event()


func _key_down(code: int) -> void:
	match state:
		St.MENU:
			match code:
				KEY_P: _go(St.LEVELS)
				KEY_1: _start_entry(1000)
				KEY_2: _start_entry(2000)
				KEY_H: _go(St.SCORES)
				KEY_E: _go(St.HELP)
				KEY_C: _go(St.CREDITS)
				KEY_X: _exit_to_arcade()
		St.LEVELS:
			match code:
				KEY_UP: selected = maxi(selected - 1, 0)
				KEY_DOWN: selected = mini(selected + 1, ROOMS.size() - 1)
				KEY_ENTER, KEY_KP_ENTER: _enter_level()
		St.HELP, St.CREDITS, St.SCORES:
			_go(St.MENU)  # any key: done, next None -> default Menu
		St.SCORE_ENTRY:
			_entry_key(code)
		St.GAME:
			var b := _button(code)
			if b != "":
				# Two Controllers are live in the original: the Game's own and the one
				# LevelList created and never released, so every press posts twice.
				controls.key_down(b)
				_post(b)
				_post(b)
	queue_redraw()


func _key_up(code: int) -> void:
	if state == St.GAME:
		var b := _button(code)
		if b != "":
			controls.key_up(b)


## Controller.keymap
static func _button(code: int) -> String:
	match code:
		KEY_X: return "QUIT"
		KEY_RIGHT: return "RIGHT"
		KEY_LEFT: return "LEFT"
		KEY_UP: return "UP"
		KEY_DOWN: return "DOWN"
		KEY_SPACE: return "JUMP"
	return ""


## eventnet post of a GAME.* event: Game, SpriteGear and Soundtrack handlers.
func _post(b: String) -> void:
	match b:
		"RIGHT":
			world.hero.force += Logic.run_force(Logic.RIGHT)
			health.exert(Logic.CAL_RUN)
			facing_left = false
		"LEFT":
			world.hero.force += Logic.run_force(Logic.LEFT)
			health.exert(Logic.CAL_RUN)
			facing_left = true
		"JUMP":
			world.hero.force += Logic.jump_force()
			health.exert(Logic.CAL_JUMP)
			if _bip:
				_bip.play()
		"QUIT":
			_end_game()
			_go(St.MENU)
			return
		_:
			return  # UP / DOWN: posted, but nothing handles them.
	world.hero.mass = health.mass()  # exert may burn fat -> HEALTH_FAT_CHANGED -> updateMass


# ---------------------------------------------------------------- states

func _go(s: St) -> void:
	state = s
	if s == St.LEVELS:
		selected = 0  # LevelList.kick
	queue_redraw()


func _exit_to_arcade() -> void:
	var reg := get_node_or_null("/root/GameRegistry")
	if reg:
		reg.return_to_arcade()


func _start_entry(score: int) -> void:
	entry_score = score
	entry_text = ""
	state = St.SCORE_ENTRY


func _entry_key(code: int) -> void:
	if code >= KEY_A and code <= KEY_Z:
		if entry_text.length() < 3:
			entry_text += char(code)  # pygame.key.name(...).upper()
	elif code == KEY_BACKSPACE and entry_text != "":
		entry_text = entry_text.left(-1)
	elif (code == KEY_ENTER or code == KEY_KP_ENTER) and entry_text.length() == 3:
		scores = Logic.insert_score(scores, entry_text, entry_score)
		_save_scores()
		state = St.SCORES


func _load_scores() -> void:
	scores = []
	if FileAccess.file_exists(SCORES_PATH):
		var f := FileAccess.open(SCORES_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		if data is Array:
			scores = data


func _save_scores() -> void:
	var f := FileAccess.open(SCORES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(scores))


func _enter_level() -> void:
	# "joe1" has no joe1-geom.svg / -back.png / -fore.png in the repo: picking it crashes
	# the original with an IOError. Here it is a no-op.
	if ROOMS[selected] != "outside":
		return
	_start_game()


# ---------------------------------------------------------------- game

func _start_game() -> void:
	health = Logic.new()
	controls = Logic.Controller.new()
	world = Logic.World.new(health.mass())
	facing_left = false
	ticks = 0
	_acc = 0.0
	state = St.GAME
	queue_redraw()


func _end_game() -> void:
	world = null


## Game.tick at a fixed 50 Hz (two 0.01 s ODE steps per tick; the original had no frame
## limiter and ran as fast as the machine allowed).
func _process(delta: float) -> void:
	if state != St.GAME:
		return
	_acc = minf(_acc + delta, 0.25)
	while _acc >= Logic.TICK and state == St.GAME:
		_acc -= Logic.TICK
		tick()
	queue_redraw()


## Game.tick: physics.step(), hero.step(), eat(Food(5,5)), controls.tick(), sprites.tick().
func tick() -> void:
	ticks += 1
	world.tick()
	health.step()
	health.eat(Logic.FOOD.x, Logic.FOOD.y)
	world.hero.mass = health.mass()  # Bird.updateMass on HEALTH_FAT_CHANGED
	for b in controls.tick():
		_post(b)
		if state != St.GAME:
			return


# ---------------------------------------------------------------- drawing

## pygame Font(None, size) renders freesansbold at size*0.6875.
static func _px(size: int) -> int:
	return int(size * 0.6875)


## Display.text: blit at top-left pos (after LEFT/CENTER/RIGHT adjust). Returns the left x used.
func _text(words: String, size: int, pos: Vector2, color: Color, justify := 0) -> float:
	var fs := _px(size)
	var w := FONT.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := pos.x
	if justify == 1:
		x -= w * 0.5
	elif justify == 2:
		x -= w
	draw_string(FONT, Vector2(x, pos.y + FONT.get_ascent(fs)), words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	return x


func _draw() -> void:
	# fit_stage makes the visible area 640x480 in the arcade (scale 1); letterbox anything else.
	var area := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, area.max(size)), Color.BLACK)
	var sc := minf(area.x / Logic.SCREEN.x, area.y / Logic.SCREEN.y)
	if sc <= 0.0:
		return
	draw_set_transform((area - Vector2(Logic.SCREEN) * sc) * 0.5, 0.0, Vector2(sc, sc))
	draw_rect(Rect2(Vector2.ZERO, Vector2(Logic.SCREEN)), Color.BLACK)
	match state:
		St.MENU:
			draw_texture(IMG_MENU, Vector2.ZERO)
		St.HELP:
			draw_texture(IMG_HELP, Vector2.ZERO)
		St.CREDITS:
			draw_texture(IMG_CREDITS, Vector2.ZERO)
		St.SCORES:
			draw_texture(IMG_SCORES, Vector2.ZERO)
			var pos := Vector2(640 / 2 + 50, 480 / 2 - 50)
			for i in scores.size():
				var line := ": ".join([str(i + 1), str(scores[i][0]), str(int(scores[i][1]))])
				# Display.text mutates pos[0] for RIGHT, and the next line starts at +72/+20 of it.
				pos.x = _text(line, 20, pos, Color.WHITE, 2)
				pos = Vector2(pos.x + 72, pos.y + 20)
		St.SCORE_ENTRY:
			_text("What are your initials?", 40, Vector2(640 / 3.5, 480 / 3.0), Color.WHITE)
			_text(entry_text, 30, Vector2(640 / 2, 480 / 2), Color.WHITE, 1)
		St.LEVELS:
			var n := ROOMS.size()
			for i in n:
				var c := Color.WHITE if i == selected else Color8(200, 200, 200)
				_text(ROOMS[i], 30, Vector2(320, 240 - n * 30 / 1.3 + i * 30 / 1.3), c, 1)
		St.GAME:
			_draw_game()
	# pygame clips at the screen edge: mask the letterbox so a ball or kiwi off the stage
	# (no glass walls) does not show in the margins.
	var big := 4096.0
	var sw := float(Logic.SCREEN.x)
	var sh := float(Logic.SCREEN.y)
	for r in [Rect2(-big, -big, big, sh + 2 * big), Rect2(sw, -big, big, sh + 2 * big),
			Rect2(0, -big, sw, big), Rect2(0, sh, sw, big)]:
		draw_rect(r, Color.BLACK)


## Where the soccer ball sprite is drawn (stage pixels).
func ball_rect() -> Rect2:
	return Rect2(world.ball.pos.round() - Vector2(16, 16), Vector2(IMG_SOCCER.get_size()))


func _draw_game() -> void:
	# SpriteGear background: game.png with rooms/outside-back.png blitted over its 540x480.
	draw_texture(IMG_GAME, Vector2.ZERO)
	draw_texture(IMG_BACK, Vector2.ZERO)
	# StatusBox white bars grow down from the top as the value drops below its ceiling.
	draw_rect(Rect2(Logic.CARB_POS, Vector2(Logic.BAR_WIDTH, health.blood_black)), Color.WHITE)
	draw_rect(Rect2(Logic.FATS_POS, Vector2(Logic.BAR_WIDTH, health.fat_black)), Color.WHITE)
	if world:
		# The ball as the TEST_ROOM drew it (states.Game): a BlockSprite with data/soccer.png,
		# centred on the rounded body position and never rotated.
		draw_texture_rect(IMG_SOCCER, ball_rect(), false)
		var c := world.hero.pos.round()
		draw_texture(IMG_KIWI_LEFT if facing_left else IMG_KIWI_RIGHT, c - Vector2(16, 16))
	draw_texture(IMG_STATUS_TXT, Logic.TEXT_POS)  # WithForeground: status text always on top
	# rooms/outside-fore.png is fully transparent, so it is not drawn.
