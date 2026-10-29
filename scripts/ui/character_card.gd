class_name CharacterCard
extends RefCounted
## Karakter kartı (R5a): şerit düğmesi kurulumu, yer tutucu monogramı, odak/kilit/seçili durum yenileme ve ✓/kilit rozeti.
## Gövdeler `characters_screen.gd`den AYNEN taşındı (düğüm adları ve ekleme sırası aynı; yerleşim karakterizasyonu
## rf_ui_characters_rects). Durum tutmaz; ekran tipini bilmez (class_name döngüsü yok).

const CARD_W := 252.0
const CARD_H := 264.0
## Yer tutucu karakterlerin (placeholder:true) portresi: belirgin soğuk ton + baş harf; release'te de görünür (K-03).
const PLACEHOLDER_TINT := Color(0.62, 0.78, 1.0)
const FALLBACK_PORTRAIT := "res://assets/ui/portre-seviye-atlama.png"


static func make(id: StringName, c: CharacterDef, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = "Card_%s" % id
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.add_theme_stylebox_override(&"normal", UiKit.stylebox(UiKit.TAS_800, UiKit.BRONZ_700, 4, 6))
	b.pressed.connect(on_press)
	var tex := UiKit.texture(c.portrait) if c != null and c.portrait != "" else null
	if tex == null:
		tex = UiKit.texture(FALLBACK_PORTRAIT)  # K-03: sahne ile aynı varsayılan portre kırpması
	if tex != null:
		var pr := TextureRect.new()
		pr.name = "Face"
		pr.texture = tex
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_SCALE
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Yüz kırpması: genişliğe sığdır, üstten hizala.
		pr.size = Vector2(CARD_W * 1.5, CARD_W * 1.5 * 1.5)
		pr.position = Vector2(-CARD_W * 0.25, -8.0)
		if c != null and c.placeholder:
			pr.self_modulate = PLACEHOLDER_TINT
		b.add_child(pr)
		if c != null and c.placeholder:
			b.add_child(monogram(c, 120))
	var scrim := ColorRect.new()
	scrim.color = Color(UiKit.VOID, 0.7)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.size = Vector2(CARD_W, 64)
	scrim.position = Vector2(0, CARD_H - 64.0)
	b.add_child(scrim)
	var nm := UiKit.label(UiKit.character_upper(c), &"LabelTimer", 28)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size = Vector2(CARD_W, 40)
	nm.position = Vector2(0, CARD_H - 52.0)
	nm.clip_text = true
	b.add_child(nm)
	var ring := Panel.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(ring)
	b.add_child(ring)
	var badge := Control.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	return b


## Yer tutucu karakterin baş harfi (monogram); kartta ve sahnede portrenin üstüne biner.
static func monogram(c: CharacterDef, px: int) -> Label:
	var m := UiKit.label(UiKit.character_upper(c).substr(0, 1), &"LabelTitle", px, UiKit.KEMIK_100)
	m.name = "Monogram"
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = Vector2(CARD_W, px * 1.3)
	m.position = Vector2(0, (CARD_H - 64.0 - px * 1.3) * 0.5)
	m.modulate.a = 0.85
	return m


## Odak/kilit/seçili görünümü; `lock_reason` yalnız kilitli ve seçili olmayan kartta kullanılır.
static func refresh(
	card: Button, name_text: String, focus: bool, locked: bool, selected: bool, lock_reason: String
) -> void:
	var border := UiKit.BRONZ_300 if focus else (UiKit.KAHVE_500 if locked else UiKit.BRONZ_700)
	var sb := UiKit.stylebox(Color(0, 0, 0, 0), border, 6 if focus else 4, 6)
	if focus:
		sb.shadow_color = Color(UiKit.AMBER, 0.4)
		sb.shadow_size = 18
	(card.get_node("Ring") as Panel).add_theme_stylebox_override(&"panel", sb)
	card.modulate = Color(0.55, 0.55, 0.55) if locked else Color.WHITE
	var badge := card.get_node("Badge") as Control
	for ch in badge.get_children():
		ch.free()
	if selected:
		var bg := BadgeDot.new(UiKit.AMBER)
		bg.position = Vector2(CARD_W - 68.0, 10.0)
		badge.add_child(bg)
		bg.add_child(UiKit.Glyph.new(&"check", UiKit.BORDO_900, 40.0))
		bg.get_child(0).position = Vector2(8, 8)
		card.accessibility_name = "%s, seçili" % name_text
	elif locked:
		var bg := BadgeDot.new(UiKit.TAS_900)
		bg.position = Vector2(CARD_W - 68.0, 10.0)
		badge.add_child(bg)
		card.accessibility_name = "%s, kilitli. %s" % [name_text, lock_reason]
	else:
		card.accessibility_name = name_text


class BadgeDot:
	extends Control
	var color: Color

	func _init(c: Color) -> void:
		color = c
		custom_minimum_size = Vector2(56, 56)
		size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 28.0, color)
		draw_arc(size * 0.5, 28.0, 0.0, TAU, 32, UiKit.BRONZ_500, 3.0, true)
		if color == UiKit.TAS_900:  # kilit rozeti
			var c := size * 0.5
			draw_rect(Rect2(c + Vector2(-11, -2), Vector2(22, 17)), UiKit.KEMIK_300)
			draw_arc(c + Vector2(0, -2), 7.0, PI, TAU, 12, UiKit.KEMIK_300, 3.0, true)
