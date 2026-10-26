extends GutTest
## Kabul (v2.0 K1–K10): karakter seçimi, çözümleme, yeni karakter altyapısı, vitrin ekranı. Plan "Kabul listesi" + sözleşmeden.
## Sözleşmede GERÇEK olanlar (CharacterRoster, Settings.karakter, V2Flow.selected_character, ShowcaseMotion, veri) dilimsiz koşar;
## ekran gövdeleri (CharactersScreen, LevelUpScreen portre/başlık) K dilimi bitmeden pending.
## İzolasyon: Settings.store_path/character_id geri alınır; kayıtlar AchKit geçici yolu; veri kopyaları SimKit/KitDev (kancada silinir).

const FIX := "res://test/fixtures"
const REAL := "res://data"

var _store_path: String = ""
var _character_id: String = ""
var _ctrl: GameController = null


func before_each() -> void:
	var st := _settings()
	_store_path = st.store_path
	_character_id = st.character_id
	st.store_path = AchKit.tmp_path("settings")


func after_each() -> void:
	if _ctrl != null and is_instance_valid(_ctrl):  # cleanup'tan önce: _exit_tree flush dosya yazar
		if _ctrl.get_parent() != null:
			_ctrl.get_parent().remove_child(_ctrl)
		_ctrl.free()
	_ctrl = null
	var st := _settings()
	st.store_path = _store_path
	st.character_id = _character_id
	AchKit.cleanup()


func after_all() -> void:
	SimKit.remove_tmp()
	KitDev.remove_tmp()


func _settings() -> Node:
	return get_node("/root/Settings")


func _gate() -> bool:
	return V2Slice.require(self, "K")


## Gerçek data/ kopyası; zyfen'ya unlock eklenmiş (K10 sözleşme fixture'ı).
func _locked_zyfen_data(achievement: String = "endure") -> GameData:
	var dir := SimKit.copy_data(REAL, "k10")
	var path := dir.path_join("characters/zyfen.json")
	var j: Dictionary = SimKit.read_json(path)
	j["unlock"] = {"achievement": achievement}
	SimKit.write_json(path, j)
	return GameData.load_dir(dir)


# --- K1: seçim kaydı ve çözümleme ---------------------------------------------------------------------------------


func test_k1_resolve_defaults_to_gunslinger_for_missing_empty_unknown() -> void:
	var d := AchKit.legacy_data()
	var st := AchKit.fake_store()
	for saved in ["", "yok_boyle", "BARUTCU", " barutcu", "../barutcu"]:
		var got := CharacterRoster.resolve(saved, d, st)
		assert_eq(got, &"gunslinger", "'%s' -> varsayılan" % saved)
	assert_eq(CharacterRoster.resolve("zyfen", d, st), &"zyfen", "geçerli ve kilitsiz")
	assert_eq(CharacterRoster.resolve("gunslinger", d, st), &"gunslinger")


func test_k1_resolve_locked_character_falls_back() -> void:
	var d := _locked_zyfen_data()
	var st := AchKit.fake_store()
	assert_eq(CharacterRoster.resolve("zyfen", d, st), &"gunslinger", "kilitli -> varsayılan")
	st.unlock(&"endure", 1700000000)
	assert_eq(CharacterRoster.resolve("zyfen", d, st), &"zyfen", "kilit açıldı")
	st.corrupt = true
	assert_eq(
		CharacterRoster.resolve("zyfen", d, st), &"gunslinger", "bozuk kayıt: güvenli yön kilitli"
	)
	assert_eq(CharacterRoster.resolve("zyfen", d, null), &"gunslinger", "store null: kilitli")


func test_k1_resolve_edge_tables_single_and_none() -> void:
	var only := GameData.load_dir(SimKit.copy_data(REAL, "k1single"))
	assert_eq(CharacterRoster.ids(only), only.character_ids)
	# Hiç karakter yoksa boş kimlik (yapay: kimlik listesini boşalt).
	var none := GameData.new()
	assert_eq(CharacterRoster.resolve("zyfen", none, AchKit.fake_store()), &"")
	assert_eq(CharacterRoster.resolve("", none, null), &"")


func test_k1_resolve_when_default_is_locked_picks_first_unlocked() -> void:
	var dir := SimKit.copy_data(REAL, "k1firstfree")
	var gp := dir.path_join("characters/gunslinger.json")
	var g: Dictionary = SimKit.read_json(gp)
	g["unlock"] = {"achievement": "endure"}
	SimKit.write_json(gp, g)
	var d := GameData.load_dir(dir)
	assert_eq(
		CharacterRoster.resolve("", d, AchKit.fake_store()),
		&"zyfen",
		"varsayılan kilitli: ilk kilitsiz"
	)
	assert_eq(
		CharacterRoster.resolve("gunslinger", d, AchKit.fake_store()),
		&"zyfen",
		"kayıtlı kilitli: ilk kilitsiz"
	)


func test_k1_roster_step_clamps_at_ends() -> void:
	var ids: Array[StringName] = [&"a", &"b", &"c"]
	assert_eq(CharacterRoster.step(ids, &"a", -1), &"a", "sarmaz")
	assert_eq(CharacterRoster.step(ids, &"c", 1), &"c")
	assert_eq(CharacterRoster.step(ids, &"a", 1), &"b")
	assert_eq(CharacterRoster.step(ids, &"c", -1), &"b")
	assert_eq(CharacterRoster.step(ids, &"yok", 1), &"a", "bilinmeyen -> ilk")
	var empty: Array[StringName] = []
	assert_eq(CharacterRoster.step(empty, &"x", 1), &"x")


func test_k1_settings_character_roundtrip_through_file() -> void:
	var st := _settings()
	st.set_character("zyfen")
	assert_true(FileAccess.file_exists(st.store_path), "set_character kaydeder")
	st.character_id = ""
	st.load_settings()
	assert_eq(st.character_id, "zyfen", "kaydet -> yükle turu")


func test_k1_set_character_then_set_sound_keeps_character() -> void:
	var st := _settings()
	var sound_before: bool = st.sound_on
	st.set_character("zyfen")
	st.set_sound(false)
	st.character_id = ""
	st.load_settings()
	assert_eq(st.character_id, "zyfen", "set_sound 'karakter'i silmez (karar 8)")
	st.set_sound(sound_before)


func test_k1_settings_bad_or_missing_character_key() -> void:
	var st := _settings()
	for body in [
		'{"karakter": 5}', '{"karakter": null}', '{"karakter": [1]}', '{"ses": false}', "{bozuk"
	]:
		AchKit.write_text(st.store_path, body)
		st.character_id = "kalinti"
		st.load_settings()
		var ok_keep: bool = st.character_id == "" or st.character_id == "kalinti"
		assert_true(ok_keep, "çökmez: %s" % body)
		if body.begins_with('{"karakter"'):
			assert_eq(st.character_id, "", "tip yanlış karakter -> boş")
	AchKit.write_text(st.store_path, '{"ses": true}')
	st.character_id = ""
	st.load_settings()
	assert_eq(st.character_id, "", "eski dosya anahtarsız: boş -> varsayılan")


func test_k1_default_settings_file_is_untouched() -> void:
	var real_path := "user://settings.cfg"
	var before := (
		FileAccess.get_file_as_bytes(real_path)
		if FileAccess.file_exists(real_path)
		else PackedByteArray()
	)
	_settings().set_character("zyfen")
	var after := (
		FileAccess.get_file_as_bytes(real_path)
		if FileAccess.file_exists(real_path)
		else PackedByteArray()
	)
	assert_eq(after, before, "varsayılan yol dosyasına dokunulmadı")


# --- K2: controller seçimi sim'e taşır ------------------------------------------------------------------------------


func test_k2_controller_source_has_no_hardcoded_character_constant() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ctrl/game_controller.gd")
	for line in src.split("\n"):
		var code: String = line.split("#")[0]
		assert_false(
			code.begins_with("const CHARACTER"), "CHARACTER sabiti kalkmış olmalı: %s" % line
		)
		assert_eq(code.findn('&"gunslinger"'), -1, "controller karakter kimliği yazmaz: %s" % line)


func test_k2_selected_zyfen_builds_matching_sim() -> void:
	var st := _settings()
	st.character_id = "zyfen"
	var flow := V2Flow.new(
		{"data": AchKit.legacy_data(), "achievements_path": AchKit.tmp_path("flow")}
	)
	var id := flow.selected_character()
	assert_eq(id, &"zyfen")
	var sim := SimKit.make(11, {"data_kind": "real", "character": id})
	assert_eq(sim.character.id, &"zyfen")
	# Zyfen sayıları (hp, şarjör) K fazının expected_tables_v202'sine kalır; burada yalnız kimlik ve başlangıç becerisi.
	assert_eq(String(sim.character.starting_skill), "ruzgar_kesigi")
	assert_eq(sim.loadout.level_of(&"ruzgar_kesigi"), 1, "başlangıç becerisi ruzgar_kesigi")
	flow.release()


func test_k2_selected_character_falls_back_without_selection() -> void:
	_settings().character_id = ""
	var flow := V2Flow.new(
		{"data": AchKit.legacy_data(), "achievements_path": AchKit.tmp_path("flow")}
	)
	assert_eq(flow.selected_character(), &"gunslinger")
	_settings().character_id = "kalinti_kimlik"
	assert_eq(flow.selected_character(), &"gunslinger")
	flow.release()


func test_k2_game_controller_start_run_uses_saved_character() -> void:
	_settings().character_id = "zyfen"
	var c := _controller()
	c.start_run()
	assert_eq(c.sim.character.id, &"zyfen", "start_run seçili karakteri kullanır")
	c.go_menu()
	_settings().character_id = ""
	c.start_run()
	assert_eq(c.sim.character.id, &"gunslinger")


func _controller() -> GameController:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.v2_opts = {
		"data": AchKit.legacy_data(),
		"achievements_path": AchKit.tmp_path("ctrl"),
		"clock": AchKit.clock(),
	}
	add_child(c)
	_ctrl = c
	c.highscores = Highscores.new(AchKit.tmp_path("hs"))
	return c


# --- K3: seviye atlama ekranı karakterden ------------------------------------------------------------------------


func _levelup(character: CharacterDef) -> LevelUpScreen:
	var s := LevelUpScreen.new()
	add_child_autofree(s)
	var sim := SimKit.make(3, {"data_kind": "real"})
	assert_true(SimKit.level_up_with(sim, 100), "ön koşul: seviye atlama")
	s.call("show_choices", sim.pending_choices(), 2, sim.data, character)
	return s


func _label_with(root: Node, text: String) -> Label:
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return n
	return null


func test_k3_levelup_shows_upper_cased_character_name() -> void:
	if _gate():
		return
	var d := AchKit.legacy_data()
	var s := _levelup(d.get_character(&"gunslinger"))
	assert_not_null(
		_label_with(s, UiKit.character_upper(d.get_character(&"gunslinger"))),
		"GUNSLINGER üst yazısı"
	)
	var s2 := _levelup(d.get_character(&"zyfen"))
	assert_not_null(
		_label_with(s2, UiKit.character_upper(d.get_character(&"zyfen"))), "ZYFEN üst yazısı"
	)


func test_k3_levelup_turkish_dotted_dotless_i_in_name() -> void:
	if _gate():
		return
	var c := CharacterDef.new()
	c.id = &"ikili"
	c.display_name = "ışık iğne"
	c.portrait = ""
	var s := _levelup(c)
	assert_not_null(_label_with(s, "IŞIK İĞNE"), "ı->I, i->İ (to_upper değil upper_tr)")


func test_k3_levelup_without_portrait_opens_without_crash_and_has_no_portrait_node() -> void:
	if _gate():
		return
	var c := CharacterDef.new()
	c.id = &"portresiz"
	c.display_name = "Portresiz"
	c.portrait = ""
	var s := _levelup(c)
	assert_not_null(s.title_label, "başlık düğümü var")
	assert_null(s.find_child("Portrait", true, false), "Portrait düğümü yok")
	var s2 := _levelup(AchKit.legacy_data().get_character(&"gunslinger"))
	assert_not_null(s2.find_child("Portrait", true, false), "portresi olan karakterde Portrait var")


func test_k3_levelup_name_and_title_geometry() -> void:
	if _gate():
		return
	var s := _levelup(AchKit.legacy_data().get_character(&"gunslinger"))
	await get_tree().process_frame
	var name_label := _label_with(
		s, UiKit.character_upper(AchKit.legacy_data().get_character(&"gunslinger"))
	)
	assert_not_null(name_label)
	if name_label != null:
		assert_almost_eq(
			name_label.get_global_rect().position.y,
			ExpectedLayoutV2.LEVELUP_NAME_Y,
			8.0,
			"üst yazı y≈880"
		)
	assert_between(s.title_label.get_global_rect().position.y, 900.0, 960.0, "başlık y≈924")


func test_k3_levelup_safe_area_moves_cards_up_from_bottom() -> void:
	if _gate():
		return
	var s := _levelup(AchKit.legacy_data().get_character(&"gunslinger"))
	await get_tree().process_frame
	var before: float = s.cards[0].get_global_rect().end.y
	s.call("apply_safe_area", ExpectedLayoutV2.SAFE_NOTCH)
	await get_tree().process_frame
	var after: float = s.cards[0].get_global_rect().end.y
	assert_lt(after, before, "alt pay 150: kartlar yukarı")


# --- K4: ekran akışı ------------------------------------------------------------------------------------------------


func test_k4_screen_enum_is_appended_and_back_goes_to_menu() -> void:
	assert_eq(PauseLogic.Screen.CHARACTERS, 7)
	assert_eq(PauseLogic.Screen.ACHIEVEMENTS, 8)
	assert_eq(PauseLogic.Screen.MENU, 0)
	assert_eq(PauseLogic.Screen.SCORES, 6, "mevcut değerler 0..6 değişmedi")
	for sc in [PauseLogic.Screen.CHARACTERS, PauseLogic.Screen.ACHIEVEMENTS]:
		assert_eq(
			PauseLogic.back_action(sc), PauseLogic.Back.TO_MENU, "geri = menü (ekran %d)" % sc
		)


func test_k4_menu_button_opens_characters_screen_and_back_returns() -> void:
	if _gate():
		return
	var c := _controller()
	c.menu.characters_requested.emit()
	assert_eq(c.screen, PauseLogic.Screen.CHARACTERS)
	assert_false(c.menu.visible)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_true(c.menu.visible)


func test_k4_characters_screen_opens_only_from_menu() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	c.open_characters()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "oyun sırasında açılmaz")


func test_k4_selecting_updates_settings_and_menu_label() -> void:
	if _gate():
		return
	var c := _controller()
	c.menu.characters_requested.emit()
	var scr := _find_characters_screen(c)
	assert_not_null(scr, "CharactersScreen sahnede")
	if scr == null:
		return
	scr.set_focus_id(&"zyfen")
	assert_true(scr.press_select())
	assert_eq(_settings().character_id, "zyfen", "seçim Settings'e yazıldı")
	c._on_back()
	assert_true(
		AchKit.any_text_contains(c.menu, "Zyfen"),
		"menü alt satırı/sürüm etiketi yeni karakteri gösterir"
	)


func _find_characters_screen(c: GameController) -> CharactersScreen:
	var found := c.ui.find_children("*", "CharactersScreen", true, false)
	return found[0] if not found.is_empty() else null


# --- K5: vitrin ekranı hareketi ------------------------------------------------------------------------------------


func test_k5_showcase_motion_pure_values() -> void:
	assert_almost_eq(ShowcaseMotion.scale_at(0.0), 1.0, 1e-6)
	assert_almost_eq(ShowcaseMotion.scale_at(1.2), 1.015, 1e-4, "nefes zirvesi")
	assert_almost_eq(ShowcaseMotion.drift_at(0.0), 0.0, 1e-4)
	var lo := 0.0
	var hi := 0.0
	for i in 600:
		var d := ShowcaseMotion.drift_at(i * 0.01)
		lo = minf(lo, d)
		hi = maxf(hi, d)
		var sc := ShowcaseMotion.scale_at(i * 0.01)
		assert_between(sc, 1.0 - 1e-6, 1.015 + 1e-6)
	assert_almost_eq(hi, 8.0, 0.05)
	assert_almost_eq(lo, -8.0, 0.05)
	assert_almost_eq(ShowcaseMotion.CROSSFADE_SEC, 0.26, 1e-6)


func _open_screen() -> CharactersScreen:
	var s := CharactersScreen.new()
	add_child_autofree(s)
	s.open(AchKit.legacy_data(), AchKit.fake_store(), &"gunslinger")
	return s


func test_k5_hidden_screen_stops_processing_and_particles_then_resumes() -> void:
	if _gate():
		return
	var s := _open_screen()
	s.visible = true
	await get_tree().process_frame
	var ps := s.find_children("*", "CPUParticles2D", true, false)
	assert_gt(ps.size(), 0, "parçacık düğümü var")
	var total := 0
	for p in ps:
		total += (p as CPUParticles2D).amount
	assert_lte(total, 12, "parçacık toplamı <= 12")
	s.visible = false
	await get_tree().process_frame
	assert_false(s.is_processing(), "gizliyken _process kapalı")
	for p in ps:
		assert_false((p as CPUParticles2D).emitting, "gizliyken emitting false")
	s.visible = true
	await get_tree().process_frame
	assert_true(s.is_processing(), "görününce geri açılır")
	for p in ps:
		assert_true((p as CPUParticles2D).emitting, "görününce emitting true")


func test_k5_showcase_does_not_touch_sim_rng_or_hash() -> void:
	if _gate():
		return
	var sim := SimKit.make(21, {"data_kind": "real"})
	var h0 := sim.state_hash()
	var s := _open_screen()
	s.visible = true
	for i in 30:
		await get_tree().process_frame
	assert_eq(sim.state_hash(), h0, "vitrin sim durumuna dokunmaz")


# --- K6: veri doğrulama (S1 fixture'ları) ------------------------------------------------------------------------


func test_k6_character_field_validation_codes() -> void:
	var cases := {
		"blurb_long": "out_of_range",
		"portrait_missing": "asset_missing",
		"unlock_unknown": "unknown_ref",
		"placeholder_type": "bad_type",
		"unlock_key": "unknown_key",
	}
	for k in cases:
		var errs := GameData.load_dir(KitDev.data_dir("%s/char_bad_%s" % [FIX, k])).validate(
			{}, true
		)
		var has := false
		for e in errs:
			if e.contains("[%s]" % cases[k]):
				has = true
		assert_true(has, "%s -> %s: %s" % [k, cases[k], errs])


func test_k6_base_gun_is_not_a_character_field() -> void:
	var errs := GameData.load_dir(KitDev.data_dir(FIX + "/char_bad_base_gun")).validate({}, true)
	var has := false
	for e in errs:
		if e.contains("[unknown_key]"):
			has = true
	assert_true(has, "base_gun kapsam dışı: unknown_key")


func test_k6_blurb_boundary_120_ok() -> void:
	var dir := SimKit.copy_data(REAL, "k6blurb")
	var p := dir.path_join("characters/zyfen.json")
	var j: Dictionary = SimKit.read_json(p)
	j["blurb"] = "x".repeat(120)
	SimKit.write_json(p, j)
	assert_eq(
		GameData.load_dir(dir).validate({}, true), PackedStringArray(), "120 karakter geçerli"
	)
	j["blurb"] = "x".repeat(121)
	SimKit.write_json(p, j)
	assert_gt(GameData.load_dir(dir).validate({}, true).size(), 0, "121 karakter hata")


# --- K7: her gerçek karakter 15 adım ---------------------------------------------------------------------------------


func test_k7_every_real_character_runs_and_keeps_invariants() -> void:
	var d := AchKit.legacy_data()
	assert_gte(d.character_ids.size(), 2)
	for id in d.character_ids:
		var sim := SimKit.make(31, {"data_kind": "quiet", "character": id})
		SimKit.run(sim, 15, Vector2.RIGHT)
		assert_eq(sim.check_invariants(), PackedStringArray(), "%s: değişmezler" % id)
		var c := d.get_character(id)
		if c.armless:  # v2.0.2: kolsuzda namlu yok, atış noktası cast_point (±0,5)
			var cp: Array = c.rig.get("cast_point", [])
			assert_eq(cp.size(), 2, "%s: cast_point" % id)
			if cp.size() == 2:
				assert_between(float(cp[0]), -0.5, 0.5, "%s: cast_point x" % id)
				assert_between(float(cp[1]), -0.5, 0.5, "%s: cast_point y" % id)
		else:
			var muzzle: Array = c.rig.get("muzzle", [])
			assert_eq(muzzle.size(), 2, "%s: namlu noktası" % id)
			if muzzle.size() == 2:
				assert_between(float(muzzle[0]), 0.0, 1.0, "%s: namlu x kol kutusunda" % id)
				assert_between(float(muzzle[1]), 0.0, 1.0, "%s: namlu y kol kutusunda" % id)
		var skill := d.get_skill(c.starting_skill)
		assert_not_null(skill, "%s: başlangıç becerisi" % id)
		assert_eq(skill.kind, SkillDef.KIND_ACTIVE, "%s: kind=active" % id)


# --- K8: Zyfen determinizmi --------------------------------------------------------------------------------------


func test_k8_zyfen_same_seed_same_hash() -> void:
	var hashes: Array[int] = []
	for run_i in 2:
		var sim := SimKit.make(41, {"data_kind": "real", "character": &"zyfen"})
		var rng := Bots.make_rng(41)
		Bots.play(sim, Bots.KITE, 900, rng, 0)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1], "Zyfen aynı tohum aynı hash")
	var other := SimKit.make(42, {"data_kind": "real", "character": &"zyfen"})
	Bots.play(other, Bots.KITE, 900, Bots.make_rng(42), 0)
	assert_ne(other.state_hash(), hashes[0], "farklı tohum farklı hash")


func test_k8_gunslinger_and_zyfen_diverge_with_same_seed() -> void:
	var a := SimKit.make(43, {"data_kind": "real", "character": &"gunslinger"})
	var b := SimKit.make(43, {"data_kind": "real", "character": &"zyfen"})
	SimKit.run(a, 120)
	SimKit.run(b, 120)
	assert_ne(a.state_hash(), b.state_hash())


# --- K9: yeni karakter belgesi --------------------------------------------------------------------------------------


func test_k9_new_character_doc_has_required_sections() -> void:
	if _gate():
		return
	var path := "res://docs/dev/new-character.md"
	assert_true(FileAccess.file_exists(path), "docs/dev/new-character.md var")
	var low := FileAccess.get_file_as_string(path).to_lower()
	for need in ["json", "görsel", "rig", "bash tools/gate.sh", "vitrin", "unlock"]:
		assert_true(low.contains(need), "belgede '%s' geçmeli" % need)
	var headings := 0
	for line in low.split("\n"):
		if line.begins_with("#"):
			headings += 1
	assert_gte(headings, 5, "bölüm başlıkları")


# --- K10: kilit ---------------------------------------------------------------------------------------------------


func test_k10_no_real_character_has_unlock() -> void:
	var d := AchKit.legacy_data()
	for id in d.character_ids:
		assert_eq(d.get_character(id).unlock_achievement, &"", "%s: ödül yok -> kilitsiz" % id)
		assert_true(CharacterRoster.is_unlocked(d.get_character(id), AchKit.fake_store()))


func test_k10_lock_reason_text_uses_achievement_name() -> void:
	var d := _locked_zyfen_data()
	assert_eq(CharacterRoster.lock_reason(d.get_character(&"zyfen"), d), "Endure başarımını aç")
	assert_false(CharacterRoster.is_unlocked(d.get_character(&"zyfen"), AchKit.fake_store()))


func test_k10_locked_character_cannot_be_selected_on_screen() -> void:
	if _gate():
		return
	var d := _locked_zyfen_data()
	var st := AchKit.fake_store()
	var s := CharactersScreen.new()
	add_child_autofree(s)
	s.open(d, st, &"gunslinger")
	watch_signals(s)
	s.set_focus_id(&"zyfen")
	assert_eq(s.focus_id(), &"zyfen")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.LOCKED)
	assert_false(s.press_select())
	assert_signal_not_emitted(s, "selected")
	assert_true(AchKit.any_text_contains(s, "Endure başarımını aç"), "kilit nedeni satırı")


func test_k10_corrupt_store_keeps_locked_character_locked() -> void:
	if _gate():
		return
	var d := _locked_zyfen_data()
	var st := AchKit.fake_store()
	st.unlock(&"endure", 1700000000)
	st.corrupt = true
	var s := CharactersScreen.new()
	add_child_autofree(s)
	s.open(d, st, &"gunslinger")
	s.set_focus_id(&"zyfen")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.LOCKED, "güvenli yön")


func test_k10_select_states_and_selected_signal() -> void:
	if _gate():
		return
	var s := _open_screen()
	assert_eq(s.focus_id(), &"gunslinger", "açılışta odak seçili karakterde")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.SELECTED)
	assert_false(s.press_select(), "odak == seçili: yeniden seçilmez")
	watch_signals(s)
	s.set_focus_id(&"zyfen")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.SELECT)
	assert_true(s.press_select())
	assert_signal_emitted_with_parameters(s, "selected", [&"zyfen"])
	assert_eq(
		s.select_button_state(), CharactersScreen.SelectState.SELECTED, "seçim sonrası SEÇİLİ"
	)


func test_k10_single_character_set_works() -> void:
	if _gate():
		return
	var dir := SimKit.copy_data(REAL, "k10single")
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(dir.path_join("characters/zyfen.json"))
	)
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(dir.path_join("characters/zyfen.json"))
	)
	var d := GameData.load_dir(dir)
	assert_eq(d.character_ids.size(), 1)
	var s := CharactersScreen.new()
	add_child_autofree(s)
	s.open(d, AchKit.fake_store(), &"gunslinger")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.SELECTED)
	assert_false(s.press_select())
