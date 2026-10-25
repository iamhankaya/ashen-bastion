# CI / gate hızı (F-044, T20261025-64)

Amaç: gate/CI süresini **doğruluktan ödün vermeden** düşürmek. Kapsam azaltan hiçbir değişiklik yapılmadı: hiçbir test
`test/long`'a taşınmadı, hiçbir test atlanmadı; koşan test sayısı önce/sonra aynıdır (2150 test, 212 dosya; bölüm 4).

## 1. Kural (zorunlu)

> **PR CI'ı, entegrasyon merge'ü ve son kapı (main) HER ZAMAN tam suite koşar.**
> Hızlı mod (`bash tools/gate.sh --changed`) yalnız geliştirici/çalışan içi hızlı geri bildirimdir; bunların yerine geçmez.

Bu kuralın uygulanışı:

- `.github/workflows/ci.yml` `push` **ve** `pull_request` üzerinde koşar; tam suite üç parçalı işle koşulur (bölüm 2). Hiçbir
  CI adımı `--changed` kullanmaz; `tools/ci/tests/test_ci_workflow.py` bunu denetler.
- `tools/gate.sh --changed`, `CI` ya da `GITHUB_ACTIONS` ortam değişkeni doluysa çıkış 2 ile **reddeder** (aynı testte
  kanıtlanır).
- Hızlı mod başarıda `GATE OK` **yazmaz**; `GATE_FAST OK (KISMİ ...)` yazar. `GATE OK` yalnız tam `gate.sh` koşusundadır.
- Entegrasyon merge'ü ve son kapı öncesi komut: `bash tools/gate.sh` (tam).

## 2. CI yapısı (paralel, kapsam aynı)

```
static  (GATE_PART=static)                    adım 1-5: kurulum, içe aktarma, lint, veri doğrulama, dilim sözdizimi, Python testleri
gut ×4  (GATE_PART=gut GATE_SHARD=K/4)        adım 1-2 + 6: GUT test dosyalarının K. parçası (tools/ci/shard.py)
test    (GATE_PART=verify GATE_SHARD_COUNT=4) needs: static, gut; parça JUnit'lerini birleştirir + adım 7 (sahte yeşil korumaları)
selftest ×6, export-debug, release-prova      değişmedi
```

- **Parçalama** `tools/ci/shard.py`: `.gutconfig.json` dizinlerindeki tüm `test_*.gd` dosyaları, `tools/ci/shard_weights.json`
  (dosya -> sn, tam gate JUnit'inden) ağırlıklarıyla açgözlü en-uzun-önce (LPT) atanır; ağırlığı olmayan yeni dosya medyan
  ağırlık alır, yani **yeni test otomatik bir parçaya düşer**. Her dosya tam bir parçada olur (`tools/ci/tests/test_shard.py`).
- **Kapsam kanıtı (verify işi)**: parça sayısı beklenenle eşit olmalı; `shard.py check-merge --require-all` her test dosyasının
  bir parçada koştuğunu (eksik/yinelenen/bilinmeyen dosya = kırmızı) denetler; birleşik JUnit üzerinde adım 7 (asgari test sayısı
  `tools/gate_min_tests.json`, tek test ≤ 60 sn, dilim/pending denetimleri) **aynen** koşar. Parçası düşen ya da hiç koşmayan
  bir iş `test` işini kırmızı yapar.
- `test` işi adını korur: dal koruması bu bağlamı bekliyor olabilir.
- Parça sayısını değiştirmek: `ci.yml` (`matrix.shard`, `/N`, `GATE_SHARD_COUNT`) ve `tools/ci/tests/test_shard.py::SHARD_COUNT`
  birlikte; `test_ci_workflow.py` tutarsızlığı yakalar. Ağırlıkları yenilemek: tam gate JUnit'inden `shard_weights.json`
  (dosya başına test süreleri toplamı) — zorunlu değildir, yalnız dengeyi iyileştirir.
- **Önbellek**: Godot ikilisi (önceden vardı); `.godot` içe aktarma önbelleği (anahtar: `.godot-version`, `project.godot`,
  `assets/**`, `art/**`, `audio/**`, `**/*.import` karması; **yalnız tam eşleşme, `restore-keys` yok**, içe aktarma adımı yine
  koşar ve eksiği/farkı yeniden içe aktarır; bozuk önbellek ilkesi: `tools/ci/prova_import_cache.sh`); pip önbelleği
  (`setup-python cache: pip`, anahtar `tools/ci/requirements-ci.txt`). Bağımlılık sürümleri `requirements-ci.txt`'te **sabitlendi**
  (doğrudan bağımlılıklar; geçişli bağımlılıklar sabit değildir).

## 3. Hızlı mod (yalnız yerel geri bildirim)

```
bash tools/gate.sh --changed [--base REF]     # REF yoksa origin/HEAD ya da origin/main ya da HEAD
```

Değişen dosyalar = `git diff --name-only $(git merge-base HEAD REF)` (çalışma ağacı dahil) + izlenmeyen dosyalar.
`tools/ci/test_map.py` (eşleme: `tools/ci/test_map.json`, `python3 tools/ci/test_map.py generate` ile üretilir) seçer:

| Değişen dosya | Sonuç |
|---|---|
| `scripts/ui|view|ctrl|audio|store|debug/*.gd` (eşlenmiş) | o dosyaya (sınıf adı, `res://` yolu, autoload adı, dizin önekiyle) **geçişli** bağımlı tüm testler |
| değişen `test/**/test_*.gd` | o test dosyası |
| `docs/**.md` hiçbir testin bağımlılığı değilse | test yok (lint/veri doğrulama yine koşar) |
| **paylaşılan**: `scripts/sim/*`, `scripts/autoload/*`, `data/*`, `test/helpers/*`, `test/fixtures/*`, `test/long/*`, `tools/gate*`, `tools/ci/*`, `tools/*.{gd,json,txt,sh}`, `project.godot`, `.gutconfig.json`, `export_presets.cfg`, `addons/*`, `.github/*`, `assets/*`, `art/*`, `audio/*`, `themes/*`, `scenes/*` | **TAM GATE** |
| eşlemede yeri olmayan dosya (yeni betik, bilinmeyen dizin, kök dosyaları) | **TAM GATE** |
| eşleme güncel değil (`test_map.py check` kırmızı), taban bulunamadı, seçim hatası | **TAM GATE** |

Karışık değişiklikte tek bir paylaşılan/eşlemesiz dosya tam gate'e düşürür. Şüphede tam suite. Hızlı modda lint yalnız değişen
`.gd` dosyalarına, Python testleri yalnız değişen araç dizinine (`tools/art`, `tools/audio`) uygulanır; veri doğrulaması her
zaman koşar; adım 7'de asgari test sayısı seçilen dosyalar için, tek test süre sınırı aynen denetlenir. Dilim/pending denetimi
tam JUnit ister ve yalnız tam gate'tedir.

Eşleme bakımı: yeni betik/test eklenince `python3 tools/ci/test_map.py generate`; `tools/ci/tests/test_test_map.py`
güncel olmayan eşlemeyi kırmızı yapar (bu test tam gate'in Python adımında koşar).

### Eşlemenin doğruluğu

- `test_test_map.py`: eşleme güncel; gate'in koştuğu her test dosyası eşlemede ve kendi değişince kendini seçiyor (**sahipsiz test
  yok**); paylaşılan dosya örnekleri `FULL`; eşlemesiz dosya `FULL`; karışık değişiklikte `FULL`; yorum satırındaki sınıf adı
  bağımlılık sayılmaz.
- `python3 tools/ci/backtest_map.py --count 120 --no-merges`: geçmiş commit'lerin diff'ine eşlemeyi (o commit'in ağacından kurulur,
  checkout gerekmez) uygular; değişen her test ve değişen kaynağa doğrudan başvuran her test seçimde değilse çıkış 1.
  Sonuç ve kasıtlı-kırma sınaması: bölüm 5.

## 4. Ölçüm

(Yerel ölçüm: 4 çekirdekli bulut makinesi; CI makinesinden farklıdır. Tablo `.gate/times.log`, JUnit ve `GATE_SLOW_INFO`
çıktılarından.)

Önce (tek süreç, `bash tools/gate.sh`):

| Adım | sn |
|---|---|
| 1. Godot kurulumu | 0 |
| 2. İçe aktarma (soğuk) | 65 |
| 3. Lint (gdformat + gdlint) | 58 |
| 4. Veri doğrulama | 0 |
| 4b. Dilim sözdizimi | 1 |
| 5. Python testleri (231) | 83 |
| 6. GUT (2150 test, 212 dosya) | 688 |
| 7. Sahte yeşil korumaları | 0 |
| **Toplam** | **~895** (CI duvar saati = toplam iş süresi; sınır 15 dk) |

(T25-56 raporu 617 sn; bu makine daha yavaş. Oran korunur.)

GUT'ta en yavaş 10 test (sn): `test_ver_v11_invariants::test_p20_late_game_crowd_invariants...` 74,0; `test_pickup_director::test_kind_distribution_follows_weights` 51,0;
`test_acc_v2_ach_determinism::test_b3_observer...` 23,4; `test_stress_run::test_run_finishes...` 22,0;
`test_acc_v11_pickups::test_p20_invariants_empty_every_60_steps...` 21,9; `test_acc_v11_determinism::test_same_seed_same_hash...` 20,3;
`test_ver_v11_invariants::test_p20_early_game...` 18,6; `test_v202_wind_golden::test_zyfen_u3_live_run_equals_record_twice` 16,8;
`test_ver_known_gaps::test_f_ver_002...` 16,4; `test_ver_f020_regression::test_f_ver3_001_f021_single_enemy...` 15,5.
En ağır dosyalar (toplam sn): `test_ver_v11_invariants` 105; `test_pickup_director` 57; `test_ver_f020_regression` 46; `test_acc_v11_pickups` 45.
En ağır dosya (105 sn) parça tabanını belirler.

Sonra (dört GUT parçası, ağırlık toplamı parça başına ≈ 168 sn; ölçümler bölüm 6 tablosunda).

## 5. Doğrulama kayıtları

Bölüm 6 ve rapor: parça koşuları, kasıtlı-kırma sınaması, geriye dönük sınama, prova matrisi.
