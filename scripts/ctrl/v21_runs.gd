class_name V21Runs
extends RefCounted
## v2.1 koşu modu/zorluk köprüsü: controller'ın TEK girişi (K-C8). Seçim Settings'te (run_mode/run_diff), profiller
## data/run_profiles.json'da (RunProfiles). Controller yalnız C fazında bağlanır; sonraki fazlar bu dosyaya
## yalnız kendi `# --- <faz> ---` bölümlerini ekler (U2: mantık, U3: kayıt çağrıları, U4a: seçim).

## Testler için: Settings autoload yerine kullanılacak nesne (run_mode/run_diff/save_settings olan herhangi bir nesne).
static var settings_override: Object = null
static var _profiles: Dictionary = {}


## Doğrulanmış profil verisi (ilk çağrıda yüklenir). Dosya hatalıysa {} (çağıranlar legacy'ye düşer).
static func profiles() -> Dictionary:
	if _profiles.is_empty():
		_profiles = RunProfiles.load_default()["profiles"]
	return _profiles


## Testler için önbelleği boşaltır.
static func reset_cache() -> void:
	_profiles = {}


## {"mode": StringName, "diff": StringName}: Settings'teki seçim; Settings yoksa dosya varsayılanı (Normal/Normal).
static func selection() -> Dictionary:
	var st := _settings()
	if st == null:
		return RunProfiles.default_selection(profiles())
	return {"mode": StringName(st.run_mode), "diff": StringName(st.run_diff)}


## Seçimi kaydeder ve yazar. Bilinmeyen mod/zorluk adı sessizce yok sayılır.
static func set_selection(mode: StringName, diff: StringName) -> void:
	var st := _settings()
	if st == null or not RunProfiles.MODES.has(mode) or not RunProfiles.DIFFS.has(diff):
		return
	st.run_mode = String(mode)
	st.run_diff = String(diff)
	st.save_settings()


## GameSim opts'u: seçili profilin end_mode/end_time/run_profile'ı. Profil kurulamazsa bugünkü RUN_OPTS (legacy).
static func run_opts() -> Dictionary:
	var sel := selection()
	var p := RunProfile.make(sel["mode"], sel["diff"], profiles())
	return (p if p != null else RunProfile.legacy()).opts()


## Kazanma: Lord/Zamanlayıcı'da sim WON; Sonsuz'da ilk Lord ölümü (`milestone_won`, sim LOST kalır).
static func run_won(sim: GameSim) -> bool:
	return sim != null and (sim.state == GameSim.State.WON or sim.milestone_won)


## Skor listesi girişi. mod/zorluk biten koşunun sonuç sözlüğünden (stats.mode/diff), yoksa geçerli seçimden.
static func score_fields(stats: Dictionary, won: bool) -> Dictionary:
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
static func scores_key(mode: StringName = &"", diff: StringName = &"") -> Dictionary:
	if mode != &"" and diff != &"":
		return {"mode": mode, "diff": diff}
	return selection()


static func _settings() -> Object:
	if settings_override != null:
		return settings_override
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null else null


# --- U3 (kayıt/başarım) ----------------------------------------------------------------------


## Zorluğa bağlı başarım kuralı (run_profiles.json "achievements"); profil dosyası hatalıysa kısıtsız.
static func achievement_rules() -> AchievementRules:
	return AchievementRules.new(profiles())


## Sim'in koşu zorluğu; profilsiz sim = Zor (sonuç sözlüğüyle aynı varsayılan).
static func diff_of(sim: GameSim) -> StringName:
	return sim.run_profile.diff if sim != null and sim.run_profile != null else &"hard"
