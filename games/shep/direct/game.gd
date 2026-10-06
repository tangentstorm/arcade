extends Control
## Shep — Direct edition. Port of tangentstorm/shep (Haxe 2 / Flash 9 + Flex,
## robocognito, 2009–2010).
##
## This script is console.mxml, the Flex shell: the Title, Help, Credits,
## LevelSelect, Game, Pause, Victory, and Defeat states, the level buttons with
## their unlocks, previews, and best times, and the SharedObject scores. It
## also holds SoundManager.hx. shep_world.gd is Game1.hx.
##
## Everything draws at the original 800x575 inside a SubViewport (which also
## gives the level its own physics space), scaled to fit. Esc is handled by the
## arcade PauseOverlay autoload. The in-game pause button in the bottom-right
## corner opens Shep's own pause screen, as in the original.

const Levels := preload("res://games/shep/direct/shep_levels.gd")
const World := preload("res://games/shep/direct/shep_world.gd")
const StarField := preload("res://games/shep/direct/star_field.gd")
const Preview := preload("res://games/shep/direct/level_preview.gd")
const ART := "res://games/shep/direct/assets/"
const SCORES_PATH := "user://shep_scores.cfg"

const STAGE := Vector2(800, 575)
const SOUND_FILES := {
	"fuse": "fuse", "wall": "wall", "fusewall": "glass-on-metal", "door": "door",
	"pocket": "pocket", "thrust": "thrust", "alert1": "alert-1", "alert2": "alert-2",
	"alert3": "alert-3", "victory": "victory", "defeat": "defeat",
}
const HALO_TEXT := Color("#0b333c")

enum { TITLE, HELP, CREDITS, LEVEL_SELECT, GAME, PAUSE, VICTORY, DEFEAT }

var state := TITLE
var back_to_where := TITLE
var scores := {}           ## svg level number -> seconds left (SharedObject "shep_scores")
var muted := false
var world: World
var stars: StarField

var _screens := {}         ## state -> Control
var _sounds := {}          ## name -> AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_pos := 0.0
var _receipt: Font
var _level_buttons: Array[Button] = []
var _preview: Preview
var _level_name: Label
var _level_text: Label
var _best_time: Label
var _trophy: TextureRect
var _mute: TextureButton
var _game_hud: Control
var _pause_button: Button
var _replay: Button
var _gameover_buttons: Array[Button] = []

@onready var _container: SubViewportContainer = %Container
@onready var _viewport: SubViewport = %Viewport


func _ready() -> void:
	_receipt = load(ART + "fake_receipt.ttf")
	_load_scores()
	_load_sounds()
	stars = StarField.new()
	_viewport.add_child(stars)
	_viewport.move_child(stars, 0)          # starCanvas: behind everything
	world = World.new()
	world.visible = false
	_viewport.add_child(world)
	_viewport.move_child(world, 1)          # gameCanvas: under the Flex screens
	world.won.connect(_on_win)
	world.lost.connect(_on_lose)
	world.sfx.connect(play_sfx)
	world.music.connect(_on_music)
	_build_screens()
	resized.connect(_layout)
	_layout()
	_set_state(TITLE)


func _exit_tree() -> void:
	if _music:
		_music.stop()


func _layout() -> void:
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	_container.scale = Vector2(s, s)
	_container.position = ((size - STAGE * s) / 2.0).floor()


# ---- states ----------------------------------------------------------------

func _set_state(s: int) -> void:
	state = s
	world.visible = s == GAME or s == PAUSE
	_game_hud.visible = world.visible
	_pause_button.visible = s == GAME
	for k in _screens:
		_screens[k].visible = k == s
	if s == LEVEL_SELECT:
		_unlock_levels()
	if s == VICTORY or s == DEFEAT:
		# the GameOver state's two buttons, shared by Victory and Defeat
		for b in _gameover_buttons:
			if b.get_parent() != _screens[s]:
				b.reparent(_screens[s], false)
		_replay.text = "Try Again" if s == DEFEAT else "Replay Level"
	_focus_default()


func _focus_default() -> void:
	var scr: Control = _screens.get(state)
	if scr == null:
		return
	for c in scr.find_children("*", "BaseButton", true, false):
		var b := c as BaseButton
		if b.visible and not b.disabled and b.focus_mode != FOCUS_NONE:
			b.grab_focus()
			return


func _start_level(ord: int) -> void:
	_set_state(GAME)
	world.start_level(Levels.ord_level(ord))


func _pause_game() -> void:
	_set_state(PAUSE)
	world.pause()


func _resume_game() -> void:
	_set_state(GAME)
	world.resume()


func _restart_level() -> void:
	_set_state(GAME)
	world.restart()


func _exit_level() -> void:
	world.exit_level()
	_set_state(LEVEL_SELECT)


func _help_from(where: int) -> void:
	back_to_where = where
	_set_state(HELP)


func _on_win(secs_left: int) -> void:
	# Game1.updateHighScores: seconds LEFT, so bigger is faster
	if Levels.record_score(scores, world.current_level, secs_left):
		_save_scores()
	_set_state(VICTORY)


func _on_lose() -> void:
	_set_state(DEFEAT)


# ---- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if state != GAME:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if world.key(event.keycode):
			get_viewport().set_input_as_handled()


func _on_stage_input(event: InputEvent) -> void:
	if state != GAME:
		return
	if event is InputEventMouseMotion:
		world.mouse_moved(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		# onClick ignores the mute-button corner
		if p.x > _mute.position.x and p.y >= _mute.position.y:
			return
		world.click_kick(p)


# ---- sound (SoundManager.hx) -------------------------------------------------

func _load_sounds() -> void:
	for k in SOUND_FILES:
		var p := AudioStreamPlayer.new()
		p.stream = load(ART + "sound/" + SOUND_FILES[k] + ".mp3")
		p.max_polyphony = 4
		add_child(p)
		_sounds[k] = p
	_music = AudioStreamPlayer.new()
	_music.stream = load(ART + "sound/wah-danube.mp3")
	add_child(_music)


func play_sfx(n: String) -> void:
	if muted:
		return
	if n == "alert3x2":
		# alert3(0, 2): play it twice
		_sounds["alert3"].play()
		var len: float = _sounds["alert3"].stream.get_length()
		get_tree().create_timer(len, false).timeout.connect(func():
			if is_instance_valid(self) and not muted:
				_sounds["alert3"].play())
		return
	if _sounds.has(n):
		_sounds[n].play()


func _on_music(cmd: String) -> void:
	match cmd:
		"start":
			_music.stop()
			_music_pos = 0.0
			if not muted:
				_music.play()
		"pause":
			if _music.playing:
				_music_pos = _music.get_playback_position()
			_music.stop()
		"resume":
			if not muted:
				_music.play(_music_pos)


func _toggle_mute() -> void:
	muted = not muted
	_music.volume_db = -80.0 if muted else 0.0
	_mute.texture_normal = load(ART + ("muted.png" if muted else "spkr.png"))


# ---- scores (SharedObject "shep_scores") --------------------------------------

func _load_scores() -> void:
	scores.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SCORES_PATH) != OK:
		return
	for k in cfg.get_section_keys("shep_scores") if cfg.has_section("shep_scores") else []:
		if k.begins_with("level_"):
			scores[int(k.substr(6))] = int(cfg.get_value("shep_scores", k))


func _save_scores() -> void:
	var cfg := ConfigFile.new()
	for lvl in scores:
		cfg.set_value("shep_scores", "level_%d" % lvl, scores[lvl])
	cfg.save(SCORES_PATH)


# ---- level select ------------------------------------------------------------

func _unlock_levels() -> void:
	for i in Levels.MENU_LEVELS:
		var ord := i + 1
		var b := _level_buttons[i]
		b.disabled = not Levels.is_unlocked(ord, scores)
		b.icon = load(ART + "lil-padlock.png") if b.disabled else null
	_trophy.visible = Levels.shows_trophy(scores)
	_show_level_info(0)


func _show_level_info(ord: int) -> void:
	if ord >= 1 and not _level_buttons[ord - 1].disabled:
		var lvl := Levels.ord_level(ord)
		_preview.show_level(lvl)
		_preview.visible = true
		_level_name.text = Levels.level_name(ord)
		_level_text.text = Levels.level_text(ord)
		_best_time.text = Levels.best_time_text(lvl, scores)
	else:
		_preview.visible = false
		_level_name.text = ""
		_level_text.text = ""
		_best_time.text = ""


# ---- building the Flex screens -----------------------------------------------

func _img(parent: Control, path: String, pos := Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ART + path)
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _screen(s: int) -> Control:
	var c := Control.new()
	c.size = STAGE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Stage.add_child(c)
	_screens[s] = c
	return c


## A Flex Halo-style push button.
func _button(parent: Control, label: String, pos: Vector2, w: float, cb: Callable, h := 22.0) -> Button:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 11)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, HALO_TEXT)
	b.add_theme_stylebox_override("normal", _halo(Color(0.93, 0.93, 0.93)))
	b.add_theme_stylebox_override("hover", _halo(Color(1, 1, 1)))
	b.add_theme_stylebox_override("focus", _halo(Color(1, 1, 1), Color("#009dff")))
	b.add_theme_stylebox_override("pressed", _halo(Color(0.8, 0.85, 0.88)))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _halo(fill: Color, border := Color(0.55, 0.57, 0.6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


## An invisible hot-spot button over artwork (the Help "BACK", the in-game
## pause button).
func _hotspot(parent: Control, rect: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _receipt_label(parent: Control, text: String, pos: Vector2, size_px := 24) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", _receipt)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_screens() -> void:
	%Stage.gui_input.connect(_on_stage_input)

	# Game: the clock lives in the world; mute + pause hot spot over the border
	_game_hud = Control.new()
	_game_hud.size = STAGE
	_game_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Stage.add_child(_game_hud)
	_mute = TextureButton.new()
	_mute.texture_normal = load(ART + "spkr.png")
	_mute.position = Vector2(696, 552)
	_mute.focus_mode = Control.FOCUS_NONE
	_mute.pressed.connect(_toggle_mute)
	_game_hud.add_child(_mute)
	_pause_button = _hotspot(_game_hud, Rect2(STAGE.x - 1 - 71, STAGE.y - 1 - 24, 71, 24), _pause_game)

	# Title
	var t := _screen(TITLE)
	_img(t, "screens/screen-bgs.png")
	_img(t, "screens/title.png")
	_button(t, "Start Game", Vector2(400 - 112 - 11, 335), 224, _set_state.bind(LEVEL_SELECT))
	_button(t, "How to Play", Vector2(277, 365), 224, _help_from.bind(TITLE))
	_button(t, "Credits", Vector2(277, 395), 224, _set_state.bind(CREDITS))

	# Pause (over the frozen game)
	var p := _screen(PAUSE)
	_img(p, "screens/paused.png")
	_button(p, "Resume Game", Vector2(288, 360), 224, _resume_game)
	_button(p, "Restart Level", Vector2(288, 405), 224, _restart_level)
	_button(p, "Exit Level", Vector2(288, 451), 224, _exit_level)
	_button(p, "How to Play", Vector2(288, 498), 224, _help_from.bind(PAUSE))

	# LevelSelect
	var ls := _screen(LEVEL_SELECT)
	_img(ls, "screens/level-select.png")
	var vb := VBoxContainer.new()
	vb.position = Vector2(15, 75)
	vb.add_theme_constant_override("separation", 6)
	ls.add_child(vb)
	for i in Levels.MENU_LEVELS:
		var b := _level_button("Level %d" % (i + 1), Vector2(165, 35))
		b.pressed.connect(_start_level.bind(i + 1))
		b.mouse_entered.connect(_show_level_info.bind(i + 1))
		b.focus_entered.connect(_show_level_info.bind(i + 1))
		vb.add_child(b)
		_level_buttons.append(b)
	var back := _level_button("Return to Title", Vector2(248, 33))
	back.position = Vector2(542, 532)
	back.pressed.connect(_set_state.bind(TITLE))
	ls.add_child(back)
	_preview = Preview.new()
	_preview.position = Vector2(354, 113)
	_preview.scale = Vector2(0.33, 0.33)
	_preview.modulate.a = 0.75
	ls.add_child(_preview)
	_receipt_label(ls, "Intari Asteroid Mining Ship", Vector2(207, 10))
	_receipt_label(ls, "\"Om-Nom-Nom\"", Vector2(313, 36))
	var info := VBoxContainer.new()
	info.position = Vector2(353, 339)
	info.size = Vector2(416, 174)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ls.add_child(info)
	_level_name = _receipt_label(info, "", Vector2.ZERO)
	_level_text = _receipt_label(info, "", Vector2.ZERO, 12)
	_level_text.custom_minimum_size = Vector2(416, 53)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	info.add_child(spacer)
	_best_time = _receipt_label(info, "", Vector2.ZERO)
	_trophy = _img(ls, "trophy.png", Vector2(10, 489))

	# Victory / Defeat (GameOver base: two buttons over a screen)
	var v := _screen(VICTORY)
	_img(v, "screens/screen-bgs.png")
	_img(v, "screens/victory.png")
	var d := _screen(DEFEAT)
	_img(d, "screens/gameover.png")
	_replay = _button(v, "Replay Level", Vector2(331.5, 411), 137, _restart_level)
	var map_btn := _button(v, "Back to Map", Vector2(331.5, 450), 137, _set_state.bind(LEVEL_SELECT))
	_gameover_buttons = [_replay, map_btn]

	# Help
	var h := _screen(HELP)
	_img(h, "screens/help.png")
	var hb := _hotspot(h, Rect2(708, 538, 82, 27), func(): _set_state(back_to_where))
	hb.focus_mode = Control.FOCUS_ALL

	# Credits (the original's site links went to robocognito.com, sculptedpixel.org
	# and withoutane.com; they're left out)
	var c := _screen(CREDITS)
	_img(c, "screens/shep-credits.png")
	_button(c, "Back", Vector2(736, 539), 52, _set_state.bind(TITLE))



func _level_button(label: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = sz
	b.size = sz
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_override("font", _receipt)
	b.add_theme_font_size_override("font_size", 24)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(st, Color.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.45))
	var clear := StyleBoxTexture.new()
	clear.texture = load(ART + "button_bg_clear.png")
	clear.content_margin_left = 8
	var light := StyleBoxTexture.new()
	light.texture = load(ART + "button_bg_light.png")
	light.content_margin_left = 8
	b.add_theme_stylebox_override("normal", clear)
	b.add_theme_stylebox_override("disabled", clear)
	b.add_theme_stylebox_override("hover", light)
	b.add_theme_stylebox_override("focus", light)
	b.add_theme_stylebox_override("pressed", light)
	return b
