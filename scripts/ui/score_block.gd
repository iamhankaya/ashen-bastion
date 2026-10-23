class_name ScoreBlock
extends Control
## HUD skor sütunu (sağ 36, üst 284): "SKOR" etiketi, değer (Cinzel 60), SERİ çipi ve kazanç başlığı. Oyun kuralı yok; sim'i okur.
## Düzen (blok yerel y): etiket 0, değer 28, çip 104 (yükseklik 48), kazanç başlığı çipin solunda y 110 (DESIGN §3.2).
## Gösterilen değer gerçeğe 180 ms'de yaklaşır; pop yalnız son pop'tan >= 300 ms ve kazanç >= 50 iken, >= 400 büyük kazanç.
## Gizli doğar (v1 HUD düzeni korunur); `bind` görünür yapar.

const EASE_SEC := 0.18
## Üstel yaklaşma sabiti: 180 ms'de kalan fark < %1 (EASE_SEC / 4,6).
const EASE_TAU := 0.039
const POP_GAIN_MIN := 50
const POP_GAP := 0.3
const BIG_GAIN := 400
const POP_UP := 0.08
const POP_DOWN := 0.16
const POP_SCALE := 1.08
const BIG_POP_SCALE := 1.18
const BIG_GLOW := 0.3
const GAIN_TITLE_SEC := 0.9
const CHIP_POP_SEC := 0.18
const CHIP_POP_SCALE := 1.25
const CHIP_BREAK_SEC := 0.22
const CHIP_BREAK_SCALE := 0.8
const CHIP_BREAK_SHAKE := 4.0
const LABEL_Y := 0.0
const VALUE_Y := 28.0
const CHIP_Y := 104.0
const CHIP_H := 48.0
const CHIP_MIN_W := 160.0
const GAIN_Y := 110.0
const GAIN_W := 220.0
const CHIP_PAD := 16.0
const GAIN_GAP := 12.0  # kazanç başlığı ile SERİ çipi (pop tepesinde de) arasındaki en az boşluk
const BAR_H := 5.0

var label_skor: Label
var value_label: Label
var chip: Chip
var gain_label: Label

var _sim: GameSim = null
var _shown: float = 0.0
var _target: int = 0
var _since_change: float = 1.0
var _since_pop: float = 1.0
var _pop_t: float = 1.0
var _pop_big: bool = false
var _gain_t: float = 1.0
var _chip_mult: int = 1
var _chip_pop_t: float = 1.0
var _chip_break_t: float = 1.0
var _bound: bool = false


## SERİ çipi: kenarlı kutu, "SERİ" + "×N" ve altta kalan süre çubuğu. Yalnız çizer.
class Chip:
	extends Control
	var mult: int = 1
	var fraction: float = 0.0
	var alpha: float = 1.0

	func width_for(mult_n: int) -> float:
		var f_small := UiKit.font_bold()
		var f_big := UiKit.font(&"display")
		var w := (
			f_small.get_string_size("SERİ", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			+ 12.0
			+ f_big.get_string_size("×%d" % mult_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		)
		return maxf(CHIP_MIN_W, w + 2.0 * CHIP_PAD)

	func _draw() -> void:
		var tier := ScoreBlock.tier_of(mult)
		if tier == 0 or size.x <= 0.0:
			return
		var border := ScoreBlock.border_color(tier)
		var sb := UiKit.stylebox(Color(UiKit.VOID, 0.7 * alpha), Color(border, alpha), 3, 10)
		if tier == 3:
			var glow := UiKit.stylebox(
				Color(UiKit.AMBER, 0.0), Color(UiKit.AMBER, 0.25 * alpha), 6, 14
			)
			draw_style_box(glow, Rect2(Vector2(-4, -4), size + Vector2(8, 8)))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f_small := UiKit.font_bold()
		var f_big := UiKit.font(&"display")
		var base := size.y * 0.5
		var x := CHIP_PAD
		draw_string(
			f_small,
			Vector2(x, base + 7.0),
			"SERİ",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			28,
			Color(UiKit.BRONZ_300, alpha)
		)
		x += f_small.get_string_size("SERİ", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 12.0
		draw_string(
			f_big,
			Vector2(x, base + 9.0),
			"×%d" % mult,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			34,
			Color(UiKit.KEMIK_100, alpha)
		)
		var bar_w := (size.x - 12.0) * clampf(fraction, 0.0, 1.0)
		if bar_w > 0.0:
			draw_rect(Rect2(6.0, size.y - 6.0 - BAR_H, bar_w, BAR_H), Color(border, alpha))


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()


func _build() -> void:
	if label_skor != null:
		return
	label_skor = UiKit.label("SKOR", &"", 26, UiKit.BRONZ_300)
	label_skor.add_theme_font_override(&"font", UiKit.font_bold())
	label_skor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_skor.position = Vector2(0, LABEL_Y)
	label_skor.size = Vector2(460, 30)
	add_child(label_skor)
	value_label = UiKit.label("0", &"LabelTimer", 60)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_constant_override(&"shadow_offset_y", 3)
	value_label.position = Vector2(0, VALUE_Y)
	value_label.size = Vector2(460, 76)
	add_child(value_label)
	chip = Chip.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.visible = false
	add_child(chip)
	_layout_chip(2)
	gain_label = UiKit.label("", &"", 28, UiKit.BRONZ_300)
	gain_label.add_theme_font_override(&"font", UiKit.font_bold())
	gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gain_label.size = Vector2(GAIN_W, 36)
	gain_label.visible = false
	add_child(gain_label)
	resized.connect(_layout)
	_layout()


## Sağa hizalı yerleşim: blok genişliği değişirse yeniden hesaplanır.
func _layout() -> void:
	var w := maxf(size.x, 460.0)
	label_skor.size.x = w
	value_label.size.x = w
	value_label.pivot_offset = Vector2(w, 38.0)
	_layout_chip(maxi(_chip_mult, 2))


func _layout_chip(mult_n: int) -> void:
	var w := chip.width_for(mult_n)
	var right := maxf(size.x, 460.0)
	chip.size = Vector2(w, CHIP_H)
	chip.position = Vector2(right - w, CHIP_Y)
	chip.pivot_offset = Vector2(w, CHIP_H * 0.5)
	# sağ pivotlu pop çipi sola büyür: başlık, pop tepesindeki sol kenarın GAIN_GAP gerisinde biter
	if gain_label != null:
		gain_label.position = Vector2(right - w * CHIP_POP_SCALE - GAIN_GAP - GAIN_W, GAIN_Y)


func bind(sim: GameSim) -> void:
	_build()
	if _sim != null and is_instance_valid(_sim.bus):
		if _sim.bus.score_changed.is_connected(_on_score_changed):
			_sim.bus.score_changed.disconnect(_on_score_changed)
		if _sim.bus.streak_changed.is_connected(_on_streak_changed):
			_sim.bus.streak_changed.disconnect(_on_streak_changed)
	_sim = sim
	visible = true
	_bound = _sim != null
	_target = 0
	_shown = 0.0
	_since_change = 1.0
	_since_pop = 1.0
	_pop_t = 1.0
	_gain_t = 1.0
	_chip_mult = _sim.score.mult if _sim != null else 1
	chip.mult = _chip_mult
	_layout_chip(maxi(_chip_mult, 2))
	_chip_pop_t = 1.0
	_chip_break_t = 1.0
	if _sim != null:
		_sim.bus.score_changed.connect(_on_score_changed)
		_sim.bus.streak_changed.connect(_on_streak_changed)
	_apply()


func refresh(dt: float) -> void:
	if not _bound or _sim == null:
		return
	_since_pop += dt
	_pop_t += dt
	_gain_t += dt
	_chip_pop_t += dt
	_chip_break_t += dt
	var t := clampi(_sim.score.total(), 0, _sim.data.score_table.display_cap)
	if t != _target:
		_target = t
		_since_change = 0.0
	else:
		_since_change += dt
	if _since_change >= EASE_SEC:
		_shown = float(_target)
	else:
		_shown = eased(_shown, _target, dt)
	_apply()


## Gösterilen değer hedefe 180 ms'de yaklaşır (dt >= 180 ms: doğrudan hedef).
static func eased(shown: float, target: int, dt: float) -> float:
	if dt >= EASE_SEC:
		return float(target)
	if dt <= 0.0:
		return shown
	return lerpf(shown, float(target), 1.0 - exp(-dt / EASE_TAU))


## gain >= 50 ve son pop'tan >= 0,3 sn.
static func should_pop(gain: int, since_last_pop: float) -> bool:
	return gain >= POP_GAIN_MIN and since_last_pop >= POP_GAP


## gain >= 400.
static func is_big_gain(gain: int) -> bool:
	return gain >= BIG_GAIN


## 0 gizli (x1), 1 x2, 2 x3-x4, 3 x5.
static func tier_of(mult: int) -> int:
	if mult <= 1:
		return 0
	if mult == 2:
		return 1
	if mult <= 4:
		return 2
	return 3


## Çip kenar rengi: x2 kemik, x3-x4 bronz, x5 amber.
static func border_color(tier: int) -> Color:
	match tier:
		1:
			return UiKit.KEMIK_300
		2:
			return UiKit.BRONZ_300
		3:
			return UiKit.AMBER
	return UiKit.BRONZ_500


## UiKit.format_thousands; en çok 99.999.999.
static func format_score(n: int) -> String:
	return UiKit.format_thousands(clampi(n, 0, 99999999))


## Pop ölçeği: 80 ms yukarı (out), 160 ms aşağı; bitince 1.
static func pop_scale(t: float, peak: float) -> float:
	if t < 0.0 or t >= POP_UP + POP_DOWN:
		return 1.0
	if t < POP_UP:
		return lerpf(1.0, peak, 1.0 - pow(1.0 - t / POP_UP, 2.0))
	return lerpf(peak, 1.0, (t - POP_UP) / POP_DOWN)


func _on_score_changed(_score: int, _mult: int, gain: int) -> void:
	if is_big_gain(gain):
		_gain_t = 0.0  # başlık her büyük kazançta; pop yine 300 ms aralık kuralına uyar
		gain_label.text = "+" + format_score(gain)
		if should_pop(gain, _since_pop):
			_pop_t = 0.0
			_pop_big = true
			_since_pop = 0.0
	elif should_pop(gain, _since_pop):
		_pop_t = 0.0
		_pop_big = false
		_since_pop = 0.0


func _on_streak_changed(mult: int, _left: float) -> void:
	if mult > _chip_mult:
		_chip_pop_t = 0.0
	elif mult == 1 and _chip_mult > 1:
		_chip_break_t = 0.0
	if mult > 1:
		chip.mult = mult
		_layout_chip(mult)
	_chip_mult = mult


func _apply() -> void:
	if value_label == null:
		return
	value_label.text = format_score(roundi(_shown))
	var peak := BIG_POP_SCALE if _pop_big else POP_SCALE
	var s := pop_scale(_pop_t, peak)
	value_label.scale = Vector2(s, s)
	var glow := 1.0
	if _pop_big and _pop_t < BIG_GLOW:
		glow = _pop_t / BIG_GLOW
	value_label.add_theme_color_override(
		&"font_color", UiKit.BRONZ_300.lerp(UiKit.KEMIK_100, glow) if _pop_big else UiKit.KEMIK_100
	)
	gain_label.visible = _gain_t < GAIN_TITLE_SEC
	gain_label.modulate.a = clampf(1.0 - _gain_t / GAIN_TITLE_SEC, 0.0, 1.0)
	_apply_chip()


func _apply_chip() -> void:
	var breaking := _chip_break_t < CHIP_BREAK_SEC
	chip.visible = tier_of(_chip_mult) > 0 or breaking
	if _sim != null and _chip_mult > 1:
		var win := float(_sim.data.score_table.window_steps) / float(ScoreTable.STEPS_PER_SEC)
		chip.fraction = _sim.score.streak_left(_sim.step_count) / win
	elif not breaking:
		chip.fraction = 0.0
	var sc := 1.0
	var off := Vector2.ZERO
	chip.alpha = 1.0
	if breaking:
		var k := _chip_break_t / CHIP_BREAK_SEC
		sc = lerpf(1.0, CHIP_BREAK_SCALE, k)
		chip.alpha = 1.0 - k
		off.x = sin(k * TAU * 3.0) * CHIP_BREAK_SHAKE * (1.0 - k)
	elif _chip_pop_t < CHIP_POP_SEC:
		var k2 := _chip_pop_t / CHIP_POP_SEC
		sc = 1.0 + (CHIP_POP_SCALE - 1.0) * (1.0 - absf(2.0 * k2 - 1.0))
	chip.scale = Vector2(sc, sc)
	var right := maxf(size.x, 460.0)
	chip.position = Vector2(right - chip.size.x + off.x, CHIP_Y)
	chip.queue_redraw()
