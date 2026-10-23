extends GutTest
## Kabul (v1.1): arayüz mantığı - Türkçe büyük harf (U12), PauseLogic (U13), ScreenDelay tek tetik (U14 saf kısım).
## S3'ten beri gerçek yardımcılar: dilimsiz koşar (kaynakta to_upper/to_lower yasağı dahil).

# --- U12: upper_tr -------------------------------------------------------------------------------------------


func test_u12_upper_tr_turkish_dotted_dotless_i_for_pickup_names() -> void:
	assert_eq(UiKit.upper_tr("Kızıl İksir"), "KIZIL İKSİR")
	assert_eq(UiKit.upper_tr("Çekim Taşı"), "ÇEKİM TAŞI")
	assert_eq(UiKit.upper_tr("Öfke Barutu"), "ÖFKE BARUTU")
	assert_eq(UiKit.upper_tr("Kızgın Namlu"), "KIZGIN NAMLU")
	assert_eq(UiKit.upper_tr("Kara Bomba"), "KARA BOMBA")
	assert_eq(UiKit.upper_tr("Sonsuz Tambur"), "SONSUZ TAMBUR")
	assert_eq(UiKit.upper_tr("i"), "İ")
	assert_eq(UiKit.upper_tr("ı"), "I")
	assert_eq(UiKit.upper_tr("En iyi 10'a girdin · 4. sıra"), "EN İYİ 10'A GİRDİN · 4. SIRA")
	assert_eq(UiKit.upper_tr("Yeni rekor"), "YENİ REKOR")


func test_u12_all_pickup_display_names_uppercase_correctly_from_data() -> void:
	var data := GameData.load_default()
	for id in data.pickup_ids:
		var name: String = data.get_pickup(id).display_name
		var up := UiKit.upper_tr(name)
		assert_false(up.contains("i"), "%s: küçük i kalmaz (%s)" % [id, up])
		assert_false(up.contains("ı"), "%s: küçük ı kalmaz" % id)
		assert_eq(up.length(), name.length(), "%s: harf sayısı korunur" % id)


func test_u12_sources_never_call_to_upper_or_to_lower() -> void:
	var offenders := PackedStringArray()
	for base in ["res://scripts", "res://tools"]:
		_scan_dir(base, offenders)
	assert_eq(offenders.size(), 0, "to_upper/to_lower yasak: %s" % str(offenders))


func _scan_dir(dir: String, offenders: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var txt := FileAccess.get_file_as_string(dir.path_join(f))
			if txt.contains("to_upper") or txt.contains("to_lower"):
				offenders.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan_dir(dir.path_join(d), offenders)


# --- U13: PauseLogic -----------------------------------------------------------------------------------------


func test_u13_scores_screen_back_goes_to_menu_and_result_delays() -> void:
	assert_eq(PauseLogic.back_action(PauseLogic.Screen.SCORES), PauseLogic.Back.TO_MENU)
	assert_eq(PauseLogic.result_delay(true), 1.8, "kazanma 1,8 sn")
	assert_eq(PauseLogic.result_delay(false), 1.3, "ölüm 1,3 sn")
	assert_eq(PauseLogic.LEVEL_UP_PREROLL, 0.18)
	assert_eq(
		PauseLogic.Screen.SCORES,
		PauseLogic.Screen.RESULT + 1,
		"SCORES sona eklendi (v1 sırası korunur)"
	)
	assert_eq(PauseLogic.Screen.MENU, 0)
	assert_eq(PauseLogic.Screen.RESULT, 5)
	assert_false(
		PauseLogic.should_auto_pause(Node.NOTIFICATION_APPLICATION_PAUSED, PauseLogic.Screen.SCORES)
	)
	assert_false(PauseLogic.sim_should_step(PauseLogic.Screen.SCORES, GameSim.State.RUNNING))


# --- U14: gecikme tek tetik ----------------------------------------------------------------------------------


func test_u14_screen_delay_fires_once_by_timer_or_skip() -> void:
	var d := ScreenDelay.new()
	assert_false(d.skip(), "aktif değilken skip no-op")
	assert_false(d.tick(1.0))
	d.start(PauseLogic.Screen.RESULT, 1.3)
	assert_true(d.active)
	assert_false(d.tick(1.29), "süre dolmadı")
	assert_true(d.tick(0.02), "süre bitince tek tetik")
	assert_false(d.tick(1.0), "ikinci tetik yok")
	assert_false(d.active)
	d.start(PauseLogic.Screen.RESULT, 1.3)
	d.start(PauseLogic.Screen.LEVEL_UP, 0.1)  # aktifken yok sayılır
	assert_eq(d.target, PauseLogic.Screen.RESULT)
	assert_true(d.skip(), "dokunma/geri/arka plan: hemen tetikler")
	assert_false(d.skip(), "skip ikinci kez no-op")
	assert_false(d.tick(5.0), "skip sonrası zamanlayıcı tekrar tetiklemez")
