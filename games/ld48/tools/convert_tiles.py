#!/usr/bin/env python3
"""Convert ld48's Godot 3 TileMap data to Godot 4 TileMapLayer data.

Godot 4's built-in 3->4 converter does not migrate 3.x atlas TileSets or
`format = 1` tile_data (it yields a 16x16 tileset with zero cells), so this
script does it by hand:

  Godot 3 tile_data triplets (cell, tile_id|flags, autotile_coord)
    cell  = (int16 y << 16) | (int16 x & 0xffff)
    coord = (uint16 y << 16) | uint16 x
  ->  Godot 4 tile_map_data (format 0): uint16 version, then per cell
    int16 x, int16 y, uint16 source_id, uint16 atlas_x, uint16 atlas_y, uint16 alt

Each Godot 3 tile id becomes the TileSetAtlasSource with the same id (see
direct/floor_tiles.tres and direct/mine_tiles.tres). None of ld48's cells use
flip/transpose flags, so the alternative id is always 0.

Usage: python3 convert_tiles.py <godot3 scene.tscn>
Prints one `name: PackedByteArray(...)` line per TileMap node.
"""
import re
import struct
import sys


def convert(ints):
    out = bytearray(struct.pack('<H', 0))
    for cell, tid, coord in zip(ints[0::3], ints[1::3], ints[2::3]):
        cell &= 0xffffffff
        x = struct.unpack('<h', struct.pack('<H', cell & 0xffff))[0]
        y = struct.unpack('<h', struct.pack('<H', cell >> 16))[0]
        if tid >> 29:
            raise SystemExit('flip/transpose flags not supported')
        out += struct.pack('<hhHHHH', x, y, tid, coord & 0xffff, (coord >> 16) & 0xffff, 0)
    return out


def main(path):
    text = open(path).read()
    for m in re.finditer(r'\[node name="([^"]+)" type="TileMap"[^\]]*\](.*?)(?=\n\[|\Z)', text, re.S):
        d = re.search(r'tile_data = PoolIntArray\((.*?)\)', m.group(2), re.S)
        ints = [int(v) for v in d.group(1).split(',')] if d else []
        data = convert(ints)
        print('%s: PackedByteArray(%s)' % (m.group(1), ', '.join(str(b) for b in data)))


if __name__ == '__main__':
    main(sys.argv[1])
