---
name: ab-ui-ekrani-ekle
description: Ashen Bastion'a Godot arayüz ekranı veya HUD öğesi eklerken (Godot Control ağacı, scripts/ui, UiKit, güvenli alan, Türkçe büyük harf, z-sırası, ekran görüntüsü öz-kontrolü) kullan; web tasarım skill'lerini kullanma.
---

# Godot UI ekranı / HUD öğesi

Bu bir **Godot Control ağacı** işidir; web/HTML tasarım skill'leri (impeccable, ui-ux-pro-max, design-taste-frontend) uymaz.

## Adımlar
1. **Tasarım dili:** `docs/ui/DESIGN-UI.md`, `docs/ui/tokens.json`, `docs/ui/ashen-bastion-theme.tres`, `docs/ui/mockups/`.
2. **Ekran:** `scripts/ui/<ad>_screen.gd` (kalıp: `scripts/ui/pause_screen.gd`, `characters_screen.gd`); denetleyici `scripts/ctrl/`. `scripts/ctrl/game_controller.gd` satır tavanındadır (946/960) — oraya ekleme yapma, mantığı ayrı sınıfa al.
3. **Güvenli alan:** ana yerleşim/sütun dışına eklenen her öğe `apply_safe_area(extra)` kapsamına girer ve `test/unit/test_safe_area.gd` kalıbıyla test edilir (çentik altında kalma hatası: AYARLAR düğmesi).
4. **Türkçe büyük harf:** `UiKit.upper_tr` (`scripts/ui/ui_kit.gd`); `to_upper/to_lower` gate'te yasak.
5. **Z-sırası:** "görünmüyor" ise önce düğüm/çizim sırasını (z-order, `add_child` sırası) ekran görüntüsüyle kontrol et, sonra eksik asset düşün.
6. **Ekran görüntüsü öz-kontrolü:** xvfb ile `tools/capture/shots.gd` (1080×2400); karşılaştırma görüntüleri `docs/ui/screenshots/`.
7. **Cihaz listesi:** kendi bölüm dosyan `docs/dev/user-verify/…`; ortak listeye yazma.
8. `bash tools/gate.sh`.

## Dokunulan dosyalar
`scripts/ui/*.gd`, `scripts/ctrl/*.gd`, `docs/ui/*`, `tools/capture/shots.gd`, `test/unit/` (yeni UI testi).

## Kontrol listesi
- [ ] `apply_safe_area` + güvenli alan testi.
- [ ] `UiKit.upper_tr`; `to_upper` yok.
- [ ] `game_controller.gd` satır tavanı aşılmadı (pipeline sürerken main'den gelen düzeltmeler için pay bırak).
- [ ] Z-order ekran görüntüsüyle doğrulandı.
- [ ] Paralel fazlarda ortak kullanıcı listesine yazılmadı.
- [ ] Yeni görsel gerekiyorsa `ab-gorsel-ikon-uret` (onaysız repoya girmez).

## Örnek
`scripts/ui/characters_screen.gd` (vitrin, `apply_safe_area` satır 455), `scripts/ui/achievements_screen.gd`.
