class_name MainMenu
extends Control


## Ana sayfa v2.0.3 (docs/design/v2.0.3/DESIGN.md §2): "kapıdan bakış" sahnesi (kemer/kule/sur/sancak/meşale, zemin yaması,
## kül/kor), koşu şeridi (v2.1, 132 px; KOŞU ekranını açar), OYNA (birincil, 180 px), KARAKTERLER | BAŞARIMLAR (dolu), EN İYİ SKORLAR | AYARLAR (hayalet), sürüm satırı.
## Yazı ölçeği (Android erişilebilirlik 2×): > 1,3 iken KARAKTERLER/BAŞARIMLAR ve SKORLAR/AYARLAR tek sütuna düşer,
## düğmeler 168 px olur; hiçbir şey kesilmez. Kaynak: çağıran (Godot yazı ölçeğini kendiliğinden vermez).
func set_font_scale(f: float) -> void:
	_font_scale = f
	if _col == null:
		return
	var stacked := is_stacked()
	run_button.set_big(stacked)
	refresh_run()
	_half_row.vertical = stacked
	_ghost_row.vertical = stacked
	for b in [characters_button, achievements_button, scores_button, settings_button]:
		(b as Button).custom_minimum_size.y = STACK_BTN_H if stacked else 132.0
		_center_glyph(b)
	# Zemin yaması düğme sütununun altına taşmasın (ara denetim #5): sahne sütun üstünde kırpılır.
	_scene.offset_bottom = (STACK_COL_TOP - 8.0 if stacked else 0.0)
	apply_safe_area(_safe_extra)


func is_stacked() -> bool:
	return _font_scale > STACK_FONT_SCALE


## Ses/titreşim anahtarları AYARLAR'a taşındı. `Settings.hareket_azalt` açıkken kül/kor, meşale, sancak ve nefes durur.
## Sürüm etiketine 3 dokunuş: yalnız debug derlemede `debug_stress_requested` (stres koşusu, U1-10).

signal play_requested
signal run_requested
signal scores_requested
signal characters_requested
signal achievements_requested
signal settings_requested
signal debug_stress_requested

const HERO_PATH := "res://assets/gfx/ui/menu/karakter.png"
const SCENE_DIR := "res://assets/gfx/ui/menu/"
const W := 936.0
const HALF_FONT := 32  # KARAKTERLER | BAŞARIMLAR başlığı (Cinzel 700)
const GHOST_FONT := 30  # "EN İYİ SKORLAR" ikonla çakışmadan 454 px düğmeye sığar
const HALF_W := 454.0
const SUB_FONT := 26  # alt satır (seçili karakter adı, açılan/toplam)
const NAME_MAX := 24  # alt satırdaki karakter adı (taşarsa "…")
const DEFAULT_CHARACTER := "Gunslinger"
const DEFAULT_ACH_TOTAL := 53  # yayımlanan kademe toplamı; denetleyici gerçek toplamı yazar
const TAPS_FOR_STRESS := 3
const TAP_WINDOW := 1.2
const STACK_FONT_SCALE := 1.3  # font_scale bunun üstündeyse yarım düğmeler tek sütuna düşer (DESIGN §2, 01d)
const STACK_BTN_H := 168.0
const MINI_PX := 68.0
const MINI_GAP := 40.0  # mini portre ile başlık arası ek sol iç boşluk
const MINI_CROP := Rect2(160.0, 80.0, 704.0, 704.0)  # 1024×1536 portrenin baş-omuz karesi
const STACK_COL_TOP := -1294.0  # şerit 168 + OYNA 180 + 4 × 168 + 6 × 27 + sürüm 40 = 1222 → y 1106 (v2.1 DESIGN §2)
const STACK_HERO_SCALE := 0.5  # tek sütunda karakter 320×466: başlık ile şerit arasında (y 634-1100)
const STACK_HERO_TOP := -566.0
const STACK_HERO_BOTTOM := -100.0
const EMBER_MAX := 36  # tasarım tavanı 40
const FLOOR_RECT := Rect2(40.0, 1322.0, 1000.0, 400.0)

const COL_TOP := -796.0  # düğme sütunu üstü (alttan): y 1604; koşu şeridi 132 + 27 + OYNA (y 1763, değişmez) + 3 satır
const COL_BOTTOM := -72.0  # sürüm satırı alt kenarı y 2328 (alt güvenli alan 72)
const HERO_TOP := -600.0  # karakter 640×932, y 600-1532
const HERO_BOTTOM := 332.0
const HEAD_TOP := 128.0
const TOP_DEFAULT := 96.0

var run_button: RunStrip
var play_button: Button
var scores_button: Button
## KARAKTERLER | BAŞARIMLAR yarım düğmeleri (454×132, OYNA'nın altında); alt satırlar bilgi taşır.
var characters_button: Button
var achievements_button: Button
## AYARLAR: sütunun son satırında, EN İYİ SKORLAR'ın yanında (başparmak bölgesi).
var settings_button: Button
var version_label: Label
var emblem: Emblem
var hero: TextureRect
var embers: CPUParticles2D

var _head: Control
var _col: VBoxContainer
var _scene: Control
var _banners: Array[TextureRect] = []
var _torch: TextureRect
var _ring: AchRing
var _person: UiKit.Glyph
var _mini: TextureRect
var _mini_ring: Control
var _characters_sub: Label
var _achievements_sub: Label
var _char_name: String = DEFAULT_CHARACTER
var _taps: int = 0
var _tap_left: float = 0.0
var _t: float = 0.0
var _font_scale: float = 1.0
var _safe_extra := Vector4.ZERO
var _half_row: BoxContainer
var _ghost_row: BoxContainer


## Prosedürel zemin: void → tas_900 → void dikey geçiş.
class Backdrop:
	extends Control

	func _draw() -> void:
		var steps := 24
		for i in steps:
			var k := float(i) / float(steps - 1)
			var mid := 1.0 - absf(k - 0.5) * 2.0  # 0 uçlarda, 1 ortada
			var c := UiKit.VOID.lerp(UiKit.TAS_900, clampf(mid * 2.2, 0.0, 1.0))
			draw_rect(Rect2(0.0, size.y * i / steps, size.x, size.y / steps + 1.0), c)


## Tambur amblemi (ana görsel dosyası yoksa yedek): bronz çember, 6 hazne, ortada amber kıvılcım.
class Emblem:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_circle(c, r * 1.12, Color(UiKit.VOID, 0.6))
		draw_arc(c, r * 1.12, 0.0, TAU, 96, UiKit.BRONZ_700, 6.0, true)
		draw_circle(c, r, UiKit.KAHVE_700)
		draw_arc(c, r, 0.0, TAU, 96, UiKit.BRONZ_500, 8.0, true)
		for i in 6:
			var p := c + Vector2.from_angle(-PI * 0.5 + TAU * i / 6.0) * r * 0.58
			draw_circle(p, r * 0.22, UiKit.VOID)
			draw_arc(p, r * 0.22, 0.0, TAU, 40, UiKit.BRONZ_300, 5.0, true)
			draw_circle(p, r * 0.1, Color(UiKit.BRONZ_300, 0.85))
		draw_circle(c, r * 0.14, UiKit.BRONZ_700)
		draw_circle(c, r * 0.07, UiKit.AMBER)


## Mini portre bronz halkası (68 px).
class MiniRing:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(68, 68)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(size * 0.5, 31.0, 0.0, TAU, 48, UiKit.BRONZ_500, 5.0, true)


## BAŞARIMLAR ilerleme halkası (68 px): dolu yay amber, kalan bordo_900, ortada yıldız.
class AchRing:
	extends Control
	var frac: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(68, 68)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 29.0, 0.0, TAU, 48, UiKit.BORDO_900, 10.0, true)
		if frac > 0.0:
			draw_arc(c, 29.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, UiKit.AMBER, 10.0, true)
		draw_circle(c, 21.0, UiKit.TAS_700)
		var pts := PackedVector2Array()
		for i in 10:
			var rad := 15.0 if i % 2 == 0 else 6.5
			pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 10.0) * rad)
		draw_colored_polygon(pts, UiKit.BRONZ_300)


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_motion_setting()
	_apply_font_setting()
	var ev := get_node_or_null(^"/root/Events")
	if ev != null:
		ev.settings_changed.connect(_apply_motion_setting)
		ev.settings_changed.connect(_apply_font_setting)


func _build() -> void:
	var bg := Backdrop.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)
	_build_scene()

	var head := VBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.anchor_right = 1.0
	head.offset_top = HEAD_TOP
	head.add_theme_constant_override(&"separation", 0)
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override(&"separation", 26)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.add_child(_ayrac(false))
	var tag := UiKit.label("ASH AND STEEL", &"LabelAccent", 34)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_constant_override(&"shadow_offset_y", 0)
	tag_row.add_child(tag)
	tag_row.add_child(_ayrac(true))
	head.add_child(tag_row)
	var title := UiKit.label("ASHEN\nBASTION", &"LabelTitle", 132)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override(&"line_spacing", -22)
	title.add_theme_constant_override(&"shadow_offset_y", 4)
	head.add_child(title)
	add_child(head)
	_head = head

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 27)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = -W * 0.5
	col.offset_right = W * 0.5
	col.offset_top = COL_TOP
	col.offset_bottom = COL_BOTTOM
	run_button = RunStrip.new()
	run_button.pressed.connect(func() -> void: run_requested.emit())
	col.add_child(run_button)
	refresh_run()
	play_button = UiKit.button("OYNA", &"primary", 180.0)
	play_button.add_theme_font_size_override(&"font_size", 68)
	_skin_button(play_button, "dugme-birincil", 42)
	play_button.pressed.connect(func() -> void: play_requested.emit())
	var crest := TextureRect.new()
	crest.texture = UiKit.texture(UiKit.SKIN_DIR + "oyna-tepe.svg")
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.anchor_left = 0.5
	crest.anchor_right = 0.5
	crest.offset_left = -120.0
	crest.offset_right = 120.0
	crest.offset_top = -24.0
	crest.offset_bottom = 24.0
	play_button.add_child(crest)
	col.add_child(play_button)
	var half := BoxContainer.new()  # tek sütunda `vertical` açılır (HBoxContainer yönü sabittir)
	half.name = "HalfRow"
	half.add_theme_constant_override(&"separation", 27)
	characters_button = _half_button("KARAKTERLER", "CharactersButton")
	characters_button.pressed.connect(func() -> void: characters_requested.emit())
	_person = UiKit.Glyph.new(&"person", UiKit.BRONZ_300, 52.0)
	characters_button.add_child(_glyph_at(_person))
	_mini = TextureRect.new()  # seçili karakterin mini portresi (ara denetim #4); yoksa kişi ikonu
	_mini.name = "MiniPortrait"
	_mini.visible = false
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.custom_minimum_size = Vector2(MINI_PX, MINI_PX)
	_mini.size = _mini.custom_minimum_size
	_mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini.stretch_mode = TextureRect.STRETCH_SCALE
	_mini.material = _circle_mask()
	characters_button.add_child(_glyph_at(_mini))
	_mini_ring = MiniRing.new()  # bronz halka (DESIGN §2 kademe 2)
	_mini_ring.name = "MiniRing"
	_mini_ring.visible = false
	characters_button.add_child(_glyph_at(_mini_ring))
	# Başlık mini portreden ≥16 px uzakta: sol iç boşluk artar (denetim #6).
	for st in [&"normal", &"hover", &"pressed", &"disabled"]:
		(characters_button.get_theme_stylebox(st) as StyleBox).content_margin_left += MINI_GAP
	achievements_button = _half_button("BAŞARIMLAR", "AchievementsButton")
	achievements_button.pressed.connect(func() -> void: achievements_requested.emit())
	_ring = AchRing.new()
	achievements_button.add_child(_glyph_at(_ring))
	half.add_child(characters_button)
	half.add_child(achievements_button)
	col.add_child(half)
	_half_row = half
	var row := BoxContainer.new()
	row.name = "GhostRow"
	row.add_theme_constant_override(&"separation", 27)
	scores_button = _ghost_button("EN İYİ SKORLAR", &"trophy", "ScoresButton")
	scores_button.pressed.connect(func() -> void: scores_requested.emit())
	settings_button = _ghost_button("AYARLAR", &"gear", "SettingsButton")
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	row.add_child(scores_button)
	row.add_child(settings_button)
	col.add_child(row)
	_ghost_row = row
	version_label = UiKit.label(version_text(), &"", 26, UiKit.KEMIK_500)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	version_label.gui_input.connect(_on_version_input)
	col.add_child(version_label)
	add_child(col)
	_col = col
	set_character_name(_char_name)
	set_achievement_count(0, DEFAULT_ACH_TOTAL)


## Sahne katmanları (alttan üste): kapı arkası ışığı, uzak sahne, sancaklar, meşale, zemin yaması, karakter, kül/kor,
## üst/alt vinyet. Hepsi 1080×2400 koordinatında; güvenli alanda yalnız karakter kutusu pay emer.
func _build_scene() -> void:
	_scene = Control.new()
	_scene.name = "Scene"
	_scene.clip_contents = true  # tek sütunda zemin yaması düğmelerin altına taşmaz (denetim v2.0.3-son #3)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_scene)
	add_child(_scene)
	var glow := _tex_rect(
		_radial(Color(UiKit.AMBER, 0.3), Color(UiKit.BORDO_500, 0.0)), Rect2(100, 540, 880, 900)
	)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	_scene.add_child(glow)
	_scene.add_child(_scene_tex("kule.png", Rect2(-90, 610, 330, 0), 0.38))
	_scene.add_child(_scene_tex("sur.png", Rect2(650, 750, 470, 0), 0.32))
	_scene.add_child(_scene_tex("kemer.png", Rect2(184, 640, 712, 0), 0.78))
	_banners.append(_scene_tex("sancak1.png", Rect2(28, 620, 128, 0), 0.9))
	_banners.append(_scene_tex("sancak2.png", Rect2(906, 640, 144, 0), 0.9))
	for b in _banners:
		b.pivot_offset = Vector2(b.size.x * 0.5, 0.0)
		_scene.add_child(b)
	var floor_patch := _scene_tex("zemin-yama.png", FLOOR_RECT, 1.0)
	floor_patch.material = _ellipse_mask()
	_scene.add_child(floor_patch)
	var shadow := _tex_rect(
		_radial(Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.0)), Rect2(240, 1442, 600, 150)
	)
	_scene.add_child(shadow)
	_torch = _scene_tex("mesale.png", Rect2(120, 1476, 130, 0), 1.0)
	_scene.add_child(_torch)

	emblem = Emblem.new()
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.anchor_left = 0.5
	emblem.anchor_right = 0.5
	emblem.anchor_top = 0.5
	emblem.anchor_bottom = 0.5
	emblem.offset_left = -330.0
	emblem.offset_right = 330.0
	emblem.offset_top = -380.0
	emblem.offset_bottom = 280.0
	add_child(emblem)
	var hero_tex := ArtLoader.texture(HERO_PATH)
	if hero_tex != null:
		emblem.visible = false
		hero = TextureRect.new()
		hero.name = "Hero"
		hero.texture = hero_tex
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.anchor_left = 0.5
		hero.anchor_right = 0.5
		hero.anchor_top = 0.5
		hero.anchor_bottom = 0.5
		hero.offset_left = -320.0
		hero.offset_right = 320.0
		hero.offset_top = HERO_TOP
		hero.offset_bottom = HERO_BOTTOM
		add_child(hero)

	embers = CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = EMBER_MAX
	embers.lifetime = 4.0
	embers.preprocess = 4.0
	embers.position = Vector2(540.0, 1500.0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(460.0, 40.0)
	embers.direction = Vector2(0.15, -1.0)
	embers.spread = 20.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 90.0
	embers.initial_velocity_max = 170.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.5
	embers.color = Color(UiKit.AMBER, 0.6)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	embers.color_ramp = fade
	add_child(embers)

	var top := _tex_rect(_vfade(UiKit.VOID, Color(UiKit.VOID, 0.0)), Rect2(0, 0, 1080, 560))
	add_child(top)
	var bottom := _tex_rect(_vfade(Color(UiKit.VOID, 0.0), UiKit.VOID), Rect2(0, 1622, 1080, 778))
	add_child(bottom)


func _tex_rect(tex: Texture2D, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = r.position
	t.size = r.size
	return t


## Sahne dokusu: genişlik verilir; yükseklik 0 ise en-boy oranından hesaplanır.
func _scene_tex(file: String, r: Rect2, alpha: float) -> TextureRect:
	var tex := UiKit.texture(SCENE_DIR + file)
	var rr := r
	if tex != null and rr.size.y <= 0.0:
		rr.size.y = rr.size.x * tex.get_height() / maxf(tex.get_width(), 1.0)
	var t := _tex_rect(tex, rr)
	t.modulate = Color(1, 1, 1, alpha)
	return t


func _radial(inner: Color, outer: Color) -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([inner, outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _vfade(from: Color, to: Color) -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([from, to])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 128
	return t


## Zemin yamasının kenarını eliptik yumuşak maskeler (doku dikdörtgen; sahneye karışır).
func _ellipse_mask() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = (
		"shader_type canvas_item;\n"
		+ "void fragment() { vec2 p = (UV - 0.5) * 2.0; COLOR.a *= smoothstep(1.0, 0.55, length(p)); }"
	)
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Sert kenarlı daire maskesi (mini portre).
func _circle_mask() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = (
		"shader_type canvas_item;\n"
		+ "void fragment() { COLOR.a *= smoothstep(0.5, 0.485, length(UV - 0.5)); }"
	)
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _ayrac(flip: bool) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiKit.texture(UiKit.SKIN_DIR + "ayrac.svg")
	t.custom_minimum_size = Vector2(150, 20)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.flip_h = flip
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Düğmeye 9-slice yüzey: normal/hover/focus = `skin`, basılı = dugme-basili; odakta 6 px bronz kenar çizgisi.
func _skin_button(b: Button, skin: String, margin: int) -> void:
	for st in [&"normal", &"hover", &"disabled"]:
		b.add_theme_stylebox_override(st, UiKit.skin_box(skin, margin, UiKit.TAS_700))
	b.add_theme_stylebox_override(&"pressed", UiKit.skin_box("dugme-basili", margin, UiKit.TAS_800))
	b.add_theme_stylebox_override(&"focus", _focus_box())


func _focus_box() -> StyleBox:
	var f := UiKit.stylebox(Color(0, 0, 0, 0), UiKit.AMBER, 6, 14)
	return f


## Yarım düğme (dolu taş): ikon/halka solda, başlık ortada, alt satır (Inter 600 26 kemik_300) altta.
func _half_button(title: String, node_name: String) -> Button:
	var b := UiKit.button(title, &"secondary")
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = HALF_W
	b.add_theme_font_size_override(&"font_size", HALF_FONT)
	_skin_button(b, "dugme-dolu", 40)
	for st in [&"normal", &"hover", &"pressed", &"disabled"]:
		var sb := b.get_theme_stylebox(st).duplicate() as StyleBox
		sb.content_margin_bottom = 40.0
		b.add_theme_stylebox_override(st, sb)
	var sub := UiKit.label("", &"", SUB_FONT, UiKit.KEMIK_300)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.anchor_top = 1.0
	sub.anchor_bottom = 1.0
	sub.offset_top = -48.0
	sub.offset_bottom = -12.0
	b.add_child(sub)
	return b


func _glyph_at(g: Control) -> Control:
	g.position = Vector2(22.0, 32.0)
	return g


## Yarım düğme ikonu: düğme yüksekliğinde (132 / tek sütunda 168) dikey ortalanır.
func _center_glyph(b: Button) -> void:
	if b != characters_button and b != achievements_button:
		return  # hayalet düğmelerin ikonu `_place_glyph` ile zaten ortalı
	var h := STACK_BTN_H if is_stacked() else 132.0
	for c in b.get_children():
		if c is UiKit.Glyph or c is AchRing or c.name == "MiniPortrait" or c.name == "MiniRing":
			var g := c as Control
			g.position.y = (h - g.size.y) * 0.5


## Hayalet düğme (dolgusuz, bronz kenar): ikon 48 + Cinzel 32; ikon yazının soluna oturur.
func _ghost_button(title: String, glyph: StringName, node_name: String) -> Button:
	var b := UiKit.button(title, &"secondary")
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = HALF_W
	b.add_theme_font_size_override(&"font_size", GHOST_FONT)
	_skin_button(b, "dugme-hayalet", 40)
	var g := UiKit.Glyph.new(glyph, UiKit.BRONZ_300, 44.0)
	b.add_child(g)
	b.resized.connect(_place_glyph.bind(b, g))
	return b


## KARAKTERLER alt satırı (seçili karakter adı; en çok NAME_MAX harf, taşarsa "…").
func set_character_name(p_name: String) -> void:
	_char_name = p_name
	if characters_button != null:
		_characters_sub = characters_button.get_node("Sub") as Label
		_characters_sub.text = clip_name(p_name)


## KARAKTERLER mini portresi: baş-omuz kırpması; doku yoksa (null) kişi ikonu kalır.
func set_character_portrait(tex: Texture2D) -> void:
	if _mini == null:
		return
	if tex == null or tex.get_width() < MINI_CROP.end.x or tex.get_height() < MINI_CROP.end.y:
		_mini.texture = null
	else:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = MINI_CROP
		_mini.texture = at
	_mini.visible = _mini.texture != null
	_mini_ring.visible = _mini.visible
	_person.visible = not _mini.visible


## BAŞARIMLAR alt satırı: "açılan/toplam" (örn. "8/22") ve ilerleme halkası.
func set_achievement_count(open_count: int, total: int) -> void:
	if achievements_button != null:
		_achievements_sub = achievements_button.get_node("Sub") as Label
		_achievements_sub.text = "%d/%d" % [open_count, total]
		_ring.frac = clampf(float(open_count) / float(maxi(total, 1)), 0.0, 1.0)
		_ring.queue_redraw()


## Tek sürüm kaynağı: project.godot `application/config/version` (karakter adı artık sürüm satırında yok).
static func version_text() -> String:
	return "Sürüm %s" % ProjectSettings.get_setting("application/config/version", "2.1.0")


## En çok NAME_MAX harf (birleştirici işaretler harf sayılmaz ve kendi harfinden ayrılmaz); fazlası "…" ile kesilir.
## Büyük/küçük harf dönüşümü yapılmaz (i/ı olduğu gibi kalır).
static func clip_name(p_name: String) -> String:
	var letters := 0
	for i in p_name.length():
		var c := p_name.unicode_at(i)
		if c >= 0x300 and c <= 0x36F:  # birleştirici işaret: önceki harfe ait
			continue
		letters += 1
		if letters > NAME_MAX:
			return p_name.substr(0, i) + "…"
	return p_name


## İkon düğmenin sol kenarında sabit durur (yazı ortalı; harf aralığı yüzünden ölçüm yerine sabit yerleşim).
func _place_glyph(b: Button, g: Control) -> void:
	g.position = Vector2(20.0, (b.size.y - g.size.y) * 0.5)


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra. Başlık üst paya göre iner,
## düğme sütunu alt paya göre yukarı çıkar (alt >= 72 + extra.w), yan paylarda sütun kayar; karakter kutusu pay emer.
func apply_safe_area(extra: Variant = null) -> void:
	var e := Vector4.ZERO
	if extra is Vector4:
		e = extra
	else:
		e = UiKit.current_safe_extra(Vector2(1080.0, 2400.0))
	if _col == null:
		return
	_safe_extra = e
	var stacked := is_stacked()
	var up := maxf(0.0, (72.0 + e.w) - (-COL_BOTTOM))
	var head_drop := maxf(0.0, e.y - (HEAD_TOP - TOP_DEFAULT))
	var shift := (e.x - e.z) * 0.5
	_head.offset_top = HEAD_TOP + head_drop
	_col.offset_top = (STACK_COL_TOP if stacked else COL_TOP) - up
	_col.offset_bottom = COL_BOTTOM - up
	_col.offset_left = -W * 0.5 + shift
	_col.offset_right = W * 0.5 + shift
	if hero != null:
		# K-01: başlık üst paya göre inince karakterin üstü de aynı farkla iner; alt kenar alt paya göre yukarı çıkar.
		# Tek sütunda karakter %50'ye küçülür (y 634-1100, başlık ile koşu şeridi arasında).
		hero.offset_top = (STACK_HERO_TOP if stacked else HERO_TOP) + head_drop
		hero.offset_bottom = (STACK_HERO_BOTTOM if stacked else HERO_BOTTOM) - up
		hero.offset_left = -320.0 * (STACK_HERO_SCALE if stacked else 1.0)
		hero.offset_right = 320.0 * (STACK_HERO_SCALE if stacked else 1.0)
	emblem.offset_top = -380.0 + head_drop
	emblem.offset_bottom = 280.0 - up


## Koşu şeridini kaydedilmiş (mod, zorluk) seçimine göre yeniler (KOŞU ekranından dönüşte ve açılışta).
func refresh_run() -> void:
	var sel := V21Runs.selection()
	run_button.show_selection(sel["mode"], sel["diff"], V21Runs.profiles())


## Ses/titreşim anahtarları AYARLAR'a taşındı; çağrılar uyumluluk için kalır (menüde gösterilecek durum yok).
func set_settings(_sound: bool, _vib: bool) -> void:
	pass


func open(sound: bool, vib: bool) -> void:
	set_settings(sound, vib)
	refresh_run()
	visible = true
	if RunScreen.should_grab_focus(RunScreen.touch_only()):  # dokunmatikte kalıcı odak çerçevesi yok (#13)
		play_button.grab_focus.call_deferred()


## Hareket azalt: kül/kor görünmez, meşale ve sancak sabit, karakter nefesi durur (DESIGN §6).
func _apply_motion_setting() -> void:
	var reduce := _reduce_motion()
	embers.visible = not reduce
	embers.emitting = not reduce
	if reduce:
		_t = 0.0
		_torch.modulate = Color(1, 1, 1, 0.85)
		for b in _banners:
			b.rotation = 0.0
		if hero != null:
			hero.scale = Vector2.ONE


## Oyun içi BÜYÜK YAZI ayarı yazı ölçeğinin kaynağıdır (ara denetim #1).
func _apply_font_setting() -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st != null:
		set_font_scale(st.font_scale())


func _reduce_motion() -> bool:
	var st := get_node_or_null(^"/root/Settings")
	return st != null and st.hareket_azalt


## Sürüm etiketine dokunuş sayacı (saf mantık): pencere içinde 3. dokunuşta true.
func register_version_tap() -> bool:
	_taps = _taps + 1 if _tap_left > 0.0 else 1
	_tap_left = TAP_WINDOW
	if _taps >= TAPS_FOR_STRESS:
		_taps = 0
		_tap_left = 0.0
		return true
	return false


func _process(delta: float) -> void:
	if _tap_left > 0.0:
		_tap_left = maxf(0.0, _tap_left - delta)
	if not visible or _reduce_motion():
		return
	_t += delta
	_torch.modulate.a = 0.85 + 0.15 * sin(_t * TAU / 2.0)
	for k in _banners.size():
		_banners[k].rotation = deg_to_rad(1.2) * sin(_t * TAU / 3.5 + k)
	if hero != null:
		hero.pivot_offset = Vector2(hero.size.x * 0.5, hero.size.y)
		hero.scale = Vector2.ONE * ShowcaseMotion.scale_at(_t)


func _on_version_input(event: InputEvent) -> void:
	var tap: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tap and register_version_tap() and OS.is_debug_build():
		debug_stress_requested.emit()
