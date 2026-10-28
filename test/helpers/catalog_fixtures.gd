class_name CatalogFixtures
extends RefCounted
## Sentetik katalog fixture'ları (sözleşme-B): 0/1/3 girdili karakter, mod/zorluk ve başarım metriği. Gerçek veriye bağlı
## değildir; testler sabit sayı yerine "tüm kimlikler için X" yazar.

const TMP_DIR := "user://catalog_fixture"  # paralel GUT süreçleri için characters() kimlik ekler


## `n` karakterli GameData (GameData.load_dir geçici dizinden; okuduktan sonra dizin silinir, USER_LEAK bırakmaz).
static func characters(n: int) -> GameData:
	var dir := "%s_%d" % [TMP_DIR, OS.get_process_id()]
	var abs_dir := ProjectSettings.globalize_path(dir)
	_rm_rf(abs_dir)  # önceki çökmeden kalan dosyalar sayıyı bozmasın
	DirAccess.make_dir_recursive_absolute(abs_dir.path_join("characters"))
	for i in n:
		var d := {
			"id": "zz_c%d" % i,
			"name": "ZZ %d" % i,
			"order": i + 1,
			"starting_skill": "",
			"max_hp": 100
		}
		var f := FileAccess.open(abs_dir.path_join("characters/zz_c%d.json" % i), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(d))
			f.close()
	var g := GameData.load_dir(dir)
	_rm_rf(abs_dir)
	return g


## `n` mod: kimlik zz_m0.., order artan, ilki varsayılan değil (RunCatalog ilkini varsayılan sayar), bitiş "lord".
static func modes(n: int) -> Array:
	var out: Array = []
	for i in n:
		(
			out
			. append(
				{
					"id": "zz_m%d" % i,
					"order": i + 1,
					"name": "ZZ MOD %d" % i,
					"description": "",
					"profile":
					{"time_scale": 1.0, "xp_mult": 1.0, "lord_hp_mult": 1.0, "rate_mult": 1.0},
					"ending": "lord",
					"icon_key": "zz",
				}
			)
		)
	return out


static func difficulties(n: int) -> Array:
	var out: Array = []
	for i in n:
		(
			out
			. append(
				{
					"id": "zz_d%d" % i,
					"order": i + 1,
					"name": "ZZ ZORLUK %d" % i,
					"description": "",
					"values":
					{
						"enemy_hp": 1.0,
						"enemy_dmg": 1.0,
						"spawn_density": 1.0,
						"xp": 1.0,
						"lord_hp": 1.0
					},
				}
			)
		)
	return out


## `n` metrik: yerleşik toplamla ifade edilen (olay + sum), persist anahtarları ayrık.
static func metrics(n: int) -> Array:
	var out: Array = []
	for i in n:
		(
			out
			. append(
				{
					"stat": "zz_stat%d" % i,
					"group": "ZZ",
					"tiers": [10, 20, 30],
					"goal_text": "ZZ %d" % i,
					"icon_family": "zz",
					"source": {"event": "kill", "filter": {}, "value": "one"},
					"aggregate": "sum",
					"persist": {"total": "zz_total%d" % i, "best": null},
				}
			)
		)
	return out


static func _rm_rf(abs_dir: String) -> void:
	for sub in DirAccess.get_directories_at(abs_dir):
		_rm_rf(abs_dir.path_join(sub))
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)
