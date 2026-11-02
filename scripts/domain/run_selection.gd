class_name RunSelection
extends RefCounted
## v2.1 koşu modu/zorluk seçimi: Settings'teki seçim (run_mode/run_diff) + data/run_profiles.json profilleri. Ayar kaynağı
## enjekte edilir (run_mode/run_diff/save_settings olan herhangi bir nesne; testlerde sahte); verilmezse Settings autoload'u.
## Controller ve seçim kullanan ekranlar (menü, duraklatma, sonuç, KOŞU) aynı örneği paylaşır (F-ashen-bastion-137).

static var _profiles: Dictionary = {}
var _source: Object = null


func _init(source: Object = null) -> void:
	_source = source


## Doğrulanmış profil verisi (ilk çağrıda yüklenir). Dosya hatalıysa {} (çağıranlar legacy'ye düşer).
static func load_profiles() -> Dictionary:
	if _profiles.is_empty():
		_profiles = RunProfiles.load_default()["profiles"]
	return _profiles


## Testler için önbelleği boşaltır.
static func reset_cache() -> void:
	_profiles = {}
	RunCatalog.reset_default_cache()


func profiles() -> Dictionary:
	return load_profiles()


## {"mode": StringName, "diff": StringName}: Settings'teki seçim; Settings yoksa dosya varsayılanı (Normal/Normal).
func selection() -> Dictionary:
	var st := _settings()
	if st == null:
		return RunProfiles.default_selection(profiles())
	return {"mode": StringName(st.run_mode), "diff": StringName(st.run_diff)}


## Seçimi kaydeder ve yazar. Bilinmeyen mod/zorluk adı sessizce yok sayılır.
func set_selection(mode: StringName, diff: StringName) -> void:
	var st := _settings()
	var cat := RunCatalog.default()
	if st == null or cat.mode(String(mode)).is_empty() or cat.difficulty(String(diff)).is_empty():
		return
	st.run_mode = String(mode)
	st.run_diff = String(diff)
	st.save_settings()


## GameSim opts'u: seçili profilin end_mode/end_time/run_profile'ı. Profil kurulamazsa bugünkü RUN_OPTS (legacy).
func run_opts() -> Dictionary:
	var sel := selection()
	var p := RunProfile.make(sel["mode"], sel["diff"], profiles())
	return (p if p != null else RunProfile.legacy()).opts()


## Skor listesi girişi. mod/zorluk biten koşunun sonuç sözlüğünden (stats.mode/diff), yoksa geçerli seçimden.
func score_fields(stats: Dictionary, won: bool) -> Dictionary:
	var sel := selection()
	return {
		"score": int(stats.get("score", 0)),
		"time": floori(float(stats.get("time", 0.0))),
		"won": won,
		"level": int(stats.get("level", 1)),
		"unix": int(Time.get_unix_time_from_system()),
		"mode": str(stats.get("mode", sel["mode"])),
		"diff": str(stats.get("diff", sel["diff"])),
	}


## Gösterilecek skor listesi: verilen çift, ikisi de boşsa geçerli seçim. {"mode": StringName, "diff": StringName}.
func scores_key(mode: StringName = &"", diff: StringName = &"") -> Dictionary:
	if mode != &"" and diff != &"":
		return {"mode": mode, "diff": diff}
	return selection()


func _settings() -> Object:
	if _source != null:
		return _source
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null else null
