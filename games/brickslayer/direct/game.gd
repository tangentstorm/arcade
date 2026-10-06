extends Control
## Brickslayer — Direct edition. Port of the javascriptgamer.com Breakout (2007).
##
## brickslayer_logic.gd holds the game. This script draws the 400x300 console
## at 2x, builds the overlay screens from the original HTML/CSS, and passes keys
## through. Esc is handled by the arcade PauseOverlay autoload.

const Logic := preload("res://games/brickslayer/direct/brickslayer_logic.gd")
const Session := preload("res://games/brickslayer/session.gd")
const TRAIL_SCENE := "res://games/brickslayer/trail/trail.tscn"
const ASSETS := "res://games/brickslayer/source/assets/"

const S := 2.0                                  ## draw scale (400x300 -> 800x600)
const TEXT_PX := 13                             ## body { font-size: 10pt }
const GRAY_666 := Color("#666666")
const GRAY_999 := Color("#999999")
const LAKE := Color("#cccccc")
const DIM := Color(0.41, 0.41, 0.41, 0.5)       ## fallback if dimgray.png missing
const SHADES := {                               ## #bricks .shadeN
	5: Color("#777777"), 4: Color("#999999"), 3: Color("#bbbbbb"),
	2: Color("#dddddd"), 1: Color("#ffffff"),
}
## soundManager.createSound(name, '../sounds/' + file). The mp3s are not on the
## live site, so each loads only if a file is later vendored.
const SOUND_FILES := {
	"serve": "whish.mp3", "hit": "plopp.mp3", "break": "glass2.mp3",
	"bounce": "boing.mp3", "fall": "deepsplosh.mp3",
}

var game: Logic
var step := Logic.LAST_STEP
var _acc_ms := 0.0
var _sounds := {}
var _bold: FontVariation
var _overlays := {}                             ## screen name -> Control
var _name_edit: LineEdit
var _score_rows: Array = []                     ## [[name Label, score Label], …]
var _paddle_tex: Texture2D
var _ball_tex: Texture2D
var _dim_tex: Texture2D

@onready var _console: Control = %Console
@onready var _footer: Label = %Footer


func _ready() -> void:
	if Session.pending_step >= 0:
		step = Session.pending_step
		Session.pending_step = -1
	_bold = FontVariation.new()
	_bold.base_font = get_theme_default_font()
	_bold.variation_embolden = 0.9
	_load_sprite_textures()
	_load_sounds()
	_build_overlays()
	_console.draw.connect(_draw_console)
	resized.connect(_layout)
	_new_game()
	_layout()
	_update_footer()


func _exit_tree() -> void:
	if game:
		game.dispose()


func _new_game() -> void:
	if game:
		game.dispose()
	game = Logic.new(step)
	game.sound.connect(_on_sound)
	game.screen_changed.connect(_on_screen_changed)
	_acc_ms = 0.0
	_on_screen_changed(game.screen)


func _layout() -> void:
	var sz := Vector2(Logic.W, Logic.H) * S
	_console.size = sz
	_console.position = ((size - sz) / 2.0).floor()


func _process(delta: float) -> void:
	_acc_ms = minf(_acc_ms + delta * 1000.0, 250.0)
	while _acc_ms >= Logic.TICK_MS:
		_acc_ms -= Logic.TICK_MS
		game.tick()
	_console.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.keycode == KEY_ESCAPE:
		return
	if k.pressed and not k.echo:
		if k.keycode == KEY_T:
			get_viewport().set_input_as_handled()
			_open_trail()
			return
		if k.keycode == KEY_R and step < Logic.STEP_SCREENS:
			_new_game()                         # earlier lessons have no restart path
			get_viewport().set_input_as_handled()
			return
	# Browsers repeat keydown while a key is held; echo events do the same here.
	if k.pressed:
		game.key_down(k.keycode)
	else:
		game.key_up(k.keycode)
	get_viewport().set_input_as_handled()


func _open_trail() -> void:
	get_tree().change_scene_to_file(TRAIL_SCENE)


func _update_footer() -> void:
	var parts: Array[String] = []
	if step < Logic.LAST_STEP:
		parts.append("Playing the trail at lesson %02d" % step)
		if step < Logic.STEP_SCREENS:
			parts.append("R: restart")
	parts.append("Esc: arcade menu")
	parts.append("T: code trail")
	_footer.text = "   |   ".join(parts)


# ---- drawing ------------------------------------------------------------

func _draw_console() -> void:
	var c := _console
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(S, S))
	c.draw_rect(Rect2(0, 0, Logic.W, Logic.H), Color.WHITE)
	if step >= Logic.STEP_WORLD:
		for b in game.bricks:
			if b.solid:
				c.draw_rect(Rect2(b.x, b.y, b.w, b.h), SHADES[b.shade])
				c.draw_rect(Rect2(b.x + 0.5, b.y + 0.5, b.w - 1, b.h - 1), GRAY_999, false, 1.0)
	if step >= Logic.STEP_PADDLE:
		_draw_gray_sprite(game.paddle)
	if step >= Logic.STEP_COLLISION:
		_draw_ball_sprite(game.ball)
	if step >= Logic.STEP_WORLD:
		# the lake is drawn over the ball, so a lost ball sinks into it
		c.draw_rect(Rect2(0, 280, Logic.W, 20), LAKE)
		c.draw_rect(Rect2(0, 280, Logic.W, 1), GRAY_999)
	if step >= Logic.STEP_SCORING:
		for i in range(1, Logic.SPARES_START + 1):
			if i <= game.balls_left:
				_draw_ball_sprite(Logic.Sprite.new(4 + (i - 1) * 20, 282, 16, 16))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if step >= Logic.STEP_SCORING:
		_draw_text("level:", 150, Color.WHITE)
		_draw_text(str(game.current_level), 200, Color.WHITE)
		_draw_text("score:", 300, Color.WHITE)
		_draw_text(str(game.score), 350, Color.WHITE, 45)


## Prefer recovered paddle.png / ball.png; fall back to gray stand-ins.
func _draw_gray_sprite(s: Logic.Sprite) -> void:
	if _paddle_tex:
		_console.draw_texture_rect(_paddle_tex, Rect2(s.x, s.y, s.w, s.h), false)
		return
	_console.draw_rect(Rect2(s.x, s.y, s.w, s.h), GRAY_999)
	_console.draw_rect(Rect2(s.x + 0.5, s.y + 0.5, s.w - 1, s.h - 1), GRAY_666, false, 1.0)


func _draw_ball_sprite(s: Logic.Sprite) -> void:
	if _ball_tex:
		_console.draw_texture_rect(_ball_tex, Rect2(s.x, s.y, s.w, s.h), false)
		return
	var center := Vector2(s.x + s.w * 0.5, s.y + s.h * 0.5)
	var radius := minf(s.w, s.h) * 0.5
	_console.draw_circle(center, radius, GRAY_999)
	_console.draw_arc(center, radius - 0.5, 0.0, TAU, 32, GRAY_666, 1.0, true)


func _draw_text(text: String, left: float, color: Color, right_align_width := 0.0) -> void:
	var px := int(TEXT_PX * S)
	var pos := Vector2(left * S, 282 * S + _bold.get_ascent(px))
	var align := HORIZONTAL_ALIGNMENT_LEFT
	var width := -1.0
	if right_align_width > 0:
		align = HORIZONTAL_ALIGNMENT_RIGHT
		width = right_align_width * S
	_console.draw_string(_bold, pos, text, align, width, px, color)


# ---- overlay screens (lessons 08-09) ------------------------------------

func _build_overlays() -> void:
	_overlays["title"] = _overlay("brickslayerlogo.png", "brickslayer", [
		"use [b]arrow keys[/b] to move paddle",
		"press [b]up arrow[/b] to launch ball",
		"press [b]p[/b] to pause game",
		"press [b]enter[/b] to start",
	])
	_overlays["pause"] = _overlay("paused.png", "paused", ["press [b]p[/b] again to unpause"])
	_overlays["clear"] = _overlay("levelclear.png", "level clear!", [])
	_overlays["gameover"] = _overlay("gameover.png", "game over", [])
	var congrats := _overlay("congrats.png", "congratulations!",
			["You made the High Score List! Enter Your Name!"])
	congrats.get_child(1).add_child(_name_row())
	_overlays["congrats"] = congrats
	var scores := _overlay("highscores.png", "high scores", [])
	var box: VBoxContainer = scores.get_child(1)
	box.add_child(_score_table())
	box.add_child(_para("press [b]enter[/b] to start"))
	_overlays["scores"] = scores


## .overlay: dimmed full-console layer, centered #666 text, 50px top padding.
func _overlay(image: String, alt: String, lines: Array) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	if _dim_tex:
		var dim := TextureRect.new()
		dim.texture = _dim_tex
		dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dim.stretch_mode = TextureRect.STRETCH_TILE
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(dim)
	else:
		var dim := ColorRect.new()
		dim.color = DIM
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 50 * S
	box.add_theme_constant_override("separation", int(TEXT_PX * S * 0.6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	box.add_child(_image(image, alt))
	for l in lines:
		box.add_child(_para(l))
	_console.add_child(root)
	return root


## <img src="../sprites/NAME" alt="ALT">. If the file wasn't recovered,
## show the alt text the way a browser would.
func _image(file: String, alt: String) -> Control:
	var path := ASSETS + "sprites/" + file
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = tex.get_size() * S
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return tr
	var l := Label.new()
	l.text = alt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _bold)
	l.add_theme_font_size_override("font_size", int(TEXT_PX * S * 2))
	l.add_theme_color_override("font_color", GRAY_666)
	l.custom_minimum_size.y = 74 * S
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _para(bbcode: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = "[center]%s[/center]" % bbcode
	r.add_theme_font_size_override("normal_font_size", int(TEXT_PX * S))
	r.add_theme_font_size_override("bold_font_size", int(TEXT_PX * S))
	r.add_theme_font_override("bold_font", _bold)
	r.add_theme_color_override("default_color", GRAY_666)
	return r


func _name_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl := Label.new()
	lbl.text = "name"
	lbl.add_theme_color_override("font_color", GRAY_666)
	lbl.add_theme_font_size_override("font_size", int(TEXT_PX * S))
	row.add_child(lbl)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 150 * S
	_name_edit.max_length = 40
	_name_edit.text_submitted.connect(func(_t): _post_score())
	row.add_child(_name_edit)
	var go := Button.new()
	go.text = "go"
	go.pressed.connect(_post_score)
	row.add_child(go)
	return row


## #scoretable: 350px wide, 3px #666 border, white 20px rows, scores right-aligned.
func _score_table() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = GRAY_666
	sb.set_border_width_all(int(3 * S))
	sb.set_content_margin_all(2 * S)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.x = 350 * S
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	_score_rows.clear()
	for i in 5:
		var name_l := Label.new()
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var score_l := Label.new()
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for l in [name_l, score_l]:
			l.custom_minimum_size.y = 20 * S
			l.add_theme_font_size_override("font_size", int(TEXT_PX * S))
			grid.add_child(l)
		_score_rows.append([name_l, score_l])
	return panel


func _refresh_scores() -> void:
	var top: Array = game.top_scores()
	for i in _score_rows.size():
		var labels: Array = _score_rows[i]
		var row: Array = top[i] if i < top.size() else [0, 0, "", "old"]
		labels[0].text = str(row[2])
		labels[1].text = str(row[0]) if row[2] != "" else ""
		var is_new: bool = row[3] == "new"   # tr.new { color:#333; bold }
		for l in labels:
			l.add_theme_color_override("font_color", Color("#333333") if is_new else GRAY_666)
			if is_new:
				l.add_theme_font_override("font", _bold)
			else:
				l.remove_theme_font_override("font")


func _post_score() -> void:
	if game.screen == "congrats":
		game.post_score(_name_edit.text)


func _on_screen_changed(screen: String) -> void:
	for key in _overlays:
		_overlays[key].visible = key == screen
	if screen == "scores":
		_refresh_scores()
	if screen == "congrats":
		_name_edit.text = ""
		_name_edit.grab_focus()
	elif _name_edit and _name_edit.has_focus():
		_name_edit.release_focus()


# ---- sprites / sound ----------------------------------------------------

func _load_sprite_textures() -> void:
	var paddle_path := ASSETS + "sprites/paddle.png"
	var ball_path := ASSETS + "sprites/ball.png"
	var dim_path := ASSETS + "sprites/dimgray.png"
	if ResourceLoader.exists(paddle_path):
		_paddle_tex = load(paddle_path)
	if ResourceLoader.exists(ball_path):
		_ball_tex = load(ball_path)
	if ResourceLoader.exists(dim_path):
		_dim_tex = load(dim_path)


func _load_sounds() -> void:
	for key in SOUND_FILES:
		var path: String = ASSETS + "sounds/" + SOUND_FILES[key]
		if ResourceLoader.exists(path):
			var p := AudioStreamPlayer.new()
			p.stream = load(path)
			add_child(p)
			_sounds[key] = p


func _on_sound(name: String) -> void:
	if _sounds.has(name):
		_sounds[name].play()
