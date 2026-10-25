# v2.0.2 denge baseline (S2)

> Bot dengesi ölçülüyor, oyun dengesi değil.

Üç kol, hepsi Gunslinger, v2.0.1 commit `9833741`, politikalar `strong, kite` (gate ölçütü) + `greedy, idle` (bilgi; plandaki "fast" = greedy), tohumlar `tools/balance/seeds_v202.txt` (A: 1001-1060, B: 2001-2060). Ham satırlar `baseline-<kol>.jsonl` (kol başına 240 koşu = 4 politika × 60 tohum).

| Kol | İçerik |
|---|---|
| `v201-A` | v2.0.1, küme A |
| `v201-B` | aynı kod, küme B (gürültü tabanı = A ile B farkı) |
| `v201-nodyn-A` | v2.0.1 + `tools/balance/patches/no_dynamite.patch` (dinamit ve Barutçu verisi silinmiş; U1b'nin Gunslinger'a etkisini taklit eder), küme A |

Yeniden üretim (≈ 1 saat/kol 4 çekirdekte; yarıda kalan koşu aynı komutla sürer):
```
bash tools/balance/baseline_run.sh all
python3 tools/balance/compare_baseline.py docs/design/v2.0.2/balance/baseline-v201-A.jsonl <yeni A koşusu> \
    --noise docs/design/v2.0.2/balance/baseline-v201-B.jsonl --nodyn docs/design/v2.0.2/balance/baseline-v201-nodyn-A.jsonl
```
Yeni kod koşusu için (60 tohum A) `tools/balance/mid_all.sh .mid 1001 60` ve karşılaştırma aracına dizin verilir.

## Sonuç ve BULGU: gürültü tabanı hedefin çok üstünde

n=60 tohumla A ile B arasındaki fark: strong survival **%6,7**, kite survival **%10,3** (plan sınırı ±%2,5). Yani ±%5 bant bu örneklemle **ölçülemiyor**; araç doğru olarak "ÖLÇÜLEMEDİ" der (`baseline-compare-v201-vs-nodyn.md`). Medyan hayatta kalma GA'sı ≈ ±%10-15 geniş. ±%2,5 gürültü için tohum sayısı kabaca (6,7/2,5)² ≈ 7× → strong ≥ ~400, kite için (10,3/2,5)² ≈ 17× → ≥ ~1000 tohum gerekir; ya da eşleşmiş tasarım/daha az gürültülü metrik (ör. 5. dk öldürme sayısı, hp_early) seçilmeli. Karar D fazı/VLAD'ındır.

Diğer gözlemler:
- `hp_mid` (ölen koşular 0) kite/greedy/idle için hep 0 (kimse 10-20 dk'da hayatta değil): ayırt edici değil; strong'ta GA çok geniş. `reach10` (strong %78, kite %42) daha bilgilendirici.
- Dinamit kaybı (v201 → nodyn) strong/kite'ta anlamlı değil (GA sıfırı içerir): +%4,3 / +%2,5 nokta tahmini, gürültü içinde.
- Her koşu ≈ 12 sn (ölümlü); 240 koşu/kol ≈ 20-40 dk.

## Uzatılmış baseline (VLAD kararı: strong + kite, 400 tohum) — ayrı fazda koşulur
Tohum kümeleri `seeds_v202.txt`: `A400` (3001-3400), `B400` (4001-4400). Kollar `v201-A400`, `v201-B400`, `v201-nodyn-A400`.
```
POLICIES="strong kite" bash tools/balance/baseline_run.sh run v201-A400 v201-B400 v201-nodyn-A400
POLICIES="strong kite" bash tools/balance/baseline_run.sh collect v201-A400 v201-B400 v201-nodyn-A400
python3 tools/balance/compare_baseline.py docs/design/v2.0.2/balance/baseline-v201-A400.jsonl <yeni A400 koşusu> \
    --noise docs/design/v2.0.2/balance/baseline-v201-B400.jsonl --nodyn docs/design/v2.0.2/balance/baseline-v201-nodyn-A400.jsonl \
    --gate-policies strong,kite --info-policies ""
```

## 400 tohum sonuçları (T20261024-93)

Üç kol 800/800 koştu (strong + kite × 400 tohum; v2.0.1 `9833741`). Ham veri `baseline-v201-{A400,B400,nodyn-A400}.jsonl`, araç çıktısı `baseline-compare-400.md` (B400, A400'e karşı "yeni" olarak verildi; yalnız gürültü sütunu ve dinamit kaybı satırı anlamlıdır, "süzgeç/diğer" sütunu bu çağrıda anlamsızdır). Bot dengesi ölçülüyor, oyun dengesi değil.

### Gürültü tabanı (A400 − B400, taban A400'e göre göreli fark, %95 bootstrap GA)

"Bant çözülür" = A-B farkının GA yarı genişliği ≤ %5. Karar yalnız survival ve hp_mid içindir; diğerleri bilgi amaçlıdır.

| metrik | politika | fark | GA | ±%2,5 sınırı | ±%5 bant çözülür |
|---|---|---|---|---|---|
| survival (medyan, karar) | strong | +%1,4 | −4,4…+6,1 | içinde | hayır (yarı genişlik 5,3) |
| survival (medyan, karar) | kite | +%3,3 | −4,2…+11,2 | aşıyor | hayır |
| hp_mid (karar) | strong | +%2,8 | −30,0…+34,5 | aşıyor | hayır |
| hp_mid (karar) | kite | +%37,4 | −100…+178,6 | aşıyor | hayır (taban ≈ 0) |
| reach10 | strong | +%0,4 | −9,2…+8,9 | içinde | hayır |
| reach10 | kite | +%4,5 | −12,9…+24,3 | aşıyor | hayır |
| kills5 | strong | +%0,1 | −0,5…+0,3 | içinde | **evet** |
| kills5 | kite | +%0,4 | −1,8…+1,0 | içinde | **evet** |
| hp_early | strong | +%0,1 | −0,2…0,0 | içinde | **evet** |
| hp_early | kite | 0,0 | −0,4…+0,4 | içinde | **evet** |

kills5 yalnız 5. dakikaya ulaşan koşuları sayar (kite'ta bir koşu ulaşmadı, n=399). hp_early strong'ta ≈ 0,999 ile tavana yakın; ayırt ediciliği düşük, kite'ta 0,986.

### Sonuç: ±%5 bant ölçülebilir mi?

- **Karar ölçütleri ölçülemez.** 400 tohumda strong survival noktası ±%2,5 içinde (+%1,4) ama GA ≈ ±%5,3: ±%5 bandı çözülemiyor. Kite survival, hp_mid ve reach10 hem sınırı aşıyor hem GA'sı çok geniş (kite survival ±%7-8). Araç kararı "ÖLÇÜLEMEDİ" verir. S2'nin n=60 bulgusu (strong %6,7, kite %10,3) 400'e çıkınca küçüldü ama hedefe inmedi; kite için tahminim ≥ ~1000 tohum idi, burada GA hâlâ ±%7-8.
- **Yardımcı ölçütler ölçülebilir:** `kills5` (strong ±%0,5, kite ±%1,8) ve `hp_early` (±%0,4 veya daha dar) ±%5 bandını rahatça çözer. Bunlar yalnız erken oyunu (0-5 dk) ölçer; orta oyun ölümünü yansıtmaz. Karar dışı olduklarından Gunslinger ±%5 hükmü için tek başına yetmez, destekleyici kanıttır.
- **Öneri (VLAD kararı):** D fazında karar için kills5 ve hp_early bandı + survival/reach10'un GA'sını birlikte raporla; survival'ı "ölçülemedi" olarak işaretle, ya da survival için eşleşmiş tasarım/daha çok tohum aç.

### Dinamitsiz kol (v201 → nodyn-A400, dinamit kaybı, %95 GA)

| politika | survival | hp_mid | reach10 | kills5 | hp_early |
|---|---|---|---|---|---|
| strong | +%1,4 (−5,8…+6,2) | +%32,0 (−2,2…+79,4) | +%0,4 (−8,4…+9,8) | +%0,1 (−0,3…+0,5) | −%0,1 (−0,2…0,0) |
| kite | **+%7,3 (+1,6…+14,1)** | −%100 (taban ≈ 0) | +%14,2 (−3,7…+35,5) | **−%1,8 (−3,2…−0,4)** | +%0,1 (−0,3…+0,5) |

Dinamit olmadan kite survival medyanı v2.0.1'den yüksek (534,6 → 573,5 sn; GA sıfırı dışlıyor), yani kite politikasında dinamitin hayatta kalmaya olumlu katkısı görünmüyor (kayıp kazanç gibi okunur); kills5 ise küçük ama anlamlı düşüyor (−%1,8). Strong'ta dinamit etkisi gürültü içinde. Kite survival için A-B gürültüsü de +%3,3 olduğundan +%7,3'ün bir kısmı gürültü olabilir (GA'nın alt ucu +%1,6).

### Yeni kodun koşusu (D fazı)

```
bash tools/balance/mid_all.sh .mid 3001 400          # A400, strong+kite, gunslinger+zyfen
python3 tools/balance/compare_baseline.py docs/design/v2.0.2/balance/baseline-v201-A400.jsonl .mid --char gunslinger \
    --noise docs/design/v2.0.2/balance/baseline-v201-B400.jsonl --nodyn docs/design/v2.0.2/balance/baseline-v201-nodyn-A400.jsonl \
    --gate-policies strong,kite --info-policies ""
```
`mid_all.sh` varsayılanı 400 tohum (3001-3400), strong/kite, gunslinger+zyfen; `POLICIES`/`CHARS` ile değişir. Süre ≈ 2 karakter × 800 koşu ≈ 2 saat (4 çekirdek). Tohum 3001-3400 baseline A400 ile aynı olduğundan eşleşmiş fark da raporlanır.
