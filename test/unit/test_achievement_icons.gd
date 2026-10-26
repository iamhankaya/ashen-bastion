extends GutTest
## AchievementIcons (B4): her stat ailesi mevcut bir ikona çözülür; icon alanı varsa o; bilinmeyen -> "".


func test_every_stat_resolves_to_an_existing_icon() -> void:
	for st in AchievementDef.STATS:
		var d := AchievementDef.new()
		d.stat = StringName(st)
		var p := AchievementIcons.path_for(d)
		assert_ne(p, "", st)
		assert_true(ResourceLoader.exists(p), "%s -> %s" % [st, p])


func test_unknown_stat_and_null_give_empty() -> void:
	var d := AchievementDef.new()
	d.stat = &"yok_boyle_stat"
	assert_eq(AchievementIcons.path_for(d), "")
	assert_eq(AchievementIcons.path_for(null), "")


func test_explicit_icon_wins_when_it_exists_else_falls_back() -> void:
	var d := AchievementDef.new()
	d.stat = &"total_kills"
	d.icon = "res://assets/ui/icons/hud-patlama.svg"
	assert_eq(AchievementIcons.path_for(d), "res://assets/ui/icons/hud-patlama.svg")
	d.icon = "res://assets/ui/icons/yok.svg"
	assert_eq(AchievementIcons.path_for(d), "res://assets/ui/icons/hud-oldurme.svg")


func test_tier_colors_are_distinct_per_family() -> void:
	assert_ne(AchievementIcons.tier_color(&"kolay"), AchievementIcons.tier_color(&"orta"))
	assert_eq(AchievementIcons.tier_color(&"zor"), AchievementIcons.tier_color(&"cok_zor"))


func test_families_use_existing_icons_or_fall_back_by_stat() -> void:
	var seen := 0
	for a in GameData.load_default().achievements:
		var d: AchievementDef = a
		if d.icon != "":
			assert_true(ResourceLoader.exists(d.icon), d.id)
			assert_eq(AchievementIcons.path_for(d), d.icon, d.id)
		else:
			assert_ne(AchievementIcons.path_for(d), "", "%s: stat ailesine göre yedek ikon" % d.id)
		seen += 1
	assert_eq(seen, 19)


func test_step_colors_distinct_and_locked_is_dim() -> void:
	var cols := {}
	for s in range(0, 5):
		cols[AchievementIcons.step_color(s)] = true
	assert_eq(cols.size(), 4, "0 kilitli, 1 demir, 2 bronz, 3-4 amber")


func test_v20_achievements_have_existing_own_png() -> void:
	var g := AchKit.legacy_data()
	var seen := 0
	for a in g.achievements:
		var d: AchievementDef = a
		assert_eq(d.icon, "res://assets/ui/achievements/%s.png" % d.id, d.id)
		assert_eq(AchievementIcons.path_for(d), d.icon, d.id)
		seen += 1
	assert_eq(seen, 22)


func test_apply_state_open_has_white_modulate_and_no_material() -> void:
	var r := TextureRect.new()
	r.modulate = Color(0.5, 0.5, 0.5, 0.4)
	AchievementIcons.apply_state(r, false)
	assert_eq(r.modulate, Color.WHITE)
	assert_null(r.material)
	r.free()


func test_apply_state_locked_uses_desaturate_shader_with_white_modulate() -> void:
	var r := TextureRect.new()
	AchievementIcons.apply_state(r, true)
	assert_eq(r.modulate, Color.WHITE)
	assert_true(r.material is ShaderMaterial)
	assert_not_null((r.material as ShaderMaterial).shader)
	assert_almost_eq(
		float((r.material as ShaderMaterial).get_shader_parameter(&"desaturate")), 1.0, 1e-6
	)
	r.free()
