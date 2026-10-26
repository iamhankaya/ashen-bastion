---
name: ab-basarim-ekle
description: Ashen Bastion'a başarım eklerken veya karakter kilidi bağlarken (data/achievements.json, stat, tier, ikon, sayı sınırı) kullan.
---

# Başarım ekle

## Adımlar
1. **Kayıt:** `data/achievements.json` — `id`, `name` (≤ 22), `desc` (≤ 60), `stat` (kapalı küme `AchievementDef.STATS`, `scripts/sim/achievement_def.gd`), `target`, `scope` (`total|run`), `tier`, `icon`. Toplam başarım sayısı 15..25 (şu an 22). Örnek kayıt: `ilk_kan`.
2. **Yeni stat gerekiyorsa** (kapalı küme): `STATS` + `scripts/ctrl/achievement_tracker.gd` + `scripts/ctrl/achievement_progress.gd` kod işidir; kapsamı raporla.
3. **İkon:** `assets/ui/achievements/<id>.png` (`ab-gorsel-ikon-uret`; `mipmaps/generate=true`); kilitli görünüm `assets/shaders/ach_locked.gdshader`.
4. **Karakter kilidi:** karakter JSON'unda `unlock: {"achievement": "<id>"}` (`ab-karakter-ekle`).
5. **Testler:** `test/acceptance/test_acc_v2_ach_*`, `test/unit/test_achievement_icons.gd`.
6. `bash tools/gate.sh`.

## Dokunulan dosyalar
`data/achievements.json`, `assets/ui/achievements/`, `scripts/sim/achievement_def.gd`, `scripts/ctrl/achievement_tracker.gd`, `scripts/ctrl/achievement_progress.gd`, `scripts/ui/achievements_screen.gd`, `test/unit/test_achievement_icons.gd`.

## Kontrol listesi
- [ ] Sayı sınırı 15..25 korundu.
- [ ] Başarım kaydı/ayar durumuna yazan test `after_each` ile geri alır.
- [ ] Başarım ekranı yeni öğe için `apply_safe_area` kapsamında.
- [ ] İkon `.import` commit'li; lisansı belirsiz görsel yok.
