extends GutTest
## v2.1 U6 denetim düzeltmeleri (A dilimi): #3 2× şerit "DEĞİŞTİR ›", #7 mod glif rengi, #8 mühür/süre çakışması,
## #13 dokunmatikte açılış odağı yok, #14 sürüm 2.1.0. Seçim sahte Settings'e yazılır (user:// kirlenmez).

const STRIP_W := 936.0
const STRIP_PAD := 28.0  # run_strip.gd satırı: sol/sağ 28
const ROW_GAP := 22.0
const SUB_GAP := 14.0
const SHIELDS_BIG_W := 99.0
const GLYPH_BIG := 80.0

var fake: V21Kit.FakeSettings
var _saved: Array = []


func before_each() -> void:
	fake = V21Kit.use_fake_settings()
	var st := get_node_or_null(^"/root/Settings")
	if st != null:
		_saved = [st.buyuk_yazi, st.hareket_azalt]
		st.buyuk_yazi = false
		st.hareket_azalt = true


func after_each() -> void:
	V21Kit.clear_fake_settings()
	var st := get_node_or_null(^"/root/Settings")
	if st != null and _saved.size() == 2:
		st.buyuk_yazi = _saved[0]
		st.hareket_azalt = _saved[1]


func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	host.theme = UiKit.theme()
	add_child_autofree(host)
	return host


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _text_w(l: Label, text: String) -> float:
	var f: Font = l.get_theme_font(&"font")
	return (
		f
		. get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size(&"font_size"))
		. x
	)


## Yazının gerçek çizim kutusu: etiket dikey ortalı, yükseklik = yazı tipi satır yüksekliği.
func _text_rect(l: Label) -> Rect2:
	var f: Font = l.get_theme_font(&"font")
	var h := f.get_height(l.get_theme_font_size(&"font_size"))
	var r := l.get_global_rect()
	return Rect2(r.position.x, r.position.y + (r.size.y - h) * 0.5, r.size.x, h)


# --- #3 ------------------------------------------------------------------------------------------------------


# Üretim değişikliği olmadan kırmızı: 2×'te metin "›" idi.
func test_a60_big_strip_keeps_the_change_label_and_fits_every_selection() -> void:
	var cfg := V21Kit.cfg()
	var host := _host()
	var strip := RunStrip.new()
	host.add_child(strip)
	strip.set_big(true)
	strip.size = Vector2(STRIP_W, RunStrip.H_BIG)
	for mode in RunStrip.mode_order():
		for diff in RunStrip.diff_order():
			strip.show_selection(mode, diff, cfg)
			await _settle()
			var ch: Label = strip._change
			assert_eq(ch.text, "DEĞİŞTİR ›", "2×'te de tam metin (%s/%s)" % [mode, diff])
			var title_w := _text_w(strip._title, strip._title.text)
			var sub_w := _text_w(strip._sub, strip._sub.text) + SUB_GAP + SHIELDS_BIG_W
			var need := GLYPH_BIG + ROW_GAP + maxf(title_w, sub_w) + ROW_GAP + _text_w(ch, ch.text)
			assert_lte(
				need,
				STRIP_W - 2.0 * STRIP_PAD,
				"%s/%s: ölçülen sığma payı (%d px gerekli)" % [mode, diff, roundi(need)]
			)
			assert_lte(
				ch.get_combined_minimum_size().x,
				ch.size.x + 0.5,
				"etiket kendi yazısından dar değil"
			)
			var inside := strip.get_global_rect().grow(-STRIP_PAD + 0.5)
			assert_true(
				inside.encloses(ch.get_global_rect()),
				"etiket şeridin içinde: %s" % ch.get_global_rect()
			)
	strip.set_big(false)
	assert_eq(strip._change.text, "DEĞİŞTİR ›", "1× aynı metin")


# --- #7 ------------------------------------------------------------------------------------------------------


# Üretim değişikliği olmadan kırmızı: glif hep bronz_300'dü.
func test_a61_mode_glyph_is_bronz_300_only_when_selected() -> void:
	V21Runs.set_selection(&"quick", &"normal")
	var s := RunScreen.new()
	_host().add_child(s)
	s.visible = true
	await _settle()
	for m in RunStrip.mode_order():
		var want := UiKit.BRONZ_300 if m == &"quick" else UiKit.BRONZ_500
		assert_eq((s._glyphs[m] as RunStrip.ModeGlyph).color, want, "ilk durum %s" % m)
	s._select_mode(&"endless")
	for m in RunStrip.mode_order():
		var want2 := UiKit.BRONZ_300 if m == &"endless" else UiKit.BRONZ_500
		assert_eq((s._glyphs[m] as RunStrip.ModeGlyph).color, want2, "seçim sonrası %s" % m)
	s.set_font_scale(2.0)
	await _settle()
	assert_eq(
		(s._glyphs[&"endless"] as RunStrip.ModeGlyph).color,
		UiKit.BRONZ_300,
		"2× yeniden kurulumda renk korunur"
	)
	assert_eq((s._glyphs[&"quick"] as RunStrip.ModeGlyph).color, UiKit.BRONZ_500)


# --- #8 ------------------------------------------------------------------------------------------------------


# Üretim değişikliği olmadan kırmızı: mühür y14-70, süre yazısı y≈67'den başlıyordu.
func test_a62_seal_never_overlaps_the_duration_text_at_1x() -> void:
	var s := RunScreen.new()
	_host().add_child(s)
	s.visible = true
	await _settle()
	s.set_font_scale(1.0)
	for m in RunStrip.mode_order():
		s._select_mode(m)
		await _settle()
		var b: Button = s.mode_buttons[m]
		var span: Label = b.get_child(0).get_child(b.get_child(0).get_child_count() - 1)
		var seal: Control = s._seals[b]
		var inter := seal.get_global_rect().intersection(_text_rect(span))
		assert_false(
			inter.has_area(),
			(
				"%s: mühür %s ile süre yazısı %s kesişmez"
				% [m, seal.get_global_rect(), _text_rect(span)]
			)
		)


# --- #13 -----------------------------------------------------------------------------------------------------


func test_a63_focus_is_grabbed_only_without_a_touchscreen() -> void:
	assert_false(RunScreen.should_grab_focus(true), "dokunmatik: odak verilmez")
	assert_true(RunScreen.should_grab_focus(false), "klavye/kumanda: odak verilir")


# --- #14 -----------------------------------------------------------------------------------------------------


func test_a64_version_line_reads_2_1_0_from_project_settings() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/version"), "2.1.0")
	assert_eq(MainMenu.version_text(), "Sürüm 2.1.0")
