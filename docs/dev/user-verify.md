# Kullanıcıda doğrulanır (prova kontrol listesi)

Bulutta telefon/emülatör yoktur; aşağıdakiler yalnız cihazda doğrulanabilir. Sonuçları (özellikle 4. madde) paylaşın.

## 1. Debug APK kurulumu

1. GitHub Actions → son `ci` koşusu → **Artifacts** → `ashen-bastion-debug-apk` → `ab-debug.apk` indirin.
2. Telefona kurun (bilinmeyen kaynaklara izin). Aynı debug anahtarıyla imzalı olduğundan sonraki CI APK'ları
   güncelleme olarak kurulur.
3. Açılışta ana menü görünmeli (Türkçe etiketler, `İ`/`Ş`/`Ğ` doğru).

## 2. Oynanış (8 dakikalık demo)

- Ekranın herhangi bir yerine dokununca joystick o noktada belirir; parmak kalkınca karakter durur.
- Karakter iki tabancayla otomatik ateş eder; HUD'da şarjör 6 → 0, **doldurma halkası** (≈1 sn) ve `↻` görünür.
- Düşman ölünce XP taşı düşer, yaklaşınca toplanır; seviye atlayınca oyun durur ve 3 kart çıkar (500 ms kilit).
- 8. dakikada **KAZANDIN**, can bitince **OYUN BİTTİ** sonuç ekranı gelir; TEKRAR OYNA / ANA MENÜ çalışır.
- Duraklat, Android geri tuşu (Devam Et), uygulamayı arka plana alma (otomatik duraklat) beklenen gibi davranır.

## 3. Görünüm ve dokunma

- Çentik/kamera deliği HUD'u kesmiyor (U1'de sabit 24 px güvenli kenar; tam `safe_area` U2-11).
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

## 5. Ses (U1'de yok)

Ses çalma katmanı uygulama-2'dedir; U1'de ses/titreşim anahtarları yalnız saklanır. Titreşim (`Settings.vibrate`)
cihazda denenebilir.
