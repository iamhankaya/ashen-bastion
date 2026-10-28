extends GutTest
## catalog_fixtures.gd (sözleşme-B): sentetik 0/1/3 karakter gerçek GameData yükleyicisinden geçer ve USER_LEAK bırakmaz.


func test_characters_zero_one_three() -> void:
	for n in [0, 1, 3]:
		var g := CatalogFixtures.characters(n)
		assert_eq(g.character_ids.size(), n, "n=%d" % n)
		assert_eq(CharacterRoster.ids(g).size(), n)
		for id in g.character_ids:
			assert_not_null(g.get_character(id), String(id))


func test_characters_keep_order() -> void:
	var g := CatalogFixtures.characters(3)
	assert_eq(g.character_ids, [&"zz_c0", &"zz_c1", &"zz_c2"] as Array[StringName])


func test_characters_fixture_leaves_no_user_files() -> void:
	CatalogFixtures.characters(2)
	var dir := "%s_%d" % [CatalogFixtures.TMP_DIR, OS.get_process_id()]
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)))


func test_characters_do_not_touch_default_cache() -> void:
	var before := GameData.load_default()
	CatalogFixtures.characters(1)
	assert_same(GameData.load_default(), before)


func test_list_fixtures_have_requested_size() -> void:
	for n in [0, 1, 3]:
		assert_eq(CatalogFixtures.modes(n).size(), n)
		assert_eq(CatalogFixtures.difficulties(n).size(), n)
		assert_eq(CatalogFixtures.metrics(n).size(), n)
