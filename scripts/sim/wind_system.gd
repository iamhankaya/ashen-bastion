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
## 5. Hortum/Tufan doğuş ve hareketi (kullanıcı kararı 2026-10-25: oyuncudan uzakta doğar, oyuncunun üzerine gelmez).
##    Doğuş: oyuncudan >= `min_spawn_dist` ve <= SPAWN_VIEW uzaktaki canlı düşmanlar (artan kimlik) arasından, bölge k için
##    `(int(r * n) + k * n / count) % n`. n = 0 ise (uzak küme yok) oyuncudan `min_spawn_dist` uzakta yedek nokta, açı
##    `r * TAU + k * TAU / count`. Çağrı başına tek `r = rng_combat.randf()`. `retarget_every` sn'de bir hedef:
##    `grid.query_circle(player_pos, 600)` (artan kimlik) içinden oyuncuya `keep_out` ya da daha uzak düşmanlar arasında
##    `ids[int(randf() * ids.size())]` konumu; aday yoksa bölgenin oyuncuya göre yönünde `keep_out` uzaklıkta nokta.
##    Yeniden hedefleme başına TAM 1 `randf()` (liste boş ya da süzülmüş de olsa). Hız `speed`; hareket bölgeyi oyuncuya
##    `keep_out`'tan fazla yaklaştırmaz (yaklaşan adım teğete düşürülür). `max_dist` artık oyuncuya dönme kuralı DEĞİLDİR.
## 6. Izgara aşama 3'te kurulur, WindSystem aşama 5'te: savrulan/çekilen düşman mermi fazında (6) bayat hücrede olabilir
##    (S1 notu). Ölçülen etki: bir adımlık kaçırma; sorgu payı olarak `radius + _max_enemy_radius` yeterli, çünkü sorgu
##    her adım taze ızgarayla yapılır. Düşman ızgaraya yeniden eklenmez (çift kayıt temas hasarını ikiye katlar).

## Yedek değerler (JSON `min_spawn_dist` / `keep_out` yoksa).
const DEFAULT_MIN_SPAWN := 300.0
const DEFAULT_KEEP_OUT := 250.0
## Doğuşta bölgeler arası en az mesafe (x `area_mult`), JSON `min_sep` yoksa taban yarıçapın bu oranı (Tufan 190 -> 133):
## merkezler ayrı hortum olarak okunsun, yine de aynı kümenin yarıçapı içinde kalsın (tam yarıçap kümeden taşırırdı).
const DEFAULT_SEP_RATIO := 0.7
## Doğuş için uzak küme arama yarıçapı (görünür alanın gevşek sınırı).
const SPAWN_VIEW := 700.0
const RETARGET_RANGE := 600.0
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


## Hortum/Tufan ortak doğurma: `count` bölge, oyuncudan `min_spawn_dist` ya da daha uzakta (uzak düşman kümesi; yoksa yedek halka). `lv` becerinin seviye sözlüğü
## (radius, life, damage, interval, pull, fling, count; isteğe bağlı speed, max_dist, boss_mult, retarget_every, min_spawn_dist, keep_out;
## yoksa türe göre yedek: DEFAULT_SPEED/DEFAULT_MAX_DIST/DEFAULT_RETARGET). `push` Hortum/Tufan için kullanılmaz (sözleşme: tik hasar + çekme, bitişte fling).
## Rastgelelik: çağrı başına tam 1 `rng_combat.randf()`. Alan x `area_mult`, ömür x `wind_time_mult`, hasar x
## `bullet_dmg_mult` doğuş anında sabitlenir.
static func cast_twisters(sim: GameSim, kind: int, lv: Dictionary) -> void:
	var n := maxi(1, int(lv.get("count", 1)))
	var min_d := float(lv.get("min_spawn_dist", DEFAULT_MIN_SPAWN))
	var r := sim.rng_combat.randf()
	var far := PackedInt32Array()
	var ids := PackedInt32Array()
	sim.grid.query_circle(sim.player_pos, SPAWN_VIEW, ids)
	for id in ids:
		if (
			sim.enemies.is_alive(id)
			and sim.enemies.pos[EnemyPool.index_of(id)].distance_to(sim.player_pos) >= min_d
		):
			far.append(id)
	var base_radius := float(lv.get("radius", 150.0))
	var sep := float(lv.get("min_sep", base_radius * DEFAULT_SEP_RATIO)) * sim.stats.area_mult
	var placed := PackedVector2Array()
	for k in n:
		var p: Vector2
		if far.is_empty():
			p = sim.player_pos + Vector2.from_angle(r * TAU + TAU * float(k) / float(n)) * min_d
		else:
			var pick := (int(r * far.size()) + int(float(k * far.size()) / float(n))) % far.size()
			p = sim.enemies.pos[EnemyPool.index_of(far[pick])]
		p = _spread(p, placed, sep, sim.player_pos, min_d, r * TAU + TAU * float(k) / float(n))
		placed.append(p)
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
				"keep_out": float(lv.get("keep_out", DEFAULT_KEEP_OUT)),
				"boss_mult": float(lv.get("boss_mult", 1.0)),
				"retarget_every": float(lv.get("retarget_every", DEFAULT_RETARGET[kind])),
				"target": p,
			}
		)


## Doğuşta aynı çağrıdaki bölgeler arası en az `sep` px: çakışan bölge ötekinden uzaklaştırılır, oyuncuya `min_d`'den
## yakınsa halkaya itilir; olmazsa `min_d` halkasında açısal kaydırılır. Rastgelelik yok (`ang` yalnız sıfır uzaklık yönü).
static func _spread(
	p: Vector2, placed: PackedVector2Array, sep: float, center: Vector2, min_d: float, ang: float
) -> Vector2:
	for _pass in 3:
		for q in placed:
			if p.distance_to(q) < sep:
				var away := p - q
				p = (
					q
					+ (
						(away.normalized() if away.length() > 0.001 else Vector2.from_angle(ang))
						* sep
					)
				)
		var off := p - center
		if off.length() < min_d:
			p = (
				center
				+ (off.normalized() if off.length() > 0.001 else Vector2.from_angle(ang)) * min_d
			)
		if _clear(p, placed, sep):
			return p
	var base := (p - center).angle()
	for step in range(1, 13):
		for sign in [1.0, -1.0]:
			var c := center + Vector2.from_angle(base + sign * TAU * float(step) / 24.0) * min_d
			if _clear(c, placed, sep):
				return c
	return p


static func _clear(p: Vector2, placed: PackedVector2Array, sep: float) -> bool:
	for q in placed:
		if p.distance_to(q) < sep - 0.001:
			return false
	return true


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


## Hortum/Tufan: hedefe doğru ilerler; `retarget_left` dolunca yeni hedef (tam 1 randf). Oyuncuya `keep_out`'tan fazla
## yaklaşmaz: adım sonu `keep_out` içinde kalıp mesafeyi azaltıyorsa radyal bileşen atılır (teğet ilerleme).
func _move(sim: GameSim, i: int, dt: float) -> void:
	var z := sim.zones
	z.retarget_left[i] -= dt
	if z.retarget_left[i] <= 0.0:
		z.retarget_left[i] += (
			z.retarget_every[i] if z.retarget_every[i] > 0.0 else DEFAULT_RETARGET[z.kind[i]]
		)
		z.target[i] = _pick_target(sim, z.pos[i], z.keep_out[i])
	var to := z.target[i] - z.pos[i]
	var dist := to.length()
	if dist <= 0.0001:
		return
	var step := to / dist * minf(z.speed[i] * dt, dist)
	var rel := z.pos[i] - sim.player_pos
	var d_old := rel.length()
	var d_new := (rel + step).length()
	if d_new < z.keep_out[i] and d_new < d_old and d_old > 0.0001:
		var u := rel / d_old
		step -= u * step.dot(u)
	z.pos[i] += step


## Oyuncuya 600 px içinde ve `keep_out` dışındaki düşmanlardan biri (artan kimlik listesinden tek randf ile); aday yoksa
## bölgenin oyuncuya göre yönünde `keep_out` uzaklıkta nokta.
func _pick_target(sim: GameSim, zone_pos: Vector2, keep_out: float) -> Vector2:
	sim.grid.query_circle(sim.player_pos, RETARGET_RANGE, _ids)
	var r := sim.rng_combat.randf()
	var live := PackedInt32Array()
	for id in _ids:
		if (
			sim.enemies.is_alive(id)
			and (sim.enemies.pos[EnemyPool.index_of(id)].distance_to(sim.player_pos) >= keep_out)
		):
			live.append(id)
	if live.is_empty():
		var away := zone_pos - sim.player_pos
		var dir := away.normalized() if away.length() > 0.0001 else Vector2.RIGHT
		return sim.player_pos + dir * keep_out
	return sim.enemies.pos[EnemyPool.index_of(live[int(r * live.size())])]
