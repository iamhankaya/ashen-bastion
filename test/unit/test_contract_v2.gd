extends GutTest
## Sözleşme (v2.0 S1–S3): yeni sınıfların imzaları, sabitleri ve sinyalleri. DEĞİŞMEMESİ GEREKEN noktalar: K/B/M fazları
## gövdeleri doldurur, imzayı değiştirmez (değişiklik gerekirse `vlad task ask`). Argüman adlarındaki baştaki `_`
## (kullanılmayan parametre) gövde yazılınca düşer; bu test onu yok sayar.

const N := TYPE_NIL
const I := TYPE_INT
const B := TYPE_BOOL
const F := TYPE_FLOAT
const D := TYPE_DICTIONARY
const O := TYPE_OBJECT
const A := TYPE_ARRAY
const SN := TYPE_STRING_NAME

# sınıf -> {yöntem: [argüman adları, dönüş türü]}
const METHODS := {
	"DataV2":
	{
		"load_achievements": ["g,root_dir", N],
		"validate": ["g,out,complete", N],
		"validate_character": ["g,out,file,d", N],
	},
	"AchievementDef":
	{
		"from_dict": ["d", O],
		"scope_of": ["p_stat", SN],
		"tier_index": ["p_tier", I],
	},
	"StoreIo":
	{
		"read_versioned": ["path,version", D],
		"write_atomic": ["path,text", B],
		"int_of": ["v,clamp_big", TYPE_NIL],
	},
	"AchievementStore":
	{
		"_init": ["p_path", O],
		"load_file": ["", B],
		"save": ["", B],
		"is_unlocked": ["id", B],
		"unlocked_at": ["id", I],
		"unlock": ["id,unix", B],
		"add_total": ["key,n", N],
		"note_best": ["score,time,level", N],
		"note_char5": ["char_id", B],
		"count_unlocked": ["known", I],
		"sanitize": ["raw", D],
	},
	"AchievementTracker":
	{
		"_init": ["p_data,p_store,p_char_id,p_clock", O],
		"attach": ["bus", N],
		"detach": ["", N],
		"poll": ["sim", N],
		"finish": ["won,stats", N],
		"run_unlocked": ["", A],
		"value_of": ["stat", I],
		"progress": ["def", I],
		"flush": ["", B],
	},
	"AchievementProgress": {"of": ["def,store", I]},
	"CharacterRoster":
	{
		"ids": ["data", A],
		"is_unlocked": ["c,store", B],
		"resolve": ["saved,data,store", SN],
		"lock_reason": ["c,data", TYPE_STRING],
		"step": ["list,current,dir", SN],
	},
	"ShowcaseMotion": {"scale_at": ["t", F], "drift_at": ["t", F]},
	"ToastQueue":
	{
		"push": ["id", B],
		"tick": ["dt", N],
		"current": ["", SN],
		"phase": ["", I],
		"offset_alpha": ["", TYPE_VECTOR2],
		"clear": ["", N],
	},
	"AchievementToast":
	{
		"rect": ["safe_top", TYPE_RECT2],
		"show_def": ["def", N],
		"apply_state": ["q", N],
	},
	"CharactersScreen":
	{
		"open": ["data,store,selected_id", N],
		"focus_id": ["", SN],
		"set_focus_id": ["id", N],
		"press_select": ["", B],
		"select_button_state": ["", I],
		"apply_safe_area": ["extra", N],
	},
	"AchievementsScreen":
	{"open": ["data,store", N], "row_count": ["", I], "apply_safe_area": ["extra", N]},
	"V2Part":
	{
		"build_world": ["refs", N],
		"bind": ["sim", N],
		"update_views": ["view_dt", N],
		"on_run_ended": ["won,stats", N],
		"on_screen": ["next", N],
		"on_pause": ["", N],
		"flush": ["", N],
		"apply_safe_areas": ["extra", N],
		"release": ["", N],
	},
	"V2Flow":
	{
		"build_world": ["refs", N],
		"bind": ["sim", N],
		"update_views": ["view_dt", N],
		"on_run_ended": ["won,stats", N],
		"on_screen": ["next", N],
		"on_pause": ["", N],
		"flush": ["", N],
		"open_characters": ["", N],
		"open_achievements": ["", N],
		"selected_character": ["", SN],
		"apply_safe_areas": ["extra", N],
		"release": ["", N],
	},
}
const SIGNALS := {
	"AchievementTracker": {"unlocked": "def"},
	"CharactersScreen": {"back_requested": "", "selected": "id"},
	"AchievementsScreen": {"back_requested": ""},
	"MainMenu": {"characters_requested": "", "achievements_requested": ""},
}
## V2Part'tan türeyen dilim sınıfları: ortak yöntemleri taşır; kendi ek yöntemleri.
const PARTS := {"V2Characters": ["open"], "V2Achievements": ["open"], "V2Maint": []}
const COMMON := [
	"build_world",
	"bind",
	"update_views",
	"on_run_ended",
	"on_screen",
	"on_pause",
	"flush",
	"apply_safe_areas",
	"release",
]


func _script_of(cls: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return load(c["path"])
	return null


func _args(sc: Script, method: String) -> String:
	var s := KitDev.arg_names(sc, method)
	if s == "<yok>":
		return s
	var out := PackedStringArray()
	for a in s.split(","):
		out.append(a.trim_prefix("_"))
	return ",".join(out)


func test_new_classes_are_registered_and_load() -> void:
	for cls in METHODS.keys() + PARTS.keys() + ["MainMenu", "UserLeak"]:
		assert_not_null(_script_of(cls), "%s global class olarak kayıtlı değil" % cls)


func test_method_signatures() -> void:
	for cls in METHODS.keys():
		var sc := _script_of(cls)
		if sc == null:
			continue
		for m in METHODS[cls].keys():
			assert_eq(_args(sc, m), METHODS[cls][m][0], "%s.%s argümanları" % [cls, m])
			assert_eq(KitDev.return_type(sc, m), METHODS[cls][m][1], "%s.%s dönüş türü" % [cls, m])


func test_signal_signatures() -> void:
	for cls in SIGNALS.keys():
		var sc := _script_of(cls)
		for s in SIGNALS[cls].keys():
			assert_eq(KitDev.has_signal_args(sc, s), SIGNALS[cls][s], "%s.%s sinyali" % [cls, s])


func test_part_classes_extend_v2part_and_carry_common_hooks() -> void:
	for cls in PARTS.keys():
		var sc := _script_of(cls)
		assert_eq(sc.get_base_script(), _script_of("V2Part"), "%s V2Part'tan türer" % cls)
		var inst: Object = sc.new()
		for m in COMMON + PARTS[cls]:
			assert_true(inst.has_method(m), "%s.%s" % [cls, m])


func test_v2flow_fields_and_part_types() -> void:
	var f := V2Flow.new()
	assert_true(f.characters is V2Characters)
	assert_true(f.achievements is V2Achievements)
	assert_true(f.maint is V2Maint)
	assert_eq(f.opts, {})
	assert_null(f.achievements.store)


func test_v2flow_does_not_know_the_controller_type() -> void:
	for p in [
		"res://scripts/ctrl/v2_flow.gd",
		"res://scripts/ctrl/v2_part.gd",
		"res://scripts/ctrl/v2_characters.gd",
		"res://scripts/ctrl/v2_achievements.gd",
		"res://scripts/ctrl/v2_maint.gd"
	]:
		assert_false(FileAccess.get_file_as_string(p).contains("GameController"), p)


func test_constants() -> void:
	assert_eq(StoreIo.MAX_BYTES, 262144)
	assert_eq(StoreIo.INT_LIMIT, 1.0e15)
	assert_eq(AchievementStore.VERSION, 1)
	assert_eq(AchievementStore.DEFAULT_PATH, "user://achievements.json")
	assert_eq(AchievementStore.MAX_UNLOCKED, 64)
	assert_eq(AchievementStore.MAX_CHARS5, 16)
	assert_eq(AchievementStore.COUNTER_CAP, 999999999)
	assert_eq(ToastQueue.MAX_QUEUE, 3)
	assert_eq(ToastQueue.IN_SEC, 0.22)
	assert_eq(ToastQueue.HOLD_SEC, 2.1)
	assert_eq(ToastQueue.OUT_SEC, 0.18)
	assert_eq(ToastQueue.GAP_SEC, 0.15)
	assert_eq(ToastQueue.Phase.IDLE, 0)
	assert_eq(ToastQueue.Phase.IN, 1)
	assert_eq(ToastQueue.Phase.HOLD, 2)
	assert_eq(ToastQueue.Phase.OUT, 3)
	assert_eq(ToastQueue.Phase.GAP, 4)
	assert_eq(ShowcaseMotion.BREATH_SEC, 2.4)
	assert_eq(ShowcaseMotion.BREATH_MAX, 0.015)
	assert_eq(ShowcaseMotion.DRIFT_SEC, 6.0)
	assert_eq(ShowcaseMotion.DRIFT_PX, 8.0)
	assert_eq(ShowcaseMotion.CROSSFADE_SEC, 0.26)
	assert_eq(CharacterRoster.DEFAULT_ID, &"gunslinger")
	assert_eq(CharactersScreen.SelectState.SELECT, 0)
	assert_eq(CharactersScreen.SelectState.SELECTED, 1)
	assert_eq(CharactersScreen.SelectState.LOCKED, 2)
	assert_eq(DataV2.ATLAS_CELLS_MAX, 16)
	assert_eq(DataV2.TIERS, PackedStringArray(["kolay", "orta", "zor", "cok_zor"]))
	assert_eq(DataV2.ACH_KEYS.size(), 11, "v2.0.3: +steps, group, legacy")


func test_toast_rect_contract() -> void:
	assert_eq(AchievementToast.rect(0.0), Rect2(150, 820, 780, 120))
	assert_eq(AchievementToast.rect(100.0), Rect2(150, 920, 780, 120))


func test_store_defaults() -> void:
	var s := AchievementStore.new("user://test_ach_contract_never_written.json")
	assert_eq(s.path, "user://test_ach_contract_never_written.json")
	assert_eq(s.unlocked, {})
	assert_eq(s.totals, {"kills": 0, "runs": 0, "wins": 0, "play_secs": 0})
	assert_eq(s.best, {"score": 0, "time": 0, "level": 0})
	assert_eq(s.chars5, PackedStringArray())
	assert_false(s.corrupt)
	assert_false(s.dirty)
	assert_eq(AchievementStore.new().path, AchievementStore.DEFAULT_PATH)


func test_store_io_int_of_matches_highscores_rules() -> void:
	assert_eq(StoreIo.int_of(5, false), 5)
	assert_eq(StoreIo.int_of(5.0, false), 5)
	assert_eq(StoreIo.int_of(-3.0, false), -3)
	assert_null(StoreIo.int_of(5.5, false))
	assert_null(StoreIo.int_of(NAN, true))
	assert_null(StoreIo.int_of(INF, true))
	assert_null(StoreIo.int_of("5", true))
	assert_null(StoreIo.int_of(true, true))
	assert_null(StoreIo.int_of(null, true))
	assert_eq(StoreIo.int_of(1.0e16, true), int(1.0e15), "ham int sınırı üstü: kırp")
	assert_null(StoreIo.int_of(1.0e16, false), "kırpma kapalıyken at")
	assert_null(StoreIo.int_of(-1.0e16, true), "negatif devasa atılır")
	for v in [0, 7, 1.0e15, 123456789.0, -1, 1.5, 1.0e16, "x"]:
		assert_eq(
			StoreIo.int_of(v, true), Highscores._int_of(v, true), "Highscores ile aynı: %s" % str(v)
		)
		assert_eq(
			StoreIo.int_of(v, false),
			Highscores._int_of(v, false),
			"Highscores ile aynı (kırpmasız): %s" % str(v)
		)


func test_b_bodies_are_real_not_stubs() -> void:
	# B1/B2 sonrası depo/izleyici/ilerleme gövdeleri iskelet değil: Stub.todo kaydı bırakmaz.
	Stub.reset()
	var path := "user://test_ach_contract_never_written.json"
	var s := AchievementStore.new("user://yok_klasor_ach/x.json")
	s.unlock(&"a", 1)
	s.save()
	s.load_file()
	var tr := AchievementTracker.new(GameData.new(), s, &"gunslinger")
	tr.attach(SimBus.new())
	tr.finish(false, {})
	AchievementProgress.of(null, s)
	assert_eq(Stub.calls().size(), 0, "iskelet gövde kalmadı: %s" % [Stub.calls()])
	assert_false(FileAccess.file_exists(path))


func test_achievement_def_from_dict_tolerates_wrong_types() -> void:
	var a := AchievementDef.from_dict({"id": 5, "name": [], "target": "x", "stat": null, "tier": 1})
	assert_eq(a.id, &"")
	assert_eq(a.display_name, "")
	assert_eq(a.target, 0)
	assert_eq(a.stat, &"")
	var b := AchievementDef.from_dict(
		{"id": "ilk_kan", "name": "İlk Kan", "target": 1.0, "icon": "res://x.png"}
	)
	assert_eq(b.id, &"ilk_kan")
	assert_eq(b.target, 1)
	assert_eq(b.icon, "res://x.png")
