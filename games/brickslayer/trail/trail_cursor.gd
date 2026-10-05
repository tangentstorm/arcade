extends RefCounted
## A cursor over the lesson trail, modeled on tangentcode's CodeTrail.
##
## In CodeTrail a trail is a list of commits, and each commit is a list of
## steps. Here each lesson is a commit and each recovered code block is a
## step. The cursor is a (lesson, block) pair, also written as one decimal
## (lesson + block/1000), like CodeTrail.stepFor().

var lessons: Array
var lesson := 0
var block := 0


func _init(p_lessons: Array) -> void:
	lessons = p_lessons


func lesson_count() -> int:
	return lessons.size()


## Lessons with no code (10-enhancements) still get one step for their notes.
func block_count(i: int = lesson) -> int:
	return maxi(1, lessons[i]["blocks"].size())


func seek(p_lesson: int, p_block: int = 0) -> void:
	lesson = clampi(p_lesson, 0, lesson_count() - 1)
	block = clampi(p_block, 0, block_count() - 1)


func value() -> float:
	return lesson + block / 1000.0


func at_start() -> bool:
	return lesson == 0 and block == 0


func at_end() -> bool:
	return lesson == lesson_count() - 1 and block == block_count() - 1


func next() -> void:
	if block + 1 < block_count():
		block += 1
	elif lesson + 1 < lesson_count():
		lesson += 1
		block = 0


func prev() -> void:
	if block > 0:
		block -= 1
	elif lesson > 0:
		lesson -= 1
		block = block_count() - 1


func current() -> Dictionary:
	return lessons[lesson]


func code() -> String:
	var blocks: Array = current()["blocks"]
	return blocks[block] if block < blocks.size() else ""


## The prose before this block, plus the lesson's closing prose on its last step.
func note() -> String:
	var notes: Array = current()["notes"]
	var text: String = notes[block] if block < notes.size() else ""
	if block == block_count() - 1 and current()["outro"] != "":
		text = (text + "\n\n" + current()["outro"]).strip_edges()
	return text
