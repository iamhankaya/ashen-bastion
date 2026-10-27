# Kılıçlı çevik kadın karakter — birleştirilmiş tasarım (Game Director)

Tarih: 2026-10-27 · Durum: **öneri, kullanıcı onayı bekliyor** · Görev: T20261027-27 (değişiklik isteği 12:35)
Girdi: `sword-character-claude.md` (Nerya) ve `sword-character-codex.md` (Veyra). İkisi de okundu; bu belge ikisinin yerine geçmez, yan yana durur.
Kapsam: yalnız belge; kod, veri ve görsel yok. Sayılar öneridir, sim'de ölçülmedi (Godot yerelde çalışmıyor, hiçbir test koşulmadı). Esin kaynağı eser adı geçmez; "Barutçu olmayacak" kararı (2026-10-24) korunur.

---

## 0. Karşılaştırma

| Konu | Nerya (Claude) | Veyra (Codex) | Değerlendirme |
|---|---|---|---|
| Hikâye/ton | Son nöbetçi; düşen kılıçlar yoldaşların nöbeti | Cenaze yeminlerinin son kılıçlısı; süzülen kılıç tamamlanmamış nöbet, düşen kılıç geciktirilmiş hüküm | Veyra'da iki yetenek hikâyeye **bağlı** (güçlü); Nerya'nın "nöbetçi" fikri sade ve akılda kalıcı |
| Çeviklik | Otomatik adım + otomatik geri sıçrayış + hasarsız pencere | Atılma yok; toparlanmada kısa %15 hız artışı, dokunulmazlık yok | Nerya daha "atik" hissettirir ama sim'de oyuncu konumunu joystick dışında değiştirir (altın hash, çarpışma, bot riski yüksek). Veyra düşük risk ama his zayıf kalabilir |
| Temel saldırı | 170 px, 110° yay, delmez; hedef yokken kapasite davranışı belirtilmemiş | 135 px, 100° yay, en çok 3 hedef; hedef yokken kapasite harcanmaz; hedef hazırlıkta seçilir, isabette yeniden kontrol | Veyra daha kesin ve test edilebilir; boşa kapasite yakmayan kural iyi |
| Ritim | 5 kesik + 0,9 sn kına/sıyrılma | 4 kesik + 0,85 sn toparlanma | Aynı fikir; Nerya'da güvenli kına fazı net, Veyra'da yalnız hız artışı |
| Gökten düşen kılıç | Küme üstüne, 0,6 sn halkalı uyarı, ≤%25 anında ölür | Yakın dövüşle vurulan en dayanıklı hedefe, 0,35 sn, ×1,25 (%30 altı), boss hariç | Veyra'nın "yakın dövüşle hazırlanır" şartı **uzaktan öldürme aracı** olmasını önler; Nerya'nın uyarı halkası okunurluk için iyi. Anında ölüm kuralı Veyra'nın çarpanından riskli |
| Süzülen kılıç | Sürekli yanında, hedefe gezinip döner (1→2 kılıç, nokta hasar) | Kısa sefer: 70 px tur + 3→5 hedefe birer vuruş, 6→4,8 sn bekleme | Kullanıcı brifi "yanında dönen" der: Nerya **her an görünür**; Veyra hasar döngüsünü (hedef başına tek isabet, boss'a sürekli hasar yok) daha iyi sınırlar |
| Diğer aktifler | Sıyrılma Kesiği, Hilal Savuruşu, Karşı Kesik, Kın Darbesi | Dikiş Darbesi, Kabza Payı, Kırık Yemin | Nerya'nın dördü otomatik sıçrayışa/alan itmeye dayanır (Zyfen'in Nefes Dalgası'na yakın); Veyra'nınlar tek hedefli, çakışma az |
| Pasifler | 5 ortak varyant + 1 özel (Keskin Kenar) | 6 ortak varyant, yeni sayısal pasif yok | Veyra daha ucuz; ikisi de ortak havuzun alt kümesi olamadığını ve Mıknatıs'ın kaldığını not eder |
| Evrimler | Nöbet Yağmuru (3 kılıç), Çember Nöbeti, Gölge Çizgisi, Tam Daire | Kesin Hüküm, Son Nöbet, Çifte Dikiş, Açılan Gedik | Veyra'nınkiler daha ölçülü, boss kuralı açık; Nerya'nın Nöbet Yağmuru "ölçülü gösteriş"i zorlar |
| Denge/bot | `blade` politikası, bant: kite'ın %90–130'u, kite politikasında ≤%60 | `melee` politikası (105–130 px kal, toparlanırken 180–220 px), boss öldürme süresi, `hp_early` ölüm oranından ayrı | İkisi de bot sorununu doğru teşhis eder; Veyra'nın politika adımları ve metrikleri daha ayrıntılı, Nerya'nın kabul bandı sayısal |
| Görsel | Çelik beyazı + bordo; kısa ceket, at kuyruğu | Hex palet (#252326, #653D43, #C8BEA9, #92918B); ense hizası saç; hareket azaltma ayarı | Veyra'nın somut palet ve hareket azaltma maddesi kullanışlı; Nerya'nın "tek efekt rengi" ilkesi net |
| Animasyon | 19 hücre (1+8+6+4) | 19 hücre; hareketli saldırı için `walk_cast` ile 25 hücre / 8000 px riski | Veyra genişlik sınırı riskini erken görmüş |
| Maliyet | Sim işi L (sıçrayış yüksek risk) | "İlk doğrulanacak parça: temel saldırı + ritim + hareketli saldırı" kapısı | Veyra'nın prototip kapısı değerli; Nerya'nın efor tablosu karşılaştırma için faydalı |
| Zayıf yön | Otomatik sıçrayış ve Karşı Kesik sim'e en çok dokunan parçalar; 8 pasif görünür; "kılıç yalnız Nerya'nın elinde" fikrinde sınır çizilmedi | Süzülen kılıç tam "yanında dönen" gibi hissettirmeyebilir; çeviklik hissi cihazda zayıf çıkabilir | Birleşik tasarım bu iki zayıflığı ele alır (aşağıda) |

---

## 1. Tema, ad, hikâye

| Alan | Karar |
|---|---|
| Ad | **Veyra** |
| Unvan (TR) | **Son Ahit'in Nöbetçisi** |
| Unvan (EN) | **Veyra, the Last Oath-Warden** |
| Kimlik | Kadın, 20'lerinin sonunda; tek, dar, düz, tek elle kullanılan uzun kılıç |
| Ton | Kederli, soğukkanlı, gösterişsiz; kuvvetini çok silahtan değil, doğru anda inen tek kesikten alır |

**Hikâye çekirdeği.** Veyra, kale Nöbetçi Birliği'nin son yeminli kılıcıdır. Kale düşerken ölülerin silahlarını topladı; sahipleri huzura kavuşmadı. Şimdi elindeki gerçek kılıçla yol açarken yoldaşlarının yeminlerini soluk çelik suretlerle çağırır: yanında süzülen kılıç bir nöbetçinin tamamlanmamış nöbeti, gökten inen kılıç geciktirilmiş son hükümdür. Her kesik dizisinden sonra kılıcını toplar ("nöbet değişti"). Derin yazım sonraya kalır (Zyfen kararı gibi).

**Dünyaya uyum.** Yıkık kale, huzursuz ölüler ve yas teması mevcut karanlık gotik/manhwa çizgisine oturur. Zyfen'in soğuk yeşilimsi beyazı ve Gunslinger'ın sıcak barut turuncusu ile karışmaz (§5).

---

## 2. Oynanış kimliği

Fantezi: **"Yaklaş, kısa bir dizi kes, toparlanırken aç."** Tek parmak joystick korunur; saldırılar ve yetenekler otomatik çalışır.

### 2.1 Temel değerler (öneri)

| Değer | Gunslinger | Zyfen | **Veyra** |
|---|---|---|---|
| Can | 100 | 85 | **95** |
| Hareket hızı | 300 | 310 | **325** |
| Dizi (`mag_cap`) | 6 | 8 | **5 kesik** |
| Toparlanma (`reload_time`) | 1,0 sn | 1,3 sn | **0,85 sn** |
| Menzil | 700 | 750 | **135** |
| Temas yarıçapı | 22 | 22 | 22 |
| Başlangıç becerisi | `cift_tabanca` | `ruzgar_kesigi` | **Ahit Kesiği** |

Menzil gerekçesi: Çürümüş Piyade yarıçapı 26 + oyuncu 22 → temas ~48 px'te başlar; 135 px bunun ~2,8 katı (Nerya 170, Veyra 135 önermişti; 135 seçildi çünkü bot ölçümü kısa menzilde daha tutarlı bir "risk" bandı verir; cihazda 135–170 arası denenmeli, §7 S4).

### 2.2 Temel saldırı — Ahit Kesiği

- Erişilebilir **en yakın düşmana** yönelen 100° yay; en çok **3 hedefe** isabet, duvar arkasına vurmaz.
- Hedef hazırlıkta seçilir, isabet anında mesafe yeniden kontrol edilir (kesik hedef kaçtıysa boşa gitmez). Hareket yönüne kilitli değildir: oyuncu geri çekilirken de vurur.
- **Menzilde hedef yokken kapasite tüketilmez.**
- **Risk:** menzil kısa. Kodda temas hasarı `CONTACT_INTERVAL = 0,6 sn`, tick başına en çok 4 temas, Çürümüş Piyade `dmg 6` (`scripts/sim/damage_system.gd`, `data/enemies/curumus_piyade.json`): kalabalığın ortasında teorik üst sınır ~40 can/sn, 95 can ≈ 2,4 sn. Oyuncunun işi nişan almak değil, **grubun kenarında kalmak**: 100–135 px bandı hedeflenir, merkeze dalmak kuşatılma riski.

### 2.3 Çeviklik — hareket kontrolü eklemeden

Birleşik karar: **v1 düşük risklidir (otomatik konum sıçraması yok)**, ama his zayıf kalırsa kontrollü bir "v2 deneyi" hazır.

1. Hızlı ayak çalışması ve kısa saldırı hazırlığı (animasyon).
2. **Toparlanmanın ilk 0,3 sn'sinde %20 hareket hızı artışı**; mevcut joystick yönünü izler, dokunma yoksa karakteri oynatmaz; dokunulmazlık yok.
3. **Kesikten sonra kısa "geri tepme" yok**; konum yalnız oyuncunun joystick'iyle değişir.
4. *Opsiyonel v2 (kullanıcı kararı, §7 S1):* Nerya'dan alınan **otomatik geri sıçrayış** (~140 px) ve ~0,2 sn temas hasarsız pencere; altın hash ve çarpışma riski yüksek olduğu için önce prototipte ölçülür.

### 2.4 Şarjör/ritim karşılığı — Nöbet Dizisi

| Gunslinger/Zyfen | Veyra |
|---|---|
| Şarjör 6 / 8 mermi | **Dizi: 5 kesik** |
| Doldurma 1,0 / 1,3 sn | **Toparlanma 0,85 sn** (kılıç gövdeye çekilir, tutuş yenilenir; temel saldırı durur) |
| HUD çentikleri | Kapasite çentikleri 5 kesik hakkını gösterir |

- Diğer aktifler kendi kurallarını izler; toparlanmada yalnız temel saldırı durur.
- **Kapanış kesiği (Nerya):** 5. kesik +%30 hasar ve +15° yay; ritmin sonunu hissettirir.
- Pasifler ritmi besler: Uzun Ahit daha uzun hücum, Sakin Tutuş daha kısa açık an.

---

## 3. Yetenek havuzu ve evrimler

Kural (Zyfen tasarımı): *değer artıranlar ortak, ekranda bir şey yapanlar karaktere özel.* **Başlangıç saldırısı dahil 6 aktif, 6 pasif, 4 evrim çifti.** Değerler seviye 1 → 5; ara seviyeler kademeli.

### 3.1 Altı aktif

| # | Aktif | Davranış ve ölçek |
|---|---|---|
| 1 | **Ahit Kesiği** *(temel saldırı)* | 22 → 40 hasar; 0,34 → 0,28 sn aralık; 135 px, 100° yay, ≤3 hedef; her kesik 1 kapasite |
| 2 | **Son Hüküm — gökten düşen kılıç** *(kullanıcı fikri)* | Son 2 sn içinde Ahit Kesiği ile vurulmuş düşmanlardan, 220 px içindeki **en yoğun/en dayanıklı hedefin** bulunduğu noktaya **tek kılıç** iner. Uyarı: yerde ince halka 0,45 sn. Hasar 90 → 190, yarıçap 50 → 65 px, bekleme 7 → 5 sn. Canı **%30 altı** sıradan düşmana ×1,5 (infaz); boss'a bu bonus yok. Geçerli hedef yoksa bekler |
| 3 | **Nöbetçi Çelik — süzülen kılıç** *(kullanıcı fikri)* | Kılıç **her an Veyra'nın yanında** 70 px yarıçapta süzülür (hasarsız, yalnız görsel). Her "sefer"de (3,0 → 2,2 sn bekleme) 190 → 220 px içindeki **en çok 3 → 5 ayrı** düşmanı birer kez ziyaret edip döner; hedef başına 16 → 30 hasar; sefer en çok 2,4 sn. Boss'a sefer başına tek isabet. İtme/çekme yok |
| 4 | **Dikiş Darbesi** | Son temel saldırı hedefinin doğrultusunda dar saplama: 170 → 190 px, 45 → 90 hasar, ≤2 hedef, 4 → 3 sn. Mermi oluşturmaz |
| 5 | **Kabza Payı** | Toparlanma başlarken en yakın düşmana tek kabza darbesi: 110 px, 18 → 36 hasar, itme 55 → 85 (boss'a itme yok). Çevresel dalga yok |
| 6 | **Kırık Yemin** | Dizi başına ilk temel isabet hedefi 3 sn işaretler; sonraki temel isabette işaret tüketilir, **30 → 70 ek hasar**. Yığılmaz, başka hedefe yayılmaz |

Ölçek kontrolü (mevcut veriden): Delen Rüzgar L1 80 hasar / 3,2 sn tek hedef; Keskin Nişan L1 90 / 3,0 sn tek hedef; Girdap L1 6 hasar, 0,5 sn, yarıçap 90. Son Hüküm bunlardan seyrek ve yakın dövüşle şartlı; Nöbetçi Çelik'in L1 hedef başına DPS'i (16 / 3,0 sn) Girdap'ın halka DPS'inin altında, ama hedef seçer.

### 3.2 Altı pasif

Yeni sayısal pasif yok; ortak pasifler `variants.<id>` ile karaktere özgü ad/ikon alır (değerler o seviyenin toplam etkisi):

| Ad | Ortak karşılık | L1 → L5 |
|---|---|---|
| Bilenmiş Ağız | `agir_kursun` | Hasar +%10 → +%50 |
| Seri Bilek | `hizli_parmak` | Saldırı hızı +%8 → +%40 |
| Uzun Ahit | `fazladan_mermi` | Dizi +1 → +5 |
| Sakin Tutuş | `hizli_doldurma` | Toparlanma −%10 → −%50 |
| Hafif Adım | `cevik_cizme` | Hız +%6 → +%30 |
| Yas Zırhı | `saglam_yelek` | Can +15 → +75; yenilenme 0,25 → 1,25/sn |

**Mıknatıs** ortak olduğu için havuzda kalır (7 ortak pasif zaten gelir; `pool` yalnız `common` ya da karakter kimliği, alt küme yok: `scripts/sim/data_v202_pool.gd`). 6'ya indirmek ortak havuzu karaktere göre filtrelemeyi gerektirir (kod işi; §7 S6). **Doğrulanmadı:** `agir_kursun` alanı `bullet_dmg_mult` kılıç hasarına uygulanıyor mu; uygulanmıyorsa Bilenmiş Ağız etkisiz kalır.

### 3.3 Dört evrim çifti

Mevcut şema: aktif seviye 5 + pasif en az seviye 1; evrim aynı yuvayı devralır.

| Çift | Evrim |
|---|---|
| Son Hüküm + Bilenmiş Ağız | **Kesin Hüküm:** 260 doğrudan hasar; hedef canı %30 altındaysa +80; yarıçap 65'te; boss'a ek hasar yok |
| Nöbetçi Çelik + Seri Bilek | **Son Nöbet:** tek kılıç 6 hedefi 36'şar hasarla ziyaret eder; 4,2 sn bekleme; boss'a sefer başına tek isabet |
| Dikiş Darbesi + Uzun Ahit | **Çifte Dikiş:** 0,12 sn arayla iki saplama, her biri 70; ikincisi hedefi yeniden takip etmez |
| Kabza Payı + Sakin Tutuş | **Açılan Gedik:** en yakın 2 ayrı düşmana 50'şer hasar, itme 95; boss itme bağışıklığını korur |

Kırık Yemin ve Ahit Kesiği evrimsizdir.

### 3.4 Mevcut havuzdan ayrım (Zyfen çakışması dahil)

| Mevcut | Veyra'daki karşılık | Fark |
|---|---|---|
| Zyfen **Girdap** (sürekli halka, itme) | Nöbetçi Çelik | Girdap çevresel sürekli hasar + itme. Kılıç ayrı cisim: boşta **hasarsız**, hasar yalnız seçili hedef ziyaretinde, itme/çekme yok, hedef başına bir isabet. Sim'de ayrı davranış; rüzgâr alanı kodunu paylaşmaz |
| Zyfen **Hortum/Tufan** (kalabalığı toplayan gezen alan) | Nöbetçi Çelik | Kılıç çekmez, alan bırakmaz, uzak kümeyi kovalamaz (190–220 px) |
| Zyfen **Delen Rüzgar / Göğün Mızrağı** (anında, en yüksek canlı hedefe, delici, art arda) | Son Hüküm | Tek düşüş, uyarılı, **alan** darbesi, delmez, önceden **yakın dövüş isabeti** ister |
| Zyfen **Nefes Dalgası** (toparlanırken çevreyi iter) | Kabza Payı | Toparlanmada yalnız **tek** tehdide müdahale; dalga yok |
| Gunslinger **Keskin Nişan** (tek atış infaz) | Son Hüküm | Menzil ve hedefleme farklı (yakın kümede, şartlı); barut/patlama dili yok |
| Gunslinger seken mermi, saçılma, ölüm patlaması | Kırık Yemin, Dikiş Darbesi | Kısa mesafede hedefe bağlı kesik; Kırık Yemin öldürme zinciri başlatmaz |

---

## 4. Denge niyeti ve sim botu

**Ödül:** kısa pencerede birkaç düşmana güçlü hasar (3 hedefli yay), yakın mesafeden kazanılan infaz, hareketli savunma. **Bedel:** toparlanırken temel hasarın kesilmesi, kuşatılma, boss'a yaklaşma zorunluluğu. Kalıcı hasar azaltma, can çalma ve dokunulmazlık önerilmiyor (v1).

**DPS hedefi.** Ahit Kesiği L1: 5 kesik × 22 = 110 hasar / (5 × 0,34 + 0,85 = 2,55 sn) ≈ **43 tek hedef hasarı/sn** (kesintisiz döngü, el hesabı); menzilde geçen süre ve ıskalarla düşer, 3 hedefli isabet ayrıca ölçülür. Kümede Gunslinger'ın **%110–130'u**, tek hedefte **%85–95'i** hedeflenir (Nerya bandı; öneri).

**Botlar uzak durur.** `test/helpers/bots.gd` `_kite_dir` tehdit yarıçapı içindeki düşmanlardan uzaklaşır; `mid_run.gd` `strong` politikası da tehdit görünce kaçar (Codex: ~260 px). Böyle bir bot 135 px menzili sistematik bastırır → ölçüm yanıltıcı. Çözüm:

1. **Yeni `melee` politikası (yalnız sim durumunu kullanır; rastgelelik yok):** grubun kenarındaki erişilebilir hedefe yaklaş; kapasite varken ~105–130 px'te kal; toparlanırken 180–220 px'e aç; kuşatılınca açık sektöre çık; duvar dolanması korunur; can < %50 ise `kite`'a geç.
2. Eski `strong/kite` sonuçları da **raporlanır** (uzak durma davranışındaki performans).
3. **Ölçümler:** aynı tohumlarda `kills5`, `hp_early` (yaşayan örneklerden hesaplandığı için **ölüm oranından ayrı** yorumlanmaz), erken ölüm oranı; menzilde geçen süre, boşa savuruş, verilen hasar başına alınan hasar, toparlanmada alınan hasar (sıfıra yakın olmalı), boss öldürme süresi, 10/15/20. dk can eğrisi. Yoğunluk DPS ve Lord bütçesi ölçümleri de yapılır.
4. **Kabul bandı (öneri):** `melee` politikasında Veyra `kills5` ≥ Gunslinger `kite` değerinin %90'ı ve ≤ %130'u; `hp_early` Gunslinger'dan düşük (risk primi) ama koşu bitebilir; `kite`/`strong` politikasında Gunslinger'ın en çok %60'ı. Bant dışı → önce katsayılar, sonra beceriler.
5. **Gunslinger kanıtı:** mevcut politikalarla `kills5/hp_early` farkı **±%5 içinde** kalır; `PRIORITY_BY_CHAR` satırı eklenir (yoksa Gunslinger önceliğine düşer).
6. **Dürüst sınır:** bot başarısı telefonda yakın dövüş rahatlığının yerine geçmez; elde hissi ölçülemez, kullanıcı notu istenir (§7).

---

## 5. Görsel ve animasyon brifi

**Silüet:** kısa, iki parçalı yas ceketi, belirgin çizmeler, bordo kuşak (tek renk damlası), ense hizasında toplu saç, gövdeden ayrılan tek uzun kılıç. Uzun palto ve geniş büyücü silüeti yok (Zyfen'den ayrılır). Kadın kimliği duruş, yüz ve oranlarla okunur; zırh hareketi destekler, yüz manhwa çizgisi, sakin.

**Palet:** kömür siyahı `#252326`, solmuş bordo `#653D43`, kirli kemik `#C8BEA9`, mat çelik `#92918B`. **Efekt rengi tek: soğuk çelik beyazı** (~`#DCE6EE`, hafif mavi kayık; Zyfen'in yeşilimsi beyazıyla ve Gunslinger turuncusuyla karışmaz). Amber/turuncu kullanılmaz.

**Ölçülü gösteriş** (ilke: tek renk, kısa süre, küçük ekran payı, tok ses):

- **Son Hüküm:** yerde 0,45 sn ince çelik beyazı halka (yarıçap = alan, dolgu yok); tek ince kılıç hattı ~0,08 sn'de iner; çarpmada 2 kare beyaz parlama, yerde kısa çatlak çizgi, az toz; **ekran sarsıntısı ≤ 2 px / 80 ms**; kılıç 0,6 sn saplı kalıp solar (yalnız görsel). Tek ses: tok metal.
- **Nöbetçi Çelik:** ~24×96 px tek sprite; kod ile süzülür; arkasında 6 örnekli solan kısa iz (0,2 sn); **kalıcı ışıklı halka yok**; sefer sırasında hedeflere uçar, vurunca yalnız mevcut hit flaşı.
- **Ahit Kesiği:** temas anında kısa çelik yay (0,12 sn); rutin saldırıda ekran sarsıntısı yok; 5. (kapanış) kesik biraz geniş ve 1 kare uzun.
- **Hareket azaltma** ayarı açıkken art izler kapanır, hedef işareti (halka) korunur.
- Efektler kod/shader (proje kararı); yalnız kılıç ve ikonlar sprite.

**Şerit planı (`ab-animasyon-seridi` / `ab-karakter-ekle`, tek parça gövde, `rig.armless: true`):** 8 yürüme + 1 duruş + 6 saldırı (`fire_frame: 3`, sıfır tabanlı, 24 fps) + 4 toparlanma = **19 hücre**; hücre yüksekliği 320, `display_height` 200. Hareket ederken de saldırdığı için `walk_cast` gerekebilir: +6 hücre = 25 hücre; 320 px hücre genişliğinde şerit 8000 px (sınır 8192; kılıç daha geniş hücre isterse aşılır). **İlk üretim kontrolü: kılıç pozunun hücre genişliği ve hareketli saldırı okunurluğu.**

Üretim yolu: duruş referansı → sabit kameralı, sağa bakan düz yeşil zemin videoları → ffmpeg kare seçimi → yeşil silme → şerit + manifest (kart notu: kare kare bağımsız görsel üretimi yok). Ayak kayması, klip boy farkı ve kıyafet tutarlılığı kalite kapısından (`quality.json`) geçmeli; kılıç kenarında yeşil hale riski var. Süzülen/düşen kılıç **ayrı tek sprite** (gövde karesinde değil).

İkon sayısı: 6 aktif + 4 evrim + 6 pasif varyantı (+ Mıknatıs varyantı isteğe bağlı) = **16**. Portre (1024×1536, tam sahne): `ab-gorsel-ikon-uret`. Bu fazda görsel üretilmez.

---

## 6. Maliyet ve risk

**Toplam kapsam: orta-yüksek.** Veri/hat hazır (`ab-karakter-ekle`); yeni sim davranışı gerekir ama Nerya'nın otomatik sıçrayışı v1'den çıkarıldığı için sim riski düştü.

| İş | Maliyet / temel risk |
|---|---|
| Karakter verisi, ortak pasif adları (`variants`) | Düşük |
| Altı aktif + dört evrim | Yüksek: yeni davranışlar (yay isabeti, hedef geçmişi, gezici kılıç, uyarılı alan darbesi), deterministik hedef sırası |
| Yakın dövüş isabeti + duvar kontrolü | Orta-yüksek: görüntüdeki temas sim isabetiyle örtüşmeli |
| Animasyon | Orta-yüksek: kılıç genişliği, aynalama, hareketli saldırı |
| `melee` bot politikası + denge | Orta: uzak politikalar korunur, yenisi eklenir |
| Görsel/ses | Portre, şerit, 16 ikon, kısa ses seti |
| *(v2 deneyi)* Otomatik sıçrayış | **Yüksek:** altın hash, çarpışma, temas hasarı kodu |

**İlk doğrulanacak parça (Codex'ten):** Ahit Kesiği + 5 kesikli ritim + hareketli saldırı. Bu tatmin edici olmadan havuzun tamamı üretilmez.

**F-ashen-bastion-060 testleri.** Karakter listesini sabitleyen 4 test yeni karakterde elle güncellenir: `test/unit/test_character_roster.gd:44` (`test_ids_follow_order_field`), `test/unit/test_characters_screen.gd:273` (`test_f030_gunslinger_first_by_order_field`), `test/acceptance/test_acc_v2_chars.gd:640` (`test_k10_single_character_set_works`: Zyfen silince tek karakter kaldığını varsayar, gerçek tek karakterli veri kurmalı), `test/unit/test_v202_pool_real.gd:64` (filtresiz aktif/evrim sayısı). Satır numaraları bulgu dosyasından; testler bu görevde yeniden doğrulanmadı. Öneri: beklentileri veri tabanlıya çevirmek (F-060).

Diğer: yeni karakter için altın hash aşaması eklenir, Gunslinger kayıtları değişmez. Cihaz listesi `docs/dev/user-verify/` altına kendi bölüm dosyası. Perf: Nöbetçi Çelik varlık sayısı Redmi Note 13 Pro'da cihaz dışında doğrulanamaz. Sıra dersi: JSON'u görseller/beceri/`--import`'tan sonra bağla.

---

## 7. Kullanıcıya açık sorular

1. **S1 — Çeviklik:** v1'de otomatik atılma yok (hızlı ayak + toparlanmada %20 hız artışı) yeterli mi, yoksa otomatik geri sıçrayış + kısa hasarsız pencere (v2 deneyi) mi istersin? *(Önerilen: önce v1, cihazda zayıfsa v2.)*
2. **S2 — Süzülen kılıç:** yanında **sürekli görünsün**, hasarı seferlerle (hedef başına tek isabet) versin tasarımı yeterli mi, yoksa sürekli dönüp sürekli mi vursun? *(Önerilen: birincisi; boss'a sürekli hasar riskini önler.)*
3. **S3 — Gökten düşen kılıç:** yakın dövüşle vurulmuş hedefe bağlı olması hoşuna gider mi, yoksa bağımsız mı çalışsın? Canı %30 altındaki düşman için anında ölüm mü, ×1,5 hasar mı? *(Önerilen: yakın dövüş şartı + ×1,5.)*
4. **S4 — Menzil/ritim:** 135 px ve 5 kesik mi, 170 px (Nerya) ya da 4 kesik (Veyra) mı? Daha uzun kombo dizileri mi istersin?
5. **S5 — Ad/tema:** "Veyra / Son Ahit'in Nöbetçisi (the Last Oath-Warden)" uygun mu; daha dünyevi bir düellocu kimliği ya da Nerya adı mı?
6. **S6 — Pasif sayısı:** 6 hedefi için ortak havuzu karaktere göre filtrelemek (kod işi) mi, yoksa Mıknatıs dahil 7 ortak pasifin görünmesi mi kabul? *(Önerilen: kabul; filtre sonra.)*
7. **S7 — Kıyafet:** kısa yas ceketi + hafif zırh mı, daha törensel bir kıyafet mi? Palet ve tek efekt rengi (soğuk çelik beyazı) onaylı mı?
8. **S8 — Kilit:** baştan açık (Zyfen gibi) mı, bir başarıma bağlı mı?
9. **Cihaz notu (elde hissi):** prototipte Redmi Note 13 Pro'da menzil (135), toparlanma hız artışı, kalabalıkta efekt okunurluğu ve Nöbetçi Çelik performansı kontrol edilecek. **Elde hissi şu an denetlenemedi.**

---

## 8. Hangi öğe nereden geldi ve neden

| Öğe | Kaynak | Neden |
|---|---|---|
| Ad Veyra, "Son Ahit" yemin teması | Codex (Nerya'dan "nöbetçi" unvanı) | İki kullanıcı yeteneği hikâyeye bağlanıyor; "nöbet" sözcüğü Nerya'dan korundu |
| Temel saldırı kuralları (100°, ≤3 hedef, hedef yoksa kapasite harcanmaz, hazırlıkta seç / isabette doğrula) | Codex | Boşa kapasite yakmaz, test edilebilir |
| Menzil 135, can 95, 5 kesik, 0,85 sn | Karma (Codex menzil/toparlanma; Nerya 5 kesik; can aradaki değer) | 5 kesik Uzun Ahit'e alan bırakır; sayılar sim'de ayarlanır |
| Kapanış kesiği (5. kesik güçlü) | Nerya | Ritim sonunu duyurur, ek kod küçük |
| Çeviklik v1: %20 hız artışı, otomatik sıçrayış yok | Codex (güç artışı Nerya'dan uyarlandı) | Sim'de konum değiştirme riskini (altın hash, çarpışma) v1'den çıkarır |
| Otomatik sıçrayış + hasarsız pencere | Nerya, **v2 deneyi** olarak | Atiklik hissi için güçlü, ama en riskli parça; kullanıcıya soruluyor |
| Süzülen kılıç **sürekli görünür** | Nerya | Kullanıcı brifi "yanında dönen" der |
| Süzülen kılıç **sefer ve tek isabet kuralı**, boss tek isabet | Codex | Sürekli boss hasarı ve Girdap çakışması önlenir |
| Gökten düşen kılıç **yakın dövüş şartı, boss bonus yok** | Codex | Uzaktan otomatik öldürme aracı olmasın |
| Gökten düşen kılıç **uyarı halkası (0,45 sn)** ve alan darbesi | Nerya | Mobil ekranda okunurluk; "ölçülü" ama adil |
| Anında ölüm (%25) yerine ×1,5 (%30 altı) | Codex | Boss/elit dengesi ve test kolaylığı |
| Dikiş Darbesi, Kabza Payı, Kırık Yemin | Codex | Tek hedefli, Zyfen'in alan etkileriyle çakışmaz, sim'e tek hedef mantığı |
| Sıyrılma Kesiği, Karşı Kesik, Kın Darbesi, Hilal Savuruşu | Nerya, **bırakıldı** | Otomatik sıçrayışa veya Nefes Dalgası'na yakın alan itmeye dayanır; Hilal Savuruşu ileride "kuşatılınca çıkış" adayı |
| Altı ortak pasif varyantı, yeni sayısal pasif yok | Codex (Nerya'nın 5 varyant fikriyle örtüşür) | En ucuz, değerler hazır; Keskin Kenar (özel pasif) kod tasarrufu için çıkarıldı |
| Dört evrim (Kesin Hüküm, Son Nöbet, Çifte Dikiş, Açılan Gedik) | Codex | Ölçülü, boss kuralları açık; Nerya'nın Nöbet Yağmuru "ölçülü gösteriş"e ters |
| Zyfen çakışma tablosu | Birleşik | İkisinin ayrımı tek tabloda; renk ayrımı Nerya'dan |
| `melee` bot politikası adımları, metrikler, ölüm oranı uyarısı | Codex | Daha ayrıntılı ve sızıntı yok |
| Sayısal kabul bandı (kite %90–130, kite politikasında ≤%60), Gunslinger ±%5 | Nerya + mevcut ölçüt | Kabul ölçütü olmadan bot sonucu yorumlanamaz |
| Palet (hex) | Codex | Somut; Zyfen yeşiliyle çakışmaz |
| Tek efekt rengi (soğuk çelik beyazı), efekt ilkeleri (≤2 px sarsıntı vb.) | Nerya | "Ölçülü gösteriş" için ölçülebilir kural |
| Hareket azaltma ayarında art izler kapanır | Codex | Erişilebilirlik |
| 19 hücre, `walk_cast` ile 25 hücre / 8000 px riski, ilk kontrol | Codex | Genişlik sınırı riskini erkenden yakalar |
| Prototip kapısı ("önce temel saldırı + ritim + hareketli saldırı") | Codex | Havuza yatırım yapmadan his doğrulanır |
| F-060 dört test | İkisi (aynı) | Skill ve bulgudan; yeniden doğrulanmadı |

---

## 9. Varsayımlar ve doğrulanmayanlar

- Tüm sayılar öneridir; sim'de ölçülmedi, hiçbir test koşulmadı (yalnız Markdown).
- `data_v202_pool.gd` davranışı (ortak havuz alt kümesi yok) kısa okumadan; `agir_kursun`'un kılıç hasarına etkisi **doğrulanmadı**.
- DPS rakamı (≈43/sn) el hesabıdır; Gunslinger ile oran bandı sim'de ölçülmedi.
- Test satır numaraları F-ashen-bastion-060'tan, yeniden doğrulanmadı.
- Elde hissi denetlenemedi.
- Esin kaynağı eser adı kullanılmadı.
