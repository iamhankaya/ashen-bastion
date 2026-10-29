class_name FxValidatorB
extends DataValidator
## Kuru deneme eklentisi: eşit `order`, kimlik sırası `a` < `b`; dosya adı `a`'dan önce gelmez, sıra kimlikten çıkar.


func validator_order() -> int:
	return 20


func validator_id() -> StringName:
	return &"b"


func run(_g: GameData, out: PackedStringArray, complete: bool) -> void:
	out.append("[fx] b: çalıştı complete=%s" % complete)
