class_name MagazineDrum
extends Control
## Şarjör tamburu (HUD sol alt, 168 px): cap yuvası çember üzerinde; dolu = bronz, boş = koyu.
## Ortada sayı + "/ cap". Son mermi: sayı amber + 220 ms nabız. Doldurma: sayı yerine amber ↻ (çizim)
## ve dış halka 0→%100 amber ilerler. Durumlar renkten bağımsız (sayı + halka + işaret).

const SIZE := 168.0
const PULSE_TIME := 0.22

var count: int = 6
var cap: int = 6
var reloading: bool = false
var progress: float = 0.0

var _pulse: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Durumu ver; değiştiyse yeniden çiz. Son mermiye inişte nabzı başlatır.
func set_state(p_count: int, p_cap: int, p_reloading: bool, p_progress: float) -> void:
	var prog := snappedf(clampf(p_progress, 0.0, 1.0), 0.01)
	if p_count == count and p_cap == cap and p_reloading == reloading and prog == progress:
		return
	if p_count == 1 and count != 1 and not p_reloading:
		_pulse = PULSE_TIME
	count = p_count
	cap = maxi(1, p_cap)
	reloading = p_reloading
	progress = prog
	queue_redraw()


## Nabız sayacı (HUD her kare çağırır).
func tick(dt: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - dt)
		queue_redraw()


## Ekran okuyucu/test için metin: "Şarjör 4 / 6" ya da "Şarjör dolduruluyor".
@warning_ignore("unused_parameter")
func set_unlimited(on: bool) -> void:
	Stub.todo(&"MagazineDrum.set_unlimited")


func describe() -> String:
	return "Şarjör dolduruluyor" if reloading else "Şarjör %d / %d" % [count, cap]


## i. yuva (0'dan) dolu mu? Yuvalar üstten saat yönünde boşalır.
static func slot_filled(i: int, p_count: int, p_cap: int, p_reloading: bool) -> bool:
	if p_reloading:
		return false
	return i < p_count and i < p_cap


func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.5
	var pulse := 1.0 + 0.06 * sin((1.0 - _pulse / PULSE_TIME) * PI) if _pulse > 0.0 else 1.0
	draw_circle(c, r - 2.0, Color(UiKit.VOID, 0.82))
	draw_arc(c, r - 3.0, 0.0, TAU, 64, UiKit.BRONZ_700, 4.0, true)
	if reloading:
		draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, UiKit.AMBER, 7.0, true)
	# yuvalar
	var slot_r := r * 0.64
	var dot := clampf(r * 0.15 * 6.0 / maxf(cap, 6.0), 7.0, r * 0.15)
	for i in cap:
		var a := -PI * 0.5 + TAU * float(i) / float(cap)
		var p := c + Vector2.from_angle(a) * slot_r * pulse
		var filled := slot_filled(i, count, cap, reloading)
		var col := UiKit.BRONZ_300 if filled else UiKit.MERMI_BOS
		if filled and count == 1:
			col = UiKit.AMBER
		draw_circle(p, dot, col)
		draw_arc(p, dot, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 2.0, true)
	# orta
	if reloading:
		_draw_reload_glyph(c, r * 0.3)
		return
	var f := UiKit.font(&"display")
	var fs := int(r * 0.62)
	var txt := str(count)
	var col_n := UiKit.AMBER if count == 1 else UiKit.KEMIK_100
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-tw * 0.5, fs * 0.2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col_n)
	var f2 := UiKit.font_semibold()
	var fs2 := int(r * 0.24)
	var sub := "/ %d" % cap
	var sw := f2.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	draw_string(
		f2,
		c + Vector2(-sw * 0.5, fs * 0.2 + fs2 * 1.15),
		sub,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs2,
		UiKit.KEMIK_300
	)


## "↻" işareti: açık yay + ok ucu (font glifine bağlı değil).
func _draw_reload_glyph(c: Vector2, rad: float) -> void:
	var a0 := -PI * 0.35
	var a1 := a0 + TAU * 0.8
	draw_arc(c, rad, a0, a1, 32, UiKit.AMBER, 7.0, true)
	var tip := c + Vector2.from_angle(a1) * rad
	var tang := Vector2.from_angle(a1 + PI * 0.5)
	var nrm := Vector2.from_angle(a1)
	draw_colored_polygon(
		PackedVector2Array(
			[tip + tang * 14.0, tip - nrm * 12.0 - tang * 4.0, tip + nrm * 12.0 - tang * 4.0]
		),
		UiKit.AMBER
	)
