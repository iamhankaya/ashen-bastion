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
const FX := [
	&"fx_kesik",
	&"fx_ay_oragi",
	&"fx_hava_bicagi",
	&"fx_kesik_parca",
	&"fx_mizrak",
	&"fx_gok_mizragi",
	&"fx_girdap",
	&"fx_hortum",
	&"fx_tufan",
	&"fx_hava_cebi",
	&"fx_dalga",
	&"fx_kasirga",
	&"fx_avuc",
]


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


func test_all_13_fx_textures_exist_with_8_percent_clear_margin_and_512_cap() -> void:
	assert_eq(FX.size(), 13)
	for id: StringName in FX:
		var p := ZyfenFx.DIR + String(id) + ".png"
		assert_true(ResourceLoader.exists(p), p)
		var img := _image(p)
		assert_lte(maxi(img.get_width(), img.get_height()), 512, "%s uzun kenar" % id)
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
		assert_true(ZyfenFx.PROJECTILE_KINDS.has(StringName(k)), "%s bilinen doku türü" % k)
	assert_true(seen_layers.has("fx_ay_oragi"), "Ay Orağı dev hilal dokusu")
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
