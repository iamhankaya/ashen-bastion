class_name FxValidatorA
extends DataValidator
## Kuru deneme eklentisi: eşit `order`, kimlik sırası `a` < `b`.


func validator_order() -> int:
	return 20


func validator_id() -> StringName:
	return &"a"


func run(_g: GameData, out: PackedStringArray, _complete: bool) -> void:
	out.append("[fx] a: çalıştı")
