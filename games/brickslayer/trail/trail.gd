extends Control
## Brickslayer code trail: step through the 2007 lessons block by block, read
## the notes and code, and play the game as it stood at that lesson.
## Esc is handled by the arcade PauseOverlay autoload.

const TrailData := preload("res://games/brickslayer/trail/trail_data.gd")
const TrailCursor := preload("res://games/brickslayer/trail/trail_cursor.gd")
const Session := preload("res://games/brickslayer/session.gd")
const GAME_SCENE := "res://games/brickslayer/direct/game.tscn"

const JS_KEYWORDS := [
	"var", "function", "return", "if", "else", "for", "while", "switch", "case",
	"break", "default", "new", "this", "null", "true", "false", "in",
]

var cursor := TrailCursor.new(TrailData.LESSONS)

@onready var _lessons: ItemList = %Lessons
@onready var _title: Label = %Title
@onready var _where: Label = %Where
@onready var _notes: RichTextLabel = %Notes
@onready var _code: CodeEdit = %Code
@onready var _prev: Button = %Prev
@onready var _next: Button = %Next
@onready var _play: Button = %Play


func _ready() -> void:
	for l in TrailData.LESSONS:
		_lessons.add_item("%s  %s" % [l["slug"].substr(0, 2), l["title"]])
	_lessons.item_selected.connect(func(i): _go(i, 0))
	_prev.pressed.connect(func(): cursor.prev(); _refresh())
	_next.pressed.connect(func(): cursor.next(); _refresh())
	_play.pressed.connect(_play_step)
	%Back.pressed.connect(GameRegistry.return_to_arcade)
	_code.syntax_highlighter = _js_highlighter()
	cursor.seek(Session.trail_lesson, Session.trail_block)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_RIGHT, KEY_PAGEDOWN:
			cursor.next(); _refresh()
		KEY_LEFT, KEY_PAGEUP:
			cursor.prev(); _refresh()
		KEY_DOWN:
			_go(cursor.lesson + 1, 0)
		KEY_UP:
			_go(cursor.lesson - 1, 0)
		KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_play_step()
			return
		_:
			return
	get_viewport().set_input_as_handled()


func _go(lesson: int, block: int) -> void:
	cursor.seek(lesson, block)
	_refresh()


func _refresh() -> void:
	var l := cursor.current()
	_title.text = "%s — %s" % [l["slug"], l["title"]]
	_where.text = "step %d / %d   ·   trail cursor %.3f" % [
		cursor.block + 1, cursor.block_count(), cursor.value()]
	var note := cursor.note()
	_notes.text = note if note != "" else "(no notes for this block)"
	var code := cursor.code()
	_code.text = code if code != "" else "// (no code in this lesson)"
	_code.scroll_vertical = 0
	_prev.disabled = cursor.at_start()
	_next.disabled = cursor.at_end()
	_play.text = "▶  Play lesson %02d" % cursor.lesson
	if not _lessons.is_selected(cursor.lesson):
		_lessons.select(cursor.lesson)
		_lessons.ensure_current_is_visible()
	Session.trail_lesson = cursor.lesson
	Session.trail_block = cursor.block


func _play_step() -> void:
	Session.pending_step = cursor.lesson
	get_tree().change_scene_to_file(GAME_SCENE)


func _js_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color("#b5cea8")
	h.symbol_color = Color("#d4d4d4")
	h.function_color = Color("#dcdcaa")
	h.member_variable_color = Color("#9cdcfe")
	for kw in JS_KEYWORDS:
		h.add_keyword_color(kw, Color("#569cd6"))
	h.add_color_region("//", "", Color("#6a9955"), true)
	h.add_color_region("/*", "*/", Color("#6a9955"))
	h.add_color_region("<!--", "-->", Color("#6a9955"))
	h.add_color_region("\"", "\"", Color("#ce9178"))
	h.add_color_region("'", "'", Color("#ce9178"))
	return h
