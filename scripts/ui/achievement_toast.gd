class_name AchievementToast
extends Control
## Koşu içi başarım bildirim kutusu (780×120, y 820 + üst güvenli pay). `mouse_filter = IGNORE` (alt düğümler dahil):
## dokunuşu yutmaz, odak almaz. Kural yok; zamanlama `ToastQueue`'dadır (DESIGN §5.2).

const SIZE_PX := Vector2(780.0, 120.0)
const X := 150.0
const Y := 820.0
const ICON_BOX := 84.0

var name_label: Label
var tag_label: Label
var icon_rect: TextureRect
var frame_rect: TextureRect
var tier_marks: TierMarks

var _box: Panel
var _built: bool = false


## Baklavalar (kademe 1–4, etiket satırında sağda).
class TierMarks:
	extends Control
	var count: int = 1
	var color: Color = UiKit.BRONZ_300

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(100.0, 20.0)

	func _draw() -> void:
		for i in 4:
			var c := Vector2(10.0 + 24.0 * float(i), 10.0)
			var pts := PackedVector2Array(
				[c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]
			)
			if i < count:
				draw_colored_polygon(pts, color)
			else:
				pts.append(pts[0])
				draw_polyline(pts, Color(color, 0.5), 2.0)


## Kutunun referans (1080×2400) dikdörtgeni; safe_top = güvenli alan üst payı.
static func rect(safe_top: float) -> Rect2:
	return Rect2(X, Y + safe_top, SIZE_PX.x, SIZE_PX.y)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false


func _ready() -> void:
	theme = UiKit.theme()
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	# Yatayda üst kutunun ortasında, y 820'den (güvenli alan zaten `Safe` düğümü ofsetinde).
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -SIZE_PX.x * 0.5
	offset_right = SIZE_PX.x * 0.5
	offset_top = Y
	offset_bottom = Y + SIZE_PX.y
	custom_minimum_size = SIZE_PX
	_box = Panel.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_box)
	add_child(_box)
	frame_rect = _tex(
		"Frame", Vector2(24.0, (SIZE_PX.y - ICON_BOX) * 0.5), Vector2(ICON_BOX, ICON_BOX)
	)
	frame_rect.texture = UiKit.frame(&"active")
	icon_rect = _tex("Icon", Vector2(24.0 + 14.0, (SIZE_PX.y - 56.0) * 0.5), Vector2(56.0, 56.0))
	tag_label = UiKit.label("BAŞARIM AÇILDI", &"", 26, UiKit.BRONZ_300)
	tag_label.name = "Tag"
	tag_label.add_theme_font_override(&"font", UiKit.font_bold())
	tag_label.position = Vector2(132.0, 16.0)
	tag_label.size = Vector2(440.0, 34.0)
	add_child(tag_label)
	name_label = UiKit.label("", &"LabelTimer", 38, UiKit.KEMIK_100)
	name_label.name = "Name"
	name_label.position = Vector2(132.0, 52.0)
	name_label.size = Vector2(SIZE_PX.x - 132.0 - 24.0, 52.0)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	add_child(name_label)
	tier_marks = TierMarks.new()
	tier_marks.name = "Tier"
	tier_marks.position = Vector2(SIZE_PX.x - 24.0 - 100.0, 20.0)
	add_child(tier_marks)
	_style(&"kolay")


func _tex(n: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.name = n
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = sz
	add_child(t)
	return t


func _style(tier: StringName) -> void:
	var hard := tier == &"zor" or tier == &"cok_zor"
	var sb := UiKit.stylebox(
		Color(UiKit.MOR_800, 0.94), UiKit.AMBER if hard else UiKit.BRONZ_500, 4, 18
	)
	if hard:
		sb.shadow_color = Color(UiKit.AMBER, 0.35)
		sb.shadow_size = 18
	_box.add_theme_stylebox_override(&"panel", sb)


func show_def(def: AchievementDef) -> void:
	_build()
	if def == null:
		visible = false
		return
	var tier_i := maxi(AchievementDef.tier_index(def.tier), 0)
	name_label.text = UiKit.upper_tr(def.display_name)
	icon_rect.texture = UiKit.texture(AchievementIcons.path_for(def))
	var col := AchievementIcons.tier_color(def.tier)
	frame_rect.modulate = col
	tier_marks.count = tier_i + 1
	tier_marks.color = col
	tier_marks.queue_redraw()
	_style(def.tier)
	accessibility_name = "Başarım açıldı: %s" % def.display_name


## Kuyruğun anlık durumunu (kimlik değişimi hariç) çizime uygular: konum kayması + alfa.
func apply_state(q: ToastQueue) -> void:
	_build()
	var oa := q.offset_alpha()
	var shown := q.current() != &""
	visible = shown
	modulate.a = oa.y
	offset_top = Y - oa.x
	offset_bottom = Y - oa.x + SIZE_PX.y
