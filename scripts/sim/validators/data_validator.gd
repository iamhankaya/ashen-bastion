class_name DataValidator
extends RefCounted
## GameData doğrulayıcı eklentisi (docs/data-schema.md `### Doğrulayıcı eklentileri`). `scripts/sim/validators/`
## altına `extends DataValidator` yeni bir dosya eklemek yeter; `GameData._discover_validators()` bulur, hiçbir
## kayıt dosyasına dokunulmaz. Doğrudan alt sınıf olmalı (ara sınıf keşfedilmez); başka eklentiye ve sim dışı
## katmana bağımlı olamaz (test_data_validator_protocol).


## Çalışma sırası: küçük önce, eşitlikte `validator_id`, sonra dosya yolu. Çekirdek doğrulayıcıların ardından koşar.
func validator_order() -> int:
	return 1000


## Benzersiz ad (sıralama ve hata ayıklama için); alt sınıf geçersiz kılar.
func validator_id() -> StringName:
	return &""


## Hataları `out`'a `"[kod] bağlam: açıklama"` biçiminde ekler. `complete`: içerik tamamlandı modu.
func run(_g: GameData, _out: PackedStringArray, _complete: bool) -> void:
	pass
