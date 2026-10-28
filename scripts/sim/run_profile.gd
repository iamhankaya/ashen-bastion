class_name RunProfile
extends RefCounted
## v2.1 koşu profili: (mod, zorluk) -> çarpanlar ve bitiş kuralı. Saf veri; `opts.run_profile` ile GameSim'e girer.
## Profil yoksa (null) ya da `is_legacy()` ise sim bugünkü davranışı BİREBİR sürdürür (RNG/hash baytı değişmez).
## Sözleşme (C fazı): alanlar ve imzalar sabit; çarpanların sim'e uygulanması U2'dedir. Kurallar: docs/data-schema.md.

var mode: StringName = &"normal"
var diff: StringName = &"hard"
var end_mode: String = GameSim.END_MODE_LORD
## Mod: süre ölçeği (Hızlı 0,5). `curve_t(t) = t / time_scale`.
var time_scale: float = 1.0
## Mod: XP ve Lord HP çarpanı, `rate` satırı çarpanı.
var xp_mult: float = 1.0
var lord_hp_mult: float = 1.0
var rate_mult: float = 1.0
## Zorluk: düşman HP/temas hasarı/doğuş yoğunluğu/XP/Lord HP çarpanı.
var enemy_hp: float = 1.0
var enemy_dmg: float = 1.0
var spawn_density: float = 1.0
var xp: float = 1.0
var lord_hp: float = 1.0
## Yalnız Sonsuz (end_mode == endless); diğerlerinde 0.
var lord_repeat_sec: float = 0.0
var lord_repeat_hp_mult: float = 1.0
var lord_hp_cap_mult: float = 1.0
var enrage_after_sec: float = 0.0
var enrage_dmg_per_min: float = 0.0


## `cfg` = RunProfiles.load_default()["profiles"] (doğrulanmış). Bilinmeyen mod/zorluk adı için null.
static func make(p_mode: StringName, p_diff: StringName, cfg: Dictionary) -> RunProfile:
	var modes: Dictionary = cfg.get("modes", {})
	var diffs: Dictionary = cfg.get("difficulties", {})
	if not modes.has(String(p_mode)) or not diffs.has(String(p_diff)):
		return null
	var m: Dictionary = modes[String(p_mode)]
	var d: Dictionary = diffs[String(p_diff)]
	var p := RunProfile.new()
	p.mode = p_mode
	p.diff = p_diff
	p.end_mode = str(m.get("end_mode", GameSim.END_MODE_LORD))
	p.time_scale = float(m.get("time_scale", 1.0))
	p.xp_mult = float(m.get("xp_mult", 1.0))
	p.lord_hp_mult = float(m.get("lord_hp_mult", 1.0))
	p.rate_mult = float(m.get("rate_mult", 1.0))
	p.lord_repeat_sec = float(m.get("lord_repeat_sec", 0.0))
	p.lord_repeat_hp_mult = float(m.get("lord_repeat_hp_mult", 1.0))
	p.lord_hp_cap_mult = float(m.get("lord_hp_cap_mult", 1.0))
	p.enrage_after_sec = float(m.get("enrage_after_sec", 0.0))
	p.enrage_dmg_per_min = float(m.get("enrage_dmg_per_min", 0.0))
	p.enemy_hp = float(d.get("enemy_hp", 1.0))
	p.enemy_dmg = float(d.get("enemy_dmg", 1.0))
	p.spawn_density = float(d.get("spawn_density", 1.0))
	p.xp = float(d.get("xp", 1.0))
	p.lord_hp = float(d.get("lord_hp", 1.0))
	return p


## Bugünkü oyun: Normal mod + Zor, tüm çarpanlar 1, `time_scale` 1. Dosyaya bağlı değildir.
static func legacy() -> RunProfile:
	return RunProfile.new()


## true ise sim hiçbir ek işlem yapmaz (K-C10).
func is_legacy() -> bool:
	if end_mode != GameSim.END_MODE_LORD:
		return false
	for v in [
		time_scale,
		xp_mult,
		lord_hp_mult,
		rate_mult,
		enemy_hp,
		enemy_dmg,
		spawn_density,
		xp,
		lord_hp
	]:
		if not is_equal_approx(float(v), 1.0):
			return false
	return true


## Zorluk/hız eğrilerinin okunduğu süre.
func curve_t(t: float) -> float:
	return t / time_scale


## {"end_mode", "end_time", "run_profile"}: GameSim opts'una katılır. Hızlı: end_time 600 (1200·time_scale);
## Sonsuz: end_time 1200 (ilk Lord), end_mode "endless".
func opts() -> Dictionary:
	return {
		"end_mode": end_mode,
		"end_time": GameSim.DEFAULT_END_TIME * time_scale,
		"run_profile": self,
	}
