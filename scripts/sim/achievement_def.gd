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
]
## Kademeler (zorluk sırası); JSON'da ASCII yazılır (`cok_zor`).
const TIERS: PackedStringArray = ["kolay", "orta", "zor", "cok_zor"]
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
	return a


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
