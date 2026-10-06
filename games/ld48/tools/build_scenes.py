#!/usr/bin/env python3
"""Regenerate direct/game.tscn and direct/ivan_office.tscn from the Godot 3
originals in source/game/scenes/ (only the TileMap cell data is generated;
the node layout below is a hand port of the original scenes).

Run from games/ld48/:  python3 tools/build_scenes.py
"""
import importlib.util
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('ct', os.path.join(HERE, 'convert_tiles.py'))
ct = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ct)


def tiles(scene):
    text = open(os.path.join(HERE, '..', 'source', 'game', 'scenes', scene)).read()
    out = {}
    for m in re.finditer(r'\[node name="([^"]+)" type="TileMap"[^\]]*\](.*?)(?=\n\[|\Z)', text, re.S):
        d = re.search(r'tile_data = PoolIntArray\((.*?)\)', m.group(2), re.S)
        ints = [int(v) for v in d.group(1).split(',')] if d else []
        out[m.group(1)] = 'PackedByteArray(%s)' % ', '.join(str(b) for b in ct.convert(ints))
    return out


P = 'res://games/ld48/direct/'
BG = '''
[node name="Background" type="CanvasLayer" parent="."]
layer = -100

[node name="ClearColor" type="ColorRect" parent="Background"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.0313726, 0.0313726, 0.0313726, 1)
'''

t0 = tiles('previously.tscn')
game = '''[gd_scene load_steps=20 format=3]

[ext_resource type="TileSet" path="{P}floor_tiles.tres" id="1_tiles"]
[ext_resource type="PackedScene" path="{P}ernie.tscn" id="2_ernie"]
[ext_resource type="PackedScene" path="{P}teleporter.tscn" id="3_teleporter"]
[ext_resource type="Texture2D" path="{P}sprites/exit.png" id="5_exit"]
[ext_resource type="Texture2D" path="{P}sprites/ivan.png" id="6_ivan"]
[ext_resource type="Texture2D" path="{P}sprites/teddy.png" id="7_teddy"]
[ext_resource type="Script" path="{P}chatroom.gd" id="8_chatroom"]
[ext_resource type="Script" path="{P}room0.gd" id="9_room0"]
[ext_resource type="Script" path="{P}sidebar.gd" id="10_sidebar"]
[ext_resource type="Script" path="{P}camshaker.gd" id="11_camshaker"]
[ext_resource type="Script" path="{P}helptext.gd" id="12_helptext"]
[ext_resource type="Theme" path="{P}ui_theme.tres" id="13_theme"]
[ext_resource type="FontFile" path="{P}fonts/RobotoCondensed-Bold.ttf" id="14_bold"]

[sub_resource type="RectangleShape2D" id="Rect_ivan"]
size = Vector2(40, 120)

[sub_resource type="RectangleShape2D" id="Rect_teddy_body"]
size = Vector2(50, 50)

[sub_resource type="RectangleShape2D" id="Rect_teddy_head"]
size = Vector2(120, 50)

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_logo"]
bg_color = Color(0.0666667, 0.0627451, 0.0745098, 1)
expand_margin_left = 5.0
expand_margin_top = 5.0
expand_margin_right = 5.0
expand_margin_bottom = 5.0

[node name="scene" type="Node2D"]
position = Vector2(-9.88818, -48.0291)
{BG}
[node name="Timer" type="Timer" parent="."]
wait_time = 0.25
autostart = true

[node name="room" type="Node2D" parent="."]
script = ExtResource("9_room0")

[node name="background" type="TileMapLayer" parent="room"]
position = Vector2(0.378296, 1.6369)
tile_map_data = {bg}
tile_set = ExtResource("1_tiles")

[node name="sprites" type="Node2D" parent="room"]

[node name="ernie" parent="room/sprites" instance=ExtResource("2_ernie")]
position = Vector2(881.004, 1424.39)

[node name="teleporter" parent="room/sprites" instance=ExtResource("3_teleporter")]
position = Vector2(1147.75, 974.078)

[node name="ivan" type="RigidBody2D" parent="room/sprites"]
visible = false
position = Vector2(718.686, 686.172)
gravity_scale = 2.5

[node name="sprite" type="Sprite2D" parent="room/sprites/ivan"]
texture = ExtResource("6_ivan")

[node name="shape" type="CollisionShape2D" parent="room/sprites/ivan"]
visible = false
position = Vector2(-3, 2)
shape = SubResource("Rect_ivan")

[node name="teddy" type="RigidBody2D" parent="room/sprites"]
position = Vector2(1848.76, 1465.15)
rotation = 1.24966
gravity_scale = 2.5
continuous_cd = 2

[node name="sprite" type="Sprite2D" parent="room/sprites/teddy"]
texture = ExtResource("7_teddy")

[node name="shape-body" type="CollisionShape2D" parent="room/sprites/teddy"]
visible = false
position = Vector2(0, 26)
shape = SubResource("Rect_teddy_body")

[node name="shape-head" type="CollisionShape2D" parent="room/sprites/teddy"]
visible = false
position = Vector2(1.88562, -27.7401)
shape = SubResource("Rect_teddy_head")

[node name="exit" type="Sprite2D" parent="room/sprites"]
visible = false
position = Vector2(198.296, 1347.86)
texture = ExtResource("5_exit")

[node name="camshaker" type="Node2D" parent="."]
script = ExtResource("11_camshaker")

[node name="camera" type="Camera2D" parent="camshaker"]
position = Vector2(369.717, 1046.55)
scale = Vector2(2, 2)
zoom = Vector2(0.333333, 0.333333)

[node name="helptext" type="Label" parent="camshaker/camera"]
offset_left = -297.0
offset_top = -484.0
offset_right = 949.0
offset_bottom = -424.0
pivot_offset = Vector2(28.8586, 7)
theme = ExtResource("13_theme")
theme_override_colors/font_color = Color(0.92549, 0.768627, 0.14902, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_fonts/font = ExtResource("14_bold")
theme_override_font_sizes/font_size = 50
text = "Previously..."
horizontal_alignment = 1
script = ExtResource("12_helptext")

[node name="sidebar" type="PanelContainer" parent="camshaker/camera"]
offset_left = -955.0
offset_top = -535.0
offset_right = -315.0
offset_bottom = 545.0
script = ExtResource("10_sidebar")

[node name="vbox" type="VBoxContainer" parent="camshaker/camera/sidebar"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="logo" type="Label" parent="camshaker/camera/sidebar/vbox"]
layout_mode = 2
pivot_offset = Vector2(28.8586, 7)
theme = ExtResource("13_theme")
theme_override_fonts/font = ExtResource("14_bold")
theme_override_font_sizes/font_size = 50
theme_override_styles/normal = SubResource("StyleBoxFlat_logo")
text = "Tetraminex"

[node name="card" type="HBoxContainer" parent="camshaker/camera/sidebar/vbox"]
visible = false
layout_mode = 2
theme_override_constants/separation = 8

[node name="box" type="VBoxContainer" parent="camshaker/camera/sidebar/vbox/card"]
layout_mode = 2

[node name="space" type="Panel" parent="camshaker/camera/sidebar/vbox/card/box"]
layout_mode = 2

[node name="icon" type="TextureRect" parent="camshaker/camera/sidebar/vbox/card/box"]
custom_minimum_size = Vector2(32, 32)
layout_mode = 2
size_flags_stretch_ratio = 0.0
texture = ExtResource("7_teddy")
expand_mode = 1

[node name="text" type="RichTextLabel" parent="camshaker/camera/sidebar/vbox/card"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme = ExtResource("13_theme")
theme_override_fonts/bold_font = ExtResource("14_bold")
theme_override_font_sizes/bold_font_size = 24
bbcode_enabled = true
text = "[b]Teddy Tetraminus[/b]
[color=#ccc]hello? here is some long text that needs to wrap.[/color]"
fit_content = true
scroll_active = false

[node name="chatroom" type="ScrollContainer" parent="camshaker/camera/sidebar/vbox"]
layout_mode = 2
size_flags_vertical = 3
horizontal_scroll_mode = 0
script = ExtResource("8_chatroom")

[node name="vbox" type="VBoxContainer" parent="camshaker/camera/sidebar/vbox/chatroom"]
custom_minimum_size = Vector2(480, 200)
layout_mode = 2
size_flags_horizontal = 3

[node name="Label" type="Label" parent="camshaker/camera"]
offset_right = 40.0
offset_bottom = 14.0

[connection signal="timeout" from="Timer" to="room" method="_on_step"]
[connection signal="helptext" from="room" to="camshaker/camera/helptext" method="_on_room_helptext"]
[connection signal="showchat" from="room" to="camshaker/camera/sidebar" method="_on_room_showchat"]
[connection signal="speak" from="room" to="camshaker/camera/sidebar/vbox/chatroom" method="_on_room0_speak"]
[connection signal="leave_object" from="room/sprites/ernie" to="room" method="_on_ernie_leave_object"]
[connection signal="reach_object" from="room/sprites/ernie" to="room" method="_on_ernie_reach_object"]
[connection signal="teleport" from="room/sprites/teleporter" to="room" method="_on_teleporter_teleport"]
'''.format(P=P, BG=BG, bg=t0['background'])

t1 = tiles("ivan's-office.tscn")
office = '''[gd_scene load_steps=6 format=3]

[ext_resource type="Texture2D" path="{P}sprites/ivan.png" id="1_ivan"]
[ext_resource type="TileSet" path="{P}mine_tiles.tres" id="2_mines"]
[ext_resource type="TileSet" path="{P}floor_tiles.tres" id="3_tiles"]
[ext_resource type="PackedScene" path="{P}ernie.tscn" id="4_ernie"]
[ext_resource type="Script" path="{P}room_ivan.gd" id="5_script"]

[node name="room-ivan" type="Node2D"]
script = ExtResource("5_script")
{BG}
[node name="camera" type="Camera2D" parent="."]
position = Vector2(960, 540)
zoom = Vector2(0.666667, 0.666667)

[node name="ivan" type="Sprite2D" parent="."]
position = Vector2(330.549, 575.711)
texture = ExtResource("1_ivan")

[node name="walls" type="TileMapLayer" parent="."]
tile_map_data = {walls}
tile_set = ExtResource("3_tiles")

[node name="mines" type="TileMapLayer" parent="."]
tile_map_data = {mines}
tile_set = ExtResource("2_mines")

[node name="ernie" parent="." instance=ExtResource("4_ernie")]
position = Vector2(1089.33, 434.499)
'''.format(P=P, BG=BG, walls=t1['walls'], mines=t1['mines'])

d = os.path.join(HERE, '..', 'direct')
open(os.path.join(d, 'game.tscn'), 'w').write(game)
open(os.path.join(d, 'ivan_office.tscn'), 'w').write(office)
print('wrote game.tscn, ivan_office.tscn')
