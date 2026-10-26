extends GutTest
## Kabul (v2.0 B1): AchievementStore + StoreIo kayıt davranışı. Plan "Veri ve kayıt" sözleşmesinden yazıldı (uygulama
## okunmadı). Dilim B bitmeden pending. Geçici yol: AchKit (user://test_ach_*), temizlik after_each.

const V := AchievementStore.VERSION


func after_each() -> void:
	AchKit.cleanup()


func _gate() -> bool:
	return V2Slice.require(self, "B")


func _raw(p: String, text: String) -> AchievementStore:
	AchKit.write_text(p, text)
	return AchievementStore.new(p)


func _assert_clean(st: AchievementStore, label: String) -> void:
	assert_eq(st.unlocked.size(), 0, label + ": unlocked boş")
	assert_eq(int(st.totals.get("kills", -1)), 0, label + ": kills 0")
	assert_eq(int(st.best.get("score", -1)), 0, label + ": best.score 0")
	assert_eq(st.chars5.size(), 0, label + ": chars5 boş")


func test_b1_missing_file_is_not_corrupt() -> void:
	if _gate():
		return
	var st := AchievementStore.new(AchKit.tmp_path())
	assert_false(st.load_file())
	assert_false(st.corrupt)
	_assert_clean(st, "yok")


func test_b1_empty_file_resets_and_keeps_no_bad_backup() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var st := _raw(p, "")
	assert_false(st.load_file())
	assert_false(FileAccess.file_exists(p + ".bad"), "boş içerik .bad olarak saklanmaz")
	_assert_clean(st, "boş")


func test_b1_truncated_json_is_corrupt_and_saved_as_bad() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var broken := '{"v":1,"unlocked":{"ilk_kan":17'
	var st := _raw(p, broken)
	assert_false(st.load_file())
	assert_true(st.corrupt)
	assert_true(FileAccess.file_exists(p + ".bad"), ".bad yedeği")
	assert_eq(AchKit.read_text(p + ".bad"), broken, "yedek özgün içerik")
	_assert_clean(st, "yarım")


func test_b1_wrong_version_is_rejected_and_state_reset() -> void:
	if _gate():
		return
	# v2.0.3: v2 artık geçerli sürüm; tanınmayan sürüm v3
	var st := _raw(AchKit.tmp_path(), '{"v":3,"unlocked":{"ilk_kan":5},"totals":{"kills":9}}')
	assert_false(st.load_file())
	assert_false(st.is_unlocked(&"ilk_kan"))
	_assert_clean(st, "v:3")


func test_b1_root_array_is_corrupt() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var st := _raw(p, "[1,2,3]")
	assert_false(st.load_file())
	assert_true(st.corrupt)
	assert_true(FileAccess.file_exists(p + ".bad"))
	_assert_clean(st, "kök dizi")


func test_b1_unlocked_as_array_is_ignored_not_crash() -> void:
	if _gate():
		return
	var st := _raw(AchKit.tmp_path(), '{"v":1,"unlocked":["ilk_kan"],"totals":{"kills":3}}')
	st.load_file()
	assert_eq(st.unlocked.size(), 0)
	assert_false(st.is_unlocked(&"ilk_kan"))


func test_b1_wrong_typed_entries_are_dropped() -> void:
	if _gate():
		return
	var raw := (
		'{"v":1,"unlocked":{"a":"yarin","b":true,"c":null,"ok":1700000000},'
		+ '"totals":{"kills":"5","runs":true,"wins":null,"play_secs":[1]},'
		+ '"best":{"score":"x","time":{},"level":false},"chars5":[1,2,null,"gunslinger"]}'
	)
	var st := _raw(AchKit.tmp_path(), raw)
	assert_true(st.load_file())
	assert_true(st.is_unlocked(&"ok"))
	assert_false(st.is_unlocked(&"a"))
	assert_false(st.is_unlocked(&"b"))
	assert_false(st.is_unlocked(&"c"))
	for k in ["kills", "runs", "wins", "play_secs"]:
		assert_eq(int(st.totals.get(k, -1)), 0, "yanlış tipli total " + k)
	for k in ["score", "time", "level"]:
		assert_eq(int(st.best.get(k, -1)), 0, "yanlış tipli best " + k)
	assert_eq(Array(st.chars5), ["gunslinger"], "chars5 yalnız dizgeler")


func test_b1_negative_values_are_not_accepted() -> void:
	if _gate():
		return
	var st := _raw(
		AchKit.tmp_path(),
		'{"v":1,"unlocked":{"a":-5,"b":0},"totals":{"kills":-3},"best":{"score":-1}}'
	)
	st.load_file()
	assert_false(st.is_unlocked(&"a"), "negatif unix")
	assert_false(st.is_unlocked(&"b"), "unix < 1")
	assert_gte(int(st.totals.get("kills", 0)), 0)
	assert_gte(int(st.best.get("score", 0)), 0)


func test_b1_sanitize_rejects_nan_inf_and_fractions() -> void:
	if _gate():
		return
	var out := (
		AchievementStore
		. sanitize(
			{
				"v": 1,
				"unlocked": {"a": NAN, "b": INF, "c": 1.5, "d": 1700000000.0},
				"totals": {"kills": NAN, "runs": INF, "wins": 2.5, "play_secs": 7.0},
				"best": {"score": -INF, "time": 3.25, "level": 4.0},
				"chars5": [],
			}
		)
	)
	var un: Dictionary = out.get("unlocked", {})
	assert_false(un.has(&"a") or un.has("a"), "NaN reddedilir")
	assert_false(un.has(&"b") or un.has("b"), "inf reddedilir")
	assert_false(un.has(&"c") or un.has("c"), "kesirli reddedilir")
	assert_true(un.has(&"d") or un.has("d"), "tamsayı değerli float kabul")
	var t: Dictionary = out.get("totals", {})
	assert_eq(int(t.get("kills", 0)), 0)
	assert_eq(int(t.get("runs", 0)), 0)
	assert_eq(int(t.get("wins", 0)), 0, "2.5 reddedilir")
	assert_eq(int(t.get("play_secs", 0)), 7)
	var b: Dictionary = out.get("best", {})
	assert_eq(int(b.get("time", 0)), 0)
	assert_eq(int(b.get("level", 0)), 4)


func test_b1_sanitize_non_dictionary_root_is_empty() -> void:
	if _gate():
		return
	assert_eq(AchievementStore.sanitize([1]), {})
	assert_eq(AchievementStore.sanitize("x"), {})
	assert_eq(AchievementStore.sanitize(null), {})
	assert_eq(AchievementStore.sanitize(3), {})


func test_b1_counter_cap_clamps_raw_int_below_int_limit() -> void:
	if _gate():
		return
	# Plan B1: sayaç COUNTER_CAP'e kırpılır; ham int INT_LIMIT (1e15) üstü ayrı durumdur ve atılır.
	var st := _raw(AchKit.tmp_path(), '{"v":1,"totals":{"kills":900000000000000}}')
	st.load_file()
	assert_eq(
		int(st.totals["kills"]), AchievementStore.COUNTER_CAP, "INT_LIMIT altı ham int kırpılır"
	)


func test_b1_raw_int_above_int_limit_is_dropped() -> void:
	if _gate():
		return
	var st := _raw(AchKit.tmp_path(), '{"v":1,"totals":{"kills":10000000000000000}}')
	st.load_file()
	assert_eq(int(st.totals.get("kills", 0)), 0, "1e15 üstü ham int atılır")


func test_b1_huge_float_never_exceeds_cap_or_goes_negative() -> void:
	if _gate():
		return
	var st := _raw(AchKit.tmp_path(), '{"v":1,"totals":{"kills":1e16,"runs":-1e16}}')
	st.load_file()
	assert_lte(int(st.totals["kills"]), AchievementStore.COUNTER_CAP)
	assert_gte(int(st.totals["kills"]), 0)
	assert_eq(int(st.totals["runs"]), 0, "-1e16 sıfır ya da reddedilir")


func test_b1_add_total_clamps_to_cap() -> void:
	if _gate():
		return
	var st := AchKit.store()
	st.add_total(&"kills", AchievementStore.COUNTER_CAP - 1)
	st.add_total(&"kills", 50)
	assert_eq(int(st.totals["kills"]), AchievementStore.COUNTER_CAP)
	assert_true(st.dirty)


func test_b1_unknown_id_is_preserved_through_roundtrip() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var st := _raw(p, '{"v":1,"unlocked":{"gelecek_basarim":1700000001}}')
	assert_true(st.load_file())
	assert_true(st.is_unlocked(&"gelecek_basarim"), "bilinmeyen kimlik korunur")
	st.dirty = true
	assert_true(st.save())
	var again := AchievementStore.new(p)
	assert_true(again.load_file())
	assert_eq(again.unlocked_at(&"gelecek_basarim"), 1700000001)


func test_b1_65th_id_is_rejected_with_sorted_processing() -> void:
	if _gate():
		return
	var d := {}
	# Eklenme sırası karışık; sıralı işleme: a00..a63 kabul, a64..a69 red.
	for i in range(69, -1, -1):
		d["a%02d" % i] = 1700000000 + i
	var st := _raw(AchKit.tmp_path(), JSON.stringify({"v": 1, "unlocked": d}))
	assert_true(st.load_file())
	assert_eq(st.unlocked.size(), AchievementStore.MAX_UNLOCKED)
	assert_true(st.is_unlocked(&"a00"))
	assert_true(st.is_unlocked(&"a63"))
	assert_false(st.is_unlocked(&"a64"), "65. ve sonrası reddedilir (sıralı işleme)")
	assert_false(st.is_unlocked(&"a69"))


func test_b1_unlock_beyond_max_returns_false() -> void:
	if _gate():
		return
	var st := AchKit.store()
	for i in AchievementStore.MAX_UNLOCKED:
		assert_true(st.unlock(StringName("x%02d" % i), 1700000000), "x%02d" % i)
	assert_false(st.unlock(&"fazla", 1700000000), "65. açılış reddedilir")
	assert_false(st.is_unlocked(&"fazla"))


func test_b1_chars5_is_unique_and_bounded() -> void:
	if _gate():
		return
	var st := AchKit.store()
	assert_true(st.note_char5(&"gunslinger"))
	assert_false(st.note_char5(&"gunslinger"), "tekrar eklenmez")
	assert_eq(st.chars5.size(), 1)
	for i in 30:
		st.note_char5(StringName("c%02d" % i))
	assert_lte(st.chars5.size(), AchievementStore.MAX_CHARS5)
	var raw: Array = []
	for i in 40:
		raw.append("k%d" % (i % 25))
	var out := AchievementStore.sanitize({"v": 1, "chars5": raw})
	var seen := {}
	for c in out.get("chars5", []):
		assert_false(seen.has(c), "yinelenen yok: %s" % c)
		seen[c] = true
	assert_lte(out.get("chars5", []).size(), AchievementStore.MAX_CHARS5)


func test_b1_tmp_file_is_never_read() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	AchKit.write_text(p + ".tmp", '{"v":1,"unlocked":{"ilk_kan":1700000000}}')
	var st := AchievementStore.new(p)
	assert_false(st.load_file())
	assert_false(st.is_unlocked(&"ilk_kan"))


func test_b1_file_over_max_bytes_is_corrupt_without_bad_copy() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var big := '{"v":1,"pad":"' + "x".repeat(StoreIo.MAX_BYTES + 10) + '"}'
	var st := _raw(p, big)
	assert_false(st.load_file())
	assert_true(st.corrupt)
	assert_false(FileAccess.file_exists(p + ".bad"), "256 KB üstü .bad yazılmaz")


func test_b1_roundtrip_and_file_layout() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var st := AchievementStore.new(p)
	assert_true(st.unlock(&"ilk_kan", 1700000005))
	st.add_total(&"kills", 12)
	st.add_total(&"runs", 2)
	st.add_total(&"wins", 1)
	st.add_total(&"play_secs", 600)
	st.note_best(1234, 301, 11)
	st.note_char5(&"gunslinger")
	assert_true(st.dirty)
	assert_true(st.save())
	assert_false(st.dirty, "başarılı save dirty'yi temizler")
	var j: Variant = JSON.parse_string(AchKit.read_text(p))
	assert_true(j is Dictionary)
	var d: Dictionary = j
	assert_eq(int(d.get("v", 0)), AchievementStore.VERSION_V2)
	for k in ["unlocked", "totals", "best", "chars5"]:
		assert_true(d.has(k), "kök anahtar " + k)
	assert_eq(int(d["unlocked"].get("ilk_kan", 0)), 1700000005)
	assert_eq(int(d["totals"].get("kills", 0)), 12)
	assert_eq(int(d["best"].get("time", 0)), 301)
	assert_eq(Array(d["chars5"]), ["gunslinger"])
	var again := AchievementStore.new(p)
	assert_true(again.load_file())
	assert_eq(again.unlocked_at(&"ilk_kan"), 1700000005)
	assert_eq(int(again.totals["play_secs"]), 600)
	assert_eq(int(again.best["score"]), 1234)
	assert_eq(int(again.best["level"]), 11)
	assert_eq(Array(again.chars5), ["gunslinger"])
	assert_false(again.dirty, "yükleme dirty bırakmaz")


func test_b1_save_file_stays_under_4kb_with_all_22_unlocked() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var st := AchievementStore.new(p)
	for r in ExpectedTablesV2.ACHIEVEMENTS:
		st.unlock(StringName(r[0]), 1700000000)
	st.add_total(&"kills", 999999999)
	st.add_total(&"play_secs", 999999999)
	st.note_best(999999999, 999999, 99)
	st.note_char5(&"gunslinger")
	st.note_char5(&"zyfen")
	assert_true(st.save())
	assert_lt(FileAccess.get_file_as_bytes(p).size(), 4096)


func test_b1_unwritable_path_returns_false_and_stays_dirty() -> void:
	if _gate():
		return
	var parent := AchKit.tmp_path("blk")
	AchKit.write_text(parent, "dosya")  # üst 'dizin' aslında dosya => yazılamaz
	var st := AchievementStore.new(parent + "/alt.json")
	st.add_total(&"kills", 1)
	assert_false(st.save())
	assert_true(st.dirty, "başarısız save dirty'yi korur")


func test_b1_rename_failure_cleans_tmp_and_retry_succeeds() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path("dir")
	var abs_p := ProjectSettings.globalize_path(p)
	DirAccess.make_dir_recursive_absolute(abs_p.path_join("dolu"))  # hedef boş olmayan dizin => rename başarısız
	var st := AchievementStore.new(p)
	st.add_total(&"kills", 3)
	assert_false(st.save())
	assert_false(FileAccess.file_exists(p + ".tmp"), "başarısızlıkta .tmp silinir")
	assert_true(st.dirty)
	AchKit.cleanup()  # engeli kaldır (dizin dahil)
	AchKit.track(p)
	assert_true(st.save(), "sonraki save yeniden dener")
	assert_false(st.dirty)
	assert_true(FileAccess.file_exists(p))
	AchKit.cleanup()


func test_b1_unlock_zero_or_negative_unix_is_rejected() -> void:
	if _gate():
		return
	var st := AchKit.store()
	assert_false(st.unlock(&"ilk_kan", 0))
	assert_false(st.unlock(&"ilk_kan", -4))
	assert_false(st.is_unlocked(&"ilk_kan"))
	assert_eq(st.unlocked_at(&"ilk_kan"), 0, "kilitli = 0")


func test_b1_second_unlock_keeps_first_timestamp() -> void:
	if _gate():
		return
	var st := AchKit.store()
	assert_true(st.unlock(&"ilk_kan", 1700000001))
	assert_false(st.unlock(&"ilk_kan", 1700000999), "zaten açık")
	assert_eq(st.unlocked_at(&"ilk_kan"), 1700000001)


func test_b1_note_best_keeps_per_field_maximum() -> void:
	if _gate():
		return
	var st := AchKit.store()
	st.note_best(100, 50, 3)
	st.note_best(40, 90, 2)
	assert_eq(int(st.best["score"]), 100)
	assert_eq(int(st.best["time"]), 90)
	assert_eq(int(st.best["level"]), 3)


func test_b1_count_unlocked_counts_only_known() -> void:
	if _gate():
		return
	var st := AchKit.store()
	st.unlock(&"ilk_kan", 1700000000)
	st.unlock(&"bes_dakika", 1700000000)
	st.unlock(&"gelecek", 1700000000)
	var known: Array[StringName] = [&"ilk_kan", &"bes_dakika", &"seviye_10"]
	assert_eq(st.count_unlocked(known), 2)
	var none: Array[StringName] = []
	assert_eq(st.count_unlocked(none), 0)


func test_b1_totals_do_not_hit_disk_until_save() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var st := AchievementStore.new(p)
	st.add_total(&"kills", 5)
	assert_false(FileAccess.file_exists(p), "add_total diske yazmaz")
	assert_true(st.dirty)


func test_b1_repair_after_corruption_new_save_is_valid() -> void:
	if _gate():
		return
	var p := AchKit.tmp_path()
	var st := _raw(p, "{bozuk")
	assert_false(st.load_file())
	assert_true(st.corrupt)
	st.add_total(&"kills", 2)
	assert_true(st.save())
	var again := AchievementStore.new(p)
	assert_true(again.load_file(), "onarım: yeni dosya geçerli")
	assert_eq(int(again.totals["kills"]), 2)
	assert_true(FileAccess.file_exists(p + ".bad"), "eski bozuk içerik yedekte kalır")
