extends GutTest
## Kabul (v1.1 D3): yerel en iyi 10 - sıralama, rekor bilgisi, bozuk/yarım/sürümü bilinmeyen dosyalar, atomik yazma,
## tarih biçimi, denetleyicide tek yazma (H1-H10). Dilim D3 bitmeden pending.
## Review Focus 1: bozuk dosya oyunu açılmaktan alıkoymaz, liste boş görünür, sonraki kayıt dosyayı onarır.

const SLICE := "D3"
const UNIX := 1_700_000_000
const ROOT := "user://v11_hs_tests"

var _dir: String = ""
var _n: int = 0


func before_each() -> void:
	_n += 1
	_dir = "%s/%d_%d" % [ROOT, OS.get_process_id(), _n]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_all() -> void:
	_rm(ProjectSettings.globalize_path(ROOT))


func _rm(abs_path: String) -> void:
	for f in DirAccess.get_files_at(abs_path):
		DirAccess.remove_absolute(abs_path.path_join(f))
	for d in DirAccess.get_directories_at(abs_path):
		_rm(abs_path.path_join(d))
	DirAccess.remove_absolute(abs_path)


func _path() -> String:
	return _dir.path_join("highscores.json")


func _e(
	score: int, unix: int = UNIX, won: bool = false, time: int = 100, level: int = 5
) -> Dictionary:
	return {"score": score, "time": time, "won": won, "level": level, "unix": unix}


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _scores(hs: Highscores) -> Array[int]:
	var out: Array[int] = []
	for e in hs.entries:
		out.append(int(e["score"]))
	return out


## Hata günlüğü yazmadan ayrıştırır (JSON.parse_string bozuk girdide motor hatası basar); hata: null.
func _parse(path: String) -> Variant:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data


func _valid_file(path: String) -> bool:
	var v: Variant = _parse(path)
	return v is Dictionary and int(v.get("v", 0)) == 1 and v.get("entries") is Array


# --- H1 ------------------------------------------------------------------------------------------------------


func test_h1_first_score_is_rank_1_and_a_record_with_previous_best_zero() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	assert_false(hs.load_file(), "dosya yok")
	assert_eq(hs.entries.size(), 0)
	var r := hs.submit(_e(1234))
	assert_eq(r["rank"], 1)
	assert_true(r["is_record"])
	assert_eq(r["previous_best"], 0)
	assert_eq(r["index"], 0)
	assert_eq(r["needed_for_top10"], 0)
	assert_eq(_scores(hs), [1234] as Array[int])


func test_h1_second_score_record_flags_and_previous_best() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	hs.submit(_e(1000))
	var up := hs.submit(_e(5000, UNIX + 1))
	assert_eq(up["rank"], 1)
	assert_true(up["is_record"])
	assert_eq(up["previous_best"], 1000)
	var down := hs.submit(_e(300, UNIX + 2))
	assert_eq(down["rank"], 3)
	assert_false(down["is_record"])
	assert_eq(down["previous_best"], 5000)
	assert_eq(down["index"], 2)
	assert_eq(_scores(hs), [5000, 1000, 300] as Array[int])


# --- H2 / H7 -------------------------------------------------------------------------------------------------


func test_h2_eleven_entries_keep_ten_sorted_descending() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	for k in 11:
		hs.submit(_e(100 * (k + 1), UNIX + k))
	assert_eq(hs.entries.size(), 10, "en çok 10")
	var want: Array[int] = []
	for k in range(10, 0, -1):
		want.append(100 * (k + 1))
	assert_eq(_scores(hs), want, "azalan; en düşük (100) atıldı")


func test_h2_equal_scores_keep_the_older_entry_first() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	hs.submit(_e(500, UNIX))
	var r := hs.submit(_e(500, UNIX + 1000))
	assert_eq(r["rank"], 2, "eşit skorda yeni giriş eskinin arkasına")
	assert_false(r["is_record"], "rekoru eşitlemek rekor değildir")
	if hs.entries.size() >= 2:
		assert_eq(hs.entries[0]["unix"], UNIX)
		assert_eq(hs.entries[1]["unix"], UNIX + 1000)
	var same_unix := hs.submit(_e(500, UNIX))
	assert_eq(same_unix["rank"], 2, "unix de eşitse ekleme sırası (kararlı): eskilerden sonra")
	assert_true(same_unix["rank"] >= 2)


func test_h2_outside_top_ten_has_rank_zero_and_reports_tenth_score() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	for k in 10:
		hs.submit(_e(1000 - 100 * k, UNIX + k))  # 1000 .. 100
	var low := hs.submit(_e(50, UNIX + 99))
	assert_eq(low["rank"], 0)
	assert_false(low["is_record"])
	assert_eq(low["needed_for_top10"], 100, "10. sıranın skoru")
	assert_eq(low["index"], -1)
	assert_eq(hs.entries.size(), 10)
	var tie := hs.submit(_e(100, UNIX + 100))
	assert_eq(tie["rank"], 0, "10. ile eşit ama daha yeni: dışarıda")
	assert_eq(tie["needed_for_top10"], 100)
	var older_tie := hs.submit(_e(100, UNIX - 5))
	assert_gt(older_tie["rank"], 0, "10. ile eşit ve daha eski: girer")
	assert_eq(hs.entries.size(), 10)


func test_h7_needed_for_top10_is_zero_while_fewer_than_ten_entries() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	for k in 9:
		var r := hs.submit(_e(100 + k, UNIX + k))
		assert_eq(r["needed_for_top10"], 0, "%d. giriş" % (k + 1))
		assert_gt(r["rank"], 0)


# --- H3 ------------------------------------------------------------------------------------------------------


func test_h3_save_load_roundtrip_and_file_shape() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	hs.submit(_e(9000, UNIX + 1, true, 1290, 31))
	hs.submit(_e(4000, UNIX + 2, false, 301, 12))
	hs.submit(_e(7000, UNIX + 3, false, 720, 20))
	assert_true(hs.save())
	var raw: Variant = _parse(_path())
	assert_true(raw is Dictionary)
	if not raw is Dictionary:
		return
	assert_eq(int(raw["v"]), 1)
	assert_eq((raw["entries"] as Array).size(), 3)
	for e in raw["entries"]:
		var keys: Array = e.keys()
		keys.sort()
		assert_eq(keys, ["level", "score", "time", "unix", "won"], "giriş alan kümesi")
		assert_true(e["won"] is bool)
	assert_lt(FileAccess.get_file_as_bytes(_path()).size(), 2048, "< 2 KB")
	var back := Highscores.new(_path())
	assert_true(back.load_file())
	assert_eq(back.entries.size(), 3)
	for i in mini(3, mini(back.entries.size(), hs.entries.size())):
		assert_eq(int(back.entries[i]["score"]), int(hs.entries[i]["score"]))
		assert_eq(int(back.entries[i]["time"]), int(hs.entries[i]["time"]))
		assert_eq(int(back.entries[i]["level"]), int(hs.entries[i]["level"]))
		assert_eq(int(back.entries[i]["unix"]), int(hs.entries[i]["unix"]))
		assert_eq(bool(back.entries[i]["won"]), bool(hs.entries[i]["won"]))


# --- H4 / H6: bozuk dosyalar ---------------------------------------------------------------------------------


func test_h4_corrupt_variants_load_as_empty_keep_bad_copy_and_next_save_repairs() -> void:
	if V11Slice.require(self, SLICE):
		return
	var variants := {
		"bozuk JSON": '{"v":1,"entries":[',
		"yarım yazılmış": '{"v":1,"entries":[{"score":5,"time":',
		"sürüm 2": '{"v":2,"entries":[]}',
		"sürüm yok": '{"entries":[]}',
		"sürüm string": '{"v":"1","entries":[]}',
		"entries dizi değil": '{"v":1,"entries":{"a":1}}',
		"kök dizi": "[1,2,3]",
		"düz metin": "merhaba",
	}
	var failures := PackedStringArray()
	for label in variants:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path()))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path() + ".bad"))
		_write(_path(), variants[label])
		var hs := Highscores.new(_path())
		var ok := hs.load_file()
		if ok:
			failures.append("%s: load_file true döndü" % label)
		if hs.entries.size() != 0:
			failures.append("%s: liste boş değil" % label)
		if not hs.corrupt:
			failures.append("%s: corrupt bayrağı yok" % label)
		if not FileAccess.file_exists(_path() + ".bad"):
			failures.append("%s: .bad saklanmadı" % label)
		elif FileAccess.get_file_as_string(_path() + ".bad") != variants[label]:
			failures.append("%s: .bad içeriği özgün değil" % label)
		hs.submit(_e(777))
		if not hs.save() or not _valid_file(_path()):
			failures.append("%s: sonraki save dosyayı onarmadı" % label)
		var again := Highscores.new(_path())
		if not again.load_file() or _scores(again) != ([777] as Array[int]):
			failures.append("%s: onarılan dosya okunamadı" % label)
	assert_eq(failures.size(), 0, str(failures))


func test_h4_empty_file_opens_as_empty_list_and_is_repaired_by_save() -> void:
	if V11Slice.require(self, SLICE):
		return
	_write(_path(), "")
	var hs := Highscores.new(_path())
	assert_false(hs.load_file())
	assert_eq(hs.entries.size(), 0)
	hs.submit(_e(10))
	assert_true(hs.save())
	assert_true(_valid_file(_path()))


func test_h4_single_bad_entries_are_dropped_the_rest_survive() -> void:
	if V11Slice.require(self, SLICE):
		return
	var body := (
		'{"v":1,"entries":['
		+ '{"score":300,"time":90,"won":true,"level":9,"unix":1700000100},'
		+ '"metin",'
		+ '{"score":"yüz","time":90,"won":false,"level":3,"unix":1700000200},'
		+ '{"score":-5,"time":90,"won":false,"level":3,"unix":1700000200},'
		+ '{"score":50,"time":90,"won":false,"level":3},'
		+ '{"score":60,"time":90,"won":"evet","level":3,"unix":1700000200},'
		+ '{"score":70,"time":-1,"won":false,"level":3,"unix":1700000200},'
		+ '{"score":100,"time":45,"won":false,"level":2,"unix":1700000300}'
		+ "]}"
	)
	_write(_path(), body)
	var hs := Highscores.new(_path())
	assert_true(hs.load_file(), "geçerli giriş var: yükleme başarılı")
	assert_eq(_scores(hs), [300, 100] as Array[int], "yalnız geçerli girişler (tek tek atılır)")


func test_h4_oversized_score_is_clamped_to_display_cap() -> void:
	if V11Slice.require(self, SLICE):
		return
	_write(
		_path(),
		'{"v":1,"entries":[{"score":999999999999,"time":9,"won":true,"level":1,"unix":1700000000}]}'
	)
	var hs := Highscores.new(_path())
	hs.load_file()
	assert_eq(hs.entries.size(), 1)
	if hs.entries.size() == 1:
		assert_eq(int(hs.entries[0]["score"]), ExpectedTablesV11.DISPLAY_CAP)
	var r := hs.submit(_e(2_000_000_000))
	if not hs.entries.is_empty():
		assert_eq(int(hs.entries[0]["score"]), ExpectedTablesV11.DISPLAY_CAP, "submit de kırpar")
	assert_gt(r["rank"], 0)


func test_h4_sanitize_is_static_and_rejects_non_array_input() -> void:
	if V11Slice.require(self, SLICE):
		return
	assert_eq(Highscores.sanitize(null).size(), 0)
	assert_eq(Highscores.sanitize("x").size(), 0)
	assert_eq(Highscores.sanitize({"a": 1}).size(), 0)
	var ok := Highscores.sanitize([_e(5), {"score": 1}, 7, _e(6)])
	assert_eq(ok.size(), 2)


func test_h6_stale_half_written_tmp_is_ignored_on_load() -> void:
	if V11Slice.require(self, SLICE):
		return
	_write(_path() + ".tmp", '{"v":1,"entries":[{"score":99,')
	var none := Highscores.new(_path())
	assert_false(none.load_file(), "ana dosya yok: .tmp okunmaz")
	assert_eq(none.entries.size(), 0)
	assert_false(none.corrupt, ".tmp bozuk dosya sayılmaz")
	var good := Highscores.new(_path())
	good.submit(_e(321))
	assert_true(good.save())
	_write(_path() + ".tmp", "çöp")
	var again := Highscores.new(_path())
	assert_true(again.load_file())
	assert_eq(_scores(again), [321] as Array[int], "geçerli ana dosya, çöp .tmp'ye rağmen")
	assert_false(again.corrupt)


func test_h6_save_goes_through_tmp_and_leaves_no_tmp_behind() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	hs.submit(_e(10))
	assert_true(hs.save())
	assert_false(FileAccess.file_exists(_path() + ".tmp"), "rename sonrası .tmp kalmaz")
	assert_true(_valid_file(_path()))
	hs.submit(_e(20, UNIX + 1))
	_write(_path() + ".tmp", "yarım")  # önceki çökmeden kalan artık
	assert_true(hs.save(), "artık .tmp üzerine yazılır")
	assert_true(_valid_file(_path()))
	assert_false(FileAccess.file_exists(_path() + ".tmp"))


# --- H5 ------------------------------------------------------------------------------------------------------


func test_h5_missing_file_is_empty_and_unwritable_path_fails_softly() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_dir.path_join("hic_yok.json"))
	assert_false(hs.load_file())
	assert_eq(hs.entries.size(), 0)
	assert_false(hs.corrupt)
	var blocker := _dir.path_join("engel")
	_write(blocker, "dosya")  # dizin olması gereken yol bir dosya
	var bad := Highscores.new(blocker.path_join("highscores.json"))
	bad.submit(_e(5))
	assert_false(bad.save(), "yazılamayan yol: false, çökme yok")
	assert_eq(_scores(bad), [5] as Array[int], "bellekteki liste korunur (oyun devam eder)")


# --- H8 ------------------------------------------------------------------------------------------------------


func test_h8_format_date_uses_local_time_from_utc_plus_bias() -> void:
	if V11Slice.require(self, SLICE):
		return
	assert_eq(Highscores.format_date(UNIX, 180), "15.11.2023", "UTC 14.11 22:13 + 3 sa = 15.11")
	assert_eq(Highscores.format_date(UNIX, 0), "14.11.2023")
	assert_eq(Highscores.format_date(UNIX, -300), "14.11.2023")
	assert_eq(Highscores.format_date(1_704_067_200, 0), "01.01.2024", "sıfır dolgulu")
	assert_eq(Highscores.format_date(1_704_067_200, -1), "31.12.2023", "gün/yıl geri taşar")
	assert_eq(Highscores.format_date(1_709_164_800, 0), "29.02.2024", "artık gün")


# --- H10 -----------------------------------------------------------------------------------------------------


func test_h10_zero_or_negative_score_is_not_recorded() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hs := Highscores.new(_path())
	for s in [0, -10]:
		var r := hs.submit(_e(s))
		assert_eq(r["rank"], 0, "skor %d" % s)
		assert_false(r["is_record"])
	assert_eq(hs.entries.size(), 0)
	hs.submit(_e(40))
	var z := hs.submit(_e(0))
	assert_eq(z["rank"], 0)
	assert_eq(hs.entries.size(), 1)


# --- H9: denetleyicide tek yazma -----------------------------------------------------------------------------


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}  # v2.0 izolasyon: yazılamaz yol, gerçek dosya oluşmaz
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	c.highscores = Highscores.new(_path())
	return c


func _die_after(c: GameController, steps: int) -> void:
	for i in steps:
		c.sim.step(Vector2.ZERO)
		c._after_step()
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c._after_step()


func _stored() -> Highscores:
	var hs := Highscores.new(_path())
	hs.load_file()
	return hs


func test_h9_run_ended_writes_the_record_exactly_once_before_the_result_screen() -> void:
	if V11Slice.require(self, SLICE):
		return
	var c := _controller()
	c.start_run()
	_die_after(c, 130)
	assert_eq(c.sim.state, GameSim.State.LOST)
	var stored := _stored()
	assert_eq(
		stored.entries.size(), 1, "run_ended işleyicisinde yazıldı (ekran gecikmesi beklenmeden)"
	)
	if stored.entries.is_empty():
		return
	var e: Dictionary = stored.entries[0]
	assert_eq(int(e["score"]), c.sim.score.total())
	assert_eq(int(e["time"]), floori(c.sim.time), "time tam saniye (floori)")
	assert_eq(int(e["level"]), c.sim.level)
	assert_false(bool(e["won"]))
	assert_between(
		float(e["unix"]),
		Time.get_unix_time_from_system() - 10.0,
		Time.get_unix_time_from_system() + 10.0
	)
	# Gecikme/atlama/arka plan: ikinci yazma yok.
	for i in 6:
		c._process(0.5)
	c._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	c._on_back()
	assert_eq(_stored().entries.size(), 1, "gecikme + atlamalar sonrası hâlâ tek kayıt")


func test_h9_replay_after_result_writes_the_new_run_only_once() -> void:
	if V11Slice.require(self, SLICE):
		return
	var c := _controller()
	c.start_run()
	_die_after(c, 130)
	for i in 6:
		c._process(0.5)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	c.start_run()
	_die_after(c, 200)
	for i in 6:
		c._process(0.5)
	assert_eq(_stored().entries.size(), 2, "iki koşu = iki kayıt (tekrar oyna ikinci yazma yapmaz)")


func test_h10_zero_score_run_writes_nothing() -> void:
	if V11Slice.require(self, SLICE):
		return
	var c := _controller()
	c.start_run()
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c._after_step()
	assert_eq(c.sim.score.total(), 0)
	assert_eq(_stored().entries.size(), 0)
