extends Node3D
## Minimal GridMap stand-in: the slim web engine is built with module_gridmap_enabled=no
## (docs/SLIM_WEB_ENGINE.md). Same API subset game.gd uses, same cell placement as GridMap
## (cell_center_x/z on, y off), one MeshInstance3D per cell.

@export var mesh_library: MeshLibrary
@export var cell_size := Vector3.ONE
## GridMap `data.cells` encoding: [x | y << 16, z, item | rot << 16] per cell.
@export var cells := PackedInt32Array()

## GridMap's 24 orthogonal bases, row-major (modules/gridmap/grid_map.cpp _ortho_bases).
const ORTHO := [
	[1, 0, 0, 0, 1, 0, 0, 0, 1], [0, -1, 0, 1, 0, 0, 0, 0, 1], [-1, 0, 0, 0, -1, 0, 0, 0, 1],
	[0, 1, 0, -1, 0, 0, 0, 0, 1], [1, 0, 0, 0, 0, -1, 0, 1, 0], [0, 0, 1, 1, 0, 0, 0, 1, 0],
	[-1, 0, 0, 0, 0, 1, 0, 1, 0], [0, 0, -1, -1, 0, 0, 0, 1, 0], [1, 0, 0, 0, -1, 0, 0, 0, -1],
	[0, 1, 0, 1, 0, 0, 0, 0, -1], [-1, 0, 0, 0, 1, 0, 0, 0, -1], [0, -1, 0, -1, 0, 0, 0, 0, -1],
	[1, 0, 0, 0, 0, 1, 0, -1, 0], [0, 0, -1, 1, 0, 0, 0, -1, 0], [-1, 0, 0, 0, 0, -1, 0, -1, 0],
	[0, 0, 1, -1, 0, 0, 0, -1, 0], [0, 0, 1, 0, 1, 0, -1, 0, 0], [0, -1, 0, 0, 0, 1, -1, 0, 0],
	[0, 0, -1, 0, -1, 0, -1, 0, 0], [0, 1, 0, 0, 0, -1, -1, 0, 0], [0, 0, 1, 0, -1, 0, 1, 0, 0],
	[0, 1, 0, 0, 0, 1, 1, 0, 0], [0, 0, -1, 0, 1, 0, 1, 0, 0], [0, -1, 0, 0, 0, -1, 1, 0, 0],
]

var _cells := {}  # Vector3i -> [item, orientation, MeshInstance3D]


func _ready() -> void:
	for i in range(0, cells.size(), 3):
		var a := cells[i]
		var pos := Vector3i(_s16(a), _s16(a >> 16), _s16(cells[i + 1]))
		set_cell_item(pos, cells[i + 2] & 0xFFFF, (cells[i + 2] >> 16) & 0x1F)


static func _s16(v: int) -> int:
	v &= 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v


func get_used_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(_cells.keys())
	return out


func get_cell_item(pos: Vector3i) -> int:
	return _cells[pos][0] if _cells.has(pos) else -1


func get_cell_item_orientation(pos: Vector3i) -> int:
	return _cells[pos][1] if _cells.has(pos) else -1


func set_cell_item(pos: Vector3i, item: int, orientation: int = 0) -> void:
	if _cells.has(pos):
		_cells[pos][2].free()
		if item < 0:
			_cells.erase(pos)
			return
	elif item < 0:
		return
	var r: Array = ORTHO[orientation]
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_library.get_item_mesh(item)
	mi.transform = Transform3D(Basis(Vector3(r[0], r[3], r[6]), Vector3(r[1], r[4], r[7]),
		Vector3(r[2], r[5], r[8])), (Vector3(pos) + Vector3(0.5, 0, 0.5)) * cell_size) \
		* mesh_library.get_item_mesh_transform(item)
	add_child(mi)
	_cells[pos] = [item, orientation, mi]


func clear() -> void:
	for c in _cells.values():
		c[2].free()
	_cells.clear()
