class_name AchievementsScreen
extends Control
## Başarımlar ekranı (aile/kademe, v2.0.3). Kayıt yazmaz, tracker bilmez; ilerleme `AchievementProgress.of(def, store)`.
## DESIGN v2.0.3 §4. Yerleşim (1080×2400): başlık y130, özet "31 / 53 kademe" y262, kroniği şeridi (5 grup mührü) y344,
## liste y520–2172 (kaydırmalı), GERİ 936×132 alt 72. Grup başlığı 936×72 (THE WATCH ...), aile satırı 936×150 (AchievementRow);
## satıra dokunmak onu açar/kapatır (aynı anda 1 açık), mühüre dokunmak gruba kaydırır, sürükleme listeyi kaydırır.

signal back_requested

const W := 936.0
const Y_TITLE := 130.0
const Y_SUM := 262.0
const Y_CHRON := 344.0
const Y_LIST := 520.0
const ROW_GAP := 12.0
const GROUP_H := 72.0
const PANEL_H := 108.0
const BACK_H := 132.0
const BOTTOM := 72.0
const TOP_DEFAULT := 96.0
const DESIGN_H := 2400.0
const SCROLL_W := 8.0  # kaydırma ipucu sütunu (içeriğin sağında)
const OTHER_GROUP := "DİĞER"  # `group` alanı olmayan (v2.0 tek eşikli) kayıtlar

var title_label: Label
var count_label: Label
var count_sub: Label
var chronicle: AchievementChronicle
var list: ScrollContainer
var content: VBoxContainer
var back_button: Button
var error_label: Label
## Satır düğümleri (görünür sıra): her satırın `meta("id")` değeri aile kimliği.
var rows: Array[AchievementRow] = []
## Açık (kademe yolu görünen) aile; &"" = hepsi kapalı.
var open_id: StringName = &""

var _extra := Vector4.ZERO
var _data: GameData = null
var _store: AchievementStore = null
var _row_w: float = 0.0
var _list_size := Vector2.ZERO
var _x0: float = 72.0
var _w: float = W
var _built: bool = false
var _open_n: int = 0
var _total: int = 0
var _fade_top: TextureRect
var _fade_bottom: TextureRect
## Yapışkan grup başlığı (DESIGN §5.1): kaydırınca üstteki grubun başlığı liste tepesinde kalır.
var sticky: Control = null
var _groups: Array[Dictionary] = []  # {name, opened, total, node}
var _sticky_idx: int = -1


func _init() -> void:
	visible = false


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	var bg := ColorRect.new()
	bg.color = UiKit.MOR_900
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)
	title_label = UiKit.label("BAŞARIMLAR", &"LabelTitle", 80)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)
	count_label = UiKit.label("0 / 0", &"LabelTimer", 56, UiKit.KEMIK_100)
	add_child(count_label)
	count_sub = UiKit.label("kademe", &"", 32, UiKit.KEMIK_300)
	count_sub.add_theme_font_override(&"font", UiKit.font_semibold())
	add_child(count_sub)
	chronicle = AchievementChronicle.new()
	chronicle.name = "Chronicle"
	chronicle.group_selected.connect(scroll_to_group)
	add_child(chronicle)
	list = ScrollContainer.new()
	list.name = "List"
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list.mouse_filter = Control.MOUSE_FILTER_STOP
	list.scroll_deadzone = 12
	UiKit.touch_scroll(list)
	add_child(list)
	content = VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", int(ROW_GAP))
	list.add_child(content)
	_fade_top = _fade(true)
	_fade_bottom = _fade(false)
	list.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _update_sticky())
	error_label = UiKit.label("Başarım listesi yüklenemedi", &"", 34, UiKit.KEMIK_300)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.visible = false
	add_child(error_label)
	back_button = UiKit.button("GERİ", &"secondary", BACK_H)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(back_button)
	_layout()


## Üst/alt 80 px solma perdesi (liste kenarında).
func _fade(top: bool) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var a := UiKit.MOR_900
	var b := Color(UiKit.MOR_900, 0.0)
	g.colors = PackedColorArray([a, b] if top else [b, a])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 80
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func open(data: GameData, store: AchievementStore) -> void:
	_build()
	_data = data
	_store = store
	open_id = &""
	_populate()
	_layout()
	list.scroll_vertical = 0
	back_button.grab_focus.call_deferred()


## Satırları geçerli genişlikte (`_w`) yeniden kurar (19 aile; ucuz).
func _populate() -> void:
	var data := _data
	var store := _store
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()  # satırın kendi `pressed` sinyalinden çağrılabilir: anında free() hata verir
	rows.clear()
	_groups.clear()
	_sticky_idx = -1
	if sticky != null:
		sticky.visible = false
	_row_w = _w
	var defs: Array[AchievementDef] = data.achievements if data != null else []
	_total = 0
	for d in defs:
		_total += AchievementStep.total(d)
	_open_n = store.count_steps(defs) if store != null else 0
	var failed := defs.is_empty() or _total == 0
	error_label.visible = failed
	list.visible = not failed
	count_label.visible = not failed
	count_sub.visible = not failed
	chronicle.visible = not failed
	_fade_top.visible = not failed
	_fade_bottom.visible = not failed
	if not failed:
		count_label.text = "%d / %d" % [_open_n, _total]
		count_label.add_theme_color_override(
			&"font_color", UiKit.AMBER if _open_n == _total else UiKit.KEMIK_100
		)
		_fill(defs, store)
	accessibility_name = "Başarımlar, %d / %d kademe" % [_open_n, _total]


func row_count() -> int:
	return rows.size()


## extra: Vector4(sol, üst, sağ, alt) ya da null (UiKit.current_safe_extra).
func apply_safe_area(extra: Variant = null) -> void:
	if extra is Vector4:
		_extra = extra
	else:
		_extra = UiKit.current_safe_extra(Vector2(1080.0, DESIGN_H))
	_layout()


func _fill(defs: Array[AchievementDef], store: AchievementStore) -> void:
	if _open_n == 0:
		content.add_child(_info_panel("Henüz kademe açılmadı. Bir koşuya başla."))
	elif _open_n == _total:
		content.add_child(_info_panel("Tüm başarımlar açıldı."))
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var opened: Array[int] = []
	var totals: Array[int] = []
	var names: Array[String] = []
	for g in AchievementDef.GROUPS:
		names.append(g)
	if defs.any(func(d: AchievementDef) -> bool: return not names.has(String(d.group))):
		names.append(OTHER_GROUP)
	for gi in names.size():
		var in_group: Array[AchievementDef] = []
		for d in defs:
			var gn := String(d.group) if names.has(String(d.group)) else OTHER_GROUP
			if gn == names[gi]:
				in_group.append(d)
		var o := 0
		var t := 0
		for d in in_group:
			o += mini(store.step_count(d.id) if store != null else 0, AchievementStep.total(d))
			t += AchievementStep.total(d)
		if gi < AchievementDef.GROUPS.size():
			opened.append(o)
			totals.append(t)
		if in_group.is_empty():
			continue
		var gh := _group_header(names[gi], o, t)
		content.add_child(gh)
		_groups.append({"name": names[gi], "opened": o, "total": t, "node": gh})
		for d in in_group:
			var row := AchievementRow.new()
			row.setup(d, store, _w, d.id == open_id, bias)
			row.pressed.connect(_on_row_pressed.bind(d.id))
			content.add_child(row)
			rows.append(row)
	chronicle.set_state(opened, totals)


## Satıra dokunma: kapalıysa açar (öncekini kapatır), açıksa kapatır. Kaydırma konumu korunur.
func _on_row_pressed(id: StringName) -> void:
	open_id = &"" if open_id == id else id
	var keep := list.scroll_vertical
	_populate()
	_layout_chronicle()
	list.set_deferred(&"scroll_vertical", keep)


## Grup başlığına kaydırır (kroniği mührü); geçersiz ya da boş grup yok sayılır.
func scroll_to_group(index: int) -> void:
	if index < 0 or index >= AchievementDef.GROUPS.size():
		return
	for g in _groups:
		if g["name"] == AchievementDef.GROUPS[index]:
			_scroll_to_node.call_deferred(g["node"])
			return


func _scroll_to_node(n: Control) -> void:
	if list != null and is_instance_valid(n):
		list.scroll_vertical = int(n.position.y)


## Kaydırma konumuna göre üstte kalan grubun başlığını liste tepesine sabitler; sıradaki başlık yaklaşınca onu iter.
func _update_sticky(scroll: float = -1.0) -> void:
	if list == null or _groups.is_empty():
		return
	var sc := float(list.scroll_vertical) if scroll < 0.0 else scroll
	var cur := -1
	for i in _groups.size():
		if (_groups[i]["node"] as Control).position.y < sc:
			cur = i
	if cur < 0:
		if sticky != null:
			sticky.visible = false
		return
	if cur != _sticky_idx or sticky == null:
		if sticky != null:
			sticky.free()
		var g := _groups[cur]
		sticky = Panel.new()
		sticky.name = "StickyHeader"
		sticky.custom_minimum_size = Vector2(_w, GROUP_H)
		sticky.size = Vector2(_w, GROUP_H)
		sticky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sticky.add_theme_stylebox_override(
			&"panel", UiKit.stylebox(Color(UiKit.MOR_900, 1.0), Color(0, 0, 0, 0), 0, 0)
		)
		sticky.add_child(_group_header(g["name"], g["opened"], g["total"]))
		add_child(sticky)
		move_child(sticky, -1)  # SD-02: solma perdesinin ÜSTÜNDE, opak
		_sticky_idx = cur
	var push := 0.0
	if cur + 1 < _groups.size():
		var gap := (_groups[cur + 1]["node"] as Control).position.y - sc
		push = minf(0.0, gap - GROUP_H)
	sticky.position = Vector2(_x0, list.position.y + push)
	sticky.visible = true


func _info_panel(text: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(_w, PANEL_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override(&"panel", UiKit.stylebox(UiKit.MOR_800, UiKit.KAHVE_500, 4, 14))
	var l := UiKit.label(text, &"", 32, UiKit.KEMIK_300)
	l.add_theme_font_override(&"font", UiKit.font_semibold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.fill(l)
	p.add_child(l)
	return p


func _group_header(group_name: String, opened: int, total: int) -> Control:
	var h := Control.new()
	h.name = "Group_%s" % group_name.replace(" ", "_")
	h.custom_minimum_size = Vector2(_w, GROUP_H)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var done := opened == total
	var t := UiKit.label(group_name, &"LabelTimer", 34, UiKit.BRONZ_300)  # sabit büyük harf: upper_tr kullanılmaz
	t.position = Vector2(8.0, 18.0)
	t.size = Vector2(_w - 16.0 - 240.0, 44.0)
	h.add_child(t)
	var c := UiKit.label(
		"%d / %d" % [opened, total], &"", 28, UiKit.AMBER if done else UiKit.KEMIK_300
	)
	c.add_theme_font_override(&"font", UiKit.font_bold())
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.position = Vector2(_w - 8.0 - 240.0, 20.0)
	c.size = Vector2(240.0, 40.0)
	h.add_child(c)
	return h


func _layout() -> void:
	if not _built:
		return
	_x0 = maxf(72.0, UiKit.SAFE_EDGE + _extra.x)
	var x1 := 1080.0 - maxf(72.0, UiKit.SAFE_EDGE + _extra.z)
	_w = minf(W, x1 - _x0)
	if _w < W:
		_w -= SCROLL_W  # dar alanda kaydırma ipucu da güvenli alanın içinde kalır
	_x0 = (1080.0 - _w) * 0.5 if _w >= W else _x0
	var dy := maxf(0.0, _extra.y - (Y_TITLE - TOP_DEFAULT))
	_abs(title_label, 0.0, Y_TITLE + dy, 1080.0, 110.0)
	var f := UiKit.font(&"display")
	var cw := f.get_string_size(count_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	var sw := UiKit.font_semibold().get_string_size("kademe", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var sx := (1080.0 - (cw + 16.0 + sw)) * 0.5
	_abs(count_label, sx, Y_SUM + dy, cw + 4.0, 68.0)
	_abs(count_sub, sx + cw + 16.0, Y_SUM + dy + 22.0, sw + 4.0, 44.0)
	_layout_chronicle(dy)
	var back_y := DESIGN_H - BOTTOM - _extra.w - BACK_H
	_abs(back_button, _x0, back_y, _w, BACK_H)
	var top := Y_LIST + dy
	var h := maxf(back_y - 24.0 - top, 0.0)
	_abs(list, _x0, top, _w + SCROLL_W, h)
	_list_size = Vector2(_w + SCROLL_W, h)
	_fit_list.call_deferred()
	if _data != null and absf(_w - _row_w) > 0.5:
		_populate()
	content.custom_minimum_size = Vector2(_w, 0.0)
	_sticky_idx = -1  # genişlik değişmiş olabilir: yapışkan başlık yeniden kurulur
	_abs(_fade_top, _x0, top, _w, 80.0)
	_abs(_fade_bottom, _x0, top + h - 80.0, _w, 80.0)
	_abs(error_label, _x0, top, _w, h)


## Satırlar daraldığında ScrollContainer'ın en küçük boyutu bir kare sonra düşer; boyutu o zaman yeniden uygular.
func _fit_list() -> void:
	if list != null and is_instance_valid(list):
		list.size = _list_size


func _layout_chronicle(dy: float = -1.0) -> void:
	if chronicle == null:
		return
	if dy < 0.0:
		dy = maxf(0.0, _extra.y - (Y_TITLE - TOP_DEFAULT))
	chronicle.position = Vector2(_x0, Y_CHRON + dy)
	chronicle.layout(_w)


func _abs(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
