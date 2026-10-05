extends SceneTree
## Loads the arcade and instantiates every playable registered scene once.
## Run: godot --headless --path . --script res://tools/smoke_scenes.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	var registry = root.get_node_or_null("GameRegistry")
	if registry == null:
		print("SMOKE FAIL: GameRegistry autoload missing")
		quit(1)
		return
	var paths: Array[String] = [registry.ARCADE_SCENE]
	var playable := 0
	for e in registry.entries:
		if e.is_playable():
			playable += 1
			paths.append(e.scene_path)
	print("registry: %d entries, %d playable" % [registry.entries.size(), playable])
	for p in paths:
		var packed := load(p) as PackedScene
		if packed == null:
			print("SMOKE FAIL: cannot load ", p)
			failures += 1
			continue
		var inst := packed.instantiate()
		root.add_child(inst)
		await process_frame
		inst.queue_free()
		await process_frame
		print("ok: ", p)
	quit(1 if failures else 0)
