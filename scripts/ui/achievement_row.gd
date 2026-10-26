class_name AchievementRow
extends Button
## Başarım ailesi satırı (DESIGN v2.0.3 §4.2-4.3): kapalıyken 936×150 (plaka · ad · sonraki hedef · değer/hedef + segmentli çubuk),
## açıkken tek nesne büyür ve kademe yolunu gösterir (zincirli mühürler). Kayıt yazmaz; ilerleme `AchievementProgress.of`.
## Dokunma `pressed` ile gelir (ekran açma/kapamayı yönetir); sürükleme ScrollContainer'a gider.

const HEAD_H := 150.0
const STEP_H := 72.0
const PATH_PAD_TOP := 8.0
const PATH_PAD_BOTTOM := 20.0
const COL_W := 232.0
const GOAL_TEXT := {
	"run_time": "%s dakika hayatta kal",
	"run_clean_secs": "%s dakika hasar almadan kal",
	"total_play_secs": "%s saat oyna",
	"run_kills": "Tek koşuda %s düşman öldür",
	"total_kills": "Toplam %s düşman öldür",
	"run_unlimited_kills": "Sonsuz Tambur'da %s düşman öldür",
	"run_bomb_hits": "Tek bombayla %s düşman vur",
	"total_boss_kills": "%s elit boss öldür",
	"run_elite_kinds": "%s elit türünü de öldür",
	"total_wins": "Kale Lordu'nu %s kez devir",
	"run_level": "%s. seviyeye ulaş",
	"run_evolutions": "%s evrim kazan",
	"run_reloads": "Tek koşuda %s kez doldur",
	"run_best_mult": "SERİ çarpanını ×%s yap",
	"run_score": "Tek koşuda %s skor yap",
	"run_pickups": "Tek koşuda %s eklenti topla",
	"run_active_slots": "%s aktif yuvayı doldur",
	"total_runs": "%s koşu oyna",
	"total_chars5": "%s karakterle 5 dakika hayatta kal",
}

var def: AchievementDef = null
var is_open: bool = false
var step_have: int = 0
var step_total: int = 0
var value: int = 0
var plate: AchievementPlate
var name_label: Label
var goal_label: Label
var value_label: Label
var segments: Segments = null
var done_chip: Label = null
var path_rows: Array[Control] = []

var _w: float = 936.0


## n parçalı çubuk: `fills[i]` 0..1, `colors[i]` parça rengi (geçilen kademe rengi); boş parça kemik çizgili.
class Segments:
	extends Control
	var fills: Array[float] = []
	var colors: Array[Color] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := fills.size()
		if n == 0:
			return
		var gap := 6.0
		var sw := (size.x - gap * float(n - 1)) / float(n)
		for i in n:
			var r := Rect2(float(i) * (sw + gap), 0.0, sw, size.y)
			draw_style_box(UiKit.stylebox(UiKit.VOID, Color(0, 0, 0, 0), 0, 7), r)
			if fills[i] > 0.0:
				var fr := Rect2(r.position, Vector2(maxf(sw * fills[i], 14.0), r.size.y))
				draw_style_box(UiKit.stylebox(colors[i], Color(0, 0, 0, 0), 0, 7), fr)


## Kademe yolundaki mühür: 0 gelecek (sönük halka), 1 aktif (halka + nokta), 2 açık (amber dolu + ✓).
class Seal:
	extends Control
	var state: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(44.0, 44.0)
		size = Vector2(44.0, 44.0)

	func _draw() -> void:
		var c := size * 0.5
		match state:
			2:
				draw_circle(c, 22.0, UiKit.AMBER)
				var pts := PackedVector2Array([Vector2(11, 23), Vector2(19, 31), Vector2(33, 14)])
				draw_polyline(pts, UiKit.VOID, 4.0, true)
			1:
				draw_arc(c, 20.0, 0.0, TAU, 28, UiKit.BRONZ_300, 4.0, true)
				draw_circle(c, 8.0, UiKit.AMBER)
			_:
				draw_arc(c, 20.0, 0.0, TAU, 28, UiKit.KAHVE_500, 4.0, true)


## Kilit rozeti (kilitli aile).
class LockBadge:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := size.x * 0.5
		draw_circle(c, s, Color(UiKit.VOID, 0.85))
		draw_rect(Rect2(c.x - s * 0.45, c.y - s * 0.05, s * 0.9, s * 0.65), UiKit.KEMIK_300)
		draw_arc(c + Vector2(0, -s * 0.05), s * 0.32, PI, TAU, 14, UiKit.KEMIK_300, 3.0, true)


## "%s" yerine eşik: süre stat'ları saniyeden dakika/saate çevrilir; bilinmeyen stat "Hedef N".
static func goal_text(d: AchievementDef, target: int) -> String:
	var n := target
	match String(d.stat):
		"run_time", "run_clean_secs":
			n = target / 60
		"total_play_secs":
			n = target / 3600
	var tpl: String = GOAL_TEXT.get(String(d.stat), "Hedef %s")
	return tpl % UiKit.format_thousands(n)


## Satır yüksekliği: açıkken kademe yolu eklenir.
static func height_for(d: AchievementDef, open: bool) -> float:
	if not open:
		return HEAD_H
	return HEAD_H + PATH_PAD_TOP + float(AchievementStep.total(d)) * STEP_H + PATH_PAD_BOTTOM


func setup(p_def: AchievementDef, store: AchievementStore, w: float, open: bool, bias: int) -> void:
	def = p_def
	_w = w
	is_open = open
	name = "Row_%s" % def.id
	set_meta(&"id", def.id)
	flat = false
	mouse_filter = Control.MOUSE_FILTER_PASS  # sürükleme listeye (ScrollContainer) geçsin
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	step_total = AchievementStep.total(def)
	step_have = mini(store.step_count(def.id) if store != null else 0, step_total)
	var prog := AchievementProgress.of(def, store)
	var floor_v := def.thresholds()[step_have - 1] if step_have > 0 else 0
	value = maxi(maxi(prog, 0), floor_v)
	var complete := step_have >= step_total and step_total > 0
	custom_minimum_size = Vector2(w, height_for(def, open))
	size = custom_minimum_size
	var edge := UiKit.KAHVE_500
	if step_have > 0:
		edge = UiKit.BRONZ_700 if step_have < 3 else UiKit.BRONZ_500
	if complete:
		edge = UiKit.BRONZ_500
	var sb := UiKit.stylebox(UiKit.MOR_700 if open else UiKit.MOR_800, edge, 4, 14)
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		add_theme_stylebox_override(st, sb)
	_build_head(store, complete, bias)
	if open:
		_build_path(store, bias)
	accessibility_name = _a11y(complete)


func _build_head(store: AchievementStore, complete: bool, bias: int) -> void:
	plate = AchievementPlate.new()
	plate.position = Vector2(20.0, 7.0)
	plate.set_step(step_have, complete)
	add_child(plate)
	var icon := TextureRect.new()
	icon.texture = UiKit.texture(AchievementIcons.path_for(def))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(20.0 + 12.0, 7.0 + 14.0 + 12.0)
	icon.size = Vector2(84.0, 84.0)
	AchievementIcons.apply_state(icon, step_have == 0)
	if step_have == 0:
		icon.modulate = Color(0.34, 0.30, 0.27)
	add_child(icon)
	if step_have == 0:
		var lock := LockBadge.new()
		lock.position = Vector2(20.0 + 108.0 - 44.0, 7.0 + 14.0 + 108.0 - 44.0)
		lock.size = Vector2(48.0, 48.0)
		add_child(lock)
	else:
		var rn := UiKit.label(AchievementStep.roman(step_have), &"LabelTimer", 24, UiKit.KEMIK_100)
		rn.name = "Roman"
		rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rn.add_theme_stylebox_override(
			&"normal",
			UiKit.stylebox(Color(UiKit.VOID, 0.85), AchievementIcons.step_color(step_have), 2, 10)
		)
		rn.position = Vector2(20.0 + 108.0 - 52.0, 7.0 + 14.0 + 108.0 - 36.0)
		rn.size = Vector2(52.0, 34.0)
		add_child(rn)
	var colx := _w - 20.0 - COL_W
	name_label = UiKit.label(def.display_name, &"LabelTimer", 38, UiKit.KEMIK_100)
	name_label.name = "Name"
	name_label.position = Vector2(156.0, 18.0)
	name_label.size = Vector2(colx - 156.0 - 12.0, 48.0)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	add_child(name_label)
	goal_label = UiKit.label(_goal_line(store, complete, bias), &"", 28, UiKit.KEMIK_300)
	goal_label.name = "Goal"
	goal_label.position = Vector2(156.0, 76.0)
	goal_label.size = Vector2(colx - 156.0 - 12.0, 40.0)
	goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_label.clip_text = true
	add_child(goal_label)
	if complete:
		done_chip = UiKit.label("TAMAM", &"", 26, UiKit.AMBER)
		done_chip.name = "Done"
		done_chip.add_theme_font_override(&"font", UiKit.font_bold())
		done_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		done_chip.add_theme_stylebox_override(
			&"normal", UiKit.stylebox(Color(UiKit.VOID, 0.4), UiKit.AMBER, 3, 17)
		)
		done_chip.position = Vector2(colx + COL_W - 140.0, 24.0)
		done_chip.size = Vector2(140.0, 40.0)
		add_child(done_chip)
	elif not is_open:
		var nxt := AchievementStep.next_target(def, step_have)
		value_label = UiKit.label(
			"%s/%s" % [UiKit.format_thousands(mini(value, nxt)), UiKit.format_thousands(nxt)],
			&"LabelTimer",
			34,
			UiKit.KEMIK_100
		)
		value_label.name = "Progress"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.position = Vector2(colx, 26.0)
		value_label.size = Vector2(COL_W, 44.0)
		add_child(value_label)
	if not is_open:
		segments = Segments.new()
		segments.name = "Segments"
		segments.position = Vector2(colx, 96.0)
		segments.size = Vector2(COL_W, 14.0)
		_fill_segments()
		add_child(segments)
	else:
		var up := UiKit.label("˄", &"LabelTimer", 40, UiKit.BRONZ_300)
		up.name = "Collapse"
		up.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		up.position = Vector2(colx + COL_W - 60.0, 30.0)
		up.size = Vector2(60.0, 48.0)
		add_child(up)


func _fill_segments() -> void:
	var th := def.thresholds()
	for i in th.size():
		var prev := th[i - 1] if i > 0 else 0
		var f := 0.0
		if i < step_have:
			f = 1.0
		elif i == step_have:
			f = clampf(float(value - prev) / float(maxi(th[i] - prev, 1)), 0.0, 1.0)
		segments.fills.append(f)
		segments.colors.append(
			AchievementIcons.step_color(i + 1) if i < step_have else UiKit.BRONZ_500
		)
		if step_have >= th.size():
			segments.colors[i] = UiKit.AMBER
	segments.queue_redraw()


func _goal_line(store: AchievementStore, complete: bool, bias: int) -> String:
	if complete:
		return (
			"Tüm kademeler açıldı. %s"
			% Highscores.format_date(store.step_unix(def.id, step_total), bias)
		)
	return goal_text(def, AchievementStep.next_target(def, step_have))


## Kademe yolu: zincirle bağlı mühürler; açık = tarih, aktif = değer/hedef (amber), gelecek = "Hedef N".
func _build_path(store: AchievementStore, bias: int) -> void:
	var th := def.thresholds()
	var y0 := HEAD_H + PATH_PAD_TOP
	for i in th.size():
		var y := y0 + float(i) * STEP_H
		var seal := Seal.new()
		seal.position = Vector2(34.0, y + (STEP_H - 44.0) * 0.5)
		seal.state = 2 if i < step_have else (1 if i == step_have else 0)
		add_child(seal)
		path_rows.append(seal)
		if i > 0:
			var link := ColorRect.new()
			link.color = UiKit.BRONZ_700 if i <= step_have else UiKit.KAHVE_500
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			link.position = Vector2(34.0 + 20.0, y - (STEP_H - 44.0) * 0.5 - 0.0)
			link.size = Vector2(4.0, STEP_H - 44.0)
			add_child(link)
		var left := UiKit.label(
			"%s · %s" % [AchievementStep.roman(i + 1), goal_text(def, th[i])],
			&"",
			28,
			UiKit.KEMIK_100 if i <= step_have else UiKit.KEMIK_500
		)
		left.name = "StepGoal%d" % (i + 1)
		left.position = Vector2(100.0, y + (STEP_H - 40.0) * 0.5)
		left.size = Vector2(_w - 100.0 - 280.0, 40.0)
		left.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		left.clip_text = true
		add_child(left)
		var right_text := ""
		var right_col := UiKit.KEMIK_500
		if i < step_have:
			right_text = Highscores.format_date(store.step_unix(def.id, i + 1), bias)
			right_col = UiKit.KEMIK_300
		elif i == step_have:
			right_text = (
				"%s / %s"
				% [UiKit.format_thousands(mini(value, th[i])), UiKit.format_thousands(th[i])]
			)
			right_col = UiKit.AMBER
		else:
			right_text = "Hedef %s" % UiKit.format_thousands(th[i])
		var right := UiKit.label(right_text, &"", 28, right_col)
		right.name = "StepValue%d" % (i + 1)
		right.add_theme_font_override(&"font", UiKit.font_bold())
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.position = Vector2(_w - 20.0 - 260.0, y + (STEP_H - 40.0) * 0.5)
		right.size = Vector2(260.0, 40.0)
		add_child(right)


func _a11y(complete: bool) -> String:
	if complete:
		return "%s, tamamlandı" % def.display_name
	var nxt := AchievementStep.next_target(def, step_have)
	return (
		"%s, kademe %d / %d, sonraki hedef %s, %s, %s"
		% [
			def.display_name,
			step_have,
			step_total,
			UiKit.format_thousands(nxt),
			UiKit.format_thousands(value),
			"açık" if is_open else "kapalı"
		]
	)
