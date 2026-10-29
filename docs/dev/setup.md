# Geliştirme ortamı kurulumu (C0 doğrulamasının kaydı)

Kart gate komutu: `bash tools/gate.sh` (çıkış 0 yeşil, 1 kırmızı, 2 kullanım hatası, 3 ağ yok). CI aynı kapsamı üç parçalı işle (static, gut×4, test) koşar; yalnız yerel hızlı geri bildirim için `bash tools/gate.sh --changed` vardır (`GATE OK` yazmaz; PR CI'ı/merge/son kapı her zaman tam suite): bkz. `docs/dev/ci-speed.md`.
İsteğe bağlı bayraklar: `GATE_EXPORT=1`, `GATE_NIGHTLY=1`, `GATE_RENDER=1`.

## Push öncesi ve yerel Windows

Push öncesi her zaman `bash tools/precheck.sh` (Godot'suz, değişen dosyalarda: test_map, gdformat, gdlint, `to_upper/to_lower`, `.sh` kipi, pytest, satır tavanı 800, UI kuralı, katman matrisi, test kimlikleri). Hata `PRECHECK_FAIL: <sınıf>: <ayrıntı>`, çıkış 1; araç yoksa ya da sınıf platformda güvenilmezse `PRECHECK_SKIP: <sınıf>: <neden>` yazılır (atlanan sınıf yeşil sayılmaz; Windows'ta pytest atlanır). `--godot` Godot'lu sınıfları ekler (`gate.sh --changed`: USER_LEAK, değişikliğe bağlı birim/içerik testleri); `--base REF` tabanı verir (varsayılan origin/main). precheck tam kapının yerine geçmez: PR CI'ı ve son kapı her zaman tam gate'tir. Sınıf listesi ve akış: `.claude/skills/ab-test-ve-kapi/SKILL.md`.

Yerel Windows Godot (altyapı-B, T20261029-02 ölçümü): `Godot_v4.7.2-stable_win64_console.exe` + **Git Bash** + `export GODOT_BIN=/c/.../Godot_v4.7.2-stable_win64_console.exe`. Git Bash'te `python3` Microsoft Store takma adıdır: `python`'a yönlendiren bir `python3` sarmalayıcısını PATH'e koy. gdtoolkit için venv (`pip install -r tools/ci/requirements-ci.txt`) ve `GATE_JOBS=1`. Ölçülen: `--import` ~66 sn, `validate_data` 1 sn, tek test dosyasıyla `gate.sh --changed` ~16 sn. Yerelde çalışmayan: tam `gate.sh` (Windows'ta `tools/ci/tests` ortam kırmızıları: godot_import, selftest_gate_groups, snapshot; UTF-8 olmayan konsolda `PYTHONUTF8=1`); tam kapı için WSL2 ya da CI. `.gitattributes` LF'yi zorlar (CRLF `.sh` dosyalarını bozar).

## Sabitlenen sürümler (2026-10-23'te doğrulandı)

| Bileşen | Sürüm | Kaynak / doğrulama |
|---|---|---|
| Godot | `4.7.2-stable` (`.godot-version`) | `github.com/godotengine/godot-builds/releases/download/4.7.2-stable/`; SHA512 `tools/ci/checksums.txt` |
| GUT | `9.7.1` (`addons/gut/`, `VERSION.txt`) | `bitwes/Gut` tag `v9.7.1` (commit `aeb5d4f`), git ile klonlanıp `addons/gut` kopyalandı |
| gdtoolkit | `4.x` (4.5.0 ile denendi) | `pip install "gdtoolkit==4.*"` |

Yedek sürüm `4.6.3-stable` kullanılmadı: 4.7.2 indirilebildi ve çalıştı.

## Ölçülen davranışlar

- `godot --headless --import` boş projede çıkış 0, ~12 sn.
- GUT (`gut_cmdln.gd -gconfig=res://.gutconfig.json`): başarılı koşuda çıkış **0**, başarısız testte çıkış **1** (ölçüldü).
- Ayrıştırma hatasında Godot'un çıkış kodu güvenilir değildir; bu yüzden gate günlüğü `^(SCRIPT ERROR|Parse Error|ERROR:)` ile tarar (izin listesi yok) ve JUnit toplamı sıfırsa ya da dosya başına asgari sayının altındaysa kırmızı verir.
- `gdformat`/`gdlint` Godot 4.7 uyumlu iskelet kodunu ayrıştırır. Godot ≥4.5'e özgü yeni sözdizimi (abstract, variadic argümanlar) kullanılmaz.

## Ağ

- Bulutta GUT için `github.com/bitwes/Gut` arşiv/release indirmeleri proxy'den 403 verir; `git clone` (anonim) çalışır. GUT vendor edilmiştir, tekrar indirmek gerekmez.
- Godot indirmesi başarısızsa `ensure_godot.sh` `GATE_NET: <host> erişilemiyor — Godot indirilemedi` yazar ve **çıkış 3** verir; gate de 3 döner. Gate'siz ilerlenmez.
- Ortam alan adları: `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` (+ export için `dl.google.com`, `maven.google.com`).

## Gate adımları

0. ön denetim kancası (`tools/ci/run_checks.sh`, `tools/ci/checks.d/NN-ad.sh`: satır tavanı, test kimlikleri, katman, UI kuralı; yalnız static/all; ilk kırmızıda `GATE FAIL`) 1. `ensure_godot.sh` 2. `--import` 3. `gdformat --check` + `gdlint` + `to_upper/to_lower` grep 4. `tools/validate_data.gd` 5. pytest 6. GUT (`test/unit`, `test/acceptance`) 7. günlük taraması, JUnit test kimliği kapısı (`tools/ci/check_test_ids.py`: bildirilen her `func test_*` koşmalı, tabandan kimlik kaybolmamalı; silinen/taşınan test `tools/ci/removed_tests.txt` / `moved_tests.txt`'e yazılır, el ile sayı güncellenmez).

Öz-test: `bash tools/ci/selftest_gate.sh` (bozuk `.gd`, anlamsal hata, boş test dizisi, test kimliği kaybı (`LOST`), koşmayan test (`MISSING`), `Stub.todo`, ağ yok → 3).
11 senaryo `GROUP[...]=N` tablosuyla 6 gruba bölünmüştür (F-028): `selftest_gate.sh --group N` yalnız o grubu, `--list` tabloyu yazar;
`ci.yml` `selftest` işi `matrix.group` ile her grubu ayrı iş olarak koşar (`fail-fast: false`, `timeout-minutes: 20`). Tam-gate senaryoları
(≈340 s) ayrı gruplardadır; en uzun grup ≈ 409 s (S0 ölçümü). Yeni senaryo = `scenario_<ad>()` + `GROUP[<ad>]=N` (tablo ↔ işlev uyumsuzluğunda çıkış 2;
`tools/ci/tests/test_selftest_gate_groups.py` matrisi de denetler). Gate süre denetimi: tek test > 75 sn → gate hatası (`tools/ci/check_durations.py`;
bilinçli istisna `test/long/`), toplam test süresi > 720 sn → `GATE_WARN` (durdurmaz); paralel GUT koşusunda (yerel/selftest tam gate, `GATE_JOBS`>1) süreler CPU çekişmesiyle şiştiği için denetim `--contended` çalışır (uyarı, hata değil; sert denetim CI parçalarında ve `GATE_JOBS=1`'de); `test` işi 15 dk sınırının %80'ine (12 dk) yaklaşırsa bölme işi açılır.

## Debug keystore

`tools/ci/debug.keystore` standart Android debug anahtarıdır (`android` / `androiddebugkey`); sır değildir. Release keystore repoda yer almaz (yalnız GitHub secret); imzalı release APK için bkz. [release.md](release.md).

## Debug APK (U1-10)

`bash tools/ci/export_debug.sh` (CI `export-debug` işi; `GATE_EXPORT=1 bash tools/gate.sh` de çağırır): Godot + export
şablonları (`ensure_godot.sh`), Android SDK/JDK (`ensure_android_sdk.sh`: runner'da hazır `ANDROID_HOME` + JDK 17, yoksa
sdkmanager), editör ayarı (`write_editor_settings.sh`), repodaki standart debug keystore ile imza, `apksigner verify`.
Çıktı `build/ab-debug.apk`; CI artifact adı `ashen-bastion-debug-apk`. Not: `export_presets.cfg`'de `min_sdk/target_sdk`
satırı yoktur (Gradle kapalıyken Godot bunu hata sayar); `project.godot`'ta ETC2/ASTC içe aktarma açıktır (Android şartı).
