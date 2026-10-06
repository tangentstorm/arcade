extends Node2D
## Shep (Enhanced). Presentation makeover of the Direct zero-g fuse puzzler.
## Physics, SVG levels, win/lose, clock and unlocks are Direct's shep_world.gd /
## shep_levels.gd. This file owns the shell, clearer fuse/ship UI, juice, and
## the letterboxed 1280x720 stage. Esc is handled by the PauseOverlay autoload.

const Levels := preload("res://games/shep/direct/shep_levels.gd")
const World := preload("res://games/shep/direct/shep_world.gd")
const StarField := preload("res://games/shep/direct/star_field.gd")
const Preview := preload("res://games/shep/direct/level_preview.gd")
const ART := "res://games/shep/direct/assets/"
const SCORES_PATH := "user://shep_scores.cfg"

const STAGE := Vector2(1280, 720)
const FIELD := Vector2(800, 575)
const FIELD_POS := Vector2(240, 72)

const BG_TOP := Color(0.04, 0.06, 0.14)
const BG_BOTTOM := Color(0.08, 0.04, 0.16)
const PANEL := Color(0.09, 0.10, 0.20, 0.92)
const FRAME := Color(0.35, 0.75, 0.95)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const CYAN := Color(0.25, 0.90, 1.0)
const RED := Color(1.0, 0.35, 0.42)
const GREEN := Color(0.35, 0.95, 0.55)

enum { TITLE, HELP, CREDITS, LEVEL_SELECT, GAME, PAUSE, VICTORY, DEFEAT }

var state := TITLE
var back_to_where := TITLE
var scores := {}
var muted := false
var world: World
var stars: StarField
var _fuses_total := 0
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _aim_pulse := 0.0

var _vp_container: SubViewportContainer
var _viewport: SubViewport
var _ui: CanvasLayer
var _cards := {}
var _level_buttons: Array[Button] = []
var _preview: Preview
var _level_name: Label
var _level_blurb: Label
var _best_time: Label
var _trophy: TextureRect
var _clock_label: Label
var _fuses_label: Label
var _hint_label: Label
var _objective: Label
var _legend: Label
var _serve_pulse: Label
var _mute_btn: Button
var _pause_btn: Button
var _replay: Button
var _gameover_btns: Array[Button] = []
var _victory_box: VBoxContainer
var _defeat_box: VBoxContainer
var _sounds := {}
var _music: AudioStreamPlayer
var _music_pos := 0.0
var _font: Font
var _panel_style := StyleBoxFlat.new()
var _field_frame := StyleBoxFlat.new()

const SOUND_FILES := {
	"fuse": "fuse", "wall": "wall", "fusewall": "glass-on-metal", "door": "door",
	"pocket": "pocket", "thrust": "thrust", "alert1": "alert-1", "alert2": "alert-2",
	"alert3": "alert-3", "victory": "victory", "defeat": "defeat",
}


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_field_frame.bg_color = Color(0, 0, 0, 0)
	_field_frame.border_color = FRAME
	_field_frame.set_border_width_all(2)
	_field_frame.set_corner_radius_all(6)
	_load_scores()
	_load_sounds()
	_build_field()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_set_state(TITLE)


func _exit_tree() -> void:
	if _music:
		_music.stop()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(s, s)
	position = (size - STAGE * s) * 0.5


func _build_field() -> void:
	_vp_container = SubViewportContainer.new()
	_vp_container.position = FIELD_POS
	_vp_container.size = FIELD
	_vp_container.stretch = true
	add_child(_vp_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(FIELD)
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp_container.add_child(_viewport)
	stars = StarField.new()
	_viewport.add_child(stars)
	world = World.new()
	world.visible = false
	_viewport.add_child(world)
	world.won.connect(_on_win)
	world.lost.connect(_on_lose)
	world.sfx.connect(_on_world_sfx)
	world.music.connect(_on_music)
	# Enhanced HUD owns the clock; hide Direct's in-field label.
	world.clock_label.visible = false
	_vp_container.gui_input.connect(_on_field_input)


# ---- states ------------------------------------------------------------------

func _set_state(s: int) -> void:
	state = s
	world.visible = s == GAME or s == PAUSE
	_vp_container.visible = world.visible
	_pause_btn.visible = s == GAME
	_mute_btn.visible = s == GAME or s == PAUSE
	for k in _cards:
		_cards[k].visible = k == s
	if s == LEVEL_SELECT:
		_unlock_levels()
	if s == VICTORY or s == DEFEAT:
		var box := _victory_box if s == VICTORY else _defeat_box
		for b in _gameover_btns:
			if b.get_parent() != box:
				b.reparent(box, false)
		_replay.text = "Try Again" if s == DEFEAT else "Replay Level"
	if s == GAME:
		_refresh_hud()


func _start_level(ord: int) -> void:
	_set_state(GAME)
	world.start_level(Levels.ord_level(ord))
	_fuses_total = world.fuses.size()
	_trail.clear()
	_refresh_hud()


func _pause_game() -> void:
	_set_state(PAUSE)
	world.pause()


func _resume_game() -> void:
	_set_state(GAME)
	world.resume()


func _restart_level() -> void:
	_set_state(GAME)
	world.restart()
	_fuses_total = world.fuses.size()
	_trail.clear()
	_refresh_hud()


func _exit_level() -> void:
	world.exit_level()
	_set_state(LEVEL_SELECT)


func _help_from(where: int) -> void:
	back_to_where = where
	_set_state(HELP)


func _on_win(secs_left: int) -> void:
	if Levels.record_score(scores, world.current_level, secs_left):
		_save_scores()
	_flash = 1.0
	_burst(world.shep.position if world.shep else FIELD * 0.5, GOLD, 28, 180.0, 3.0, 0.9, 0.0)
	_float_text(FIELD * 0.5 + Vector2(0, -40), "DOCKED", GOLD)
	_set_state(VICTORY)


func _on_lose() -> void:
	_shake = 1.0
	_flash = 0.7
	_set_state(DEFEAT)


# ---- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		return
	if state != GAME:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if world.key(event.keycode):
			get_viewport().set_input_as_handled()


func _on_field_input(event: InputEvent) -> void:
	if state != GAME:
		return
	if event is InputEventMouseMotion:
		world.mouse_moved(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world.click_kick(event.position)
		_on_kick(event.position)


func _on_kick(_p: Vector2) -> void:
	if world.shep == null:
		return
	_burst(world.shep.position, CYAN, 8, 90.0, 2.0, 0.35, 0.0)
	_shake = maxf(_shake, 0.12)


# ---- sound / scores ----------------------------------------------------------

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
		_sounds["alert3"].play()
		var len: float = _sounds["alert3"].stream.get_length()
		get_tree().create_timer(len, false).timeout.connect(func():
			if is_instance_valid(self) and not muted:
				_sounds["alert3"].play())
		return
	if _sounds.has(n):
		_sounds[n].play()


func _on_world_sfx(n: String) -> void:
	play_sfx(n)
	match n:
		"pocket":
			_on_fuse_docked()
		"thrust":
			if world.shep:
				_burst(world.shep.position, Color(1, 0.7, 0.3), 5, 60.0, 1.5, 0.25, 0.0)
		"wall":
			_shake = maxf(_shake, 0.2)
		"door":
			_float_text(FIELD * 0.5, "DOOR OPEN", GOLD)
			_burst(FIELD * 0.5, GOLD, 12, 120.0, 2.5, 0.5, 0.0)
		"victory", "defeat":
			pass


func _on_fuse_docked() -> void:
	_refresh_hud()
	var pos := FIELD * 0.5
	if world.shep:
		pos = world.shep.position
	# Prefer the pocket nearest the last removed fuse: approximate with shep or field center.
	for p in world.pockets:
		if world.shep and world.shep.position.distance_to(p["pos"]) < 120.0:
			pos = p["pos"]
			break
	_burst(pos, GREEN, 16, 140.0, 2.5, 0.55, 80.0)
	_float_text(pos + Vector2(0, -20), "FUSED", CYAN)
	_shake = maxf(_shake, 0.18)
	if world.fuses.is_empty():
		_float_text(FIELD * 0.5 + Vector2(0, 30), "DOCK SHEP", GREEN)
		_aim_pulse = 1.0


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
	_mute_btn.text = "Muted" if muted else "Sound"


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


# ---- HUD refresh -------------------------------------------------------------

func _refresh_hud() -> void:
	if world == null:
		return
	_clock_label.text = Levels.clock_text(world.secs_left())
	var left := world.fuses.size()
	_fuses_label.text = "%d / %d" % [maxi(_fuses_total - left, 0), _fuses_total] if _fuses_total > 0 else "0 / 0"
	if left == 0 and state == GAME and not world.done:
		_objective.text = "All fuses set. Dock Shep in any socket."
		_objective.add_theme_color_override("font_color", GREEN)
	elif state == GAME:
		_objective.text = "Push each fuse into the matching socket, then dock."
		_objective.add_theme_color_override("font_color", MUTED)
	_hint_label.modulate.a = 0.55 + 0.45 * sin(_time * 3.5) if left == 0 and state == GAME else 0.85
	_hint_label.visible = state == GAME and left == 0 and not world.done
	_serve_pulse.visible = _hint_label.visible


# ---- juice -------------------------------------------------------------------

func _burst(pos: Vector2, color: Color, n: int, speed: float, size: float, life: float, grav: float) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0)
		_particles.append({
			"pos": pos, "vel": v, "life": life, "max": life,
			"color": color, "size": size * randf_range(0.6, 1.2), "grav": grav,
		})
	if _particles.size() > 360:
		_particles = _particles.slice(_particles.size() - 360)


func _float_text(pos: Vector2, text: String, color: Color = GOLD) -> void:
	_floaters.append({"pos": pos, "life": 0.85, "text": text, "color": color})


func _process(delta: float) -> void:
	_time += delta
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	_flash = move_toward(_flash, 0.0, delta * 2.2)
	_aim_pulse = move_toward(_aim_pulse, 0.0, delta * 0.35)
	for p in _particles:
		p.life -= delta
		p.vel.y += p.grav * delta
		p.pos += p.vel * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 36.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	if state == GAME and world and world.shep and not world.done and not world.paused:
		_trail.append(world.shep.position)
		if _trail.size() > 14:
			_trail.pop_front()
		_refresh_hud()
		if world.secs_left() <= 30:
			_clock_label.add_theme_color_override("font_color", RED.lerp(Color(1, 0.6, 0.2), 0.5 + 0.5 * sin(_time * 8.0)))
		else:
			_clock_label.add_theme_color_override("font_color", INK)
	elif not _trail.is_empty():
		_trail.pop_front()
	queue_redraw()


# ---- drawing -----------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * _shake * _shake
	draw_set_transform(shake)
	var m := 500.0
	draw_polygon(PackedVector2Array([
		Vector2(-m, -m), Vector2(STAGE.x + m, -m),
		Vector2(STAGE.x + m, STAGE.y + m), Vector2(-m, STAGE.y + m),
	]), PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	draw_style_box(_panel_style, Rect2(24, 72, 196, 575))
	draw_style_box(_panel_style, Rect2(1060, 72, 196, 575))
	# field frame glow
	var frame := Rect2(FIELD_POS, FIELD)
	for i in 3:
		draw_rect(frame.grow(4 + i * 5), Color(FRAME, 0.12 - i * 0.03), false, 3.0)
	draw_style_box(_field_frame, frame.grow(2))
	if _flash > 0.0:
		draw_rect(frame, Color(1, 1, 1, _flash * 0.35))
	if state == GAME or state == PAUSE:
		_draw_play_overlay(shake)
	draw_set_transform(Vector2.ZERO)


func _draw_play_overlay(shake: Vector2) -> void:
	if world == null or not world.visible:
		return
	draw_set_transform(shake + FIELD_POS)
	# Shep thrust trail
	for i in _trail.size():
		var t := float(i + 1) / (_trail.size() + 1)
		draw_circle(_trail[i], 10.0 * t, Color(CYAN, 0.18 * t))
	# Fuse / socket color rings (clearer matching)
	for p in world.pockets:
		var col := RED if int(p["code"]) > 0 else CYAN
		var r := Levels.POCKET_RADIUS + 10.0 + 2.0 * sin(_time * 3.0 + p["pos"].x * 0.01)
		draw_arc(p["pos"], r, 0.0, TAU, 40, Color(col, 0.55), 2.0, true)
		draw_circle(p["pos"], 4.0, Color(col, 0.35))
	for f in world.fuses:
		var body: RigidBody2D = f["body"]
		if not is_instance_valid(body):
			continue
		var col := RED if int(f["code"]) > 0 else CYAN
		draw_arc(body.position, Levels.FUSE_RADIUS + 6.0, 0.0, TAU, 28, Color(col, 0.9), 2.5, true)
		draw_circle(body.position, 3.0, col)
		# velocity whisker
		var tip: Vector2 = body.position + body.linear_velocity * 0.04
		draw_line(body.position, tip, Color(col, 0.45), 1.5, true)
	# Aim assist + ship ring
	if world.shep and is_instance_valid(world.shep) and not world.done:
		var sp: Vector2 = world.shep.position
		var pulse := 1.0 + 0.15 * sin(_time * 5.0) + 0.25 * _aim_pulse
		draw_arc(sp, Levels.SHEP_RADIUS + 8.0 * pulse, 0.0, TAU, 36, Color(GREEN, 0.55 + 0.35 * _aim_pulse), 2.0, true)
		var aim: Vector2
		if world.keyboard_control:
			aim = Levels.facing(world.shep_clip.rotation_degrees) * 90.0
		else:
			aim = Levels.calc_vector(sp, world.mouse_pos, 120.0)
			aim = aim.normalized() * 90.0 if aim.length() > 0.01 else Vector2.ZERO
		if aim.length() > 1.0:
			var tip2 := sp + aim
			draw_line(sp, tip2, Color(INK, 0.55), 2.0, true)
			draw_circle(tip2, 4.0, Color(GOLD, 0.85))
			# chevrons along the aim
			for k in 3:
				var t := (k + 1) / 4.0
				var cpos := sp.lerp(tip2, t)
				draw_circle(cpos, 2.0, Color(CYAN, 0.5))
	# Juice particles / floaters in field space
	for p in _particles:
		var a: float = p.life / p.max
		var s: float = p.size * (0.5 + 0.5 * a)
		draw_circle(p.pos, s, Color(p.color, a))
	for f in _floaters:
		var a2: float = clampf(f.life / 0.85, 0.0, 1.0)
		draw_string_outline(_font, f.pos + Vector2(-40, 0), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.55 * a2))
		draw_string(_font, f.pos + Vector2(-40, 0), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(f.color, a2))
	draw_set_transform(shake)


# ---- UI ----------------------------------------------------------------------

func _label(text: String, size: int, color := INK, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font_size)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		match state_name:
			"hover", "focus":
				s.bg_color = color.lightened(0.18)
			"pressed":
				s.bg_color = color.darkened(0.18)
			_:
				s.bg_color = color
		s.border_color = color.lightened(0.4)
		s.set_border_width_all(2)
		s.set_corner_radius_all(12)
		s.content_margin_left = 28
		s.content_margin_right = 28
		s.content_margin_top = 8
		s.content_margin_bottom = 10
		b.add_theme_stylebox_override(state_name, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	return b


func _place(c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	return c


func _card(root: Control, key: int) -> VBoxContainer:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	_place(holder, Rect2(0, 0, STAGE.x, STAGE.y))
	root.add_child(holder)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.07, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, Rect2(FIELD_POS, FIELD))
	holder.add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(center, Rect2(FIELD_POS, FIELD))
	holder.add_child(center)
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.09, 0.18, 0.97)
	s.border_color = FRAME
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.shadow_color = Color(FRAME, 0.22)
	s.shadow_size = 16
	s.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", s)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	_cards[key] = holder
	return v


func _hud_block(root: Control, x: float, y: float, caption: String) -> Label:
	var cap := _label(caption, 16, MUTED)
	_place(cap, Rect2(x, y, 196, 22))
	root.add_child(cap)
	var val := _label("0", 34, INK)
	_place(val, Rect2(x, y + 22, 196, 44))
	root.add_child(val)
	return val


func _unlock_levels() -> void:
	for i in Levels.MENU_LEVELS:
		var ord := i + 1
		var b := _level_buttons[i]
		b.disabled = not Levels.is_unlocked(ord, scores)
		b.text = ("  Level %d" % ord) + ("  [locked]" if b.disabled else "")
	_trophy.visible = Levels.shows_trophy(scores)
	_show_level_info(1 if Levels.is_unlocked(1, scores) else 0)


func _show_level_info(ord: int) -> void:
	if ord >= 1 and ord <= Levels.MENU_LEVELS and not _level_buttons[ord - 1].disabled:
		var lvl := Levels.ord_level(ord)
		_preview.show_level(lvl)
		_preview.visible = true
		_level_name.text = Levels.level_name(ord)
		_level_blurb.text = Levels.level_text(ord)
		_best_time.text = Levels.best_time_text(lvl, scores)
	else:
		_preview.visible = false
		_level_name.text = ""
		_level_blurb.text = ""
		_best_time.text = ""


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.follow_viewport_enabled = false
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(root, Rect2(Vector2.ZERO, STAGE))
	_ui.add_child(root)

	var title_bar := _label("SHEP", 28, Color(FRAME.lightened(0.25)))
	title_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(title_bar, Rect2(860, 18, 200, 36))
	root.add_child(title_bar)
	var enh := _label("ENHANCED", 16, GOLD)
	enh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(enh, Rect2(1060, 24, 180, 24))
	root.add_child(enh)

	_clock_label = _label("02:00", 56, INK, 8)
	_place(_clock_label, Rect2(STAGE.x * 0.5 - 120, 6, 240, 60))
	root.add_child(_clock_label)

	var lives_cap := _label("FUSES SET", 16, MUTED)
	_place(lives_cap, Rect2(24, 100, 196, 22))
	root.add_child(lives_cap)
	_fuses_label = _label("0 / 0", 36, CYAN)
	_place(_fuses_label, Rect2(24, 122, 196, 48))
	root.add_child(_fuses_label)

	_legend = _label("CYAN fuse -> cyan socket\nRED fuse -> red socket\n(opens a door)\n\nMouse aims\nClick jets\nArrows = keyboard aim\n\nEsc arcade pause", 15, MUTED)
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(_legend, Rect2(36, 200, 172, 280))
	root.add_child(_legend)

	_objective = _label("Push each fuse into the matching socket, then dock.", 15, MUTED)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_objective, Rect2(1068, 100, 180, 90))
	root.add_child(_objective)

	var tip := _label("MATCH COLORS", 16, GOLD)
	_place(tip, Rect2(1060, 210, 196, 24))
	root.add_child(tip)
	var tip2 := _label("Rings on fuses and\nsockets share a color.\nDock Shep only after\nevery fuse is set.", 15, MUTED)
	tip2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(tip2, Rect2(1072, 238, 172, 120))
	root.add_child(tip2)

	_hint_label = _label("Dock Shep in a glowing socket", 24, GREEN, 6)
	_place(_hint_label, Rect2(FIELD_POS.x, FIELD_POS.y + FIELD.y - 48, FIELD.x, 36))
	root.add_child(_hint_label)
	_hint_label.visible = false
	_serve_pulse = _hint_label

	_mute_btn = _button("Sound", Color(0.22, 0.28, 0.48), 16)
	_mute_btn.focus_mode = Control.FOCUS_NONE
	_place(_mute_btn, Rect2(1068, 520, 180, 36))
	_mute_btn.pressed.connect(_toggle_mute)
	root.add_child(_mute_btn)
	_mute_btn.visible = false

	_pause_btn = _button("Pause", Color(0.28, 0.35, 0.58), 16)
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_place(_pause_btn, Rect2(1068, 566, 180, 36))
	_pause_btn.pressed.connect(_pause_game)
	root.add_child(_pause_btn)
	_pause_btn.visible = false

	# Title
	var tv := _card(root, TITLE)
	tv.add_child(_label("Shep", 72, Color.WHITE, 12))
	tv.add_child(_label("ENHANCED", 26, GOLD))
	tv.add_child(_label("Zero-g fuse puzzles on the Om-Nom-Nom.\nMatch fuse colors to sockets, then dock before the clock runs out.", 18, MUTED))
	var play := _button("Play", Color(0.20, 0.55, 0.85))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_set_state.bind(LEVEL_SELECT))
	tv.add_child(play)
	var how := _button("How to Play", Color(0.28, 0.32, 0.55), 20)
	how.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	how.pressed.connect(_help_from.bind(TITLE))
	tv.add_child(how)
	var cred := _button("Credits", Color(0.28, 0.32, 0.55), 20)
	cred.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cred.pressed.connect(_set_state.bind(CREDITS))
	tv.add_child(cred)

	# Pause
	var pv := _card(root, PAUSE)
	pv.add_child(_label("Paused", 64, Color.WHITE, 10))
	var resume := _button("Resume", Color(0.20, 0.55, 0.85))
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(_resume_game)
	pv.add_child(resume)
	var restart := _button("Restart Level", Color(0.35, 0.40, 0.62), 20)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(_restart_level)
	pv.add_child(restart)
	var exit_lvl := _button("Exit Level", Color(0.35, 0.40, 0.62), 20)
	exit_lvl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exit_lvl.pressed.connect(_exit_level)
	pv.add_child(exit_lvl)

	# Level select
	var ls_holder := Control.new()
	ls_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	ls_holder.visible = false
	_place(ls_holder, Rect2(0, 0, STAGE.x, STAGE.y))
	root.add_child(ls_holder)
	_cards[LEVEL_SELECT] = ls_holder
	var ls_shade := ColorRect.new()
	ls_shade.color = Color(0.02, 0.03, 0.08, 0.88)
	ls_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(ls_shade, Rect2(0, 0, STAGE.x, STAGE.y))
	ls_holder.add_child(ls_shade)
	var ls_title := _label("Choose a Level", 40, Color.WHITE, 8)
	_place(ls_title, Rect2(0, 40, STAGE.x, 50))
	ls_holder.add_child(ls_title)
	var ship := _label("Intari Asteroid Mining Ship  \"Om-Nom-Nom\"", 18, MUTED)
	_place(ship, Rect2(0, 88, STAGE.x, 28))
	ls_holder.add_child(ship)
	var vb := VBoxContainer.new()
	vb.position = Vector2(80, 140)
	vb.add_theme_constant_override("separation", 8)
	ls_holder.add_child(vb)
	for i in Levels.MENU_LEVELS:
		var b := _button("  Level %d" % (i + 1), Color(0.18, 0.28, 0.48), 22)
		b.custom_minimum_size = Vector2(280, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_start_level.bind(i + 1))
		b.mouse_entered.connect(_show_level_info.bind(i + 1))
		b.focus_entered.connect(_show_level_info.bind(i + 1))
		vb.add_child(b)
		_level_buttons.append(b)
	_preview = Preview.new()
	_preview.position = Vector2(480, 150)
	_preview.scale = Vector2(0.55, 0.55)
	_preview.modulate.a = 0.9
	ls_holder.add_child(_preview)
	_level_name = _label("", 28, GOLD)
	_level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(_level_name, Rect2(480, 480, 520, 36))
	ls_holder.add_child(_level_name)
	_level_blurb = _label("", 16, MUTED)
	_level_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_level_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_level_blurb, Rect2(480, 516, 520, 60))
	ls_holder.add_child(_level_blurb)
	_best_time = _label("", 18, CYAN)
	_best_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(_best_time, Rect2(480, 580, 520, 28))
	ls_holder.add_child(_best_time)
	_trophy = TextureRect.new()
	_trophy.texture = load(ART + "trophy.png")
	_trophy.position = Vector2(90, 620)
	_trophy.visible = false
	_trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ls_holder.add_child(_trophy)
	var back_title := _button("Return to Title", Color(0.30, 0.35, 0.58), 18)
	_place(back_title, Rect2(980, 640, 220, 40))
	back_title.pressed.connect(_set_state.bind(TITLE))
	ls_holder.add_child(back_title)

	# Victory / Defeat
	var vv := _card(root, VICTORY)
	_victory_box = vv
	vv.add_child(_label("Victory", 68, GOLD, 12))
	vv.add_child(_label("Shep is docked. Nice flying.", 20, MUTED))
	_replay = _button("Replay Level", Color(0.20, 0.55, 0.85), 22)
	_replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_replay.pressed.connect(_restart_level)
	vv.add_child(_replay)
	var map_btn := _button("Back to Map", Color(0.30, 0.35, 0.58), 20)
	map_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map_btn.pressed.connect(_set_state.bind(LEVEL_SELECT))
	vv.add_child(map_btn)
	_gameover_btns = [_replay, map_btn]

	var dv := _card(root, DEFEAT)
	_defeat_box = dv
	dv.add_child(_label("Time's Up", 68, RED, 12))
	dv.add_child(_label("The clock hit zero before Shep docked.", 20, MUTED))

	# Help
	var hv := _card(root, HELP)
	hv.add_child(_label("How to Play", 48, Color.WHITE, 10))
	hv.add_child(_label(
		"Move the mouse to aim Shep. Click to jet.\n"
		+ "Push every fuse into the socket of the same color.\n"
		+ "Cyan rings are plain fuses; red rings open doors.\n"
		+ "When the last fuse is set, dock Shep in any socket.\n"
		+ "You have two minutes. Esc opens the arcade pause.",
		18, MUTED))
	var hb := _button("Back", Color(0.30, 0.35, 0.58), 20)
	hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hb.pressed.connect(func(): _set_state(back_to_where))
	hv.add_child(hb)

	# Credits
	var cv := _card(root, CREDITS)
	cv.add_child(_label("Credits", 48, Color.WHITE, 10))
	cv.add_child(_label(
		"Original Shep (2010) by robocognito\n"
		+ "Michal J Wallace - programming, levels\n"
		+ "Sean D Siem - art, sound\n\n"
		+ "Enhanced presentation - GodotBot arcade port\n"
		+ "Same physics and puzzles as Direct.",
		18, MUTED))
	var cb := _button("Back", Color(0.30, 0.35, 0.58), 20)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cb.pressed.connect(_set_state.bind(TITLE))
	cv.add_child(cb)

	var back := _button("Back to Arcade", Color(0.25, 0.32, 0.65), 18)
	back.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat = back.get_theme_stylebox(st).duplicate()
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 6
		s.content_margin_bottom = 8
		back.add_theme_stylebox_override(st, s)
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)
