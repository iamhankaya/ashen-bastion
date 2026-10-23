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
const V4 := TYPE_VECTOR4

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
		# v1.1
		"bomb_blast": ["pos,radius,dmg,elite_frac,elite_min", I],
		"debug_spawn_pickup": ["kind_id,pos", I],
		"debug_collect_pickups": ["", N],
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
		"set_unlimited": ["on", N],
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
	"StatBlock": {"rebuild": ["loadout,data", N], "set_buffs": ["dmg,rate", N]},
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
		# v1.1
		"get_pickup": ["id", O],
	},
	# --- v1.1 sim ---
	"PickupPool":
	{
		"spawn": ["kind,p,life_steps", I],
		"remove": ["i", N],
		"tick": ["expired_kinds", N],
	},
	"BombPool":
	{
		"is_full": ["", B],
		"plant": ["p,fuse,r,kind", I],
		"tick": ["ready", N],
		"remove": ["i", N],
	},
	"BuffManager":
	{
		"start": ["kind,duration_steps,m", B],
		"active": ["kind", B],
		"ratio": ["kind", F],
		"tick": ["ended", N],
		"damage_mult": ["", F],
		"fire_rate_mult": ["", F],
		"unlimited": ["", B],
		"kind_of": ["name", I],
		"name_of": ["kind", SN],
	},
	"PickupDirector":
	{
		"_init": ["cfg,rng", O],
		"step": ["sim", N],
		"skip_to": ["step_count", N],
		"progress_hash": ["", I],
	},
	"ScoreKeeper":
	{
		"_init": ["table", O],
		"on_kill": ["type_id,step", I],
		"on_evolution": ["", I],
		"on_lord": ["", I],
		"break_streak": ["step", N],
		"tick": ["step", N],
		"total": ["", I],
		"streak_left": ["step", F],
		"parts": ["", D],
	},
	"ScoreTable": {"points": ["type_id", I], "mult_for": ["streak", I]},
	# --- v1.1 görünüm ---
	"WalkCycle":
	{
		"advance": ["phase,dist,stride", F],
		"frame_at": ["phase,frames", I],
		"nearest_contact": ["phase,frames", I],
		"foot_shift_per_frame": ["stride,frames", F],
	},
	"PlayerAnim":
	{
		"configure": ["rig", N],
		"reset": ["", N],
		"update": ["dt,vel,facing_left,reload_progress", N],
		"on_shot": ["gun", N],
		"on_damaged": ["amount,from_dir", N],
		"on_level_up": ["", N],
		"on_buffs": ["mask", N],
		"on_died": ["from_dir", N],
		"on_won": ["", N],
		"death_done": ["", B],
	},
	"EnemyAnim":
	{
		"bind": ["data,atlas", N],
		"sync_slot": ["i,gen,pos", N],
		"pose_of": ["kind,hz,bob,rot_rad,sq,t,phase0", V4],
	},
	"EnemyShadowLayer": {"write": ["buf,n", N]},
	"EnemyRenderer": {"set_ghosts": ["g", N]},
	"AshGhostRenderer":
	{
		"bind": ["sim,enemy_renderer", N],
		"update_ghosts": ["dt", N],
		"ghost_count": ["", I],
	},
	"PickupRenderer": {"bind": ["sim", N], "refresh": ["dt", N]},
	"FxRenderer":
	{
		"add_ring": ["pos,r_max,dur,color,width", N],
		"add_shell": ["pos,dir", N],
		"add_particle": ["kind,pos,vel,life", N],
		"add_char": ["pos,radius", N],
	},
	# --- v1.1 UI, kontrol, depo ---
	"ScoreBlock":
	{
		"bind": ["sim", N],
		"refresh": ["dt", N],
		"eased": ["shown,target,dt", F],
		"should_pop": ["gain,since_last_pop", B],
		"is_big_gain": ["gain", B],
		"tier_of": ["mult", I],
		"format_score": ["n", S],
	},
	"BuffRow":
	{
		"bind": ["sim", N],
		"refresh": ["dt", N],
		"badge_x": ["n", F],
		"seconds_text": ["left_steps", S],
		"blinking": ["left_s", B],
	},
	"OffscreenArrow":
	{
		"bind": ["sim", N],
		"refresh": ["dt", N],
		"place": ["target,cam_pos,view,safe,margin", D],
	},
	"FloatText": {"show_text": ["text,world_to_screen_pos", N], "refresh": ["dt", N]},
	"MagazineDrum": {"set_unlimited": ["on", N]},
	"Highscores":
	{
		"_init": ["p_path", O],
		"load_file": ["", B],
		"submit": ["entry", D],
		"save": ["", B],
		"sanitize": ["raw", A],
		"better": ["a,b", B],
		"format_date": ["unix,tz_bias_min", S],
	},
	"HighscoreScreen":
	{
		"show_scores": ["entries,highlight_index", N],
		"apply_safe_area": ["extra", N],
	},
	"ResultScreen":
	{
		"show_result": ["p_won,p_stats,combos,subtitle,record", N],
		"content_bottom": ["", F],
		"apply_safe_area": ["extra", N],
	},
	"ResultTimeline": {"buttons_ready_at": ["skip_t", F]},
	"MainMenu": {"apply_safe_area": ["extra", N]},
	"ScreenDelay":
	{
		"start": ["p_target,seconds", N],
		"tick": ["dt", B],
		"skip": ["", B],
	},
	"HitStop": {"request": ["sec", N], "tick": ["dt", B]},
	"PauseLogic": {"result_delay": ["won", F]},
	"GameController":
	{
		"_v11_build_world": ["", N],
		"_v11_bind": ["new_sim", N],
		"_v11_bind_player": ["new_sim", N],
		"_v11_bind_pickups": ["new_sim", N],
		"_v11_bind_score": ["new_sim", N],
		"_v11_update_views": ["view_dt", N],
		"_v11_update_player": ["view_dt", N],
		"_v11_update_pickups": ["view_dt", N],
		"_v11_process": ["delta", N],
		"_v11_hit_stop": ["delta", B],
		"_v11_after_step": ["", N],
		"_v11_on_run_ended": ["won,stats", N],
		"_v11_on_screen": ["next", N],
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
		# v1.1
		"pickup_spawned": "kind_id,pos",
		"pickup_collected": "kind_id,pos",
		"pickup_expired": "kind_id",
		"buff_started": "kind,duration",
		"buff_ended": "kind",
		"bomb_planted": "pos,radius,fuse",
		"bomb_exploded": "pos,radius",
		"score_changed": "score,mult,gain",
		"streak_changed": "mult,left",
	},
	"ScoreKeeper": {"gained": "gain,source", "streak_changed": "mult,left"},
	"MainMenu": {"scores_requested": ""},
	"HighscoreScreen": {"back_requested": "", "play_requested": ""},
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
		"AudioDirector",
		# v1.1
		"PickupDef",
		"ScoreTable",
		"DataV11",
		"WavesValidator",
		"PickupSystem",
		"V11State",
		"Motion",
		"ResultTimeline"
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
	assert_eq(SimBus.new().get_script().get_script_signal_list().size(), 25, "16 v1 + 9 v1.1")


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


func test_v11_constants_and_limits() -> void:
	assert_eq(PickupPool.CAP, 8)
	assert_eq(BombPool.CAP, 4)
	assert_eq(BuffManager.COUNT, 3)
	assert_eq(BuffManager.Kind.DAMAGE, 0)
	assert_eq(BuffManager.Kind.FIRE_RATE, 1)
	assert_eq(BuffManager.Kind.UNLIMITED, 2)
	assert_eq(ScoreKeeper.WINDOW_STEPS, 180)
	assert_eq(
		GameSim.RNG_STREAMS,
		[&"spawn", &"choice", &"map", &"combat", &"pickup"] as Array[StringName]
	)
	assert_eq(AshGhostRenderer.CAP, 64)
	assert_eq(AshGhostRenderer.LOD_ALIVE, 150)
	assert_eq(EnemyAnim.LUT_SIZE, 256)
	assert_eq(HitStop.MAX_SEC, 0.15)
	assert_eq(Highscores.VERSION, 1)
	assert_eq(Highscores.MAX_ENTRIES, 10)
	assert_eq(Highscores.DEFAULT_PATH, "user://highscores.json")
	assert_eq(PauseLogic.LEVEL_UP_PREROLL, 0.18)
	assert_eq(PauseLogic.Screen.SCORES, 6, "Screen.SCORES sona eklendi")
	assert_eq(PauseLogic.Screen.RESULT, 5)
	assert_eq(PlayerAnim.Mode.IDLE, 0)
	assert_eq(PlayerAnim.Mode.WALK, 1)
	assert_eq(PlayerAnim.Mode.DEAD, 2)
	assert_eq(BuffManager.kind_of("damage"), 0)
	assert_eq(BuffManager.kind_of("fire_rate"), 1)
	assert_eq(BuffManager.kind_of("unlimited"), 2)
	assert_eq(BuffManager.kind_of("shield"), -1)
	assert_eq(BuffManager.name_of(2), &"unlimited")
	assert_eq(BuffManager.name_of(3), &"")


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
		"range_mult",
		"buff_dmg_mult",
		"buff_rate_mult"
	]:
		assert_true(p in st, "StatBlock.%s" % p)
	assert_eq(st.bullet_dmg_mult, 1.0)
	assert_eq(st.mag_add, 0)
	var m := Magazine.new()
	for p in [
		"count", "cap", "reloading", "reload_left", "reload_total", "refund_used", "unlimited"
	]:
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
		"rng_combat",
		# v1.1
		"rng_pickup",
		"pickups",
		"bombs",
		"buffs",
		"pickup_director",
		"score"
	]:
		assert_true(p in sim, "GameSim.%s" % p)


func test_v11_value_classes_have_their_contract_fields() -> void:
	var pd := PickupDef.new()
	for p in [
		"id",
		"display_name",
		"rarity",
		"weight",
		"effect",
		"amount",
		"buff",
		"mult",
		"duration",
		"radius",
		"fuse",
		"dmg",
		"elite_frac",
		"elite_min",
		"toast",
		"icon"
	]:
		assert_true(p in pd, "PickupDef.%s" % p)
	var st := ScoreTable.new()
	for p in [
		"kill_points",
		"tiers",
		"window_steps",
		"evolution_bonus",
		"survival_per_sec",
		"lord_bonus",
		"display_cap"
	]:
		assert_true(p in st, "ScoreTable.%s" % p)
	var pool := PickupPool.new()
	for p in ["count", "pos", "kind_idx", "age_steps", "left_steps", "uid"]:
		assert_true(p in pool, "PickupPool.%s" % p)
	var bp := BombPool.new()
	for p in ["count", "pos", "fuse_steps", "fuse_total", "radius", "kind_idx"]:
		assert_true(p in bp, "BombPool.%s" % p)
	var bm := BuffManager.new()
	for p in ["left_steps", "total_steps", "mult"]:
		assert_true(p in bm, "BuffManager.%s" % p)
	var sk := ScoreKeeper.new(st)
	for p in [
		"kills_part",
		"streak_part",
		"evolution_part",
		"survival_part",
		"lord_part",
		"streak_count",
		"mult",
		"best_mult",
		"last_kill_step"
	]:
		assert_true(p in sk, "ScoreKeeper.%s" % p)
	assert_true("next_step" in PickupDirector.new({}, RandomNumberGenerator.new()))
	var pa := PlayerAnim.new()
	for p in [
		"mode",
		"lean",
		"bob_px",
		"sx",
		"sy",
		"turn_x",
		"frame_a",
		"frame_b",
		"frame_mix",
		"walk_phase",
		"hit",
		"tint_amt",
		"desat",
		"scarf_amp",
		"arm_rot",
		"arm_back",
		"arm_len",
		"knock_px",
		"body_rot",
		"sink_px",
		"fade",
		"halo",
		"level_ring",
		"aura_mask"
	]:
		assert_true(p in pa, "PlayerAnim.%s" % p)
	var er := EnemyRenderer.new()
	for p in ["last_anim_instances", "last_frame_selects", "last_shadow_instances", "shadows"]:
		assert_true(p in er, "EnemyRenderer.%s" % p)
	er.free()
	var ea := EnemyAnim.new()
	assert_true("last_anim_instances" in ea and "last_frame_selects" in ea)
	var hs := Highscores.new("user://x.json")
	assert_true("entries" in hs and "corrupt" in hs)
	var sd := ScreenDelay.new()
	assert_true("active" in sd and "target" in sd and "left" in sd)
	for sc in [ScoreBlock, BuffRow, OffscreenArrow, FloatText, HighscoreScreen]:
		var node: Control = sc.new()
		assert_not_null(node, "yüklenir: %s" % sc)
		node.free()
	var gc := GameController.new()
	for p in ["highscores", "scores_screen", "pickup_renderer", "enemy_shadows", "ghosts"]:
		assert_true(p in gc, "GameController.%s" % p)
	gc.free()
