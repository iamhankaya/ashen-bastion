class_name AchievementPlate
extends Control
## Aile kademe plakası (DESIGN v2.0.3 §4.2): yapısal silüet kademeyi taşır (renk tek başına değil, gri tonlamada da ayırt edilir).
## 0 kilitli (taş kenar) · I yalın demir · II 4 köşe perçini · III köşebentler · IV bordo plaka + taç + halo.
## İkon ortada 84 px; Roma rozeti sağ altta. Çizim yalnız `_draw`; dokunuşu yutmaz.

const BOX := Vector2(108.0, 122.0)  # taç üstte 14 px taşar
const BODY := Rect2(0.0, 14.0, 108.0, 108.0)

var step: int = 0
var complete: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BOX
	size = BOX


func set_step(p_step: int, p_complete: bool = false) -> void:
	step = clampi(p_step, 0, 4)
	complete = p_complete
	queue_redraw()


func _draw() -> void:
	var body := BODY
	if step == 0:
		_frame(body, UiKit.MOR_800, UiKit.KAHVE_500, 4)
		return
	if step >= 4:
		draw_circle(body.get_center(), 62.0, Color(UiKit.AMBER, 0.14))  # halo
		_frame(body, UiKit.BORDO_700, UiKit.AMBER, 5)
		_brackets(body, UiKit.AMBER)
		_crown()
		return
	var edge := AchievementIcons.step_color(step)
	_frame(body, UiKit.MOR_800, edge, 4)
	if step == 2:
		for p in _corners(body, 12.0):
			draw_circle(p, 5.0, edge)
	elif step == 3:
		_brackets(body, edge)


func _frame(r: Rect2, fill: Color, edge: Color, w: int) -> void:
	draw_style_box(UiKit.stylebox(fill, edge, w, 12), r)


## Dört köşede L biçimli köşebent.
func _brackets(r: Rect2, col: Color) -> void:
	var a := 22.0
	var m := 6.0
	var x0 := r.position.x + m
	var y0 := r.position.y + m
	var x1 := r.end.x - m
	var y1 := r.end.y - m
	draw_polyline(
		PackedVector2Array([Vector2(x0, y0 + a), Vector2(x0, y0), Vector2(x0 + a, y0)]), col, 5.0
	)
	draw_polyline(
		PackedVector2Array([Vector2(x1 - a, y0), Vector2(x1, y0), Vector2(x1, y0 + a)]), col, 5.0
	)
	draw_polyline(
		PackedVector2Array([Vector2(x0, y1 - a), Vector2(x0, y1), Vector2(x0 + a, y1)]), col, 5.0
	)
	draw_polyline(
		PackedVector2Array([Vector2(x1 - a, y1), Vector2(x1, y1), Vector2(x1, y1 - a)]), col, 5.0
	)


func _corners(r: Rect2, inset: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			r.position + Vector2(inset, inset),
			Vector2(r.end.x - inset, r.position.y + inset),
			Vector2(r.position.x + inset, r.end.y - inset),
			r.end - Vector2(inset, inset),
		]
	)


## Üç sivri taç, plakanın üst kenarından 14 px taşar.
func _crown() -> void:
	var cx := BOX.x * 0.5
	var pts := PackedVector2Array(
		[
			Vector2(cx - 26.0, 18.0),
			Vector2(cx - 26.0, 4.0),
			Vector2(cx - 13.0, 12.0),
			Vector2(cx, 0.0),
			Vector2(cx + 13.0, 12.0),
			Vector2(cx + 26.0, 4.0),
			Vector2(cx + 26.0, 18.0),
		]
	)
	draw_colored_polygon(pts, UiKit.AMBER)
