extends GutTest
## Kabul (v1.1): bütçe - havuz CAP'leri, atlas bellek hesabı, oyuncu şeridi, perf_budget.json değişmezliği (G tablosu).
## Hesap testleri; cihaz/zaman ölçümü yok (zaman yalnız bilgi, "Kullanıcıda doğrulanır").

const BUDGET_PATH := "res://tools/perf_budget.json"
const SHADER_PATH := "res://assets/shaders/enemy_flash.gdshader"
## v1 tavanları (tools/perf_budget.json); v1.1 bunları DEĞİŞTİRMEZ - değişim bilinçli olarak bu sabitle birlikte yapılır.
const V1_CEILINGS := {
	"hash_inserts": 500,
	"hash_queries": 640,
	"cells_scanned": 2650,
	"collision_tests": 470,
	"enemy_updates": 500,
	"proj_updates": 630,
	"explosions": 1,
}


func test_pool_caps_are_8_4_and_gems_enemies_unchanged() -> void:
	assert_eq(PickupPool.CAP, 8)
	assert_eq(BombPool.CAP, 4)
	assert_eq(AshGhostRenderer.CAP, 64)
	assert_eq(GemPool.CAP, 300, "v1 taş havuzu değişmez")
	var sim := SimKit.make(1, {"data_kind": "quiet_pickups"})
	for k in 12:
		sim.debug_spawn_pickup(&"kizil_iksir", Vector2(900.0 + 10.0 * k, 0))
	assert_eq(sim.pickups.count, 8, "eklenti havuzu 8'de dolar")
	assert_eq(sim.debug_spawn_pickup(&"kizil_iksir", Vector2(2000, 0)), -1, "dolu: -1")


func test_perf_budget_file_is_unchanged_by_v11() -> void:
	var budget: Variant = KitDev.read_json(BUDGET_PATH)
	assert_true(budget is Dictionary)
	if not budget is Dictionary:
		return
	assert_eq(budget.size(), V1_CEILINGS.size(), "yeni sayaç anahtarı eklenmez")
	for k in V1_CEILINGS:
		assert_eq(int(budget.get(k, -1)), V1_CEILINGS[k], "%s tavanı v1 değeri" % k)


func test_work_keys_unchanged_so_pickups_and_score_add_no_counters() -> void:
	var keys: Array[StringName] = [
		&"hash_inserts",
		&"hash_queries",
		&"cells_scanned",
		&"collision_tests",
		&"enemy_updates",
		&"proj_updates",
		&"explosions"
	]
	for k in keys:
		assert_true(GameSim.WORK_KEYS.has(k), "%s" % k)
	assert_eq(GameSim.WORK_KEYS.size(), keys.size(), "WORK_KEYS değişmez")


func test_atlas_dimensions_and_memory_follow_the_cell_count() -> void:
	var data := GameData.load_default()
	var paths: Array[String] = []
	for id in data.enemy_ids:
		var sp := data.get_enemy(id).sprite
		if not paths.has(sp):
			paths.append(sp)
	var atlas := EnemyAtlas.new().build(paths)
	var total := 0
	for p in paths:
		total += int(atlas.cells[p]["frames"])
	var rows := ceili(float(total) / float(EnemyAtlas.COLS))
	assert_eq(atlas.rows, rows)
	assert_eq(atlas.texture.get_width(), EnemyAtlas.COLS * EnemyAtlas.CELL)
	assert_eq(atlas.texture.get_height(), rows * EnemyAtlas.CELL)
	assert_eq(atlas.rects.size(), EnemyAtlas.COLS * rows)
	var bytes := atlas.texture.get_width() * atlas.texture.get_height() * 4
	assert_lte(bytes, ExpectedTablesV11.ATLAS_BYTES_MAX, "atlas <= ~8,3 MB (+tolerans)")
	if total == ExpectedTablesV11.ATLAS_CELLS:
		assert_eq(
			Vector2i(atlas.texture.get_width(), atlas.texture.get_height()),
			ExpectedTablesV11.ATLAS_PX,
			"11 hücre: 3x4 = 1248x1664"
		)
		assert_almost_eq(float(bytes) / 1.0e6, 8.3, 0.1)
	assert_lte(total, ExpectedTablesV11.CELL_RECT_UNIFORM, "cell_rect[16] yeter")


func test_eleven_cells_make_a_3x4_atlas_of_1248x1664() -> void:
	# Sentetik: 6 tek kareli yer tutucu + 5 hücreli şerit eşdeğeri yerine 11 ayrı sprite (her biri 1 hücre).
	var paths: Array[String] = []
	for k in ExpectedTablesV11.ATLAS_CELLS:
		paths.append("res://yok/sprite_%d.png" % k)
	var atlas := EnemyAtlas.new().build(paths)
	assert_eq(atlas.rows, ExpectedTablesV11.ATLAS_ROWS)
	assert_eq(atlas.texture.get_width(), ExpectedTablesV11.ATLAS_PX.x)
	assert_eq(atlas.texture.get_height(), ExpectedTablesV11.ATLAS_PX.y)
	assert_eq(atlas.rects.size(), EnemyAtlas.COLS * ExpectedTablesV11.ATLAS_ROWS)
	assert_lte(float(atlas.texture.get_width() * atlas.texture.get_height() * 4) / 1.0e6, 8.4)


func test_enemy_shader_cell_rect_uniform_is_large_enough_for_the_atlas() -> void:
	var src := FileAccess.get_file_as_string(SHADER_PATH)
	var rx := RegEx.new()
	rx.compile("uniform\\s+vec4\\s+cell_rect\\s*\\[\\s*(\\d+)\\s*\\]")
	var m := rx.search(src)
	assert_not_null(m, "cell_rect dizisi shader'da")
	if m == null:
		return
	var size := int(m.get_string(1))
	var data := GameData.load_default()
	var paths: Array[String] = []
	for id in data.enemy_ids:
		var sp := data.get_enemy(id).sprite
		if not paths.has(sp):
			paths.append(sp)
	var atlas := EnemyAtlas.new().build(paths)
	assert_gte(
		size,
		atlas.rects.size(),
		"uniform dizisi atlas hücre sayısını kapsar (16'yı aşarsa büyütülmeli)"
	)


func test_player_strip_budget_formula_for_n_plus_one_cells() -> void:
	# (N+1) hücre x hücre boyutu <= 3 MB RGBA, hücre yüksekliği <= 400 px (sözleşmedeki gunslinger.json hücresi).
	var w: Dictionary = GameData.load_default().get_character(&"gunslinger").rig["walk"]
	var cell: Array = w["cell"]
	var n := int(w["frames"]) if int(w["frames"]) > 0 else 6
	assert_lte(int(cell[1]), 400, "hücre yüksekliği <= 400")
	var bytes := (n + 1) * int(cell[0]) * int(cell[1]) * 4
	assert_lte(
		bytes, ExpectedTablesV11.STRIP_BYTES_MAX, "(N+1) hücre RGBA <= 3 MB (%d bayt)" % bytes
	)
	if int(w["frames"]) > 0 and FileAccess.file_exists(String(w["strip"])):
		var img := Image.load_from_file(ProjectSettings.globalize_path(String(w["strip"])))
		if img != null:
			assert_lte(
				img.get_width() * img.get_height() * 4,
				ExpectedTablesV11.STRIP_BYTES_MAX,
				"şerit dosyası <= 3 MB RGBA"
			)
			assert_eq(img.get_width() % (int(w["frames"]) + 1), 0, "şerit (N+1) eşit hücre")


func test_pickups_and_score_add_no_work_counters_over_the_v1_baseline() -> void:
	# Eklenti+skor açık/kapalı iki özdeş boş koşu: v1 iş sayaçları birebir eşit (yeni kod hash/çarpışma işi üretmez).
	var on := SimKit.make(2, {"data_kind": "quiet_pickups"})
	var off := SimKit.make(2, {"data_kind": "quiet_pickups", "pickups": false})
	SimKit.run(on, 1200)
	SimKit.run(off, 1200)
	for k in GameSim.WORK_KEYS:
		assert_eq(on.work[k], off.work[k], "%s: eklentili/eklentisiz aynı iş" % k)
