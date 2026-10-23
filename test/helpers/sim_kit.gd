class_name SimKit
extends RefCounted
## Tester yardımcıları: GameSim kurulumu, olay süzme, koşturma. Yalnız sözleşme yüzeyine (GameSim, event_log,
## bus, havuzların açık alanları) bakar; iç yapıya bakmaz.
##
## Veri türleri (opts["data_kind"]):
##   "quiet"          gerçek data/, doğurma çizelgesi BOŞ (kural testleri tesadüfi düşmandan arınır; varsayılan)
##   "real"           gerçek data/ (waves.json dahil)
##   "fixture"        test/fixtures/data_valid, doğurma çizelgesi boş
##   "fixture_waves"  test/fixtures/data_valid (waves.json dahil)

const CHAR := &"gunslinger"
const STEP := GameSim.STEP
const FIXTURE_DIR := "res://test/fixtures/data_valid"
const REAL_DIR := "res://data"
const TMP_ROOT := "user://sim_kit_tmp"
const EMPTY_WAVES := {
	"end_time": 1200,
	"rows": [],
	"after_lord": {"piyade_rate_mult": 0.5, "karga_stop": true},
}

static var _cache: Dictionary = {}
static var _counter: int = 0


## opts: GameSim seçenekleri + "data_kind". log_events varsayılan true.
static func make(seed_value: int = 1, opts: Dictionary = {}) -> GameSim:
	var o := opts.duplicate()
	var kind: String = str(o.get("data_kind", "quiet"))
	o.erase("data_kind")
	if not o.has("log_events"):
		o["log_events"] = true
	if not o.has("data"):
		o["data"] = data_for(kind)
	var character_id: StringName = o.get("character", CHAR)
	o.erase("character")
	return GameSim.new(seed_value, character_id, o)


static func data_for(kind: String) -> GameData:
	match kind:
		"real":
			return GameData.load_default()
		"quiet":
			return _cached("quiet", REAL_DIR, true)
		"fixture":
			return _cached("fixture", FIXTURE_DIR, true)
		"fixture_waves":
			return _cached("fixture_waves", FIXTURE_DIR, false)
	return GameData.load_default()


## Oyuncuyu ölümsüz yapar (ölçüm koşuları için). hp <= max_hp değişmezi korunur.
static func godmode(sim: GameSim) -> void:
	sim.max_hp = 1.0e9
	sim.hp = 1.0e9


static func events(sim: GameSim, type: StringName) -> Array:
	var out: Array = []
	for e in sim.event_log:
		if e["type"] == type:
			out.append(e)
	return out


static func count_events(sim: GameSim, type: StringName) -> int:
	var n := 0
	for e in sim.event_log:
		if e["type"] == type:
			n += 1
	return n


## Sonuncu olay (yoksa boş sözlük).
static func last_event(sim: GameSim, type: StringName) -> Dictionary:
	for i in range(sim.event_log.size() - 1, -1, -1):
		if sim.event_log[i]["type"] == type:
			return sim.event_log[i]
	return {}


## En çok `steps` adım; State != RUNNING olursa durur. Gerçekten atılan adım sayısını döndürür.
static func run(sim: GameSim, steps: int, move: Vector2 = Vector2.ZERO) -> int:
	var n := 0
	while n < steps and sim.state == GameSim.State.RUNNING:
		sim.step(move)
		n += 1
	return n


## pred() true olana, State != RUNNING olana ya da max_steps dolana kadar adım atar. pred sağlandıysa true.
static func run_until(
	sim: GameSim, pred: Callable, max_steps: int, move: Vector2 = Vector2.ZERO
) -> bool:
	for i in max_steps:
		if pred.call():
			return true
		if sim.state != GameSim.State.RUNNING:
			return false
		sim.step(move)
	return bool(pred.call())


## debug_spawn sarmalayıcı: -1 ise (havuz dolu/bilinmeyen tür) -1 döner.
static func add_enemy(sim: GameSim, type_id: StringName, pos: Vector2) -> int:
	return sim.debug_spawn(type_id, pos)


## Düşman havuzunda kimliğin hp'si (canlı değilse -1).
static func enemy_hp(sim: GameSim, id: int) -> float:
	if not sim.enemies.is_alive(id):
		return -1.0
	return sim.enemies.hp[EnemyPool.index_of(id)]


static func enemy_pos(sim: GameSim, id: int) -> Vector2:
	return sim.enemies.pos[EnemyPool.index_of(id)]


## LEVEL_UP durumuna girene kadar (en çok max_steps) adım atar.
static func run_to_level_up(sim: GameSim, max_steps: int = 10) -> bool:
	for i in max_steps:
		if sim.state == GameSim.State.LEVEL_UP:
			return true
		if sim.state != GameSim.State.RUNNING:
			return false
		sim.step(Vector2.ZERO)
	return sim.state == GameSim.State.LEVEL_UP


## xp ekler ve LEVEL_UP'a girer; girerse true.
static func level_up_with(sim: GameSim, xp: int) -> bool:
	sim.debug_add_xp(xp)
	return run_to_level_up(sim)


## Bekleyen kartlarda `skill_id` olanın indeksi (yoksa -1).
static func card_index(sim: GameSim, skill_id: StringName) -> int:
	var cards := sim.pending_choices()
	for i in cards.size():
		if cards[i].skill_id == skill_id:
			return i
	return -1


## Veri dizinini (res:// ya da user://) yeni bir user:// dizinine kopyalar; yolunu döndürür.
static func copy_data(src: String, label: String) -> String:
	_counter += 1
	var dest := "%s/%s_%d_%d" % [TMP_ROOT, label, OS.get_process_id(), _counter]
	_copy_dir(src, dest)
	return dest


static func write_json(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(value, "  "))


static func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func remove_tmp() -> void:
	_cache.clear()
	_remove_recursive(ProjectSettings.globalize_path(TMP_ROOT))


static func _cached(key: String, src: String, empty_waves: bool) -> GameData:
	if _cache.has(key):
		return _cache[key]
	var dir := copy_data(src, key)
	if empty_waves:
		write_json(dir.path_join("waves.json"), EMPTY_WAVES)
	var g := GameData.load_dir(dir)
	_cache[key] = g
	return g


static func _copy_dir(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst))
	for f in DirAccess.get_files_at(src):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var out := FileAccess.open(dst.path_join(f), FileAccess.WRITE)
		out.store_buffer(FileAccess.get_file_as_bytes(src.path_join(f)))
	for d in DirAccess.get_directories_at(src):
		_copy_dir(src.path_join(d), dst.path_join(d))


static func _remove_recursive(abs_path: String) -> void:
	for f in DirAccess.get_files_at(abs_path):
		DirAccess.remove_absolute(abs_path.path_join(f))
	for d in DirAccess.get_directories_at(abs_path):
		_remove_recursive(abs_path.path_join(d))
		DirAccess.remove_absolute(abs_path.path_join(d))
	DirAccess.remove_absolute(abs_path)
