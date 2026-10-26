class_name DataV2
extends RefCounted
## v2.0 veri yükleme ve doğrulama: data/achievements.json, karakterin yeni alanları (blurb, portrait, unlock,
## placeholder), F-013 atlas hücre sınırı. GameData bu sınıfı çağırır (DataV11 kalıbı: GameData dosyası gdlint 1000
## satır sınırında). Hata biçimi ve kodlar GameData'nın: "[kod] bağlam: açıklama". Şema: docs/data-schema.md

const ACH_FILE := "achievements.json"
const ACH_KEYS: PackedStringArray = [
	"id", "name", "desc", "stat", "target", "scope", "tier", "icon", "steps", "group", "legacy"
]
const TIERS: PackedStringArray = ["kolay", "orta", "zor", "cok_zor"]
const SCOPES: PackedStringArray = ["run", "total"]
## shaders: enemy_flash.gdshader `cell_rect[16]`, ash_ghost.gdshader `cell_rect[16]`.
const SFX_DIR := "res://assets/audio/sfx/"
const ATLAS_CELLS_MAX := 16
## Karakter `sfx` sözlüğü anahtarları (AudioDirector olayları).
const SFX_EVENTS: PackedStringArray = ["shot", "hit", "reload_start", "reload_end", "dry"]
## v2.0.3: kayıt sayısı artık AİLE sayısı; toplam kademe (legacy kayıt = 1) üst sınırı STEPS_TOTAL_MAX.
const ACH_COUNT_MIN := 12
const ACH_COUNT_MAX := 30
const STEPS_TOTAL_MAX := 80
const NAME_MAX := 22
const DESC_MAX := 60
const ID_MAX := 40
const TARGET_MAX := 999999999
const BLURB_MAX := 120
const UNLOCK_KEYS: PackedStringArray = ["achievement"]


## `<root>/achievements.json` isteğe bağlı: yoksa liste boş (tamamlandı modunda `validate` zorunlu tutar).
## Ayrıştırma hatası GameData.load_errors'a girer; geçerli kimlikli kayıtlar tanım olarak alınır.
static func load_achievements(g: GameData, root_dir: String) -> void:
	g._v2 = {"ach": null, "ach_present": false, "ach_failed": false}
	var path := root_dir.path_join(ACH_FILE)
	if not FileAccess.file_exists(path):
		return
	var before := g.load_errors.size()
	var data: Variant = g._read_json(path, ACH_FILE).get("data")
	g._v2["ach"] = data
	g._v2["ach_present"] = true
	g._v2["ach_failed"] = g.load_errors.size() > before  # bad_json zaten bildirildi
	if not (data is Array):
		return
	for d in data:
		if d is Dictionary and GameData._valid_id(d.get("id")):
			var id := StringName(d["id"])
			if not g._achievements.has(id):
				var def := AchievementDef.from_dict(d)
				g._achievements[id] = def
				g.achievement_ids.append(id)
				g.achievements.append(def)


## complete: içerik tamamlandı modu (dosya zorunlu, aile adedi 12..30, kademe toplamı ≤ 80; eski şemada her zorlukta en az bir kayıt).
static func validate(g: GameData, out: PackedStringArray, complete: bool) -> void:
	_validate_atlas_cells(g, out)
	for e in g._raw_skills:
		if e["data"] is Dictionary:
			validate_skill_sfx(out, e["file"], e["data"])
			validate_cast_sfx(out, e["file"], e["data"])
	if not g._v2.get("ach_present", false):
		if complete:
			GameData._err(
				out, "missing_file", ACH_FILE, "dosya yok (içerik tamamlandı modunda zorunlu)"
			)
		return
	if g._v2.get("ach_failed", false):
		return
	var raw: Variant = g._v2.get("ach")
	if not (raw is Array):
		GameData._err(out, "bad_type", ACH_FILE, "kök dizi olmalı")
		return
	var seen := {}
	var tiers_seen := {}
	var fam := {"legacy": {}, "families": 0, "steps": 0}
	for i in (raw as Array).size():
		_validate_achievement(g, out, "%s[%d]" % [ACH_FILE, i], raw[i], seen, tiers_seen, fam)
	if complete:
		_validate_complete(out, (raw as Array).size(), tiers_seen, fam)


## F-013: düşman atlası 16 hücreyi aşarsa shader `cell_rect[16]` taşar.
## v2.0.1: isteğe bağlı `sfx` (yalnız evrimde): assets/audio/sfx/<sfx>.ogg var olmalı.
## Hata kodları: unknown_key (evrim dışı), bad_type (boş/metin değil), asset_missing (dosya yok).
static func validate_skill_sfx(out: PackedStringArray, file: String, d: Dictionary) -> void:
	if not d.has("sfx"):
		return
	var sfx: Variant = d["sfx"]
	if d.get("kind") != "evolution":
		GameData._err(out, "unknown_key", file, "'sfx' yalnız evrimde olur")
	elif not (sfx is String) or (sfx as String).is_empty():
		GameData._err(out, "bad_type", file, "'sfx' boş olmayan metin olmalı")
	elif not ResourceLoader.exists(SFX_DIR + (sfx as String) + ".ogg"):
		GameData._err(out, "asset_missing", file, "'sfx' = '%s' için SFX dosyası yok" % sfx)


## v2.0.2 A4: `cast_sfx` (aktif ve evrimde): `<id>.ogg` ya da `<id>_1.ogg` (varyasyon) var olmalı.
static func validate_cast_sfx(out: PackedStringArray, file: String, d: Dictionary) -> void:
	if not d.has("cast_sfx"):
		return
	if d.get("kind") == "passive":
		GameData._err(out, "unknown_key", file, "'cast_sfx' pasifte olmaz")
	else:
		_check_sfx_id(out, file, "cast_sfx", d["cast_sfx"])


## SFX kimliği: boş olmayan metin ve dosya (ya da `_1` varyasyonu) mevcut.
static func _check_sfx_id(out: PackedStringArray, file: String, key: String, v: Variant) -> void:
	if not (v is String) or (v as String).is_empty():
		GameData._err(out, "bad_type", file, "'%s' boş olmayan metin olmalı" % key)
	elif not sfx_exists(v):
		GameData._err(out, "asset_missing", file, "'%s' = '%s' için SFX dosyası yok" % [key, v])


## Kimlik tek dosya ya da `_1..N` varyasyon olarak var mı (Sfx.pick_stream ile aynı arama).
static func sfx_exists(id: String) -> bool:
	return (
		ResourceLoader.exists(SFX_DIR + id + ".ogg")
		or ResourceLoader.exists(SFX_DIR + id + "_1.ogg")
	)


## Karakter `sfx` sözlüğü: anahtarlar SFX_EVENTS, değer metin ya da metin dizisi.
static func validate_character_sfx(out: PackedStringArray, file: String, v: Variant) -> void:
	if not (v is Dictionary):
		GameData._err(out, "bad_type", file, "'sfx' nesne olmalı")
		return
	GameData._unknown_keys(out, file + " sfx", v, SFX_EVENTS)
	for k in v:
		var val: Variant = v[k]
		var ids: Array = val if val is Array else [val]
		if ids.is_empty():
			GameData._err(out, "bad_type", file, "'sfx.%s' boş dizi" % k)
		for id in ids:
			_check_sfx_id(out, file, "sfx." + str(k), id)


static func _validate_atlas_cells(g: GameData, out: PackedStringArray) -> void:
	if g.enemy_ids.size() > ATLAS_CELLS_MAX:
		GameData._err(
			out,
			"atlas_cells",
			"enemies",
			"%d düşman > %d atlas hücresi (cell_rect[16])" % [g.enemy_ids.size(), ATLAS_CELLS_MAX]
		)


static func _validate_achievement(
	g: GameData,
	out: PackedStringArray,
	ctx: String,
	d: Variant,
	seen: Dictionary,
	tiers_seen: Dictionary,
	fam: Dictionary
) -> void:
	if not (d is Dictionary):
		GameData._err(out, "bad_type", ctx, "kayıt nesne olmalı")
		return
	GameData._unknown_keys(out, ctx, d, ACH_KEYS)
	_validate_id(out, ctx, d, seen)
	_validate_text(out, ctx, d, "name", NAME_MAX)
	_validate_text(out, ctx, d, "desc", DESC_MAX)
	var family: bool = d.has("steps")
	if family:
		fam["families"] += 1
		_validate_family(out, ctx, d, fam)
	else:
		fam["steps"] += 1
		for k in ["group", "legacy"]:
			if d.has(k):
				GameData._err(
					out, "steps_invalid", ctx, "'%s' yalnız 'steps' ile birlikte olur" % k
				)
		GameData._num(out, ctx, d, "target", 1, TARGET_MAX, true)
	var stat_ok := false
	if GameData._str(out, ctx, d, "stat"):
		stat_ok = AchievementDef.STATS.has(d["stat"])
		if not stat_ok:
			GameData._err(out, "unknown_stat", ctx, "bilinmeyen stat '%s'" % d["stat"])
	var scope_ok := _enum_field(out, ctx, d, "scope", SCOPES)
	if stat_ok and scope_ok and str(AchievementDef.scope_of(StringName(d["stat"]))) != d["scope"]:
		GameData._err(
			out,
			"scope_mismatch",
			ctx,
			"scope '%s' stat '%s' kapsamıyla uyuşmuyor" % [d["scope"], d["stat"]]
		)
	if not family and _enum_field(out, ctx, d, "tier", TIERS):
		tiers_seen[d["tier"]] = true
	if d.has("icon"):
		g._check_asset(out, ctx, d, "icon")


## Aile kaydı (`steps` var): target/tier olmaz, 1..MAX_STEPS kesin artan eşik, `group` zorunlu, `legacy` isteğe bağlı.
static func _validate_family(
	out: PackedStringArray, ctx: String, d: Dictionary, fam: Dictionary
) -> void:
	if d.has("target") or d.has("tier"):
		GameData._err(out, "steps_invalid", ctx, "'steps' ile 'target'/'tier' birlikte olmaz")
	var n := _validate_steps(out, ctx, d["steps"])
	fam["steps"] += maxi(n, 0)
	_enum_field(out, ctx, d, "group", AchievementDef.GROUPS)
	if d.has("legacy"):
		_validate_legacy(out, ctx, d["legacy"], n, fam["legacy"])


## Geçerliyse kademe sayısı, değilse -1.
static func _validate_steps(out: PackedStringArray, ctx: String, s: Variant) -> int:
	var max_steps := AchievementDef.MAX_STEPS
	if not (s is Array) or (s as Array).is_empty() or (s as Array).size() > max_steps:
		GameData._err(out, "steps_invalid", ctx, "'steps' 1..%d elemanlı dizi olmalı" % max_steps)
		return -1
	var prev := 0
	for v in s:
		var iv := _step_int(v)
		if iv < 1 or iv <= prev:
			GameData._err(
				out, "steps_invalid", ctx, "'steps' kesin artan 1..%d tamsayı olmalı" % TARGET_MAX
			)
			return -1
		prev = iv
	return (s as Array).size()


## `legacy`: {eski_kimlik: kademe(1..n)}; kimlik 22 eski başarımdan biri olmalı ve tek ailede geçmeli.
static func _validate_legacy(
	out: PackedStringArray, ctx: String, lg: Variant, n: int, seen: Dictionary
) -> void:
	if not (lg is Dictionary):
		GameData._err(out, "legacy_unknown", ctx, "'legacy' nesne olmalı")
		return
	for k in lg:
		var key := str(k)
		if not AchievementDef.LEGACY_IDS.has(key):
			GameData._err(out, "legacy_unknown", ctx, "eski kimlik '%s' tanımsız" % key)
		elif seen.has(key):
			GameData._err(out, "legacy_unknown", ctx, "'%s' iki ailede (%s)" % [key, seen[key]])
		else:
			seen[key] = ctx
		var step := _step_int(lg[k])
		if step < 1 or (n >= 0 and step > n):
			GameData._err(out, "legacy_unknown", ctx, "'%s' kademesi 1..%d olmalı" % [key, n])


## int ya da tamsayı değerli float -> int (1..TARGET_MAX dışı ve diğer her şey -1).
static func _step_int(v: Variant) -> int:
	var iv: Variant = StoreIo.int_of(v, false)
	return iv if iv != null and iv >= 1 and iv <= TARGET_MAX else -1


static func _validate_id(
	out: PackedStringArray, ctx: String, d: Dictionary, seen: Dictionary
) -> void:
	if not GameData._str(out, ctx, d, "id"):
		return
	var id: String = d["id"]
	if not _id_ok(id):
		GameData._err(out, "bad_type", ctx, "id '%s' [a-z0-9_]{1,%d} olmalı" % [id, ID_MAX])
		return
	if seen.has(id):
		GameData._err(out, "dup_id", ctx, "id '%s' tekrarlanıyor (%s)" % [id, seen[id]])
	else:
		seen[id] = ctx


static func _validate_text(
	out: PackedStringArray, ctx: String, d: Dictionary, key: String, max_len: int
) -> void:
	if GameData._str(out, ctx, d, key) and (d[key] as String).length() > max_len:
		GameData._err(
			out,
			"out_of_range",
			ctx,
			"'%s' %d > %d karakter" % [key, (d[key] as String).length(), max_len]
		)


## Kapalı küme alanı (metin, `allowed` içinden). Geçerliyse true.
static func _enum_field(
	out: PackedStringArray, ctx: String, d: Dictionary, key: String, allowed: PackedStringArray
) -> bool:
	if not GameData._str(out, ctx, d, key):
		return false
	if not allowed.has(d[key]):
		GameData._err(out, "bad_type", ctx, "'%s' = '%s', izinli: %s" % [key, d[key], allowed])
		return false
	return true


static func _validate_complete(
	out: PackedStringArray, count: int, tiers_seen: Dictionary, fam: Dictionary
) -> void:
	if count < ACH_COUNT_MIN or count > ACH_COUNT_MAX:
		GameData._err(
			out,
			"ach_count",
			ACH_FILE,
			"%d başarım, beklenen %d..%d" % [count, ACH_COUNT_MIN, ACH_COUNT_MAX]
		)
	if fam["steps"] > STEPS_TOTAL_MAX:
		GameData._err(
			out,
			"steps_invalid",
			ACH_FILE,
			"kademe toplamı %d > %d" % [fam["steps"], STEPS_TOTAL_MAX]
		)
	for t in TIERS:
		if fam["families"] == 0 and not tiers_seen.has(t):
			GameData._err(out, "tier_missing", ACH_FILE, "'%s' kademesinde başarım yok" % t)


## Karakter dosyasının v2.0 alanları (blurb, portrait, unlock, placeholder); hepsi isteğe bağlı.
static func validate_character(
	g: GameData, out: PackedStringArray, file: String, d: Dictionary
) -> void:
	if d.has("blurb"):
		if not (d["blurb"] is String):
			GameData._err(out, "bad_type", file, "'blurb' metin olmalı")
		elif (d["blurb"] as String).length() > BLURB_MAX:
			GameData._err(out, "out_of_range", file, "'blurb' > %d karakter" % BLURB_MAX)
	if d.has("portrait"):
		g._check_asset(out, file, d, "portrait")
	if d.has("portrait_video"):
		_validate_portrait_video(g, out, file, d["portrait_video"])
	if d.has("placeholder") and not (d["placeholder"] is bool):
		GameData._err(out, "bad_type", file, "'placeholder' bool olmalı")
	if d.has("unlock"):
		_validate_unlock(g, out, file, d["unlock"])
	if d.has("display_upper"):
		if not (d["display_upper"] is String):
			GameData._err(out, "bad_type", file, "'display_upper' metin olmalı")
		elif (d["display_upper"] as String).length() > NAME_MAX:
			GameData._err(out, "out_of_range", file, "'display_upper' > %d karakter" % NAME_MAX)
	if d.has("sfx"):
		validate_character_sfx(out, file, d["sfx"])
	if d.has("order") and not (d["order"] is int or d["order"] is float):
		GameData._err(out, "bad_type", file, "'order' tam sayı olmalı")


## v2.0.3 hareketli portre: Theora `.ogv` (res:// yolu ya da placeholder:); dosya yoksa `asset_missing`.
static func _validate_portrait_video(
	g: GameData, out: PackedStringArray, file: String, v: Variant
) -> void:
	if not (v is String) or not (v as String).ends_with(".ogv"):
		GameData._err(out, "bad_type", file, "'portrait_video' .ogv yolu olmalı")
		return
	g._check_asset(out, file, {"portrait_video": v}, "portrait_video")


static func _validate_unlock(g: GameData, out: PackedStringArray, file: String, u: Variant) -> void:
	if not (u is Dictionary):
		GameData._err(out, "bad_type", file, "'unlock' nesne olmalı")
		return
	GameData._unknown_keys(out, file + " unlock", u, UNLOCK_KEYS)
	if not GameData._str(out, file + " unlock", u, "achievement"):
		return
	if g.get_achievement(StringName(u["achievement"])) == null:
		GameData._err(out, "unknown_ref", file, "unlock.achievement '%s' yok" % u["achievement"])


static func _id_ok(id: String) -> bool:
	if id.is_empty() or id.length() > ID_MAX:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		if not ((c >= 0x61 and c <= 0x7A) or (c >= 0x30 and c <= 0x39) or c == 0x5F):
			return false
	return true
