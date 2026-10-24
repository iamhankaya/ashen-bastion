class_name WindSystem
extends RefCounted
## Rüzgar bölgeleri adımı (GameSim.wind; `_phase_skills` sonunda `step(self)`). Bölge türleri: Hortum (KIND_TWISTER),
## Tufan (KIND_GIANT, dev hortum), Hava Cebi (KIND_POCKET). Girdap bölge DEĞİLDİR (davranış içinde).
##
## Algoritma (plan "Arayüzler/5"):
## 1. `i = count-1 -> 0` geriye gezilir. Adım içinde doğan bölgeler (ör. bölge tiki ile ölen düşmandan cep) havuz SONUNA
##    eklenir; geriye gezi onlara girmez (bir sonraki adımda işlenir), `remove(i)` son elemanı i'ye taşır ama i zaten işlendi.
## 2. Her bölge: `life -= dt`; hareket (yalnız Hortum/Tufan); `tick_left -= dt`, `<= 0` iken tik. Her adım grid sorgusu:
##    `query_circle(pos, radius + sim._max_enemy_radius)`, mesafe kuralı `dist <= radius + enemies.radius[i]`. Çekme
##    (`pull` px/sn x dt, merkeze, merkeze varınca durur: NaN yok) her adım, hasar yalnız tikte. Hasar `&"dot"` (zırhı yok
##    sayar; cepte `&"pocket_dot"`), elit/Lord için x `boss_mult`. Elit/Lord çekilmez/itilmez (`WindUtil.displace`).
## 3. Hava Cebi tiki sırasında `in_pocket_tick` true tutulur: `on_kill` etiket TAŞIMAZ (enemy_id, pos); `hava_cebi.on_kill`
##    bu bayrağa bakar (cep tiki ile ölen düşman yeni cep doğurmaz, zincir yok).
## 4. Ömür sonu: Hortum ve Tufan savurma (`fling` px, dışa, elit hariç) + 2x tik hasarı, sonra `remove`.
## 5. Hortum/Tufan hareketi: doğuş oyuncudan 250 px, açı `rng_combat.randf() * TAU` (count > 1 ise bölge i için
##    `+ i * TAU / count`; çağrı başına tek randf). `retarget_every` sn'de bir hedef: `grid.query_circle(player_pos, 600)`
##    (artan kimlik sırası), boş değilse `ids[int(rng_combat.randf() * ids.size())]` konumu, boşsa oyuncu + sabit ofset.
##    Yeniden hedefleme başına TAM 1 `randf()` (liste boş da olsa). Hız `speed`; konum oyuncudan `max_dist`'i aşarsa
##    hedef oyuncuya çevrilir.
## 6. Izgara aşama 3'te kurulur, WindSystem aşama 5'te: savrulan/çekilen düşman mermi fazında (6) bayat hücrede olabilir
##    (S1 notu). Ölçülen etki: bir adımlık kaçırma; sorgu payı olarak `radius + _max_enemy_radius` yeterli, çünkü sorgu
##    her adım taze ızgarayla yapılır. Düşman ızgaraya yeniden eklenmez (çift kayıt temas hasarını ikiye katlar).

const SPAWN_DIST := 250.0
const RETARGET_RANGE := 600.0
## Hedefsiz bekleyişte (yakında düşman yok) oyuncunun yanında dolaşma noktası.
const IDLE_OFFSET := Vector2(120.0, 0.0)
const DEFAULT_SPEED := {ZonePool.KIND_TWISTER: 90.0, ZonePool.KIND_GIANT: 110.0}
const DEFAULT_RETARGET := {ZonePool.KIND_TWISTER: 1.0, ZonePool.KIND_GIANT: 1.5}
const DEFAULT_MAX_DIST := {ZonePool.KIND_TWISTER: 600.0, ZonePool.KIND_GIANT: 700.0}
const TICK_EVERY := 0.4
## Ömür sonu savurmasında tik hasarı çarpanı.
const FINAL_TICK_MULT := 2.0

## Hava Cebi tik hasarı sürerken true (on_kill etiket taşımadığı için örnek bayrağı).
var in_pocket_tick: bool = false

var _ids: PackedInt32Array = PackedInt32Array()


func step(sim: GameSim) -> void:
	var zones := sim.zones
	var i := zones.count - 1
	while i >= 0:
		_step_zone(sim, i)
		i -= 1


## Bölge doğurur; -1 (dolu/rezerv) ise `sim.fx.zone_dropped` artar (kayıp sessiz değildir).
static func spawn_zone(sim: GameSim, kind: int, p: Vector2, o: Dictionary = {}) -> int:
	var i := sim.zones.spawn(kind, p, o)
	if i < 0:
		sim.fx.zone_dropped += 1
	return i


## Hortum/Tufan ortak doğurma: `count` bölge, oyuncudan SPAWN_DIST uzakta eşit açılı. `lv` becerinin seviye sözlüğü
## (radius, life, damage, interval, pull, fling, count; isteğe bağlı speed, max_dist, boss_mult; yeniden hedefleme aralığı
## türe göre sabit: DEFAULT_RETARGET). `push` Hortum/Tufan için kullanılmaz (sözleşme: tik hasar + çekme, bitişte fling).
## Rastgelelik: çağrı başına tam 1 `rng_combat.randf()`. Alan x `area_mult`, ömür x `wind_time_mult`, hasar x
## `bullet_dmg_mult` doğuş anında sabitlenir.
static func cast_twisters(sim: GameSim, kind: int, lv: Dictionary) -> void:
	var n := maxi(1, int(lv.get("count", 1)))
	var base := sim.rng_combat.randf() * TAU
	for k in n:
		var p := sim.player_pos + Vector2.from_angle(base + TAU * float(k) / float(n)) * SPAWN_DIST
		spawn_zone(
			sim,
			kind,
			p,
			{
				"radius": float(lv.get("radius", 150.0)) * sim.stats.area_mult,
				"life": float(lv.get("life", 3.0)) * sim.stats.wind_time_mult,
				"tick_every": float(lv.get("interval", TICK_EVERY)),
				"dmg": float(lv.get("damage", 8.0)) * sim.stats.bullet_dmg_mult,
				"pull": float(lv.get("pull", 0.0)),
				"push": float(lv.get("push", 0.0)),
				"fling": float(lv.get("fling", 0.0)),
				"speed": float(lv.get("speed", DEFAULT_SPEED[kind])),
				"max_dist": float(lv.get("max_dist", DEFAULT_MAX_DIST[kind])),
				"boss_mult": float(lv.get("boss_mult", 1.0)),
				"target": p,
			}
		)


func _step_zone(sim: GameSim, i: int) -> void:
	var z := sim.zones
	var dt := GameSim.STEP
	z.life[i] -= dt
	var moving := z.kind[i] != ZonePool.KIND_POCKET
	if moving:
		_move(sim, i, dt)
	z.tick_left[i] -= dt
	var tick := z.tick_left[i] <= 0.0
	if tick:
		z.tick_left[i] += z.tick_every[i]
	var ending := z.life[i] <= 0.0
	var pocket := not moving
	in_pocket_tick = pocket
	_affect(sim, i, dt, tick, ending and moving)
	in_pocket_tick = false
	if ending:
		z.remove(i)


## Bölge içindeki her canlı düşmana: tikte hasar, her adım merkeze çekme, bitişte (fling) dışa savurma. Sıcak yol:
## çekme adımı küçüktür (`pull` x dt), bu yüzden `map.slide` yerine doğrudan konum eklenir; yer düşmanlarının harabe
## çözümü aynı adımın EnemyAI aşamasında (resolve) yapılır. Büyük hareket (fling) `WindUtil.displace` ile alt adımlıdır.
func _affect(sim: GameSim, i: int, dt: float, tick: bool, final_blast: bool) -> void:
	var z := sim.zones
	var en := sim.enemies
	var center := z.pos[i]
	var radius := z.radius[i]
	var tag := &"pocket_dot" if z.kind[i] == ZonePool.KIND_POCKET else &"dot"
	var pull_step := z.pull[i] * dt
	sim.grid.query_circle(center, radius + sim._max_enemy_radius, _ids)
	for id in _ids:
		if not en.is_alive(id):
			continue
		var e := EnemyPool.index_of(id)
		var reach := radius + en.radius[e]
		var to_center := center - en.pos[e]
		var d2 := to_center.length_squared()
		if d2 > reach * reach:
			continue
		var elite := en.radius[e] > GameSim.SMALL_ENEMY_RADIUS and en.is_elite(e)
		if tick or final_blast:
			var d := z.dmg[i] * (z.boss_mult[i] if elite else 1.0)
			if final_blast:
				d *= FINAL_TICK_MULT
			sim.damage_enemy(id, d, tag)
			if not en.is_alive(id):
				continue
		if elite or d2 < 0.0001 and not final_blast:
			continue
		if final_blast:
			if z.fling[i] > 0.0:
				var away := -to_center / sqrt(d2) if d2 > 0.0001 else Vector2.RIGHT
				WindUtil.displace(sim, e, away * z.fling[i])
		elif pull_step > 0.0:
			var dist := sqrt(d2)
			en.pos[e] += to_center / dist * minf(pull_step, dist)


## Hortum/Tufan: hedefe doğru ilerler; `retarget_left` dolunca yeni hedef (tam 1 randf); `max_dist` aşılırsa oyuncuya döner.
func _move(sim: GameSim, i: int, dt: float) -> void:
	var z := sim.zones
	z.retarget_left[i] -= dt
	if z.retarget_left[i] <= 0.0:
		z.retarget_left[i] += DEFAULT_RETARGET[z.kind[i]]
		z.target[i] = _pick_target(sim)
	if z.pos[i].distance_to(sim.player_pos) > z.max_dist[i]:
		z.target[i] = sim.player_pos
	var to := z.target[i] - z.pos[i]
	var dist := to.length()
	if dist > 0.0001:
		z.pos[i] += to / dist * minf(z.speed[i] * dt, dist)


## Oyuncuya 600 px içindeki düşmanlardan biri (artan kimlik listesinden tek randf ile); yoksa oyuncu + sabit ofset.
func _pick_target(sim: GameSim) -> Vector2:
	sim.grid.query_circle(sim.player_pos, RETARGET_RANGE, _ids)
	var r := sim.rng_combat.randf()
	var live := PackedInt32Array()
	for id in _ids:
		if sim.enemies.is_alive(id):
			live.append(id)
	if live.is_empty():
		return sim.player_pos + IDLE_OFFSET
	return sim.enemies.pos[EnemyPool.index_of(live[int(r * live.size())])]
