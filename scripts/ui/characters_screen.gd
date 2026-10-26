class_name CharactersScreen
extends Control
## Karakterler ekranı: vitrin sahnesi (portre + parçacık) + bilgi paneli + kart şeridi + SEÇ/GERİ. Karakter BAŞLATMAZ
## (sinyal yayar), sim yok. Tasarım: docs/design/v2.0/DESIGN.md §4. Düzen sabitleri 1080×2400 tasarım pikseli.
## Hareket (ShowcaseMotion) yalnız görünürken çalışır: gizliyken `_process` ve parçacıklar kapalıdır (K5).

signal back_requested
## SEÇ basıldı (yalnız kilitsiz ve odak != seçili).
signal selected(id: StringName)

enum SelectState { SELECT, SELECTED, LOCKED }

const W := 1080.0
const MARGIN := 72.0
const COL_W := 936.0
const TITLE_Y := 112.0
const STAGE_TOP := 190.0
const STAGE_BOTTOM := 1250.0
const NAME_Y := 1060.0
const PANEL_BOTTOM := 1696.0  # 1250 + 446
const PANEL_H := 446.0
const CARD_W := 252.0
const CARD_H := 264.0
const CARD_GAP := 27.0
const STRIP_Y := 1722.0
const SELECT_Y := 2013.0
const SELECT_H := 156.0
const BACK_Y := 2196.0
const BACK_H := 132.0
const PORTRAIT_W := 1120.0  # sahneden geniş: nefes/sürüklenme kenar göstermez
const PORTRAIT_H := 1680.0  # 1024×1536 → genişliğe sığdırılmış
const SWAP_SLIDE := 40.0
const STAT_KEYS: Array[String] = ["CAN", "HIZ", "ŞARJÖR", "DOLDURMA", "MENZİL", "TOPLAMA"]

var title_label: Label
var counter_label: Label
var name_label: Label
var chip_label: Label
var _chip_lock: Control
var _stage_mono: Label
var blurb_label: Label
var skill_label: Label
var select_button: Button
var back_button: Button
var cards: Array[Button] = []
var particles: CPUParticles2D
var stage: Control

var _data: GameData
var _store: AchievementStore
var _ids: Array[StringName] = []
var _selected: StringName = &""
var _focus: StringName = &""
var _t: float = 0.0
var _portrait: TextureRect
var _ghost: TextureRect
var _video: PortraitPlayer
var _lock_ring: Control
var _panel: PanelContainer
var _stat_values: Array[Label] = []
var _skill_icon: TextureRect
var _strip: ScrollContainer
var _strip_row: HBoxContainer
var _reason: Label
var _placeholder_tag: Label
var _swap_tween: Tween
var _drag_from: float = 0.0
var _dragging: bool = false
var _safe := Vector4.ZERO


func _ready() -> void:
	_ensure_built()
	visibility_changed.connect(_apply_running)
	_apply_running()


## `open` ağaca eklenmeden önce de çağrılabilir (V2Characters kurulumu): düğümler bir kez kurulur.
func _ensure_built() -> void:
	if stage != null:
		return
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.VOID
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(bg)
	add_child(bg)

	stage = Control.new()
	stage.name = "Stage"
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.gui_input.connect(_on_stage_input)
	add_child(stage)
	_ghost = _portrait_rect("Ghost")
	_portrait = _portrait_rect("Portrait")
	stage.add_child(_ghost)
	stage.add_child(_portrait)
	_video = PortraitPlayer.new()  # statik portrenin çocuğu: nefes/sürüklenme/çapraz solma birlikte gelir
	_video.size = Vector2(PORTRAIT_W, PORTRAIT_H)
	_portrait.add_child(_video)
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.fill(shade)
	stage.add_child(shade)
	_stage_mono = UiKit.label("", &"LabelTitle", 480, UiKit.KEMIK_100)
	_stage_mono.name = "Monogram"
	_stage_mono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_mono.modulate.a = 0.22
	UiKit.fill(_stage_mono)
	stage.add_child(_stage_mono)
	_lock_ring = _LockRing.new()
	_lock_ring.name = "LockRing"
	_lock_ring.visible = false
	stage.add_child(_lock_ring)
	particles = _make_particles()
	stage.add_child(particles)

	title_label = UiKit.label("KARAKTERLER", &"LabelTitle", 64)
	title_label.position = Vector2(MARGIN, TITLE_Y)
	add_child(title_label)
	counter_label = UiKit.label("", &"", 28, UiKit.BRONZ_300)
	counter_label.add_theme_font_override(&"font", UiKit.font_bold())
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label.size = Vector2(200, 40)
	add_child(counter_label)

	name_label = UiKit.label("", &"LabelTitle", 96)
	name_label.add_theme_constant_override(&"shadow_offset_y", 6)
	add_child(name_label)
	chip_label = UiKit.label("", &"", 26, UiKit.AMBER)
	chip_label.add_theme_font_override(&"font", UiKit.font_bold())
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(chip_label)
	_chip_lock = _LockGlyph.new()
	_chip_lock.visible = false
	chip_label.add_child(_chip_lock)

	_build_panel()

	_strip = ScrollContainer.new()
	_strip.name = "Strip"
	_strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.touch_scroll(_strip)
	add_child(_strip)
	_strip_row = HBoxContainer.new()
	_strip_row.add_theme_constant_override(&"separation", int(CARD_GAP))
	_strip.add_child(_strip_row)

	select_button = UiKit.button("SEÇ", &"primary", SELECT_H)
	select_button.name = "SelectButton"
	select_button.add_theme_font_size_override(&"font_size", 46)
	select_button.pressed.connect(press_select)
	add_child(select_button)
	_reason = UiKit.label("", &"", 28, UiKit.KEMIK_300)
	_reason.add_theme_font_override(&"font", UiKit.font_semibold())
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.size = Vector2(COL_W, 40)
	_reason.position = Vector2(0, SELECT_H - 56.0)
	select_button.add_child(_reason)
	back_button = UiKit.button("GERİ", &"secondary", BACK_H)
	back_button.name = "BackButton"
	back_button.accessibility_name = "Geri"
	back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(back_button)
	_placeholder_tag = UiKit.label("YER TUTUCU", &"", 26, UiKit.KEMIK_300)
	_placeholder_tag.name = "PlaceholderTag"
	_placeholder_tag.visible = false
	add_child(_placeholder_tag)
	_layout()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(COL_W, PANEL_H)
	_panel.add_theme_stylebox_override(&"panel", _panel_style())
	_panel.resized.connect(_place_panel)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	_panel.add_child(col)
	blurb_label = UiKit.label("", &"", 32, UiKit.KEMIK_100)
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.max_lines_visible = 4
	blurb_label.custom_minimum_size = Vector2(COL_W - 48.0, 0)
	col.add_child(blurb_label)
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override(&"separation", 18)
	skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 84 px çerçeveli ikon (DESIGN §4.2): çerçeve altta (önce eklenir), ikon üstte (SD-01).
	var icon_box := Control.new()
	icon_box.name = "SkillIconBox"
	icon_box.custom_minimum_size = Vector2(84, 84)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_row.add_child(icon_box)
	var icon_frame := TextureRect.new()
	icon_frame.name = "SkillFrame"
	icon_frame.texture = UiKit.frame(&"active")
	icon_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.size = Vector2(84, 84)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_frame)
	_skill_icon = TextureRect.new()
	_skill_icon.name = "SkillIcon"
	_skill_icon.position = Vector2(10, 10)
	_skill_icon.size = Vector2(64, 64)
	_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_skill_icon)
	var sc := VBoxContainer.new()
	sc.alignment = BoxContainer.ALIGNMENT_CENTER
	sc.add_theme_constant_override(&"separation", -2)
	sc.add_child(_bold_label("BAŞLANGIÇ BECERİSİ", 26, UiKit.BRONZ_300))
	skill_label = UiKit.label("", &"LabelTimer", 38)
	sc.add_child(skill_label)
	skill_row.add_child(sc)
	col.add_child(skill_row)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 12)
	for key in STAT_KEYS:
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(282, 78)
		tile.add_theme_stylebox_override(&"panel", _tile_style())
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", -6)
		v.add_child(_bold_label(key, 26, UiKit.KEMIK_300))
		var val := UiKit.label("", &"LabelTimer", 40)
		val.add_theme_color_override(&"font_color", UiKit.KEMIK_100)
		v.add_child(val)
		tile.add_child(v)
		grid.add_child(tile)
		_stat_values.append(val)
	col.add_child(grid)


func _bold_label(text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, &"", size, color)
	l.add_theme_font_override(&"font", UiKit.font_bold())
	return l


static func _panel_style() -> StyleBoxFlat:
	var sb := UiKit.stylebox(UiKit.MOR_700, UiKit.BRONZ_500, 4, 18, true)
	sb.set_content_margin_all(24)
	return sb


static func _tile_style() -> StyleBoxFlat:
	var sb := UiKit.stylebox(UiKit.MOR_900, UiKit.MOR_900, 0, 12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	return sb


func _portrait_rect(node_name: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = node_name
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(PORTRAIT_W, PORTRAIT_H)
	return r


func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Embers"
	p.amount = 12
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.texture = _ember_texture()
	p.color = Color(UiKit.AMBER, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.emitting = false
	return p


static func _ember_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 16
	t.height = 16
	return t


## Alt gradyan: sahne altında void %100 → y ≈ 1000'de şeffaf.
static func _shade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.76, 1.0])
	g.colors = PackedColorArray(
		[Color(UiKit.VOID, 0.0), Color(UiKit.VOID, 0.0), Color(UiKit.VOID, 1.0)]
	)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 256
	return t


## Güvenli alan payına göre dikey yerleşim; sahne yüksekliği payı emer.
func _layout() -> void:
	var top := _safe.y
	var bottom := _safe.w
	title_label.position = Vector2(MARGIN, TITLE_Y + top)
	counter_label.position = Vector2(W - MARGIN - 200.0, TITLE_Y + top + 22.0)
	var stage_top := STAGE_TOP + top
	var stage_bottom := STAGE_BOTTOM - bottom
	stage.position = Vector2(0, stage_top)
	stage.size = Vector2(W, stage_bottom - stage_top)
	_lock_ring.position = Vector2((W - 240.0) * 0.5, (stage.size.y - 240.0) * 0.4)
	_lock_ring.size = Vector2(240, 240)
	particles.position = Vector2(W * 0.5, stage.size.y)
	particles.emission_rect_extents = Vector2(W * 0.5, 4.0)
	_place_portrait(0.0)
	name_label.position = Vector2(MARGIN, NAME_Y - bottom)
	chip_label.position = Vector2(MARGIN, NAME_Y - bottom)
	_place_panel()
	_strip.position = Vector2(MARGIN, STRIP_Y - bottom)
	_strip.size = Vector2(COL_W, CARD_H + 8.0)
	select_button.position = Vector2(MARGIN, SELECT_Y - bottom)
	select_button.size = Vector2(COL_W, SELECT_H)
	back_button.position = Vector2(MARGIN, BACK_Y - bottom)
	back_button.size = Vector2(COL_W, BACK_H)
	_placeholder_tag.position = Vector2(W - 260.0, 24.0 + top)
	_place_name_chip()


func _place_portrait(extra_x: float) -> void:
	var x := (W - PORTRAIT_W) * 0.5 + ShowcaseMotion.drift_at(_t) + extra_x
	_portrait.position = Vector2(x, 0)
	_ghost.position = Vector2(x, 0)
	_portrait.pivot_offset = Vector2(PORTRAIT_W * 0.5, stage.size.y)
	_portrait.scale = Vector2.ONE * ShowcaseMotion.scale_at(_t)


func _place_panel() -> void:
	_panel.size = Vector2(COL_W, _panel.size.y)
	_panel.position = Vector2(MARGIN, PANEL_BOTTOM - _safe.w - _panel.size.y)


func _place_name_chip() -> void:
	# Ad bloğu panelin üstüne yaslanır (panel uzarsa ad yukarı kayar).
	var y := minf(NAME_Y - _safe.w, _panel.position.y - 150.0)
	name_label.position.y = y
	# K-05: çip adın taban çizgisine oturur (ad yazısının ascent'i - çip ascent'i - üst boşluk).
	var nf := name_label.get_theme_font(&"font")
	var cf := chip_label.get_theme_font(&"font")
	var base := nf.get_ascent(96) - cf.get_ascent(26) - CHIP_PAD_Y
	chip_label.position = Vector2(MARGIN + name_label.get_minimum_size().x + 28.0, y + base)


func _reduce_motion() -> bool:
	var st := get_node_or_null(^"/root/Settings")
	return st != null and st.hareket_azalt


func _apply_running() -> void:
	var on := is_visible_in_tree()
	set_process(on)
	if _video != null:
		_video.paused = not on
	if particles != null:
		particles.emitting = on


func _process(delta: float) -> void:
	_t += delta
	if stage != null:
		_place_portrait(0.0)


## Ekranı kurar: sıra `CharacterRoster.ids`, odak = seçili (geçersizse ilk karakter).
func open(data: GameData, store: AchievementStore, selected_id: StringName) -> void:
	_ensure_built()
	_data = data
	_store = store
	_ids = CharacterRoster.ids(data)
	_selected = selected_id
	var start := selected_id if _ids.has(selected_id) else (_ids[0] if not _ids.is_empty() else &"")
	_rebuild_cards()
	counter_label.visible = _ids.size() > 1
	_strip.visible = _ids.size() > 1
	_focus = &""
	_set_focus(start, 0)
	accessibility_name = "Karakterler, seçili: %s" % _display_name(_selected)
	if is_inside_tree():
		(
			(select_button if select_button.is_inside_tree() else back_button)
			. grab_focus
			. call_deferred()
		)


func focus_id() -> StringName:
	return _focus


func set_focus_id(id: StringName) -> void:
	if _data == null or not _ids.has(id):
		return
	_set_focus(id, signi(_ids.find(id) - _ids.find(_focus)))


## Test/D-pad için; kilitliyse false. Odak seçiliyse işlevsiz (true değil: yeni seçim olmadı).
func press_select() -> bool:
	var st := select_button_state()
	if st != SelectState.SELECT:
		return false
	_selected = _focus
	selected.emit(_focus)
	_refresh_state()
	_refresh_cards()
	_pulse_select()
	return true


## SelectState.
func select_button_state() -> int:
	if _data == null or _focus == &"":
		return SelectState.SELECTED if _focus == _selected else SelectState.SELECT
	var c := _data.get_character(_focus)
	if c != null and not CharacterRoster.is_unlocked(c, _store):
		return SelectState.LOCKED
	return SelectState.SELECTED if _focus == _selected else SelectState.SELECT


## extra: Vector4(sol, üst, sağ, alt) ya da null (UiKit.current_safe_extra).
func apply_safe_area(extra: Variant = null) -> void:
	if extra is Vector4:
		_safe = extra
	else:
		_safe = UiKit.current_safe_extra(Vector2(W, 2400.0))
	_safe = Vector4(maxf(0.0, _safe.x), maxf(0.0, _safe.y), maxf(0.0, _safe.z), maxf(0.0, _safe.w))
	_layout()


func _display_name(id: StringName) -> String:
	var c := _data.get_character(id) if _data != null else null
	return c.display_name if c != null else ""


func _set_focus(id: StringName, dir: int) -> void:
	if id == &"" or id == _focus:
		_refresh_state()
		return
	var first := _focus == &""
	_focus = id
	_refresh_info()
	_refresh_state()
	_refresh_cards()
	_scroll_to_focus()
	if not first:
		_crossfade(dir)


func _refresh_info() -> void:
	var c := _data.get_character(_focus)
	if c == null:
		return
	name_label.text = UiKit.character_upper(c)
	blurb_label.text = c.blurb
	var sk := _data.get_skill(c.starting_skill)
	skill_label.text = UiKit.upper_tr(sk.name_for(c.id) if sk != null else String(c.starting_skill))
	_skill_icon.texture = UiKit.skill_icon(
		c.starting_skill, sk.icon_for(c.id) if sk != null else ""
	)
	var vals: Array[String] = [
		_num(c.max_hp),
		_num(c.move_speed),
		_num(float(c.mag_cap)),
		"%s SN" % _num(c.reload_time),
		_num(c.attack_range),
		_num(c.pickup_radius),
	]
	for i in vals.size():
		_stat_values[i].text = vals[i]
	counter_label.text = "%d / %d" % [_ids.find(_focus) + 1, _ids.size()]
	var tex := UiKit.texture(c.portrait) if c.portrait != "" else null
	if tex == null:
		tex = UiKit.texture(CharactersScreen._FALLBACK_PORTRAIT)
	_ghost.texture = _portrait.texture
	_portrait.texture = tex
	_portrait.self_modulate = PLACEHOLDER_TINT if c.placeholder else Color.WHITE
	_video.show_source("" if c.placeholder else c.portrait_video, _reduce_motion())
	_stage_mono.text = UiKit.character_upper(c).substr(0, 1) if c.placeholder else ""
	_placeholder_tag.visible = OS.is_debug_build() and c.placeholder
	_place_name_chip.call_deferred()


## Yer tutucu karakterlerin (placeholder:true) portresi: belirgin soğuk ton + baş harf; release'te de görünür (K-03).
const PLACEHOLDER_TINT := Color(0.62, 0.78, 1.0)
const CHIP_PAD_Y := 8.0
const CHIP_PAD_X := 22.0
const CHIP_LOCK_W := 26.0
const CHIP_LOCK_GAP := 12.0  # SD-04: kilit glifi ile metin arası (>= 8 px)
const _FALLBACK_PORTRAIT := "res://assets/ui/portre-seviye-atlama.png"


func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.1f" % v).replace(".", ",")


func _refresh_state() -> void:
	var st := select_button_state()
	var c := _data.get_character(_focus) if _data != null else null
	_lock_ring.visible = st == SelectState.LOCKED
	stage.modulate = Color(0.5, 0.5, 0.5, 1.0) if st == SelectState.LOCKED else Color.WHITE
	_reason.text = ""
	match st:
		SelectState.SELECT:
			select_button.text = "SEÇ"
			select_button.theme_type_variation = &""
			select_button.disabled = false
			select_button.accessibility_name = "Seç"
			chip_label.text = ""
			_style_chip(SelectState.SELECT)
			_style_select(false, false)
		SelectState.SELECTED:
			select_button.text = "✓ SEÇİLİ"
			select_button.theme_type_variation = &""
			select_button.disabled = false
			select_button.accessibility_name = "Seçili"
			chip_label.text = "✓ SEÇİLİ"
			chip_label.add_theme_color_override(&"font_color", UiKit.AMBER)
			_style_chip(SelectState.SELECTED)
			_style_select(true, false)
		_:
			select_button.text = "KİLİTLİ"
			select_button.disabled = false
			var why := CharacterRoster.lock_reason(c, _data) if c != null else ""
			_reason.text = why
			chip_label.text = "KİLİTLİ"
			chip_label.add_theme_color_override(&"font_color", UiKit.BRONZ_300)
			_style_chip(SelectState.LOCKED)
			select_button.accessibility_name = "%s, kilitli. %s" % [_display_name(_focus), why]
			_style_select(false, true)
	_place_name_chip.call_deferred()


## K-05: ad yanı çip kapsül (mor zemin + kenar); kilitli çipte soluna çizili asma kilit.
func _style_chip(st: int) -> void:
	if st == SelectState.SELECT:
		chip_label.remove_theme_stylebox_override(&"normal")
		_chip_lock.visible = false
		return
	var locked := st == SelectState.LOCKED
	var sb := UiKit.stylebox(UiKit.MOR_800, UiKit.KAHVE_500 if locked else UiKit.AMBER, 3, 999)
	sb.content_margin_left = CHIP_PAD_X + (CHIP_LOCK_W + CHIP_LOCK_GAP if locked else 0.0)
	sb.content_margin_right = CHIP_PAD_X
	sb.content_margin_top = CHIP_PAD_Y
	sb.content_margin_bottom = CHIP_PAD_Y
	chip_label.add_theme_stylebox_override(&"normal", sb)
	chip_label.reset_size()  # SD-04: eski genişlikte ortalanmış metin kilide binmesin
	_chip_lock.visible = locked
	_chip_lock.position = Vector2(CHIP_PAD_X, CHIP_PAD_Y + 4.0)


## SEÇİLİ: mor_700 zemin + 5 px amber kenar + ışıma, amber metin; KİLİTLİ: mor_800 + kahve_500 kenar, metin kemik_300.
func _style_select(is_selected: bool, locked: bool) -> void:
	var sb: StyleBoxFlat
	var fg := UiKit.KEMIK_100
	if is_selected:
		sb = UiKit.stylebox(UiKit.MOR_700, UiKit.AMBER, 5, 18)
		sb.shadow_color = Color(UiKit.AMBER, 0.45)
		sb.shadow_size = 22
		fg = UiKit.AMBER
	elif locked:
		sb = UiKit.stylebox(UiKit.MOR_800, UiKit.KAHVE_500, 4, 18)
		sb.content_margin_bottom = 56.0
		fg = UiKit.KEMIK_300
	else:
		# K-02: SEÇİLİ'den dönünce odak (focus) stili de temizlenir; yoksa odaktaki SEÇ mor/amber kalır.
		for st in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			select_button.remove_theme_stylebox_override(st)
		select_button.remove_theme_color_override(&"font_color")
		select_button.remove_theme_color_override(&"font_focus_color")
		return
	for st in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		select_button.add_theme_stylebox_override(st, sb)
	select_button.add_theme_color_override(&"font_color", fg)
	select_button.add_theme_color_override(&"font_focus_color", fg)  # K-04: odakta da amber
	select_button.add_theme_color_override(&"font_hover_color", fg)
	select_button.add_theme_color_override(&"font_pressed_color", fg)
	select_button.add_theme_color_override(&"font_disabled_color", fg)


func _rebuild_cards() -> void:
	for c in cards:
		c.queue_free()
	cards.clear()
	for id in _ids:
		var card := _make_card(id)
		_strip_row.add_child(card)
		cards.append(card)
	# Ortalı; sığmayan kartlarda kaydırma (anında yapışma).
	var content := _ids.size() * CARD_W + maxi(_ids.size() - 1, 0) * CARD_GAP
	_strip_row.custom_minimum_size.x = maxf(content, COL_W)
	_strip_row.alignment = BoxContainer.ALIGNMENT_CENTER


func _make_card(id: StringName) -> Button:
	var c := _data.get_character(id)
	var b := Button.new()
	b.name = "Card_%s" % id
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.add_theme_stylebox_override(&"normal", UiKit.stylebox(UiKit.MOR_800, UiKit.BRONZ_700, 4, 18))
	b.pressed.connect(set_focus_id.bind(id))
	var tex := UiKit.texture(c.portrait) if c != null and c.portrait != "" else null
	if tex == null:
		tex = UiKit.texture(_FALLBACK_PORTRAIT)  # K-03: sahne ile aynı varsayılan portre kırpması
	if tex != null:
		var pr := TextureRect.new()
		pr.name = "Face"
		pr.texture = tex
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_SCALE
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Yüz kırpması: genişliğe sığdır, üstten hizala.
		pr.size = Vector2(CARD_W * 1.5, CARD_W * 1.5 * 1.5)
		pr.position = Vector2(-CARD_W * 0.25, -8.0)
		if c != null and c.placeholder:
			pr.self_modulate = PLACEHOLDER_TINT
		b.add_child(pr)
		if c != null and c.placeholder:
			b.add_child(_monogram(c, 120))
	var scrim := ColorRect.new()
	scrim.color = Color(UiKit.VOID, 0.7)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.size = Vector2(CARD_W, 64)
	scrim.position = Vector2(0, CARD_H - 64.0)
	b.add_child(scrim)
	var nm := UiKit.label(UiKit.character_upper(c), &"LabelTimer", 28)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size = Vector2(CARD_W, 40)
	nm.position = Vector2(0, CARD_H - 52.0)
	nm.clip_text = true
	b.add_child(nm)
	var ring := Panel.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(ring)
	b.add_child(ring)
	var badge := Control.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	return b


## Yer tutucu karakterin baş harfi (monogram); kartta ve sahnede portrenin üstüne biner.
func _monogram(c: CharacterDef, px: int) -> Label:
	var m := UiKit.label(UiKit.character_upper(c).substr(0, 1), &"LabelTitle", px, UiKit.KEMIK_100)
	m.name = "Monogram"
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = Vector2(CARD_W, px * 1.3)
	m.position = Vector2(0, (CARD_H - 64.0 - px * 1.3) * 0.5)
	m.modulate.a = 0.85
	return m


func _refresh_cards() -> void:
	for i in cards.size():
		var id := _ids[i]
		var card := cards[i]
		var c := _data.get_character(id)
		var locked := c != null and not CharacterRoster.is_unlocked(c, _store)
		var focus := id == _focus
		var border := UiKit.BRONZ_300 if focus else (UiKit.KAHVE_500 if locked else UiKit.BRONZ_700)
		var sb := UiKit.stylebox(Color(0, 0, 0, 0), border, 6 if focus else 4, 18)
		if focus:
			sb.shadow_color = Color(UiKit.AMBER, 0.4)
			sb.shadow_size = 18
		(card.get_node("Ring") as Panel).add_theme_stylebox_override(&"panel", sb)
		card.modulate = Color(0.55, 0.55, 0.55) if locked else Color.WHITE
		var name_text := _display_name(id)
		var badge := card.get_node("Badge") as Control
		for ch in badge.get_children():
			ch.free()
		if id == _selected:
			var bg := _BadgeDot.new(UiKit.AMBER)
			bg.position = Vector2(CARD_W - 68.0, 10.0)
			badge.add_child(bg)
			bg.add_child(UiKit.Glyph.new(&"check", UiKit.BORDO_900, 40.0))
			bg.get_child(0).position = Vector2(8, 8)
			card.accessibility_name = "%s, seçili" % name_text
		elif locked:
			var bg := _BadgeDot.new(UiKit.MOR_900)
			bg.position = Vector2(CARD_W - 68.0, 10.0)
			badge.add_child(bg)
			card.accessibility_name = (
				"%s, kilitli. %s" % [name_text, CharacterRoster.lock_reason(c, _data)]
			)
		else:
			card.accessibility_name = name_text


func _scroll_to_focus() -> void:
	var i := _ids.find(_focus)
	if i < 0 or not is_inside_tree():
		return
	var x := i * (CARD_W + CARD_GAP)
	var view := _strip.size.x
	var cur := _strip.scroll_horizontal
	if x < cur:
		_strip.scroll_horizontal = int(x)
	elif x + CARD_W > cur + view:
		_strip.scroll_horizontal = int(x + CARD_W - view)


## V4: eski sahne solar + 40 px kayar, yenisi gelir (260 ms, cubic-out).
func _crossfade(dir: int) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if _swap_tween != null and _swap_tween.is_valid():
		_swap_tween.kill()
	var d := float(dir) if dir != 0 else 1.0
	_ghost.modulate.a = 1.0
	_portrait.modulate.a = 0.0
	_swap_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	_swap_tween.tween_property(_ghost, "modulate:a", 0.0, ShowcaseMotion.CROSSFADE_SEC)
	_swap_tween.tween_property(_portrait, "modulate:a", 1.0, ShowcaseMotion.CROSSFADE_SEC)
	_swap_tween.tween_property(
		_ghost, "position:x", _ghost.position.x - d * SWAP_SLIDE, ShowcaseMotion.CROSSFADE_SEC
	)


## V5: ✓ rozeti ve düğme geçişi; titreşim açıksa 30 ms (V2Characters yapar).
func _pulse_select() -> void:
	if not is_inside_tree():
		return
	var i := _ids.find(_focus)
	if i < 0:
		return
	var badge := cards[i].get_node("Badge") as Control
	badge.pivot_offset = Vector2(CARD_W - 40.0, 38.0)
	badge.scale = Vector2.ONE * 1.25
	create_tween().tween_property(badge, "scale", Vector2.ONE, 0.18)


func _on_stage_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		var down: bool = ev.pressed
		var x: float = ev.position.x
		if down:
			_dragging = true
			_drag_from = x
		elif _dragging:
			_dragging = false
			var dx := x - _drag_from
			if absf(dx) > 90.0:
				_step(-1 if dx > 0.0 else 1)


func _step(dir: int) -> void:
	set_focus_id(CharacterRoster.step(_ids, _focus, dir))


func _unhandled_input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or _ids.size() < 2:
		return
	if ev.is_action_pressed(&"ui_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed(&"ui_right"):
		_step(1)
		get_viewport().set_input_as_handled()


class _LockGlyph:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(CharactersScreen.CHIP_LOCK_W, 30)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := UiKit.BRONZ_300
		draw_arc(Vector2(13, 11), 7.0, PI, TAU, 14, c, 3.0, true)
		draw_rect(Rect2(3, 12, 20, 16), c)
		draw_rect(Rect2(11, 17, 4, 6), UiKit.MOR_800)


class _BadgeDot:
	extends Control
	var color: Color

	func _init(c: Color) -> void:
		color = c
		custom_minimum_size = Vector2(56, 56)
		size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 28.0, color)
		draw_arc(size * 0.5, 28.0, 0.0, TAU, 32, UiKit.BRONZ_500, 3.0, true)
		if color == UiKit.MOR_900:  # kilit rozeti
			var c := size * 0.5
			draw_rect(Rect2(c + Vector2(-11, -2), Vector2(22, 17)), UiKit.KEMIK_300)
			draw_arc(c + Vector2(0, -2), 7.0, PI, TAU, 12, UiKit.KEMIK_300, 3.0, true)


class _LockRing:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 120.0, Color(UiKit.VOID, 0.6))
		draw_arc(c, 118.0, 0.0, TAU, 48, UiKit.KEMIK_300, 6.0, true)
		# Kilit: gövde + kulp
		draw_rect(Rect2(c + Vector2(-44, -6), Vector2(88, 72)), UiKit.KEMIK_300)
		draw_arc(c + Vector2(0, -6), 30.0, PI, TAU, 24, UiKit.KEMIK_300, 12.0, true)
		draw_circle(c + Vector2(0, 28), 9.0, UiKit.VOID)
