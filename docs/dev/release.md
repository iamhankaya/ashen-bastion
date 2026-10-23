# İmzalı release APK (runbook)

Repo **public**. Anahtar ve şifre asla commit'lenmez, sohbete/loga yazılmaz; yalnız GitHub secret'larında durur.
Secret yoksa release işi **anlaşılır bir hatayla durur**; imzasız ya da debug-imzalı APK üretmez.

## 1. Kalıcı keystore'u kendi bilgisayarında üret (bir kez)

JDK gerekir (`keytool`). Bu komutu **repo dışında** bir klasörde çalıştır:

```bash
keytool -genkeypair -v -keystore ashen-bastion.keystore -alias ashenbastion \
  -keyalg RSA -keysize 2048 -validity 10000
```

- Şifreyi (en az **8 karakter**) kendin seç; komut sorar. "Key password" sorusunda Enter'a basıp **keystore şifresiyle aynı** bırak (Godot tek şifre kullanır).
- Alias: `ashenbastion` (aşağıdaki `ANDROID_KEYSTORE_USER`).
- Üretimi doğrula: `keytool -list -v -keystore ashen-bastion.keystore -alias ashenbastion` (SHA256 parmak izini not al; APK'daki ile karşılaştırılır).

> **YEDEKLE.** `ashen-bastion.keystore` dosyasını ve şifresini parola yöneticisi/şifreli yedek gibi en az iki ayrı yere koy.
> **Kaybolursa** aynı imzayla yeni sürüm üretilemez; telefondaki uygulama güncellenemez, silip yeniden kurman gerekir.
> **Repoya ekleme** (`.gitignore` `*.keystore` dosyalarını zaten dışlar).

## 2. GitHub secret'larını ekle

Base64 (tek satır):

```bash
base64 -w0 ashen-bastion.keystore      # macOS: base64 -i ashen-bastion.keystore | tr -d '\n'
```

Repo → **Settings → Secrets and variables → Actions → New repository secret** (ya da **Settings → Environments → `release`** altındaki environment secret'ları; ikisi de çalışır):

| Secret | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | yukarıdaki base64 çıktısı |
| `ANDROID_KEYSTORE_USER` | alias: `ashenbastion` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore (= anahtar) şifresi |

Önerilen sertleştirme: Settings → Environments → `release` → "Deployment branches and tags" ile yalnız `master` ve `v*` etiketlerine izin ver; isteğe bağlı "Required reviewers". Fork PR'ları secret göremez; `release.yml` `pull_request` ile hiç tetiklenmez.

Sonra yerel dosyaları sakla/sil: base64 çıktısını panodan ve kabuk geçmişinden temizle.

## 3. Release işini tetikle

- **Elle:** GitHub → **Actions → release → Run workflow** (dal: `master`).
- **Sürüm etiketiyle:** `git tag v0.1.0 && git push origin v0.1.0` — APK ayrıca **Releases** sayfasına da konur.

Release işi push/PR'da **koşmaz**. `version/code` her koşuda `github.run_number` olur (güncelleme olarak kurulabilmesi için artar); etiket varsa `version/name` etiketten gelir.

## 4. APK'yı indir ve kur

- Actions → ilgili `release` koşusu → **Artifacts → `ashen-bastion-release-apk`** (zip içinde `ab-release.apk`, 30 gün saklanır; indirmek için GitHub oturumu gerekir), **veya**
- etiketle tetiklendiyse **Releases → `ashen-bastion-<etiket>.apk`**. (Repo public olduğundan Release APK'sı herkese indirilebilir.)
- Koşunun özetinde **sertifika SHA-256** yazar; adım 1'deki `keytool -list` parmak iziyle (iki noktasız, küçük harf) aynı olmalı.
- Telefonda "bilinmeyen kaynaklardan kur" izni ver. Önceden **debug APK** kuruluysa imza farklı olduğu için önce onu kaldır (bir kez); sonraki release APK'ları güncelleme olarak kurulur.

## Hata mesajları

| Mesaj | Anlamı |
|---|---|
| `Eksik secret: …` (çıkış 2) | Adım 2'deki secret'lar tanımlı değil (adları mesajda). |
| `Keystore açılamadı: şifre veya alias yanlış` | `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEYSTORE_USER` hatalı. |
| `…base64 geçerli değil` | `base64 -w0` ile **tek satır** üret; sonda satır sonu/boşluk olmasın. |
| `…debug anahtarıyla aynı` | Yanlış keystore verilmiş (herkese açık debug anahtarı). |
| `Sır sızıntısı tespit edildi` | Günlük/APK/`export_presets.cfg` içinde şifre bulundu; APK silinir. Bildir, şifreyi değiştir. |

## Güvence ve prova

- `tools/ci/export_release.sh`: secret kontrolü → geçici keystore (`umask 077`, çıkışta/INT/TERM'de silinir) → Godot `--export-release` (anahtar yalnız Godot sürecinin ortam değişkeninde; argv'de ve `export_presets.cfg`'de yok) → `apksigner verify` + **sertifika parmak izi == kalıcı keystore, != debug** → sızıntı taraması.
- `bash tools/ci/prova_release.sh --fast` (CI'da `release-prova` işi) olumsuz yolları, `--full` gerçek export'u (geçici test keystore'uyla) sınar.
- Sürümler sabit: Godot `.godot-version`, Android build-tools `35.0.1`, JDK 17.
