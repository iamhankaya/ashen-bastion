class_name CatalogLoader
extends RefCounted
## GameData veri kökünü okur: dosya başına kayıtlar (characters/skills/enemies), waves/ruins, v1.1/v2.0 tabloları.
## Okuma hataları `g.load_errors`'a gider (validate() çıktısının başı).


static func load_all(g: GameData) -> void:
	g._raw_characters = read_dir(g, "characters")
	g._raw_skills = read_dir(g, "skills")
	g._raw_enemies = read_dir(g, "enemies")
	g._raw_metrics = read_dir(g, "achievements")
	for e in g._raw_metrics:
		if e["data"] is Dictionary:
			g._stat_metrics.append(e["data"])
	var wp := g.root_dir.path_join("waves.json")
	if FileAccess.file_exists(wp):
		var r := read_json(g, wp, "waves.json")
		g._raw_waves = r.get("data")
		g._waves_failed = r.get("failed", false)
	else:
		g.load_errors.append("[missing_file] waves.json: dosya yok")
	if g._raw_waves is Dictionary:
		g.waves = g._raw_waves
	var rp := g.root_dir.path_join("ruins.json")
	if FileAccess.file_exists(rp):
		var rr := read_json(g, rp, "ruins.json")
		g._raw_ruins = rr.get("data")
		g._ruins_failed = rr.get("failed", false)
		if g._raw_ruins is Array:
			for x in g._raw_ruins:
				if x is Dictionary:
					g.ruins.append(x)
	DataV11.load_tables(g)
	DataV2.load_achievements(g, g.root_dir)
	for e in g._raw_characters:
		var d: Variant = e["data"]
		if (
			d is Dictionary
			and GameData._valid_id(d.get("id"))
			and not g._characters.has(StringName(d["id"]))
		):
			var c := CharacterDef.from_dict(d)
			g._characters[c.id] = c
			g.character_ids.append(c.id)
	g._sort_character_ids()
	for e in g._raw_skills:
		var d: Variant = e["data"]
		if (
			d is Dictionary
			and GameData._valid_id(d.get("id"))
			and not g._skills.has(StringName(d["id"]))
		):
			var s := SkillDef.from_dict(d)
			g._skills[s.id] = s
			g.skill_ids.append(s.id)
	for e in g._raw_enemies:
		var d: Variant = e["data"]
		if (
			d is Dictionary
			and GameData._valid_id(d.get("id"))
			and not g._enemies.has(StringName(d["id"]))
		):
			var en := EnemyDef.from_dict(d)
			g._enemies[en.id] = en
			g.enemy_ids.append(en.id)


static func read_dir(g: GameData, sub: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var dir := g.root_dir.path_join(sub)
	if not DirAccess.dir_exists_absolute(dir):
		return res  # eksik dizin = boş (temiz checkout'ta boş dizinler git'te yoktur)
	var files := DirAccess.get_files_at(dir)
	var names: Array[String] = []
	for f in files:
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		var rel := sub + "/" + f
		var r := read_json(g, dir.path_join(f), rel)
		res.append({"file": rel, "data": r.get("data"), "failed": r.get("failed", false)})
	return res


static func read_json(g: GameData, path: String, rel: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		g.load_errors.append(
			"[bad_json] %s: JSON okunamadı (satır %d)" % [rel, json.get_error_line()]
		)
		return {"data": null}
	return {"data": json.data}
