# v2.0.2 S2 — karar ve ölçüm notları

## Gate süre tabanı (yerel, 4 çekirdek, S2 sonu)
Toplam 435 sn (CI bütçesi 15 dk = %48): GUT 370 sn, pytest 31 sn, lint 24 sn, import 10 sn. >20 sn testler (bilgi): `test_ver_v11_invariants::test_p20_late_game…` 41,9 sn, `test_pickup_director::test_kind_distribution…` 28,5 sn (S2 öncesi; dokunulmadı). Yeni S2 testleri < 1 sn. Kural: yeni test ≤ 20 sn, aşanlar `test/long`. `tools/ci/ci_budget.json` + `check_budget.py` (gate sonunda uyarı, %80) + `test_ci_budget.py` (ci.yml sınırlarıyla tutarlılık). selftest işi (20 dk) tam-gate senaryoları ≈ 7 dk/grup; K turlarında izlenir.

## Gate denetimleri gerçekten koşuyor
`test_selftest_gate_groups.py` (pytest adımı, geçti) ve `user_leak` (GUT adımı: yeni testler `USER_LEAK` üretmedi; izin listesi boş kaldı). `check_slices.py --v202` gate adım 4b ve 7'de.

## AudioDirector (audio_director.gd:250) karar notu
`_on_shot` karaktere bakmadan `shot_right/left` çalar. Öneri (A4, kullanıcı sesleri gelince): karakter JSON'una isteğe bağlı `sfx` sözlüğü (`shot`, `reload`) eklenir, `AudioDirector` yoksa mevcut varsayılana düşer (evrim sesindeki `sfx` kalıbı). S2'de kod değişmedi; yalnız 6 ses dosyası var, Zyfen için ayrı kayıt yok.

## Yasak-ad kuralı
`tools/gate.sh` yalnız `to_upper/to_lower` denetler; `git grep` yasak-ad kuralı gate'te YOK (plan: bu sürümde eklenmez). U1 kabulüne tek seferlik elle kontrol kalır.

## Varsayımlar
- Planın "fast" politikası koşucuda yok; `greedy` kullanıldı (bilgi amaçlı).
- `--file` = dilim dosyası (konumsal bağımsız değişkenle eşdeğer). v2.0.2 testleri `--classname-re v202` ile ayrılır (v1.1 `test_p20_` adı çakışması).
- `hp_mid` "ölen koşu 0" tanımı harfiyen uygulandı; ayırt ediciliği düşük (baseline README).
- `make_zyfen_strip.py`: S2 de bir sürüm yazmıştı (stand/glob girdili, `--palm-px`); U2 gerçek karelerle kendi sürümünü merge ettiği için çakışmada U2 sürümü esas alındı, S2 sürümü atıldı (palm ölçümü yok; K `palm` testi gerekirse U2 aracına eklenmeli).
