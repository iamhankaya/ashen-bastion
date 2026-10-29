class_name AchKit
extends RefCounted
## Başarım/karakter kabul yardımcıları: geçici kayıt yolu (user://test_ach_*.json), enjekte saat, sentetik SimBus olayları,
## tek yerde `.tmp/.bad` temizliği. Hiçbir test gerçek user://achievements.json ya da settings.cfg'ye yazmaz (gate USER_LEAK).

const PREFIX := "user://test_ach_"
const FIXED_UNIX := 1700000000


## B diliminden bağımsız bellek içi depo: K testleri (karakter kilidi) AchievementStore iskeleti Stub.todo iken de koşar.
class FakeStore:
	extends AchievementStore
	var ids: Dictionary = {}

	func is_unlocked(id: StringName) -> bool:
		return ids.has(id)

	func unlocked_at(id: StringName) -> int:
		return int(ids.get(id, 0))

	func unlock(id: StringName, unix: int) -> bool:
		if unix < 1 or ids.has(id):
			return false
		ids[id] = unix
		return true


static var _n: int = 0
static var _made: Array[String] = []


## Yeni geçici kayıt yolu (dosya yok). `after_each`'te `cleanup()` çağrılmalı.
static func tmp_path(label: String = "s") -> String:
	_n += 1
	var p := "%s%s_%d_%d.json" % [PREFIX, label, OS.get_process_id(), _n]
	_made.append(p)
	return p


## tmp_path ile üretilen her yolun kendisini, `.tmp`, `.bad` yan dosyalarını (ve dizi olarak kurulduysa dizini) siler.
static func cleanup() -> void:
	for p in _made:
		for suffix in ["", ".tmp", ".bad", AchievementStore.BACKUP_SUFFIX]:
			_rm_any(ProjectSettings.globalize_path(p + suffix))
	_made.clear()


## Dışarıda üretilmiş yolu temizlik listesine ekler.
static func track(path: String) -> void:
	if not _made.has(path):
		_made.append(path)


static func _rm_any(abs_path: String) -> void:
	if DirAccess.dir_exists_absolute(abs_path):
		for f in DirAccess.get_files_at(abs_path):
			DirAccess.remove_absolute(abs_path.path_join(f))
		for d in DirAccess.get_directories_at(abs_path):
			_rm_any(abs_path.path_join(d))
		DirAccess.remove_absolute(abs_path)
	elif FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


static func write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## Sabit saat (unix); Callable `() -> int`.
static func clock(unix: int = FIXED_UNIX) -> Callable:
	return func() -> int: return unix


## v2.0 kabul/birim testleri 22 tek eşikli başarım varsayar: `legacy_data()` / `legacy_rig()` (gerçek `data/` + `LEGACY_DIR` kayıtları).
## `data()` / `rig()` gerçek v2.0.3 aile verisidir.
const LEGACY_DIR := "res://test/fixtures/ach_v20"
static var _legacy: GameData = null


static func data() -> GameData:
	return GameData.load_default()


## Gerçek katalog, ama karakter listesi yalnız `ids` (sırası gerçek `order` sırasıdır). Altın/baz (golden) ekran testleri
## yeni karakter eklenince kaymasın diye: yeni örnek (paylaşılan önbelleği değiştirmez).
static func data_with_characters(ids: Array) -> GameData:
	var g := GameData.load_dir("res://data")
	for id in g.character_ids.duplicate():
		if not ids.has(id):
			g.character_ids.erase(id)
			g._characters.erase(id)
	return g


static func legacy_data() -> GameData:
	if _legacy == null:
		_legacy = GameData.load_dir("res://data")
		_legacy.achievements.clear()
		_legacy.achievement_ids.clear()
		_legacy._achievements.clear()
		DataV2.load_achievements(_legacy, LEGACY_DIR)
	return _legacy


static func store(path: String = "") -> AchievementStore:
	return AchievementStore.new(path if path != "" else tmp_path())


## Bellek içi sahte depo (dosya yok; B iskeletinden bağımsız).
static func fake_store(open_ids: Array = []) -> AchievementStore:
	var f := FakeStore.new(tmp_path("fake"))
	for id in open_ids:
		f.ids[StringName(id)] = FIXED_UNIX
	return f


## {"store","tracker","bus"}: yeni depo (geçici yol), tracker (gerçek aile verisi ya da `p_data`), SimBus ve attach.
static func rig(
	char_id: StringName = &"gunslinger", unix: int = FIXED_UNIX, p_data: GameData = null
) -> Dictionary:
	var st := store()
	var tr := AchievementTracker.new(p_data if p_data != null else data(), st, char_id, clock(unix))
	var bus := SimBus.new()
	tr.attach(bus)
	return {"store": st, "tracker": tr, "bus": bus}


## v2.0 (22 tek eşikli kayıt) verisiyle `rig`.
static func legacy_rig(char_id: StringName = &"gunslinger", unix: int = FIXED_UNIX) -> Dictionary:
	return rig(char_id, unix, legacy_data())


## n kez düşman ölümü (varsayılan sıradan tür).
static func kills(bus: SimBus, n: int, type_id: StringName = ExpectedTablesV2.NORMAL_ENEMY) -> void:
	for i in n:
		bus.enemy_killed.emit(type_id, Vector2.ZERO)


## poll için taze sim: `time` saniyeye ilerletilir (debug_set_time yalnız ileri gider), eklentisiz/dalgasız veri.
static func sim_at(time_sec: float, seed_value: int = 1) -> GameSim:
	var sim := SimKit.make(seed_value, {"data_kind": "quiet", "pickups": false})
	if time_sec > 0.0:
		sim.debug_set_time(time_sec)
	return sim


## Etkin yuvaları n'e tamamlar (gerçek aktif beceri kimlikleri; yuva sınırına uyar).
static func fill_actives(sim: GameSim, n: int) -> void:
	var ids: Array[StringName] = [
		&"cift_tabanca",
		&"doldurma_sacilmasi",
		&"keskin_nisan",
		&"yelpaze_atis",
		&"seken_mermi",
		&"sarapnel",
		&"mermi_firtinasi",
		&"gurleyen_yelpaze",
	]
	for id in ids:
		if sim.loadout.actives().size() >= n:
			return
		sim.debug_grant(id, 1)


## Düğüm ağacındaki tüm Label/Button metinleri (sonuç ekranı çipi, etiket aramaları için).
static func texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	_collect(root, out)
	return out


static func _collect(n: Node, out: PackedStringArray) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_collect(c, out)


static func any_text_contains(root: Node, needle: String) -> bool:
	for t in texts(root):
		if t.contains(needle):
			return true
	return false
