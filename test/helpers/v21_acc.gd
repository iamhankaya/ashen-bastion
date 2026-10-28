class_name V21Acc
extends RefCounted
## v2.1 kabul testleri ortak yardımcıları (sahip: tester; yalnız test_acc_v21_* kullanır). Yalnız GameSim/SimBus sözleşme
## yüzeyine bakar. Global durumu değiştirmez.

const LORD := &"kale_lordu"

static var _lord_only: GameData = null


## Gerçek veri; dalga çizelgesinde yalnız Lord satırı kalır (kalabalıksız, hızlı Lord testleri).
## Taze `load_dir` örneği (`load_default` önbelleği paylaşılır: `waves` değişirse tüm testler bozulur);
## süreç boyu bir kez kurulur, sim veriyi değiştirmez.
static func lord_only_data() -> GameData:
	if _lord_only != null:
		return _lord_only
	var d := GameData.load_dir("res://data")
	var w: Dictionary = d.waves.duplicate(true)
	var rows: Array = []
	for r: Dictionary in w["rows"]:
		if r.get("kind", "") == "boss" and r.get("type", "") == String(LORD):
			rows.append(r)
	w["rows"] = rows
	d.waves = w
	_lord_only = d
	return d


## Önbelleği bırakır: statik değişken GameData kaynaklarını tuttuğundan, çıkışta 'resources still in use' hatasını
## (gate: günlükte hata satırı) önlemek için kullanan her kabul dosyası after_all'da çağırır.
static func release() -> void:
	_lord_only = null


static func lord_id(sim: GameSim) -> int:
	for id in sim.alive_ids():
		if sim.enemies.type_id_of(EnemyPool.index_of(id)) == LORD:
			return id
	return -1


static func hp_of(sim: GameSim, id: int) -> float:
	return sim.enemies.hp[EnemyPool.index_of(id)]


## Sim olaylarını toplar: {"spawns": [zaman], "warns": [zaman], "slain": [n], "milestone": [sayı]}.
## Lambdalar sim'i ZAYIF tutar: sim.bus -> lambda -> sim döngüsü sim'i (ve GameData kaynaklarını) sızdırır; çıkışta
## 'resources still in use' hatası gate'i kırar (CI 40514013114, gut 2).
static func watch(sim: GameSim) -> Dictionary:
	var w := {"spawns": [], "warns": [], "slain": [], "milestone": [0]}
	var wr: WeakRef = weakref(sim)
	sim.bus.boss_spawned.connect(
		func(t: StringName) -> void:
			if t == LORD and wr.get_ref() != null:
				w["spawns"].append((wr.get_ref() as GameSim).time)
	)
	sim.bus.boss_warning.connect(
		func(t: StringName) -> void:
			if t == LORD and wr.get_ref() != null:
				w["warns"].append((wr.get_ref() as GameSim).time)
	)
	sim.bus.lord_slain.connect(func(n: int) -> void: w["slain"].append(n))
	sim.bus.milestone_reached.connect(func() -> void: w["milestone"][0] += 1)
	return w


## Oyuncuyu ölümsüz yapar, silahı susturur (düşman ölümleri yalnız testin kararıdır).
static func quiet_player(sim: GameSim) -> void:
	sim.gun_damage = 0.0
	sim.max_hp = 1.0e9
	sim.hp = 1.0e9


## En çok `max_steps` adım ya da `until` true dönene dek ilerletir; koşu bittiyse durur. Seviye seçimi 0. kart.
static func run_until(sim: GameSim, max_steps: int, until: Callable = Callable()) -> int:
	var n := 0
	while n < max_steps:
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(Vector2.ZERO)
		n += 1
		if until.is_valid() and until.call():
			break
	return n


## Lord'u öldürür (varsa); öldürülen Lord kimliği ya da -1.
static func slay_lord(sim: GameSim) -> int:
	var id := lord_id(sim)
	if id >= 0:
		sim.damage_enemy(id, 1.0e9, &"bullet")
	return id
