---
name: ab-basarim-ekle
description: Ashen Bastion'a başarım eklerken veya karakter kilidi bağlarken (data/achievements.json aile/kademe şeması, stat, ikon, sayı sınırı, kayıt göçü) kullan.
---

# Başarım ekle (aile / kademe, v2.0.3)

Bir kayıt = bir **aile**; `steps` ile 1..5 kademe taşır ("10/50/250 düşman öldür" = tek aile, 3 kademe). Şema ve göç kuralları: `docs/data-schema.md` ("Başarım — aile/kademe", "C fazı notları").

## Adımlar
1. **Kayıt:** `data/achievements.json` — `id` (aile; `[a-z0-9_]`), `name` (≤ 22, **İngilizce, sabit büyük harf**; `upper_tr` kullanılmaz), `desc` (≤ 60, Türkçe), `stat` (kapalı küme `AchievementDef.STATS`), `scope` (`total|run`, stat'ın kapsamıyla aynı), `steps` (1..5 kesin artan eşik), `group` (`THE WATCH|THE CULLING|THE CROWNED|THE ARMORY|THE ROAD`), `icon` (isteğe bağlı; yoksa stat'a göre yedek ikon). `target`/`tier` aile kaydında YASAK. Örnek: `reaper`.
2. **Sınırlar:** aile sayısı **12..30**, toplam kademe **≤ 80** (şu an 19 aile / 53 kademe). `legacy` yalnız v2.0.2'nin 22 eski kimliği içindir; yeni aileye yazılmaz.
3. **Yeni stat gerekiyorsa** (kapalı küme; **yalnız SONA eklenir**, indeks sırası testle sabit): `STATS` + `AchievementTracker` (indeks sabiti, olay besleme, `_value`) + `AchievementDef.TOTAL_KEY/BEST_KEY` + `AchievementStore.TOTAL_KEYS/BEST_KEYS` + `AchievementRow.GOAL_TEXT` (sonraki hedef metni) + `AchievementIcons.FAMILY`. Kapsamı raporla; kayıt şeması değişirse göç testi ekle.
4. **İkon:** `assets/ui/achievements/<id>.png` (`ab-gorsel-ikon-uret`; `mipmaps/generate=true`). Kademe için ayrı ikon YOK: kademe plaka silüeti + Roma rozeti + segmentle gösterilir (`AchievementPlate`, `AchievementRow`).
5. **Karakter kilidi:** karakter JSON'unda `unlock: {"achievement": "<aile>"}` (kademe ≥ 1 açar; `ab-karakter-ekle`).
6. **Testler:** `test/unit/test_v203_c_*` (adım aritmetiği + veri tablosu, göç, tracker, ekran), `test_achievement_icons.gd`; yeni dosya eklersen `ab-test-ve-kapi` kayıtları. v2.0 tek eşikli kayıt testleri `AchKit.legacy_data()` (`test/fixtures/ach_v20/`) üzerinde koşar; gerçek veriye bağlama.
7. **Kuru deneme:** sahte bir aile ekleyip ekran/tracker/gate'i koş (mevcut testlerin sabit listeleri burada çıkar: aile/kademe sayıları `test_v203_c_steps.gd`, `docs/data-schema.md` tablosu).
   Yeni aile eklenince aile/kademe sayısına bağlı sabit listeler kırılır (kaynak: `docs/dev/v2.0.3-verification.md`, kuru deneme 1); bu 7 dosyayı baştan güncelle:
   `test_achievements_screen.gd` (aile sayısı, `0 / 53` toplamı, grup toplamı), `test_v203_c_tracker.gd`, `test_v203_c_steps.gd`, `test_acc_v203_ach_data.gd`, `test_v203_c_migration.gd`, `test_achievement_icons.gd`, `test_acc_v2_isolation.gd`.
   **Yeni aile ayrı stat kullanır:** mevcut bir stat'ı (ör. `total_kills`) paylaşan aile `reaper` tracker testlerini de kirletir; yeni aileye yeni stat aç (adım 3).
8. `bash tools/gate.sh`.

## Dokunulan dosyalar
`data/achievements.json`, `scripts/sim/achievement_def.gd`, `scripts/ctrl/achievement_{tracker,progress,step}.gd`, `scripts/store/achievement_{store,migration}.gd`, `scripts/ui/achievements_screen.gd`, `achievement_{row,plate,chronicle,toast,icons}.gd`, `assets/ui/achievements/`, testler.

## Kontrol listesi
- [ ] Aile 12..30, kademe toplamı ≤ 80, `steps` kesin artan.
- [ ] Eşiği değiştirilen/yeniden bölünen kimlik için kayıtlı kademe geri alınmıyor (`reconcile` sessiz verir); eski kayıt gerekiyorsa göç testi.
- [ ] Başarım kaydı/ayar durumuna yazan test `after_each` ile geri alır (`AchKit.cleanup`).
- [ ] Başarım ekranı yeni öğe için `apply_safe_area` kapsamında; ekran görüntüsü öz-kontrolü (`tools/capture/shots_ach.gd`).
- [ ] İngilizce adlar sabit büyük harf; `to_upper`/`upper_tr` kullanılmadı.
- [ ] İkon `.import` commit'li; lisansı belirsiz görsel yok.
