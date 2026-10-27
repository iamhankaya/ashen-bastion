extends GutTest
## v2.1 U6 denetim düzeltmeleri: Sonsuz bandı (B: canlı bölge #4, dikey denge #12, 2× #2) ve duraklatma (A: 2× çipler #2,
## çip/eylem aralığı #17). Godot yerelde koşmaz: CI. Ayar (buyuk_yazi) testten önce sabitlenir, sonra geri alınır.

const SCREEN := Vector2(1080.0, 2400.0)

var fake: V21Kit.FakeSettings
var _saved: Array = []


func before_each() -> void:
	fake = V21Kit.use_fake_settings()
	var st := get_node_or_null(^"/root/Settings")
	if st != null:
		_saved = [st.buyuk_yazi, st.hareket_azalt]
		st.buyuk_yazi = false
		st.hareket_azalt = false


func after_each() -> void:
	V21Kit.clear_fake_settings()
	var st := get_node_or_null(^"/root/Settings")
	if st != null and _saved.size() == 2:
		st.buyuk_yazi = _saved[0]
		st.hareket_azalt = _saved[1]


func _host() -> Control:
	var host := Control.new()
	host.size = SCREEN
	add_child_autofree(host)
	return host


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _band() -> MilestoneBand:
	var b := MilestoneBand.new()
	_host().add_child(b)
	return b


## Bandın dikey boşlukları: [üst, alt] = ilk/son görünür etiketin kutusu ile bant kenarı arası.
func _gaps(b: MilestoneBand) -> Array:
	var last: Label = b.hint_label if b.hint_label.visible else b.sub_label
	return [
		b.title_label.position.y,
		b.band_height() - (last.position.y + last.size.y),
	]


# --- #4 canlı bölge (milestone_band.gd accessibility_live atamıyorsa kırmızı) ---------------------------------


func test_b60_band_is_a_polite_live_region_only_while_shown() -> void:
	var b := _band()
	assert_eq(b.accessibility_live, AccessibilityServer.LIVE_OFF, "gizliyken canlı bölge kapalı")
	b.show_band(300.0, false)
	assert_eq(b.accessibility_live, AccessibilityServer.LIVE_POLITE, "nazik, kesmeden")
	b.advance(3.3)
	assert_false(b.visible)
	assert_eq(b.accessibility_live, AccessibilityServer.LIVE_OFF, "süre bitince kapanır")
	b.show_band(0.0, true)
	assert_eq(b.accessibility_live, AccessibilityServer.LIVE_POLITE)
	b.hide_band()
	assert_eq(b.accessibility_live, AccessibilityServer.LIVE_OFF)


# --- #4 duyurulan metin ipucunu da okur (a11y_text yoksa kırmızı) ---------------------------------------------


func test_b61_spoken_text_includes_the_repeat_hint() -> void:
	assert_eq(MilestoneBand.a11y_text(0.0), MilestoneBand.A11Y, "ipucu yoksa eski cümle")
	assert_eq(
		MilestoneBand.a11y_text(300.0),
		MilestoneBand.A11Y + " Lord beş dakika sonra daha güçlü döner."
	)
	assert_eq(
		MilestoneBand.a11y_text(330.0),
		MilestoneBand.A11Y + " Lord beş dakika otuz saniye sonra daha güçlü döner."
	)
	var b := _band()
	b.show_band(300.0, false)
	assert_eq(b.accessibility_name, MilestoneBand.a11y_text(300.0))


# --- #12 dikey denge (band_height/layout yoksa kırmızı) -----------------------------------------------------


func test_b62_content_is_vertically_balanced_with_and_without_the_hint() -> void:
	var b := _band()
	b.show_band(300.0, true)
	var with_hint := _gaps(b)
	assert_eq(b.band_height(), MilestoneBand.H, "1× bant 204")
	assert_lte(absf(with_hint[0] - with_hint[1]), 8.0, "ipucu varken dengeli %s" % [with_hint])
	assert_lte(absf(with_hint[0] - 22.0), 2.0, "ipucu varken yerleşim v2.1 ile aynı (üst 22)")
	b.show_band(0.0, true)
	var no_hint := _gaps(b)
	assert_false(b.hint_label.visible)
	assert_eq(b.band_height(), MilestoneBand.H)
	assert_lte(absf(no_hint[0] - no_hint[1]), 8.0, "ipucu yokken dengeli %s" % [no_hint])
	assert_gt(no_hint[0], with_hint[0] + 10.0, "ipucu yokken içerik aşağı ortalanır")


# --- #2 2× yazı: kesilmez, yükseklik sayıyla ----------------------------------------------------------------


func test_b63_big_font_grows_the_band_a_little_and_keeps_text_inside() -> void:
	var b := _band()
	b.show_band(300.0, true)
	b.set_font_scale(2.0)
	assert_true(b.is_big())
	var h := b.band_height()
	assert_gt(h, MilestoneBand.H, "2×'te bant büyür")
	assert_lte(h, MilestoneBand.H + 60.0, "ama oyun alanını gereğinden fazla örtmez")
	assert_eq(b.size.y, h, "bant düğümü de büyür")
	for l in [b.title_label, b.sub_label, b.hint_label]:
		var lab := l as Label
		var font := lab.get_theme_font(&"font")
		var fs := lab.get_theme_font_size(&"font_size")
		var need := font.get_multiline_string_size(
			lab.text, HORIZONTAL_ALIGNMENT_CENTER, lab.size.x, fs
		)
		assert_gte(lab.size.y + 0.5, need.y, "%s: kutu metne yeter" % lab.text)
		assert_gte(lab.position.y, 0.0)
		assert_lte(lab.position.y + lab.size.y, h + 0.5, "%s: bant içinde" % lab.text)
		assert_gte(fs, 26, "min metin 26 px")
	var g := _gaps(b)
	assert_lte(absf(g[0] - g[1]), 8.0, "2×'te de dengeli %s" % [g])
	b.show_band(0.0, true)
	g = _gaps(b)
	assert_lte(absf(g[0] - g[1]), 8.0, "2× ipucusuz dengeli %s" % [g])
	b.set_font_scale(1.0)
	assert_false(b.is_big())
	assert_eq(b.band_height(), MilestoneBand.H, "1×'e dönünce 204")


func test_b64_hud_hands_the_font_scale_to_the_band_when_it_shows() -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st == null:
		pass_test("Settings autoload yok")
		return
	var sim := GameSim.new(5, &"gunslinger", V21Kit.profile(&"endless", &"hard").opts())
	var hud := Hud.new()
	_host().add_child(hud)
	hud.bind(sim)
	st.buyuk_yazi = true
	sim.bus.milestone_reached.emit()
	assert_true(hud.milestone_band.is_big(), "2× ayarı bantta")
	assert_true(hud.is_big())
	hud.refresh(4.0)
	st.buyuk_yazi = false
	sim.bus.milestone_reached.emit()
	assert_false(hud.milestone_band.is_big(), "1×'e dönüş")


# --- duraklatma: 2× çipler (#2) ve çip/eylem aralığı (#17) -------------------------------------------------


func _pause() -> PauseScreen:
	var p := PauseScreen.new()
	_host().add_child(p)
	await _settle()
	p.open([] as Array[SkillState], [] as Array[SkillState], true, true)
	p.apply_safe_area(Vector4.ZERO)
	await _settle()
	return p


# set_font_scale/is_big/chips_rows yoksa kırmızı
func test_a60_big_font_wraps_the_chips_onto_two_rows_adding_56_px() -> void:
	var p := await _pause()
	var one_row := p.chips_slot.custom_minimum_size.y
	assert_false(p.is_big())
	assert_null(p.chips_v, "1×: tek satır")
	p.set_font_scale(2.0)
	await _settle()
	assert_true(p.is_big())
	assert_not_null(p.chips_v, "2×: çipler iki satıra sarar")
	assert_eq(p.chips_slot.custom_minimum_size.y, one_row + 56.0, "satır +56 (DESIGN §5)")
	var mode_r := (p.chips_v.get_node("ModeChip") as Control).get_global_rect()
	var diff_r := (p.chips_v.get_node("DiffChip") as Control).get_global_rect()
	assert_lte(mode_r.end.y, diff_r.position.y, "satırlar çakışmaz")
	var slot_r := p.chips_slot.get_global_rect()
	assert_gte(mode_r.position.y + 0.5, slot_r.position.y)
	assert_lte(diff_r.end.y, slot_r.end.y + 0.5, "çipler slot içinde")
	p.set_font_scale(1.0)
	await _settle()
	assert_null(p.chips_v)
	assert_eq(p.chips_slot.custom_minimum_size.y, one_row)


func test_a61_opening_reads_the_font_scale_setting() -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st == null:
		pass_test("Settings autoload yok")
		return
	var p := await _pause()
	st.buyuk_yazi = true
	p.open([] as Array[SkillState], [] as Array[SkillState], true, true)
	assert_true(p.is_big(), "açılışta Settings.font_scale okunur")
	assert_eq(p.chips_slot.get_child_count(), 1, "çipler birikmez")
	st.buyuk_yazi = false
	p.open([] as Array[SkillState], [] as Array[SkillState], true, true)
	assert_false(p.is_big())


# 1× ve 2×, sıfır/çentikli pay: çip ile eylem düğmeleri arası >= 24 px; sıfır payda sütun ekrana sığar
func test_a62_chips_keep_24_px_from_the_actions_at_1x_and_2x() -> void:
	assert_gte(PauseScreen.GAP_MIN, PauseScreen.CHIP_ACTION_MIN, "sıkışma tabanı >= 24")
	assert_gte(PauseScreen.CHIP_ACTION_MIN, 24.0)
	var p := await _pause()
	for big in [false, true]:
		p.set_font_scale(2.0 if big else 1.0)
		for extra in [Vector4.ZERO, Vector4(0.0, 120.0, 0.0, 200.0)]:
			p.apply_safe_area(extra)
			await _settle()
			var dist := p.resume_button.global_position.y - p.chips_slot.get_global_rect().end.y
			assert_gte(dist, 24.0, "büyük=%s pay=%s: çip->DEVAM ET %s px" % [big, extra, dist])
			assert_gte(p.gap.custom_minimum_size.y, PauseScreen.GAP_MIN)
			assert_lte(p.gap.custom_minimum_size.y, PauseScreen.GAP_H)
		p.apply_safe_area(Vector4.ZERO)
		await _settle()
		var limit := SCREEN.y - UiKit.DEFAULT_BOTTOM + 0.5
		assert_lte(p.column.get_global_rect().end.y, limit, "büyük=%s: sütun ekrana sığar" % big)
		assert_eq(p.gap.custom_minimum_size.y, PauseScreen.GAP_H, "pay 0: eylemler eski yerinde")
