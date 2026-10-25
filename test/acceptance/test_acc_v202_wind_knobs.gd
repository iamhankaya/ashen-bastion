extends GutTest
## Kabul (v2.0.2 K, Z/E): Hortum/Tufan davranış alanları JSON'dan okunur (plan Arayüzler/1: "Yeni davranış alanları (Hortum/Tufan,
## JSON'da): speed, target_mode: "cluster", retarget_every, max_dist, boss_mult" ve Arayüzler/5 başlangıç değerleri: Hortum 90 / 1,0 / 600,
## Tufan 110 / 1,5 / 700). D fazı dengeyi bu düğmelerle ayarlar; JSON'da yoksa ya da okunmuyorsa ayar yapılamaz.
## Gerçek data/ kopyalanır, JSON değiştirilir, GameData.load_dir ile yüklenir (paylaşılan önbelleğe yazılmaz; after_all siler).

const BASE_START := {
	"hortum": {"speed": 90.0, "retarget_every": 1.0, "max_dist": 600.0},
	"tufan": {"speed": 110.0, "retarget_every": 1.5, "max_dist": 700.0},
}
var _label: int = 0


func after_all() -> void:
	SimKit.remove_tmp()


func _data_with(skill_id: String, patch: Dictionary) -> GameData:
	_label += 1
	var dir := SimKit.copy_data("res://data", "knobs%d" % _label)
	var path := dir.path_join("skills/%s.json" % skill_id)
	var j: Dictionary = SimKit.read_json(path)
	for lv in j["levels"]:
		(lv as Dictionary).merge(patch, true)
	SimKit.write_json(path, j)
	return GameData.load_dir(dir)


func _sim(skill_id: String, patch: Dictionary, level: int = 1) -> GameSim:
	var sim := SimKit.make(
		1, {"character": &"zyfen", "log_events": true, "data": _data_with(skill_id, patch)}
	)
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	if skill_id == "tufan":
		sim.debug_grant(&"tufan")
	else:
		sim.debug_grant(StringName(skill_id), level)
	SimKit.godmode(sim)
	return sim


func test_z1_plan_start_values_are_written_in_hortum_and_tufan_json() -> void:
	if V202Slice.require(self, "Z"):
		return
	var data := GameData.load_default()
	var missing: Array[String] = []
	for id in BASE_START:
		var def := data.get_skill(StringName(id))
		for lv in def.levels:
			for k in BASE_START[id]:
				if not lv.has(k):
					missing.append("%s.%s" % [id, k])
				elif absf(float(lv[k]) - float(BASE_START[id][k])) > 0.001:
					missing.append("%s.%s=%s (plan %s)" % [id, k, lv[k], BASE_START[id][k]])
			if str(lv.get("target_mode", "")) != "cluster":
				missing.append("%s.target_mode" % id)
	var uniq := {}
	for m in missing:
		uniq[m] = true
	assert_eq(
		uniq.keys(),
		[],
		"plan Arayüzler/1 + /5: JSON'da bulunmayan ya da başlangıç değerinden farklı alanlar"
	)


func test_z2_json_speed_zero_freezes_the_twister() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := _sim("hortum", {"speed": 0.0})
	AccV202.dummy(sim, Vector2(400, 0))
	SimKit.run_until(sim, func() -> bool: return sim.zones.count > 0, 700)
	var p0 := sim.zones.pos[0]
	AccV202.steps(sim, 90)
	assert_eq(sim.zones.pos[0], p0, "speed 0: bölge yerinde")


func test_z3_json_retarget_every_changes_the_number_of_draws() -> void:
	if V202Slice.require(self, "Z"):
		return
	var counts := []
	for every in [1.0, 0.25]:
		var sim := _sim("hortum", {"retarget_every": every})
		AccV202.dummy(sim, Vector2(400, 0))
		SimKit.run_until(sim, func() -> bool: return sim.zones.count > 0, 700)
		var rep := RandomNumberGenerator.new()
		rep.state = sim.rng_combat.state
		AccV202.steps(sim, 150)
		var used := -1
		for k in range(0, 30):
			var r2 := RandomNumberGenerator.new()
			r2.state = rep.state
			for _j in k:
				r2.randf()
			if r2.state == sim.rng_combat.state:
				used = k
				break
		counts.append(used)
	assert_gt(
		counts[1], counts[0] + 3, "retarget_every 0,25 sn çok daha sık çeker: %s" % str(counts)
	)


func test_z4_json_max_dist_pulls_the_twister_back_to_the_player() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := _sim("hortum", {"max_dist": 120.0, "speed": 400.0})
	AccV202.dummy(sim, Vector2(500, 0))
	SimKit.run_until(sim, func() -> bool: return sim.zones.count > 0, 700)
	var farthest := 0.0
	for _k in 120:
		sim.step(Vector2.ZERO)
		if sim.zones.count > 0:
			farthest = maxf(farthest, sim.zones.pos[0].distance_to(sim.player_pos))
	assert_lt(
		farthest,
		250.0 + 120.0 + 80.0,
		"max_dist 120: hortum oyuncudan çok uzaklaşmaz (%.0f)" % farthest
	)


func test_z5_json_boss_mult_scales_the_tick_damage_on_elites() -> void:
	if V202Slice.require(self, "Z"):
		return
	var out := []
	for mult in [1.0, 0.5]:
		var sim := _sim("hortum", {"boss_mult": mult})
		AccV202.dummy(sim, Vector2(400, 0))
		SimKit.run_until(sim, func() -> bool: return sim.zones.count > 0, 700)
		sim.zones.speed[0] = 0.0
		var elite := AccV202.dummy(sim, sim.zones.pos[0] + Vector2(40, 0), &"elit_piyade")
		AccV202.steps(sim, 40)
		var ev := AccV202.damages(sim, &"dot", elite)
		assert_gt(ev.size(), 0)
		out.append(float(ev[0]["amount"]))
	assert_almost_eq(
		out[1], out[0] * 0.5, 0.05, "boss_mult 0,5 elit tik hasarını yarıya indirir: %s" % str(out)
	)
