extends GutTest
## v2.1 U1a (M dilimi): ölçüm aracı mid_run.gd — Lord bandı, Lord yokken strong ile birebir, Lord izleyici, çıktı alanları,
## user:// temizliği. Python tarafı: tools/ci/tests/test_v21_m_measure.py. Koşular kısadır (gate bütçesi: dilim başına <= +15 sn).

const MID := "res://tools/balance/mid_run.gd"
const FIELDS: PackedStringArray = [
	"mode",
	"diff",
	"won",
	"milestone_won",
	"end_reason",
	"reached_lord",
	"lord_spawn_t",
	"lord_alive_secs",
	"lord_end",
	"lord_hp_frac_end",
	"lord_hit_frac",
	"lords_killed",
	"post_lord_secs",
	"level_at_1200",
	"level_at_end",
	"kills",
	"kills5",
	"hp_early",
	"time",
	"level",
]

var mid: GDScript


func before_each() -> void:
	mid = load(MID)


func test_m1_band_dir_approaches_when_far_flees_when_near_and_circles_inside_the_band() -> void:
	var lord := Vector2(1000, 0)
	assert_eq(mid.band_dir(Vector2(0, 0), lord), Vector2.RIGHT, "400 px'ten uzak: yaklaş")
	assert_eq(mid.band_dir(Vector2(900, 0), lord), Vector2.LEFT, "250 px'ten yakın: kaç")
	var tangent: Vector2 = mid.band_dir(Vector2(680, 0), lord)
	assert_almost_eq(tangent.length(), 1.0, 0.001)
	assert_almost_eq(tangent.dot(Vector2.RIGHT), 0.0, 0.001, "bant içi: Lord yönüne dik (teğet)")


func test_m2_band_dir_keeps_a_walking_bot_inside_the_band_once_it_arrives() -> void:
	var lord := Vector2.ZERO
	var p := Vector2(900, 0)
	var step_len := 200.0 / 60.0
	var inside_since := -1
	for i in 60 * 20:
		p += mid.band_dir(p, lord) * step_len
		var d := p.distance_to(lord)
		if inside_since < 0 and d <= mid.LORD_BAND_MAX:
			inside_since = i
		if inside_since >= 0:
			assert_between(d, mid.LORD_BAND_MIN - step_len, mid.LORD_BAND_MAX + step_len)
	assert_gt(inside_since, -1, "bant 20 sn içinde yakalanmalı")


func test_m3_strong_lord_equals_strong_when_no_lord_exists() -> void:
	var a: Dictionary = mid.run_one(41, "strong", &"gunslinger", "", "normal", 18000)
	var b: Dictionary = mid.run_one(41, "strong_lord", &"gunslinger", "", "normal", 18000)
	for k in ["time", "level", "kills", "kills5", "hp_early", "level5", "evolutions"]:
		assert_eq(b[k], a[k], "Lord yokken %s aynı olmalı (ilk 300 sn)" % k)
	assert_false(b["reached_lord"])


func test_m4_output_has_all_v21_fields_and_legacy_defaults() -> void:
	var r: Dictionary = mid.run_one(7, "kite", &"gunslinger", "", "normal", 120)
	for f in FIELDS:
		assert_true(r.has(f), "alan eksik: %s" % f)
	assert_eq([r["mode"], r["diff"]], ["normal", "hard"], "mod verilmezse legacy Zor")
	assert_eq(r["end_reason"], "timeout")
	assert_eq(r["lord_end"], "none")
	assert_eq(r["lord_hp_frac_end"], -1.0)
	assert_eq(r["level_at_1200"], -1)
	assert_eq(r["lords_killed"], 0)


func test_m5_mode_and_diff_arguments_select_the_profile_and_unknown_names_return_an_error() -> void:
	var q: Dictionary = mid.run_one(7, "kite", &"gunslinger", "quick", "easy", 120)
	assert_eq([q["mode"], q["diff"]], ["quick", "easy"])
	var bad: Dictionary = mid.run_one(7, "kite", &"gunslinger", "nope", "easy", 120)
	assert_true(bad.has("error"))


func test_m6_lord_tracker_records_spawn_hits_and_death_of_the_first_lord() -> void:
	var sim := SimKit.make(301, {"data_kind": "real", "start_time": 1186.0})
	SimKit.godmode(sim)
	var st: Dictionary = mid.make_lord_tracker(sim)
	var guard := 0
	while st["n"] == 0 and guard < 60 * 10:
		guard += 1
		sim.step(Vector2.ZERO)
		mid._track_lord(sim, st)
	assert_eq(st["n"], 1, "Lord 1190. sn'de doğar")
	assert_gte(st["spawn_t"], 1190.0)
	assert_eq(mid.lord_id(sim), st["id"])
	var i := EnemyPool.index_of(st["id"])
	sim.enemies.hp[i] -= 10.0
	sim.step(Vector2.ZERO)
	mid._track_lord(sim, st)
	assert_eq(st["hit_steps"], 1, "can kaybeden adım vuruş sayılır")
	assert_lt(st["hp_frac"], 1.0)
	sim.enemies.kill(st["id"])
	mid._track_lord(sim, st)
	assert_eq(st["killed"], 1)
	assert_gte(st["death_t"], st["spawn_t"])
	assert_eq(st["id"], -1)


func test_m7_run_one_writes_nothing_under_user_dir() -> void:
	var before := _user_listing()
	mid.run_one(3, "strong_lord", &"gunslinger", "", "normal", 120)
	assert_eq(_user_listing(), before, "ölçüm koşusu user:// altına yazmaz")


func _user_listing() -> Array:
	var out: Array = []
	for d in DirAccess.get_directories_at("user://"):
		out.append("d:" + d)
	for f in DirAccess.get_files_at("user://"):
		out.append("f:" + f)
	out.sort()
	return out
