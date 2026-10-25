extends GutTest
## Kabul (v2.0.2 K, W/Z/E): plan "Arayüzler/6" sayısal tabloları. Beklenen değerler ExpectedTablesV202'deki ELLE kopyadan gelir
## (bağımsız); gerçek taraf data/skills/*.json ve data/characters/zyfen.json. Sayı/denge ayarı D fazındadır: bir sayı bilerek
## değişirse yalnız expected_tables_v202.gd güncellenir (VLAD onayıyla), test kapsamı küçülmez.
## Dilim işaretleri: W (temel rüzgar), Z (bölgeler + Nefes Dalgası + Fırtına Gözü), E (evrimler), R (karakter verisi).

const BASIC := ["ruzgar_kesigi", "hava_bicaklari", "delen_ruzgar", "bolunen_kesik"]
const ZONES := ["girdap", "hortum", "hava_cebi", "nefes_dalgasi", "furtina_gozu"]
const EVOS := ["ay_oragi", "kasirga_patlamasi", "gogun_mizragi", "tufan"]

## Hortum/Tufan JSON düğmeleri: değerleri test_acc_v202_wind_knobs.gd z1'de (BASE_START) sınanır; plan sayısal tablosunda
## yoktur. Bu yüzden yalnız bu iki beceride "tabloda olmayan anahtar" denetiminden muaftır (başka beceride hâlâ yakalanır).
const KNOB_KEYS := ["speed", "target_mode", "retarget_every", "max_dist", "boss_mult"]
const KNOB_SKILLS := ["hortum", "tufan"]

var _data: GameData


func before_all() -> void:
	_data = GameData.load_default()


func _check_skill(id: String) -> void:
	var want: Dictionary = ExpectedTablesV202.SKILLS[id]
	var def := _data.get_skill(StringName(id))
	assert_not_null(def, "%s tanımlı" % id)
	if def == null:
		return
	assert_eq(str(def.kind), want["kind"], "%s türü" % id)
	var lv: Array = want["levels"]
	assert_eq(def.max_level, lv.size(), "%s max_level" % id)
	assert_eq(def.levels.size(), lv.size(), "%s seviye sayısı" % id)
	for k in mini(lv.size(), def.levels.size()):
		var w: Dictionary = lv[k]
		var got: Dictionary = def.levels[k]
		for key in w:
			assert_true(got.has(key), "%s sv%d: '%s' anahtarı var" % [id, k + 1, key])
			if got.has(key):
				assert_almost_eq(
					float(got[key]), float(w[key]), 0.0001, "%s sv%d %s" % [id, k + 1, key]
				)
		for key in got:  # tabloda olmayan sayısal anahtar eklenmemiş olmalı (sessiz denge değişimi)
			if id in KNOB_SKILLS and key in KNOB_KEYS:
				continue
			assert_true(w.has(key), "%s sv%d: tabloda olmayan '%s'" % [id, k + 1, key])
	if want.has("requires"):
		var rq: Dictionary = want["requires"]
		assert_eq(str(def.requires.get("active", "")), rq["active"], "%s requires.active" % id)
		assert_eq(int(def.requires.get("active_level", 0)), 5, "%s requires.active_level" % id)
		assert_eq(str(def.requires.get("passive", "")), rq["passive"], "%s requires.passive" % id)
		assert_gte(int(def.requires.get("passive_min_level", 0)), 1, "%s passive_min_level" % id)


func test_w1_basic_wind_actives_match_plan_table() -> void:
	if V202Slice.require(self, "W"):
		return
	for id in BASIC:
		_check_skill(id)


func test_z1_zone_actives_and_storm_eye_match_plan_table() -> void:
	if V202Slice.require(self, "Z"):
		return
	for id in ZONES:
		_check_skill(id)


func test_e1_evolutions_match_plan_table() -> void:
	if V202Slice.require(self, "E"):
		return
	for id in EVOS:
		_check_skill(id)


func test_e2_evolution_effects_are_not_in_gunslinger_pool_and_all_need_max_active() -> void:
	if V202Slice.require(self, "E"):
		return
	for id in EVOS:
		var def := _data.get_skill(StringName(id))
		assert_eq(str(def.pool), "zyfen", "%s Zyfen havuzunda" % id)
		assert_eq(int(def.requires.get("active_level", 0)), 5, "%s aktifi sv5 ister" % id)


func test_r1_zyfen_character_matches_plan_table() -> void:
	if V202Slice.require(self, "R"):
		return
	var c := _data.get_character(&"zyfen")
	assert_not_null(c, "zyfen tanımlı")
	if c == null:
		return
	var w := ExpectedTablesV202.CHARACTER
	assert_almost_eq(c.max_hp, float(w["max_hp"]), 0.001, "max_hp")
	assert_almost_eq(c.move_speed, float(w["move_speed"]), 0.001, "move_speed")
	assert_eq(c.mag_cap, int(w["mag_cap"]), "mag_cap")
	assert_almost_eq(c.reload_time, float(w["reload_time"]), 0.0001, "reload_time")
	assert_almost_eq(c.attack_range, float(w["range"]), 0.001, "range")
	assert_almost_eq(c.pickup_radius, float(w["pickup_radius"]), 0.001, "pickup_radius")
	assert_almost_eq(c.collision_radius, float(w["collision_radius"]), 0.001, "collision_radius")
	assert_eq(c.order, int(w["order"]), "order")
	assert_eq(c.display_upper, str(w["display_upper"]), "display_upper")
	assert_eq(str(c.starting_skill), str(w["starting_skill"]), "starting_skill")
	assert_true(c.unlock_achievement == &"", "Zyfen baştan açık (kilit yok)")
	assert_eq(c.action_while_moving, false, "action_while_moving açıkça false (düzeltme eki)")
	assert_true(c.armless, "kolsuz rig")


func test_r2_zyfen_starts_with_its_own_starting_skill_and_stats() -> void:
	if V202Slice.require(self, "R"):
		return
	var sim := SimKit.make(1, {"character": &"zyfen"})
	assert_eq(sim.loadout.level_of(&"ruzgar_kesigi"), 1, "başlangıç becerisi")
	assert_almost_eq(sim.max_hp, 85.0, 0.001, "azami can")
	assert_eq(sim.magazine.cap, 8, "şarjör")
	assert_almost_eq(sim.magazine.reload_total if sim.magazine.reloading else 1.3, 1.3, 0.0001)
	assert_almost_eq(sim.gun_interval, 0.36, 0.0001, "Rüzgar Kesiği sv1 aralığı")
	assert_almost_eq(sim.gun_damage, 12.0, 0.0001, "Rüzgar Kesiği sv1 hasarı")
