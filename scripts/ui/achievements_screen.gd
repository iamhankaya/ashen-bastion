class_name AchievementsScreen
extends Control
## Başarımlar ekranı (liste). Kayıt yazmaz, tracker bilmez; ilerleme `AchievementProgress.of(def, store)`. DESIGN §5.1.
## Yerleşim (1080×2400): başlık y130, özet y262, çubuk y340 (936×20), liste y400–2172 (kaydırmalı), GERİ 936×132 alt 72.
## Satır 936×156 (aralık 12), grup başlığı 936×72 (KOLAY/ORTA/ZOR/ÇOK ZOR). Satırlar dokunulmaz; sürükleme listeyi kaydırır.

signal back_requested

const W := 936.0
const Y_TITLE := 130.0
const Y_SUM := 262.0
const Y_BAR := 340.0
const BAR_H := 20.0
const Y_LIST := 400.0
const ROW_H := 156.0
const DESC_H := 74.0  # SD-03: 28 px yazıda 2 satır = 70 px sığar
const ROW_GAP := 12.0
const GROUP_H := 72.0
const PANEL_H := 108.0
const BACK_H := 132.0
const BOTTOM := 72.0
const TOP_DEFAULT := 96.0
const DESIGN_H := 2400.0
const SCROLL_W := 8.0  # kaydırma ipucu sütunu (içeriğin sağında)
const GROUP_NAMES := ["KOLAY", "ORTA", "ZOR", "ÇOK ZOR"]

var title_label: Label
var count_label: Label
var count_sub: Label
var bar: Control
var list: ScrollContainer
var content: VBoxContainer
var back_button: Button
var error_label: Label
## Satır düğümleri (tanım sırası değil, görünür sıra): her satırın `meta("id")` değeri başarım kimliği.
var rows: Array[Control] = []

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
var _groups: Array[Dictionary] = []  # {tier, opened, total, node}
var _sticky_tier: int = -1


## Özet çubuğu: oran 0..1; hepsi açıksa amber.
class Bar:
	extends Control
	var ratio: float = 0.0
	var done: bool = false
	var thin: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := 10.0 if not thin else 7.0
		draw_style_box(
			UiKit.stylebox(UiKit.MOR_700, Color(0, 0, 0, 0), 0, int(r)), Rect2(Vector2.ZERO, size)
		)
		var fw := size.x * clampf(ratio, 0.0, 1.0)
		if fw >= 1.0:
			var col := UiKit.AMBER if done else UiKit.BRONZ_500
			draw_style_box(
				UiKit.stylebox(col, Color(0, 0, 0, 0), 0, int(r)),
				Rect2(0, 0, maxf(fw, r * 2.0), size.y)
			)


## Kademe baklavaları: dolu sayısı `count` (1..4), 16 px.
class Diamonds:
	extends Control
	var count: int = 1
	var color: Color = UiKit.BRONZ_300

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(4.0 * 22.0, 16.0)

	func _draw() -> void:
		for i in 4:
			var c := Vector2(8.0 + 22.0 * float(i), 8.0)
			var pts := PackedVector2Array(
				[c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]
			)
			if i < count:
				draw_colored_polygon(pts, color)
			else:
				pts.append(pts[0])
				draw_polyline(pts, Color(color, 0.45), 2.0)


## ✓ rozeti (açık) ya da kilit rozeti (kilitli).
class Badge:
	extends Control
	var locked: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		if locked:
			draw_circle(c, size.x * 0.5, Color(UiKit.VOID, 0.85))
			var s := size.x * 0.5
			draw_rect(Rect2(c.x - s * 0.45, c.y - s * 0.05, s * 0.9, s * 0.65), UiKit.KEMIK_300)
			draw_arc(c + Vector2(0, -s * 0.05), s * 0.32, PI, TAU, 14, UiKit.KEMIK_300, 3.0, true)
		else:
			draw_circle(c, size.x * 0.5, Color("#8DB58A"))
			var k := size.x / 44.0
			var pts := PackedVector2Array(
				[Vector2(11, 23) * k, Vector2(19, 31) * k, Vector2(33, 14) * k]
			)
			draw_polyline(pts, UiKit.VOID, 4.0, true)


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
	count_sub = UiKit.label("açıldı", &"", 32, UiKit.KEMIK_300)
	count_sub.add_theme_font_override(&"font", UiKit.font_semibold())
	add_child(count_sub)
	bar = Bar.new()
	add_child(bar)
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
	_populate()
	_layout()
	list.scroll_vertical = 0
	back_button.grab_focus.call_deferred()


## Satırları geçerli genişlikte (`_w`) yeniden kurar (liste 22 satır; ucuz).
func _populate() -> void:
	var data := _data
	var store := _store
	for c in content.get_children():
		content.remove_child(c)
		c.free()
	rows.clear()
	_groups.clear()
	_sticky_tier = -1
	if sticky != null:
		sticky.visible = false
	_row_w = _w
	var defs: Array[AchievementDef] = data.achievements if data != null else []
	_total = defs.size()
	var known: Array[StringName] = []
	for d in defs:
		known.append(d.id)
	_open_n = store.count_unlocked(known) if store != null else 0
	var failed := defs.is_empty()
	error_label.visible = failed
	list.visible = not failed
	count_label.visible = not failed
	count_sub.visible = not failed
	bar.visible = not failed
	_fade_top.visible = not failed
	_fade_bottom.visible = not failed
	if not failed:
		count_label.text = "%d / %d" % [_open_n, _total]
		(bar as Bar).ratio = float(_open_n) / float(_total)
		(bar as Bar).done = _open_n == _total
		bar.queue_redraw()
		count_label.add_theme_color_override(
			&"font_color", UiKit.AMBER if _open_n == _total else UiKit.KEMIK_100
		)
		_fill(defs, store)
	accessibility_name = "Başarımlar, %d / %d açıldı" % [_open_n, _total]


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
		content.add_child(_info_panel("Henüz açılan başarım yok. Bir koşuya başla."))
	elif _open_n == _total:
		content.add_child(_info_panel("Tüm başarımlar açıldı."))
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	for tier_i in AchievementDef.TIERS.size():
		var in_tier: Array[AchievementDef] = []
		for d in defs:
			if AchievementDef.tier_index(d.tier) == tier_i:
				in_tier.append(d)
		if in_tier.is_empty():
			continue
		var opened: Array[AchievementDef] = []
		var locked: Array[AchievementDef] = []
		for d in in_tier:
			if store != null and store.is_unlocked(d.id):
				opened.append(d)
			else:
				locked.append(d)
		var gh := _group_header(tier_i, opened.size(), in_tier.size())
		content.add_child(gh)
		_groups.append(
			{"tier": tier_i, "opened": opened.size(), "total": in_tier.size(), "node": gh}
		)
		for d in opened + locked:
			var row := _make_row(d, store, bias)
			content.add_child(row)
			rows.append(row)


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
	if cur != _sticky_tier or sticky == null:
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
		sticky.add_child(_group_header(g["tier"], g["opened"], g["total"]))
		add_child(sticky)
		move_child(sticky, -1)  # SD-02: solma perdesinin ÜSTÜNDE, opak
		_sticky_tier = cur
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


func _group_header(tier_i: int, opened: int, total: int) -> Control:
	var h := Control.new()
	h.name = "Group%d" % tier_i
	h.custom_minimum_size = Vector2(_w, GROUP_H)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := AchievementIcons.tier_color(StringName(AchievementDef.TIERS[tier_i]))
	var t := UiKit.label(GROUP_NAMES[tier_i], &"LabelTimer", 34, UiKit.BRONZ_300)
	t.position = Vector2(8.0, 18.0)
	t.size = Vector2(300.0, 44.0)
	h.add_child(t)
	var dm := Diamonds.new()
	dm.count = tier_i + 1
	dm.color = col
	dm.position = Vector2(8.0 + 190.0, 28.0)
	h.add_child(dm)
	var done := opened == total
	var c := UiKit.label(
		"%d / %d" % [opened, total], &"", 28, UiKit.AMBER if done else UiKit.KEMIK_300
	)
	c.add_theme_font_override(&"font", UiKit.font_bold())
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.position = Vector2(_w - 8.0 - 240.0, 20.0)
	c.size = Vector2(240.0, 40.0)
	h.add_child(c)
	return h


func _make_row(d: AchievementDef, store: AchievementStore, bias: int) -> Control:
	var is_open := store != null and store.is_unlocked(d.id)
	var tier := StringName(d.tier)
	var row := Panel.new()
	row.name = "Row_%s" % d.id
	row.set_meta(&"id", d.id)
	row.custom_minimum_size = Vector2(_w, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := UiKit.KAHVE_500
	if is_open:
		edge = UiKit.BRONZ_700 if (tier == &"kolay" or tier == &"orta") else UiKit.BRONZ_500
		if tier == &"cok_zor":
			edge = UiKit.AMBER
	var sb := UiKit.stylebox(UiKit.MOR_800, edge, 4, 14)
	if is_open and tier == &"cok_zor":
		sb.shadow_color = Color(UiKit.AMBER, 0.3)
		sb.shadow_size = 12
	row.add_theme_stylebox_override(&"panel", sb)
	# İkon plakası 108×108, ikon 68.
	var plate := TextureRect.new()
	plate.texture = UiKit.frame(&"active" if is_open else &"passive")
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(24.0, 24.0)
	plate.size = Vector2(108.0, 108.0)
	plate.modulate = AchievementIcons.tier_color(tier) if is_open else Color(0.62, 0.6, 0.58)
	row.add_child(plate)
	var icon := TextureRect.new()
	icon.texture = UiKit.texture(AchievementIcons.path_for(d))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(24.0 + 20.0, 24.0 + 20.0)
	icon.size = Vector2(68.0, 68.0)
	icon.modulate = Color(1, 1, 1, 1.0) if is_open else Color(0.62, 0.6, 0.58, 0.45)
	row.add_child(icon)
	if not is_open:
		var lock := Badge.new()
		lock.locked = true
		lock.position = Vector2(24.0 + 108.0 - 40.0, 24.0 + 108.0 - 40.0)
		lock.size = Vector2(40.0, 40.0)
		row.add_child(lock)
	var name_l := UiKit.label(UiKit.upper_tr(d.display_name), &"LabelTimer", 38, UiKit.KEMIK_100)
	name_l.name = "Name"
	name_l.position = Vector2(156.0, 20.0)
	name_l.size = Vector2(_w - 156.0 - 240.0 - 24.0, 48.0)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.clip_text = true
	row.add_child(name_l)
	var desc := UiKit.label(d.desc, &"", 28, UiKit.KEMIK_300)
	desc.name = "Desc"
	desc.position = Vector2(156.0, 72.0)
	desc.size = Vector2(_w - 156.0 - 240.0 - 24.0, DESC_H)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 2
	desc.clip_text = true
	row.add_child(desc)
	var colx := _w - 24.0 - 240.0
	var a11y := ""
	if is_open:
		var date := Highscores.format_date(store.unlocked_at(d.id), bias)
		var ok := Badge.new()
		ok.position = Vector2(colx + 240.0 - 44.0, 26.0)
		ok.size = Vector2(44.0, 44.0)
		row.add_child(ok)
		var dl := UiKit.label(date, &"", 26, UiKit.KEMIK_500)
		dl.name = "Date"
		dl.add_theme_font_override(&"font", UiKit.font_semibold())
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dl.position = Vector2(colx, 84.0)
		dl.size = Vector2(240.0, 36.0)
		row.add_child(dl)
		a11y = "%s, açıldı %s" % [d.display_name, date]
	else:
		var prog := AchievementProgress.of(d, store)
		if prog >= 0:
			var shown := mini(prog, d.target)
			var pl := UiKit.label(
				"%s/%s" % [UiKit.format_thousands(shown), UiKit.format_thousands(d.target)],
				&"LabelTimer",
				34,
				UiKit.KEMIK_100
			)
			pl.name = "Progress"
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pl.position = Vector2(colx, 38.0)
			pl.size = Vector2(240.0, 44.0)
			row.add_child(pl)
			var pb := Bar.new()
			pb.thin = true
			pb.ratio = float(shown) / float(maxi(d.target, 1))
			pb.position = Vector2(colx, 96.0)
			pb.size = Vector2(240.0, 14.0)
			row.add_child(pb)
			a11y = "%s, kilitli, %d / %d" % [d.display_name, shown, d.target]
		else:
			var chip := UiKit.label("TEK KOŞU", &"", 26, UiKit.BRONZ_300)
			chip.name = "Chip"
			chip.add_theme_font_override(&"font", UiKit.font_bold())
			chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip.add_theme_stylebox_override(
				&"normal", UiKit.stylebox(Color(UiKit.VOID, 0.4), UiKit.BRONZ_700, 3, 17)
			)
			chip.position = Vector2(colx + 240.0 - 170.0, 34.0)
			chip.size = Vector2(170.0, 40.0)
			row.add_child(chip)
			var goal := UiKit.label(
				"Hedef %s" % UiKit.format_thousands(d.target), &"", 26, UiKit.KEMIK_500
			)
			goal.name = "Goal"
			goal.add_theme_font_override(&"font", UiKit.font_semibold())
			goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			goal.position = Vector2(colx, 88.0)
			goal.size = Vector2(240.0, 36.0)
			row.add_child(goal)
			a11y = "%s, kilitli, tek koşuda hedef %d" % [d.display_name, d.target]
	row.accessibility_name = a11y
	return row


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
	var sw := UiKit.font_semibold().get_string_size("açıldı", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var sx := (1080.0 - (cw + 16.0 + sw)) * 0.5
	_abs(count_label, sx, Y_SUM + dy, cw + 4.0, 68.0)
	_abs(count_sub, sx + cw + 16.0, Y_SUM + dy + 22.0, sw + 4.0, 44.0)
	_abs(bar, _x0, Y_BAR + dy, _w, BAR_H)
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
	_sticky_tier = -1  # genişlik değişmiş olabilir: yapışkan başlık yeniden kurulur
	_abs(_fade_top, _x0, top, _w, 80.0)
	_abs(_fade_bottom, _x0, top + h - 80.0, _w, 80.0)
	_abs(error_label, _x0, top, _w, h)


## Satırlar daraldığında ScrollContainer'ın en küçük boyutu bir kare sonra düşer; boyutu o zaman yeniden uygular.
func _fit_list() -> void:
	if list != null and is_instance_valid(list):
		list.size = _list_size


func _abs(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
