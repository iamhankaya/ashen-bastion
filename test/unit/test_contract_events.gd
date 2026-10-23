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
	# v1.1 (sona eklenir)
	"pickup_spawn",
	"pickup_collect",
	"pickup_expire",
	"buff_start",
	"buff_end",
	"bomb_plant",
	"bomb_explode",
	"score",
	"streak_reset",
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


func test_v11_event_types_are_unique_and_appended_after_the_v1_ones() -> void:
	var seen := {}
	for t in SimEvents.ALL:
		assert_false(seen.has(t), "yinelenen tür %s" % t)
		seen[t] = true
	assert_eq(SimEvents.ALL.size(), 28)
	assert_eq(SimEvents.ALL[18], SimEvents.RUN_END, "v1 türleri aynı sırada kalır")
	assert_eq(SimEvents.ALL[19], SimEvents.PICKUP_SPAWN)
	assert_eq(SimEvents.ALL[27], SimEvents.STREAK_RESET)


func test_v11_event_records_keep_step_and_type_and_accept_their_fields() -> void:
	var r := SimEvents.make(
		5, SimEvents.BUFF_START, {"kind": &"damage", "duration": 12.0, "refreshed": false}
	)
	assert_eq(r["type"], SimEvents.BUFF_START)
	assert_eq(r["kind"], &"damage")
	var r2 := SimEvents.make(
		5, SimEvents.SCORE, {"gain": 10, "total": 10, "mult": 1, "source": &"kill"}
	)
	assert_eq(r2["gain"], 10)
	assert_eq(r2.size(), 6)
