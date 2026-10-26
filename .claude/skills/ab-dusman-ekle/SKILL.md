---
name: ab-dusman-ekle
description: Ashen Bastion'a yeni düşman, elit veya boss eklerken (data/enemies JSON, tek sabit görsel, atlas sınırı, waves.json satırı, hareket kipi) kullan.
---

# Düşman / elit / boss ekle

Düşmanlar **tek sabit görsel + kodla hareket**tir (kare animasyonu yok).

## Adımlar
1. **Veri:** `data/enemies/<id>.json` — `ai` (örn. `air`), `sprite`, `display_height`, `tint`, `anim.kind` (`crawl|flap|float|stomp`) ve anim alanları. Örnek: `data/enemies/les_kargasi.json`.
2. **Görsel:** tek PNG (`assets/gfx/enemies/<id>.png`), `python3 tools/art/process_art.py --only <id>` (`tools/art/art_manifest.json`); ya da mevcut sprite'ı paylaş + `tint`. Görsel kullanıcı makinesinde Codex ile üretilir, onaysız repoya girmez (`ab-gorsel-ikon-uret`).
3. **Atlas sınırı:** en çok 16 hücre (`ATLAS_CELLS_MAX`, `scripts/sim/data_v2.gd`; `scripts/view/enemy_atlas.gd`, shader `cell_rect[16]`). Son ekleme v1'de bu sınırın tuzağıdır; 17. düşman veri doğrulamada kırmızı verir.
4. **Dalga:** `data/waves.json` satırı (`rate|group|burst`); elit `at < end_time`, Lord `at == end_time`.
5. **Test:** tablo testleri + `test/acceptance/test_acc_waves.gd`; botlar (`test/helpers/bots.gd`) ve kısa koşular; denge → `ab-denge-olcumu`.
6. `bash tools/gate.sh`.

## Dokunulan dosyalar
`data/enemies/<id>.json`, `data/waves.json`, `assets/gfx/enemies/`, `assets/gfx/manifest.json`, `tools/art/art_manifest.json`, `test/acceptance/test_acc_waves.gd`, `test/helpers/bots.gd`.

## Kontrol listesi
- [ ] Atlas ≤ 16 hücre.
- [ ] Harita/çarpışma/hareket etkisi varsa bot hareketi ve kısa koşu testleri aynı fazda.
- [ ] Bilinen açığı sabitleyen test `karakterizasyon (F-xxx)`; kabul testi kusuru beklenen değer yapmaz.
- [ ] Sim değiştiyse altın hash etkisi raporlandı.
- [ ] Denge kayması açık noktaya.
