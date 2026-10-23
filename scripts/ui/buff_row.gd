class_name BuffRow
extends Control
## Süreli etki rozetleri (sol alt; en çok 3: Hasar, Hız, Sınırsız): rozet x = 231 + n·120, 108 px daire, yay + ikon + kalan sn.
## DESIGN §2.4. Rozet sırası etki türü sırasıdır (Hasar, Hız, Sınırsız); biten rozet 220 ms'de küçülüp solar ve kalanlar
## 180 ms'de sola kayar. Yeni/yenilenen etki rozeti pop yapar (1 → 1,15). Gizli doğar; `bind` görünür yapar.

const BADGE := 108.0
const STEP_X := 120.0
const FIRST_X := 231.0
const RING_W := 8.0
const RING_W_LOW := 5.0
const ICON_PX := 46.0
const SECS_SIZE := 26
const LOW_SEC := 3.0
const BLINK_HZ := 2.5
const BLINK_LOW := 0.55
const CLOSE_TIME := 0.22
const SLIDE_TIME := 0.18
const POP_TIME := 0.18
const POP_PEAK := 1.15
const KIND_RARITY := [&"uncommon", &"uncommon", &"rare"]

var _sim: GameSim = null
var _t: float = 0.0
var _icons: Array[Texture2D] = [null, null, null]
# Etki türü başına görünüm durumu.
var _x := PackedFloat32Array([FIRST_X, FIRST_X, FIRST_X])
var _target_x := PackedFloat32Array([FIRST_X, FIRST_X, FIRST_X])
var _shown := PackedByteArray([0, 0, 0])
var _close := PackedFloat32Array([0.0, 0.0, 0.0])
var _pop := PackedFloat32Array([0.0, 0.0, 0.0])
var _last_left := PackedInt32Array([0, 0, 0])
var _last_left_steps := PackedInt32Array([0, 0, 0])


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(sim: GameSim) -> void:
	_sim = sim
	visible = sim != null
	for k in BuffManager.COUNT:
		_shown[k] = 0
		_close[k] = 0.0
		_pop[k] = 0.0
		_last_left_steps[k] = 0
		_x[k] = FIRST_X
		_target_x[k] = FIRST_X
		_icons[k] = null
	if sim != null:
		for id in sim.data.pickup_ids:
			var def := sim.data.get_pickup(id)
			if def.effect == &"buff":
				var k := BuffManager.kind_of(String(def.buff))
				if k >= 0:
					_icons[k] = ArtLoader.texture(def.icon)
	queue_redraw()


func refresh(dt: float) -> void:
	if not visible or _sim == null:
		return
	_t += dt
	var n := 0
	for k in BuffManager.COUNT:
		var left := _sim.buffs.left_steps[k]
		if left > 0:
			_target_x[k] = badge_x(n)
			if _shown[k] == 0:
				_x[k] = _target_x[k]
				_pop[k] = POP_TIME
			elif left > _last_left_steps[k]:
				_pop[k] = POP_TIME  # yenileme
			_shown[k] = 1
			_close[k] = 0.0
			n += 1
		elif _shown[k] == 1:
			_shown[k] = 0
			_close[k] = CLOSE_TIME
		_last_left_steps[k] = left
		_pop[k] = maxf(0.0, _pop[k] - dt)
		_close[k] = maxf(0.0, _close[k] - dt)
		if dt > 0.0:
			_x[k] = move_toward(_x[k], _target_x[k], STEP_X / SLIDE_TIME * dt)
		else:
			_x[k] = _target_x[k]
	queue_redraw()


## Görünür (açık ya da kapanmakta) rozet sayısı.
func badge_count() -> int:
	var c := 0
	for k in BuffManager.COUNT:
		if _shown[k] == 1 or _close[k] > 0.0:
			c += 1
	return c


## n. rozetin sol x'i: 231 + n × 120.
static func badge_x(n: int) -> float:
	return FIRST_X + float(n) * STEP_X


## ceil(left_steps / 60) metni.
static func seconds_text(left_steps: int) -> String:
	return str(ceili(float(maxi(left_steps, 0)) / 60.0))


## Son 3 sn: rozet yanıp söner.
static func blinking(left_s: float) -> bool:
	return left_s <= LOW_SEC


func _draw() -> void:
	if _sim == null:
		return
	for k in BuffManager.COUNT:
		var closing := _close[k] > 0.0 and _shown[k] == 0
		if _shown[k] == 0 and not closing:
			continue
		var scale_k := 1.0
		var alpha := 1.0
		if closing:
			var u := 1.0 - _close[k] / CLOSE_TIME
			scale_k = lerpf(1.0, 0.6, u)
			alpha = 1.0 - u
		elif _pop[k] > 0.0:
			scale_k = lerpf(1.0, POP_PEAK, sin(PI * (1.0 - _pop[k] / POP_TIME)))
		var left_steps: int = _sim.buffs.left_steps[k]
		var low := not closing and blinking(float(left_steps) / 60.0)
		if low:
			alpha *= lerpf(BLINK_LOW, 1.0, 0.5 + 0.5 * sin(TAU * BLINK_HZ * _t))
		_draw_badge(k, _x[k], scale_k, alpha, low, left_steps)


func _draw_badge(k: int, x: float, s: float, a: float, low: bool, left_steps: int) -> void:
	var c := Vector2(x + BADGE * 0.5, BADGE * 0.5)
	var r := BADGE * 0.5 * s
	var rarity: StringName = KIND_RARITY[k]
	var col := PickupRenderer.rarity_color(rarity)
	var ring := RING_W_LOW if low else RING_W
	draw_circle(c, r, Color(UiKit.MOR_900, a))
	draw_arc(c, r - ring * 0.5, 0.0, TAU, 48, Color(UiKit.MERMI_BOS, a), ring, true)
	var ratio := _sim.buffs.ratio(k)
	if ratio > 0.0:
		var a0 := -PI * 0.5 + TAU * (1.0 - ratio)  # saat yönünde azalan
		draw_arc(c, r - ring * 0.5, a0, -PI * 0.5 + TAU, 48, Color(col, a), ring, true)
	draw_arc(c, r - ring - 1.5, 0.0, TAU, 48, Color(UiKit.BORDO_900, a), 3.0, true)
	var tex: Texture2D = _icons[k]
	if tex != null:
		var h := ICON_PX * 0.5 * s
		draw_texture_rect(
			tex, Rect2(c + Vector2(-h, -h - 8.0 * s), Vector2(h, h) * 2.0), false, Color(1, 1, 1, a)
		)
	var f := UiKit.font_semibold()
	var fs := roundi(float(SECS_SIZE) * s)
	var txt := seconds_text(left_steps) if left_steps > 0 else ""
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := c + Vector2(-tw * 0.5, r * 0.62)
	draw_string(
		f, tp + Vector2(0.0, 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8 * a)
	)
	draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiKit.KEMIK_100, a))
