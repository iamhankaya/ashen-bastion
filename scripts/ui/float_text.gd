class_name FloatText
extends Control
## Kayan metin (toplama başlığı): 700 ms, 60 px yükselir, havuz 3. Metin `pickups.json.toast` + `UiKit.upper_tr`.
## Cinzel 44, 3 px gölge. Konum ekran koordinatıdır (çağıran dünya→ekran çevirir). Gizli doğar; `show_text` görünür yapar.

const POOL := 3
const TIME := 0.7
const RISE := 60.0
const FONT_SIZE := 44
const SHADOW := 3.0

var _text: Array[String] = ["", "", ""]
var _pos := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _left := PackedFloat32Array([0.0, 0.0, 0.0])
var _head: int = 0


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_text(text: String, world_to_screen_pos: Vector2) -> void:
	if text == "":
		return
	visible = true
	_text[_head] = UiKit.upper_tr(text)  # idempotent: zaten büyükse değişmez
	_pos[_head] = world_to_screen_pos
	_left[_head] = TIME
	_head = (_head + 1) % POOL
	queue_redraw()


## Etkin (süresi dolmamış) başlık sayısı.
func active_count() -> int:
	var n := 0
	for i in POOL:
		if _left[i] > 0.0:
			n += 1
	return n


## Kalan ilerleme 0..1 (0 = yeni, 1 = bitti); i. yuva etkin değilse 1.
func progress_of(i: int) -> float:
	return 1.0 - clampf(_left[i] / TIME, 0.0, 1.0)


func refresh(dt: float) -> void:
	if not visible:
		return
	var any := false
	for i in POOL:
		if _left[i] > 0.0:
			_left[i] = maxf(0.0, _left[i] - dt)
			any = true
	if any:
		queue_redraw()


func _draw() -> void:
	var f := UiKit.font(&"display")
	var origin := global_position if is_inside_tree() else Vector2.ZERO
	for i in POOL:
		if _left[i] <= 0.0:
			continue
		var u := progress_of(i)
		var p := _pos[i] - origin + Vector2(0.0, -RISE * (1.0 - pow(1.0 - u, 3.0)))
		var a := 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
		var tw := f.get_string_size(_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var tp := p - Vector2(tw * 0.5, 0.0)
		draw_string(
			f,
			tp + Vector2(0.0, SHADOW),
			_text[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			FONT_SIZE,
			Color(0, 0, 0, 0.8 * a)
		)
		draw_string(
			f, tp, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(UiKit.KEMIK_100, a)
		)
