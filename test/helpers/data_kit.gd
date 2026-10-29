class_name DataKit
extends RefCounted
## `GameData._default` (paylaşımlı önbellek) için test yardımcısı. Kural (docs/data-schema.md `### Paylaşılan veri`):
## `GameData.load_default()` nesneleri SALT OKUNURDUR. Veriyi değiştiren test `copy()` ile kendi kopyasını alır ve
## `GameSim`'e `{"data": copy}` olarak verir; önbelleğe dokunmaz. Önbelleği sıfırlaması gereken test `use_fresh()` çağırır
## ve `after_each`'te `release()` çağırır.


## Önbellekten bağımsız, taze yüklenmiş `res://data` kopyası: yazan test bunu kullanır.
static func copy() -> GameData:
	return GameData.load_dir("res://data")


## Önbelleği sıfırlayıp taze varsayılan veriyi döndürür (sonraki `load_default()` aynı nesneyi verir).
static func use_fresh() -> GameData:
	GameData.clear_default_cache()
	return GameData.load_default()


## `after_each` temizliği: sonraki test paylaşılan önbelleği yeniden yükler.
static func release() -> void:
	GameData.clear_default_cache()
