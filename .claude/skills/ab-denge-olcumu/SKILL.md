---
name: ab-denge-olcumu
description: Ashen Bastion'da denge ayarı veya ölçümü (bot koşuları, tools/balance, Gunslinger ±%5 kanıtı, DPS yoğunluk bandı, Lord bütçesi, tohum kümeleri) gerektiğinde kullan.
---

# Denge ölçümü

Botlar bot dengesini ölçer; kullanıcının cihaz geri bildirimi ("oyun zor") ile çelişirse çelişkiyi raporda açıkça yaz. Ayar yalnız `data/**` üzerinden.

## Adımlar
1. **Ölçütü netleştir:** karar ölçütleri `kills5` ve `hp_early`; `survival`/`hp_mid` bilgi amaçlı.
2. **Taban (değişmez):** `bash tools/balance/baseline_run.sh` (A = 1001–1060, B = 2001–2060 tohumları).
3. **Yeni kod:** `POLICIES="strong kite" CHARS=gunslinger bash tools/balance/mid_all.sh .mid` (400 tohum; tohum listeleri `tools/balance/seeds_v202.txt`).
4. **Karşılaştır:** `python3 tools/balance/compare_baseline.py <taban> <yeni> --noise <B> --nodyn <nodyn>` (taban dosyaları `docs/design/v2.0.2/balance/baseline-v201-A400.jsonl`, `…-B400.jsonl`, `…-nodyn-A400.jsonl`; `<yeni>` = `mid_all.sh` çıktı dizini); Gunslinger farkı ±%5 içinde olmalı.
5. **Yeni karakter bandı:** `tools/balance/dps_density.gd`, `test/long/test_ver_v202_band.gd`, `tools/balance/lord_budget.gd`; A/B: `tools/balance/ab_all.sh`.
6. **Rapor:** `docs/design/<sürüm>/balance/` (örnek `docs/design/v2.0.2/balance/`). Ham çıktı klasörü (`.mid/` vb.) **aynı commit'te** `.gitignore`'a.

## Dokunulan dosyalar
`test/helpers/bots.gd`, `tools/balance/*`, `scripts/sim/difficulty.gd`, `data/waves.json`, `data/skills/*.json`, `test/fixtures/golden_hashes.json`.

## Kontrol listesi
- [ ] Önce/sonra aynı tohumlarla; beklenmeyen kayma kapsam dışı sayılmaz, açık noktaya.
- [ ] Harita/çarpışma değiştiyse bot hareketi ve kısa koşu kabul testleri aynı fazda.
- [ ] Bulguya bağlı davranış sabitleyen test `karakterizasyon (F-xxx)`; kabul testi kusuru beklenen değer yapmaz.
- [ ] Ölçüm aracı çıktısı `.gitignore`'da (daha önce `.mid/` 80 dosya commit'lenmişti).
- [ ] Sim değiştiyse altın hash etkisi raporlandı.

## Örnek
Zyfen ±%5 kanıtı: `docs/design/v2.0.2/balance/` altındaki raporlar.
