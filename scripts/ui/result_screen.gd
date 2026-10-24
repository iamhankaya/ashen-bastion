class_name ResultScreen
extends Control
## Oyun Bitti / Kazandın + skor dökümü (DESIGN §3.3–3.4). Blok sırası ve boyları `Y_*` sabitleridir; düğmeler
## max(içerik_alt + 24, 1500) konumundadır. Skor 0→N 900 ms sayar, döküm satırları 300 ms'den 120 ms arayla girer,
## YENİ REKOR damgası 1250 ms'de düşer, düğmeler 1300 ms'de açılır (dokunma = hepsini bitir, düğme en erken 800 ms).
## Veri: run_ended(won, stats) {time, level, kills, evolutions, score, score_parts, best_mult} + Highscores.submit sonucu.

signal replay_requested
signal menu_requested
## Rekor damgası düştü (denetleyici titreşim verir).
signal record_stamped

const W := 936.0
const MAX_COMBOS := 4
const EMPTY_TEXT := "Bu seferlik kombo yok."
const LOST_SUB := "Kale seni yuttu."
const WON_SUB := "Düşmüş Kale Lordu devrildi."

const SIDE_MIN := 72.0
const Y_TITLE := 170.0
const Y_SUB := 300.0
const Y_DIV := 380.0
const Y_HERO := 404.0
const Y_HERO_VALUE := 440.0
const Y_RECORD := 590.0
const BAND_H := 96.0
const RECORD_BLOCK_H := 150.0
const Y_BREAKDOWN := 760.0
const ROW_H := 84.0
const BREAKDOWN_PAD := 12.0
const Y_STRIP := 1228.0
const STRIP_H := 170.0
const Y_COMBOS := 1422.0
const GAP := 24.0
const BUTTONS_MIN_Y := 1500.0
const REPLAY_H := 156.0
const MENU_H := 132.0
const BUTTON_GAP := 27.0
## v2.0 (B4) yeni başarım özet çipi: şerit ile kombolar arasında 936×96; döküm satırlarından sonra 1100 ms'de 200 ms kayma-giriş.
const CHIP_H := 96.0
const CHIP_AT := 1.1
const CHIP_IN := 0.2
const CHIP_SLIDE := 24.0
const CHIP_MAX_COMBOS := 3
const DETAIL_FONT := 26
const EMPTY_ROW_ALPHA := 0.35
const STAMP_SEC := 0.28
const STAMP_SCALE := 1.3
const SHINE_SEC := 0.6
const PILL_SEC := 0.2
const ROW_SLIDE_PX := 40.0
## Güvenli alan dışında bırakılan alt/üst taban (UiKit varsayılanları).
const TOP_DEFAULT := 96.0
const BOTTOM_DEFAULT := 72.0
const DESIGN_H := 2400.0
const DISPLAY_CAP := 99999999

var won: bool = false
var stats: Dictionary = {}
var last_record: Dictionary = {}
## &"none" | &"record" | &"top10" | &"outside" (test/okuma için).
var record_kind: StringName = &"none"
var title_label: Label
var sub_label: Label
var divider: Control
var score_caption: Label
var score_value: Label
var record_band: Control
var record_label: Label
var record_stars: Array[Control] = []
var record_pill: Label
var record_note: Label
var breakdown_panel: PanelContainer
var breakdown_rows: Array[Control] = []
var strip_panel: PanelContainer
var time_value: Label
var level_value: Label
var kills_value: Label
var combo_panel: PanelContainer
var combo_box: VBoxContainer
var replay_button: Button
var menu_button: Button
var glow: TextureRect
var achievement_chip: Panel
var chip_title: Label
var chip_names: Label
var chip_star: Control

var _t: float = 0.0
var _skip_t: float = -1.0
var _subtitle: String = ""
var _extra := Vector4.ZERO
var _x0: float = SIDE_MIN
var _w: float = W
var _dy: float = 0.0
var _row_targets: Array[int] = []
var _row_dim: Array[bool] = []
var _row_plus: Array[bool] = []
var _row_dash: Array[bool] = []
var _stamped: bool = false
var _shine: ColorRect
var _strip_nodes: Array[Control] = []
var _hero_total: int = 0
var _combos_data: Array[Dictionary] = []
var _shown_combos: int = MAX_COMBOS
var _new_names: Array[String] = []


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.VOID
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)
	glow = TextureRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.anchor_right = 1.0
	glow.offset_bottom = 1100.0
	add_child(glow)

	title_label = UiKit.label("OYUN BİTTİ", &"LabelTitle", 104)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_constant_override(&"shadow_offset_y", 5)
	add_child(title_label)
	sub_label = UiKit.label(LOST_SUB, &"", 34, UiKit.KEMIK_300)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub_label)
	divider = UiKit.divider()
	add_child(divider)

	score_caption = UiKit.label("SKOR", &"LabelAccent", 34)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(score_caption)
	score_value = UiKit.label("0", &"LabelTitle", 120)
	score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_value.add_theme_constant_override(&"shadow_offset_y", 5)
	add_child(score_value)

	_build_record()
	_build_breakdown()
	_build_strip()
	_build_chip()

	combo_panel = PanelContainer.new()
	combo_panel.theme_type_variation = &"PanelRaised"
	combo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override(&"separation", 16)
	cv.add_child(UiKit.label("KURULAN KOMBOLAR", &"LabelAccent", 32))
	combo_box = VBoxContainer.new()
	combo_box.add_theme_constant_override(&"separation", 0)
	cv.add_child(combo_box)
	combo_panel.add_child(cv)
	add_child(combo_panel)

	replay_button = UiKit.button("TEKRAR OYNA", &"primary", REPLAY_H)
	replay_button.add_theme_font_size_override(&"font_size", 52)
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	add_child(replay_button)
	menu_button = UiKit.button("ANA MENÜ", &"secondary", MENU_H)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	add_child(menu_button)
	_layout()


func _build_record() -> void:
	record_band = Control.new()
	record_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record_band.clip_contents = true
	record_band.visible = false
	record_band.draw.connect(_draw_band)
	add_child(record_band)
	record_label = UiKit.label("YENİ REKOR", &"LabelTitle", 56, UiKit.AMBER)
	record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record_label.add_theme_constant_override(&"shadow_offset_y", 3)
	record_band.add_child(record_label)
	for i in 2:
		var star := UiKit.Glyph.new(&"star", UiKit.AMBER, 48.0)
		record_band.add_child(star)
		record_stars.append(star)
	_shine = ColorRect.new()
	_shine.color = Color(UiKit.KEMIK_100, 0.35)
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.visible = false
	record_band.add_child(_shine)
	record_pill = UiKit.label("", &"LabelTimer", 38)
	record_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record_pill.add_theme_stylebox_override(
		&"normal", UiKit.stylebox(Color(UiKit.VOID, 0.5), UiKit.BRONZ_500, 4, 24)
	)
	record_pill.visible = false
	add_child(record_pill)
	record_note = UiKit.label("", &"", 30, UiKit.KEMIK_500)
	record_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(record_note)


func _draw_band() -> void:
	var r := Rect2(Vector2.ZERO, record_band.size)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([UiKit.BORDO_700, UiKit.BORDO_500, UiKit.BORDO_700])
	record_band.draw_rect(r, UiKit.BORDO_900)
	var steps := 24
	for i in steps:
		var k0 := float(i) / steps
		var c := g.sample(k0)
		record_band.draw_rect(
			Rect2(r.size.x * k0, 0, r.size.x / steps + 1.0, r.size.y), Color(c, 0.9)
		)
	record_band.draw_rect(Rect2(0, 0, r.size.x, 4), UiKit.AMBER)
	record_band.draw_rect(Rect2(0, r.size.y - 4, r.size.x, 4), UiKit.AMBER)


func _build_breakdown() -> void:
	breakdown_panel = PanelContainer.new()
	breakdown_panel.theme_type_variation = &"PanelRaised"
	breakdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(breakdown_panel)
	var defs := [
		["hud-oldurme", "Öldürme"],
		["hud-xp", "Seri çarpanı"],
		["dinamit", "Evrim bonusu"],
		["hud-sure", "Hayatta kalma"],
		["hud-can", "Lord bonusu"],
	]
	for d in defs:
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.name = "Icon"
		ic.texture = UiKit.hud_icon(d[0])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(0, 18)
		ic.size = Vector2(48, 48)
		row.add_child(ic)
		var l := UiKit.label(d[1], &"", 32, UiKit.KEMIK_100)
		l.name = "Name"
		l.add_theme_font_override(&"font", UiKit.font_semibold())
		l.position = Vector2(72, 0)
		l.size = Vector2(330, ROW_H)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		var det := UiKit.label("", &"", DETAIL_FONT, UiKit.KEMIK_500)
		det.name = "Detail"
		det.add_theme_font_override(&"font", UiKit.font_semibold())
		det.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		det.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(det)
		var v := UiKit.label("0", &"LabelTimer", 44)
		v.name = "Value"
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(v)
		add_child(row)
		breakdown_rows.append(row)


func _build_strip() -> void:
	strip_panel = PanelContainer.new()
	strip_panel.theme_type_variation = &"PanelRaised"
	strip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip_panel)
	var defs := [["hud-sure", "Süre"], ["hud-xp", "Seviye"], ["hud-oldurme", "Öldürme"]]
	var vals: Array[Label] = []
	for d in defs:
		var col := Control.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.name = "Icon"
		ic.texture = UiKit.hud_icon(d[0])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ic)
		var v := UiKit.label("0", &"LabelTimer", 48)
		v.name = "Value"
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(v)
		var cap := UiKit.label(d[1], &"", 26, UiKit.KEMIK_300)
		cap.name = "Caption"
		cap.add_theme_font_override(&"font", UiKit.font_semibold())
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)
		add_child(col)
		_strip_nodes.append(col)
		vals.append(v)
	time_value = vals[0]
	level_value = vals[1]
	kills_value = vals[2]


func _build_chip() -> void:
	achievement_chip = Panel.new()
	achievement_chip.name = "AchievementChip"
	achievement_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	achievement_chip.add_theme_stylebox_override(
		&"panel", UiKit.stylebox(UiKit.MOR_800, UiKit.AMBER, 4, 14)
	)
	achievement_chip.visible = false
	add_child(achievement_chip)
	chip_star = UiKit.Glyph.new(&"star", UiKit.AMBER, 44.0)
	chip_star.position = Vector2(28.0, (CHIP_H - 44.0) * 0.5)
	chip_star.size = Vector2(44.0, 44.0)
	achievement_chip.add_child(chip_star)
	chip_title = UiKit.label("", &"LabelTimer", 30, UiKit.AMBER)
	chip_title.name = "Title"
	chip_title.position = Vector2(92.0, 8.0)
	chip_title.size = Vector2(300.0, 40.0)
	achievement_chip.add_child(chip_title)
	chip_names = UiKit.label("", &"", 28, UiKit.KEMIK_300)
	chip_names.name = "Names"
	chip_names.add_theme_font_override(&"font", UiKit.font_semibold())
	chip_names.position = Vector2(92.0, 48.0)
	chip_names.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip_names.clip_text = true
	achievement_chip.add_child(chip_names)


## Koşuda açılan başarımların görünen adları; `show_result`'tan ÖNCE çağrılır. Boş => v1.1 düzeni aynen.
## Çip: "YENİ BAŞARIM · N" + ilk iki ad ("+k" kalan); varken kombolar en çok 3 satır.
func set_new_achievements(names: Array[String]) -> void:
	_new_names = names.duplicate()
	if achievement_chip == null:
		return
	var n := _new_names.size()
	achievement_chip.visible = n > 0
	if n > 0:
		chip_title.text = "YENİ BAŞARIM · %d" % n
		var shown := ", ".join(_new_names.slice(0, 2))
		if n > 2:
			shown += " +%d" % (n - 2)
		chip_names.text = shown
		achievement_chip.accessibility_name = ("%d yeni başarım: %s" % [n, ", ".join(_new_names)])
	if _shown_combos != _combo_cap():
		_shown_combos = _combo_cap()
		if combo_box != null:
			_render_combos()
	_layout()


func has_new_achievements() -> bool:
	return not _new_names.is_empty()


func _combo_cap() -> int:
	return CHIP_MAX_COMBOS if not _new_names.is_empty() else MAX_COMBOS


## Sonucu göster. combos: UiKit.combo_rows() çıktısı. subtitle boşsa varsayılan. record: Highscores.submit sonucu
## ({} = rekor bilgisi yok).
func show_result(
	p_won: bool,
	p_stats: Dictionary,
	combos: Array[Dictionary] = [],
	subtitle: String = "",
	record: Dictionary = {}
) -> void:
	won = p_won
	stats = p_stats
	last_record = record
	_subtitle = subtitle
	title_label.text = "KAZANDIN" if won else "OYUN BİTTİ"
	title_label.add_theme_color_override(&"font_color", UiKit.AMBER if won else UiKit.KEMIK_100)
	sub_label.text = subtitle if subtitle != "" else (WON_SUB if won else LOST_SUB)
	glow.texture = _glow_texture(UiKit.AMBER if won else UiKit.BORDO_500)
	_shown_combos = _combo_cap()
	_fill_combos(combos)
	_fill_record()
	_fill_rows()
	_hero_total = clampi(int(stats.get("score", 0)), 0, DISPLAY_CAP)
	var amber := won or record_kind == &"record"
	score_value.add_theme_color_override(&"font_color", UiKit.AMBER if amber else UiKit.KEMIK_100)
	_t = 0.0
	_skip_t = -1.0
	_stamped = false
	_layout()
	_apply(0.0)
	visible = true


func _fill_combos(combos: Array[Dictionary]) -> void:
	_combos_data = combos
	_render_combos()


## Görünen kombo satırları `_shown_combos` kadar; taşma olursa `_layout` bunu azaltır ve "+N" büyür.
func _render_combos() -> void:
	var combos := _combos_data
	for c in combo_box.get_children():
		combo_box.remove_child(c)
		c.queue_free()
	if combos.is_empty():
		var e := UiKit.label(EMPTY_TEXT, &"", 32, UiKit.KEMIK_300)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(_w - 100.0, 0)
		combo_box.add_child(e)
		return
	for i in mini(combos.size(), _shown_combos):
		combo_box.add_child(_combo_row(combos[i]))
	if combos.size() > _shown_combos:
		var more := UiKit.label(
			"+%d" % (combos.size() - _shown_combos), &"LabelTimer", 36, UiKit.BRONZ_300
		)
		more.custom_minimum_size = Vector2(0, 56)
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		combo_box.add_child(more)


func _fill_record() -> void:
	record_kind = &"none"
	var rank := int(last_record.get("rank", 0))
	if last_record.is_empty():
		pass
	elif rank == 1 and bool(last_record.get("is_record", false)):
		record_kind = &"record"
	elif rank >= 2:
		record_kind = &"top10"
	elif rank == 0 and int(last_record.get("needed_for_top10", 0)) > 0:
		record_kind = &"outside"
	record_band.visible = record_kind == &"record"
	record_pill.visible = record_kind == &"top10"
	record_note.text = ""
	match record_kind:
		&"record":
			var prev := int(last_record.get("previous_best", 0))
			record_note.text = (
				"Önceki en iyi: %s" % UiKit.format_thousands(prev) if prev > 0 else ""
			)
		&"top10":
			record_pill.text = "EN İYİ 10'A GİRDİN · %d. SIRA" % rank
		&"outside":
			record_note.text = (
				"10. sıra için gereken: %s"
				% UiKit.format_thousands(int(last_record.get("needed_for_top10", 0)))
			)


func _fill_rows() -> void:
	var parts: Dictionary = stats.get("score_parts", {})
	var evo_n := (stats.get("evolutions", []) as Array).size()
	var lord := int(parts.get("lord", 0))
	var evo := int(parts.get("evolution", 0))
	var vals: Array[int] = [
		int(parts.get("kills", 0)),
		int(parts.get("streak", 0)),
		evo,
		int(parts.get("survival", 0)),
		lord,
	]
	var plus: Array[bool] = [false, true, true, true, true]
	var details: Array[String] = [
		"",
		"en yüksek ×%d" % int(stats.get("best_mult", 1)),
		"%d evrim" % evo_n,
		UiKit.format_time(float(stats.get("time", 0.0))),
		"" if (lord > 0 or won) else "Lord'u yen",
	]
	_row_targets = vals
	_row_plus = plus
	_row_dim = [false, false, evo == 0, false, lord == 0]
	_row_dash = [false, false, false, false, lord == 0]
	for i in breakdown_rows.size():
		(breakdown_rows[i].get_node("Detail") as Label).text = details[i]


## Yerleşim: tüm bloklar mutlak konumlu (Y_* sabitleri). Güvenli alan üst payı kadar aşağı kayar.
func _layout() -> void:
	if title_label == null:
		return
	_x0 = maxf(SIDE_MIN, UiKit.SAFE_EDGE + _extra.x)
	var x1 := 1080.0 - maxf(SIDE_MIN, UiKit.SAFE_EDGE + _extra.z)
	_w = minf(W, x1 - _x0)
	_x0 = (1080.0 - _w) * 0.5 if _w >= W else _x0
	_dy = maxf(0.0, _extra.y - (Y_TITLE - TOP_DEFAULT))
	_put(title_label, 0.0, Y_TITLE, 1080.0, 130.0)
	title_label.position.x = 0.0
	_put(sub_label, 0.0, Y_SUB, 1080.0, 50.0)
	sub_label.position.x = 0.0
	_put(divider, _x0, Y_DIV, _w, 20.0)
	_put(score_caption, 0.0, Y_HERO, 1080.0, 44.0)
	_put(score_value, 0.0, Y_HERO_VALUE, 1080.0, 130.0)
	_put(record_band, _x0, Y_RECORD, _w, BAND_H)
	record_band.pivot_offset = Vector2(_w * 0.5, BAND_H * 0.5)
	record_band.queue_redraw()
	record_label.position = Vector2(0, 0)
	record_label.size = record_band.size
	for i in record_stars.size():
		var sx := 70.0 if i == 0 else _w - 70.0 - 48.0
		record_stars[i].position = Vector2(sx, (BAND_H - 48.0) * 0.5)
		record_stars[i].size = Vector2(48.0, 48.0)
	_put(record_pill, _x0 + 40.0, Y_RECORD + 20.0, _w - 80.0, 76.0)
	record_pill.pivot_offset = Vector2((_w - 80.0) * 0.5, 38.0)
	_put(
		record_note,
		_x0,
		Y_RECORD + BAND_H + 8.0 if record_kind == &"record" else Y_RECORD + 54.0,
		_w,
		40.0
	)
	var bh := ROW_H * float(breakdown_rows.size()) + 2.0 * BREAKDOWN_PAD
	_put(breakdown_panel, _x0, Y_BREAKDOWN, _w, bh)
	for i in breakdown_rows.size():
		var row := breakdown_rows[i]
		_put(row, _x0 + 36.0, Y_BREAKDOWN + BREAKDOWN_PAD + float(i) * ROW_H, _w - 72.0, ROW_H)
		var rw := _w - 72.0
		var det := row.get_node("Detail") as Label
		det.position = Vector2(rw - 500.0, 0)
		det.size = Vector2(230.0, ROW_H)
		var val := row.get_node("Value") as Label
		val.position = Vector2(rw - 260.0, 0)
		val.size = Vector2(260.0, ROW_H)
	_put(strip_panel, _x0, Y_STRIP, _w, STRIP_H)
	var cw := _w / 3.0
	for i in _strip_nodes.size():
		var col := _strip_nodes[i]
		_put(col, _x0 + cw * i, Y_STRIP, cw, STRIP_H)
		(col.get_node("Icon") as Control).position = Vector2(cw * 0.5 - 22.0, 18.0)
		(col.get_node("Icon") as Control).size = Vector2(44, 44)
		(col.get_node("Value") as Control).position = Vector2(0, 62.0)
		(col.get_node("Value") as Control).size = Vector2(cw, 64.0)
		(col.get_node("Caption") as Control).position = Vector2(0, 126.0)
		(col.get_node("Caption") as Control).size = Vector2(cw, 34.0)
	var combos_y := Y_COMBOS
	if not _new_names.is_empty():
		_put(achievement_chip, _x0, Y_COMBOS, _w, CHIP_H)
		chip_names.size = Vector2(_w - 92.0 - 28.0, 40.0)
		combos_y += CHIP_H + GAP
	combo_panel.custom_minimum_size = Vector2(_w, 0)
	combo_panel.size = Vector2(_w, 0)
	combo_panel.position = Vector2(_x0, combos_y + _dy)
	combo_panel.size = Vector2(_w, combo_panel.get_combined_minimum_size().y)
	var by := maxf(combo_panel.position.y + combo_panel.size.y + GAP, BUTTONS_MIN_Y)
	var limit := DESIGN_H - BOTTOM_DEFAULT - _extra.w
	if (
		by + REPLAY_H + BUTTON_GAP + MENU_H > limit
		and _shown_combos > 1
		and _combos_data.size() > 1
	):
		_shown_combos -= 1  # alt güvenli alana sığmıyor: bir kombo satırı daha "+N"e katılır
		_render_combos()
		_layout()
		return
	_put_abs(replay_button, _x0, by, _w, REPLAY_H)
	_put_abs(menu_button, _x0, by + REPLAY_H + BUTTON_GAP, _w, MENU_H)


func _put(c: Control, x: float, y: float, w: float, h: float) -> void:
	_put_abs(c, x, y + _dy, w, h)


func _put_abs(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


## İçeriğin alt kenarı (düğmeler dahil; test için).
func content_bottom() -> float:
	_layout()
	return menu_button.position.y + menu_button.size.y


## İçerik bloklarının (düğmeler hariç) alt kenarı.
func blocks_bottom() -> float:
	_layout()
	return combo_panel.position.y + combo_panel.size.y


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra.
func apply_safe_area(extra: Variant = null) -> void:
	if extra is Vector4:
		_extra = extra
	else:
		_extra = UiKit.current_safe_extra(Vector2(1080.0, DESIGN_H))
	_shown_combos = _combo_cap()
	if combo_box != null:
		_render_combos()
	_layout()


## Animasyonu bitir (dokunma ile atlama): değerler son halini alır, düğmeler en erken 800 ms'de açılır.
func finish_count() -> void:
	if _skip_t < 0.0:
		_skip_t = _t
	_apply(_t)


func buttons_enabled() -> bool:
	return _t >= ResultTimeline.buttons_ready_at(_skip_t)


func _process(delta: float) -> void:
	if not visible:
		return
	if _t < ResultTimeline.buttons_at() + STAMP_SEC + 0.1:
		_t += delta
		_apply(_t)


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tap and _skip_t < 0.0 and _t < ResultTimeline.buttons_at():
		finish_count()
		accept_event()


func _apply(t: float) -> void:
	var done := _skip_t >= 0.0
	var k := 1.0 if done else ResultTimeline.count_progress(t)
	score_value.text = UiKit.format_thousands(roundi(float(_hero_total) * k))
	time_value.text = UiKit.format_time(float(stats.get("time", 0.0)) * k)
	level_value.text = str(roundi(float(stats.get("level", 1)) * k))
	kills_value.text = UiKit.format_thousands(roundi(float(stats.get("kills", 0)) * k))
	for i in breakdown_rows.size():
		var rp := 1.0 if done else ResultTimeline.row_progress(i, t)
		var row := breakdown_rows[i]
		var target: int = _row_targets[i] if i < _row_targets.size() else 0
		var val := row.get_node("Value") as Label
		if _row_dash[i]:
			val.text = "—"
		else:
			var n := roundi(float(target) * rp)
			val.text = ("+" if _row_plus[i] else "") + UiKit.format_thousands(n)
		var a := rp if not _row_dim[i] else rp * EMPTY_ROW_ALPHA
		row.modulate.a = a
		row.position.y = (
			Y_BREAKDOWN + _dy + BREAKDOWN_PAD + float(i) * ROW_H + (1.0 - rp) * ROW_SLIDE_PX
		)
	_apply_chip(t, done)
	_apply_stamp(t, done)
	var on := buttons_enabled()
	replay_button.disabled = not on
	menu_button.disabled = not on


func _apply_chip(t: float, done: bool) -> void:
	if _new_names.is_empty():
		return
	var k := 1.0 if done else ResultTimeline.cubic_out(clampf((t - CHIP_AT) / CHIP_IN, 0.0, 1.0))
	achievement_chip.modulate.a = k
	achievement_chip.position.y = Y_COMBOS + _dy + (1.0 - k) * CHIP_SLIDE


func _apply_stamp(t: float, done: bool) -> void:
	var at := ResultTimeline.stamp_at()
	if record_kind == &"record":
		var dt := t - at
		if done or dt >= 0.0:
			var k := 1.0 if done else ResultTimeline.cubic_out(dt / STAMP_SEC)
			var sc := lerpf(STAMP_SCALE, 1.0, k)
			record_band.scale = Vector2(sc, sc)
			record_band.modulate.a = 1.0
			record_note.modulate.a = 1.0
			if not _stamped:
				_stamped = true
				record_stamped.emit()
			_shine.visible = not done and dt < SHINE_SEC
			if _shine.visible:
				_shine.size = Vector2(120.0, BAND_H)
				_shine.position = Vector2(lerpf(-120.0, _w, dt / SHINE_SEC), 0)
		else:
			record_band.scale = Vector2(STAMP_SCALE, STAMP_SCALE)
			record_band.modulate.a = 0.0
			record_note.modulate.a = 0.0
			_shine.visible = false
	elif record_kind == &"top10":
		var p := 1.0 if done else clampf(t / PILL_SEC, 0.0, 1.0)
		record_pill.modulate.a = p
		record_pill.scale = Vector2.ONE * lerpf(0.9, 1.0, p)
		record_note.modulate.a = 1.0
	else:
		record_note.modulate.a = 1.0 if done else clampf(t / PILL_SEC, 0.0, 1.0)


func _combo_row(c: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)
	row.add_theme_constant_override(&"separation", 27)
	var slot := SkillSlot.new(&"evolution", 80.0)
	slot.set_skill(StringName(str(c.get("id", ""))), 0, str(c.get("icon", "")), true)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", 0)
	v.add_child(UiKit.label(UiKit.upper_tr(str(c.get("name", ""))), &"LabelTimer", 36))
	v.add_child(UiKit.label(str(c.get("pair", "")), &"", 26, UiKit.KEMIK_300))
	row.add_child(v)
	return row


static func _glow_texture(c: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(c, 0.45), Color(c, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(1.1, 0.75)
	t.width = 128
	t.height = 128
	return t
