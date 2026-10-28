extends GutTest
## Karakterizasyon (plan Faz 4 madde 12): GameData doğrulayıcı hata mesajları ve SIRASI. Her bozuk fixture dizini için
## `validate({}, true)` çıktısı birebir sabit. Baz: rf_data_errors.json. Mesaj sırası değişirse test kırılır (determinizm sözleşmesi).

const ROOT := "res://test/fixtures/"


func test_rf_validator_messages_and_order() -> void:
	var dirs := Array(DirAccess.get_directories_at(ROOT))
	dirs.sort()
	var out := {}
	for d in dirs:
		if not (d.begins_with("data_") or d.begins_with("char_bad_") or d.begins_with("pool_bad_")):
			continue
		out[d] = Array(GameData.load_dir(ROOT + d).validate({}, true))
	assert_gt(out.size(), 40, "bozuk fixture dizinleri bulundu")
	RfBaseline.check(self, "rf_data_errors", out)


func test_rf_real_data_is_valid_and_validation_is_repeatable() -> void:
	var a := Array(GameData.load_dir("res://data").validate({}, true))
	var b := Array(GameData.load_dir("res://data").validate({}, true))
	assert_eq(a, b, "doğrulama tekrarlanabilir")
	assert_eq(a, [], "gerçek veri geçerli")
