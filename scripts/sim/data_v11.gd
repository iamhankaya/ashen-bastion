class_name DataV11
extends RefCounted
## v1.1 veri yükleme ve doğrulama: data/pickups.json, data/score.json, düşman `anim`, karakter `rig.walk`.
## GameData bu sınıfı çağırır (RuinsValidator kalıbı: GameData dosyası gdlint 1000 satır sınırında). Hata biçimi ve
## kodlar GameData'nın: "[kod] bağlam: açıklama". Şema: docs/data-schema.md

## Kareli yürüme (rig.walk): frames 0 = prosedürel yedek, 2..12 = kare modu.
const WALK_KEYS: PackedStringArray = ["frames", "stride", "strip", "cell", "shoulder_dev"]
const WALK_MAX_FRAMES := 12

## Düşman animasyonu (enemies/<id>.json `anim`); yoksa kind "none".
const ANIM_KEYS: PackedStringArray = [
	"kind",
	"hz",
	"bob",
	"rot",
	"sq",
	"lean",
	"hover",
	"knock",
	"hit_sq",
	"hit_rot",
	"cycle",
	"death",
	"death_ms",
	"alpha",
]
const ANIM_KINDS: PackedStringArray = ["crawl", "flap", "float", "stomp", "none"]
const ANIM_DEATHS: PackedStringArray = ["collapse", "fall", "ash_up", "ash_big", "lord"]
## Sayısal anim anahtarlarının sınırları [alt, üst]. rot <= 15: sin/cos yaklaşımı (plan A3) bu sınıra dayanır.
const ANIM_BOUNDS := {
	"hz": [0.0, 20.0],
	"bob": [0.0, 100.0],
	"rot": [0.0, 15.0],
	"sq": [0.0, 0.5],
	"lean": [0.0, 45.0],
	"hover": [0.0, 300.0],
	"knock": [0.0, 100.0],
	"hit_sq": [0.0, 0.5],
	"hit_rot": [0.0, 45.0],
	"cycle": [1.0, 2000.0],
	"death_ms": [50.0, 5000.0],
}
## data/pickups.json
const PICKUP_TOP_KEYS: PackedStringArray = ["spawn", "kinds"]
const PICKUP_SPAWN_KEYS: PackedStringArray = [
	"first",
	"interval",
	"dist",
	"clearance",
	"life",
	"blink_last",
	"collect_radius",
	"max_alive",
]
const PICKUP_KIND_KEYS: PackedStringArray = [
	"id",
	"name",
	"rarity",
	"weight",
	"effect",
	"amount",
	"buff",
	"mult",
	"duration",
	"radius",
	"fuse",
	"dmg",
	"elite_frac",
	"elite_min",
	"toast",
	"icon",
]
const PICKUP_EFFECTS: PackedStringArray = ["heal", "magnet", "buff", "bomb"]
const PICKUP_RARITIES: PackedStringArray = ["common", "uncommon", "rare"]
const PICKUP_MAX_ALIVE_LIMIT := 8  # PickupPool.CAP
## data/score.json
const SCORE_TOP_KEYS: PackedStringArray = [
	"kill_points", "streak", "evolution_bonus", "survival_per_sec", "lord_bonus", "display_cap"
]
const SCORE_STREAK_KEYS: PackedStringArray = ["window", "tiers"]
const SCORE_BONUS_MAX := 1000000
const SCORE_DISPLAY_CAP_MAX := 99999999
const SCORE_MAX_TIERS := 20
const SCORE_MAX_MULT := 100
const SCORE_MAX_THRESHOLD := 100000


## pickups.json / score.json isteğe bağlıdır (yoksa boş tablo); "içerik tamamlandı" modunda zorunludur.
## Ham veri g._v11'e yazılır: pickups, pickups_failed, score, score_failed.
static func load_tables(g: GameData) -> void:
	g._v11 = {"pickups": null, "pickups_failed": false, "score": null, "score_failed": false}
	var pickups: Variant = _read(g, "pickups.json", "pickups")
	if pickups is Dictionary:
		g.pickup_cfg = pickups
		var kinds: Variant = g.pickup_cfg.get("kinds", [])
		if kinds is Array:
			for k in kinds:
				if k is Dictionary and GameData._valid_id(k.get("id")):
					var id := StringName(k["id"])
					if not g._pickups.has(id):
						g._pickups[id] = PickupDef.from_dict(k)
						g.pickup_ids.append(id)
	var score: Variant = _read(g, "score.json", "score")
	if score is Dictionary:
		g.score_table = ScoreTable.from_dict(score)


## Dosyayı okur; yoksa null. Ayrıştırma hatası load_errors'a girer ve `<key>_failed` işaretlenir.
static func _read(g: GameData, file: String, key: String) -> Variant:
	var path := g.root_dir.path_join(file)
	if not FileAccess.file_exists(path):
		return null
	var before := g.load_errors.size()
	var data: Variant = CatalogLoader.read_json(g, path, file).get("data")
	g._v11[key] = data
	g._v11[key + "_failed"] = g.load_errors.size() > before  # bad_json zaten bildirildi
	return data


static func validate(g: GameData, out: PackedStringArray) -> void:
	_validate_pickups(g, out)
	_validate_score(g, out)


## "İçerik tamamlandı" modu: iki dosya zorunlu, her düşman için kill_points kaydı.
static func validate_complete(g: GameData, out: PackedStringArray) -> void:
	for f in ["pickups.json", "score.json"]:
		if not FileAccess.file_exists(g.root_dir.path_join(f)):
			GameData._err(out, "missing_file", f, "dosya yok (içerik tamamlandı modunda zorunlu)")
	var sc: Variant = g._v11.get("score")
	if sc is Dictionary and sc.get("kill_points") is Dictionary:
		for eid in g.enemy_ids:
			if not (sc["kill_points"] as Dictionary).has(String(eid)):
				GameData._err(
					out,
					"missing_field",
					"score.json kill_points",
					"düşman '%s' için kayıt yok" % eid
				)


# --- düşman anim ---------------------------------------------------------------------------


## Düşman `anim` bloğu (isteğe bağlı): `kind` zorunlu, diğer anahtarlar isteğe bağlı (yoksa görünüm varsayılanı).
static func validate_enemy(
	g: GameData, out: PackedStringArray, file: String, d: Dictionary
) -> void:
	if not d.has("anim"):
		return
	if not (d["anim"] is Dictionary):
		GameData._err(out, "bad_type", file, "'anim' nesne olmalı")
		return
	var a: Dictionary = d["anim"]
	var ctx := file + " anim"
	GameData._unknown_keys(out, ctx, a, ANIM_KEYS)
	if not a.has("kind"):
		GameData._err(out, "missing_field", ctx, "'kind' yok")
	elif not (a["kind"] is String) or not ANIM_KINDS.has(a["kind"]):
		GameData._err(out, "bad_kind", ctx, "'kind' crawl|flap|float|stomp|none olmalı")
	if a.has("death") and (not (a["death"] is String) or not ANIM_DEATHS.has(a["death"])):
		GameData._err(out, "bad_kind", ctx, "'death' collapse|fall|ash_up|ash_big|lord olmalı")
	for k in ANIM_BOUNDS.keys():
		if a.has(k):
			var b: Array = ANIM_BOUNDS[k]
			GameData._num(out, ctx, a, k, b[0], b[1])
	if a.has("alpha"):
		GameData._pair(out, ctx, a, "alpha", 0, 1)


# --- rig.walk ------------------------------------------------------------------------------


## rig.walk (isteğe bağlı): frames 0 (prosedürel yedek) ya da 2..12; kare modunda şerit, hücre ve omuz sapmaları da denetlenir.
static func validate_walk(g: GameData, out: PackedStringArray, ctx: String, r: Dictionary) -> void:
	if not r.has("walk"):
		return
	if not (r["walk"] is Dictionary):
		GameData._err(out, "bad_type", ctx, "'walk' nesne olmalı")
		return
	var w: Dictionary = r["walk"]
	ctx += " walk"
	GameData._unknown_keys(out, ctx, w, WALK_KEYS)
	var frames_ok := GameData._num(out, ctx, w, "frames", 0, WALK_MAX_FRAMES, true)
	var frames := int(w["frames"]) if frames_ok else 0
	if frames_ok and frames == 1:
		GameData._err(
			out, "out_of_range", ctx, "'frames' 0 (yedek) ya da 2..%d olmalı" % WALK_MAX_FRAMES
		)
		frames_ok = false
	GameData._num(out, ctx, w, "stride", 20, 600)
	if frames > 0:
		g._check_asset(out, ctx, w, "strip")
		_validate_walk_cell(out, ctx, w)
	if w.has("shoulder_dev"):
		_validate_shoulder_dev(out, ctx, w["shoulder_dev"], frames if frames_ok else -1)


static func _validate_walk_cell(out: PackedStringArray, ctx: String, w: Dictionary) -> void:
	if not w.has("cell"):
		GameData._err(out, "missing_field", ctx, "'cell' yok")
		return
	var c: Variant = w["cell"]
	var good: bool = c is Array and (c as Array).size() == 2
	if good:
		for x in c:
			good = good and GameData._is_int(x) and float(x) > 0.0
	if not good:
		GameData._err(
			out, "bad_type", ctx, "'cell' [genişlik, yükseklik] pozitif tamsayı çifti olmalı"
		)


## shoulder_dev: boş ya da (frames+1) adet [dx, dy] (display_height kesri, -0,2..0,2). frames < 0: sayı bilinmiyor.
static func _validate_shoulder_dev(
	out: PackedStringArray, ctx: String, v: Variant, frames: int
) -> void:
	if not (v is Array):
		GameData._err(out, "bad_type", ctx, "'shoulder_dev' dizi olmalı")
		return
	var arr: Array = v
	if arr.is_empty():
		return
	if frames >= 0 and arr.size() != frames + 1:
		GameData._err(
			out,
			"out_of_range",
			ctx,
			(
				"'shoulder_dev' boş ya da %d (frames+1) eleman olmalı, %d var"
				% [frames + 1, arr.size()]
			)
		)
		return
	for i in arr.size():
		if not GameData._pair(out, ctx, {"shoulder_dev": arr[i]}, "shoulder_dev", -0.2, 0.2):
			return


# --- eklentiler ----------------------------------------------------------------------------


static func _validate_pickups(g: GameData, out: PackedStringArray) -> void:
	var raw: Variant = g._v11.get("pickups")
	if (
		g._v11.get("pickups_failed", false)
		or (raw == null and not FileAccess.file_exists(g.root_dir.path_join("pickups.json")))
	):
		return  # dosya isteğe bağlı; bad_json zaten bildirildi
	if not (raw is Dictionary):
		GameData._err(out, "not_object", "pickups.json", "kök nesne olmalı")
		return
	var root: Dictionary = raw
	GameData._unknown_keys(out, "pickups.json", root, PICKUP_TOP_KEYS)
	if not root.has("spawn"):
		GameData._err(out, "missing_field", "pickups.json", "'spawn' yok")
	elif not (root["spawn"] is Dictionary):
		GameData._err(out, "bad_type", "pickups.json", "'spawn' nesne olmalı")
	else:
		_validate_pickup_spawn(out, "pickups.json spawn", root["spawn"])
	if not root.has("kinds"):
		GameData._err(out, "missing_field", "pickups.json", "'kinds' yok")
	elif not (root["kinds"] is Array):
		GameData._err(out, "bad_type", "pickups.json", "'kinds' dizi olmalı")
	else:
		var seen := {}
		var total := 0.0
		for i in (root["kinds"] as Array).size():
			total += _validate_pickup_kind(
				g, out, "pickups.json kinds[%d]" % i, root["kinds"][i], seen
			)
		if total <= 0.0:
			GameData._err(out, "pickup_weight", "pickups.json kinds", "ağırlık toplamı > 0 olmalı")


static func _validate_pickup_spawn(out: PackedStringArray, ctx: String, sp: Dictionary) -> void:
	GameData._unknown_keys(out, ctx, sp, PICKUP_SPAWN_KEYS)
	for k in ["first", "interval", "dist"]:
		var hi := 2000.0 if k == "dist" else 3600.0
		var lo := 0.0 if k == "first" else 1.0
		if GameData._pair(out, ctx, sp, k, lo, hi) and float(sp[k][0]) > float(sp[k][1]):
			GameData._err(out, "out_of_range", ctx, "'%s' [a,b] için a <= b olmalı" % k)
	GameData._num(out, ctx, sp, "clearance", 0, 500)
	var life_ok := GameData._num(out, ctx, sp, "life", 1, 600)
	var blink_ok := GameData._num(out, ctx, sp, "blink_last", 0, 600)
	if life_ok and blink_ok and float(sp["life"]) <= float(sp["blink_last"]):
		GameData._err(out, "out_of_range", ctx, "'life' > 'blink_last' olmalı")
	GameData._num(out, ctx, sp, "collect_radius", 1, 500)
	GameData._num(out, ctx, sp, "max_alive", 1, PICKUP_MAX_ALIVE_LIMIT, true)


## Bir eklenti türünü doğrular; ağırlığını (geçersizse 0) döndürür.
static func _validate_pickup_kind(
	g: GameData, out: PackedStringArray, ctx: String, k: Variant, seen: Dictionary
) -> float:
	if not (k is Dictionary):
		GameData._err(out, "not_object", ctx, "tür nesne olmalı")
		return 0.0
	var d: Dictionary = k
	GameData._unknown_keys(out, ctx, d, PICKUP_KIND_KEYS)
	if GameData._str(out, ctx, d, "id"):
		if seen.has(d["id"]):
			GameData._err(
				out, "dup_id", ctx, "id '%s' tekrarlanıyor (%s)" % [d["id"], seen[d["id"]]]
			)
		else:
			seen[d["id"]] = ctx
	GameData._str(out, ctx, d, "name")
	if not d.has("rarity") or not (d["rarity"] is String) or not PICKUP_RARITIES.has(d["rarity"]):
		GameData._err(out, "bad_kind", ctx, "'rarity' common|uncommon|rare olmalı")
	if not d.has("toast") or not (d["toast"] is String):
		GameData._err(out, "bad_type", ctx, "'toast' metin olmalı (boş olabilir)")
	g._check_asset(out, ctx, d, "icon")
	var weight_ok := GameData._num(out, ctx, d, "weight", 0, 1000)
	if not d.has("effect") or not (d["effect"] is String) or not PICKUP_EFFECTS.has(d["effect"]):
		GameData._err(out, "bad_kind", ctx, "'effect' heal|magnet|buff|bomb olmalı")
	else:
		match d["effect"]:
			"heal":
				GameData._num(out, ctx, d, "amount", 1, 10000)
			"buff":
				_validate_pickup_buff(out, ctx, d)
			"bomb":
				GameData._num(out, ctx, d, "radius", 1, 1000)
				GameData._num(out, ctx, d, "fuse", 0.1, 10)
				GameData._num(out, ctx, d, "dmg", 0, 100000)
				if d.has("elite_frac"):
					GameData._num(out, ctx, d, "elite_frac", 0, 1)
				if d.has("elite_min"):
					GameData._num(out, ctx, d, "elite_min", 0, 100000)
	return float(d["weight"]) if weight_ok else 0.0


static func _validate_pickup_buff(out: PackedStringArray, ctx: String, d: Dictionary) -> void:
	if not d.has("buff"):
		GameData._err(out, "missing_field", ctx, "'buff' yok")
	elif not (d["buff"] is String) or BuffManager.kind_of(d["buff"]) < 0:
		GameData._err(out, "bad_kind", ctx, "'buff' damage|fire_rate|unlimited olmalı")
	GameData._num(out, ctx, d, "duration", 0.1, 600)
	# Çarpan hasar/atış hızı için zorunlu; sınırsız şarjörde anlamsız (verilirse yine aralık denetlenir).
	if d.has("mult") or d.get("buff") != "unlimited":
		GameData._num(out, ctx, d, "mult", 1, 10)


# --- skor ----------------------------------------------------------------------------------


static func _validate_score(g: GameData, out: PackedStringArray) -> void:
	var raw: Variant = g._v11.get("score")
	if (
		g._v11.get("score_failed", false)
		or (raw == null and not FileAccess.file_exists(g.root_dir.path_join("score.json")))
	):
		return
	if not (raw is Dictionary):
		GameData._err(out, "not_object", "score.json", "kök nesne olmalı")
		return
	var sc: Dictionary = raw
	GameData._unknown_keys(out, "score.json", sc, SCORE_TOP_KEYS)
	_validate_score_points(g, out, sc)
	if not sc.has("streak"):
		GameData._err(out, "missing_field", "score.json", "'streak' yok")
	elif not (sc["streak"] is Dictionary):
		GameData._err(out, "bad_type", "score.json", "'streak' nesne olmalı")
	else:
		var st: Dictionary = sc["streak"]
		GameData._unknown_keys(out, "score.json streak", st, SCORE_STREAK_KEYS)
		GameData._num(out, "score.json streak", st, "window", 0.5, 30)
		_validate_score_tiers(out, st)
	for k in ["evolution_bonus", "survival_per_sec", "lord_bonus"]:
		GameData._num(out, "score.json", sc, k, 0, SCORE_BONUS_MAX, true)
	GameData._num(out, "score.json", sc, "display_cap", 1, SCORE_DISPLAY_CAP_MAX, true)


static func _validate_score_points(g: GameData, out: PackedStringArray, sc: Dictionary) -> void:
	if not sc.has("kill_points"):
		GameData._err(out, "missing_field", "score.json", "'kill_points' yok")
		return
	if not (sc["kill_points"] is Dictionary):
		GameData._err(out, "bad_type", "score.json", "'kill_points' nesne olmalı")
		return
	var kp: Dictionary = sc["kill_points"]
	var keys: Array = kp.keys()
	keys.sort()  # hata sırası kararlı
	for k in keys:
		if g.get_enemy(StringName(str(k))) == null:
			GameData._err(out, "unknown_enemy", "score.json kill_points", "düşman '%s' yok" % k)
		GameData._num(out, "score.json kill_points", kp, str(k), 0, SCORE_BONUS_MAX * 10, true)


## streak.tiers: [[min_seri, çarpan], …]; ilk [0, 1], eşikler ve çarpanlar kesin artan.
static func _validate_score_tiers(out: PackedStringArray, st: Dictionary) -> void:
	var ctx := "score.json streak"
	if not st.has("tiers"):
		GameData._err(out, "missing_field", ctx, "'tiers' yok")
		return
	var tiers: Variant = st["tiers"]
	if not (tiers is Array) or (tiers as Array).is_empty():
		GameData._err(out, "bad_type", ctx, "'tiers' dolu dizi olmalı")
		return
	if (tiers as Array).size() > SCORE_MAX_TIERS:
		GameData._err(out, "score_tiers", ctx, "en çok %d basamak" % SCORE_MAX_TIERS)
		return
	var prev_min := -1
	var prev_mult := 0
	for i in (tiers as Array).size():
		var row: Variant = tiers[i]
		var shape: bool = row is Array and (row as Array).size() == 2
		if shape:
			for x in row:
				shape = shape and GameData._is_int(x)
		if not shape:
			GameData._err(
				out, "bad_type", ctx, "tiers[%d] [min_seri, çarpan] tamsayı çifti olmalı" % i
			)
			return
		var mn := int(row[0])
		var mu := int(row[1])
		if i == 0 and (mn != 0 or mu != 1):
			GameData._err(out, "score_tiers", ctx, "ilk basamak [0, 1] olmalı")
			return
		if mu > SCORE_MAX_MULT or mn > SCORE_MAX_THRESHOLD:
			GameData._err(
				out,
				"score_tiers",
				ctx,
				(
					"tiers[%d]: çarpan ≤ %d, eşik ≤ %d olmalı"
					% [i, SCORE_MAX_MULT, SCORE_MAX_THRESHOLD]
				)
			)
			return
		if mn <= prev_min or mu <= prev_mult:
			GameData._err(
				out, "score_tiers", ctx, "tiers[%d]: eşikler ve çarpanlar kesin artan olmalı" % i
			)
			return
		prev_min = mn
		prev_mult = mu
