---
name: ab-test-ve-kapi
description: Ashen Bastion'a yeni test dosyası, test yardımcısı, araç veya CI işi eklerken (test kimliği kapısı, test_map, shard_weights, süre bütçesi, karakterizasyon adlandırması, geri alma) kullan.
---

# Test, kapı ve CI

Kapı komutu: `bash tools/gate.sh` (tam kapsam). CI aynı kapsamı parçalayarak koşar: `GATE_PART=static|gut|verify` (`.github/workflows/ci.yml`, `docs/dev/ci-speed.md`). `--changed` yalnız yerel hızlı geri bildirimdir.

## Adımlar
1. **Test yaz:** birim `test/unit/`, kabul `test/acceptance/` (kabul/E2E tester'ındır), ağır koşular `test/long/`. Adlandırma: dilim önekleri (`test_acc_v2_*`, `test_v202_*`); açık bulguyu sabitleyen test `karakterizasyon (F-xxx)`; kusurlu davranışı beklenen değer yapma, bulgu kimliğine bağlı `pending`.
2. **Kayıtlar:** asgari sayı tablosu emekli (el ile sayı yükseltilmez): kapı `check_test_ids.py` kimlik kapısıdır, yeni `func test_*` otomatik izlenir; `tools/ci/test_map.json` artık izlenmez, gate üretir (`python3 tools/ci/test_map.py ensure`; elle commit yok); silinen/taşınan test `tools/ci/removed_tests.txt` / `moved_tests.txt`'e yazılır (`check_test_ids.py`); parça ağırlıkları `tools/ci/shard_weights.json`.
3. **Geri alma:** global/önbellek durumuna (GameData, Settings) yazan test `after_each` ile geri alır; `user://` sızıntısı kırmızıdır (`tools/ci/user_leak_allow.txt`).
4. **Süre bütçesi:** test dosyası ≤ 75 sn (`python3 tools/ci/check_durations.py`); yavaşsa `test/long/`. CI iş süresi sınıra %80 yaklaşınca bölme işi aç (`tools/ci/ci_budget.json`, `tools/ci/check_budget.py`).
5. **Harita/çarpışma/hareket değişirse** test botları (`test/helpers/bots.gd`) ve kısa koşu testleri aynı fazda.
6. **Araç ekliyorsan** çıktı klasörünü aynı commit'te `.gitignore`'a ekle.
7. **CI işi:** `.github/workflows/ci.yml`; job `env`'de `${{ runner.temp }}` kullanılmaz; `actionlint`; gate'e adım eklenirse `tools/ci/tests/test_ci_workflow.py` güncellenir.
8. **Paralel fazlar** ortak kayıt dosyalarını (dilim dosyaları, `removed_tests.txt`/`moved_tests.txt`) aynı anda değiştirmez; sözleşme fazı önceden hazırlar, satır başına birleştirilebilir biçim seçer.

## Dokunulan dosyalar
`tools/gate.sh`, `tools/ci/check_test_ids.py`, `tools/ci/test_map.json`, `tools/ci/shard_weights.json`, `tools/ci/ci_budget.json`, `tools/ci/check_durations.py`, `.github/workflows/ci.yml`, `tools/ci/tests/`.

## Doğrulama
`python3 -m pytest -q -p no:cacheprovider tools/ci/tests`; `python3 tools/ci/test_map.py check`; gate; lint: `gdformat --check scripts tools test` ve `gdlint scripts tools test`.

## Kontrol listesi
- [ ] Yeni test pending/sıfır-test olarak kalmadı; silinen/taşınan test `removed_tests.txt`/`moved_tests.txt`'te.
- [ ] `after_each` geri alma var; `USER_LEAK` yok.
- [ ] Süre ≤ 75 sn; CI süre payı sınırın %80'inin altında.
- [ ] Türkçe `to_upper/to_lower` yok (`UiKit.upper_tr`).
- [ ] Yasaklı ad denetimi (`tools/ci/check_forbidden_names.sh`): desen `GATE_FORBIDDEN_RE` secret'ından, repoya yazılmaz.
