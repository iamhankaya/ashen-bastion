extends GutTest
## Kabul: plan tabloları (test/helpers/expected_tables.gd, SABİT) <-> data/** JSON eşleşmesi.
## U1 kayıtları (3 aktif, 8 pasif, 3 düşman, karakter, waves satır 1-3) slice 1'de; kalanlar slice 2'de.

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _skill(id: StringName) -> SkillDef:
	return _data.get_skill(id)


func _slice2() -> bool:
	if Slice.current() < 2:
		pending("içerik slice 2 (Uygulama-2) kapsamında")
		return false
	return true


func _check_active(id: StringName) -> void:
	var s := _skill(id)
	assert_not_null(s, "%s kaydı yok" % id)
	if s == null:
		return
	assert_eq(String(s.kind), "active", "%s kind" % id)
	assert_eq(s.max_level, 5, "%s max_level" % id)
	assert_eq(s.levels.size(), 5, "%s levels" % id)
	var table: Dictionary = ExpectedTables.ACTIVE_LEVELS[id]
	for key in table.keys():
		for i in 5:
			var lvl: Dictionary = s.levels[i]
			assert_true(lvl.has(key), "%s sv%d '%s' yok" % [id, i + 1, key])
			if lvl.has(key):
				assert_almost_eq(
					float(lvl[key]), float(table[key][i]), 0.0001, "%s sv%d %s" % [id, i + 1, key]
				)


func _check_passive(id: StringName) -> void:
	var s := _skill(id)
	assert_not_null(s, "%s kaydı yok" % id)
	if s == null:
		return
	assert_eq(String(s.kind), "passive", "%s kind" % id)
	assert_eq(s.max_level, 5, "%s max_level" % id)
	assert_eq(s.levels.size(), 5, "%s levels" % id)
	var steps: Dictionary = ExpectedTables.PASSIVE_STEPS[id]
	for i in 5:
		var lvl: Dictionary = s.levels[i]
		var got := PackedStringArray()
		for k in lvl.keys():
			got.append(str(k))
		got.sort()
		var want := PackedStringArray()
		for k in steps.keys():
			want.append(str(k))
		want.sort()
		assert_eq(got, want, "%s sv%d anahtar kümesi (menzil pasifi vb. yok)" % [id, i + 1])
		for k in steps.keys():
			if lvl.has(k):
				assert_almost_eq(
					float(lvl[k]),
					float(steps[k]) * float(i + 1),
					0.0001,
					"%s sv%d %s (toplam değer)" % [id, i + 1, k]
				)


func _check_enemy(id: StringName) -> void:
	var e := _data.get_enemy(id)
	assert_not_null(e, "%s kaydı yok" % id)
	if e == null:
		return
	var t: Dictionary = ExpectedTables.ENEMIES[id]
	assert_almost_eq(e.hp, float(t["hp"]), 0.0001, "%s hp" % id)
	assert_almost_eq(e.speed, float(t["speed"]), 0.0001, "%s speed" % id)
	assert_almost_eq(e.dmg, float(t["dmg"]), 0.0001, "%s temas hasarı" % id)
	assert_almost_eq(e.radius, float(t["radius"]), 0.0001, "%s radius" % id)
	assert_almost_eq(e.armor, float(t["armor"]), 0.0001, "%s armor" % id)
	assert_eq(e.xp, int(t["xp"]), "%s xp" % id)
	assert_eq(String(e.ai), str(t["ai"]), "%s ai" % id)


func _row(kind: String, type_id: String, from: float = -1.0) -> Dictionary:
	for r in _data.waves.get("rows", []):
		if (
			r.get("kind", "") == kind
			and r.get("type", "") == type_id
			and (from < 0.0 or is_equal_approx(float(r.get("from", -2.0)), from))
		):
			return r
	return {}


func test_real_data_validates_cleanly() -> void:
	var errs := _data.validate({}, Slice.is_content_complete())
	assert_eq(errs, PackedStringArray(), "data/** doğrulaması hatasız olmalı")


func test_gunslinger_character_table() -> void:
	var c := _data.get_character(&"gunslinger")
	assert_not_null(c, "gunslinger yok")
	if c == null:
		return
	var t := ExpectedTables.CHARACTER
	assert_almost_eq(c.max_hp, float(t["max_hp"]), 0.0001)
	assert_almost_eq(c.move_speed, float(t["move_speed"]), 0.0001)
	assert_eq(c.mag_cap, int(t["mag_cap"]))
	assert_almost_eq(c.reload_time, float(t["reload_time"]), 0.0001)
	assert_almost_eq(c.pickup_radius, float(t["pickup_radius"]), 0.0001)
	assert_almost_eq(c.collision_radius, float(t["collision_radius"]), 0.0001)
	assert_eq(String(c.starting_skill), str(t["starting_skill"]))
	assert_almost_eq(c.attack_range, float(t["range"]), 0.0001)


func test_u1_actives_match_table() -> void:
	for id in ExpectedTables.U1_ACTIVES:
		_check_active(id)


func test_u1_passives_match_table_and_are_cumulative() -> void:
	for id in ExpectedTables.PASSIVES:
		_check_passive(id)


func test_u1_enemies_match_table() -> void:
	for id in ExpectedTables.U1_ENEMIES:
		_check_enemy(id)


func test_waves_rows_1_to_3_match_table() -> void:
	var piyade := _row("rate", "curumus_piyade")
	assert_false(piyade.is_empty(), "piyade rate satırı yok")
	if not piyade.is_empty():
		assert_eq(float(piyade["from"]), 0.0)
		assert_eq(float(piyade["to"]), 1200.0)
		assert_eq(piyade["rate"], [0.8, 4.2])
	var karga := _row("group", "les_kargasi")
	assert_false(karga.is_empty(), "karga group satırı yok")
	if not karga.is_empty():
		assert_eq(float(karga["from"]), 90.0)
		assert_eq(float(karga["to"]), 1200.0)
		assert_eq(karga["group"], [6.0, 14.0])
		assert_eq(karga["every"], [26.0, 12.0])
	var sov := _row("rate", "sovalye_hayaleti")
	assert_false(sov.is_empty(), "şövalye hayaleti rate satırı yok")
	if not sov.is_empty():
		assert_eq(float(sov["from"]), 240.0)
		assert_eq(float(sov["to"]), 1200.0)
		assert_eq(sov["rate"], [0.05, 0.8])


func test_after_lord_and_end_time() -> void:
	assert_almost_eq(float(_data.waves.get("end_time", 1200)), ExpectedTables.END_TIME, 0.0001)
	var al: Dictionary = _data.waves.get("after_lord", {})
	assert_almost_eq(float(al.get("piyade_rate_mult", -1)), 0.5, 0.0001)
	assert_eq(al.get("karga_stop", null), true)


func test_at_least_two_active_skills_are_rhythm_tagged() -> void:
	var n := 0
	for s in _data.skills_of_kind(&"active"):
		if "rhythm" in s.tags:
			n += 1
	assert_gte(n, 2, "şarjör ritmiyle etkileşen (rhythm) aktif sayısı >= 2 olmalı")


func test_slice2_remaining_actives_match_table() -> void:
	if not _slice2():
		return
	for id in ExpectedTables.U2_ACTIVES:
		_check_active(id)


func test_slice2_evolutions_match_table() -> void:
	if not _slice2():
		return
	for id in ExpectedTables.EVOLUTIONS:
		var s := _skill(id)
		assert_not_null(s, "%s yok" % id)
		if s == null:
			continue
		assert_eq(String(s.kind), "evolution")
		assert_eq(s.max_level, 1)
		var want: Array = ExpectedTables.EVOLUTION_REQUIRES[id]
		assert_eq(str(s.requires.get("active", "")), String(want[0]), "%s requires.active" % id)
		assert_eq(int(s.requires.get("active_level", 0)), 5, "%s active_level" % id)
		assert_eq(str(s.requires.get("passive", "")), String(want[1]), "%s requires.passive" % id)
		assert_gte(int(s.requires.get("passive_min_level", 0)), 1, "%s passive_min_level" % id)


func test_slice2_record_counts_are_8_8_4_and_7_enemies() -> void:
	if not _slice2():
		return
	assert_eq(_data.skills_of_kind(&"active").size(), 8, "8 aktif")
	assert_eq(_data.skills_of_kind(&"passive").size(), 8, "8 pasif")
	assert_eq(_data.skills_of_kind(&"evolution").size(), 4, "4 evrim")
	assert_eq(_data.enemy_ids.size(), 7, "7 düşman")


func test_slice2_boss_enemies_match_table() -> void:
	if not _slice2():
		return
	for id in ExpectedTables.U2_ENEMIES:
		_check_enemy(id)
	var karga := _data.get_enemy(&"elit_karga")
	if karga != null:
		assert_almost_eq(
			float(karga.charge.get("every", -1)), 4.0, 0.0001, "elit_karga şarj aralığı"
		)
		assert_almost_eq(float(karga.charge.get("duration", -1)), 0.8, 0.0001, "şarj süresi")
		assert_almost_eq(float(karga.charge.get("speed", -1)), 380.0, 0.0001, "şarj hızı")
	var lord := _data.get_enemy(&"kale_lordu")
	if lord != null:
		assert_eq(str(lord.summon.get("type", "")), "curumus_piyade")
		assert_almost_eq(float(lord.summon.get("every", -1)), 8.0, 0.0001)
		assert_eq(int(lord.summon.get("count", -1)), 12)
		assert_almost_eq(float(lord.summon.get("enrage_hp_frac", -1)), 0.5, 0.0001)
		assert_almost_eq(float(lord.summon.get("enrage_speed_mult", -1)), 1.4, 0.0001)
		assert_almost_eq(float(lord.summon.get("enrage_every", -1)), 5.0, 0.0001)


func test_slice2_waves_rows_4_to_6_match_table() -> void:
	if not _slice2():
		return
	var bursts: Array[float] = []
	for r in _data.waves.get("rows", []):
		if r.get("kind", "") == "burst" and r.get("type", "") == "curumus_piyade":
			bursts.append(float(r["at"]))
			assert_eq(
				int(r["count"]),
				int(ExpectedTables.BURST_COUNTS[int(r["at"])]),
				"halka dalgası adedi"
			)
			assert_eq(r["ring"], true)
	bursts.sort()
	assert_eq(bursts, ExpectedTables.BURST_TIMES, "halka dalgaları 480/720/960. sn")
	for boss in ExpectedTables.BOSSES.keys():
		var row := _row("boss", String(boss))
		assert_false(row.is_empty(), "%s boss satırı yok" % boss)
		if not row.is_empty():
			assert_almost_eq(
				float(row["at"]), float(ExpectedTables.BOSSES[boss]), 0.0001, "%s at" % boss
			)
			assert_almost_eq(
				float(row.get("warn", ExpectedTables.BOSS_WARN)), ExpectedTables.BOSS_WARN, 0.0001
			)
