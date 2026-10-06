extends RefCounted
## Word lists and keyboard layouts from Decker typing.deck config card.

const WORD_LIST_NAMES := ["letters", "sight words", "english top 100", "decker"]

const LETTERS := "a b c d e f g h i j k l m n o p q r s t u v w x y z"

const SIGHT_WORDS := (
	"a about all am an and are as at be been but by called can come could day "
	+ "did do down each end find first for from get go had has have he her him "
	+ "his how if in into is it its like long look made make many may more my "
	+ "no not now number of on one or other out part people said see she so "
	+ "some than that the their them then there these they this time to two "
	+ "up use was water way we were what when which who will with words would "
	+ "write you your"
)

const ENGLISH_TOP_100 := (
	"a about after all also an and any as at back be because but by can come "
	+ "could day do even first for from get give go good have he her him his "
	+ "how i if in into it its just know like look make me most my new no not "
	+ "now of on one only or other our out over people say see she so some "
	+ "take than that the their them then there these they think this time to "
	+ "two up us use want way we well what when which who will with work would "
	+ "year you your"
)

const DECKER := (
	"add alert and app array asc author bits brush by card cards cat clear "
	+ "colors cols column contraptions copy corners count cursor deck desc "
	+ "dict dir distinct do down drop e each else elseif encoded end end eval "
	+ "event exit extract fill find first flip font fonts format frame from "
	+ "fullscreen gamepad get gindex go gridlines gridsize group headers held "
	+ "here if image in index index insert into keys keystore kiosk last len "
	+ "like line list local locked make max merge min min modules ms name "
	+ "newdeck nil now on ops or orderby outline panic parse paste patterns "
	+ "pi platform play playing pointer poly pos prev print prod purge random "
	+ "range raze read readcsv readxml remove render replace rev rtext save "
	+ "script scrollbar seed select shortcut show size sleep slice sound "
	+ "sounds span split start step string struct style sum sys table take "
	+ "text textsize transition trim typeof unless up update value version "
	+ "where while window with workspace write writecsv writexml xor z"
)

const LAYOUT_NAMES := ["qwerty", "dvorak", "colemak"]

## Layout strings: rows separated by \n; '.' = spacer.
const LAYOUTS := {
	"qwerty": "qwertyuiop\nasdfghjkl\nzxcvbnm",
	"dvorak": "...pyfgcrl\naoeuidhtns\n.qjkxbmwvz",
	"colemak": "qwfpgjluy\narstdhneio\nzxcvbkm",
}


static func word_list(name: String) -> PackedStringArray:
	var raw := LETTERS
	match name:
		"sight words":
			raw = SIGHT_WORDS
		"english top 100":
			raw = ENGLISH_TOP_100
		"decker":
			raw = DECKER
		_:
			raw = LETTERS
	var out: PackedStringArray = []
	for w in raw.split(" ", false):
		var t := w.strip_edges().to_lower()
		if t != "":
			out.append(t)
	return out


static func layout_rows(name: String) -> PackedStringArray:
	var s: String = LAYOUTS.get(name, LAYOUTS["qwerty"])
	return PackedStringArray(s.split("\n"))
