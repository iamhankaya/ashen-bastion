class_name ResultAnim
extends RefCounted
## Sonuç ekranı animasyonu (R5b): skor sayımı, döküm satırı girişi, başarım çipi kayması, rekor damgası/hap. Gövdeler
## `result_screen.gd`den AYNEN taşındı; zaman çizelgesi `ResultTimeline`dadır. `host` ResultScreen'dir ama tipi BİLİNMEZ
## (class_name döngüsü yok): alanlara dinamik erişilir. Durum tutmaz.

## v2.0 (B4) başarım çipi: döküm satırlarından sonra 1100 ms'de 200 ms kayma-giriş.
const CHIP_AT := 1.1
const CHIP_IN := 0.2
const CHIP_SLIDE := 24.0
const EMPTY_ROW_ALPHA := 0.35
const STAMP_SEC := 0.28
const STAMP_SCALE := 1.3
const SHINE_SEC := 0.6
const PILL_SEC := 0.2
const ROW_SLIDE_PX := 40.0


static func apply(host, t: float) -> void:
	var done := host._skip_t >= 0.0
	var k := 1.0 if done else ResultTimeline.count_progress(t)
	host.score_value.text = UiKit.format_thousands(roundi(float(host._hero_total) * k))
	host.time_value.text = UiKit.format_time(float(host.stats.get("time", 0.0)) * k)
	host.level_value.text = str(roundi(float(host.stats.get("level", 1)) * k))
	host.kills_value.text = UiKit.format_thousands(roundi(float(host.stats.get("kills", 0)) * k))
	for i in host.breakdown_rows.size():
		var rp := 1.0 if done else ResultTimeline.row_progress(i, t)
		var row: Control = host.breakdown_rows[i]
		var target: int = host._row_targets[i] if i < host._row_targets.size() else 0
		var val := row.get_node("Value") as Label
		if host._row_dash[i]:
			val.text = "—"
		else:
			var n := roundi(float(target) * rp)
			val.text = ("+" if host._row_plus[i] else "") + UiKit.format_thousands(n)
		var a := rp if not host._row_dim[i] else rp * EMPTY_ROW_ALPHA
		row.modulate.a = a
		row.position.y = (
			ResultLayout.Y_BREAKDOWN
			+ host._dy
			+ host._bdy
			+ ResultLayout.BREAKDOWN_PAD
			+ float(i) * ResultLayout.ROW_H
			+ (1.0 - rp) * ROW_SLIDE_PX
		)
	apply_chip(host, t, done)
	apply_stamp(host, t, done)
	var on: bool = host.buttons_enabled()
	host.replay_button.disabled = not on
	host.menu_button.disabled = not on


static func apply_chip(host, t: float, done: bool) -> void:
	if host._new_names.is_empty():
		return
	var k := 1.0 if done else ResultTimeline.cubic_out(clampf((t - CHIP_AT) / CHIP_IN, 0.0, 1.0))
	host.achievement_chip.modulate.a = k
	host.achievement_chip.position.y = (
		host._chip_y
		+ host._dy
		+ host._bdy
		+ (1.0 - k) * ResultLayout.chip_slide(host._tier, CHIP_SLIDE)
	)


static func apply_stamp(host, t: float, done: bool) -> void:
	var at := ResultTimeline.stamp_at()
	if host.record_kind == &"record":
		var dt := t - at
		if done or dt >= 0.0:
			var k := 1.0 if done else ResultTimeline.cubic_out(dt / STAMP_SEC)
			var sc := lerpf(STAMP_SCALE, 1.0, k)
			host.record_band.scale = Vector2(sc, sc)
			host.record_band.modulate.a = 1.0
			host.record_note.modulate.a = 1.0
			if not host._stamped:
				host._stamped = true
				host.record_stamped.emit()
			host._shine.visible = not done and dt < SHINE_SEC
			if host._shine.visible:
				host._shine.size = Vector2(120.0, ResultLayout.BAND_H)
				host._shine.position = Vector2(lerpf(-120.0, host._w, dt / SHINE_SEC), 0)
		else:
			host.record_band.scale = Vector2(STAMP_SCALE, STAMP_SCALE)
			host.record_band.modulate.a = 0.0
			host.record_note.modulate.a = 0.0
			host._shine.visible = false
	elif host.record_kind == &"top10":
		var p := 1.0 if done else clampf(t / PILL_SEC, 0.0, 1.0)
		host.record_pill.modulate.a = p
		host.record_pill.scale = Vector2.ONE * lerpf(0.9, 1.0, p)
		host.record_note.modulate.a = 1.0
	else:
		host.record_note.modulate.a = 1.0 if done else clampf(t / PILL_SEC, 0.0, 1.0)
