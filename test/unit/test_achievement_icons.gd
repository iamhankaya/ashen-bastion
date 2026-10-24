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
	d.icon = "res://assets/ui/icons/dinamit.svg"
	assert_eq(AchievementIcons.path_for(d), "res://assets/ui/icons/dinamit.svg")
	d.icon = "res://assets/ui/icons/yok.svg"
	assert_eq(AchievementIcons.path_for(d), "res://assets/ui/icons/hud-oldurme.svg")


func test_tier_colors_are_distinct_per_family() -> void:
	assert_ne(AchievementIcons.tier_color(&"kolay"), AchievementIcons.tier_color(&"orta"))
	assert_eq(AchievementIcons.tier_color(&"zor"), AchievementIcons.tier_color(&"cok_zor"))
