extends SceneTree
## Fails when games/ uses a class the slim web engine compiles out
## (tools/build_slim_web_template.sh: no CSG, GridMap or 3D physics). Desktop has them, so
## without this check a scene passes CI and then fails to load only on Pages (#117, #112).

const BANNED := "\\b(CSG\\w*3D|GridMap|RigidBody3D|StaticBody3D|CharacterBody3D|AnimatableBody3D|Area3D|CollisionShape3D|CollisionPolygon3D|\\w+Shape3D|RayCast3D|ShapeCast3D|NavigationRegion3D|NavigationAgent3D|VehicleBody3D|SoftBody3D|\\w+Joint3D)\\b"

var _re := RegEx.new()
var _hits := 0


func _initialize() -> void:
	_re.compile(BANNED)
	for d in ["res://games"]:
		_scan(d)
	if _hits == 0:
		print("ok: no slim-web-excluded classes in games/")
	print("VERIFY DONE: ", _hits)
	quit(_hits)


func _scan(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "tscn", "tres"]:
			var lines := FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			for i in lines.size():
				var line := lines[i]
				if line.begins_with("#") or line.strip_edges().begins_with("##"):
					continue
				var m := _re.search(line)
				if m:
					print("SMOKE FAIL: web_classes %s/%s:%d uses %s (not in the slim web engine)" % [dir, f, i + 1, m.get_string()])
					_hits += 1
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub)
