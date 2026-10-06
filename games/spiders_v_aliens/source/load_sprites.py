import xml.etree.ElementTree as ET
tree = ET.parse('as3/escape.dam')
root = tree.getroot()


sprites = [s.attrib["name"] for s in root.findall("spriteEntries/sprite")]

remap = {
    "Portal - noPower": "portal_off",
    "Alien-Dead": "alien_dead" }


scene = None
for group in root.findall("layers/group"):
    for layer in group.findall("spritelayer"):
        # print("  ",layer.attrib["name"])
        name = group.attrib["name"]+"-"+layer.attrib["name"]
        scene = open("godot/maps/"+name+".csv", "w")
        for sprite in layer.findall("sprite"):
            a = sprite.attrib
            s = sprites[int(a["idx"])-1]
            s = remap.get(s,s)
            s = s.lower()
            scene.write(",".join([a["x"], a["y"], s]))
            scene.write("\n")
