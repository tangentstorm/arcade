extends SceneTree
## Headless checks for mineswpr_b4 (b4 cart host, issue #45 Phase 4).
## Run: godot --headless --path . --script res://tools/test_mineswpr_b4.gd

const SCENE := "res://games/mineswpr_b4/direct/game.tscn"

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: mineswpr_b4 ", msg)
	else:
		print("SMOKE FAIL: mineswpr_b4 ", msg)
		_fail += 1


func _initialize() -> void:
	_run.call_deferred()


func _type_line(line: String) -> void:
	for i in line.length():
		var ch := line[i]
		var ev := InputEventKey.new()
		ev.pressed = true
		match ch:
			"\n":
				ev.keycode = KEY_ENTER
			" ":
				ev.keycode = KEY_SPACE
				ev.unicode = 32
			_:
				ev.unicode = ch.unicode_at(0)
		root.push_input(ev)


func _run() -> void:
	var registry = root.get_node_or_null("GameRegistry")
	_check(registry != null, "GameRegistry autoload present")
	var entry = registry.get_entry("mineswpr_b4", "direct") if registry else null
	_check(entry != null and entry.is_playable(), "registry direct entry playable")
	_check(entry != null and entry.scene_path == SCENE, "scene_path matches")
	_check(entry != null and entry.scale_mode == "letterbox", "letterbox scale")
	var d = registry.get_entry("mineswpr", "direct") if registry else null
	var enh = registry.get_entry("mineswpr", "enhanced") if registry else null
	_check(d != null and d.is_playable() and enh != null and enh.is_playable(),
		"GDScript mineswpr Direct+Enhanced still playable")

	var packed := load(SCENE) as PackedScene
	_check(packed != null, "PackedScene loads")
	if packed == null:
		quit(1)
		return
	var inst = packed.instantiate()
	root.add_child(inst)
	await process_frame
	# Re-boot with a fixed seed after ready (cmdline may be empty under --script).
	inst.seed_value = 45
	inst._boot()
	await process_frame
	await process_frame
	_check(inst.cart != null and inst.cart.vm != null, "cart VM booted")
	_check(not inst.halted, "not halted after boot")
	var row0: String = inst.term_grid.row_text(0)
	_check(row0.contains("MINESWPR.RXE") or row0.strip_edges() != "",
		"TermGrid has content after boot (row0=%s)" % JSON.stringify(row0.left(48)))

	_type_line("0 0 ?\n")
	await process_frame
	_check(not inst.halted, "still running after typed prod")
	_check(inst.term_grid.row_text(0).length() > 0, "screen still populated")

	# Esc must not halt the cart (PauseOverlay owns Esc in the arcade).
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	root.push_input(esc)
	await process_frame
	_check(is_instance_valid(inst) and not inst.halted, "Esc does not halt the cart")

	# Hover (2,5): brackets inked Y (11), glyph untouched, survives a full
	# cart draw, and leaving restores the cart's colors.
	var tg = inst.term_grid
	var hx: int = inst.BOARD_COL + 4 * 2
	var hy: int = inst.BOARD_ROW + 5
	var before := [tg.fg_at(hx, hy), tg.fg_at(hx + 1, hy), tg.fg_at(hx + 2, hy)]
	tg.cell_hovered.emit(hx + 1, hy)
	_check([tg.fg_at(hx, hy), tg.fg_at(hx + 1, hy), tg.fg_at(hx + 2, hy)] == [11, before[1], 11],
		"hover inks brackets 11")
	inst._unlight()
	inst._after(inst.cart.call_word("draw"))
	_check(tg.fg_at(hx, hy) == 11 and tg.fg_at(hx + 2, hy) == 11, "hover survives full draw")
	tg.cell_hovered.emit(-1, -1)
	_check([tg.fg_at(hx, hy), tg.fg_at(hx + 1, hy), tg.fg_at(hx + 2, hy)] == before,
		"hover leave restores colors")

	inst.queue_free()
	await process_frame
	if _fail:
		print("mineswpr_b4: FAIL (%d)" % _fail)
		quit(1)
	else:
		print("mineswpr_b4: PASS")
		quit(0)
