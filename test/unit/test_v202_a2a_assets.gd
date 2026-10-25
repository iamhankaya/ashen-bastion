extends GutTest
## A2a: Zyfen ikonları (13 beceri + 7 pasif varyantı) ve 13 rüzgar efekt dokusu veriye/koda bağlı; boyalı ikon renk çarpanı
## olmadan gösterilir; mermi doku sınıflaması ve katmanları; Nefes Dalgası/Kasırga/avuç doku halkaları.

const WIND_SKILLS := [
	&"ruzgar_kesigi",
	&"hava_bicaklari",
	&"delen_ruzgar",
	&"bolunen_kesik",
	&"girdap",
	&"hortum",
	&"hava_cebi",
	&"nefes_dalgasi",
	&"furtina_gozu",
	&"ay_oragi",
	&"kasirga_patlamasi",
	&"gogun_mizragi",
	&"tufan",
]
const PASSIVES := [
	&"agir_kursun",
	&"cevik_cizme",
	&"fazladan_mermi",
	&"hizli_doldurma",
	&"hizli_parmak",
	&"miknatis",
	&"saglam_yelek",
]
const FX := ZyfenFx.ALL


func _image(path: String) -> Image:
	return (load(path) as Texture2D).get_image()


func _alpha_box(img: Image) -> Rect2i:
	return img.get_used_rect()


func test_every_zyfen_skill_icon_is_a_png_that_exists() -> void:
	var g := GameData.load_dir("res://data")
	for id: StringName in WIND_SKILLS:
		var p := g.get_skill(id).icon_for(&"zyfen")
		assert_true(p.ends_with(".png"), "%s: PNG ikon" % id)
		assert_true(ResourceLoader.exists(p), "%s: %s var" % [id, p])
	for id: StringName in PASSIVES:
		var p := g.get_skill(id).icon_for(&"zyfen")
		assert_true(
			p.begins_with("res://assets/ui/icons/zyfen/") and p.ends_with(".png"),
			"%s: zyfen varyantı" % id
		)
		assert_true(ResourceLoader.exists(p), "%s: %s var" % [id, p])
		# A2b: Gunslinger kendi boyalı ikonunu kullanır; Zyfen varyantı ondan ayrı dosyadır.
		assert_ne(g.get_skill(id).icon_for(&"gunslinger"), p, "%s: Zyfen varyantı ayrı dosya" % id)


func test_icons_are_square_canvas_with_content_centered_in_80_percent() -> void:
	var g := GameData.load_dir("res://data")
	var ids: Array = []
	ids.append_array(WIND_SKILLS)
	ids.append_array(PASSIVES)
	for id: StringName in ids:
		var img := _image(g.get_skill(id).icon_for(&"zyfen"))
		assert_eq(img.get_width(), img.get_height(), "%s kare" % id)
		var box := _alpha_box(img)
		var side := maxi(box.size.x, box.size.y)
		assert_almost_eq(
			float(side) / float(img.get_width()), 0.8, 0.02, "%s uzun kenar ~%%80" % id
		)
		var c := Vector2(box.position) + Vector2(box.size) * 0.5
		assert_almost_eq(c.x, img.get_width() * 0.5, 3.0, "%s yatay ortalı" % id)
		assert_almost_eq(c.y, img.get_height() * 0.5, 3.0, "%s dikey ortalı" % id)


func test_skill_icon_lookup_gives_a_texture_for_all_20_icons() -> void:
	var g := GameData.load_dir("res://data")
	var ids: Array = []
	ids.append_array(WIND_SKILLS)
	ids.append_array(PASSIVES)
	for id: StringName in ids:
		assert_not_null(UiKit.skill_icon(id, g.get_skill(id).icon_for(&"zyfen")), "%s" % id)
	for id: StringName in WIND_SKILLS:
		assert_not_null(UiKit.skill_icon(id), "%s: alan boşken de kimlikten bulunur" % id)


func test_painted_icon_slot_has_white_modulate_and_no_material() -> void:
	var slot := SkillSlot.new(&"active", 180.0)
	add_child_autofree(slot)
	slot.set_skill(&"tufan", 1, "res://assets/ui/icons/tufan.png")
	assert_eq(slot.modulate, Color.WHITE)
	assert_null(slot.material)
	assert_not_null(slot.icon)


func test_all_32_fx_parts_exist_with_8_percent_clear_margin_and_512_cap() -> void:
	assert_eq(FX.size(), 32)
	for id: StringName in FX:
		var p := ZyfenFx.DIR + String(id) + ".png"
		assert_true(ResourceLoader.exists(p), p)
		var img := _image(p)
		assert_lte(maxi(img.get_width(), img.get_height()), 512, "%s uzun kenar" % id)
		assert_not_null(ZyfenFx.texture(id), "%s yüklenir" % id)
		if id == ZyfenFx.HORTUM_AKIS:
			assert_eq(img.get_width(), img.get_height(), "akış dokusu kare (döşenir)")
			continue
		var a := img.get_used_rect()
		var mx := int(img.get_width() * 0.075)
		var my := int(img.get_height() * 0.075)
		assert_gte(a.position.x, mx, "%s sol pay" % id)
		assert_gte(a.position.y, my, "%s üst pay" % id)
		assert_lte(a.end.x, img.get_width() - mx, "%s sağ pay" % id)
		assert_lte(a.end.y, img.get_height() - my, "%s alt pay" % id)
		assert_not_null(ZyfenFx.texture(id), "%s yüklenir" % id)


func test_projectile_kind_classification_follows_flags_radius_and_speed() -> void:
	var w := ProjectilePool.FLAG_WIND
	var sp := ProjectilePool.FLAG_SPLIT
	assert_eq(ZyfenFx.projectile_kind(w, 14.0, 900.0, false), ZyfenFx.KESIK)
	assert_eq(
		ZyfenFx.projectile_kind(w | ProjectilePool.FLAG_SPLITTER, 14.0, 900.0, false), ZyfenFx.KESIK
	)
	assert_eq(ZyfenFx.projectile_kind(w, 10.0, 900.0, false), ZyfenFx.HAVA_BICAGI)
	assert_eq(ZyfenFx.projectile_kind(w | sp, 14.0, 900.0, false), ZyfenFx.KESIK_PARCA)
	assert_eq(ZyfenFx.projectile_kind(w | sp, 40.0, 700.0, false), ZyfenFx.AY_ORAGI)
	assert_eq(ZyfenFx.projectile_kind(w, 10.0, 1400.0, false), ZyfenFx.MIZRAK)
	assert_eq(ZyfenFx.projectile_kind(w, 10.0, 1400.0, true), ZyfenFx.GOK_MIZRAGI)


func test_projectile_renderer_routes_wind_to_texture_layers_and_keeps_visible_count() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "character": &"zyfen", "pickups": false})
	sim.debug_grant(&"ay_oragi", 5)
	SimKit.godmode(sim)
	for k in 6:
		var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(260 + 60 * k, 0))
		sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
		sim.enemies.hp[EnemyPool.index_of(id)] = WindKit.TOUGH_HP
	var r := ProjectileRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	var seen_layers := {}
	for _i in 300:
		SimKit.run(sim, 1, Vector2.ZERO)
		r.refresh()
		assert_eq(r.visible_count(), sim.projectiles.count, "görünür = canlı")
		for child in r.get_children():
			var m := (child as MultiMeshInstance2D).multimesh
			if m.visible_instance_count > 0:
				seen_layers[child.name] = true
	assert_gt(seen_layers.size(), 0, "doku katmanı kullanıldı")
	for k: String in seen_layers:
		assert_true(ZyfenFx.PROJECTILE_LAYERS.has(StringName(k)), "%s bilinen katman" % k)
	assert_true(seen_layers.has("fx_ay_oragi"), "Ay Orağı dev hilal dokusu")
	assert_true(seen_layers.has("fx_ay_oragi_iz"), "Ay Orağı iz şeridi")
	assert_true(seen_layers.has("fx_parilti"), "Ay Orağı yıldız parıltısı")
	assert_eq(
		r.multimesh.visible_instance_count,
		0,
		"rüzgar mermisi ana katmanda çizilmez (Zyfen yalnız rüzgar atar)"
	)


func test_wave_and_hurricane_signals_add_textured_rings_that_fade() -> void:
	var sim := WindKit.make()
	var cam := CameraRig.new()
	add_child_autofree(cam)
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	fx.bind(sim, cam)
	sim.fx.wind_wave.emit(Vector2.ZERO, 200.0, false)
	sim.fx.wind_wave.emit(Vector2.ZERO, 900.0, true)
	assert_eq(fx.ring_count(), 2)
	fx.update_fx(0.016)
	await wait_process_frames(1)
	for _i in 60:
		fx.update_fx(0.02)
	assert_eq(fx.ring_count(), 0, "dalgalar sönüp biter")


func test_palm_hit_only_for_armless_characters_and_ring_buffer_unaffected() -> void:
	var zy := WindKit.make()
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	fx.bind(zy)
	zy.bus.enemy_hit.emit(Vector2(10, 0))
	assert_eq(fx._hit_left.count(0.0), FxRenderer.MAX_HITS - 1, "kolsuzda isabet avucu")
	assert_eq(fx.ring_count(), 0, "isabet halka tamponunu kullanmaz")
	var gs := GameSim.new(1, &"gunslinger")
	var fx2 := FxRenderer.new()
	add_child_autofree(fx2)
	fx2.bind(gs)
	gs.bus.enemy_hit.emit(Vector2(10, 0))
	assert_eq(fx2._hit_left.count(0.0), FxRenderer.MAX_HITS, "Gunslinger'da yok")


func test_flow_shader_exists_and_flow_texture_is_square() -> void:
	assert_not_null(ZyfenFx.shader("wind_flow"))
	assert_not_null(ZyfenFx.shader("wind_spear"))
	var wr := WindRenderer.new()
	add_child_autofree(wr)
	assert_not_null(wr._flow_layer.material, "akış katmanı gölgelendiricili")


func test_split_parent_vanishing_starts_a_break_burst_that_expires() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "character": &"zyfen", "pickups": false})
	SimKit.godmode(sim)
	var r := ProjectileRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	sim.spawn_projectile(
		Vector2(100, 0),
		Vector2(900, 0),
		1.0,
		{
			"flags": ProjectilePool.FLAG_WIND | ProjectilePool.FLAG_SPLITTER,
			"radius": 14.0,
			"life": 1.0
		}
	)
	r.refresh()
	assert_eq(r._burst_t0.count(-100.0), ProjectileRenderer.MAX_BURSTS, "ebeveyn var: patlama yok")
	sim.projectiles.remove(0)
	sim.step(Vector2.ZERO)
	r.refresh()
	assert_eq(r._burst_t0.count(-100.0), ProjectileRenderer.MAX_BURSTS - 1, "kayboldu: patlama")
	var n := int(r._layers[ZyfenFx.KESIK_KIRILMA]["n"])
	assert_eq(n, 1)
	SimKit.run(sim, 30, Vector2.ZERO)
	r.refresh()
	assert_eq(int(r._layers[ZyfenFx.KESIK_KIRILMA]["n"]), 0, "patlama söner")


func test_gok_mizragi_draws_a_light_column_only_right_after_spawn() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "character": &"zyfen", "pickups": false})
	sim.debug_grant(&"gogun_mizragi", 5)
	SimKit.godmode(sim)
	var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(400, 0))
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	sim.enemies.hp[EnemyPool.index_of(id)] = WindKit.TOUGH_HP
	var r := ProjectileRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	var early := 0
	var late := 0
	for _i in 600:
		SimKit.run(sim, 1, Vector2.ZERO)
		r.refresh()
		var fast := 0
		var fresh := 0
		for k in sim.projectiles.count:
			if sim.projectiles.vel[k].length() >= ZyfenFx.SPEAR_SPEED:
				fast += 1
				var age := ProjectileRenderer.SPEAR_LIFE - sim.projectiles.life[k]
				if age < ProjectileRenderer.BEAM_TIME:
					fresh += 1
		var beams := int(r._layers[ZyfenFx.GOK_ISIK]["n"])
		assert_eq(beams, fresh, "sütun sayısı = yeni doğan mızrak sayısı")
		if fast > 0 and fresh == 0 and beams > 0:
			late += 1
		if fresh > 0:
			early += 1
	assert_gt(early, 0, "çıkışta ışık sütunu")
	assert_eq(late, 0, "geç karelerde sütun yok")


func test_wave_has_an_echo_ring_in_one_slot_and_palm_gathers() -> void:
	var sim := WindKit.make()
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	fx.bind(sim)
	sim.fx.wind_wave.emit(Vector2.ZERO, 200.0, false)
	assert_eq(fx.ring_count(), 1, "ikinci halka aynı yuvada")
	assert_gt(fx._ring_echo[(fx._ring_head + FxRenderer.MAX_RINGS - 1) % FxRenderer.MAX_RINGS], 0.0)
	sim.bus.shot_fired.emit(0, Vector2(10, 10), Vector2.RIGHT)
	var h := (fx._ring_head + FxRenderer.MAX_RINGS - 1) % FxRenderer.MAX_RINGS
	assert_gt(fx._ring_r0[h], 1.0, "avuç küçülerek toplanır")


func test_hit_is_big_only_near_a_moon_or_spear() -> void:
	var sim := WindKit.make()
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	fx.bind(sim)
	sim.spawn_projectile(
		Vector2(50, 0),
		Vector2(1400, 0),
		1.0,
		{"flags": ProjectilePool.FLAG_WIND, "radius": 10.0, "life": 1.0}
	)
	fx.update_fx(0.016)
	sim.bus.enemy_hit.emit(Vector2(60, 0))
	sim.bus.enemy_hit.emit(Vector2(900, 900))
	assert_eq(fx._hit_big.count(1), 1, "yalnız mızrağa yakın isabet büyük")
