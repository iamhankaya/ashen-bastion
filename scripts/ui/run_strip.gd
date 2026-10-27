class_name RunStrip
extends Button
## v2.1 koşu şeridi (docs/design/v2.1/DESIGN.md §2): ana sayfada OYNA'nın üstünde seçili (mod, zorluk) özeti; tüm şerit tek
## dokunma hedefidir ve KOŞU ekranını açar. Aynı dosya KOŞU ekranının ve duraklatma çiplerinin ortak metin/glif kaynağıdır:
## sayılar ve süreler `data/run_profiles.json`'dan (V21Runs.profiles) gelir, burada sabit sayı yoktur.

const H := 132.0
const NO_DATA := -2  # profil dosyası okunamadı: süre/Lord dakikası yazılmaz
const H_BIG := 168.0
const MODE_ORDER: Array[StringName] = [&"quick", &"normal", &"endless"]
const DIFF_ORDER: Array[StringName] = [&"easy", &"normal", &"hard"]
const MODE_NAMES := {&"quick": "HIZLI", &"normal": "NORMAL", &"endless": "SONSUZ"}
const MODE_TITLES := {&"quick": "Hızlı", &"normal": "Normal", &"endless": "Sonsuz"}
const DIFF_NAMES := {&"easy": "KOLAY", &"normal": "NORMAL", &"hard": "ZOR"}
const DIFF_TITLES := {&"easy": "Kolay", &"normal": "Normal", &"hard": "Zor"}
const SHIELDS := {&"easy": 1, &"normal": 2, &"hard": 3}
const MODE_DESC := {
	&"quick": "Kısa koşu. Lord %d. dakikada gelir.",
	&"normal": "Klasik koşu. Lord %d. dakikada gelir.",
	&"endless": "Lord devrilince koşu sürer; ölene kadar.",
}
const DIFF_DESC := {
	&"easy": "Daha az ve zayıf düşman.",
	&"normal": "Dengeli koşu.",
	&"hard": "Yoğun ve sert düşman.",
}
## Ayrıntı levhası satırları: [etiket, RunProfiles zorluk alanı].
const DETAIL_ROWS := [
	["Düşman canı", "enemy_hp"],
	["Düşman hasarı", "enemy_dmg"],
	["Düşman sayısı", "spawn_density"],
	["Kazanılan XP", "xp"],
]
## TalkBack için küçük harfli metinler (to_lower Türkçe i/İ tuzağı nedeniyle yasak).
const DIFF_SPOKEN := {
	&"easy": "daha az ve zayıf düşman",
	&"normal": "dengeli koşu",
	&"hard": "yoğun ve sert düşman",
}
const DETAIL_SPOKEN := {
	"enemy_hp": "düşman canı",
	"enemy_dmg": "düşman hasarı",
	"spawn_density": "düşman sayısı",
	"xp": "kazanılan XP",
}
const RULE_BASE := "Skorun bu mod ve zorluğun kendi listesine yazılır."
const RULE_EASY := "Kolay'da Lord başarımları ve toplam sayaçlar ilerlemez."
const RULE_ENDLESS := "İlk Lord'u devirmek zaferdir; koşu sen ölene kadar sürer."
const ONES := ["", "bir", "iki", "üç", "dört", "beş", "altı", "yedi", "sekiz", "dokuz"]
const TENS := ["", "on", "yirmi", "otuz", "kırk", "elli", "altmış", "yetmiş", "seksen", "doksan"]

var _glyph_slot: Control
var _title: Label
var _sub: Label
var _shields: Shields
var _change: Label
var _big: bool = false


## Mod glifi (DESIGN §4): HIZLI çift ok, NORMAL kum saati, SONSUZ sonsuz halkası. Çizim, emoji/yazı tipi gerekmez.
class ModeGlyph:
	extends Control
	var mode: StringName = &"normal"
	var color: Color = UiKit.BRONZ_300

	func _init(
		p_mode: StringName = &"normal", p_color: Color = UiKit.BRONZ_300, p_size := 64.0
	) -> void:
		mode = p_mode
		color = p_color
		custom_minimum_size = Vector2(p_size, p_size)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		match mode:
			&"quick":
				for dx in [-0.42, 0.42]:
					draw_colored_polygon(
						PackedVector2Array(
							[
								c + Vector2(r * (dx - 0.4), -r * 0.62),
								c + Vector2(r * (dx + 0.4), 0.0),
								c + Vector2(r * (dx - 0.4), r * 0.62),
							]
						),
						color
					)
			&"endless":
				var w := maxf(3.0, r * 0.22)
				draw_arc(c + Vector2(-r * 0.4, 0.0), r * 0.4, 0.0, TAU, 32, color, w, true)
				draw_arc(c + Vector2(r * 0.4, 0.0), r * 0.4, 0.0, TAU, 32, color, w, true)
			_:
				var top := PackedVector2Array(
					[c + Vector2(-r * 0.6, -r * 0.8), c + Vector2(r * 0.6, -r * 0.8), c]
				)
				var bottom := PackedVector2Array(
					[c, c + Vector2(r * 0.6, r * 0.8), c + Vector2(-r * 0.6, r * 0.8)]
				)
				draw_colored_polygon(top, color)
				draw_colored_polygon(bottom, color)


## Zorluk kalkanları (DESIGN §4): `count` dolu + kalanı boş, toplam 3 (sayı = zorluk).
class Shields:
	extends Control
	var count: int = 2
	var color: Color = UiKit.BRONZ_300

	func _init(
		p_count: int = 2, p_color: Color = UiKit.BRONZ_300, p_size := Vector2(84, 28)
	) -> void:
		count = p_count
		color = p_color
		custom_minimum_size = p_size
		size = p_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := (size.x - 2.0 * size.y * 0.25) / 3.0
		for i in 3:
			var x := float(i) * (w + size.y * 0.25)
			var pts := PackedVector2Array(
				[
					Vector2(x, 0.0),
					Vector2(x + w, 0.0),
					Vector2(x + w, size.y * 0.55),
					Vector2(x + w * 0.5, size.y),
					Vector2(x, size.y * 0.55),
				]
			)
			if i < count:
				draw_colored_polygon(pts, color)
			else:
				pts.append(pts[0])
				draw_polyline(pts, color, maxf(2.0, size.y * 0.1), true)


## Uyarı üçgeni (`!`, amber): kural levhası ve sonuç notu.
class WarnGlyph:
	extends Control

	func _init(p_size := 40.0) -> void:
		custom_minimum_size = Vector2(p_size, p_size)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y)
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(r * 0.5, r * 0.05),
					Vector2(r * 0.97, r * 0.92),
					Vector2(r * 0.03, r * 0.92)
				]
			),
			UiKit.AMBER
		)
		draw_rect(Rect2(r * 0.46, r * 0.34, r * 0.08, r * 0.30), UiKit.VOID)
		draw_rect(Rect2(r * 0.46, r * 0.70, r * 0.08, r * 0.08), UiKit.VOID)


func _init() -> void:
	name = "RunStrip"
	custom_minimum_size = Vector2(0, H)
	focus_mode = Control.FOCUS_ALL
	for st in [&"normal", &"hover", &"disabled"]:
		add_theme_stylebox_override(st, UiKit.skin_box("levha", 40, UiKit.TAS_700))
	add_theme_stylebox_override(&"pressed", UiKit.skin_box("dugme-basili", 40, UiKit.TAS_800))
	add_theme_stylebox_override(&"focus", UiKit.stylebox(Color(0, 0, 0, 0), UiKit.AMBER, 6, 14))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 22)
	UiKit.fill(row)
	row.offset_left = 28.0
	row.offset_right = -28.0
	add_child(row)
	_glyph_slot = Control.new()
	_glyph_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_glyph_slot)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 2)
	_title = UiKit.label("", &"LabelAccent", 34, UiKit.KEMIK_100)
	_title.add_theme_constant_override(&"shadow_offset_y", 0)
	text.add_child(_title)
	var sub := HBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_constant_override(&"separation", 14)
	_sub = UiKit.label("", &"", 26, UiKit.KEMIK_300)
	sub.add_child(_sub)
	_shields = Shields.new(2, UiKit.KEMIK_300, Vector2(66, 22))
	_shields.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub.add_child(_shields)
	text.add_child(sub)
	row.add_child(text)
	_change = UiKit.label("DEĞİŞTİR ›", &"", 26, UiKit.BRONZ_300)
	_change.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_change)


## 2× yazı: yükseklik 168, glif 80, yazı 50/40; "DEĞİŞTİR" sözcüğü düşer, yalnız "›" kalır (sığma için).
func set_big(big: bool) -> void:
	_big = big
	custom_minimum_size.y = H_BIG if big else H
	_title.add_theme_font_size_override(&"font_size", 50 if big else 34)
	_sub.add_theme_font_size_override(&"font_size", 40 if big else 26)
	_shields.custom_minimum_size = Vector2(99, 33) if big else Vector2(66, 22)
	_shields.size = _shields.custom_minimum_size
	_change.text = "›" if big else "DEĞİŞTİR ›"
	_change.add_theme_font_size_override(&"font_size", 56 if big else 26)


func is_big() -> bool:
	return _big


## Şerit içeriğini seçime göre yeniler. cfg = V21Runs.profiles() (boş: süre yazılmaz).
func show_selection(mode: StringName, diff: StringName, cfg: Dictionary) -> void:
	for c in _glyph_slot.get_children():
		c.queue_free()
	var gs := 80.0 if _big else 64.0
	_glyph_slot.custom_minimum_size = Vector2(gs, gs)
	_glyph_slot.add_child(ModeGlyph.new(mode, UiKit.BRONZ_300, gs))
	_title.text = title_text(mode, cfg)
	_sub.text = "Zorluk: %s" % DIFF_TITLES.get(diff, "")
	_shields.count = int(SHIELDS.get(diff, 0))
	_shields.queue_redraw()
	accessibility_name = strip_a11y(mode, diff, cfg)


# --- saf metin kaynağı (testler ağaçsız çağırır) ---------------------------------------------------------------


## Mod süresi dakika: Sonsuz için -1 (süresiz), diğerleri 20 dk × time_scale.
static func minutes(mode: StringName, cfg: Dictionary) -> int:
	var m: Dictionary = cfg.get("modes", {}).get(String(mode), {})
	if m.is_empty():
		return NO_DATA
	if str(m.get("end_mode", "")) == "endless":
		return -1
	return roundi(GameSim.DEFAULT_END_TIME * float(m.get("time_scale", 1.0)) / 60.0)


## "10 DK" / "20 DK" / "∞".
static func duration_text(mode: StringName, cfg: Dictionary) -> String:
	var mins := minutes(mode, cfg)
	if mins == NO_DATA:
		return ""
	return "∞" if mins < 0 else "%d DK" % mins


## Şerit başlığı: "NORMAL · 20 DK"; Sonsuz'da süre yazılmaz ("SONSUZ").
static func title_text(mode: StringName, cfg: Dictionary) -> String:
	var mins := minutes(mode, cfg)
	var n: String = MODE_NAMES.get(mode, "")
	return n if mins < 0 else "%s · %d DK" % [n, mins]


## Mod açıklaması (Hızlı/Normal'de Lord dakikası profildeki süreden).
static func mode_desc(mode: StringName, cfg: Dictionary) -> String:
	var d: String = MODE_DESC.get(mode, "")
	if not d.contains("%d"):
		return d
	var mins := minutes(mode, cfg)
	return d.get_slice(".", 0) + "." if mins == NO_DATA else d % mins


## Ayrıntı satırı değeri: çarpan -> "−%30" / "+%25"; 1,0 -> Zor satırlarında "tam", XP'de "aynı".
static func delta_text(key: String, factor: float) -> String:
	var pct := roundi((factor - 1.0) * 100.0)
	if pct == 0:
		return "aynı" if key == "xp" else "tam"
	return "%s%%%d" % ["+" if pct > 0 else "−", absi(pct)]


## [[etiket, değer], ...] seçili zorluk için; zorluk yoksa boş.
static func detail_rows(diff: StringName, cfg: Dictionary) -> Array:
	var d: Dictionary = cfg.get("difficulties", {}).get(String(diff), {})
	var out := []
	if d.is_empty():
		return out
	for r in DETAIL_ROWS:
		out.append([r[0], delta_text(r[1], float(d.get(r[1], 1.0)))])
	return out


## Kural levhası satırları: [{"text", "warn"}]; ilk satır her zaman nötr.
static func rule_lines(mode: StringName, diff: StringName) -> Array:
	var out := [{"text": RULE_BASE, "warn": false}]
	if diff == &"easy":
		out.append({"text": RULE_EASY, "warn": true})
	if mode == &"endless":
		out.append({"text": RULE_ENDLESS, "warn": true})
	return out


## 0-99 Türkçe okunuş (TalkBack): 25 -> "yirmi beş".
static func spoken(n: int) -> String:
	if n <= 0:
		return "sıfır"
	if n >= 100:
		return str(n)
	return (TENS[floori(n / 10.0)] + " " + ONES[n % 10]).strip_edges()


static func _minutes_spoken(mode: StringName, cfg: Dictionary) -> String:
	var mins := minutes(mode, cfg)
	return "" if mins < 0 else "%s dakika" % spoken(mins)


static func strip_a11y(mode: StringName, diff: StringName, cfg: Dictionary) -> String:
	var m: String = MODE_TITLES.get(mode, "")
	var span := _minutes_spoken(mode, cfg)
	return (
		"Koşu: %s%s. Zorluk: %s. Değiştirmek için çift dokun."
		% [m, ", " + span if span != "" else "", DIFF_TITLES.get(diff, "")]
	)


static func mode_a11y(mode: StringName, cfg: Dictionary, selected: bool) -> String:
	var state := "seçili" if selected else "seçili değil"
	var mins := minutes(mode, cfg)
	if mins == NO_DATA:
		return "%s mod, %s" % [MODE_TITLES.get(mode, ""), state]
	if mins < 0:
		return (
			"%s mod, Lord devrilince koşu sürer, ölene kadar, %s"
			% [MODE_TITLES.get(mode, ""), state]
		)
	return (
		"%s mod, %s dakika, Lord %s dakikada gelir, %s"
		% [MODE_TITLES.get(mode, ""), spoken(mins), spoken(mins), state]
	)


static func diff_a11y(diff: StringName, selected: bool) -> String:
	return (
		"%s zorluk, %s kalkan üç üzerinden, %s, %s"
		% [
			DIFF_TITLES.get(diff, ""),
			spoken(int(SHIELDS.get(diff, 0))),
			DIFF_SPOKEN.get(diff, ""),
			"seçili" if selected else "seçili değil",
		]
	)


static func detail_a11y(diff: StringName, cfg: Dictionary) -> String:
	var parts := PackedStringArray()
	var d: Dictionary = cfg.get("difficulties", {}).get(String(diff), {})
	for r in DETAIL_ROWS:
		var pct := roundi((float(d.get(r[1], 1.0)) - 1.0) * 100.0)
		var what: String = DETAIL_SPOKEN[r[1]]
		if pct == 0:
			parts.append("%s %s" % [what, "aynı" if r[1] == "xp" else "tam"])
		else:
			parts.append("%s yüzde %s %s" % [what, spoken(absi(pct)), "fazla" if pct > 0 else "az"])
	return "%s zorluk ayrıntıları: %s." % [DIFF_TITLES.get(diff, ""), ", ".join(parts)]


# --- bilgi çipi (duraklatma; sonuç ekranı U4b'de aynı bileşeni kullanır) ------------------------------------------


## Kare köşeli bilgi çipi (DESIGN §5): 3 px bronz_500 kenar, void α0,5 dolgu; dokunma almaz.
static func make_chip(glyph: Control, text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiKit.stylebox(Color(UiKit.VOID, 0.5), UiKit.BRONZ_500, 3, 0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override(&"panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override(&"separation", 12)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(glyph)
	var l := UiKit.label(text, &"", 28, UiKit.KEMIK_100)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	chip.add_child(h)
	return chip


## Mod çipi + zorluk çipi yan yana (HBox, ortalı). Çipler salt bilgidir.
static func make_chips(mode: StringName, diff: StringName, cfg: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "RunChips"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 16)
	var mode_chip := make_chip(ModeGlyph.new(mode, UiKit.BRONZ_300, 36.0), title_text(mode, cfg))
	mode_chip.name = "ModeChip"
	var span := _minutes_spoken(mode, cfg)
	mode_chip.accessibility_name = (
		"Mod: %s%s." % [MODE_TITLES.get(mode, ""), ", " + span if span != "" else ""]
	)
	row.add_child(mode_chip)
	var diff_chip := make_chip(
		Shields.new(int(SHIELDS.get(diff, 0)), UiKit.BRONZ_300, Vector2(63, 21)),
		DIFF_NAMES.get(diff, "")
	)
	diff_chip.name = "DiffChip"
	diff_chip.accessibility_name = "Zorluk: %s." % DIFF_TITLES.get(diff, "")
	row.add_child(diff_chip)
	return row
