class_name RunScreen
extends Control
## v2.1 KOŞU ekranı (docs/design/v2.1/DESIGN.md §3): "Hangi koşuyu, ne kadar zorlukta oynayacağım?" Üç mod satırı (HIZLI /
## NORMAL / SONSUZ), üç zorluk kartı (KOLAY / NORMAL / ZOR), seçili zorluğun ayrıntı levhası ve kural levhası; GERİ sabit.
## Dokun = seç + anında kaydet (V21Runs.set_selection -> Settings); onay düğmesi yok. Koşuda değişmez (menüden açılır).
## Sayılar ve süreler `data/run_profiles.json`'dan (V21Runs.profiles), metinler RunStrip'tedir. 2× yazıda (font_scale > 1,3)
## satırlar uzar, zorluk kartları dikey sıraya düşer; liste kayar, GERİ sabittir.

signal back_requested
signal selection_changed(mode: StringName, diff: StringName)

const W := 936.0
const TITLE_TOP := 96.0
const LIST_TOP := 250.0
const BACK_H := 132.0
const BACK_TOP := 2196.0
const MODE_H := 184.0
const MODE_H_BIG := 336.0
const MODE_GAP := 16
const CARD_W := 296.0
const CARD_H := 272.0
const CARD_GAP := 24
const CARD_H_BIG := 260.0
const BIG_SCALE := 1.3
const FADE_SEC := 0.14
const SECTION_GAP := 30

var title_label: Label
var back_button: Button
var scroll: ScrollContainer
var column: VBoxContainer
## mod/zorluk kimliği (StringName) -> Button; testler ve odak için açık.
var mode_buttons: Dictionary = {}
var diff_buttons: Dictionary = {}
var detail_panel: PanelContainer
var rules_panel: PanelContainer

var _mode: StringName = &"normal"
var _diff: StringName = &"normal"
var _big: bool = false
var _title_box: Control
var _fades: Dictionary = {}  # Control -> Tween
var _seals: Dictionary = {}  # Button -> Seal
var _detail_rows: VBoxContainer
var _rule_rows: VBoxContainer


## Seçili satır/kart mührü: bordo daire + amber halka + ✓ (renk dışı ikinci kanal, DESIGN §3).
class Seal:
	extends Control

	func _init(p_size := 56.0) -> void:
		custom_minimum_size = Vector2(p_size, p_size)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, UiKit.BORDO_900)
		draw_arc(c, r - 2.0, 0.0, TAU, 32, UiKit.AMBER, 3.0, true)
		var pts := PackedVector2Array(
			[
				c + Vector2(-r * 0.42, 0.0),
				c + Vector2(-r * 0.1, r * 0.34),
				c + Vector2(r * 0.46, -r * 0.34)
			]
		)
		draw_polyline(pts, UiKit.KEMIK_100, maxf(3.0, r * 0.14), true)


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false
	visibility_changed.connect(_on_visibility)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.TAS_900
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)
	var glow := TextureRect.new()  # üstten sıcak tek ışık (ayarlar ekranıyla aynı sakin oda)
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
	column.add_theme_constant_override(&"separation", SECTION_GAP)
	scroll.add_child(column)
	_build_list()

	_title_box = PanelContainer.new()
	_title_box.add_theme_stylebox_override(&"panel", UiKit.skin_box("lento", 60, UiKit.TAS_800))
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.anchor_left = 0.5
	_title_box.anchor_right = 0.5
	_title_box.offset_left = -260.0
	_title_box.offset_right = 260.0
	_title_box.offset_top = TITLE_TOP
	_title_box.offset_bottom = TITLE_TOP + 120.0
	title_label = UiKit.label("KOŞU", &"LabelTitle", 64)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_box.add_child(title_label)
	add_child(_title_box)

	back_button = UiKit.back_button(BACK_H)
	back_button.anchor_left = 0.5
	back_button.anchor_right = 0.5
	back_button.offset_left = -W * 0.5
	back_button.offset_right = W * 0.5
	back_button.offset_top = BACK_TOP
	back_button.offset_bottom = BACK_TOP + BACK_H
	back_button.pressed.connect(close)
	add_child(back_button)


## Liste gövdesi (MOD, ZORLUK, ayrıntı, kural). 2× yazı değişince baştan kurulur.
func _build_list() -> void:
	mode_buttons = {}
	diff_buttons = {}
	_seals = {}
	column.add_child(_section("MOD"))
	var modes := VBoxContainer.new()
	modes.name = "Modes"
	modes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modes.add_theme_constant_override(&"separation", MODE_GAP)
	for m in RunStrip.MODE_ORDER:
		var b := _mode_row(m)
		mode_buttons[m] = b
		modes.add_child(b)
	column.add_child(modes)
	column.add_child(_section("ZORLUK"))
	var cards: BoxContainer = VBoxContainer.new() if _big else HBoxContainer.new()
	cards.name = "Difficulties"
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override(&"separation", MODE_GAP if _big else CARD_GAP)
	for d in RunStrip.DIFF_ORDER:
		var b := _diff_card(d)
		diff_buttons[d] = b
		cards.add_child(b)
	column.add_child(cards)
	detail_panel = _panel()
	detail_panel.name = "Detail"
	_detail_rows = _panel_rows(detail_panel)
	column.add_child(detail_panel)
	rules_panel = _panel()
	rules_panel.name = "Rules"
	_rule_rows = _panel_rows(rules_panel)
	column.add_child(rules_panel)


func _section(text: String) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 18)
	var t := UiKit.label(text, &"LabelAccent", _fs(34))
	t.add_theme_constant_override(&"shadow_offset_y", 0)
	head.add_child(t)
	var line := ColorRect.new()
	line.color = UiKit.BRONZ_700
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size.y = 3.0
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(line)
	return head


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiKit.skin_box("levha", 40, UiKit.TAS_800)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	p.add_theme_stylebox_override(&"panel", sb)
	return p


func _panel_rows(p: PanelContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override(&"separation", 6)
	p.add_child(v)
	return v


func _skin(b: Button, selected: bool) -> void:
	var skin := "dugme-birincil" if selected else "dugme-dolu"
	for st in [&"normal", &"hover", &"disabled"]:
		b.add_theme_stylebox_override(st, UiKit.skin_box(skin, 40, UiKit.TAS_700))
	b.add_theme_stylebox_override(&"pressed", UiKit.skin_box("dugme-basili", 40, UiKit.TAS_800))
	b.add_theme_stylebox_override(&"focus", UiKit.stylebox(Color(0, 0, 0, 0), UiKit.AMBER, 6, 14))


func _seal_for(b: Button) -> void:
	var s := Seal.new()
	s.anchor_left = 1.0
	s.anchor_right = 1.0
	s.offset_left = -72.0
	s.offset_right = -16.0
	s.offset_top = 14.0
	s.offset_bottom = 70.0
	s.visible = false  # _apply_selection yalnız seçiliyi açar
	b.add_child(s)
	_seals[b] = s


func _mode_row(m: StringName) -> Button:
	var b := Button.new()
	b.name = "Mode_%s" % m
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, MODE_H_BIG if _big else MODE_H)
	_skin(b, false)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override(&"separation", 24)
	UiKit.fill(h)
	h.offset_left = 28.0
	h.offset_right = -28.0
	var g := RunStrip.ModeGlyph.new(m, UiKit.BRONZ_300, 84.0 * (1.5 if _big else 1.0))
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(g)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UiKit.label(RunStrip.MODE_NAMES[m], &"LabelAccent", _fs(44), UiKit.KEMIK_100))
	var d := UiKit.label(RunStrip.mode_desc(m, V21Runs.profiles()), &"", _fs(28), UiKit.KEMIK_300)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	h.add_child(v)
	var span := UiKit.label(RunStrip.duration_text(m, V21Runs.profiles()), &"LabelAccent", _fs(38))
	span.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if span.text == "∞":  # Cinzel'de ∞ yok: gövde yazı tipi
		span.theme_type_variation = &""
		span.add_theme_font_size_override(&"font_size", _fs(40))
		span.add_theme_color_override(&"font_color", UiKit.KEMIK_100)
	h.add_child(span)
	b.add_child(h)
	_seal_for(b)
	b.pressed.connect(_select_mode.bind(m))
	return b


func _diff_card(d: StringName) -> Button:
	var b := Button.new()
	b.name = "Diff_%s" % d
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0 if _big else CARD_W, CARD_H_BIG if _big else CARD_H)
	if not _big:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(b, false)
	var shields := RunStrip.Shields.new(
		int(RunStrip.SHIELDS[d]), UiKit.BRONZ_300, Vector2(126, 42) if _big else Vector2(84, 28)
	)
	var name_l := UiKit.label(RunStrip.DIFF_NAMES[d], &"LabelAccent", _fs(40), UiKit.KEMIK_100)
	var desc := UiKit.label(RunStrip.DIFF_DESC[d], &"", _fs(26), UiKit.KEMIK_300)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var box: BoxContainer = HBoxContainer.new() if _big else VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 20 if _big else 10)
	UiKit.fill(box)
	box.offset_left = 24.0
	box.offset_right = -24.0
	box.offset_top = 16.0
	box.offset_bottom = -16.0
	shields.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shields.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # VBox: çapraz eksen yatay
	box.add_child(shields)
	if _big:
		var tv := VBoxContainer.new()
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(name_l)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(desc)
		box.add_child(tv)
	else:
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_l)
		box.add_child(desc)
	b.add_child(box)
	_seal_for(b)
	b.pressed.connect(_select_diff.bind(d))
	return b


## 2× yazı: satırlar uzar, kartlar dikey sıraya düşer (liste yeniden kurulur).
func set_font_scale(f: float) -> void:
	var big := f > BIG_SCALE
	if big == _big or column == null:
		return
	_big = big
	for c in column.get_children():
		column.remove_child(c)
		c.queue_free()
	_build_list()
	_apply_selection(false)


func is_big() -> bool:
	return _big


## 2×'te yazı ×1,6 (tasarım: ad 44→64, açıklama 28→44, süre 38→56 civarı).
func _fs(base: int) -> int:
	return roundi(float(base) * 1.6) if _big else base


func selection() -> Dictionary:
	return {"mode": _mode, "diff": _diff}


func _select_mode(m: StringName) -> void:
	V21Runs.set_selection(m, V21Runs.selection()["diff"])
	_apply_selection(true)
	selection_changed.emit(_mode, _diff)


func _select_diff(d: StringName) -> void:
	V21Runs.set_selection(V21Runs.selection()["mode"], d)
	_apply_selection(true)
	selection_changed.emit(_mode, _diff)


## Kaydedilmiş seçimi (V21Runs) ekrana yansıtır: yüzey, mühür, a11y adı, ayrıntı ve kural levhaları.
func _apply_selection(animate: bool) -> void:
	var sel := V21Runs.selection()
	_mode = sel["mode"]
	_diff = sel["diff"]
	var cfg := V21Runs.profiles()
	for m in mode_buttons:
		var b: Button = mode_buttons[m]
		var on: bool = m == _mode
		_skin(b, on)
		(_seals[b] as Control).visible = on
		b.accessibility_name = RunStrip.mode_a11y(m, cfg, on)
	for d in diff_buttons:
		var b: Button = diff_buttons[d]
		var on: bool = d == _diff
		_skin(b, on)
		(_seals[b] as Control).visible = on
		b.accessibility_name = RunStrip.diff_a11y(d, on)
	_fill_detail(cfg)
	_fill_rules()
	if animate:
		_fade(detail_panel)
		_fade(rules_panel)


func _fill_detail(cfg: Dictionary) -> void:
	_clear(_detail_rows)
	for r in RunStrip.detail_rows(_diff, cfg):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size.y = 110.0 if _big else 64.0
		var l := UiKit.label(r[0], &"", _fs(30), UiKit.KEMIK_300)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		var v := UiKit.label(r[1], &"LabelAccent", _fs(34), UiKit.KEMIK_100)
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(v)
		_detail_rows.add_child(row)
	detail_panel.accessibility_name = RunStrip.detail_a11y(_diff, cfg)


func _fill_rules() -> void:
	_clear(_rule_rows)
	for line in RunStrip.rule_lines(_mode, _diff):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 16)
		if line["warn"]:
			var w := RunStrip.WarnGlyph.new(56.0 if _big else 40.0)
			w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(w)
		var l := UiKit.label(
			line["text"], &"", _fs(28), UiKit.KEMIK_100 if line["warn"] else UiKit.KEMIK_300
		)
		if line["warn"]:
			l.add_theme_font_override(&"font", UiKit.font_semibold())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.custom_minimum_size.y = 110.0 if _big else 64.0
		_rule_rows.add_child(row)
	var warns := PackedStringArray()
	for line in RunStrip.rule_lines(_mode, _diff):
		warns.append(("Uyarı: " if line["warn"] else "") + line["text"])
	rules_panel.accessibility_name = " ".join(warns)


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


## 140 ms çapraz geçiş; `hareket_azalt` açıkken anlık.
func _fade(c: Control) -> void:
	if _reduce_motion() or not is_inside_tree():
		return
	if _fades.has(c) and _fades[c].is_valid():
		_fades[c].kill()
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, FADE_SEC)
	_fades[c] = tw


func _reduce_motion() -> bool:
	var st := get_node_or_null(^"/root/Settings")
	return st != null and st.hareket_azalt


## Ekran görünür olunca (controller `visible`'ı sürer): yazı ölçeği + kayıtlı seçim yansır, seçili satır görünüme kayar.
func _on_visibility() -> void:
	if not visible or column == null:
		return
	var st := get_node_or_null(^"/root/Settings")
	if st != null:
		set_font_scale(st.font_scale())
	_apply_selection(false)
	scroll.scroll_vertical = 0
	_focus_selected.call_deferred()


func _focus_selected() -> void:
	var b: Button = mode_buttons.get(_mode, back_button)
	scroll.ensure_control_visible(b)
	b.grab_focus()


## GERİ ya da Android geri: ekran kapanır, back_requested yayılır (controller menüye döner).
func close() -> void:
	visible = false
	back_requested.emit()


## Güvenli alan payı: Vector4(sol, üst, sağ, alt). Başlık üst paya göre iner, liste başlığın altından başlar, GERİ alt paya
## göre yukarı çıkar; yan paylarda liste kayar.
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
