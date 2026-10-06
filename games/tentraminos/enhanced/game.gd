extends Control
## Tentraminos — Enhanced edition.
## A presentation layer over the *unchanged* Direct rules (direct/tentraminos_logic.gd):
## same 9×9 grid, 10-second rounds, 100 ms step() state machine, cursor-holds-tiles gravity,
## 4+ groups scoring 10·2^(n−4), same keymap. What's new: a clearer board (rounded tiles,
## colour glyphs, same-colour bridges, danger markers), a modern HUD (clock ring, best score,
## round stats), and juice (sliding rotations, smooth falls, landing squash, clear bursts,
## score popups, screen shake, synthesized SFX).
## Esc is handled by the PauseOverlay autoload (pausing the tree freezes the round clock).

const Logic := preload("res://games/tentraminos/direct/tentraminos_logic.gd")
const Board := preload("res://games/tentraminos/enhanced/board.gd")
const Sfx := preload("res://games/tentraminos/enhanced/sfx.gd")

const BEST_PATH := "user://tentraminos_enhanced.cfg"
const GW := Logic.GW
const N := Logic.NUMCELLS

## Same keymap as Direct (original dvorak map + arrows + wasd + z/x + k/l, and j).
const KEYMAP := {
	KEY_C: "^", KEY_H: "<", KEY_N: ">", KEY_O: "(", KEY_P: "p", KEY_T: "v", KEY_U: ")",
	KEY_J: ")",
	KEY_X: ")", KEY_Z: "(",
	KEY_W: "^", KEY_A: "<", KEY_S: "v", KEY_D: ">", KEY_K: "(", KEY_L: ")",
	KEY_LEFT: "<", KEY_UP: "^", KEY_RIGHT: ">", KEY_DOWN: "v",
}

## Set before adding to the tree to make runs deterministic (tests). -1 = random.
var seed_value := -1
## Tests turn this off so they don't overwrite the player's best score.
var persist_best := true

var game  # Logic instance (the Direct rules)
var started := false
var sfx: Node

# -- HUD bookkeeping --------------------------------------------------------
var best := 0
var new_best := false
var rounds := 0
var tiles_cleared := 0
var biggest_group := 0
var last_clear := ""
var display_score := 0.0

# -- juice state (all purely visual) ----------------------------------------
var offsets := PackedVector2Array()   # per-cell draw offset (px), decays to 0
var squash := PackedFloat32Array()    # per-cell landing squash 0..1
var falling := PackedByteArray()      # cell received a falling tile last tick
var particles: Array = []             # {pos, vel, color, life, size, spin}
var popups: Array = []                # {pos, text, color, life, size}
var flashes: Array = []               # {cell, color, life}
var shake := 0.0
var cursor_px := Vector2.ZERO         # cursor top-left in grid space (px)
var cursor_nudge := Vector2.ZERO
var rot_flash := {"dir": 0, "life": 0.0}
var hold_pop := 0.0
var time := 0.0
var show_glyphs := true

var _acc_ms := 0.0
var _cursor_tween: Tween
var _rng := RandomNumberGenerator.new()

@onready var board: Control = %Board
@onready var ring: Control = %ClockRing
@onready var _score: Label = %ScoreValue
@onready var _best: Label = %BestValue
@onready var _stats: Label = %Stats
@onready var _status: Label = %Status
@onready var _overlay: Control = %Overlay
@onready var _card_title: Label = %CardTitle
@onready var _card_body: Label = %CardBody
@onready var _card_hint: Label = %CardHint


func _ready() -> void:
	game = Logic.new(seed_value)
	_rng.seed = 27 if seed_value < 0 else seed_value
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	offsets.resize(N)
	squash.resize(N)
	falling.resize(N)
	board.g = self
	ring.g = self
	board.custom_minimum_size = Board.BOARD_SIZE
	%BackButton.pressed.connect(_to_arcade)
	%CardBack.pressed.connect(_to_arcade)
	_load_best()
	cursor_px = _cursor_target()
	_show_card("start")
	_refresh_hud()


func _exit_tree() -> void:
	if sfx:
		sfx.stop_all()


func _to_arcade() -> void:
	var reg := get_node_or_null("/root/GameRegistry")
	if reg != null:
		reg.return_to_arcade()


# -- loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	if started:
		_acc_ms = minf(_acc_ms + delta * 1000.0, 1000.0)
		while _acc_ms >= Logic.TICK_MS:
			_acc_ms -= Logic.TICK_MS
			tick_once()
	_update_juice(delta)
	_refresh_hud()
	queue_redraw()
	board.queue_redraw()
	ring.queue_redraw()


## Advance the Direct state machine by one 100 ms step and derive the juice from what changed.
func tick_once() -> void:
	var before: PackedInt32Array = game.matrix.duplicate()
	var prev_hold: PackedInt32Array = game.hold.duplicate()
	var prev_state: int = game.next
	var prev_score: int = game.score
	var prev_clock: int = game.clock
	game.tick(Logic.TICK_MS)
	match prev_state:
		Logic.NEWGAME:
			_drop_row()
		Logic.NEXTROUND:
			rounds += 1
			hold_pop = 1.0
		Logic.PLAYING:
			_gravity_juice(before)
			var s0 := ceili(prev_clock / 1000.0)
			var s1 := ceili(maxi(game.clock, 0) / 1000.0)
			if s1 < s0:
				if s1 >= 1 and s1 <= 3:
					sfx.play("tick")
				elif s1 == 0:
					sfx.play("tock")
		Logic.TIMEUP:
			var mid := before.duplicate()
			for i in GW:
				mid[i] = prev_hold[i]
			_drop_row()
			_clear_juice(mid, prev_score)
		Logic.CASCADE:
			_gravity_juice(before)
		Logic.CHECK4END:
			if game.next == Logic.THEEND:
				_on_game_over()


# -- input -----------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	if not started:
		if not k.echo and (k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or KEYMAP.has(k.keycode)):
			start_game()
			get_viewport().set_input_as_handled()
		return
	if game.next == Logic.THEEND:
		if not k.echo and k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_R, KEY_SPACE]:
			restart()
			get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_M and not k.echo:
		sfx.muted = not sfx.muted
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_G and not k.echo:
		show_glyphs = not show_glyphs
		get_viewport().set_input_as_handled()
		return
	if not KEYMAP.has(k.keycode):
		return
	var c: String = KEYMAP[k.keycode]
	if c == "p" and k.echo:
		return
	press(c)
	get_viewport().set_input_as_handled()


## Apply one original command code (^ v < > ( ) p) with Enhanced feedback.
func press(c: String) -> void:
	match c:
		"^", "v", "<", ">":
			var before := Vector2i(game.cursor_x, game.cursor_y)
			game.code(c)
			if Vector2i(game.cursor_x, game.cursor_y) != before:
				sfx.play("move")
				_move_cursor()
			else:
				var dir := {"^": Vector2.UP, "v": Vector2.DOWN, "<": Vector2.LEFT, ">": Vector2.RIGHT}
				cursor_nudge = dir[c] * 7.0
		"(", ")":
			var cxy: int = game.cursor_y * GW + game.cursor_x
			var o := offsets.duplicate()
			game.code(c)
			var pairs: Array
			if c == "(":  # counter-clockwise
				pairs = [[cxy, cxy + 1], [cxy + 1, cxy + GW + 1], [cxy + GW + 1, cxy + GW], [cxy + GW, cxy]]
			else:          # clockwise
				pairs = [[cxy, cxy + GW], [cxy + GW, cxy + GW + 1], [cxy + GW + 1, cxy + 1], [cxy + 1, cxy]]
			for p in pairs:
				var dst: int = p[0]
				var src: int = p[1]
				offsets[dst] = o[src] + Board.cell_vec(src) - Board.cell_vec(dst)
				falling[dst] = 0
				squash[dst] = 0.0
			rot_flash = {"dir": -1 if c == "(" else 1, "life": 1.0}
			sfx.play("rotate", 1.0 if c == ")" else 0.89)
		"p":
			game.code("p")
			sfx.play("pause", 1.0 if game.paused else 1.3)


func start_game() -> void:
	started = true
	_acc_ms = 0.0
	_show_card("")
	sfx.play("start")


func restart() -> void:
	game.new_game()
	_acc_ms = 0.0
	rounds = 0
	tiles_cleared = 0
	biggest_group = 0
	last_clear = ""
	new_best = false
	display_score = 0.0
	offsets.fill(Vector2.ZERO)
	squash.fill(0.0)
	falling.fill(0)
	particles.clear()
	popups.clear()
	flashes.clear()
	_move_cursor()
	start_game()


# -- juice -------------------------------------------------------------------

func _cursor_target() -> Vector2:
	return Board.cell_vec(game.cursor_y * GW + game.cursor_x)


func _move_cursor() -> void:
	if _cursor_tween:
		_cursor_tween.kill()
	if not is_inside_tree():
		cursor_px = _cursor_target()
		return
	_cursor_tween = create_tween()
	_cursor_tween.tween_property(self, "cursor_px", _cursor_target(), 0.09) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The hold row was released into row 0: slide those tiles down out of the tray.
func _drop_row() -> void:
	for i in GW:
		if game.matrix[i] != 0:
			offsets[i] = Vector2(0, -(Board.CELL + Board.TRAY_GAP))
			falling[i] = 1
	sfx.play("drop")


## run_gravity moves each tile at most one row per tick, so "empty before, filled after"
## means the tile came from the cell above.
func _gravity_juice(before: PackedInt32Array) -> void:
	var after: PackedInt32Array = game.matrix
	var o := offsets.duplicate()
	var fell := PackedByteArray()
	fell.resize(N)
	for j in N:
		if before[j] != 0 and after[j] == 0:
			offsets[j] = Vector2.ZERO
	for j in range(GW, N):
		if before[j] == 0 and after[j] != 0:
			offsets[j] = o[j - GW] + Vector2(0, -Board.CELL)
			fell[j] = 1
	var landed := 0
	for j in N:
		if falling[j] and not fell[j] and after[j] != 0 and (j + GW >= N or not fell[j + GW]):
			squash[j] = 1.0
			landed += 1
			if j + GW >= N or after[j + GW] != 0:
				var p := Board.GRID_ORIGIN + Board.cell_vec(j) + Vector2(Board.CELL * 0.5, Board.CELL)
				for k in 2:
					_spawn_particle(p + Vector2(_rng.randf_range(-20, 20), -2),
							Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-90, -30)),
							Color(1, 1, 1, 0.5), 0.35, 3.0)
	falling = fell
	if landed > 0:
		sfx.play("land", _rng.randf_range(0.9, 1.15))


static func base_color(v: int) -> int:
	return v - 9 if v > 8 else v


## TIMEUP cleared every lit group: burst them, pop the points, shake the board.
func _clear_juice(mid: PackedInt32Array, prev_score: int) -> void:
	var after: PackedInt32Array = game.matrix
	var cleared := {}
	for i in N:
		if mid[i] != 0 and after[i] == 0:
			cleared[i] = base_color(mid[i])
	if cleared.is_empty():
		return
	var seen := {}
	var groups: Array = []
	for i in cleared:
		if seen.has(i):
			continue
		var grp: Array[int] = []
		var stack: Array[int] = [i]
		seen[i] = true
		while not stack.is_empty():
			var c: int = stack.pop_back()
			grp.append(c)
			var x := c % GW
			for nb in [c - GW, c + GW, c - 1 if x > 0 else -1, c + 1 if x < GW - 1 else -1]:
				if nb >= 0 and nb < N and cleared.has(nb) and not seen.has(nb) and cleared[nb] == cleared[i]:
					seen[nb] = true
					stack.append(nb)
		groups.append(grp)
	var total: int = game.score - prev_score
	for grp in groups:
		var n: int = grp.size()
		var color: Color = Logic.COLORS[cleared[grp[0]] + 9]
		var centroid := Vector2.ZERO
		for c in grp:
			var center := Board.GRID_ORIGIN + Board.cell_vec(c) + Vector2.ONE * Board.CELL * 0.5
			centroid += center
			flashes.append({"cell": c, "color": color, "life": 1.0})
			offsets[c] = Vector2.ZERO
			falling[c] = 0
			for k in 7:
				var a := _rng.randf() * TAU
				var sp := _rng.randf_range(120.0, 380.0)
				_spawn_particle(center, Vector2(cos(a), sin(a)) * sp + Vector2(0, -120), color,
						_rng.randf_range(0.5, 0.9), _rng.randf_range(4.0, 9.0))
		centroid /= n
		var pts := 10 * (1 << mini(n - 4, 58))
		popups.append({"pos": centroid, "text": "+%d" % pts, "color": color,
				"life": 1.0, "size": 30 + mini(n - 4, 6) * 4})
		tiles_cleared += n
		biggest_group = maxi(biggest_group, n)
	if groups.size() > 1:
		popups.append({"pos": Board.GRID_ORIGIN + Vector2(Board.CELL * 4.5, Board.CELL * 1.2),
				"text": "%d GROUPS!  +%d" % [groups.size(), total], "color": Color("#ffffff"),
				"life": 1.3, "size": 34})
	last_clear = "+%d  ·  %d tiles in %d group%s" % [total, cleared.size(), groups.size(),
			"" if groups.size() == 1 else "s"]
	shake = clampf(0.35 + 0.15 * groups.size() + cleared.size() / 40.0, 0.0, 1.0)
	if total <= 20:
		sfx.play("clear1")
	elif total <= 80:
		sfx.play("clear2")
	else:
		sfx.play("clear3")


func _spawn_particle(pos: Vector2, vel: Vector2, color: Color, life: float, size: float) -> void:
	if particles.size() > 600:
		return
	particles.append({"pos": pos, "vel": vel, "color": color, "life": 1.0, "span": life,
			"size": size, "spin": _rng.randf_range(-8.0, 8.0), "rot": _rng.randf() * TAU})


func _update_juice(delta: float) -> void:
	for i in N:
		var off := offsets[i]
		if off != Vector2.ZERO:
			offsets[i] = off.move_toward(Vector2.ZERO, maxf(640.0 * delta, off.length() * 16.0 * delta))
		if squash[i] > 0.0:
			squash[i] = maxf(0.0, squash[i] - delta * 6.0)
	var alive: Array = []
	for p in particles:
		p.life -= delta / p.span
		if p.life > 0.0:
			p.vel.y += 900.0 * delta
			p.pos += p.vel * delta
			p.rot += p.spin * delta
			alive.append(p)
	particles = alive
	var keep: Array = []
	for p in popups:
		p.life -= delta / 1.1
		if p.life > 0.0:
			p.pos.y -= 55.0 * delta
			keep.append(p)
	popups = keep
	var fl: Array = []
	for f in flashes:
		f.life -= delta * 3.5
		if f.life > 0.0:
			fl.append(f)
	flashes = fl
	shake = maxf(0.0, shake - delta * 2.5)
	cursor_nudge = cursor_nudge.move_toward(Vector2.ZERO, 90.0 * delta)
	rot_flash.life = maxf(0.0, rot_flash.life - delta * 5.0)
	hold_pop = maxf(0.0, hold_pop - delta * 4.0)
	display_score = move_toward(display_score, game.score,
			maxf(60.0 * delta, absf(game.score - display_score) * 8.0 * delta))


func shake_offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	var s := shake * shake * 11.0
	return Vector2(sin(time * 83.0), cos(time * 71.0)) * s


## Round clock in ms, interpolated between 100 ms steps for a smooth ring.
func display_clock_ms() -> float:
	if game.next == Logic.PLAYING and not game.paused and started:
		return maxf(0.0, game.clock - _acc_ms)
	return maxf(0.0, game.clock)


## Columns where the next drop would stick in the top row (rows 1–8 full), unless a clear saves it.
func danger_columns() -> Array[int]:
	var out: Array[int] = []
	for x in GW:
		var full := true
		for y in range(1, Logic.GH):
			if game.matrix[y * GW + x] == 0:
				full = false
				break
		if full:
			out.append(x)
	return out


# -- HUD -----------------------------------------------------------------------

func _refresh_hud() -> void:
	_score.text = str(roundi(display_score))
	_best.text = "BEST  %d%s" % [maxi(best, game.score), "  ★ NEW" if new_best else ""]
	_stats.text = "ROUND %d    TILES %d    BIGGEST %d" % [rounds, tiles_cleared, biggest_group]
	if not started:
		_status.text = "Press Space to start"
	elif game.next == Logic.THEEND:
		_status.text = "Game over"
	elif game.paused:
		_status.text = "Paused  ·  P to resume"
	elif last_clear != "":
		_status.text = "Last clear  " + last_clear
	else:
		_status.text = "Make groups of 4+ before the clock hits 0"


func _show_card(kind: String) -> void:
	_overlay.visible = kind != ""
	match kind:
		"start":
			_card_title.text = "TENTRAMINOS"
			_card_body.text = "Slide and spin tiles with the 2×2 cursor to make groups of 4+ \
same-coloured tiles. Groups light up when they're big enough.\n\nEvery 10 seconds the lit groups \
clear (10 × 2ⁿ⁻⁴ points) and a new row drops in. Tiles held inside the cursor don't fall. \
If a tile gets stuck in the top row, it's game over."
			_card_hint.text = "Space / Enter to start"
		"over":
			_card_title.text = "GAME OVER"
			var lines := "Score  %d\nBest  %d%s\n\nRounds %d   ·   Tiles cleared %d   ·   Biggest group %d" % [
					game.score, best, "   ★ new best!" if new_best else "", rounds, tiles_cleared, biggest_group]
			_card_body.text = lines
			_card_hint.text = "Enter / R / Space to play again"


func _on_game_over() -> void:
	sfx.play("lose")
	if game.score > best:
		best = game.score
		new_best = true
		_save_best()
		sfx.play("best")
	_show_card("over")


func _load_best() -> void:
	if not persist_best:
		return
	var cf := ConfigFile.new()
	if cf.load(BEST_PATH) == OK:
		best = int(cf.get_value("tentraminos", "best", 0))


func _save_best() -> void:
	if not persist_best:
		return
	var cf := ConfigFile.new()
	cf.set_value("tentraminos", "best", best)
	cf.save(BEST_PATH)


# -- backdrop --------------------------------------------------------------------

func _draw() -> void:
	var top := Color("#151a2b")
	var bottom := Color("#0b0d16")
	var bands := 24
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, size.y * t, size.x, size.y / bands + 1), top.lerp(bottom, t))
	# slow drifting colour blobs from the palette (very faint)
	for i in 6:
		var c: Color = Logic.COLORS[10 + i]
		c.a = 0.05
		var p := Vector2(size.x * (0.15 + 0.14 * i) + sin(time * 0.21 + i * 1.7) * 60.0,
				size.y * (0.3 + 0.4 * fmod(i * 0.37, 1.0)) + cos(time * 0.17 + i) * 50.0)
		draw_circle(p, 150.0 + 30.0 * sin(time * 0.3 + i), c)
