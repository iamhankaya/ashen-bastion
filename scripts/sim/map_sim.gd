class_name MapSim
extends RefCounted
## Chunk başına deterministik harabe yerleşimi ve taban izine uyan çarpışma daireleri. Görsel yok.
## Chunk 1024 px; oyuncunun çevresindeki 2 chunk yarıçapı tembel üretilir; her chunk `_mix(seed, cx, cy)` ile üretilir
## (üretim sırasından bağımsız, aynı tohum = aynı harita). Başlangıç çevresi boş. Mermiler engelden geçer; yalnız oyuncu
## ve "ground" düşmanlar engelden iter (resolve; elit/Lord/uçan/hayalet muaf — bilinçli, bkz. docs/dev/ruins.md).
##
## Katı harabe = `data/ruins.json` `collision` dairelerinin birleşimi (`foot` noktasına göre dünya px). Engel kaydı:
## `ob_pos`/`ob_r` = bu dairelerin sarmalayan (bounding) çemberi (yerleşim ve çakışma denetimi), `ob_foot` = sprite
## çapası. Katı harabenin sarmalayan çemberi chunk kenarından `ob_r + MIN_GAP/2` içeride tutulur; bu yüzden komşu
## chunk'ların katı harabeleri hiçbir üretim sırasında çakışmaz (komşu içeriğine bakmadan, F-ver-002).
## Daireler 256 px'lik ızgara hücrelerinde aranır; `resolve` varlığın kapladığı tüm hücrelere bakar.

const CHUNK := 1024.0
const CHUNK_RADIUS := 2
const CELL := 256.0
const START_CLEAR := 420.0
const SOLID_RANGE := Vector2i(1, 3)
const DECOR_RANGE := Vector2i(3, 6)
const MIN_GAP := 70.0
const RESOLVE_PASSES := 4  # birleşik daire kümesinde iç içe itme yakınsaması
const MAX_SUBSTEP := 12.0  # slide: alt adım uzunluğu (en küçük daire yarıçapı 24 + oyuncu 22'nin çok altında)
const PUSH_EPS := 0.01

## Engel dizileri (üretim sırası). Dekorlar da burada (solid = 0), çarpışma ızgarasında değiller.
## ob_pos/ob_r: sarmalayan çember; ob_foot: sprite çapası (dekorda ob_pos ile aynı).
var count: int = 0
var ob_pos: PackedVector2Array = PackedVector2Array()
var ob_r: PackedFloat32Array = PackedFloat32Array()
var ob_foot: PackedVector2Array = PackedVector2Array()
var ob_ruin: PackedInt32Array = PackedInt32Array()
var ob_solid: PackedByteArray = PackedByteArray()
## Çarpışma daireleri (yalnız katı engeller; üretim sırası), dünya koordinatı.
var circ_pos: PackedVector2Array = PackedVector2Array()
var circ_r: PackedFloat32Array = PackedFloat32Array()

var _seed: int = 0
var _defs: Array[Dictionary] = []
var _solid_defs: Array[int] = []
var _decor_defs: Array[int] = []
var _def_circles: Array[PackedVector3Array] = []  # def -> foot'a göre (x, y, r) daireleri
var _def_center: Array[Vector2] = []  # def -> sarmalayan çember merkezi (foot'a göre)
var _def_bound: PackedFloat32Array = PackedFloat32Array()  # def -> sarmalayan çember yarıçapı
var _chunks: Dictionary = {}  # chunk anahtarı -> PackedInt32Array (engel indeksleri)
var _cells: Dictionary = {}  # hücre anahtarı -> PackedInt32Array (daire indeksleri)
var circ_first: PackedInt32Array = PackedInt32Array()  # engel -> ilk daire indeksi
var circ_count: PackedInt32Array = PackedInt32Array()  # engel -> daire sayısı (dekor 0)
var _last_chunk: Vector2i = Vector2i(1 << 30, 1 << 30)


func _init(p_seed: int = 0, defs: Array = []) -> void:
	_seed = p_seed
	for d in defs:
		if d is Dictionary:
			_defs.append(d)
	for i in _defs.size():
		var solid := bool(_defs[i].get("solid", false))
		if solid:
			_solid_defs.append(i)
		else:
			_decor_defs.append(i)
		var circles := circles_of_def(_defs[i]) if solid else PackedVector3Array()
		var center := Vector2.ZERO
		var bound := float((_defs[i].get("footprint", {}) as Dictionary).get("w", 100.0)) * 0.5
		if not circles.is_empty():
			center = _bounds_center(circles)
			bound = 0.0
			for c in circles:
				bound = maxf(bound, Vector2(c.x, c.y).distance_to(center) + c.z)
		_def_circles.append(circles)
		_def_center.append(center)
		_def_bound.append(bound)


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


## Katı çarpışma daireleri: Array[Vector3] (x, y, yarıçap), merkez çevresindeki chunk'lar.
func obstacles_near(center: Vector2) -> Array[Vector3]:
	ensure(center)
	var out: Array[Vector3] = []
	var c := chunk_of(center)
	for dy in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for dx in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			for i in chunk_obstacles(Vector2i(c.x + dx, c.y + dy)):
				if ob_solid[i] == 1:
					for k in range(circ_first[i], circ_first[i] + circ_count[i]):
						out.append(Vector3(circ_pos[k].x, circ_pos[k].y, circ_r[k]))
	return out


## `pos`'ta `radius` yarıçaplı daire katı engellerden dışarı itilir; yeni konumu döndürür. Varlığın kapladığı tüm
## hücrelere bakılır (komşu hücre kaçağı yok). Birleşik daire kümesinde birkaç geçişle yakınsar; itme daire
## normali boyuncadır, yani hareketin yüzeye dik bileşeni silinir, teğet bileşeni kalır (kenar boyunca kayma).
func resolve(pos: Vector2, radius: float) -> Vector2:
	if _cells.is_empty():
		return pos
	for _pass in RESOLVE_PASSES:
		var moved := false
		var cx0 := floori((pos.x - radius) / CELL)
		var cx1 := floori((pos.x + radius) / CELL)
		var cy0 := floori((pos.y - radius) / CELL)
		var cy1 := floori((pos.y + radius) / CELL)
		for cy in range(cy0, cy1 + 1):
			for cx in range(cx0, cx1 + 1):
				var found: Variant = _cells.get(cx * 1000003 + cy)
				if found == null:
					continue
				var list: PackedInt32Array = found
				for i in list:
					var d := pos - circ_pos[i]
					var min_d := circ_r[i] + radius
					var l2 := d.length_squared()
					if l2 >= (min_d - PUSH_EPS) * (min_d - PUSH_EPS):
						continue
					moved = true
					if l2 < 0.0001:
						pos = circ_pos[i] + Vector2(min_d, 0.0)
					else:
						pos = circ_pos[i] + d * (min_d / sqrt(l2))
		if not moved:
			break
	return pos


## `from`'dan `to`'ya hareket: en çok MAX_SUBSTEP uzunluklu alt adımlarla ilerler, her adımda resolve eder
## (hızlı hareket ince engeli atlayamaz). Başlangıç konumu engel dışında varsayılır.
func slide(from: Vector2, to: Vector2, radius: float) -> Vector2:
	var n := maxi(1, ceili(from.distance_to(to) / MAX_SUBSTEP))
	var step := (to - from) / float(n)
	var pos := from
	for _k in n:
		pos = resolve(pos + step, radius)
	return pos


## Harabe tanımının çarpışma daireleri (foot'a göre x, y, r). `collision` yoksa foot'ta tek daire (footprint.w/2).
static func circles_of_def(def: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	var raw: Variant = def.get("collision")
	if raw is Array:
		for c in raw:
			if c is Dictionary:
				out.append(
					Vector3(float(c.get("x", 0.0)), float(c.get("y", 0.0)), float(c.get("r", 1.0)))
				)
	if out.is_empty():
		var w := float((def.get("footprint", {}) as Dictionary).get("w", 100.0))
		out.append(Vector3(0.0, 0.0, w * 0.5))
	return out


## Dairelerin sarmalayan çemberi (merkez, yarıçap) — foot'a göre. Merkez: daire sınırlarının kutu ortası.
static func bounds_of_def(def: Dictionary) -> Vector3:
	var circles := circles_of_def(def)
	var center := _bounds_center(circles)
	var bound := 0.0
	for c in circles:
		bound = maxf(bound, Vector2(c.x, c.y).distance_to(center) + c.z)
	return Vector3(center.x, center.y, bound)


static func _bounds_center(circles: PackedVector3Array) -> Vector2:
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for c in circles:
		lo = Vector2(minf(lo.x, c.x - c.z), minf(lo.y, c.y - c.z))
		hi = Vector2(maxf(hi.x, c.x + c.z), maxf(hi.y, c.y + c.z))
	return (lo + hi) * 0.5


func _generate(c: Vector2i) -> void:
	var key := _chunk_key(c)
	if _chunks.has(key):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix(_seed, c.x, c.y)
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
			var r := _def_bound[di]
			var u := Vector2(rng.randf(), rng.randf())
			var p := origin + u * CHUNK
			if solid:
				# sarmalayan çember chunk kenarından r + MIN_GAP/2 içeride: komşu chunk'larla çakışma imkânsız
				var m := minf(r + MIN_GAP * 0.5, CHUNK * 0.5)
				p = origin + Vector2(m, m) + u * (CHUNK - 2.0 * m)
			if p.length() < START_CLEAR + r:
				continue
			if solid and _overlaps_solid(p, r, made):
				continue
			var idx := count
			count += 1
			ob_pos.append(p)
			ob_r.append(r)
			ob_foot.append(p - _def_center[di])
			ob_ruin.append(di)
			ob_solid.append(1 if solid else 0)
			made.append(idx)
			circ_first.append(circ_pos.size())
			if solid:
				var foot := p - _def_center[di]
				for cc in _def_circles[di]:
					circ_pos.append(foot + Vector2(cc.x, cc.y))
					circ_r.append(cc.z)
					_register_cell(circ_pos.size() - 1)
			circ_count.append(circ_pos.size() - circ_first[idx])
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


func _register_cell(ci: int) -> void:
	var lo := circ_pos[ci] - Vector2(circ_r[ci], circ_r[ci])
	var hi := circ_pos[ci] + Vector2(circ_r[ci], circ_r[ci])
	for cy in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
		for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			var k := cx * 1000003 + cy
			var arr: PackedInt32Array = _cells.get(k, PackedInt32Array())
			arr.append(ci)
			_cells[k] = arr


static func _chunk_key(c: Vector2i) -> int:
	return c.x * 1000003 + c.y


## Sürümler/platformlar arası kararlı tamsayı karıştırma (Variant hash'ine bağlı değil).
static func _mix(a: int, b: int, c: int) -> int:
	var x := (a ^ (b * 0x9E3779B1) ^ (c * 0x85EBCA6B)) & 0x7FFFFFFFFFFFFFFF
	x = ((x ^ (x >> 30)) * 0x3F58476D1CE4E5B9) & 0x7FFFFFFFFFFFFFFF
	x = ((x ^ (x >> 27)) * 0x14D049BB133111EB) & 0x7FFFFFFFFFFFFFFF
	return x ^ (x >> 31)
