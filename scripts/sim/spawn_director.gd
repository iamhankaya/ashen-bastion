class_name SpawnDirector
extends RefCounted
## `waves` verisine göre doğurma, uzak düşmanı geri taşıma konumu, spawn kaybı sayacı.
## U1: rate ve group satırları. burst/boss/lord satırları U2'dedir (burada yok sayılır).

## Doğma halkası: kamera yarı-köşegeni (√(540²+1200²) ≈ 1315,9) + 80 px.
const RING_RADIUS := 1395.9
const GROUP_SPREAD := 36.0

var waves: Dictionary = {}
var _rows: Array = []
var _acc: PackedFloat64Array = PackedFloat64Array()  # rate: birikim; group: kalan bekleme süresi
var _skip_before: float = 0.0


func _init(p_waves: Dictionary = {}) -> void:
	waves = p_waves
	var rows: Variant = waves.get("rows", [])
	_rows = rows if rows is Array else []
	_acc.resize(_rows.size())
	for k in _rows.size():
		_acc[k] = 0.0


func step(sim: GameSim) -> void:
	var t := sim.time
	var dt := GameSim.STEP
	var cap := Difficulty.alive_cap(t)
	for k in _rows.size():
		var row: Dictionary = _rows[k]
		var kind := str(row.get("kind", ""))
		if kind != "rate" and kind != "group":
			continue
		var from_t := float(row.get("from", 0.0))
		var to_t := float(row.get("to", 0.0))
		if t < from_t or t >= to_t:
			continue
		var f := (t - from_t) / (to_t - from_t)
		var type_id := StringName(str(row.get("type", "")))
		if kind == "rate":
			var r: Array = row.get("rate", [0.0, 0.0])
			_acc[k] += lerpf(float(r[0]), float(r[1]), f) * dt
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
			var n := roundi(lerpf(float(g[0]), float(g[1]), f))
			var center := ring_position(sim, TAU * sim.rng_spawn.randf())
			for j in n:
				if sim.enemies.count >= cap:
					break
				var off := (
					Vector2.from_angle(TAU * sim.rng_spawn.randf())
					* (GROUP_SPREAD * sim.rng_spawn.randf())
				)
				sim.spawn_enemy(type_id, center + off)


## start_time / debug_set_time atlamasında: at < t olan olaylar "yapıldı" işaretlenir (U1'de at olayı yok).
func skip_to(t: float) -> void:
	_skip_before = maxf(_skip_before, t)


## Oyuncu çevresindeki doğma halkasında verilen açıda konum.
func ring_position(sim: GameSim, angle: float) -> Vector2:
	return sim.player_pos + Vector2.from_angle(angle) * RING_RADIUS


## Uzaklaşan düşmanın taşınacağı konum: oyuncunun hareket yönündeki halka (durağansa rastgele açı).
func recycle_position(sim: GameSim) -> Vector2:
	var mv := sim.last_move
	var base := mv.angle() if mv.length_squared() > 0.01 else TAU * sim.rng_spawn.randf()
	return ring_position(sim, base + (sim.rng_spawn.randf() - 0.5) * 1.2)
