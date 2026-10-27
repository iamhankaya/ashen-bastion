extends GutTest
## v2.1 U6 sonuç ekranı denetim düzeltmeleri (#5 kombo kademeleri, #2 büyük yazı, #9 sıra notu, #10 Y_SUB, #15 TalkBack).
## Godot yerelde koşmaz: CI. Kademe aritmetiği docs/dev notunda değil, ResultFit.TIERS ve result_screen.gd başlığındadır.

const STATS := {
	"time": 1500.0,
	"level": 12,
	"kills": 400,
	"score": 9000,
	"best_mult": 3,
	"evolutions": [],
	"score_parts": {"kills": 100, "streak": 10, "evolution": 0, "survival": 50, "lord": 5000},
}
const NOTCH := Vector4(0.0, 60.0, 0.0, 40.0)
const LAST_TIER := 4

var fake: V21Kit.FakeSettings


func before_each() -> void:
	fake = V21Kit.use_fake_settings()


func after_each() -> void:
	V21Kit.clear_fake_settings()


func _combos(n: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k in n:
		rows.append({"id": &"zincirleme_patlama", "name": "Kıyamet", "pair": "A + B", "icon": ""})
	return rows


## chip: başarım özet çipi; easy: Kolay notu; extra: güvenli alan payı (sol, üst, sağ, alt).
func _make(
	n: int, easy: bool, chip: bool, extra: Vector4 = Vector4.ZERO, rec: Dictionary = {}
) -> ResultScreen:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var r := ResultScreen.new()
	host.add_child(r)
	if chip:
		r.set_new_achievements(["AİLE II", "AİLE III"] as Array[String])
	r.apply_safe_area(extra)
	var st := STATS.duplicate(true)
	st["mode"] = "normal"
	st["diff"] = "easy" if easy else "normal"
	r.show_result(true, st, _combos(n), "", rec)
	return r


func _rows(r: ResultScreen) -> int:
	var k := 0
	for c in r.combo_box.get_children():
		if c is HBoxContainer:
			k += 1
	return k


func _plus_text(r: ResultScreen) -> String:
	for c in r.combo_box.get_children():
		if c is Label and (c as Label).text.begins_with("+"):
			return (c as Label).text
	return ""


func _bottom(c: Control) -> float:
	return c.position.y + c.size.y


func _limit(extra: Vector4) -> float:
	return 2400.0 - ResultScreen.BOTTOM_DEFAULT - extra.w


## Aritmetiği imkânsız en kötü durumlar: Kolay + çip (+N satırıyla n >= 5; çentikte n >= 4) ya da çentik + (Kolay | çip) + n >= 5.
## Gerisi sığmak zorunda (çip tavanı artık çipsizle aynı: 4 satır + "+N").
func _must_fit(easy: bool, chip: bool, notch: bool, n: int) -> bool:
	if easy and chip and (n >= 5 or (notch and n >= 4)):
		return false
	return not (notch and (easy or chip) and n >= 5)


func _assert_no_overlap(r: ResultScreen, tag: String) -> void:
	assert_lte(
		_bottom(r.breakdown_panel), r.strip_panel.position.y, tag + ": döküm şeritten önce biter"
	)
	var below := r.combo_panel.position.y
	if r.easy_note.visible:
		below = r.easy_note.position.y
	elif r.achievement_chip.visible:
		below = r.achievement_chip.position.y
	assert_lte(_bottom(r.strip_panel), below, tag + ": şerit altındaki bloktan önce biter")
	if r.easy_note.visible and r.achievement_chip.visible:
		assert_lte(_bottom(r.easy_note), r.achievement_chip.position.y, tag + ": not < çip")
	if r.achievement_chip.visible:
		assert_lte(_bottom(r.achievement_chip), r.combo_panel.position.y, tag + ": çip < panel")
	elif r.easy_note.visible:
		assert_lte(_bottom(r.easy_note), r.combo_panel.position.y, tag + ": not < panel")
	assert_lte(_bottom(r.combo_panel), r.replay_button.position.y, tag + ": panel < Tekrar")
	assert_lte(_bottom(r.replay_button), r.menu_button.position.y, tag + ": Tekrar < Menü")


# --- #5 kombo kademeleri ---------------------------------------------------------------------------------------


# Kırmızı olur: result_screen.gd kademe yerine satır azaltıyordu (5 kombo -> 3 satır '+2'; alt güvenli alanda 0 satır).
func test_b60_state_matrix_never_cuts_rows_and_never_overlaps() -> void:
	for easy in [false, true]:
		for chip in [false, true]:
			for extra in [Vector4.ZERO, NOTCH]:
				for n in [0, 1, 4, 5, 8]:
					var tag := "easy=%s chip=%s extra=%s n=%d" % [easy, chip, extra, n]
					var r := _make(n, easy, chip, extra)
					var cap := 4
					assert_eq(_rows(r), mini(n, cap), tag + ": satır sayısı hedefte (azaltma yok)")
					assert_eq(
						_plus_text(r), "+%d" % (n - cap) if n > cap else "", tag + ": '+N' korunur"
					)
					_assert_no_overlap(r, tag)
					assert_gte(r.replay_button.size.y, 132.0, tag + ": Tekrar >= 132")
					assert_gte(r.menu_button.size.y, 112.0, tag + ": Menü >= 112")
					var fits := r.content_bottom() <= _limit(extra) + 0.5
					if _must_fit(easy, chip, extra == NOTCH, n):
						assert_true(
							fits, tag + ": düğmeler alt sınırda (%.0f)" % r.content_bottom()
						)
					else:
						assert_true(
							fits or r._tier == LAST_TIER, tag + ": sığmıyorsa en sıkı kademede"
						)


# Kırmızı olur: kademe tablosu (ResultFit.TIERS) ve '_tier' yok.
func test_b61_tier_zero_keeps_design_sizes_when_it_fits() -> void:
	var r := _make(4, false, false)
	assert_eq(r._tier, 0, "4 kombo, payı yok: tasarım ölçüleri")
	assert_eq(r.replay_button.size.y, ResultScreen.REPLAY_H)
	assert_eq(r.menu_button.size.y, ResultScreen.MENU_H)
	assert_almost_eq(
		r.menu_button.position.y - _bottom(r.replay_button), ResultScreen.BUTTON_GAP, 0.01
	)
	assert_almost_eq(r.replay_button.position.y - _bottom(r.combo_panel), ResultScreen.GAP, 0.01)


# Kırmızı olur: önce düğme/boşluk payı (5 kombo '+1' ile 4 satır), satır azaltma yok.
func test_b62_five_combos_use_spacing_then_button_tiers_not_rows() -> void:
	var r := _make(5, false, false)
	assert_eq(_rows(r), 4)
	assert_eq(_plus_text(r), "+1")
	assert_gt(r._tier, 0, "tasarım ölçüleri sığmaz (2354 > 2328): kademe devrede")
	assert_lte(r.content_bottom(), _limit(Vector4.ZERO) + 0.5)
	assert_gte(
		r.replay_button.position.y - _bottom(r.combo_panel),
		ResultScreen.GAP - 0.01,
		"panel→düğme 24"
	)
	var chip := _make(5, false, true)
	assert_eq(
		[_rows(chip), _plus_text(chip)], [4, "+1"], "çipli de 4 satır + '+1' (kullanıcı kararı b)"
	)


# Kırmızı olur: eski kod bu kombinasyonda satırı 0'a kadar indiriyordu.
func test_b63_infeasible_worst_case_keeps_rows_and_reports_overflow() -> void:
	var r := _make(8, true, true, NOTCH)
	assert_eq(_rows(r), 4, "Kolay + çip + çentik: 4 satır kalır (0'a inmez)")
	assert_eq(_plus_text(r), "+4")
	assert_eq(r._tier, LAST_TIER)
	_assert_no_overlap(r, "en kötü")
	var big_inset := _make(4, false, false, Vector4(0, 100, 0, 150))
	assert_eq(_rows(big_inset), 4, "olağandışı alt pay: yine 4 satır")


# --- #10 Y_SUB ---------------------------------------------------------------------------------------------------


# Kırmızı olur: Y_SUB 300'dü.
func test_b64_subtitle_sits_at_292_above_the_chips() -> void:
	assert_eq(ResultScreen.Y_SUB, 292.0)
	var r := _make(0, false, false)
	assert_eq(r.sub_label.position.y, 292.0)
	assert_lte(_bottom(r.sub_label), r.chip_holder.position.y)
	assert_eq(r.chip_holder.position.y, ResultScreen.Y_CHIPS, "çipler y352'de kalır")


# --- #15 TalkBack ------------------------------------------------------------------------------------------------


# Kırmızı olur: a11y metni rakamlıydı ("3. sıra").
func test_b65_spoken_rank_words_for_one_to_ten() -> void:
	var want := [
		"birinci",
		"ikinci",
		"üçüncü",
		"dördüncü",
		"beşinci",
		"altıncı",
		"yedinci",
		"sekizinci",
		"dokuzuncu",
		"onuncu"
	]
	for i in 10:
		assert_eq(ResultFit.spoken_rank(i + 1), want[i])
	assert_eq(ResultFit.spoken_rank(11), "11.")
	var st := STATS.duplicate(true)
	st["mode"] = "normal"
	st["diff"] = "hard"
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var r := ResultScreen.new()
	host.add_child(r)
	r.show_result(true, st, _combos(0), "", {"rank": 3, "is_record": false, "previous_best": 900})
	assert_eq(r.record_note.text, "Normal · Zor listesinde 3. sıra", "görünen metin rakamlı kalır")
	assert_eq(r.record_note.accessibility_name, "Normal modda, Zor listesinde üçüncü sıra.")


# --- #9 sıra notu ------------------------------------------------------------------------------------------------


func _assert_note_fits(r: ResultScreen, tag: String) -> void:
	var note := r.record_note
	var font := note.get_theme_font(&"font")
	var fs := note.get_theme_font_size(&"font_size")
	var wide := font.get_string_size(note.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	assert_gte(fs, ResultFit.NOTE_FONT_MIN, tag + ": yazı >= 26")
	if wide > r._w:
		assert_ne(note.autowrap_mode, TextServer.AUTOWRAP_OFF, tag + ": sığmıyorsa sarar")
		assert_gte(note.size.y, 2.0 * font.get_height(fs) - 1.0, tag + ": 2 satır payı")
	assert_lte(_bottom(note), r.breakdown_panel.position.y, tag + ": döküm bloğuyla çakışmaz")


# Kırmızı olur: kutu 936×40 tek satır, sarma yok, küçültme yok.
func test_b66_longest_rank_note_never_overflows_or_hits_the_breakdown() -> void:
	var rec := {"rank": 1, "is_record": true, "previous_best": 1234567, "needed_for_top10": 0}
	var longest := "Hızlı · Kolay listesinde 1. sıra · Önceki en iyi: 1.234.567"
	for extra in [Vector4.ZERO, Vector4(100, 0, 100, 0), Vector4(150, 0, 150, 0)]:
		var r := _make(0, false, false, extra, rec)
		var st := STATS.duplicate(true)
		st["mode"] = "quick"
		st["diff"] = "easy"
		r.show_result(true, st, _combos(0), "", rec)
		assert_eq(r.record_note.text, longest)
		_assert_note_fits(r, "extra=%s" % [extra])
	var top10 := {"rank": 10, "is_record": false, "previous_best": 5, "needed_for_top10": 0}
	var t := _make(0, false, false, Vector4(150, 0, 150, 0), top10)
	_assert_note_fits(t, "top10")


# --- #2 büyük yazı -----------------------------------------------------------------------------------------------


# Kırmızı olur: set_font_scale / is_big yok.
func test_b67_font_scale_threshold_and_flag() -> void:
	var r := _make(0, false, false)
	assert_false(r.is_big())
	r.set_font_scale(1.3)
	assert_false(r.is_big(), "1,3 eşik değil (>)")
	r.set_font_scale(2.0)
	assert_true(r.is_big())
	r.set_font_scale(1.0)
	assert_false(r.is_big())


# Kırmızı olur: büyük yazıda çip satırı sarmıyordu, yazılar büyümüyordu.
func test_b68_big_text_wraps_chips_grows_fonts_and_shifts_blocks() -> void:
	var r := _make(2, false, false)
	var div_1x := r.divider.position.y
	var brk_1x := r.breakdown_panel.position.y
	var name_1x := (r.breakdown_rows[0].get_node("Name") as Label).get_theme_font_size(&"font_size")
	r.set_font_scale(2.0)
	assert_true(r._run_chips is HFlowContainer, "çipler sarar (HFlowContainer)")
	assert_eq(r.chip_holder.size.y, ResultScreen.CHIP_ROW_H + 56.0, "çip satırı +56")
	assert_eq(r.divider.position.y, div_1x + 56.0)
	assert_eq(r.breakdown_panel.position.y, brk_1x + 56.0 + ResultScreen.NOTE_EXTRA)
	assert_eq(r.title_label.position.y, 170.0, "üst bloklar yerinde")
	var name_label := r.breakdown_rows[0].get_node("Name") as Label
	assert_eq(name_label.get_theme_font_size(&"font_size"), 40)
	assert_gt(name_label.get_theme_font_size(&"font_size"), name_1x)
	assert_eq(
		(r.breakdown_rows[0].get_node("Detail") as Label).get_theme_font_size(&"font_size"), 34
	)
	assert_eq(r.replay_button.get_theme_font_size(&"font_size"), 60)
	# 1x'e dönünce yerleşim birebir eski
	r.set_font_scale(1.0)
	assert_eq(r.divider.position.y, div_1x)
	assert_eq(r.breakdown_panel.position.y, brk_1x)
	assert_eq(r.chip_holder.size.y, ResultScreen.CHIP_ROW_H)
	assert_false(r.menu_button.has_theme_font_size_override(&"font_size"))
	assert_eq(name_label.get_theme_font_size(&"font_size"), name_1x)


# Kırmızı olur: büyük yazıda hiçbir kesilme/çakışma kontrolü yok.
func test_b69_big_text_texts_fit_their_boxes() -> void:
	var r := _make(2, false, false, Vector4.ZERO, {"rank": 2, "is_record": false})
	r.set_font_scale(2.0)
	r.finish_count()
	for row in r.breakdown_rows:
		for nm in ["Name", "Detail"]:
			var l := row.get_node(nm) as Label
			var fs := l.get_theme_font_size(&"font_size")
			var w := (
				l
				. get_theme_font(&"font")
				. get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
				. x
			)
			assert_lte(
				w, l.size.x, "%s: '%s' kutuya sığar (%.0f > %.0f)" % [nm, l.text, w, l.size.x]
			)
		var name_l := row.get_node("Name") as Label
		var det_l := row.get_node("Detail") as Label
		assert_lte(name_l.position.x + name_l.size.x, det_l.position.x + det_l.size.x)
	assert_lte(_bottom(r.breakdown_panel), r.strip_panel.position.y)
	var nm_font := r.record_note.get_theme_font_size(&"font_size")
	assert_gte(nm_font, 30, "büyük yazıda sıra notu en az 30")
	assert_lte(_bottom(r.record_note), r.breakdown_panel.position.y)


# Kırmızı olur: büyük yazıda taşma için kaydırma yok (düğmeler 2400'ün altına düşüyordu).
func test_b70_big_text_matrix_has_no_overlap_and_scrolls_when_it_cannot_fit() -> void:
	for easy in [false, true]:
		for chip in [false, true]:
			for n in [0, 4, 5]:
				var tag := "2x easy=%s chip=%s n=%d" % [easy, chip, n]
				var r := _make(n, easy, chip, NOTCH)
				r.set_font_scale(2.0)
				var cap := 4
				assert_eq(_rows(r), mini(n, cap), tag + ": satır azaltma yok")
				_assert_no_overlap(r, tag)
				var bottom := r.content_bottom()
				if bottom > _limit(NOTCH) + 0.5:
					var scroll := r.get_node_or_null("ResultScroll") as ScrollContainer
					assert_not_null(scroll, tag + ": sığmayan içerik kaydırılır")
					if scroll != null:
						assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
						assert_gte(
							r._content.custom_minimum_size.y,
							bottom + ResultScreen.BOTTOM_DEFAULT + NOTCH.w - 0.5,
							tag + ": içerik alt payı dahil"
						)
						assert_true(r.menu_button.get_parent() == r._content)
				else:
					assert_true(
						(
							r.get_node_or_null("ResultScroll") == null
							or (
								(r.get_node("ResultScroll") as ScrollContainer).vertical_scroll_mode
								== ScrollContainer.SCROLL_MODE_DISABLED
							)
						),
						tag + ": sığıyorsa kaydırma kapalı"
					)


# --- CI görüntü bulguları (run 40522756345) -----------------------------------------------------------------------


# Kırmızı olur: paneller tema PanelRaised (mor) idi; Kolay notu etiketinin sarma genişliği taban değildi (not boş görünüyordu).
func test_b71_panels_are_stone_and_easy_note_text_has_a_wrap_width() -> void:
	var r := _make(2, true, false)
	for p: PanelContainer in [r.breakdown_panel, r.strip_panel, r.combo_panel]:
		var sb := p.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_not_null(sb, p.name + ": düz taş kutusu")
		assert_eq(sb.bg_color, UiKit.TAS_800, p.name + ": taş dolgu (mor değil)")
	var text := r.easy_note.get_node("Text") as Label
	assert_gte(
		text.custom_minimum_size.x,
		600.0,
		"sarma genişliği taban: dar genişlikte min yükseklik şişmez"
	)
	assert_lte(text.get_combined_minimum_size().y, r.easy_note.size.y, "metin not şeridine sığar")
