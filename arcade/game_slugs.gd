extends RefCounted
## Public short-URL slugs for GameRegistry ids (static helpers; preload, no autoload).
##
## Pages serves one thin stub per playable title at /arcade/<slug>/ (tools/gen_game_pages.py).
## Most titles use slug == id; ALIASES overrides a few. This file is the single source of truth:
## gen_game_pages.py parses ALIASES out of it, so edit the table here only.

const SITE := "https://tangentstorm.github.io/arcade"

## Short URL slug -> GameRegistry id (slug == id for every title not listed).
const ALIASES := {
	"mineswpr": "mineswpr_b4",   # b4 TermGrid host is the default Mineswpr
	"mineswpr.old": "mineswpr",  # original GDScript port
}


## Public slug for a registry id ("mineswpr_b4" -> "mineswpr", "mineswpr" -> "mineswpr.old").
static func id_to_slug(id: String) -> String:
	for slug in ALIASES:
		if ALIASES[slug] == id:
			return slug
	return id


## Registry id for a public slug (inverse of id_to_slug; unknown slugs map to themselves).
static func slug_to_id(slug: String) -> String:
	return ALIASES.get(slug, slug)


## Absolute shareable URL: SITE/<slug>/ plus ?e=enhanced for the Enhanced edition.
static func share_url(id: String, edition: String) -> String:
	var url := "%s/%s/" % [SITE, id_to_slug(id)]
	return url + "?e=enhanced" if edition == "enhanced" else url
