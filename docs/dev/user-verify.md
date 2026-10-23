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
