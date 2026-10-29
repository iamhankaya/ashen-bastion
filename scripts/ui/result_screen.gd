class_name ResultScreen
extends Control
## Oyun Bitti / Kazandın + skor dökümü (DESIGN §3.3–3.4). Blok sırası ve boyları `Y_*` sabitleridir; düğmeler
## max(içerik_alt + 24, 1500) konumundadır. Skor 0→N 900 ms sayar, döküm satırları 300 ms'den 120 ms arayla girer,
## YENİ REKOR damgası 1250 ms'de düşer, düğmeler 1300 ms'de açılır (dokunma = hepsini bitir, düğme en erken 800 ms).
## Veri: run_ended(won, stats) {time, level, kills, evolutions, score, score_parts, best_mult} + Highscores.submit sonucu.

signal replay_requested
signal menu_requested
## Rekor damgası düştü (denetleyici titreşim verir).
signal record_stamped

## Sabitler sahiplerinde (ResultLayout / ResultAnim / ResultModel); public yüzey (rf_api_surface) için burada yeniden verilir.
const W := ResultLayout.W
const MAX_COMBOS := ResultModel.MAX_COMBOS
const EMPTY_TEXT := ResultModel.EMPTY_TEXT
const LOST_SUB := ResultModel.LOST_SUB
const WON_SUB := ResultModel.WON_SUB
const CHIP_MAX_COMBOS := ResultModel.CHIP_MAX_COMBOS
const EASY_NOTE := ResultModel.EASY_NOTE
const DISPLAY_CAP := ResultModel.DISPLAY_CAP

const SIDE_MIN := ResultLayout.SIDE_MIN
const Y_TITLE := ResultLayout.Y_TITLE
const Y_SUB := ResultLayout.Y_SUB
const Y_CHIPS := ResultLayout.Y_CHIPS
const CHIP_ROW_H := ResultLayout.CHIP_ROW_H
const Y_DIV := ResultLayout.Y_DIV
const Y_HERO := ResultLayout.Y_HERO
const Y_HERO_VALUE := ResultLayout.Y_HERO_VALUE
const Y_RECORD := ResultLayout.Y_RECORD
const BAND_H := ResultLayout.BAND_H
const RECORD_BLOCK_H := ResultLayout.RECORD_BLOCK_H
const Y_BREAKDOWN := ResultLayout.Y_BREAKDOWN
const ROW_H := ResultLayout.ROW_H
const BREAKDOWN_PAD := ResultLayout.BREAKDOWN_PAD
const Y_STRIP := ResultLayout.Y_STRIP
const STRIP_H := ResultLayout.STRIP_H
const Y_COMBOS := ResultLayout.Y_COMBOS
const GAP := ResultLayout.GAP
const BUTTONS_MIN_Y := ResultLayout.BUTTONS_MIN_Y
const REPLAY_H := ResultLayout.REPLAY_H
const MENU_H := ResultLayout.MENU_H
const BUTTON_GAP := ResultLayout.BUTTON_GAP
const CHIP_H := ResultLayout.CHIP_H
const NOTE_H := ResultLayout.NOTE_H
const DETAIL_FONT := ResultLayout.DETAIL_FONT
const TOP_DEFAULT := ResultLayout.TOP_DEFAULT
const BOTTOM_DEFAULT := ResultLayout.BOTTOM_DEFAULT
const DESIGN_H := ResultLayout.DESIGN_H
const BIG_SCALE := ResultLayout.BIG_SCALE
const CHIP_WRAP := ResultLayout.CHIP_WRAP
const NOTE_EXTRA := ResultLayout.NOTE_EXTRA

const CHIP_AT := ResultAnim.CHIP_AT
const CHIP_IN := ResultAnim.CHIP_IN
const CHIP_SLIDE := ResultAnim.CHIP_SLIDE
const EMPTY_ROW_ALPHA := ResultAnim.EMPTY_ROW_ALPHA
const STAMP_SEC := ResultAnim.STAMP_SEC
const STAMP_SCALE := ResultAnim.STAMP_SCALE
const SHINE_SEC := ResultAnim.SHINE_SEC
const PILL_SEC := ResultAnim.PILL_SEC
const ROW_SLIDE_PX := ResultAnim.ROW_SLIDE_PX

var won: bool = false
var stats: Dictionary = {}
var last_record: Dictionary = {}
## &"none" | &"record" | &"top10" | &"outside" (test/okuma için).
var record_kind: StringName = &"none"
var title_label: Label
var sub_label: Label
var divider: Control
var score_caption: Label
var score_value: Label
var record_band: Control
var record_label: Label
var record_stars: Array[Control] = []
var record_pill: Label
var record_note: Label
var breakdown_panel: PanelContainer
var breakdown_rows: Array[Control] = []
var strip_panel: PanelContainer
var time_value: Label
var level_value: Label
var kills_value: Label
var combo_panel: PanelContainer
var combo_box: VBoxContainer
var replay_button: Button
var menu_button: Button
var glow: TextureRect
var achievement_chip: Panel
var chip_title: Label
var chip_names: Label
var chip_star: Control
var combo_cv: VBoxContainer
var combo_title: Label
## v2.1 (U4b): koşu çipleri (mod, zorluk, Sonsuz'da LORD ×N) ve Kolay notu. Mod/zorluk sonuç sözlüğünden (stats.mode/diff).
var chip_holder: Control
var easy_note: Panel
var run_mode: StringName = &""
var run_diff: StringName = &""

var _t: float = 0.0
var _skip_t: float = -1.0
var _subtitle: String = ""
var _extra := Vector4.ZERO
var _x0: float = SIDE_MIN
var _w: float = W
var _dy: float = 0.0
var _row_targets: Array[int] = []
var _row_dim: Array[bool] = []
var _row_plus: Array[bool] = []
var _row_dash: Array[bool] = []
var _stamped: bool = false
var _shine: ColorRect
var _strip_nodes: Array[Control] = []
var _hero_total: int = 0
var _combos_data: Array[Dictionary] = []
var _shown_combos: int = MAX_COMBOS
var _new_names: Array[String] = []
var _chip_y: float = Y_COMBOS
var _run_chips: Control = null
var _big: bool = false
## Çip satırı sarınca altındaki blokların kaydığı pay (büyük yazıda CHIP_WRAP + NOTE_EXTRA).
var _bdy: float = 0.0
var _tier: int = 0
var _panel_sb: StyleBox
var _bg: ColorRect
var _scroll: ScrollContainer
var _content: Control


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	ResultBlocks.build(self)


func _draw_band() -> void:
	ResultBlocks.draw_band(record_band)


func _render_combos() -> void:
	ResultBlocks.render_combos(self)


## Sıra satırı: "Normal · Zor listesinde 3. sıra" (Mod · Zorluk); mod/zorluk bilinmiyorsa boş.
static func rank_line(mode: StringName, diff: StringName, rank: int) -> String:
	return ResultModel.rank_line(mode, diff, rank)


## Sonsuz zaferinde alt başlık: "Lord'u devirdin; sonra 7:48 daha dayandın."; kilometre taşı yoksa boş.
static func endless_sub(time: float, milestone_t: float) -> String:
	return ResultModel.endless_sub(time, milestone_t)


## Koşuda açılan başarımların görünen adları; `show_result`'tan ÖNCE çağrılır. Boş => v1.1 düzeni aynen.
## Çip: "YENİ BAŞARIM · N" + ilk iki ad ("+k" kalan); varken kombolar en çok 3 satır.
## `steps` >= 0 (aile/kademe kaydı, v2.0.3): başlık "YENİ KADEME · steps", adlar "AİLE II" biçiminde gelir.
func set_new_achievements(names: Array[String], steps: int = -1) -> void:
	_new_names = names.duplicate()
	if achievement_chip == null:
		return
	achievement_chip.visible = not _new_names.is_empty()
	if not _new_names.is_empty():
		var texts := ResultModel.chip_texts(_new_names, steps)
		chip_title.text = texts["title"]
		chip_names.text = texts["names"]
		achievement_chip.accessibility_name = texts["a11y"]
	if _shown_combos != _combo_cap():
		_shown_combos = _combo_cap()
		if combo_box != null:
			_render_combos()
	_layout()


func has_new_achievements() -> bool:
	return not _new_names.is_empty()


func _combo_cap() -> int:
	return ResultModel.combo_cap(not _new_names.is_empty())


## Sonucu göster. combos: UiKit.combo_rows() çıktısı. subtitle boşsa varsayılan. record: Highscores.submit sonucu
## ({} = rekor bilgisi yok).
func show_result(
	p_won: bool,
	p_stats: Dictionary,
	combos: Array[Dictionary] = [],
	subtitle: String = "",
	record: Dictionary = {}
) -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st != null:
		_big = float(st.font_scale()) > BIG_SCALE
		ResultLayout.apply_fonts(self)
	won = p_won
	stats = p_stats
	last_record = record
	_subtitle = subtitle
	title_label.text = "KAZANDIN" if won else "OYUN BİTTİ"
	title_label.add_theme_color_override(&"font_color", UiKit.AMBER if won else UiKit.KEMIK_100)
	sub_label.text = subtitle if subtitle != "" else (WON_SUB if won else LOST_SUB)
	if won and str(stats.get("mode", "")) == "endless":
		var endless := ResultModel.endless_sub(
			float(stats.get("time", 0.0)), float(stats.get("milestone_t", -1.0))
		)
		sub_label.text = endless if endless != "" else sub_label.text
	glow.texture = ResultBlocks.glow_texture(UiKit.AMBER if won else UiKit.BORDO_500)
	_shown_combos = _combo_cap()
	_fill_combos(combos)
	ResultBlocks.fill_run(self, V21Runs.profiles)
	ResultBlocks.fill_record(self)
	ResultBlocks.fill_rows(self)
	_hero_total = clampi(int(stats.get("score", 0)), 0, DISPLAY_CAP)
	var amber := won or record_kind == &"record"
	score_value.add_theme_color_override(&"font_color", UiKit.AMBER if amber else UiKit.KEMIK_100)
	_t = 0.0
	_skip_t = -1.0
	_stamped = false
	_layout()
	_apply(0.0)
	visible = true


func _fill_combos(combos: Array[Dictionary]) -> void:
	_combos_data = combos
	_render_combos()


func _layout() -> void:
	ResultLayout.layout(self)


## Büyük yazı (denetim #2): `f` > 1,3 => çip satırı sarar, döküm/şerit/kombo/düğme yazıları büyür.
func set_font_scale(f: float) -> void:
	var big := f > BIG_SCALE
	if big == _big:
		return
	_big = big
	ResultLayout.apply_fonts(self)
	if title_label == null:
		return
	_render_combos()
	if not stats.is_empty():
		ResultBlocks.fill_run(self, V21Runs.profiles)
	_layout()
	if not stats.is_empty():
		_apply(_t)


func is_big() -> bool:
	return _big


## İçeriğin alt kenarı (düğmeler dahil; test için).
func content_bottom() -> float:
	_layout()
	return menu_button.position.y + menu_button.size.y


## İçerik bloklarının (düğmeler hariç) alt kenarı.
func blocks_bottom() -> float:
	_layout()
	return combo_panel.position.y + combo_panel.size.y


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra.
func apply_safe_area(extra: Variant = null) -> void:
	if extra is Vector4:
		_extra = extra
	else:
		_extra = UiKit.current_safe_extra(Vector2(1080.0, DESIGN_H))
	_shown_combos = _combo_cap()
	if combo_box != null:
		_render_combos()
	_layout()


## Animasyonu bitir (dokunma ile atlama): değerler son halini alır, düğmeler en erken 800 ms'de açılır.
func finish_count() -> void:
	if _skip_t < 0.0:
		_skip_t = _t
	_apply(_t)


func buttons_enabled() -> bool:
	return _t >= ResultTimeline.buttons_ready_at(_skip_t)


func _process(delta: float) -> void:
	if not visible:
		return
	if _t < ResultTimeline.buttons_at() + STAMP_SEC + 0.1:
		_t += delta
		_apply(_t)


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tap and _skip_t < 0.0 and _t < ResultTimeline.buttons_at():
		finish_count()
		accept_event()


func _apply(t: float) -> void:
	ResultAnim.apply(self, t)
