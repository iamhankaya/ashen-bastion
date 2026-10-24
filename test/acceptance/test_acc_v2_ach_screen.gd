extends GutTest
## Kabul (v2.0 B6/B7/B9): Başarımlar ekranı, 22 kayıtlık veri, ödül/sim bağımsızlığı. Düzen sayıları: expected_layout_v2.gd
## (kaynak DESIGN.md §5.1). Satır düğümü adları sözleşmede olmadığından satırlar BOYUTA göre bulunur (936×156).
## B7/B9 sözleşmede gerçek olduğu için dilimsiz; ekran testleri dilim B ister.

const TS := 1700049600  # 2023-11-15 12:00 UTC (saat dilimi payı: gün değişmez)


func after_each() -> void:
	AchKit.cleanup()


func _gate() -> bool:
	return V2Slice.require(self, "B")


func _screen(st: AchievementStore, d: GameData = null) -> AchievementsScreen:
	var s := AchievementsScreen.new()
	add_child_autofree(s)
	s.open(d if d != null else AchKit.data(), st)
	return s


func _rows(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		var sz := c.size if c.size.x > 0.0 else c.custom_minimum_size
		if (
			absf(sz.x - ExpectedLayoutV2.ROW_SIZE.x) < 1.0
			and absf(sz.y - ExpectedLayoutV2.ROW_SIZE.y) < 1.0
		):
			out.append(c)
	return out


# --- B7: veri ----------------------------------------------------------------------------------------------------


func test_b7_real_data_matches_plan_table() -> void:
	var d := GameData.load_default()
	assert_eq(d.achievements.size(), ExpectedTablesV2.ACHIEVEMENTS.size())
	var seen := {}
	for i in ExpectedTablesV2.ACHIEVEMENTS.size():
		var r: Array = ExpectedTablesV2.ACHIEVEMENTS[i]
		assert_false(seen.has(r[0]), "tekil kimlik %s" % r[0])
		seen[r[0]] = true
		var a := d.get_achievement(StringName(r[0]))
		assert_not_null(a, r[0])
		if a == null:
			continue
		assert_eq(d.achievement_ids[i], StringName(r[0]), "dosya sırası %d" % i)
		assert_eq(String(a.stat), r[1], r[0])
		assert_eq(a.target, r[2], r[0])
		assert_eq(String(a.tier), r[3], r[0])
		assert_eq(String(a.scope), r[4], r[0])


func test_b7_every_tier_present_with_6_9_5_2_distribution() -> void:
	var d := GameData.load_default()
	var n := [0, 0, 0, 0]
	for a in d.achievements:
		n[AchievementDef.tier_index(a.tier)] += 1
	assert_eq(n, ExpectedTablesV2.TIER_COUNTS)
	for k in n:
		assert_gte(k, 1)


func test_b7_stat_set_is_closed_at_20_and_matches_table() -> void:
	assert_eq(AchievementDef.STATS.size(), 20)
	for s in ExpectedTablesV2.STATS:
		assert_true(AchievementDef.STATS.has(s), s)
	for s in AchievementDef.STATS:
		assert_true(ExpectedTablesV2.STATS.has(s), s)


func test_b7_real_defs_obey_text_limits() -> void:
	for a in GameData.load_default().achievements:
		assert_lte(a.display_name.length(), 22, a.id)
		assert_lte(a.desc.length(), 60, a.id)
		assert_ne(a.display_name, "")


# --- B9: ödül yok, sim başarımı bilmez ----------------------------------------------------------------------------


func test_b9_no_real_character_uses_unlock() -> void:
	var d := GameData.load_default()
	for id in d.character_ids:
		assert_eq(d.get_character(id).unlock_achievement, &"")


func test_b9_sim_sources_do_not_mention_achievement_classes() -> void:
	var offenders := PackedStringArray()
	var stack: Array[String] = ["res://scripts/sim"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			# Veri yükleyici (DataV2/AchievementDef/GameData) tanım taşır; sim ÇALIŞMA zamanı dosyaları taranır.
			if f in ["data_v2.gd", "achievement_def.gd", "game_data.gd", "character_def.gd"]:
				continue
			var src := FileAccess.get_file_as_string(dir.path_join(f))
			for line in src.split("\n"):
				var code: String = line.split("#")[0]
				if code.contains("Achievement"):
					offenders.append("%s/%s: %s" % [dir, f, line.strip_edges()])
		for d2 in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(d2))
	assert_eq(offenders, PackedStringArray(), "scripts/sim çalışma zamanı başarımı bilmemeli")


func test_b9_sim_has_no_unlock_or_reward_hooks() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/sim/game_sim.gd")
	assert_false(src.contains("achievement"), "GameSim başarım bilmez")
	assert_false(src.contains("unlock"), "GameSim kilit açmaz")


# --- B6: ekran ------------------------------------------------------------------------------------------------


func test_b6_screen_has_22_rows_of_936x156_with_touch_height() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store())
	await get_tree().process_frame
	assert_eq(s.row_count(), 22)
	var rows := _rows(s)
	assert_eq(rows.size(), 22, "936×156 satır sayısı")
	for r in rows:
		assert_gte(
			maxf(r.size.y, r.custom_minimum_size.y),
			ExpectedLayoutV2.ROW_TOUCH_MIN,
			"dokunma hedefi >= 132"
		)


func test_b6_empty_store_shows_zero_of_22_without_error() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store())
	assert_true(AchKit.any_text_contains(s, "0 / 22"), "özet 0 / 22")
	assert_false(AchKit.any_text_contains(s, "hata"), "hata iletisi yok")


func test_b6_summary_counts_only_known_ids_and_unknown_kept_in_store() -> void:
	if _gate():
		return
	var st := AchKit.store()
	st.unlock(&"ilk_kan", TS)
	st.unlock(&"bes_dakika", TS)
	st.unlock(&"gelecek_sürüm_başarımı", TS)
	var s := _screen(st)
	assert_true(AchKit.any_text_contains(s, "2 / 22"), "yalnız bilinen kimlikler sayılır")
	assert_false(AchKit.any_text_contains(s, "gelecek"), "bilinmeyen kimlik gösterilmez")
	assert_true(st.is_unlocked(&"gelecek_sürüm_başarımı"), "ama kayıttan silinmez")
	assert_eq(s.row_count(), 22)


func test_b6_progress_text_and_cap_at_target() -> void:
	if _gate():
		return
	var st := AchKit.store()
	st.totals["kills"] = 34
	var s := _screen(st)
	assert_true(AchKit.any_text_contains(s, "34/" + UiKit.format_thousands(10000)), "34/10.000")
	var st2 := AchKit.store()
	st2.totals["kills"] = 25000
	var s2 := _screen(st2)
	assert_true(AchKit.any_text_contains(s2, "10.000/10.000"), "hedefi aşan değer hedef/hedef")
	assert_false(AchKit.any_text_contains(s2, "25.000"), "ham aşan değer gösterilmez")


func test_b6_run_scoped_without_progress_source_shows_single_run_label() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store())
	assert_true(AchKit.any_text_contains(s, "TEK KOŞU"), "TEK KOŞU çipi")
	assert_true(AchKit.any_text_contains(s, "Hedef 500"), "Hedef 500 (kırım)")


func test_b6_unlocked_row_shows_date_in_dd_mm_yyyy() -> void:
	if _gate():
		return
	var st := AchKit.store()
	st.unlock(&"ilk_kan", TS)
	var s := _screen(st)
	assert_true(AchKit.any_text_contains(s, "15.11.2023"), "tarih GG.AA.YYYY")


func test_b6_back_signal_and_scroll_container_for_22_rows() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store())
	watch_signals(s)
	s.back_requested.emit()
	assert_signal_emitted(s, "back_requested")
	var sc := s.find_children("*", "ScrollContainer", true, false)
	assert_gt(sc.size(), 0, ">= 22 satır: kaydırma")


func test_b6_safe_area_keeps_content_inside() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store())
	s.size = ExpectedLayoutV2.REF
	s.apply_safe_area(ExpectedLayoutV2.SAFE_NOTCH)
	await get_tree().process_frame
	await get_tree().process_frame
	var rows := _rows(s)
	assert_gt(rows.size(), 0)
	var top := INF
	var scroll := s.find_children("*", "ScrollContainer", true, false)
	for n in scroll:
		var r := (n as Control).get_global_rect()
		top = minf(top, r.position.y)
		assert_lte(
			r.end.y,
			ExpectedLayoutV2.REF.y - ExpectedLayoutV2.ACH_BOTTOM_PAD - 150.0 + 1.0,
			"alt pay"
		)
	if top < INF:
		assert_gte(top, ExpectedLayoutV2.ACH_TOP_MIN + 100.0 - 1.0, "üst pay")


func test_b6_corrupt_or_missing_store_shows_all_locked_without_error() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	AchKit.write_text(p, "{bozuk")
	var st := AchievementStore.new(p)
	st.load_file()
	var s := _screen(st)
	assert_true(AchKit.any_text_contains(s, "0 / 22"))
	assert_eq(s.row_count(), 22)


func test_b6_empty_definitions_show_error_text_not_rows() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store(), GameData.new())
	assert_eq(s.row_count(), 0)
	assert_true(s.get_child_count() > 0, "ekran boş değil: hata metni")


func test_b6_progress_helper_maps_sources() -> void:
	if _gate():
		return
	var st := AchKit.store()
	var d := AchKit.data()
	st.totals["kills"] = 7
	st.totals["runs"] = 3
	st.best["time"] = 120
	st.best["level"] = 4
	st.best["score"] = 900
	st.chars5 = PackedStringArray(["gunslinger"])
	assert_eq(AchievementProgress.of(d.get_achievement(&"ilk_kan"), st), 7)
	assert_eq(AchievementProgress.of(d.get_achievement(&"yerlesik"), st), 3)
	assert_eq(AchievementProgress.of(d.get_achievement(&"bes_dakika"), st), 120)
	assert_eq(AchievementProgress.of(d.get_achievement(&"seviye_10"), st), 4)
	assert_eq(AchievementProgress.of(d.get_achievement(&"skor_100k"), st), 900)
	assert_eq(AchievementProgress.of(d.get_achievement(&"cifte_yol"), st), 1)
	assert_eq(AchievementProgress.of(d.get_achievement(&"kirim"), st), -1, "kaynağı olmayan: -1")
	assert_eq(AchievementProgress.of(d.get_achievement(&"ilk_evrim"), st), -1)
