extends Node2D
## Silly Game Direct: rebuild the Godot 3 TileMap (beach autotile + water) as a
## TileMapLayer, using the decoded MainScene tile_data.

const TileData3 := preload("res://games/silly_game/direct/tile_data.gd")
const TILES_TEX := preload("res://games/silly_game/direct/assets/tiles.svg")

## Beach region in tiles.svg starts at (256,256); 64×64 cells → atlas origin (4,4).
const BEACH_ORIGIN := Vector2i(4, 4)
## Water single tile at Rect2(512, 320, 64, 64) → atlas (8, 5).
const WATER_ATLAS := Vector2i(8, 5)
const SOURCE_ID := 0
const CELL := 64

@onready var layer: TileMapLayer = $TileMap

var placed := 0


func _ready() -> void:
	layer.tile_set = _make_tileset()
	# Original TileMap position (MainScene.tscn).
	layer.position = Vector2(553, 544)
	var src := layer.tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	for row in TileData3.rows():
		var cell := Vector2i(row[0], row[1])
		var tid: int = row[2]
		var atlas: Vector2i
		if tid == 1:
			atlas = WATER_ATLAS
		else:
			atlas = BEACH_ORIGIN + Vector2i(row[3], row[4])
		if not src.has_tile(atlas):
			continue
		layer.set_cell(cell, SOURCE_ID, atlas)
		placed += 1


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	var src := TileSetAtlasSource.new()
	src.texture = TILES_TEX
	src.texture_region_size = Vector2i(CELL, CELL)
	# Beach autotile grid 6×3 at (4,4)..(9,6), plus water (8,5) already in that range.
	for y in range(4, 7):
		for x in range(4, 10):
			var c := Vector2i(x, y)
			if not src.has_tile(c):
				src.create_tile(c)
	ts.add_source(src, SOURCE_ID)
	return ts
