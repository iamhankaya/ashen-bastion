# T20261023-83 v1 doğrulama-3 — kapanış raporu

### Yapılanlar
- Entegrasyon: `git fetch origin vlad/T20261023-55:refs/remotes/origin/vlad/T20261023-55` + `git merge origin/vlad/T20261023-55` → "Already up to date". F-020 düzeltmesi (`enemy_ai.gd` dolanma modu, `ai_dir` `state_hash`'te) tabanda mevcut.
- Yeni `test/acceptance/test_ver_f020_regression.gd` (9 test); `tools/gate_min_tests.json` güncellendi (9). Üretim koduna dokunulmadı.
- İkon doğrulaması (kod değil, ölçüm): `GATE_EXPORT=1` ile debug APK derlendi, içerik incelendi (aşağıda).
- Birleşik cihaz kontrol listesi `docs/dev/user-verify.md` olarak yeniden yazıldı (16 madde, aşağıda aynısı).
- Ortamda `gdtoolkit==4.5.0`, pytest, pillow, numpy… `pip` ile kuruldu; Godot 4.7.2 `ensure_godot.sh` ile indi (kod değişikliği yok).

### Kapsam
| Alan | Test / kanıt |
|---|---|
| F-020: yeni tohumlar (4–9), tek düşman, düz + ±0,6 rad eğik, gerçek harita | `test_karakterizasyon_f_ver3_001_single_enemy_stuck_in_concave_real_ruins` (144 durum) |
| F-020: 8'li grup, yığılma ölçümü | `…group_of_8_stacks_at_concave_real_ruins` (96 durum) |
| Kamp (oyuncu sabit 60 sn), taraf salınımı | `…camping_player_locks_group_only_at_concave_ruins` (24 durum) |
| İçbükey: iki harabe arası dar boşluk (82 px; düşman 41,6 px, oyuncu 44 px), 5 kayıklık × {1, 8} düşman | `test_concave_gap_between_two_ruins_enemy_passes_when_passable` (**yeşil**, 10/10) |
| İçbükey: U kap, L köşe | `…concave_cup_traps_enemy_inside_pocket`, `…concave_l_corner_traps_enemy` (karakterizasyon) |
| Elit/Lord-dışı muafiyet: elit_piyade/sovalye/karga, uçan, hayalet harabeden geçer; yer düşmanı geçmez | `test_exempt_kinds_still_ignore_ruins_after_f020` |
| Determinizm: aynı tohum aynı hash (dolanma dahil), `ai_dir` değişince hash değişir | `test_same_seed_same_hash_with_detouring_enemies_and_ai_dir_is_in_the_hash` |
| Kalabalık: 376 yer düşmanı harabe yoğun bölgede, 600 adım, iş sayacı bütçesi, iki koşu özdeş | `test_crowd_of_376_ground_enemies_pressing_on_ruins_stays_under_work_budget` |
| Tam regresyon | Mevcut: `test_ver_end_to_end` (Lord ile kazanma, ölüm), `test_ver_boss_lord`, `test_boss_safety` (Lord her koşulda doğar), `test_ver_solid_ruins`, `test_ruin_collision` (oyuncu girmez/kayar), `test_cinzel_text` (Türkçe büyük harf), `test_hud_boss_bar`, `test_result_layout`, `test_ver_determinism_full`, `test_ver_crowd_perf` — hepsi gate'te yeşil |
| Release hattı | `bash tools/ci/prova_release.sh --fast` → **PROVA YEŞİL** (8 olumsuz senaryo, geçici keystore silindi) |
| İkon | `tools/art/tests/test_icons.py` 5/5; APK incelemesi aşağıda |

Ölçüm değerleri (sim, deterministik; gerçek harita tohum 4–9, düşman `curumus_piyade`, oyuncu sabit ve ölümsüz, düşman canı sonsuz):
| Senaryo | Sonuç |
|---|---|
| Tek düşman, düz + eğik, 30 sn | **137/144 ulaştı, 7 takıldı** |
| 8'li grup, düz + eğik, 35 sn | **90/96 ulaştı, 6 takıldı**; takılan gruplarda harabe yüzünde yığılan düşman toplamı 31 |
| 8'li grup, düz, 60 sn kamp (tohum 4–6) | 23/24, **1 takıldı**, yığılan 8; takılmayanlarda taraf değişimi **0** |
| Dar boşluk (geçilebilir) | 10/10 ulaştı (kayıklık 0/±150: 8,8–10,1 sn; kayıklık ±400: tek düşman 32–34 sn, 8'li 11 sn) |
| U kap (700×500, açık yan -y) | 6/6 **takıldı** (60 sn) |
| L köşe (iç köşede) | 4/4 **takıldı** (60 sn) |
| Önceki doğrulama-2 ölçümü (aynı yöntem, doğrudan arka, seed 1–3) | tek %33 / grup %50 takılıyordu → artık yeşil (`test_ver_enemy_behind_ruin` 2/2) |

Takılan gerçek-harita durumlarının hepsi 9–11 daireli büyük yapıdadır (tanı koşusu: ob12 r=234 seed 5; ob1 r=234 seed 9, komşu yok; ob34 r=156 seed 8). Yani tek yapının içbükey cebi yeter; komşu harabe şart değil.

İkon (APK `build/ab-debug.apk`, 41 MB, debug anahtarıyla imzalı, SHA-256 `2ffb1e34…fa2`):
- `export_presets.cfg` `launcher_icons/*` → `res://assets/icon/{main_192x192,foreground_432x432,background_432x432,monochrome_432x432}.png`; `project.godot` `config/icon="res://assets/icon/main_192x192.png"`.
- APK: `res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}-v4/` ve `res/mipmap/` altında `icon.webp`, `icon_foreground.webp`, `icon_background.webp`, `icon_monochrome.webp` var; `res/mipmap-anydpi-v26/icon.xml` = `<adaptive-icon>` (background, foreground, monochrome). `aapt2 dump badging`: `application: icon='res/mipmap-anydpi-v26/icon.xml'`.
- `icon_foreground.webp` 34–48 bayt, alfa%0: **bilerek boş** (`test_background_opaque_foreground_empty` bunu zorunlu kılıyor; sanat arka plan + monochrome katmanında). Cihazda maske altında görünüm kontrol listesinde (madde 3).
- `aapt2` uyarısı: `themed_icon.xml` dosya referansı yok (Godot şablonu; ikon çalışmasını etkilemez).

### Bulunan hatalar
| # | Önem | Bulgu |
|---|---|---|
| F-ver3-001 | **Orta** (düşük sıklık) | F-020 düzeltmesi düz arka-yüz durumunu giderdi (önceki %33/%50 → 0), ama düşman **içbükey cepli yapılarda hâlâ kalıcı takılıyor**: gerçek haritada tek düşman 7/144 (%4,9), 8'li grup 6/96 (%6,3), kamp 60 sn'de 1/24. U kap ve L köşe sentetik senaryolarında **hepsi** takılıyor. Kök neden (`enemy_ai.gd`): dolanma yerel tepkisel (hedef yönü ×0,5 + teğet ×0,866, taraf sabit; 1,5 sn'de 40 px'ten az ilerleyince taraf değişir). Hedefe yaklaştıran yönlerde bir cebin içinde iki taraf da çıkmazsa (kapta iki yan duvar, L'de iki kol) düşman cebin dibinde taraf değiştirerek salınır; cepten çıkmak için hedeften uzaklaşmak gerekir ve algoritma bunu yapmaz. Takılan düşman taraf salınımı yapar (en çok 8–20 değişim/60 sn), takılmayan her durumda salınım ≤1 (kenarda yön tersleme adım düzeyinde sayısı yüksek ama genlik ≈1 px/adım: titreme değil). Etki: oyuncunun yapının cebine karşı kamp yaparken sınırlı düşman baskısı yaratması; yalnız çok daireli içbükey yapılar. Elit/Lord/uçan/hayalet etkilenmez. |
| F-ver3-002 | Düşük | `assets/icon` önizleme/kaynak notu: foreground boş (tasarım gereği). Yanlış anlaşılmaması için cihaz maddesine eklendi. Hata değil. |
Kritik 0, yüksek 0.

### Kırmızı bırakılan testler
yok. F-ver3-001 testleri `karakterizasyon (F-xxx)` olarak **yeşil**: mevcut davranışı (7, 6, 1, 6/6, 4/4 takılan) sabitler; düzeltme gelince `assert_eq(stuck, 0)` olarak tersine çevrilir (testlerin açıklamasında yazılı).

### Test sonuçları
Temiz klon (`git clone --branch vlad/T20261023-83` GitHub'dan, ayrı dizin; head `3fd8c30` (testler); sonraki commit yalnız rapor ve `user-verify.md` belgelerini ekler): `GATE_RENDER=1 GATE_EXPORT=1 bash tools/gate.sh`:
- import, gdformat/gdlint, `to_upper/to_lower` taraması, veri doğrulama: temiz
- pytest: **40 geçti** (CI + art + audio)
- GUT: **65 betik, 502 test, 502 geçti, 0 kırmızı**, 18 282 doğrulama (≈188 sn)
- `check_junit` asgari test sayıları: geçti
- Debug APK: imzalı, 41 024 112 bayt, SHA-256 `2ffb1e3475186ddc6a580a5252899751defde2b0aa072813634f69313fe6afa2`
- Render smoke (xvfb, opengl3): temiz
- **GATE OK** (çıkış 0)
Ek: `prova_release.sh --fast` PROVA YEŞİL; `test_icons.py` 5 geçti. Kalabalık: 376 yer düşmanı harabe yoğun bölgede 600 adım ≈1,6–1,8 ms/adım (bulut CPU'su, yalnız bilgi), iş sayacı bütçe altında (enemy_updates 376 ≤ 500), iki koşu sayaç ve hash olarak özdeş.

### Kabul kriterleri
- [x] Temiz klonda gate (render + export) tam yeşil; kırmızı test yok.
- [x] F-020 doğrulandı (düz arka-yüz giderildi; içbükey kalıntı F-ver3-001 olarak belgeli, karakterizasyonlu), ikon doğrulandı (APK + test), doğrulama raporu ve birleşik cihaz kontrol listesi.
- Not: "içbükey köşe senaryosu ekle ve ölç" yapıldı; sonuç düzeltme kararı için aşağıda.

### Önerilen düzeltmeler
1. **F-ver3-001 (karar: v1'e mi, v1.1'e mi):** `enemy_ai.gd` dolanmasına çıkmaz tespiti: iki taraf da (taraf değişimi sonrası) ilerlemezse düşmana kısa süreli (≈2 sn) "kaçış" modu ver (hedeften uzaklaşan, ceplerin açık tarafına doğru; örn. son ilerleme çapasından geri yürüme + rastgele sabit sapma) ya da `MapSim`'de daire kümesinin dışbükey zarfına göre sanal itme. Doğrulama: test dosyasındaki 5 karakterizasyon testi `stuck=0`'a çevrilir. Sıklık düşük (%5, yalnız büyük içbükey yapılar) ve elitler etkilenmediği için v1 engeli sayılmadı.
2. Önceki açık düşükler (kod incelemesi #2/#6, F-ver2-002) izlemede, kapsam dışı.

### Cihaz kontrol listesi
(`docs/dev/user-verify.md` ile aynı; v1 için kullanıcıya verilecek tek liste.)
**A. Kurulum ve ikon**
1. CI artifact `ashen-bastion-debug-apk` → `ab-debug.apk` kur (bilinmeyen kaynak izni); sonraki CI APK'ları güncelleme olarak kurulur.
2. Menü: Türkçe harfler doğru (`İ`/`Ş`/`Ğ`), "ASH AND STEEL" üst yazısı başlığın üstüne sığıyor.
3. **Uygulama ikonu:** ana ekranda koyu bastion ikonu; yuvarlak/kare/damla maskede kesilme yok; Android 13+ temalı ikonda monochrome sürüm doğru. (Adaptive ön katman bilerek boş.)
**B. Oynanış (20 dk)**
4. Joystick her yerde belirir, parmak kalkınca durur; otomatik ateş; şarjör tamburu 6→0 + `↻` halkası (≈1 sn); XP taşı toplanır.
5. Seviye atlama: 3 kart (500 ms kilit); evrim kartı en altta; kart adları `İ` ile (ŞİFA, BARUT KESESİ, KIYAMET MERMİSİ…), kombo adları büyük harf.
6. Duraklat, geri tuşu (Devam Et), arka plana alınca otomatik duraklat, TEKRAR OYNA / ANA MENÜ.
7. 5/10/15. dk "ARA BOSS YAKLAŞIYOR" + elit; 20. dk "KALE LORDU GELİYOR"; Lord'u yenince KAZANDIN + "Şafak söktü; kale seni yutamadı."; ölünce OYUN BİTTİ + "Kale seni yuttu." + kombo listesi (kombosuzsa "Bu seferlik kombo yok." kısa panel, 5 kombo ekrana sığar). Lord dövüşü ≈6–7 dk sürebilir.
8. Elit/Lord çubuğu: pasif yuvaların altında ortada, elit ince bronz, Lord kalın amber, ad okunur, Lord çubuğu uyarı bandının üstünde, "+N" eki.
**C. Harabeler ve düşman davranışı**
9. Yüksek yapılara 8 yönden gir: içinden geçilmez, kenarda kayma akıcı, takılma/titreme yok; alçak (dekor) harabelerden geçilir; komşu chunk sınırlarında sıkışma yok.
10. Harabeyi arkana alıp dur: düşmanlar dolanıp ulaşmalı (F-020). Bilinen sınır F-ver3-001: büyük içbükey yapının cebinde asılı kalan düşman olabilir (sim ≈%5); kaç düşman / ne kadar süre / yığılma / titreme gözle.
**D. Görünüm, performans, ses**
11. Stres ölçümü: menüde sürüm etiketine 3 dokunuş → 60 sn; ort./p95 kare süresi (hedef p95 ≤16,7 ms), çizim, bellek; geç oyun (15+ dk) akıcı mı. Sonucu paylaş.
12. Görünüm: rim konturu kalabalıkta rahatsız etmiyor mu, oyuncu ~200 px okunur, çentik/yuvarlak köşe (yan ≥36 px), joystick (ölü bölge ≈24, yarıçap 195), dokunma hedefleri.
13. Debug etiketi `düşman N/M  taş N/M` + `kesme düzeltmesi: AÇIK|KAPALI` (dokun): ~2 dk AÇIK / ~2 dk KAPALI; kaybolma ya da N≠M varsa ekran görüntüsü.
14. Ses: müzik döngüsü/geçişler, boss uyarısında ve duraklatmada kısma; SFX yok (beklenen); titreşim.
**E. Karar ve yayın**
15. Denge hissi (kullanıcı kararı, v1.1): geç oyun tehdidi, Lord zorluğu.
16. APK imzalama (release, GitHub secret) ve aynı anahtarla güncelleme (önce debug APK'yı kaldır).

### Açık noktalar
- F-ver3-001 (içbükey cep takılması) açık; düzeltme v1/v1.1 kararı bekliyor, testler karakterizasyonlu ve gate yeşil.
- Ölçümler sabit oyuncu ve ölümsüz düşmanla; hareketli oyuncuda süre/oran cihazda gözlenecek (madde 10).
- Cihazda doğrulanmadı: ikonun gerçek launcher'da görünümü, FPS/p95, dokunma/çentik, ses duyumu, imzalı release APK (`prova_release.sh --full` koşulmadı; yalnız `--fast`).
- `gdtoolkit` yerel ortamda kurulmuştu; CI ile aynı sürüm (4.5.0).
- Kapsam dışı (T20261023-78): denge (F-ver-007), SFX, N3–N8, #11.
