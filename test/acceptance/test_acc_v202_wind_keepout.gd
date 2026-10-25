extends GutTest
## Kabul (T20261025-79): Hortum/Tufan oyuncudan UZAKTA doğar ve oyuncunun üzerine GELMEZ (kullanıcı kararı 2026-10-25).
## Davranış: doğuş merkezi oyuncudan >= `min_spawn_dist` (uzak kümede; uygun küme yoksa bu uzaklıkta yedek nokta);
## yeniden hedeflemede oyuncuya `keep_out` içindeki hedef seçilmez; hareket bölge merkezini oyuncuya `keep_out`'tan fazla
## yaklaştırmaz; "max_dist aşılırsa oyuncuya dön" kuralı yoktur. Çekme/tik/2x bitiş/savurmasızlık test_acc_v202_wind_skills.gd'dedir.
## Sayılar data/skills/{hortum,tufan}.json yeni alanlarından (`min_spawn_dist`, `keep_out`) okunur; başlangıç değerleri 300/250.
## Bu dosya V202Slice kapısı kullanmaz (yeni davranışın kendi kabulü). Uygulama gelmeden KIRMIZI olması beklenen durumdur.
##
## Varsayımlar (sözleşme belgesi güncellenince doğrulanmalı):
## - Veri alanları: `min_spawn_dist` ve `keep_out` (görev metnindeki ad önerisi); `WindSystem.cast_twisters(sim, kind, lv)` bu alanları
##   `lv` sözlüğünden okur. Bölge havuzunda yeni alan adı VARSAYILMAZ: testler yalnız `pos/target/retarget_left` okur/yazar.
## - Yedek doğuş noktası "bu uzaklıkta" = `min_spawn_dist` (+ en çok SPAWN_TOL px), görünür alan üst sınırı VIEW_MAX.

const STEP := GameSim.STEP
const SPAWN_TOL := 5.0
## Görünür alan için gevşek üst sınır (RETARGET_RANGE = 600; ekran yarı çapraz uzunluğu bunun altındadır).
const VIEW_MAX := 700.0
const EPS := 0.01
## Beceri tick'i doğuşla aynı adımda bölge adımını da işler: doğuştan sonra en çok 1 adım hareket (hız <= 110 px/sn x 1/60).
const MOVE_SLACK := 2.0

const CASES := [[&"hortum", 1], [&"hortum", 4], [&"hortum", 5], [&"tufan", 1]]


func _lv(id: StringName, level: int) -> Dictionary:
	var f := FileAccess.open("res://data/skills/%s.json" % id, FileAccess.READ)
	assert_not_null(f, "%s.json açıldı" % id)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	return (d["levels"] as Array)[level - 1]


func _kind(id: StringName) -> int:
	return ZonePool.KIND_GIANT if id == &"tufan" else ZonePool.KIND_TWISTER


func _label(c: Array) -> String:
	return "%s sv%d" % [c[0], c[1]]


## Küme: merkez etrafında 5 kukla (sıkı).
func _cluster(sim: GameSim, center: Vector2, n: int = 5) -> void:
	for k in n:
		WindKit.dummy(sim, center + Vector2.from_angle(TAU * k / n) * 20.0)


# --- Veri --------------------------------------------------------------------------------------------------


func test_k0_data_has_min_spawn_dist_and_keep_out_for_hortum_and_tufan() -> void:
	for c in CASES:
		var lv := _lv(c[0], c[1])
		assert_true(lv.has("min_spawn_dist"), "%s: min_spawn_dist alanı var" % _label(c))
		assert_true(lv.has("keep_out"), "%s: keep_out alanı var" % _label(c))
		assert_gte(
			float(lv.get("min_spawn_dist", 0.0)), 300.0, "%s: min_spawn_dist >= 300" % _label(c)
		)
		assert_gte(float(lv.get("keep_out", 0.0)), 250.0, "%s: keep_out >= 250" % _label(c))
		assert_gte(
			float(lv.get("min_spawn_dist", 0.0)),
			float(lv.get("keep_out", 1.0e9)),
			"%s: doğuş uzaklığı keep_out'tan küçük olamaz" % _label(c)
		)


# --- Doğuş -------------------------------------------------------------------------------------------------


func test_k1_spawn_center_is_at_least_min_spawn_dist_from_player_with_enemies_around() -> void:
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var min_d := float(lv.get("min_spawn_dist", 300.0))
		for seed_value in [1, 2, 3, 7]:
			var sim := WindKit.make(c[0], c[1], seed_value)
			_cluster(sim, sim.player_pos + Vector2(500, 0))
			_cluster(sim, sim.player_pos + Vector2(-100, 60))
			WindKit.skill_steps(sim, 1)
			assert_gt(sim.zones.count, 0, "%s: bölge doğdu" % _label(c))
			for i in sim.zones.count:
				assert_gte(
					sim.zones.pos[i].distance_to(sim.player_pos),
					min_d - MOVE_SLACK,
					(
						"%s tohum %d bölge %d: doğuşta oyuncudan >= min_spawn_dist"
						% [_label(c), seed_value, i]
					)
				)


func test_k2_far_cluster_is_chosen_over_near_cluster() -> void:
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var min_d := float(lv.get("min_spawn_dist", 300.0))
		for seed_value in [1, 2, 3, 4, 5, 6]:
			var sim := WindKit.make(c[0], c[1], seed_value)
			var near_c := sim.player_pos + Vector2(0, -120)
			var far_c := sim.player_pos + Vector2(480, 0)
			_cluster(sim, near_c)
			_cluster(sim, far_c)
			WindKit.skill_steps(sim, 1)
			assert_gt(sim.zones.count, 0, "%s: bölge doğdu" % _label(c))
			var r := float(sim.zones.radius[0])
			for i in sim.zones.count:
				var p := sim.zones.pos[i]
				assert_gte(
					p.distance_to(sim.player_pos), min_d - MOVE_SLACK, "%s: uzak mesafe" % _label(c)
				)
				assert_lt(
					p.distance_to(far_c),
					r,
					(
						"%s tohum %d bölge %d: yakın küme değil, uzak küme seçildi"
						% [_label(c), seed_value, i]
					)
				)


func test_k3_no_far_cluster_uses_fallback_point_at_min_spawn_dist_inside_view() -> void:
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var min_d := float(lv.get("min_spawn_dist", 300.0))
		for seed_value in [1, 2, 3, 4]:
			var sim := WindKit.make(c[0], c[1], seed_value)
			# Bütün düşmanlar oyuncuya yakın (< min_spawn_dist): uygun küme yok.
			_cluster(sim, sim.player_pos + Vector2(90, 40))
			_cluster(sim, sim.player_pos + Vector2(-110, -60), 3)
			WindKit.skill_steps(sim, 1)
			assert_gt(sim.zones.count, 0, "%s: bölge yine doğar" % _label(c))
			for i in sim.zones.count:
				var d := sim.zones.pos[i].distance_to(sim.player_pos)
				assert_gte(
					d,
					min_d - MOVE_SLACK,
					"%s tohum %d: yedek nokta >= min_spawn_dist" % [_label(c), seed_value]
				)
				assert_lte(
					d,
					min_d + SPAWN_TOL,
					"%s tohum %d: yedek nokta bu uzaklıkta" % [_label(c), seed_value]
				)
				assert_lte(d, VIEW_MAX, "%s: görünür alan içinde" % _label(c))


func test_k3b_cast_with_no_enemies_at_all_still_respects_min_spawn_dist() -> void:
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var min_d := float(lv.get("min_spawn_dist", 300.0))
		var sim := WindKit.make(&"", 1, 3)
		WindSystem.cast_twisters(sim, _kind(c[0]), lv)
		assert_gt(sim.zones.count, 0, "%s: bölge doğdu" % _label(c))
		for i in sim.zones.count:
			assert_gte(
				sim.zones.pos[i].distance_to(sim.player_pos),
				min_d - EPS,
				"%s: düşmansız doğuş" % _label(c)
			)


func test_k3c_spawn_distance_holds_when_player_is_away_from_origin() -> void:
	var lv := _lv(&"hortum", 4)
	var min_d := float(lv.get("min_spawn_dist", 300.0))
	var sim := WindKit.make(&"hortum", 4, 5)
	sim.player_pos = Vector2(1500, -900)
	_cluster(sim, sim.player_pos + Vector2(60, 0))
	WindKit.skill_steps(sim, 1)
	assert_gt(sim.zones.count, 0)
	for i in sim.zones.count:
		assert_gte(
			sim.zones.pos[i].distance_to(sim.player_pos),
			min_d - MOVE_SLACK,
			"oyuncu orijinde değilken"
		)


# --- Yeniden hedefleme ---------------------------------------------------------------------------------


func test_k4_retarget_never_picks_a_target_within_keep_out_of_player() -> void:
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var keep := float(lv.get("keep_out", 250.0))
		for seed_value in [1, 2, 3]:
			var sim := WindKit.make(c[0], c[1], seed_value)
			# Düşmanların hepsi keep_out içinde ve ayrıca bir uzak küme: hiçbir seçim keep_out içine düşmemeli.
			for k in 6:
				WindKit.dummy(sim, sim.player_pos + Vector2.from_angle(TAU * k / 6.0) * 120.0)
			_cluster(sim, sim.player_pos + Vector2(-480, 100))
			WindSystem.cast_twisters(sim, _kind(c[0]), lv)
			var picks := 0
			for _round in 40:
				for i in sim.zones.count:
					sim.zones.retarget_left[i] = 0.0
				WindKit.zone_steps(sim, 1)
				for i in sim.zones.count:
					picks += 1
					assert_gte(
						sim.zones.target[i].distance_to(sim.player_pos),
						keep - EPS,
						(
							"%s tohum %d: hedef oyuncuya keep_out içinde seçilmedi"
							% [_label(c), seed_value]
						)
					)
			assert_gt(picks, 0)


func test_k4b_retarget_with_only_near_enemies_still_avoids_keep_out() -> void:
	var lv := _lv(&"hortum", 1)
	var keep := float(lv.get("keep_out", 250.0))
	var sim := WindKit.make(&"hortum", 1, 2)
	for k in 6:
		WindKit.dummy(sim, sim.player_pos + Vector2.from_angle(TAU * k / 6.0) * 100.0)
	WindSystem.cast_twisters(sim, ZonePool.KIND_TWISTER, lv)
	for _round in 20:
		sim.zones.retarget_left[0] = 0.0
		WindKit.zone_steps(sim, 1)
		assert_gte(
			sim.zones.target[0].distance_to(sim.player_pos),
			keep - EPS,
			"uygun düşman yokken de keep_out dışı"
		)


func test_k5_retarget_draws_exactly_one_randf_even_when_all_candidates_are_filtered() -> void:
	# Sözleşme (behavior-contract.md Hortum satırı): yeniden hedefleme başına TAM 1 randf. Filtre kaç adayı
	# elerse elesin çekiliş sayısı değişmez (determinizm). Sözleşme değişirse bu test ve belge birlikte güncellenir.
	for scenario in ["hepsi_yakin", "karma", "bos"]:
		var sim := WindKit.make(&"hortum", 1, 4)
		var lv := _lv(&"hortum", 1)
		match scenario:
			"hepsi_yakin":
				for k in 5:
					WindKit.dummy(sim, sim.player_pos + Vector2(80 + 10 * k, 0))
			"karma":
				_cluster(sim, sim.player_pos + Vector2(90, 0), 3)
				_cluster(sim, sim.player_pos + Vector2(450, 0), 3)
		WindSystem.cast_twisters(sim, ZonePool.KIND_TWISTER, lv)
		var n := sim.zones.count
		assert_eq(n, 1)
		sim.zones.retarget_left[0] = 0.0
		var ref := RandomNumberGenerator.new()
		ref.seed = sim.rng_combat.seed
		ref.state = sim.rng_combat.state
		ref.randf()
		WindKit.zone_steps(sim, 1)
		assert_eq(
			sim.rng_combat.state, ref.state, "%s: yeniden hedefleme başına tam 1 randf" % scenario
		)


# --- Hareket -------------------------------------------------------------------------------------------


func test_k6_zone_aimed_through_the_player_stops_at_keep_out() -> void:
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var keep := float(lv.get("keep_out", 250.0))
		var sim := WindKit.make(c[0], c[1], 2)
		WindSystem.cast_twisters(sim, _kind(c[0]), lv)
		for i in sim.zones.count:
			sim.zones.life[i] = 1.0e6
			sim.zones.retarget_left[i] = 1.0e9  # yeniden hedefleme yok: hedef elle verildi
			sim.zones.target[i] = sim.player_pos  # tam oyuncunun üstüne
		var worst := 1.0e9
		for _s in 600:
			WindKit.zone_steps(sim, 1)
			for i in sim.zones.count:
				worst = minf(worst, sim.zones.pos[i].distance_to(sim.player_pos))
		assert_gte(worst, keep - 0.5, "%s: ömür boyu oyuncuya >= keep_out" % _label(c))


func test_k7_zone_never_moves_closer_to_the_player_by_its_own_movement() -> void:
	# Oyuncu bölgeye doğru yürür (bölge itilmez); iddia: bölgenin KENDİ hareketi mesafeyi azaltmaz.
	# Her adımda oyuncu konumu sabit tutulup yalnız wind.step çağrılır: d_sonra >= min(d_önce, keep_out).
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var keep := float(lv.get("keep_out", 250.0))
		var sim := WindKit.make(c[0], c[1], 3)
		_cluster(sim, sim.player_pos + Vector2(500, 0))
		WindSystem.cast_twisters(sim, _kind(c[0]), lv)
		for i in sim.zones.count:
			sim.zones.life[i] = 1.0e6
		var bad := 0
		for s in 900:
			# Oyuncu her zaman ilk bölgeye doğru 3 px/adım yürür (içine girer).
			var to := sim.zones.pos[0] - sim.player_pos
			if to.length() > 1.0:
				sim.player_pos += to.normalized() * 3.0
			var before: Array[float] = []
			for i in sim.zones.count:
				before.append(sim.zones.pos[i].distance_to(sim.player_pos))
			WindKit.zone_steps(sim, 1)
			for i in sim.zones.count:
				var after := sim.zones.pos[i].distance_to(sim.player_pos)
				if after < minf(before[i], keep) - 0.05:
					bad += 1
		assert_eq(
			bad,
			0,
			"%s: bölge kendi hareketiyle oyuncuya yaklaşmadı (keep_out %.0f)" % [_label(c), keep]
		)


func test_k8_free_run_with_enemies_keeps_zone_outside_keep_out_every_step() -> void:
	# Gerçek döngü: düşmanlar oyuncuyu çevreler, oyuncu durur; hortum ömrü boyunca keep_out dışında kalır.
	for c in [[&"hortum", 5], [&"tufan", 1]]:
		var lv := _lv(c[0], c[1])
		var keep := float(lv.get("keep_out", 250.0))
		var sim := AccV202.zyfen({c[0]: c[1]}, true, 5)
		for k in 8:
			AccV202.dummy(
				sim, sim.player_pos + Vector2.from_angle(TAU * k / 8.0) * (150.0 + 60.0 * (k % 3))
			)
		var seen := 0
		var worst := 1.0e9
		for _s in 900:
			sim.step(Vector2.ZERO)
			for i in sim.zones.count:
				seen += 1
				worst = minf(worst, sim.zones.pos[i].distance_to(sim.player_pos))
		assert_gt(seen, 0, "%s: bölge oluştu" % _label(c))
		assert_gte(worst, keep - 0.5, "%s: tam döngüde en yakın bölge uzaklığı" % _label(c))


func test_k9_beyond_max_dist_zone_does_not_turn_back_to_the_player() -> void:
	# Eski kural kalktı: oyuncudan max_dist'ten uzak bölge oyuncuya DÖNMEZ (hedefi oyuncu olmaz, mesafe azalmaz).
	for c in CASES:
		var lv := _lv(c[0], c[1])
		var sim := WindKit.make(&"", 1, 2)
		WindSystem.cast_twisters(sim, _kind(c[0]), lv)
		var max_d := float(lv.get("max_dist", 600.0))
		for i in sim.zones.count:
			sim.zones.life[i] = 1.0e6
			sim.zones.retarget_left[i] = 1.0e9
			sim.zones.pos[i] = sim.player_pos + Vector2(max_d + 150.0, 0)
			sim.zones.target[i] = sim.player_pos + Vector2(max_d + 450.0, 0)
		var d0 := sim.zones.pos[0].distance_to(sim.player_pos)
		WindKit.zone_steps(sim, 120)
		for i in sim.zones.count:
			assert_ne(
				sim.zones.target[i], sim.player_pos, "%s: hedef oyuncuya çevrilmedi" % _label(c)
			)
			assert_gte(
				sim.zones.pos[i].distance_to(sim.player_pos),
				d0 - EPS,
				"%s: max_dist ötesinde oyuncuya doğru dönmedi" % _label(c)
			)
