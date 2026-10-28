class_name ResultBlocks
extends RefCounted
## Sonuç ekranı blokları (R5b): düğüm kurulumu (başlık, skor, rekor bandı, döküm, şerit, çip, Kolay notu, kombo paneli,
## düğmeler) ve içerik doldurma. Gövdeler `result_screen.gd`den AYNEN taşındı (düğüm adları ve ekleme sırası aynı; sahne
## ağacı ve yerleşim karakterizasyonu rf_ui_result_rects). `host` ResultScreen'dir ama tipi BİLİNMEZ (class_name döngüsü
## yok): alanlara dinamik erişilir. Durum tutmaz.


static func build(host) -> void:
	host._bg = ColorRect.new()
	host._bg.color = UiKit.VOID
	host._bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(host._bg)
	host.add_child(host._bg)
	host.glow = TextureRect.new()
	host.glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.glow.stretch_mode = TextureRect.STRETCH_SCALE
	host.glow.anchor_right = 1.0
	host.glow.offset_bottom = 1100.0
	host.add_child(host.glow)

	host.title_label = UiKit.label("OYUN BİTTİ", &"LabelTitle", 104)
	host.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.title_label.add_theme_constant_override(&"shadow_offset_y", 5)
	host.add_child(host.title_label)
	host.sub_label = UiKit.label(ResultModel.LOST_SUB, &"", 34, UiKit.KEMIK_300)
	host.sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(host.sub_label)
	host.divider = UiKit.divider()
	host.add_child(host.divider)

	host.score_caption = UiKit.label("SKOR", &"LabelAccent", 34)
	host.score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(host.score_caption)
	host.score_value = UiKit.label("0", &"LabelTitle", 120)
	host.score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.score_value.add_theme_constant_override(&"shadow_offset_y", 5)
	host.add_child(host.score_value)

	build_record(host)
	build_breakdown(host)
	build_strip(host)
	build_chip(host)
	build_run_info(host)

	host.combo_panel = PanelContainer.new()
	host.combo_panel.theme_type_variation = &"PanelRaised"
	host.combo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# kademeler panel üst/alt boşluğunu değiştirir: tema kutusunun kopyası (kenar/renk aynı)
	host._panel_sb = ResultFit.stone_box()
	host.combo_panel.add_theme_stylebox_override(&"panel", host._panel_sb)
	var cv := VBoxContainer.new()
	host.combo_cv = cv
	cv.add_theme_constant_override(&"separation", 16)
	host.combo_title = UiKit.label("KURULAN KOMBOLAR", &"LabelAccent", 32)
	cv.add_child(host.combo_title)
	host.combo_box = VBoxContainer.new()
	host.combo_box.add_theme_constant_override(&"separation", 0)
	cv.add_child(host.combo_box)
	host.combo_panel.add_child(cv)
	host.add_child(host.combo_panel)

	host.replay_button = UiKit.button("TEKRAR OYNA", &"primary", ResultLayout.REPLAY_H)
	host.replay_button.add_theme_font_size_override(&"font_size", 52)
	host.replay_button.pressed.connect(func() -> void: host.replay_requested.emit())
	host.add_child(host.replay_button)
	host.menu_button = UiKit.button("ANA MENÜ", &"secondary", ResultLayout.MENU_H)
	host.menu_button.pressed.connect(func() -> void: host.menu_requested.emit())
	host.add_child(host.menu_button)
	ResultLayout.apply_fonts(host)
	ResultLayout.layout(host)


static func build_record(host) -> void:
	host.record_band = Control.new()
	host.record_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.record_band.clip_contents = true
	host.record_band.visible = false
	host.record_band.draw.connect(host._draw_band)
	host.add_child(host.record_band)
	host.record_label = UiKit.label("YENİ REKOR", &"LabelTitle", 56, UiKit.AMBER)
	host.record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host.record_label.add_theme_constant_override(&"shadow_offset_y", 3)
	host.record_band.add_child(host.record_label)
	for i in 2:
		var star := UiKit.Glyph.new(&"star", UiKit.AMBER, 48.0)
		host.record_band.add_child(star)
		host.record_stars.append(star)
	host._shine = ColorRect.new()
	host._shine.color = Color(UiKit.KEMIK_100, 0.35)
	host._shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._shine.visible = false
	host.record_band.add_child(host._shine)
	host.record_pill = UiKit.label("", &"LabelTimer", 38)
	host.record_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.record_pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host.record_pill.add_theme_stylebox_override(
		&"normal", UiKit.stylebox(Color(UiKit.VOID, 0.5), UiKit.BRONZ_500, 4, 24)
	)
	host.record_pill.visible = false
	host.add_child(host.record_pill)
	host.record_note = UiKit.label("", &"", 30, UiKit.KEMIK_500)
	host.record_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(host.record_note)


static func build_breakdown(host) -> void:
	host.breakdown_panel = PanelContainer.new()
	host.breakdown_panel.add_theme_stylebox_override(&"panel", ResultFit.stone_box())
	host.breakdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(host.breakdown_panel)
	var defs := [
		["hud-oldurme", "Öldürme"],
		["hud-xp", "Seri çarpanı"],
		["hud-patlama", "Evrim bonusu"],
		["hud-sure", "Hayatta kalma"],
		["hud-can", "Lord bonusu"],
	]
	for d in defs:
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.name = "Icon"
		ic.texture = UiKit.hud_icon(d[0])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(0, 18)
		ic.size = Vector2(48, 48)
		row.add_child(ic)
		var l := UiKit.label(d[1], &"", 32, UiKit.KEMIK_100)
		l.name = "Name"
		l.add_theme_font_override(&"font", UiKit.font_semibold())
		l.position = Vector2(72, 0)
		l.size = Vector2(330, ResultLayout.ROW_H)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		var det := UiKit.label("", &"", ResultLayout.DETAIL_FONT, UiKit.KEMIK_500)
		det.name = "Detail"
		det.add_theme_font_override(&"font", UiKit.font_semibold())
		det.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		det.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(det)
		var v := UiKit.label("0", &"LabelTimer", 44)
		v.name = "Value"
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(v)
		host.add_child(row)
		host.breakdown_rows.append(row)


static func build_strip(host) -> void:
	host.strip_panel = PanelContainer.new()
	host.strip_panel.add_theme_stylebox_override(&"panel", ResultFit.stone_box())
	host.strip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(host.strip_panel)
	var defs := [["hud-sure", "Süre"], ["hud-xp", "Seviye"], ["hud-oldurme", "Öldürme"]]
	var vals: Array[Label] = []
	for d in defs:
		var col := Control.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.name = "Icon"
		ic.texture = UiKit.hud_icon(d[0])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ic)
		var v := UiKit.label("0", &"LabelTimer", 48)
		v.name = "Value"
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(v)
		var cap := UiKit.label(d[1], &"", 26, UiKit.KEMIK_300)
		cap.name = "Caption"
		cap.add_theme_font_override(&"font", UiKit.font_semibold())
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)
		host.add_child(col)
		host._strip_nodes.append(col)
		vals.append(v)
	host.time_value = vals[0]
	host.level_value = vals[1]
	host.kills_value = vals[2]


static func build_chip(host) -> void:
	host.achievement_chip = Panel.new()
	host.achievement_chip.name = "AchievementChip"
	host.achievement_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.achievement_chip.add_theme_stylebox_override(
		&"panel", UiKit.stylebox(UiKit.MOR_800, UiKit.AMBER, 4, 14)
	)
	host.achievement_chip.visible = false
	host.add_child(host.achievement_chip)
	host.chip_star = UiKit.Glyph.new(&"star", UiKit.AMBER, 44.0)
	host.chip_star.position = Vector2(28.0, (ResultLayout.CHIP_H - 44.0) * 0.5)
	host.chip_star.size = Vector2(44.0, 44.0)
	host.achievement_chip.add_child(host.chip_star)
	host.chip_title = UiKit.label("", &"LabelTimer", 30, UiKit.AMBER)
	host.chip_title.name = "Title"
	host.chip_title.position = Vector2(92.0, 8.0)
	host.chip_title.size = Vector2(300.0, 40.0)
	host.achievement_chip.add_child(host.chip_title)
	host.chip_names = UiKit.label("", &"", 28, UiKit.KEMIK_300)
	host.chip_names.name = "Names"
	host.chip_names.add_theme_font_override(&"font", UiKit.font_semibold())
	host.chip_names.position = Vector2(92.0, 48.0)
	host.chip_names.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host.chip_names.clip_text = true
	host.achievement_chip.add_child(host.chip_names)


static func build_run_info(host) -> void:
	host.chip_holder = Control.new()
	host.chip_holder.name = "RunChips"
	host.chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.chip_holder.visible = false
	host.add_child(host.chip_holder)
	host.easy_note = Panel.new()
	host.easy_note.name = "EasyNote"
	host.easy_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.easy_note.add_theme_stylebox_override(
		&"panel", UiKit.stylebox(Color(UiKit.VOID, 0.5), UiKit.BRONZ_700, 2, 6)
	)
	host.easy_note.visible = false
	host.add_child(host.easy_note)
	var bar := ColorRect.new()
	bar.color = UiKit.AMBER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2.ZERO
	bar.size = Vector2(6.0, ResultLayout.NOTE_H)
	host.easy_note.add_child(bar)
	var warn := RunStrip.WarnGlyph.new(40.0)
	warn.position = Vector2(30.0, (ResultLayout.NOTE_H - 40.0) * 0.5)
	host.easy_note.add_child(warn)
	var l := UiKit.label(ResultModel.EASY_NOTE, &"", 28, UiKit.KEMIK_100)
	l.name = "Text"
	l.add_theme_font_override(&"font", UiKit.font_semibold())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(92.0, 0.0)
	host.easy_note.add_child(l)
	host.easy_note.accessibility_name = "Uyarı: " + ResultModel.EASY_NOTE


## Koşu çipleri ve Kolay notu `stats.mode/diff/lords_killed`'dan; bilinmiyorsa (eski çağrılar) ikisi de gizli.
static func fill_run(host, profiles: Callable) -> void:
	host.run_mode = StringName(str(host.stats.get("mode", "")))
	host.run_diff = StringName(str(host.stats.get("diff", "")))
	var known := RunStrip.MODE_ORDER.has(host.run_mode) and RunStrip.DIFF_ORDER.has(host.run_diff)
	if host._run_chips != null:
		host.chip_holder.remove_child(host._run_chips)
		host._run_chips.queue_free()
		host._run_chips = null
	host.chip_holder.visible = known
	host.easy_note.visible = known and host.run_diff == &"easy"
	if not known:
		return
	var row := RunStrip.make_chips(host.run_mode, host.run_diff, profiles.call())
	var lords := int(host.stats.get("lords_killed", 0))
	if host.run_mode == &"endless" and lords > 0:
		var lord_chip := RunStrip.make_chip(
			UiKit.Glyph.new(&"star", UiKit.AMBER, 30.0), "LORD ×%d" % lords
		)
		lord_chip.name = "LordChip"
		lord_chip.accessibility_name = "%d Lord devrildi." % lords
		row.add_child(lord_chip)
	var holder_row: Control = ResultFit.wrap_chips(row) if host._big else row
	host.chip_holder.add_child(holder_row)
	holder_row.size = Vector2(host._w, ResultLayout.chip_h(host))
	host._run_chips = holder_row


## Görünen kombo satırları `_shown_combos` kadar (sabit tavan); taşan kombolar "+N" olur. Satır/aralık ölçüsü `_tier`dir.
static func render_combos(host) -> void:
	var combos: Array[Dictionary] = host._combos_data
	for c in host.combo_box.get_children():
		host.combo_box.remove_child(c)
		c.queue_free()
	if combos.is_empty():
		var e := UiKit.label(ResultModel.EMPTY_TEXT, &"", 40 if host._big else 32, UiKit.KEMIK_300)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(host._w - 100.0, 0)
		host.combo_box.add_child(e)
		return
	for i in mini(combos.size(), host._shown_combos):
		host.combo_box.add_child(combo_row(host, combos[i]))
	if combos.size() > host._shown_combos:
		var more := UiKit.label(
			"+%d" % (combos.size() - host._shown_combos),
			&"LabelTimer",
			42 if host._big else 36,
			UiKit.BRONZ_300
		)
		more.custom_minimum_size = Vector2(0, ResultFit.TIERS[host._tier][ResultFit.T_MORE])
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		host.combo_box.add_child(more)


static func combo_row(host, c: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ResultFit.TIERS[host._tier][ResultFit.T_ROW])
	row.add_theme_constant_override(&"separation", 27)
	var slot := SkillSlot.new(&"evolution", 80.0)
	slot.set_skill(StringName(str(c.get("id", ""))), 0, str(c.get("icon", "")), true)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", 0)
	v.add_child(
		UiKit.label(UiKit.upper_tr(str(c.get("name", ""))), &"LabelTimer", 40 if host._big else 36)
	)
	v.add_child(UiKit.label(str(c.get("pair", "")), &"", 30 if host._big else 26, UiKit.KEMIK_300))
	row.add_child(v)
	return row


static func draw_band(band: Control) -> void:
	var r := Rect2(Vector2.ZERO, band.size)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([UiKit.BORDO_700, UiKit.BORDO_500, UiKit.BORDO_700])
	band.draw_rect(r, UiKit.BORDO_900)
	var steps := 24
	for i in steps:
		var k0 := float(i) / steps
		var c := g.sample(k0)
		band.draw_rect(Rect2(r.size.x * k0, 0, r.size.x / steps + 1.0, r.size.y), Color(c, 0.9))
	band.draw_rect(Rect2(0, 0, r.size.x, 4), UiKit.AMBER)
	band.draw_rect(Rect2(0, r.size.y - 4, r.size.x, 4), UiKit.AMBER)


static func fill_record(host) -> void:
	host.record_kind = ResultModel.record_kind(host.last_record)
	var rank := int(host.last_record.get("rank", 0))
	host.record_band.visible = host.record_kind == &"record"
	host.record_pill.visible = host.record_kind == &"top10"
	host.record_note.text = ""
	host.record_note.accessibility_name = ""
	match host.record_kind:
		&"record":
			var prev := int(host.last_record.get("previous_best", 0))
			host.record_note.text = (
				"Önceki en iyi: %s" % UiKit.format_thousands(prev) if prev > 0 else ""
			)
			prefix_rank_line(host, rank)
		&"top10":
			host.record_pill.text = "EN İYİ 10'A GİRDİN · %d. SIRA" % rank
			prefix_rank_line(host, rank)
		&"outside":
			host.record_note.text = (
				"10. sıra için gereken: %s"
				% UiKit.format_thousands(int(host.last_record.get("needed_for_top10", 0)))
			)


## v2.1: not satırının başına "Mod · Zorluk listesinde N. sıra" eklenir (varsa eski metin " · " ile sürer).
static func prefix_rank_line(host, rank: int) -> void:
	var line := ResultModel.rank_line(host.run_mode, host.run_diff, rank)
	if line == "":
		return
	host.record_note.text = (
		line if host.record_note.text == "" else line + " · " + host.record_note.text
	)
	host.record_note.accessibility_name = (
		"%s modda, %s listesinde %s sıra."
		% [
			RunStrip.MODE_TITLES[host.run_mode],
			RunStrip.DIFF_TITLES[host.run_diff],
			ResultFit.spoken_rank(rank)
		]
	)


static func fill_rows(host) -> void:
	var rows := ResultModel.rows(host.stats, host.won)
	host._row_targets = rows["vals"]
	host._row_plus = rows["plus"]
	host._row_dim = rows["dim"]
	host._row_dash = rows["dash"]
	var details: Array[String] = rows["details"]
	for i in host.breakdown_rows.size():
		(host.breakdown_rows[i].get_node("Detail") as Label).text = details[i]


static func glow_texture(c: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(c, 0.45), Color(c, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(1.1, 0.75)
	t.width = 128
	t.height = 128
	return t
