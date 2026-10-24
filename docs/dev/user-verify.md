# Kullanıcıda doğrulanır (v1 cihaz kontrol listesi — tek liste)

Bulutta telefon/emülatör yoktur; aşağıdakiler yalnız cihazda doğrulanabilir. Sonuçları (özellikle 11. madde) paylaşın.
Kaynak: doğrulama-1 (T…-64), doğrulama-2 (T…-80), doğrulama-3 (T…-83) listeleri birleştirildi, tekrarlar ayıklandı.

## A. Kurulum ve ikon
1. GitHub Actions → son `ci` koşusu → **Artifacts** → `ashen-bastion-debug-apk` → `ab-debug.apk`; telefona kurun (bilinmeyen kaynaklara izin).
   Debug anahtarı sabit olduğundan sonraki CI APK'ları güncelleme olarak kurulur.
2. Açılışta ana menü: Türkçe harfler (`İ`/`Ş`/`Ğ`) doğru, "ASH AND STEEL" üst yazısı başlığın üstüne sığıyor.
3. **Uygulama ikonu:** ana ekranda koyu bastion ikonu görünür; yuvarlak/kare/damla maske altında kesilme yok. Android 13+ temalı
   ikon açıksa tek renkli (monochrome) sürüm doğru görünür. (Adaptive ön katman bilerek boştur; sanat arka plan katmanındadır.)

## B. Oynanış (tam oyun: 20 dakika)
4. Joystick ekranın herhangi bir yerinde belirir, parmak kalkınca karakter durur; ateş otomatik; HUD şarjör tamburu 6→0, `↻`
   doldurma halkası (≈1 sn); XP taşı düşer ve yaklaşınca toplanır.
5. Seviye atlama: oyun durur, 3 kart (500 ms kilit); aktif beceri 5. seviyede + eşleşen pasif varsa **evrim** kartı en altta.
   Kart adlarında `i` olanlar `İ` ile (ŞİFA, BARUT KESESİ, KIYAMET MERMİSİ…), kombo adları büyük harf.
6. Duraklat, Android geri tuşu (Devam Et), uygulamayı arka plana alma (otomatik duraklat), TEKRAR OYNA / ANA MENÜ.
7. 5/10/15. dk "ARA BOSS YAKLAŞIYOR" bandı + elit; 20. dk "KALE LORDU GELİYOR". Lord'u yenince **KAZANDIN** + "Şafak söktü; kale
   seni yutamadı."; ölünce **OYUN BİTTİ** + "Kale seni yuttu." ve kombo listesi (kombosuzsa "Bu seferlik kombo yok." kısa panel,
   düğmeler hemen altında; 5 kombo ekrana sığar). Lord dövüşü orta yapıyla ≈6–7 dk sürebilir.
8. Elit/Lord çubuğu: pasif yuvaların altında ortada; elit ince bronz, Lord kalın amber; ad okunur; Lord çubuğu uyarı bandının
   üstünde; birden çok elitte "+N" eki.

## C. Harabeler ve düşman davranışı
9. **Katı harabeler:** yüksek yapılara (kule, bayrak, meşale direği) joystick ile 8 yönden gir; içinden geçilmemeli, kenarda kayma
   akıcı, takılma/titreme yok. Alçak (dekor) harabelerden geçilebilir. Komşu chunk sınırındaki iç içe harabelerde de sıkışma yok.
10. **Düşman/harabe (F-020 + F-ver3-001):** harabeyi arkana alıp dur: sıradan düşmanlar yanından dolanıp sana ulaşmalı. Bilinen
    sınır: içbükey/çukurlu büyük yapıların (çok daireli, kap gibi) içine girip orada asılı kalan düşman olabilir (sim: yaklaşık
    %5 durum). Bunu gözleyin: kaç kişi, ne kadar süre, yığılma, titreme?

## D. Görünüm, performans, ses
11. **Stres ölçümü:** menüde sürüm etiketine 3 dokunuş (yalnız debug APK) → 60 sn senaryo (400 düşman + ~500 mermi); ekrandaki
    ortalama / p95 kare süresi, draw call, bellek (veya `user://perf.json`). Hedef: 60 FPS, p95 ≤ 16,7 ms. Tutmazsa
    `docs/dev/perf.md` yedek merdiveni. Ayrıca gerçek oyunda geç oyun (15+ dk) kalabalığı akıcı mı.
12. Görünüm: rim konturu kalabalıkta rahatsız ediyor mu, oyuncu ~200 px okunur, çentik/kamera deliği ve yuvarlak köşelerde HUD
    kesilmiyor (yan ≥36 px), joystick (ölü bölge ≈24, yarıçap 195; 180–210 denenebilir), dokunma hedefleri rahat.
13. Debug etiketi `düşman N/M  taş N/M` ve `kesme düzeltmesi: AÇIK|KAPALI` (etikete dokun, ayar saklanır): ~2 dk AÇIK, ~2 dk
    KAPALI oyna; düşman/taş kaybolması var mı, N≠M ise ekran görüntüsü paylaş (F-002 cihazda çözüldü; kontrol amaçlı).
14. Ses: müzik döngü dikişi, geçişler (1,5 / 4 / 2 sn crossfade), boss uyarısında ve duraklatmada kısma; **SFX yok (beklenen)**;
    titreşim (`Settings.vibrate`).

## E. Karar ve yayın
15. Denge hissi (kullanıcı kararı, v1.1/backlog): geç oyun tehdidi ve kalabalık yeterli mi, Lord çok mu kolay/zor.
16. APK imzalama (`docs/dev/release.md`, GitHub secret) ve aynı anahtarla güncelleme kurulumu (önce debug APK'yı kaldır).

# v1.1 cihaz kontrol listesi (kullanıcıda doğrulanır — T20261023-98)

Aynı kural: bulutta telefon yok; bunlar yalnız cihazda görülür. Her satır: **ne** — nasıl bakılır → beklenen. Kurulum için A bölümü (debug APK).
Dengeye dokunan sonuçlar (geç oyun zorluğu vb.) ayrı denge görevine veridir; ayar bu listenin konusu değil (`docs/dev/v1.1-ab-report.md`).

## F. Performans
17. **view_ms (perf yedek merdiveni kararı)** — debug APK, menüde sürüm etiketine 3 dokun → 60 sn stres; ekrandaki/`user://perf.json` `view_ms_avg` ve `view_ms_p95` → orta sınıf cihazda avg ≤ 4 ms ve p95 ≤ 8 ms; avg > 4 ya da p95 > 8 ise `docs/dev/perf.md` yedek merdiveninin **1. adımı** (>200 canlıda yalnız bob).
18. **FPS** — aynı koşuda ortalama/p95 kare süresi ve gerçek oyunda 15+ dk kalabalık → 60 FPS, p95 ≤ 16,7 ms; eklenti/skor/hayalet eklenince v1'e göre fark hissedilmiyor.

## G. Ekran kenarları (çentik / güvenli alan)
19. **Gerçek çentik / yuvarlak köşe** — çentikli ve yuvarlak köşeli telefonda oyun, menü, En İyi Skorlar, sonuç ve skor ekranı → hiçbir yazı/düğme kesilmiyor; yan boşluk ≥ 36 px.
20. **Lord bandı** — 20. dk "KALE LORDU GELİYOR" sırasında SERİ çipi, skor, rozet satırı ve Lord çubuğu bandın altında kalmıyor → okunuyor.
21. **Ekran dışı eklenti oku** — yerde eklenti varken kameradan uzaklaş → ok kenardan ≥ 36 px içeride, yuvarlak köşeye girmiyor, doğru yönü gösteriyor, eklenti ekrana girince kayboluyor.

## H. Görünüm
22. **Gölge koyuluğu (OLED / parlaklık)** — düşman ve oyuncu yer gölgesi; ekran parlaklığını düşük/orta/yüksek dene → gölge okunuyor (elit/Lord "yüzmüyor"), ama zemini batırmıyor; kalabalıkta (300) sorun yok.
23. **İkon okunurluğu (54–80 px)** — eklenti rozetleri, yerdeki eklenti ikonları, menü/skor kupa ikonu → ilk bakışta ayırt ediliyor (İksir/Çekim/Barut/Namlu/Bomba/Sonsuz).
24. **∞ tambur** — Sonsuz Tambur alınca HUD şarjör tamburu → ∞ simgesi, 6 yuva amber, doldurma halkası yok; süre bitince normale dönüyor.
25. **Kupa ikonu** — ana menüde EN İYİ SKORLAR düğmesi → kupa ikonu net ve düğme yazısıyla hizalı.
26. **Menü anahtar yazısı 36 px** — "SES: AÇIK / TİTREŞİM: KAPALI" → yazı sığıyor, satır taşmıyor, dokunma hedefi rahat.
27. **Oyuncu yürüme omuz sapması (≈17 px, karar bekliyor)** — oyuncuyu tam hızda yürüt, silahlara/omuzlara bak → gövde kayıyor gibi görünüyor mu? Görünüyorsa kararını yaz (gerçek kareler D4'te bağlanmadı; prosedürel yedek çalışıyor).

## I. His
28. **Hasar / vuruş donması** — hasar al, düşman vur → parlama + kısa donma doğal, yorucu/gecikme gibi değil (parlama ≤ 3/sn).
29. **Sonuç gecikmesi** — ölünce ≈1,3 sn, kazanınca ≈1,8 sn sonra sonuç ekranı → "ani kesilme" ya da "uzun bekleme" hissi yok.
30. **Seviye ön vurgusu** — seviye atlayınca kısa (≈180 ms) altın vurgu sonra kartlar → akıcı, rahatsız etmiyor.
31. **Seviye halkası kart seçiminden sonra** — kartı seçince mor halka dalgası yayılıyor (önce değil) → doğru sırada.
32. **Bomba kamera sarsıntısı** — Kara Bomba al, 0,8 sn fitil, patlama → ≈18 px kısa sarsıntı; mide bulandırmıyor, titreşim deseni uygun.
33. **Bomba etkisi** — toplama noktasında patlıyor, tüm haritayı temizlemiyor, çevredekiler hasar alıyor, sen etkilenmiyorsun → beklenen.

## J. Karar / F-021
34. **F-021 kaçış AÇIK/KAPALI** — debug etiketi sağ altta (`çıkmaz kaçışı: AÇIK|KAPALI`, dokunarak çevir; `kaçışta N  girilen M`): ~2 dk AÇIK, ~2 dk KAPALI oyna → AÇIK'ta harabeye takılan düşman kaçıp (22–36 sn sürüyor) tekrar yaklaşıyor mu, his nasıl; KAPALI'da takılı kalan oluyor mu.
35. **Debug etiketi dokunmayı yutuyor mu** — etiketlerin (kesme düzeltmesi + çıkmaz kaçışı) altında kalan düğmelere/joystick'e dokun → etiket dışı dokunma etkilenmiyor; etiket rozet saniyelerini örtmüyor.
36. **`user://highscores.json` boş/bozuk** — (a) dosya yokken En İyi Skorlar → "HENÜZ SKOR YOK" ve OYNA; (b) dosyayı boş/rastgele yazıyla bozup aç → çökme yok, liste boş, `highscores.json.bad` oluşur, bir sonraki oyun sonunda geçerli dosya yazılır.
37. **Skor / SERİ hissi** — SERİ çipi ×N, hasar alınca bozulması, sonuç ekranı sayımı ve rekor bandı → okunuyor, tatmin edici; kombo ekranı sığıyor.
38. **Geç oyun dengesi (veri: A/B raporu)** — eklentilerle 15+ dk oynayınca geç oyun "zor ama eklentilerle dengelenebilir" mi; denge ayarı şimdilik YOK (kullanıcı kararı).

# v2.0 cihaz kontrol listesi (kullanıcıda doğrulanır — T20261024-55 sözleşmesi; dilim fazları kendi alt başlığına ekler)

Aynı kural: bulutta telefon yok; bunlar yalnız cihazda görülür. Her satır: **ne** — nasıl bakılır → beklenen. Kurulum için A bölümü (debug APK).
Her dilim yalnız kendi alt başlığına madde ekler (birleştirme çakışması olmasın); genel/sözleşme maddeleri aşağıdadır.

## Genel (sözleşme)
39. **Ana menü yeni düzeni** — KARAKTERLER ∣ BAŞARIMLAR yarım düğmeleri OYNA'nın altında, EN İYİ SKORLAR ve SES ∣ TİTREŞİM yerinde; alt satırda seçili karakter adı ve `açılan/toplam` → hiçbir öğe kesilmiyor, ana görsel (960×960) düğmelerin üstünde kalıyor; çentikli/yuvarlak köşeli cihazda da.
40. **Sürüm etiketi** — menü en altında `Sürüm 2.0 · <karakter adı>`; uzun ad `…` ile kesilir (Türkçe `i`/`ı` bozulmaz).
41. **Geri tuşu** — (K/B ekranları gelince) Android geri tuşu Karakterler ve Başarımlar ekranından ana menüye döner; menüde çıkar.

### K — Karakterler
- **K-1 Karakterler ekranı** — Ana menüden KARAKTERLER: portre nefes alıyor/yana sürükleniyor, kor parçacıkları yükseliyor; kenarlarda boşluk görünmüyor. Bilgi paneli (açıklama, başlangıç becerisi, 6 karo) taşmıyor.
- **K-2 Seçim** — Karakter kartına dokun (ya da sahnede yatay kaydır): portre 260 ms'de yumuşak değişir. SEÇ'e bas: düğme "✓ SEÇİLİ" olur, kartta ✓ rozeti çıkar, ekrandan çıkılmaz; GERİ ile menüde KARAKTERLER alt satırı ve sürüm etiketi yeni adı yazar; OYNA o karakterle başlar (Barutçu: can 120, başlangıçta dinamit).
- **K-3 Seviye atlama** — Seviye atlayınca üstte seçili karakterin adı ve altında "SEVİYE N" okunuyor (portre yüzünü örtmüyor); alt gradyan kartlara kadar karanlık.
- **K-4 Çentik / güvenli alan** — Çentikli/yuvarlak köşeli cihazda başlık, SEÇ ve GERİ kesilmiyor; seviye atlama kartları alt çubuğa binmiyor.
- **K-5 Yer tutucu görsel tonu** — Barutçu portresi Gunslinger'dan belirgin soluk/sepya tonda (yer tutucu); debug APK'da sağ üstte "YER TUTUCU" etiketi. Gerçek görsel gelince kalkacak.
- **K-6 Performans** — Karakterler ekranı açıkken akıcılık (hedef ≤ 1,5 ms/kare vitrin); ekran kapanınca (menüye/koşuya) pil/ısı artışı yok (parçacıklar durur).
- **K-7 2× yazı boyutu** — Sistem yazı boyutu 2× iken kart adları, SEÇ/KİLİTLİ ve GERİ metni taşmıyor.

### B — Başarımlar
(Başarım fazı ekler: bildirimin kalabalık üstünde okunurluğu ve y 820'nin başparmakla örtüşmemesi, çentik düzeni.)
- [ ] Bir başarım açılınca kutu y 820'de belirir, ~2,5 sn kalır, dokunma/joystick kesilmez; üst üste açılışlarda tek tek gelir.
- [ ] Başarımlar ekranı: liste kaydırılır, GERİ menüye döner, çentikli cihazda başlık/GERİ güvenli alan içinde.
- [ ] Koşu sonunda açılan başarım varsa sonuç ekranında "YENİ BAŞARIM · N" çipi görünür; düğmeler ekran içinde.
- [ ] Uygulamayı koşu ortasında arka plana alıp kapat/aç: o ana dek açılanlar listede durur.
- [ ] Yer tutucu başarım ikonları (mevcut HUD/beceri ikonları) kabul edilebilir mi? (22 özel ikon üretilirse yalnız PNG + `icon` yolu eklenir.)

### M — Bakım
Bu bölümün maddeleri **M-n** diye numaralanır (K/B ile çakışmasın). Bulut yalnız masaüstü/headless koştu; aşağıdakiler cihazda görülür.

**Cihaz değerlendirmesi (bulgu `deferred`; tasarım değişikliği yok):**
- **M-1 (N3) Kalabalıkta rim** — geç oyunda (≈14. dk, 80+ düşman) kalabalığa bak → konturlar "tel kafes" gibi birleşiyor mu? Okunurluğa zarar vermiyorsa kabul; gerekirse `EnemyRenderer.RIM_*` kalınlığı/opaklığı (≈%70) ayarlanır.
- **M-2 (N5) Oyuncu harabe önünde** — açık taşlı bir harabenin önünde dur → oyuncu siluetini kaybediyor mu (palto + rim taşa karışıyor mu)? Ayak ışığı yetiyorsa kabul.
- **M-3 (N8) Duraklatma düğme sırası** — DEVAM ET üstte, BAŞTAN BAŞLA / ANA MENÜ başparmak bölgesinde → yanlışlıkla basma riski var mı? Onay diyaloğu (VAZGEÇ odakta) korunur; rahatsız ediyorsa karar verilir.
- **M-4 (S-01) Gölge kazancı `GAIN` 2,2** — elit şövalye / Lord / hayalet gölgesi düşük parlaklık ve OLED'de ayağa oturuyor mu ("yüzüyor" izlenimi yok)? Kod ölçümü: koyulaşma ≥ %42 (eşik %40 + 0,02 pay). Yetersizse `EnemyShadowLayer.GAIN` artırılır.

**Bu fazda değişenler (cihazda görülmeli):**
- **M-5 (N6) Elit/Lord rim tonu** — Kale Lordu ve elitlerin konturu bronz/amber (beyaz "kesilmiş kağıt" değil), diğer düşmanlarla tutarlı; elitte yalnız kalınlık farklı.
- **M-6 (S-02) Seviye halkası** — kart seçiminden sonra yer halkası belirgin: 4 px, parlak mor-mavi, yumuşak ışımalı, ≈0,45 sn'de solarak büyüyor; koyu çimende rahatça seçilir.
- **M-7 (S-05) Ekran dışı ok** — eklenti ekran dışındayken ok (daire + üçgen ucu dahil) ekran/çentik kenarından ≥ 36 px içeride; köşelerde ve çentikli cihazda kesilmiyor.
- **M-8 (N7) Güvenli alan** — duraklatma ekranı (ve K ile seviye atlama) çentik/yuvarlak köşeye girmiyor; ekranı döndür/pencere boyutunu değiştir → HUD yeniden hizalanıyor (M8a).
- **M-9 (M8c) Kapanış** — uygulamadan çıkarken donma/kare atlaması yok (ses nesneleri artık 150 ms bekletmiyor); çıkışta çökme yok.
- **M-10 (S-04) Debug etiketleri (yalnız debug APK)** — sayaç etiketleri ekranın üst kenarında (y 6–40), hiçbir düğmeyi/oku örtmüyor, dokunmayı yutmuyor; bayrağı çevirmek için oyun sırasında etiketin yanındaki küçük "dokun: AÇIK/KAPALI" alanına dokun (duraklatma ve sonuç ekranında dokunulmaz).
- **M-11 (shader) Derleme** — elit rim değişikliği `enemy_flash.gdshader`'a `rim_elite_color` ekledi → cihazda (Mali/Adreno) düşmanlar render ediliyor, siyah/eksik sprite yok.
