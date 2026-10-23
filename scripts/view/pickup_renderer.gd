class_name PickupRenderer
extends Node2D
## Yerdeki eklentiler + bomba fitili/yarıçap görünümü (≤12 öğe, `_draw`). Sim'i yalnız okur (DESIGN §2.2, §2.3, §2.5).
## Katman: zemin parlaması (additive çocuk) → gölge → ikon; bomba: fitilde dolgu + kesikli halka, yerdeyken yaklaşınca
## yarıçap önizlemesi. Toplama efektleri (ikon uçuşu, iksir artıları, çekim/etki halkası) küçük bir halka tamponda yaşar.
## Görünüm saati (`_t`) yalnız `refresh(dt)` ile ilerler; WON/LOST'ta bomba halkası gizlenir (bomba patlamaz).

const ICON_SIZE := 80.0
const SHADOW_SIZE := Vector2(60.0, 16.0)
const SHADOW_ALPHA := 0.45
const GLOW_SIZE := Vector2(140.0, 80.0)
const GLOW_ALPHA := 0.55
const BOB_PX := 6.0
const BOB_HZ := 0.9
const SPAWN_STEPS := 16
const SPAWN_PEAK := 1.15
const BLINK_HZ := 2.5
const BLINK_LOW := 0.45
const FADE_STEPS := 9  # son 150 ms solma
const PREVIEW_NEAR := 500.0
const PREVIEW_ALPHA := 0.35
const DASH := 26.0
const GAP := 18.0
const FUSE_RING_WIDTH := 5.0
const FUSE_SPIN := deg_to_rad(20.0)
const PULSE_STEPS := 15  # fitilin son 250 ms'si
const MAX_FX := 8
const FLY_TIME := 0.12
const PLUS_TIME := 0.5
const MAGNET_TIME := 0.5
const MAGNET_RADIUS := 1400.0
const RING_TIME := 0.45
const SPARKS := 4
const RARITY_HZ := {&"common": 0.8, &"uncommon": 1.0, &"rare": 1.4}
const MAX_ITEMS := 12

enum Fx { FLY, PLUS, MAGNET, RING }

## Son çizimde kaç öğe (eklenti + bomba) çizildi; ≤ MAX_ITEMS (8 eklenti + 4 bomba).
var last_draw_items: int = 0
var last_fx_items: int = 0

var _sim: GameSim = null
var _t: float = 0.0
var _glow: Node2D = null
var _icons: Array[Texture2D] = []
var _colors: Array[Color] = []
var _hz: PackedFloat32Array = PackedFloat32Array()
var _blink_steps: int = 300
# Efekt halka tamponu.
var _fx_kind := PackedInt32Array()
var _fx_pos := PackedVector2Array()
var _fx_left := PackedFloat32Array()
var _fx_tex := PackedInt32Array()
var _fx_color: Array[Color] = []
var _fx_head: int = 0


func _init() -> void:
	_fx_kind.resize(MAX_FX)
	_fx_pos.resize(MAX_FX)
	_fx_left.resize(MAX_FX)
	_fx_tex.resize(MAX_FX)
	_fx_color.resize(MAX_FX)
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func bind(sim: GameSim) -> void:
	if _sim != null and _sim.bus.pickup_collected.is_connected(_on_collected):
		_sim.bus.pickup_collected.disconnect(_on_collected)
	_sim = sim
	_fx_left.fill(0.0)
	_icons.clear()
	_colors.clear()
	_hz = PackedFloat32Array()
	last_draw_items = 0
	last_fx_items = 0
	queue_redraw()
	_glow.queue_redraw()
	if sim == null:
		return
	for id in sim.data.pickup_ids:
		var def := sim.data.get_pickup(id)
		_icons.append(ArtLoader.texture(def.icon))
		_colors.append(rarity_color(def.rarity))
		_hz.append(float(RARITY_HZ.get(def.rarity, 0.8)))
	var sp: Variant = sim.data.pickup_cfg.get("spawn", {})
	if sp is Dictionary:
		_blink_steps = roundi(float((sp as Dictionary).get("blink_last", 5.0)) * 60.0)
	sim.bus.pickup_collected.connect(_on_collected)


func refresh(dt: float) -> void:
	if _sim == null:
		return
	_t += dt
	for i in MAX_FX:
		if _fx_left[i] > 0.0:
			_fx_left[i] = maxf(0.0, _fx_left[i] - dt)
	var dirty := _sim.pickups.count > 0 or _sim.bombs.count > 0 or last_draw_items > 0
	if not dirty:
		for i in MAX_FX:
			if _fx_left[i] > 0.0:
				dirty = true
				break
	if dirty or last_fx_items > 0:
		queue_redraw()
		_glow.queue_redraw()


# --- saf yardımcılar (testli) ---------------------------------------------------------------


## Zemin parlaması dokusu: ortada dolu, kenarda sıfıra yumuşak düşen (sert kenarlı plaka gibi görünmez, V-07).
static func glow_texture() -> Texture2D:
	return PlaceholderArt.soft_circle(128)


static func rarity_color(rarity: StringName) -> Color:
	match rarity:
		&"rare":
			return UiKit.AMBER
		&"uncommon":
			return UiKit.BRONZ_300
	return UiKit.KEMIK_300


## Doğma animasyonu ölçeği: 260 ms'de 0 → 1,15 → 1 (cubic-out ilk kısım).
static func spawn_scale(age_steps: int) -> float:
	if age_steps >= SPAWN_STEPS:
		return 1.0
	var u := clampf(float(age_steps) / float(SPAWN_STEPS), 0.0, 1.0)
	if u < 0.6:
		return SPAWN_PEAK * (1.0 - pow(1.0 - u / 0.6, 3.0))
	return lerpf(SPAWN_PEAK, 1.0, (u - 0.6) / 0.4)


## Süre bitiyor: son blink_steps adımda α 1↔0,45 (2,5 Hz), en son 150 ms solma; öncesinde 1.
static func blink_alpha(left_steps: int, blink_steps: int, t: float) -> float:
	if left_steps > blink_steps:
		return 1.0
	var a := lerpf(BLINK_LOW, 1.0, 0.5 + 0.5 * sin(TAU * BLINK_HZ * t))
	if left_steps < FADE_STEPS:
		a *= clampf(float(left_steps) / float(FADE_STEPS), 0.0, 1.0)
	return a


## Bomba önizlemesi α: oyuncu 500 px'e yaklaşınca belirir, uzaklaşınca solar (40 px'lik yumuşak kenar).
static func preview_alpha(dist_to_player: float) -> float:
	return PREVIEW_ALPHA * clampf((PREVIEW_NEAR + 40.0 - dist_to_player) / 40.0, 0.0, 1.0)


## Fitil ilerlemesine göre iç dolgu α'sı: 0,08 → 0,28 doğrusal.
static func fuse_fill_alpha(fuse_left: int, fuse_total: int) -> float:
	if fuse_total <= 0:
		return 0.28
	return lerpf(0.08, 0.28, 1.0 - clampf(float(fuse_left) / float(fuse_total), 0.0, 1.0))


## Kesikli halka dilim sayısı (r=320 için 46).
static func dash_count(radius: float) -> int:
	return maxi(3, roundi(TAU * radius / (DASH + GAP)))


## Eklenti kayan süzülme ofseti (y, px): ±6 px, 0,9 Hz; faz uid'den.
static func bob_offset(t: float, uid: int) -> float:
	return BOB_PX * sin(TAU * BOB_HZ * t + float(uid) * 1.7)


# --- olaylar ----------------------------------------------------------------------------------


func _on_collected(kind_id: StringName, pos: Vector2) -> void:
	if _sim == null:
		return
	var k := _sim.data.pickup_ids.find(kind_id)
	if k < 0:
		return
	var def := _sim.data.get_pickup(kind_id)
	var col := _colors[k]
	_push_fx(Fx.FLY, pos, FLY_TIME, k, col)
	match def.effect:
		&"heal":
			_push_fx(Fx.PLUS, pos, PLUS_TIME, k, UiKit.KEMIK_100)
		&"magnet":
			_push_fx(Fx.MAGNET, pos, MAGNET_TIME, k, UiKit.XP_PARLAK)
		&"buff":
			_push_fx(Fx.RING, pos, RING_TIME, k, col)


func _push_fx(kind: int, pos: Vector2, dur: float, tex: int, col: Color) -> void:
	_fx_kind[_fx_head] = kind
	_fx_pos[_fx_head] = pos
	_fx_left[_fx_head] = dur
	_fx_tex[_fx_head] = tex
	_fx_color[_fx_head] = col
	_fx_head = (_fx_head + 1) % MAX_FX


# --- çizim -----------------------------------------------------------------------------------


func _draw() -> void:
	last_draw_items = 0
	last_fx_items = 0
	if _sim == null:
		return
	var pk := _sim.pickups
	var running_or_paused := _sim.state != GameSim.State.WON and _sim.state != GameSim.State.LOST
	var player := _sim.player_pos
	if running_or_paused:
		for b in mini(_sim.bombs.count, BombPool.CAP):
			_draw_bomb(b)
			last_draw_items += 1
	for i in mini(pk.count, PickupPool.CAP):
		var k := pk.kind_idx[i]
		var p := pk.pos[i]
		var a := blink_alpha(pk.left_steps[i], _blink_steps, _t)
		var s := spawn_scale(pk.age_steps[i])
		# gölge (sabit), ikon (süzülür)
		draw_set_transform(p + Vector2(0.0, 30.0), 0.0, Vector2(1.0, SHADOW_SIZE.y / SHADOW_SIZE.x))
		draw_circle(Vector2.ZERO, SHADOW_SIZE.x * 0.5 * s, Color(0.0, 0.0, 0.0, SHADOW_ALPHA * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_icon(k, p + Vector2(0.0, bob_offset(_t, pk.uid[i])), s, a)
		if _is_bomb(k) and running_or_paused:
			var d := p.distance_to(player)
			var pa := preview_alpha(d)
			if pa > 0.0:
				_draw_dashed(
					p,
					_sim.data.get_pickup(_sim.data.pickup_ids[k]).radius,
					_t * FUSE_SPIN,
					4.0,
					Color(UiKit.CAN_KRITIK, pa)
				)
		last_draw_items += 1
	_draw_fx_icons()


func _draw_icon(k: int, p: Vector2, s: float, a: float) -> void:
	var tex: Texture2D = _icons[k] if k < _icons.size() else null
	var half := ICON_SIZE * 0.5 * s
	if tex != null:
		draw_texture_rect(
			tex, Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), false, Color(1, 1, 1, a)
		)
	else:
		draw_circle(
			p, half * 0.8, Color(_colors[k], a) if k < _colors.size() else Color(1, 1, 1, a)
		)


func _is_bomb(k: int) -> bool:
	return _sim.data.get_pickup(_sim.data.pickup_ids[k]).effect == &"bomb"


func _draw_bomb(b: int) -> void:
	var bm := _sim.bombs
	var p := bm.pos[b]
	var r := bm.radius[b]
	var left := bm.fuse_steps[b]
	var total := bm.fuse_total[b]
	var pulse := 1.0
	if left <= PULSE_STEPS:
		pulse = 1.0 + 0.03 * sin(TAU * float(PULSE_STEPS - left) / 7.5)
	var fill := UiKit.CAN_KRITIK.lerp(UiKit.BORDO_700, 0.5)
	fill.a = fuse_fill_alpha(left, total)
	draw_circle(p, r * pulse, fill)
	_draw_dashed(p, r * pulse, _t * FUSE_SPIN, FUSE_RING_WIDTH, UiKit.CAN_KRITIK)
	var k := bm.kind_idx[b]
	var flick := 0.8 + 0.2 * sin(_t * 38.0 + float(b))
	_draw_icon(k, p, 1.0, flick)


## Kesikli halka (26 px çizgi / 18 px boşluk), `rot` radyan döner.
func _draw_dashed(c: Vector2, r: float, rot: float, width: float, col: Color) -> void:
	var n := dash_count(r)
	var step := TAU / float(n)
	var span := step * DASH / (DASH + GAP)
	for i in n:
		var a0 := rot + float(i) * step
		draw_arc(c, r, a0, a0 + span, 4, col, width, true)


func _draw_fx_icons() -> void:
	for i in MAX_FX:
		if _fx_left[i] <= 0.0 or _fx_kind[i] != Fx.FLY:
			continue
		var u := 1.0 - _fx_left[i] / FLY_TIME
		var e := u * u  # ease-in
		var target := _sim.player_pos
		var p := _fx_pos[i].lerp(target, e)
		_draw_icon(_fx_tex[i], p, lerpf(1.0, 0.4, e), 1.0 - 0.3 * e)
		last_fx_items += 1


func _draw_glow() -> void:
	if _sim == null:
		return
	var pk := _sim.pickups
	for i in mini(pk.count, PickupPool.CAP):
		var k := pk.kind_idx[i]
		var col := _colors[k] if k < _colors.size() else Color.WHITE
		var hz := _hz[k] if k < _hz.size() else 0.8
		var a := blink_alpha(pk.left_steps[i], _blink_steps, _t)
		var pulse := 0.75 + 0.25 * sin(TAU * hz * _t + float(pk.uid[i]))
		var s := spawn_scale(pk.age_steps[i])
		var p := pk.pos[i]
		_glow.draw_set_transform(
			p + Vector2(0.0, 22.0), 0.0, Vector2(1.0, GLOW_SIZE.y / GLOW_SIZE.x)
		)
		var gr := GLOW_SIZE.x * 0.5 * s
		_glow.draw_texture_rect(
			glow_texture(),
			Rect2(Vector2(-gr, -gr), Vector2(gr, gr) * 2.0),
			false,
			Color(col, GLOW_ALPHA * pulse * a)
		)
		_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if pk.age_steps[i] < 18:  # doğma halkası 0 → 90 px (300 ms)
			var u := float(pk.age_steps[i]) / 18.0
			_glow.draw_arc(p, 90.0 * u, 0.0, TAU, 32, Color(col, 0.6 * (1.0 - u)), 4.0, true)
		var item_k := _rarity_of(k)
		if item_k >= 1:  # Seyrek/Nadir: yörüngede 4 kıvılcım
			for j in SPARKS:
				var ang := _t * 2.0 + TAU * float(j) / float(SPARKS)
				_glow.draw_circle(p + Vector2.from_angle(ang) * 52.0, 3.5, Color(col, 0.9 * a))
		if item_k == 2:  # Nadir: ışık sütunu + dönen çift halka
			var beam := 140.0
			_glow.draw_rect(
				Rect2(p + Vector2(-14.0, -beam), Vector2(28.0, beam)), Color(col, 0.35 * pulse * a)
			)
			for j in 2:
				var rr := 48.0 + 10.0 * float(j)
				_glow.draw_arc(
					p,
					rr,
					_t * (1.2 + float(j)),
					_t * (1.2 + float(j)) + PI,
					24,
					Color(col, 0.7 * a),
					3.0,
					true
				)
	for b in mini(_sim.bombs.count, BombPool.CAP):
		if _sim.state == GameSim.State.WON or _sim.state == GameSim.State.LOST:
			break
		_glow.draw_circle(
			_sim.bombs.pos[b], 34.0, Color(UiKit.AMBER, 0.25 + 0.2 * sin(_t * 40.0 + float(b)))
		)
	_draw_glow_fx()


func _rarity_of(k: int) -> int:
	var r := _sim.data.get_pickup(_sim.data.pickup_ids[k]).rarity
	return 2 if r == &"rare" else (1 if r == &"uncommon" else 0)


func _draw_glow_fx() -> void:
	for i in MAX_FX:
		if _fx_left[i] <= 0.0:
			continue
		var p := _fx_pos[i]
		var col := _fx_color[i]
		match _fx_kind[i]:
			Fx.PLUS:
				var u := 1.0 - _fx_left[i] / PLUS_TIME
				for j in 6:
					var off := Vector2((float(j) - 2.5) * 22.0, -u * 70.0 - float(j % 2) * 18.0)
					var c := p + off
					_glow.draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color(col, 1.0 - u), 3.0)
					_glow.draw_line(c + Vector2(0, -7), c + Vector2(0, 7), Color(col, 1.0 - u), 3.0)
				last_fx_items += 1
			Fx.MAGNET:
				var u := 1.0 - _fx_left[i] / MAGNET_TIME
				_glow.draw_arc(
					_sim.player_pos,
					MAGNET_RADIUS * u,
					0.0,
					TAU,
					96,
					Color(col, 0.7 * (1.0 - u)),
					10.0,
					true
				)
				last_fx_items += 1
			Fx.RING:
				var u := 1.0 - _fx_left[i] / RING_TIME
				var c2 := _sim.player_pos
				_glow.draw_arc(
					c2, 40.0 + 110.0 * u, 0.0, TAU, 48, Color(col, 0.8 * (1.0 - u)), 6.0, true
				)
				last_fx_items += 1
