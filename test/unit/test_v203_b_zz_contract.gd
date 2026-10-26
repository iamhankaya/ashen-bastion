extends GutTest
## v2.0.3 sözleşme (B ad alanı): küre tipi -> görsel eşlemesi veri alanları. Sim değişmez (hash yalnız count/total_value).
## `zz` ayırıcısı için test_v203_c_zz_schema.gd'ye bak.


func test_tier_of_classifies_by_value_boundaries() -> void:
	assert_eq(GemTiers.tier_of(1), GemTiers.NORMAL)
	assert_eq(GemTiers.tier_of(4), GemTiers.NORMAL)
	assert_eq(GemTiers.tier_of(5), GemTiers.ELIT)
	assert_eq(GemTiers.tier_of(79), GemTiers.ELIT)
	assert_eq(GemTiers.tier_of(80), GemTiers.BOSS)
	assert_eq(GemTiers.tier_of(5000), GemTiers.BOSS, "birleşmiş taş en üst sınıfta kalır")


func test_tier_of_never_returns_out_of_range_for_bad_values() -> void:
	assert_eq(GemTiers.tier_of(0), GemTiers.NORMAL)
	assert_eq(GemTiers.tier_of(-3), GemTiers.NORMAL)


func test_enemy_xp_values_land_in_the_agreed_tiers() -> void:
	var g := GameData.load_dir("res://data")
	var expect := {
		&"curumus_piyade": GemTiers.NORMAL,
		&"les_kargasi": GemTiers.NORMAL,
		&"sovalye_hayaleti": GemTiers.ELIT,
		&"elit_piyade": GemTiers.BOSS,
		&"elit_sovalye": GemTiers.BOSS,
		&"elit_karga": GemTiers.BOSS,
		&"kale_lordu": GemTiers.BOSS,
	}
	for id in expect:
		var e: Variant = g.get_enemy(id)
		assert_not_null(e, String(id))
		assert_eq(GemTiers.tier_of(e.xp), expect[id], String(id))


func test_data_fields_have_one_entry_per_tier() -> void:
	assert_eq(GemTiers.TEXTURES.size(), GemTiers.COUNT)
	assert_eq(GemTiers.ORB_PX.size(), GemTiers.COUNT)
	assert_eq(GemTiers.COUNT, 3)
	assert_eq(GemTiers.ORB_PX, PackedInt32Array([34, 48, 68]))
	for t in GemTiers.TEXTURES:
		assert_true(t.begins_with("res://assets/gfx/fx/gems/"), t)
