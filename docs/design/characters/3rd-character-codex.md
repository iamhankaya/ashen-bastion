# 3. karakter önerisi (Codex)

## 1. Tema, ad ve kısa hikâye

**Öneri: Ahdar, Mezar Mühürcüsü — Ahdar, the Grave Sealer**  
Veri kimliği önerisi: `ahdar`.

Ahdar, kale mezarlığının son mühürcüsüdür. Kuşatma gecesi ölülerin kapıları içeriden açmasını engellemek için bütün mezarları kendi kanıyla mühürlemiştir. Kale düştüğünde mühürler kırılmış, taşıdığı mezar levhasına gömdüğü insanların adları kazınmıştır. Şimdi kaleye dönerek her adı yeniden yerine bağlar; kendi adı için bıraktığı boşluk giderek daralmaktadır.

Karakterin ana vaadi: **Oyuncu savaş alanına bir rota yazar, sonra o rotayı tamamlayarak gücünü açığa çıkarır.** Böylece karakter seçimi, düşmanlardan kaçarken verilen hareket kararlarını değiştirir.

Karanlık fantastik dil; aşınmış taş, cenaze demiri, balmumu ve kül üzerinden kurulur. Silahı, iki eliyle taşıdığı kısa ve ağır bir mühür levhasıdır.

Dünya ve mevcut karakter tonu için dayanak: [Zyfen tasarımı](docs/design/v2.0.2/2026-10-24-zyfen-design.md).

## 2. Oynanış kimliği

**Kimlik: sabit alanlar kuran, geri dönüş rotası planlayan orta menzilli mühürcü.**

| Karakter | Temel hareket kararı |
|---|---|
| Gunslinger | Ateş ederken güvenli mesafeyi korumak; şarjör döngüsünü değerlendirmek |
| Zyfen | Delici kesikleri ve geniş alan etkilerini düşman yoğunluğuna taşımak |
| Ahdar | Bıraktığı mühre geri dönmekle güvenli kaçış arasında karar vermek |

Mevcut sayısal temel: Gunslinger 100 can, 300 hız, 6 atış ve 1 saniye doldurma; Zyfen 85 can, 310 hız, 8 kesik ve 1,3 saniye toplama kullanıyor. Kaynaklar: [Gunslinger](data/characters/gunslinger.json), [Zyfen](data/characters/zyfen.json).

**Temel saldırı — Kabir Damgası:** En yakın geçerli hedefin altına kısa hazırlık göstergesinden sonra bir mühür vurur. Hedef hazırlık sırasında yer değiştirirse damga eski konumda kalır. Küçük alan hasarı verir; mermi uçuşu, sekme veya delme kullanmaz. Hazırlık yaklaşık 0,2 saniyedir; oyuncunun hareketi kesilmez.

**Şarjör karşılığı — Ahit:** Her saldırı bir ahit harcar. Döngünün ilk saldırısı, oyuncunun o anki konumuna bir **dönüş mührü** bırakır. Ahit bitince yaklaşık 1,2 saniyelik **yeniden bağlama** başlar; bu sırada hareket serbest, temel saldırı kapalıdır.

Yeniden bağlama sırasında dönüş mührüne yaklaşmak, döngü başına bir kez mühür çevresinde **Kapanış** darbesi oluşturur. Süre bitince kapasite her durumda dolar; mühre dönmek zorunlu değildir. Dönüş mührü o döngü sonunda silinir. Böylece sıkışan oyuncu ödülü bırakıp kaçabilir.

Başlangıç denemesi için: **95 can, 295 hız, 5 ahit, 1,2 saniye bağlama, 500 menzil**; toplama ve çarpışma yarıçapları mevcut karakterlerle aynı. Bunlar ölçülmemiş tasarım değerleridir.

**Tek parmak, dikey ekran:** Yerleştirme düğmesi, çizim hareketi veya ikinci nişan kontrolü yoktur. Saldırı otomatik; dönüş mührü hareketle kullanılır. Mühür, bağlama başladığında belirginleşir; kalan pencere çevresindeki yayla gösterilir. Ekran dışındaki mühre dönme zorunluluğu oluşturulmaz.

**Ortak pasiflerle ilişki:** Kapasite artışı daha uzun saldırı evresi, hızlı doldurma daha kısa savunmasızlık fakat daha dar dönüş penceresi verir. Kapanış hasarı harcanan ahit sayısıyla ölçeklenir; böylece kapasite yükseltmesi yalnızca ödülü geciktirmez.

**Sonsuz Tambur:** Sınırsız temel saldırı sürer; gerçek bağlama başlamadığı için Kapanış tetiklenmez. Pickup bitince dönüş mührü yeni normal döngüde kurulur. Bu tercih, mevcut Nefes Dalgası’nın Sonsuz Tambur sırasında tetiklenmemesiyle tutarlıdır: [davranış sözleşmesi](docs/design/v2.0.2/behavior-contract.md).

## 3. Yetenek havuzu ve evrim çiftleri

Aşağıdaki **6 aktif temel saldırıyı da içerir**: bir başlangıç becerisi ve beş seçilebilir ek aktif. Aktifler ve evrimler `pool: ahdar` olur.

| Aktif | Davranış ve koşuya etkisi |
|---|---|
| **Kabir Damgası** | Başlangıç saldırısı. Seviyeleri hasarı ve küçük damganın alanını artırır; mühre geri dönme kimliğini ilk dakikadan verir. |
| **Mezar Dikişi** | Belirli aralıklarla mevcut konumla dönüş mührü arasında kısa ömürlü bir dikiş açar. Çizgiyi geçen düşman bir kez hasar alır. Oyuncu düşmanları hattın üzerinden geçirmeye çalışır. |
| **Nöbet Taşı** | Periyodik olarak oyuncunun bulunduğu yere sabit taş bırakır. Yaklaşan ilk düşmana kısa gecikmeli tek darbe vurup söner; aynı anda en fazla iki taş. Hareket rotası pusu yerleşimine dönüşür. |
| **Suskun Hüküm** | Damgayla vurulan bir hedefi kısa süre işaretler. Süre sonunda yalnız Ahdar’ın o hedefe verdiği hasarın sınırlı bölümünü tekrar uygular. Tek hedefe odaklanmayı ödüllendirir. |
| **Son Eşik** | Bağlama başında oyuncunun konumunda kısa bir eşik bırakır. Eşiği geçen sıradan düşmanlar kısa süre yavaşlar; hasar ve itme yoktur. Dönüş yolunu hazırlamak için kullanılır. |
| **Yas Yolu** | Yeterli hareket mesafesinden sonra arkada kısa ömürlü, kesintili bir iz bırakır. Her düşman aynı iz parçasından yalnız bir kez hasar alır. Uzun yaylar çizerek geri çekilmeyi destekler. |

**Altı pasif önerisi**, mevcut “değer artıranlar ortak, ekranda bir şey yapanlar karaktere özel” kuralını korur:

| Pasif | Etki | Havuz yaklaşımı |
|---|---|---|
| **Ağır Ahit** | Genel hasar artışı | Mevcut `agir_kursun` için karakter adı/ikonu |
| **Kısa Dua** | Bağlama süresi azalır | Mevcut `hizli_doldurma` karşılığı |
| **Ek Satır** | Ahit kapasitesi artar | Mevcut `fazladan_mermi` karşılığı |
| **Cenaze Adımı** | Hareket hızı artar | Mevcut `cevik_cizme` karşılığı |
| **Derin Oyuk** | Kalıcı mühür etkilerinin süresi artar; eşzamanlı nesne sınırı artmaz | Yeni ortak sayısal pasif; diğer karakterlere anlamlı karşılık gerekir |
| **Merhamet Payı** | Kapanış başarıyla tamamlanınca kısa süreli, birikmeyen küçük hasar azaltımı | Ahdar’a özel; yeni görsel durum geri bildirimi |

İlk dört pasif yeni veri kopyaları oluşturmaz. Mevcut ortak can, toplama ve saldırı hızı pasifleri de havuzda kalır. **Derin Oyuk**, diğer karakterlere ve teklif sıklıklarına etkisi nedeniyle ayrı denge maliyeti taşır.

**Evrim koşulu:** İlgili aktif seviye 5, pasif en az seviye 1. Evrim, kaynak aktifin davranışını devralır; kaynakla üst üste çalışarak iki kez hasar üretmez.

| Aktif + pasif | Evrim | Karar değişikliği |
|---|---|---|
| Mezar Dikişi + Ek Satır | **Lahit Kapısı** | İnce çizgi, aralıklı kapanan geniş bir şeride dönüşür. Oyuncu paralel kaçış yolları kurar. |
| Nöbet Taşı + Derin Oyuk | **Sessiz Mahkeme** | İki taş sırayla hüküm verir; taşlardan birinin tetiklenmesi diğerini kısa süre hazırlar. Aralarında düşman taşıma önem kazanır. |
| Suskun Hüküm + Ağır Ahit | **Son İsim** | Kaydedilen hasar, sınırlı sayıda gecikmeli hükümle geri döner. Boss odaklı koşu seçeneği açılır; hükümler kendi hasarını yeniden kaydetmez. |
| Son Eşik + Kısa Dua | **Dönüş Ayini** | Dönüş mührü başarıyla tamamlanırsa ikinci eşik mühür konumunda belirir. Başarılı geri dönüş bir sonraki kaçışı hazırlar. |
| Yas Yolu + Cenaze Adımı | **Cenaze Alayı** | İzler daha uzun, seyrek darbeler veren bir koridora dönüşür. Geniş dolaşma rotası desteklenir; aynı düşmana tekrar vurma sınırı korunur. |

**Mevcut havuzdan ayrım:** Gunslinger’ın Yelpaze Atış, Seken Mermi ve doldurma patlamaları; Zyfen’in Girdap, Hortum ve Hava Cebi alanları zaten mevcut. Ahdar’ın ayırıcı öğesi **önceden belirlenmiş konuma geri dönüş ve oyuncunun hareketiyle kurulan sabit hatlar** olmalıdır. Düşman çekme, sekme, öldürmeden alan zinciri veya ekran çapında doldurma patlaması eklenmemeli.

Dayanaklar: [Seken Mermi](data/skills/seken_mermi.json), [Doldurma Saçılması](data/skills/doldurma_sacilmasi.json), [Hortum](data/skills/hortum.json), [Hava Cebi](data/skills/hava_cebi.json), [Tufan evrim koşulları](data/skills/tufan.json).

## 4. Denge niyeti ve sim ölçümü

**Güçlü yönler:** Hazırlanmış rotalarda verimli alan hasarı; düşmanı takip ettirerek oynama; tek hedef hükmüyle boss koşusu kurabilme.  
**Zayıf yönler:** Ani yön değişiminde hazırlığın boşa gitmesi; hızlı düşmanların damgadan çıkabilmesi; bağlama sırasında mühre dönmenin risk taşıması. Yavaşlatma boss ve elitleri kilitlememeli.

Üç farklı koşu hedeflenir:

- **Hat kurma:** Mezar Dikişi + Nöbet Taşı; iki konum arasında düşman taşıma.
- **Gezici aşındırma:** Yas Yolu + Son Eşik; geniş rotalarla alanı kullanma.
- **Hüküm:** Suskun Hüküm + hasar ve ritim pasifleri; öncelikli hedefe odaklanma.

**Ölçüm planı:**

| Ölçüm | Yöntem ve karar |
|---|---|
| Ham hasar | Mevcut `dps_table.gd` ve `dps_density.gd` düzenleri: halka, çizgi, küme; 10/50/200 hedef. Sabit oyuncunun yanında hareketli rota senaryosu da gerekir. |
| Evrim kazancı | Kaynak aktif sv5 ve aynı pasif yüküyle karşılaştırma. Başlangıç hedefi 10/50 yoğunlukta yaklaşık 1,8–2,2 kat; 200 hedef ayrı raporlanır. |
| Boss bütçesi | `lord_budget.gd` yaklaşımıyla 60 saniyelik ek hasar; ilk hedef tek evrim setinde Lord canının en fazla %25’i. Hareketli boss senaryosu ayrıca gerekir. |
| Mevcut karakterlere etki | Aynı sürümün önce/sonra eşleşmiş tohumları; strong/kite, 400 tohum. Gunslinger için `kills5` ve `hp_early` ±%5; Zyfen de regresyon karşılaştırmasına alınır. |
| Kimliğin çalışması | Başarılı dönüş/döngü oranı, dönüş için kat edilen mesafe, bağlamada alınan hasar, boşa çıkan damga oranı, beceri başına hasar payı. Bunlar yeni telemetri gerektirir. |
| Performans ve doğruluk | En yüksek kapasite/süre setinde nesne sayısı ve çarpışma işi; aynı tohumda aynı hash, sunum bağlı/bağımsız eşitliği, duraklatmada sayaçların durması. |

Kapanışın toplam hasarda ilk hedef payı yaklaşık **%20–30** olabilir: kimliği hissettirecek kadar güçlü, güvenli dönüş mümkün olmadığında koşuyu çökertecek kadar baskın olmamalı. Bu oran bir tasarım hipotezidir.

Mevcut strong/kite botları geri dönüş kararını bilmiyor. Karaktere uygun beceri öncelikleri ve bir dönüş politikası eklenmeden kötü bot sonucu, doğrudan karakter zayıflığı sayılmamalı. “Koşular farklı hissediyor” iddiası ayrıca oyuncu oturumlarında doğrulanmalı; üç yapı oyuncuya farklı hareket kararları verdirmelidir.

Denge kaynakları: [ölçüm yöntemleri ve gürültü sınırları](docs/design/v2.0.2/balance/README.md), [son doğrulama ve yoğunluk çelişkileri](docs/design/v2.0.2/balance/d-verification.md). Bu öneri için sim çalıştırılmadı.

## 5. Görsel ve animasyon brifi

**Silüet:** Kısa, geniş omuzlu, ağır adımlı bir figür. Başında alçak cenaze başlığı; gövdesinin önünde iki elle taşınan dikdörtgen mühür levhası. Kısa, parçalı etek; uzun saç ve uzun palto kullanılmaz. Levha gövdeye yakın tutulur; aşırı geniş şerit hücresine neden olmaz.

**Palet:** Kömür `#252323`, kemik `#C7B99B`, pas `#79472E`, kurumuş balmumu `#8F713F`. Etkin mühürlerde soluk kehribar `#D8AD62`; sınırlı parlaklık. Mühür durumları renk dışında kırık/tamamlanmış çizgi ve merkez simgesiyle ayrılır.

**Hareket dili:** Yürüyüşte levha ağır ama dengeli; saldırıda başparmak levhaya bastırılır, ardından avuç açılır. Bağlamada levha göğse çekilir ve avuç yeniden kapanır. Ayak hareketi gerektirmeyen üst gövde eylemi, hareket ederken saldırı sunumunu kolaylaştırır.

| Klip | Kare | Brif |
|---|---:|---|
| Yürüme | 8 | Tam adım döngüsü; net ayak teması, az gövde salınımı |
| Duruş | 1 | Levha ve yüz küçük ölçekte okunur |
| Saldırı | 6 | 24 fps; sıfır tabanlı `fire_frame: 3` anında mühür salımı |
| Bağlama | 4 | Başlangıç, sıkıştırma, gerilim, çözülme pozları |

Temel şerit **19 hücre**, hücre yüksekliği 320 px, oyun içi gösterim yüksekliği 200 px. Genişlik alfa sınırından hesaplanır; toplam doku genişliği en fazla 8192 px. Tam gövde `rig.armless: true` kullanılır. Hareket sırasında eylem görünümü için hattın isteğe bağlı `walk_cast` seçeneği ayrıca değerlendirilir.

`ab-animasyon-seridi` uyumu: duruş referansı ve üç sabit kameralı, sağa bakan, yeşil zeminli video → ffmpeg kare seçimi → yeşil silme → şerit, manifest ve kalite raporu. Levhadaki oyuklar gövde videosunda opak tutulur; yarı saydam büyü ayrı efekt katmanında üretilir. `cast_point` avuçtan ölçülür; uzaktaki damga sim hedef konumunda gösterilir.

Kalite hedefleri: klip boy sapması ≤%6; gerekli ayak çiftlerinde kayma ≤3 px; manifest ile `cast_point` farkı ≤0,03. İleride portre 1024×1536 ve durağan yedeği bulunan hareketli portre gerekir.

Dayanaklar: [animasyon hattı](.claude/skills/ab-animasyon-seridi/SKILL.md), [karakter üretim başvurusu](docs/dev/new-character.md). Bu fazda görsel üretilmedi.

## 6. Maliyet, risk ve karakter ekleme hattı

**Toplam maliyet: orta–yüksek.** Vitrin ve karakter kaydı mevcut veri altyapısına uygundur. Asıl iş, dönüş mührünün sim durumu, konuma bağlı tetikler, hasar kaydı ve hareketli denge senaryolarıdır. Bu karakter yalnız JSON ekleyerek tamamlanamaz.

| İş paketi | Kapsam / risk |
|---|---|
| Karakter verisi | `ahdar`, sıra 3, kendi başlangıç aktifi, tam gövde rig, portre ve olay sesleri; mevcut roster altyapısı kullanılabilir |
| Sim davranışları | 6 aktif + 5 evrim; döngü kimliği, nesne sınırları ve tekrar tetiklenme engelleri gerekir |
| Pasifler | Dört ortak beceri varyantı; bir yeni ortak pasif; bir özel pasif. Ortak süre pasifi bütün teklif ve denge havuzunu etkiler |
| Sanat | Duruş, üç animasyon kaynağı, şerit, statik/hareketli portre; önerilen 17 ikon sunumu ve ayırt edilebilir mühür efektleri |
| Denge araçları | `mid_run.gd` karakter öncelikleri, `mid_all.sh` karakter listesi; dönüş davranışlı politika ve hareketli ölçümler |
| Başlıca tasarım riski | Güvenli dönüş için sürekli aynı küçük daireyi çizmenin en iyi stratejiye dönüşmesi; hat, gezici ve hüküm yapılarıyla sınanmalı |

**F-ashen-bastion-060 kapsamında işaret edilen karakter listesi sabitlemeleri:** Bulgu kimliğinin metnini yerel dosyalarda bulamadım; ancak üretim yönergesi dört kırılmayı açıkça listeliyor ve ilgili testler mevcut:

- [test_character_roster.gd](test/unit/test_character_roster.gd:42): `test_ids_follow_order_field`, iki kimlikli tam liste bekliyor.
- [test_characters_screen.gd](test/unit/test_characters_screen.gd:265): `test_f030_gunslinger_first_by_order_field`, son karşılaştırmada iki elemanlı liste bekliyor.
- [test_acc_v2_chars.gd](test/acceptance/test_acc_v2_chars.gd:633): `test_k10_single_character_set_works`, Zyfen silinince tek karakter kalacağını varsayıyor.
- [test_v202_pool_real.gd](test/unit/test_v202_pool_real.gd:63): filtresiz aktif, pasif ve evrim sayılarını sabitliyor; önerilen havuzla güncellenmesi gerekir.

Uygulama fazında tek karakter senaryosu, diğer bütün karakterlerin kaldırıldığı kontrollü fixture ile kurulmalı; sıralama testleri üçüncü karakteri kapsamalı. Ayrıca iki karakterlik sabit matrisler yeni karakterin animasyon ve determinizm kapsamını kendiliğinden genişletmez; ayrı taranmalı.

**Hat sırası:** Tasarım değerlerinin karara bağlanması → sanat ve beceri referanslarının hazırlanması → import → karakter JSON’unun bağlanması → sabit beklentilerin güncellenmesi → denge ve yeni altın hash kayıtları → görsel/cihaz doğrulaması → `bash tools/gate.sh`.

Manifest ve yürüyüş kalite testleri kolsuz karakterleri otomatik tarar. Gunslinger’ın altın hash kayıtları korunmalı; yeni ortak pasif nedeniyle değişiklik oluşursa bunun etkisi ayrıca açıklanmalıdır.

Kaynak: [ab-karakter-ekle](.claude/skills/ab-karakter-ekle/SKILL.md). Bu çalışma yalnız öneri belgesidir; hiçbir dosya değiştirilmedi ve test çalıştırılmadı.

## 7. İki alternatif kısa konsept

**Çan Bekçisi — Bell Warden:** Sırtındaki çatlak cenaze çanını kısa tokmak darbeleriyle uyandıran eski bir kale görevlisi. Temel saldırısı yakın menzilli, yönlü ses darbeleridir; şarjör çanın biriktirebildiği titreşim, doldurma ise susturma anıdır. Koşular darbe aralığı, son vuruş ve düşmanı uygun mesafeye alma üzerinden ayrışır. Tek parmak kullanıma uygundur; Zyfen’in çevresel dalga ve alan hasarıyla benzeşme riski yüksektir.

**Kefen Dokuyucu — Shroud Weaver:** Kuşatmada kaybolanları cenaze bezine işleyen bir dokuyucu. Otomatik saldırıları hedeflere sınırlı sayıda ip bağlar; son ilmekten sonra gelen toparlanma ipleri gererek bağlı hedeflerde hasarı sonuçlandırır. Koşu çeşitliliği az hedefe yoğunlaşma veya geniş bağ ağı kurma seçiminden doğar. Güçlü bir görsel kimliği vardır; çok hedefli bağ seçimi, çizgi okunabilirliği ve boss ölçeklemesi Ahdar’dan daha yüksek uygulama riski taşır.