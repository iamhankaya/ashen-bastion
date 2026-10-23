# T20261023-64 Ashen Bastion v1 — doğrulama (son doğrulama) raporu

Doğrulanan: `08fc5e3` (entegrasyon `vlad/T20261023-55` ile "Already up to date"). Doğrulama commit'i `85ae394`; rapor commit'i bunun üstünde. Üretim koduna dokunulmadı.

### Yapılanlar
- Belgeler okundu (tasarım, uygulama-2/1, kabul, ara denetim, user-verify); `test-driven-development`, `systematic-debugging`, `verification-before-completion` skill'leri repoda var, doğrulama işi olduğu için ayrıca yüklenmedi (eksik olarak not).
- **Temiz klonda taban gate** (`git clone` + `GATE_RENDER=1 bash tools/gate.sh`, `08fc5e3`): **GATE OK**, 411 test, 0 kırmızı, pytest 33, render smoke dahil.
- 7 yeni kabul dosyası, 48 test (`test/acceptance/test_ver_*.gd`) + 2 gate-dışı araç (`test/helpers/balance_observe.gd`, `test/helpers/fuzz_invariants.gd`).
- Denge gözlemi (bot koşuları, 1500 sn, Lord dahil), kalabalık sahne ölçümü, 10 uzun koşuda invariant taraması, xvfb ekran görüntüsüyle rim/kontrast görsel kontrolü.
- Mutasyon kontrolü: `_make_room` çağrısı ve "atlanmış Lord satırı" koşulu geçici silindi → yeni testler kırmızı oldu (sonra geri alındı, `git diff` temiz). Aynı mutasyonda geliştiricinin `test_boss_safety` testi YEŞİL kaldı (F-ver-006).

### Kapsam
| Alan | Önceki durum | Eklenen testler |
|---|---|---|
| Baştan sona oyun (menü → seviye atla/seç → evrim → 20. dk Lord → kazanma → sonuç → tekrar; ölüm yolu) | birim: ekran akışı; kabul: timer modu 90 sn demo | `test_ver_end_to_end` (4): gerçek `GameController` ile Lord kazanışı ve sonuç ekranı verisi, ölüm + bekleyen seviye aynı adım, doğal ölüm (idle), menü "ASH AND STEEL" |
| Lord her koşulda doğar | `test_boss_safety` (fixture, doğal boşalma yer açıyor → zayıf) | `test_ver_boss_lord` (9): gerçek waves.json; havuz HER ADIM dolu; elit/şövalye dolu; `start_time` 1190…3000; `debug_set_time` 1100…1600; uyarı 5 sn; Lord yaşarken kazanılmaz; Lord ölümü + oyuncu ölümü aynı adım = WON; çağırma baskısında Lord silinmez; timer kipinde Lord yok |
| Determinizm | kabul: 8 test (hash her 300 adım) | `test_ver_determinism_full` (8): elit ve Lord/öfke/çağırma boyunca eş koşu hash, Lord AI durumu hash'te, harita düzeni (tohum, üretim sırası), `_mix` sabit değerleri, **F-ver-001 (kırmızı)** |
| Anti-hedefler (ölümsüzlük yok, 10. dk sonrası tehdit) + şarjör ritmi HUD | kısmen (zorluk eğrisi, şarjör sinyalleri) | `test_ver_goals` (11): dokunulmazlık/can çalma anahtarı yok, yenilenme ≤1,25/sn, 20. dk temas tick'i ≫ yenilenme, yakın temas halkası her aşamada öldürür, çarpanlar 10→20. dk büyür, boss ritmi 5/10/15/20, doğuş yöneticisi 300+ düşmana ulaşır, HUD tamburu şarjörü her adım izler, ritim etiketi, `doldurma_sacilmasi` yalnız doldurma başında, `son_mermi_patlar` yalnız son kurşundan |
| Kalabalık performans (gerçek geç oyun yükü) | dev stres sahnesi: yalnız piyade + sentetik mermi | `test_ver_crowd_perf` (4): tam donanım + karışık türler 376 düşman, elit+Lord 376, tüm havuzlar dolu CAP, sayaç determinizmi; sayaçlar `perf_budget.json` altında; ms yalnız bilgi |
| F-002 bağlantısı, yalnız-debug etiketi, metinler, depo hijyeni | `test_render_cull`, `test_contrast` | `test_ver_render_text` (7): 3 renderer `_init`'te düzeltmeyi kuruyor, geçiş + saklama, etiket görünür/canlı sayısı, release kapıları (kod taraması), eski menü yazısı yok, imza/sır dosyası yok |
| Bilinen açıklar (durum) | belgelenmişti, testsiz | `test_ver_known_gaps` (5): **karakterizasyon (F-ver-002)** ×2 chunk çakışması, **karakterizasyon (F-ver-003)** SFX yok, **karakterizasyon (F-ver-004)** HUD güvenli alan, F-ver-005 shader dizisi koruma testi |
| Denge / uzun koşu araçları | `tools/balance/sim_run.gd` | `balance_observe.gd` (hedef-yönelimli bot, 5/10/15/20/21 dk anlık), `fuzz_invariants.gd` (ölümsüz bot, rastgele kart) |

### Bulunan hatalar
| Kimlik | Önem | Bulgu | Yeniden üretme / kanıt |
|---|---|---|---|
| F-ver-001 | Düşük | `GameSim._stream_seed` 4 RNG akışını (harita dahil) `hash([tohum, ad])` Variant hash'inden türetiyor. Uygulama-2'nin "harita tohumu sürüm-bağımsız" düzeltmesi yalnız chunk karışımını (`MapSim._mix`) kapsıyor; girişi hâlâ motor sürümüne bağlı 32 bit değer (`hash([1,"map"])`=912682907). Aynı motorda görünür etki yok; motor yükseltince aynı tohum başka harita/doğuş verir. | `test_ver_determinism_full::test_stream_seeds_do_not_depend_on_variant_hash` (**kırmızı**). Öneri: tohum+akış adı için elle yazılmış 64 bit karıştırma (ör. FNV/SplitMix). |
| F-ver-002 | Orta | Komşu chunk sınırında katı harabeler çakışıyor (bilinen). Sayı: 20 tohum × 81 chunk'ta **99 çakışan çift**, en kötü örtüşme 195 px; çakışma merceğinde `resolve` sonrası oyuncunun (r=22) hâlâ harabe içinde kaldığı **73** durum. Aynı chunk içinde çakışma 0 (kural çalışıyor). | `test_ver_known_gaps` karakterizasyon testleri (yeşil; düzelince kırmızıya döner, tersine çevrilmeli). |
| F-ver-003 | Düşük | SFX dosyası yok (bilinen): atış/doldurma/patlama/XP sessiz; müzik 7 parça var. Sessiz çalma hata vermiyor. | `test_ver_known_gaps` karakterizasyon (F-ver-003). |
| F-ver-004 | Düşük | HUD güvenli alanı yalnız `_build`'de uygulanıyor, `size_changed` dinlenmiyor (bilinen). | karakterizasyon (F-ver-004). |
| F-ver-005 | Bilgi | Shader `cell_rect[16]`; kullanılan hücre 6 (guard testi yeşil, 16'ya dayanırsa uyarı verir). | `test_f_ver_005_…`. |
| F-ver-006 | Düşük (test kalitesi) | `test_boss_safety::test_lord_spawns_even_when_the_pool_is_full` `_make_room` kaldırılsa da yeşil: havuz birkaç adımda doğal boşalıyor, Lord yeniden deneme ile doğuyor. Gerçek koruma yalnız havuz sürekli dolu tutulunca sınanır. | Mutasyon: `_make_room(sim)` → `pass`; dev testi yeşil, `test_ver_boss_lord` 2 test kırmızı. |
| F-ver-007 | Orta (denge, sayıları DEĞİŞTİRMEDİM) | Hedef-yönelimli bot 6 koşunun 3'ünü kazandı; kazananlarda 10–20. dk'da canlı düşman 23–63 (sınır 220–400) ve can ≥%39 (çoğunda ≥%86). "En kalabalık anda 300+ düşman, yüzlerce mermi" yalnız zayıf yapıda (bot ölürken) ya da sentetik stresle oluşuyor; tam donanım kalabalıkta en çok ~45 eşzamanlı mermi. Ayrıntı "Denge gözlemi". | `balance_observe.gd` çıktıları; `test_ver_crowd_perf` bilgi satırları. |
| Not | Bilgi | Rapor "7 `rhythm` etiketli" diyor; veride **8** (3 aktif, 2 pasif, 3 evrim). Test 8'i sabitliyor. `SimKit.godmode` `choose()` sonrası max_hp yeniden kurulduğu için her adım yenilenmeli (test yardımcısı notu). | `test_ver_goals::test_rhythm_tags_…` |

Kritik 0, yüksek 0.

### Kırmızı bırakılan testler
- `test_ver_determinism_full.gd::test_stream_seeds_do_not_depend_on_variant_hash` — **F-ver-001** (4 assert: map, spawn, choice, combat akışı). Bilinçli kırmızı; üretim düzeltmesi (tohum karıştırma) ile yeşile döner. Bu yüzden bu branch'te gate kırmızıdır (aşağıya bakın).

### Test sonuçları
- **Temiz klon, taban `08fc5e3`:** `GATE_RENDER=1 bash tools/gate.sh` → **GATE OK**, 411 test (50 betik), 0 kırmızı, pytest 33 geçti, render smoke dahil.
- **Temiz klon, `85ae394` (taban + yeni testler):** gate adım 1–5 geçti (kurulum, import, lint, veri, pytest); adım 6 GUT: **459 test, 458 geçti, 1 kırmızı** (yalnız F-ver-001) → `GATE FAIL: GUT çıkış kodu 1`. Kırmızı beklenen; adım 7–10 (asgari test sayısı, render smoke) bu kırmızı yüzünden bu koşuda çalışmadı. Yalnız test ve gate-dışı araç eklendiğinden render smoke tabandaki (yeşil) sonuçtan farklı olamaz; doğrulanmadı.
- `gdformat --check` ve `gdlint` (scripts tools test) temiz.
- **Gate-dışı uzun koşular:** `fuzz_invariants.gd` ölümsüz bot, rastgele kart, 1500 sn, her 120 adımda `check_invariants()`: 10 koşu (kite 1,2,20,21; greedy 10,11,12,30,31,32) **0 ihlal**. greedy: 6 koşuda 4 kazanma (Lord öldü), 2 ölüm. kite (XP toplamıyor): 1500 sn'de seviye 8–13, Lord ölmedi, havuz 400'e çıktı, tohum 20'de 25 doğuş kaybı, çökme yok.
- **Mutasyonlar:** yukarıda (F-ver-006).
- **sim_run (mevcut araç, 6 tohum, Lord dahil 1500 sn):** idle 153–179 sn (medyan 156); kite 471–733 sn (medyan 490); greedy 209–344 sn (medyan 323); smart 682–974 sn (medyan 927, 0 evrim). Hiçbiri 20. dk'ya ulaşmadı (bilinen).
- Koşulmadı: cihaz (FPS, dokunma, shader, çentik, kesme düzeltmesinin gerçek etkisi), APK derleme/imzalama (`GATE_EXPORT`), `GATE_NIGHTLY` (100 tohum), ses duyumu, GitHub Actions.

### Kabul kriterleri
Çatı (T20261023-55) ve bu görevin kriterleri:
- **Doğrulama raporu (geçen/kalan, önem, temiz klon gate, cihaz listesi):** karşılandı (bu belge).
- **Baştan sona oyun (başla → seçim → evrim → ölüm/Lord → sonuç):** karşılandı (gerçek `GameController` + sim; Lord havuz doluyken, `start_time` ve `debug_set_time` atlamasında doğuyor). Cihazda el ile oynanış: **cihazda**.
- **Şarjör ritmi HUD'da görünür, ≥2 beceri ritimle etkileşir:** karşılandı (HUD tamburu her adım sim ile eşit; 3 aktif ritim becerisi, 2'si olay düzeyinde doğrulandı). Görsel hissi: **cihazda**.
- **F-ashen-bastion-002:** kod ve test olarak karşılandı (3 renderer `_init`'te kuruyor, açma/kapama, debug etiketi yalnız debug derlemede). Düzeltmenin GPU'da gerçekten işe yaradığı: **cihazda**.
- **Kontrast ≥3:1, menü "ASH AND STEEL", kazanma alt başlığı:** karşılandı (testler + xvfb ekran görüntüsünde kontur görünür). Cihaz görünümü: **cihazda**.
- **Determinizm (aynı tohum → aynı state_hash; AI ve doğuş hash'te):** karşılandı. **Kısmen karşılanmadı:** harita/akış tohumunun sürüm-bağımsızlığı (F-ver-001, kırmızı test).
- **Performans (300+ düşman bütçesi):** headless için karşılandı: 376 düşman, tam donanım, ≈1,4–1,8 ms/adım ortalama, en kötü 7 ms (bulut CPU'su). Cihaz FPS/p95: **cihazda**.
- **Anti-hedefler:** ölümsüzlük yok: karşılandı. "10. dk sonrası tehdit kalması": mekanik çarpanlar karşılandı; oyuncu yapısı güçlüyken fiilî tehdit düşük (F-ver-007): **kullanıcı kararı/denge**.
- **Regresyon:** 411 taban test yeşil kaldı.
- **Denge gözlemi:** yapıldı, sayılar aşağıda, değişiklik yok.
- **APK imzalama:** koşulmadı (**cihazda/CI**).

### Denge gözlemi
Hiçbir sayı değiştirilmedi. Bot, sim ve veri: `balance_observe.gd` (kite/greedy hareketi, evrim çiftlerini önceleyen kart sırası), 6 tohum, ölümlü.

| Tohum | Sonuç | Süre | Seviye | Evrim | Lord doğuş→ölüm |
|---|---|---|---|---|---|
| 1 | kazandı | 1438 sn | 30 | 1 | 1200→1438 (238 sn) |
| 2 | öldü | 491 sn | 11 | 0 | – |
| 3 | kazandı | 1263 sn | 36 | 3 | 1200→1263 (63 sn) |
| 4 | öldü | 635 sn | 15 | 0 | – |
| 5 | kazandı | 1357 sn | 39 | 0 | 1200→1357 (157 sn) |
| 6 | öldü | 728 sn | 14 | 0 | – |

Anlık görüntüler (kazanan koşular; canlı düşman / can oranı / seviye; sınır `alive_cap`):

| Dakika | Sınır | Tohum 1 | Tohum 3 | Tohum 5 |
|---|---|---|---|---|
| 5 | 130 | 20 / 1,00 / 11 | 14 / 1,00 / 11 | 15 / 1,00 / 11 |
| 10 | 220 | 27 / 1,00 / 20 | 44 / 0,86 / 20 | 23 / 1,00 / 21 |
| 15 | 310 | 42 / 1,00 / 27 | 41 / 0,86 / 29 | 63 / 1,00 / 26 |
| 20 | 400 | 47 / 0,39 / 30 | 33 / 0,86 / 36 | 48 / 1,00 / 35 |

Ölen koşular 10. dk'da: tohum 4 canlı 136, can 0,75; tohum 6 canlı 88, can 0,68 (zayıf yapı, seviye 14).
- **Ölüm dağılımı iki uçlu:** yapı kurulamayan oyuncu 8–12. dk'da ölüyor (canlı 88–136); kuran oyuncu 10–20. dk'da neredeyse hasar almıyor.
- **Lord:** 45 000 can, zırh 6. Başlangıç donanımıyla 600 sn'de öldürülemedi (çağırmaların 403–559'u dolu havuzda kayboldu); orta yapı (seken_mermi 3, son_mermi_patlar 3, agir_kursun 3, hizli_parmak 3) ≈380–400 sn; tam donanım ≈50 sn. Yani kazanma yapıya bağlı; botlar için Lord'a ulaşan yapı seviye ≈30+ gerektiriyor.
- **Azami yapı (tüm aktif/pasif 5, 3 evrim, saglam_yelek 5):** 5/10/15/18. dk'da 60 sn'de 0–90 hasar; teması değen 160'lık halkada 30 sn'de en çok 128 hasar (175 can, yenilenme 1,25/sn). Bu yapı ≈59 seviye gerektirir, bot koşularında erişilmedi.
- **Evrim:** 6 koşuda 0–3 evrim; rastgele seçen botlar 17–27. seviyede 0 evrim (kart sırası öncelikli bot 3'ünde ≥1).
- **Tek tick hasar sınırı:** 4 temas × (Lord 40 + elitler 30/28/14, ölçeklenmez) = 112 > 100 başlangıç canı; yalnız Lord + elit kalabalığında teorik tek tick ölümü.
- **Eşzamanlı mermi:** tam donanım kalabalıkta tepe ≈40–88; "yüzlerce mermi" yalnız sentetik stres.
- **Performans (bulut CPU, headless, bilgi):** 376 düşman tam donanım 1,77 ms/adım ort. (en kötü 7,0), elit+Lord kalabalığı 1,73 (4,5); sayaçlar bütçe altında. Önceki uygulama-2 raporu 3,5→4,5 ms demişti; bu ölçüm farklı sahne/makine.

### Önerilen düzeltmeler
1. **F-ver-001:** `GameSim._stream_seed` için Variant hash'ten bağımsız 64 bit karıştırma yaz; `test_stream_seeds_do_not_depend_on_variant_hash` yeşile döner. (Harita ve doğuş akışı değişir; hash'e sabit değer gömen test yok, `_mix` değerleri değişmez.)
2. **F-ver-002:** `MapSim._generate` komşu chunk'ların katı harabelerini de `_overlaps_solid` ile denetlesin (üretim sırası bağımsız kalmalı: komşu chunk içeriği tohumdan türediği için ön hesapla ya da chunk kenar şeridinde yerleşim yasağı). Düzelince karakterizasyon testlerini tersine çevir.
3. **F-ver-006:** `test_boss_safety`'e havuzu her adım dolduran bir döngü ekle (veya `test_ver_boss_lord` ile birleştir).
4. **F-ver-007 (karar):** kuran oyuncu için 10–20. dk tehdit ve "300+ düşman / yüzlerce mermi" hedefi. Seçenekler: sürekli doğuş hızı (`waves.json` rate), hp eğrisi, ya da cap'e bağlı doldurma; sayıları kullanıcı kararıyla ve cihaz geri bildirimiyle ayarla.
5. SFX paketi (F-ver-003), HUD güvenli alanını `size_changed`'de yeniden uygula (F-ver-004).
6. Gate: `tools/gate_min_tests.json` yeni `test_ver_*` dosyalarını da kapsasın (`tools/update_min_tests.sh`, F-ver-001 düzeldikten sonra).
7. Teorik (düşük): havuz yalnız elitlerle dolarsa `_make_room` yer açamaz ve Lord doğmaz; gerçek oyunda elit sayısı üçle sınırlı olduğundan ulaşılamaz, yine de yer açma elit olmayan bulamazsa Lord dışı herhangi bir düşmanı seçebilir.

### Cihaz kontrol listesi
Güncel liste (`docs/dev/user-verify.md` üstüne eklemeler **kalın**):
1. Debug APK kurulumu (CI artifact `ashen-bastion-debug-apk`); menü Türkçe harfler, **üst yazı "ASH AND STEEL" başlığın üstüne sığıyor**.
2. Tam oyun akışı: joystick, ateş, şarjör tamburu + `↻` doldurma halkası, XP taşı, seviye atlama (500 ms kilit), evrim kartı en altta, duraklat/geri tuşu/arka plan otomatik duraklatma, TEKRAR OYNA/ANA MENÜ.
3. **5/10/15. dk "ARA BOSS YAKLAŞIYOR" bandı + elit; 20. dk "KALE LORDU GELİYOR" bandı; Lord'u yenince KAZANDIN + "Şafak söktü; kale seni yutamadı."; ölümde OYUN BİTTİ + "Kale seni yuttu." ve kombo listesi.** (Lord dövüşü hissi: orta yapıyla ≈6–7 dk sürebilir.)
4. **F-002:** debug etiketi `düşman N/M taş N/M` ve `kesme düzeltmesi: AÇIK|KAPALI`; ~2 dk AÇIK, ~2 dk KAPALI oyna; kaybolma var mı, N≠M görüntüsü paylaş.
5. Görünüm: rim konturu kalabalıkta rahatsız ediyor mu (`RIM_*` sabitleri), oyuncu ~200 px okunur mu, rig pivotları/namlu hizası, çentik/güvenli alan (yan ≥36 px), joystick (ölü bölge 24, yarıçap 195), dokunma hedefleri.
6. **Harabeler: komşu chunk sınırında iç içe geçmiş büyük harabelere gir; sıkışma/titreme var mı (F-ver-002).**
7. Stres ölçümü: ana menüde sürüm etiketine 3 dokunuş → 60 sn; ort./p95 kare süresi, çizim, bellek (hedef p95 ≤16,7 ms). **Gerçek oyunda geç oyun (15+ dk) kalabalığında akıcılık.**
8. Ses: müzik döngü dikişi, geçişler, boss uyarısında/duraklatmada kısma; **SFX hâlâ yok (beklenen)**; titreşim.
9. **Denge hissi (kullanıcı kararı bekliyor):** geç oyunda tehdit ve kalabalık yeterli mi (F-ver-007), Lord çok mu kolay/zor.
10. APK imzalama (release, GitHub secret) ve aynı anahtarla güncelleme kurulumu.

### Açık noktalar
- **Kullanıcı kararı:** F-ver-007 (geç oyun tehdidi / "yüzlerce mermi" hedefi), F-ver-001 düzeltmesinin zamanı (motor yükseltmesinden önce), SFX kaynağı, müzik lisansı.
- Rapor/veri tutarsızlığı: "7 ritim etiketli" yerine 8.
- Gate bu branch'te F-ver-001 yüzünden bilinçli kırmızı; entegrasyondan önce ya düzeltilmeli ya da o test `pending` yapılmalı (VLAD kararı). Taban `08fc5e3` yeşildir.
- Render smoke ve `selftest_gate.sh` bu HEAD'de koşulmadı (yalnız test eklendi); `selftest` "taban yeşil" senaryosu kırmızı bir testle düşebilir.
- Render'lı kesme düzeltmesinin etkisi, FPS, APK imzalama, ses duyumu ve 100 tohumluk nightly koşulmadı.
- Denge ölçümleri bot ve tek makinede; bot politikaları naif (evrim için hedef-yönelimli bot yalnız öncelik listesi kullanır).
- Uygulama-2 raporundaki `.gate/junit.xml` yazma hatası (`.gate` yokken GUT tek başına) yalnız elle koşuda görülür; gate dizini kendisi oluşturur.
