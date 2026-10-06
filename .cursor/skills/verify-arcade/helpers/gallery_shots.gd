extends SceneTree
## verify-arcade: screenshot the real gallery window (Xvfb or a real display;
## not --headless). The OS window size comes from `--resolution WxH` on the
## command line (layout.sh starts one process per size: resizing from a script
## does not take effect without a window manager).
## Env: VERIFY_OUT (required), VERIFY_TAG (file tag, default WxH of the window).
## Prints one "shot:" metrics line and "VERIFY FAIL" if grid/scroll leave the view.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("VERIFY_OUT")
	if out == "" or DisplayServer.get_name() == "headless":
		print("VERIFY FAIL: need VERIFY_OUT and a display (run under xvfb-run, not --headless)")
		quit(1)
		return
	var reg = root.get_node("GameRegistry")
	change_scene_to_file(reg.ARCADE_SCENE)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var win := DisplayServer.window_get_size()
	var tag := OS.get_environment("VERIFY_TAG")
	if tag == "":
		tag = "%dx%d" % [win.x, win.y]
	var arc: Control = current_scene
	var vis := root.get_visible_rect().size
	var gl: GridContainer = arc.get_node("%GameList")
	var g := gl.get_global_rect()
	var r := (arc.get_node("%Scroll") as Control).get_global_rect()
	var ok := r.position.x >= 0.0 and r.end.x <= vis.x + 0.5 and g.end.x <= r.end.x + 0.5
	var path := out.path_join("gallery-%s.png" % tag)
	root.get_texture().get_image().save_png(path)
	print("shot: %s window=%s logical=%s cols=%d grid_w=%.0f scroll_w=%.0f %s" % [
		path, win, vis, gl.columns, g.size.x, r.size.x, "fits" if ok else "OVERFLOW"])
	if not ok:
		print("VERIFY FAIL: gallery overflows at ", tag)
	quit(0 if ok else 1)
