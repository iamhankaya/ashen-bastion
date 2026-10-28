# U5 ayar turu 3 (son) — hedef / sonuç

Run 40593904748 (`balance.yml`, ref `vlad/T20261027-35` = 6ed9bae, A400 = 3001–3400, `chars=gunslinger`). Ham tablolar: `round3-report.md`, süreler: `round3-timing.md` (en yavaş alt iş 1725 sn, sınır 10800 sn). Sayılar `round3-changes.md`'deki değerlerdir. Ölçülen bot dengesidir, insan dengesi değil. 10. dk canlı % ve Sonsuz Lord sonrası ömür artifact'taki ham `baseline.jsonl`'den hesaplandı.

| # | Ölçüt (spec) | Hedef | Tur 1 | Tur 2 | Tur 3 | Durum |
|---|---|---|---|---|---|---|
| 2 | Kolay strong kazanma | ≥ 55 | 53,2 | 56,0 | 62,5 (57,8…67,2) | ✓ |
| 2 | Kolay strong Lord'a ulaşma | ≥ 70 | 68,8 | 76,0 | 84,5 | ✓ |
| 2 | Kolay kite Lord'a ulaşma | ≥ 25 | 5,5 | 13,8 | 27,0 | ✓ |
| 3 | Normal strong Lord'a ulaşma | 35–45 | 33,8 | 36,2 | 37,8 | ✓ |
| 3 | Normal strong kazanma | 20–30 | 19,5 | 21,5 | 24,5 (20,5…28,7) | ✓ |
| 3 | Normal kite 20. dk | ≥ 8 | 1,0 | 2,2 | 3,5 | ✗ |
| 3 | Normal strong 10. dk | ≥ 85 | 90,0 | 94,2 | 97,5 | ✓ |
| 4 | Zor strong kazanma | ≤ 5 | 10,2 | 10,2 | 10,2 | ✗ (legacy) |
| 4 | Zor strong Lord'a ulaşma | 10–16 | 22,0 | 22,0 | 22,0 | ✗ (legacy) |
| 4 | Zor kite kazanma | ≤ 1 | 0,0 | 0,0 | 0,0 | ✓ |
| 5 | Sıralama (süre medyanı, strong) | Kolay > Normal > Zor | ✓ | 1239 > 931 > 689 | 1243 > 943 > 689 | ✓ |
| 6 | Hızlı − Normal kazanma | ±10 puan | −8,8 | −7,7 | −7,5 (−12,8…−1,8) | ✓ |
| 6 | Hızlı seviye oranı | ≥ 0,70 | 0,946 | 0,946 | 0,944 | ✓ |
| 6 | Hızlı toplam süre | ≤ 11 dk | 656 sn | 653 sn | 656,8 sn | ✓ |
| 7 | Lord dövüşü Normal | 3–6 dk | 49,7 sn | 50,2 sn | 51,5 sn | ✗ (yapısal) |
| 7 | Lord dövüşü Hızlı | 1,5–3 dk | 25,2 sn | 25,7 sn | 26,7 sn | ✗ (yapısal) |
| 8 | Sonsuz Lord sonrası medyan ömür | ≥ 3 dk | 349 sn | 344 sn | 317 sn (Kolay n=144), 312 sn (Normal n=29) | ✓ |
| 8 | Sonsuz Lord sonrası 5 dk içinde ölüm | ≥ %90 | %0 | %0 | %0,7 (Kolay), %0 (Normal) | ✗ |
| 8 | Sonsuz 40. dk kare/bellek | sınırı geçer | — | — | ölçülmedi (nightly) | — |
| 1 | Regresyon | değişmez | — | — | gate/CI'a bağlı | — |

Tur 3'te tutmayanlar (yeniden ayar yok, VLAD kararı):

- **Normal kite 20. dk 3,5 (≥ 8):** hasar ve yoğunluk düşüşü kite'ı ~1 → 2,2 → 3,5 çıkardı; Normal strong ulaşma 37,8 ile 45 üst sınırına yakın, daha fazla düşüş strong'u pencere dışına iter.
- **Zor (4):** `hard` çarpanları 1,0 ve Normal mod + Zor = `RunProfile.legacy()` (K-C10, altın hash); sayıyla ayarlanamaz.
- **Lord dövüşü (7):** ~50 sn / ~26 sn. 3–6 dk için Normal/Kolay `lord_hp` Zor'un 1,0'ından yüksek olmalı, zorluk sırasını bozar; süre öldürülenlerin medyanı (hayatta kalma yanlılığı).
- **Sonsuz 5 dk içinde ölüm (8):** enrage alt/üst sınırda (1200 sn, 1,0/dk) bile Lord sonrası ölümler 305–335 sn'de kümeleniyor. Neden: `lord_repeat_sec` = 300 ile gelen ikinci Lord botu öldürüyor; enrage temas hasarı çarpanı bot ölümünü öne çekmiyor. Spec ölçütü bu sayılarla (K-C4 aralıkları) karşılanamıyor; `lord_repeat_sec` ya da enrage biçimi (tasarım) gerekir.

Sonsuz 40. dk kare süresi/bellek bu iş akışında ölçülmez (nightly `test_ver_v21_endless_long`); regresyon (1) gate/CI sonucuna bağlıdır.
