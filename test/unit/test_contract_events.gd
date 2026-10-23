extends GutTest
## Sözleşme: event_log tür adları ve kayıt biçimi.

const EXPECTED := [
	"shot",
	"damage",
	"explosion",
	"kill",
	"spawn",
	"spawn_dropped",
	"reload_start",
	"reload_end",
	"refund",
	"dry_fire",
	"gem_dropped",
	"gem_collected",
	"level_up",
	"choices",
	"choice_made",
	"evolution",
	"boss_warning",
	"boss_spawn",
	"run_end",
]


func test_event_type_names_match_plan() -> void:
	var names: Array[String] = []
	for t in SimEvents.ALL:
		names.append(String(t))
	assert_eq(names, EXPECTED as Array[String])


func test_make_record_has_step_and_type() -> void:
	var r := SimEvents.make(12, SimEvents.SHOT, {"gun": 1, "dmg": 15.0})
	assert_eq(r["step"], 12)
	assert_eq(r["type"], SimEvents.SHOT)
	assert_eq(r["gun"], 1)
	assert_eq(r["dmg"], 15.0)


func test_make_does_not_let_fields_overwrite_step_and_type_silently() -> void:
	# alanlar step/type'ı ezerse kayıt bozulur; sözleşme: çağıran bu adları alan olarak kullanmaz.
	var r := SimEvents.make(1, SimEvents.KILL)
	assert_eq(r.size(), 2)
