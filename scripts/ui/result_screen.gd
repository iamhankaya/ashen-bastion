class_name ResultScreen
extends Control
## Oyun Bitti / Kazandın (docs/ui/mockups/06-oyun-bitti, 06b-oyun-bitti-kombosuz, 07-kazandin).
## Başlık + alt başlık, istatistik paneli (Süre MM:SS, Seviye, Öldürme — binlik ayracı nokta), kurulan kombolar
## (yoksa öğretici boş durum metni), TEKRAR OYNA / ANA MENÜ. Sayılar 600 ms'de sayarak artar (dokun = bitir);
## düğmeler 800 ms sonra etkinleşir. Veri: run_ended(won, stats) sözlüğü {time, level, kills, evolutions}.

signal replay_requested
signal menu_requested

const COUNT_TIME := 0.6
const BUTTON_DELAY := 0.8
const W := 936.0
const MAX_COMBOS := 5
const EMPTY_TEXT := "Bu seferlik kombo yok."
const LOST_SUB := "Kale seni yuttu."
const WON_SUB := "Düşmüş Kale Lordu devrildi."

var won: bool = false
var stats: Dictionary = {}
var title_label: Label
var sub_label: Label
var time_value: Label
var level_value: Label
var kills_value: Label
var combo_box: VBoxContainer
var replay_button: Button
var menu_button: Button
var glow: TextureRect

var _t: float = 0.0
var _subtitle: String = ""


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

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 24)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.offset_left = -W * 0.5
	col.offset_right = W * 0.5
	col.offset_top = 170.0
	add_child(col)

	title_label = UiKit.label("OYUN BİTTİ", &"LabelTitle", 104)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_constant_override(&"shadow_offset_y", 5)
	col.add_child(title_label)
	sub_label = UiKit.label(LOST_SUB, &"", 34, UiKit.KEMIK_300)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub_label)
	col.add_child(UiKit.divider())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 90)
	col.add_child(gap)

	var stats_panel := PanelContainer.new()
	stats_panel.theme_type_variation = &"PanelRaised"
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override(&"separation", 0)
	time_value = _stat_row(sv, "hud-sure", "Süre", true)
	level_value = _stat_row(sv, "hud-xp", "Seviye", true)
	kills_value = _stat_row(sv, "hud-oldurme", "Öldürme", false)
	stats_panel.add_child(sv)
	col.add_child(stats_panel)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 36)
	col.add_child(gap2)
	var combo_panel := PanelContainer.new()
	combo_panel.theme_type_variation = &"PanelRaised"
	combo_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # içeriğe göre boyutlanır (boşken kısa satır)
	combo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override(&"separation", 24)
	cv.add_child(UiKit.label("KURULAN KOMBOLAR", &"LabelAccent", 32))
	combo_box = VBoxContainer.new()
	combo_box.add_theme_constant_override(&"separation", 20)
	cv.add_child(combo_box)
	combo_panel.add_child(cv)
	col.add_child(combo_panel)

	var gap3 := Control.new()  # düğmeler içeriğin hemen altında (alta sabit değil): panel↔düğme ölü boşluk yok
	gap3.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap3)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override(&"separation", 27)
	replay_button = UiKit.button("TEKRAR OYNA", &"primary", 156.0)
	replay_button.add_theme_font_size_override(&"font_size", 52)
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	menu_button = UiKit.button("ANA MENÜ", &"secondary")
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	btns.add_child(replay_button)
	btns.add_child(menu_button)
	col.add_child(btns)


## Sonucu göster. combos: UiKit.combo_rows() çıktısı. subtitle boşsa varsayılan.
@warning_ignore("unused_parameter")
func show_result(
	p_won: bool,
	p_stats: Dictionary,
	combos: Array[Dictionary] = [],
	subtitle: String = "",
	record: Dictionary = {}
) -> void:
	won = p_won
	stats = p_stats
	_subtitle = subtitle
	title_label.text = "KAZANDIN" if won else "OYUN BİTTİ"
	title_label.add_theme_color_override(&"font_color", UiKit.AMBER if won else UiKit.KEMIK_100)
	sub_label.text = subtitle if subtitle != "" else (WON_SUB if won else LOST_SUB)
	glow.texture = _glow_texture(UiKit.AMBER if won else UiKit.BORDO_500)
	for c in combo_box.get_children():
		c.queue_free()
	if combos.is_empty():
		var e := UiKit.label(EMPTY_TEXT, &"", 32, UiKit.KEMIK_300)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(W - 100.0, 0)
		combo_box.add_child(e)
	else:
		for i in mini(combos.size(), MAX_COMBOS):
			combo_box.add_child(_combo_row(combos[i]))
	_t = 0.0
	_apply(0.0)
	visible = true


## İçeriğin alt kenarı (test için). Gövde D3-4'te.
func content_bottom() -> float:
	Stub.todo(&"ResultScreen.content_bottom")
	return 0.0


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra. Gövde D3-4'te.
@warning_ignore("unused_parameter")
func apply_safe_area(extra: Variant = null) -> void:
	Stub.todo(&"ResultScreen.apply_safe_area")


## Animasyonu bitir (dokunma ile atlama).
func finish_count() -> void:
	_t = maxf(_t, COUNT_TIME)
	_apply(_t)


func buttons_enabled() -> bool:
	return _t >= BUTTON_DELAY


func _process(delta: float) -> void:
	if not visible or _t >= BUTTON_DELAY:
		return
	_t += delta
	_apply(_t)


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tap and _t < COUNT_TIME:
		finish_count()
		accept_event()


func _apply(t: float) -> void:
	var k := clampf(t / COUNT_TIME, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)  # cubic-out
	time_value.text = UiKit.format_time(float(stats.get("time", 0.0)) * k)
	level_value.text = str(roundi(float(stats.get("level", 1)) * k))
	kills_value.text = UiKit.format_thousands(roundi(float(stats.get("kills", 0)) * k))
	var on := t >= BUTTON_DELAY
	replay_button.disabled = not on
	menu_button.disabled = not on


func _stat_row(parent: VBoxContainer, icon: String, label_text: String, line: bool) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 132)
	row.add_theme_constant_override(&"separation", 24)
	var ic := TextureRect.new()
	ic.texture = UiKit.hud_icon(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(60, 60)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := UiKit.label(label_text, &"", 34, UiKit.KEMIK_300)
	l.add_theme_font_override(&"font", UiKit.font_semibold())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	var v := UiKit.label("0", &"LabelTimer", 60)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_FILL
	row.add_child(v)
	parent.add_child(row)
	if line:
		var sep := ColorRect.new()
		sep.color = Color(UiKit.KEMIK_500, 0.25)
		sep.custom_minimum_size = Vector2(0, 2)
		parent.add_child(sep)
	return v


func _combo_row(c: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 27)
	var slot := SkillSlot.new(&"evolution", 112.0)
	slot.set_skill(StringName(str(c.get("id", ""))), 0, str(c.get("icon", "")), true)
	row.add_child(slot)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", 2)
	v.add_child(UiKit.label(UiKit.upper_tr(str(c.get("name", ""))), &"LabelTimer", 40))
	v.add_child(UiKit.label(str(c.get("pair", "")), &"", 28, UiKit.KEMIK_300))
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
