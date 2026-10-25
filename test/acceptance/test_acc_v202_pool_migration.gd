extends GutTest
## Kabul (v2.0.2 K, P): Barutçu'nun kaldırılması ve kayıt göçü (plan U1b + test stratejisi "Barutçu göçü + negatifler,
## chars5 bayt değişmez"). Davranış: kayıtlı `karakter` Barutçu ise oyun Gunslinger ile açılır; başarım deposundaki
## `chars5` listesi hiç yeniden yazılmaz/filtrelenmez (bayt karşılaştırması); bozuk girdiler çökertmez.
## Yalnız geçici yollar kullanılır (user:// sızıntısı yok; after_each siler).

const SETTINGS_TMP := "user://test_acc_v202_mig_settings.cfg"
const STORE_TMP := "user://test_acc_v202_mig_ach.json"
const SettingsScript := preload("res://scripts/autoload/settings.gd")

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func after_each() -> void:
	for p in [SETTINGS_TMP, STORE_TMP, STORE_TMP + ".bad", STORE_TMP + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _store_json(chars5: Variant) -> String:
	return JSON.stringify(
		{
			"v": AchievementStore.VERSION,
			"unlocked": {},
			"totals": {"kills": 0, "runs": 0, "wins": 0, "play_secs": 0},
			"best": {"score": 0, "time": 0, "level": 0},
			"chars5": chars5
		}
	)


func test_p1_barutcu_is_gone_from_data_roster_and_files() -> void:
	if V202Slice.require(self, "P"):
		return
	assert_null(_data.get_character(&"barutcu"), "veride yok")
	assert_eq(CharacterRoster.ids(_data), [&"gunslinger", &"zyfen"] as Array[StringName])
	assert_false(
		FileAccess.file_exists("res://data/characters/barutcu.json"), "barutcu.json silindi"
	)
	assert_null(_data.get_skill(&"dinamit"), "dinamit kaldırıldı")
	assert_false(FileAccess.file_exists("res://data/skills/dinamit.json"), "dinamit.json silindi")


func test_p2_saved_barutcu_boots_as_gunslinger_and_survives_a_save_cycle() -> void:
	if V202Slice.require(self, "P"):
		return
	_write(SETTINGS_TMP, JSON.stringify({"karakter": "barutcu"}))
	var s: Node = autofree(SettingsScript.new())
	s.store_path = SETTINGS_TMP
	s.load_settings()
	assert_eq(CharacterRoster.resolve(s.character_id, _data, null), &"gunslinger")
	assert_true(s.save_settings(), "ayar yazılır")
	var s2: Node = autofree(SettingsScript.new())
	s2.store_path = SETTINGS_TMP
	s2.load_settings()
	assert_eq(
		CharacterRoster.resolve(s2.character_id, _data, null), &"gunslinger", "yeniden yükleme"
	)
	assert_ne(
		CharacterRoster.resolve(s2.character_id, _data, null), &"", "boş karakter kimliği yok"
	)


func test_p3_chars5_with_barutcu_is_byte_identical_after_load_and_save() -> void:
	if V202Slice.require(self, "P"):
		return
	var text := _store_json(["gunslinger", "barutcu"])
	_write(STORE_TMP, text)
	var st := AchievementStore.new(STORE_TMP)
	assert_true(st.load_file())
	assert_false(st.corrupt)
	assert_true(st.save())
	assert_eq(FileAccess.get_file_as_string(STORE_TMP), text, "bayt bayt aynı")
	assert_eq(AchievementProgress.of(_data.get_achievement(&"cifte_yol"), st), 2, "ilerleme 2")


func test_p4_new_run_of_zyfen_extends_chars5_without_dropping_barutcu() -> void:
	if V202Slice.require(self, "P"):
		return
	_write(STORE_TMP, _store_json(["barutcu"]))
	var st := AchievementStore.new(STORE_TMP)
	assert_true(st.load_file())
	assert_true(st.note_char5(&"zyfen"), "yeni karakter eklenir")
	assert_eq(Array(st.chars5), ["barutcu", "zyfen"], "eski kayıt korunur, sıra korunur")
	assert_false(st.note_char5(&"barutcu"), "aynı kimlik ikinci kez eklenmez")


func test_p5_bad_settings_and_store_shapes_never_crash_and_resolve_to_default() -> void:
	if V202Slice.require(self, "P"):
		return
	for text in [
		"", "{", "[1,2]", "not json", '{"karakter": 5}', '{"karakter": null}', '{"karakter": ""}'
	]:
		_write(SETTINGS_TMP, text)
		var s: Node = autofree(SettingsScript.new())
		s.store_path = SETTINGS_TMP
		s.load_settings()
		assert_eq(CharacterRoster.resolve(s.character_id, _data, null), &"gunslinger", text)
	for raw in ['"barutcu"', "null", "5", "[]", "[5, null, {}]", '{"a": 1}']:
		_write(STORE_TMP, '{"v":1,"unlocked":{},"totals":{},"best":{},"chars5":%s}' % raw)
		var st := AchievementStore.new(STORE_TMP)
		st.load_file()
		assert_false(st.corrupt, raw)
		assert_eq(st.chars5.size(), 0, raw)


func test_p6_path_traversal_and_spelling_variants_do_not_select_a_phantom_character() -> void:
	if V202Slice.require(self, "P"):
		return
	for saved in [
		"BARUTCU",
		"Barutcu",
		" barutcu",
		"../data/characters/barutcu",
		"barutcu\n",
		"zyfen/../barutcu"
	]:
		assert_eq(CharacterRoster.resolve(saved, _data, null), &"gunslinger", saved)


func _scan(dir: String, hits: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "json", "svg", "tscn", "tres", "cfg", "txt", "md"]:
			var t := FileAccess.get_file_as_string(dir.path_join(f))
			if t.findn("barutcu") >= 0 or t.findn("dinamit") >= 0:
				hits.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), hits)


func test_p7_no_barutcu_or_dynamite_reference_is_left_in_production_files() -> void:
	if V202Slice.require(self, "P"):
		return
	# Plan U1 kabul: `git grep -i -e barutcu -e dinamit` yalnız göç testleri, kart/tasarım belgesi ve chars5 fixture'ında kalır.
	# Üretim klasörleri (veri, betik, sahne, varlık) temiz olmalı.
	var hits: Array[String] = []
	for d in ["res://data", "res://scripts", "res://scenes", "res://assets", "res://themes"]:
		_scan(d, hits)
	assert_eq(hits, [] as Array[String], "üretim dosyalarında kalan Barutçu/dinamit anmaları")
