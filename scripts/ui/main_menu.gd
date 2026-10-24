class_name MainMenu
extends Control
## Ana menü (docs/ui/mockups/01-ana-menu). Oyun adı, OYNA (birincil, 180 px), Ses/Titreşim anahtarları,
## sürüm etiketi. Ana görsel varsa (assets/gfx/ui/ana_gorsel.png) tambur amblemi yerine o gösterilir.
## Sürüm etiketine 3 dokunuş: yalnız debug derlemede `debug_stress_requested` (stres koşusu, U1-10).

signal play_requested
signal scores_requested
signal characters_requested
signal achievements_requested
signal sound_toggled(on: bool)
signal vibration_toggled(on: bool)
signal debug_stress_requested

const VERSION := "2.0"
const HERO_PATH := "res://assets/gfx/ui/ana_gorsel.png"
const W := 936.0
const TOGGLE_FONT := 36  # "TİTREŞİM: KAPALI" 454 px'e sığar; sütun 936'dan taşmaz (F-ashen-bastion-022)
const TOGGLE_W := 454.0  # iki anahtar eşit genişlikte (etiket uzunluğu yerleşimi kaydırmaz)
const HALF_FONT := 34  # KARAKTERLER | BAŞARIMLAR başlığı (Cinzel 700 34)
const SUB_FONT := 26  # alt satır (seçili karakter adı, açılan/toplam)
const NAME_MAX := 24  # sürüm satırındaki karakter adı (taşarsa "…")
const DEFAULT_CHARACTER := "Gunslinger"
const DEFAULT_ACH_TOTAL := 22
const TAPS_FOR_STRESS := 3
const TAP_WINDOW := 1.2

var play_button: Button
## v1.1: EN İYİ SKORLAR düğmesi (D3-5 kurar; iskelette null).
var scores_button: Button
## v2.0: KARAKTERLER | BAŞARIMLAR yarım düğmeleri (454×132, OYNA'nın altında); alt satırlar bilgi taşır.
var characters_button: Button
var achievements_button: Button
var sound_button: Button
var vibration_button: Button
var version_label: Label
var emblem: Emblem
var hero: TextureRect

const COL_TOP := -844.0  # düğme sütunu üstü (alttan): y 1556 (v1.1: 1715; +159 = bir 132'lik satır + aralık)
const COL_BOTTOM := -120.0
const HERO_TOP := -640.0  # ana görsel kutusu 960x960, y 560-1520 (v1.1: 960x1020, y 660-1680)
const HERO_BOTTOM := 320.0
const HEAD_TOP := 150.0
const TOP_DEFAULT := 96.0

var _head: Control
var _col: VBoxContainer
var _characters_sub: Label
var _achievements_sub: Label
var _char_name: String = DEFAULT_CHARACTER
var _sound_on: bool = true
var _vibration_on: bool = true
var _taps: int = 0
var _tap_left: float = 0.0


## Prosedürel zemin: koyu mor, ortada bordo ışıma, seyrek kül kıvılcımları.
class Backdrop:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.MOR_900)
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		for i in 12:
			var k := 1.0 - float(i) / 12.0
			draw_circle(c, size.x * (0.2 + 0.06 * i), Color(UiKit.BORDO_700, 0.05 * k))
		var rng := RandomNumberGenerator.new()
		rng.seed = 1453
		for i in 70:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var a := rng.randf_range(0.08, 0.4)
			draw_circle(p, rng.randf_range(1.5, 4.0), Color(UiKit.AMBER, a))
		draw_rect(Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color(UiKit.VOID, 0.55))


## Tambur amblemi (şarjör ritmi): bronz çember, 6 hazne, ortada amber kıvılcım.
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


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := Backdrop.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)

	var head := VBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.anchor_right = 1.0
	head.offset_top = HEAD_TOP
	head.add_theme_constant_override(&"separation", 0)
	var tag := UiKit.label("ASH AND STEEL", &"LabelAccent", 36)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_constant_override(&"shadow_offset_y", 0)
	head.add_child(tag)
	var title := UiKit.label("ASHEN\nBASTION", &"LabelTitle", 150)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override(&"line_spacing", -30)
	title.add_theme_constant_override(&"shadow_offset_y", 6)
	head.add_child(title)
	add_child(head)
	_head = head

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
		# Ana görsel (art/ref/ana-gorsel-atis.png, yeşil zemini temizlenmiş): başlık ile düğmeler arasında.
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
		hero.offset_left = -480.0
		hero.offset_right = 480.0
		hero.offset_top = HERO_TOP
		hero.offset_bottom = HERO_BOTTOM
		add_child(hero)

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
	play_button = UiKit.button("OYNA", &"primary", 180.0)
	play_button.add_theme_font_size_override(&"font_size", 64)
	play_button.pressed.connect(func() -> void: play_requested.emit())
	col.add_child(play_button)
	var half := HBoxContainer.new()
	half.name = "HalfRow"
	half.add_theme_constant_override(&"separation", 27)
	characters_button = _half_button("KARAKTERLER", &"person", "CharactersButton")
	characters_button.pressed.connect(func() -> void: characters_requested.emit())
	achievements_button = _half_button("BAŞARIMLAR", &"star", "AchievementsButton")
	achievements_button.pressed.connect(func() -> void: achievements_requested.emit())
	half.add_child(characters_button)
	half.add_child(achievements_button)
	col.add_child(half)
	scores_button = UiKit.button("EN İYİ SKORLAR", &"secondary")
	scores_button.name = "ScoresButton"
	scores_button.pressed.connect(func() -> void: scores_requested.emit())
	scores_button.add_child(UiKit.Glyph.new(&"trophy", UiKit.BRONZ_300, 52.0))
	scores_button.resized.connect(_place_trophy)
	col.add_child(scores_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 27)
	sound_button = UiKit.button("", &"secondary")
	sound_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_button.custom_minimum_size.x = TOGGLE_W
	sound_button.add_theme_font_size_override(&"font_size", TOGGLE_FONT)
	sound_button.pressed.connect(_on_sound)
	vibration_button = UiKit.button("", &"secondary")
	vibration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vibration_button.custom_minimum_size.x = TOGGLE_W
	vibration_button.add_theme_font_size_override(&"font_size", TOGGLE_FONT)
	vibration_button.pressed.connect(_on_vibration)
	row.add_child(sound_button)
	row.add_child(vibration_button)
	col.add_child(row)
	version_label = UiKit.label(version_text(_char_name), &"", 26, UiKit.KEMIK_500)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	version_label.gui_input.connect(_on_version_input)
	col.add_child(version_label)
	add_child(col)
	_col = col
	set_settings(_sound_on, _vibration_on)
	set_character_name(_char_name)
	set_achievement_count(0, DEFAULT_ACH_TOTAL)
	_place_trophy()


## Yarım düğme: ikon (52) solda, başlık ortada, alt satır (Inter 600 26 kemik_300) altta. Yazıyı yukarı almak için stil
## alt kenar boşluğu artırılır (tema stil kutuları kopyalanır).
func _half_button(title: String, glyph: StringName, node_name: String) -> Button:
	var b := UiKit.button(title, &"secondary")
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = TOGGLE_W
	b.add_theme_font_size_override(&"font_size", HALF_FONT)
	for st in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var sb: StyleBox = UiKit.theme().get_stylebox(st, &"ButtonSecondary")
		if sb != null:
			var d := sb.duplicate() as StyleBox
			d.content_margin_bottom = 40.0
			b.add_theme_stylebox_override(st, d)
	var g := UiKit.Glyph.new(glyph, UiKit.BRONZ_300, 52.0)
	g.position = Vector2(22.0, 40.0)
	b.add_child(g)
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


## KARAKTERLER alt satırı ve sürüm etiketi ("Sürüm 2.0 · <ad>"; ad en çok NAME_MAX harf, taşarsa "…").
func set_character_name(p_name: String) -> void:
	_char_name = p_name
	if characters_button != null:
		_characters_sub = characters_button.get_node("Sub") as Label
		_characters_sub.text = clip_name(p_name)
		version_label.text = version_text(p_name)


## BAŞARIMLAR alt satırı: "açılan/toplam" (örn. "8/22").
func set_achievement_count(open_count: int, total: int) -> void:
	if achievements_button != null:
		_achievements_sub = achievements_button.get_node("Sub") as Label
		_achievements_sub.text = "%d/%d" % [open_count, total]


static func version_text(p_name: String) -> String:
	return "Sürüm %s · %s" % [VERSION, clip_name(p_name)]


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


## Kupa ikonu EN İYİ SKORLAR yazısının soluna oturur (yazı ortalı).
func _place_trophy() -> void:
	if scores_button == null or scores_button.get_child_count() == 0:
		return
	var g := scores_button.get_child(0) as Control
	var f := scores_button.get_theme_font(&"font")
	var fs := scores_button.get_theme_font_size(&"font_size")
	var tw := f.get_string_size(scores_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bw := maxf(scores_button.size.x, W)
	g.position = Vector2(
		(bw - tw) * 0.5 - 52.0 - 18.0, (maxf(scores_button.size.y, 132.0) - 52.0) * 0.5
	)


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra. Başlık üst paya göre iner,
## düğme sütunu ve ana görsel alt paya göre yukarı çıkar (alt >= 72 + extra.w).
func apply_safe_area(extra: Variant = null) -> void:
	var e := Vector4.ZERO
	if extra is Vector4:
		e = extra
	else:
		e = UiKit.current_safe_extra(Vector2(1080.0, 2400.0))
	if _col == null:
		return
	var up := maxf(0.0, (72.0 + e.w) - (-COL_BOTTOM))
	var head_drop := maxf(0.0, e.y - (HEAD_TOP - TOP_DEFAULT))
	_head.offset_top = HEAD_TOP + head_drop
	_col.offset_top = COL_TOP - up
	_col.offset_bottom = COL_BOTTOM - up
	if hero != null:
		# K-01: başlık üst paya göre inince görselin üstü de aynı farkla iner (görsel alt kenardan yukarı çıkarken üstten değil alttan küçülür; başlıkla aralık sabit kalır).
		hero.offset_top = HERO_TOP + head_drop
		hero.offset_bottom = HERO_BOTTOM - up
	emblem.offset_top = -380.0 + head_drop
	emblem.offset_bottom = 280.0 - up


func set_settings(sound: bool, vib: bool) -> void:
	_sound_on = sound
	_vibration_on = vib
	if sound_button != null:
		sound_button.text = UiKit.toggle_text("SES", sound)
		vibration_button.text = UiKit.toggle_text("TİTREŞİM", vib)


func open(sound: bool, vib: bool) -> void:
	set_settings(sound, vib)
	visible = true
	play_button.grab_focus.call_deferred()


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


func _on_version_input(event: InputEvent) -> void:
	var tap: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tap and register_version_tap() and OS.is_debug_build():
		debug_stress_requested.emit()


func _on_sound() -> void:
	set_settings(not _sound_on, _vibration_on)
	sound_toggled.emit(_sound_on)


func _on_vibration() -> void:
	set_settings(_sound_on, not _vibration_on)
	vibration_toggled.emit(_vibration_on)
