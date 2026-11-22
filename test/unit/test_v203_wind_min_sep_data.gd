extends GutTest
## F-ashen-bastion-049: Hortum/Tufan `min_sep` kodda gizli varsayılan değil, veride yazılı. Değer eski varsayılanla
## (taban yarıçap x WindSystem.DEFAULT_SEP_RATIO) aynıdır; yani davranış değişmez.

const SKILLS := ["hortum", "tufan"]

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func test_every_level_declares_min_sep_equal_to_old_default() -> void:
	for id in SKILLS:
		var def := _data.get_skill(StringName(id))
		assert_not_null(def, "%s tanımlı" % id)
		if def == null:
			continue
		for k in def.levels.size():
			var lv: Dictionary = def.levels[k]
			assert_true(lv.has("min_sep"), "%s sv%d: min_sep veride" % [id, k + 1])
			if lv.has("min_sep"):
				assert_almost_eq(
					float(lv["min_sep"]),
					float(lv["radius"]) * WindSystem.DEFAULT_SEP_RATIO,
					0.01,
					"%s sv%d: min_sep eski varsayılanla aynı" % [id, k + 1]
				)
