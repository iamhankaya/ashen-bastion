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
## U6: içerik bloğu bant içinde dikey ortalanır (en az PAD_MIN üst/alt); 2×'te yazı büyür, bant gerekirse uzar.
const PAD_MIN := 20.0
const TEXT_W := 880.0  # 936 - 2×28 yan pay; sarma genişliği
const BIG_SCALE := 1.3
const SIZES := [54, 32, 28]  # başlık, alt başlık, ipucu
const SIZES_BIG := [64, 44, 40]  # başlık ≈ 16 harf × 64 × 0,8 ≈ 820 < 880: tek satır
const BOX_MIN := [72.0, 44.0, 40.0]
const GAPS := [2.0, 4.0]
const GAPS_BIG := [8.0, 8.0]

var title_label: Label
var sub_label: Label
var hint_label: Label
var left: float = 0.0
var reduce_motion: bool = false
var _t: float = 0.0
var _safe_top: float = 0.0
var _dy: float = 0.0
var _h: float = H
var _big: bool = false


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
	add_child(title_label)
	sub_label = UiKit.label(SUB, &"", 32, UiKit.AMBER)
	sub_label.add_theme_font_override(&"font", UiKit.font_semibold())
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub_label)
	hint_label = UiKit.label("", &"", 28, UiKit.KEMIK_100)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)
	for l in [title_label, sub_label, hint_label]:
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accessibility_name = A11Y
	_relayout()


## TalkBack cümlesi: band + (varsa) tekrar ipucu, süre Türkçe okunuşla ("beş dakika otuz saniye").
static func a11y_text(repeat_sec: float) -> String:
	if repeat_sec <= 0.0:
		return A11Y
	var s := floori(repeat_sec)
	var parts := PackedStringArray()
	if s / 60 > 0:
		parts.append("%s dakika" % RunStrip.spoken(s / 60))
	if s % 60 > 0:
		parts.append("%s saniye" % RunStrip.spoken(s % 60))
	return "%s Lord %s sonra daha güçlü döner." % [A11Y, " ".join(parts)]


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
	accessibility_name = a11y_text(repeat_sec)  # canlı bölge: her gösterimde metin yeniden verilir
	reduce_motion = reduced
	_t = 0.0
	left = SHOW_SEC
	_relayout()
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
	_set_live(false)


## 2× yazı (`f > 1,3`): yazı büyür, bant gerekirse uzar. HUD bantı göstermeden önce çağırır.
func set_font_scale(f: float) -> void:
	_big = f > BIG_SCALE
	_relayout()


func is_big() -> bool:
	return _big


func band_height() -> float:
	return _h


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
	offset_bottom = Y + _safe_top + dy + _h
	_dy = dy


## İçerik bloğunu (başlık, alt başlık, varsa ipucu) bant içinde dikey ortalar; yükseklik = max(204, blok + 2×PAD_MIN).
## Kutu yüksekliği metnin sarılmış ölçüsünden gelir (2×'te kesilme yok).
func _relayout() -> void:
	var sizes: Array = SIZES_BIG if _big else SIZES
	var gaps: Array = GAPS_BIG if _big else GAPS
	var labels: Array[Label] = [title_label, sub_label, hint_label]
	var n := 3 if hint_label.visible else 2
	var boxes: Array[float] = []
	var total := 0.0
	for i in n:
		var l := labels[i]
		l.add_theme_font_size_override(&"font_size", sizes[i])
		var need := l.get_theme_font(&"font").get_multiline_string_size(
			l.text, HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, sizes[i]
		)
		boxes.append(maxf(BOX_MIN[i], ceilf(need.y)))
		total += boxes[i] + (gaps[i - 1] if i > 0 else 0.0)
	_h = maxf(H, total + 2.0 * PAD_MIN)
	var y := (_h - total) * 0.5
	for i in n:
		labels[i].position = Vector2((W - TEXT_W) * 0.5, y)
		labels[i].size = Vector2(TEXT_W, boxes[i])
		y += boxes[i] + (gaps[i] if i < n - 1 else 0.0)
	place(_dy)


func _set_live(on: bool) -> void:
	var mode := DisplayServer.LIVE_POLITE if on else DisplayServer.LIVE_OFF
	if accessibility_live != mode:
		accessibility_live = mode


func _apply() -> void:
	var p := phase(_t, reduce_motion)
	visible = p["visible"]
	_set_live(visible)
	modulate.a = p["alpha"]
	place(p["dy"])
