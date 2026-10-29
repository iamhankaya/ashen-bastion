---
name: ab-surum-kabul
description: Ashen Bastion'da bir sürümü/dilimi kabule hazırlarken (dilim işaretleri, tools/gate.sh, user-verify listesi, entegrasyon dalı aktarımı, tag/PR sınırı) kullan.
---

# Sürüm ve kabul akışı

## Adımlar
1. **Dilim işareti:** `tools/v202_slices.txt`, `tools/v2_slices.txt` (önkoşul: kabul testleri yeşil, user:// sızıntısı yok, `tools/gate_min_tests.json` yükseltilmiş: `bash tools/update_min_tests.sh`). Sözdizimi: `python3 tools/ci/check_slices.py --v202 tools/v202_slices.txt`. Kapalı dilimde kabul testi `pending` döner; yerelde `V202_SLICES_FORCE=<simge>` ile zorla (F-050: v2.0.2 dilimleri bilinçli kapalı mı sorusu açık).
2. **Gate:** `bash tools/gate.sh` (isteğe bağlı `GATE_EXPORT=1`, `GATE_RENDER=1`). Aynı anda tek gate koş. `--changed` yalnız yerel geri bildirimdir ("GATE_FAST OK (KISMİ)"), kabul yerine geçmez.
3. **Entegrasyon:** rapordan önce entegrasyon dalını kendi dalına al (`git merge origin/<entegrasyon>`), lint + gate; ortak dosyalarda (controller satır tavanı, `ci.yml`) pay bırak.
4. **Cihaz listesi:** faz kendi bölüm dosyasını yazar (`docs/dev/user-verify/…`); ortak `docs/dev/user-verify.md` birleştirmesini doğrulama fazı yapar.
5. **Cihazda görülebilir hata:** debug APK'ya aç/kapa bayrağı + sayaç etiketi (ör. "düşman N/M", düzeltme AÇIK/KAPALI); kullanıcı iki durumu karşılaştırır.
6. **Etiket/PR sınırı:** sürüm etiketi kullanıcı makinesinden basılır (`docs/dev/release.md`). Çalışan tag, push (kendi dalı dışı), PR, merge yapmaz.

## Dokunulan dosyalar
`tools/v202_slices.txt`, `tools/v2_slices.txt`, `test/helpers/v202_slice.gd`, `tools/ci/check_slices.py`, `tools/gate.sh`, `tools/gate_min_tests.json`, `tools/update_min_tests.sh`, `docs/dev/user-verify.md`, `docs/dev/release.md`, `.github/workflows/ci.yml`.

## Kontrol listesi
- [ ] Gate yeşil; kırmızıysa çıktısıyla rapor, kapsam genişletilmez.
- [ ] Pipeline sürerken main'e düzeltme gittiyse aktarım fazı planlandı.
- [ ] Paralel fazlar `docs/dev/user-verify.md`'ye doğrudan yazmadı.
- [ ] Hata yalnız cihazda görülüyorsa debug bayrağı + sayaç var.
- [ ] Koşulamayanlar (export, render, cihaz) "koşulmadı" listesinde.
- [ ] Yasaklı ad denetimi yeşil ya da "atlandı" (`tools/ci/check_forbidden_names.sh`).

## Örnek
v2.0.2: `tools/v202_slices.txt`, `docs/dev/user-verify/` altındaki v2.0.2 bölüm dosyaları.
