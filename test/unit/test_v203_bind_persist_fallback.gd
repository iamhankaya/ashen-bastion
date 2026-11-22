extends GutTest
## F-ashen-bastion-170: bind_persist, metrik kaydı `persist` anahtarını (ya da bir yarısını) vermediğinde yerleşik stat'ın
## sabit tablo anahtarını (TOTAL_KEY/BEST_KEY) silmez; veri verdiği anahtar yerleşiğin üstüne yazar.


func _def(stat: String) -> AchievementDef:
	return AchievementDef.from_dict({"id": "x", "stat": stat})


func test_builtin_total_key_survives_persist_without_total() -> void:
	var a := _def("total_kills")
	assert_eq(a.total_key, "kills", "ön koşul: yerleşik anahtar")
	a.bind_persist([{"stat": "total_kills", "persist": {"best": "kills_best"}}])
	assert_eq(a.total_key, "kills", "persist'te total yok: yerleşik anahtar kalır")
	assert_eq(a.best_key, "kills_best", "persist'teki best uygulanır")


func test_builtin_best_key_survives_persist_without_best() -> void:
	var a := _def("run_time")
	assert_eq(a.best_key, "time", "ön koşul: yerleşik anahtar")
	a.bind_persist([{"stat": "run_time", "persist": {"total": "time_total"}}])
	assert_eq(a.best_key, "time", "persist'te best yok: yerleşik anahtar kalır")
	assert_eq(a.total_key, "time_total", "persist'teki total uygulanır")


func test_non_string_persist_value_falls_back_to_builtin() -> void:
	var a := _def("total_wins")
	a.bind_persist([{"stat": "total_wins", "persist": {"total": 5}}])
	assert_eq(a.total_key, "wins", "string olmayan değer yerleşiğe düşer")


func test_data_only_stat_without_builtin_stays_empty() -> void:
	var a := _def("yeni_stat_yok")
	a.bind_persist([{"stat": "yeni_stat_yok", "persist": {}}])
	assert_eq([a.total_key, a.best_key], ["", ""], "yerleşiği olmayan stat boş kalır")


func test_persist_overrides_builtin_when_given() -> void:
	var a := _def("total_kills")
	a.bind_persist([{"stat": "total_kills", "persist": {"total": "k2"}}])
	assert_eq(a.total_key, "k2")
