extends GutTest
## ResultModel (R5b): result_screen.gd'den çıkarılan saf veri mantığı; değerler bölme öncesi ResultScreen çıktısıyla aynıdır.


func test_rf5b_record_kind_ranks() -> void:
	assert_eq(ResultModel.record_kind({}), &"none", "bilgi yok")
	assert_eq(ResultModel.record_kind({"rank": 1, "is_record": true}), &"record")
	assert_eq(
		ResultModel.record_kind({"rank": 1, "is_record": false}), &"none", "1. ama rekor değil"
	)
	assert_eq(ResultModel.record_kind({"rank": 5}), &"top10")
	assert_eq(ResultModel.record_kind({"rank": 0, "needed_for_top10": 120}), &"outside")
	assert_eq(ResultModel.record_kind({"rank": 0, "needed_for_top10": 0}), &"none")


func test_rf5b_rows_values_and_flags() -> void:
	var stats := {
		"time": 321.0,
		"best_mult": 3,
		"evolutions": [1, 2],
		"score_parts": {"kills": 100, "streak": 10, "evolution": 0, "survival": 50, "lord": 0},
	}
	var rows := ResultModel.rows(stats, false)
	assert_eq(Array(rows["vals"]), [100, 10, 0, 50, 0])
	assert_eq(Array(rows["plus"]), [false, true, true, true, true])
	assert_eq(Array(rows["dim"]), [false, false, true, false, true], "evrim 0 ve lord 0 soluk")
	assert_eq(Array(rows["dash"]), [false, false, false, false, true], "lord 0: çizgi")
	assert_eq(rows["details"][1], "en yüksek ×3")
	assert_eq(rows["details"][2], "2 evrim")
	assert_eq(rows["details"][4], "Lord'u yen")


func test_rf5b_rows_lord_hint_hidden_on_win() -> void:
	var rows := ResultModel.rows({"score_parts": {}}, true)
	assert_eq(rows["details"][4], "", "kazanınca Lord ipucu yok")


func test_rf5b_chip_texts_achievement_and_step() -> void:
	var names: Array[String] = ["A", "B", "C"]
	var t := ResultModel.chip_texts(names, -1)
	assert_eq(t["title"], "YENİ BAŞARIM · 3")
	assert_eq(t["names"], "A, B +1")
	assert_eq(t["a11y"], "3 yeni başarım: A, B, C")
	var one: Array[String] = ["AİLE II"]
	var s := ResultModel.chip_texts(one, 2)
	assert_eq(s["title"], "YENİ KADEME · 2")
	assert_eq(s["a11y"], "2 yeni kademe: AİLE II")


func test_rf5b_combo_cap_and_static_lines() -> void:
	assert_eq(ResultModel.combo_cap(false), ResultModel.MAX_COMBOS)
	assert_eq(ResultModel.combo_cap(true), ResultModel.CHIP_MAX_COMBOS)
	assert_eq(ResultModel.rank_line(&"normal", &"hard", 3), "Normal · Zor listesinde 3. sıra")
	assert_eq(ResultModel.rank_line(&"normal", &"hard", 0), "")
	assert_eq(ResultModel.endless_sub(1668.0, -1.0), "")


func test_rf5b_screen_keeps_public_constants_and_delegates() -> void:
	assert_eq(ResultScreen.REPLAY_H, ResultLayout.REPLAY_H)
	assert_eq(ResultScreen.STAMP_SEC, ResultAnim.STAMP_SEC)
	assert_eq(
		ResultScreen.rank_line(&"endless", &"hard", 1),
		ResultModel.rank_line(&"endless", &"hard", 1)
	)
