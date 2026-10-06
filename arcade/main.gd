extends Control
## Arcade gallery: full-bleed card grid, one card per title.
## Global Original (Direct) / Enhanced mode switch drives every card.
## Each card is a clickable screenshot with the game name underneath.

const PREVIEW_DIR := "res://arcade/previews"
const PREF_PATH := "user://arcade_prefs.cfg"
const CARD_MIN_W := 260.0
const CARD_GAP := 16
const PREVIEW_ASPECT := 16.0 / 9.0

@onready var _list: GridContainer = %GameList
@onready var _scroll: ScrollContainer = %Scroll
@onready var _mode_direct: Button = %ModeDirect
@onready var _mode_enhanced: Button = %ModeEnhanced
@onready var _mode_hint: Label = %ModeHint

var _edition: String = "direct"  ## "direct" (Original) or "enhanced"
var _cards: Dictionary = {}  ## id -> PanelContainer
var _hover_style: StyleBoxFlat
var _normal_style: StyleBoxFlat
var _muted_style: StyleBoxFlat
var _focus_style: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_load_pref()
	_wire_mode_switch()
	_apply_mode_buttons()
	_list.add_theme_constant_override("h_separation", CARD_GAP)
	_list.add_theme_constant_override("v_separation", CARD_GAP)
	_build_gallery()
	resized.connect(_reflow_columns)
	_scroll.resized.connect(_reflow_columns)
	await get_tree().process_frame
	_reflow_columns()


func _build_styles() -> void:
	_normal_style = _card_style(Color(0.12, 0.12, 0.18, 1), Color(0.28, 0.30, 0.42, 1), 1)
	_hover_style = _card_style(Color(0.16, 0.17, 0.26, 1), Color(0.45, 0.55, 0.95, 1), 2)
	_muted_style = _card_style(Color(0.09, 0.09, 0.12, 1), Color(0.20, 0.20, 0.26, 1), 1)
	_focus_style = _card_style(Color(0.14, 0.15, 0.24, 1), Color(0.70, 0.78, 1.0, 1), 2)


func _card_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(12)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


func _wire_mode_switch() -> void:
	_style_mode_pill(_mode_direct, true)
	_style_mode_pill(_mode_enhanced, false)
	_mode_direct.pressed.connect(_set_edition.bind("direct"))
	_mode_enhanced.pressed.connect(_set_edition.bind("enhanced"))
	_mode_direct.focus_mode = Control.FOCUS_ALL
	_mode_enhanced.focus_mode = Control.FOCUS_ALL


func _style_mode_pill(btn: Button, left: bool) -> void:
	## Segmented control look: shared pill, active fill, clear focus ring.
	for state in ["normal", "pressed", "hover", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_border_width_all(1)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		if left:
			s.corner_radius_top_left = 20
			s.corner_radius_bottom_left = 20
			s.corner_radius_top_right = 0
			s.corner_radius_bottom_right = 0
		else:
			s.corner_radius_top_left = 0
			s.corner_radius_bottom_left = 0
			s.corner_radius_top_right = 20
			s.corner_radius_bottom_right = 20
		match state:
			"pressed":
				s.bg_color = Color(0.35, 0.45, 0.95, 1)
				s.border_color = Color(0.55, 0.65, 1.0, 1)
			"hover":
				s.bg_color = Color(0.22, 0.24, 0.38, 1)
				s.border_color = Color(0.45, 0.50, 0.75, 1)
			"focus":
				s.bg_color = Color(0.20, 0.22, 0.36, 1)
				s.border_color = Color(0.75, 0.82, 1.0, 1)
				s.set_border_width_all(2)
			"disabled":
				s.bg_color = Color(0.12, 0.12, 0.16, 1)
				s.border_color = Color(0.22, 0.22, 0.28, 1)
			_:
				s.bg_color = Color(0.14, 0.15, 0.22, 1)
				s.border_color = Color(0.32, 0.34, 0.48, 1)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.96, 1.0, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.add_theme_font_size_override("font_size", 15)


func _set_edition(edition: String) -> void:
	if _edition == edition:
		_apply_mode_buttons()
		return
	_edition = edition
	_save_pref()
	_apply_mode_buttons()
	_refresh_cards()


func _apply_mode_buttons() -> void:
	var is_direct := _edition == "direct"
	_mode_direct.set_pressed_no_signal(is_direct)
	_mode_enhanced.set_pressed_no_signal(not is_direct)
	_mode_direct.button_pressed = is_direct
	_mode_enhanced.button_pressed = not is_direct
	var label := "Original" if is_direct else "Enhanced"
	_mode_hint.text = "Showing %s editions — click a screenshot to play." % label


func _load_pref() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREF_PATH) != OK:
		return
	var ed := str(cfg.get_value("gallery", "edition", "direct"))
	if ed in ["direct", "enhanced"]:
		_edition = ed


func _save_pref() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREF_PATH)
	cfg.set_value("gallery", "edition", _edition)
	cfg.save(PREF_PATH)


func _build_gallery() -> void:
	for child in _list.get_children():
		child.queue_free()
	_cards.clear()
	for id in GameRegistry.title_ids():
		if id == "_template":
			continue
		var card := _make_card(id)
		_list.add_child(card)
		_cards[id] = card
	_refresh_cards()


func _reflow_columns() -> void:
	## Fit columns to the visible scroll width so cards wrap to new rows and
	## only the ScrollContainer scrolls vertically (no horizontal overflow).
	var avail := _scroll.size.x
	if avail < 64.0:
		avail = maxf(size.x - 40.0, 64.0)
	## Always reserve the vertical scrollbar's width; otherwise the grid is
	## exactly as wide as the ScrollContainer and the bar pushes it past.
	avail = maxf(avail - _scroll.get_v_scroll_bar().get_combined_minimum_size().x, 64.0)
	var cols := maxi(1, int(floor((avail + float(CARD_GAP)) / (CARD_MIN_W + float(CARD_GAP)))))
	## Exact cell width that fills `avail` for `cols` (may be > CARD_MIN_W).
	## Never bump above a fitting width — that caused side-scrolling.
	var cell_w := floorf((avail - float(CARD_GAP) * float(cols - 1)) / float(cols))
	cell_w = maxf(cell_w, 1.0)
	if _list.columns != cols:
		_list.columns = cols
	## Keep the grid's own min width from exceeding the viewport.
	_list.custom_minimum_size = Vector2(0, 0)
	var preview_h := cell_w / PREVIEW_ASPECT
	for id in _cards:
		var card: PanelContainer = _cards[id]
		card.custom_minimum_size = Vector2(cell_w, preview_h + 44.0)
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if card.has_meta("preview_host"):
			var host: Control = card.get_meta("preview_host")
			host.custom_minimum_size = Vector2(0, preview_h)
	## We run inside the scroll's own resize, so the card min-size changes above
	## don't refresh its cached child size: the bar range stays one resize stale
	## and the bottom rows become unreachable. Re-read it now.
	_scroll.update_minimum_size()


func _make_card(id: String) -> Control:
	var direct = GameRegistry.get_entry(id, "direct")
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta("game_id", id)
	card.add_theme_stylebox_override("panel", _normal_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	var preview_host := Control.new()
	preview_host.name = "PreviewHost"
	preview_host.custom_minimum_size = Vector2(0, 146)
	preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_host.clip_contents = true
	vbox.add_child(preview_host)
	card.set_meta("preview_host", preview_host)

	var tex := TextureRect.new()
	tex.name = "Preview"
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_host.add_child(tex)
	card.set_meta("preview", tex)

	var placeholder := ColorRect.new()
	placeholder.name = "Placeholder"
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.color = Color(0.14, 0.14, 0.20, 1)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_host.add_child(placeholder)
	card.set_meta("placeholder", placeholder)

	# Coming-soon veil + label drawn ON the screenshot (screenshot is the CTA).
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.05, 0.05, 0.08, 0.55)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.visible = false
	preview_host.add_child(veil)
	card.set_meta("veil", veil)

	var overlay := Label.new()
	overlay.name = "OverlayLabel"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_theme_font_size_override("font_size", 18)
	overlay.add_theme_color_override("font_color", Color(0.92, 0.93, 1.0, 0.95))
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_host.add_child(overlay)
	card.set_meta("overlay", overlay)

	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left", 10)
	footer.add_theme_constant_override("margin_right", 10)
	footer.add_theme_constant_override("margin_top", 8)
	footer.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(footer)

	var title := Label.new()
	title.text = direct.title if direct else id
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.add_child(title)
	card.set_meta("title", title)

	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))
	card.focus_entered.connect(_on_card_focus.bind(card, true))
	card.focus_exited.connect(_on_card_focus.bind(card, false))
	card.gui_input.connect(_on_card_gui.bind(card))

	return card


func _on_card_hover(card: PanelContainer, on: bool) -> void:
	if card.has_meta("playable") and not card.get_meta("playable"):
		return
	if card.has_focus():
		return
	card.add_theme_stylebox_override("panel", _hover_style if on else _normal_style)


func _on_card_focus(card: PanelContainer, on: bool) -> void:
	if card.has_meta("playable") and not card.get_meta("playable"):
		card.add_theme_stylebox_override("panel", _muted_style)
		return
	card.add_theme_stylebox_override("panel", _focus_style if on else _normal_style)


func _on_card_gui(event: InputEvent, card: PanelContainer) -> void:
	if not (card.has_meta("playable") and card.get_meta("playable")):
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_launch_card(card)
		card.accept_event()
		return
	if event.is_action_pressed("ui_accept"):
		_launch_card(card)
		card.accept_event()


func _launch_card(card: PanelContainer) -> void:
	var id: String = card.get_meta("game_id")
	var entry = GameRegistry.get_entry(id, _edition)
	if entry != null and entry.is_playable():
		GameRegistry.launch(entry)


func _refresh_cards() -> void:
	for id in _cards:
		_update_card(_cards[id], id)
	_reflow_columns()


func _update_card(card: PanelContainer, id: String) -> void:
	var entry = GameRegistry.get_entry(id, _edition)
	var playable := entry != null and entry.is_playable()
	card.set_meta("playable", playable)

	var tex: TextureRect = card.get_meta("preview")
	var placeholder: ColorRect = card.get_meta("placeholder")
	var veil: ColorRect = card.get_meta("veil")
	var overlay: Label = card.get_meta("overlay")
	var title: Label = card.get_meta("title")

	# Per-edition shot when one exists (e.g. <id>_enhanced.png), else the Direct one.
	var preview_path := "%s/%s_%s.png" % [PREVIEW_DIR, id, _edition]
	if not ResourceLoader.exists(preview_path):
		preview_path = "%s/%s_direct.png" % [PREVIEW_DIR, id]
	var has_shot := ResourceLoader.exists(preview_path)
	if has_shot:
		tex.texture = load(preview_path)
		tex.visible = true
		placeholder.visible = false
	else:
		tex.texture = null
		tex.visible = false
		placeholder.visible = true
		placeholder.color = Color(0.14, 0.14, 0.20, 1) if playable else Color(0.10, 0.10, 0.13, 1)

	if playable:
		veil.visible = false
		overlay.text = ""
		overlay.visible = false
		tex.modulate = Color(1, 1, 1, 1)
		title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1))
		card.add_theme_stylebox_override("panel", _normal_style)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.focus_mode = Control.FOCUS_ALL
		card.modulate = Color(1, 1, 1, 1)
		# Playable but no shot yet: keep a quiet label on the placeholder, not a CTA button.
		if not has_shot:
			overlay.text = "Preview pending"
			overlay.visible = true
			overlay.add_theme_color_override("font_color", Color(0.70, 0.74, 0.88, 0.9))
	else:
		var reason := "Coming soon"
		if entry != null and entry.status == "wip":
			reason = "Not working yet"
		veil.visible = has_shot
		overlay.text = reason
		overlay.visible = true
		overlay.add_theme_color_override("font_color", Color(0.90, 0.92, 1.0, 0.95))
		if has_shot:
			tex.modulate = Color(0.55, 0.55, 0.62, 1)
		else:
			tex.modulate = Color(1, 1, 1, 1)
		title.add_theme_color_override("font_color", Color(0.60, 0.62, 0.72, 1))
		card.add_theme_stylebox_override("panel", _muted_style)
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		card.focus_mode = Control.FOCUS_ALL
		card.modulate = Color(0.88, 0.88, 0.92, 1)
