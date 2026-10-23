class_name JoystickView
extends Control
## Sanal joystick: YALNIZ InputGate çıktısını gösterir (karar vermez, girdi okumaz).
## Dokunulan yerde belirir: taban 300 px (%28 opak), topuz 132 px (%55 opak), topuz yarıçapı 150 px ile sınırlı;
## parmak kalkınca 120 ms'de söner (görünürlük InputGate.visibility()).

const BASE_DIAMETER := 300.0
const KNOB_DIAMETER := 132.0
const BASE_ALPHA := 0.28
const KNOB_ALPHA := 0.55

var base_center: Vector2 = Vector2.ZERO
var knob_center: Vector2 = Vector2.ZERO
var alpha: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(self)


## Taban ve topuz merkezleri (saf): topuz tabandan en çok max_radius uzakta.
static func knob_position(origin: Vector2, finger: Vector2, max_radius: float) -> Vector2:
	return origin + InputGate.clamp_offset(finger - origin, max_radius)


## InputGate'in durumunu yansıt; değiştiyse yeniden çiz.
func show_state(gate: InputGate) -> void:
	var a := gate.visibility()
	var b := gate.origin
	var k := knob_position(gate.origin, gate.current, InputGate.MAX_RADIUS)
	if is_equal_approx(a, alpha) and b == base_center and k == knob_center:
		return
	alpha = a
	base_center = b
	knob_center = k
	queue_redraw()


func _draw() -> void:
	if alpha <= 0.0:
		return
	var br := BASE_DIAMETER * 0.5
	draw_circle(base_center, br, Color(UiKit.VOID, BASE_ALPHA * alpha))
	draw_arc(base_center, br, 0.0, TAU, 64, Color(UiKit.BRONZ_500, 0.8 * alpha), 4.0, true)
	draw_circle(knob_center, KNOB_DIAMETER * 0.5, Color(UiKit.KEMIK_300, KNOB_ALPHA * alpha))
	draw_arc(
		knob_center,
		KNOB_DIAMETER * 0.5,
		0.0,
		TAU,
		48,
		Color(UiKit.KEMIK_100, 0.6 * alpha),
		3.0,
		true
	)
