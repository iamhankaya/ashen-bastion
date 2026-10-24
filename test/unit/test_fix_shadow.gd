extends GutTest
## V-01 (ara denetim): yer gölgesi okunurluğu. Gölge pikselleri (etkin α >= 0,05) ortalama >= %40 koyulaşır;
## elit/Lord gölgesi ayağın en çok 10 px altında merkezlenir ve sprite kadar geniştir; oyuncu gölgesi aynı ölçüyü sağlar.

const MIN_VISIBLE := 0.05


## Gölge dokusundan ve verilen tepe α'dan, görünür (>= MIN_VISIBLE) piksellerin ortalama koyulaşması.
func _mean_darkening(tex: Texture2D, peak_alpha: float) -> float:
	var img := tex.get_image()
	var sum := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var a := minf(img.get_pixel(x, y).a * peak_alpha, 1.0)
			if a >= MIN_VISIBLE:
				sum += a
				n += 1
	return sum / float(maxi(n, 1))


func _renderer(sim: GameSim) -> EnemyRenderer:
	var r := EnemyRenderer.new()
	add_child_autofree(r)
	r.shadows = EnemyShadowLayer.new()
	add_child_autofree(r.shadows)
	r.bind(sim)
	return r


func _sim() -> GameSim:
	return GameSim.new(11, &"gunslinger", {"end_mode": "lord"})


func test_enemy_shadow_pixels_darken_at_least_40_percent() -> void:
	var layer := EnemyShadowLayer.new()
	add_child_autofree(layer)
	var peak := EnemyShadowLayer.SHADOW_ALPHA * EnemyShadowLayer.GAIN
	assert_gte(_mean_darkening(layer.texture, peak), 0.40, "ortalama koyulaşma >= %40")


func test_shader_gain_matches_constant() -> void:
	var layer := EnemyShadowLayer.new()
	add_child_autofree(layer)
	var mat := layer.material as ShaderMaterial
	assert_not_null(mat, "gölge katmanında kazanç shader'ı")
	if mat != null:
		assert_almost_eq(float(mat.get_shader_parameter("gain")), EnemyShadowLayer.GAIN, 1e-4)


func test_player_shadow_pixels_darken_at_least_40_percent() -> void:
	var v := PlayerView.new()
	add_child_autofree(v)
	assert_not_null(v.shadow.texture, "oyuncu gölgesi yumuşak dokuyla çizilir")
	if v.shadow.texture != null:
		assert_gte(_mean_darkening(v.shadow.texture, PlayerView.Shadow.ALPHA), 0.40)


func test_elite_and_lord_shadow_sits_within_10px_below_the_foot() -> void:
	for id in [&"elit_piyade", &"elit_sovalye", &"kale_lordu"]:
		var sim := _sim()
		var r := _renderer(sim)
		var i := EnemyPool.index_of(sim.spawn_enemy(id, sim.player_pos + Vector2(-500.0, 0.0)))
		sim.time = 1.0
		r.refresh()
		var t := sim.enemies.type_idx[i]
		var foot_y := sim.enemies.pos[i].y + r.foot_of(t)
		var sy := r.shadows.multimesh.buffer[7]
		assert_between(sy - foot_y, 0.0, 10.0, "%s: gölge merkezi ayağın 0..10 px altında" % id)


func test_elite_shadow_is_as_wide_as_the_sprite_and_taller_than_regular() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := EnemyPool.index_of(sim.spawn_enemy(&"elit_piyade", sim.player_pos + Vector2(-500, 0)))
	sim.time = 1.0
	r.refresh()
	var t := sim.enemies.type_idx[i]
	var b := r.shadows.multimesh.buffer
	assert_almost_eq(b[0], r.sprite_world_width(t) * EnemyRenderer.SHADOW_W_ELITE, 0.5)
	assert_gt(b[5], b[0] * EnemyRenderer.SHADOW_H, "elit gölgesi normalden yüksek oranlı")


func test_regular_enemy_shadow_geometry_is_unchanged() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := EnemyPool.index_of(
		sim.spawn_enemy(&"curumus_piyade", sim.player_pos + Vector2(-500, 0))
	)
	sim.time = 1.0
	r.refresh()
	var t := sim.enemies.type_idx[i]
	var b := r.shadows.multimesh.buffer
	assert_almost_eq(b[0], 0.8 * r.sprite_world_width(t), 0.5)
	assert_almost_eq(b[5], 0.2 * b[0], 0.5)
	assert_almost_eq(b[7], sim.enemies.pos[i].y + r.quad_size(t).y * 0.5, 1.0)
	assert_almost_eq(b[11], 0.38, 1e-3)
