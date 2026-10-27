class_name MilestoneBand
extends Control
## Sonsuz kilometre taşı bandı (DESIGN v2.1 §6): ilk Lord devrilince üstte 936×204 bant, 3,2 sn. Giriş 220 ms kayma,
## çıkış 400 ms soluma; `hareket_azalt`'ta anlık (görünme süresi aynı). Dokunmayı engellemez, duraklatmaz.
## Zamanı `advance(dt)` sürer (HUD.refresh çağırır; duraklatmada ilerlemez).

const W := 936.0
const H := 204.0
const Y := 300.0
const SHOW_SEC := 3.2
const IN_SEC := 0.22
const OUT_SEC := 0.4
const SLIDE_PX := 60.0
const TITLE := "KALE LORDU DÜŞTÜ"
const SUB := "ZAFER SAYILDI · Koşu sürüyor"
const A11Y := "Kale Lordu düştü. Zafer sayıldı, koşu sürüyor."

var title_label: Label
var sub_label: Label
var hint_label: Label
var left: float = 0.0
var reduce_motion: bool = false
var _t: float = 0.0
var _safe_top: float = 0.0


func _init() -> void:
	name = "MilestoneBand"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		&"panel", UiKit.skin_box("dugme-birincil", 40, UiKit.BORDO_500)
	)
	UiKit.fill(panel)
	add_child(panel)
	title_label = UiKit.label(TITLE, &"LabelTitle", 54, UiKit.KEMIK_100)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0.0, 22.0)
	title_label.size = Vector2(W, 72.0)
	add_child(title_label)
	sub_label = UiKit.label(SUB, &"", 32, UiKit.AMBER)
	sub_label.add_theme_font_override(&"font", UiKit.font_semibold())
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.position = Vector2(0.0, 96.0)
	sub_label.size = Vector2(W, 44.0)
	add_child(sub_label)
	hint_label = UiKit.label("", &"", 28, UiKit.KEMIK_100)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(0.0, 144.0)
	hint_label.size = Vector2(W, 40.0)
	add_child(hint_label)
	accessibility_name = A11Y
	place(0.0)


## "Lord 5:00 sonra daha güçlü döner." (K4); tekrar kapalıysa (≤0) satır boş.
static func hint_text(repeat_sec: float) -> String:
	if repeat_sec <= 0.0:
		return ""
	return "Lord %s sonra daha güçlü döner." % mss(repeat_sec)


## "M:SS" (dakika başında sıfır yok; tasarım metinleri "5:00", "7:48").
static func mss(sec: float) -> String:
	var s := maxi(0, floori(sec))
	return "%d:%02d" % [s / 60, s % 60]


## t sn'deki durum: {"alpha": 0..1, "dy": px (yukarıdan kayma), "visible": bool}. Saf; testler ağaçsız çağırır.
static func phase(t: float, reduced: bool) -> Dictionary:
	if t < 0.0 or t >= SHOW_SEC:
		return {"alpha": 0.0, "dy": 0.0, "visible": false}
	if reduced:
		return {"alpha": 1.0, "dy": 0.0, "visible": true}
	if t < IN_SEC:
		var k := ResultTimeline.cubic_out(t / IN_SEC)
		return {"alpha": k, "dy": (1.0 - k) * -SLIDE_PX, "visible": true}
	var out_at := SHOW_SEC - OUT_SEC
	if t >= out_at:
		return {"alpha": 1.0 - (t - out_at) / OUT_SEC, "dy": 0.0, "visible": true}
	return {"alpha": 1.0, "dy": 0.0, "visible": true}


## Bandı başlatır (yeniden çağrı sayacı sıfırlar).
func show_band(repeat_sec: float, reduced: bool) -> void:
	hint_label.text = hint_text(repeat_sec)
	hint_label.visible = hint_label.text != ""
	reduce_motion = reduced
	_t = 0.0
	left = SHOW_SEC
	_apply()


func advance(dt: float) -> void:
	if left <= 0.0:
		return
	_t += dt
	left = maxf(0.0, SHOW_SEC - _t)
	_apply()


func hide_band() -> void:
	_t = 0.0
	left = 0.0
	visible = false


## Güvenli alan üst payı (HUD ile aynı oranda iner).
func set_safe_top(top: float) -> void:
	_safe_top = top
	place(0.0)


func place(dy: float) -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = Y + _safe_top + dy
	offset_bottom = Y + _safe_top + dy + H


func _apply() -> void:
	var p := phase(_t, reduce_motion)
	visible = p["visible"]
	modulate.a = p["alpha"]
	place(p["dy"])
