# Kılıçlı karakter önerisi (Codex)

*27 Ekim 2026 — Bağımsız tasarım önerisi. Sayılar prototip başlangıç değerleridir; ölçülmüş denge sonucu değildir. Dosya değiştirilmedi, kod veya görsel üretilmedi. `docs/design/characters/` okunmadı.*

## 1. Tema, ad ve kısa hikâye

**Ad: Sera, Son Yemin — Sera, the Last Oath**  
**Karakter kimliği:** Kılıç kullanan, çevik bir kadın yakın dövüşçü. Kısa mesafede kararlı darbeler indirir; kılıcını toparlarken düşmanın erişiminden sıyrılır.

Sera, kalenin cenaze muhafızlarından sağ kalan son kişidir. Görevi, ölülerin silahlarını mühürleyip sahipleriyle birlikte gömmekti. Kale düştüğünde mezarlar açıldı, fakat mühürlü kılıçlar sahiplerine dönmedi. Şimdi Sera’nın yanında dolaşan tek bir eski kılıç ve çağrısına yukarıdan cevap veren ağır bir infaz kılıcı vardır. Sera, kalenin ölülerini ikinci kez susturmak için geri döner.

Temanın merkezinde **çelik, yas ve tamamlanmamış görev** bulunur. Büyü, silahların iradesinde görünür; karakterin her hareketini kaplayan bir aura gerekmez. “Barutçu olmayacak” kararı korunur.

Dünyanın gotik harabeleri, koyu paleti ve otomatik saldırı üzerine kurulu tek parmak kontrolüyle uyumludur. Kaynak: [ana tasarım belgesi](docs/design/2026-10-23-ashen-bastion-v1-design.md).

## 2. Oynanış kimliği

**Ana döngü: yaklaş → dört kesiş yap → kılıcı toparlarken sıyrıl → yeniden gir.**

| Başlangıç özelliği | Öneri |
|---|---:|
| Can | 100 |
| Hareket hızı | 330 |
| Çarpışma yarıçapı | 22 |
| Toplama yarıçapı | 110 |
| Temel saldırı erişimi | 125 dünya birimi |
| Seri kapasitesi | 4 kesiş |
| Toparlanma süresi | 0,90 sn |

Karşılaştırma için Gunslinger’ın hızı 300, menzili 700, şarjörü 6 ve doldurması 1 saniye; Zyfen’in hızı 310, menzili 750, kapasitesi 8 ve doldurması 1,3 saniyedir. Sera’nın farkı, hareket üstünlüğü karşılığında çok daha kısa erişimdir. Kaynaklar: [Gunslinger](data/characters/gunslinger.json), [Zyfen](data/characters/zyfen.json).

**Yakın dövüş ve tek parmak kontrolü.** Oyuncu mevcut joystick ile hareket eder; saldırı ve hedef seçimi otomatiktir. En yakın erişilebilir düşmana doğru 100° açıyla kesiş yapılır. Her kesiş aynı düşmana yalnız bir kez vurur; başlangıçta en çok üç hedefi keser. Hedef, savuruş boyunca sabit tutulur; kareler arasında sağa sola dönme önlenir.

125 birimlik erişim, düşmanın içine girmeden kalabalığın kenarını kesmeye izin verir. Arkadan gelen düşmanlar saldırı yayının dışında kaldığı için çevrelenmek tehlikelidir. Hedef yokken seri harcanmaz. Savuruş başladıktan sonra düşman uzaklaşırsa kesiş boşa gidebilir; bu nedenle kısa hazırlık ve okunur erişim önemlidir.

**Çeviklik.** Yeni kaçış düğmesi, çift dokunma veya kaydırma hareketi eklenmez. Seri bitip toparlanma başladığında, mevcut joystick yönünde **0,22 saniyelik +%30 hız** verilir. Parmak kalkmışsa karakter kendiliğinden yer değiştirmez. Bu küçük hızlanma, alçalan gövde ve kısa kılıç iziyle atılma hissi verir. Çarpışma kuralları geçerlidir; düşman veya duvar içinden geçiş ve genel dokunulmazlık yoktur.

**Şarjör karşılığı: “Kesiş serisi”.** Dört HUD işareti her temel saldırıda azalır. Boşalınca Sera kılıcı gövdesine çeker, tutuşunu düzeltir; temel saldırı 0,90 saniye durur. Hareket devam eder. Yan yetenekler kendi kurallarına göre çalışabilir.

Ek kapasite, daha uzun saldırı penceresi sağlar fakat toparlanmaya bağlı etkileri seyrekleştirir. Böylece kapasite ile hızlı toparlanma farklı yapı tercihleri olur. Hareket ederken saldırı zorunlu bir tasarım koşuludur; bu, Zyfen’in mevcut `action_while_moving: false` ayarından ayrılır.

## 3. Yetenek havuzu ve evrimler

Altı aktif, başlangıç saldırısını da içerir. “Aktif”, otomatik çalışan beceri yuvasıdır; yeni düğme anlamına gelmez. Aktif ve pasifler beş seviyelidir; aşağıdaki **S1 → S5** değerleri başlangıç ve son seviyeyi gösterir.

### Altı aktif

| Aktif | Davranış | Sayı ve ölçek önerisi |
|---|---|---|
| **1. Yemin Kesişi** | Başlangıç saldırısı. Yakındaki hedefe kısa, fiziksel kılıç yayı. | Hasar **24 → 42**; aralık **0,30 → 0,24 sn**; erişim **125 → 140**; hedef sınırı **3 → 5**. Her kesiş bir seri işareti tüketir. |
| **2. Son Hüküm** | **Gökten düşen kılıç.** Son 2 sn içinde temel saldırıyla yaralanmış, 220 birim içindeki düşmanlardan mevcut canı en yüksek olana tek kılıç iner. | Bekleme **8 → 5,5 sn**; merkez hasarı **100 → 220**; çevre yarıçapı **45 → 65**, çevre hasarı merkez değerinin %35’i. Merkez hedef iki kez hasar almaz. |
| **3. Yoldaş Çelik** | **Süzülen kılıç.** Beklerken omuz çevresinde yavaşça döner; saldırıda yakın düşmanlara sırayla gider ve geri döner. | Sefer aralığı **3 → 2 sn**; **2 → 4 farklı hedef**; vuruş **16 → 30**; oyuncudan uzaklık sınırı **180 → 220**. Her seferde aynı hedefe en çok bir vuruş. |
| **4. Son Çentik** | Serinin son temel kesişini ağırlaştırır; ön tarafta dar bir bitiriş darbesi verir. | Son kesişe **+20 → +55** hasar; isabet alan sıradan düşmanlara **18 → 30 birim** itme. Elit ve boss itilmez. Patlama üretmez. |
| **5. Çelik Siper** | Toparlanma başında kısa bir savunma penceresi açar. Bu sıradaki ilk temas darbesini azaltıp saldırgana karşılık verir. | Pencere **0,20 → 0,30 sn**; o darbenin hasarında **%30 → %50** azalma; karşılık **20 → 50** hasar. Döngü başına bir kez, en fazla 140 erişim. |
| **6. Açık Dikiş** | Temel kılıç isabeti hedefte tek bir yara açar. Tekrar vuruş yarayı yeniler; sınırsız yığın oluşturmaz. | **2 sn boyunca toplam 10 → 26** hasar; 0,5 sn aralıklı tikler. Yardımcı kılıçlar ve yara tikleri yeni yara açmaz. |

**Son Hüküm’ün infaz hissi:** Önce 0,35 saniyelik ince bir hedef çizgisi belirir; sonra tek ağır kılıç düşer. İşaretlenen konum sabit kalır, böylece hareketli hedef kaçabilir. Uygun hedef yoksa beceri hazır bekler. Boss üzerinde yüzde can silme veya otomatik öldürme uygulanmaz. Gücü, Sera’nın önce yakına girerek hazırladığı darbeyi tamamlamasından gelir.

**Yoldaş Çelik’in hedef kuralı:** En yakından başlayıp ziyaret edilmemiş hedeflere gider; eşitlikte sabit hedef kimliği kullanılır. Yörüngede beklerken ve dönüşte hasar vermez. Aynı anda yalnız bir sefer vardır; önceki kılıç dönmediyse yenisi doğmaz.

### Altı pasif

Ortak pasiflerin mevcut değerleri korunur; Sera’ya özel ad, açıklama ve ikon varyantları kullanılır.

| Sera’daki ad | Mevcut veri kimliği | S1 → S5 |
|---|---|---|
| **Bilenmiş Ağız** | `agir_kursun` | Kılıç kaynaklı hasar **+%10 → +%50** |
| **Seri Bilek** | `hizli_parmak` | Temel saldırı hızı **+%8 → +%40** |
| **Uzun Talim** | `fazladan_mermi` | Seri kapasitesi **+1 → +5 kesiş** |
| **Dingin Tutuş** | `hizli_doldurma` | Toparlanma süresi **−%10 → −%50** |
| **Hafif Adım** | `cevik_cizme` | Hareket hızı **+%6 → +%30** |
| **Yas Zırhı** | `saglam_yelek` | Can **+15 → +75**, yenilenme **0,25 → 1,25/sn** |

`Bilenmiş Ağız` yeni kılıç davranışlarında hasara bir kez uygulanmalıdır; yaraya veya evrim darbesine aktarılırken ikinci kez çarpılmamalıdır.

**Havuz kararı:** Mevcut ortak havuzda yedi pasif bulunuyor. Bu önerinin tam altı pasif olması için `miknatis` Sera’nın seçimlerinden çıkarılmalıdır. Mevcut `pool: common` davranışı bunu kendiliğinden sağlamaz; karaktere göre izin listesi ayrı uygulama maliyetidir. Kaynak: [gerçek havuz testleri](test/unit/test_v202_pool_real.gd).

### Dört evrim çifti

Mevcut eşleşme biçimi korunur: **aktif S5 + ilgili pasif en az S1**. Evrim, aktif yuvasındaki eski becerinin yerini alır.

| Çift | Evrim | Davranış değişikliği |
|---|---|---|
| Son Hüküm + Bilenmiş Ağız | **Kesin Hüküm** | Tek kılıç korunur. Merkez hasarı 330 olur; hedef canı %30’un altındaysa ×1,5. Çevre yarıçapı büyümez. |
| Yoldaş Çelik + Seri Bilek | **Sadık Çelik** | Dört farklı hedefe 42’şer hasar verir; ardından yaşayan ziyaret edilmiş hedeflerden canı en düşük olana tek 60 hasarlık bitiriş yapar. Hâlâ tek kılıçtır. |
| Son Çentik + Uzun Talim | **Son Nokta** | Son kesişteki +55 yerine +90 hasar; ana hedefe 0,12 sn sonra, hâlâ erişimdeyse 60 hasarlık ikinci kesiş. İkinci darbe seri tüketmez ve kendini tetiklemez. |
| Çelik Siper + Dingin Tutuş | **Demir Sükûnet** | İlk temas darbesinde azaltma %65’e, karşılık 100 hasara çıkar. Pencere 0,30 sn kalır; yalnız saldırgana vurur. |

### Mevcut karakterlerden ayrım

**Gunslinger:** Uzakta kalırken ateş, sekme ve patlamalarla verim üretir. Sera’nın hasar fırsatı kısa erişime girerek açılır. Son Çentik, son mermi ritmini paylaşır fakat etkisi dar bir fiziksel kesiştir; alan patlamasına dönüşmez.

**Zyfen:** Girdap sürekli çevre hasarı ve itme, Hortum/Tufan gezici alan kontrolü, Nefes Dalgası toparlanma anında çevresel itme sağlar. Sera’da:

- Yoldaş Çelik’in **dönüşü görseldir**; hasarı ayrı hedef ziyaretlerinden gelir.
- Çekme, sürekli hasar halkası ve üst üste biriken alanlar bulunmaz.
- Son Hüküm yakın dövüşle hazırlanır; uzaktaki dayanıklı hedefe düzenli mızrak salvosundan ayrılır.
- Çelik Siper yalnız bir saldırgana cevap verir; toparlanma dalgası üretmez.

Bu ayrım renk değişikliğine değil, hedefleme ve hasar dağılımına dayanır. Kaynaklar: [Girdap](data/skills/girdap.json), [Hortum](data/skills/hortum.json), [Nefes Dalgası](data/skills/nefes_dalgasi.json), [Göğün Mızrağı](data/skills/gogun_mizragi.json), [davranış sözleşmesi](docs/design/v2.0.2/behavior-contract.md).

## 4. Denge niyeti ve sim ölçümü

**Ödül:** Yakındaki birkaç hedefe güçlü kesiş, hızlı hedef bitirme ve öldürülen düşmanın XP’sine yakın bulunma.  
**Risk:** Arkadan kuşatılma, toparlanırken temel saldırının kesilmesi ve erişim dışına çıkan hedefe boşa savurma.

Koruma, sürekli hasar azaltmaya dönüşmemelidir. Çelik Siper olmadan da başlangıç karakteri oynanabilir olmalıdır; savunma kartı yaşamak için zorunlu seçim haline gelirse önce temel erişim ve saldırı hazırlığı gözden geçirilmelidir.

**Yeni bot politikası gerekir.** Mevcut `kite`, 350 birim içindeki tehditlerden uzaklaşır. Bu politika, 125 birimlik kılıcı kullanamadan hayatta kalmaya çalışabilir. Kaynak: [bots.gd](test/helpers/bots.gd).

Önerilen yakın dövüş politikası:

1. Erişilebilir hedefe, yaklaşık **95–115 birimlik saldırı bandına** yaklaşır.
2. Seri devam ederken düşman çevresinde teğet hareket eder; temas mesafesine girmez.
3. Toparlanırken açık yöne çekilir; seri dolunca yeniden yaklaşır.
4. Düşük can veya kuşatılmada saldırı isteğini azaltır; güvenli XP’yi toplar.
5. Hedef seçimi sabit kurallarla yapılır; gelecek doğuşları veya gizli bilgiyi kullanmaz.

`kite` sonuçları da raporlanır, fakat yeni karakter için tek denge hükmü sayılmaz. Kart seçme öncelikleri Sera’nın evrimlerini tamamlayacak şekilde ayrıca tanımlanır.

| Ölçüm | Amaç |
|---|---|
| Saldırı erişiminde geçirilen süre ve boşa kesiş oranı | Botun karakteri gerçekten kullanabildiğini görmek |
| Seri/toparlanma başına alınan hasar | Riskin hangi aşamada oluştuğunu ayırmak |
| Temel kesiş, yara ve yardımcı kılıçların hasar payı | Yakın dövüş kimliğinin korunması |
| Tek hedef ile 10/50/200 düşman yoğunluğu | Hedef sınırlarının ve evrim kazancının kontrolü |
| `kills5`, `hp_early`, 10. dakikaya erişim, ölüm nedeni | Erken güç ile sonraki hayatta kalmayı birlikte okumak |
| Lord’a hasar/dakika | İnfaz temasının boss’u aşırı kolaylaştırmaması |

İlk hipotez: eşit seviyede, erişim içindeki tek hedefe temel saldırı verimi Gunslinger’dan yaklaşık **%15–30 yüksek** olabilir; yaklaşma ve kaçış süreleri gerçek koşu üstünlüğünü azaltmalıdır. Evrimler kendi S5 tabanlarına göre kontrollü koşullarda yaklaşık **1,5–2 kat katkı** hedefler. Bunlar kabul edilmiş eşikler değildir.

Aynı tohumlarla önce/sonra ölçüm yapılır. Gunslinger regresyonu için mevcut **`kills5` ve `hp_early` ±%5** yaklaşımı korunur; geniş belirsizlik “denge sağlandı” diye yorumlanmaz. Mevcut raporlar hayatta kalma ölçümünün 400 tohumda bile gürültülü olabildiğini gösteriyor. Kaynaklar: [denge raporu](docs/design/v2.0.2/balance/d-verification.md), [yoğunluk ölçümleri](docs/design/v2.0.2/balance/d-dps-density.md).

## 5. Görsel ve animasyon brifi

**Silüet:** Bağlı koyu saç, kısa asimetrik omuz örtüsü, belden ayrılan iki dar kumaş parçası, görünür diz ve ayak hareketleri. Tek uzun kılıç aşağı çapraz tutulur; yardımcı kılıç omuz gerisinde ikinci, küçük bir çizgi oluşturur. Ağır etek ve uzun pelerin çeviklik hissini kapatmamalıdır.

**Palet:** Kömür siyahı `#242329`, kül grisi `#77757B`, kemik beyazı `#D8D0BE`, soluk bordo `#643C47`; metalde sınırlı mat gümüş. Amber yalnız küçük mühür ayrıntısında kullanılır.

**Ölçülü gösteriş:**

- Temel saldırıda tek ince kesiş izi; yaklaşık 0,10–0,15 sn.
- Son Hüküm’de bir düşüş çizgisi, tek metal darbesi ve kısa toz kalkışı.
- Yoldaş Çelik’te yalnız hareket sırasında dar iz; kalıcı parlak halka yok.
- Evrimde kılıç sayısını ve ekran kaplamasını büyütmek yerine darbenin zamanlaması belirginleşir.
- Hareket azaltma ayarında sallantı ve art izleri kapanabilir; hedef işareti ve isabet okunurluğu kalır.

**`ab-animasyon-seridi` üretim planı:** Tek parça gövde, `rig.armless: true`; yürüme 8, duruş 1, kesiş 6, toparlanma 4 kare: **19 hücrelik temel şerit**. Kesiş başlangıcı için 24 fps ve sıfır tabanlı `fire_frame: 3` uygun ilk denemedir.

Hareket sırasında kesişin bacakları dondurması kabul edilmez. Gerekirse isteğe bağlı `walk_cast` klibi eklenir; altı kareyle toplam 25 hücre olur. Bu seçenekte 8192 piksel sınırı hücre genişliğini en fazla yaklaşık 327 piksele indirir. Uzun kılıç savuruşu bu nedenle üretimin kritik riskidir; geniş kesiş izi ayrı efekt olmalıdır.

Kareler **video → ffmpeg → yeşil temizleme → şerit** hattından gelir. Hücre yüksekliği 320, görüntü yüksekliği için başlangıç 200; genişlik ve adım mesafesi manifest ölçümünden alınır. Ayak kayması, klip boy sapması, aynalama ve kılıç-el tutarlılığı denetlenir. Yukarıdan inen ve süzülen kılıçlar gövde şeridinden ayrı varlıklardır.

Kaynaklar: [animasyon becerisi](.claude/skills/ab-animasyon-seridi/SKILL.md), [yeni karakter hattı](docs/dev/new-character.md). Bu fazda üretim yapılmaz.

## 6. Maliyet ve risk

**Genel maliyet: orta–yüksek.** Karakterin listeye eklenmesi veriyle çözülebilir; yakın dövüş davranışı yalnız JSON ekleyerek tamamlanmaz.

| İş | Maliyet / temel risk |
|---|---|
| Kısa menzilli kesiş ve hareket sırasında saldırı | Yüksek: hedef seçimi, savuruş geometrisi, tek vuruş garantisi, animasyon eşleşmesi |
| İki yardımcı kılıç | Orta: hedefin ölmesi, menzil dışına çıkması, seferin tamamlanması ve yeniden tetikleme |
| Seri ve toparlanma | Orta: mevcut şarjör olayları kullanılabilir; hız penceresi ve temas karşılığı yeni davranıştır |
| Altılı pasif havuzu | Orta: ortak pasifleri karakter bazında filtrelemek gerekir |
| Görsel üretim | Orta–yüksek: uzun kılıcın şerit genişliği ve hareketli saldırı tutarlılığı |
| Denge ve bot | Yüksek: mevcut uzak mesafe politikası yeterli değildir |

`ab-karakter-ekle` sırası izlenir: tasarımın ardından görseller ve beceri referansları hazırlanır; karakter JSON’u eksik varlıklarla erken bağlanmaz. Portre, şerit, manifest, kalite raporu, ikonlar, metal darbe/toparlanma sesleri ve karaktere ait doğrulama listesi gerekir. Yeni sim durumları deterministik hash kapsamına alınır; mevcut Gunslinger kayıtları korunur.

**F-ashen-bastion-060 kapsamındaki karakter listesi riski:** Kimliğin tam metni taranan dosyalarda bulunamadı; ancak kullanıcı brifindeki risk, karakter ekleme becerisinde belirtilen ve testlerde görülen şu dört varsayımla örtüşüyor:

| Dosya / test | Gerekli düzeltme niyeti |
|---|---|
| [test_character_roster.gd](test/unit/test_character_roster.gd) — `test_ids_follow_order_field` | İki karakterlik sabit listeye yeni karakteri `order: 3` ile eklemek |
| [test_characters_screen.gd](test/unit/test_characters_screen.gd) — `test_f030_gunslinger_first_by_order_field` | Liste beklentisini genişletirken Gunslinger’ın ilk olmasını korumak |
| [test_acc_v2_chars.gd](test/acceptance/test_acc_v2_chars.gd) — `test_k10_single_character_set_works` | Yalnız Zyfen’i silmek yerine gerçekten tek karakterli veri kümesi oluşturmak |
| [test_v202_pool_real.gd](test/unit/test_v202_pool_real.gd) — `test_empty_character_id_keeps_old_unfiltered_behavior` | Altı yeni aktif ve dört evrimin filtresiz toplamlarını hesaba katmak |

Tek karakter testinin beklenen sayısını üçe çıkarmak doğru çözüm değildir; testin tek karakter senaryosu korunmalıdır.

Uygulama fazında ayrıca havuz sızıntısı, evrim yer değiştirmesi, çoklu isabet, boss itme bağışıklığı, duraklatmada zamanlayıcıların durması, deterministik hedef sırası ve kalabalık performansı doğrulanır. Sonrasında veri doğrulaması, yürüyüş kalite kapısı ve `tools/gate.sh` çalıştırılır. **Bu belge fazında test çalıştırılmadı.**

Kaynak: [ab-karakter-ekle](.claude/skills/ab-karakter-ekle/SKILL.md).

## 7. Kullanıcıya açık sorular

1. **Sera’nın tonu:** Sessiz cenaze muhafızı fikri uygun mu, daha saldırgan bir düellocu mu tercih edersin?
2. **Süzülen kılıç:** Öneride tek kılıç sürekli görünür, fakat yalnız hedef ziyaretlerinde hasar verir. Beklerken görünmesi mi, saldırı anında belirmesi mi daha iyi?
3. **Gökten düşen kılıç:** Önce yakın dövüşle yaralanmış hedefe inmesi hoşuna gider mi, bağımsız hedef seçmesini mi istersin?
4. **Çeviklik:** Joystick yönünde kısa hızlanma yeterli mi, daha belirgin fiziksel atılma hissi mi arıyorsun?
5. **Erişim:** Karakter başlangıçtan açık mı olsun, mevcut bir başarım üzerinden mi açılsın?

Bu tercihler gelene kadar önerinin varsayımı: **sessiz muhafız teması, görünür tek yardımcı kılıç, yakın dövüşle hazırlanan infaz ve başlangıçtan açık karakter.**