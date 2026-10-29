extends GutTest
## R8: dört reducer eklentisi (hasara kadar süre, farklı elit türleri, buff koşulu, 5 dk'da farklı karakter) doğrudan.


func after_each() -> void:
	AchKit.cleanup()


func _state(extra: Dictionary = {}) -> Dictionary:
	var s := {"value": 0}
	s.merge(extra)
	return s


func test_clean_secs_rises_with_time_until_first_damage() -> void:
	var r := CleanSecsReducer.new()
	var st := _state()
	r.reset(st)
	var sim := SimKit.make(1, {"log_events": false})
	sim.time = 40.0
	r.poll(sim, st)
	assert_eq(r.value(st), 40)
	r.on_event(&"player_damaged", {}, st)
	sim.time = 90.0
	r.poll(sim, st)
	assert_eq(r.value(st), 40, "hasardan sonra donar")
	r.reset(st)
	assert_eq(r.value(st), 0)


func test_elite_kinds_counts_distinct_kinds_only() -> void:
	var r := EliteKindsReducer.new()
	var st := _state()
	r.reset(st)
	for t in [&"elit_piyade", &"elit_piyade", &"elit_karga", &"curumus_piyade", &"elit_piyade"]:
		r.on_event(&"enemy_killed", {"type_id": t}, st)
	assert_eq(r.value(st), 2)
	r.on_event(&"enemy_killed", {"type_id": &"elit_sovalye"}, st)
	assert_eq(r.value(st), 3)
	r.on_event(&"level_up", {"type_id": &"elit_sovalye"}, st)  # başka olay yok sayılır
	assert_eq(r.value(st), 3)


func test_unlimited_kills_only_while_buff_and_refresh_keeps_count() -> void:
	var r := UnlimitedKillsReducer.new()
	var st := _state()
	r.reset(st)
	r.on_event(&"enemy_killed", {"type_id": &"x"}, st)
	assert_eq(r.value(st), 0, "buff yokken sayılmaz")
	r.on_event(&"buff_started", {"kind": &"unlimited"}, st)
	for _i in 3:
		r.on_event(&"enemy_killed", {"type_id": &"x"}, st)
	r.on_event(&"buff_started", {"kind": &"unlimited"}, st)  # yenileme
	assert_eq(r.value(st), 3, "yenileme sıfırlamaz")
	r.on_event(&"buff_started", {"kind": &"damage"}, st)
	r.on_event(&"buff_ended", {"kind": &"damage"}, st)
	r.on_event(&"enemy_killed", {"type_id": &"x"}, st)
	assert_eq(r.value(st), 4, "başka buff etkisiz")
	r.on_event(&"buff_ended", {"kind": &"unlimited"}, st)
	r.on_event(&"enemy_killed", {"type_id": &"x"}, st)
	assert_eq(r.value(st), 4, "bitince sayılmaz")
	r.on_event(&"buff_started", {"kind": &"unlimited"}, st)
	assert_eq(r.value(st), 0, "yeni buff sıfırlar")


func test_chars_five_adds_only_for_long_runs_and_counting_rules() -> void:
	var r := CharsFiveReducer.new()
	var store := AchievementStore.new(AchKit.tmp_path())
	var st := _state({"store": store, "char_id": &"gunslinger"})
	assert_eq(r.value(st), 0)
	assert_eq(r.finish({"time": 299, "counts_chars5": true}, st), -1, "5 dk altı")
	assert_eq(r.finish({"time": 400, "counts_chars5": false}, st), -1, "kural saymıyor")
	assert_eq(r.finish({"time": 300, "counts_chars5": true}, st), 1)
	assert_eq(r.finish({"time": 500, "counts_chars5": true}, st), 1, "aynı karakter tek sayılır")
	st["char_id"] = &"zyfen"
	assert_eq(r.finish({"time": 500, "counts_chars5": true}, st), 2)
	assert_eq(r.value(st), 2)


func test_chars_five_value_without_store_is_zero() -> void:
	assert_eq(CharsFiveReducer.new().value({}), 0)
