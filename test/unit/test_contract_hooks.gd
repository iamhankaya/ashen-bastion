extends GutTest
## Sözleşme: 12 beceri kimliği SkillRegistry'de, belgede ve kanca/API/bayrak adları gerçekte var.

const DOC := "res://docs/dev/skill-hooks.md"
const SKILL_IDS: Array[String] = [
	"cift_tabanca",
	"dinamit",
	"doldurma_sacilmasi",
	"gurleyen_yelpaze",
	"keskin_nisan",
	"kiyamet_mermisi",
	"mermi_firtinasi",
	"sarapnel",
	"seken_mermi",
	"son_mermi_patlar",
	"yelpaze_atis",
	"zincirleme_patlama",
]
## Gerçek gövdesi olan davranışlar (uygulama-1). Yeni uygulanan beceri buraya eklenir.
const IMPLEMENTED: Array[String] = [
	"cift_tabanca",
	"dinamit",
	"doldurma_sacilmasi",
	"gurleyen_yelpaze",
	"keskin_nisan",
	"kiyamet_mermisi",
	"mermi_firtinasi",
	"sarapnel",
	"seken_mermi",
	"son_mermi_patlar",
	"yelpaze_atis",
	"zincirleme_patlama",
]
const API_EXTRA: Array[String] = ["magazine", "rng_combat"]


func before_each() -> void:
	Stub.reset()


func _doc() -> String:
	return FileAccess.get_file_as_string(DOC)


func _tokens(cell: String) -> Array[String]:
	var out: Array[String] = []
	for part in cell.split(","):
		var t := part.strip_edges().trim_prefix("`").trim_suffix("`")
		if t != "":
			out.append(t)
	return out


## "Beceri → kanca eşlemesi" tablosu: {id: [kancalar, api, bayraklar, alanlar]}
func _mapping() -> Dictionary:
	var rows := {}
	var in_table := false
	for line in _doc().split("\n"):
		if line.begins_with("| Beceri |"):
			in_table = true
			continue
		if not in_table:
			continue
		if not line.begins_with("|"):
			break
		var cells := line.split("|")
		if cells.size() < 7 or cells[1].strip_edges().begins_with("---"):
			continue
		var id := cells[1].strip_edges().trim_prefix("`").trim_suffix("`")
		rows[id] = [_tokens(cells[2]), _tokens(cells[3]), _tokens(cells[4]), _tokens(cells[5])]
	return rows


func test_all_twelve_skills_registered_in_alphabetical_order() -> void:
	var keys: Array[String] = []
	for k in SkillRegistry.BEHAVIORS.keys():
		keys.append(String(k))
	assert_eq(keys, SKILL_IDS)


func test_every_behavior_derives_from_skill_behavior_and_instantiates() -> void:
	for id in SKILL_IDS:
		var sc: GDScript = SkillRegistry.BEHAVIORS[StringName(id)]
		var inst: Object = sc.new()
		assert_true(inst is SkillBehavior, "%s SkillBehavior'dan türemeli" % id)


func test_doc_mentions_every_skill_id() -> void:
	var doc := _doc()
	for id in SKILL_IDS:
		assert_true(("`%s`" % id) in doc, "%s belgede yok" % id)


func test_doc_mapping_has_exactly_the_twelve_skills() -> void:
	var rows := _mapping()
	var ids: Array[String] = []
	for k in rows.keys():
		ids.append(k)
	ids.sort()
	assert_eq(ids, SKILL_IDS)


func test_mapped_hooks_exist_on_skill_behavior() -> void:
	var methods := {}
	for m in SkillBehavior.new().get_method_list():
		methods[m["name"]] = true
	var rows := _mapping()
	for id in rows.keys():
		for h in rows[id][0]:
			assert_true(methods.has(h), "%s: kanca '%s' SkillBehavior'da yok" % [id, h])


func test_mapped_api_exists_on_game_sim() -> void:
	var sim := GameSim.new(1, &"gunslinger")
	var rows := _mapping()
	for id in rows.keys():
		for a in rows[id][1]:
			var ok := sim.has_method(a) or API_EXTRA.has(a)
			if a in API_EXTRA:
				ok = a in sim
			assert_true(ok, "%s: API '%s' GameSim'de yok" % [id, a])


func test_mapped_flags_exist_on_projectile_pool() -> void:
	var rows := _mapping()
	for id in rows.keys():
		for f in rows[id][2]:
			assert_true(
				ProjectilePool.new().get_script().get_script_constant_map().has("FLAG_" + f),
				"%s: bayrak %s yok" % [id, f]
			)


func test_mapped_fields_exist_on_shot_context() -> void:
	var sc := ShotContext.new()
	var rows := _mapping()
	for id in rows.keys():
		for p in rows[id][3]:
			assert_true(p in sc, "%s: alan %s ShotContext'te yok" % [id, p])


func test_hooks_are_noop_by_default() -> void:
	# Varsayılan kancalar boş: iskelet davranışı çağrılınca iş yapmaz ve Stub'a düşmez.
	var b := SkillBehavior.new()
	b.modify_shot(ShotContext.new())
	b.on_last_bullet(ShotContext.new())
	b.on_reload_start()
	b.on_reload_tick(0.1)
	b.on_reload_end()
	b.on_kill(0, Vector2.ZERO)
	b.on_hit(0, 0)
	b.tick(0.1)
	assert_eq(Stub.calls().size(), 0)


func test_implemented_behaviors_do_not_hit_the_stub() -> void:
	var data := GameData.load_default()
	for id in IMPLEMENTED:
		Stub.reset()
		var b: SkillBehavior = SkillRegistry.BEHAVIORS[StringName(id)].new()
		b.setup(GameSim.new(1, &"gunslinger"), data.get_skill(StringName(id)), 1)
		assert_eq(Stub.calls().size(), 0, id)


func test_no_behavior_source_still_calls_stub_todo() -> void:
	for id in SKILL_IDS:
		var src := FileAccess.get_file_as_string("res://scripts/sim/skills/%s.gd" % id)
		assert_false("Stub.todo" in src, "%s hâlâ iskelet" % id)
