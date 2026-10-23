class_name UiKit
extends RefCounted
## UI yardımcıları: token renkleri (docs/ui/tokens.json), tema, yazı tipleri, düğme/etiket kurucuları,
## ikon çözümü ve biçimleyiciler. Metinler zaten büyük harfle yazılır (kodla büyütme yok: Türkçe i/İ).

const THEME_PATH := "res://themes/ashen-bastion-theme.tres"
const ICON_DIR := "res://assets/ui/icons/"
const FRAME_DIR := "res://assets/ui/frames/"
const SAFE_EDGE := 24.0  # U1 güvenli kenar sabiti (tam safe_area U2-11'de)
const SIDE := 36.0

const VOID := Color("#0d0910")
const MOR_900 := Color("#171020")
const MOR_800 := Color("#211832")
const MOR_700 := Color("#2f2342")
const MOR_500 := Color("#4d3a6b")
const BORDO_900 := Color("#2b0e14")
const BORDO_700 := Color("#5c1d26")
const BORDO_500 := Color("#8f2a36")
const BORDO_400 := Color("#b8404a")
const KEMIK_100 := Color("#efe7d6")
const KEMIK_300 := Color("#cfc4ae")
const KEMIK_500 := Color("#a39883")
const KAHVE_900 := Color("#1c1411")
const KAHVE_700 := Color("#2e211c")
const KAHVE_500 := Color("#4a3830")
const BRONZ_700 := Color("#7a6045")
const BRONZ_500 := Color("#a88a5c")
const BRONZ_300 := Color("#d2b47e")
const AMBER := Color("#e8a24a")
const CAN_KRITIK := Color("#e0584f")
const XP := Color("#7c5cc4")
const XP_PARLAK := Color("#a98bef")
const MERMI_BOS := Color("#3a2e28")
const OVERLAY_DIM := Color(0.051, 0.035, 0.063, 0.8)

static var _theme: Theme = null
static var _tex_cache: Dictionary = {}


static func theme() -> Theme:
	if _theme == null:
		var t: Variant = load(THEME_PATH) if ResourceLoader.exists(THEME_PATH) else null
		_theme = t if t is Theme else Theme.new()
	return _theme


## Tema yazı tipi rolleri: "display" (Cinzel 700), "title" (Cinzel 900), "body" (Inter 400).
static func font(role: StringName) -> Font:
	var t := theme()
	match role:
		&"title":
			return t.get_font(&"font", &"LabelTitle")
		&"display":
			return t.get_font(&"font", &"LabelTimer")
	return t.default_font if t.default_font != null else ThemeDB.fallback_font


## Inter 600 (HUD küçük etiket) — temada ayrı tip yok, ext kaynaktan kurulur.
static func font_semibold() -> Font:
	if _tex_cache.has("font_semi"):
		return _tex_cache["font_semi"]
	var base := "res://assets/fonts/inter-latin-600-normal.woff2"
	var ext := "res://assets/fonts/inter-latin-ext-600-normal.woff2"
	var f: Font = font(&"body")
	if ResourceLoader.exists(base) and ResourceLoader.exists(ext):
		var fv := FontVariation.new()
		fv.base_font = load(base)
		fv.fallbacks = [load(ext)]
		f = fv
	_tex_cache["font_semi"] = f
	return f


static func label(
	text: String, variation: StringName = &"", size: int = 0, color: Variant = null
) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override(&"font_size", size)
	if color is Color:
		l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## kind: &"primary" (bordo), &"secondary" (mor), &"danger" (mor zemin + bordo kenar).
static func button(text: String, kind: StringName = &"primary", height: float = 132.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_ALL
	if kind == &"secondary" or kind == &"danger":
		b.theme_type_variation = &"ButtonSecondary"
	if kind == &"danger":
		for st in [&"normal", &"hover", &"pressed"]:
			var sb: Variant = theme().get_stylebox(st, &"ButtonSecondary")
			if sb is StyleBoxFlat:
				var d := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
				d.border_color = BORDO_400
				b.add_theme_stylebox_override(st, d)
	return b


static func stylebox(
	bg: Color, border: Color, border_w: int, radius: int, shadow: bool = false
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.7)
		sb.shadow_size = 14
		sb.shadow_offset = Vector2(0, 8)
	return sb


## Doku yükle (önbellekli); yoksa null.
static func texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Texture2D:
			t = r
	_tex_cache[path] = t
	return t


## HUD ikonu: "hud-can", "hud-duraklat" ...
static func hud_icon(icon_name: String) -> Texture2D:
	return texture(ICON_DIR + icon_name + ".svg")


## Beceri ikonu: tanımdaki `icon` gerçek yol ise o; değilse assets/ui/icons/<id tireli>.svg; yoksa null
## (çağıran yer tutucu şekil çizer).
static func skill_icon(skill_id: StringName, icon_field: String = "") -> Texture2D:
	if icon_field.begins_with("res://"):
		var t := texture(icon_field)
		if t != null:
			return t
	return texture(ICON_DIR + String(skill_id).replace("_", "-") + ".svg")


## Çerçeve: &"active" kare, &"passive" daire, &"evolution" sekizgen.
static func frame(kind: StringName) -> Texture2D:
	match kind:
		&"passive":
			return texture(FRAME_DIR + "cerceve-pasif.svg")
		&"evolution":
			return texture(FRAME_DIR + "cerceve-evrim.svg")
	return texture(FRAME_DIR + "cerceve-aktif.svg")


## Saniye → "MM:SS" (negatif 0'a kırpılır).
static func format_time(seconds: float) -> String:
	var s := maxi(0, int(floorf(seconds)))
	return "%02d:%02d" % [int(s / 60.0), s % 60]


## Binlik ayracı nokta: 1482 → "1.482".
static func format_thousands(n: int) -> String:
	var neg := n < 0
	var digits := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if neg else "") + out


## Ayar anahtarı etiketi: "SES: AÇIK" / "TİTREŞİM: KAPALI" (önceden büyük harf).
static func toggle_text(label_upper: String, on: bool) -> String:
	return "%s: %s" % [label_upper, "AÇIK" if on else "KAPALI"]


## Tam ekran kökü olarak bir Control'ü yay.
static func fill(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## Evrim kombo satırları: [{id, name, pair, icon}] (sonuç ekranı).
static func combo_rows(evolutions: Array, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in evolutions:
		var id := StringName(str(e))
		var title := String(id).replace("_", " ")  # tanım yoksa (U2 evrimleri) okunur kimlik
		var pair := ""
		var icon := ""
		var def: SkillDef = data.get_skill(id) if data != null else null
		if def != null:
			title = def.display_name
			icon = def.icon
			var a := _skill_name(data, StringName(str(def.requires.get("active", ""))))
			var p := _skill_name(data, StringName(str(def.requires.get("passive", ""))))
			if a != "" and p != "":
				pair = "%s + %s" % [a, p]
		out.append({"id": id, "name": title, "pair": pair, "icon": icon})
	return out


static func _skill_name(data: GameData, id: StringName) -> String:
	if id == &"":
		return ""
	var d: SkillDef = data.get_skill(id)
	return d.display_name if d != null else String(id)


## Ortası parlak bronz ayırıcı çizgi.
static func divider() -> Control:
	var tr := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray(
		[Color(UiKit.BRONZ_300, 0.0), Color(UiKit.BRONZ_300, 0.9), Color(UiKit.BRONZ_300, 0.0)]
	)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = Vector2(0, 4)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
