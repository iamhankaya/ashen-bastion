extends GutTest
## Sözleşme: sınıf/yöntem/sinyal imzaları. DEĞİŞMEMESİ GEREKEN noktalar (yalnız sona eklenebilir).

const N := TYPE_NIL
const I := TYPE_INT
const F := TYPE_FLOAT
const B := TYPE_BOOL
const V := TYPE_VECTOR2
const D := TYPE_DICTIONARY
const O := TYPE_OBJECT
const A := TYPE_ARRAY
const S := TYPE_STRING
const SN := TYPE_STRING_NAME
const PI := TYPE_PACKED_INT32_ARRAY
const PS := TYPE_PACKED_STRING_ARRAY

# sınıf -> {yöntem: [argüman adları, dönüş türü]}
const METHODS := {
	"GameSim":
	{
		"_init": ["p_seed,character_id,opts", O],
		"step": ["move", N],
		"pending_choices": ["", A],
		"choose": ["index", B],
		"spawn_projectile": ["p,v,dmg,o", I],
		"explode": ["pos,radius,dmg,source", N],
		"hitscan": ["origin,dir,range_px,dmg", I],
		"damage_enemy": ["id,amount,kind", N],
		"pick_highest_hp": ["from,range_px", I],
		"state_hash": ["", I],
		"check_invariants": ["", PS],
		"alive_ids": ["", PI],
		"debug_grant": ["skill_id,lvl", N],
		"debug_spawn": ["type_id,pos", I],
		"debug_fill": ["type_id,n,ring_radius", I],
		"debug_set_time": ["t", N],
		"debug_add_xp": ["n", N],
		"debug_force_choices": ["ids", N],
		"take_forced_choices": ["", A],
		"log_event": ["type,fields", N],
	},
	"Magazine":
	{
		"can_fire": ["", B],
		"consume": ["", D],
		"refund": ["n", N],
		"tick": ["dt,stats", N],
		"start_reload": ["stats", N],
		"set_cap": ["new_cap", N],
		"reset_cycle_flags": ["", N],
	},
	"Loadout":
	{
		"_init": ["p_data", O],
		"level_of": ["skill_id", I],
		"actives": ["", A],
		"passives": ["", A],
		"add_or_upgrade": ["skill_id", N],
		"evolution_ready": ["", SN],
		"apply_evolution": ["evo_id", N],
		"roll_choices": ["rng", A],
	},
	"StatBlock": {"rebuild": ["loadout,data", N]},
	"SkillBehavior":
	{
		"setup": ["api,def,level", N],
		"modify_shot": ["ctx", N],
		"on_last_bullet": ["ctx", N],
		"on_reload_start": ["", N],
		"on_reload_tick": ["dt", N],
		"on_reload_end": ["", N],
		"on_kill": ["enemy_id,pos", N],
		"on_hit": ["enemy_id,proj_id", N],
		"tick": ["dt", N],
	},
	"SpatialHash":
	{
		"_init": ["p_cell", O],
		"clear": ["", N],
		"insert": ["id,pos", N],
		"query_circle": ["center,radius,out", N],
	},
	"EnemyPool":
	{
		"spawn": ["type_id,p,hp_mult,contact_mult,speed_mult", I],
		"kill": ["id", N],
		"is_alive": ["id", B],
		"radius_of": ["id", F],
		"alive_ids": ["", PI],
	},
	"ProjectilePool":
	{
		"spawn": ["p,v,damage,o", I],
		"has_hit": ["pid,enemy_id", B],
		"mark_hit": ["pid,enemy_id", N],
	},
	"GemPool": {"drop": ["p,v", N], "total_value": ["", I]},
	"Targeting": {"pick": ["gun,from,attack_range,enemies,grid,other_target", I]},
	"XpCurve": {"need": ["n", I], "cumulative": ["level", I]},
	"Difficulty":
	{
		"enemy_hp_mult": ["t", F],
		"enemy_dmg_mult": ["t", F],
		"enemy_speed_mult": ["t", F],
		"alive_cap": ["t", I],
	},
	"DamageSystem":
	{
		"after_armor": ["raw,armor", F],
		"damage_enemy": ["sim,id,amount,kind", N],
		"contact_tick": ["sim,dt", F],
	},
	"PlayerRig": {"muzzle_world": ["gun,player_pos,aim_angle,facing_left,rig", V]},
	"SpawnDirector": {"step": ["sim", N], "skip_to": ["t", N]},
	"EnemyAI": {"step": ["sim", N]},
	"MapSim": {"obstacles_near": ["center", A]},
	"MusicPlan": {"track_for": ["time,flags", SN]},
	"Sfx": {"play": ["id,opts", N]},
	"GameData":
	{
		"get_character": ["id", O],
		"get_skill": ["id", O],
		"get_enemy": ["id", O],
		"skills_of_kind": ["kind", A],
		"validate": ["registry,complete", PS],
	},
}

const SIGNALS := {
	"SimBus":
	{
		"magazine_changed": "count,cap",
		"reload_started": "duration",
		"reload_finished": "",
		"shot_fired": "gun,origin,dir",
		"last_bullet_fired": "origin",
		"dry_fire": "gun",
		"enemy_killed": "type_id,pos",
		"gem_collected": "value",
		"player_damaged": "amount,hp",
		"level_up": "level",
		"choice_made": "skill_id",
		"evolution_gained": "evo_id",
		"boss_warning": "kind",
		"boss_spawned": "type_id",
		"explosion": "pos,radius",
		"run_ended": "won,stats",
	},
	"Magazine":
	{
		"changed": "count,cap",
		"reload_started": "duration",
		"reload_finished": "",
	},
}


func _script_of(cls: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return load(c["path"])
	return null


func test_class_names_are_registered() -> void:
	for cls in METHODS.keys():
		assert_not_null(_script_of(cls), "%s global class olarak kayıtlı değil" % cls)
	for cls in [
		"SimBus",
		"SimEvents",
		"Choice",
		"ShotContext",
		"SkillState",
		"SkillDef",
		"EnemyDef",
		"CharacterDef",
		"Stub",
		"SkillRegistry",
		"ZonePool",
		"AudioDirector"
	]:
		assert_not_null(_script_of(cls), "%s global class olarak kayıtlı değil" % cls)


func test_method_signatures() -> void:
	for cls in METHODS.keys():
		var sc := _script_of(cls)
		if sc == null:
			continue
		for m in METHODS[cls].keys():
			var want_args: String = METHODS[cls][m][0]
			var want_ret: int = METHODS[cls][m][1]
			assert_eq(KitDev.arg_names(sc, m), want_args, "%s.%s argümanları" % [cls, m])
			assert_eq(KitDev.return_type(sc, m), want_ret, "%s.%s dönüş türü" % [cls, m])


func test_signal_signatures() -> void:
	for cls in SIGNALS.keys():
		var sc := _script_of(cls)
		for s in SIGNALS[cls].keys():
			assert_eq(KitDev.has_signal_args(sc, s), SIGNALS[cls][s], "%s.%s sinyali" % [cls, s])


func test_sim_bus_has_exactly_the_contract_signals() -> void:
	assert_eq(SimBus.new().get_script().get_script_signal_list().size(), 16)


func test_constants_and_limits() -> void:
	assert_almost_eq(GameSim.STEP, 1.0 / 60.0, 1e-9)
	assert_eq(GameSim.State.RUNNING, 0)
	assert_eq(GameSim.State.LEVEL_UP, 1)
	assert_eq(GameSim.State.WON, 2)
	assert_eq(GameSim.State.LOST, 3)
	assert_eq(EnemyPool.CAP, 400)
	assert_eq(ProjectilePool.CAP, 600)
	assert_eq(ProjectilePool.HIT_SLOTS, 12)
	assert_eq(GemPool.CAP, 300)
	assert_eq(ZonePool.CAP, 64)
	assert_eq(Loadout.ACTIVE_SLOTS, 6)
	assert_eq(Loadout.PASSIVE_SLOTS, 6)
	assert_eq(SpatialHash.new().cell, 96.0)


func test_projectile_flags_are_distinct_bits() -> void:
	var f := [
		ProjectilePool.FLAG_EXPLODES,
		ProjectilePool.FLAG_EXPLODE_ON_EXPIRE,
		ProjectilePool.FLAG_EXPLODE_ON_BOUNCE,
		ProjectilePool.FLAG_RICOCHET,
		ProjectilePool.FLAG_RADIAL,
	]
	var all := 0
	for x in f:
		assert_eq(all & x, 0, "bayrak çakışması")
		all |= x
		assert_eq(x & (x - 1), 0, "tek bit olmalı")


func test_data_shape_of_value_classes() -> void:
	var c := Choice.new()
	for p in ["kind", "skill_id", "from_level", "to_level", "title", "desc", "icon"]:
		assert_true(p in c, "Choice.%s" % p)
	assert_eq(Choice.KIND_UPGRADE, &"upgrade")
	assert_eq(Choice.KIND_NEW, &"new")
	assert_eq(Choice.KIND_EVOLUTION, &"evolution")
	assert_eq(Choice.KIND_HEAL, &"heal")
	var sc := ShotContext.new()
	for p in [
		"gun",
		"index_in_mag",
		"is_last",
		"origin",
		"dir",
		"damage",
		"pierce",
		"bounces",
		"flags",
		"ex_radius",
		"ex_dmg",
		"push",
		"tags"
	]:
		assert_true(p in sc, "ShotContext.%s" % p)
	var st := StatBlock.new()
	for p in [
		"bullet_dmg_mult",
		"fire_rate_mult",
		"reload_time_mult",
		"mag_add",
		"area_mult",
		"explosion_dmg_mult",
		"move_speed_mult",
		"max_hp_add",
		"regen",
		"pickup_mult",
		"range_mult"
	]:
		assert_true(p in st, "StatBlock.%s" % p)
	assert_eq(st.bullet_dmg_mult, 1.0)
	assert_eq(st.mag_add, 0)
	var m := Magazine.new()
	for p in ["count", "cap", "reloading", "reload_left", "reload_total", "refund_used"]:
		assert_true(p in m, "Magazine.%s" % p)
	assert_eq(m.cap, 6)


func test_pool_id_encoding() -> void:
	var id := EnemyPool.make_id(3, 17)
	assert_eq(id, (3 << 16) | 17)
	assert_eq(EnemyPool.index_of(id), 17)
	assert_eq(EnemyPool.gen_of(id), 3)
	# nesil 16 bit: 65536 -> 0'a döner
	assert_eq(EnemyPool.make_id(65536, 5), EnemyPool.make_id(0, 5))


func test_game_sim_public_state_variables() -> void:
	var sim := GameSim.new(1, &"gunslinger")
	for p in [
		"bus",
		"state",
		"time",
		"step_count",
		"level",
		"xp",
		"xp_to_next",
		"pending_levels",
		"hp",
		"max_hp",
		"kills",
		"player_pos",
		"magazine",
		"loadout",
		"enemies",
		"projectiles",
		"gems",
		"zones",
		"stats",
		"evolved_log",
		"event_log",
		"work",
		"spawn_dropped",
		"rng_spawn",
		"rng_choice",
		"rng_map",
		"rng_combat"
	]:
		assert_true(p in sim, "GameSim.%s" % p)
