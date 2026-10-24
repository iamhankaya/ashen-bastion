extends GutTest
## Kabul (v1.1): plan "Sayılar" tablolarının SABİT kopyası (ExpectedTablesV11) ile gerçek data/** eşleşmesi.
## Denge ayarı bu sürümde yok: tablo ve veri birlikte, yalnız denge görevinde değişir. Dilim bağımsız (S1 gerçek).

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= 1e-4


func test_pickups_json_spawn_block_matches_plan() -> void:
	var sp: Dictionary = _data.pickup_cfg["spawn"]
	for k in ExpectedTablesV11.PICKUP_SPAWN:
		var want: Variant = ExpectedTablesV11.PICKUP_SPAWN[k]
		if want is Array:
			assert_eq((sp[k] as Array).size(), 2, "spawn.%s çift" % k)
			assert_almost_eq(float(sp[k][0]), float(want[0]), 1e-4, "spawn.%s min" % k)
			assert_almost_eq(float(sp[k][1]), float(want[1]), 1e-4, "spawn.%s max" % k)
		else:
			assert_almost_eq(float(sp[k]), float(want), 1e-4, "spawn.%s" % k)


func test_pickup_kinds_order_ids_and_values_match_plan() -> void:
	assert_eq(_data.pickup_ids, ExpectedTablesV11.PICKUP_ORDER, "tür sırası (PickupPool.kind_idx)")
	var total := 0.0
	for id in ExpectedTablesV11.PICKUP_ORDER:
		var def: PickupDef = _data.get_pickup(id)
		assert_not_null(def, "%s" % id)
		if def == null:
			continue
		var want: Dictionary = ExpectedTablesV11.PICKUPS[id]
		assert_eq(def.display_name, want["name"], "%s ad" % id)
		assert_eq(String(def.rarity), want["rarity"], "%s nadirlik" % id)
		assert_eq(String(def.effect), want["effect"], "%s etki" % id)
		assert_almost_eq(def.weight, float(want["weight"]), 1e-4, "%s ağırlık" % id)
		total += def.weight
		for k in ["amount", "mult", "duration", "radius", "fuse", "dmg", "elite_frac", "elite_min"]:
			if want.has(k):
				assert_almost_eq(float(def.get(k)), float(want[k]), 1e-4, "%s.%s" % [id, k])
		if want.has("buff"):
			assert_eq(String(def.buff), want["buff"], "%s buff" % id)
		assert_true(FileAccess.file_exists(def.icon), "%s ikon dosyası" % id)
	assert_almost_eq(total, ExpectedTablesV11.WEIGHT_TOTAL, 1e-4, "ağırlık toplamı 100")


func test_derived_step_counts_are_whole_steps() -> void:
	# Tam sayı adım kuralı: sn × 60 yuvarlaması beklenen adım sayılarını verir.
	var hz := ExpectedTablesV11.HZ
	assert_eq(roundi(_data.get_pickup(&"ofke_barutu").duration * hz), ExpectedTablesV11.BUFF_STEPS)
	assert_eq(roundi(_data.get_pickup(&"kizgin_namlu").duration * hz), ExpectedTablesV11.BUFF_STEPS)
	assert_eq(
		roundi(_data.get_pickup(&"sonsuz_tambur").duration * hz), ExpectedTablesV11.UNLIMITED_STEPS
	)
	assert_eq(roundi(_data.get_pickup(&"kara_bomba").fuse * hz), ExpectedTablesV11.FUSE_STEPS)
	assert_eq(roundi(float(_data.pickup_cfg["spawn"]["life"]) * hz), ExpectedTablesV11.LIFE_STEPS)


func test_score_json_matches_plan() -> void:
	var t := _data.score_table
	for id in ExpectedTablesV11.KILL_POINTS:
		assert_eq(t.points(id), ExpectedTablesV11.KILL_POINTS[id], "%s puan" % id)
	assert_eq(t.tiers, ExpectedTablesV11.TIERS, "SERİ basamakları")
	assert_eq(t.window_steps, ExpectedTablesV11.WINDOW_STEPS, "SERİ penceresi 180 adım")
	assert_eq(ScoreKeeper.WINDOW_STEPS, ExpectedTablesV11.WINDOW_STEPS)
	assert_eq(t.evolution_bonus, ExpectedTablesV11.EVOLUTION_BONUS)
	assert_eq(t.survival_per_sec, ExpectedTablesV11.SURVIVAL_PER_SEC)
	assert_eq(t.lord_bonus, ExpectedTablesV11.LORD_BONUS)
	assert_eq(t.display_cap, ExpectedTablesV11.DISPLAY_CAP)


func test_every_enemy_has_kill_points_and_score_mult_boundaries() -> void:
	for id in _data.enemy_ids:
		assert_true(ExpectedTablesV11.KILL_POINTS.has(id), "%s için puan" % id)
		assert_gt(_data.score_table.points(id), 0, "%s puan > 0" % id)
	var t := _data.score_table
	var edges := {0: 1, 9: 1, 10: 2, 24: 2, 25: 3, 49: 3, 50: 4, 99: 4, 100: 5, 400: 5}
	for n in edges:
		assert_eq(t.mult_for(n), edges[n], "mult_for(%d)" % n)


func test_enemy_anim_tables_match_plan() -> void:
	for id in ExpectedTablesV11.ENEMY_ANIM:
		var a: Dictionary = _data.get_enemy(id).anim
		var want: Dictionary = ExpectedTablesV11.ENEMY_ANIM[id]
		for k in want:
			if k == "alpha":
				assert_eq((a[k] as Array).size(), 2, "%s alpha" % id)
				assert_almost_eq(float(a[k][0]), float(want[k][0]), 1e-4, "%s alpha[0]" % id)
				assert_almost_eq(float(a[k][1]), float(want[k][1]), 1e-4, "%s alpha[1]" % id)
			elif want[k] is String:
				assert_eq(String(a[k]), want[k], "%s.%s" % [id, k])
			else:
				assert_almost_eq(float(a[k]), float(want[k]), 1e-4, "%s.%s" % [id, k])


func test_player_walk_rig_defaults_are_valid_for_both_modes() -> void:
	var rig: Dictionary = _data.get_character(&"gunslinger").rig
	assert_true(rig.has("walk"), "rig.walk var")
	var w: Dictionary = rig["walk"]
	assert_almost_eq(float(w["stride"]), ExpectedTablesV11.WALK_STRIDE, 1e-4, "stride 136 px")
	var n := int(w["frames"])
	assert_true(n == 0 or (n >= 2 and n <= 12), "frames 0 (yedek) ya da 2..12: %d" % n)
	if n > 0:
		assert_true(FileAccess.file_exists(String(w["strip"])), "kare modunda şerit dosyası var")
		assert_eq(
			(w["shoulder_dev"] as Array).size() in [0, n + 1], true, "shoulder_dev boş ya da N+1"
		)


func test_pool_caps_and_budget_constants() -> void:
	assert_eq(PickupPool.CAP, ExpectedTablesV11.POOL_CAPS["pickups"])
	assert_eq(BombPool.CAP, ExpectedTablesV11.POOL_CAPS["bombs"])
	assert_eq(AshGhostRenderer.CAP, ExpectedTablesV11.POOL_CAPS["ghosts"])
	assert_eq(EnemyAnim.LUT_SIZE, 256)
	assert_eq(AshGhostRenderer.LOD_ALIVE, 150)
	assert_eq(HitStop.MAX_SEC, ExpectedTablesV11.HITSTOP_MAX)
	assert_eq(PauseLogic.LEVEL_UP_PREROLL, ExpectedTablesV11.DELAY_LEVELUP)
	assert_eq(GameSim.RNG_STREAMS.back(), &"pickup", "beşinci akış sonda")
	assert_eq(GameSim.RNG_STREAMS.size(), 5)


func test_pickup_icons_load_as_textures_at_a_readable_size() -> void:
	for id in _data.pickup_ids:
		var def: PickupDef = _data.get_pickup(id)
		var tex := (
			ArtLoader.texture(def.icon) if def.icon.ends_with(".png") else load(def.icon)
			as Texture2D
		)
		assert_not_null(tex, "%s: ikon yüklenir (%s)" % [id, def.icon])
		if tex != null:
			assert_gte(tex.get_width(), 50, "%s: ikon >= 50 px (54-80 px okunurluk)" % id)
