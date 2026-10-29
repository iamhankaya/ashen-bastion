---
name: ab-ui-ekrani-ekle
description: Ashen Bastion'a Godot arayüz ekranı veya HUD öğesi eklerken (Godot Control ağacı, scripts/ui, UiKit, güvenli alan, Türkçe büyük harf, z-sırası, ekran görüntüsü öz-kontrolü) kullan; web tasarım skill'lerini kullanma.
---

# Godot UI ekranı / HUD öğesi

Bu bir **Godot Control ağacı** işidir; web/HTML tasarım skill'leri (impeccable, ui-ux-pro-max, design-taste-frontend) uymaz.

## Adımlar
1. **Tasarım dili:** `docs/ui/DESIGN-UI.md`, `docs/ui/tokens.json`, `docs/ui/ashen-bastion-theme.tres`, `docs/ui/mockups/`.
2. **Ekran:** `scripts/ui/<ad>_screen.gd` (kalıp: `scripts/ui/pause_screen.gd`, `characters_screen.gd`); denetleyici `scripts/ctrl/`. Satır tavanı tek tip **800** (`check_line_budget`); `scripts/ctrl/game_controller.gd` 784/800'dedir — oraya ekleme yapma, mantığı ayrı sınıfa al. Katman matrisi (`check_layers`): `ui` yalnız izinli katmanlara bağlanır; `ui → store/ctrl` yeni bağımlılığı `LAYER_VIOLATION` verir ve `tools/ci/layer_exceptions.txt` yalnız azalır (yeni istisna yazma; veriyi `domain`/görünüm modeli üzerinden al).
3. **Güvenli alan:** ana yerleşim/sütun dışına eklenen her öğe `apply_safe_area(extra)` kapsamına girer ve `test/unit/test_safe_area.gd` kalıbıyla test edilir (çentik altında kalma hatası: AYARLAR düğmesi).
3b. **Kaydırma kabı:** yalnız `UiKit.make_scroll(axis, opts)` (`name`, `follow_focus`, `deadzone`, `mouse_filter`, `show_bars`, `custom_min`; dokunma kaydırmasını da bağlar, ayrıca `touch_scroll` çağırma). Fabrika (`ui_kit.gd`) dışında doğrudan `ScrollContainer` örneği ve `.tscn`'de `type="ScrollContainer"` düğümü `check_ui_rules`'ta `UI_RULE` verir; istisna dosyası (`ui_rules_exceptions.txt`) boştur ve yalnız azalır.
4. **Türkçe büyük harf:** `UiKit.upper_tr` (`scripts/ui/ui_kit.gd`); `to_upper/to_lower` gate'te yasak.
5. **Z-sırası:** "görünmüyor" ise önce düğüm/çizim sırasını (z-order, `add_child` sırası) ekran görüntüsüyle kontrol et, sonra eksik asset düşün.
6. **Ekran görüntüsü öz-kontrolü:** xvfb ile `tools/capture/shots.gd` (1080×2400); karşılaştırma görüntüleri `docs/ui/screenshots/`.
7. **Cihaz listesi:** kendi bölüm dosyan `docs/dev/user-verify/…`; ortak listeye yazma.
8. **Doğrulama:** `bash tools/precheck.sh` (UI_RULES, LAYERS, LINE_BUDGET sınıfları; ayrıntı `ab-test-ve-kapi`) → push → CI. Yerleşim karakterizasyon bazları (`rf_ui_*_rects.json`: sonuç, karakterler, ayarlar, koşu) mevcut ekranların yerleşimini sabitler; bilerek değişiyorsa `baseline_changes.txt` gerekçesi gerekir. Önbellekli UI kaynağı (`UiKit`/`ArtLoader`) testlerde `clear_caches()` ile temizlenir.

## Dokunulan dosyalar
`scripts/ui/*.gd`, `scripts/ctrl/*.gd`, `docs/ui/*`, `tools/capture/shots.gd`, `test/unit/` (yeni UI testi).

## Kontrol listesi
- [ ] `apply_safe_area` + güvenli alan testi.
- [ ] `UiKit.upper_tr`; `to_upper` yok.
- [ ] Kaydırma kabı `UiKit.make_scroll` ile; fabrika dışı doğrudan `ScrollContainer` üretimi yok.
- [ ] Hiçbir `scripts/**/*.gd` > 800 satır; `game_controller.gd` payı (784/800) korundu; `layer_exceptions.txt`'e satır eklenmedi.
- [ ] `rf_ui_*` bazları değişmedi ya da gerekçeli (`baseline_changes.txt`).
- [ ] Z-order ekran görüntüsüyle doğrulandı.
- [ ] Paralel fazlarda ortak kullanıcı listesine yazılmadı.
- [ ] Yeni görsel gerekiyorsa `ab-gorsel-ikon-uret` (onaysız repoya girmez).

## Örnek
`scripts/ui/characters_screen.gd` (vitrin, `apply_safe_area` satır 455), `scripts/ui/achievements_screen.gd`.
