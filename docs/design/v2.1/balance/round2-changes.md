# U5 ayar turu 2 — yapılan değişiklikler (ölçümden önce)

Dayanak: `round1.md` (run 40521328969). Kullanıcı kararı: dar yetki; yalnız `data/run_profiles.json` sayıları ve bu sayıları sabitleyen testlerin DEĞERLERİ. Test mantığı, kapsam ve assert yapısı değişmedi, gevşetme yok.

## `data/run_profiles.json`

| Alan | Eski | Yeni | Amaç (tur 1 sonucu → hedef) |
|---|---|---|---|
| `difficulties.easy.enemy_dmg` | 0,55 | 0,40 | Kolay kazanma 53,2 → ≥55, ulaşma 68,8 → ≥70, kite ulaşma 5,5 → ≥25 |
| `difficulties.easy.spawn_density` | 0,70 | 0,60 | aynı |
| `difficulties.normal.enemy_dmg` | 0,75 | 0,60 | Normal strong ulaşma 33,8 → 35–45, kazanma 19,5 → 20–30, kite 20. dk 1,0 → ≥8 |
| `modes.endless.enrage_after_sec` | 2400 | 1500 | Lord sonrası 5 dk içinde ölüm %0 → ≥%90 (medyan ≥3 dk korunacak) |
| `modes.endless.enrage_dmg_per_min` | 0,10 | 0,35 | aynı |

Değişmeyenler: Zor (legacy, K-C10), tüm `enemy_hp`, `xp`, `lord_hp`, `lord_hp_mult`, Hızlı `rate_mult` (1,0; fark −8,8 ±10 içinde).

## Güncellenen test değerleri (eski → yeni)

| Dosya:satır (eski numara) | Eski | Yeni |
|---|---|---|
| `test/acceptance/test_acc_v21_profile.gd:131` | Kolay temas 0.55 ("×0,55") | 0.40 ("×0,40") |
| `test/acceptance/test_acc_v21_profile.gd:132` | Normal temas 0.75 ("×0,75") | 0.60 ("×0,60") |
| `test/acceptance/test_acc_v21_profile.gd:154` | Kolay doğuş aralığı 0.60–0.80 ("×0,70") | 0.50–0.70 ("×0,60") |
| `test/unit/test_v21_contract_sim.gd:27` | `enrage_after_sec` 2400.0 | 1500.0 |
| `test/unit/test_v21_s_sim.gd:128` | `def.dmg * 0.55` | `def.dmg * 0.40` |
| `test/unit/test_v21_s_sim.gd:135` | `40.0 * 0.55` | `40.0 * 0.40` |
| `test/unit/test_v21_s_sim.gd:149,152` | eşik öncesi zaman 2399.0 | 1499.0 |
| `test/unit/test_v21_s_sim.gd:155-156` | zaman 3000.0, çarpan 2.0 (1+0,10·10) | zaman 2100.0, çarpan 4.5 (1+0,35·10) |
| `test/unit/test_v21_s_sim.gd:161-162` | zaman 3000.0, `40.0 * 2.0` | zaman 2100.0, `40.0 * 4.5` |
| `test/acceptance/test_acc_v21_endless.gd:3` | "2400. sn" (açıklama) | "1500. sn" |
| `test/acceptance/test_acc_v21_endless.gd:174` | zamanlar 2000 / 2400 / 2700 / normal 2700 | 1300 / 1500 / 1800 / normal 1800 |
| `test/acceptance/test_acc_v21_endless.gd:191-196` | anahtarlar `@2000/@2400/@2700`, oran 1.5 ("×(1+0,10·5)") | `@1300/@1500/@1800`, oran 2.75 ("×(1+0,35·5)") |

Not: `test_acc_v21_endless.gd` en düşük zaman 2000 yerine 1300 (1200 = ilk Lord doğuş anı; eski testte üç zaman da 1200'ün üstündeydi, aynı durum korundu).
`test/fixtures/profile_bad_*/run_profiles.json` `gen_profile_fixtures.py` ile yeniden üretildi (bozuk varyantlar gerçek dosyadan türer).
`test/unit/test_v21_contract_profiles.gd` değişmedi (Zor ve aralık sabitleri etkilenmedi).

## UI testi (VLAD yetkisi, 23:20)

| Dosya:satır | Eski | Yeni |
|---|---|---|
| `test/unit/test_v21_a_run_ui.gd:90` | `["Düşman hasarı", "−%25"]` (Normal) | `"−%40"` |
| `test/unit/test_v21_a_run_ui.gd:208` | `["−%15", "−%25", "−%15", "aynı"]` | `["−%15", "−%40", "−%15", "aynı"]` |
| `test/unit/test_v21_a_run_ui.gd:211` | `["−%30", "−%45", "−%30", "+%25"]` (Kolay) | `["−%30", "−%60", "−%40", "+%25"]` |

## Yerelde koşulamayan

Godot yok: değişen GUT testleri (`test_acc_v21_profile`, `test_v21_contract_sim`, `test_v21_s_sim`, `test_acc_v21_endless`, `test_v21_a_run_ui`) CI'da koşar.
