extends GutTest
## Doğrulama (T20261023-64): tasarım belgesi anti-hedefleri ve şarjör ritmi görünürlüğü.
##  - "ölümsüzlük yok": hiçbir mekanik dokunulmazlık/can çalma vermez; geç oyunda yakın temas hâlâ öldürür.
##  - "10. dakikadan sonra tehdit kalmaması" (mekanik tarafı): çarpanlar ve eşzamanlı sınır 10→20. dk büyür.
##  - "kalabalıkta takılma" için kalabalık sahne testleri: test_ver_crowd_perf.gd.
##  - şarjör ritmi HUD'da görünür; ritim etiketli beceriler şarjörle etkileşir.
## Oyuncu dengesi ölçümleri (bot koşuları) testte değil raporda: test/helpers/balance_observe.gd.

const TIMES: Array[float] = [0.0, 300.0, 600.0, 900.0, 1100.0]


func _skill_data() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/skills"):
		if f.ends_with(".json"):
			var d: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("res://data/skills/" + f)
			)
			if d is Dictionary:
				out[String(d["id"])] = d
	return out


func _ring_survival(start: float, build: Array) -> float:
	var sim := SimKit.make(99, {"data_kind": "real", "start_time": start, "log_events": false})
	for g in build:
		sim.debug_grant(g[0], g[1])
	sim.hp = sim.max_hp
	sim.debug_fill(&"curumus_piyade", 60, 45.0)  # oyuncuya değen halka
	var rng := Bots.make_rng(99)
	var steps := 0
	while steps < 60 * 60 and sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
		if sim.state == GameSim.State.LEVEL_UP:
			Bots.choose(sim, rng)
			continue
		sim.step(Vector2.ZERO)
		steps += 1
	assert_eq(sim.state, GameSim.State.LOST, "start=%d: yakın temas halkası öldürür" % int(start))
	return sim.time - start


func test_no_invulnerability_or_lifesteal_mechanics_exist_in_data() -> void:
	var worst_regen := 0.0
	var worst_hp := 0.0
	for id in _skill_data():
		var d: Dictionary = _skill_data()[id]
		for lv in d.get("levels", []):
			for k in (lv as Dictionary).keys():
				assert_false(
					String(k) in ["invulnerable", "lifesteal", "heal_on_kill", "shield", "dodge"],
					"%s: dokunulmazlık/can çalma anahtarı '%s' yok" % [id, k]
				)
		if d["kind"] == "passive":
			var last: Dictionary = d["levels"][d["levels"].size() - 1]
			worst_regen += float(last.get("regen", 0.0))
			worst_hp += float(last.get("max_hp_add", 0.0))
	# yenilenme/can veren tüm pasifler toplamı (yuva sınırı 6 pasif; en iyi durumda hepsi bu üçlüde): üst sınır
	var sim := SimKit.make(5, {"data_kind": "real"})
	sim.debug_grant(&"saglam_yelek", 5)
	assert_almost_eq(sim.stats.regen, worst_regen, 0.0001, "yenilenme kaynağı yalnız saglam_yelek")
	assert_lte(sim.stats.regen, 2.0, "azami yenilenme küçük (can/sn)")
	assert_lte(sim.max_hp, sim.character.max_hp + worst_hp + 0.01, "azami can sınırlı")
	assert_lte(sim.max_hp, 250.0)


func test_late_contact_damage_dwarfs_maximum_regeneration() -> void:
	# 20. dakikada tek temas tick'i (4 düşman) azami yenilenmenin ~60 katı: yenilenme ölümsüzlük vermez.
	var sim := SimKit.make(6, {"data_kind": "real", "start_time": 1200.0})
	sim.debug_grant(&"saglam_yelek", 5)
	for i in 4:
		SimKit.add_enemy(sim, &"curumus_piyade", Vector2(20, 0))
	var before := sim.hp
	sim.step(Vector2.ZERO)
	var tick := before - sim.hp
	var regen_per_tick := sim.stats.regen * DamageSystem.CONTACT_INTERVAL
	assert_gt(tick, 30.0, "4 piyade teması tek tick'te ≥30 can")
	assert_gt(tick, regen_per_tick * 30.0, "temas tick'i yenilenmeden çok büyük")


func test_starting_loadout_dies_in_a_touching_ring_at_every_stage_of_the_run() -> void:
	var prev := 1.0e9
	for t in TIMES:
		var survived := _ring_survival(t, [])
		assert_lt(survived, 10.0, "t=%d: halkada 10 sn dayanamaz (%.1f)" % [int(t), survived])
		assert_lte(survived, prev + 0.01, "t=%d: hayatta kalma süresi artmaz" % int(t))
		prev = survived


func test_max_defence_build_still_dies_in_a_late_touching_ring_of_knights() -> void:
	var sim := SimKit.make(98, {"data_kind": "real", "start_time": 1100.0, "log_events": false})
	sim.debug_grant(&"saglam_yelek", 5)  # +75 can, 1,25/sn
	sim.hp = sim.max_hp
	sim.debug_fill(&"sovalye_hayaleti", 80, 60.0)
	var steps := 0
	while steps < 60 * 30 and sim.state == GameSim.State.RUNNING:
		sim.step(Vector2.ZERO)
		steps += 1
	assert_eq(sim.state, GameSim.State.LOST, "savunma azami olsa da kuşatma öldürür")


func test_threat_curves_keep_rising_after_minute_10_up_to_minute_20() -> void:
	for m in range(10, 20):
		var t0 := float(m) * 60.0
		var t1 := float(m + 1) * 60.0
		assert_gt(
			Difficulty.enemy_hp_mult(t1),
			Difficulty.enemy_hp_mult(t0),
			"hp çarpanı %d→%d" % [m, m + 1]
		)
		assert_gt(Difficulty.enemy_dmg_mult(t1), Difficulty.enemy_dmg_mult(t0), "hasar çarpanı")
		assert_gte(Difficulty.enemy_speed_mult(t1), Difficulty.enemy_speed_mult(t0), "hız çarpanı")
		assert_gte(Difficulty.alive_cap(t1), Difficulty.alive_cap(t0), "eşzamanlı sınır")
	assert_gt(Difficulty.alive_cap(1200.0), 300, "20. dk'da 300+ düşmana izin var")
	assert_gt(Difficulty.enemy_hp_mult(1200.0), Difficulty.enemy_hp_mult(600.0) * 1.5)


func test_boss_cadence_gives_a_threat_every_five_minutes_until_the_lord() -> void:
	var rows: Array = (SimKit.data_for("real").waves["rows"] as Array).filter(
		func(r: Dictionary) -> bool: return r["kind"] == "boss"
	)
	var ats: Array = rows.map(func(r: Dictionary) -> float: return float(r["at"]))
	ats.sort()
	assert_eq(ats, [300.0, 600.0, 900.0, 1200.0], "5/10/15. dk elit, 20. dk Lord")


func test_enemy_pool_pressure_is_reachable_by_the_director_late_in_the_run() -> void:
	# Doğuş yöneticisi 15–20. dk'da gerçekten 300+ eşzamanlı düşmana ulaşabilir (oyuncu öldürmezse).
	var sim := SimKit.make(97, {"data_kind": "real", "start_time": 1100.0, "log_events": false})
	SimKit.godmode(sim)
	sim.gun_damage = 0.0  # silahsız oyuncu: doğuş hızı tek başına ölçülür
	var peak := 0
	for i in 60 * 100:
		sim.step(Vector2.ZERO)
		SimKit.godmode(sim)
		peak = maxi(peak, sim.enemies.count)
	assert_gte(peak, 300, "geç oyunda 300+ düşman birikebilir (tepe %d)" % peak)


func test_magazine_drum_in_hud_follows_the_cycle_every_step() -> void:
	var sim := SimKit.make(51, {"data_kind": "real", "log_events": false})
	SimKit.godmode(sim)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.bind(sim)
	SimKit.add_enemy(sim, &"elit_piyade", Vector2(300, 0))
	var saw_full := false
	var saw_last := false
	var saw_reload := false
	var progress_seen: Array[float] = []
	var reload_cycles := 0
	var was_reloading := false
	for i in 60 * 8:
		sim.step(Vector2.ZERO)
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
		SimKit.godmode(sim)
		hud.refresh(GameSim.STEP)
		var d := hud.drum
		assert_eq(d.count, sim.magazine.count, "tambur sayısı = şarjör")
		assert_eq(d.cap, sim.magazine.cap)
		assert_eq(d.reloading, sim.magazine.reloading, "tambur doldurma durumu = şarjör")
		if sim.magazine.count == sim.magazine.cap and not sim.magazine.reloading:
			saw_full = true
		if sim.magazine.count == 1 and not sim.magazine.reloading:
			saw_last = true
			assert_eq(d.describe(), "Şarjör 1 / %d" % d.cap)
		if sim.magazine.reloading:
			saw_reload = true
			assert_eq(d.describe(), "Şarjör dolduruluyor")
			progress_seen.append(d.progress)
		if was_reloading and not sim.magazine.reloading:
			reload_cycles += 1
		was_reloading = sim.magazine.reloading
	assert_true(saw_full and saw_last and saw_reload, "dolu/son mermi/doldurma durumları görüldü")
	assert_gte(reload_cycles, 3, "birden çok doldurma döngüsü")
	assert_gt(progress_seen.max(), 0.9, "doldurma halkası ~%100'e ulaşır")
	assert_lt(progress_seen.min(), 0.15, "doldurma halkası baştan başlar")
	for k in range(1, progress_seen.size()):
		if progress_seen[k] < progress_seen[k - 1] - 0.5:
			continue  # yeni döngü
		assert_gte(progress_seen[k] + 0.0001, progress_seen[k - 1], "ilerleme monoton")


func test_rhythm_tags_cover_active_skills_that_react_to_the_magazine() -> void:
	var data := SimKit.data_for("real")
	var rhythm_actives: Array[StringName] = []
	var rhythm_all := 0
	for id in data.skill_ids:
		var def := data.get_skill(id)
		if "rhythm" in def.tags and def.available_to(&"gunslinger"):  # v2.0.2: Zyfen'in sayımı K fazında
			rhythm_all += 1
			if def.kind == SkillDef.KIND_ACTIVE:
				rhythm_actives.append(id)
	assert_gte(rhythm_actives.size(), 2, "en az 2 aktif beceri ritim etiketli")
	assert_eq(rhythm_all, 8, "ritim etiketli kayıt: 3 aktif + 2 pasif + 3 evrim (rapor '7' diyor)")


func _rhythm_run(skill_id: StringName) -> GameSim:
	var sim := SimKit.make(61, {"data_kind": "real", "log_events": true})
	sim.debug_grant(skill_id, 3)
	SimKit.add_enemy(sim, &"elit_piyade", Vector2(350, 0))
	SimKit.godmode(sim)
	SimKit.run(sim, 60 * 6)
	return sim


func test_doldurma_sacilmasi_fires_exactly_when_a_reload_starts() -> void:
	var sim := _rhythm_run(&"doldurma_sacilmasi")
	var reload_steps: Array = SimKit.events(sim, SimEvents.RELOAD_START).map(
		func(e: Dictionary) -> int: return int(e["step"])
	)
	assert_gte(reload_steps.size(), 3)
	var skill_shots := SimKit.events(sim, SimEvents.SHOT).filter(
		func(e: Dictionary) -> bool: return int(e["gun"]) == -1
	)
	assert_gt(skill_shots.size(), 0, "beceri kurşunları var")
	for e in skill_shots:
		assert_true(
			int(e["step"]) in reload_steps,
			"beceri kurşunu doldurma başlangıcında (adım %d)" % int(e["step"])
		)


func test_son_mermi_patlar_explodes_only_from_the_last_bullet_of_a_magazine() -> void:
	var sim := _rhythm_run(&"son_mermi_patlar")
	var last_shot_steps: Array = (
		SimKit
		. events(sim, SimEvents.SHOT)
		. filter(func(e: Dictionary) -> bool: return bool(e["is_last"]))
		. map(func(e: Dictionary) -> int: return int(e["step"]))
	)
	var explosions := SimKit.events(sim, SimEvents.EXPLOSION)
	assert_gte(last_shot_steps.size(), 3, "birden çok şarjör boşaldı")
	assert_gt(explosions.size(), 0, "son mermi patladı")
	assert_lte(explosions.size(), last_shot_steps.size(), "şarjör başına en çok bir patlama")
	for e in explosions:
		var step := int(e["step"])
		var after_last := last_shot_steps.any(
			func(ls: int) -> bool: return step >= ls and step - ls < 60
		)
		assert_true(after_last, "patlama son kurşundan sonra (adım %d)" % step)
