class_name LevelUpScreen
extends Control
## Seviye atlama (docs/ui/mockups/04-seviye-atlama). Üstte portre + "GUNSLINGER / SEVİYE N", altta 1..3 kart
## (984×324, aralık 27). Karta dokun = seç (onay yok). Açılıştan sonra 500 ms giriş kilidi (kartlar %60 opak).
## Evrim kartı her zaman en altta (amber, sekizgen çerçeve); seçenek yoksa tek "Şifa" kartı.
## Oyun kuralı yok: kartlar sim.pending_choices()'tan gelir, seçim `chosen(sim_index)` ile döner.

signal chosen(index: int)

const LOCK_TIME := 0.5
const LOCKED_ALPHA := 0.6
const CARD_W := 984.0
const CARD_H := 324.0
const CARD_GAP := 27.0
const ICON := 180.0
const PORTRAIT := "res://assets/ui/portre-seviye-atlama.png"
const PORTRAIT_H := 1620.0
## v2.0 başlık bloğu (N4): üst yazı y 880, başlık y ≈ 924; portre perdesi alt gradyan duraklı.
const NAME_Y := 880.0
const TITLE_Y := 924.0
const CARDS_BOTTOM := 200.0

var title_label: Label
## v2.0: karakter adı (üst yazı) ve portre düğümü (portre yoksa null; bordo radyal zemin kullanılır).
var name_label: Label
var portrait_node: TextureRect = null
var cards_box: VBoxContainer
var cards: Array[Button] = []
## Görüntülenen kart sırası → sim'deki seçim indeksi.
var order: PackedInt32Array = PackedInt32Array()

var _lock_left: float = 0.0
var _portrait_host: Control
var _backdrop: TextureRect
var _head: VBoxContainer
var _hint: Label
var _safe_bottom: float = 0.0
var _data: GameData = null


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

	_portrait_host = Control.new()
	_portrait_host.name = "PortraitHost"
	_portrait_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_host.anchor_right = 1.0
	_portrait_host.offset_bottom = PORTRAIT_H
	add_child(_portrait_host)
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_right = 1.0
	shade.offset_bottom = PORTRAIT_H
	add_child(shade)
	var below := ColorRect.new()
	below.color = UiKit.VOID
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	below.anchor_right = 1.0
	below.anchor_bottom = 1.0
	below.offset_top = PORTRAIT_H - 2.0
	add_child(below)

	_head = VBoxContainer.new()
	_head.position = Vector2(60, NAME_Y)
	_head.add_theme_constant_override(&"separation", -6)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label = UiKit.label("GUNSLINGER", &"LabelAccent", 34)
	name_label.add_theme_constant_override(&"shadow_offset_y", 3)
	_head.add_child(name_label)
	title_label = UiKit.label("SEVİYE 2", &"LabelTitle", 104)
	title_label.add_theme_constant_override(&"shadow_offset_y", 4)
	_head.add_child(title_label)
	add_child(_head)
	set_character(null)

	cards_box = VBoxContainer.new()
	cards_box.name = "Cards"
	cards_box.add_theme_constant_override(&"separation", int(CARD_GAP))
	cards_box.alignment = BoxContainer.ALIGNMENT_END
	cards_box.anchor_left = 0.5
	cards_box.anchor_right = 0.5
	cards_box.anchor_top = 1.0
	cards_box.anchor_bottom = 1.0
	cards_box.offset_left = -CARD_W * 0.5
	cards_box.offset_right = CARD_W * 0.5
	cards_box.offset_top = -200.0 - 3.0 * CARD_H - 2.0 * CARD_GAP
	cards_box.offset_bottom = -200.0
	cards_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(cards_box)

	_hint = UiKit.label("Bir karta dokun", &"", 28, UiKit.KEMIK_300)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_top = -140.0
	_hint.offset_bottom = -90.0
	add_child(_hint)


## Kart sırası (saf): evrim kartları en alta; diğerlerinin göreli sırası korunur. Dönen: sim indeksleri.
static func display_order(kinds: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in kinds.size():
		if StringName(str(kinds[i])) != Choice.KIND_EVOLUTION:
			out.append(i)
	for i in kinds.size():
		if StringName(str(kinds[i])) == Choice.KIND_EVOLUTION:
			out.append(i)
	return out


## Kartları göster ve 500 ms kilidi başlat.
func show_choices(
	choices: Array, level: int, data: GameData = null, character: CharacterDef = null
) -> void:
	_data = data
	set_character(character)
	title_label.text = "SEVİYE %d" % level
	for c in cards:
		c.queue_free()
	cards.clear()
	var kinds: Array = []
	for ch in choices:
		kinds.append(ch.kind if ch is Choice else &"")
	order = display_order(kinds)
	for k in order.size():
		var sim_index := order[k]
		var card := _make_card(choices[sim_index])
		card.name = "Card%d" % k
		card.pressed.connect(_on_card_pressed.bind(sim_index))
		cards_box.add_child(card)
		cards.append(card)
	_lock_left = LOCK_TIME
	_apply_lock()
	visible = true
	if not cards.is_empty():
		cards[0].grab_focus.call_deferred()  # varsayılan odak (klavye/gamepad)


## Karakter başlığı + portre (null = v1.1: Gunslinger, varsayılan portre). Portre dosyası yoksa portresiz düzen:
## bordo radyal zemin, başlık aynı yerde (çökmez).
func set_character(character: CharacterDef) -> void:
	var path := character.portrait if character != null else PORTRAIT
	name_label.text = UiKit.upper_tr(character.display_name) if character != null else "GUNSLINGER"
	if portrait_node != null:
		portrait_node.free()
		portrait_node = null
	if _backdrop != null:
		_backdrop.free()
		_backdrop = null
	var tex := UiKit.texture(path) if path != "" else null
	if tex != null:
		portrait_node = TextureRect.new()
		portrait_node.name = "Portrait"
		portrait_node.texture = tex
		portrait_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.fill(portrait_node)
		_portrait_host.add_child(portrait_node)
	else:
		_backdrop = TextureRect.new()
		_backdrop.name = "Backdrop"
		_backdrop.texture = _backdrop_texture()
		_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.fill(_backdrop)
		_portrait_host.add_child(_backdrop)


## N7: alt pay kartları ve ipucunu yukarı alır; üst pay etkilemez (başlık y 880). extra: Vector4 ya da null.
func apply_safe_area(extra: Variant = null) -> void:
	var e := Vector4.ZERO
	if extra is Vector4:
		e = extra
	else:
		e = UiKit.current_safe_extra(Vector2(1080.0, 2400.0))
	_safe_bottom = maxf(0.0, e.w)
	cards_box.offset_top = -(CARDS_BOTTOM + _safe_bottom) - 3.0 * CARD_H - 2.0 * CARD_GAP
	cards_box.offset_bottom = -(CARDS_BOTTOM + _safe_bottom)
	_hint.offset_top = -(140.0 + _safe_bottom)
	_hint.offset_bottom = -(90.0 + _safe_bottom)


func is_locked() -> bool:
	return _lock_left > 0.0


func _process(delta: float) -> void:
	if _lock_left > 0.0:
		_lock_left = maxf(0.0, _lock_left - delta)
		if _lock_left == 0.0:
			_apply_lock()


func _apply_lock() -> void:
	var locked := is_locked()
	for c in cards:
		c.disabled = locked
		c.modulate = Color(1, 1, 1, LOCKED_ALPHA if locked else 1.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP


func _on_card_pressed(sim_index: int) -> void:
	if is_locked():
		return
	chosen.emit(sim_index)


func _make_card(ch: Variant) -> Button:
	var kind: StringName = ch.kind if ch is Choice else &"heal"
	var evo := kind == Choice.KIND_EVOLUTION
	var card := Button.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.focus_mode = Control.FOCUS_ALL
	var border := UiKit.AMBER if evo else UiKit.BRONZ_700
	var n := UiKit.stylebox(UiKit.MOR_700, border, 5 if evo else 4, 18, true)
	if evo:
		n.shadow_color = Color(UiKit.AMBER, 0.45)
		n.shadow_size = 24
		n.shadow_offset = Vector2.ZERO
	var p := UiKit.stylebox(UiKit.MOR_800, UiKit.BRONZ_300, 6, 18)
	p.expand_margin_top = -6.0
	p.expand_margin_bottom = 6.0
	card.add_theme_stylebox_override(&"normal", n)
	card.add_theme_stylebox_override(&"hover", n)
	card.add_theme_stylebox_override(&"disabled", n)
	card.add_theme_stylebox_override(&"pressed", p)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 40)
	UiKit.fill(row)
	row.offset_left = 36
	row.offset_right = -36
	card.add_child(row)

	var id: StringName = ch.skill_id if ch is Choice else &""
	var icon_field: String = ch.icon if ch is Choice else ""
	var slot: SkillSlot
	if kind == Choice.KIND_HEAL:
		slot = SkillSlot.new(&"active", ICON)
		slot.set_skill(&"sifa", 0)
		slot.icon = UiKit.hud_icon("hud-can")
	else:
		slot = SkillSlot.new(_skill_kind(id), ICON)
		slot.set_skill(id if id != &"" else &"bilinmiyor", 0, icon_field, evo)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 10)
	row.add_child(col)
	var title: String = ch.title if ch is Choice else "Şifa"
	var t := UiKit.label(UiKit.upper_tr(title), &"LabelTimer", 46)  # Cinzel'de küçük harf yok
	t.add_theme_color_override(&"font_color", UiKit.KEMIK_100)
	col.add_child(t)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override(&"separation", 16)
	meta.add_child(_tag(kind))
	var lv := UiKit.label(
		level_text(kind, ch.from_level if ch is Choice else 0, ch.to_level if ch is Choice else 0),
		&"",
		28,
		UiKit.BRONZ_300
	)
	lv.add_theme_font_override(&"font", UiKit.font_semibold())
	meta.add_child(lv)
	col.add_child(meta)
	var desc := UiKit.label(ch.desc if ch is Choice else "Canın %25 yenilenir.", &"", 32)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override(&"font_color", UiKit.KEMIK_300)
	desc.custom_minimum_size = Vector2(600, 0)
	col.add_child(desc)
	return card


## "Sv. 4 › 5" / "Sv. 1" / "Yeni form" / "+%25 can".
static func level_text(kind: StringName, from_level: int, to_level: int) -> String:
	match kind:
		Choice.KIND_UPGRADE:
			return "Sv. %d › %d" % [from_level, to_level]
		Choice.KIND_NEW:
			return "Sv. %d" % maxi(1, to_level)
		Choice.KIND_EVOLUTION:
			return "Yeni form"
	return "+%25 can"


## Etiket metni (önceden büyük harf).
static func tag_text(kind: StringName) -> String:
	match kind:
		Choice.KIND_UPGRADE:
			return "YÜKSELT"
		Choice.KIND_NEW:
			return "YENİ"
		Choice.KIND_EVOLUTION:
			return "EVRİM"
	return "ŞİFA"


func _tag(kind: StringName) -> PanelContainer:
	var bg := UiKit.MOR_500
	var fg := UiKit.KEMIK_100
	match kind:
		Choice.KIND_UPGRADE:
			bg = UiKit.BORDO_700
		Choice.KIND_EVOLUTION:
			bg = UiKit.AMBER
			fg = UiKit.BORDO_900
		Choice.KIND_HEAL:
			bg = UiKit.BORDO_500
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiKit.stylebox(bg, UiKit.BRONZ_500 if kind != Choice.KIND_EVOLUTION else bg, 2, 22)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override(&"panel", sb)
	var l := UiKit.label(tag_text(kind), &"", 26, fg)
	l.add_theme_font_override(&"font", UiKit.font_semibold())
	l.add_theme_constant_override(&"shadow_offset_y", 0)
	pc.add_child(l)
	return pc


func _skill_kind(id: StringName) -> StringName:
	var def: SkillDef = _data.get_skill(id) if _data != null else null
	if def != null and def.kind == SkillDef.KIND_PASSIVE:
		return &"passive"
	return &"active"


## Alt gradyan duraklı (void): y 560: 0 → y 860: 0,72 → y 1000: 0,90 → y 1150: 1 (üst perde yok).
static func _shade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(
		[0.0, 560.0 / PORTRAIT_H, 860.0 / PORTRAIT_H, 1000.0 / PORTRAIT_H, 1150.0 / PORTRAIT_H]
	)
	g.colors = PackedColorArray(
		[
			Color(UiKit.VOID, 0.0),
			Color(UiKit.VOID, 0.0),
			Color(UiKit.VOID, 0.72),
			Color(UiKit.VOID, 0.90),
			Color(UiKit.VOID, 1.0),
		]
	)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 256
	return t


## Portresiz zemin: bordo radyal (#5C1D26 α 0,55 → void).
static func _backdrop_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(UiKit.BORDO_700, 0.55), Color(UiKit.VOID, 1.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.35)
	t.fill_to = Vector2(1.0, 0.9)
	t.width = 128
	t.height = 128
	return t
