# Kılıçlı karakter önerisi (Codex)

27 Ekim 2026 — bağımsız tasarım taslağı. Sayılar ilk prototip içindir; uygulanmış veya dengesi doğrulanmış değildir. Dosya değiştirilmedi, görsel üretilmedi; `docs/design/characters/` okunmadı.

## 1. Tema, ad ve kısa hikâye

**Ad:** Veyra  
**Türkçe unvan:** Son Ahit’in Kılıcı  
**İngilizce:** Veyra, Blade of the Last Oath

Veyra, kale muhafızlarının cenaze yeminlerini tutan son kılıçlıdır. Kale düştüğünde ölülerin silahlarını topladı; ancak sahipleri huzura kavuşmadı. Şimdi elindeki gerçek kılıçla yol açarken, taşıdığı yeminlerin soluk çelik suretlerini çağırır. Yanında süzülen kılıç bir muhafızın tamamlanmamış nöbeti, gökten inen kılıç ise geciktirilmiş son hükümdür.

Kadın, çevik, soğukkanlı bir yakın dövüşçü. Büyüsü sınırlı ve ağırbaşlıdır: kuvvetini çok sayıda silah göstermekten değil, doğru anda inen tek kesikten alır.

Kale harabeleri, huzursuz ölüler ve yas teması mevcut dünyayla uyumludur. Barutçu olmayacak; silah, mekanik ve görsel kimliği kılıç üzerine kuruludur.

**Dayanak:** [Ana dünya tasarımı](docs/design/2026-10-23-ashen-bastion-v1-design.md), [Zyfen tasarımı](docs/design/v2.0.2/2026-10-24-zyfen-design.md).

## 2. Oynanış kimliği

**Ana his: yaklaş, kısa bir kesik dizisi çıkar, toparlanırken mesafe aç.** Oyuncu mevcut tek parmak hareketini kullanır; saldırılar ve yetenekler otomatik çalışır.

| Başlangıç değeri | Öneri |
|---|---:|
| Can | 100 |
| Hareket hızı | 325 |
| Çarpışma yarıçapı | 22 |
| Temel saldırı menzili | 135 |
| Dizi kapasitesi, `mag_cap` | 4 kesik |
| Toparlanma, `reload_time` | 0,85 sn |
| Başlangıç becerisi | Ahit Kesiği |

Karşılaştırma için Gunslinger 100 can, 300 hız ve 700 menzile; Zyfen 85 can, 310 hız ve 750 menzile sahip. Veyra’nın avantajı hareket ve kısa mesafede yoğun hasar olmalı.

**Menzil ve risk:** Temel saldırı, erişilebilir en yakın düşmana yönelen 100° bir yaydır. Hareket yönüne kilitlenmez; oyuncu geri çekilirken de vurabilir. En fazla üç hedefe isabet eder. Hedef, hazırlık başında seçilir; isabet anında mesafe yeniden kontrol edilir. Duvar arkasına vurmaz. Menzilde hedef yokken kapasite tüketilmez.

Böylece dikey ekranda oyuncunun işi ayrıca nişan almak değil, düşman grubunun kenarında kalmaktır. Yaklaşık 105–135 birimlik saldırı bandı hedeflenir; merkeze dalmak kuşatılma riski taşır.

**Çeviklik:** Yeni atılma düğmesi veya otomatik konum sıçraması eklenmez. Hızlı ayak çalışması, kısa saldırı hazırlığı ve toparlanmanın ilk 0,25 saniyesindeki **%15 hareket hızı artışı** kaçış hissi verir. Bu artış mevcut joystick yönünü izler; dokunma yoksa karakteri hareket ettirmez. Dokunulmazlık sağlamaz.

**Şarjör karşılığı:** Dört kesikten sonra Veyra kılıcını gövdesine yakın toplar, tutuşunu yeniler. Temel saldırı durur; diğer aktifler kendi kurallarını izler. HUD’daki kapasite çentikleri dört kesik hakkını gösterir. Fazladan kapasite daha uzun hücum, hızlı toparlanma daha kısa açık anlamına gelir.

**Dayanak:** [Gunslinger verisi](data/characters/gunslinger.json), [Zyfen verisi](data/characters/zyfen.json), [karakter ekleme sözleşmesi](docs/dev/new-character.md).

## 3. Yetenek havuzu ve evrimler

Altı aktif **başlangıç saldırısını içerir**. Aktifler ve evrimler Veyra havuzundadır. Aşağıdaki değerler seviye 1 → 5’i gösterir; ara seviyeler kademeli ilerler.

### Altı aktif

| Aktif | Davranış ve ölçek |
|---|---|
| **Ahit Kesiği** | Temel saldırı. 24 → 42 hasar; 0,34 → 0,28 sn aralık. 135 menzil, 100° yay, en fazla üç hedef. Her savuruş bir kapasite tüketir. |
| **Son Hüküm — gökten düşen kılıç** | Son 2 sn içinde temel saldırıyla vurulmuş, 220 birim içindeki en dayanıklı hedefin bulunduğu noktaya tek kılıç iner. 0,35 sn işaretleme; 90 → 190 hasar, 45 → 60 yarıçap, 7 → 5 sn bekleme. Canı %30 altındaki düşmana ×1,25; boss’a bu bonus uygulanmaz. Geçerli hedef yokken bekler. |
| **Nöbetçi Çelik — süzülen kılıç** | Tek kılıç önce karakter yanında 70 birim yarıçapta kısa bir tur atar; ardından 190 → 220 birim içindeki en fazla 3 → 5 ayrı düşmanı ziyaret edip döner. Hedef başına 16 → 30 hasar; aynı hedefe kullanım başına bir isabet. 6 → 4,8 sn bekleme, en fazla 2,4 sn etkinlik. |
| **Dikiş Darbesi** | Son temel saldırı hedefinin doğrultusunda dar bir saplama. 170 → 190 menzil, 45 → 90 hasar, en fazla iki hedef; 4 → 3 sn bekleme. Mermi oluşturmaz. |
| **Kabza Payı** | Toparlanma başladığında en yakın düşmana tek kabza darbesi: 110 menzil, 18 → 36 hasar, 55 → 85 birim itiş. Boss’a itiş uygulanmaz. Çevresel dalga oluşturmaz. |
| **Kırık Yemin** | Dizi başına ilk temel saldırı isabeti hedefi 3 sn işaretler. Aynı hedefe sonraki temel isabette işaret tüketilir: 30 → 70 ek hasar. İşaret yığılmaz, başka hedefe yayılmaz. |

**Son Hüküm**, uzun menzilden otomatik öldürme aracı değildir; yaklaşarak kazanılan bir infaz darbesidir. **Nöbetçi Çelik** de tek boss üzerinde durup sürekli hasar veremez.

### Altı pasif

Yeni sayısal pasifler üretmek yerine ortak pasiflerin karaktere özgü adları kullanılır. Değerler seviye başına toplanmaz; ilgili seviyenin toplam etkisidir.

| Veyra’daki ad | Mevcut karşılık | Seviye 1 → 5 |
|---|---|---|
| **Bilenmiş Ağız** | `agir_kursun` | Hasar +%10 → +%50 |
| **Seri Bilek** | `hizli_parmak` | Saldırı hızı +%8 → +%40 |
| **Uzun Ahit** | `fazladan_mermi` | Dizi kapasitesi +1 → +5 |
| **Sakin Tutuş** | `hizli_doldurma` | Toparlanma süresi −%10 → −%50 |
| **Hafif Adım** | `cevik_cizme` | Hareket hızı +%6 → +%30 |
| **Yas Zırhı** | `saglam_yelek` | Can +15 → +75; yenilenme 0,25 → 1,25/sn |

Bunlar önerilen altı pasiflik yapıdır. Mevcut ortak havuzdaki **Mıknatıs erişilebilir kalır**; altı pasif yuva sınırıyla yarışır. Yalnız altı pasifi seçilebilir yapmak, mevcut “sayısal artışlar ortak” kuralını değiştirmeyi gerektirir.

### Dört evrim çifti

Mevcut şemaya uygun koşul: **aktif seviye 5 + ilgili pasif en az seviye 1**. Evrim aynı aktif yuvayı devralır.

| Çift | Evrim ve sonuç |
|---|---|
| Son Hüküm + Bilenmiş Ağız | **Kesin Hüküm:** 260 doğrudan hasar; hedefin canı %30 altındaysa 80 ek hasar. Yarıçap 60’ta kalır. Boss’a ek hasar yok. |
| Nöbetçi Çelik + Seri Bilek | **Son Nöbet:** Tek kılıç altı farklı hedefi 36’şar hasarla ziyaret eder; 4,2 sn bekleme. Boss’a kullanım başına hâlâ tek isabet. |
| Dikiş Darbesi + Uzun Ahit | **Çifte Dikiş:** Aynı doğrultuda 0,12 sn arayla iki saplama; her biri 70 hasar. Menzil 190’da kalır; ikinci darbe hedefi yeniden takip etmez. |
| Kabza Payı + Sakin Tutuş | **Açılan Gedik:** En yakın iki ayrı düşmana 50’şer hasar ve 95 birim itiş. Bir hedefe iki kez vurmaz; boss itiş bağışıklığını korur. |

### Mevcut havuzdan ayrım

- **Gunslinger:** Seken mermi, parçalanma, ölüm patlaması ve doldurma salvoları yerine kısa mesafede hedefe bağlı kesikler. Kırık Yemin öldürme zinciri başlatmaz.
- **Zyfen’in Girdap’ı:** Sürekli çevresel hasar ve geri itiş sağlar. Nöbetçi Çelik’in boşta dönüşü hasarsızdır; hasar yalnız belirli hedef ziyaretlerinde gerçekleşir.
- **Hortum/Tufan:** Kalabalığı toplayan, dolaşan alanlar kurar. Nöbetçi Çelik çekmez, alan bırakmaz, uzaktaki kümeyi kovalamaz.
- **Göğün Mızrağı:** Art arda delici saldırılar üretir. Son Hüküm tek düşüş, kısa erişim ve önceden yakın dövüş isabeti ister.
- **Nefes Dalgası:** Toparlanırken çevreyi iter. Kabza Payı yalnız tek tehdide müdahale eder.

**Dayanak:** [Girdap](data/skills/girdap.json), [Hortum](data/skills/hortum.json), [Göğün Mızrağı](data/skills/gogun_mizragi.json), [Nefes Dalgası](data/skills/nefes_dalgasi.json), [havuz testleri](test/unit/test_v202_pool_real.gd).

## 4. Denge niyeti ve sim botu

**Ödül:** Kısa saldırı penceresinde birkaç düşmana güçlü hasar, yakın mesafeden kazanılan infaz ve hareketli savunma.

**Bedel:** Toparlanırken temel hasarın kesilmesi, çevrelenme, boss’a yaklaşma zorunluluğu. Kalıcı hasar azaltma, can çalma veya dokunulmazlık önerilmiyor.

Ahit Kesiği’nin seviye 1’de kesintisiz döngü DPS’si, kullanılan zamanlama hesabına göre yaklaşık **40–46 tek hedef hasarı/sn** olur. Gerçek değer menzilde geçirilen süre ve ıskalarla düşer; üç hedefe vurma avantajı ayrıca ölçülmelidir.

**Bot politikası gerekli:** Mevcut `strong`, 260 birim içinde tehdit görünce uzaklaşır. Bu, 135 menzilli karakterin temel saldırısını sistematik olarak bastırır.

Önerilen `melee` politikası:

1. Erişilebilir, grubun kenarındaki hedefe yaklaşır.
2. Kapasite varken yaklaşık 105–130 birim mesafede kalmaya çalışır.
3. Toparlanırken 180–220 birime açılır.
4. Kuşatılınca açık sektöre çıkar; duvar dolanmayı korur.
5. Yalnız oyuncunun erişebildiği hareket ve görünür durum bilgisini kullanır.

Eski `strong/kite` sonuçları da raporlanır; bunlar uzak durma davranışındaki performansı gösterir.

**Ölçüm planı:** Aynı tohumlarla `kills5`, `hp_early`, erken ölüm oranı; ayrıca saldırı menzilinde geçirilen süre, boşa savuruş, verilen hasar başına alınan hasar, toparlanmada alınan hasar ve boss öldürme süresi. `hp_early` yaşayan örneklerden hesaplandığı için ölüm oranından ayrı yorumlanmaz.

Yeni karakterin kart öncelikleri `PRIORITY_BY_CHAR` içine eklenmeli; aksi halde Gunslinger önceliklerine düşüyor. Yoğunluk DPS ve Lord bütçesi ölçümleri de yapılmalı. Gunslinger’ın mevcut politikalarla `kills5/hp_early` farkı **±%5 içinde** tutulmalı. Bot başarısı, telefondaki yakın dövüş rahatlığının yerine geçmez.

**Dayanak:** [Botlar](test/helpers/bots.gd), [orta oyun ölçümü](tools/balance/mid_run.gd), [denge hattı](.claude/skills/ab-denge-olcumu/SKILL.md).

## 5. Görsel ve animasyon brifi

**Silüet:** Kısa, iki parçalı yas ceketi; belirgin çizmeler; gövdeden ayrılan tek uzun kılıç. Saç ense hizasında toplu. Uzun palto ve geniş büyücü silüetinden ayrılır. Kadın kimliği duruş, yüz ve oranlarla okunur; zırh hareketi destekler.

**Palet:** Kömür siyahı `#252326`, solmuş bordo `#653D43`, kirli kemik `#C8BEA9`, mat çelik `#92918B`. Büyü izlerinde çok az sönük amber. Zyfen’in yeşilimsi beyaz rüzgâr dilini kullanmaz.

**Ölçülü gösteriş:**

- Gök kılıcı: küçük zemin işareti, tek ince düşüş izi, kısa toz ve tok metal sesi.
- Süzülen kılıç: okunur tek silah ve kısa hareket izi; kalıcı ışıklı halka yok.
- Temel kesik: temas anında kısa çelik yayı; ekran sarsıntısı rutin saldırıda kullanılmaz.
- Hareket azaltma ayarında art izler kapanır; hedef işareti korunur.

**Şerit planı:** Tek parça gövde; 8 yürüme + 1 duruş + 6 saldırı + 4 toparlanma = **19 hücre**. Saldırı 24 fps, sıfır tabanlı `fire_frame: 3`; temas animasyonla eşleşir.

Hareket ederken de saldırdığı için `walk_cast` gerekebilir. Altı ek hücreyle 25 hücre oluşur; 320 px hücre genişliğinde şerit 8000 px olur. Kılıç daha geniş hücre gerektirirse 8192 sınırı aşılır. Bu yüzden ilk üretim kontrolü, **kılıç pozunun hücre genişliği ve hareketli saldırı okunurluğu** olmalıdır.

Üretim yolu: duruş referansı → sabit kameralı, sağa bakan yeşil zemin videoları → ffmpeg ile kare seçimi → yeşil silme → şerit ve manifest. Kare kare bağımsız görsel üretimi önerilmiyor. Ayak kayması, klip boy farkı ve kıyafet tutarlılığı kalite kapısından geçmeli.

**Dayanak:** [ab-animasyon-seridi](.claude/skills/ab-animasyon-seridi/SKILL.md), [ab-karakter-ekle](.claude/skills/ab-karakter-ekle/SKILL.md).

## 6. Maliyet ve risk

**Toplam kapsam: orta-yüksek.** Karakter seçimine veri eklemek hazır bir hat; gerçek yakın dövüş isabeti, hedef geçmişi, gezici kılıç ve bot davranışı ayrıca çalışma gerektirir.

| İş | Maliyet / temel risk |
|---|---|
| Karakter verisi, ortak pasif adları | Düşük; mevcut şema ve variant yapısı kullanılabilir. |
| Altı aktif, dört evrim | Yüksek; yeni davranışlar ve deterministik hedef sırası gerekir. |
| Yakın dövüş ve duvar kontrolü | Orta-yüksek; görüntüde temas ile sim isabeti örtüşmeli. |
| Animasyon | Orta-yüksek; kılıç genişliği, aynalama ve hareketli saldırı ana riskler. |
| Bot ve denge | Orta; uzak mesafe politikası korunarak yenisi eklenmeli. |
| Görsel/ses varlıkları | Portre, gövde/şerit, 10 aktif/evrim ikonu, pasif varyantları ve kısa ses seti. |

**İlk doğrulanacak parça:** Ahit Kesiği + dört kesiklik ritim + hareketli saldırı. Bunlar tatmin edici olmadan tüm havuzun üretimine geçilmemeli.

`ab-karakter-ekle` hattında görseller, beceri havuzu ve import hazırlandıktan sonra karakter JSON’u bağlanır. Veri doğrulaması, rig manifest/kalite kapıları, deterministik tekrarlar ve karakter ekranı kontrolü gerekir.

**F-ashen-bastion-060 kapsamındaki karakter listesi testleri:** Kimliğin tam metnini okunan dosyalarda bulamadım; brifteki bulguyla örtüşen dört sabit varsayımı doğruladım:

- [test_character_roster.gd](test/unit/test_character_roster.gd): `test_ids_follow_order_field` iki kimlik bekliyor.
- [test_characters_screen.gd](test/unit/test_characters_screen.gd): `test_f030_gunslinger_first_by_order_field` yeni sıralamayla gözden geçirilmeli.
- [test_acc_v2_chars.gd](test/acceptance/test_acc_v2_chars.gd): `test_k10_single_character_set_works`, yalnız Zyfen’i silerek tek karakter kaldığını varsayıyor. Test gerçekten tek karakterli veri kurmalı.
- [test_v202_pool_real.gd](test/unit/test_v202_pool_real.gd): filtresiz havuz beklentileri altı aktif ve dört evrim artışını kapsamalı.

Yeni karakterin altın hash kayıtları eklenmeli; Gunslinger kayıtları değişmemeli. Bu belge fazında test çalıştırılmadı.

## 7. Kullanıcıya açık sorular

1. **Veyra ve Son Ahit teması** uygun mu; yoksa daha dünyevi bir düellocu kimliği mi tercih edersin?
2. **Gökten düşen kılıcın yakın dövüşle hazırlanması** hoşuna gider mi, yoksa bağımsız çalışması mı önemli?
3. **Süzülen kılıcın kısa nöbetler halinde çalışması** yeterli mi; yanında sürekli görünmesini ister misin? Sürekli görünmesi, sürekli hasar vermesinden ayrı tutulabilir.
4. Çeviklik hissi için **hızlı ayak çalışması ve toparlanma hızlanması** yeterli mi; gerçek otomatik atılma bekliyor musun?
5. **Dört kesiklik kısa ritim** ve grubun kenarında savaşma fikri mi, daha uzun kombo dizileri mi sana yakın?
6. Görsel yönde **kısa yas ceketi ve hafif zırh** mı, daha törensel bir kıyafet mi tercih edersin?