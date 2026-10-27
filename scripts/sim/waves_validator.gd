class_name WavesValidator
extends RefCounted
## waves.json doğrulaması (GameData.validate çağırır; RuinsValidator kalıbı). Kurallar: docs/data-schema.md


static func run(g: GameData, out: PackedStringArray) -> void:
	if (
		g._waves_failed
		or (g._raw_waves == null and not FileAccess.file_exists(g.root_dir.path_join("waves.json")))
	):
		return  # missing_file / bad_json zaten bildirildi
	if not (g._raw_waves is Dictionary):
		GameData._err(out, "not_object", "waves.json", "kök nesne olmalı")
		return
	_root(g, out, g._raw_waves)


## v2.1: ölçeklenmiş (WaveScaler) ya da türetilmiş waves sözlüğünü aynı kurallarla doğrular; boş dizi = geçerli.
static func validate_dict(waves: Dictionary, g: GameData) -> Array:
	var out := PackedStringArray()
	_root(g, out, waves)
	return Array(out)


static func _root(g: GameData, out: PackedStringArray, w: Dictionary) -> void:
	for k in w.keys():
		if not ["rows", "after_lord", "end_time"].has(k):
			GameData._err(out, "wave_unknown_key", "waves.json", "bilinmeyen anahtar '%s'" % k)
	var end_time := GameData.DEFAULT_END_TIME
	if w.has("end_time"):
		if GameData._num(out, "waves.json", w, "end_time", 60, 7200):
			end_time = float(w["end_time"])
	if not w.has("rows"):
		GameData._err(out, "missing_field", "waves.json", "'rows' yok")
	elif not (w["rows"] is Array):
		GameData._err(out, "bad_type", "waves.json", "'rows' dizi olmalı")
	else:
		for i in (w["rows"] as Array).size():
			_row(g, out, "waves.json rows[%d]" % i, w["rows"][i], end_time)
	if w.has("after_lord"):
		if not (w["after_lord"] is Dictionary):
			GameData._err(out, "bad_type", "waves.json", "'after_lord' nesne olmalı")
		else:
			var al: Dictionary = w["after_lord"]
			for k in al.keys():
				if not ["piyade_rate_mult", "karga_stop"].has(k):
					GameData._err(
						out,
						"wave_unknown_key",
						"waves.json after_lord",
						"bilinmeyen anahtar '%s'" % k
					)
			GameData._num(out, "waves.json after_lord", al, "piyade_rate_mult", 0, 1)
			if not al.has("karga_stop") or not (al["karga_stop"] is bool):
				GameData._err(out, "bad_type", "waves.json after_lord", "'karga_stop' bool olmalı")


static func _row(
	g: GameData, out: PackedStringArray, ctx: String, row: Variant, end_time: float
) -> void:
	if not (row is Dictionary):
		GameData._err(out, "not_object", ctx, "satır nesne olmalı")
		return
	var r: Dictionary = row
	if not r.has("kind") or not (r["kind"] is String) or not GameData.WAVE_KINDS.has(r["kind"]):
		GameData._err(out, "wave_kind", ctx, "'kind' rate|group|burst|boss olmalı")
		return
	var kind: String = r["kind"]
	var allowed: Array = ["kind", "type"]
	var type_ok := GameData._str(out, ctx, r, "type")
	var etype: EnemyDef = g._enemies.get(StringName(r["type"])) if type_ok else null
	if type_ok and etype == null:
		GameData._err(out, "unknown_enemy", ctx, "tür '%s' yok" % r["type"])
	match kind:
		"rate", "group":
			allowed.append_array(["from", "to", kind, "every"])
			var f_ok := GameData._num(out, ctx, r, "from", 0, end_time)
			var t_ok := GameData._num(out, ctx, r, "to", 0, end_time)
			if f_ok and t_ok and float(r["from"]) >= float(r["to"]):
				GameData._err(out, "wave_range", ctx, "'from' < 'to' olmalı")
			if kind == "rate":
				if (
					GameData._pair(out, ctx, r, "rate", 0, 1000)
					and float(r["rate"][0]) > float(r["rate"][1])
				):
					GameData._err(out, "wave_range", ctx, "'rate' [a,b] için a <= b olmalı")
			else:
				if (
					GameData._pair(out, ctx, r, "group", 1, 400)
					and float(r["group"][0]) > float(r["group"][1])
				):
					GameData._err(out, "wave_range", ctx, "'group' [a,b] için a <= b olmalı")
				GameData._pair(out, ctx, r, "every", 0.1, 600)
			if etype != null and not GameData.SPAWNABLE_AI.has(String(etype.ai)):
				GameData._err(
					out,
					"wave_enemy_ai",
					ctx,
					"'%s' (ai %s) rate/group ile doğmaz" % [etype.id, etype.ai]
				)
		"burst":
			allowed.append_array(["at", "count", "ring"])
			GameData._num(out, ctx, r, "at", 0, end_time)
			GameData._num(out, ctx, r, "count", 1, GameData.MAX_BURST_COUNT, true)
			if not r.has("ring") or not (r["ring"] is bool):
				GameData._err(out, "bad_type", ctx, "'ring' bool olmalı")
			if etype != null and not GameData.SPAWNABLE_AI.has(String(etype.ai)):
				GameData._err(
					out,
					"wave_enemy_ai",
					ctx,
					"'%s' (ai %s) burst ile doğmaz" % [etype.id, etype.ai]
				)
		"boss":
			allowed.append_array(["at", "warn"])
			var warn := 5.0
			if r.has("warn") and GameData._num(out, ctx, r, "warn", 0, 30):
				warn = float(r["warn"])
			if GameData._num(out, ctx, r, "at", 0, end_time):
				var at := float(r["at"])
				if at < warn:
					GameData._err(out, "wave_boss_time", ctx, "'at' >= 'warn' olmalı")
				if etype != null and etype.ai == &"lord" and not is_equal_approx(at, end_time):
					GameData._err(
						out, "wave_boss_time", ctx, "lord 'at' = end_time (%s) olmalı" % end_time
					)
				if etype != null and etype.ai == &"elite" and at >= end_time:
					GameData._err(out, "wave_boss_time", ctx, "elit 'at' < end_time olmalı")
			if etype != null and etype.ai != &"elite" and etype.ai != &"lord":
				GameData._err(out, "wave_enemy_ai", ctx, "boss türü elite|lord olmalı")
	for k in r.keys():
		if not allowed.has(k):
			GameData._err(out, "wave_unknown_key", ctx, "bilinmeyen anahtar '%s'" % k)
