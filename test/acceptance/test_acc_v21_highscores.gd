extends GutTest
## Kabul (v2.1 K): highscore ayrımı ve kayıt göçü (spec senaryo 9, K5-A, plan K-C6). (mod, zorluk) başına ayrı en iyi 10;
## v1 dosyası -> v2 (`{"v":2,"lists":{"<mod>:<zorluk>":[...]}}`), v1 girişleri `normal:normal`; `.v1.bak` + atomik yazım;
## bozuk v2 dosyası çökertmez. Ayrım testleri (sep*) controller'a kadar C'den beri koşar; göç testleri (v21k1-v21k13, v21k20) V21Slice "K" açılana
## dek pending. VARSAYIM: göç `load_file()` sırasında (ya da en geç sonraki `save()`'de) yapılır; testler ikisini de
## karşılamak için göçten sonra `save()` çağırır. Yalnız geçici yollar (user:// sızıntısı yok; after_all siler).

const ROOT := "user://v21_hs_acc"
const FIX := "res://test/fixtures/hs_v1/"
const UNIX := 1_700_000_000

var _dir: String = ""
var _n: int = 0


func before_each() -> void:
	_n += 1
	_dir = "%s/%d_%d" % [ROOT, OS.get_process_id(), _n]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_each() -> void:
	V21Kit.clear_fake_settings()


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


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## Fixture'ı geçici yola kopyalar; ham metni döner.
func _install(fixture: String) -> String:
	var text := FileAccess.get_file_as_string(FIX + fixture)
	assert_ne(text, "", "fixture okundu: %s" % fixture)
	_write(_path(), text)
	return text


func _e(score: int, mode: String, diff: String, unix: int = UNIX) -> Dictionary:
	return {
		"score": score,
		"time": 60,
		"won": false,
		"level": 3,
		"unix": unix,
		"mode": mode,
		"diff": diff
	}


func _scores(list: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for e in list:
		out.append(int(e["score"]))
	return out


func _bak_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(_dir)):
		if (
			f != "highscores.json.v1.bak"
			and f.begins_with("highscores.json.v1.")
			and f.ends_with(".bak")
		):
			out.append(f)
	return out


func _migrate() -> Highscores:
	var h := Highscores.new(_path())
	h.load_file()
	h.save()
	return h


func _controller(fake_mode: String, fake_diff: String) -> GameController:
	var fake := V21Kit.use_fake_settings()
	fake.run_mode = fake_mode
	fake.run_diff = fake_diff
	var c := GameController.new()
	c.v2_opts = {"achievements_path": _dir.path_join("ach.json")}
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.highscores = Highscores.new(_path())
	add_child_autofree(c)
	c.start_run()
	return c


func _die(c: GameController) -> void:
	c.sim.score.on_kill(&"elit_karga", c.sim.step_count)  # skor > 0: Highscores sıfır skoru kabul etmez
	for i in 30:
		c.sim.step(Vector2.ZERO)
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c._after_step()


# --- Ayrım (controller dahil) ------------------------------------------------------------------


func test_sep1_each_mode_difficulty_pair_has_its_own_ten() -> void:
	var h := Highscores.new(_path())
	var pairs := [["normal", "normal"], ["normal", "hard"], ["quick", "easy"], ["endless", "hard"]]
	for p in pairs:
		for i in 12:
			h.submit(_e(1000 + i, p[0], p[1]))
	for p in pairs:
		var list := h.list_for(StringName(p[0]), StringName(p[1]))
		assert_eq(list.size(), 10, "%s:%s en iyi 10" % p)
		assert_eq(list[0]["score"], 1011)
		assert_eq(list[9]["score"], 1002)
	assert_eq(h.list_for(&"quick", &"hard").size(), 0, "dokunulmayan çift boş")
	assert_eq(h.list_for(&"normal", &"normal").size(), 10, "normal:normal da kendi 10'u")


func test_sep2_a_finished_run_lands_in_the_list_of_its_own_mode_and_difficulty() -> void:
	var c := _controller("quick", "easy")
	_die(c)
	assert_eq(c.highscores.list_for(&"quick", &"easy").size(), 1, "biten koşunun listesi")
	assert_eq(c.highscores.list_for(&"normal", &"normal").size(), 0, "varsayılan liste karışmadı")
	assert_eq(c.highscores.list_for(&"normal", &"hard").size(), 0)


func test_v21k20_the_saved_entry_carries_its_mode_and_difficulty() -> void:
	if V21Slice.require(self, "K"):  # giriş alanları v2 biçimiyle (U3) kalıcı olur
		return
	var c := _controller("quick", "easy")
	_die(c)
	var e: Dictionary = c.highscores.list_for(&"quick", &"easy")[0]
	assert_eq(e["mode"], "quick")
	assert_eq(e["diff"], "easy")


func test_sep3_changing_the_selection_mid_run_does_not_move_the_score() -> void:
	var c := _controller("endless", "normal")
	V21Runs.set_selection(&"quick", &"hard")  # koşu sürerken ayar değişti
	_die(c)
	assert_eq(c.highscores.list_for(&"endless", &"normal").size(), 1, "koşunun kendi çifti")
	assert_eq(c.highscores.list_for(&"quick", &"hard").size(), 0, "yeni seçim değil")


func test_sep4_open_scores_shows_the_pair_it_is_asked_for() -> void:
	var c := _controller("normal", "normal")
	c.highscores.submit(_e(777, "endless", "hard"))
	var key := V21Runs.scores_key(&"endless", &"hard")
	assert_eq(c.highscores.list_for(key["mode"], key["diff"])[0]["score"], 777)
	assert_eq(c.highscores.list_for(&"normal", &"normal").size(), 0)


# --- Kayıt göçü (K dilimi) ---------------------------------------------------------------------


func test_v21k1_v1_entries_become_the_normal_normal_list() -> void:
	if V21Slice.require(self, "K"):
		return
	_install("v1_full.json")
	var h := _migrate()
	var list := h.list_for(&"normal", &"normal")
	assert_eq(list.size(), 10, "10 giriş korundu")
	assert_eq(list[0]["score"], 100000)
	assert_eq(
		_scores(list), [100000, 93000, 86000, 79000, 72000, 65000, 58000, 51000, 44000, 37000]
	)
	assert_true(list[0]["won"])
	for e in list:
		assert_eq([e["mode"], e["diff"]], ["normal", "normal"], "giriş etiketi")
	for other in [[&"quick", &"easy"], [&"normal", &"hard"], [&"endless", &"normal"]]:
		assert_eq(h.list_for(other[0], other[1]).size(), 0, "%s:%s boş" % other)


func test_v21k2_migration_writes_the_v2_format_to_disk() -> void:
	if V21Slice.require(self, "K"):
		return
	_install("v1_full.json")
	_migrate()
	var doc: Variant = JSON.parse_string(_read(_path()))
	assert_true(doc is Dictionary, "geçerli JSON")
	assert_eq(int(doc["v"]), 2)
	assert_true(doc["lists"] is Dictionary)
	assert_eq((doc["lists"]["normal:normal"] as Array).size(), 10)
	assert_false(FileAccess.file_exists(_path() + ".tmp"), "yarım .tmp kalmadı")


func test_v21k3_the_v1_file_is_backed_up_byte_for_byte() -> void:
	if V21Slice.require(self, "K"):
		return
	var original := _install("v1_full.json")
	_migrate()
	assert_true(FileAccess.file_exists(_path() + ".v1.bak"), ".v1.bak yazıldı")
	assert_eq(_read(_path() + ".v1.bak"), original, "v1 baytları aynen")


func test_v21k4_an_existing_backup_is_never_overwritten() -> void:
	if V21Slice.require(self, "K"):
		return
	var original := _install("v1_full.json")
	_write(_path() + ".v1.bak", "ESKI YEDEK")
	_migrate()
	assert_eq(_read(_path() + ".v1.bak"), "ESKI YEDEK", "var olan yedek korunur")
	var extra := _bak_files()
	assert_eq(extra.size(), 1, "zaman damgalı ikinci yedek: %s" % [extra])
	if extra.size() == 1:
		assert_eq(_read(_dir.path_join(extra[0])), original)


func test_v21k5_migration_is_idempotent_and_does_not_rebackup() -> void:
	if V21Slice.require(self, "K"):
		return
	_install("v1_full.json")
	_migrate()
	var after_first := _read(_path())
	var h2 := _migrate()
	assert_eq(_read(_path()), after_first, "ikinci açılış aynı içerik")
	assert_eq(h2.list_for(&"normal", &"normal").size(), 10)
	assert_eq(_bak_files().size(), 0, "yeniden yedek alınmaz")


func test_v21k6_mixed_v1_keeps_the_valid_entries_and_drops_the_rest() -> void:
	if V21Slice.require(self, "K"):
		return
	_install("v1_mixed.json")
	var list := _migrate().list_for(&"normal", &"normal")
	assert_eq(_scores(list), [99999999, 5000, 5000], "tavan, bozuklar atıldı")
	assert_eq(list[1]["unix"], UNIX - 10, "eşit skorda eski giriş önde (kararlı)")
	assert_eq(list[2]["unix"], UNIX)


func test_v21k7_empty_and_missing_v1_files_do_not_crash() -> void:
	if V21Slice.require(self, "K"):
		return
	_install("v1_empty.json")
	var h := _migrate()
	assert_eq(h.list_for(&"normal", &"normal").size(), 0)
	assert_false(h.corrupt)
	var fresh := Highscores.new(_dir.path_join("yok.json"))
	assert_false(fresh.load_file(), "dosya yok: false")
	assert_eq(fresh.list_for(&"quick", &"easy").size(), 0)


func test_v21k8_v2_roundtrip_keeps_every_list_apart() -> void:
	if V21Slice.require(self, "K"):
		return
	var h := Highscores.new(_path())
	h.submit(_e(300, "normal", "normal"))
	h.submit(_e(500, "quick", "easy"))
	h.submit(_e(900, "endless", "hard"))
	h.submit(_e(100, "endless", "hard"))
	assert_true(h.save())
	var back := Highscores.new(_path())
	assert_true(back.load_file())
	assert_eq(_scores(back.list_for(&"normal", &"normal")), [300])
	assert_eq(_scores(back.list_for(&"quick", &"easy")), [500])
	assert_eq(_scores(back.list_for(&"endless", &"hard")), [900, 100])
	assert_eq(back.list_for(&"quick", &"hard").size(), 0)
	assert_eq(back.entries.size(), 1, "entries = normal:normal görünümü")


func test_v21k9_the_list_key_is_authoritative_over_entry_fields() -> void:
	if V21Slice.require(self, "K"):
		return
	var doc := {
		"v": 2,
		"lists":
		{
			"quick:easy":
			[
				{
					"score": 40,
					"time": 5,
					"won": false,
					"level": 1,
					"unix": UNIX,
					"mode": "endless",
					"diff": "hard"
				},
				{"score": 30, "time": 5, "won": false, "level": 1, "unix": UNIX},
			],
		},
	}
	_write(_path(), JSON.stringify(doc))
	var hs := Highscores.new(_path())
	hs.load_file()
	var got := hs.list_for(&"quick", &"easy")
	assert_eq(got.size(), 2)
	for e in got:
		assert_eq([e["mode"], e["diff"]], ["quick", "easy"], "anahtara göre yeniden yazıldı")
	assert_eq(hs.list_for(&"endless", &"hard").size(), 0, "giriş alanı listeyi değiştirmez")


func test_v21k10_unknown_list_keys_are_preserved_for_forward_compat() -> void:
	if V21Slice.require(self, "K"):
		return
	var doc := {
		"v": 2,
		"lists":
		{
			"normal:normal": [{"score": 10, "time": 1, "won": false, "level": 1, "unix": UNIX}],
			"turbo:cetin": [{"score": 77, "time": 1, "won": false, "level": 1, "unix": UNIX}],
		},
	}
	_write(_path(), JSON.stringify(doc))
	var h := Highscores.new(_path())
	h.load_file()
	h.submit(_e(20, "normal", "normal"))
	assert_true(h.save())
	var saved: Dictionary = JSON.parse_string(_read(_path()))
	assert_true(saved["lists"].has("turbo:cetin"), "bilinmeyen liste silinmedi")
	assert_eq(int(saved["lists"]["turbo:cetin"][0]["score"]), 77)
	assert_eq(_scores(h.list_for(&"normal", &"normal")), [20, 10])


func test_v21k11_corrupt_v2_files_open_empty_and_keep_a_bad_copy() -> void:
	if V21Slice.require(self, "K"):
		return
	var bodies := [
		"{ yarım",
		JSON.stringify({"v": "2", "lists": {}}),
		JSON.stringify({"v": 2}),
		JSON.stringify({"v": 2, "lists": [1, 2]}),
		JSON.stringify([1, 2, 3]),
	]
	for body: String in bodies:
		_write(_path(), body)
		DirAccess.remove_absolute(_path() + ".bad")
		var h := Highscores.new(_path())
		h.load_file()
		assert_true(h.corrupt, "bozuk sayıldı: %s" % body)
		assert_eq(h.list_for(&"normal", &"normal").size(), 0)
		assert_eq(_read(_path() + ".bad"), body, ".bad kopyası")
		assert_true(h.submit(_e(5, "quick", "easy"))["rank"] == 1, "oyun sürer, yazma çalışır")
		assert_true(h.save(), "sonraki kayıt dosyayı onarır")


func test_v21k12_oversized_and_dirty_lists_are_cleaned() -> void:
	if V21Slice.require(self, "K"):
		return
	var rows: Array = []
	for i in 14:
		rows.append({"score": 500 + (i % 7), "time": 1, "won": false, "level": 1, "unix": UNIX + i})
	rows.append({"score": 900, "time": -4, "won": false, "level": 1, "unix": UNIX})
	rows.append({"score": 800, "time": 1, "won": false, "level": 1})
	rows.append({"score": 1.0e20, "time": 1, "won": true, "level": 1, "unix": UNIX})
	_write(_path(), JSON.stringify({"v": 2, "lists": {"endless:easy": rows}}))
	var h := Highscores.new(_path())
	h.load_file()
	var list := h.list_for(&"endless", &"easy")
	assert_eq(list.size(), 10, "10'a kırpıldı")
	assert_eq(list[0]["score"], 99999999, "devasa skor tavana çekildi")
	for i in list.size() - 1:
		assert_gte(int(list[i]["score"]), int(list[i + 1]["score"]), "sıralı")
		if list[i]["score"] == list[i + 1]["score"]:
			assert_lte(int(list[i]["unix"]), int(list[i + 1]["unix"]), "eşitte eski önde")
	for e in list:
		assert_gte(int(e["time"]), 0, "negatif süre girişi atıldı")


func test_v21k13_all_helper_files_derive_from_the_injected_path() -> void:
	if V21Slice.require(self, "K"):
		return
	_install("v1_full.json")
	_migrate()
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(_dir)):
		assert_true(f.begins_with("highscores.json"), "yan dosya enjekte yoldan türer: %s" % f)
	assert_false(FileAccess.file_exists(_path() + ".tmp"))
