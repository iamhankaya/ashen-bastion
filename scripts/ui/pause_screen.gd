class_name PauseScreen
extends Control
## Duraklatma (docs/ui/mockups/05-duraklatma, 05b-duraklatma-onay). %80 perde, DURAKLATILDI, mevcut beceriler
## paneli (yalnız bilgi), DEVAM ET / SES / TİTREŞİM / BAŞTAN BAŞLA / ANA MENÜ. Baştan Başla ve Ana Menü onay
## diyaloğu açar (VAZGEÇ varsayılan odak). Geri tuşu: duraklatmada Devam Et, diyalogda Vazgeç (karar PauseLogic'te).

signal resume_requested
signal restart_confirmed
signal menu_confirmed
signal sound_toggled(on: bool)
signal vibration_toggled(on: bool)
signal settings_requested

enum Confirm { NONE, RESTART, MENU }

const BTN_W := 936.0
const COL_TOP := 380.0
const GAP_H := 95.0  # v2.1: koşu çipleri (48 + 27) eklendi; eylem düğmeleri eski yerinde kalır (170 - 75)
const GAP_MIN := 40.0
const CHIP_H := 48.0
const CHIP_ROW_GAP := 8.0  # 2×: çipler iki satıra sarar; slot 48 -> 104 (satır +56, DESIGN §5)
const CHIP_ACTION_MIN := 24.0  # çip ile eylem düğmeleri arası en az (U6 #17); GAP_MIN bunun altına inmez
const BIG_SCALE := 1.3

var resume_button: Button
var sound_button: Button
var vibration_button: Button
var settings_button: Button
var restart_button: Button
var menu_button: Button
var active_slots: Array[SkillSlot] = []
var passive_slots: Array[SkillSlot] = []
var dialog: Control
var dialog_text: Label
var dialog_cancel: Button
var dialog_ok: Button
var confirm_kind: int = Confirm.NONE
var column: VBoxContainer
var gap: Control
var chips_slot: Control
var chips: HBoxContainer
## 2×: çipler bu dikey kapta (HBoxContainer.vertical sabittir); 1×'te null.
var chips_v: VBoxContainer = null

var _sound_on: bool = true
var _vibration_on: bool = true
var _big: bool = false
var _safe_extra: Variant = null


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = UiKit.OVERLAY_DIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(scrim)
	add_child(scrim)

	var col := VBoxContainer.new()
	column = col
	col.name = "Column"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 27)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.offset_left = -BTN_W * 0.5
	col.offset_right = BTN_W * 0.5
	col.offset_top = COL_TOP  # HUD yuva satırlarının (y<350) altında; başlık onlara binmez
	add_child(col)

	var title := UiKit.label("DURAKLATILDI", &"LabelTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override(&"shadow_offset_y", 5)
	col.add_child(title)
	col.add_child(UiKit.divider())
	chips_slot = Control.new()  # v2.1 koşu çipleri (mod + zorluk), salt bilgi; open() doldurur
	chips_slot.name = "ChipsSlot"
	chips_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips_slot.custom_minimum_size = Vector2(0, CHIP_H)
	col.add_child(chips_slot)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", ResultFit.stone_box())
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override(&"separation", 18)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(UiKit.label("AKTİF BECERİLER", &"LabelAccent", 34))
	pv.add_child(_slot_row(&"active", 98.0, active_slots))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	pv.add_child(spacer)
	pv.add_child(UiKit.label("PASİF BECERİLER", &"LabelAccent", 34))
	pv.add_child(_slot_row(&"passive", 82.0, passive_slots))
	panel.add_child(pv)
	col.add_child(panel)

	gap = Control.new()
	gap.custom_minimum_size = Vector2(0, GAP_H)  # eylem düğmeleri makete göre aşağıda (başparmak bölgesi)
	col.add_child(gap)

	resume_button = UiKit.button("DEVAM ET", &"primary", 156.0)
	resume_button.add_theme_font_size_override(&"font_size", 52)
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	col.add_child(resume_button)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 27)
	sound_button = _stone_button("")
	sound_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_button.custom_minimum_size.x = 454.0
	sound_button.pressed.connect(_on_sound)
	vibration_button = _stone_button("")
	vibration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vibration_button.custom_minimum_size.x = 454.0
	vibration_button.pressed.connect(_on_vibration)
	row.add_child(sound_button)
	row.add_child(vibration_button)
	col.add_child(row)

	settings_button = _stone_button("AYARLAR")
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	col.add_child(settings_button)

	restart_button = _stone_button("BAŞTAN BAŞLA")
	restart_button.pressed.connect(open_confirm.bind(Confirm.RESTART))
	col.add_child(restart_button)
	menu_button = _stone_button("ANA MENÜ", true)
	menu_button.pressed.connect(open_confirm.bind(Confirm.MENU))
	col.add_child(menu_button)

	_build_dialog()
	set_settings(_sound_on, _vibration_on)


## Güvenli alan payı (N7): Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra. Sütun üst payı kadar iner,
## yan paylarda kayar; alt pay sütunu aşağıdan sıkıştırırsa boşluk (gap) küçülür. Pay 0 iken v1.1 düzeni birebir.
func apply_safe_area(extra: Variant = null) -> void:
	var view := Vector2(1080.0, 2400.0)
	if is_inside_tree() and size.y > 0.0:
		view = size
	_safe_extra = extra
	var e: Vector4
	if extra is Vector4:
		e = extra
	else:
		e = UiKit.current_safe_extra(view)
	if column == null:
		return
	var shift := (e.x - e.z) * 0.5
	column.offset_left = -BTN_W * 0.5 + shift
	column.offset_right = BTN_W * 0.5 + shift
	column.offset_top = COL_TOP + e.y
	gap.custom_minimum_size.y = GAP_H
	var bottom_limit := view.y - UiKit.DEFAULT_BOTTOM - e.w
	var over := column.offset_top + column.get_combined_minimum_size().y - bottom_limit
	gap.custom_minimum_size.y = clampf(
		GAP_H - maxf(over, 0.0), maxf(GAP_MIN, CHIP_ACTION_MIN), GAP_H
	)


## İkincil düğme taş dilde (DESIGN v2.1, skor GERİ kalıbı): tema `ButtonSecondary` mordur, yalnız bu ekranda geçersiz kılınır.
## Tehlikeli eylem (ANA MENÜ) taş zemin + bordo çerçeve.
func _stone_button(text: String, danger: bool = false) -> Button:
	var b := UiKit.button(text, &"secondary")
	for st in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(st, _stone_style("dugme-dolu", danger))
	b.add_theme_stylebox_override(&"pressed", _stone_style("dugme-basili", danger))
	return b


func _stone_style(skin: String, danger: bool) -> StyleBox:
	if not danger:
		return UiKit.skin_box(skin)
	var sb := UiKit.stylebox(UiKit.TAS_600, UiKit.BORDO_400, 5, 18)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, 20.0)
	return sb


func _build_dialog() -> void:
	dialog = Control.new()
	dialog.name = "Dialog"
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.fill(dialog)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.VOID, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(dim)
	dialog.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", ResultFit.stone_box())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -BTN_W * 0.5
	panel.offset_right = BTN_W * 0.5
	panel.offset_top = -270.0
	panel.offset_bottom = 270.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 36)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_text = UiKit.label("", &"", 36)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_text.custom_minimum_size = Vector2(BTN_W - 90.0, 0)
	v.add_child(dialog_text)
	dialog_cancel = _stone_button("VAZGEÇ")
	dialog_cancel.pressed.connect(close_confirm)
	v.add_child(dialog_cancel)
	dialog_ok = UiKit.button("", &"primary")
	dialog_ok.pressed.connect(_on_confirm_ok)
	v.add_child(dialog_ok)
	panel.add_child(v)
	dialog.add_child(panel)
	dialog.visible = false
	add_child(dialog)


## Ekranı aç: beceri yuvaları ve ayar anahtarları güncellenir; diyalog kapalı başlar.
func open(actives: Array[SkillState], passives: Array[SkillState], sound: bool, vib: bool) -> void:
	_fill(active_slots, actives)
	_fill(passive_slots, passives)
	set_settings(sound, vib)
	var st := get_node_or_null(^"/root/Settings") if is_inside_tree() else null
	if st != null:
		set_font_scale(st.font_scale())  # 2× yazı: ayar ekran her açıldığında okunur
	refresh_chips()
	close_confirm()
	visible = true
	resume_button.grab_focus.call_deferred()


## Koşu çipleri (DESIGN §5 Pause): geçerli (mod, zorluk); koşu içinde değiştirilemez, bu yüzden kayıtlı seçim koşununkidir.
func refresh_chips() -> void:
	if chips_slot == null:
		return
	if chips_v != null:
		chips_slot.remove_child(chips_v)
		chips_v.queue_free()
		chips_v = null
	elif chips != null:
		chips_slot.remove_child(chips)
	if chips != null:
		chips.queue_free()
	var sel := V21Runs.selection()
	chips = RunStrip.make_chips(sel["mode"], sel["diff"], V21Runs.profiles())
	UiKit.fill(chips)
	chips_slot.add_child(chips)
	_layout_chips()


## 2× yazı (`f > 1,3`): çipler iki satıra sarar (slot +56); güvenli alan sıkıştırması yeni yükseklikle yeniden hesaplanır.
func set_font_scale(f: float) -> void:
	var big := f > BIG_SCALE
	var changed := big != _big
	_big = big
	_layout_chips()
	if changed and column != null:
		apply_safe_area(_safe_extra)


func is_big() -> bool:
	return _big


func _layout_chips() -> void:
	if chips_slot == null:
		return
	chips_slot.custom_minimum_size.y = CHIP_H * 2.0 + CHIP_ROW_GAP if _big else CHIP_H
	if chips == null:
		return
	if _big and chips_v == null:
		chips_v = VBoxContainer.new()
		chips_v.add_theme_constant_override(&"separation", int(CHIP_ROW_GAP))
		UiKit.fill(chips_v)
		for c in chips.get_children():
			chips.remove_child(c)
			(c as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			chips_v.add_child(c)
		chips_slot.remove_child(chips)
		chips_slot.add_child(chips_v)
	elif not _big and chips_v != null:
		for c in chips_v.get_children():
			chips_v.remove_child(c)
			(c as Control).size_flags_horizontal = Control.SIZE_FILL
			chips.add_child(c)
		chips_slot.remove_child(chips_v)
		chips_v.queue_free()
		chips_v = null
		chips_slot.add_child(chips)


func set_settings(sound: bool, vib: bool) -> void:
	_sound_on = sound
	_vibration_on = vib
	if sound_button != null:
		sound_button.text = UiKit.toggle_text("SES", sound)
		vibration_button.text = UiKit.toggle_text("TİTREŞİM", vib)


## Onay metni (saf).
static func confirm_text(kind: int) -> String:
	if kind == Confirm.RESTART:
		return "Baştan başlansın mı? Bu oyundaki ilerleme kaybolur. Her oyun sıfırdan başlar."
	return "Ana menüye dönülsün mü? Bu oyundaki ilerleme kaybolur. Her oyun sıfırdan başlar."


static func confirm_button_text(kind: int) -> String:
	return "BAŞTAN BAŞLA" if kind == Confirm.RESTART else "ANA MENÜYE DÖN"


func open_confirm(kind: int) -> void:
	confirm_kind = kind
	dialog_text.text = confirm_text(kind)
	dialog_ok.text = confirm_button_text(kind)
	dialog.visible = true
	dialog_cancel.grab_focus.call_deferred()


func close_confirm() -> void:
	confirm_kind = Confirm.NONE
	if dialog != null:
		dialog.visible = false


func is_confirm_open() -> bool:
	return dialog != null and dialog.visible


func _on_confirm_ok() -> void:
	var k := confirm_kind
	close_confirm()
	if k == Confirm.RESTART:
		restart_confirmed.emit()
	elif k == Confirm.MENU:
		menu_confirmed.emit()


func _on_sound() -> void:
	set_settings(not _sound_on, _vibration_on)
	sound_toggled.emit(_sound_on)


func _on_vibration() -> void:
	set_settings(_sound_on, not _vibration_on)
	vibration_toggled.emit(_vibration_on)


func _slot_row(kind: StringName, s: float, out: Array[SkillSlot]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 18)
	for i in 6:
		var slot := SkillSlot.new(kind, s)
		row.add_child(slot)
		out.append(slot)
	return row


func _fill(slots: Array[SkillSlot], states: Array[SkillState]) -> void:
	for i in slots.size():
		if i < states.size() and states[i] != null:
			var st := states[i]
			var icon := Hud._icon_of(st)
			var evo := st.def != null and st.def.kind == SkillDef.KIND_EVOLUTION
			slots[i].set_skill(st.id, st.level, icon, evo)
		else:
			slots[i].set_skill(&"", 0)
