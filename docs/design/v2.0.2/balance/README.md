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
Yeni kod koşusu için `tools/balance/mid_all.sh .mid 1001 60` (A) ve karşılaştırma aracına dizin verilir.

## Sonuç ve BULGU: gürültü tabanı hedefin çok üstünde

n=60 tohumla A ile B arasındaki fark: strong survival **%6,7**, kite survival **%10,3** (plan sınırı ±%2,5). Yani ±%5 bant bu örneklemle **ölçülemiyor**; araç doğru olarak "ÖLÇÜLEMEDİ" der (`baseline-compare-v201-vs-nodyn.md`). Medyan hayatta kalma GA'sı ≈ ±%10-15 geniş. ±%2,5 gürültü için tohum sayısı kabaca (6,7/2,5)² ≈ 7× → strong ≥ ~400, kite için (10,3/2,5)² ≈ 17× → ≥ ~1000 tohum gerekir; ya da eşleşmiş tasarım/daha az gürültülü metrik (ör. 5. dk öldürme sayısı, hp_early) seçilmeli. Karar D fazı/VLAD'ındır.

Diğer gözlemler:
- `hp_mid` (ölen koşular 0) kite/greedy/idle için hep 0 (kimse 10-20 dk'da hayatta değil): ayırt edici değil; strong'ta GA çok geniş. `reach10` (strong %78, kite %42) daha bilgilendirici.
- Dinamit kaybı (v201 → nodyn) strong/kite'ta anlamlı değil (GA sıfırı içerir): +%4,3 / +%2,5 nokta tahmini, gürültü içinde.
- Her koşu ≈ 12 sn (ölümlü); 240 koşu/kol ≈ 20-40 dk.
