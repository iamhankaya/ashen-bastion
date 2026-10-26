extends GutTest
## v2.0.3 C: aşamalı başarım aritmetiği (AchievementStep) ve gerçek veri tablosu (19 aile, 53 kademe, 22 eski kimlik).

const LEGACY := "res://test/fixtures/ach_v20/achievements.json"


func _def(steps: Array, target: int = 0) -> AchievementDef:
	var d := AchievementDef.new()
	for s in steps:
		d.steps.append(int(s))
	d.target = target
	return d


func test_reached_counts_thresholds_at_or_below_value() -> void:
	var d := _def([1, 250, 2500, 10000])
	assert_eq(AchievementStep.reached(d, 0), 0)
	assert_eq(AchievementStep.reached(d, 1), 1)
	assert_eq(AchievementStep.reached(d, 249), 1)
	assert_eq(AchievementStep.reached(d, 250), 2)
	assert_eq(AchievementStep.reached(d, 10000), 4)
	assert_eq(AchievementStep.reached(d, 999999999), 4)


func test_legacy_shaped_def_is_a_single_step() -> void:
	var d := _def([], 100)
	assert_eq(AchievementStep.total(d), 1)
	assert_eq(AchievementStep.reached(d, 99), 0)
	assert_eq(AchievementStep.reached(d, 100), 1)


func test_def_without_any_threshold_has_no_steps() -> void:
	var d := _def([], 0)
	assert_eq(AchievementStep.total(d), 0)
	assert_eq(AchievementStep.reached(d, 5), 0)


func test_next_target_is_zero_when_complete() -> void:
	var d := _def([5, 8])
	assert_eq(AchievementStep.next_target(d, 0), 5)
	assert_eq(AchievementStep.next_target(d, 1), 8)
	assert_eq(AchievementStep.next_target(d, 2), 0)
	assert_eq(AchievementStep.next_target(d, 7), 0, "taşan sayı tamam sayılır")


func test_roman_numerals_cover_max_steps() -> void:
	assert_eq(AchievementStep.roman(1), "I")
	assert_eq(AchievementStep.roman(4), "IV")
	assert_eq(AchievementStep.roman(5), "V")
	assert_eq(AchievementStep.roman(0), "")
	assert_eq(AchievementStep.roman(6), "")


func test_real_data_has_19_families_and_53_steps_and_validates() -> void:
	var g := GameData.load_dir("res://data")
	assert_eq(g.achievements.size(), 19)
	var n := 0
	for d in g.achievements:
		assert_false(d.steps.is_empty(), "%s aile kaydı" % d.id)
		n += AchievementStep.total(d)
	assert_eq(n, 53)
	assert_eq(g.validate({}, true), PackedStringArray())


func test_real_data_groups_cover_all_five_and_names_are_fixed_upper() -> void:
	var seen := {}
	for d in GameData.load_dir("res://data").achievements:
		seen[String(d.group)] = true
		assert_eq(d.display_name, d.display_name.to_upper(), "%s adı sabit büyük harf" % d.id)
	for g in AchievementDef.GROUPS:
		assert_true(seen.has(g), "%s grubunda aile var" % g)


func test_every_legacy_id_maps_to_one_family_step_with_the_old_target() -> void:
	var old := {}
	for r in JSON.parse_string(FileAccess.get_file_as_string(LEGACY)):
		old[String(r["id"])] = r
	assert_eq(old.size(), 22)
	var mapped := {}
	for d in GameData.load_dir("res://data").achievements:
		for k in d.legacy:
			assert_false(mapped.has(k), "%s tek ailede" % k)
			mapped[k] = true
			assert_eq(
				d.steps[int(d.legacy[k]) - 1],
				int(old[k]["target"]),
				"%s eşiği eski hedefle birebir" % k
			)
	assert_eq(mapped.size(), 22, "22 eski kimliğin hepsi eşlenir")
	for k in old:
		assert_true(mapped.has(k), k)
