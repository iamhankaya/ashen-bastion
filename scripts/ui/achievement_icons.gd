class_name AchievementIcons
extends RefCounted
## Başarım ikonu çözümü: `icon` (geçerli res:// yolu) varsa o; yoksa `stat` ailesine göre mevcut ikon (yer tutucu, DESIGN §6.3).

const DIR := UiKit.ICON_DIR
## stat -> assets/ui/icons altındaki ad (uzantısız). Kapalı küme `AchievementDef.STATS`'ın tümü kapsanır.
const FAMILY := {
	"total_kills": "hud-oldurme",
	"total_runs": "hud-duraklat",
	"total_wins": "kiyamet-mermisi",
	"total_play_secs": "hud-sure",
	"total_chars5": "cift-tabanca",
	"run_kills": "hud-oldurme",
	"run_time": "hud-sure",
	"run_level": "hud-xp",
	"run_score": "agir-kursun",
	"run_reloads": "hud-mermi",
	"run_active_slots": "cift-tabanca",
	"run_best_mult": "mermi-firtinasi",
	"run_elit_piyade": "hud-oldurme",
	"run_elite_kinds": "hud-oldurme",
	"run_pickups": "miknatis",
	"run_clean_secs": "hud-can",
	"run_evolutions": "zincirleme-patlama",
	"run_unlimited_kills": "mermi-firtinasi",
	"run_won": "kiyamet-mermisi",
	"run_bomb_hits": "dinamit",
}


## Dönüş: Texture2D yolu ("" = ikonsuz).
static func path_for(def: AchievementDef) -> String:
	if def == null:
		return ""
	if def.icon.begins_with("res://") and ResourceLoader.exists(def.icon):
		return def.icon
	var base: String = FAMILY.get(String(def.stat), "")
	if base == "":
		return ""
	var p := DIR + base + ".svg"
	return p if ResourceLoader.exists(p) else ""


## Kademe rengi (DESIGN §5.1.1): kolay/orta/zor/çok zor.
static func tier_color(tier: StringName) -> Color:
	match String(tier):
		"kolay":
			return UiKit.KEMIK_300
		"orta":
			return UiKit.BRONZ_300
		"zor", "cok_zor":
			return UiKit.AMBER
	return UiKit.KEMIK_300
