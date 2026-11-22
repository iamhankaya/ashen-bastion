extends GutTest
## F-ashen-bastion-127: GUT koşu kancaları (pre/post) tek yardımcı `UserLeak.clear_run_caches()` ile UiKit/ArtLoader/
## AchievementMetricRegistry önbelleklerini sıfırlar; yalnız koşu sonu değil koşu başı da temiz başlanır.


func after_each() -> void:
	UserLeak.clear_run_caches()


func test_clear_run_caches_empties_all_run_scoped_caches() -> void:
	UiKit.font_semibold()
	ArtLoader._cache["probe"] = null
	var before := AchievementMetricRegistry.default()
	assert_false(UiKit._tex_cache.is_empty(), "ön koşul: UiKit dolu")
	UserLeak.clear_run_caches()
	assert_true(UiKit._tex_cache.is_empty(), "UiKit boş")
	assert_true(ArtLoader._cache.is_empty(), "ArtLoader boş")
	assert_ne(
		AchievementMetricRegistry.default().get_instance_id(),
		before.get_instance_id(),
		"metrik kaydı yeniden okunur"
	)


func test_both_hooks_call_the_helper() -> void:
	for p in ["res://tools/ci/gut_pre_hook.gd", "res://tools/ci/gut_stub_hook.gd"]:
		var src := FileAccess.get_file_as_string(p)
		assert_string_contains(src, "UserLeak.clear_run_caches()", p)
