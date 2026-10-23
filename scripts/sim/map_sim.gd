class_name MapSim
extends RefCounted
## Chunk başına deterministik harabe yerleşimi ve dairesel engeller. Görsel yok.
## Chunk 1024 px; oyuncunun çevresindeki 2 chunk yarıçapı tembel üretilir; her chunk `hash(seed, cx, cy)` ile üretilir
## (üretim sırasından bağımsız, aynı tohum = aynı harita). Başlangıç çevresi boş. Mermiler engelden geçer; yalnız oyuncu
## ve "ground" düşmanlar engelden iter (resolve). Engel daireleri 256 px'lik ızgara hücrelerinde aranır.

const CHUNK := 1024.0
const CHUNK_RADIUS := 2
const CELL := 256.0
const START_CLEAR := 420.0
const SOLID_RANGE := Vector2i(1, 3)
const DECOR_RANGE := Vector2i(3, 6)
const MIN_GAP := 70.0
const CELL_PAD := 90.0  # hücre kaydında engel çapına eklenen pay (en büyük varlık yarıçapı)

## Engel dizileri (üretim sırası). Dekorlar da burada (solid = 0), çarpışma ızgarasında değiller.
var count: int = 0
var ob_pos: PackedVector2Array = PackedVector2Array()
var ob_r: PackedFloat32Array = PackedFloat32Array()
var ob_ruin: PackedInt32Array = PackedInt32Array()
var ob_solid: PackedByteArray = PackedByteArray()

var _seed: int = 0
var _defs: Array[Dictionary] = []
var _solid_defs: Array[int] = []
var _decor_defs: Array[int] = []
var _chunks: Dictionary = {}  # chunk anahtarı -> PackedInt32Array (engel indeksleri)
var _cells: Dictionary = {}  # hücre anahtarı -> PackedInt32Array (katı engel indeksleri)
var _last_chunk: Vector2i = Vector2i(1 << 30, 1 << 30)


func _init(p_seed: int = 0, defs: Array = []) -> void:
	_seed = p_seed
	for d in defs:
		if d is Dictionary:
			_defs.append(d)
	for i in _defs.size():
		if bool(_defs[i].get("solid", false)):
			_solid_defs.append(i)
		else:
			_decor_defs.append(i)


## Harabe tanımı (data/ruins.json kaydı) — engel `ob_ruin` indeksi.
func def_of(i: int) -> Dictionary:
	return _defs[ob_ruin[i]]


static func chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


## Merkez çevresindeki chunk'ları üretir (chunk değişmediyse hemen döner).
func ensure(center: Vector2) -> void:
	var c := chunk_of(center)
	if c == _last_chunk:
		return
	_last_chunk = c
	for dy in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for dx in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			_generate(Vector2i(c.x + dx, c.y + dy))


## Chunk'taki engel indeksleri (üretilmemişse boş).
func chunk_obstacles(c: Vector2i) -> PackedInt32Array:
	return _chunks.get(_chunk_key(c), PackedInt32Array())


## Dairesel katı engeller: Array[Vector3] (x, y, yarıçap), merkez çevresindeki chunk'lar.
func obstacles_near(center: Vector2) -> Array[Vector3]:
	ensure(center)
	var out: Array[Vector3] = []
	var c := chunk_of(center)
	for dy in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for dx in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			for i in chunk_obstacles(Vector2i(c.x + dx, c.y + dy)):
				if ob_solid[i] == 1:
					out.append(Vector3(ob_pos[i].x, ob_pos[i].y, ob_r[i]))
	return out


## `pos`'ta `radius` yarıçaplı daire katı engellerden dışarı itilir; yeni konumu döndürür.
func resolve(pos: Vector2, radius: float) -> Vector2:
	if _cells.is_empty():
		return pos
	var found: Variant = _cells.get(_cell_key(pos))
	if found == null:
		return pos
	var list: PackedInt32Array = found
	for i in list:
		var d := pos - ob_pos[i]
		var min_d := ob_r[i] + radius
		var l2 := d.length_squared()
		if l2 < min_d * min_d:
			if l2 < 0.0001:
				pos = ob_pos[i] + Vector2(min_d, 0.0)
			else:
				pos = ob_pos[i] + d * (min_d / sqrt(l2))
	return pos


func _generate(c: Vector2i) -> void:
	var key := _chunk_key(c)
	if _chunks.has(key):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, c.x, c.y])
	var made := PackedInt32Array()
	if not _defs.is_empty():
		var origin := Vector2(c.x * CHUNK, c.y * CHUNK)
		var n_solid := (
			rng.randi_range(SOLID_RANGE.x, SOLID_RANGE.y) if not _solid_defs.is_empty() else 0
		)
		var n_decor := (
			rng.randi_range(DECOR_RANGE.x, DECOR_RANGE.y) if not _decor_defs.is_empty() else 0
		)
		for k in n_solid + n_decor:
			var solid := k < n_solid
			var di := _pick(rng, _solid_defs if solid else _decor_defs)
			var def := _defs[di]
			var r := float((def.get("footprint", {}) as Dictionary).get("w", 100.0)) * 0.5
			var p := origin + Vector2(rng.randf(), rng.randf()) * CHUNK
			if p.length() < START_CLEAR + r:
				continue
			if solid and _overlaps_solid(p, r, made):
				continue
			var idx := count
			count += 1
			ob_pos.append(p)
			ob_r.append(r)
			ob_ruin.append(di)
			ob_solid.append(1 if solid else 0)
			made.append(idx)
			if solid:
				_register_cells(idx)
	_chunks[key] = made


func _overlaps_solid(p: Vector2, r: float, mine: PackedInt32Array) -> bool:
	for i in mine:
		if ob_solid[i] == 1 and p.distance_to(ob_pos[i]) < r + ob_r[i] + MIN_GAP:
			return true
	return false


func _pick(rng: RandomNumberGenerator, pool: Array[int]) -> int:
	var total := 0.0
	for di in pool:
		total += float(_defs[di].get("weight", 1.0))
	var t := rng.randf() * total
	for di in pool:
		t -= float(_defs[di].get("weight", 1.0))
		if t <= 0.0:
			return di
	return pool[pool.size() - 1]


func _register_cells(idx: int) -> void:
	var reach := ob_r[idx] + CELL_PAD
	var lo := ob_pos[idx] - Vector2(reach, reach)
	var hi := ob_pos[idx] + Vector2(reach, reach)
	for cy in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
		for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			var k := cx * 1000003 + cy
			var arr: PackedInt32Array = _cells.get(k, PackedInt32Array())
			arr.append(idx)
			_cells[k] = arr


static func _chunk_key(c: Vector2i) -> int:
	return c.x * 1000003 + c.y


static func _cell_key(p: Vector2) -> int:
	return floori(p.x / CELL) * 1000003 + floori(p.y / CELL)
