class_name SpatialHash
extends RefCounted
## Hücre ızgarası (varsayılan 96 px). Her adım yeniden kurulur; çağıran artan indeks sırasıyla ekler.
## query_circle sonucu ARTAN id sıralıdır (determinizm). U1-1 bu gövdeyi hız için yeniden yazabilir; sözleşme değişmez.

var cell: float = 96.0
## Deterministik iş sayaçları (sim `work` sözlüğüne aktarır).
var stat_inserts: int = 0
var stat_queries: int = 0
var stat_cells_scanned: int = 0

var _cells: Dictionary = {}  # Vector2i -> PackedInt32Array (indeks: _ids sırası)
var _ids: PackedInt32Array = PackedInt32Array()
var _pts: PackedVector2Array = PackedVector2Array()


func _init(p_cell: float = 96.0) -> void:
	cell = p_cell


func clear() -> void:
	_cells.clear()
	_ids.resize(0)
	_pts.resize(0)


func insert(id: int, pos: Vector2) -> void:
	var slot := _ids.size()
	_ids.append(id)
	_pts.append(pos)
	var key := _key(pos)
	if not _cells.has(key):
		_cells[key] = PackedInt32Array()
	var arr: PackedInt32Array = _cells[key]
	arr.append(slot)
	_cells[key] = arr
	stat_inserts += 1


## out temizlenir; id'ler ARTAN sıralı döner.
func query_circle(center: Vector2, radius: float, out: PackedInt32Array) -> void:
	out.resize(0)
	stat_queries += 1
	var lo := _key(center - Vector2(radius, radius))
	var hi := _key(center + Vector2(radius, radius))
	var r2 := radius * radius
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			stat_cells_scanned += 1
			var key := Vector2i(cx, cy)
			if not _cells.has(key):
				continue
			for slot in _cells[key]:
				if _pts[slot].distance_squared_to(center) <= r2:
					out.append(_ids[slot])
	out.sort()


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))
