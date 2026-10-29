---
name: ab-test-ve-kapi
description: Ashen Bastion'da push öncesi akış (precheck, yerel Godot, gate --changed, CI izleme, JUnit), yeni test/araç/CI işi, test kimliği kapısı, satır tavanı ve katman matrisi, karakterizasyon bazı veya mutasyon kanıtı gerektiğinde kullan.
---

# Test, kapı ve CI

Tam kapı: `bash tools/gate.sh`. CI aynı kapsamı parçalayarak koşar (`GATE_PART=static|gut|verify`, `.github/workflows/ci.yml`, `docs/dev/ci-speed.md`). `--changed` yalnız yerel hızlı geri bildirimdir ve kabul yerine geçmez.

## Push öncesi akış (sırayla)
1. **`bash tools/precheck.sh`** (Godot'suz, saniyeler): değişen dosyalarda test_map (`ensure`), gdformat, gdlint, `to_upper/to_lower` (UPPER_LOWER), `.sh` kipi 100755 (SH_MODE), pytest `-k "not slow"`, satır tavanı, UI kuralı, katman, test kimlikleri (static). Hata: stderr `PRECHECK_FAIL: <sınıf>: <ayrıntı>`, çıkış 1. **Atlanan sınıf yeşil değildir:** `PRECHECK_SKIP: <sınıf>: <neden>` (araç yok / Windows'ta pytest / Godot'lu sınıflar) görünür; atlananı raporda "koşulmadı" diye say. Taban `--base REF` (varsayılan origin/main; entegrasyon dalındaysan `--base vlad/<entegrasyon>`, yoksa main'den gelen eski `UPPER_LOWER` yanlış pozitifi çıkar).
2. **Yerel Godot varsa `bash tools/precheck.sh --godot`** = precheck + `gate.sh --changed` (USER_LEAK ve değişikliğe bağlı birim/içerik testleri). `GODOT_BIN` zorunlu, yoksa `PRECHECK_FAIL: GODOT`.
3. **Yerel Windows kurulumu (altyapı-B):** `Godot_v4.7.2-stable_win64_console.exe` (SHA512 release `SHA512-SUMS.txt` ile; `checksums.txt`'te win64 yok), `export GODOT_BIN=/c/.../Godot_v4.7.2-stable_win64_console.exe`, **Git Bash** (cmd/PowerShell değil), PATH'te çalışan `python3` (Git Bash'te `python3` Microsoft Store takma adıdır: `python`'a yönlendiren sarmalayıcı koy), gdtoolkit (venv, `pip install -r tools/ci/requirements-ci.txt`), `GATE_JOBS=1`. Ölçülen: `--import` ~66 sn, tek test dosyasıyla `gate.sh --changed` ~16 sn. Windows'ta tam `gate.sh` ve `tools/ci/tests` pytest ortam kırmızıları (godot_import, selftest_gate_groups, snapshot) verir: tam kapı için WSL2 ya da CI. `--import` sonrası çıkan izlenmeyen `.uid` ve değişen `addons/gut/**/*.import` dosyalarını commit'leme (yeni `.gd` ile kendi `.uid`'i aynı commit'tedir).
4. Yerel Godot yoksa kapı CI'dır; raporda "yerel GUT/Godot koşulmadı" yaz.
5. **Push** (yalnız `vlad/<id>` dalı) → `ci-triage` skill'i → **tek** `gh run watch <run-id> --interval 60 --exit-status` (GitHub API ikincil sınırı: yoklama döngüsü kurma; sık yoklama GitHub API ikincil sınırına takılıp 403 verir; 5 çalışan aynı anda izlerken yaşandı).
6. **Kırmızıda JUnit:** kapı GUT günlüğünü son 30 satıra kırpar; başarısız test adı/mesajı orada yoktur. `gh run download <run-id> -n gut-junit-<K>` (K = 1..4 parça) ile JUnit'i indir, `<failure>` içeren `testcase`'e bak. Bayat kırmızı sınıfı için `ci-triage`.

## Adımlar (içerik/test eklerken)
1. **Test yaz:** birim `test/unit/`, kabul `test/acceptance/` (kabul/E2E tester'ındır), ağır koşular `test/long/`. Adlandırma: dilim önekleri (`test_acc_v2_*`, `test_v202_*`); açık bulguyu sabitleyen test `karakterizasyon (F-xxx)`; kusurlu davranışı beklenen değer yapma, bulgu kimliğine bağlı `pending`.
2. **Test kimliği kapısı:** asgari sayı tablosu yok (eski dosya başına asgari-sayı tablosu ve güncelleme betiği silindi). `tools/ci/check_test_ids.py` kimlik kapısıdır: bildirilen her `func test_*` koşmalı, tabandaki kimlik kaybolmamalı; yeni test otomatik izlenir, sayı el ile yükseltilmez.
   - Test **silerken** `tools/ci/removed_tests.txt`: `id | gerekçe | görev/bulgu` (id = `yol::fonksiyon`).
   - Test **taşırken/bölerken/yeniden adlandırırken** `tools/ci/moved_tests.txt`: `eski -> yeni1, yeni2` (eski HEAD'de yok; tüm yeniler HEAD'de var; bir eski tek satır; bir yeni en çok bir eskiden).
   - Dilimden bağımsız çalışma anında `pending()` dönen bilinen test: `tools/ci/pending_allowed.txt` (`id | gerekçe | görev`). Dilim kapalıyken pending doğaldır; dilim açıkken pending/sıfır test kapıyı kırar.
3. **`test_map.json` izlenmez:** hızlı mod ve precheck `python3 tools/ci/test_map.py ensure` ile üretir; elle commit yok, "generate + commit" yok. Çakışma çıkarsa dosyayı üretilene bırak.
4. **Geri alma:** global/önbellek durumuna (GameData, Settings, `UiKit`/`ArtLoader`/`Sfx` önbellekleri) yazan test `after_each` ile geri alır; `user://` sızıntısı `USER_LEAK` ile kırmızıdır (`tools/ci/user_leak_allow.txt`). UI ekranı açan test `Settings.store_path`'i geçici yola alır.
5. **Satır tavanı (tek tip 800):** `scripts/**/*.gd` dosyası 800 satırı aşamaz (`check_line_budget.py`, gdlint 1000 × 0,8). Geçiş istisnası `tools/ci/line_budget_exceptions.txt` (`yol | tavan`) **yalnız azalır**: yeni satır/artış `LINE_BUDGET_RAISED`, dosya ≤ 800 olunca satır silinmezse `LINE_BUDGET_STALE`. Büyük dosyada mantığı ayrı sınıfa çıkar; istisna ekleme.
6. **Katman matrisi:** `check_layers.py` `scripts/**` bağımlılığını denetler (sim, store, domain, validate, view, autoload, ui, ctrl, audio, debug). **sim → store/ui/ctrl yasak**; ilke ihlali `LAYER_VIOLATION`. İstisna `tools/ci/layer_exceptions.txt` (`kaynak -> hedef`) **yalnız azalır** (`LAYER_NEW_EXCEPTION`, `LAYER_STALE`); ilk listeyi `--emit-baseline` üretir, elle yazılmaz. Yeni kodda önce `domain`'e koy ya da bağımlılığı tersine çevir.
7. **Karakterizasyon güvenlik ağı:** `test/characterization/baseline/*.json` refactor öncesi davranışın ölçülmüş bazıdır (`test/acceptance/test_acc_rf_*`). Baz **yalnız gerekçeli** değişir: değişen dosyanın sha256'sı `tools/ci/baseline_changes.txt`'e `dosya | sha256 | gerekçe | görev` satırıyla eklenmezse gate kırmızıdır (`BASELINE_CHANGED`, `test_rf_baseline_guard.py`). Baz değeri CI JUnit'inden `tools/ci/rf_extract_baselines.py` ile ayıklanır (kapı günlüğü kırpılır). Yeni public alan/metot/sinyal `rf_api_surface` bazını kırar: iç durumu `_` önekli tut. Baz değişikliğini "testi yeşile çekmek" için yapma; davranış bilerek değiştiyse gerekçeyi yaz.
8. **Mutasyon kanıtı (kapı değil, dilim kabulü):** `GODOT_BIN=<godot> bash tools/ci/mutation_check.sh test/characterization/mutations/<ad>.patch test/unit/test_x.gd ...` yamayı uygular, testleri koşar, **kırmızı** bekler, yamayı geri alır. Çıkış 0 = mutasyon öldü; 1 = `MUTANT_SURVIVED` (test zayıf); 2 = yama/test yüklenemedi (öldürme sayılmaz).
9. **Süre bütçesi:** test dosyası ≤ 75 sn (`python3 tools/ci/check_durations.py`); yavaşsa `test/long/`. CI iş süresi sınırın %80'ine yaklaşınca bölme işi aç (`tools/ci/ci_budget.json`, `tools/ci/check_budget.py`). Parça ağırlıkları `tools/ci/shard_weights.json` (`tools/ci/refresh_weights.py --junit … --write`).
10. **Harita/çarpışma/hareket** değişirse test botları (`test/helpers/bots.gd`) ve kısa koşu testleri aynı fazda.
11. **Araç ekliyorsan** çıktı klasörünü aynı commit'te `.gitignore`'a ekle.
12. **CI işi:** `.github/workflows/ci.yml` (`push: [main, 'vlad/**']`, `pull_request` yok; job `env`'de `${{ runner.temp }}` kullanılmaz; her işte `timeout-minutes`); `actionlint`; gate'e adım eklenirse `tools/ci/tests/test_ci_workflow.py` güncellenir. Yeni ön denetim `tools/ci/checks.d/NN-ad.sh` (gate adım 0, ad sırasıyla, ilk kırmızıda durur).
13. **Paralel fazlar** ortak kayıt dosyalarını (dilim dosyaları, `removed_tests.txt`/`moved_tests.txt`, istisna dosyaları) aynı anda değiştirmez; sözleşme fazı önceden hazırlar, satır başına birleştirilebilir biçim seçer.

## Dokunulan dosyalar
`tools/gate.sh`, `tools/precheck.sh`, `tools/ci/{check_test_ids,check_line_budget,check_layers,check_ui_rules,check_durations}.py`, `tools/ci/{removed_tests,moved_tests,pending_allowed,baseline_changes,line_budget_exceptions,layer_exceptions,ui_rules_exceptions}.txt`, `tools/ci/shard_weights.json`, `tools/ci/ci_budget.json`, `tools/ci/checks.d/`, `.github/workflows/ci.yml`, `tools/ci/tests/`, `test/characterization/`.

## Doğrulama
`bash tools/precheck.sh` (+ `--godot`); `python3 -m pytest -q -p no:cacheprovider tools/ci/tests` (Windows'ta `PYTHONUTF8=1`, ortam kırmızıları taban dalda da vardır: karşılaştır); tam kapı CI'da; lint: `gdformat --check scripts tools test` ve `gdlint scripts tools test`.

## Kontrol listesi
- [ ] `precheck.sh` temiz; `PRECHECK_SKIP` satırları raporda "koşulmadı".
- [ ] Yeni test pending/sıfır-test kalmadı; silinen/taşınan test `removed_tests.txt`/`moved_tests.txt`'te.
- [ ] `after_each` geri alma var; `USER_LEAK` yok.
- [ ] Süre ≤ 75 sn; CI süre payı sınırın %80'inin altında.
- [ ] Hiçbir `scripts/**/*.gd` > 800 satır; istisna dosyalarına satır eklenmedi (`LINE_BUDGET_RAISED`/`LAYER_NEW_EXCEPTION` yok).
- [ ] `baseline/` değiştiyse `baseline_changes.txt` satırı + gerekçe; değişmediyse `BASELINE_CHANGED` yok.
- [ ] Türkçe `to_upper/to_lower` yok (`UiKit.upper_tr`).
- [ ] CI izleme tek `gh run watch <id> --interval 60`; kırmızıda `gut-junit-<K>` artifact'ı okundu.
- [ ] Yasaklı ad denetimi (`tools/ci/check_forbidden_names.sh`): desen `GATE_FORBIDDEN_RE` secret'ından, repoya yazılmaz.
