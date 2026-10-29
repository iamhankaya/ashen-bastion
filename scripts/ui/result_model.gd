class_name ResultModel
extends RefCounted
## Sonuç ekranı saf veri mantığı (R5b): rekor türü, döküm satırı değerleri, başarım çipi metni, sıra/alt başlık satırları.
## Düğüm yok, durum yok; sabitler ve gövdeler `result_screen.gd`den AYNEN taşındı.

const MAX_COMBOS := 4
const EMPTY_TEXT := "Bu seferlik kombo yok."
const LOST_SUB := "Kale seni yuttu."
const WON_SUB := "Düşmüş Kale Lordu devrildi."
## v2.0 (B4) yeni başarım çipi varken kombolar en çok bu kadar satır.
const CHIP_MAX_COMBOS := 4
## v2.1 Kolay notu metni.
const EASY_NOTE := "Kolay: bu koşu Lord başarımlarına ve toplam sayaçlara yazılmadı."
const DISPLAY_CAP := 99999999


## Sıra satırı: "Normal · Zor listesinde 3. sıra" (Mod · Zorluk); mod/zorluk bilinmiyorsa boş.
static func rank_line(mode: StringName, diff: StringName, rank: int) -> String:
	if rank <= 0 or RunStrip.mode_title(mode) == "" or RunStrip.diff_title(diff) == "":
		return ""
	return (
		"%s · %s listesinde %d. sıra" % [RunStrip.mode_title(mode), RunStrip.diff_title(diff), rank]
	)


## Sonsuz zaferinde alt başlık: "Lord'u devirdin; sonra 7:48 daha dayandın."; kilometre taşı yoksa boş.
static func endless_sub(time: float, milestone_t: float) -> String:
	if milestone_t < 0.0 or time < milestone_t:
		return ""
	return "Lord'u devirdin; sonra %s daha dayandın." % MilestoneBand.mss(time - milestone_t)


## Görünen kombo tavanı: yeni başarım çipi varken CHIP_MAX_COMBOS, yoksa MAX_COMBOS.
static func combo_cap(has_new_achievements: bool) -> int:
	return CHIP_MAX_COMBOS if has_new_achievements else MAX_COMBOS


## &"none" | &"record" | &"top10" | &"outside" (Highscores.submit sonucundan; {} = rekor bilgisi yok).
static func record_kind(rec: Dictionary) -> StringName:
	var rank := int(rec.get("rank", 0))
	if rec.is_empty():
		return &"none"
	if rank == 1 and bool(rec.get("is_record", false)):
		return &"record"
	if rank >= 2:
		return &"top10"
	if rank == 0 and int(rec.get("needed_for_top10", 0)) > 0:
		return &"outside"
	return &"none"


## Döküm satırı verisi (5 satır): hedef değerler, "+" öneki, soluk/çizgi bayrakları, ayrıntı metinleri.
static func rows(stats: Dictionary, won: bool) -> Dictionary:
	var parts: Dictionary = stats.get("score_parts", {})
	var evo_n := (stats.get("evolutions", []) as Array).size()
	var lord := int(parts.get("lord", 0))
	var evo := int(parts.get("evolution", 0))
	var vals: Array[int] = [
		int(parts.get("kills", 0)),
		int(parts.get("streak", 0)),
		evo,
		int(parts.get("survival", 0)),
		lord,
	]
	var plus: Array[bool] = [false, true, true, true, true]
	var dim: Array[bool] = [false, false, evo == 0, false, lord == 0]
	var dash: Array[bool] = [false, false, false, false, lord == 0]
	var details: Array[String] = [
		"",
		"en yüksek ×%d" % int(stats.get("best_mult", 1)),
		"%d evrim" % evo_n,
		UiKit.format_time(float(stats.get("time", 0.0))),
		"" if (lord > 0 or won) else "Lord'u yen",
	]
	return {"vals": vals, "plus": plus, "dim": dim, "dash": dash, "details": details}


## Başarım çipi metni: {title, names, a11y}. `steps` >= 0 (aile/kademe kaydı): başlık "YENİ KADEME · steps".
static func chip_texts(names: Array[String], steps: int) -> Dictionary:
	var n := names.size()
	var shown := ", ".join(names.slice(0, 2))
	if n > 2:
		shown += " +%d" % (n - 2)
	return {
		"title": "YENİ KADEME · %d" % steps if steps >= 0 else "YENİ BAŞARIM · %d" % n,
		"names": shown,
		"a11y":
		(
			"%d %s: %s"
			% [
				steps if steps >= 0 else n,
				"yeni kademe" if steps >= 0 else "yeni başarım",
				", ".join(names)
			]
		),
	}
