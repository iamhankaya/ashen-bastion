# U5 ayar turu 1 — hedef / sonuç

Run 40521328969 (`balance.yml`, ref `vlad/T20261027-35` = c7f87bd, `first_seed=3001`, `seeds_per_job=100`, `chars=gunslinger`; A400 = 3001–3400).
Ham tablolar: `round1-report.md`, süreler: `round1-timing.md` (en yavaş alt iş 1694 sn, sınır 10800 sn). Profil sayıları bu turda **değişmemiş** başlangıç (`data/run_profiles.json`, TAHMİN) değerleridir.
Ölçülen bot dengesidir, insan dengesi değil; `strong_lord` evrim almaz (spec Riskler).

Değerler: kazanma % (GA), Lord'a ulaşma % (= 20. dk'ya canlı ulaşan), 10. dk canlı % (`time ≥ 600`; artifact'taki ham `baseline.jsonl`'den hesaplandı).

| # | Ölçüt (spec) | Hedef | Tur 1 | Durum |
|---|---|---|---|---|
| 2 | Kolay strong kazanma | ≥ 55 | 53,2 (48,2…58,2) | ✗ (−1,8) |
| 2 | Kolay strong Lord'a ulaşma | ≥ 70 | 68,8 | ✗ (−1,2) |
| 2 | Kolay kite Lord'a ulaşma | ≥ 25 | 5,5 | ✗ |
| 3 | Normal strong Lord'a ulaşma | 35–45 | 33,8 | ✗ (−1,2) |
| 3 | Normal strong kazanma | 20–30 | 19,5 (16,0…23,5) | ✗ (−0,5; GA içinde) |
| 3 | Normal kite 20. dk | ≥ 8 | 1,0 | ✗ |
| 3 | Normal strong 10. dk | ≥ 85 | 90,0 | ✓ |
| 4 | Zor strong kazanma | ≤ 5 | 10,2 (7,5…13,2) | ✗ |
| 4 | Zor strong Lord'a ulaşma | 10–16 | 22,0 | ✗ |
| 4 | Zor kite kazanma | ≤ 1 | 0,0 | ✓ |
| 5 | Sıralama (süre medyanı, strong) | Kolay > Normal > Zor | 1236 > 855 > 689 | ✓ |
| 6 | Hızlı − Normal kazanma | ±10 puan | −8,8 (−13,8…−4,0) | ✓ (GA sınırı aşıyor) |
| 6 | Hızlı Lord | 600. sn | 600 (end_time) | ✓ |
| 6 | Hızlı toplam süre | ≤ 11 dk | maks 656 sn | ✓ |
| 6 | Hızlı seviye / Normal 20. dk seviyesi | ≥ 0,70 | 0,946 | ✓ |
| 7 | Lord dövüşü Normal | 3–6 dk | 49,7 sn (öldürülenlerin medyanı) | ✗ |
| 7 | Lord dövüşü Hızlı | 1,5–3 dk | 25,2 sn | ✗ |
| 8 | Sonsuz: Lord ölünce koşu sürer | evet | evet (maks 2651 sn) | ✓ |
| 8 | Sonsuz: Lord sonrası medyan ömür | ≥ 3 dk | 349 sn (Kolay n=121), 334 sn (Normal n=21) | ✓ |
| 8 | Sonsuz: Lord sonrası 5 dk içinde ölüm | ≥ %90 | %0 (hepsi ≥ 300 sn) | ✗ |
| 8 | Sonsuz: 40. dk kare süresi/bellek | sınırı geçer | ölçülmedi (nightly `test_ver_v21_endless_long`) | — |
| 1 | Regresyon (golden, kills5/hp_early ±%5) | değişmez | profil sayısı değişmedi; gate'e bağlı | — |

Yardımcı gözlemler: `strong_lord` sağlama (Kolay, Lord can oranı medyanı ≤ 0,5) GEÇTİ (0,0, n=275). Kolay−Normal fark: +33,8 puan kazanma (GA +27,7…+40,0). Hızlı−Normal Lord'a ulaşma −11,5 puan.

## Tur 2 için çıkarımlar (sayılar tahmin, ölçümle sınanacak)

- **Zor (4):** `hard` çarpanları 1,0 ve Normal mod + Zor = `RunProfile.legacy()` (K-C10, altın hash). Zor `strong_lord` ile 22 % Lord'a ulaşıyor; spec'in ≤5 / 10–16 ölçütü `strong` botu ve v2.0.1 durumuna göre yazılmış. Sayıyla ayarlanamaz → açık nokta.
- **Lord dövüşü (7):** süre öldürülenlerin medyanı (hayatta kalma yanlılığı: Lord'a yenilenler dahil değil). Zor'un `lord_hp` = 1,0 sabit; Normal/Kolay'ın Lord HP'sini Zor'dan yüksek yapmak zorluk sırasını bozar. Karar kullanıcıya/VLAD'a ait.
- **Kolay (2):** kazanma/ulaşma eşiğe 1–2 puan; kite'ın 5,5 → 25 için hasar ve yoğunluk belirgin düşmeli.
- **Normal (3):** strong ulaşma/kazanma pencerenin hemen altında; hasarı biraz düşürmek kazanma/ulaşma oranını (0,58 → ~0,65) birlikte yukarı çeker.
- **Hızlı (6):** ölçütler tutuyor; Normal değişirse Hızlı de kayar, `rate_mult` 2,0 (K-C9) yalnız fark ±10'u aşarsa.
- **Sonsuz (8):** Lord sonrası %0 < 300 sn; enrage Lord ölümünden (~1300 sn) çok sonra (2400 sn) başlıyor.
