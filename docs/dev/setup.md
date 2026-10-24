# Geliştirme ortamı kurulumu (C0 doğrulamasının kaydı)

Kart gate komutu: `bash tools/gate.sh` (çıkış 0 yeşil, 1 kırmızı, 3 ağ yok).
İsteğe bağlı bayraklar: `GATE_EXPORT=1`, `GATE_NIGHTLY=1`, `GATE_RENDER=1`.

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

1. `ensure_godot.sh` 2. `--import` 3. `gdformat --check` + `gdlint` + `to_upper/to_lower` grep 4. `tools/validate_data.gd` 5. pytest 6. GUT (`test/unit`, `test/acceptance`) 7. günlük taraması, JUnit asgari sayı (`tools/gate_min_tests.json`; yalnız `tools/update_min_tests.sh` ile bilinçli güncellenir).

Öz-test: `bash tools/ci/selftest_gate.sh` (bozuk `.gd`, anlamsal hata, boş test dizisi, asgari sayı altı, `Stub.todo`, ağ yok → 3).
11 senaryo `GROUP[...]=N` tablosuyla 6 gruba bölünmüştür (F-028): `selftest_gate.sh --group N` yalnız o grubu, `--list` tabloyu yazar;
`ci.yml` `selftest` işi `matrix.group` ile her grubu ayrı iş olarak koşar (`fail-fast: false`, `timeout-minutes: 20`). Tam-gate senaryoları
(≈340 s) ayrı gruplardadır; en uzun grup ≈ 409 s (S0 ölçümü). Yeni senaryo = `scenario_<ad>()` + `GROUP[<ad>]=N` (tablo ↔ işlev uyumsuzluğunda çıkış 2;
`tools/ci/tests/test_selftest_gate_groups.py` matrisi de denetler). Gate süre denetimi: tek test > 60 sn → gate hatası (`tools/ci/check_durations.py`;
bilinçli istisna `test/long/`), toplam test süresi > 720 sn → `GATE_WARN` (durdurmaz); `test` işi 15 dk sınırının %80'ine (12 dk) yaklaşırsa bölme işi açılır.

## Debug keystore

`tools/ci/debug.keystore` standart Android debug anahtarıdır (`android` / `androiddebugkey`); sır değildir. Release keystore repoda yer almaz (yalnız GitHub secret); imzalı release APK için bkz. [release.md](release.md).

## Debug APK (U1-10)

`bash tools/ci/export_debug.sh` (CI `export-debug` işi; `GATE_EXPORT=1 bash tools/gate.sh` de çağırır): Godot + export
şablonları (`ensure_godot.sh`), Android SDK/JDK (`ensure_android_sdk.sh`: runner'da hazır `ANDROID_HOME` + JDK 17, yoksa
sdkmanager), editör ayarı (`write_editor_settings.sh`), repodaki standart debug keystore ile imza, `apksigner verify`.
Çıktı `build/ab-debug.apk`; CI artifact adı `ashen-bastion-debug-apk`. Not: `export_presets.cfg`'de `min_sdk/target_sdk`
satırı yoktur (Gradle kapalıyken Godot bunu hata sayar); `project.godot`'ta ETC2/ASTC içe aktarma açıktır (Android şartı).
