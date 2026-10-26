---
name: ab-efekt-shader
description: Ashen Bastion'da efekt/shader eklerken veya değiştirirken (katmanlı doku parçaları, WindRenderer/ProjectileRenderer/FxRenderer, gölgelendirici, harman, perf bütçesi, ekran görüntüsü karşılaştırması) kullan.
---

# Katmanlı efekt / shader

Efektler **kodla ve katmanlı dokularla** çizilir; her parçanın animasyonu sim zamanının saf fonksiyonudur. **Sim'e dokunma** (altın hash değişmemeli). Örnek: Zyfen (`fx_v2`).

## Katmanlı yöntem
- Mermi = gövde + iz + parıltı + kırılma. Bölge = arka gövde + döşenebilir akış + taban + yörünge taşları + şimşek.
- Doku parçaları kullanıcı makinesinde Codex ile üretilir ve repoya girmeden kullanıcıya gösterilir (`ab-gorsel-ikon-uret`); kaynak `art/source/<ad>/fx_v2/`.

## Adımlar
1. **Z-sırası önce:** "görünmüyor" teşhisinde önce düğüm/çizim sırası (z-order, `add_child` sırası) ekran görüntüsüyle bakılır, sonra eksik asset düşünülür.
2. **Doku işleme:** `python3 tools/art/process_zyfen_fx.py [--check]` (mermi/bölge 512, akış 256, taş/parıltı 128; her kenarda ≥ %8 şeffaf pay). Çıktı `assets/gfx/fx/zyfen/`. Yeni karakter için aynı kalıpla araç/manifest genişlet.
3. **Kimlikler:** `scripts/view/zyfen_fx.gd` (`ALL`, `ADDITIVE_PROJECTILES`, `ZONES_ADDITIVE`, `GRADE_*`). Renderer'lar: `scripts/view/projectile_renderer.gd`, `wind_renderer.gd`, `fx_renderer.gd`; shader'lar `assets/shaders/wind_flow.gdshader`, `wind_spear.gdshader`, `wind_body.gdshader`.
4. **Harman:** bölgeler alfa, mermiler additive; ekran görüntüsüyle seç.
5. **Perf bütçesi:** `MAX_DRAWN = 24`, `MAX_DRAW_CALLS = 110`, `MAX_BODY_SCREEN` (`wind_renderer.gd`); bütçe dosyaları `tools/perf_budget.json`, `tools/perf_budget_zyfen.json`; kalabalıkta taş/şimşek sayısı düşürülür.
6. **Ekran görüntüsü:** xvfb ile `tools/capture/shots_zyfen_fx.gd` (`SEED=20261025`) → `docs/design/<sürüm>/fx-vN/`.
7. **Cihaz ince ayarı:** kendi bölüm dosyan `docs/dev/user-verify/<sürüm>-fx-tuning.md` kalıbı; ortak listeye yazma.

## Doğrulama
`python3 -m pytest -q -p no:cacheprovider tools/art/tests/test_process_zyfen_fx.py`; GUT `test/unit/test_v202_a2a_assets.gd`, `test_v202_wind_renderer.gd`, `test_v202_wind_perf.gd`; `GATE_RENDER=1 bash tools/gate.sh`; cihaz maddeleri.

## Kontrol listesi
- [ ] Cihazda görülebilecek görsel hata için debug APK bayrağı + sayaç etiketi (ör. "düzeltme AÇIK/KAPALI").
- [ ] Z-order/`add_child` sırası kontrol edildi.
- [ ] Geçici çıktı klasörü (`tools/art/_preview/`, ekran görüntüsü ham çıktıları) `.gitignore`'da.
- [ ] Sim ve altın hash değişmedi.
- [ ] Perf bütçesi testleri yeşil.
- [ ] Lisansı belirsiz doku eklenmedi.
