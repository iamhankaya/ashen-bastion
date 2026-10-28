# U5 ayar turu 3 (son) — yapılan değişiklikler (ölçümden önce)

Dayanak: `round2.md` (run 40577026397). Yetki: VLAD 01:15 (dar yetki kapsamı, son tur): yalnız `data/run_profiles.json` sayıları ve bunları sabitleyen testlerin DEĞERLERİ. Test mantığı ve assert yapısı değişmedi.

## `data/run_profiles.json`

| Alan | Tur 2 | Tur 3 | Amaç (tur 2 sonucu → hedef) |
|---|---|---|---|
| `difficulties.easy.enemy_dmg` | 0,40 | 0,30 | Kolay kite ulaşma 13,8 → ≥25 |
| `difficulties.easy.spawn_density` | 0,60 | 0,50 | aynı |
| `difficulties.normal.enemy_dmg` | 0,60 | 0,50 | Normal kite 20. dk 2,2 → ≥8 |
| `difficulties.normal.spawn_density` | 0,85 | 0,80 | aynı |
| `modes.endless.enrage_after_sec` | 1500 | 1200 (alt sınır) | Sonsuz Lord sonrası 5 dk içinde ölüm %0 → ≥%90 |
| `modes.endless.enrage_dmg_per_min` | 0,35 | 1,0 (üst sınır) | aynı |

## Güncellenen test değerleri (eski → yeni)

| Dosya | Eski | Yeni |
|---|---|---|
| `test_acc_v21_profile.gd` Kolay temas | 0.40 ("×0,40") | 0.30 ("×0,30") |
| `test_acc_v21_profile.gd` Normal temas | 0.60 ("×0,60") | 0.50 ("×0,50") |
| `test_acc_v21_profile.gd` Kolay doğuş aralığı | 0.50–0.70 ("×0,60") | 0.40–0.60 ("×0,50") |
| `test_acc_v21_profile.gd` Normal doğuş aralığı | 0.75–0.95 ("×0,85") | 0.70–0.90 ("×0,80") |
| `test_v21_contract_sim.gd` `enrage_after_sec` | 1500.0 | 1200.0 |
| `test_v21_s_sim.gd` Kolay/Lord temas | `* 0.40` (2 yer) | `* 0.30` |
| `test_v21_s_sim.gd` eşik öncesi zaman (2 yer) | 1499.0 | 1199.0 |
| `test_v21_s_sim.gd` eşik sonrası | zaman 2100.0, çarpan 4.5 (1+0,35·10) | zaman 1800.0, çarpan 11.0 (1+1,0·10) |
| `test_v21_s_sim.gd` Lord eşik sonrası | zaman 2100.0, `40.0 * 4.5` | zaman 1800.0, `40.0 * 11.0` |
| `test_v21_s_sim.gd` `test_s20` | aralık 5, 6 ("0,60") | 4, 5 ("0,50") |
| `test_v21_s_sim.gd` `test_s22` (2 yer) | 6 | 5 |
| `test_acc_v21_endless.gd` başlık | "1500. sn" | "1200. sn" |
| `test_acc_v21_endless.gd` zamanlar | 1300 / 1500 / 1800 / normal 1800 | 1100 / 1200 / 1500 / normal 1500 |
| `test_acc_v21_endless.gd` anahtarlar, oran | `@1300/@1500/@1800`, 2.75 (×(1+0,35·5)) | `@1100/@1200/@1500`, 6.0 (×(1+1,0·5)) |
| `test_v21_a_run_ui.gd` Normal hasar / sayı | "−%40" / "−%15" | "−%50" / "−%20" (2 yer) |
| `test_v21_a_run_ui.gd` Kolay satırları | `−%30, −%60, −%40, +%25` | `−%30, −%70, −%50, +%25` |
| `test_v21_a_run_ui.gd` `test_a6` TalkBack | "yüzde altmış / yüzde kırk az" | "yüzde yetmiş / yüzde elli az" |

`test/fixtures/profile_bad_*/run_profiles.json` `gen_profile_fixtures.py` ile yeniden üretildi; `test_map.json` yenilendi.

## Yerelde koşulamayan

Godot yok: GUT testleri (yukarıdaki dosyalar) yalnız CI'da koşar. Yerelde: `gdformat --check` temiz; `pytest tools/ci/tests` 167 geçti, 1 başarısız (`test_v2_snapshot_is_byte_identical`, bilinen Windows) + 8 `test_godot_import` deselect.

## Entegrasyon merge sonrası düzeltme (`test_acc_v21_endless.gd`)

`vlad/T20261027-15` merge'ünde `test_s30` entegrasyon dalında yeniden yazılmıştı (2 sn'lik pencere eşiğin altında bitmeli). Çakışma o yapıyla çözüldü, değerler tur 3'e uyarlandı: zamanlar 1100 / 1190 (eşik 1200'ün altı) / 1500 / normal 1500; oran 6.0 (×(1+1,0·5)). Tur 3 CI'ı (6ed9bae) bu satırlar yeniydi: CI yeşil, merge sonrası CI VLAD'da.
