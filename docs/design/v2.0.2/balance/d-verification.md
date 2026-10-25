# v2.0.2 D — doğrulama (denge) raporu

> Bot dengesi ölçülüyor, oyun dengesi değil. Ölçümler kod değişmeden (sayı ayarı YAPILMADI) alındı.

## 1. Gunslinger ±%5 (kullanıcı kararı 2026-10-25: kanıt `kills5` + `hp_early`)

Koşu: `CHARS=gunslinger POLICIES="strong kite" bash tools/balance/mid_all.sh .mid` (3001-3400, 800/800), karşılaştırma `compare_baseline.py ... v201-A400` (`d-compare-gunslinger-400.md`). Önkoşul: temiz klonda `godot --headless --import` (yoksa sınıf adları çözülmez, koşu sessizce boş çıkar).

| politika | ölçüt | v2.0.1 | v2.0.2 | fark (%95 GA) | ±%5 | durum |
|---|---|---|---|---|---|---|
| strong | kills5 | 402,8 | 403,3 | +%0,1 (−0,3…+0,5) | içinde | **KABUL** |
| strong | hp_early | 0,999 | 0,999 | −%0,1 (−0,2…0,0) | içinde | **KABUL** |
| kite | kills5 | 363,9 | 357,4 | −%1,7 (−3,1…−0,4) | içinde | **KABUL** |
| kite | hp_early | 0,986 | 0,987 | +%0,1 (−0,3…+0,5) | içinde | **KABUL** |
| strong | survival | 679,5 | 688,8 | +%1,4 (−5,7…+6,2) | – | ölçülemedi (gürültü tabanı > bant) |
| strong | hp_mid | 0,144 | 0,190 | +%32 (−2…+81) | – | ölçülemedi (gürültü tabanı > bant) |
| kite | survival | 534,6 | 573,5 | +%7,3 (+1,5…+14,2) | – | ölçülemedi (gürültü tabanı > bant) |
| kite | hp_mid | 0,004 | 0,000 | −%100 (taban ≈ 0) | – | ölçülemedi (gürültü tabanı > bant) |

Karar survival/hp_mid'e dayanmaz.

**Sapma kaynağı.** v2.0.2 Gunslinger satırları dinamitsiz kolla (`v201-nodyn-A400`) **birebir aynı** (survival 688,8 / 573,5; kills5 403,3 / 357,4): "süzgeç/diğer" sütunu her ölçütte +%0,0. Yani v2.0.1'e göre tüm sapma Barutçu/dinamit kaldırmasından gelir; havuz ayrımı Gunslinger sonucunu değiştirmez (bot kararlarını da). Kite survival +%7,3'ün bir kısmı gürültü olabilir (A−B gürültüsü +%3,3).

## 2. Zyfen bandı (`d-dps-density.md`, `tools/balance/dps_density.gd`)

12 → 10/50/200 kukla ("crowd" düzeni), 20 sn. Toplam DPS = temel saldırı + beceri. Aşağıda **hedef dışı** olanlar:

| ölçüt | hedef | 10 | 50 | 200 | durum |
|---|---|---|---|---|---|
| ay_oragi ÷ bolunen_kesik sv5 | 1,8-2,2 | 3,24 | 3,12 | 4,39 | yüksek |
| gogun_mizragi ÷ delen_ruzgar sv5 | 1,8-2,2 | 1,94 | 1,80 | 1,93 | içinde |
| kasirga_patlamasi ÷ nefes_dalgasi sv5 | 1,8-2,2 | 1,96 | 2,34 | 2,57 | 50/200'de yüksek |
| tufan ÷ hortum sv5 | 1,8-2,2 | 1,64 | 1,60 | 1,48 | düşük |
| kasirga_patlamasi ÷ mermi_firtinasi | ≤ 3 | 0,9 | 3,3 | 12,5 | 50/200'de aşıyor |
| tufan ÷ mermi_firtinasi | ≤ 3 | 2,9 | 10,0 | 22,2 | 50/200'de aşıyor |

Gunslinger referansı kalabalıkta çok geniş dağılır (200'de aktifler 52…5002, evrimler 556…58461); mermi_firtinasi yoğunluktan bağımsız (556). Zyfen aktifleri 200'de: hortum 8356, nefes_dalgasi 2698, delen_ruzgar 1838, girdap 1529.

**Çelişki:** "evrim = aktif sv5 × 1,8-2,2" ile "Kasırga/Tufan ≤ 3 × mermi_firtinasi" 50/200 yoğunlukta birlikte sağlanamaz: 200'de sınır 3×556 ≈ 1668, oysa Hortum sv5 tek başına 8356, Nefes sv5 2698. Sağlamak için temel aktifleri de ~%80-90 kısmak gerekir.

## 3. Lord bütçesi (`d-lord-budget.md`, `tools/balance/lord_budget.gd`)

Hareketsiz Lord (45000 HP), 60 sn, 3 tohum, beceri farkı: Hortum sv5 **%6,8 / dk**; Tufan seti (Hortum sv5 + Fırtına Gözü + Tufan) **%20,8 / dk**. Sınır ≤ %25 → **karşılandı, `boss_mult` değişmedi** (1,0).

## 4. Diğer
- `docs/dev/user-verify/*.md` → `docs/dev/user-verify.md` bölüm L.
- Band raporu: `test/long/test_ver_v202_band.gd` (gate dışı).
