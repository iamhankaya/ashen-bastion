extends GutTest
## Kabul (v2.1 M, S): kazanma/Lord'a ulaşma ölçütünün (spec senaryo 2-8) ölçüm altyapısı sözleşmesi. Oranlar istatistiktir
## (400 tohum, bootstrap %95 GA): balance.yml A400/B400 koşularının işidir; birim kapıya KONMAZ (gürültü, süre). Burada
## (a) ölçüm aracının plandaki yüzeyi (politika, çıktı alanları, süre sınırları, matris) ve (b) deterministik bir sim vekili
## sınanır: aynı tohum ve aynı oyun, Kolay < Normal < Zor hasar yer. V21Slice "M" (a) ve "S" (b) açılana dek pending.

const MID_RUN := "res://tools/balance/mid_run.gd"
const BALANCE_YML := "res://.github/workflows/balance.yml"
const FIELDS := [
	"mode",
	"diff",
	"result",
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
	"kills5",
	"hp_early",
]


func test_m1_the_measurement_tool_reports_every_planned_field() -> void:
	if V21Slice.require(self, "M"):
		return
	var text := FileAccess.get_file_as_string(MID_RUN)
	assert_ne(text, "", "mid_run.gd okundu")
	for f in FIELDS:
		assert_true(text.contains('"%s"' % f), "çıktı alanı: %s" % f)


func test_m2_the_tool_can_play_the_lord_fight_and_the_endless_horizon() -> void:
	if V21Slice.require(self, "M"):
		return
	var text := FileAccess.get_file_as_string(MID_RUN)
	assert_true(text.contains("strong_lord"), "strong_lord politikası")
	var m := RegEx.create_from_string("const MAX_STEPS\\s*:?=\\s*(\\d+)")
	var hit := m.search(text)
	assert_not_null(hit, "MAX_STEPS sabiti")
	if hit != null:
		assert_gte(int(hit.get_string(1)), 144000, "Lord dövüşü için ≥ 2400 sn (144000 adım)")


func test_m3_the_balance_workflow_covers_the_mode_difficulty_matrix() -> void:
	if V21Slice.require(self, "M"):
		return
	var text := FileAccess.get_file_as_string(BALANCE_YML)
	assert_ne(text, "", "balance.yml var")
	for token in ["quick", "endless", "easy", "hard", "strong_lord", "kite"]:
		assert_true(text.contains(token), "matriste: %s" % token)


func _damage_taken(diff: StringName) -> float:
	var total := 0.0
	for seed_value in [3, 8, 15]:
		var s := (
			GameSim
			. new(
				seed_value,
				&"gunslinger",
				{
					"data": GameData.load_default(),
					"run_profile": V21Kit.profile(&"normal", diff),
					"start_time": 600.0,
					"log_events": false,
				}
			)
		)
		s.max_hp = 1.0e9
		s.hp = 1.0e9
		var rng := Bots.make_rng(seed_value)
		Bots.play(s, &"kite", 60 * 40, rng)
		total += 1.0e9 - s.hp
	return total


func test_s31_easier_difficulties_take_less_damage_under_identical_play() -> void:
	if V21Slice.require(self, "S"):
		return
	var easy := _damage_taken(&"easy")
	var normal := _damage_taken(&"normal")
	var hard := _damage_taken(&"hard")
	assert_gt(hard, 0.0, "Zor'da hasar alındı (kurulum)")
	assert_lt(easy, normal, "Kolay < Normal (%.0f < %.0f)" % [easy, normal])
	assert_lt(normal, hard, "Normal < Zor (%.0f < %.0f)" % [normal, hard])
