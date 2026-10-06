#!/usr/bin/env python3
"""Extract Level_RoomN.as + CSVs into direct/level_data.gd."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "source" / "levels"
OUT = ROOT / "direct" / "level_data.gd"

sprite_re = re.compile(
    r"addSpriteToLayer\(null,\s*(\w+),\s*SpritesGroup\s*,\s*([\d.]+),\s*([\d.]+)"
    r".*?generateProperties\(\s*(.*?)\s*\),\s*onAddCallback\s*\)",
    re.S,
)
prop_color = re.compile(r'name:"color",\s*value:"(\w+)"')
prop_vert = re.compile(r'name:"isVertical",\s*value:(true|false)')
grav_re = re.compile(r"gravity:Boolean\s*=\s*(true|false)")


def load_csv(path: Path):
    rows = []
    for line in path.read_text().strip().splitlines():
        line = line.strip().rstrip(",")
        if not line:
            continue
        rows.append([int(c) for c in line.split(",") if c != ""])
    return rows


rooms = []
for n in range(10):
    text = (SRC / f"Level_Room{n}.as").read_text()
    gravity = grav_re.search(text).group(1) == "true"
    sprites = []
    for m in sprite_re.finditer(text):
        kind, x, y, props = m.group(1), float(m.group(2)), float(m.group(3)), m.group(4)
        entry = {"kind": kind, "x": x, "y": y}
        cm = prop_color.search(props or "")
        if cm:
            entry["color"] = cm.group(1)
        vm = prop_vert.search(props or "")
        if vm:
            entry["isVertical"] = vm.group(1) == "true"
        sprites.append(entry)
    rooms.append({
        "id": n,
        "gravity": gravity,
        "sprites": sprites,
        "tiles": load_csv(SRC / f"mapCSV_Room{n}_Tiles.csv"),
        "walls": load_csv(SRC / f"mapCSV_Room{n}_Walls.csv"),
    })

lines = [
    "extends RefCounted",
    "## Auto-generated from tetraminex Level_RoomN.as + mapCSV_RoomN_*.csv",
    "## Do not edit by hand — re-run games/tetraminex/tools/extract_levels.py",
    "",
    "const CELL := 30",
    "const ROOM_W := 16",
    "const ROOM_H := 16",
    "const COLLIDE_INDEX := 4  ## walls tile >= this is solid",
    "",
    "const COLOR_NAMES := {",
    '\t"red": 0, "purple": 1, "blue": 2, "green": 3,',
    '\t"yellow": 4, "cyan": 5, "orange": 6, "gray": 7,',
    "}",
    "",
    "const ROOMS: Array = [",
]
for r in rooms:
    lines.append("\t{")
    lines.append(f'\t\t"id": {r["id"]},')
    lines.append(f'\t\t"gravity": {str(r["gravity"]).lower()},')
    lines.append('\t\t"sprites": [')
    for s in r["sprites"]:
        parts = [f'"kind": "{s["kind"]}"', f'"x": {s["x"]}', f'"y": {s["y"]}']
        if "color" in s:
            parts.append(f'"color": "{s["color"]}"')
        if "isVertical" in s:
            parts.append(f'"isVertical": {str(s["isVertical"]).lower()}')
        lines.append("\t\t\t{ " + ", ".join(parts) + " },")
    lines.append("\t\t],")
    lines.append('\t\t"tiles": [')
    for row in r["tiles"]:
        lines.append("\t\t\t[" + ", ".join(str(c) for c in row) + "],")
    lines.append("\t\t],")
    lines.append('\t\t"walls": [')
    for row in r["walls"]:
        lines.append("\t\t\t[" + ", ".join(str(c) for c in row) + "],")
    lines.append("\t\t],")
    lines.append("\t},")
lines.append("]")
lines.append("")
OUT.write_text("\n".join(lines) + "\n")
print("wrote", OUT, OUT.stat().st_size, "bytes")
