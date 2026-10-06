extends Node2D
## LD48: Deeper and Deeper (Enhanced). Presentation makeover of the Direct
## Godot 4 port. Rooms, Ernie physics, teleporter, dialog script and assets are
## the Direct scenes/scripts (instanced, not copied). This file owns the
## 1280×720 letterbox shell, restyled chat/help chrome, juice, title card, and
## Back to Arcade. Esc is handled by the PauseOverlay autoload.
## No Alchementrix IP.

const ROOM0 := preload("res://games/ld48/direct/game.tscn")
const OFFICE := preload("res://games/ld48/direct/ivan_office.tscn")
const ICON_TEDDY := preload("res://games/ld48/direct/sprites/teddy-chat.png")
const ICON_ERNIE := preload("res://games/ld48/direct/sprites/ernie-chat.png")
const ICON_IVAN := preload("res://games/ld48/direct/sprites/ivan-chat.png")

const STAGE := Vector2(1280, 720)
## Full-stage SubViewport so Direct Camera2D framing (room0 zoom ⅓, office zoom ⅔) matches Direct.
const FIELD := Vector2(1280, 720)
const FIELD_POS := Vector2(0, 0)

const BG_TOP := Color(0.04, 0.05, 0.10)
const BG_BOTTOM := Color(0.08, 0.04, 0.12)
const PANEL := Color(0.08, 0.09, 0.18, 0.94)
const FRAME := Color(0.45, 0.78, 0.95)
const INK := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.58, 0.64, 0.82)
const GOLD := Color(1.0, 0.84, 0.32)
const AMBER := Color(0.95, 0.72, 0.25)

const NAMES := {
	"teddy": "Teddy Tetraminus",
	"ernie": "Ernie Goldsmile",
	"ivan": "Ivan C. Punchko",
}
const ACCENTS := {
	"teddy": Color(0.72, 0.35, 0.85),
	"ernie": Color(0.95, 0.78, 0.25),
	"ivan": Color(0.30, 0.75, 0.90),
}
const ICONS := {
	"teddy": ICON_TEDDY,
	"ernie": ICON_ERNIE,
	"ivan": ICON_IVAN,
}

enum { TITLE, PLAY }

var state := TITLE
var room_kind := "room0"  ## "room0" | "office"
var _room: Node = null
var _ernie: CharacterBody2D = null
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _particles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _ernie_was_floor := true
var _ernie_prev_pos := Vector2.ZERO
var _chat_visible := false
var _warp_progress := 0.0

var _vp_container: SubViewportContainer
var _viewport: SubViewport
var _ui: CanvasLayer
var _cards := {}
var _chat_panel: Panel
var _chat_scroll: ScrollContainer
var _chat_vbox: VBoxContainer
var _help_label: Label
var _room_label: Label
var _hint_label: Label
var _charge_label: Label
var _font: Font
var _panel_style := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_panel_style.bg_color = PANEL
	_panel_style.border_color = Color(FRAME, 0.45)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(14)
	_build_field()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_set_state(TITLE)


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
	_vp_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_vp_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(FIELD)
	_viewport.handle_input_locally = true
	_viewport.physics_object_picking = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp_container.add_child(_viewport)
	_vp_container.visible = false


func _set_state(s: int) -> void:
	state = s
	_vp_container.visible = s == PLAY
	for k in _cards:
		_cards[k].visible = (k == "title" and s == TITLE)
	if s == PLAY and _room == null:
		_load_room0()


func _load_room0() -> void:
	_clear_room()
	room_kind = "room0"
	_room = ROOM0.instantiate()
	_viewport.add_child(_room)
	var room_node: Node = _room.get_node("room")
	_ernie = room_node.get_node("sprites/ernie") as CharacterBody2D
	_ernie_was_floor = true
	_ernie_prev_pos = _ernie.global_position
	# Keep Direct scripts; intercept warp so the Enhanced shell stays put.
	var tele: Node = room_node.get_node("sprites/teleporter")
	if tele.teleport.is_connected(room_node._on_teleporter_teleport):
		tele.teleport.disconnect(room_node._on_teleporter_teleport)
	tele.teleport.connect(_on_warp_to_office)
	# Hide Direct camera-parented chrome; Enhanced owns chat/help.
	var sidebar: CanvasItem = _room.get_node("camshaker/camera/sidebar")
	var help: CanvasItem = _room.get_node("camshaker/camera/helptext")
	sidebar.visible = false
	help.visible = false
	if room_node.showchat.is_connected(sidebar._on_room_showchat):
		room_node.showchat.disconnect(sidebar._on_room_showchat)
	if room_node.helptext.is_connected(help._on_room_helptext):
		room_node.helptext.disconnect(help._on_room_helptext)
	if room_node.speak.is_connected(_room.get_node("camshaker/camera/sidebar/vbox/chatroom")._on_room0_speak):
		room_node.speak.disconnect(_room.get_node("camshaker/camera/sidebar/vbox/chatroom")._on_room0_speak)
	room_node.showchat.connect(_on_showchat)
	room_node.helptext.connect(_on_helptext)
	room_node.speak.connect(_on_speak)
	_clear_chat()
	_chat_visible = false
	_chat_panel.visible = false
	_help_label.text = ""
	_room_label.text = "Previously..."
	_hint_label.text = "A/D or <-/-> walk | Space jump | E interact | 0 skip dialog | R restart | Esc pause"
	_charge_label.text = ""


func _load_office() -> void:
	_clear_room()
	room_kind = "office"
	_room = OFFICE.instantiate()
	_viewport.add_child(_room)
	_ernie = _room.get_node("ernie") as CharacterBody2D
	_ernie_was_floor = true
	_ernie_prev_pos = _ernie.global_position
	_clear_chat()
	_chat_visible = false
	_chat_panel.visible = false
	_help_label.text = "Hold right mouse to aim | left-click to teleport"
	_room_label.text = "Ivan's office"
	_hint_label.text = "RMB aim | LMB teleport | R restart | Esc pause"
	_charge_label.text = ""
	_flash = 1.0
	_flash_color = Color(0.7, 0.9, 1.0)
	_shake = 0.55
	_spawn_burst(FIELD_POS + FIELD * 0.5, Color(0.55, 0.85, 1.0), 28)
	_floater("WARP!", FIELD_POS + Vector2(FIELD.x * 0.5, FIELD.y * 0.35), GOLD)


func _clear_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.queue_free()
	_room = null
	_ernie = null
	_warp_progress = 0.0


func _on_warp_to_office() -> void:
	_load_office()


func _on_showchat(flag: bool) -> void:
	_chat_visible = flag
	_chat_panel.visible = flag


func _on_helptext(msg: String) -> void:
	_help_label.text = str(msg)


func _on_speak(who: String, msg: String) -> void:
	var key := str(who).to_lower()
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var accent: Color = ACCENTS.get(key, FRAME)
	style.bg_color = Color(0.10, 0.11, 0.20, 0.96)
	style.border_color = accent
	style.set_border_width_all(2)
	style.border_width_left = 5
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ICONS.get(key, ICON_ERNIE)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = NAMES.get(key, who)
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", accent)
	col.add_child(name_l)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(200, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", INK)
	# Strip residual bbcode from Direct lines; we own the styling.
	var plain := str(msg).replace("[b]", "").replace("[/b]", "")
	body.text = plain
	col.add_child(body)
	_chat_vbox.add_child(card)
	await get_tree().process_frame
	_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)
	_floater(NAMES.get(key, who).split(" ")[0], FIELD_POS + Vector2(80, 40), accent)


func _clear_chat() -> void:
	if _chat_vbox == null:
		return
	for c in _chat_vbox.get_children():
		c.queue_free()


func _process(delta: float) -> void:
	_time += delta
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.2)
	_animate_particles(delta)
	if state == TITLE:
		queue_redraw()
		return
	_track_ernie_juice()
	_track_teleporter()
	# Mirror Direct quake into shell shake for chrome juice.
	if room_kind == "room0" and _room != null and is_instance_valid(_room):
		var shaker = _room.get_node_or_null("camshaker")
		if shaker and shaker.shake > 0:
			_shake = maxf(_shake, 0.25)
			if randf() < delta * 12.0:
				_spawn_dust(FIELD_POS + Vector2(randf() * FIELD.x, FIELD.y - 20.0), Color(0.55, 0.5, 0.4))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if state == TITLE:
		if event.is_action_pressed("ui_accept") or (
				event is InputEventKey and event.pressed and not event.echo
				and event.keycode in [KEY_SPACE, KEY_ENTER]):
			_set_state(PLAY)
			get_viewport().set_input_as_handled()


func _track_ernie_juice() -> void:
	if _ernie == null or not is_instance_valid(_ernie):
		return
	var on_floor := _ernie.is_on_floor()
	if on_floor and not _ernie_was_floor:
		# Landing puff.
		var local := _world_to_field(_ernie.global_position + Vector2(0, 40))
		_spawn_burst(local, Color(0.75, 0.7, 0.55), 10)
		_shake = maxf(_shake, 0.12)
	elif on_floor and absf(_ernie.global_position.x - _ernie_prev_pos.x) > 2.0:
		if randf() < 0.18:
			_spawn_dust(_world_to_field(_ernie.global_position + Vector2(0, 42)), Color(0.6, 0.55, 0.45, 0.7))
	_ernie_was_floor = on_floor
	_ernie_prev_pos = _ernie.global_position


func _track_teleporter() -> void:
	_warp_progress = 0.0
	_charge_label.text = ""
	if room_kind != "room0" or _room == null or not is_instance_valid(_room):
		return
	var tele = _room.get_node_or_null("room/sprites/teleporter")
	if tele == null:
		return
	if tele.interacting:
		_warp_progress = clampf(tele.time / tele.TRIGGER, 0.0, 1.0)
		_charge_label.text = "Charging... %d%%" % int(_warp_progress * 100.0)
		if randf() < 0.35:
			_spawn_dust(FIELD_POS + FIELD * 0.55 + Vector2(randf_range(-30, 30), randf_range(-40, 10)),
					Color(0.45, 0.85, 1.0))
	elif tele.visible and not tele.freeze and tele.position.y > 0:
		# Device is live in the world after dialog drops it.
		pass


func _world_to_field(world_pos: Vector2) -> Vector2:
	# Best-effort: map via the active Camera2D inside the SubViewport.
	if _viewport == null:
		return FIELD_POS + FIELD * 0.5
	var cam := _viewport.get_camera_2d()
	if cam == null:
		return FIELD_POS + FIELD * 0.5
	var half := Vector2(_viewport.size) * 0.5
	var local := (world_pos - cam.get_screen_center_position()) * cam.zoom + half
	return FIELD_POS + local * (FIELD / Vector2(_viewport.size))


func _spawn_burst(at: Vector2, color: Color, n: int) -> void:
	for i in n:
		_particles.append({
			"p": at,
			"v": Vector2(randf_range(-1, 1), randf_range(-1.2, -0.1)).normalized() * randf_range(40, 140),
			"life": randf_range(0.25, 0.7),
			"max": 0.7,
			"c": color,
			"r": randf_range(2.0, 5.0),
		})


func _spawn_dust(at: Vector2, color: Color) -> void:
	_particles.append({
		"p": at,
		"v": Vector2(randf_range(-20, 20), randf_range(-40, -10)),
		"life": randf_range(0.3, 0.6),
		"max": 0.6,
		"c": color,
		"r": randf_range(1.5, 3.5),
	})


func _floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"t": text, "p": at, "life": 0.9, "c": color})


func _animate_particles(delta: float) -> void:
	var next: Array[Dictionary] = []
	for p in _particles:
		p.life -= delta
		if p.life <= 0.0:
			continue
		p.p += p.v * delta
		p.v.y += 220.0 * delta
		next.append(p)
	_particles = next
	var fnext: Array[Dictionary] = []
	for f in _floaters:
		f.life -= delta
		if f.life <= 0.0:
			continue
		f.p.y -= 40.0 * delta
		fnext.append(f)
	_floaters = fnext


func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * _shake * _shake
	draw_rect(Rect2(Vector2.ZERO, STAGE), BG_TOP)
	draw_rect(Rect2(0, STAGE.y * 0.55, STAGE.x, STAGE.y * 0.45), BG_BOTTOM)
	# Field frame
	var fr := Rect2(FIELD_POS + shake, FIELD)
	draw_rect(fr.grow(6), Color(0.02, 0.03, 0.07))
	draw_rect(fr.grow(4), Color(FRAME, 0.4), false, 2.0)
	# Charge ring over the field when holding E on the teleporter.
	if _warp_progress > 0.0:
		var c := FIELD_POS + FIELD * 0.5 + shake
		draw_arc(c, 54.0, -PI * 0.5, -PI * 0.5 + TAU * _warp_progress, 48,
				Color(0.4, 0.9, 1.0, 0.85), 5.0, true)
	draw_set_transform(shake)
	for p in _particles:
		var a := clampf(p.life / p.max, 0.0, 1.0)
		draw_circle(p.p, p.r * a, Color(p.c, a))
	for f in _floaters:
		var a := clampf(f.life / 0.9, 0.0, 1.0)
		draw_string(_font, f.p, f.t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(f.c, a))
	draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, STAGE), Color(_flash_color, _flash * 0.5))
	# Soft vignette over the field only.
	if state == PLAY:
		draw_rect(Rect2(FIELD_POS, Vector2(FIELD.x, 18)), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(FIELD_POS.x, FIELD_POS.y + FIELD.y - 18, FIELD.x, 18), Color(0, 0, 0, 0.3))


# ---- UI ----------------------------------------------------------------------

func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.15) if st == "hover" else color.darkened(0.15) if st == "pressed" else color
		s.border_color = color.lightened(0.45)
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 6
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(st, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


func _panel(root: Control, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _panel_style.duplicate())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = rect.position
	p.size = rect.size
	root.add_child(p)
	return p


func _add(parent: Control, c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	parent.add_child(c)
	return c


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = STAGE
	_ui.add_child(root)

	var title := _label("DEEPER AND DEEPER", 26, FRAME.lightened(0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, title, Rect2(0, 8, STAGE.x, 34))
	var sub := _label("Enhanced  |  Ludum Dare 48  |  Tetraminex prologue", 14, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, sub, Rect2(0, 40, STAGE.x, 22))

	var back := _button("Back to Arcade", Color(0.25, 0.32, 0.65), 18)
	back.position = Vector2(14, 12)
	back.pressed.connect(GameRegistry.return_to_arcade)
	root.add_child(back)

	# Top-right chrome: room + controls (floats over the full-bleed field)
	var rp := _panel(root, Rect2(STAGE.x - 268, 64, 248, 280))
	_add(rp, _label("ROOM", 13, MUTED), Rect2(14, 12, 220, 18))
	_room_label = _add(rp, _label("-", 18, GOLD), Rect2(14, 32, 220, 24)) as Label
	_add(rp, _label("CONTROLS", 13, MUTED), Rect2(14, 70, 220, 18))
	_hint_label = _add(rp, _label("", 12, INK), Rect2(14, 90, 220, 90)) as Label
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(rp, _label("CHARGE", 13, MUTED), Rect2(14, 190, 220, 18))
	_charge_label = _add(rp, _label("", 16, FRAME), Rect2(14, 210, 220, 24)) as Label
	_add(rp, _label("Same rooms & physics as Direct.", 12, MUTED), Rect2(14, 244, 220, 20))

	# Chat overlay (left), restyled Direct sidebar
	_chat_panel = _panel(root, Rect2(16, 64, 320, 540))
	_chat_panel.visible = false
	_add(_chat_panel, _label("TETRAMINEX CHAT", 14, FRAME), Rect2(14, 10, 290, 22))
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_add(_chat_panel, _chat_scroll, Rect2(10, 40, 300, 480))
	_chat_vbox = VBoxContainer.new()
	_chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_vbox.add_theme_constant_override("separation", 8)
	_chat_scroll.add_child(_chat_vbox)

	# Help toast
	_help_label = _label("", 18, GOLD)
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(root, _help_label, Rect2(20, STAGE.y - 48, STAGE.x - 40, 32))

	# Title card
	var title_holder := Control.new()
	title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, title_holder, Rect2(Vector2.ZERO, STAGE))
	_cards["title"] = title_holder
	var tc := CenterContainer.new()
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(title_holder, tc, Rect2(0, 64, STAGE.x, STAGE.y - 64))
	var tp := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.07, 0.08, 0.18, 0.95)
	ts.border_color = FRAME
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(16)
	ts.content_margin_left = 36
	ts.content_margin_right = 36
	ts.content_margin_top = 28
	ts.content_margin_bottom = 28
	tp.add_theme_stylebox_override("panel", ts)
	tc.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	tp.add_child(tv)
	var t1 := _label("DEEPER AND DEEPER", 32, FRAME.lightened(0.25))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t1)
	var t2 := _label("An Enhanced makeover of the LD48 jam prologue.", 15, MUTED)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t2)
	var t3 := _label("Same rooms, Ernie physics, and dialog as Direct.", 14, MUTED)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t3)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	tv.add_child(gap)
	var play := _button("Press Space to begin", Color(0.20, 0.55, 0.75), 20)
	play.pressed.connect(func(): _set_state(PLAY))
	tv.add_child(play)
	var t4 := _label("Esc opens Pause | Back to Arcade never steals focus", 12, MUTED)
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t4)
