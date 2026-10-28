class_name SpawnDirector
extends RefCounted
## `waves` verisine göre doğurma, uzak düşmanı geri taşıma konumu, spawn kaybı sayacı.
## rate/group (sürekli), burst (halka dalgası), boss (uyarı + doğuş; Kale Lordu dahil) ve after_lord satırları.

## Doğma halkası: kamera yarı-köşegeni (√(540²+1200²) ≈ 1315,9) + 80 px.
const RING_RADIUS := 1395.9
const GROUP_SPREAD := 36.0
## Sürekli doğuş havuzun bu kadarını boş bırakır: boss/Lord/çağırma/halka dalgası için yer kalsın.
const BOSS_RESERVE := 24

var waves: Dictionary = {}
## Test kancası (M10/F-018): false iken Lord için `_make_room` çağrılmaz. Üretimde hep true; durum hash'ine girmez.
var make_room_enabled: bool = true
var _rows: Array = []
var _acc: PackedFloat64Array = PackedFloat64Array()  # rate: birikim; group: kalan bekleme süresi
var _skip_before: float = 0.0
var _done: PackedByteArray = PackedByteArray()  # burst/boss: tetiklendi
var _warned: PackedByteArray = PackedByteArray()  # boss: uyarı verildi
var _spawned: PackedByteArray = PackedByteArray()  # boss: gerçekten doğdu


func _init(p_waves: Dictionary = {}) -> void:
	waves = p_waves
	var rows: Variant = waves.get("rows", [])
	_rows = rows if rows is Array else []
	_acc.resize(_rows.size())
	_done.resize(_rows.size())
	_warned.resize(_rows.size())
	_spawned.resize(_rows.size())
	for k in _rows.size():
		_acc[k] = 0.0
		_done[k] = 0
		_warned[k] = 0
		_spawned[k] = 0


func step(sim: GameSim) -> void:
	var t := sim.time
	var dt := GameSim.STEP
	var cap := mini(Difficulty.alive_cap(V21Sim.curve_t(sim)), EnemyPool.CAP - BOSS_RESERVE)
	var after := sim.end_mode == GameSim.END_MODE_LORD and t >= sim.end_time
	var endless := sim.end_mode == GameSim.END_MODE_ENDLESS
	var rscale := V21Sim.rate_scale(sim)
	var al: Dictionary = waves.get("after_lord", {})
	for k in _rows.size():
		var row: Dictionary = _rows[k]
		var kind := str(row.get("kind", ""))
		if kind == "burst":
			_burst(sim, k, row, t)
			continue
		if kind == "boss":
			_boss(sim, k, row, t)
			continue
		if kind != "rate" and kind != "group":
			continue
		var from_t := float(row.get("from", 0.0))
		var to_t := float(row.get("to", 0.0))
		var type_id := StringName(str(row.get("type", "")))
		var rate_mult := 1.0
		var f := (t - from_t) / (to_t - from_t)
		if t >= to_t:
			f = 1.0
			# Sonsuz (K-C1): satırlar son değerinde sürer, after_lord yok. Aksi halde yalnız after_lord piyade
			# sürekli doğuşu (Lord doğduktan sonra yarı hızda) sürer, kargalar durur.
			if not endless:
				if not (after and kind == "rate" and type_id == &"curumus_piyade"):
					continue
				rate_mult = float(al.get("piyade_rate_mult", 1.0))
		elif t < from_t:
			continue
		if kind == "rate":
			var r: Array = row.get("rate", [0.0, 0.0])
			_acc[k] += lerpf(float(r[0]), float(r[1]), f) * rate_mult * rscale * dt
			while _acc[k] >= 1.0:
				_acc[k] -= 1.0
				if sim.enemies.count < cap:
					sim.spawn_enemy(type_id, ring_position(sim, TAU * sim.rng_spawn.randf()))
			_acc[k] = minf(_acc[k], 1.0)
		else:
			_acc[k] -= dt
			if _acc[k] > 0.0:
				continue
			var g: Array = row.get("group", [1, 1])
			var ev: Array = row.get("every", [10.0, 10.0])
			_acc[k] = lerpf(float(ev[0]), float(ev[1]), f)
			var n := V21Sim.count(sim, lerpf(float(g[0]), float(g[1]), f))
			var center := ring_position(sim, TAU * sim.rng_spawn.randf())
			for j in n:
				if sim.enemies.count >= cap:
					break
				var off := (
					Vector2.from_angle(TAU * sim.rng_spawn.randf())
					* (GROUP_SPREAD * sim.rng_spawn.randf())
				)
				sim.spawn_enemy(type_id, center + off)


## Halka dalgası: `at` anında `count` düşman oyuncunun çevresindeki doğma halkasına eşit aralıkla (havuz sınırı hariç
## eşzamanlı sınıra bağlı değil).
func _burst(sim: GameSim, k: int, row: Dictionary, t: float) -> void:
	if _done[k] == 1 or t < float(row.get("at", 0.0)):
		return
	_done[k] = 1
	var type_id := StringName(str(row.get("type", "")))
	var n := V21Sim.count(sim, float(int(row.get("count", 1))))
	var a0 := TAU * sim.rng_spawn.randf()
	for j in n:
		var a := (
			a0
			+ (
				TAU * float(j) / float(n)
				if bool(row.get("ring", true))
				else TAU * sim.rng_spawn.randf()
			)
		)
		sim.spawn_enemy(type_id, ring_position(sim, a))


## Boss/Lord: `warn` sn önce uyarı (olay + sinyal), `at` anında doğuş. Havuz doluysa doğuş kaybolur (yeniden denenmez).
func _boss(sim: GameSim, k: int, row: Dictionary, t: float) -> void:
	var type_id := StringName(str(row.get("type", "")))
	var def := sim.data.get_enemy(type_id)
	if def == null or (def.ai == &"lord" and not sim.lord_mode()):
		return
	var at := float(row.get("at", 0.0))
	if _warned[k] == 0 and t >= at - float(row.get("warn", 5.0)):
		_warned[k] = 1
		sim.log_event(SimEvents.BOSS_WARNING, {"kind": type_id})
		sim.bus.boss_warning.emit(type_id)
	# Lord kazanmanın tek yolu: start_time/debug_set_time ile atlanmış olsa da (henüz doğmadıysa) doğar.
	var is_lord := def.ai == &"lord"
	if (_done[k] == 0 or (is_lord and _spawned[k] == 0)) and t >= at:
		_done[k] = 1
		if is_lord and make_room_enabled and sim.enemies.count >= EnemyPool.CAP:
			_make_room(sim)
		var id := sim.spawn_enemy(type_id, ring_position(sim, TAU * sim.rng_spawn.randf()))
		if id >= 0:
			_spawned[k] = 1
			sim.log_event(SimEvents.BOSS_SPAWN, {"enemy_type": type_id, "id": id})
			sim.bus.boss_spawned.emit(type_id)


## Lord tekrarı (V21Sim.step) için: havuz doluysa yer açar (`_boss` ile aynı kural ve kanca).
func make_room_for_lord(sim: GameSim) -> void:
	if make_room_enabled and sim.enemies.count >= EnemyPool.CAP:
		_make_room(sim)


## Havuz doluyken Lord için oyuncudan en uzak sıradan (elit olmayan) düşmanı sessizce kaldırır (XP/öldürme yok).
func _make_room(sim: GameSim) -> void:
	var e := sim.enemies
	var best := -1
	var best_d := -1.0
	for i in EnemyPool.CAP:
		if e.alive[i] == 1 and not e.is_elite(i):
			var d := e.pos[i].distance_squared_to(sim.player_pos)
			if d > best_d:
				best_d = d
				best = i
	if best >= 0:
		e.kill(EnemyPool.make_id(e.gen[best], best))


## Burst/boss tetik durumunun özeti (state_hash için).
func progress_hash() -> int:
	var h := 0
	for k in _rows.size():
		h = h * 7 + int(_done[k]) + 2 * int(_warned[k]) + 4 * int(_spawned[k])
		h &= 0x3FFFFFFFFFFF
	return h


## start_time / debug_set_time atlamasında: at < t olan olaylar "yapıldı" işaretlenir (U1'de at olayı yok).
func skip_to(t: float) -> void:
	_skip_before = maxf(_skip_before, t)
	for k in _rows.size():
		var row: Dictionary = _rows[k]
		var kind := str(row.get("kind", ""))
		var at := float(row.get("at", 0.0))
		if kind == "burst" and at < t:
			_done[k] = 1
		elif kind == "boss":
			if at < t:
				_done[k] = 1
			if at - float(row.get("warn", 5.0)) < t:
				_warned[k] = 1


## Oyuncu çevresindeki doğma halkasında verilen açıda konum.
func ring_position(sim: GameSim, angle: float) -> Vector2:
	return sim.player_pos + Vector2.from_angle(angle) * RING_RADIUS


## Uzaklaşan düşmanın taşınacağı konum: oyuncunun hareket yönündeki halka (durağansa rastgele açı).
func recycle_position(sim: GameSim) -> Vector2:
	var mv := sim.last_move
	var base := mv.angle() if mv.length_squared() > 0.01 else TAU * sim.rng_spawn.randf()
	return ring_position(sim, base + (sim.rng_spawn.randf() - 0.5) * 1.2)
