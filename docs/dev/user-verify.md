# Kullanıcıda doğrulanır (prova kontrol listesi)

Bulutta telefon/emülatör yoktur; aşağıdakiler yalnız cihazda doğrulanabilir. Sonuçları (özellikle 4. madde) paylaşın.

## 1. Debug APK kurulumu

1. GitHub Actions → son `ci` koşusu → **Artifacts** → `ashen-bastion-debug-apk` → `ab-debug.apk` indirin.
2. Telefona kurun (bilinmeyen kaynaklara izin). Aynı debug anahtarıyla imzalı olduğundan sonraki CI APK'ları
   güncelleme olarak kurulur.
3. Açılışta ana menü görünmeli (Türkçe etiketler, `İ`/`Ş`/`Ğ` doğru).

## 2. Oynanış (tam oyun: 20 dakika)

- Ekranın herhangi bir yerine dokununca joystick o noktada belirir; parmak kalkınca karakter durur.
- Karakter iki tabancayla otomatik ateş eder; HUD'da şarjör 6 → 0, **doldurma halkası** (≈1 sn) ve `↻` görünür.
- Düşman ölünce XP taşı düşer, yaklaşınca toplanır; seviye atlayınca oyun durur ve 3 kart çıkar (500 ms kilit).
- 5/10/15. dakikada uyarı bandı ("ARA BOSS YAKLAŞIYOR") + uyarı sesi, ardından elit; 20. dakikada "KALE LORDU GELİYOR" ve Lord.
  Lord'u yenmek **KAZANDIN**, can bitince **OYUN BİTTİ** sonuç ekranı gelir (süre, seviye, öldürme, kurulan kombolar).
- Seviye atlamada 3 kart; aktif becerisi 5. seviyedeki ve eşleşen pasifi olan oyuncuya **evrim** kartı en altta çıkar.
- TEKRAR OYNA / ANA MENÜ çalışır.
- Duraklat, Android geri tuşu (Devam Et), uygulamayı arka plana alma (otomatik duraklat) beklenen gibi davranır.

## 3. Görünüm ve dokunma

- Çentik/kamera deliği ve yuvarlak köşeler HUD'u kesmiyor: yan boşluk ≥36 px, ayrıca `DisplayServer.get_display_safe_area()` payı eklenir.
- Joystick: ölü bölge ≈24 px, yarıçap 195 px (`InputGate.MAX_RADIUS` / `DEAD_ZONE_PX`; cihazda 180–210 arası denenir).
- Düşmanlar ve oyuncu zeminden açık konturla (rim) ayrışıyor; oyuncu boyu ~200 px.
- Dokunma hedefleri rahat, kazara dokunma yok.

## 4. Cihaz içi stres ölçümü (bize gönderin)

1. Ana menüde **sürüm etiketine 3 kez dokunun** (yalnız debug APK'da çalışır).
2. 60 sn'lik senaryo çalışır: 400 düşman + ~500 mermi, sabit tohum. Sonuç ekranda görünür ve
   `user://perf.json` dosyasına yazılır (ortalama / p95 kare süresi, draw call, nesne sayısı, bellek).
3. Ekran görüntüsünü ya da `perf.json` içeriğini paylaşın.
   (`perf.json` yolu: `/storage/emulated/0/Android/data/com.iamhankaya.ashenbastion/files/` altında olmayabilir;
   ekrandaki sayılar yeterlidir.)

Hedef: 60 FPS, p95 kare süresi ≤ 16,7 ms. Tutmazsa `docs/dev/perf.md` yedek merdiveni sırayla uygulanır; "300+"
hedefinin altına inme kararı kullanıcıya aittir.

## 5. F-ashen-bastion-002 (düşman/XP taşı bir iki kare görünmez olma) karşılaştırması

Debug APK'da oyun sırasında ekranın altında (x≈300, y≈2236) iki satır belirir: `düşman N/M  taş N/M` (MultiMesh
görünür sayısı / canlı sayı) ve `kesme düzeltmesi: AÇIK|KAPALI (dokun)`. Etikete dokunmak
`RenderingServer.canvas_item_set_custom_rect` düzeltmesini açar/kapatır (ayar saklanır).
1. Düzeltme AÇIKken ~2 dk oynayın, özellikle yerden XP taşı toplarken: görünmez olma oluyor mu?
2. Etikete dokunup KAPALI yapın, aynı şekilde oynayın: sorun geri geliyor mu?
3. Sayılar farklıysa (N ≠ M) ekran görüntüsünü paylaşın.

## 6. Ses

Müzik (menü, savaş-1 → 10. dk savaş-2, boss uyarısı, Kale Lordu, kazandın, kaybettin) `assets/audio/music/*.ogg`.
Kontrol: döngü dikişi duyuluyor mu, geçişler (1,5 / 4 / 2 sn crossfade) doğal mı, boss uyarısında müzik kısılıyor mu,
duraklatmada müzik kısılıyor mu. **SFX dosyası yok** (atış, doldurma, patlama, XP çınlaması sessiz): CC0 paket
`assets/audio/sfx/<kimlik>.ogg` olarak konunca çalar (`LICENSES-audio.md`). Titreşim (`Settings.vibrate`) cihazda denenebilir.
