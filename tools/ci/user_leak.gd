class_name UserLeak
extends RefCounted
## `user://` sızıntı denetimi (v2.0 S3): GUT öncesi/sonrası dosya listesi + özetler karşılaştırılır. Kancalar:
## tools/ci/gut_pre_hook.gd (taban) ve tools/ci/gut_stub_hook.gd (karşılaştırma). Çıktı satırı: `USER_LEAK: <yol>`.
## Kural: koşu sırasında OLUŞAN dosya/dizin ya da DEĞİŞEN/SİLİNEN izlenen dosya (settings.cfg, achievements.json,
## highscores.json) sızıntıdır; gerçek kayıtlar testlerce bozulmamalı.
## Hariç: `user://logs/` ve `objectdb_snapshots/` (motor) ile TEMP_DIRS (SimKit/KitDev'in koşu boyu önbellek dizinleri;
## koşu sonunda kancada silinir). İzlenen dosyalar koşu sonunda her durumda taban içeriğine GERİ YAZILIR (geliştiricinin
## gerçek kaydı bozulmaz), izin listesinde olsa da.
## İzin listesi: tools/ci/user_leak_allow.txt (her satır `desen  # gerekçe`; desen user:// köküne göre `String.match`
## kalıbıdır). Listeye girmek bir BULGUdur (düzeltilemeyen v1/v1.1 sızıntısı), kalıcı çözüm değildir.

const ROOT := "user://"
const ALLOW_PATH := "res://tools/ci/user_leak_allow.txt"
const TRACKED: PackedStringArray = ["settings.cfg", "achievements.json", "highscores.json"]
const IGNORED_PREFIX: PackedStringArray = ["logs/", "objectdb_snapshots/"]
const TEMP_DIRS: PackedStringArray = ["sim_kit_tmp", "kit_dev_tmp"]

## Son taban: {göreli_yol: özet} (dizinler "dir/" soneki, özet "dir").
static var baseline: Dictionary = {}
static var has_baseline: bool = false
## İzlenen dosyaların taban içeriği: yol -> PackedByteArray (yoksa kayıt yok).
static var tracked_bytes: Dictionary = {}


static func snapshot() -> Dictionary:
	var out := {}
	_walk("", out)
	return out


static func save_baseline() -> void:
	baseline = snapshot()
	has_baseline = true
	tracked_bytes = {}
	for t in TRACKED:
		if FileAccess.file_exists(ROOT + t):
			tracked_bytes[t] = FileAccess.get_file_as_bytes(ROOT + t)


## İzin listesi desenleri (yorumlar ve boş satırlar atlanır).
static func allow_patterns() -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(ALLOW_PATH):
		return out
	for line in FileAccess.get_file_as_string(ALLOW_PATH).split("\n"):
		var s := line.get_slice("#", 0).strip_edges()
		if not s.is_empty():
			out.append(s)
	return out


## Sızıntı yolları (sıralı). `allow` boşsa izin listesi yok sayılır.
static func leaks(
	before: Dictionary, after: Dictionary, allow: PackedStringArray
) -> PackedStringArray:
	var out := PackedStringArray()
	var keys: Array = after.keys()
	keys.sort()
	for k: String in keys:
		if _allowed(k, allow):
			continue
		if not before.has(k):
			out.append(k)
		elif TRACKED.has(k) and before[k] != after[k]:
			out.append(k)
	var gone: Array = before.keys()
	gone.sort()
	for k: String in gone:
		if TRACKED.has(k) and not after.has(k) and not _allowed(k, allow):
			out.append(k)
	return out


## Taban yoksa boş.
static func current_leaks() -> PackedStringArray:
	if not has_baseline:
		return PackedStringArray()
	return leaks(baseline, snapshot(), allow_patterns())


## İzin listesi sayesinde sessizce geçen sızıntılar (bilgi satırı için).
static func allowed_leaks() -> PackedStringArray:
	if not has_baseline:
		return PackedStringArray()
	var all := leaks(baseline, snapshot(), PackedStringArray())
	var out := PackedStringArray()
	for k in all:
		if _allowed(k, allow_patterns()):
			out.append(k)
	return out


## Koşu sonu temizliği: önbellek dizinlerini siler, izlenen dosyaları taban içeriğine geri yazar (taban yoksa dokunmaz).
static func cleanup_and_restore() -> void:
	if not has_baseline:
		return
	for d in TEMP_DIRS:
		_remove_recursive(ProjectSettings.globalize_path(ROOT + d))
	for t in TRACKED:
		var path := ROOT + t
		if tracked_bytes.has(t):
			var cur := (
				FileAccess.get_file_as_bytes(path)
				if FileAccess.file_exists(path)
				else PackedByteArray()
			)
			if cur != tracked_bytes[t]:
				var f := FileAccess.open(path, FileAccess.WRITE)
				if f != null:
					f.store_buffer(tracked_bytes[t])
					f.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _allowed(path: String, allow: PackedStringArray) -> bool:
	for pat in allow:
		if path.match(pat) or path.trim_suffix("/").match(pat):
			return true
	return false


static func _walk(rel: String, out: Dictionary) -> void:
	var dir := ROOT + rel
	for f in DirAccess.get_files_at(dir):
		var r := rel + f
		if _ignored(r):
			continue
		out[r] = FileAccess.get_md5(ROOT + r)
	for d in DirAccess.get_directories_at(dir):
		var r := rel + d + "/"
		if _ignored(r):
			continue
		out[r] = "dir"
		_walk(r, out)


static func _ignored(rel: String) -> bool:
	for p in IGNORED_PREFIX:
		if rel.begins_with(p):
			return true
	for t in TEMP_DIRS:
		if rel == t + "/" or rel.begins_with(t + "/"):
			return true
	return false


static func _remove_recursive(abs_path: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	for f in DirAccess.get_files_at(abs_path):
		DirAccess.remove_absolute(abs_path.path_join(f))
	for d in DirAccess.get_directories_at(abs_path):
		_remove_recursive(abs_path.path_join(d))
		DirAccess.remove_absolute(abs_path.path_join(d))
	DirAccess.remove_absolute(abs_path)
