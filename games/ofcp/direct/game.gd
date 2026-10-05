extends Control
## OFCP — Direct edition: thin Godot client for the live OFCP server.
##
## All rules, dealing, scoring and the AI opponent run server-side at
## wss://ofcp.tangentcode.com/ws. This scene only renders game_state messages
## and sends the player's placements. No rules engine or AI weights ship here.
##
## Controls: click a hand card, then a row (or press 1/2/3 = top/middle/bottom).
## Enter = confirm, H = hint, Backspace = clear, N = new hand. Esc = arcade pause.

const OfcpWs := preload("res://games/ofcp/direct/ofcp_ws.gd")
const OfcpTable := preload("res://games/ofcp/direct/ofcp_table.gd")
const SuitIcon := preload("res://games/ofcp/direct/suit_icon.gd")

const MODES := ["normal", "windfall", "progressive"]
const MODE_LABELS := ["Cash / normal", "Windfall", "Progressive"]
const ROW_LABEL := {"top": "Top", "middle": "Middle", "bottom": "Bottom"}

const FELT := Color(0.06, 0.28, 0.16)
const CARD_BG := Color(0.97, 0.97, 0.94)
const RED := Color(0.78, 0.08, 0.1)
const BLACK := Color(0.08, 0.08, 0.1)

var ws: Node
var table := OfcpTable.new()
var selected: Dictionary = {}
var session_id := ""
var profile := ""
var game_started := false
var waiting_for_server := false
var hint_pending := false
var _last_result := ""

# UI refs
var _status: Label
var _scores: Label
var _phase: Label
var _breakdown: RichTextLabel
var _log: RichTextLabel
var _opp_box: VBoxContainer
var _my_rows := {}        # row -> HBoxContainer (cards)
var _row_buttons := {}    # row -> Button
var _hand_box: HBoxContainer
var _confirm_btn: Button
var _hint_btn: Button
var _clear_btn: Button
var _new_hand_btn: Button
var _overlay: PanelContainer
var _overlay_msg: Label
var _mode_opt: OptionButton
var _play_btn: Button
var _reconnect_btn: Button


func _ready() -> void:
	_build_ui()
	ws = OfcpWs.new()
	ws.name = "OfcpWs"
	add_child(ws)
	ws.opened.connect(_on_ws_opened)
	ws.closed.connect(_on_ws_closed)
	ws.message_received.connect(_on_message)
	_refresh()
	if DisplayServer.get_name() == "headless":
		_set_overlay("Headless run: not connecting to the live server.", false)
		return
	_connect()


func _exit_tree() -> void:
	if ws != null:
		ws.close()


# ---------------------------------------------------------------- networking

func _connect() -> void:
	game_started = false
	session_id = ""
	table = OfcpTable.new()
	selected = {}
	_set_overlay("Connecting to %s …" % OfcpWs.DEFAULT_URL, false)
	var err: Error = ws.connect_to_server(OfcpWs.DEFAULT_URL)
	if err != OK:
		_set_overlay("Could not start connection (error %d)." % err, false, true)
	_refresh()


func _send(msg: Dictionary) -> void:
	if not ws.send_msg(msg):
		_log_line("[color=salmon]not connected — message not sent[/color]")
		return
	waiting_for_server = msg.type in ["place_initial", "place_pineapple", "start_game", "new_hand"]


func _on_ws_opened() -> void:
	_status_text("Connected", Color.PALE_GREEN)


func _on_ws_closed(code: int, reason: String) -> void:
	var why := "code %d" % code
	if reason != "":
		why += ", " + reason
	var hint := ""
	if code == -1 or code == 1006:
		if OS.has_feature("web"):
			hint = "\nThe server only accepts pages served from https://tangentstorm.github.io."
		else:
			hint = "\nIf this persists the server may be down, or rejecting this Origin (403)."
	_status_text("Disconnected", Color.SALMON)
	_log_line("[color=salmon]disconnected (%s)[/color]" % why)
	_set_overlay("Disconnected from server (%s).%s" % [why, hint], false, true)
	waiting_for_server = false
	_refresh()


func _on_message(msg: Dictionary) -> void:
	var t := String(msg.get("type", ""))
	match t:
		"connected":
			session_id = String(msg.get("sessionId", ""))
			_log_line("connected as %s (session %s)" % [msg.get("playerId", "?"), session_id])
		"waiting":
			_set_overlay("Connected. Heads-up vs 1 AI — choose a mode:", true)
		"ready":
			profile = String(msg.get("profile", msg.get("mode", "")))
			if msg.has("sessionId"):
				session_id = String(msg.sessionId)
			_log_line("ready: %s, profile %s" % [", ".join(PackedStringArray(msg.get("players", []))), profile])
			game_started = true
			_hide_overlay()
			_send({"type": "start_game"})
		"game_state":
			waiting_for_server = false
			var was_over := table.is_game_over()
			table.apply_state(msg)
			if not table.is_pending(selected) and not _in_unplaced(selected):
				selected = {}
			_auto_select()
			if table.is_game_over() and not was_over:
				_log_line("hand over — total %+d" % table.my_score())
		"hint":
			hint_pending = false
			if table.apply_hint(msg):
				selected = {}
				_auto_select()
				_log_line("hint applied (review, then Confirm)")
			else:
				_log_line("hint received but could not be applied")
		"flagged":
			_log_line("hand flagged for review")
		"error":
			waiting_for_server = false
			hint_pending = false
			var m := String(msg.get("message", "error"))
			_log_line("[color=salmon]server: %s[/color]" % m)
			_status_text(m, Color.SALMON)
		_:
			_log_line("(ignored message type '%s')" % t)
	_refresh()


# ---------------------------------------------------------------- actions

func _on_play_pressed() -> void:
	if not ws.is_open():
		_connect()
		return
	var mode: String = MODES[_mode_opt.selected]
	_set_overlay("Starting vs AI (%s) …" % mode, false)
	_send({"type": "start_vs_ai", "aiCount": 1, "mode": mode})


func _on_confirm() -> void:
	if waiting_for_server:
		return  # guard against double submits (e.g. repeated key events on Web)
	var msg := table.build_submit()
	if msg.is_empty():
		return
	_send(msg)
	selected = {}
	_refresh()


func _on_hint() -> void:
	if table.is_my_turn() and not hint_pending and not waiting_for_server:
		hint_pending = true
		_send({"type": "get_hint"})
		_refresh()


func _on_clear() -> void:
	table.clear_pending()
	selected = {}
	_auto_select()
	_refresh()


func _on_new_hand() -> void:
	if table.is_game_over():
		_send({"type": "new_hand"})
		_refresh()


func _on_back() -> void:
	ws.close()
	GameRegistry.return_to_arcade()


func _on_hand_card(c: Dictionary) -> void:
	selected = {} if OfcpTable.card_eq(selected, c) else c
	_refresh()


func _on_row(row: String) -> void:
	if selected.is_empty():
		_auto_select()
	if selected.is_empty():
		return
	if table.place(selected, row):
		selected = {}
		_auto_select()
	_refresh()


func _on_pending_card(c: Dictionary) -> void:
	if table.unplace(c):
		selected = c
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_T:
			_on_row("top")
		KEY_2, KEY_M:
			_on_row("middle")
		KEY_3, KEY_B:
			_on_row("bottom")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if table.is_game_over():
				_on_new_hand()
			else:
				_on_confirm()
		KEY_H:
			_on_hint()
		KEY_BACKSPACE:
			_on_clear()
		KEY_N:
			_on_new_hand()
		_:
			return
	get_viewport().set_input_as_handled()


func _auto_select() -> void:
	if not selected.is_empty() or not table.is_my_turn():
		return
	if table.pending.size() >= table.need_place():
		return
	var rest := table.unplaced()
	if rest.size() > 0:
		selected = rest[0]


func _in_unplaced(c: Dictionary) -> bool:
	if c.is_empty():
		return false
	for u in table.unplaced():
		if OfcpTable.card_eq(u, c):
			return true
	return false


# ---------------------------------------------------------------- rendering

func _refresh() -> void:
	if _status == null:
		return
	var my_turn := table.is_my_turn()
	# phase / prompt
	var ph := table.phase()
	var prompt := ""
	if not game_started:
		prompt = ""
	elif table.is_game_over():
		prompt = "Hand over. Press New Hand (N) to deal again."
	elif my_turn:
		var need := table.need_place()
		var discard := table.hand().size() - need
		prompt = "Your turn: place %d card%s" % [need, "" if need == 1 else "s"]
		if discard > 0:
			prompt += ", discard %d (the unplaced card%s)" % [discard, "" if discard == 1 else "s"]
		prompt += ".  %d/%d placed." % [table.pending.size(), need]
	elif ph != "":
		prompt = "AI is thinking…"
	if waiting_for_server and not table.is_game_over():
		prompt = "Waiting for server…"
	_phase.text = prompt
	var round_txt := ""
	if ph != "" and not table.is_game_over():
		round_txt = "  ·  %s, street %d" % [ph.capitalize(), int(table.state.get("round", 0)) + 1]
	var opp_score := 0
	var s := table.scores()
	for i in s.size():
		if i != table.my_index():
			opp_score += int(s[i])
	_scores.text = "Score  You %+d  ·  AI %+d%s%s" % [table.my_score(), opp_score,
		("  ·  " + profile) if profile != "" else "", round_txt]

	_render_opponents()
	_render_my_board()
	_render_hand()
	_render_breakdown()

	_confirm_btn.disabled = not table.can_submit() or waiting_for_server
	_hint_btn.disabled = not my_turn or hint_pending or waiting_for_server
	_clear_btn.disabled = table.pending.is_empty()
	_new_hand_btn.disabled = not table.is_game_over() or waiting_for_server
	_new_hand_btn.visible = table.is_game_over()
	_confirm_btn.visible = not table.is_game_over()


func _render_opponents() -> void:
	for ch in _opp_box.get_children():
		ch.queue_free()
	var opps := table.opponents()
	if opps.is_empty():
		var l := Label.new()
		l.text = "Opponent board appears here."
		l.modulate = Color(1, 1, 1, 0.6)
		_opp_box.add_child(l)
		return
	for o in opps:
		var head := Label.new()
		var fl := "  (Fantasyland)" if o.get("fantasyland", false) else ""
		head.text = "AI %d%s" % [int(o.get("index", 0)), fl]
		_opp_box.add_child(head)
		var b: Dictionary = o.get("board", {})
		for row in OfcpTable.ROWS:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 4)
			var rl := Label.new()
			rl.text = ROW_LABEL[row]
			rl.custom_minimum_size = Vector2(70, 0)
			hb.add_child(rl)
			var cards: Array = b.get(row, [])
			for c in cards:
				hb.add_child(_card_widget(c, Vector2(40, 54), "plain"))
			for _i in OfcpTable.ROW_CAP[row] - cards.size():
				hb.add_child(_slot_widget(Vector2(40, 54)))
			_opp_box.add_child(hb)


func _render_my_board() -> void:
	var my_turn := table.is_my_turn()
	for row in OfcpTable.ROWS:
		var hb: HBoxContainer = _my_rows[row]
		for ch in hb.get_children():
			ch.queue_free()
		var cards := table.row_cards(row)
		for c in cards:
			hb.add_child(_card_widget(c, Vector2(56, 78), "plain"))
		var pend := table.pending_in_row(row)
		for c in pend:
			var w := _card_widget(c, Vector2(56, 78), "pending")
			w.pressed.connect(_on_pending_card.bind(c))
			w.tooltip_text = "Click to take back"
			hb.add_child(w)
		for _i in OfcpTable.ROW_CAP[row] - cards.size() - pend.size():
			hb.add_child(_slot_widget(Vector2(56, 78)))
		var btn: Button = _row_buttons[row]
		var space := table.row_space(row)
		btn.text = "%s  (%d)" % [ROW_LABEL[row], space]
		btn.disabled = not my_turn or space <= 0 or table.pending.size() >= table.need_place()


func _render_hand() -> void:
	for ch in _hand_box.get_children():
		ch.queue_free()
	var rest := table.unplaced()
	var full := table.is_my_turn() and table.pending.size() >= table.need_place()
	for c in rest:
		var style := "selected" if OfcpTable.card_eq(c, selected) else "plain"
		if full:
			style = "discard"
		var w := _card_widget(c, Vector2(64, 90), style)
		w.disabled = not table.is_my_turn() or full
		w.pressed.connect(_on_hand_card.bind(c))
		_hand_box.add_child(w)
	if rest.is_empty():
		var l := Label.new()
		l.text = "(no cards in hand)" if game_started else ""
		l.modulate = Color(1, 1, 1, 0.6)
		_hand_box.add_child(l)
	elif full:
		var l := Label.new()
		l.text = "<- discard"
		_hand_box.add_child(l)


func _render_breakdown() -> void:
	if not table.is_game_over():
		_breakdown.text = _last_result if _last_result != "" else "[i]Last hand results appear here.[/i]"
		return
	var lines: PackedStringArray = []
	var opps := table.opponents()
	for i in opps.size():
		var bd := table.breakdown(i)
		if bd.is_empty():
			continue
		var a: Dictionary = bd.get("playerA", {})
		var b: Dictionary = bd.get("playerB", {})
		lines.append("[b]vs AI %d[/b]" % int(opps[i].get("index", i + 1)))
		if a.get("fouled", false):
			lines.append("[color=salmon]You fouled![/color]")
		if b.get("fouled", false):
			lines.append("[color=palegreen]AI fouled![/color]")
		var ar: Array = a.get("rows", [])
		var br: Array = b.get("rows", [])
		for r in ar.size():
			var ra: Dictionary = ar[r]
			var rb: Dictionary = br[r] if r < br.size() else {}
			var w := String(ra.get("winner", "tie"))
			var mark := "=" if w == "tie" else ("[color=palegreen]WIN[/color]" if w == "A" else "[color=salmon]loss[/color]")
			lines.append("%s: %s%s vs %s%s  %s" % [
				ROW_LABEL.get(ra.get("row", ""), ra.get("row", "")),
				ra.get("rank", ""), _roy(ra), rb.get("rank", ""), _roy(rb), mark])
		var rw: Dictionary = bd.get("rowWins", {})
		lines.append("Rows %d–%d" % [int(rw.get("A", 0)), int(rw.get("B", 0))])
		var scoop = bd.get("scoop", null)
		if scoop != null and String(scoop) != "" and String(scoop) != "<null>":
			lines.append("Scoop: %s (+%d)" % ["you" if String(scoop) == "A" else "AI", int(bd.get("scoopBonus", 0))])
		lines.append("Royalties %d vs %d" % [int(a.get("totalRoyalties", 0)), int(b.get("totalRoyalties", 0))])
		var net := int(bd.get("netScore", 0))
		lines.append("[b]Hand: %+d[/b]" % net)
	if table.is_fantasyland():
		lines.append("[color=gold]You're in Fantasyland next hand![/color]")
	_last_result = "\n".join(lines)
	_breakdown.text = _last_result


func _roy(r: Dictionary) -> String:
	var n := int(r.get("royalties", 0))
	return " (+%d)" % n if n > 0 else ""


func _card_widget(c: Dictionary, sz: Vector2, style: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = OfcpTable.card_str(c)
	var fg := RED if OfcpTable.is_red(c) else BLACK
	# rank label + drawn suit pip (fonts on Web lack the suit glyphs)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(center)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 1)
	center.add_child(hb)
	var rank := Label.new()
	var r := String(c.get("rank", "?"))
	rank.text = "10" if r == "T" else r
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank.add_theme_font_size_override("font_size", int(sz.y * 0.3))
	rank.add_theme_color_override("font_color", fg)
	hb.add_child(rank)
	var pip := SuitIcon.new(String(c.get("suit", "s")), fg)
	pip.custom_minimum_size = Vector2(sz.y * 0.24, sz.y * 0.24)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(pip)
	var bg := CARD_BG
	var border := Color(0.3, 0.3, 0.3)
	var bw := 1
	match style:
		"selected":
			border = Color.GOLD
			bw = 4
		"pending":
			bg = Color(1.0, 0.95, 0.7)
			border = Color.ORANGE
			bw = 3
		"discard":
			bg = Color(0.8, 0.8, 0.8)
			border = Color.INDIAN_RED
			bw = 3
	var sb := _box(bg, border, bw)
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, sb)
	return b


func _slot_widget(sz: Vector2) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = sz
	p.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.15), Color(1, 1, 1, 0.2), 1))
	return p


func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(6)
	return sb


func _status_text(t: String, col: Color) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", col)


func _log_line(t: String) -> void:
	_log.append_text(t + "\n")


func _set_overlay(text: String, can_play: bool, can_reconnect: bool = false) -> void:
	_overlay.visible = true
	_overlay_msg.text = text
	_play_btn.visible = can_play
	_mode_opt.visible = can_play
	_reconnect_btn.visible = can_reconnect
	if can_play:
		_play_btn.grab_focus()
	elif can_reconnect:
		_reconnect_btn.grab_focus()


func _hide_overlay() -> void:
	_overlay.visible = false


# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = FELT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	var title := Label.new()
	title.text = "OFCP · Pineapple  (Direct · live server)"
	title.add_theme_font_size_override("font_size", 24)
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_status = Label.new()
	top.add_child(_status)
	_status_text("Offline", Color(1, 1, 1, 0.7))
	var back := Button.new()
	back.text = "Back to Arcade"
	back.pressed.connect(_on_back)
	top.add_child(back)

	_scores = Label.new()
	_scores.add_theme_font_size_override("font_size", 18)
	root.add_child(_scores)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	root.add_child(main)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	main.add_child(left)

	var you_lbl := Label.new()
	you_lbl.text = "Your board"
	left.add_child(you_lbl)
	for row in OfcpTable.ROWS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(120, 78)
		rb.focus_mode = Control.FOCUS_NONE
		rb.tooltip_text = "Place the selected card here"
		rb.pressed.connect(_on_row.bind(row))
		hb.add_child(rb)
		_row_buttons[row] = rb
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		hb.add_child(cards)
		_my_rows[row] = cards
		left.add_child(hb)

	_phase = Label.new()
	_phase.add_theme_font_size_override("font_size", 18)
	_phase.add_theme_color_override("font_color", Color.GOLD)
	left.add_child(_phase)

	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 8)
	left.add_child(hand_row)
	var hl := Label.new()
	hl.text = "Hand"
	hl.custom_minimum_size = Vector2(120, 0)
	hand_row.add_child(hl)
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", 6)
	_hand_box.custom_minimum_size = Vector2(0, 90)
	hand_row.add_child(_hand_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	left.add_child(actions)
	_confirm_btn = _action_button("Confirm (Enter)", _on_confirm, actions)
	_hint_btn = _action_button("Hint (H)", _on_hint, actions)
	_clear_btn = _action_button("Clear (Bksp)", _on_clear, actions)
	_new_hand_btn = _action_button("New Hand (N)", _on_new_hand, actions)

	# right panel
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 6)
	main.add_child(right)
	_opp_box = VBoxContainer.new()
	_opp_box.add_theme_constant_override("separation", 3)
	right.add_child(_opp_box)
	right.add_child(HSeparator.new())
	var bl := Label.new()
	bl.text = "Last hand"
	right.add_child(bl)
	_breakdown = RichTextLabel.new()
	_breakdown.bbcode_enabled = true
	_breakdown.fit_content = false
	_breakdown.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_breakdown)
	var ll := Label.new()
	ll.text = "Log"
	right.add_child(ll)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 110)
	_log.add_theme_font_size_override("normal_font_size", 13)
	right.add_child(_log)

	# connection / start overlay
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_overlay = PanelContainer.new()
	_overlay.custom_minimum_size = Vector2(520, 0)
	_overlay.add_theme_stylebox_override("panel", _box(Color(0.05, 0.08, 0.12, 0.96), Color.GOLD, 2))
	center.add_child(_overlay)
	var om := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		om.add_theme_constant_override("margin_" + side, 20)
	_overlay.add_child(om)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	om.add_child(ov)
	var ot := Label.new()
	ot.text = "Open Face Chinese Poker — Pineapple"
	ot.add_theme_font_size_override("font_size", 22)
	ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(ot)
	_overlay_msg = Label.new()
	_overlay_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_overlay_msg)
	_mode_opt = OptionButton.new()
	for i in MODES.size():
		_mode_opt.add_item(MODE_LABELS[i], i)
	_mode_opt.selected = 0
	ov.add_child(_mode_opt)
	_play_btn = Button.new()
	_play_btn.text = "Play vs AI"
	_play_btn.pressed.connect(_on_play_pressed)
	ov.add_child(_play_btn)
	_reconnect_btn = Button.new()
	_reconnect_btn.text = "Reconnect"
	_reconnect_btn.pressed.connect(_connect)
	ov.add_child(_reconnect_btn)
	var ob := Button.new()
	ob.text = "Back to Arcade"
	ob.pressed.connect(_on_back)
	ov.add_child(ob)
	var note := Label.new()
	note.text = "Cards are dealt, scored and played by the AI on the server (ofcp.tangentcode.com)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(1, 1, 1, 0.6)
	ov.add_child(note)


func _action_button(text: String, cb: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
