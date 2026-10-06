extends Control
## Spiders v. Aliens: Enhanced edition.
## A presentation layer over the Direct edition's simulation: the rules, the level and the
## 60 Hz fixed step are exactly res://games/spiders_v_aliens/direct/sva_logic.gd (shared, not
## copied). This edition only changes how the game looks, sounds and explains itself:
##   * stage.gd   - widescreen 854x480 world view, supersampled, smooth camera, per-pixel
##                  lighting, palette regrade, nebula backdrop, glows, drop shadows
##   * hud.gd     - crisp native-resolution HUD, restyled title / prologue / end screens,
##                  minimap, contextual grab prompts (hints.gd)
##   * sfx.gd     - synthesized sound effects (the original had music only)
## Esc goes to the PauseOverlay autoload (pausing the tree stops the simulation and audio).

const Logic := preload("res://games/spiders_v_aliens/direct/sva_logic.gd")
const Hints := preload("res://games/spiders_v_aliens/enhanced/hints.gd")
const Stage := preload("res://games/spiders_v_aliens/enhanced/stage.gd")
const Sfx := preload("res://games/spiders_v_aliens/enhanced/sfx.gd")
const MUSIC := preload("res://games/spiders_v_aliens/direct/audio/sva-music.mp3")

const VIEW := Stage.VIEW
## Same as Direct: Flixel's FlxG.volume 0.5 x playMusic volume 1.0.
const MUSIC_VOLUME := 0.5

## Keys the shared simulation polls (as in Direct) plus Enhanced extras:
## enter = skip the prologue, r = retry after GAME OVER, m = minimap, h = grab hints.
const KEYMAP := {
	"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
	"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D,
	"comma": KEY_COMMA, "o": KEY_O, "e": KEY_E,
	"g": KEY_G, "space": KEY_SPACE,
	"enter": KEY_ENTER, "r": KEY_R, "m": KEY_M, "h": KEY_H,
}

var world: Logic = Logic.new(Logic.MENU)
var stage: Stage
var sfx: Sfx
var time := 0.0
var cam_center := Vector2(800, 900)
var cam_topleft := Vector2.ZERO
var show_map := true
var show_hints := true
var play_time := 0.0
var aliens_at_start := 0
var hurt_flash := 0.0
var fade := 1.0
var prompts: Array = []

var _acc := 0.0
var _just := {}
var _snap := true
var _music: AudioStreamPlayer
var _snap_state := {}

@onready var _view: TextureRect = %WorldView
@onready var hud: Control = %Hud
@onready var _back: Button = %BackButton


func _ready() -> void:
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	move_child(stage, 0)
	_view.texture = stage.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	var loop: AudioStreamMP3 = MUSIC.duplicate()
	loop.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = loop
	_music.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(_music)
	_back.focus_mode = Control.FOCUS_NONE  # Space must start the game, never press this
	_back.pressed.connect(_to_arcade)
	resized.connect(_layout)
	_layout()
	hud.game = self
	_render()


func _exit_tree() -> void:
	world.dispose()
	_music.stop()
	sfx.stop_all()


func _to_arcade() -> void:
	var reg := get_node_or_null("/root/GameRegistry")
	if reg != null:
		reg.return_to_arcade()


# --- layout -------------------------------------------------------------------
## Where the 854x480 world view sits inside this Control (aspect kept, centered).
func view_rect() -> Rect2:
	var s := minf(size.x / VIEW.x, size.y / VIEW.y)
	if s <= 0.0:
		s = 1.0
	var sz := VIEW * s
	return Rect2(((size - sz) * 0.5).floor(), sz)


func view_scale() -> float:
	return view_rect().size.x / VIEW.x


func world_to_screen(p: Vector2) -> Vector2:
	var r := view_rect()
	return r.position + (p - cam_topleft) * (r.size.x / VIEW.x)


func _layout() -> void:
	var r := view_rect()
	_view.position = r.position
	_view.size = r.size
	# supersample to the next integer >= physical pixels per world texel
	var phys := view_scale()
	var vp := get_viewport()
	if vp != null:
		phys *= vp.get_final_transform().get_scale().x
	stage.set_supersample(int(ceil(phys - 0.01)))


# --- input --------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for k in KEYMAP:
			if event.keycode == KEYMAP[k]:
				_just[k] = true


func _poll_held() -> Dictionary:
	var held := {}
	for k in KEYMAP:
		held[k] = Input.is_key_pressed(KEYMAP[k])
	return held


func _process(delta: float) -> void:
	time += delta
	_acc = minf(_acc + delta, 0.25)
	while _acc >= Logic.DT:
		_acc -= Logic.DT
		var just := _just
		_just = {}
		step_once(_poll_held(), just)
	_update_camera(delta)
	hurt_flash = move_toward(hurt_flash, 0.0, delta * 2.5)
	fade = move_toward(fade, 0.0, delta * 2.2)
	if Engine.get_process_frames() % 30 == 0:
		_layout()
	_render()


## One Flixel frame. `held`/`just` use KEYMAP names (tests drive the scene through this).
func step_once(held: Dictionary, just := {}) -> void:
	for k in just:
		held[k] = true  # a tap shorter than one frame still counts as held once
	if just.get("m", false):
		show_map = not show_map
	if just.get("h", false):
		show_hints = not show_hints
	var s := world.state
	if just.get("enter", false) and (s == Logic.MENU or s == Logic.OPENING1 or s == Logic.OPENING2):
		new_game()
		return
	if just.get("r", false) and s == Logic.DEATH:
		new_game()
		return
	var before := _snapshot()
	world.step({"held": held, "just": just})
	if world.music_start:
		_music.play()  # FlxG.playMusic restarts the loop from the top
	if world.state != s:
		_on_state_changed(s)
	elif world.state == Logic.PLAY:
		play_time += Logic.DT
		_sound_events(before, _snapshot())
	prompts = _prompts()


## Start a fresh run straight into the AlienShip (Enhanced QoL: skip prologue / retry).
func new_game() -> void:
	var s := world.state
	world.dispose()
	world = Logic.new(Logic.PLAY)
	_music.play()
	_on_state_changed(s)
	prompts = _prompts()


func _on_state_changed(prev: int) -> void:
	fade = 0.6
	match world.state:
		Logic.PLAY:
			play_time = 0.0
			hurt_flash = 0.0
			aliens_at_start = alive_aliens()
			_snap = true
			hud.reset_map()
		Logic.DEATH:
			sfx.play("lose")
			hurt_flash = 1.0
		Logic.WIN:
			sfx.play("win")
		Logic.MENU:
			_snap = true
	if prev == Logic.PLAY and world.state != Logic.PLAY:
		fade = 0.0


func alive_aliens() -> int:
	var n := 0
	for a in world.aliens:
		if a.alive and a.exists:
			n += 1
	return n


func locks_open() -> int:
	var n := 0
	for m in world.machines:
		if m.kind == "KeyBox" and m.has_power:
			n += 1
	return n


func locks_total() -> int:
	var n := 0
	for m in world.machines:
		if m.kind == "KeyBox":
			n += 1
	return n


func _prompts() -> Array:
	if world.state != Logic.PLAY or world.cam_target == null:
		return []
	return Hints.prompts(world, world.cam_target)


# --- audio events (diffing the shared simulation; it has no event hooks) -------
func _snapshot() -> Dictionary:
	if world.state != Logic.PLAY or world.hero == null:
		return {}
	var power := []
	for m in world.machines:
		power.append(m.has_power)
	var holding := 0
	for g in world.grabber_list:
		if g.exists and g.content != null and g.content.exists:
			holding += 1
	return {
		"health": world.hero.health,
		"bullets": world.bullets.size(),
		"aliens": alive_aliens(),
		"hero": Vector2(world.hero.x, world.hero.y),
		"geist": Vector2(world.geist.x, world.geist.y),
		"power": power,
		"holding": holding,
	}


func _sound_events(a: Dictionary, b: Dictionary) -> void:
	if a.is_empty() or b.is_empty():
		return
	if b.health < a.health:
		sfx.play("hurt")
		hurt_flash = 1.0
	elif b.health > a.health:
		sfx.play("heal")
	if b.bullets > a.bullets:
		sfx.play("zap")
	if b.aliens < a.aliens:
		sfx.play("splat")
	if a.hero.distance_to(b.hero) > 10.0 or a.geist.distance_to(b.geist) > 10.0:
		sfx.play("warp")
	for i in mini(a.power.size(), b.power.size()):
		if a.power[i] != b.power[i]:
			var kind: String = world.machines[i].kind
			if kind == "KeyBox" and b.power[i]:
				sfx.play("unlock")
			elif kind == "SwitchBox":
				sfx.play("click")
	if b.holding > a.holding:
		sfx.play("grab")
	elif b.holding < a.holding:
		sfx.play("drop")


# --- camera & render ----------------------------------------------------------
func in_level() -> bool:
	var s := world.state
	return world.hero != null and (s == Logic.PLAY or s == Logic.DEATH or s == Logic.WIN)


func _update_camera(delta: float) -> void:
	if in_level() and world.cam_target != null:
		var t = world.cam_target
		var target := Vector2(t.x + t.w * 0.5, t.y + t.h * 0.5)
		if world.state == Logic.PLAY:
			target += Vector2(t.vx, t.vy) * 0.18  # a little look-ahead
		if _snap or cam_center.distance_to(target) > 220.0:
			cam_center = target
			_snap = false
		else:
			cam_center = cam_center.lerp(target, 1.0 - exp(-7.0 * delta))
	else:
		# title / prologue backdrop: drift slowly over the dimmed ship
		cam_center = Vector2(820, 960) + Vector2(cos(time * 0.045) * 520.0, sin(time * 0.031) * 360.0)
	var tl := cam_center - VIEW * 0.5
	tl.x = clampf(tl.x, 0.0, Logic.BOUNDS_W - VIEW.x)
	tl.y = clampf(tl.y, 0.0, Logic.BOUNDS_H - VIEW.y)
	cam_topleft = tl.round() + (Vector2(world.shake_x, world.shake_y) * 0.75).round()


func _render() -> void:
	var marks: Array = []
	if show_hints:
		for p in prompts:
			var c := Color(0.35, 1.0, 0.95, 0.9)
			if p["danger"]:
				c = Color(1.0, 0.3, 0.3, 0.95)
			elif not p["active"]:
				c = Color(1.0, 0.7, 0.3, 0.8)
			elif p["held"]:
				c = Color(1.0, 0.95, 0.5, 0.9)
			marks.append({"target": p["target"], "color": c})
	stage.marks = marks
	stage.geist_hint = world.toggle_cam
	stage.sync(world, cam_topleft, time, in_level())
	_back.visible = world.state == Logic.MENU
	hud.queue_redraw()
