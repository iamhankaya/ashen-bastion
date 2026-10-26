class_name AchievementDef
extends RefCounted
## Başarım tanımı (data/achievements.json kaydı). Şema: docs/data-schema.md. Sim'den bağımsız; yalnız veri tipi.

## Kapalı `stat` kümesi (kapsam: total = koşular arası toplam, run = tek koşu). Yeni stat = kod + tracker işi.
const STATS: PackedStringArray = [
	"total_kills",
	"total_runs",
	"total_wins",
	"total_play_secs",
	"total_chars5",
	"run_kills",
	"run_time",
	"run_level",
	"run_score",
	"run_reloads",
	"run_active_slots",
	"run_best_mult",
	"run_elit_piyade",
	"run_elite_kinds",
	"run_pickups",
	"run_clean_secs",
	"run_evolutions",
	"run_unlimited_kills",
	"run_won",
	"run_bomb_hits",
	"total_boss_kills",  # v2.0.3
]
## Kademeler (zorluk sırası); JSON'da ASCII yazılır (`cok_zor`).
const TIERS: PackedStringArray = ["kolay", "orta", "zor", "cok_zor"]
## v2.0.3 aşamalı şema: bir kayıt = bir aile; `steps` 1..MAX_STEPS artan eşik, `group` ekran grubu, `legacy` eski kimlik -> kademe (1'den).
const MAX_STEPS := 5
const GROUPS: PackedStringArray = [
	"THE WATCH", "THE CULLING", "THE CROWNED", "THE ARMORY", "THE ROAD"
]
## v2.0.2'de kayıtlı 22 başarım kimliği; `legacy` yalnız bunlara başvurabilir (kayıt göçü).
const LEGACY_IDS: PackedStringArray = [
	"ilk_kan",
	"bes_dakika",
	"seviye_10",
	"yerlesik",
	"tambur_ustasi",
	"alti_silah",
	"kirim",
	"on_dakika",
	"seri_ustasi",
	"piyade_avcisi",
	"eklenti_avcisi",
	"dokunulmaz",
	"seviye_20",
	"kalabalik_kesici",
	"cifte_yol",
	"on_bes_dakika",
	"uc_elit",
	"ilk_evrim",
	"skor_100k",
	"sinirsiz_kirim",
	"kale_lordu_devrildi",
	"bomba_ustasi",
]
## stat -> depo alanı: `total_*` için `totals`, `run_*` için `best` (koşu en iyisi). Kaynağı olmayan stat bu tablolarda yoktur.
const TOTAL_KEY := {
	"total_kills": "kills",
	"total_runs": "runs",
	"total_wins": "wins",
	"total_play_secs": "play_secs",
	"total_boss_kills": "boss_kills",
}
const BEST_KEY := {
	"run_time": "time",
	"run_level": "level",
	"run_score": "score",
	"run_kills": "kills",
	"run_reloads": "reloads",
	"run_active_slots": "active_slots",
	"run_best_mult": "mult",
	"run_elite_kinds": "elite_kinds",
	"run_pickups": "pickups",
	"run_clean_secs": "clean_secs",
	"run_evolutions": "evolutions",
	"run_unlimited_kills": "unlimited_kills",
	"run_bomb_hits": "bomb_hits",
}
const SCOPE_RUN := &"run"
const SCOPE_TOTAL := &"total"

var id: StringName = &""
var display_name: String = ""
var desc: String = ""
var stat: StringName = &""
var target: int = 0
var scope: StringName = &""
var tier: StringName = &""
var icon: String = ""
var steps: Array[int] = []
var group: StringName = &""
var legacy: Dictionary = {}


static func from_dict(d: Dictionary) -> AchievementDef:
	var a := AchievementDef.new()
	a.id = StringName(_s(d.get("id", "")))
	a.display_name = _s(d.get("name", ""))
	a.desc = _s(d.get("desc", ""))
	a.stat = StringName(_s(d.get("stat", "")))
	var t: Variant = d.get("target", 0)
	a.target = int(t) if (t is int or t is float) and is_finite(float(t)) else 0
	a.scope = StringName(_s(d.get("scope", "")))
	a.tier = StringName(_s(d.get("tier", "")))
	a.icon = _s(d.get("icon", ""))
	var st: Variant = d.get("steps", [])
	if st is Array:
		for v in st:
			if v is int or (v is float and is_finite(v)):
				a.steps.append(int(v))
	a.group = StringName(_s(d.get("group", "")))
	var lg: Variant = d.get("legacy", {})
	a.legacy = (lg as Dictionary).duplicate() if lg is Dictionary else {}
	return a


## Kademe eşikleri: `steps`, yoksa tek kademe `target` (v2.0 kaydı); ikisi de yoksa boş.
func thresholds() -> Array[int]:
	if not steps.is_empty():
		return steps
	var out: Array[int] = []
	if target > 0:
		out.append(target)
	return out


## &"run" | &"total"; bilinmeyen stat için &"".
static func scope_of(p_stat: StringName) -> StringName:
	if not STATS.has(String(p_stat)):
		return &""
	return SCOPE_TOTAL if String(p_stat).begins_with("total_") else SCOPE_RUN


## 0..3 (kolay..cok_zor); bilinmeyen kademe -1.
static func tier_index(p_tier: StringName) -> int:
	return TIERS.find(String(p_tier))


static func _s(v: Variant) -> String:
	return v if v is String else ""
