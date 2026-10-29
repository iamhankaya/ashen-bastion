class_name CrossRefValidator
extends RefCounted
## GameData çapraz referans doğrulaması: evrim `requires` (beceri kayıtları yüklendikten sonra) ve "içerik
## tamamlandı" kuralları. Mesaj/sıra game_data.gd'deki eski gövdelerle aynıdır.

var g: GameData


func _init(p_data: GameData) -> void:
	g = p_data


## Yalnız kendi alanları geçerli evrimler (kayıtlar `_screen` çıktısıdır).
func evolutions(out: PackedStringArray, entries: Array[Dictionary]) -> void:
	var evo_targets := {}
	for e in entries:
		var d: Dictionary = e["data"]
		if d.get("kind") == "evolution" and d.get("requires") is Dictionary:
			_validate_requires(out, e["file"], d)
			var act: Variant = (d["requires"] as Dictionary).get("active")
			if act is String:
				if evo_targets.has(act):
					GameData._err(
						out,
						"dup_evolution",
						e["file"],
						"'%s' için ikinci evrim (%s)" % [act, evo_targets[act]]
					)
				else:
					evo_targets[act] = e["file"]


## Evrim 'requires' şekli ve referansları (tüm beceri kayıtları yüklendikten sonra).
func _validate_requires(out: PackedStringArray, file: String, d: Dictionary) -> void:
	var rq: Dictionary = d["requires"]
	var shape_ok := GameData._str(out, file + " requires", rq, "active")
	shape_ok = GameData._str(out, file + " requires", rq, "passive") and shape_ok
	shape_ok = (
		GameData._num(
			out, file + " requires", rq, "active_level", 1, GameData.MAX_LEVEL_LIMIT, true
		)
		and shape_ok
	)
	shape_ok = (
		GameData._num(
			out, file + " requires", rq, "passive_min_level", 1, GameData.MAX_LEVEL_LIMIT, true
		)
		and shape_ok
	)
	if not shape_ok:
		return
	var act: SkillDef = g._skills.get(StringName(rq["active"]))
	var pas: SkillDef = g._skills.get(StringName(rq["passive"]))
	if act == null:
		GameData._err(out, "requires_ref", file, "requires.active '%s' yok" % rq["active"])
	elif act.kind != SkillDef.KIND_ACTIVE:
		GameData._err(
			out, "requires_kind", file, "requires.active '%s' kind:active değil" % rq["active"]
		)
	elif int(rq["active_level"]) != act.max_level:
		GameData._err(
			out,
			"requires_level",
			file,
			"requires.active_level, '%s' max_level (%d) olmalı" % [act.id, act.max_level]
		)
	if pas == null:
		GameData._err(out, "requires_ref", file, "requires.passive '%s' yok" % rq["passive"])
	elif pas.kind != SkillDef.KIND_PASSIVE:
		GameData._err(
			out, "requires_kind", file, "requires.passive '%s' kind:passive değil" % rq["passive"]
		)
	elif int(rq["passive_min_level"]) > pas.max_level:
		GameData._err(
			out,
			"requires_level",
			file,
			"requires.passive_min_level, '%s' max_level (%d) üstünde" % [pas.id, pas.max_level]
		)


func complete(out: PackedStringArray) -> void:
	DataV11.validate_complete(g, out)
	var n := 0
	for s in g.skills_of_kind(SkillDef.KIND_ACTIVE):
		if s.tags.has(GameData.RHYTHM_TAG):
			n += 1
	if n < GameData.MIN_RHYTHM_ACTIVES:
		GameData._err(
			out,
			"rhythm_count",
			"skills",
			"'rhythm' etiketli aktif %d < %d" % [n, GameData.MIN_RHYTHM_ACTIVES]
		)
