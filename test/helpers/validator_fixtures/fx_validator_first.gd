class_name FxValidatorFirst
extends DataValidator
## Kuru deneme eklentisi: sırası en küçük, kimliği alfabetik olarak sonda (sıra `order`'a bağlı olmalı).


func validator_order() -> int:
	return 5


func validator_id() -> StringName:
	return &"z_first"


func run(_g: GameData, out: PackedStringArray, _complete: bool) -> void:
	out.append("[fx] z_first: çalıştı")
