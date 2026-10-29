class_name RunPresentation
extends RefCounted
## GameController koşu sunumu (R4): debug etiket metinleri, toplama başlığı ve Lord ölümü efektleri. Durum controller'da kalır
## (`_lord_*` alanlarını testler okur); `host` GameController'dır ama tipi BİLİNMEZ (class_name döngüsü yok, V2Flow kuralı).


static func render_text(sim: GameSim, enemies: EnemyRenderer, gems: GemRenderer) -> String:
	if sim == null:
		return ""
	return (
		"düşman %d/%d  taş %d/%d\nkesme düzeltmesi: %s (dokun)"
		% [
			enemies.visible_count(),
			sim.enemies.count,
			gems.visible_count(),
			sim.gems.count,
			"AÇIK" if RenderFix.enabled else "KAPALI",
		]
	)


static func escape_text(sim: GameSim, begun_base: int, enabled: bool) -> String:
	var live := EnemyEscape.escaping_count(sim) if sim != null else 0
	var begun := begun_base + (sim.enemies.escape_begun if sim != null else 0)
	return (
		"kaçışta %d  girilen %d\nçıkmaz kaçışı: %s (dokun)"
		% [live, begun, "AÇIK" if enabled else "KAPALI"]
	)


## Toplama başlığı: pickups.json `toast` (boşsa yok), oyuncunun üstünde kayar.
static func pickup_toast(host, kind_id: StringName) -> void:
	var def: PickupDef = host.sim.data.get_pickup(kind_id)
	if def == null or def.toast == "":
		return
	var screen_pos: Vector2 = (
		host.get_viewport().get_canvas_transform() * (host.sim.player_pos + Vector2(0.0, -140.0))
	)
	host.hud.float_text.show_text(UiKit.upper_tr(def.toast), screen_pos)


## Lord ölümü (E10): vuruş donması 150 ms, kamera 18 px, 900 ms içinde 3 patlama (±120 px), yavaş çekim 0,4× (1,2 sn).
static func lord_killed(host, pos: Vector2) -> void:
	host.hit_stop.request(Motion.sec(Motion.HITSTOP_LORD_DEATH))
	host.camera.shake(18.0)
	host._lord_slow_left = Motion.sec(Motion.LORD_SLOWMO)
	var t: PackedFloat32Array = host._lord_blast_t
	var at: PackedVector2Array = host._lord_blast_pos
	for k in 3:
		t.append(0.1 + 0.3 * float(k) + randf() * 0.1)
		at.append(pos + Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0)))
	host._lord_blast_t = t  # Variant erişimde değer/başvuru farkına karşı geri yaz
	host._lord_blast_pos = at


## Bekleyen Lord patlamalarını gerçek süreyle (yavaş çekimden bağımsız) geri sayar.
static func tick_blasts(host, vdt: float) -> void:
	var t: PackedFloat32Array = host._lord_blast_t
	var at: PackedVector2Array = host._lord_blast_pos
	var k := 0
	while k < t.size():
		t[k] -= vdt
		if t[k] <= 0.0:
			host.fx_renderer.add_explosion(at[k], 150.0)
			t.remove_at(k)
			at.remove_at(k)
		else:
			k += 1
	host._lord_blast_t = t
	host._lord_blast_pos = at


## Öfkeli Lord kor aurası (E9): `rate` parçacık/sn.
static func lord_embers(host, vdt: float, rate: float) -> void:
	if not (host.enemy_renderer.lord_enraged_now and vdt > 0.0):
		return
	host._lord_ember_acc += vdt * rate
	while host._lord_ember_acc >= 1.0:
		host._lord_ember_acc -= 1.0
		var a := randf() * TAU
		host.fx_renderer.add_particle(
			&"ember",
			host.enemy_renderer.lord_pos + Vector2.from_angle(a) * 70.0,
			Vector2(cos(a) * 25.0, -50.0),
			0.8
		)
