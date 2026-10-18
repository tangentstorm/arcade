extends Node3D
## dungeon-scroll-demo Direct: Godot 4 port of tangentstream/dungeon-scroll-demo.
## Template GridMap (left) -> rewrite rules -> Generated GridMap (right).
## R regenerates (the source's inspector "generate" button). Esc is left for PauseOverlay.

@onready var template: GridMap = $Template
@onready var generated: GridMap = $Generated

const DEFAULT_RULES = '''{
	"floor" : [
		[0.75, "floor"],
		[0.10, "floor-detail"],
		[0.10, "rocks"],
		[0.05, "wall"]
	]
}'''

## JSON object mapping tile names to lists of [probability, tile name] pairs.
@export_multiline var rewrite_rules: String = DEFAULT_RULES

var parsed_rules: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	regen_rules()  # Generated keeps the layout baked into the source scene until R.


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		generate()
		get_viewport().set_input_as_handled()


## The source's "generate" button: re-parse rules, then rewrite the template.
func generate(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	regen_rules()
	copy_template()


func regen_rules() -> void:
	var tmp: Dictionary = JSON.parse_string(rewrite_rules)
	var lib: MeshLibrary = template.mesh_library
	parsed_rules = {}
	for str_key in tmp.keys():
		var rule := []
		for pair in tmp[str_key]:
			rule.append([pair[0], lib.find_item_by_name(pair[1])])
		parsed_rules[lib.find_item_by_name(str_key)] = rule


func copy_template() -> void:
	generated.clear()
	for cell_p in template.get_used_cells():
		var cell_i := template.get_cell_item(cell_p)
		var cell_o := template.get_cell_item_orientation(cell_p)
		if parsed_rules.has(cell_i):
			var x := rng.randf()
			var p := 0.0
			for option in parsed_rules[cell_i]:
				p += option[0]
				if x < p:
					cell_i = option[1]
					break
		generated.set_cell_item(cell_p, cell_i, cell_o)
