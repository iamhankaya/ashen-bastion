# Ashen Bastion v1 — Tasarım

Tarih: 2026-10-23 · Durum: kullanıcı tarafından onaylandı · Oyun adı: **Ashen Bastion** (kalıcı ad; ilk oynanabilir karakter: Gunslinger)

## 1. Amaç ve neden

Kullanıcının kendi telefonunda (Xiaomi Redmi Note 13 Pro) oynayacağı, Vampire Survivors türünde, tek oyunculu bir 2D mobil oyun. Asıl motivasyon: karakterlerin ve görsellerin "bize ait" olduğu, karanlık atmosferli bir hayatta kalma oyunu. Başarı ölçütü: kullanıcının kısa molalarda keyifle açıp oynadığı, her oyunda "bu sefer daha iyi bir kombo kuracağım" hissini veren bir oyun.

## 2. Hedefler, hedef dışı, anti-hedefler

**Hedefler**
- Zamana karşı hayatta kalma: zayıf düşmanlarla başlar, zaman geçtikçe düşmanlar hem güçlenir hem çoğalır.
- Düşman öldür → XP topla → seviye atla → beceri seç döngüsü.
- Geç oyunda ekranı dolduran mermiler ve patlayıcı kombolar (güç fantezisi), ama karakter dengeli: güç kazanılır, bedava gelmez.
- Gunslinger kimliği: iki tabanca, 6 mermilik şarjör ve yeniden doldurma ritmi.
- Karanlık gotik atmosfer + manhwa çizgisinde karakter.

**Hedef dışı (v1)**
- Store yayını, reklam, uygulama içi satın alma, çevrimiçi özellikler, çok oyunculu.
- Oyunlar arası kalıcı ilerleme (meta progression): her oyun sıfırdan başlar (kullanıcı kararı).
- Birden fazla oynanabilir karakter, birden fazla harita (v1'de yok; ama ileride yeni karakterler eklenecek, bkz. Kısıtlar).

**Anti-hedefler (teknik olarak çalışsa bile başarısızlık sayılır)**
- Karakterin ölümsüzleşmesi; 10. dakikadan sonra hiçbir tehdidin kalmaması.
- Kalabalıkta takılan oyun (kalabalık sahnede belirgin kare düşmesi).
- "Programcı çizimi" görünümünün final sürümde kalması.
- Karakterin tanınabilir şekilde başkasına ait bir karakterin kopyası olması: karakter bir manhwa karakterinden yalnızca genel hava olarak esinlenir; başka bir eserin adı, logosu veya metni oyunda ve repoda hiçbir yerde kullanılmaz.

## 3. Kısıtlar

- Platform: Android, store dışı; imzalı APK telefona elle kurulur (DiskPilot Mobile ile aynı dağıtım modeli). İleride arkadaşlarla APK paylaşımı mümkün olmalı (aynı imza ile güncellenebilir).
- Hedef cihaz: Xiaomi Redmi Note 13 Pro (HyperOS). Hedef 60 FPS; en kalabalık anda en az ~300 düşman + yüzlerce mermi ekranda.
- Ayrı proje ve ayrı private repo (yeni). DiskPilot Mobile ile kod paylaşımı yok.
- Bulut çalışma ortamında emülatör/telefon yok: gerçek cihaz testi kullanıcıda; geliştirme sırasında kontroller masaüstü/headless çalıştırma ve otomatik testlerle.
- Arayüz dili Türkçe.
- Genişletilebilirlik: oyunun adı dünyayı anlatır, kahramanı değil; ileride yeni oynanabilir karakterler eklenecek. Karakter (görseller, temel silah, başlangıç becerisi, istatistikler) veri olarak tanımlanmalı; yeni karakter eklemek oyun döngüsünü değiştirmemeli. v1'de karakter seçimi ekranı yoktur.
- Repo **public**: imza anahtarı (keystore) ve şifreleri asla commit'lenmez, yalnızca GitHub secret olarak tutulur.

## 4. Kullanıcının verdiği kararlar

- Tür: Vampire Survivors benzeri, tek oyunculu, zamana karşı hayatta kalma.
- 2D (3D gerçekçi değil).
- Görsel tarz: karakter manhwa çizgisinde (konturlu, cel-shading), dünya karanlık gotik (sis, silüet, sıcak amber ışık).
- Karakter: iki tabancalı, çevik gunslinger (kül rengi dağınık saç, yırtık mor soylu paltosu, kırmızı atkı). Onaylı referans görseller: `art/ref/karakter-konsept.png`, `art/ref/sprite-durus-kosu.png`, `art/ref/ana-gorsel-atis.png`.
- Görsel üretim yolu: karakter, düşman ve harita görselleri kullanıcı tarafından bir yapay zekâ görsel aracıyla (referans görselle tutarlılık) düz yeşil arka planla üretilir; arayüz Claude Design ile tasarlanır.
- Otomatik ateş; oyuncu yalnızca hareket eder (tek parmak).
- Seviye atlayınca oyun durur, 3 beceriden biri seçilir.
- Her oyun sıfırdan başlar.
- Şarjör ve yeniden doldurma ritmi oyunun merkezinde.
- Kişisel proje; belki ileride arkadaşlarla paylaşılır.
- Ekran yönü: **dikey (portrait)**, tek elle oynanır.
- Karakter animasyonu parçalı görsellerle: kullanıcı kolsuz gövde (palto + atkı dahil) ve tabancalı tek kol görsellerini üretip gönderecek.

## 5. Oyun tasarımı

### 5.1 Bir oyunun akışı
- Tek harita: yıkık kale harabeleriyle dolu bir savaş alanı. Harita oyuncuyla birlikte kayar (sınırsız ya da büyük sınırlı alan: builder'a bırakıldı), harabeler engel ve siper görevi görür.
- Süre 20 dakika (VLAD önerisi). 20. dakikada son düşman (Düşmüş Kale Lordu) gelir; onu yenmek oyunu kazandırır. Ölünce "oyun bitti" ekranı: süre, seviye, öldürülen düşman sayısı, kurulan kombolar.
- Ara bosslar: 5, 10, 15. dakikalarda güçlü bir düşman (VLAD önerisi).

### 5.2 Kontrol
- Dikey ekran, tek el. Ekranın herhangi bir yerine dokunulunca orada beliren sanal joystick; parmak kalkınca karakter durur.
- Ateş otomatik: en yakın / en tehlikeli düşmana nişan (kesin hedefleme kuralı builder'a bırakıldı). İki tabanca birbirinden bağımsız hedef alabilir.

### 5.3 Şarjör ritmi
- Temel silah: iki tabanca, ortak 6 mermilik şarjör (VLAD önerisi; tabanca başına ayrı şarjör de olabilir, builder dengelemeyle karar verir).
- Şarjör boşalınca kısa bir yeniden doldurma anı (~1 sn başlangıçta) olur; bu sırada temel ateş durur. Görsel/işitsel olarak net hissedilir (tambur dönme sesi, HUD'da mermi sayacı).
- Beceriler bu ritimle etkileşir: örnekler "Son mermi patlar", "Doldururken etrafa kurşun saçar", "Hızlı doldurma", "Fazladan mermi".

### 5.4 Beceriler ve kombolar (VLAD önerisi, sayılar ayarlanabilir)
- 6 aktif yuva (atış türleri/silahlar) + 6 pasif yuva (atış hızı, hasar, menzil, hareket hızı, can, toplama alanı vb.). Her beceri birkaç seviyeye yükseltilebilir.
- Evrim/kombo: bir aktif beceri en üst seviyeye ulaşıp ilgili pasifle eşleşince güçlü bir forma dönüşür. Örnek: Seken Mermi + Barut Kesesi → Zincirleme Patlama (her kurşun düşmandan düşmana seker, her vuruşta patlar).
- v1 içerik hedefi: ~8 aktif, ~8 pasif, ~4 evrim. Gunslinger temalı olmalı (seken/delici/patlayan mermi, yelpaze atış, dinamit, şarapnel vb.).
- Seviye atlama ekranında 3 seçenek; karakterin büyük portresi bu ekranda yer alır.

### 5.5 Düşmanlar ve zorluk eğrisi
- Dört kademe + son düşman (VLAD önerisi, görseller kullanıcıdan gelecek):
  1. Çürümüş piyade: yavaş, kalabalık, zayıf.
  2. Leş kargası sürüsü: hızlı, kırılgan, sürü halinde.
  3. Zırhlı şövalye hayaleti: yavaş, dayanıklı, ağır vuruş.
  4. Düşmüş Kale Lordu: son düşman.
- Zaman ilerledikçe hem düşman sayısı hem gücü (can, hız, hasar) artar; yeni türler belirli dakikalarda katılır. Eğri, 15. dakikada ekranı dolduran gücü hayatta kalmanın şartı yapacak şekilde ayarlanır (güç fantezisi ile tehdit dengede).
- Öldürülen düşman XP taşı düşürür; oyuncu toplama alanına girince toplanır.

### 5.6 Ekranlar
- Açılış/ana menü (ana görsel: `art/ref/ana-gorsel-atis.png`), oyun ekranı + HUD (süre, seviye, XP çubuğu, can, mermi sayacı), seviye atlama seçimi, duraklatma, oyun bitti/kazandın.
- Arayüz tasarımı Claude Design ile; renk paleti konsept sayfasındaki örneklerden: koyu mor, bordo, kemik beyazı, koyu kahve, bronz.

## 6. Görsel varlıklar

- Bakış açısı: göz hizası / hafif önden (3/4) yandan görünüm; sola gidişte yatay ayna. Tam profil koşu kullanılmaz.
- Karakter (parçalı rig, kullanıcı kararı): kullanıcı iki görsel üretir: (a) kolsuz tam gövde (palto, atkı, bacaklar görünür, elde silah yok), (b) tabancalı tek sağ kol, yatay uzanmış. Sol kol (b)'nin aynasıdır. Kollar hedefe doğru döner (iki tabanca bağımsız nişan), gövde yürürken sallanır/eğilir (bob, squash), palto etekleri ve atkı kod/shader ile ikincil hareketle dalgalanır. Doldurma, hasar ve ölüm de bu parçalarla kodla canlandırılır. Kare kare sprite kullanılmaz. `art/ref/sprite-durus-kosu.png` sol poz oran/renk referansıdır. Namlu alevleri ve mermiler oyun içi efekttir, çizime gömülmez.
- Düşmanlar (VLAD kararı): her tür için tek sabit görsel; hareket kodla (sallanma, squash/stretch, yön çevirme, vurulunca beyaz parlama). Düşmanlara iskelet rig uygulanmaz (300+ düşman performansı). Ara bosslar normal düşmanların büyütülmüş, renk/ışık değiştirilmiş elit sürümleridir; son düşmanın (Kale Lordu) kendi görseli vardır.
- Harita (VLAD kararı): yukarıdan görünen, döşenebilir (tileable) zemin dokusu + ayrı ayrı yerleştirilen harabe parçaları (duvar, kule, kemer, moloz). Harabeler göz hizası/3/4 görünümlü dikey nesnelerdir; derinlik sıralaması (y-sort) ve çarpışma alanı alır. Tek parça büyük boyalı harita kullanılmaz.
- Kullanıcıdan gelen tüm görseller düz yeşil arka planla gelir; yeşil arka plan silinir, delikler şeffaf kalır, kenardaki yeşil yansıma temizlenir.
- Diğer görseller (VLAD kararı): beceri/evrim ikonları Claude Design ile (vektör, aynı palet); mermi, namlu alevi, patlama, XP taşı ve ışık/sis efektleri kodla/shader ile; seviye atlama portresi `art/ref/portre-seviye-atlama.png`; menü ana görseli `art/ref/ana-gorsel-atis.png`.
- Görseller hazır olmadan geliştirme geçici (placeholder) görsellerle ilerler; oyunun eğlenceli olup olmadığı görsellerden bağımsız test edilir. Görseller geldikçe değiştirilir.
- Karakter telefonda ~80–100 px boyunda görünecek; ince uzun çizgi okunmazsa sprite ölçeği büyütülür (prototipte karar).

## 7. Nasıl yapılacak (VLAD'ın kararları, kullanıcı itiraz edebilir)

- Motor: Godot 4 (GDScript), 2D; Android APK dışa aktarımı; iskelet animasyonu Godot'nun yerleşik 2D iskelet sistemiyle.
- Dağıtım: CI'da imzalı APK üretimi; kalıcı imza anahtarı (arkadaşlarla paylaşımda güncellemelerin kurulabilmesi için şart).
- Performans: kalabalık için havuzlama (object pooling) ve hafif çarpışma yaklaşımı; ayrıntı builder'da.

## 8. Builder'a bırakılanlar

- Kod mimarisi, sahne yapısı, veri formatları (beceri/düşman tanımları).
- Hedefleme kuralı, hasar formülleri, XP eğrisi, doğma (spawn) zamanlaması, tüm denge sayıları.
- Haritanın sınırlı mı sonsuz mu olduğu.
- Ses: v1'de serbest lisanslı ses efektleri/müzik ya da geçici sesler (kullanıcı tercihi açık nokta).
- Test yaklaşımı ve CI kurgusu.

## 9. Açık noktalar

- Oyunun kesin adı ve repo adı.
- Düşman, harita ve karakter parça görselleri (kullanıcı üretiyor); gelene kadar geçici görsellerle ilerlenir.
- Ses ve müzik kaynağı.
