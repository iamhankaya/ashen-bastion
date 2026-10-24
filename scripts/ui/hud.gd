class_name Hud
extends Control
## Oyun HUD'ı (docs/ui/mockups/02-hud-oyun, 03-hud-doldurma, 08-hud-anatomi). Oyun kuralı yok; sim'i okur.
## Üst: seviye rozeti, XP çubuğu, süre MM:SS, duraklat (tek etkileşimli öğe). Altında can çubuğu + yazı,
## aktif (kare) ve pasif (daire) yuva satırları. Sol alt: 6 yuvalı şarjör tamburu. Can < %25: kenar vinyeti.
## Konumlar 1080×2400 referans pikseli; üst/yan kenar UiKit.SAFE_EDGE (36 px) + cihaz güvenli alanı payı (UiKit.safe_extra).

signal pause_pressed

const TOP := UiKit.SAFE_EDGE + 60.0  # ilk satırın üstü (rozet y = 84)
const BADGE := 84.0
const XP_H := 24.0
const PAUSE := 132.0
const HP_W := 360.0
const HP_H := 44.0
const SLOT_A := 78.0
const SLOT_P := 66.0
const SLOT_GAP := 9.0
const BOTTOM := 72.0
const CRITICAL := 0.25
const BAR_EASE := 0.18
const BOSS_BAND_TIME := 2.4
## "KALE LORDU GELİYOR" bandı: tam genişlik; üst kenarı cihaz üst payı kadar iner (HUD ile aynı oranda kayar, V-03).
const BOSS_BAND_TOP := 520.0
const BOSS_BAND_H := 132.0
const HUD_ALPHA := 0.85
## Elit/Lord can satırı: pasif yuva satırının altında, ortada, oyuncu canından ayrı (N2). Ad üstte (≥26 px),
## çubuk altta; Lord daha kalın ve ayrı renkte. Birden çok elit varsa en yüksek maks. canlı gösterilir, ada "+N" eklenir.
const BOSS_W := 700.0
const BOSS_Y := TOP + 350.0
const BOSS_NAME_H := 40.0
const BOSS_GAP := 2.0
const BOSS_BAR_ELITE := 24.0
const BOSS_BAR_LORD := 32.0
const BOSS_NAME_SIZE := 28
const BOSS_NAME_SIZE_LORD := 32
## v1.1 yerleşimi (DESIGN §3.2, §2.4, §5.2). İçerikleri ilgili sınıflar çizer; burada yalnız kutular.
const SCORE_TOP := 284.0  # skor sütunu: sağ SAFE_EDGE, üst 284 (SKOR etiketi 284, değer 312, SERİ çipi 388..436)
const SCORE_W := 460.0
const SCORE_H := 152.0
const BUFF_BADGE := 108.0  # etki rozeti; rozet n'nin sol x'i 231 + n·120 (BuffRow.badge_x), alt BOTTOM
const BUFF_ROW_W := 231.0 + 3.0 * 120.0 - 12.0

var level_badge: LevelBadge
var xp_bar: ProgressBar
var timer_label: Label
var pause_button: Button
var hp_bar: ProgressBar
var hp_label: Label
var active_slots: Array[SkillSlot] = []
var passive_slots: Array[SkillSlot] = []
var drum: MagazineDrum
var boss_band: PanelContainer
## Elit/Lord canı satırı (elit ya da Lord canlıyken görünür): ad etiketi + çubuk.
var boss_row: Control
var boss_bar: ProgressBar
var boss_name: Label
## Gösterilen hedef: Lord mu, ve ondan başka kaç elit canlı (ada "+N" olarak eklenir).
var boss_is_lord: bool = false
var boss_extra: int = 0
var boss_label: Label
var vignette: Vignette
## v1.1 (gizli doğar; ilgili D fazı görünür yapar): skor sütunu, etki rozetleri, ekran dışı ok, kayan metin.
var score_block: ScoreBlock
var buff_row: BuffRow
var offscreen_arrow: OffscreenArrow
var float_text: FloatText
## v2.0: başarım bildirim katmanı. 'safe' altında, 'Layer' (HUD_ALPHA) dışında; IGNORE. B3 kendi düğümünü ekler.
var toast_host: Control
## Cihaz güvenli alanı payı kadar içeri çekilmiş katman (rozet, çubuklar, yuvalar, tambur, duraklat).
var safe: Control

var _sim: GameSim = null
var _xp_shown: float = 0.0
var _hp_critical: bool = false
var _boss_left: float = 0.0
var _boss_scan: int = 0
var _safe_top: float = 0.0
var _boss_style: int = -1  # 0 elit, 1 Lord (stil değişince yeniden kurulur)


## Seviye rozeti (daire + sayı).
class LevelBadge:
	extends Control
	var level: int = 1

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c, r - 2.0, UiKit.MOR_800)
		draw_arc(c, r - 3.0, 0.0, TAU, 48, UiKit.BRONZ_300, 4.0, true)
		var f := UiKit.font(&"display")
		var fs := 40
		var t := str(level)
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(
			f,
			c + Vector2(-tw * 0.5, fs * 0.36),
			t,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			UiKit.KEMIK_100
		)


## Düşük can kenar vinyeti (kırmızı; hasarda 120 ms nabız).
class Vignette:
	extends Control
	var strength: float = 0.0

	func _draw() -> void:
		if strength <= 0.0:
			return
		var w := size.x
		var h := size.y
		var d := 140.0
		var on := Color(UiKit.CAN_KRITIK, 0.5 * strength)
		var off := Color(UiKit.CAN_KRITIK, 0.0)
		var cols := PackedColorArray([on, on, off, off])
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - d, d), Vector2(d, d)]),
			cols
		)
		draw_polygon(
			PackedVector2Array(
				[Vector2(0, h), Vector2(w, h), Vector2(w - d, h - d), Vector2(d, h - d)]
			),
			cols
		)
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(0, h), Vector2(d, h - d), Vector2(d, d)]),
			cols
		)
		draw_polygon(
			PackedVector2Array(
				[Vector2(w, 0), Vector2(w, h), Vector2(w - d, h - d), Vector2(w - d, d)]
			),
			cols
		)


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	vignette = Vignette.new()
	vignette.name = "Vignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(vignette)
	add_child(vignette)

	safe = Control.new()
	safe.name = "Safe"
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(safe)
	add_child(safe)
	apply_safe_area()

	var root := Control.new()
	root.name = "Layer"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate = Color(1, 1, 1, HUD_ALPHA)
	UiKit.fill(root)
	safe.add_child(root)

	level_badge = LevelBadge.new()
	level_badge.name = "LevelBadge"
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(level_badge, 0.0, Rect2(UiKit.SAFE_EDGE, TOP, BADGE, BADGE))
	root.add_child(level_badge)

	xp_bar = ProgressBar.new()
	xp_bar.name = "XpBar"
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.max_value = 1.0
	xp_bar.step = 0.0
	_place_stretch(xp_bar, 132.0, UiKit.SIDE, TOP + 16.0, XP_H)
	root.add_child(xp_bar)

	timer_label = UiKit.label("00:00", &"LabelTimer")
	timer_label.name = "Timer"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_constant_override(&"shadow_offset_y", 3)
	_place(timer_label, 0.5, Rect2(-240, TOP + 38.0, 480, 96))
	root.add_child(timer_label)

	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.focus_mode = Control.FOCUS_ALL  # klavye/gamepad odağı (DESIGN-UI §8); focus stili tanımlı
	pause_button.icon = UiKit.hud_icon("hud-duraklat")
	pause_button.expand_icon = true
	pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var circle := UiKit.stylebox(Color(UiKit.VOID, 0.55), UiKit.BRONZ_500, 4, 66)
	circle.set_content_margin_all(40)
	var circle_p := UiKit.stylebox(Color(UiKit.MOR_900, 0.9), UiKit.BRONZ_300, 4, 66)
	circle_p.set_content_margin_all(44)
	for st in [&"normal", &"hover", &"focus"]:
		pause_button.add_theme_stylebox_override(st, circle)
	pause_button.add_theme_stylebox_override(&"pressed", circle_p)
	_place(pause_button, 1.0, Rect2(-UiKit.SIDE - PAUSE, TOP + 44.0, PAUSE, PAUSE))
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	safe.add_child(pause_button)  # tam opak ve vinyetin üstünde

	var heart := TextureRect.new()
	heart.name = "Heart"
	heart.texture = UiKit.hud_icon("hud-can")
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(heart, 0.0, Rect2(UiKit.SIDE - 6.0, TOP + 106.0, 56, 56))
	hp_bar = ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.theme_type_variation = &"ProgressBarHP"
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.step = 0.0
	_place(hp_bar, 0.0, Rect2(UiKit.SIDE + 24.0, TOP + 112.0, HP_W, HP_H))
	root.add_child(hp_bar)
	root.add_child(heart)
	hp_label = UiKit.label("100 / 100", &"", 28)
	hp_label.name = "HpLabel"
	hp_label.add_theme_font_override(&"font", UiKit.font_semibold())
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.fill(hp_label)
	hp_bar.add_child(hp_label)

	for i in Loadout.ACTIVE_SLOTS:
		var s := SkillSlot.new(&"active", SLOT_A)
		s.name = "Active%d" % i
		_place(s, 0.0, Rect2(UiKit.SIDE + i * (SLOT_A + SLOT_GAP), TOP + 194.0, SLOT_A, SLOT_A))
		root.add_child(s)
		active_slots.append(s)
	for i in Loadout.PASSIVE_SLOTS:
		var s := SkillSlot.new(&"passive", SLOT_P)
		s.name = "Passive%d" % i
		_place(
			s, 0.0, Rect2(UiKit.SIDE + 6.0 + i * (SLOT_P + SLOT_GAP), TOP + 284.0, SLOT_P, SLOT_P)
		)
		root.add_child(s)
		passive_slots.append(s)

	boss_row = Control.new()
	boss_row.name = "BossRow"
	boss_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_row.visible = false
	_place(
		boss_row, 0.5, Rect2(-BOSS_W * 0.5, BOSS_Y, BOSS_W, BOSS_NAME_H + BOSS_GAP + BOSS_BAR_LORD)
	)
	root.add_child(boss_row)
	boss_name = UiKit.label("", &"LabelAccent", BOSS_NAME_SIZE, UiKit.KEMIK_100)
	boss_name.name = "BossName"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_name.offset_right = BOSS_W
	boss_name.offset_bottom = BOSS_NAME_H
	boss_name.add_theme_constant_override(&"shadow_offset_y", 2)
	boss_row.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.name = "BossBar"
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.max_value = 1.0
	boss_bar.step = 0.0
	boss_bar.visible = false
	boss_bar.offset_top = BOSS_NAME_H + BOSS_GAP
	boss_bar.offset_right = BOSS_W
	boss_bar.offset_bottom = BOSS_NAME_H + BOSS_GAP + BOSS_BAR_ELITE
	boss_row.add_child(boss_bar)
	_style_boss(false)

	drum = MagazineDrum.new()
	drum.name = "MagazineDrum"
	drum.anchor_top = 1.0
	drum.anchor_bottom = 1.0
	drum.offset_left = UiKit.SIDE
	drum.offset_right = UiKit.SIDE + MagazineDrum.SIZE
	drum.offset_top = -BOTTOM - MagazineDrum.SIZE
	drum.offset_bottom = -BOTTOM
	root.add_child(drum)

	_build_v11(root)

	boss_band = PanelContainer.new()
	boss_band.name = "BossBand"
	boss_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := UiKit.stylebox(Color(UiKit.BORDO_900, 0.88), UiKit.AMBER, 0, 0)
	band.border_width_top = 4
	band.border_width_bottom = 4
	boss_band.add_theme_stylebox_override(&"panel", band)
	_place_stretch(boss_band, 0.0, 0.0, BOSS_BAND_TOP, BOSS_BAND_H)
	_shift_boss_band()
	boss_label = UiKit.label("", &"LabelAccent", 56, UiKit.KEMIK_100)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_band.add_child(boss_label)
	boss_band.visible = false
	add_child(boss_band)


## v1.1 öğeleri (hepsi gizli): skor sütunu ve etki rozetleri HUD katmanında, ok ve kayan metin tam ekran güvenli katmanda.
func _build_v11(root: Control) -> void:
	score_block = ScoreBlock.new()
	score_block.name = "ScoreBlock"
	_place(score_block, 1.0, Rect2(-UiKit.SAFE_EDGE - SCORE_W, SCORE_TOP, SCORE_W, SCORE_H))
	root.add_child(score_block)
	buff_row = BuffRow.new()
	buff_row.name = "BuffRow"
	buff_row.anchor_top = 1.0
	buff_row.anchor_bottom = 1.0
	buff_row.offset_left = 0.0
	buff_row.offset_right = BUFF_ROW_W
	buff_row.offset_top = -BOTTOM - BUFF_BADGE
	buff_row.offset_bottom = -BOTTOM
	root.add_child(buff_row)
	offscreen_arrow = OffscreenArrow.new()
	offscreen_arrow.name = "OffscreenArrow"
	UiKit.fill(offscreen_arrow)
	safe.add_child(offscreen_arrow)
	float_text = FloatText.new()
	float_text.name = "FloatText"
	UiKit.fill(float_text)
	safe.add_child(float_text)
	toast_host = Control.new()
	toast_host.name = "ToastHost"
	toast_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(toast_host)
	safe.add_child(toast_host)


## Güvenli alan payını (çentik, yuvarlak köşe) uygular; payı DisplayServer.get_display_safe_area'dan alır.
func apply_safe_area(extra: Variant = null) -> void:
	var e: Vector4
	if extra is Vector4:
		e = extra
	else:
		e = UiKit.current_safe_extra(
			get_viewport_rect().size if is_inside_tree() else Vector2(1080, 2400)
		)
	safe.offset_left = e.x
	safe.offset_top = e.y
	safe.offset_right = -e.z
	safe.offset_bottom = -e.w
	_safe_top = e.y
	_shift_boss_band()


## Lord bandını güvenli alan üst payı kadar indirir (bant `safe` dışında, tam genişlikte kalır).
func _shift_boss_band() -> void:
	if boss_band != null:
		boss_band.offset_top = BOSS_BAND_TOP + _safe_top
		boss_band.offset_bottom = BOSS_BAND_TOP + _safe_top + BOSS_BAND_H


## Sim'e bağlan (yeni oyun). Sinyallerden yalnız görsel geri bildirim alınır.
func bind(sim: GameSim) -> void:
	if _sim != null:
		if _sim.bus.boss_warning.is_connected(_on_boss_warning):
			_sim.bus.boss_warning.disconnect(_on_boss_warning)
		if _sim.bus.player_damaged.is_connected(_on_player_damaged):
			_sim.bus.player_damaged.disconnect(_on_player_damaged)
	_sim = sim
	_bind_v11(sim)
	_boss_left = 0.0
	if boss_band != null:
		boss_band.visible = false
	if sim == null:
		return
	sim.bus.boss_warning.connect(_on_boss_warning)
	sim.bus.player_damaged.connect(_on_player_damaged)
	_xp_shown = _xp_ratio()
	refresh(0.0)


## Her kare (oyun ekranında): sim'den oku, göster.
func refresh(dt: float) -> void:
	if _sim == null or level_badge == null:
		return
	if level_badge.level != _sim.level:
		level_badge.level = _sim.level
		level_badge.queue_redraw()
	var target := _xp_ratio()
	if target < _xp_shown:
		_xp_shown = target  # seviye atlamada sıfırdan başla
	else:
		_xp_shown = (
			lerpf(_xp_shown, target, clampf(dt / BAR_EASE, 0.0, 1.0)) if dt > 0.0 else target
		)
	xp_bar.value = _xp_shown
	timer_label.text = UiKit.format_time(_sim.time)
	hp_bar.max_value = maxf(_sim.max_hp, 1.0)
	hp_bar.value = clampf(_sim.hp, 0.0, _sim.max_hp)
	hp_label.text = hp_text(_sim.hp, _sim.max_hp)
	_set_critical(is_critical(_sim.hp, _sim.max_hp))
	_refresh_slots(active_slots, _sim.loadout.actives())
	_refresh_slots(passive_slots, _sim.loadout.passives())
	var mag := _sim.magazine
	var prog := 0.0
	if mag.reloading and mag.reload_total > 0.0:
		prog = 1.0 - mag.reload_left / mag.reload_total
	drum.set_state(mag.count, mag.cap, mag.reloading, prog)
	drum.tick(dt)
	_refresh_boss_bar()
	_refresh_v11(dt)
	_tick_effects(dt)


func _bind_v11(sim: GameSim) -> void:
	if score_block == null:
		return  # _build'den önce
	score_block.bind(sim)
	buff_row.bind(sim)
	offscreen_arrow.bind(sim)


func _refresh_v11(dt: float) -> void:
	drum.set_unlimited(_sim.magazine.unlimited)
	score_block.refresh(dt)
	buff_row.refresh(dt)
	offscreen_arrow.refresh(dt)
	float_text.refresh(dt)


## "86 / 120" (yukarı yuvarlanmış can; 0'ın altı 0).
static func hp_text(hp: float, max_hp: float) -> String:
	return "%d / %d" % [maxi(0, ceili(hp)), roundi(max_hp)]


static func is_critical(hp: float, max_hp: float) -> bool:
	return max_hp > 0.0 and hp / max_hp < CRITICAL


## Boss bandı metni (önceden büyük harf).
static func boss_text(kind: StringName) -> String:
	if String(kind).contains("lord"):
		return "KALE LORDU GELİYOR"
	return "ARA BOSS YAKLAŞIYOR"


func show_boss_band(kind: StringName) -> void:
	boss_label.text = boss_text(kind)
	boss_band.visible = true
	_boss_left = BOSS_BAND_TIME


## Her 6. karede düşman havuzunu tarar; Lord varsa Lord'u, yoksa en yüksek maks. canlı elit'i gösterir. Diğer canlı
## elitler ada "+N" olarak eklenir (hepsine ayrı çubuk yok: üstte yer yok, hedef en tehlikeli olandır).
func _refresh_boss_bar() -> void:
	_boss_scan += 1
	if _boss_scan % 6 != 0:
		return
	var e := _sim.enemies
	var best := -1
	var best_max := 0.0
	var lord := false
	var n := 0
	for i in EnemyPool.CAP:
		if e.alive[i] == 1 and e.is_elite(i):
			n += 1
			var is_lord := e.def_of(i).ai == &"lord"
			if (is_lord and not lord) or (is_lord == lord and e.max_hp[i] > best_max):
				best = i
				best_max = e.max_hp[i]
				lord = is_lord
	boss_row.visible = best >= 0
	boss_bar.visible = best >= 0
	if best >= 0:
		boss_is_lord = lord
		boss_extra = n - 1
		_style_boss(lord)
		boss_bar.value = clampf(e.hp[best] / maxf(e.max_hp[best], 1.0), 0.0, 1.0)
		boss_name.text = boss_title(e.def_of(best).display_name, boss_extra)


## Cinzel'de küçük harf yok: ad Türkçe büyük harfe çevrilir; birden çok elit varsa "+N".
static func boss_title(display_name: String, extra: int) -> String:
	var t := UiKit.upper_tr(display_name)
	return t if extra <= 0 else "%s  +%d" % [t, extra]


## Elit: bronz, ince; Lord: amber dolgu + kemik çerçeve, daha kalın ve daha büyük ad (final dövüşü "boss" gibi okunur).
func _style_boss(lord: bool) -> void:
	var style := 1 if lord else 0
	if style == _boss_style:
		return
	_boss_style = style
	var h := BOSS_BAR_LORD if lord else BOSS_BAR_ELITE
	boss_bar.offset_bottom = boss_bar.offset_top + h
	var bg := UiKit.stylebox(
		Color(UiKit.VOID, 0.8), UiKit.KEMIK_100 if lord else UiKit.BRONZ_300, 3 if lord else 2, 8
	)
	var fill := UiKit.stylebox(
		UiKit.AMBER if lord else UiKit.BRONZ_500, UiKit.BORDO_400 if lord else UiKit.BRONZ_300, 0, 6
	)
	boss_bar.add_theme_stylebox_override(&"background", bg)
	boss_bar.add_theme_stylebox_override(&"fill", fill)
	boss_name.add_theme_font_size_override(
		&"font_size", BOSS_NAME_SIZE_LORD if lord else BOSS_NAME_SIZE
	)
	boss_name.add_theme_color_override(&"font_color", UiKit.AMBER if lord else UiKit.KEMIK_100)


func _xp_ratio() -> float:
	if _sim == null or _sim.xp_to_next <= 0:
		return 0.0
	return clampf(float(_sim.xp) / float(_sim.xp_to_next), 0.0, 1.0)


## Karaktere göre çözülmüş ikon (SkillState.icon); boşsa tanımın ikonu.
static func _icon_of(st: SkillState) -> String:
	if st.icon != "":
		return st.icon
	return st.def.icon if st.def != null else ""


func _refresh_slots(slots: Array[SkillSlot], states: Array[SkillState]) -> void:
	for i in slots.size():
		if i < states.size() and states[i] != null:
			var st := states[i]
			var icon_field := _icon_of(st)
			var evolved := st.def != null and st.def.kind == SkillDef.KIND_EVOLUTION
			slots[i].set_skill(st.id, st.level, icon_field, evolved)
		else:
			slots[i].set_skill(&"", 0)


func _set_critical(on: bool) -> void:
	if on == _hp_critical:
		return
	_hp_critical = on
	if on:
		var sb := UiKit.stylebox(UiKit.CAN_KRITIK, UiKit.CAN_KRITIK, 0, 22)
		hp_bar.add_theme_stylebox_override(&"fill", sb)
	else:
		hp_bar.remove_theme_stylebox_override(&"fill")


func _tick_effects(dt: float) -> void:
	var target := 0.75 if _hp_critical else 0.0
	var v := vignette.strength
	if v > target:
		v = maxf(target, v - dt / 0.12)  # nabız 120 ms'de söner
	else:
		v = target
	if not is_equal_approx(v, vignette.strength):
		vignette.strength = v
		vignette.queue_redraw()
	if _boss_left > 0.0:
		_boss_left = maxf(0.0, _boss_left - dt)
		boss_band.visible = _boss_left > 0.0


func _on_boss_warning(kind: StringName) -> void:
	show_boss_band(kind)


func _on_player_damaged(_amount: float, hp: float) -> void:
	if _sim != null and is_critical(hp, _sim.max_hp):
		vignette.strength = 1.0
		vignette.queue_redraw()


## ax: yatay çapa (0 sol, 0.5 orta, 1 sağ), üst çapa; r: çapaya göre ofset dikdörtgeni.
func _place(c: Control, ax: float, r: Rect2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


## Soldan `left`, sağdan `right` boşlukla yatay yayılan, üstten `top` konumlu öğe.
func _place_stretch(c: Control, left: float, right: float, top: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = left
	c.offset_right = -right
	c.offset_top = top
	c.offset_bottom = top + h
