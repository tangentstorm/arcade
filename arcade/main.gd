extends Control
## Arcade gallery: card grid of all titles. Unplayable editions show Coming soon.

@onready var _list: GridContainer = %GameList


func _ready() -> void:
	_build_gallery()


func _build_gallery() -> void:
	for child in _list.get_children():
		child.queue_free()
	for id in GameRegistry.title_ids():
		if id == "_template":
			continue  # keep stub in project, hide from public gallery
		_list.add_child(_make_card(id))


func _make_card(id: String) -> Control:
	var direct = GameRegistry.get_entry(id, "direct")
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 200)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = direct.title
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	var art := ColorRect.new()
	art.custom_minimum_size = Vector2(0, 72)
	art.color = Color(0.15, 0.15, 0.22, 1)
	vbox.add_child(art)

	var coming := Label.new()
	coming.text = "Coming soon"
	coming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coming.modulate = Color(0.75, 0.75, 0.85, 1)
	vbox.add_child(coming)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	for edition in GameRegistry.EDITIONS:
		var entry = GameRegistry.get_entry(id, edition)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry != null and entry.is_playable():
			btn.text = edition.capitalize()
			btn.pressed.connect(GameRegistry.launch.bind(entry))
		else:
			btn.text = "%s · soon" % edition.capitalize()
			btn.disabled = true
		buttons.add_child(btn)

	return card
