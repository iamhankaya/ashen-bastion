class_name SkillSlot
extends Control
## Beceri yuvası (yalnız bilgi; dokunulmaz): çerçeve (aktif kare / pasif daire / evrim sekizgen),
## ikon, sağ altta seviye rozeti. Boş yuva %35 opak. İkon yoksa yer tutucu şekil çizilir.

const EMPTY_ALPHA := 0.35

var kind: StringName = &"active"
var skill_id: StringName = &""
var level: int = 0
var icon: Texture2D = null
var badge_size: float = 26.0

var _shown_kind: StringName = &"active"
var _shown_icon_field: String = ""


func _init(p_kind: StringName = &"active", p_size: float = 78.0) -> void:
	kind = p_kind
	_shown_kind = p_kind
	custom_minimum_size = Vector2(p_size, p_size)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_size = maxf(22.0, p_size * 0.34)


## Boş yuva için skill_id = &"".
func set_skill(id: StringName, lvl: int, icon_field: String = "", evolved: bool = false) -> void:
	var k := &"evolution" if evolved else kind
	if id == skill_id and lvl == level and k == _shown_kind and icon_field == _shown_icon_field:
		return
	_shown_icon_field = icon_field
	skill_id = id
	level = lvl
	_shown_kind = k
	icon = UiKit.skill_icon(id, icon_field) if id != &"" else null
	queue_redraw()


func is_empty() -> bool:
	return skill_id == &""


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var a := EMPTY_ALPHA if is_empty() else 1.0
	var c := r.get_center()
	var k := _shown_kind if not is_empty() else kind
	# zemin
	var bg := Color(UiKit.VOID, 0.75 * a)
	match k:
		&"passive":
			draw_circle(c, size.x * 0.5 - 2.0, bg)
		&"evolution":
			draw_colored_polygon(_octagon(c, size.x * 0.5 - 2.0), Color(UiKit.BORDO_900, a))
		_:
			draw_rect(r.grow(-2.0), bg)
	# çerçeve
	var fr := UiKit.frame(k)
	if fr != null:
		draw_texture_rect(fr, r, false, Color(1, 1, 1, a))
	else:
		var border := UiKit.AMBER if k == &"evolution" else UiKit.BRONZ_500
		match k:
			&"passive":
				draw_arc(c, size.x * 0.5 - 2.0, 0.0, TAU, 40, Color(border, a), 3.0, true)
			_:
				draw_rect(r.grow(-2.0), Color(border, a), false, 3.0)
	# ikon (çerçeve SVG'si dolgulu olduğu için üstüne çizilir)
	if not is_empty():
		var ir := r.grow(-size.x * 0.16)
		if icon != null:
			draw_texture_rect(icon, ir, false)
		else:
			_draw_placeholder(ir)
	# seviye rozeti
	if not is_empty() and level > 0:
		var bc := Vector2(size.x - badge_size * 0.35, size.y - badge_size * 0.35)
		draw_circle(bc, badge_size * 0.5, UiKit.VOID)
		draw_arc(bc, badge_size * 0.5, 0.0, TAU, 24, UiKit.KEMIK_100, 2.0, true)
		var f := UiKit.font_semibold()
		var fs := int(badge_size * 0.72)
		var txt := str(level)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(
			f,
			bc + Vector2(-tw * 0.5, fs * 0.36),
			txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			UiKit.KEMIK_100
		)


func _draw_placeholder(ir: Rect2) -> void:
	# Kimlikten türetilen renkli elmas + baş harf (ikon gelene dek).
	var h := float(absi(hash(String(skill_id))) % 360) / 360.0
	var col := Color.from_hsv(h, 0.35, 0.75)
	var c := ir.get_center()
	var s := ir.size.x * 0.42
	draw_colored_polygon(
		PackedVector2Array(
			[c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]
		),
		col
	)
	var f := UiKit.font(&"display")
	var fs := int(ir.size.x * 0.42)
	var ch := String(skill_id).substr(0, 1)
	if ch == "":
		return
	var tw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(
		f, c + Vector2(-tw * 0.5, fs * 0.35), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.VOID
	)


static func _octagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * r)
	return pts
