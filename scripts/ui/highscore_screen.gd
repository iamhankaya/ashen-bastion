class_name HighscoreScreen
extends Control
## En İyi Skorlar ekranı (DESIGN v2.1 §7): iki sıra üçlü sekme (MOD 3 + ZORLUK 3 = 9 liste), en çok 10 satır, boş sekme,
## GERİ ve BU AYARLA OYNA. Kural yok; seçili (mod, zorluk) listesini `store`'dan (Highscores) okur.
## Satırlar 936×~147, aralık 12, y 590'dan; GERİ altta (alt 72). Veri bozuksa/boşsa boş durum gibi davranır.

signal back_requested
## Eski (v1.1) sözleşme: boş sekmede oyna düğmesi; v2.1'de `play_with_requested` ile birlikte yayılır.
signal play_requested
## Boş sekmenin çifti seçilip koşu başlatılır ("BU AYARLA OYNA").
signal play_with_requested(mode: StringName, diff: StringName)
## Sekme değişti (kalıcı değil; denetleyici dinlemek zorunda değil).
signal tab_changed(mode: StringName, diff: StringName)

const W := 936.0
const ROWS := 10
const Y_TITLE := 150.0
const Y_TAB_MODE := 290.0
const Y_TAB_DIFF := 434.0
const TAB_H := 132.0
const TAB_GAP := 12.0
const Y_ROWS := 590.0
const ROW_H := 156.0
const ROW_GAP := 12.0
const ROW_MIN_H := 120.0
const BACK_H := 132.0
const PLAY_H := 180.0
const Y_PLAY := 1500.0
const BOTTOM := 72.0
const TOP_DEFAULT := 96.0
const DESIGN_H := 2400.0
const SLIDE_SEC := 0.26
const SLIDE_PX := 40.0
## 2× yazı eşiği (RunScreen.BIG_SCALE ile aynı) ve satır içi yazı çarpanı (DESIGN §7 2×: sekme 40, satır 156, liste kayar).
const BIG_SCALE := 1.3
const BIG_K := 1.3
const TAB_FONT := 34
const TAB_FONT_BIG := 40
const NEW_FONT := 26

var title_label: Label
var back_button: Button
var play_button: Button
var empty_box: Control
var empty_title: Label
var empty_text: Label
## Satır düğümleri (her zaman 10; dolu olmayanlar boş yuva): Rank/Score/Chip/Time/Date/New alt düğümleri.
var rows: Array[Control] = []
var empty: bool = true
var highlight: int = -1
## Sekme listeleri bu depodan okunur (denetleyici atar); null = sekme değişince boş liste.
var store: Highscores = null
var sel_mode: StringName = &"normal"
var sel_diff: StringName = &"normal"
var mode_tabs: Array[SegTab] = []
var diff_tabs: Array[SegTab] = []
## 2×'te satırların içinde kaydığı kap (ilk 2×'te kurulur; 1×'te gizli ve boş).
var list_scroll: ScrollContainer = null

var _extra := Vector4.ZERO
var _x0: float = 72.0
var _w: float = W
var _dy: float = 0.0
var _entries: Array[Dictionary] = []
var _slide_t: float = 1.0
var _built: bool = false
var _big: bool = false
var _list_content: Control = null


## Segmentli sekme (DESIGN v2.1 §7): seçili = bordo yüzey + 6 px amber alt çizgi + 900 yazı; seçilmemiş = taş yüzey.
class SegTab:
	extends Button
	const LINE_H := 6.0
	var selected: bool = false
	var _name_label: Label
	var _glyph: Control

	func setup(glyph: Control, text: String) -> void:
		custom_minimum_size = Vector2(0, HighscoreScreen.TAB_H)
		focus_mode = Control.FOCUS_ALL
		for st in [&"normal", &"hover", &"disabled"]:
			add_theme_stylebox_override(st, UiKit.skin_box("dugme-dolu", 40, UiKit.TAS_600))
		add_theme_stylebox_override(&"pressed", UiKit.skin_box("dugme-basili", 40, UiKit.TAS_800))
		add_theme_stylebox_override(&"focus", UiKit.stylebox(Color(0, 0, 0, 0), UiKit.AMBER, 6, 14))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 12)
		UiKit.fill(row)
		_glyph = glyph
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
		_name_label = UiKit.label(text, &"LabelAccent", HighscoreScreen.TAB_FONT, UiKit.KEMIK_300)
		_name_label.add_theme_constant_override(&"shadow_offset_y", 0)
		row.add_child(_name_label)
		add_child(row)

	func set_selected(on: bool) -> void:
		selected = on
		var skin := "dugme-birincil" if on else "dugme-dolu"
		var fallback := UiKit.BORDO_500 if on else UiKit.TAS_600
		for st in [&"normal", &"hover", &"disabled"]:
			add_theme_stylebox_override(st, UiKit.skin_box(skin, 40, fallback))
		_name_label.theme_type_variation = &"LabelTitle" if on else &"LabelAccent"
		_name_label.add_theme_color_override(
			&"font_color", UiKit.KEMIK_100 if on else UiKit.KEMIK_300
		)
		# glif: seçili bronz_300, seçilmemiş bronz_500 (DESIGN §4; bordo üstü bronz_300 ≥ 4,1)
		_glyph.set(&"color", UiKit.BRONZ_300 if on else UiKit.BRONZ_500)
		_glyph.queue_redraw()
		queue_redraw()

	func set_label_size(px: int) -> void:
		_name_label.add_theme_font_size_override(&"font_size", px)

	func label_size() -> int:
		return _name_label.get_theme_font_size(&"font_size")

	func _draw() -> void:
		if selected:
			draw_rect(Rect2(0.0, size.y - LINE_H, size.x, LINE_H), UiKit.AMBER)


## Sonuç çipi: "KAZANDI" (amber kenar + çizilmiş onay) / "YENİLDİ" (bordo dolgu).
class ResultChip:
	extends Control
	const FONT_SIZE := 26  # min metin 26 px (V-05)
	const HEIGHT := 40.0
	var won: bool = false
	var text: String = ""
	## Yazı çarpanı (2×'te 1,3): yazı, yükseklik ve dolgular birlikte büyür.
	var k: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, HEIGHT)

	func font_px() -> int:
		return roundi(FONT_SIZE * k)

	func configure(p_won: bool) -> void:
		won = p_won
		text = "KAZANDI" if won else "YENİLDİ"
		var f := UiKit.font_bold()
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px()).x
		size = Vector2(tw + (62.0 if won else 38.0) * k, HEIGHT * k)
		custom_minimum_size = size
		queue_redraw()

	func _draw() -> void:
		var sb: StyleBoxFlat
		var col := UiKit.AMBER if won else UiKit.KEMIK_100
		if won:
			sb = UiKit.stylebox(Color(UiKit.VOID, 0.0), UiKit.AMBER, 3, 20)
		else:
			sb = UiKit.stylebox(UiKit.BORDO_500, UiKit.BORDO_400, 2, 20)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var x := 19.0 * k
		if won:
			var pts := PackedVector2Array([Vector2(14, 21), Vector2(20, 28), Vector2(31, 12)])
			for i in pts.size():
				pts[i] *= k
			draw_polyline(pts, col, 3.0, true)
			x = 40.0 * k
		draw_string(
			UiKit.font_bold(),
			Vector2(x, 29.0 * k),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_px(),
			col
		)


## Sıra rozeti: 1–3 kalın halka (bronz/kemik/koyu bronz, 8 px), 4–10 ince bronz_700 (5 px); renk + rakam.
class RankBadge:
	extends Control
	var rank: int = 1
	var faded: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(84, 84)
		size = Vector2(84, 84)

	func _draw() -> void:
		var c := size * 0.5
		var ring := UiKit.BRONZ_700
		var w := 5.0
		match rank:
			1:
				ring = UiKit.BRONZ_300
				w = 8.0
			2:
				ring = UiKit.KEMIK_300
				w = 8.0
			3:
				ring = UiKit.BRONZ_500
				w = 8.0
		var a := 0.5 if faded else 1.0
		draw_circle(c, 42.0, Color(UiKit.VOID, 0.7 * a))
		draw_arc(c, 42.0 - w * 0.5, 0.0, TAU, 48, Color(ring, a), w, true)
		var f := UiKit.font(&"title")
		var txt := str(rank)
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44)
		draw_string(
			f,
			Vector2(c.x - sz.x * 0.5, c.y + 15.0),
			txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			44,
			Color(UiKit.KEMIK_100 if not faded else UiKit.KEMIK_500, a)
		)


## Boş yuva çerçevesi: kesikli kenar.
class DashedFrame:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Color(UiKit.BRONZ_700, 0.6)
		var step := 18.0
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(minf(x + 10.0, size.x), 0), col, 2.0)
			draw_line(Vector2(x, size.y), Vector2(minf(x + 10.0, size.x), size.y), col, 2.0)
			x += step
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(0, minf(y + 10.0, size.y)), col, 2.0)
			draw_line(Vector2(size.x, y), Vector2(size.x, minf(y + 10.0, size.y)), col, 2.0)
			y += step


## Boş durum çemberi: kesikli yıldız çemberi 160 px.
class EmptyRing:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(160, 160)
		size = Vector2(160, 160)

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(UiKit.BRONZ_500, 0.7)
		for i in 28:
			var a0 := TAU * i / 28.0
			draw_arc(c, 76.0, a0, a0 + TAU / 56.0, 4, col, 4.0, true)
		var pts := PackedVector2Array()
		for i in 10:
			var rad := 40.0 if i % 2 == 0 else 17.0
			pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 10.0) * rad)
		draw_colored_polygon(pts, Color(UiKit.BRONZ_500, 0.55))


func _init() -> void:
	visible = false
	visibility_changed.connect(_on_visibility)


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
	bg.color = UiKit.TAS_900
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)
	var glow := TextureRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.anchor_right = 1.0
	glow.offset_bottom = 900.0
	glow.texture = _warm_fade()
	add_child(glow)
	title_label = UiKit.label("EN İYİ SKORLAR", &"LabelTitle", 80)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_constant_override(&"shadow_offset_y", 4)
	add_child(title_label)
	_build_tabs()
	for i in ROWS:
		var row := _make_row(i)
		add_child(row)
		rows.append(row)
	empty_box = Control.new()
	empty_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := EmptyRing.new()
	ring.name = "Ring"
	empty_box.add_child(ring)
	empty_title = UiKit.label("HENÜZ SKOR YOK", &"LabelTimer", 56)
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_box.add_child(empty_title)
	empty_text = UiKit.label("", &"", 34, UiKit.KEMIK_300)
	empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_box.add_child(empty_text)
	add_child(empty_box)
	play_button = UiKit.button("BU AYARLA OYNA", &"primary", PLAY_H)
	play_button.add_theme_font_size_override(&"font_size", 56)
	play_button.pressed.connect(_on_play)
	add_child(play_button)
	back_button = UiKit.back_button(BACK_H)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(back_button)
	_layout()


func _build_tabs() -> void:
	for m: StringName in RunStrip.MODE_ORDER:
		var tab := SegTab.new()
		tab.name = "ModeTab_%s" % m
		tab.setup(RunStrip.ModeGlyph.new(m, UiKit.BRONZ_500, 40.0), RunStrip.MODE_NAMES[m])
		tab.pressed.connect(func() -> void: select_tab(m, sel_diff))
		add_child(tab)
		mode_tabs.append(tab)
	for d: StringName in RunStrip.DIFF_ORDER:
		var tab := SegTab.new()
		tab.name = "DiffTab_%s" % d
		tab.setup(
			RunStrip.Shields.new(int(RunStrip.SHIELDS[d]), UiKit.BRONZ_500, Vector2(60.0, 20.0)),
			RunStrip.DIFF_NAMES[d]
		)
		tab.pressed.connect(func() -> void: select_tab(sel_mode, d))
		add_child(tab)
		diff_tabs.append(tab)


func _on_play() -> void:
	play_requested.emit()
	play_with_requested.emit(sel_mode, sel_diff)


## Sekme seçimi (kalıcı değil): listeyi `store`'dan yeniler, vurgu yok.
func select_tab(mode: StringName, diff: StringName) -> void:
	_mark_tabs(mode, diff)
	var list: Array[Dictionary] = []
	if store != null:
		list = store.list_for(mode, diff)
	_fill(list, -1)
	tab_changed.emit(mode, diff)


func _mark_tabs(mode: StringName, diff: StringName) -> void:
	sel_mode = mode
	sel_diff = diff
	for i in mode_tabs.size():
		var m: StringName = RunStrip.MODE_ORDER[i]
		mode_tabs[i].set_selected(m == mode)
		mode_tabs[i].accessibility_name = (
			"Mod sekmesi, %s, %s, üç sekmeden %s"
			% [RunStrip.MODE_TITLES[m], "seçili" if m == mode else "seçili değil", _ordinal(i)]
		)
	for i in diff_tabs.size():
		var d: StringName = RunStrip.DIFF_ORDER[i]
		diff_tabs[i].set_selected(d == diff)
		diff_tabs[i].accessibility_name = (
			"Zorluk sekmesi, %s, %s, üç sekmeden %s"
			% [RunStrip.DIFF_TITLES[d], "seçili" if d == diff else "seçili değil", _ordinal(i)]
		)


static func _ordinal(i: int) -> String:
	return ["birincisi", "ikincisi", "üçüncüsü"][i]


## Boş sekme metni: "Sonsuz · Zor listesinde kayıt yok." + yönlendirme (DESIGN §7 `04b`).
static func empty_text_for(mode: StringName, diff: StringName) -> String:
	return (
		"%s · %s listesinde kayıt yok.\nBu ayarla oynayıp ilk skoru yaz."
		% [RunStrip.MODE_TITLES.get(mode, ""), RunStrip.DIFF_TITLES.get(diff, "")]
	)


func _make_row(i: int) -> Control:
	var row := Control.new()
	row.name = "Row%d" % i
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.name = "Bg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override(&"panel", _raised_style())
	UiKit.fill(bg)
	row.add_child(bg)
	var inner := Control.new()
	inner.name = "Inner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inner)
	var dash := DashedFrame.new()
	dash.name = "Dash"
	row.add_child(dash)
	var badge := RankBadge.new()
	badge.name = "Rank"
	badge.rank = i + 1
	inner.add_child(badge)
	var score := UiKit.label("", &"LabelTimer", 56, UiKit.KEMIK_100)
	score.name = "Score"
	inner.add_child(score)
	var chip := ResultChip.new()
	chip.name = "Chip"
	inner.add_child(chip)
	var time := UiKit.label("", &"", 28, UiKit.KEMIK_100)
	time.name = "Time"
	time.add_theme_font_override(&"font", UiKit.font_semibold())
	inner.add_child(time)
	var date := UiKit.label("", &"", 26, UiKit.KEMIK_500)
	date.name = "Date"
	date.add_theme_font_override(&"font", UiKit.font_semibold())
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(date)
	var tag := UiKit.label("YENİ", &"", NEW_FONT, UiKit.AMBER)
	tag.name = "New"
	tag.add_theme_font_override(&"font", UiKit.font_bold())
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_stylebox_override(
		&"normal", UiKit.stylebox(Color(UiKit.VOID, 0.4), UiKit.AMBER, 3, 17)
	)
	inner.add_child(tag)
	return row


## highlight_index: vurgulanacak satır (-1 = yok; denetleyici hep -1 verir). mode/diff: açılış sekmesi.
func show_scores(
	entries: Array[Dictionary],
	highlight_index: int = -1,
	mode: StringName = &"normal",
	diff: StringName = &"normal"
) -> void:
	_build()
	_sync_font_scale()
	_mark_tabs(mode, diff)
	_fill(entries, highlight_index)
	visible = true
	(play_button if empty else back_button).grab_focus.call_deferred()


func _fill(entries: Array[Dictionary], highlight_index: int) -> void:
	_entries = entries.slice(0, ROWS)
	highlight = (
		highlight_index if highlight_index >= 0 and highlight_index < _entries.size() else -1
	)
	empty = _entries.is_empty()
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	for i in ROWS:
		var row := rows[i]
		var filled := i < _entries.size()
		(row.get_node("Dash") as Control).visible = not filled and not empty
		row.visible = not empty
		var inner := row.get_node("Inner") as Control
		var badge := inner.get_node("Rank") as RankBadge
		badge.faded = not filled
		badge.queue_redraw()
		for n in ["Score", "Chip", "Time", "Date"]:
			(inner.get_node(n) as Control).visible = filled
		(inner.get_node("New") as Control).visible = filled and i == highlight
		var bg := row.get_node("Bg") as Panel
		row.modulate.a = 1.0
		if filled:
			var e := _entries[i]
			(inner.get_node("Score") as Label).text = UiKit.format_thousands(int(e["score"]))
			(inner.get_node("Chip") as ResultChip).configure(bool(e["won"]))
			(inner.get_node("Time") as Label).text = UiKit.format_time(float(e["time"]))
			(inner.get_node("Date") as Label).text = Highscores.format_date(int(e["unix"]), bias)
			if i == highlight:
				bg.add_theme_stylebox_override(
					&"panel", UiKit.stylebox(UiKit.TAS_700, UiKit.AMBER, 5, 14, true)
				)
			else:
				bg.add_theme_stylebox_override(&"panel", _raised_style())
		else:
			bg.add_theme_stylebox_override(
				&"panel", UiKit.stylebox(Color(UiKit.VOID, 0.35), Color(0, 0, 0, 0), 0, 14)
			)
	empty_box.visible = empty
	empty_text.text = empty_text_for(sel_mode, sel_diff)
	play_button.accessibility_name = (
		"%s modda, %s zorlukta oyna"
		% [RunStrip.MODE_TITLES[sel_mode], RunStrip.DIFF_TITLES[sel_diff]]
	)
	play_button.visible = empty
	_slide_t = 0.0 if highlight >= 0 else 1.0
	_layout()
	if _big and highlight >= 0:
		list_scroll.ensure_control_visible.call_deferred(rows[highlight])
	elif _big:
		list_scroll.scroll_vertical = 0


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra.
func apply_safe_area(extra: Variant = null) -> void:
	if extra is Vector4:
		_extra = extra
	else:
		_extra = UiKit.current_safe_extra(Vector2(1080.0, DESIGN_H))
	_layout()


func _layout() -> void:
	if not _built:
		return
	_x0 = maxf(72.0, UiKit.SAFE_EDGE + _extra.x)
	var x1 := 1080.0 - maxf(72.0, UiKit.SAFE_EDGE + _extra.z)
	_w = minf(W, x1 - _x0)
	_x0 = (1080.0 - _w) * 0.5 if _w >= W else _x0
	_dy = maxf(0.0, _extra.y - (Y_TITLE - TOP_DEFAULT))
	_abs(title_label, 0.0, Y_TITLE + _dy, 1080.0, 110.0)
	var tab_w := (_w - 2.0 * TAB_GAP) / 3.0
	for i in 3:
		_abs(mode_tabs[i], _x0 + float(i) * (tab_w + TAB_GAP), Y_TAB_MODE + _dy, tab_w, TAB_H)
		_abs(diff_tabs[i], _x0 + float(i) * (tab_w + TAB_GAP), Y_TAB_DIFF + _dy, tab_w, TAB_H)
	var back_y := DESIGN_H - BOTTOM - _extra.w - BACK_H
	_abs(back_button, _x0, back_y, _w, BACK_H)
	var play_y := minf(Y_PLAY + _dy, back_y - BUTTONS_GAP - PLAY_H)
	_abs(play_button, _x0, play_y, _w, PLAY_H)
	var top := Y_ROWS + _dy
	var avail := back_y - 24.0 - top
	var pitch := minf(ROW_H + ROW_GAP, (avail + ROW_GAP) / float(ROWS))
	var rh := clampf(pitch - ROW_GAP, ROW_MIN_H, ROW_H)
	if _big:  # 2×: pitch sıkıştırılmaz, liste kaydırma kabında kayar (GERİ sabit)
		pitch = ROW_H + ROW_GAP
		rh = ROW_H
		_abs(list_scroll, 0.0, top, 1080.0, maxf(0.0, avail))
		_list_content.custom_minimum_size = Vector2(1080.0, float(ROWS) * pitch - ROW_GAP)
		list_scroll.visible = not empty
	for i in ROWS:
		var row := rows[i]
		_abs(row, _x0, (0.0 if _big else top) + float(i) * pitch, _w, rh)
		_layout_row(row, rh)
	var ey := 700.0 + _dy
	_abs(empty_box, _x0, ey, _w, 520.0)
	(empty_box.get_node("Ring") as Control).position = Vector2((_w - 160.0) * 0.5, 0)
	_abs(empty_title, 0.0, 220.0, _w, 80.0)
	empty_title.position = Vector2(0, 220.0)
	# autowrap'lı Label'ın en küçük yüksekliği, genişlik 1 px'ken hesaplanıp (2202 px) takılabiliyordu: genişlik taban olarak verilir
	empty_text.custom_minimum_size = Vector2(_w - 120.0, 0.0)
	_abs(empty_text, 60.0, 330.0, _w - 120.0, 140.0)


const BUTTONS_GAP := 27.0


## Satır yüzeyi: düz taş kutu (tema "PanelRaised" mor olduğundan kullanılmaz; DESIGN v2.1 §0 taş dili).
static func _raised_style() -> StyleBox:
	return UiKit.stylebox(UiKit.TAS_800, UiKit.BRONZ_700, 3, 14)


## Üstten sıcak tek ışık (KOŞU/ayarlar ekranlarıyla aynı sakin oda): amber α0,16 → 0.
static func _warm_fade() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(UiKit.AMBER, 0.16), Color(UiKit.AMBER, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	return t


## 2× yazı (font_scale > 1,3): sekme etiketi 40, satır içi yazılar ×1,3, satır 156, liste kayar.
func set_font_scale(f: float) -> void:
	_build()
	var big := f > BIG_SCALE
	if big == _big:
		return
	_big = big
	_ensure_list_scroll()
	var host: Control = _list_content if big else self
	for row in rows:
		row.reparent(host, false)
	if not big:  # satırlar kaydırma kabının önüne, özgün sıraya döner
		for row in rows:
			move_child(row, list_scroll.get_index())
	list_scroll.visible = big and not empty
	for t in mode_tabs + diff_tabs:
		t.set_label_size(TAB_FONT_BIG if big else TAB_FONT)
	_apply_row_scale()
	_layout()


func is_big() -> bool:
	return _big


func _ensure_list_scroll() -> void:
	if list_scroll != null:
		return
	list_scroll = ScrollContainer.new()
	list_scroll.name = "ListScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_scroll.visible = false
	UiKit.touch_scroll(list_scroll)
	add_child(list_scroll)
	move_child(list_scroll, rows[0].get_index())
	_list_content = Control.new()
	_list_content.mouse_filter = Control.MOUSE_FILTER_PASS
	list_scroll.add_child(_list_content)


## Satır içi yazı ve çip ölçeği (skor 56, süre 28, tarih 26, çip 26, YENİ 26; 2×'te ×1,3).
func _apply_row_scale() -> void:
	var k := BIG_K if _big else 1.0
	for row in rows:
		var inner := row.get_node("Inner") as Control
		(inner.get_node("Score") as Label).add_theme_font_size_override(
			&"font_size", roundi(56.0 * k)
		)
		(inner.get_node("Time") as Label).add_theme_font_size_override(
			&"font_size", roundi(28.0 * k)
		)
		(inner.get_node("Date") as Label).add_theme_font_size_override(
			&"font_size", roundi(26.0 * k)
		)
		(inner.get_node("New") as Label).add_theme_font_size_override(
			&"font_size", roundi(float(NEW_FONT) * k)
		)
		var chip := inner.get_node("Chip") as ResultChip
		chip.k = k
		if chip.text != "":
			chip.configure(chip.won)


func _sync_font_scale() -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st != null:
		set_font_scale(st.font_scale())


## Ekran görününce yazı ölçeği Settings'ten okunur (denetleyici `visible`'ı sürer).
func _on_visibility() -> void:
	if visible and _built:
		_sync_font_scale()


func _layout_row(row: Control, h: float) -> void:
	var inner := row.get_node("Inner") as Control
	inner.position = Vector2.ZERO
	inner.size = Vector2(_w, h)
	var cy := h * 0.5
	var badge := inner.get_node("Rank") as Control
	badge.position = Vector2(24.0, cy - 42.0)
	var dash := row.get_node("Dash") as Control
	dash.position = Vector2.ZERO
	dash.size = Vector2(_w, h)
	var score := inner.get_node("Score") as Label
	var chip := inner.get_node("Chip") as Control
	var time := inner.get_node("Time") as Label
	var date := inner.get_node("Date") as Label
	var tag := inner.get_node("New") as Control
	if _big:
		# 2×: sağ sütun 300 px (tarih üstte, YENİ altta); sol: skor üstte, çip + süre altta; hepsi 156 içinde
		var rx := _w - 24.0 - 300.0
		score.position = Vector2(140.0, 0.0)
		score.size = Vector2(rx - 8.0 - 140.0, 100.0)
		chip.position = Vector2(140.0, 102.0)
		time.position = Vector2(140.0 + chip.size.x + 14.0, 105.0)
		time.size = Vector2(maxf(0.0, rx - 8.0 - time.position.x), 46.0)
		date.position = Vector2(rx, 14.0)
		date.size = Vector2(300.0, 46.0)
		tag.size = Vector2(140.0, 56.0)
		tag.position = Vector2(_w - 24.0 - tag.size.x, 88.0)
		return
	var dx := _w - 24.0 - 240.0
	date.position = Vector2(dx, cy - 18.0)
	date.size = Vector2(240.0, 36.0)
	tag.size = Vector2(110.0, 44.0)  # YENİ 26 px yazı (min metin 26)
	tag.position = Vector2(dx - tag.size.x - 8.0, cy - 22.0)
	score.position = Vector2(140.0, maxf(2.0, cy - 66.0))
	score.size = Vector2(minf(_w - 420.0, tag.position.x - 8.0 - 140.0), 76.0)
	chip.position = Vector2(140.0, cy + 22.0)
	time.position = Vector2(140.0 + chip.size.x + 14.0, cy + 18.0)
	time.size = Vector2(160.0, 40.0)


func _abs(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


func _process(delta: float) -> void:
	if not visible or _slide_t >= 1.0 or highlight < 0:
		return
	_slide_t = minf(1.0, _slide_t + delta / SLIDE_SEC)
	var k := ResultTimeline.cubic_out(_slide_t)
	var row := rows[highlight]
	row.modulate.a = k
	(row.get_node("Inner") as Control).position.x = (1.0 - k) * SLIDE_PX
