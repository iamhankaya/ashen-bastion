# Ashen Bastion — Piyasa araştırması

Görev: T20261027-06 · Rol: Game Director · Tarih/erişim tarihi: 2026-10-27 · Yazan: VLAD çalışanı (araştırma + kod/belge okuma; üretim koduna dokunulmadı)

Bu rapor pazarlama stratejisi görevinin (growth) girdisidir. Okuma sırası: önce §1 (nasıl ölçtük, neyi ölçemedik), sonra §6 (üç soruya cevap), §7 (pazarlama girdisi).

## 1. Yöntem ve sınırlar (önce bunu oku)

- **Oyun çalıştırılmadı.** Bu makinede Godot kurulu değil (`godot` komutu yok); `docs/dev/setup.md` Godot 4.7.2'yi CI/gate indirmesiyle kullanıyor. Karşılaştırma `data/`, `docs/design`, `docs/spec`, `docs/dev` ve proje kartına dayanır. **Dokunmatik "elde hissi" denetlenemedi** (rol kuralı: uydurma yok).
- **Steam inceleme API'si çalışmadı** (her istek mağaza ana sayfasına 302 verdi). Yorum temaları, `steamcommunity.com` "en faydalı" listelerinden oyun başına ~10 olumlu + ~10 olumsuz incelemeden çıkarıldı. Bu **istatistiksel örnek değildir**; "x/6 oyun" ifadeleri örnek içi sayımdır, yaygınlık ölçüsü değildir.
- **Reddit'e erişilemedi** (WebFetch reddit.com'u reddetti; arama Reddit gönderisi döndürmedi). Bu yüzden Reddit temaları **doğrulanamadı**. Forum/söylem kaynağı olarak Steam tartışmaları, Quarter To Three forumu, itch.io ve basın incelemeleri kullanıldı; her tema 1–3 tekil kaynağa dayanır.
- **Google Play / App Store sayfaları yüklenmedi.** Mobil puan, yorum sayısı ve kurulum bandı çoğu oyun için **doğrulanamadı**. Mobil yorum temaları ağırlıkla basın incelemeleri ve otomatik özet sayfalarından; ham mağaza yorumu değil.
- Satış/gelir/indirme rakamları **TAHMİN**'dir (AppMagic / Sensor Tower, ikinci elden aktarım); hiçbiri bu raporun kendi ölçümü değil. Doğrulanamayan her veri "doğrulanamadı" yazıldı.
- Steam yüzdeleri yalnız **İngilizce incelemeler** içindir (mağaza sayfasında gösterilen).
- Görev tanımındaki "kale savunması + roguelite" ve "Bloons/tower-defense melezleri" örneklerinden yalnız **Bloons TD 6** doğrulandı. Kingdom Rush Vengeance doğrulanamadı (yanlış sayfa çekildi, veri kaydedilmedi); Rampart benzeri/kale savunma roguelite başlıkları **araştırılmadı**. Oyunun gerçek döngüsü kale savunması değil, hareketli hayatta kalma olduğundan (bkz. §5) çekirdek rakip seti survivors-like'tır.

## 2. Rakip tablosu

Kaynak sütunu mağaza/haber sayfasıdır; tüm erişim tarihi 2026-10-27.

| # | Oyun | Çekirdek döngü | Fiyat / model | Platform | İnceleme göstergesi | Kaynak |
|---|------|----------------|---------------|----------|---------------------|--------|
| 1 | Vampire Survivors | Otomatik saldırı, yalnız hareket; XP → silah/pasif seç, evrim; altın dükkânı, açılabilir karakterler | 3,49 $ | PC (Windows/macOS) | %98 olumlu / 128.424 (son 30 gün %94 / 909) | [Steam](https://store.steampowered.com/app/1794680/Vampire_Survivors/) |
| 1b | Vampire Survivors (mobil) | Aynı; mobilde tek çubuk | Ücretsiz, IAP yok, isteğe bağlı ödüllü reklam (reklamı kaldırma satın alması bulunamadı) | iOS/Android | İlk hafta ~1,1 M indirme (TAHMİN, AppMagic); mağaza puanı doğrulanamadı | [MobileGamer.biz](https://mobilegamer.biz/vampire-survivors-mobile-has-passed-1m-downloads-in-its-first-week/) |
| 2 | Brotato | Arena nişancısı roguelite; 20–90 sn dalga, aralarda dükkân; 6 silaha kadar | PC 2,99 $; mobil premium 4,99 $ | PC, iOS, Android | %96 / 32.686 (son 30 gün %90 / 945); iOS 4,7/5, 3,8 B puan | [Steam](https://store.steampowered.com/app/1942280/Brotato/), [App Store](https://apps.apple.com/us/app/brotato-premium/id1668755109) |
| 3 | Halls of Torment | Karanlık/Diablo esintili survivors-like; 30 dk koşu; 11 karakter, 6 harita, 74 yetenek/geliştirme | 4,99 $ | PC (Windows/Linux); mobil sürüm bulunamadı | %95 / 21.338 (son 30 gün %85 / 163) | [Steam](https://store.steampowered.com/app/2218750/Halls_of_Torment/) |
| 4 | 20 Minutes Till Dawn | Nişan alarak atış, 20 dk hayatta kalma; rün meta ilerlemesi | 4,99 $ | PC | %91 / 12.920 (son 30 gün **%48 / 64, Karışık**) | [Steam](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/) |
| 5 | Soulstone Survivors | Survivors-like; 350+ beceri, 100+ üretilebilir silah | 7,99 $ | PC | %91 / 12.367 (son 30 gün %80 / 110) | [Steam](https://store.steampowered.com/app/2066020/Soulstone_Survivors/) |
| 6 | Deep Rock Galactic: Survivor | Tek oyunculu otomatik nişancı; DLC'li | 7,49 $ | PC (mobil duyuruldu, Kasım 2025, mağaza verisi yok) | %87 / 24.134 (son 30 gün %82 / 201) | [Steam](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/), [Gematsu](https://www.gematsu.com/2025/09/deep-rock-galactic-survivor-coming-to-ios-android-in-november) |
| 7 | Survivor.io (Habby) | Mobil-öncelikli; tek el; koşu ≤15 dk, her 5 dk boss; **6 aktif + 6 pasif geçici yetenek** (bizimle aynı yuva düzeni) | Ücretsiz, IAP + reklam + gacha | iOS/Android | iOS 4,7/5, 245 B puan; gelir **TAHMİN** >500 M $ ömür boyu IAP (Sensor Tower, 2024) | [App Store](https://apps.apple.com/us/app/survivor-io/id1528941310), [Naavik](https://naavik.co/deep-dives/survivorio-archeros-footsteps/), [WNhub](https://wnhub.io/news/finance/item-43301) |
| 8 | Archero (Habby) | Mobil dur-ve-ateş et roguelite (horde survivor değil) | Ücretsiz, IAP (battle pass 4,99/16,99 $) + enerji | iOS/Android | iOS 4,7/5, 471 B puan | [App Store](https://apps.apple.com/us/app/archero/id1453651052) |
| 9 | Bloons TD 6 | Kule savunma; 25 kule × 3 yol, 17 kahraman, 70+ harita | 7,79 $ | PC (mobil fiyatı doğrulanamadı) | %97 / 232.259 (son 30 gün %96 / 2.704) | [Steam](https://store.steampowered.com/app/960090/Bloons_TD_6/) |

Özet gözlemler:
- PC'de tür fiyat çıpası **3–8 $**, memnuniyet **%87–98**. Mobilde üç model yan yana: premium (Brotato 4,99 $), ücretsiz + isteğe bağlı ödüllü reklam, IAP yok (Vampire Survivors), ücretsiz + IAP/gacha (Survivor.io, Archero) — gelir lideri sonuncusu (TAHMİN).
- Tipik koşu **15–30 dk** (20MTD 20 dk; Survivor.io ≤15 dk; Halls of Torment ~30 dk; Brotato <30 dk). Ashen Bastion'ın 20 dk'sı normun içinde. Vampire Survivors'ın 30 dk'sı alınan kaynakta doğrulanamadı.
- İçerik büyümesi: Vampire Survivors Erken Erişim'de 7 karakter / 22 silah / 1 harita ile başladı, 1.0 planı 24 karakter / 48 silah+evrim / 10 harita idi (plan; nihai sayı doğrulanamadı — [NME](https://www.nme.com/news/vampire-survivors-roadmap-teases-lots-more-characters-stages-and-weapons-3191859)). Halls of Torment 1.0'da 11 karakter, 6 harita.

## 3. Yorum temaları

Örnek sayısı çok küçük (bkz. §1); alıntılar kısa ya da özet. Tüm Steam bağlantıları `steamcommunity.com` "en faydalı" listeleridir, erişim 2026-10-27.

### 3.1 Olumlu temalar (oyuncular neyi seviyor)

| Tema | Örnek (özet / kısa alıntı) | Oyunlar | Kaynak |
|------|----------------------------|---------|--------|
| "Bir koşu daha" bağımlılığı | Oyuncu "Oyna'ya basıyorsun, saat sabahın 3'ü" diyor (VS, 2022-04); Brotato'yu sırf bırakmak için sildiğini yazan var (2023-05); patlamalar "beynimi mutlu ediyor" (Soulstone) | VS, Brotato, Soulstone | [VS](https://steamcommunity.com/app/1794680/positivereviews/?browsefilter=toprated&filterLanguage=english), [Brotato](https://steamcommunity.com/app/1942280/positivereviews/?browsefilter=toprated&filterLanguage=english), [Soulstone](https://steamcommunity.com/app/2066020/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Fiyatına değer | "Steam'deki en iyi 3 $'lık oyun" (VS); ~5 $'a 50 saat (Halls of Torment) | VS, HoT, 20MTD, Soulstone | [HoT](https://steamcommunity.com/app/2218750/positivereviews/?browsefilter=toprated&filterLanguage=english), [20MTD](https://steamcommunity.com/app/1966900/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Basit, erişilebilir kontrol | Engelli bir oyuncu kontrolü "çok erişilebilir" buluyor (VS, 2022-01); yalnız WASD ile oynanırken kedi sevilebiliyor (HoT); toplantıda bile oynanır (Soulstone) | VS, HoT, Soulstone | [VS](https://steamcommunity.com/app/1794680/positivereviews/?browsefilter=toprated&filterLanguage=english), [HoT](https://steamcommunity.com/app/2218750/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Build/silah sinerjisi keşfi | 3 saat sonra benzer silahların birleştirilebildiğini fark etmek (Brotato); "bir sürü seçenek" (20MTD) | Brotato, 20MTD, Soulstone | [Brotato](https://steamcommunity.com/app/1942280/positivereviews/?browsefilter=toprated&filterLanguage=english), [20MTD](https://steamcommunity.com/app/1966900/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Türün "daha aktif/ileri" hali | "VS'den bir basamak yukarı, NES'ten SNES'e" (HoT); "daha aktif bir Vampire Survivors" (20MTD) | HoT, 20MTD | [HoT](https://steamcommunity.com/app/2218750/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Mobil/flash oyun rahatlığı | "Eğlenceli bir mobil oyun gibi" (Brotato, 2022-10) | Brotato | [Brotato](https://steamcommunity.com/app/1942280/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Tamamlama/meydan okuma kancası | %100 tamamlama peşinde oyuncu (20MTD); "eğlenceli ve zorlayıcı" (Brotato) | Brotato, 20MTD | [20MTD](https://steamcommunity.com/app/1966900/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Cila / geliştirici kalitesi | "hem güzel görünüyor hem güzel oynanıyor" (20MTD) | 20MTD, Soulstone, DRG:S | [20MTD](https://steamcommunity.com/app/1966900/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Mobilde tek çubuk + dikey ekran | Tek çubuk kontrol başparmakla ve dikey oynanış için "mükemmel" (TouchArcade, VS mobil) | VS mobil | [TouchArcade](https://toucharcade.com/2022/12/09/vampire-survivors-mobile-review-controller-cloud-save-sync-dlc-unlock-iphone-ipad-pro/) |
| İsteğe bağlı ödüllü reklam / tek seferlik satın alma | Reklamlar isteğe bağlı ve rahatsız etmiyor (VS mobil); Brotato mobil tek seferlik premium | VS mobil, Brotato mobil | [Common Sense Media](https://www.commonsensemedia.org/app-reviews/vampire-survivors), [Pocket Tactics](https://www.pockettactics.com/vampire-survivors/review) |
| Karanlık/Diablo esintili estetik | Retro Diablo estetiği ve sınıf çeşitliliği övülüyor (HoT) — ama görseller "mütevazı", canavar tasarımı klişe bulunmuş | HoT | [Xbox Hub](https://www.thexboxhub.com/halls-of-torment-review/), [PC Gamer](https://pcgamer.com/games/action/halls-of-torment-review) |

Not: sanat/ses övgüsü ve "kısa oturum" övgüsü örneklerde belirgin çıkmadı; Halls of Torment'ta tersine "30 dk çok uzun" şikâyeti var.

### 3.2 Olumsuz temalar (oyuncular neden şikâyet ediyor)

| Tema | Örnek (özet / kısa alıntı) | Oyunlar | Kaynak |
|------|----------------------------|---------|--------|
| Koşular birbirine benziyor, build'ler az | Soulstone: "her build, karakter, silah ve koşu birebir aynı hissediyor"; DRG:S: "ilk koşu tüm koşular gibi" (2025-11); HoT: aynı 15 yetenek tekrar tekrar (2025-03) | Örnekte 6/6 oyun | [Soulstone](https://steamcommunity.com/app/2066020/negativereviews/?browsefilter=toprated&filterLanguage=english), [DRG:S](https://steamcommunity.com/app/2321470/negativereviews/?browsefilter=toprated&filterLanguage=english), [HoT](https://steamcommunity.com/app/2218750/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Zahmetli (grind) meta ilerleme | 20MTD: meta ilerleme "uğraşmaya değmez" (2023-08); HoT: aynı yeteneklerle zorluk seviyesi kasma; VS: "slot makinesi" hissi | Örnekte 5/6 | [20MTD](https://steamcommunity.com/app/1966900/negativereviews/?browsefilter=toprated&filterLanguage=english), [HoT](https://steamcommunity.com/app/2218750/negativereviews/?browsefilter=toprated&filterLanguage=english), [VS](https://steamcommunity.com/app/1794680/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Sığ geç oyun | HoT: 30. dk'dan sonra beceriler "ilham vermeyen istatistik bonusu" (2023-12); VS: eşyalar/evrimler öğrenilince strateji kalmıyor (2023-04); DRG:S: geliştiriciler "fikri yarıda tüketti" (2025-09) | Örnekte 4/6 | [HoT](https://steamcommunity.com/app/2218750/negativereviews/?browsefilter=toprated&filterLanguage=english), [VS](https://steamcommunity.com/app/1794680/negativereviews/?browsefilter=toprated&filterLanguage=english), [DRG:S](https://steamcommunity.com/app/2321470/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Denge ve zorluk sorunları | Brotato: eşya/silah/sınıflar "aşırı dengesiz" (2024-04); DRG:S: silah dengesi "berbat" (2025-10); Soulstone: zorunlu üst zorluk kademeleri elden geçmeli | Brotato, DRG:S, Soulstone | [Brotato](https://steamcommunity.com/app/1942280/negativereviews/?browsefilter=toprated&filterLanguage=english), [DRG:S](https://steamcommunity.com/app/2321470/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| RNG'ye bağımlılık | Brotato: "RNG uygulaması oyunu mahvediyor" (2024-03); ihtiyaç duyulan eşya gelmeyince koşu boşa | Brotato, Soulstone | [Brotato](https://steamcommunity.com/app/1942280/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Koşu çok uzun / yavaş tempo | HoT: 30 dk koşu "çok şey istiyor" (2023-07); VS: fazla pasif, beklemek gibi (2023-10) | HoT, VS | [HoT](https://steamcommunity.com/app/2218750/negativereviews/?browsefilter=toprated&filterLanguage=english), [VS](https://steamcommunity.com/app/1794680/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Yamaların oyun hissini bozması | HoT: 2023-09 yaması üç incelemede "keyfi öldürdü"; Brotato: "yeni güncelleme berbat" | HoT, Brotato | [HoT](https://steamcommunity.com/app/2218750/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| İçerik/mod eksikliği | DRG:S olumlu incelemelerde bile co-op, sonsuz mod ve içerik isteniyor (2024-02…11) | DRG:S | [DRG:S](https://steamcommunity.com/app/2321470/positivereviews/?browsefilter=toprated&filterLanguage=english) |
| Görsel erişilebilirlik | 20MTD: yanıp sönen ışıklar ve düşük kontrast yüzünden oynayamayan oyuncular (2022-06) | 20MTD | [20MTD](https://steamcommunity.com/app/1966900/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Kayıt kaybı / hata | Soulstone: kolay tetiklenen, kaydı sıfırlayan hata (2023-09) | Soulstone | [Soulstone](https://steamcommunity.com/app/2066020/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Platform ihmali algısı | 20MTD'nin 10 olumsuz örneğinden 6'sı PC sürümünün mobil için bırakıldığını söylüyor; son 30 gün %48 | 20MTD | [20MTD](https://steamcommunity.com/app/1966900/negativereviews/?browsefilter=toprated&filterLanguage=english) |
| Mobil: zorunlu reklam, enerji, pay-to-win | Archero 1'de enerji noktası başına ~12 dk (toplayıcı sayfa); Survivor.io'da reklamların ses ayarını aşması, ilerleme kaybı, pay-to-win algısı (otomatik özet sayfaları); VS mobilde reklamı satın alarak kaldırma yolu yok, küçük dokunma hedefleri (TouchArcade); Super Wizard'da yeniden diriliş reklam arkasında, reklamsız geçiş ayda 19,99 $ (TapTap) | Mobil başlıklar | [TouchArcade](https://toucharcade.com/2022/12/09/vampire-survivors-mobile-review-controller-cloud-save-sync-dlc-unlock-iphone-ipad-pro/), [TapTap](https://www.taptap.io/post/1735358), [JustUseApp](https://justuseapp.com/en/app/1453651052/archero/reviews), [Kimola](https://kimola.com/reports/comprehensive-survivor-io-feedback-report-unlock-insights-app-store-sg-142100) |
| Tür yorgunluğu / klon seli | Xbox Hub incelemecisi "Survivors" yorgunluğuna girdiğini yazıyor; The Sixth Axis klon selinden söz ediyor; VS sonsuz modunda 2.500+ dk'lık koşular "idle" oyuna dönüşüyor | Tür geneli | [Xbox Hub](https://www.thexboxhub.com/halls-of-torment-review/), [The Sixth Axis](https://thesixthaxis.com/2025/02/10/jotunnslayer-hordes-of-hel-early-access-review), [Steam tartışma](https://steamcommunity.com/app/1794680/discussions/0/3470612993476523598) |

Çapraz mobil rakam (tür özelinde değil, satıcı verisi; düşük güven): 1–3 yıldızlı mobil oyun yorumlarında agresif para kazanma/pay-to-win %34, hata/çökme %22, rahatsız edici reklam %18 — [Unstar](https://unstar.app/blog/gaming-app-reviews-what-mobile-gamers-hate-most-2026).

### 3.3 Talepler ve boşluk sinyalleri (forum/söylem; zayıf kanıt)

- **Karanlık tema + online co-op:** Halls of Torment başlığında karanlık temalı co-op arayan oyuncuya multiplayer gelmeyeceği, VS co-op'unun yalnız yerel olduğu söylenmiş — [Steam tartışması](https://steamcommunity.com/app/2218750/discussions/0/4033600999073816465). Ashen Bastion tek oyunculu; bu bir pazar boşluğu notudur, öneri değildir.
- **Koşu uzunluğu seçimi:** survivors-like'a özel talep **doğrulanamadı**; komşu türlerde var (Space Marine 2 horde, Warframe forumları) — [Focus forum](https://community.focus-entmt.com/focus-entertainment/space-marine-2/forums/6-general/threads/46959-how-would-you-like-horde-mode-to-function-in-terms-of-how-it-plays-out).
- **Erişilebilirlik:** VS'nin 26 erişilebilirlik özelliği var, zorluk seçici yok ([Family Gaming Database](https://www.familygamingdatabase.com/accessibility/Vampire+Survivors)). Steam rehberi ayarlanabilir yazı boyutu, renk alternatifi önerir ([Steamworks](https://partner.steamgames.com/doc/accessibility_features)). Tür özelinde renk körlüğü/yazı boyutu şikâyeti bulunamadı.
- **Türkçe:** Türkçe yok diye istek listesinden çıkaran/kampanya yapan Türk oyuncular var (genel Steam talebi, tür özelinde değil) — [Steam](https://steamcommunity.com/discussions/forum/1/601899481260118311), [Donanım Arşivi](https://forum.donanimarsivi.com/posts/11246800/). Talebin büyüklüğü ölçülemedi.
- **Doğrulanamadı** (kaynak yok): günlük meydan okuma talebi, dodge/aktif beceri talebi, ending/boss çeşitliliği talebi, enerji sistemi/pil/pay-to-win için tür özelinde mobil şikâyet, Türkiye Google Play puanları.

## 4. Çapraz özet: tekrar eden şikâyetler = pazar boşlukları

Örnek içinde en çok tekrar eden üç şikâyet: (1) koşular birbirine benziyor (6/6), (2) grind'li meta ilerleme (5/6), (3) sığ geç oyun (4/6). Ek olarak mobilde reklam/enerji/pay-to-win baskısı. **Çıkarım (örnek küçük, yaygınlık kanıtı değil):** run-to-run çeşitlilik yüksek, koşu uzunluğu ayarlanabilir/kısa, meta ilerlemesi kasma gerektirmeyen, reklamsız/enerjisiz ve düşük fiyatlı bir mobil oyun en çok tekrar eden boşlukların hepsine hitap eder.

## 5. Ashen Bastion bugün (kanıt: repo)

| Alan | Durum | Kanıt |
|------|-------|-------|
| Çekirdek döngü | Otomatik ateş, tek parmak sanal joystick, dikey ekran; öldür → XP → seviye → 3 karttan beceri seç; her koşu sıfırdan | `docs/design/2026-10-23-ashen-bastion-v1-design.md` §4–5 |
| Koşu yapısı | 20 dk; elit boss 5/10/15. dk, Düşmüş Kale Lordu 20. dk; kazanma = Lord'u yenmek | tasarım §5.1; `data/waves.json` (`end_time` 1200) |
| Beceri | 32 beceri tanımı: 15 aktif, 9 pasif, 8 evrim; 6 aktif + 6 pasif yuva | `data/skills/*.json` sayımı; tasarım §5.4 |
| Kimlik mekaniği | İki tabanca, ortak 6 mermilik şarjör, doldurma ritmi ve ona bağlı beceriler (Hızlı doldurma, Son mermi patlar, Doldururken saçılma…) | tasarım §5.3; `data/skills/` |
| Karakter | 2 (Gunslinger, Zyfen — rüzgâr büyücüsü); veriyle yeni karakter eklenir (`docs/dev/new-character.md`); kilit altyapısı var, kullanılmıyor | `data/characters/`; `docs/dev/user-verify.md` D-3 |
| Düşman | 7 tür: 3 temel, 3 elit, Kale Lordu | `data/enemies/` |
| Harita | 1 harita (üretimli parçalar + katı harabeler) | `data/ruins.json`; proje kartı |
| Meta | Kalıcı para/yükseltme **yok** (kullanıcı kararı); skor, ardışık öldürme çarpanı, en iyi skorlar, 19 aile / 53 kademe başarım (şimdilik yalnız kayıt, ödül yok) | tasarım §2; `data/score.json`; `data/achievements.json`; kart |
| Erişilebilirlik | BÜYÜK YAZI, renk körlüğü paneli, güvenli alan (v2.0.3) | `docs/design/v2.0.3/DESIGN.md`; kart |
| Dil | Yalnız Türkçe arayüz | tasarım §3 |
| Dağıtım | Store yok; imzalı APK elle kurulur; reklam/IAP/çevrimiçi yok | tasarım §2–3; kart |
| Denge | Kullanıcı geri bildirimi: "oyun şu an zor — 6 koşu, kazanma yok" (2025-10-25); F-011 açık, F-019 (wontfix) ile çelişkili | kart "Açık konular" |
| Planlı ama yok | Hızlı/normal/sonsuz koşu modları (karar 2026-10-26, ileri iş) | kart "Kapsam dışı kalanlar" |

Tasarım dokümanındaki "4 kademe düşman" ifadesi artık geçerli değil; veri 7 tür gösteriyor.

## 6. Üç soru

### 6.1 Bizde neler eksik (türde beklenen, bizde olmayan)

| # | Eksik | Neden "beklenen" | Değer | Maliyet |
|---|-------|------------------|-------|---------|
| E1 | Kazanılabilir/ayarlanabilir zorluk (denge) | Rakip incelemelerinde denge şikâyeti yaygın (Brotato, DRG:S, Soulstone); bizde kullanıcı 6 koşuda kazanamadı | Yüksek | S–M |
| E2 | Koşu modları (hızlı/normal/sonsuz) | HoT'ta "30 dk uzun" şikâyeti; DRG:S'de sonsuz mod istemi; VS'de sonsuz mod var | Yüksek | M |
| E3 | Yeterli karakter çeşitliliği (şu an 2) | VS EA'da 7, HoT'ta 11 karakter; "koşular aynı hissediyor" şikâyeti 6/6 | Yüksek | M (karakter başına, veri-güdümlü) – L (toplam) |
| E4 | Birden fazla harita/bölge (şu an 1) | VS 1.0 planı 10 harita; HoT 6 harita | Orta–Yüksek | L |
| E5 | Mağaza-hazır varlıklar ve dağıtım kanalı (mağaza sayfası, görseller, ekran görüntüleri, İngilizce) | Tüm rakipler bir kanalda; bizde APK-only, Türkçe-only | Dağıtım kararına bağlı (yüksek, karar verilirse) | M |
| E6 | Anlamlı kalıcı ilerleme (kasmayan) | Rakiplerde meta var; ama kasma şikâyet konusu | Orta | S–M |
| E7 | Çevrimiçi/yerel co-op | Karanlık temada co-op boşluğu görünüyor (zayıf kanıt) | Düşük (tek oyunculu vizyon) | L |

### 6.2 Neler eklenebilir (değer/maliyet sırasıyla)

| Sıra | Eklenti | Değer | Maliyet | Gerekçe |
|------|---------|-------|---------|---------|
| 1 | Denge geçişi + isteğe bağlı zorluk seçici (F-011 ile birlikte) | Yüksek | S–M | Kendi cihaz geri bildirimimiz; rakiplerde en sık denge şikâyeti. Zaten veri-güdümlü (`difficulty.gd`, `waves.json`). |
| 2 | Koşu modları: Hızlı (~10 dk) / Normal (20 dk) / Sonsuz | Yüksek | M | Kart "ileri iş" diyor. Tür şikâyeti: uzunluk (HoT), mod eksikliği (DRG:S). Mobil için kısa oturum güçlü kanca. |
| 3 | 3. ve 4. karakter (farklı oyun hissi: örn. yakın dövüş/tuzak) | Yüksek | M/karakter | "Koşular aynı" şikâyetinin doğrudan karşılığı; karakter ekleme hattı hazır (`ab-karakter-ekle`). |
| 4 | Başarımla karakter/kozmetik açma (kilit altyapısı mevcut) | Orta | S | Kasmadan ilerleme hissi; D-3 kararı bekliyor. |
| 5 | İkinci harita/tema (örn. katedral, mezarlık) | Orta–Yüksek | L | Çeşitlilik; maliyet yüksek (zemin + harabe + düşman görseli). |
| 6 | Boss/elit çeşitliliği + geç oyun karar noktaları | Orta | M | "Sığ geç oyun" şikâyeti; bizde 3 elit + Lord var. |
| 7 | İngilizce yerelleştirme | Yüksek (global dağıtım kararı gelirse) | M | Şu an yalnız Türkçe. Türkçe-öncelik pazarlama kancası olabilir (bkz. §7). |
| 8 | Yanıp sönme/kontrast seçenekleri (hassas ışık) | Orta | S | 20MTD şikâyeti; bizde renk körlüğü + büyük yazı var, yanıp sönme azaltma doğrulanmadı. |
| 9 | Günlük meydan okuma | Düşük | M | Talep doğrulanamadı; çevrimiçi/sunucu gerektirmeyen tohumlu sürüm mümkün. |
| 10 | Co-op | Düşük | L | Talep zayıf kanıtlı; vizyon tek oyunculu. |

### 6.3 Rakip şikâyetlerinden fırsatlar

| Rakip şikâyeti | Fırsat | Bizde durum | Değer | Maliyet |
|----------------|--------|-------------|-------|---------|
| Reklam/enerji/IAP baskısı (mobil) | "Reklamsız, enerjisiz, çevrimdışı, tek seferlik" konumlandırma | Zaten böyle (reklam/IAP/çevrimiçi hedef dışı) | Yüksek | S (iletişim) |
| Koşular aynı hissediyor | Veri-güdümlü karakter + evrim kombinasyonları; kuruluma özgü şarjör ritmi | 2 karakter, 8 evrim, şarjör kimliği var | Yüksek | M |
| Grind'li meta | "Kasma yok, her koşu sıfırdan" | Kullanıcı kararı zaten bu | Orta–Yüksek | S |
| Uzun koşu | 10 dk hızlı mod + 20 dk | Yalnız 20 dk | Yüksek | M |
| Dar kontrol / küçük dokunma hedefi (VS mobil) | Tek başparmak, büyük hedefler, güvenli alan | Tek parmak joystick + güvenli alan + büyük yazı | Orta | S (cihaz doğrulaması) |
| Yamaların hissi bozması | Sürümler arası denge karakterizasyonu (sim/baseline testleri var) | `tools/balance`, gate, golden hash | Orta | S |
| Kayıt kaybı/hata | Kayıt göçü ve testli başarım motoru | v1→v2 göç testleri var | Düşük–Orta | S |
| Platform ihmali algısı | Tek platforma net bağlılık | Yalnız Android | Düşük | — |

### 6.4 Önceliklendirilmiş kısa liste (ilk 5)

1. **Denge geçişi + zorluk seçici** — Değer yüksek, maliyet S–M. Kazanılamayan oyun pazarlanamaz; kendi cihaz verimiz + rakip denge şikâyetleri.
2. **Koşu modları (Hızlı/Normal/Sonsuz)** — Değer yüksek, M. Uzunluk ve mod şikâyetlerini kapatır; mobil oturum uygunluğu kancası.
3. **3. karakter (ayırt edici oynanışlı)** — Değer yüksek, M. "Koşular aynı" şikâyetinin ana ilacı; ikinci karakterle hat kanıtlı.
4. **Dağıtım kanalı kararı + mağaza-hazır varlıklar + İngilizce** — Değer: karara bağlı yüksek, M. Pazarlamanın ön koşulu (bkz. §8).
5. **Başarımla kilit açma (kasmayan meta)** — Değer orta, S. Altyapı hazır; ilerleme hissi.

## 7. Pazarlama fazına girdi

### 7.1 Hedef kitle tahmini (**varsayım**; hiçbiri ölçülmedi)

- **Birincil:** Türkiye'de Android'de oynayan, VS/Brotato/Survivor.io gibi oyunlara aşina, 16–35 yaş mobil oyuncular; Türkçe arayüz arayanlar (talep büyüklüğü doğrulanamadı).
- **İkincil (dağıtım kararı gelirse):** Reklam/enerji/IAP'tan bıkmış, premium veya reklamsız mobil survivors-like arayan global Android oyuncuları; karanlık/gotik estetik sevenler (Halls of Torment %95 olumlu, tema talebi var).
- **Üçüncül:** Arkadaş çevresi — tasarım kararı gereği ilk kitle (APK paylaşımı).

### 7.2 Konumlandırma cümlesi adayları

1. "Reklamsız, enerjisiz, tek başparmakla: yıkık kalede 20 dakikalık hayatta kalma."
2. "İki tabancanın ritmi: şarjörü boşalt, doldur, kaleyi ayakta tut."
3. "Karanlık gotik bir kalede, her koşuda farklı bir kombo — kasmadan."
4. "Cebindeki karanlık: dikey, tek elle, çevrimdışı survivors-like."
5. (Türkçe-öncelik) "Türkçe arayüzlü, Türkiye'nin kendi gotik hayatta kalma oyunu." — yerelleştirme talebi tür özelinde doğrulanamadı; test edilmeli.

### 7.3 Kanca (hook) adayları (kanıt: repo)

| Kanca | Neden güçlü | Doğrulama |
|-------|-------------|-----------|
| Şarjör/doldurma ritmi | Türde ayırt edici mekanik; rakip tablosunda yok (varsayım: kapsamlı tarama yapılmadı) | tasarım §5.3 |
| Tek parmak, dikey, çevrimdışı, reklamsız/enerjisiz | Mobil şikâyetlerin tersi (§3.2) | tasarım §2–3 |
| 20 dk koşu + 5/10/15 boss ritmi | Survivor.io (≤15 dk, 5 dk boss) ile aynı yapı, PC normu içinde | `waves.json` |
| Karakter başına farklı oyun hissi (tabanca / rüzgâr büyüsü) | "Koşular aynı" boşluğu | `data/characters/` |
| 53 kademeli başarım + mühürler | Tamamlama kancası (Brotato/20MTD'de övülüyor) | `data/achievements.json` |
| Hareketli karakter portreleri, gotik/manhwa çizgisi, taş-kahve palet | Görsel kimlik; HoT'ta görsel estetik hem övgü hem eleştiri konusu (jenerik kalma riski) | v2.0.3 tasarımı |
| Türkçe arayüz | Tür özelinde nadir; talep büyüklüğü doğrulanamadı | tasarım §3 |
| Kazanılabilir ve ayarlanabilir zorluk (yapılırsa) | Denge şikâyetinin tersi | E1 yapılırsa |

## 8. Riskler ve açık noktalar

- **Dağıtım kanalı yok.** Proje kararı "store'a çıkmaz, APK elle". Pazarlama stratejisi ya (a) kapalı/arkadaş dağıtımı ya da (b) mağaza çıkışı kararı gerektirir. Bu karar kullanıcının; growth görevi bunu sormalı. Mağaza kararı gelirse E5 ön koşuldur.
- **Repo public:** bu rapor ve pazarlama çıktıları karakterin esin kaynağı olan eser adını içermemelidir (kart kuralı).
- **Rekabet doygunluğu:** basın "tür yorgunluğu/klon seli" diyor; fark yaratma (kanca) zorunlu.
- **Hiç hands-on test yok** (Godot yok); elde hissi, performans ve görsel kalite denetlenemedi. Cihaz doğrulama listeleri (`docs/dev/user-verify*`) hâlâ açık.
- **Veri güveni:** örnek küçük; mobil mağaza verisi yok; Reddit yok; gelir/indirme rakamları tahmin. Pazarlama bütçesi/hedefi bu rakamlara dayandırılmamalı.
- **Doğrulanamadı listesi:** VS güncel içerik sayıları (wiki 402), Soulstone/DRG:S içerik sayıları, mobil puan/kurulum bantları, VS 30 dk koşu uzunluğu, Türkiye pazar büyüklüğü, tür özelinde günlük görev/dodge talebi.
