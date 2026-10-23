class_name SpatialHash
extends RefCounted
## Hücre ızgarası (varsayılan 96 px), sabit boyutlu kova tablosu + bağlı liste (Dictionary/dizi tahsisi yok).
## Her adım yeniden kurulur; query_circle sonucu ARTAN id sıralıdır (determinizm). Farklı hücreler aynı kovaya
## düşebilir: sonuç yine mesafeyle süzülür, kova sorgu başına bir kez gezilir.

const BUCKETS := 1024  # 2'nin kuvveti
const BUCKET_MASK := BUCKETS - 1

var cell: float = 96.0
## Deterministik iş sayaçları (sim `work` sözlüğüne aktarır).
var stat_inserts: int = 0
var stat_queries: int = 0
var stat_cells_scanned: int = 0

var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _ids: PackedInt32Array = PackedInt32Array()
var _pts: PackedVector2Array = PackedVector2Array()
var _n: int = 0
var _stamp: PackedInt32Array = PackedInt32Array()
var _query_no: int = 0


func _init(p_cell: float = 96.0) -> void:
	cell = p_cell
	_head.resize(BUCKETS)
	_head.fill(-1)
	_stamp.resize(BUCKETS)
	_next.resize(512)
	_ids.resize(512)
	_pts.resize(512)


func clear() -> void:
	_head.fill(-1)
	_n = 0


func insert(id: int, pos: Vector2) -> void:
	if _n >= _ids.size():
		var cap := _ids.size() * 2
		_next.resize(cap)
		_ids.resize(cap)
		_pts.resize(cap)
	var slot := _n
	_n += 1
	_ids[slot] = id
	_pts[slot] = pos
	var b := _bucket(floori(pos.x / cell), floori(pos.y / cell))
	_next[slot] = _head[b]
	_head[b] = slot
	stat_inserts += 1


## out temizlenir; id'ler ARTAN sıralı döner.
func query_circle(center: Vector2, radius: float, out: PackedInt32Array) -> void:
	out.resize(0)
	stat_queries += 1
	var lx := floori((center.x - radius) / cell)
	var hx := floori((center.x + radius) / cell)
	var ly := floori((center.y - radius) / cell)
	var hy := floori((center.y + radius) / cell)
	var r2 := radius * radius
	if float(hx - lx + 1) * float(hy - ly + 1) > float(_n):
		# Çok geniş daire: hücre gezmek yerine tüm girdileri tara (sonuç aynı, süre sınırlı)
		stat_cells_scanned += _n
		for slot in _n:
			if _pts[slot].distance_squared_to(center) <= r2:
				out.append(_ids[slot])
		out.sort()
		return
	_query_no += 1
	for cy in range(ly, hy + 1):
		for cx in range(lx, hx + 1):
			stat_cells_scanned += 1
			var b := _bucket(cx, cy)
			if _stamp[b] == _query_no:
				continue
			_stamp[b] = _query_no
			var slot := _head[b]
			while slot >= 0:
				if _pts[slot].distance_squared_to(center) <= r2:
					out.append(_ids[slot])
				slot = _next[slot]
	out.sort()


func _bucket(cx: int, cy: int) -> int:
	return ((cx * 73856093) ^ (cy * 19349663)) & BUCKET_MASK
