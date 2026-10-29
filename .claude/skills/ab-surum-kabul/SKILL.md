---
name: ab-surum-kabul
description: Ashen Bastion'da bir sürümü/dilimi kabule hazırlarken (dilim işaretleri, tools/gate.sh, user-verify listesi, entegrasyon dalı aktarımı, tag/PR sınırı) kullan.
---

# Sürüm ve kabul akışı

## Adımlar
1. **Dilim işareti:** `tools/v202_slices.txt`, `tools/v2_slices.txt` (önkoşul: kabul testleri yeşil, user:// sızıntısı yok, dilimdeki test kimlikleri koşuyor: `python3 tools/ci/check_test_ids.py --mode full --junit <junit>`). Sözdizimi: `python3 tools/ci/check_slices.py --v202 tools/v202_slices.txt`. v2.0.2 durumu: **P R W Z E açık**, **A ertelendi** (F-ashen-bastion-128: A sınıfı testlerinde `test_a<N>_` öneki yok, bu yüzden simge açılamıyor; olası çözümler: testleri yeniden adlandırmak (`moved_tests.txt`) ya da A'yı profilden çıkarmak; karar açık, bulgu içeriği kb'dedir). Açık dilimde pending/sıfır test kapıyı kırar; kapalı dilimde kabul testi `pending` döner ve yerelde `V202_SLICES_FORCE=<simge>` ile zorlanır (yalnız kapalı simge için). İki aşamalı zorlu koşu: `tools/ci/v202_forced_run.sh` + `v202_forced_summary.py` (Linux/CI; sızıntı, gerçek kırmızı, pending ayrı raporlanır). Simge açmak ayrı commit, önkoşul: o dilimin testleri gerçek kodda yeşil.
2. **Kapı:** push öncesi `bash tools/precheck.sh` (+ `--godot`), tam kapı CI'da (`ab-test-ve-kapi`: tek `gh run watch <id> --interval 60`, kırmızıda `gut-junit-<K>`); yerelde tam `bash tools/gate.sh` yalnız Linux/WSL2 (isteğe bağlı `GATE_EXPORT=1`, `GATE_RENDER=1`; aynı anda tek gate). `--changed` yalnız yerel geri bildirimdir ("GATE_FAST OK (KISMİ)"), kabul yerine geçmez.
3. **Entegrasyon:** rapordan önce entegrasyon dalını kendi dalına al (`git merge origin/<entegrasyon>`), lint + precheck + CI; ortak dosyalarda (satır tavanı 800: `game_controller.gd` 784/800, `ci.yml`) pay bırak; istisna dosyaları (`line_budget_exceptions.txt`, `layer_exceptions.txt`) yalnız azalır, entegrasyonda satır geri gelmez.
4. **Cihaz listesi:** faz kendi bölüm dosyasını yazar (`docs/dev/user-verify/…`); ortak `docs/dev/user-verify.md` birleştirmesini doğrulama fazı yapar.
5. **Cihazda görülebilir hata:** debug APK'ya aç/kapa bayrağı + sayaç etiketi (ör. "düşman N/M", düzeltme AÇIK/KAPALI); kullanıcı iki durumu karşılaştırır.
6. **Etiket/PR sınırı:** sürüm etiketi kullanıcı makinesinden basılır (`docs/dev/release.md`). Çalışan tag, push (kendi dalı dışı), PR, merge yapmaz.

## Dokunulan dosyalar
`tools/v202_slices.txt`, `tools/v2_slices.txt`, `test/helpers/v202_slice.gd`, `tools/ci/check_slices.py`, `tools/gate.sh`, `docs/dev/user-verify.md`, `docs/dev/release.md`, `.github/workflows/ci.yml`.

## Kontrol listesi
- [ ] CI tam kapı yeşil (`test` bağlamı); kırmızıysa çıktısıyla rapor, kapsam genişletilmez.
- [ ] Pipeline sürerken main'e düzeltme gittiyse aktarım fazı planlandı.
- [ ] Paralel fazlar `docs/dev/user-verify.md`'ye doğrudan yazmadı.
- [ ] Hata yalnız cihazda görülüyorsa debug bayrağı + sayaç var.
- [ ] Koşulamayanlar (export, render, cihaz) "koşulmadı" listesinde.
- [ ] Yasaklı ad denetimi yeşil ya da "atlandı" (`tools/ci/check_forbidden_names.sh`).

## Örnek
v2.0.2: `tools/v202_slices.txt`, `docs/dev/user-verify/` altındaki v2.0.2 bölüm dosyaları.
