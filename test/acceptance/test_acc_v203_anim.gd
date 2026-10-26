extends GutTest
## Kabul (v2.0.3 A): Gunslinger yürüme şeridi, hareketli portre düşüş davranışı, altın hash değişmezliği.
## Kaynak: çatı kabul ölçütleri #1–#2, `ab-animasyon-seridi` (kalite kapısı, rig.walk), data-schema.md `portrait_video`
## (".ogv; yoksa/yüklenemezse statik portre") ve `Settings.hareket_azalt` (hareketli portre durur).
## Dilim A kapalıyken `test_a*` pending; `test_g*` (altın hash) HER ZAMAN koşar: görünüm işi sim'i bozmamalı.
## N8: F-ashen-bastion-064 (gunslinger.json `rig.walk`: frames 0 + var olmayan şerit) bu işte düzelir; test düzeltilmiş durumu bekler.

const FIX := "res://test/fixtures"
const CHARS := ["gunslinger", "zyfen"]
## v2.0.2 altın zincirinin u1b aşaması, Gunslinger (test/fixtures/golden_hashes.json). Burada sabit: kayıt dosyası sessizce yeniden
## üretilirse test kırılır (dosyayı DEĞİL sabiti değiştirmek bilinçli karar ister).
const GOLDEN_U1B := {11: 500033848, 23: 3935248278, 37: 722930297}

var _saved_reduce: bool = false


func before_each() -> void:
	_saved_reduce = Settings.hareket_azalt


func after_each() -> void:
	Settings.hareket_azalt = _saved_reduce


func _gate() -> bool:
	return V203Slice.require(self, "A")


func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _all_players(root: Node) -> Array[VideoStreamPlayer]:
	var out: Array[VideoStreamPlayer] = []
	for n in root.find_children("*", "VideoStreamPlayer", true, false):
		out.append(n as VideoStreamPlayer)
	return out


func _screen(data: GameData, selected: StringName = &"gunslinger") -> CharactersScreen:
	var s := CharactersScreen.new()
	s.size = ExpectedLayoutV2.REF
	add_child_autofree(s)
	s.open(data, AchKit.store(), selected)
	return s


func _has_static_visual(s: CharactersScreen) -> bool:
	for n in s.find_children("*", "TextureRect", true, false):
		var t := n as TextureRect
		if t.texture != null and t.size.x > 100.0 and t.size.y > 100.0:
			return true
	return false


# --- Gunslinger yürüme şeridi (F-038, F-064) ---------------------------------------------------------------------


func test_a1_gunslinger_walk_strip_passes_the_quality_gate() -> void:
	if _gate():
		return
	var q := _json("res://art/source/gunslinger/quality.json")
	assert_false(q.is_empty(), "art/source/gunslinger/quality.json var ve okunur")
	assert_true(bool(q.get("pass", false)), "quality.json pass:true")
	var checks: Dictionary = q.get("checks", {})
	for k in ["foot_slide", "height_dev", "strip_width"]:
		assert_true(bool(checks.get(k, false)), "kalite kontrolü %s" % k)


func test_a2_gunslinger_rig_walk_points_to_a_real_strip_f064() -> void:
	if _gate():
		return
	var d := GameData.load_default().get_character(&"gunslinger")
	assert_not_null(d)
	var walk: Dictionary = (d.rig as Dictionary).get("walk", {})
	assert_gte(int(walk.get("frames", 0)), 4, "yürüme karesi sayısı > 0 (F-064: eskiden 0)")
	var strip := str(walk.get("strip", ""))
	assert_true(ResourceLoader.exists(strip), "şerit dosyası var: %s" % strip)
	var cell: Array = walk.get("cell", [0, 0])
	assert_gt(int(cell[0]), 0)
	assert_gt(int(cell[1]), 0)
	var tex := load(strip) as Texture2D
	assert_not_null(tex)
	if tex != null:
		assert_gte(
			tex.get_width(),
			int(cell[0]) * int(walk.get("frames", 0)),
			"şerit genişliği >= kare x hücre"
		)
		assert_lte(tex.get_width(), 8192, "şerit genişliği sınırı")
		assert_eq(tex.get_height(), int(cell[1]), "hücre yüksekliği şeritle aynı")


func test_a3_walk_keeps_the_gun_arm_a_separate_part() -> void:
	if _gate():
		return
	assert_true(
		ResourceLoader.exists("res://assets/gfx/char/gunslinger_arm.png"),
		"tabancalı kol ayrı parça"
	)
	assert_true(ResourceLoader.exists("res://assets/gfx/char/gunslinger_body.png"), "gövde parçası")


# --- hareketli portre -----------------------------------------------------------------------------------------------------


func test_a4_both_characters_declare_an_existing_ogv_and_keep_a_static_portrait() -> void:
	if _gate():
		return
	var g := GameData.load_default()
	for id in CHARS:
		var c := g.get_character(StringName(id))
		assert_not_null(c, id)
		if c == null:
			continue
		assert_true(c.portrait_video.ends_with(".ogv"), "%s: portrait_video .ogv" % id)
		assert_true(ResourceLoader.exists(c.portrait_video), "%s: video dosyası var" % id)
		assert_ne(c.portrait, "", "%s: statik portre yedeği duruyor" % id)
		assert_true(ResourceLoader.exists(c.portrait), "%s: statik portre dosyası var" % id)
	assert_eq(GameData.load_dir("res://data").validate({}, true), PackedStringArray())


func test_a5_motion_allowed_shows_a_looping_portrait_player_for_the_focused_character() -> void:
	if _gate():
		return
	Settings.hareket_azalt = false
	var s := _screen(GameData.load_default())
	await get_tree().process_frame
	var players := _all_players(s)
	assert_gt(players.size(), 0, "hareketli portre oynatıcısı var")
	for p in players:
		assert_not_null(p.stream, "akış yüklü")
		assert_true(p.loop, "döngü")
	assert_true(_has_static_visual(s), "statik portre de hazırda (yedek/geçiş)")


func test_a6_reduced_motion_falls_back_to_the_static_portrait_and_plays_nothing() -> void:
	if _gate():
		return
	Settings.hareket_azalt = true
	var s := _screen(GameData.load_default())
	await get_tree().process_frame
	for p in _all_players(s):
		assert_false(p.is_playing(), "hareket azalt AÇIK: oynatıcı çalmaz")
		assert_false(p.autoplay, "hareket azalt AÇIK: otomatik oynatma yok")
		assert_false(p.visible, "hareket azalt AÇIK: oynatıcı görünmez")
	assert_true(_has_static_visual(s), "statik portre görünür")


func test_a7_load_failure_falls_back_to_the_static_portrait_without_error() -> void:
	if _gate():
		return
	Settings.hareket_azalt = false
	var dir := KitDev.data_dir("%s/char_bad_portrait_video_missing" % FIX)
	var s := _screen(GameData.load_dir(dir))
	await get_tree().process_frame
	for p in _all_players(s):
		assert_false(p.is_playing(), "yüklenemeyen video çalmaz")
		assert_false(p.visible and p.stream != null, "yüklenemeyen video gösterilmez")
	assert_true(_has_static_visual(s), "statik portre görünür")
	assert_false(AchKit.any_text_contains(s, "hata"), "hata iletisi yok")


func test_a8_switching_focus_between_characters_never_leaves_two_players_running() -> void:
	if _gate():
		return
	Settings.hareket_azalt = false
	var s := _screen(GameData.load_default())
	await get_tree().process_frame
	s.set_focus_id(&"zyfen")
	await get_tree().process_frame
	var running := 0
	for p in _all_players(s):
		if p.visible and p.is_playing():
			running += 1
	assert_lte(running, 1, "aynı anda en çok bir portre oynar")


## Bozuk akış zaman aşımı yolu: gerçek bozuk .ogv motor ERROR satırı yazar (gate günlüğünü kırar), bu yüzden akış YOK iken
## doğrudan _process çağrılır: ilk kare gelmezse START_TIMEOUT_SEC sonunda `failed` tek kez çıkar, oynatıcı gizli kalır.
func test_a9_stalled_stream_gives_up_after_the_timeout_and_stays_hidden() -> void:
	if _gate():
		return
	var p := PortraitPlayer.new()
	add_child_autofree(p)
	watch_signals(p)
	p.set_process(true)
	p._process(PortraitPlayer.START_TIMEOUT_SEC * 0.5)
	assert_signal_not_emitted(p, "failed", "süre dolmadan vazgeçilmez")
	assert_true(p.is_processing(), "süre dolana dek beklemeye devam eder")
	p._process(PortraitPlayer.START_TIMEOUT_SEC)
	assert_signal_emit_count(p, "failed", 1)
	assert_false(p.is_processing(), "vazgeçince işlem durur")
	assert_false(p.visible, "siyah çakma yok: gizli kalır")
	assert_false(p.is_live())
	assert_null(p.stream)


# --- altın hash değişmezliği (HER ZAMAN) ----------------------------------------------------------------------


func test_g1_golden_fixture_still_holds_the_agreed_gunslinger_hashes() -> void:
	var fix := GoldenKit.load_fixture()
	for s in GOLDEN_U1B:
		var rec: Dictionary = fix["stages"]["u1b"]["gunslinger"][str(s)]
		assert_eq(int(rec["hash"]), GOLDEN_U1B[s], "u1b kaydı tohum %d" % s)


func test_g1_live_gunslinger_run_still_matches_the_golden_hash() -> void:
	var s: int = GOLDEN_U1B.keys()[0]
	var got := GoldenKit.run(s, &"gunslinger")
	assert_eq(int(got["hash"]), GOLDEN_U1B[s], "görünüm işi sim'i değiştirmez (tohum %d)" % s)
	assert_eq(int(got["state"]), 0, "koşu RUNNING bitti")
