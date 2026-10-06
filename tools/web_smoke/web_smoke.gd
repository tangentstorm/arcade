extends Node
## Browser smoke for the Web export. tools/web_smoke/web_smoke.sh copies the project to a
## temp dir and injects this as an autoload; it is never part of the shipped game.
## With ?smoke=all it checks the classes the arcade needs, opens every playable scene,
## and tries the OFCP wss:// endpoint.

const CLASSES := ["RigidBody2D", "StaticBody2D", "AnimatableBody2D", "CharacterBody2D", "Area2D",
	"CollisionShape2D", "PhysicsServer2D", "WebSocketPeer", "AudioStreamPlayer", "AudioStreamMP3",
	"AudioStreamOggVorbis", "AudioStreamWAV", "TileMap", "TileMapLayer", "GPUParticles2D",
	"ParticleProcessMaterial", "CodeEdit", "RichTextLabel", "LineEdit", "ItemList", "OptionButton",
	"SubViewport", "WorldEnvironment", "Environment", "FontVariation", "FontFile", "JavaScriptBridge", "Tween", "ShaderMaterial", "Line2D"]

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	var q := str(JavaScriptBridge.eval("location.search"))
	if q.find("smoke=all") == -1:
		return
	_run.call_deferred()

func _run() -> void:
	var failures := 0
	for c in CLASSES:
		if not ClassDB.class_exists(c):
			print("WEBSMOKE FAIL: missing class ", c); failures += 1
	print("WEBSMOKE text_server=", TextServerManager.get_primary_interface().get_name())
	var registry = get_node("/root/GameRegistry")
	var paths: Array[String] = []
	for e in registry.entries:
		if e.is_playable():
			paths.append(e.scene_path)
	for p in paths:
		var packed := load(p) as PackedScene
		if packed == null:
			print("WEBSMOKE FAIL: cannot load ", p); failures += 1; continue
		var inst := packed.instantiate()
		get_tree().root.add_child(inst)
		for i in 45:
			await get_tree().process_frame
		print("WEBSMOKE show: ", p)
		await get_tree().create_timer(1.5).timeout
		inst.queue_free()
		await get_tree().process_frame
		print("WEBSMOKE ok: ", p)
	var ws := WebSocketPeer.new()
	var err := ws.connect_to_url("wss://ofcp.tangentcode.com/ws")
	var st := -1
	for i in 600:
		ws.poll()
		st = ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN or st == WebSocketPeer.STATE_CLOSED:
			break
		await get_tree().process_frame
	print("WEBSMOKE wss err=%d state=%d (1=OPEN 3=CLOSED)" % [err, st])
	ws.close()
	print("WEBSMOKE DONE failures=%d scenes=%d" % [failures, paths.size()])
