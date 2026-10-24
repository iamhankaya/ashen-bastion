extends GutTest
## S1 sözleşmesi: Zyfen sim'i (no-op gövdelerle) çalışır; karakter yokken sim çökmez; bütçeler.

const ZYFEN_SKILLS: Array[StringName] = [
	&"ruzgar_kesigi",
	&"hava_bicaklari",
	&"girdap",
	&"hortum",
	&"delen_ruzgar",
	&"bolunen_kesik",
	&"hava_cebi",
	&"nefes_dalgasi",
	&"ay_oragi",
	&"kasirga_patlamasi",
	&"gogun_mizragi",
	&"tufan",
]


func test_zyfen_sim_runs_600_steps_without_errors() -> void:
	var sim := SimKit.make(7, {"data_kind": "real", "character": &"zyfen"})
	for k in 6:
		SimKit.add_enemy(sim, &"curumus_piyade", Vector2.from_angle(float(k)) * 260.0)
	SimKit.run(sim, 600, Vector2.RIGHT)
	assert_eq(sim.step_count, 600)
	assert_eq(sim.check_invariants().size(), 0, str(sim.check_invariants()))
	assert_eq(sim.max_hp, 85.0)
	assert_eq(sim.magazine.cap, 8)


func test_zyfen_same_seed_two_runs_same_hash() -> void:
	var a := SimKit.make(11, {"data_kind": "real", "character": &"zyfen"})
	var b := SimKit.make(11, {"data_kind": "real", "character": &"zyfen"})
	for k in 5:
		SimKit.add_enemy(a, &"curumus_piyade", Vector2.from_angle(float(k)) * 200.0)
		SimKit.add_enemy(b, &"curumus_piyade", Vector2.from_angle(float(k)) * 200.0)
	SimKit.run(a, 600, Vector2.RIGHT)
	SimKit.run(b, 600, Vector2.RIGHT)
	assert_eq(a.state_hash(), b.state_hash())


func test_zyfen_level_up_offers_cards_of_its_pool() -> void:
	var sim := SimKit.make(3, {"data_kind": "real", "character": &"zyfen"})
	assert_true(SimKit.level_up_with(sim, 500))
	var cards := sim.pending_choices()
	assert_gt(cards.size(), 0)
	for c in cards:
		assert_true(sim.data.get_skill(c.skill_id).available_to(&"zyfen"), c.skill_id)


func test_all_zyfen_behaviors_registered_and_noop() -> void:
	var data := GameData.load_default()
	for id in ZYFEN_SKILLS:
		assert_true(SkillRegistry.BEHAVIORS.has(id), "%s kayıtlı" % id)
		var def := data.get_skill(id)
		assert_not_null(def, id)
		assert_eq(def.pool, &"zyfen", id)
		assert_eq(def.behavior, id)
	assert_eq(data.get_skill(&"furtina_gozu").kind, SkillDef.KIND_PASSIVE)
	assert_eq(data.get_skill(&"furtina_gozu").pool, &"zyfen")


func test_sim_without_character_does_not_crash() -> void:
	var sim := GameSim.new(1, &"yok_boyle", {"data": GameData.load_default()})
	assert_null(sim.character)
	assert_not_null(sim.loadout)
	assert_eq(sim.loadout.character_id, &"", "karaktersiz: filtresiz")
	sim.step(Vector2.RIGHT)
	assert_eq(sim.step_count, 0, "karaktersiz sim adım atmaz")
	assert_eq(sim.check_invariants().size(), 0)


func test_loadout_gets_the_character_id() -> void:
	assert_eq(SimKit.make(1, {}).loadout.character_id, &"gunslinger")
	assert_eq(SimKit.make(1, {"character": &"zyfen"}).loadout.character_id, &"zyfen")


func test_character_list_has_zyfen_alongside_the_old_ones() -> void:
	var ids := GameData.load_default().character_ids
	assert_true(ids.has(&"gunslinger") and ids.has(&"zyfen"))
