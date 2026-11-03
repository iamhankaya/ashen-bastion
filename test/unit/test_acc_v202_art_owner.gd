extends GutTest
## F-150: rig kapısı sahip kuralı. Paylaşılan şerit yalnız kanonik yoldan (`assets/gfx/char/<sahip>_strip.png`) sahip sayılır;
## waiver karaktere bağlıdır (başka karakterin waiver'ı yenisini aklamaz).


func _rig(strip: String) -> Dictionary:
	return {"walk": {"strip": strip}}


func test_own_strip_owner_is_the_character() -> void:
	assert_eq(AccV202.art_owner(&"veyra", _rig("res://assets/gfx/char/veyra_strip.png")), &"veyra")


func test_canonical_shared_strip_points_to_its_owner() -> void:
	var rig := _rig("res://assets/gfx/char/zyfen_strip.png")
	assert_eq(AccV202.art_owner(&"veyra", rig), &"zyfen")


func test_strip_named_after_another_owner_in_a_foreign_dir_does_not_borrow_that_owner() -> void:
	var rig := _rig("res://assets/gfx/char/veyra/zyfen_strip.png")
	assert_eq(AccV202.art_owner(&"veyra", rig), &"veyra", "yol kanonik değil: kendi kaynağı aranır")


func test_non_strip_name_or_missing_walk_falls_back_to_the_character() -> void:
	assert_eq(AccV202.art_owner(&"veyra", _rig("res://assets/gfx/char/x.png")), &"veyra")
	assert_eq(AccV202.art_owner(&"veyra", {}), &"veyra")


func test_waiver_is_bound_to_the_character_not_the_strip_owner() -> void:
	assert_eq(AccV202.waiver_path(&"veyra"), "res://docs/design/walk-waiver-veyra.md")
	assert_eq(AccV202.waiver_path(&"zyfen"), "res://docs/design/v2.0.2/walk-waiver.md")
