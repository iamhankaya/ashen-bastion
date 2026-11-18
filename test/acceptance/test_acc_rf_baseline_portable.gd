extends GutTest
## T20261118-03 (F-ashen-bastion-164 doğrulaması): platformdan bağımsız baz karşılaştırmasının GERÇEKTEN ayırt
## ettiğini kanıtlar. Yeşil yol (tolerans) kadar kırmızı yol da sınanır; yoksa tolerans her şeyi yutabilir.

const ROW := "root/Hud/Label|Label|%s,%s,%s,%s"


func _rows(x: float, y: float, w: float, h: float) -> Array:
	return [ROW % [x, y, w, h]]


## Tolerans değeri sabit sayılarla sınanır (RfBaseline.X_TOL_PX'e göreli yazılırsa tolerans şişince test de şişer).
func test_rects_small_x_width_drift_passes_large_fails() -> void:
	var base := _rows(10, 5, 100, 20)
	assert_eq(RfBaseline._rects_diff(_rows(14, 5, 96, 20), base, ""), "", "4 px font farkı geçer")
	assert_ne(
		RfBaseline._rects_diff(_rows(40, 5, 100, 20), base, ""), "", "30 px x kayması kırmızı"
	)
	assert_ne(
		RfBaseline._rects_diff(_rows(10, 5, 140, 20), base, ""),
		"",
		"40 px genişlik kayması kırmızı"
	)


func test_rects_y_height_class_path_and_count_stay_exact() -> void:
	var base := _rows(10, 5, 100, 20)
	assert_ne(RfBaseline._rects_diff(_rows(10, 6, 100, 20), base, ""), "", "y birebir")
	assert_ne(RfBaseline._rects_diff(_rows(10, 5, 100, 21), base, ""), "", "yükseklik birebir")
	assert_ne(
		RfBaseline._rects_diff(["root/Hud/Label|Button|10,5,100,20"], base, ""), "", "sınıf birebir"
	)
	assert_ne(
		RfBaseline._rects_diff(["root/Hud/Other|Label|10,5,100,20"], base, ""), "", "yol birebir"
	)
	assert_ne(RfBaseline._rects_diff(base + base, base, ""), "", "eleman sayısı birebir")
	assert_ne(RfBaseline._rects_diff([], base, ""), "", "eksik eleman")


func test_rects_malformed_row_is_not_silently_accepted() -> void:
	assert_ne(RfBaseline._rects_diff(["bozuk"], _rows(10, 5, 100, 20), ""), "")


func test_canon_text_is_stable_across_float_noise_and_signed_zero() -> void:
	var t: Variant = load("res://test/acceptance/test_acc_rf_trail.gd").new()
	assert_eq(t._canon_text(-0.0), t._canon_text(0.0), "işaretli sıfır")
	assert_eq(t._canon_text(-0.04), t._canon_text(0.0), "-0.04 yuvarlanınca -0.0 olmamalı")
	assert_eq(t._canon_text(1.00000000001), t._canon_text(1.0), "son basamak gürültüsü")
	assert_eq(t._canon_text(Vector2(0.3, -0.0)), t._canon_text(Vector2(0.30000000004, 0.0)))
	t.free()


func test_canon_text_still_distinguishes_real_differences() -> void:
	var t: Variant = load("res://test/acceptance/test_acc_rf_trail.gd").new()
	assert_ne(t._canon_text(1.0), t._canon_text(1.2))
	assert_ne(t._canon_text({"a": 1}), t._canon_text({"a": 2}))
	assert_ne(t._canon_text([1, 2]), t._canon_text([2, 1]), "dizi sırası anlamlı")
	assert_eq(
		t._canon_text({"b": 1, "a": 2}), t._canon_text({"a": 2, "b": 1}), "anahtar sırası değil"
	)
	t.free()
