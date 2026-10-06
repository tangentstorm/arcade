extends SceneTree
## verify-arcade: drive the real arcade the way a player does, with injected
## mouse/keyboard events (no direct setters). Steps:
##   gallery -> Enhanced -> Original -> click card -> Esc -> Resume -> Esc Esc
##   -> gallery -> click card -> Esc -> "Back to Arcade" -> gallery.
## Env: VERIFY_OUT (dir for PNGs + prefs backup), VERIFY_GAME (card title,
## default "Tetraminex"). Screenshots only when not --headless (use Xvfb).
## Prints "step ok: ..." per step, "VERIFY FAIL: ..." on any failure,
## "VERIFY DONE" at the end. Exit 0 only when every step passed.

const PREF := "user://arcade_prefs.cfg"

var _out := ""
var _fail := 0
var _pref_backup = null  ## String contents, or null if the file was absent
var _shots := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = OS.get_environment("VERIFY_OUT")
	_shots = DisplayServer.get_name() != "headless" and _out != ""
	var want := OS.get_environment("VERIFY_GAME")
	if want == "":
		want = "Tetraminex"
	_backup_pref()
	var reg = root.get_node("GameRegistry")
	var pause = root.get_node("PauseOverlay")

	change_scene_to_file(reg.ARCADE_SCENE)
	await _frames(20)
	var arc: Control = current_scene
	_check(arc != null and arc.scene_file_path == reg.ARCADE_SCENE, "gallery is current scene")
	var cards: Array = arc.get_node("%GameList").get_children()
	var expect: int = reg.title_ids().size() - 1  # minus _template
	_check(cards.size() == expect, "gallery shows %d cards (want %d)" % [cards.size(), expect])
	await _shot("01-gallery")

	await _click(arc.get_node("%ModeEnhanced"))
	_check(arc.get_node("%ModeHint").text.contains("Enhanced"), "Enhanced hint: " + arc.get_node("%ModeHint").text)
	_check(arc.get_node("%ModeEnhanced").button_pressed, "Enhanced pill pressed")
	print("info: enhanced playable cards: %d" % _playable(cards))
	await _shot("02-enhanced")

	await _click(arc.get_node("%ModeDirect"))
	_check(arc.get_node("%ModeHint").text.contains("Original"), "Original hint: " + arc.get_node("%ModeHint").text)
	print("info: original playable cards: %d" % _playable(cards))

	var card: Control = null
	for c in cards:
		if c.get_meta("title").text == want:
			card = c
	_check(card != null and card.get_meta("playable"), "card '%s' present and playable" % want)
	if card == null:
		return _finish()
	var entry = reg.get_entry(card.get_meta("game_id"), "direct")
	var title: String = card.get_meta("title").text
	var panel: Control = pause.get_node("Panel")

	# Round 1: click card -> Esc -> Resume -> Esc -> Esc (back via keyboard).
	await _open_card(title, entry.scene_path)
	await _shot("03-game")
	await _key(KEY_ESCAPE)
	_check(panel.visible and paused, "Esc shows pause overlay + pauses tree")
	await _shot("04-paused")
	await _click(pause.get_node("%ResumeButton"))
	_check(not panel.visible and not paused and _in(entry.scene_path), "Resume hides overlay, game continues")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _frames(20)
	_check(_in(reg.ARCADE_SCENE) and not paused and not panel.visible, "Esc, Esc returns to gallery")

	# Round 2: click card again -> Esc -> "Back to Arcade" button.
	await _open_card(title, entry.scene_path)
	await _key(KEY_ESCAPE)
	_check(panel.visible and paused, "Esc shows pause overlay again")
	await _click(pause.get_node("%ArcadeButton"))
	await _frames(20)
	_check(_in(reg.ARCADE_SCENE) and not paused and not panel.visible,
		"Back to Arcade returns to gallery, unpaused")
	await _shot("05-back")
	_finish()


func _in(path: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == path


## Find the card by title in the (possibly rebuilt) gallery, scroll to it, click it.
func _open_card(title: String, scene_path: String) -> void:
	var arc: Control = current_scene
	var card: Control = null
	for c in arc.get_node("%GameList").get_children():
		if c.get_meta("title").text == title:
			card = c
	arc.get_node("%Scroll").ensure_control_visible(card)
	await _frames(5)
	await _click(card)
	await _frames(30)
	_check(_in(scene_path), "clicked '%s' -> %s" % [title, scene_path])


func _finish() -> void:
	_restore_pref()
	print("VERIFY DONE: %d failure(s)" % _fail)
	quit(1 if _fail else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("step ok: ", what)
	else:
		print("VERIFY FAIL: ", what)
		_fail += 1


func _playable(cards: Array) -> int:
	var n := 0
	for c in cards:
		if c.get_meta("playable"):
			n += 1
	return n


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Real left click at the control's on-screen centre.
func _click(c: Control) -> void:
	var p: Vector2 = root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))
	var mv := InputEventMouseMotion.new()
	mv.position = p
	root.push_input(mv)
	await _frames(2)
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.position = p
		b.pressed = down
		root.push_input(b)
		await _frames(2)
	await _frames(4)


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		root.push_input(e)
		await _frames(2)
	await _frames(4)


func _shot(name: String) -> void:
	if not _shots:
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("shot: ", path)


func _backup_pref() -> void:
	if FileAccess.file_exists(PREF):
		_pref_backup = FileAccess.get_file_as_string(PREF)


func _restore_pref() -> void:
	if _pref_backup == null:
		if FileAccess.file_exists(PREF):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PREF))
	else:
		var f := FileAccess.open(PREF, FileAccess.WRITE)
		f.store_string(_pref_backup)
		f.close()
