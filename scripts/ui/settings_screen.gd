class_name SettingsScreen
extends Control
## Ayarlar ekranı v2.0.3 ("sakin oda", docs/design/v2.0.3/DESIGN.md §3). Menüden ve duraklatmadan açılır, GERİ ile döner.
## Bölümler (SettingsSections.IDS): SES (TÜM SESLER anahtarı, MÜZİK ve EFEKT kaydırıcıları %0-100 / %5 adım),
## DOKUNUŞ (TİTREŞİM), GÖRÜNÜM (HAREKETİ AZALT), HAKKINDA (sürüm). Liste ScrollContainer'da kayar, GERİ sabittir.
## Kaydırırken ses anında değişir (persist=false), bırakınca kaydedilir; efekt bırakılınca örnek atış çalar.
## Ses kapalıyken kaydırıcıya dokunmak ana anahtarı açar. Hareket azalt doğrudan `Settings`e yazılır.

## close() sonrası yayınlanır (bilgi amaçlı).
signal back_requested
signal sound_toggled(on: bool)
signal vibration_toggled(on: bool)
signal hareket_azalt_toggled(on: bool)

const W := 936.0
const TITLE_TOP := 96.0
const LIST_TOP := 250.0
const BACK_H := 132.0
const BACK_TOP := 2196.0
const ROW_H := 132.0
const SLIDER_H := 132.0  # dokunma alanı (tutamak 84 px, ray 28 px)
const GRABBER := 84
const RAIL_H := 28
const CARD_GAP := 30
const PREVIEW_ID := &"shot_right"
const SWITCH_SEC := 0.14
## LİSANSLAR alt ekranı satırları: [başlık, açıklama] (kaynaklar: assets/fonts/LICENSE-*-OFL.txt, LICENSES-audio.md).
const LICENSE_ROWS := [
	["CINZEL", "Yazı tipi · SIL Open Font License 1.1"],
	["INTER", "Yazı tipi · SIL Open Font License 1.1"],
	["SES VE MÜZİK", "Kaynaklar ve lisanslar: LICENSES-audio.md"],
]
const SECTION_TITLES := {
	&"ses": "SES", &"dokunus": "DOKUNUŞ", &"gorunum": "GÖRÜNÜM", &"hakkinda": "HAKKINDA"
}

var title_label: Label
var music_slider: HSlider
var sfx_slider: HSlider
var music_value: Label
var sfx_value: Label
var sound_button: Button
var vibration_button: Button
var hareket_button: Button
var back_button: Button
var scroll: ScrollContainer
var column: VBoxContainer
var muted_note: Label
var licenses_button: Button
var licenses: Control
var lic_back_button: Button

var _sound_on: bool = true
var _vibration_on: bool = true
var _hareket_on: bool = false
var _title_box: Control
var _lic_title: Control
var _lic_card: Control
var _title_drop: float = 0.0


## Anahtar çizimi: tasarımın kor mührü (anahtar-ac/kapali.svg); doku yoksa düz çizim. Sözcük AÇIK/KAPALI solda.
class Switch:
	extends HBoxContainer
	var word: Label
	var plate: TextureRect
	var on: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override(&"separation", 18)
		word = UiKit.label("", &"LabelAccent", 28)
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(word)
		plate = TextureRect.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.custom_minimum_size = Vector2(156, 84)
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(plate)
		set_on(false)

	## `animate`: eski mühür 140 ms içinde solar; `hareket_azalt` açıkken anlık (DESIGN §6).
	func set_on(p_on: bool, animate: bool = false) -> void:
		on = p_on
		word.text = "AÇIK" if on else "KAPALI"
		word.add_theme_color_override(&"font_color", UiKit.KEMIK_100 if on else UiKit.KEMIK_300)
		var old := plate.texture
		plate.texture = UiKit.texture(
			UiKit.SKIN_DIR + ("anahtar-ac.svg" if on else "anahtar-kapali.svg")
		)
		if not animate or old == null or old == plate.texture:
			return
		var st := get_node_or_null(^"/root/Settings")  # ağaçta değilken sorulmaz (_init çağrısı animate=false)
		if st != null and st.hareket_azalt:
			return
		var ghost := TextureRect.new()
		ghost.texture = old
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		UiKit.fill(ghost)
		plate.add_child(ghost)
		var tw := create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, SWITCH_SEC)
		tw.tween_callback(ghost.queue_free)


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.TAS_900
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)
	# Üstten sıcak tek ışık (amber α0,16); alt vinyet.
	var glow := TextureRect.new()
	glow.texture = _vertical_fade(Color(UiKit.AMBER, 0.16), Color(UiKit.AMBER, 0.0))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_right = 1.0
	glow.offset_bottom = 600.0
	add_child(glow)

	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.offset_left = -W * 0.5
	scroll.offset_right = W * 0.5
	scroll.offset_top = LIST_TOP
	scroll.offset_bottom = BACK_TOP - 24.0
	UiKit.touch_scroll(scroll)
	add_child(scroll)
	column = VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", CARD_GAP)
	scroll.add_child(column)

	_build_ses()
	_build_dokunus()
	_build_gorunum()
	_build_hakkinda()

	_title_box = PanelContainer.new()
	_title_box.add_theme_stylebox_override(&"panel", UiKit.skin_box("lento", 60, UiKit.TAS_800))
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.anchor_left = 0.5
	_title_box.anchor_right = 0.5
	_title_box.offset_left = -260.0
	_title_box.offset_right = 260.0
	_title_box.offset_top = TITLE_TOP
	_title_box.offset_bottom = TITLE_TOP + 120.0
	title_label = UiKit.label("AYARLAR", &"LabelTitle", 64)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_box.add_child(title_label)
	add_child(_title_box)

	back_button = UiKit.button("GERİ", &"secondary", BACK_H)
	back_button.add_theme_font_size_override(&"font_size", 48)
	for st in [&"normal", &"hover", &"focus"]:
		back_button.add_theme_stylebox_override(st, UiKit.skin_box("dugme-dolu"))
	back_button.add_theme_stylebox_override(&"pressed", UiKit.skin_box("dugme-basili"))
	back_button.accessibility_name = "Geri"
	back_button.anchor_left = 0.5
	back_button.anchor_right = 0.5
	back_button.offset_left = -W * 0.5
	back_button.offset_right = W * 0.5
	back_button.offset_top = BACK_TOP
	back_button.offset_bottom = BACK_TOP + BACK_H
	back_button.pressed.connect(close)
	add_child(back_button)
	_build_licenses()
	set_values(AudioMix.MAX_PCT, AudioMix.MAX_PCT, true)


func _build_ses() -> void:
	var card := _section(&"ses")
	sound_button = _toggle_row(card, "TÜM SESLER", "")
	sound_button.pressed.connect(_on_sound)
	muted_note = UiKit.label(
		"Ses kapalı. Bir kaydırıcıya dokunmak sesi açar.", &"", 28, UiKit.KEMIK_300
	)
	muted_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	muted_note.custom_minimum_size.y = 76.0
	card.add_child(muted_note)
	music_slider = _slider_row(card, "MÜZİK")
	music_value = music_slider.get_meta(&"value_label")
	sfx_slider = _slider_row(card, "EFEKT")
	sfx_value = sfx_slider.get_meta(&"value_label")
	music_slider.value_changed.connect(func(v: float) -> void: _changed(music_slider, v, false))
	sfx_slider.value_changed.connect(func(v: float) -> void: _changed(sfx_slider, v, false))
	music_slider.drag_ended.connect(
		func(_c: bool) -> void: _changed(music_slider, music_slider.value, true)
	)
	sfx_slider.drag_ended.connect(
		func(_c: bool) -> void: _changed(sfx_slider, sfx_slider.value, true)
	)


func _build_dokunus() -> void:
	vibration_button = _toggle_row(
		_section(&"dokunus"), "TİTREŞİM", "Doldurma ve vuruşlarda hafif titreşim."
	)
	vibration_button.pressed.connect(_on_vibration)


func _build_gorunum() -> void:
	hareket_button = _toggle_row(
		_section(&"gorunum"),
		"HAREKETİ AZALT",
		"Hareketli portreleri ve ekran efektlerini durdurur."
	)
	hareket_button.pressed.connect(_on_hareket)


func _build_hakkinda() -> void:
	var card := _section(&"hakkinda")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.y = ROW_H
	var l := UiKit.label("SÜRÜM", &"LabelAccent", 36)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var v := UiKit.label(version_text(), &"", 36, UiKit.KEMIK_100)
	v.name = "VersionValue"
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(v)
	card.add_child(row)
	card.add_child(_licenses_row())


## HAKKINDA > LİSANSLAR satırı: tek dokunma hedefi, sağda ">" işareti.
func _licenses_row() -> Button:
	licenses_button = Button.new()
	licenses_button.flat = true
	licenses_button.custom_minimum_size = Vector2(0, ROW_H)
	licenses_button.accessibility_name = "Lisanslar"
	licenses_button.add_theme_stylebox_override(
		&"focus", UiKit.stylebox(Color(0, 0, 0, 0), UiKit.BRONZ_300, 6, 8)
	)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(h)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UiKit.label("LİSANSLAR", &"LabelAccent", 36))
	v.add_child(UiKit.label("Yazı tipleri, ses ve müzik.", &"", 28, UiKit.KEMIK_300))
	h.add_child(v)
	var chevron := UiKit.label("›", &"LabelAccent", 56)
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(chevron)
	licenses_button.add_child(h)
	licenses_button.pressed.connect(_open_licenses)
	return licenses_button


## LİSANSLAR alt ekranı (DESIGN `02d`): lento başlık, tek kart, GERİ ayarlara döner.
func _build_licenses() -> void:
	licenses = Control.new()
	licenses.name = "Licenses"
	UiKit.fill(licenses)
	licenses.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiKit.TAS_900
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	licenses.add_child(bg)
	_lic_title = PanelContainer.new()
	_lic_title.add_theme_stylebox_override(&"panel", UiKit.skin_box("lento", 60, UiKit.TAS_800))
	_lic_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lic_title.anchor_left = 0.5
	_lic_title.anchor_right = 0.5
	_lic_title.offset_left = -260.0
	_lic_title.offset_right = 260.0
	_lic_title.offset_top = TITLE_TOP
	_lic_title.offset_bottom = TITLE_TOP + 120.0
	var t := UiKit.label("LİSANSLAR", &"LabelTitle", 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lic_title.add_child(t)
	licenses.add_child(_lic_title)
	_lic_card = PanelContainer.new()
	_lic_card.add_theme_stylebox_override(&"panel", UiKit.skin_box("levha", 40, UiKit.TAS_800))
	_lic_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lic_card.anchor_left = 0.5
	_lic_card.anchor_right = 0.5
	_lic_card.offset_left = -W * 0.5
	_lic_card.offset_right = W * 0.5
	_lic_card.offset_top = LIST_TOP + 10.0
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override(&"separation", 12)
	for r in LICENSE_ROWS:
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(UiKit.label(r[0], &"LabelAccent", 36))
		var d := UiKit.label(r[1], &"", 28, UiKit.KEMIK_300)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
		rows.add_child(box)
	_lic_card.add_child(rows)
	licenses.add_child(_lic_card)
	lic_back_button = UiKit.button("GERİ", &"secondary", BACK_H)
	lic_back_button.add_theme_font_size_override(&"font_size", 48)
	lic_back_button.add_theme_stylebox_override(&"normal", UiKit.skin_box("dugme-dolu"))
	lic_back_button.add_theme_stylebox_override(&"hover", UiKit.skin_box("dugme-dolu"))
	lic_back_button.add_theme_stylebox_override(&"pressed", UiKit.skin_box("dugme-basili"))
	lic_back_button.accessibility_name = "Geri"
	lic_back_button.anchor_left = 0.5
	lic_back_button.anchor_right = 0.5
	lic_back_button.offset_left = -W * 0.5
	lic_back_button.offset_right = W * 0.5
	lic_back_button.offset_top = BACK_TOP
	lic_back_button.offset_bottom = BACK_TOP + BACK_H
	lic_back_button.pressed.connect(_close_licenses)
	licenses.add_child(lic_back_button)
	licenses.visible = false
	add_child(licenses)


func _open_licenses() -> void:
	licenses.visible = true
	lic_back_button.grab_focus.call_deferred()


func _close_licenses() -> void:
	licenses.visible = false
	licenses_button.grab_focus.call_deferred()


## Tek sürüm kaynağı: project.godot `application/config/version`.
static func version_text() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "2.0.3"))


## Bölüm başlığı (Cinzel 34 + bronz çizgi) ve altında `levha` kartı; kartın içerik kutusunu döndürür.
func _section(id: StringName) -> VBoxContainer:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 18)
	var t := UiKit.label(SECTION_TITLES[id], &"LabelAccent", 34)
	t.add_theme_constant_override(&"shadow_offset_y", 0)
	head.add_child(t)
	var line := ColorRect.new()
	line.color = UiKit.BRONZ_700
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size.y = 3.0
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(line)
	var wrap := VBoxContainer.new()
	wrap.name = SettingsSections.node_name(id)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override(&"separation", 12)
	wrap.add_child(head)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiKit.skin_box("levha", 40, UiKit.TAS_800)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override(&"panel", sb)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override(&"separation", 12)
	panel.add_child(inner)
	wrap.add_child(panel)
	column.add_child(wrap)
	return inner


## Tek dokunma hedefli anahtar satırı (≥132): etiket + açıklama solda, AÇIK/KAPALI sözcüğü + mühür sağda.
func _toggle_row(parent: Control, caption: String, desc: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.accessibility_name = caption
	var focus := UiKit.stylebox(Color(0, 0, 0, 0), UiKit.BRONZ_300, 6, 8)
	b.add_theme_stylebox_override(&"focus", focus)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(h)
	h.add_theme_constant_override(&"separation", 18)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UiKit.label(caption, &"LabelAccent", 36))
	if desc != "":
		var d := UiKit.label(desc, &"", 28, UiKit.KEMIK_300)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
	h.add_child(v)
	var sw := Switch.new()
	sw.name = "Switch"
	h.add_child(sw)
	b.add_child(h)
	b.set_meta(&"switch", sw)
	parent.add_child(b)
	return b


## Başlık + yüzde etiketi, altında kaydırıcı; `value_label` meta'sında etiket.
func _slider_row(parent: Control, caption: String) -> HSlider:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiKit.label(caption, &"LabelAccent", 36)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var val := UiKit.label("100%", &"LabelAccent", 40, UiKit.KEMIK_100)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.custom_minimum_size.x = 160.0
	head.add_child(val)
	parent.add_child(head)
	var s := HSlider.new()
	s.min_value = AudioMix.MIN_PCT
	s.max_value = AudioMix.MAX_PCT
	s.step = AudioMix.STEP
	s.value = AudioMix.MAX_PCT
	s.custom_minimum_size = Vector2(0, SLIDER_H)
	s.scrollable = false
	s.focus_mode = Control.FOCUS_ALL
	s.add_theme_stylebox_override(&"slider", _rail("ray"))
	s.add_theme_stylebox_override(&"grabber_area", _rail("ray-dolgu"))
	s.add_theme_stylebox_override(&"grabber_area_highlight", _rail("ray-dolgu"))
	var knob := UiKit.texture(UiKit.SKIN_DIR + "tutamak.svg")
	if knob != null:
		s.add_theme_icon_override(&"grabber", knob)
		s.add_theme_icon_override(&"grabber_highlight", knob)
		s.add_theme_icon_override(&"grabber_disabled", knob)
	else:
		s.add_theme_icon_override(&"grabber", _grabber_tex(UiKit.BRONZ_300))
		s.add_theme_icon_override(&"grabber_highlight", _grabber_tex(UiKit.AMBER))
		s.add_theme_icon_override(&"grabber_disabled", _grabber_tex(UiKit.BRONZ_700))
	s.gui_input.connect(_on_slider_input.bind(s))
	s.set_meta(&"value_label", val)
	parent.add_child(s)
	return s


## Cihazda `emulate_mouse_from_touch` kapalı: dokunma/sürükleme olayları değere doğrudan çevrilir (fare yolu
## Slider'ın kendisinde; emülasyon olayları (device -1) atlanır, çift işleme olmaz). Olay tüketilir, liste kaymaz.
func _on_slider_input(ev: InputEvent, s: HSlider) -> void:
	var pos := Vector2.ZERO
	var release := false
	if ev is InputEventScreenTouch and ev.device != InputEvent.DEVICE_ID_EMULATION:
		pos = (ev as InputEventScreenTouch).position
		release = not (ev as InputEventScreenTouch).pressed
	elif ev is InputEventScreenDrag and ev.device != InputEvent.DEVICE_ID_EMULATION:
		pos = (ev as InputEventScreenDrag).position
	else:
		return
	s.accept_event()
	if release:
		s.drag_ended.emit(true)
		return
	var pad := float(GRABBER) * 0.5
	var t := clampf((pos.x - pad) / maxf(s.size.x - pad * 2.0, 1.0), 0.0, 1.0)
	s.value = s.min_value + t * (s.max_value - s.min_value)


## Kaydırırken ses anında değişir (kaydedilmez); bırakınca kaydedilir, efekt bırakılınca örnek atış çalar.
## Ses kapalıyken kaydırıcıya dokunmak ana anahtarı açar.
func _changed(s: HSlider, v: float, final: bool) -> void:
	var pct := AudioMix.clamp_pct(v)
	var st := _settings()
	if not st.sound_on:
		st.set_sound(true)
		set_values(int(music_slider.value), int(sfx_slider.value), _vibration_on, true)
		sound_toggled.emit(true)
	if s == music_slider:
		music_value.text = "%d%%" % pct
		st.set_music_pct(pct, final)
	else:
		sfx_value.text = "%d%%" % pct
		st.set_sfx_pct(pct, final)
		if final:
			Sfx.play(PREVIEW_ID)


## Değerleri dışarıdan ayarla (sinyal yaymaz). Ses ve hareket azalt durumu `Settings`ten okunur.
func set_values(music_pct: int, sfx_pct: int, vib: bool, animate: bool = false) -> void:
	_vibration_on = vib
	if music_slider == null:
		return
	var st := _settings()
	_sound_on = st.sound_on
	_hareket_on = st.hareket_azalt
	music_slider.set_value_no_signal(music_pct)
	sfx_slider.set_value_no_signal(sfx_pct)
	music_value.text = "%d%%" % music_pct
	sfx_value.text = "%d%%" % sfx_pct
	_set_switch(sound_button, _sound_on, "Ses", animate)
	_set_switch(vibration_button, vib, "Titreşim", animate)
	_set_switch(hareket_button, _hareket_on, "Hareketi azalt", animate)
	muted_note.visible = not _sound_on
	for s in [music_slider, sfx_slider]:
		(s as Control).modulate = Color.WHITE if _sound_on else Color(1, 1, 1, 0.55)
	music_slider.accessibility_name = "Müzik, yüzde %d" % music_pct
	sfx_slider.accessibility_name = "Efekt, yüzde %d" % sfx_pct


func _set_switch(b: Button, on: bool, spoken: String, animate: bool = false) -> void:
	(b.get_meta(&"switch") as Switch).set_on(on, animate)
	b.accessibility_name = "%s, %s" % [spoken, "açık" if on else "kapalı"]


## Kaydedilmiş değerlerle açar.
func open() -> void:
	var st := _settings()
	set_values(st.music_pct, st.sfx_pct, st.vibration_on)
	scroll.scroll_vertical = 0
	licenses.visible = false
	visible = true
	back_button.grab_focus.call_deferred()


## Klavye/odak ile değişen (bırakma olayı olmayan) değerler de yazılır.
func close() -> void:
	if licenses.visible:  # Android geri: önce LİSANSLAR alt ekranı kapanır, ayarlar açık kalır
		_close_licenses()
		return
	visible = false
	_settings().save_settings()
	back_requested.emit()


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra. Başlık üst paya göre iner, liste
## başlığın altından başlar, GERİ alt paya göre yukarı çıkar; liste GERİ'nin üstünde biter.
func apply_safe_area(extra: Variant = null) -> void:
	var e := Vector4.ZERO
	if extra is Vector4:
		e = extra
	else:
		e = UiKit.current_safe_extra(Vector2(1080.0, 2400.0))
	if scroll == null:
		return
	var shift := (e.x - e.z) * 0.5
	_title_box.offset_top = TITLE_TOP + e.y
	_title_box.offset_bottom = TITLE_TOP + e.y + 120.0
	scroll.offset_top = LIST_TOP + e.y
	scroll.offset_bottom = BACK_TOP - e.w - 24.0
	scroll.offset_left = -W * 0.5 + shift
	scroll.offset_right = W * 0.5 + shift
	back_button.offset_top = BACK_TOP - e.w
	back_button.offset_bottom = BACK_TOP - e.w + BACK_H
	back_button.offset_left = -W * 0.5 + shift
	back_button.offset_right = W * 0.5 + shift
	_lic_title.offset_top = TITLE_TOP + e.y
	_lic_title.offset_bottom = TITLE_TOP + e.y + 120.0
	_lic_card.offset_top = LIST_TOP + 10.0 + e.y
	lic_back_button.offset_top = BACK_TOP - e.w
	lic_back_button.offset_bottom = BACK_TOP - e.w + BACK_H
	lic_back_button.offset_left = -W * 0.5 + shift
	lic_back_button.offset_right = W * 0.5 + shift


func _settings() -> Node:
	return get_node(^"/root/Settings")


func _on_sound() -> void:
	_settings().set_sound(not _sound_on)
	set_values(int(music_slider.value), int(sfx_slider.value), _vibration_on, true)
	sound_toggled.emit(_sound_on)


func _on_vibration() -> void:
	set_values(int(music_slider.value), int(sfx_slider.value), not _vibration_on, true)
	vibration_toggled.emit(_vibration_on)


func _on_hareket() -> void:
	_settings().set_hareket_azalt(not _hareket_on)
	set_values(int(music_slider.value), int(sfx_slider.value), _vibration_on, true)
	hareket_azalt_toggled.emit(_hareket_on)


func _rail(skin: String) -> StyleBox:
	var sb := UiKit.skin_box(skin, 24, UiKit.BORDO_500) as StyleBox
	if sb is StyleBoxTexture:
		var t := sb as StyleBoxTexture
		t.texture_margin_top = 0
		t.texture_margin_bottom = 0
		t.content_margin_top = RAIL_H / 2.0
		t.content_margin_bottom = RAIL_H / 2.0
	return sb


## Yumuşak kenarlı yuvarlak tutamak (doku yoksa yedek).
func _grabber_tex(color: Color) -> Texture2D:
	var img := Image.create(GRABBER, GRABBER, false, Image.FORMAT_RGBA8)
	var c := Vector2(GRABBER, GRABBER) * 0.5
	var r := GRABBER * 0.5 - 2.0
	for y in GRABBER:
		for x in GRABBER:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var edge := clampf(r - d + 0.5, 0.0, 1.0)
			var ring := clampf(d - (r - 7.0), 0.0, 1.0)
			var col := color.lerp(UiKit.KAHVE_900, ring * 0.9)
			img.set_pixel(x, y, Color(col, edge))
	return ImageTexture.create_from_image(img)


func _vertical_fade(from: Color, to: Color) -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([from, to])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	return t
