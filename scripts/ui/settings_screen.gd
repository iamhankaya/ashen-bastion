class_name SettingsScreen
extends Control
## Ayarlar ekranı (menüden ve duraklatmadan açılır, GERİ ile döner). MÜZİK ve EFEKT kaydırıcıları (%0-100, %5 adım,
## yanında yüzde etiketi) ile TİTREŞİM anahtarı. Kaydırırken ses anında değişir (persist=false), bırakınca kaydedilir;
## efekt bırakılınca örnek atış sesi çalar. Tam ekran opak zemin; ScrollContainer yok (içerik 1080×2400'e sığar),
## bu yüzden kaydırıcı sürüklemesi `UiKit.touch_scroll` ile çakışmaz.

## close() sonrası yayınlanır (bilgi amaçlı).
signal back_requested
signal vibration_toggled(on: bool)

const W := 936.0
const COL_TOP := 380.0
const SLIDER_H := 132.0  # dokunma alanı (tutamak 84 px, ray 20 px)
const GRABBER := 84
const RAIL_H := 20
const PREVIEW_ID := &"shot_right"

var title_label: Label
var music_slider: HSlider
var sfx_slider: HSlider
var music_value: Label
var sfx_value: Label
var vibration_button: Button
var back_button: Button
var column: VBoxContainer

var _vibration_on: bool = true
var _grabber: Texture2D = null


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.MOR_900
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)

	column = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 27)
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.offset_left = -W * 0.5
	column.offset_right = W * 0.5
	column.offset_top = COL_TOP
	add_child(column)

	title_label = UiKit.label("AYARLAR", &"LabelTitle")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_constant_override(&"shadow_offset_y", 5)
	column.add_child(title_label)
	column.add_child(UiKit.divider())

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override(&"separation", 18)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music_slider = _slider_row(pv, "MÜZİK")
	music_value = music_slider.get_meta(&"value_label")
	sfx_slider = _slider_row(pv, "EFEKT")
	sfx_value = sfx_slider.get_meta(&"value_label")
	music_slider.value_changed.connect(func(v: float) -> void: _changed(music_slider, v, false))
	sfx_slider.value_changed.connect(func(v: float) -> void: _changed(sfx_slider, v, false))
	music_slider.drag_ended.connect(
		func(_c: bool) -> void: _changed(music_slider, music_slider.value, true)
	)
	sfx_slider.drag_ended.connect(
		func(_c: bool) -> void: _changed(sfx_slider, sfx_slider.value, true)
	)
	panel.add_child(pv)
	column.add_child(panel)

	vibration_button = UiKit.button("", &"secondary")
	vibration_button.pressed.connect(_on_vibration)
	column.add_child(vibration_button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 300)
	column.add_child(spacer)
	back_button = UiKit.button("GERİ", &"primary", 156.0)
	back_button.add_theme_font_size_override(&"font_size", 52)
	back_button.pressed.connect(close)
	column.add_child(back_button)
	set_values(AudioMix.MAX_PCT, AudioMix.MAX_PCT, true)


## Başlık + kaydırıcı + yüzde etiketi satırı; `value_label` meta'sında etiket.
func _slider_row(parent: Control, caption: String) -> HSlider:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiKit.label(caption, &"LabelAccent", 40)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var val := UiKit.label("100%", &"", 44, UiKit.KEMIK_100)
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
	s.add_theme_stylebox_override(&"slider", _rail(UiKit.MOR_700, UiKit.MOR_500))
	s.add_theme_stylebox_override(&"grabber_area", _rail(UiKit.BORDO_500, UiKit.BORDO_400))
	s.add_theme_stylebox_override(
		&"grabber_area_highlight", _rail(UiKit.BORDO_400, UiKit.BORDO_400)
	)
	s.add_theme_icon_override(&"grabber", _grabber_tex(UiKit.BRONZ_300))
	s.add_theme_icon_override(&"grabber_highlight", _grabber_tex(UiKit.AMBER))
	s.add_theme_icon_override(&"grabber_disabled", _grabber_tex(UiKit.BRONZ_700))
	s.gui_input.connect(_on_slider_input.bind(s))
	s.set_meta(&"value_label", val)
	parent.add_child(s)
	return s


## Cihazda `emulate_mouse_from_touch` kapalı: dokunma/sürükleme olayları değere doğrudan çevrilir (fare yolu
## Slider'ın kendisinde; emülasyon olayları (device -1) atlanır, çift işleme olmaz). Olay tüketilir, ekran kaymaz.
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
func _changed(s: HSlider, v: float, final: bool) -> void:
	var pct := AudioMix.clamp_pct(v)
	var st := _settings()
	if s == music_slider:
		music_value.text = "%d%%" % pct
		st.set_music_pct(pct, final)
	else:
		sfx_value.text = "%d%%" % pct
		st.set_sfx_pct(pct, final)
		if final:
			Sfx.play(PREVIEW_ID)


## Değerleri dışarıdan ayarla (sinyal yaymaz).
func set_values(music_pct: int, sfx_pct: int, vib: bool) -> void:
	_vibration_on = vib
	if music_slider != null:
		music_slider.set_value_no_signal(music_pct)
		sfx_slider.set_value_no_signal(sfx_pct)
		music_value.text = "%d%%" % music_pct
		sfx_value.text = "%d%%" % sfx_pct
		vibration_button.text = UiKit.toggle_text("TİTREŞİM", vib)


## Kaydedilmiş değerlerle açar.
func open() -> void:
	var st := _settings()
	set_values(st.music_pct, st.sfx_pct, st.vibration_on)
	visible = true
	back_button.grab_focus.call_deferred()


## Klavye/odak ile değişen (bırakma olayı olmayan) değerler de yazılır.
func close() -> void:
	visible = false
	_settings().save_settings()
	back_requested.emit()


func _settings() -> Node:
	return get_node(^"/root/Settings")


func _on_vibration() -> void:
	set_values(int(music_slider.value), int(sfx_slider.value), not _vibration_on)
	vibration_toggled.emit(_vibration_on)


func _rail(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := UiKit.stylebox(fill, border, 3, RAIL_H / 2)
	sb.content_margin_top = RAIL_H / 2.0
	sb.content_margin_bottom = RAIL_H / 2.0
	return sb


## Yumuşak kenarlı yuvarlak tutamak (doku dosyası gerekmez).
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
