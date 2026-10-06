extends Node2D
## Shep: Game1.hx, the in-level game. It's a zero-gravity billiards room.
##
## physaxe is replaced by Godot 2D physics. Game1 stepped physaxe once per
## frame at 24 fps with dt = 1, so its speeds are pixels per frame. Here every
## speed is multiplied by FPS (24) and every per-frame factor is raised to
## 24 * delta. See PORT.md for the full mapping.
##
## Layers, back to front, as in Game1.new: bg (blurred, shifted on wall hits),
## mg (pockets, doors, spinners, crates, fuses, then Shep), fg, the border
## overlay, the physics debug layer, and the clock.

signal won(secs_left: int)
signal lost
signal sfx(name: String)
signal music(cmd: String)   ## "start", "pause", "resume"

const Levels := preload("res://games/shep/direct/shep_levels.gd")
const Preview := preload("res://games/shep/direct/level_preview.gd")
const BLUR := preload("res://games/shep/direct/blur.gdshader")
const ART := "res://games/shep/direct/assets/"

const FPS := 24.0
const GAME_FRICTION := 0.985     ## Game1.updateWorld, bot and fuses only
const PHX_FRICTION := 0.999      ## physaxe DEFAULT_PROPERTIES, every body
const KICK_MOUSE := 50.0         ## onClick: kick(cuebot, calcVector(50))
const KICK_KEY := 5.0            ## Keyboard.UP: shepClipVector().mult(5)
const TURN_KEY := 15.0           ## LEFT / RIGHT: rotation -/+ 15
const AIM_R := 150.0             ## drawVector: calcVector(150)

## phx.Material(restitution, friction, density)
const DENSITY_SHEP := 20.0
const DENSITY_FUSE := 15.0
const DENSITY_FLOATY := 100.0
const MASS_SCALE := 0.001
## physaxe takes max(restitution) per contact; Godot adds the two bounces.
## These values give wall-vs-body 0.9 and body-vs-body 0.5, as in the original.
const BOUNCE_WALL := 0.65
const BOUNCE_BODY := 0.25
## physaxe takes sqrt(f1 * f2); Godot takes min. Keep the source coefficients.
const FRICTION_WALL := 2.0
const FRICTION_FLOATY := 2.0
const FRICTION_FUSE := 10.0
const FRICTION_SHEP := 20.0
const TOUCH_SLOP := 1.5          ## px of slack for the pocket "arbiter" test

var current_level := 0
var done := true
var paused := false
var keyboard_control := false
var show_physics := false
var time_left := float(Levels.TIME_LIMIT)
var last_text := ""

var level: Dictionary = {}
var mouse_pos := Vector2(400, 287)  ## stage coordinates, fed by game.gd
var svg_override := ""          ## tests: load this SVG text instead of the pack
var shep: RigidBody2D
var shep_clip: Node2D
var glow_clip: Sprite2D
var pockets: Array[Dictionary] = []      ## {body, code, pos, clip, glow}
var fuses: Array[Dictionary] = []        ## {body, code}
var doors: Array[Dictionary] = []        ## {body, clip}
var spinners: Array[AnimatableBody2D] = []
var floaters: Array[RigidBody2D] = []

var bg: Node2D
var mg: Node2D
var fg: Node2D
var debug_layer: Node2D
var clock_label: Label
var _bg_mat: ShaderMaterial
var _fg_mat: ShaderMaterial
var _blur := Vector2.ZERO
var _shake: Tween
var _glow_tween: Tween
var _mats := {}
var _last_v := Vector2.ZERO
var _tex := {}
var _clock_font: Font


func _ready() -> void:
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BLUR
	_fg_mat = ShaderMaterial.new()
	_fg_mat.shader = BLUR
	bg = _layer("Bg")
	bg.material = _bg_mat
	mg = _layer("Mg")
	fg = _layer("Fg")
	fg.material = _fg_mat
	var border := Sprite2D.new()
	border.texture = _t("blank_overlay")
	border.centered = false
	add_child(border)
	debug_layer = _layer("Physics")
	debug_layer.modulate.a = 0.5
	debug_layer.draw.connect(_draw_physics)
	clock_label = Label.new()
	clock_label.text = "00:00"
	_clock_font = load(ART + "led_regular.ttf")
	clock_label.add_theme_font_override("font", _clock_font)
	clock_label.add_theme_font_size_override("font_size", 24)
	clock_label.add_theme_color_override("font_color", Color(1, 0, 0))
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.position = Vector2(340, -3)
	clock_label.size = Vector2(120, 30)
	clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock_label)
	_mats["wall"] = _mat(BOUNCE_WALL, FRICTION_WALL)
	_mats["floaty"] = _mat(BOUNCE_BODY, FRICTION_FLOATY)
	_mats["fuse"] = _mat(BOUNCE_BODY, FRICTION_FUSE)
	_mats["shep"] = _mat(BOUNCE_BODY, FRICTION_SHEP)
	_set_sim(false)


func _exit_tree() -> void:
	_set_sim(true)


func _layer(n: String) -> Node2D:
	var l := Node2D.new()
	l.name = n
	add_child(l)
	return l


func _mat(bounce: float, friction: float) -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = bounce
	m.friction = friction
	return m


func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(ART + n + ".png")
	return _tex[n]


## Pauses or runs this viewport's physics space (physaxe's world only moved
## when Game1 called world.step).
func _set_sim(active: bool) -> void:
	if not is_inside_tree():
		return
	var w := get_world_2d()
	if w and w != get_tree().root.world_2d:
		PhysicsServer2D.space_set_active(w.space, active)


# ---- console API (called from game.gd, like console.mxml called Game1) ------

func start_level(n: int) -> void:
	resume()
	_reset_world(n)
	music.emit("start")
	time_left = float(Levels.TIME_LIMIT)
	last_text = ""
	done = false
	_set_sim(true)


func restart() -> void:
	start_level(current_level)


func pause() -> void:
	paused = true
	music.emit("pause")
	_set_sim(false)


func resume() -> void:
	paused = false
	time_left = float(Levels.time_count(time_left))   # FlashClock.resume
	music.emit("resume")
	if not done:
		_set_sim(true)


func exit_level() -> void:
	done = true
	_set_sim(false)


func secs_left() -> int:
	return Levels.time_count(time_left)


# ---- world setup -----------------------------------------------------------

func _reset_world(n: int) -> void:
	done = true
	bg.modulate = Color.WHITE
	mg.modulate = Color.WHITE
	fg.modulate = Color.WHITE
	bg.position = Vector2.ZERO
	_set_blur(Vector2.ZERO)
	for layer in [bg, mg, fg]:
		for c in layer.get_children():
			layer.remove_child(c)
			c.queue_free()
	pockets.clear()
	fuses.clear()
	doors.clear()
	spinners.clear()
	floaters.clear()
	current_level = n

	shep = _rigid("Shep", _circle(Levels.SHEP_RADIUS), _mats["shep"],
		PI * Levels.SHEP_RADIUS * Levels.SHEP_RADIUS * DENSITY_SHEP)
	shep.position = Levels.DEFAULT_START
	shep.body_entered.connect(_on_shep_contact)
	shep_clip = Node2D.new()
	var png := Sprite2D.new()
	png.texture = _t("bot")
	png.centered = false
	png.position = -png.texture.get_size() / 2.0
	shep_clip.add_child(png)
	glow_clip = Sprite2D.new()
	glow_clip.texture = _t("engine-glow")
	glow_clip.centered = false
	glow_clip.position = Vector2(-glow_clip.texture.get_width() / 2.0,
		png.position.y + png.texture.get_height() - glow_clip.texture.get_height() + 5)
	glow_clip.modulate.a = 0.0
	shep_clip.add_child(glow_clip)

	# boundary walls: top, left, right, bottom
	var b := Levels.BORDER
	var walls := StaticBody2D.new()
	walls.name = "Border"
	walls.physics_material_override = _mats["wall"]
	for r in [Rect2(0, 0, Levels.W, b), Rect2(0, b, b, Levels.H - 2 * b),
			Rect2(Levels.W - b, b, b, Levels.H - 2 * b), Rect2(0, Levels.H - b, Levels.W, b)]:
		walls.add_child(_box_shape(r))
	mg.add_child(walls)

	_load_level(n)


func _load_level(n: int) -> void:
	var bgn := Levels.bg_name(n)
	if bgn != "":
		bg.add_child(_sprite(bgn))
	var fgn := Levels.fg_name(n)
	if fgn != "":
		fg.add_child(_sprite(fgn))
	level = Levels.parse_svg(svg_override) if svg_override != "" else Levels.parse_level(n)
	for it in level["items"]:
		match it["kind"]:
			Levels.WALL_RECT: _add_wall_rect(it["rect"])
			Levels.WALL_POLY: _add_wall_poly(it["center"], it["points"])
			Levels.FLOATER: _add_floater(it)
			Levels.POCKET: _add_pocket(it["pos"], it["code"])
			Levels.DOOR: _add_door(it["rect"])
			Levels.SPINNER: _add_spinner(it["pos"], it["horizontal"])
			Levels.FUSE: _add_fuse(it["pos"], it["code"])
	shep.position = level["start"]
	shep_clip.position = shep.position
	mg.add_child(shep)
	mg.add_child(shep_clip)   # shep is at the very end so he goes on top


func _sprite(n: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _t(n)
	s.centered = false
	return s


func _circle(r: float) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = r
	cs.shape = c
	return cs


func _box_shape(r: Rect2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	return cs


func _rigid(n: String, shape: Node2D, mat: PhysicsMaterial, area_density: float) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = n
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.mass = maxf(area_density * MASS_SCALE, 0.01)
	body.physics_material_override = mat
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.add_child(shape)
	return body


func _add_wall_rect(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.physics_material_override = _mats["wall"]
	body.add_child(_box_shape(r))
	mg.add_child(body)


func _add_wall_poly(c: Vector2, pts: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.physics_material_override = _mats["wall"]
	body.position = c
	var cp := CollisionPolygon2D.new()
	cp.polygon = pts
	body.add_child(cp)
	mg.add_child(body)


func _add_floater(it: Dictionary) -> void:
	var cp := CollisionPolygon2D.new()
	cp.polygon = it["points"]
	var body := _rigid("Floater", cp, _mats["floaty"],
		Levels.poly_area(it["points"]) * DENSITY_FLOATY)
	body.position = it["center"]
	var clip := _sprite("cargo-box" if it["clip"] == "cargo" else "hex-crate")
	clip.position = -clip.texture.get_size() / 2.0
	body.add_child(clip)
	body.body_entered.connect(_on_floater_contact.bind(body))
	floaters.append(body)
	mg.add_child(body)


func _add_pocket(c: Vector2, code: int) -> void:
	var body := StaticBody2D.new()
	body.name = "Pocket"
	body.set_meta("pocket", true)
	body.physics_material_override = _mats["wall"]
	body.position = c
	body.add_child(_circle(Levels.POCKET_RADIUS))
	mg.add_child(body)
	var clip := Node2D.new()
	clip.position = c
	var sock := Sprite2D.new()
	sock.texture = _t("red-pocket" if code > 0 else "pocket")
	clip.add_child(sock)
	var glow := Sprite2D.new()
	glow.texture = _t("socket-glow")
	glow.modulate = Color(0.95, 0, 0) if code > 0 else Color(0, 0.65, 0.85)
	clip.add_child(glow)
	mg.add_child(clip)
	pockets.append({"body": body, "code": code, "pos": c, "clip": clip, "glow": glow})


func _add_door(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "Door"
	body.physics_material_override = _mats["wall"]
	body.add_child(_box_shape(r))
	mg.add_child(body)
	var clip := _sprite("door")
	clip.position = r.position
	clip.modulate = Color(1.0, 0.85, 0.85)   # stand-in for the red GlowFilter
	mg.add_child(clip)
	doors.append({"body": body, "clip": clip})


func _add_spinner(c: Vector2, horizontal: bool) -> void:
	var body := AnimatableBody2D.new()
	body.name = "Spinner"
	body.physics_material_override = _mats["wall"]
	body.position = c
	body.add_child(_box_shape(Rect2(-Levels.SPINNER_SIZE / 2.0, Levels.SPINNER_SIZE)))
	if horizontal:
		body.rotation = deg_to_rad(-90)
	var clip := Sprite2D.new()
	clip.texture = _t("spinner")
	body.add_child(clip)
	spinners.append(body)
	mg.add_child(body)


func _add_fuse(c: Vector2, code: int) -> void:
	var r := Levels.FUSE_RADIUS
	var body := _rigid("Fuse", _circle(r), _mats["fuse"], PI * r * r * DENSITY_FUSE)
	body.set_meta("fuse", true)
	body.position = c
	var clip := Sprite2D.new()
	clip.texture = _t("red-ball" if code > 0 else "ball")
	body.add_child(clip)
	body.body_entered.connect(_on_fuse_contact.bind(body))
	mg.add_child(body)
	fuses.append({"body": body, "code": code})


# ---- per frame ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if done or paused or shep == null:
		return
	_update_world(delta)
	_update_clock(delta)
	# these have to come after the clock updates
	_check_for_win()
	if done:
		return
	_check_for_loss()
	_draw_world()


func _update_world(delta: float) -> void:
	var frames := FPS * delta
	var lin := pow(GAME_FRICTION * PHX_FRICTION, frames)
	var ang := pow(PHX_FRICTION, frames)
	_last_v = shep.linear_velocity
	shep.linear_velocity *= lin
	shep.angular_velocity *= ang
	for f in fuses:
		var body: RigidBody2D = f["body"]
		body.linear_velocity *= lin
		body.angular_velocity *= ang
	for body in floaters:
		body.linear_velocity *= pow(PHX_FRICTION, frames)
		body.angular_velocity *= ang
	# power the spinners
	for s in spinners:
		s.rotation += Levels.SPINNER_VELOCITY * frames


func _update_clock(delta: float) -> void:
	time_left -= delta
	var count := Levels.time_count(time_left)
	var text := Levels.clock_text(count)
	clock_label.text = text
	if count <= 30:
		# red alert!
		var v := Levels.red_alert_v(time_left)
		bg.modulate = Color(0.25 + v, 0, 0)
		mg.modulate = Color(1 + v, 0.75, 0.75)
		fg.modulate = Color(0.75 + v, 0.5, 0.5)
		if text != last_text:
			var a := Levels.alert_for(count)
			if a != "":
				sfx.emit(a)
	last_text = text


func _touching(body: RigidBody2D, radius: float, pocket: Dictionary) -> bool:
	if body.get_colliding_bodies().has(pocket["body"]):
		return true
	return body.position.distance_to(pocket["pos"]) <= radius + Levels.POCKET_RADIUS + TOUCH_SLOP


func _check_for_win() -> void:
	for pocket in pockets:
		if _touching(shep, Levels.SHEP_RADIUS, pocket):
			if fuses.is_empty():
				_on_win()
				return
		for f in fuses.duplicate():
			if not _touching(f["body"], Levels.FUSE_RADIUS, pocket):
				continue
			if f["code"] != pocket["code"]:
				continue
			fuses.erase(f)
			var body: RigidBody2D = f["body"]
			mg.remove_child(body)
			body.queue_free()
			#@TODO: multiple colored doors?  (original note)
			if pocket["code"] > 0 and not doors.is_empty():
				open_door(doors[0])
			sfx.emit("pocket")
			if fuses.is_empty():
				for p in pockets:
					_open_wide(p)
			else:
				_swallow(pocket)


## PocketClip.swallow: socket.swf played its close/open frames. That clip is
## Flash vector art, so this is a quick squeeze of pocket.png instead.
func _swallow(pocket: Dictionary) -> void:
	var clip: Node2D = pocket["clip"]
	var tw := clip.create_tween()
	tw.tween_property(clip, "scale", Vector2(0.8, 0.8), 0.15)
	tw.tween_property(clip, "scale", Vector2.ONE, 0.25)


## PocketClip.openWide: the socket stays fully open once every fuse is in.
## Shown as a pulsing glow so you can see where to dock.
func _open_wide(pocket: Dictionary) -> void:
	_swallow(pocket)
	var glow: Sprite2D = pocket["glow"]
	glow.modulate = Color(0.4, 1.0, 0.6)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.35, 0.5)
	tw.tween_property(glow, "modulate:a", 1.0, 0.5)


func open_door(d: Dictionary) -> void:
	sfx.emit("door")
	doors.erase(d)
	var body: StaticBody2D = d["body"]
	if is_instance_valid(body):
		body.queue_free()
	var clip: Sprite2D = d["clip"]
	clip.modulate = Color.WHITE   # d.clip.filters = []
	var tw := clip.create_tween()
	tw.tween_property(clip, "position:y", clip.position.y + clip.texture.get_height(), 1.0) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(clip.queue_free)


func _check_for_loss() -> void:
	if Levels.time_count(time_left) <= 0:
		_on_loss()


func _draw_world() -> void:
	if show_physics:
		debug_layer.queue_redraw()
	var v: Vector2
	if keyboard_control:
		v = Levels.facing(shep_clip.rotation_degrees) * 10.0
	else:
		v = Levels.calc_vector(shep.position, mouse_pos, AIM_R)
		shep_clip.rotation_degrees = Levels.aim_rotation_deg(v)
	shep_clip.position = shep.position


func _on_win() -> void:
	done = true
	_set_sim(false)
	sfx.emit("victory")
	music.emit("pause")
	won.emit(secs_left())


func _on_loss() -> void:
	done = true
	_set_sim(false)
	sfx.emit("defeat")
	music.emit("pause")
	lost.emit()


# ---- contact sounds (drawWorld / makeBallSounds / makeFloatSounds) ------------

func _is_circle(n: Node) -> bool:
	return n.has_meta("fuse") or n.has_meta("pocket")


func _on_shep_contact(other: Node) -> void:
	if done or other.has_meta("pocket"):
		return  # handled by checkForWin
	if other.has_meta("fuse"):
		sfx.emit("fuse")
		return
	sfx.emit("wall")
	# the background lurches away from the hit and blurs, then settles
	var dir := _last_v.normalized() if _last_v.length() > 0.01 else Vector2.ZERO
	var c := dir * Levels.SHEP_RADIUS     # contact point relative to the bot
	var shift := Vector2(-floorf(c.x / 2.5), -floorf(c.y / 2.5))
	if _shake and _shake.is_valid():
		_shake.kill()
	_shake = create_tween().set_parallel()
	_shake.tween_method(_set_bg_offset, shift, Vector2.ZERO, 0.6)
	# Flash clamps negative blur to 0
	_shake.tween_method(_set_blur, Vector2(maxf(shift.x, 0), maxf(shift.y, 0)), Vector2.ZERO, 0.6)


func _on_fuse_contact(other: Node, me: RigidBody2D) -> void:
	if done:
		return
	if _is_circle(other):
		if other == shep:
			return  # handled by the bot
		if other.has_meta("fuse") and other.get_instance_id() < me.get_instance_id():
			return  # the pair shares one arbiter: only one sound
		sfx.emit("fuse")   # fuse on fuse
	elif other != shep:
		sfx.emit("fusewall")  # fuse on wall


func _on_floater_contact(other: Node, _me: RigidBody2D) -> void:
	if done or _is_circle(other) or other == shep:
		return
	sfx.emit("wall")


func _set_bg_offset(v: Vector2) -> void:
	bg.position = v


func _set_blur(v: Vector2) -> void:
	_blur = v
	_bg_mat.set_shader_parameter("blur", v)
	_fg_mat.set_shader_parameter("blur", v / 2.0)


# ---- input -------------------------------------------------------------------

## onClick: jet toward the mouse.
func click_kick(at: Vector2) -> void:
	if done or paused:
		return
	mouse_pos = at
	keyboard_control = false
	kick(Levels.calc_vector(shep.position, mouse_pos, KICK_MOUSE))


func kick(per_frame: Vector2) -> void:
	shep.sleeping = false
	shep.linear_velocity += per_frame * FPS
	sfx.emit("thrust")
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	glow_clip.modulate.a = 1.0
	_glow_tween = create_tween()
	_glow_tween.tween_property(glow_clip, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func mouse_moved(at: Vector2) -> void:
	mouse_pos = at
	keyboard_control = false


## Game1.onKeyDown. Returns true if the key was used. The letter and digit keys
## are Michal's debug keys, kept as they were.
func key(code: Key) -> bool:
	match code:
		KEY_B:
			_set_blur(Vector2(10, _blur.y))
		KEY_O:
			if not doors.is_empty():
				open_door(doors[0])
				doors.clear()
		KEY_P:
			show_physics = not show_physics
			debug_layer.queue_redraw()
		KEY_R:
			time_left = 30.0   # red alert 1
		KEY_E:
			time_left = 20.0   # red alert 2
		KEY_D:
			time_left = 10.0   # red alert 3
		KEY_T:
			bg.modulate = Color(randf(), randf(), randf())
		KEY_X:
			var pre := Preview.new()
			pre.scale = Vector2(0.33, 0.33)
			pre.show_level(current_level)
			fg.add_child(pre)
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			start_level(code - KEY_0)
		# keyboard steering: Game1 had this branch behind keyboardControl,
		# which nothing ever set. The port turns it on with the arrows.
		KEY_UP:
			if done or paused:
				return false
			keyboard_control = true
			kick(Levels.facing(shep_clip.rotation_degrees) * KICK_KEY)
		KEY_LEFT:
			keyboard_control = true
			shep_clip.rotation_degrees -= TURN_KEY
		KEY_RIGHT:
			keyboard_control = true
			shep_clip.rotation_degrees += TURN_KEY
		_:
			return false
	return true


# ---- debug draw (P) ----------------------------------------------------------

func _draw_physics() -> void:
	if not show_physics:
		return
	for body in mg.get_children():
		if not body is CollisionObject2D:
			continue
		var xf: Transform2D = body.transform
		for c in body.get_children():
			if c is CollisionShape2D:
				var t: Transform2D = xf * c.transform
				debug_layer.draw_set_transform_matrix(t)
				if c.shape is CircleShape2D:
					debug_layer.draw_circle(Vector2.ZERO, c.shape.radius, Color(0.2, 0.9, 0.3))
					debug_layer.draw_line(Vector2.ZERO, Vector2(c.shape.radius, 0), Color.BLACK)
				elif c.shape is RectangleShape2D:
					debug_layer.draw_rect(Rect2(-c.shape.size / 2.0, c.shape.size), Color(0.3, 0.6, 1.0))
			elif c is CollisionPolygon2D:
				debug_layer.draw_set_transform_matrix(xf * c.transform)
				debug_layer.draw_colored_polygon(c.polygon, Color(1.0, 0.6, 0.2))
	# the 60x60 pocket zones ("really just here for debugging purposes")
	debug_layer.draw_set_transform_matrix(Transform2D.IDENTITY)
	for p in pockets:
		var z := Levels.POCKET_ZONE
		debug_layer.draw_rect(Rect2(p["pos"] - Vector2(z, z) / 2.0, Vector2(z, z)), Color(1, 1, 1), false, 1.0)
