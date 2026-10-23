extends GutTest
## Doğrulama (T20261023-98): bellek / atlas hesabı. Sabit havuz ayak izi, düşman atlası, oyuncu şeridi, MultiMesh tamponları
## ve koşu boyunca büyümeme. Sayılar masaüstü bayt hesabıdır (cihaz GPU belleği sürücüye bağlı; yalnız üst sınır kanıtı).

const POOL_BUDGET_BYTES := 2_000_000  # tüm sim havuzları (SoA) birlikte
const TOTAL_BUDGET_BYTES := 24_000_000  # atlas + oyuncu şeridi + tamponlar + havuzlar


## Bir nesnenin Packed*Array alanlarının toplam bayt boyutu (ad -> bayt).
func after_all() -> void:
	SimKit.remove_tmp()


func _packed_bytes(obj: Object) -> int:
	var total := 0
	for p in obj.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var v: Variant = obj.get(p["name"])
		if (
			v is PackedFloat32Array
			or v is PackedInt32Array
			or v is PackedVector2Array
			or v is PackedInt64Array
			or v is PackedFloat64Array
			or v is PackedColorArray
		):
			total += v.to_byte_array().size()
	return total


func _pools(sim: GameSim) -> Array:
	return [sim.enemies, sim.projectiles, sim.gems, sim.zones, sim.pickups, sim.bombs, sim.buffs]


func _pool_total(sim: GameSim) -> int:
	var total := 0
	for p in _pools(sim):
		total += _packed_bytes(p)
	return total


func test_sim_pool_footprint_is_small_and_fixed_across_a_long_run() -> void:
	var sim := SimKit.make(41, {"data_kind": "real", "log_events": false})
	SimKit.godmode(sim)
	var before := _pool_total(sim)
	assert_gt(before, 0, "havuz alanları okunabiliyor")
	assert_lte(before, POOL_BUDGET_BYTES, "havuz ayak izi %d bayt" % before)
	var rng := Bots.make_rng(41)
	Bots.play(sim, &"greedy_pickup", 12000, rng)
	# Boş-kimlik yığını (`EnemyPool._free`) kullanım sırasında küçülür; büyüme olmamalı.
	assert_lte(_pool_total(sim), before, "havuz dizileri koşuda büyümez (sabit CAP)")
	assert_lte(sim.event_log.size(), 0, "log_events kapalıyken olay kaydı birikmez")


func test_enemy_atlas_and_total_budget() -> void:
	var data := GameData.load_default()
	var paths: Array[String] = []
	for id in data.enemy_ids:
		var sp := data.get_enemy(id).sprite
		if not paths.has(sp):
			paths.append(sp)
	var atlas := EnemyAtlas.new().build(paths)
	var atlas_bytes := atlas.texture.get_width() * atlas.texture.get_height() * 4
	var cells := 0
	for p in paths:
		cells += int(atlas.cells[p]["frames"])
	assert_lte(cells, EnemyAtlas.COLS * atlas.rows, "hücre sayısı atlas satırlarına sığar")
	# Oyuncu şeridi: (N+1) hücre RGBA (kare yoksa N=6 varsayımı = üst sınır hesabı).
	var w: Dictionary = data.get_character(&"gunslinger").rig["walk"]
	var n := int(w["frames"]) if int(w["frames"]) > 0 else 6
	var strip_bytes := (n + 1) * int(w["cell"][0]) * int(w["cell"][1]) * 4
	# MultiMesh tamponları: düşman 16 float, gölge 12 float, CAP örnek.
	var mm_bytes := EnemyPool.CAP * (16 + 12) * 4
	var pools := _pool_total(SimKit.make(1, {"data_kind": "real"}))
	var total := atlas_bytes + strip_bytes + mm_bytes + pools
	(
		gut
		. p(
			(
				"bellek: atlas %.2f MB (%d hücre, %dx%d) + oyuncu şeridi %.2f MB + tampon %.2f MB + havuz %.2f MB = %.2f MB"
				% [
					atlas_bytes / 1.0e6,
					cells,
					atlas.texture.get_width(),
					atlas.texture.get_height(),
					strip_bytes / 1.0e6,
					mm_bytes / 1.0e6,
					pools / 1.0e6,
					total / 1.0e6,
				]
			)
		)
	)
	assert_lte(atlas_bytes, ExpectedTablesV11.ATLAS_BYTES_MAX)
	assert_lte(strip_bytes, ExpectedTablesV11.STRIP_BYTES_MAX)
	assert_lte(total, TOTAL_BUDGET_BYTES, "toplam görünür bellek %.2f MB" % (total / 1.0e6))
	assert_eq(EnemyAtlas.CELL, 416, "hücre boyutu hesapla uyumlu")
