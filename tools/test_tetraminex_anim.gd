extends SceneTree
## Tetraminex timed animations (Direct + Enhanced): teletype talk, fade curtain,
## teleporter glow, exit fade -> next room. Advances real frames, asserts progress.

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("SMOKE FAIL: tetraminex_anim ", msg)
		_fail += 1


func _initialize() -> void:
	call_deferred("_run")


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < end:
		await process_frame


func _run() -> void:
	for ed in ["direct", "enhanced"]:
		var g = (load("res://games/tetraminex/%s/game.tscn" % ed) as PackedScene).instantiate()
		root.add_child(g)
		await process_frame
		var fx = g._fx
		var lbl: Label = g._talk_label
		# Teletype
		_check(g._talk_overlay.visible and lbl.visible_characters == 0, "%s talk starts typing at 0 chars" % ed)
		await _wait(0.5)
		var n: int = lbl.visible_characters
		_check(n > 3 and n < lbl.text.length(), "%s teletype mid-way after 0.5 s (%d/%d)" % [ed, n, lbl.text.length()])
		_check(g._talk_hint.modulate.a == 0.0, "%s hint hidden while typing" % ed)
		# Fade-in curtain (fast: ~0.8 s from black)
		_check(fx.curtain.color.a < 1.0 and fx.curtain.color.a > 0.0, "%s curtain mid fade-in (a=%.2f)" % [ed, fx.curtain.color.a])
		await _wait(0.6)
		_check(fx.curtain.color.a == 0.0, "%s curtain fully faded in" % ed)
		g._advance_talk()  # skip ahead
		_check(lbl.visible_characters == -1 and g._talk_overlay.visible, "%s Enter while typing skips ahead" % ed)
		_check(g._talk_hint.modulate.a == 1.0, "%s hint shown when done" % ed)
		g._advance_talk()  # dismiss
		_check(not g._talk_overlay.visible, "%s second Enter dismisses" % ed)
		# Teleporter glow (room 8)
		g.load_level(8)
		await process_frame
		_check(is_instance_valid(fx.glow), "%s room 8 teleporter sprite present" % ed)
		var seen := {}
		for i in 12:
			await _wait(0.06)
			seen[(fx.glow.texture as AtlasTexture).region.position.x] = true
		_check(seen.size() >= 3, "%s teleporter glow cycles frames (%s)" % [ed, seen.keys()])
		# Exit: fade out, then next room
		g.load_level(0)
		g._talk_queue.clear()
		g._hide_talk()
		await _wait(0.9)  # let the room fade in first
		g._on_hero_exited()
		_check(g.level_num == 0 and fx.fading_out(), "%s exit starts fade-out (room stays 0)" % ed)
		await _wait(0.45)
		_check(g.level_num == 0 and fx.curtain.color.a > 0.3, "%s curtain darkening (a=%.2f)" % [ed, fx.curtain.color.a])
		await _wait(0.6)
		_check(g.level_num == 1, "%s after fade-out loads room 1" % ed)
		g.queue_free()
		await process_frame
	quit(1 if _fail else 0)
