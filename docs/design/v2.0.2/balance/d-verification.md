# v2.0.2 D — doğrulama (denge) raporu

> Bot dengesi ölçülüyor, oyun dengesi değil. Bölüm 1 ve 2'nin 'önce' tablosu sayı ayarından önce alındı; ayar bölüm 5'te (kullanıcı kararı: Seçenek A).

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

> Bölüm 2 tablosu **ayardan önceki** durumdur (`d-dps-density-before.md`); ayar sonrası tablo `d-dps-density.md`.

## 3. Lord bütçesi (`d-lord-budget.md`, `tools/balance/lord_budget.gd`)

Hareketsiz Lord (45000 HP), 60 sn, 3 tohum, beceri farkı: Hortum sv5 **%6,8 / dk**; Tufan seti (Hortum sv5 + Fırtına Gözü + Tufan) **%20,8 / dk** (ayardan önce), ayardan sonra **%21,6 / dk**. Sınır ≤ %25 → **karşılandı, `boss_mult` değişmedi** (1,0).

## 4. Diğer
- `docs/dev/user-verify/*.md` → `docs/dev/user-verify.md` bölüm L.
- Band raporu: `test/long/test_ver_v202_band.gd` (gate dışı).

## 5. Ayar (kullanıcı kararı 2026-10-25: Seçenek A)

Yalnız `data/skills/*.json`: `ay_oragi.damage_mult` 3,5 → 2,0; `tufan.damage` 16 → 20 (+%25); `kasirga_patlamasi.damage` 40 → 36 (−%10; −%15 denemesi Kasırga'yı 10 yoğunlukta 1,74'e, banda girmeden düşürdü). Gunslinger dosyalarına dokunulmadı.

| ölçüt | hedef | 10 | 50 | 200 |
|---|---|---|---|---|
| ay_oragi ÷ bolunen_kesik sv5 | 1,8-2,2 | 2,04 | 1,94 | **2,75** |
| gogun_mizragi ÷ delen_ruzgar sv5 | 1,8-2,2 | 1,94 | 1,80 | 1,93 |
| kasirga_patlamasi ÷ nefes_dalgasi sv5 | 1,8-2,2 | 1,81 | 2,14 | **2,34** |
| tufan ÷ hortum sv5 | 1,8-2,2 | 2,01 | 1,98 | 1,83 |
| kasirga_patlamasi ÷ mermi_firtinasi (≤ 3 yalnız 10'da) | ≤ 3 | 0,82 | 3,0 (bilgi) | 11,3 (bilgi) |
| tufan ÷ mermi_firtinasi (≤ 3 yalnız 10'da) | ≤ 3 | **3,56** | 12,4 (bilgi) | 27,5 (bilgi) |

Kalan sapmalar (karar ölçütü gereği raporlanır, ayarlanmadı): Ay Orağı 200'de 2,75 (delme: hilal PIERCE_ALL, yoğunlukla orantılı büyür; 10/50'yi bantta tutan değerle 200 bandın üstünde kalır). Kasırga 200'de 2,34. **Tufan 10 yoğunlukta 3,56× > 3×**: Hortum sv5'in 10'daki DPS'i 868, evrimin ≥ 1,8× olması için ≥ 1563 gerekir = Mermi Fırtınası'nın 3,18×'i; iki ölçüt 10'da da birlikte sağlanamaz (Tufan'ı 3× altına çekmek oranı 1,69'a düşürür). Oran öncelendi.

"Gunslinger ±%15" bilgi olarak: eşleşme tablosu verilmedi; Gunslinger 200 yoğunlukta aktifler 52…5002, evrimler 556…58461 aralığında, Zyfen aktifleri 507…8356, evrimleri 1394…15309 — Zyfen aralığı Gunslinger'ın içinde, uç değerlere ulaşmıyor.

Altın hash: `zyfen_u3` aynı anahtarla yeniden kaydedildi (tohum 23 ve 37 değişti; 11 aynı kaldı). Gunslinger altın hash'leri değişmedi (u3 = u1b yeşil).
Lord bütçesi ayardan sonra: Tufan seti %21,6 / dk (≤ %25).
