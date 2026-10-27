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
  `tools/gate_min_tests.json`, tek test ≤ 75 sn, dilim/pending denetimleri) **aynen** koşar. Parçası düşen ya da hiç koşmayan
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

Sonra (CI benzetimi: her iş temiz kopyada, soğuk `.godot` ile ve yalnız başına; `tools/gate.sh` parçaları, aynı makine):

| İş | sn | Ayrıntı |
|---|---|---|
| static | 170 | içe aktarma 50, lint 44, veri 1, Python testleri 75 (259 test) |
| gut 1/4 | 209 | içe aktarma 47 + GUT 162 |
| gut 2/4 | 274 | içe aktarma 104 (**F-042 SIGABRT, bir yeniden deneme**) + GUT 170 |
| gut 3/4 | 236 | içe aktarma 52 + GUT 184 |
| gut 4/4 | 218 | içe aktarma 48 + GUT 170 |
| test (verify) | ~2 | birleştirme + adım 7 |
| **Duvar saati** (işler paralel) | **≈ 240–280** | en yavaş iş + verify (önce ≈ 895) |
| **Toplam iş süresi** | ≈ 1110 | her GUT işi kendi içe aktarmasını yapar (önce ≈ 895) |

Duvar saati ≈ %70 düşer; toplam iş süresi ≈ %24 artar (4× içe aktarma). `.godot` önbelleği isabet ettiğinde içe aktarma ≈ 11 sn'dir
(ölçüm: önbellekli 11 sn, soğuk 49 sn; tüm dosyaların mtime'ı yeni iken). CI makinesinde ölçülmedi (bölüm 7).

**Kapsam aynı:** birleşik JUnit = tam gate JUnit'i ile aynı test seti: 212 dosya, 2150 test (144 pending, önce de 144);
`(classname, ad)` kümeleri birebir eşit. Python testleri 231 -> 259 (bu işin 28 yeni testi).

## 5. Doğrulama kayıtları

- **Kasıtlı-kırma (mutasyon) sınaması** (`tools/ci/prova_test_map.py`): 6 eşlenmiş betiğin (hud, music_plan, highscores,
  walk_cycle, hit_stop, showcase_motion) her işlevi `push_error` ile bozuldu; TAM suite 4 parçada koşuldu: 212 dosyanın **46'sı
  kırmızı, 46'sı da** eşlemenin seçtiği 57 dosyanın içinde (**kaçan 0**, fazla seçim 11).
- **Geriye dönük sınama** (`tools/ci/backtest_map.py`; her commit için eşleme o commit'in ağacından): son 120 tekil commit:
  71 FULL, 49 kısmi seçim, **ihlal 0** (değişen her test ve değişen kaynağa doğrudan başvuran her test seçimde). Son 24 first-parent
  (PR merge) commit: 21 FULL, 3 kısmi, ihlal 0 (büyük PR'lar `data/`/`scripts/sim` değiştirdiği için tam gate'e düşer).
- **Hızlı mod uçtan uca:** `scripts/ui/toast_queue.gd` değişikliği: 26 test dosyası / 302 test, toplam 84 sn
  (`GATE_FAST OK (KISMİ ...)`); yalnız `docs/dev/setup.md`: GUT yok, 11 sn; `data/skills/tufan.json` ya da `tools/gate.sh`
  değişikliği: "TAM GATE koşuluyor" (tam gate'e düştü); `CI=true` ile çıkış 2.
- **Selftest:** 11 senaryo / 6 grup OK (aşağıdaki not).
- **Prova matrisi** (umask 077, `bash -s`, yetkisiz kullanıcı, eksik/yinelenen parça, ikinci koşu): raporda.

## 6. Bilinen sınırlar

- **60 sn tek-test sınırı (`check_durations.py`) bu makinede aşılıyor.** `test_p20_late_game_crowd_invariants...` burada 66–74 sn
  (T25-56 raporundaki makinede 56 sn); sınır değişmedi (duvar saati eşiği, kapsam azaltmaz). Bu makinede tam `gate.sh` yalnız bu
  sınır yüzünden kırmızıdır; sınır 100'e çıkarılınca (geçici yerel yama, commit'lenmedi) aynı commit'in tam gate'i ve 11 selftest
  senaryosu GATE OK / OK verdi. Eşik, testin kendisi hızlandırılana (kabul testi: tester alanı) kadar sınıra yakındır.
- **F-042 içe aktarma çöküşü:** parçalı CI beş (static + 4 gut) Godot içe aktarması yapar; her biri çöküş imzasına karşı
  tek yeniden denemeyle korunur (`godot_import.sh`). Benzetimde 5 içe aktarmadan 1'i çöktü ve yeniden denemeyle geçti.
  Çöküş editör açılışında olduğundan `.godot` önbelleği riski azaltmaz.
- Bağımlılıklar yalnız doğrudan sabitlendi (`requirements-ci.txt`); gdtoolkit'in geçişli bağımlılıkları (lark, vb.) sabit değil.

## Tek-test süre sınırı 60 -> 75 sn (F-ashen-bastion-048)

`tools/ci/check_durations.py --limit` varsayılanı, `tools/gate.sh` hata mesajları ve `docs/dev/setup.md` 75 sn oldu. Bu **geçici**dir (kullanıcı kararı 2026-10-25); kalıcı çözüm testi hızlandırmaktır.

## Yerel tam gate: paralel GUT (F-066, T20261026-75)

Sorun: tek süreçli `bash tools/gate.sh` 819 sn'ye çıktı (15 dk = 900 sn bütçenin %91'i); GUT adımı süreyi belirler
(`tools/ci/shard_weights.json` toplamı ≈ 686 sn / 226 dosya). Bulut çalışanları da bu gate'i koşar.

Çözüm (kapsam aynı, hiçbir test taşınmadı/atlanmadı): tam gate adım 6'yı `tools/ci/run_gut_parallel.sh` ile **N paralel
Godot sürecinde** koşar. N = `GATE_JOBS` (varsayılan `min(4, çekirdek)`; `GATE_JOBS=1` eski tek süreç yolu).
- Parçalama CI ile aynıdır (`shard.py config K N`, LPT, `shard_weights.json`); her süreç kendi JUnit/günlüğünü yazar.
- **Kendi `XDG_DATA_HOME`'u:** `user://` süreç başına ayrıdır. Ortak olsaydı USER_LEAK denetimi (kanca taban/son karşılaştırır)
  başka parçanın geçici dosyalarını sızıntı sayardı.
- Kapsam kanıtı CI `test` işiyle aynı: `shard.py check-merge --require-all` (eksik/yinelenen/bilinmeyen dosya = kırmızı), sonra
  `shard.py merge` -> `.gate/junit.xml`; adım 7 (asgari sayı, 75 sn, dilim/pending) birleşik JUnit üstünde aynen koşar.
- Hızlı mod (`--changed`) ve `GATE_PART=gut|static|verify` yolları değişmedi; CI işleri değişmedi (`ci.yml` aynı).
- Saat eşiği yok: testler yalnız ms'i raporlar (`test_acc_perf_counters`, `test_ver_crowd_perf`), duvar saatine iddia etmez;
  paralel yük sonuçları değiştirmez. Tek-test 75 sn sınırı yük altında tek test için daha riskli olabilir (en yavaş test 105 sn'lik
  dosyanın içindeki testlerden biri); kırmızı olursa `GATE_JOBS=2` ile ölçüp sınırı/testi ele alın.
- Öz-test: `tools/ci/tests/test_gate_parallel.py` (sahte Godot: kapsam, ayrı `user://`, kırmızı parça, eksik JUnit, USER_LEAK,
  bariyerle gerçek eşzamanlılık).

`test/long`'a taşıma (>20 sn testler) **yapılmadı**: `test/long` `.gutconfig.json` kümesinde değildir, taşıma gate kapsamını
düşürür; görev kuralı (kapsam aynı kalır) ile çelişir.
