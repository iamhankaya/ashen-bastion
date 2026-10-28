class_name UiKit
extends RefCounted
## UI yardımcıları: token renkleri (docs/ui/tokens.json), tema, yazı tipleri, düğme/etiket kurucuları,
## ikon çözümü ve biçimleyiciler. Sabit metinler büyük harfle yazılır; Cinzel'de küçük harf yoktur (küçük `i` noktasız
## `I` çizilir), bu yüzden veriden gelen (dinamik) adlar Cinzel etiketine `upper_tr` ile Türkçe büyük harfe çevrilerek verilir.

const THEME_PATH := "res://themes/ashen-bastion-theme.tres"
const ICON_DIR := "res://assets/ui/icons/"
const FRAME_DIR := "res://assets/ui/frames/"
const SKIN_DIR := "res://assets/ui/v203/"  # v2.0.3 9-slice SVG yüzeyleri (docs/design/v2.0.3/frames)
const SAFE_EDGE := 36.0  # varsayılan yan/üst boşluk; çentik/yuvarlak köşe safe_extra ile eklenir
const SIDE := 36.0
const DEFAULT_TOP := 96.0  # DESIGN-UI §5: üst 96 / yan 36 / alt 72
const DEFAULT_BOTTOM := 72.0
const SCROLL_AXIS_VERTICAL := 0  # make_scroll ekseni
const SCROLL_AXIS_HORIZONTAL := 1
const SCROLL_AXIS_BOTH := 2

const VOID := Color("#0d0910")
const MOR_900 := Color("#171020")
const MOR_800 := Color("#211832")
const MOR_700 := Color("#2f2342")
const MOR_500 := Color("#4d3a6b")
# v2.0.3 sıcak taş yüzeyler (mor_* yüzeylerin yerine; tokens-v2.0.3.json)
const TAS_900 := Color("#151110")
const TAS_800 := Color("#1F1917")
const TAS_700 := Color("#2D2422")
const TAS_600 := Color("#3B302C")
const DEMIR := Color("#8C8379")
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

## Türkçe büyük harf dönüşümü (ASCII dışı küçük harfler): i→İ, ı→I öncelikli; motorun yerel büyütmesi kullanılmaz.
const UPPER_MAP := {
	0x69: 0x130,  # i → İ
	0x131: 0x49,  # ı → I
	0xE7: 0xC7,  # ç → Ç
	0x11F: 0x11E,  # ğ → Ğ
	0xF6: 0xD6,  # ö → Ö
	0x15F: 0x15E,  # ş → Ş
	0xFC: 0xDC,  # ü → Ü
	0xE2: 0xC2,  # â → Â
	0xEE: 0xCE,  # î → Î
	0xFB: 0xDB,  # û → Û
}

static var _theme: Theme = null
static var _tex_cache: Dictionary = {}


## Doku/yazı tipi önbelleğini boşaltır (test sızıntı koruması: gut_stub_hook).
static func clear_caches() -> void:
	_tex_cache.clear()


## Cihaz güvenli alanının (DisplayServer.get_display_safe_area) varsayılan boşlukların ÖTESİNDE kalan payı,
## görünüm (viewport) pikseli cinsinden: (sol, üst, sağ, alt). Güvenli alan bilinmiyorsa (boş) sıfır.
## win: pencere piksel boyutu; safe: pencere pikselinde güvenli dikdörtgen; view: viewport boyutu.
static func safe_extra(win: Vector2i, safe: Rect2i, view: Vector2) -> Vector4:
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0 or view.x <= 0.0:
		return Vector4.ZERO
	var k := view.x / float(win.x)
	var left := float(safe.position.x) * k
	var top := float(safe.position.y) * k
	var right := float(win.x - safe.end.x) * k
	var bottom := float(win.y - safe.end.y) * k
	return Vector4(
		maxf(0.0, left - SIDE),
		maxf(0.0, top - DEFAULT_TOP),
		maxf(0.0, right - SIDE),
		maxf(0.0, bottom - DEFAULT_BOTTOM)
	)


## Çalışma anı güvenli alan payı (masaüstü/headless'ta sıfır).
static func current_safe_extra(view: Vector2) -> Vector4:
	return safe_extra(DisplayServer.window_get_size(), DisplayServer.get_display_safe_area(), view)


## Türkçe büyük harf: "Barut Kesesi" → "BARUT KESESİ", "Şifa" → "ŞİFA", "mermi" → "MERMİ".
## Karakter adı büyük harfle: `display_upper` varsa o (özel ad, F-029), yoksa upper_tr.
static func character_upper(c: CharacterDef) -> String:
	if c == null:
		return ""
	return c.display_upper if c.display_upper != "" else upper_tr(c.display_name)


static func upper_tr(text: String) -> String:
	var out := ""
	for k in text.length():
		var c := text.unicode_at(k)
		if UPPER_MAP.has(c):
			c = UPPER_MAP[c]
		elif c >= 0x61 and c <= 0x7A:
			c -= 32
		out += char(c)
	return out


## Yazı tiplerinde olmayan simgeler (★ ✓ kupa) çizim ile: Control olarak yerleştirilir, `size` içine sığar.
class Glyph:
	extends Control
	var kind: StringName = &"star"
	var color: Color = UiKit.AMBER

	func _init(
		p_kind: StringName = &"star", p_color: Color = UiKit.AMBER, p_size: float = 48.0
	) -> void:
		kind = p_kind
		color = p_color
		custom_minimum_size = Vector2(p_size, p_size)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		match kind:
			&"star":
				var pts := PackedVector2Array()
				for i in 10:
					var rad := r if i % 2 == 0 else r * 0.42
					pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 10.0) * rad)
				draw_colored_polygon(pts, color)
			&"check":
				var w := maxf(2.0, r * 0.28)
				draw_polyline(
					PackedVector2Array(
						[
							c + Vector2(-r * 0.7, 0.0),
							c + Vector2(-r * 0.2, r * 0.55),
							c + Vector2(r * 0.75, -r * 0.6)
						]
					),
					color,
					w,
					true
				)
			&"gear":
				var cog := PackedVector2Array()
				for i in 24:
					var rad := r if (i / 2) % 2 == 0 else r * 0.78
					cog.append(c + Vector2.from_angle(TAU * i / 24.0) * rad)
				draw_colored_polygon(cog, color)
				draw_circle(c, r * 0.34, UiKit.TAS_800)
			&"speaker", &"speaker_muted":
				var cone := PackedVector2Array(
					[
						c + Vector2(-r * 0.9, -r * 0.3),
						c + Vector2(-r * 0.45, -r * 0.3),
						c + Vector2(r * 0.15, -r * 0.8),
						c + Vector2(r * 0.15, r * 0.8),
						c + Vector2(-r * 0.45, r * 0.3),
						c + Vector2(-r * 0.9, r * 0.3),
					]
				)
				draw_colored_polygon(cone, color)
				var sw := maxf(3.0, r * 0.16)
				if kind == &"speaker":
					draw_arc(c + Vector2(r * 0.1, 0.0), r * 0.55, -0.9, 0.9, 12, color, sw, true)
				else:  # üzeri çizili: kırmızı çarpı (can_kritik)
					var x0 := c + Vector2(r * 0.35, -r * 0.45)
					var x1 := c + Vector2(r * 0.95, r * 0.45)
					draw_line(x0, x1, UiKit.CAN_KRITIK, sw, true)
					draw_line(Vector2(x0.x, x1.y), Vector2(x1.x, x0.y), UiKit.CAN_KRITIK, sw, true)
			&"person":
				draw_circle(c + Vector2(0.0, -r * 0.42), r * 0.34, color)
				var body := PackedVector2Array()
				for i in 13:
					var a := PI + PI * float(i) / 12.0
					body.append(c + Vector2(cos(a) * r * 0.78, r * 0.95 + sin(a) * r * 0.78))
				draw_colored_polygon(body, color)
			&"trophy":
				var cup := PackedVector2Array(
					[
						c + Vector2(-r * 0.6, -r * 0.8),
						c + Vector2(r * 0.6, -r * 0.8),
						c + Vector2(r * 0.45, r * 0.1),
						c + Vector2(r * 0.15, r * 0.35),
						c + Vector2(-r * 0.15, r * 0.35),
						c + Vector2(-r * 0.45, r * 0.1),
					]
				)
				draw_colored_polygon(cup, color)
				var w2 := maxf(2.0, r * 0.16)
				draw_arc(
					c + Vector2(-r * 0.62, -r * 0.45),
					r * 0.3,
					PI * 0.5,
					PI * 1.5,
					12,
					color,
					w2,
					true
				)
				draw_arc(
					c + Vector2(r * 0.62, -r * 0.45),
					r * 0.3,
					-PI * 0.5,
					PI * 0.5,
					12,
					color,
					w2,
					true
				)
				draw_rect(Rect2(c + Vector2(-r * 0.1, r * 0.35), Vector2(r * 0.2, r * 0.3)), color)
				draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.65), Vector2(r * 0.9, r * 0.2)), color)


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


## Inter 700 (HUD etiketleri: SKOR, SERİ) — font_semibold ile aynı kalıp.
static func font_bold() -> Font:
	if _tex_cache.has("font_bold"):
		return _tex_cache["font_bold"]
	var base := "res://assets/fonts/inter-latin-700-normal.woff2"
	var ext := "res://assets/fonts/inter-latin-ext-700-normal.woff2"
	var f: Font = font_semibold()
	if ResourceLoader.exists(base) and ResourceLoader.exists(ext):
		var fv := FontVariation.new()
		fv.base_font = load(base)
		fv.fallbacks = [load(ext)]
		f = fv
	_tex_cache["font_bold"] = f
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


## Tüm ekranlarda ortak GERİ düğmesi (taş levha; denetim v2.0.3-son #1).
static func back_button(height: float = 132.0) -> Button:
	var b := button("GERİ", &"secondary", height)
	b.add_theme_font_size_override(&"font_size", 48)
	for st in [&"normal", &"hover", &"focus"]:
		b.add_theme_stylebox_override(st, skin_box("dugme-dolu"))
	b.add_theme_stylebox_override(&"pressed", skin_box("dugme-basili"))
	b.accessibility_name = "Geri"
	return b


## v2.0.3 9-slice yüzey (levha, dugme-*, lento); doku yoksa düz kutuya düşer (testte içe aktarma beklenmez).
static func skin_box(skin_name: String, margin: int = 40, fallback: Color = KAHVE_900) -> StyleBox:
	var t := texture(SKIN_DIR + skin_name + ".svg")
	if t == null:
		return stylebox(fallback, BRONZ_700, 3, 8)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.5
	sb.content_margin_bottom = margin * 0.5
	return sb


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


## Beceri ikonu: tanımdaki `icon` gerçek yol ise o; değilse assets/ui/icons/<id tireli>.png (yoksa .svg); yoksa null
## (çağıran yer tutucu şekil çizer).
static func skill_icon(skill_id: StringName, icon_field: String = "") -> Texture2D:
	if icon_field.begins_with("res://"):
		var t := texture(icon_field)
		if t != null:
			return t
	var base := ICON_DIR + String(skill_id).replace("_", "-")
	var png := texture(base + ".png")
	return png if png != null else texture(base + ".svg")


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


## F-037: cihazda `emulate_mouse_from_touch` kapalı; ScrollContainer parmak sürüklemesini (InputEventScreenDrag)
## kendiliğinden kaydırmaz. Sürüklemeyi kaydırmaya çevirir. Fare↔dokunma emülasyonu (device -1) atlanır:
## fare sürüklemesini ScrollContainer zaten kaydırır, ikinci kez kaydırmak çift hız yapardı.
static func touch_scroll(sc: ScrollContainer) -> void:
	if sc.has_meta(&"touch_scroll"):
		return  # idempotent: ikinci çağrı sürüklemeyi iki kez kaydırmasın
	sc.set_meta(&"touch_scroll", true)
	sc.gui_input.connect(
		func(ev: InputEvent) -> void:
			if not (ev is InputEventScreenDrag) or ev.device == InputEvent.DEVICE_ID_EMULATION:
				return
			var rel: Vector2 = (ev as InputEventScreenDrag).relative
			if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				sc.scroll_vertical -= int(roundf(rel.y))
			if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				sc.scroll_horizontal -= int(roundf(rel.x))
			sc.accept_event()
	)


## Kaydırma kabının TEK üretim noktası (tools/ci/check_ui_rules.py: başka yerde `ScrollContainer.new()` yasak); `touch_scroll`
## bağlı döner. `axis`: açık eksen(ler), kapalı eksen SCROLL_MODE_DISABLED. `opts` (yoksa Godot varsayılanı kalır):
## name, follow_focus, deadzone (scroll_deadzone), mouse_filter, size_flags_h/_v, custom_min, show_bars (false => SHOW_NEVER).
## 7 mevcut yerin ayarı (R2 geçişi bu tabloya göre; hepsi dikey, "karakter şeridi" yatay):
##   achievements_screen:88 V {name List, mouse_filter STOP, deadzone 12}   characters_screen:153 H {name Strip, show_bars false}
##   highscore_screen:604   V {name ListScroll}                             result_layout:353 V {name ResultScroll, mouse_filter PASS}
##   run_screen:99, settings_screen:142 V {name Scroll}                     settings_screen:339 V {name LicScroll}
## Yerleşim (anchor/offset/fill) ve `visible` çağıranda kalır.
static func make_scroll(axis: int = SCROLL_AXIS_VERTICAL, opts: Dictionary = {}) -> ScrollContainer:
	var sc := ScrollContainer.new()
	var open := ScrollContainer.SCROLL_MODE_AUTO
	if not bool(opts.get("show_bars", true)):
		open = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var off := ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = open if axis != SCROLL_AXIS_VERTICAL else off
	sc.vertical_scroll_mode = open if axis != SCROLL_AXIS_HORIZONTAL else off
	if opts.has("name"):
		sc.name = str(opts["name"])
	if opts.has("follow_focus"):
		sc.follow_focus = bool(opts["follow_focus"])
	if opts.has("deadzone"):
		sc.scroll_deadzone = int(opts["deadzone"])
	if opts.has("mouse_filter"):
		sc.mouse_filter = int(opts["mouse_filter"]) as Control.MouseFilter
	if opts.has("size_flags_h"):
		sc.size_flags_horizontal = int(opts["size_flags_h"]) as Control.SizeFlags
	if opts.has("size_flags_v"):
		sc.size_flags_vertical = int(opts["size_flags_v"]) as Control.SizeFlags
	if opts.has("custom_min"):
		sc.custom_minimum_size = opts["custom_min"]
	touch_scroll(sc)
	return sc


## Tam ekran kökü olarak bir Control'ü yay.
static func fill(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## Evrim kombo satırları: [{id, name, pair, icon}] (sonuç ekranı). `character_id` doluysa adlar ve ikon karaktere göre
## çözülür (`name_for`/`icon_for`); boşsa varsayılan adlar.
static func combo_rows(
	evolutions: Array, data: GameData, character_id: StringName = &""
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in evolutions:
		var id := StringName(str(e))
		var title := String(id).replace("_", " ")  # tanım yoksa (U2 evrimleri) okunur kimlik
		var pair := ""
		var icon := ""
		var def: SkillDef = data.get_skill(id) if data != null else null
		if def != null:
			title = def.name_for(character_id)
			icon = def.icon_for(character_id)
			var a := _skill_name(
				data, StringName(str(def.requires.get("active", ""))), character_id
			)
			var p := _skill_name(
				data, StringName(str(def.requires.get("passive", ""))), character_id
			)
			if a != "" and p != "":
				pair = "%s + %s" % [a, p]
		out.append({"id": id, "name": title, "pair": pair, "icon": icon})
	return out


static func _skill_name(data: GameData, id: StringName, character_id: StringName = &"") -> String:
	if id == &"":
		return ""
	var d: SkillDef = data.get_skill(id)
	return d.name_for(character_id) if d != null else String(id)


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
