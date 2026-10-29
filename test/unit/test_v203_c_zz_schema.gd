extends GutTest
## v2.0.3 sözleşme (C ad alanı): aşamalı başarım şeması. Dosya adındaki `zz`, ortak kayıt dosyalarında (asgari-sayı tablosu,
## shard_weights) C fazının satırlarını A/B/D'nin satırlarından ayrı tutan ayırıcıdır (N4); C kendi testlerini
## `test_v203_c_<ad>.gd` diye ekler, bu dosyayı yeniden adlandırmaz.

const FIX := "res://test/fixtures"
const OLD_IDS := [
	"ilk_kan",
	"bes_dakika",
	"seviye_10",
	"yerlesik",
	"tambur_ustasi",
	"alti_silah",
	"kirim",
	"on_dakika",
	"seri_ustasi",
	"piyade_avcisi",
	"eklenti_avcisi",
	"dokunulmaz",
	"seviye_20",
	"kalabalik_kesici",
	"cifte_yol",
	"on_bes_dakika",
	"uc_elit",
	"ilk_evrim",
	"skor_100k",
	"sinirsiz_kirim",
	"kale_lordu_devrildi",
	"bomba_ustasi",
]


func _codes(errs: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	for e in errs:
		out.append(e.get_slice("]", 0).trim_prefix("["))
	return out


func _family(over: Dictionary = {}) -> Dictionary:
	var d := {
		"id": "reaper",
		"name": "Reaper",
		"desc": "Toplam düşman öldür",
		"stat": "total_kills",
		"scope": "total",
		"group": "THE CULLING",
		"steps": [100, 1000, 5000, 25000],
		"legacy": {"ilk_kan": 1}
	}
	var out := d.duplicate(true)
	for k in over:
		if over[k] == null:
			out.erase(k)
		else:
			out[k] = over[k]
	return out


func _errs(records: Array, complete: bool = false) -> PackedStringArray:
	var dir := KitDev.data_dir_with({"achievements.json": records})
	return GameData.load_dir(dir).validate({}, complete)


func test_stats_gains_total_boss_kills_at_the_end() -> void:
	assert_eq(AchievementDef.STATS.size(), AchievementMetricRegistry.default().stats().size())
	assert_eq(AchievementDef.STATS[20], "total_boss_kills")
	assert_eq(AchievementDef.scope_of(&"total_boss_kills"), &"total")


func test_from_dict_reads_steps_group_legacy() -> void:
	var def := AchievementDef.from_dict(_family())
	assert_eq(def.steps, [100, 1000, 5000, 25000])
	assert_eq(def.group, &"THE CULLING")
	assert_eq(def.legacy, {"ilk_kan": 1})
	assert_eq(def.thresholds(), [100, 1000, 5000, 25000])


func test_legacy_record_without_steps_is_one_step_of_target() -> void:
	var def := AchievementDef.from_dict(
		{"id": "ilk_kan", "stat": "total_kills", "target": 7, "scope": "total", "tier": "kolay"}
	)
	assert_eq(def.steps, [] as Array[int])
	assert_eq(def.thresholds(), [7])


func test_from_dict_ignores_malformed_steps() -> void:
	var def := AchievementDef.from_dict({"id": "x", "steps": "100", "legacy": [1], "group": 5})
	assert_eq(def.steps, [] as Array[int])
	assert_eq(def.legacy, {})
	assert_eq(def.group, &"")


func test_groups_are_the_five_approved_names() -> void:
	assert_eq(
		AchievementDef.GROUPS,
		PackedStringArray(["THE WATCH", "THE CULLING", "THE CROWNED", "THE ARMORY", "THE ROAD"])
	)


func test_legacy_ids_are_the_22_existing_achievements() -> void:
	assert_eq(AchievementDef.LEGACY_IDS.size(), 22)
	for id in OLD_IDS:
		assert_true(AchievementDef.LEGACY_IDS.has(id), id)


func test_valid_family_record_passes() -> void:
	assert_eq(_errs([_family()]), PackedStringArray())


func test_shipped_data_still_validates_with_new_schema() -> void:
	assert_eq(GameData.load_dir("res://data").validate({}, true), PackedStringArray())


func test_steps_must_be_strictly_increasing_positive_ints_up_to_five() -> void:
	var bad := [[], [0, 5], [5, 5], [10, 5], [1, 2, 3, 4, 5, 6], ["a"], [1.5], [1000000000]]
	for s in bad:
		assert_true(_codes(_errs([_family({"steps": s})])).has("steps_invalid"), str(s))
	assert_true(_codes(_errs([_family({"steps": "100"})])).has("steps_invalid"), "metin")


func test_steps_excludes_target_and_tier() -> void:
	assert_true(_codes(_errs([_family({"target": 5})])).has("steps_invalid"))
	assert_true(_codes(_errs([_family({"tier": "kolay"})])).has("steps_invalid"))


func test_group_and_legacy_need_steps() -> void:
	var legacy_rec := {
		"id": "ilk_kan",
		"name": "x",
		"desc": "x",
		"stat": "total_kills",
		"target": 1,
		"scope": "total",
		"tier": "kolay",
	}
	var with_group := legacy_rec.duplicate()
	with_group["group"] = "THE ROAD"
	assert_true(_codes(_errs([with_group])).has("steps_invalid"))
	var with_legacy := legacy_rec.duplicate()
	with_legacy["legacy"] = {"ilk_kan": 1}
	assert_true(_codes(_errs([with_legacy])).has("steps_invalid"))


func test_family_requires_known_group() -> void:
	assert_true(_codes(_errs([_family({"group": null})])).has("missing_field"))
	assert_true(_codes(_errs([_family({"group": "SURVIVAL"})])).has("bad_type"))


func test_legacy_must_name_an_old_id_and_a_valid_step() -> void:
	assert_true(_codes(_errs([_family({"legacy": {"yok_boyle": 1}})])).has("legacy_unknown"))
	assert_true(_codes(_errs([_family({"legacy": {"ilk_kan": 5}})])).has("legacy_unknown"))
	assert_true(_codes(_errs([_family({"legacy": {"ilk_kan": 0}})])).has("legacy_unknown"))
	assert_true(_codes(_errs([_family({"legacy": {"ilk_kan": "1"}})])).has("legacy_unknown"))
	assert_true(_codes(_errs([_family({"legacy": [1]})])).has("legacy_unknown"))


func test_legacy_id_cannot_map_twice() -> void:
	var b := _family({"id": "other", "name": "Other"})
	assert_true(_codes(_errs([_family(), b])).has("legacy_unknown"))


func test_family_count_bounds_are_12_to_30() -> void:
	for n in [11, 31]:
		var recs: Array = []
		for i in n:
			recs.append(_family({"id": "fam_%d" % i, "legacy": null}))
		assert_true(_codes(_errs(recs, true)).has("ach_count"), "%d" % n)
	for n in [12, 30]:
		var recs: Array = []
		for i in n:
			recs.append(_family({"id": "fam_%d" % i, "legacy": null, "steps": [1 + i]}))
		assert_false(_codes(_errs(recs, true)).has("ach_count"), "%d" % n)


func test_total_steps_are_capped_at_80() -> void:
	var recs: Array = []
	for i in 17:  # 17 x 5 = 85 kademe
		recs.append(_family({"id": "fam_%d" % i, "legacy": null, "steps": [1, 2, 3, 4, 5]}))
	assert_true(_codes(_errs(recs, true)).has("steps_invalid"))


func test_tier_missing_is_not_demanded_of_families() -> void:
	var recs: Array = []
	for i in 12:
		recs.append(_family({"id": "fam_%d" % i, "legacy": null}))
	assert_false(_codes(_errs(recs, true)).has("tier_missing"))
