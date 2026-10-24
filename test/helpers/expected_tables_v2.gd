class_name ExpectedTablesV2
extends RefCounted
## v2.0 kabul beklenen tabloları. Kaynak: docs/plan/v2.0-plan.md "22 başarım (kesin liste)" ve Barutçu sözleşmesi.
## Kabul testleri veri JSON'unu OKUYARAK beklenti üretmez; sayılar buradan sabit alınır.

## [id, stat, target, tier, scope]
const ACHIEVEMENTS: Array = [
	["ilk_kan", "total_kills", 1, "kolay", "total"],
	["bes_dakika", "run_time", 300, "kolay", "run"],
	["seviye_10", "run_level", 10, "kolay", "run"],
	["yerlesik", "total_runs", 10, "kolay", "total"],
	["tambur_ustasi", "run_reloads", 100, "kolay", "run"],
	["alti_silah", "run_active_slots", 6, "kolay", "run"],
	["kirim", "run_kills", 500, "orta", "run"],
	["on_dakika", "run_time", 600, "orta", "run"],
	["seri_ustasi", "run_best_mult", 5, "orta", "run"],
	["piyade_avcisi", "run_elit_piyade", 1, "orta", "run"],
	["eklenti_avcisi", "run_pickups", 5, "orta", "run"],
	["dokunulmaz", "run_clean_secs", 180, "orta", "run"],
	["seviye_20", "run_level", 20, "orta", "run"],
	["kalabalik_kesici", "total_kills", 10000, "orta", "total"],
	["cifte_yol", "total_chars5", 2, "orta", "total"],
	["on_bes_dakika", "run_time", 900, "zor", "run"],
	["uc_elit", "run_elite_kinds", 3, "zor", "run"],
	["ilk_evrim", "run_evolutions", 1, "zor", "run"],
	["skor_100k", "run_score", 100000, "zor", "run"],
	["sinirsiz_kirim", "run_unlimited_kills", 100, "zor", "run"],
	["kale_lordu_devrildi", "run_won", 1, "cok_zor", "run"],
	["bomba_ustasi", "run_bomb_hits", 20, "cok_zor", "run"],
]
const TIER_COUNTS: Array = [6, 9, 5, 2]  # kolay, orta, zor, cok_zor

## Kapalı stat kümesi (20).
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

const ELITE_KINDS: PackedStringArray = ["elit_piyade", "elit_sovalye", "elit_karga"]
const NORMAL_ENEMY := &"curumus_piyade"

const BARUTCU := {
	"id": "barutcu",
	"name": "Barutçu",
	"max_hp": 120.0,
	"mag_cap": 5,
	"starting_skill": "dinamit",
}


static func row(id: String) -> Array:
	for r in ACHIEVEMENTS:
		if r[0] == id:
			return r
	return []


## Verilen stat'ı kullanan satırlar (hedefe göre artan).
static func rows_of(stat: String) -> Array:
	var out: Array = []
	for r in ACHIEVEMENTS:
		if r[1] == stat:
			out.append(r)
	return out
