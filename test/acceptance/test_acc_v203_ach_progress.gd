extends GutTest
## Kabul (v2.0.3 C): aşamalı başarım DAVRANIŞI — eşik geçişi, tek bildirim, boss sayacı, kayıt göçü, ekran gösterimi.
## Kaynak: DESIGN.md §4 (kademe/özet/boş-hepsi açık durumları, bildirim–liste tutarlılığı, çoklu eşik = tek bildirim),
## data-schema.md "Kayıt göçü (imza)". Kademe SEVİYESİNİN depodaki gösterimi sözleşmede yok (Açık nokta); bu yüzden göç,
## kademe ≥ 1 = `store.is_unlocked(aile)` (data-schema: `unlock.achievement` = aile) ve sayaçların korunması üzerinden sınanır.
## Dilim C kapalıyken pending. Kayıtlar AchKit geçici yolundadır (after_each temizler); gerçek user:// dosyasına yazılmaz.

const TS := 1700049600  # 2023-11-15 12:00 UTC


func after_each() -> void:
	AchKit.cleanup()


func _gate() -> bool:
	return V203Slice.require(self, "C")


## `stat` için ilk aile (veri sırası); yoksa null.
func _family_of(stat: StringName) -> AchievementDef:
	for a in AchKit.data().achievements:
		if a.stat == stat and not a.steps.is_empty():
			return a
	return null


func _count_signals(tr: AchievementTracker) -> Array:
	var got: Array = []
	tr.unlocked.connect(func(d: AchievementDef) -> void: got.append(d.id))
	return got


# --- eşik geçişi (total_kills ailesi) -----------------------------------------------------------------------------


func test_c5_each_threshold_notifies_once_when_crossed_and_not_before() -> void:
	if _gate():
		return
	var fam := _family_of(&"total_kills")
	assert_not_null(fam, "total_kills ailesi")
	if fam == null:
		return
	for k in fam.steps.size():
		var rig := AchKit.rig()
		var st: AchievementStore = rig["store"]
		var tr: AchievementTracker = rig["tracker"]
		var got := _count_signals(tr)
		st.totals["kills"] = fam.steps[k] - 2  # 1. kesim eşiğin 1 altı (ilk kademe 1 ise 0)
		AchKit.kills(rig["bus"], 1, ExpectedTablesV2.NORMAL_ENEMY)  # eşiğin 1 altı
		var before := got.count(fam.id)
		AchKit.kills(rig["bus"], 1, ExpectedTablesV2.NORMAL_ENEMY)  # tam eşik
		assert_eq(got.count(fam.id), before + 1, "kademe %d eşikte bildirir" % (k + 1))
		AchKit.kills(rig["bus"], 1, ExpectedTablesV2.NORMAL_ENEMY)  # eşiğin üstü: tekrar yok
		assert_eq(got.count(fam.id), before + 1, "kademe %d tekrar bildirmez" % (k + 1))
		assert_true(st.is_unlocked(fam.id), "kademe ≥ 1 = aile açık")


func test_c5_a_jump_over_several_thresholds_is_one_notification_for_the_family() -> void:
	if _gate():
		return
	var fam := _family_of(&"total_kills")
	if fam == null:
		return
	var rig := AchKit.rig()
	var tr: AchievementTracker = rig["tracker"]
	var got := _count_signals(tr)
	(rig["store"] as AchievementStore).totals["kills"] = fam.steps[-1] - 1
	AchKit.kills(rig["bus"], 1, ExpectedTablesV2.NORMAL_ENEMY)
	assert_eq(got.count(fam.id), 1, "çoklu eşik = tek bildirim (en yüksek kademe)")


func test_c5_progress_does_not_drop_below_the_stored_counter() -> void:
	if _gate():
		return
	var fam := _family_of(&"total_kills")
	if fam == null:
		return
	var rig := AchKit.rig()
	(rig["store"] as AchievementStore).totals["kills"] = fam.steps[0] + 3
	assert_eq((rig["tracker"] as AchievementTracker).progress(fam), fam.steps[0] + 3)


# --- boss sayacı (total_boss_kills) -----------------------------------------------------------------------------------


func test_c6_elite_kind_deaths_feed_total_boss_kills_and_normal_deaths_do_not() -> void:
	if _gate():
		return
	var rig := AchKit.rig()
	var tr: AchievementTracker = rig["tracker"]
	AchKit.kills(rig["bus"], 3, ExpectedTablesV2.NORMAL_ENEMY)
	assert_eq(tr.value_of(&"total_boss_kills"), 0, "sıradan düşman boss sayılmaz")
	for kind in ExpectedTablesV2.ELITE_KINDS:
		var before := tr.value_of(&"total_boss_kills")
		AchKit.kills(rig["bus"], 1, StringName(kind))
		assert_eq(tr.value_of(&"total_boss_kills"), before + 1, kind)


func test_c6_total_boss_kills_survives_save_and_load() -> void:
	if _gate():
		return
	var path := AchKit.tmp_path("boss")
	var st := AchievementStore.new(path)
	var tr := AchievementTracker.new(AchKit.data(), st, &"gunslinger", AchKit.clock())
	var bus := SimBus.new()
	tr.attach(bus)
	AchKit.kills(bus, 2, &"elit_piyade")
	assert_true(tr.flush())
	var back := AchievementStore.new(path)
	assert_true(back.load_file())
	var tr2 := AchievementTracker.new(AchKit.data(), back, &"gunslinger", AchKit.clock())
	assert_eq(tr2.value_of(&"total_boss_kills"), 2, "sayaç koşular arası kalıcı")


# --- kayıt göçü ----------------------------------------------------------------------------------------------------------


func _v1_save() -> Dictionary:
	return {
		"v": 1,
		"unlocked":
		{"ilk_kan": TS, "bes_dakika": TS + 5, "kirim": TS + 9, "sinirsiz_kirim": TS + 20},
		"totals": {"kills": 4321, "runs": 12, "wins": 1, "play_secs": 9000},
		"best": {"score": 123456, "time": 905, "level": 21},
		"chars5": ["gunslinger", "zyfen"],
	}


func _write_v1(path: String) -> String:
	var text := JSON.stringify(_v1_save())
	AchKit.write_text(path, text)
	return text


func test_c7_migrate_v1_marks_v2_keeps_counters_and_is_pure_and_idempotent() -> void:
	if _gate():
		return
	var raw := _v1_save()
	var snapshot := raw.duplicate(true)
	var defs: Array = AchKit.data().achievements
	var out := AchievementStore.migrate_v1(raw, defs)
	assert_eq(raw, snapshot, "girdi değişmez")
	assert_eq(int(out["v"]), AchievementStore.VERSION_V2, "v2 işareti")
	assert_eq(out["totals"], raw["totals"], "sayaçlar korunur")
	assert_eq(out["best"], raw["best"], "en iyiler korunur")
	assert_eq(out["chars5"], raw["chars5"], "karakter listesi korunur")
	assert_eq(AchievementStore.migrate_v1(out, defs), out, "idempotent")


func test_c7_v1_file_opens_without_loss_and_every_old_unlock_keeps_its_family_open() -> void:
	if _gate():
		return
	var path := AchKit.tmp_path("mig")
	_write_v1(path)
	var st := AchievementStore.new(path)
	assert_true(st.load_file(), "v1 dosyası açılır")
	assert_false(st.corrupt, "v1 bozuk sayılmaz")
	assert_eq(int(st.totals["kills"]), 4321)
	assert_eq(int(st.best["score"]), 123456)
	assert_eq(st.chars5, PackedStringArray(["gunslinger", "zyfen"]))
	for old_id in _v1_save()["unlocked"]:
		var fam: AchievementDef = null
		for a in AchKit.data().achievements:
			if a.legacy.has(old_id):
				fam = a
		assert_not_null(fam, "%s bir aileye eşlenmiş" % old_id)
		if fam != null:
			assert_true(st.is_unlocked(fam.id), "%s → %s açık kalır" % [old_id, fam.id])


func test_c7_first_v2_write_keeps_a_single_v1_backup_and_roundtrips() -> void:
	if _gate():
		return
	var path := AchKit.tmp_path("bak")
	var original := _write_v1(path)
	var bak := path + AchievementStore.BACKUP_SUFFIX
	AchKit.track(bak)
	var st := AchievementStore.new(path)
	assert_true(st.load_file())
	st.add_total(&"kills", 1)
	assert_true(st.save())
	assert_true(FileAccess.file_exists(bak), "ilk v2 yazımından önce .v1.bak")
	assert_eq(AchKit.read_text(bak), original, "yedek özgün v1 içeriği")
	var saved: Variant = JSON.parse_string(AchKit.read_text(path))
	assert_eq(int((saved as Dictionary)["v"]), AchievementStore.VERSION_V2)
	st.add_total(&"kills", 1)
	assert_true(st.save())
	assert_eq(AchKit.read_text(bak), original, "yedek ikinci yazımda ezilmez")
	var back := AchievementStore.new(path)
	assert_true(back.load_file())
	assert_eq(int(back.totals["kills"]), 4323)
	assert_eq(back.unlocked, st.unlocked)


func test_c7_unknown_future_version_is_corrupt_and_does_not_crash() -> void:
	if _gate():
		return
	var path := AchKit.tmp_path("fut")
	AchKit.write_text(path, '{"v":3,"unlocked":{"ilk_kan":1}}')
	var st := AchievementStore.new(path)
	assert_false(st.load_file())
	assert_true(st.corrupt)
	assert_true(FileAccess.file_exists(path + ".bad"), "bozuk içerik .bad olarak saklanır")
	assert_true(st.unlocked.is_empty())


# --- ekran -----------------------------------------------------------------------------------------------------------------


func _screen(st: AchievementStore) -> AchievementsScreen:
	var s := AchievementsScreen.new()
	add_child_autofree(s)
	s.open(AchKit.data(), st)
	return s


func _total_steps() -> int:
	var n := 0
	for a in AchKit.data().achievements:
		n += a.thresholds().size()
	return n


func test_c8_screen_summary_counts_steps_and_group_headers_are_fixed_uppercase() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store())
	await get_tree().process_frame
	assert_true(AchKit.any_text_contains(s, "0 / %d" % _total_steps()), "özet 0 / toplam kademe")
	for g in AchievementDef.GROUPS:
		assert_true(AchKit.any_text_contains(s, g), "grup başlığı %s" % g)
	assert_true(AchKit.any_text_contains(s, "Henüz kademe açılmadı"), "boş durum metni")
	assert_false(AchKit.any_text_contains(s, "hata"), "hata iletisi yok")


func test_c8_screen_lists_every_family_name_and_hides_unknown_ids() -> void:
	if _gate():
		return
	var st := AchKit.store()
	st.unlock(&"gelecek_surum_basarimi", TS)
	var s := _screen(st)
	await get_tree().process_frame
	for a in AchKit.data().achievements:
		assert_true(AchKit.any_text_contains(s, a.display_name), a.display_name)
	assert_false(AchKit.any_text_contains(s, "gelecek"), "bilinmeyen kimlik gösterilmez")
	assert_true(st.is_unlocked(&"gelecek_surum_basarimi"), "ama kayıttan silinmez")


func test_c8_screen_shows_progress_toward_the_next_step_of_a_family() -> void:
	if _gate():
		return
	var fam := _family_of(&"total_kills")
	if fam == null:
		return
	var st := AchKit.store()
	st.totals["kills"] = fam.steps[0] + 7
	st.unlock(fam.id, TS)
	var s := _screen(st)
	await get_tree().process_frame
	var cur := UiKit.format_thousands(fam.steps[0] + 7)
	assert_true(AchKit.any_text_contains(s, cur), "güncel değer %s" % cur)
	var nxt := UiKit.format_thousands(fam.steps[1])
	assert_true(AchKit.any_text_contains(s, nxt), "sonraki hedef %s" % nxt)


func test_c8_screen_all_open_shows_total_and_the_completion_line() -> void:
	if _gate():
		return
	var st := AchKit.store()
	for a in AchKit.data().achievements:
		st.unlock(a.id, TS)
	st.totals["kills"] = 999999
	var s := _screen(st)
	await get_tree().process_frame
	assert_true(AchKit.any_text_contains(s, "Tüm başarımlar açıldı"), "hepsi açık durumu")


func test_c8_screen_safe_area_keeps_back_button_inside_and_title_below_the_inset() -> void:
	if _gate():
		return
	var s := _screen(AchKit.store())
	s.size = ExpectedLayoutV2.REF
	var extra := Vector4(0.0, 120.0, 0.0, 90.0)
	s.apply_safe_area(extra)
	await get_tree().process_frame
	var back_bottom := s.back_button.global_position.y + s.back_button.size.y
	assert_lte(
		back_bottom, ExpectedLayoutV2.REF.y - ExpectedLayoutV2.ACH_BOTTOM_PAD - extra.w + 0.5
	)
	assert_gte(s.title_label.global_position.y, ExpectedLayoutV2.ACH_TOP_MIN + extra.y - 0.5)
