extends Node2D
## godotlab/tilemap Direct edition: the original Kenney tilemap test level.
## The Godot 3 TileMap's tile_data is replayed verbatim (tile_data.gd) into a
## Godot 4 TileMapLayer whose atlas matches the original "tiles_spritesheet.png 2"
## autotile (72x72 grid over the whole sheet, no spacing).

const TileData3 := preload("res://games/godotlab_tilemap/direct/tile_data.gd")
const SOURCE_ID := 0

@onready var layer: TileMapLayer = $TileMap

var placed := 0
var skipped_blank := 0   ## cells whose atlas region lies outside the sheet (drew nothing in Godot 3)


func _ready() -> void:
	var src := layer.tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	for row in TileData3.decode():
		var cell: Vector2i = row[0]
		var atlas: Vector2i = row[1]
		if not src.has_tile(atlas):
			skipped_blank += 1
			continue
		layer.set_cell(cell, SOURCE_ID, atlas)
		placed += 1
