class_name RuinView
extends RefCounted
## Harabe sprite'ları: MapSim chunk'larından, oyuncunun çevresindeki chunk'lar için Sprite2D üretir ve uzaklaşanları
## serbest bırakır. Sprite'lar y-sıralı `actors` düğümünün doğrudan çocuğudur (oyuncu ile aynı sıralama). Sprite'ın
## düğüm konumu = harabenin ayak noktası. Yalnız görsel; sim'e dokunmaz.

const KEEP_RADIUS := 3  # chunk; bundan uzaktaki sprite'lar serbest bırakılır
const TINT := Color(0.82, 0.76, 0.86)
## Dekor (katı olmayan alçak parça) zemin katmanıdır: oyuncu/düşman/mermi her zaman üstünde, y-sıralamaya girmez.
## Katı yapılar oyuncuyla y-sıralıdır (arkasından geçerken örter). Böylece "üstünden geçilen" ile "geçilemeyen"
## görsel olarak ayrışır.
const DECOR_Z := -50

var _actors: Node2D = null
var _map: MapSim = null
var _sprites: Dictionary = {}  # engel indeksi -> Sprite2D
var _last_chunk: Vector2i = Vector2i(1 << 30, 1 << 30)


func bind(actors: Node2D, map: MapSim) -> void:
	clear()
	_actors = actors
	_map = map
	_last_chunk = Vector2i(1 << 30, 1 << 30)


func clear() -> void:
	for i in _sprites:
		var s: Sprite2D = _sprites[i]
		if is_instance_valid(s):
			s.queue_free()
	_sprites.clear()


## Her kare (ucuz): chunk değişmediyse hemen döner.
func follow(center: Vector2) -> void:
	if _map == null or _actors == null:
		return
	var c := MapSim.chunk_of(center)
	if c == _last_chunk:
		return
	_last_chunk = c
	_map.ensure(center)
	var keep := {}
	for dy in range(-MapSim.CHUNK_RADIUS, MapSim.CHUNK_RADIUS + 1):
		for dx in range(-MapSim.CHUNK_RADIUS, MapSim.CHUNK_RADIUS + 1):
			for i in _map.chunk_obstacles(Vector2i(c.x + dx, c.y + dy)):
				keep[i] = true
				if not _sprites.has(i):
					_make(i)
	for i in _sprites.keys():
		if keep.has(i):
			continue
		var oc := MapSim.chunk_of(_map.ob_pos[i])
		if absi(oc.x - c.x) > KEEP_RADIUS or absi(oc.y - c.y) > KEEP_RADIUS:
			var s: Sprite2D = _sprites[i]
			if is_instance_valid(s):
				s.queue_free()
			_sprites.erase(i)


func sprite_count() -> int:
	return _sprites.size()


func _make(i: int) -> void:
	var def := _map.def_of(i)
	var tex := ArtLoader.texture(str(def.get("sprite", "")))
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var foot: Array = def.get("foot", [0.5, 0.9])
	s.offset = -Vector2(float(foot[0]), float(foot[1])) * tex.get_size()
	var k := float(def.get("display_scale", 1.0))
	s.scale = Vector2(k, k)
	s.modulate = TINT
	s.position = _map.ob_foot[i]
	if _map.ob_solid[i] == 0:
		s.z_index = DECOR_Z
	_actors.add_child(s)
	_sprites[i] = s
