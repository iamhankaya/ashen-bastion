# U5 ayar turu 2 — hedef / sonuç

Run 40577026397 (`balance.yml`, ref `vlad/T20261027-35` = 4efe562, A400 = 3001–3400, `chars=gunslinger`). Ham tablolar: `round2-report.md`, süreler: `round2-timing.md`. Profil sayıları `round2-changes.md`'deki değerlerdir. Ölçülen bot dengesidir, insan dengesi değil.

10. dk canlı % ve Sonsuz Lord sonrası ömür artifact'taki ham `baseline.jsonl`'den hesaplandı.

| # | Ölçüt (spec) | Hedef | Tur 1 | Tur 2 | Durum |
|---|---|---|---|---|---|
| 2 | Kolay strong kazanma | ≥ 55 | 53,2 | 56,0 (51,2…60,8) | ✓ |
| 2 | Kolay strong Lord'a ulaşma | ≥ 70 | 68,8 | 76,0 | ✓ |
| 2 | Kolay kite Lord'a ulaşma | ≥ 25 | 5,5 | 13,8 | ✗ (yön doğru) |
| 3 | Normal strong Lord'a ulaşma | 35–45 | 33,8 | 36,2 | ✓ |
| 3 | Normal strong kazanma | 20–30 | 19,5 | 21,5 (17,8…25,8) | ✓ |
| 3 | Normal kite 20. dk | ≥ 8 | 1,0 | 2,2 | ✗ |
| 3 | Normal strong 10. dk | ≥ 85 | 90,0 | 94,2 | ✓ |
| 4 | Zor strong kazanma | ≤ 5 | 10,2 | 10,2 | ✗ (legacy, ayarlanamaz) |
| 4 | Zor strong Lord'a ulaşma | 10–16 | 22,0 | 22,0 | ✗ (legacy) |
| 4 | Zor kite kazanma | ≤ 1 | 0,0 | 0,0 | ✓ |
| 5 | Sıralama (süre medyanı, strong) | Kolay > Normal > Zor | ✓ | 1239 > 931 > 689 | ✓ |
| 6 | Hızlı − Normal kazanma | ±10 puan | −8,8 | −7,7 (−13,0…−2,5) | ✓ |
| 6 | Hızlı seviye oranı | ≥ 0,70 | 0,946 | 0,946 | ✓ |
| 6 | Hızlı toplam süre | ≤ 11 dk | 656 sn | süre medyanları ≤ 611 sn (Kolay) | ✓ |
| 7 | Lord dövüşü Normal | 3–6 dk | 49,7 sn | 50,2 sn | ✗ (yapısal) |
| 7 | Lord dövüşü Hızlı | 1,5–3 dk | 25,2 sn | 25,7 sn | ✗ (yapısal) |
| 8 | Sonsuz Lord sonrası medyan ömür | ≥ 3 dk | 349 / 334 sn | 344 sn (Kolay n=152), 329 sn (Normal n=30) | ✓ |
| 8 | Sonsuz Lord sonrası 5 dk içinde ölüm | ≥ %90 | %0 | %0 (hepsi ≥ 300 sn) | ✗ |
| 8 | Sonsuz 40. dk kare/bellek | sınırı geçer | ölçülmedi | ölçülmedi (nightly) | — |
| 1 | Regresyon | değişmez | — | gate/CI'a bağlı | — |

Not: "Hızlı toplam süre" için bu turda baseline.jsonl'den maksimum hesaplanmadı; Hızlı Lord 600. sn sabit ve Hızlı Kolay süre medyanı 611 sn. Tur 1 değeri (656 sn) referans.

## Çıkarımlar

- Sonsuz'da enrage etkisiz kaldı: Lord sonrası ölümler ~315–350 sn'de kümeleniyor (ikinci küme ~650–675 sn). `lord_repeat_sec` = 300 → ölümler enrage'den değil tekrar eden Lord'dan (kill + 300 sn + dövüş). Tur 2 enrage'i Lord ölümünde (~1245 sn) çarpanı yalnız 1,0, 5 dk sonra ~1,4 yapıyor; bot bundan etkilenmiyor.
- Kolay kite 5,5 → 13,8, Normal kite 1,0 → 2,2: hasar/yoğunluk düşüşü doğru yönde ama hedefe uzak. Aynı düşüş strong'u artırıyor (Normal strong ulaşma 36,2, pencere üstü sınır 45).
- Zor ve Lord dövüşü süresi tur 1'deki gibi: sayıyla çözülmez (bkz. `round1.md`).
