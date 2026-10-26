class_name AchievementChronicle
extends Control
## Kale kroniği şeridi (DESIGN v2.0.3 §4.1): bronz zincir üzerinde 5 grup mührü (84 px) + kısa etiket. Mühür dokunma = gruba kay
## (hedef 187×132). Durum: tamam (amber ✓) · ilerliyor (bronz halka) · hiç yok (sönük). Metin korunur (erişilebilirlik).

signal group_selected(index: int)

const HEIGHT := 150.0
const SEAL := 84.0
const TARGET := Vector2(187.0, 132.0)
const LABELS: PackedStringArray = ["WATCH", "CULLING", "CROWNED", "ARMORY", "ROAD"]

var buttons: Array[Button] = []
var _seals: Array[Seal] = []
var _w: float = 936.0


class Seal:
	extends Control
	var state: int = 0  # 0 hiç yok, 1 ilerliyor, 2 tamam

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		match state:
			2:
				draw_circle(c, r, UiKit.AMBER)
				var k := size.x / 84.0
				var pts := PackedVector2Array(
					[Vector2(24, 44) * k, Vector2(37, 57) * k, Vector2(61, 28) * k]
				)
				draw_polyline(pts, UiKit.VOID, 6.0, true)
			1:
				draw_circle(c, r, UiKit.TAS_800)
				draw_arc(c, r - 3.0, 0.0, TAU, 40, UiKit.BRONZ_300, 6.0, true)
				draw_circle(c, r * 0.28, UiKit.BRONZ_300)
			_:
				draw_circle(c, r, UiKit.TAS_900)
				draw_arc(c, r - 3.0, 0.0, TAU, 40, UiKit.KAHVE_500, 6.0, true)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in LABELS.size():
		var b := Button.new()
		b.name = "Group%d" % i
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = TARGET
		b.size = TARGET
		b.pressed.connect(func() -> void: group_selected.emit(i))
		add_child(b)
		buttons.append(b)
		var seal := Seal.new()
		seal.size = Vector2(SEAL, SEAL)
		seal.position = Vector2((TARGET.x - SEAL) * 0.5, 0.0)
		b.add_child(seal)
		_seals.append(seal)
		var l := UiKit.label(LABELS[i], &"", 26, UiKit.KEMIK_300)
		l.name = "Label"
		l.add_theme_font_override(&"font", UiKit.font_semibold())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0.0, SEAL + 6.0)
		l.size = Vector2(TARGET.x, 36.0)
		b.add_child(l)
	custom_minimum_size = Vector2(0.0, HEIGHT)


## opened[i] / totals[i]: grubun açılan ve toplam kademesi.
func set_state(opened: Array[int], totals: Array[int]) -> void:
	for i in LABELS.size():
		var o := opened[i] if i < opened.size() else 0
		var t := totals[i] if i < totals.size() else 0
		_seals[i].state = 2 if (t > 0 and o >= t) else (1 if o > 0 else 0)
		_seals[i].queue_redraw()
		buttons[i].accessibility_name = "%s, %d / %d" % [AchievementDef.GROUPS[i], o, t]
	queue_redraw()


func layout(w: float) -> void:
	_w = w
	size = Vector2(w, HEIGHT)
	var slot := w / float(LABELS.size())
	for i in LABELS.size():
		buttons[i].position = Vector2(slot * (float(i) + 0.5) - TARGET.x * 0.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var slot := _w / float(LABELS.size())
	var y := SEAL * 0.5
	draw_line(Vector2(slot * 0.5, y), Vector2(_w - slot * 0.5, y), UiKit.BRONZ_700, 6.0)
