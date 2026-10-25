extends GutTest
## Kabul (v2.0.2 K, E): evrim kartı Zyfen'de var / Gunslinger'da yok (plan test stratejisi). Zyfen'in 4 evrimi aktifi sv5 +
## ilgili ortak/özel pasifi >= sv1 ister; kart seviye atlamada ilk kart olarak çıkar, seçilince ham aktifin yerini alır.

const PAIRS := {
	"ay_oragi": ["bolunen_kesik", "agir_kursun"],
	"kasirga_patlamasi": ["nefes_dalgasi", "hizli_doldurma"],
	"gogun_mizragi": ["delen_ruzgar", "hizli_parmak"],
	"tufan": ["hortum", "furtina_gozu"],
}


func _sim_with(character: StringName, active: String, active_lv: int, passive: String) -> GameSim:
	var sim := SimKit.make(4, {"character": character, "data_kind": "real"})
	SimKit.godmode(sim)
	sim.debug_grant(StringName(active), active_lv)
	if passive != "":
		sim.debug_grant(StringName(passive), 1)
	return sim


func test_e1_each_zyfen_evolution_is_offered_when_requirements_are_met() -> void:
	if V202Slice.require(self, "E"):
		return
	for evo in PAIRS:
		var sim := _sim_with(&"zyfen", PAIRS[evo][0], 5, PAIRS[evo][1])
		assert_true(SimKit.level_up_with(sim, sim.xp_to_next), "%s: seviye atlandı" % evo)
		var cards := sim.pending_choices()
		var k := SimKit.card_index(sim, StringName(evo))
		assert_gte(k, 0, "%s kartı teklifte" % evo)
		assert_eq(k, cards.size() - 1, "%s kartı son kart (mevcut v1.1 kuralı)" % evo)
		assert_eq(cards[k].kind, Choice.KIND_EVOLUTION)
		assert_eq(
			cards[k].title, sim.data.get_skill(StringName(evo)).name_for(&"zyfen"), "kart başlığı"
		)
		assert_gt(cards[k].desc.length(), 0, "kart açıklaması")


func test_e2_choosing_the_evolution_replaces_the_active_and_logs_it() -> void:
	if V202Slice.require(self, "E"):
		return
	for evo in PAIRS:
		var sim := _sim_with(&"zyfen", PAIRS[evo][0], 5, PAIRS[evo][1])
		SimKit.level_up_with(sim, sim.xp_to_next)
		assert_true(sim.choose(SimKit.card_index(sim, StringName(evo))))
		assert_eq(sim.loadout.level_of(StringName(evo)), 1, "%s sahip" % evo)
		assert_true(sim.evolved_log.has(StringName(evo)), "%s kayıtta" % evo)
		assert_eq(
			sim.loadout.level_of(StringName(PAIRS[evo][0])), 0, "%s ham aktif yerini bıraktı" % evo
		)
		assert_eq(sim.state, GameSim.State.RUNNING)


func test_e3_evolution_needs_the_active_at_level_5_and_the_passive() -> void:
	if V202Slice.require(self, "E"):
		return
	for evo in PAIRS:
		var low := _sim_with(&"zyfen", PAIRS[evo][0], 4, PAIRS[evo][1])
		assert_eq(low.loadout.evolution_ready(), &"", "%s: aktif sv4 yetmez" % evo)
		var nopass := _sim_with(&"zyfen", PAIRS[evo][0], 5, "")
		assert_eq(nopass.loadout.evolution_ready(), &"", "%s: pasif yoksa olmaz" % evo)
		var ok := _sim_with(&"zyfen", PAIRS[evo][0], 5, PAIRS[evo][1])
		assert_eq(ok.loadout.evolution_ready(), StringName(evo), "%s hazır" % evo)


func test_e4_zyfen_evolution_cards_never_appear_for_gunslinger_even_with_the_same_items() -> void:
	if V202Slice.require(self, "E"):
		return
	for evo in PAIRS:
		var g := _sim_with(&"gunslinger", PAIRS[evo][0], 5, PAIRS[evo][1])
		assert_eq(g.loadout.evolution_ready(), &"", "%s Gunslinger'da hazır sayılmaz" % evo)
		SimKit.level_up_with(g, g.xp_to_next)
		for c in g.pending_choices():
			assert_ne(c.kind, Choice.KIND_EVOLUTION, "%s: Gunslinger'a evrim kartı yok" % evo)
			assert_ne(c.skill_id, StringName(evo))


func test_e5_gunslinger_keeps_its_own_four_evolutions() -> void:
	if V202Slice.require(self, "E"):
		return
	var pairs := {
		"gurleyen_yelpaze": ["yelpaze_atis", "hizli_parmak"],
		"zincirleme_patlama": ["seken_mermi", "barut_kesesi"],
		"kiyamet_mermisi": ["son_mermi_patlar", ""],
		"mermi_firtinasi": ["doldurma_sacilmasi", ""],
	}
	var data := GameData.load_default()
	for evo in pairs:
		var req: Dictionary = data.get_skill(StringName(evo)).requires
		var sim := _sim_with(&"gunslinger", String(req["active"]), 5, String(req["passive"]))
		assert_eq(sim.loadout.evolution_ready(), StringName(evo), "%s Gunslinger'da hazır" % evo)
		var z := _sim_with(&"zyfen", String(req["active"]), 5, String(req["passive"]))
		assert_eq(z.loadout.evolution_ready(), &"", "%s Zyfen'de hazır değil" % evo)


func test_e6_evolved_zyfen_sim_runs_600_steps_without_invariant_violations() -> void:
	if V202Slice.require(self, "E"):
		return
	var sim := AccV202.zyfen(
		{"furtina_gozu": 3, "agir_kursun": 3, "hizli_doldurma": 3, "hizli_parmak": 3}, false, 9
	)
	for evo in PAIRS:
		sim.debug_grant(StringName(evo))
	sim.debug_fill(&"curumus_piyade", 120, 380.0)
	for k in 600:
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
		sim.step(Vector2(1, 0.3) if k % 200 < 100 else Vector2(-1, -0.3))
	assert_eq(Array(sim.check_invariants()), [], "sim değişmezleri")
	assert_ne(sim.state, GameSim.State.LOST, "ölmedi (ölümsüz)")
