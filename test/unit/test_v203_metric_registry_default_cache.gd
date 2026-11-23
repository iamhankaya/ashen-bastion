extends GutTest
## F-ashen-bastion-142: gerçek veri kaydı (`default()`) her çağrıda 21 metrik JSON'unu diskten okumaz; bellekte tutulur,
## temizleme çağrısıyla yeniden okunur. İçerik her iki durumda aynıdır.


func after_each() -> void:
	AchievementMetricRegistry.clear_default_cache()


func test_default_is_memoized_until_cleared() -> void:
	AchievementMetricRegistry.clear_default_cache()
	var a := AchievementMetricRegistry.default()
	var b := AchievementMetricRegistry.default()
	assert_same(a, b, "ikinci çağrı aynı kaydı döndürür (diske gitmez)")
	AchievementMetricRegistry.clear_default_cache()
	var c := AchievementMetricRegistry.default()
	assert_ne(c.get_instance_id(), a.get_instance_id(), "temizlemeden sonra yeniden okunur")
	assert_eq(c.stats(), a.stats(), "içerik aynı")
	assert_eq(c.total_tiers(), a.total_tiers())


func test_default_content_matches_fresh_read() -> void:
	var cached := AchievementMetricRegistry.default()
	var fresh := AchievementMetricRegistry.from_dicts(MetricSchema.read_dir())
	assert_eq(cached.stats(), fresh.stats())
	assert_eq(cached.validate(), fresh.validate())
