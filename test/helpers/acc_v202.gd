class_name AccV202
extends RefCounted
## v2.0.2 (Zyfen) kabul testleri için küçük yardımcılar. Yalnız sözleşme yüzeyine bakar (GameSim açık alanları,
## event_log, havuz dizileri). Düşmanı dondurmak için `enemies.speed` sıfırlanır (konum testleri deterministik kalır).

const CHAR_Z := &"zyfen"
const CHAR_G := &"gunslinger"
const TOUGH_HP := 1.0e7
const STEP := GameSim.STEP


## Kolsuz karakterin sanat kaynağı sahibi: `rig.walk.strip` `<sahip>_strip.png` ise `art/source/<sahip>/` (yalnız veriyle eklenen
## karakter başka karakterin şeridini paylaşabilir); şerit adı bu kalıpta değilse karakterin kendi kimliği. `art/source/<sahip>/`
## yoksa test KIRMIZI kalır (atlanmaz): yeni sanat getiren karakter kendi şeridini ve kaynağını da getirmelidir.
static func art_owner(id: StringName, rig: Dictionary) -> StringName:
	var walk: Variant = rig.get("walk", {})
	var strip := str((walk as Dictionary).get("strip", "")) if walk is Dictionary else ""
	var base := strip.get_file()
	return StringName(base.trim_suffix("_strip.png")) if base.ends_with("_strip.png") else id


## Zyfen sim'i, gerçek veri, doğurma çizelgesi boş. Tabanca susturulur (`silence`), beceriler verilir, ölümsüz.
static func zyfen(
	grants: Dictionary = {},
	silence: bool = true,
	seed_value: int = 1,
	character: StringName = CHAR_Z
) -> GameSim:
	var sim := SimKit.make(seed_value, {"character": character, "log_events": true})
	if silence:
		sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	for k in grants:
		sim.debug_grant(StringName(k), int(grants[k]))
	SimKit.godmode(sim)  # beceri verildikten SONRA: debug_grant azami canı yeniden hesaplar
	return sim


## Sabit (hp çok yüksek, hareketsiz) kukla düşman; kimlik döner.
static func dummy(sim: GameSim, pos: Vector2, type_id: StringName = &"curumus_piyade") -> int:
	var id := sim.debug_spawn(type_id, pos)
	var i := EnemyPool.index_of(id)
	sim.enemies.hp[i] = TOUGH_HP
	sim.enemies.max_hp[i] = TOUGH_HP
	sim.enemies.speed[i] = 0.0
	return id


static func hp_of(sim: GameSim, id: int) -> float:
	return sim.enemies.hp[EnemyPool.index_of(id)]


static func lost(sim: GameSim, id: int) -> float:
	return TOUGH_HP - hp_of(sim, id)


static func pos_of(sim: GameSim, id: int) -> Vector2:
	return sim.enemies.pos[EnemyPool.index_of(id)]


## `n` tam sim adımı (ızgara, beceriler, mermiler, AI dahil).
static func steps(sim: GameSim, n: int) -> void:
	for _k in n:
		sim.step(Vector2.ZERO)


## Oyuncuyu hareket ettirmeden `n` adım atar ve her adım sonunda `cb(sim)` çağırır.
static func steps_with(sim: GameSim, n: int, cb: Callable) -> void:
	for _k in n:
		sim.step(Vector2.ZERO)
		cb.call(sim)


## event_log'daki `kind` türünde DAMAGE kayıtları (isteğe bağlı hedef süzgeci; -1 = hepsi), `from_step` dahil sonrası.
static func damages(sim: GameSim, kind: StringName, target: int = -1, from_step: int = 0) -> Array:
	var out: Array = []
	for e in sim.event_log:
		if e["type"] != SimEvents.DAMAGE or e["step"] < from_step:
			continue
		if e["kind"] == kind and (target < 0 or e["target"] == target):
			out.append(e)
	return out


## Havuzdaki mermi sayısı belirli bayrakla.
static func projectiles_with(sim: GameSim, flag: int) -> int:
	var n := 0
	for i in sim.projectiles.count:
		if sim.projectiles.flags[i] & flag:
			n += 1
	return n


## Doldurmayı hemen başlatır (şarjörü boşalt + start_reload); doldurma başlangıç kancaları o adımda çalışır.
static func begin_reload(sim: GameSim) -> void:
	sim.magazine.count = 0
	sim.magazine.start_reload(sim.stats)


## Skill kimliği JSON'dan seviye sözlüğü (bağımsız okuma: oyun kodundan değil, dosyadan).
static func json_levels(skill_id: String) -> Array:
	var f := FileAccess.open("res://data/skills/%s.json" % skill_id, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return (d as Dictionary)["levels"]
