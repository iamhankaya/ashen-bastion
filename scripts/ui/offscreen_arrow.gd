class_name OffscreenArrow
extends Control
## Ekran dışı eklenti oku: oyuncuya en yakın canlı eklenti ekran dışındaysa kenarda 84 px yuvarlak ok (güvenli alan içinde,
## aynı anda ≤1). DESIGN §2.2. Kamera oyuncuyu izlediğinden kamera konumu = `sim.player_pos` (sarsıntı yok sayılır);
## görünüm boyutu `get_viewport_rect()`; konum hesabı saf `place()` içindedir. Gizli doğar; `bind` görünür yapar.

const SIZE := 84.0
const ICON_PX := 50.0
const ALPHA := 0.7
const MARGIN := SIZE * 0.5 + 8.0
const RING_W := 5.0

var _sim: GameSim = null
var _info: Dictionary = {"visible": false, "pos": Vector2.ZERO, "angle": 0.0}
var _kind: int = -1
var _icons: Array[Texture2D] = []
var _colors: Array[Color] = []


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(sim: GameSim) -> void:
	_sim = sim
	visible = sim != null
	_icons.clear()
	_colors.clear()
	_kind = -1
	_info = {"visible": false, "pos": Vector2.ZERO, "angle": 0.0}
	if sim != null:
		for id in sim.data.pickup_ids:
			var def := sim.data.get_pickup(id)
			_icons.append(ArtLoader.texture(def.icon))
			_colors.append(PickupRenderer.rarity_color(def.rarity))
	queue_redraw()


@warning_ignore("unused_parameter")
func refresh(dt: float) -> void:
	if not visible or _sim == null:
		return
	var was: bool = _info["visible"]
	var idx := nearest_pickup(_sim)
	if idx < 0:
		_info["visible"] = false
		_kind = -1
	else:
		var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1080, 2400)
		var origin := global_position if is_inside_tree() else Vector2.ZERO
		var safe := Rect2(origin, size)
		_kind = _sim.pickups.kind_idx[idx]
		_info = place(_sim.pickups.pos[idx], _sim.player_pos, vp, safe, MARGIN)
	if was or _info["visible"]:
		queue_redraw()


## Oyuncuya en yakın canlı eklentinin indeksi (yoksa -1; eşitlikte en düşük indeks).
static func nearest_pickup(sim: GameSim) -> int:
	var best := -1
	var best_d := INF
	for i in sim.pickups.count:
		var d := sim.pickups.pos[i].distance_squared_to(sim.player_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## {"visible": bool, "pos": Vector2, "angle": float}: hedef (dünya) ekrandaysa gizli; değilse ekran merkezinden hedefe
## çizilen ışının güvenli dikdörtgenin (margin içeri) kenarıyla kesişimi (ekran koordinatı); angle = ışının yönü (rad).
## cam_pos = ekran merkezindeki dünya noktası, view = ekran boyutu (1 dünya px = 1 ekran px).
static func place(
	target: Vector2, cam_pos: Vector2, view: Vector2, safe: Rect2, margin: float
) -> Dictionary:
	var center := view * 0.5
	var s := center + (target - cam_pos)
	if Rect2(Vector2.ZERO, view).has_point(s):
		return {"visible": false, "pos": s, "angle": 0.0}
	var d := s - center
	var inner := safe.grow(-margin)
	var t := INF
	if d.x > 0.0:
		t = minf(t, (inner.end.x - center.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, (inner.position.x - center.x) / d.x)
	if d.y > 0.0:
		t = minf(t, (inner.end.y - center.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, (inner.position.y - center.y) / d.y)
	var pos := center + d * minf(t, 1.0)
	pos = Vector2(
		clampf(pos.x, inner.position.x, inner.end.x), clampf(pos.y, inner.position.y, inner.end.y)
	)
	return {"visible": true, "pos": pos, "angle": d.angle()}


func _draw() -> void:
	if not bool(_info["visible"]) or _kind < 0:
		return
	var origin := global_position if is_inside_tree() else Vector2.ZERO
	var c: Vector2 = (_info["pos"] as Vector2) - origin
	var ang: float = _info["angle"]
	var col: Color = _colors[_kind] if _kind < _colors.size() else UiKit.KEMIK_300
	draw_circle(c, SIZE * 0.5, Color(UiKit.MOR_900, ALPHA))
	draw_arc(c, SIZE * 0.5 - RING_W * 0.5, 0.0, TAU, 40, Color(col, ALPHA), RING_W, true)
	var tex: Texture2D = _icons[_kind] if _kind < _icons.size() else null
	if tex != null:
		var h := ICON_PX * 0.5
		draw_texture_rect(
			tex, Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), false, Color(1, 1, 1, ALPHA + 0.2)
		)
	# dışa bakan üçgen işaret
	var dir := Vector2.from_angle(ang)
	var nrm := Vector2(-dir.y, dir.x)
	var tip := c + dir * (SIZE * 0.5 + 12.0)
	var base := c + dir * (SIZE * 0.5 - 2.0)
	draw_colored_polygon(
		PackedVector2Array([tip, base + nrm * 12.0, base - nrm * 12.0]), Color(col, ALPHA)
	)
