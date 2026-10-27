# Kılıçlı çevik kadın karakter — final tasarım önerisi (Game Director)

Tarih: 2026-10-27 · Durum: **öneri, kullanıcı onayı bekliyor** · Görev: T20261027-27 (değişiklik isteği 12:43)
Girdi: `sword-character-merged.md` (Veyra, birleşik) ve `sword-character-codex-astra.md` (Sera). Her ikisi okundu; bunların kökeni olan `sword-character-claude.md` (Nerya) ve `sword-character-codex.md` birleşik belgenin §8'inde izlenir. Önceki belgeler değiştirilmedi.
Kapsam: yalnız belge; kod, veri ve görsel yok. Sayılar öneri; sim'de ölçülmedi, hiçbir test koşulmadı (Godot yerelde çalışmıyor). Esin kaynağı eser adı geçmez; "Barutçu olmayacak" kararı (2026-10-24) korunur.

---

## 0. Karşılaştırma: Veyra (birleşik) ve Sera

| Konu | Veyra (birleşik) | Sera (Codex astra) | Değerlendirme |
|---|---|---|---|
| Hikâye/ton | Yeminli son kılıç; iki yetenek hikâyeye bağlı | Cenaze muhafızı, mühürlü kılıçlar sahiplerine dönmedi; yardımcı kılıç + infaz kılıcı | Sera'nın "mühür/mezar" imgesi somut ve dünyaya yakın; Veyra'nın "nöbet/ahit" dili daha yalın. İkisi bağdaşır |
| Temel değerler | 95 can, 325 hız, 5 kesik, 0,85 sn, menzil 135 | 100 can, 330 hız, 4 kesiş, 0,90 sn, erişim 125 → 140 (seviyeyle) | Sera erişimi seviyeyle büyütür (iyi ölçek); iki bağımsız öneri **4 kesik** ritminde birleşti |
| Temel saldırı | 100°, ≤3 hedef, hedef yokken kapasite yanmaz | Aynı + hedef sabit, aynı düşmana kesiş başına tek vuruş, hedef sınırı 3 → 5 | Sera'nın "hedef savuruş boyunca sabit, tek vuruş garantisi" test edilebilirliği artırır |
| Çeviklik | Toparlanmada %20 hız / 0,3 sn; sıçrayış v2 deneyi | +%30 hız / 0,22 sn, dokunulmazlık yok, çarpışma geçerli | Aynı fikir; Sera'nın "parmak kalkmışsa karakter kendiliğinden yer değiştirmez" kuralı net |
| Gökten düşen kılıç | Son 2 sn'de vurulmuş hedef, küme, 0,45 sn uyarı, ×1,5 (%30 altı) | Son 2 sn'de vurulmuş, en yüksek **mevcut can**lı hedef; sabit nokta, 0,35 sn çizgi; merkez 100 → 220 + çevre %35; boss'ta infaz yok | Sera'nın merkez+çevre ayrımı kalabalıkta hasarı kontrol eder, sabit nokta "kaçabilir" adaleti verir; Veyra'nın daha uzun uyarısı okunurluk için iyi |
| Süzülen kılıç | Sürekli görünür, seferli hasar, 3 → 5 hedef | Beklerken omuz çevresinde döner; ziyaret sırası sabit kurallı (en yakın, eşitte düşük kimlik), aynı anda tek sefer | Sera'nın **deterministik ziyaret sırası** ve "önceki dönmediyse yenisi doğmaz" kuralı güçlü; Veyra'nın hedef sayısı fazla cömert olabilir |
| Savunma | Yok (dokunulmazlık yok, hız artışı) | **Çelik Siper:** toparlanma başında kısa pencere, ilk temas darbesinde %30 → %50 azaltma + karşılık | VLAD notu: güvenli ek. Riski: zorunlu seçim olmaya kayabilir; Sera bunu açıkça not eder |
| Diğer aktifler | Dikiş Darbesi, Kabza Payı, Kırık Yemin | Son Çentik, Açık Dikiş | Son Çentik ritme bağlı ve ucuz; Kabza Payı ile Çelik Siper aynı toparlanma anında çakışıyor |
| Pasifler | 6 ortak varyant | Aynı 6; `agir_kursun`'un yeni davranışlarda **bir kez** uygulanması uyarısı; Mıknatıs çıkarılmalı | Sera'nın çift çarpma uyarısı değerli; her ikisi de filtre kodu gerektirdiğini söyler |
| Evrimler | Kesin Hüküm, Son Nöbet (6 hedef), Çifte Dikiş, Açılan Gedik | Kesin Hüküm, Sadık Çelik (4 hedef + tek bitiriş), Son Nokta, Demir Sükûnet | Sera'nınkiler kılıç sayısını/ekranı büyütmeden "zamanlamayı belirginleştirir"; ölçülü gösteriş ilkesine daha uygun |
| Denge/bot | `melee` politikası, kabul bandı, ±%5 | Politika (95–115 px), ölçüm tablosu (10/50/200 yoğunluk, Lord'a hasar/dk, ölüm nedeni), hipotez bandı, 400 tohum gürültü uyarısı | Sera'nın ölçüm tablosu daha geniş; Veyra'nın sayısal kabul bandı daha net |
| Görsel | Kısa yas ceketi, tek efekt rengi (çelik beyazı), hex palet | Asimetrik omuz örtüsü, belden iki kumaş şeridi, hex palet, amber küçük mühürde | İkisi de palet verir; Sera silüette hareket okunurluğunu düşünmüş |
| Animasyon | 19 hücre; `walk_cast` ile 25 hücre / 8000 px | 19 hücre; 25 hücrede hücre genişliği ≤ ~327 px; geniş kesiş izi ayrı efekt | Sera'nın genişlik sınırı ve "iz ayrı efekt" çözümü somut |
| Zayıf yön | Süzülen kılıçta çok hedef; Kabza Payı ile siper boşluğu; yeni davranış sayısı fazla | Çelik Siper ve Açık Dikiş (yara sistemi) yeni; ad/ton sorusu az; eşik sayıları "hipotez" | Final bunları ele alır |

---

## 1. Tema, ad, hikâye

| Alan | Karar |
|---|---|
| Ad | **Veyra** |
| Unvan (TR) | **Son Ahit'in Nöbetçisi** |
| Unvan (EN) | **Veyra, the Last Oath-Warden** |
| Kimlik | Kadın, 20'lerinin sonunda; tek, dar, düz, tek elle kullanılan uzun kılıç |
| Ton | Kederli, soğukkanlı, gösterişsiz; kuvvetini çok silahtan değil, doğru anda inen tek kesikten alır |

**Hikâye çekirdeği.** Veyra, kale Nöbetçi Birliği'nin son yeminli kılıcı ve cenaze muhafızıdır: ölülerin silahlarını mühürleyip sahipleriyle birlikte gömmek görevdi. Kale düşünce mezarlar açıldı, mühürlü kılıçlar sahiplerine dönmedi. Şimdi yanında bir eski kılıç süzülür (tamamlanmamış nöbet), çağrısına gökten ağır bir kılıç cevap verir (geciktirilmiş son hüküm). Her kesik dizisinden sonra kılıcını gövdesine çeker ("nöbet değişti"). Merkezde çelik, yas ve tamamlanmamış görev var; büyü silahların iradesinde görünür, karakteri saran bir aura yoktur. Derin yazım sonraya kalır.

**Dünyaya uyum.** Yıkık kale, huzursuz ölüler ve yas teması mevcut karanlık gotik/manhwa çizgisine oturur; Zyfen'in yeşilimsi beyazı ve Gunslinger'ın barut turuncusuyla karışmaz (§5).

---

## 2. Oynanış kimliği

Fantezi: **"Yaklaş, dört kesik, toparlanırken sıyrıl, yeniden gir."** Tek parmak joystick korunur; saldırı ve hedef seçimi otomatiktir.

### 2.1 Temel değerler (öneri; Veyra ile Sera'nın arası)

| Değer | Gunslinger | Zyfen | **Veyra (final)** |
|---|---|---|---|
| Can | 100 | 85 | **95** |
| Hareket hızı | 300 | 310 | **325** |
| Dizi (`mag_cap`) | 6 | 8 | **4 kesik** |
| Toparlanma (`reload_time`) | 1,0 sn | 1,3 sn | **0,85 sn** |
| Menzil | 700 | 750 | **130** (seviyeyle 145'e) |
| Temas yarıçapı / toplama | 22 / 110 | 22 / 110 | 22 / 110 |
| Başlangıç becerisi | `cift_tabanca` | `ruzgar_kesigi` | **Ahit Kesiği** |

Menzil gerekçesi: Çürümüş Piyade yarıçapı 26 + oyuncu 22 → temas ~48 px'te başlar; 130 px bunun ~2,7 katı. Kodda temas hasarı `CONTACT_INTERVAL = 0,6 sn`, tick başına ≤4 temas, Çürümüş Piyade `dmg 6` (`scripts/sim/damage_system.gd`, `data/enemies/curumus_piyade.json`): kalabalığın ortasında teorik üst sınır ~40 can/sn, 95 can ≈ 2,4 sn.

### 2.2 Temel saldırı — Ahit Kesiği

- Erişilebilir **en yakın düşmana** yönelen 100° yay; başlangıçta ≤3, seviyeyle 5 hedef; duvar arkasına vurmaz.
- Hedef hazırlıkta seçilir ve savuruş boyunca **sabit** kalır (kareler arası dönme yok); isabet anında mesafe yeniden kontrol edilir. Bir kesik bir düşmana **en çok bir kez** vurur.
- **Menzilde hedef yokken kapasite tüketilmez.** Savuruş başladıktan sonra hedef uzaklaşırsa kesik boşa gidebilir; kısa hazırlık bu yüzden önemlidir.
- Hareket yönüne kilitli değil: oyuncu geri çekilirken de vurur. Hareket ederken saldırı zorunlu tasarım koşuludur (Zyfen'in `action_while_moving: false` ayarından ayrılır).
- Oyuncunun işi nişan almak değil, **grubun kenarında kalmaktır**; arkadan gelenler yayın dışında kalır, merkeze dalmak kuşatılma riskidir.

### 2.3 Çeviklik — hareket kontrolü eklemeden

**v1 (önerilen):** seri bitip toparlanma başlayınca joystick yönünde **0,25 sn'lik +%25 hız**; parmak kalkmışsa karakter kendiliğinden yer değiştirmez; dokunulmazlık yok, çarpışma kuralları geçerli. Alçalan gövde ve kısa kılıç izi atılma hissini destekler.
**Opsiyonel v2 deneyi (Nerya'dan; kullanıcı kararı, §7 S1):** otomatik geri sıçrayış ve ~0,2 sn hasarsız pencere; altın hash/çarpışma riski yüksek olduğu için yalnız v1 cihazda zayıf kalırsa denenir.

### 2.4 Şarjör/ritim karşılığı — Nöbet Dizisi

| Gunslinger/Zyfen | Veyra |
|---|---|
| Şarjör 6 / 8 mermi | **Dizi: 4 kesik** |
| Doldurma 1,0 / 1,3 sn | **Toparlanma 0,85 sn:** kılıç gövdeye çekilir, temel saldırı durur, hareket sürer |
| HUD çentikleri | 4 çentik, her temel saldırıda azalır |

Yan yetenekler toparlanmada kendi kurallarına göre çalışır. Uzun Ahit dizi uzatır (daha uzun hücum, toparlanmaya bağlı etkiler seyrekleşir); Sakin Tutuş açık anı kısaltır: iki ayrı yapı tercihi.

---

## 3. Yetenek havuzu ve evrimler

Kural: *değer artıranlar ortak, ekranda bir şey yapanlar karaktere özel.* **Başlangıç saldırısı dahil 6 aktif, 6 pasif, 4 evrim.** Değerler seviye 1 → 5; ara seviyeler kademeli.

### 3.1 Altı aktif

| # | Aktif | Davranış ve ölçek |
|---|---|---|
| 1 | **Ahit Kesiği** *(temel saldırı)* | Hasar 24 → 42; aralık 0,32 → 0,26 sn; menzil 130 → 145; hedef 3 → 5; her kesik 1 kapasite |
| 2 | **Son Hüküm — gökten düşen kılıç** *(kullanıcı fikri)* | Son 2 sn'de Ahit Kesiği ile vurulmuş, 220 px içindeki düşmanlardan **mevcut canı en yüksek** olanın bulunduğu noktaya (eşitlikte düşük kimlik) **tek kılıç** iner. Yerde 0,4 sn ince halka/çizgi; nokta **sabit**, hedef kaçabilir. Merkez hasarı 90 → 200, çevre yarıçapı 50 → 65 px, çevre hasarı merkezin %40'ı; bekleme 7,5 → 5,5 sn. Merkez hedef iki kez hasar almaz. Canı **%30 altı sıradan** düşmana merkez ×1,5 (infaz); boss'ta bu bonus ve yüzde can silme yok. Geçerli hedef yoksa hazır bekler |
| 3 | **Nöbetçi Çelik — süzülen kılıç** *(kullanıcı fikri)* | Kılıç **her an** omuz çevresinde (~70 px) yavaşça süzülür (hasarsız, görsel). **Sefer:** 3,2 → 2,2 sn'de bir; oyuncudan 190 → 220 px içinde **ziyaret edilmemiş** en yakın hedeflerden başlayıp 3 → 5 ayrı düşmanı sırayla ziyaret eder (eşitlikte düşük kimlik), döner; hedef başına 14 → 28 hasar, sefer en çok 2,4 sn. Aynı anda tek sefer; önceki dönmediyse yenisi doğmaz. Boss'a sefer başına tek isabet. İtme/çekme yok |
| 4 | **Çelik Siper** *(güvenli ek, Sera'dan)* | Toparlanma başında kısa pencere (0,20 → 0,30 sn): o penceredeki **ilk temas darbesinin** hasarı %30 → %50 azalır ve saldırgana **karşılık** verilir (kabza darbesi: 20 → 50 hasar, 140 px'e kadar; sıradan düşmana itme 55 → 85, boss/elite itme yok). Döngü başına bir kez. Dokunulmazlık değildir, dalga üretmez |
| 5 | **Son Çentik** | Serinin **son** temel kesiği ağırlaşır: +20 → +55 hasar, önde dar bitiriş; isabet alan sıradan düşmanlara 18 → 30 birim itme (elit/boss itilmez). Patlama yok |
| 6 | **Kırık Yemin** | Dizi başına ilk temel isabet hedefi 3 sn işaretler; aynı hedefe sonraki temel isabette işaret tüketilir, **30 → 70 ek hasar**. Yığılmaz, başka hedefe yayılmaz |

**Çelik Siper güvenliği (VLAD notu değerlendirmesi):** eklenebilir, çünkü (a) tek temas darbesini kısmen azaltır, sürekli azaltma değil; (b) dokunulmazlık/can çalma yok; (c) yalnız bir saldırgana karşılık verir (Nefes Dalgası gibi dalga değil); (d) başlangıç becerisi değil, seçimle gelir. Riski: yaşamak için **zorunlu seçim** olma ihtimali. Ölçüt: Çelik Siper'siz Veyra oynanabilir kalmalı; Siper'li/siz `PRIORITY_BY_CHAR` koşularında Siper'in sağladığı ek hayatta kalma (ölüm oranı ve `hp_early` farkı) başka bir aktifin ortalamasının ~1,5 katını aşarsa önce temel menzil/hazırlık gözden geçirilir. Kabza Payı (birleşik belge) bu aktifin karşılığı olarak birleştirildi; ayrı aktif olarak çıkarıldı.

### 3.2 Altı pasif

Ortak pasifler `variants.<id>` ile karaktere özgü ad/ikon alır; değerler o seviyenin toplam etkisidir.

| Ad | Ortak karşılık | L1 → L5 |
|---|---|---|
| Bilenmiş Ağız | `agir_kursun` | Kılıç hasarı +%10 → +%50 |
| Seri Bilek | `hizli_parmak` | Saldırı hızı +%8 → +%40 |
| Uzun Ahit | `fazladan_mermi` | Dizi +1 → +5 |
| Sakin Tutuş | `hizli_doldurma` | Toparlanma −%10 → −%50 |
| Hafif Adım | `cevik_cizme` | Hız +%6 → +%30 |
| Yas Zırhı | `saglam_yelek` | Can +15 → +75; yenilenme 0,25 → 1,25/sn |

Kural (Sera'dan): Bilenmiş Ağız yeni davranışlarda hasara **bir kez** uygulanır; Kırık Yemin ek hasarına veya evrim darbesine aktarılırken ikinci kez çarpılmaz. **Doğrulanmadı:** `agir_kursun` (`bullet_dmg_mult`) kılıç hasarına uygulanıyor mu.

**Havuz:** `pool` yalnız `common` ya da karakter kimliği (`scripts/sim/data_v202_pool.gd`); yedi ortak pasifin hepsi gelir, **Mıknatıs** de. 6 pasifi tam yapmak karaktere göre izin listesi gerektirir (kod; §7 S6).

### 3.3 Dört evrim çifti

Koşul: aktif seviye 5 + pasif en az seviye 1; evrim aynı aktif yuvasını devralır.

| Çift | Evrim |
|---|---|
| Son Hüküm + Bilenmiş Ağız | **Kesin Hüküm:** tek kılıç; merkez hasarı 300; hedef canı %30 altındaysa ×1,5; çevre yarıçapı büyümez; boss'ta ek hasar yok |
| Nöbetçi Çelik + Seri Bilek | **Sadık Çelik:** 4 farklı hedefe 42'şer; ardından yaşayan ziyaretli hedeflerden canı en düşüğe tek 60 hasarlık bitiriş; hâlâ tek kılıç; boss'a sefer başına tek isabet |
| Çelik Siper + Sakin Tutuş | **Demir Sükûnet:** azaltma %65'e, karşılık 100 hasara; pencere 0,30 sn'de kalır; yalnız saldırgana vurur |
| Son Çentik + Uzun Ahit | **Son Nokta:** son kesikte +55 yerine +90; ana hedefe 0,12 sn sonra, hâlâ erişimdeyse 60 hasarlık ikinci kesik; ikinci darbe kapasite tüketmez ve kendini tetiklemez |

Evrim kılıç sayısını/ekran kaplamasını büyütmez; **zamanlama** belirginleşir. Kırık Yemin ve Ahit Kesiği evrimsizdir.

### 3.4 Mevcut karakterlerden ayrım

| Mevcut | Veyra | Fark |
|---|---|---|
| Zyfen **Girdap** (sürekli halka, itme) | Nöbetçi Çelik | Boşta dönüş **hasarsız**; hasar yalnız ayrı hedef ziyaretlerinden; çekme, sürekli halka, üst üste alan yok. Sim'de ayrı davranış, rüzgâr alanı kodunu paylaşmaz |
| Zyfen **Hortum/Tufan** (gezen çekim alanı) | Nöbetçi Çelik | Kılıç çekmez, alan bırakmaz, uzak kümeyi kovalamaz (≤220 px) |
| Zyfen **Delen Rüzgar / Göğün Mızrağı** (anında, delici, art arda) | Son Hüküm | Tek düşüş, uyarılı sabit nokta, delmez, önceden **yakın dövüş isabeti** ister; uzaktan düzenli salvo yok |
| Zyfen **Nefes Dalgası** (toparlanırken çevre itme) | Çelik Siper | Yalnız bir saldırgana cevap; toparlanma dalgası üretmez |
| Gunslinger **Keskin Nişan, Son Mermi Patlar** (tek atış infaz, son kurşun) | Son Hüküm, Son Çentik | Menzil ve hedefleme farklı; Son Çentik dar fiziksel kesik, alan patlaması değil |
| Gunslinger seken mermi, saçılma, ölüm patlaması | Kırık Yemin, Nöbetçi Çelik | Kısa mesafede hedefe bağlı kesik; Kırık Yemin öldürme zinciri başlatmaz |

Ayrım renge değil, **hedefleme ve hasar dağılımına** dayanır.

---

## 4. Denge niyeti ve sim botu

**Ödül:** yakındaki birkaç hedefe güçlü kesik, hızlı hedef bitirme, yakın mesafeden kazanılan infaz, hareketli savunma. **Risk:** arkadan kuşatılma, toparlanırken temel saldırının kesilmesi, erişim dışına çıkan hedefe boşa savurma. Sürekli hasar azaltma, can çalma, dokunulmazlık önerilmiyor.

**Bot sorunu.** `test/helpers/bots.gd` `_kite_dir` tehdit yarıçapı içindeki düşmanlardan uzaklaşır; `mid_run.gd` `strong` de tehdit görünce kaçar. 130 px menzilli karakter bu politikalarla sistematik bastırılır. **Yeni `melee` politikası** (yalnız sim durumu ve oyuncunun erişebildiği bilgi; gelecek doğuşları kullanmaz; rastgelelik yok):

1. Erişilebilir, grubun kenarındaki hedefe ~100–125 px'lik saldırı bandına yaklaşır.
2. Dizi sürerken düşman çevresinde **teğet** hareket eder, temas mesafesine girmez.
3. Toparlanırken 180–220 px'e açılır; dizi dolunca yeniden yaklaşır.
4. Kuşatılınca açık sektöre çıkar; can < %50 ise saldırı isteğini azaltıp güvenli XP toplar (`kite`'a geç); duvar dolanması korunur.
5. `kite`/`strong` sonuçları da raporlanır ama tek denge hükmü sayılmaz.

**Ölçümler (aynı tohumlarda önce/sonra):** `kills5`, `hp_early` (yaşayan örneklerden hesaplandığı için ölüm oranından ayrı yorumlanmaz), erken ölüm oranı, 10. dakikaya erişim, ölüm nedeni; menzilde geçen süre ve boşa kesik oranı; seri/toparlanma başına alınan hasar (toparlanmada sıfıra yakın); temel kesik, yara/işaret ve yardımcı kılıçların hasar payı; tek hedef ile 10/50/200 düşman yoğunluğu; boss öldürme süresi ve Lord'a hasar/dk (infaz boss'u kolaylaştırmamalı); Çelik Siper'in engellediği hasar (§3.1 ölçütü). `PRIORITY_BY_CHAR`'a kart öncelikleri evrimleri tamamlayacak biçimde eklenir (yoksa Gunslinger önceliğine düşer).

**Kabul bandı (hipotez, kabul edilmiş eşik değil):**
- Erişim içi tek hedefe temel kesik verimi eşit seviyede Gunslinger'dan %15–30 yüksek **olabilir** (Sera); yaklaşma/kaçış süreleriyle bunun net koşu üstünlüğü ~%90–110 bandına inmelidir (tek hedef), kümede %110–140.
- `melee` politikasında Veyra `kills5` ≥ Gunslinger `kite`'ın %90'ı, ≤ %130'u; `hp_early` Gunslinger'dan düşük (risk primi) ama koşu bitebilir; `kite/strong` politikasında Gunslinger'ın en çok %60'ı.
- Evrimler kendi S5 tabanlarına göre kontrollü koşullarda ~1,5–2× katkı hedefler.
- Gunslinger regresyonu: `kills5` ve `hp_early` **±%5** (mevcut ölçüt); geniş belirsizlik "denge sağlandı" diye yorumlanmaz. Sera, hayatta kalma ölçümünün 400 tohumda bile gürültülü olabildiğini yazıyor; `docs/design/v2.0.2/balance/` raporları bu görevde **okunmadı, doğrulanmadı**.
- **Dürüst sınır:** bot başarısı telefondaki yakın dövüş rahatlığının yerine geçmez; elde hissi ölçülemez (§7).

---

## 5. Görsel ve animasyon brifi

**Silüet:** bağlı koyu saç (ense hizası), kısa yas ceketi, **tek asimetrik kısa omuz örtüsü**, belden ayrılan **iki dar kumaş şeridi** (hareketi okutur; `rig.sway` ile uyumlu), belirgin çizmeler, görünür diz ve ayak hareketi, tek uzun kılıç aşağı çapraz; süzülen kılıç omuz gerisinde ikinci küçük çizgi. Uzun palto/pelerin ve geniş büyücü silüeti yok (Zyfen'den ayrılır). Kadın kimliği duruş, yüz ve oranlarla okunur; yüz manhwa çizgisi, sakin.

**Palet:** kömür siyahı `#252326`, solmuş bordo `#653D43`, kirli kemik `#C8BEA9`, mat çelik `#92918B`. **Efekt rengi tek: soğuk çelik beyazı** (~`#DCE6EE`, hafif mavi kayık). Amber yalnız omuz mührü gibi ≤6 px ayrıntıda, efektte kullanılmaz (Gunslinger turuncusundan ayrılsın).

**Ölçülü gösteriş** (ilke: tek renk, kısa süre, küçük ekran payı, tok ses):

- **Ahit Kesiği:** tek ince çelik yay, ~0,10–0,15 sn; rutin saldırıda ekran sarsıntısı yok.
- **Son Hüküm:** yerde 0,4 sn ince halka; tek ince kılıç hattı ~0,08 sn'de iner; 2 karelik beyaz parlama, yerde kısa çatlak çizgi, az toz; **sarsıntı ≤ 2 px / 80 ms**; kılıç 0,6 sn saplı kalıp solar (görsel). Tek ses: tok metal.
- **Nöbetçi Çelik:** ~24×96 px tek sprite, kod ile süzülür; yalnız **hareket sırasında** dar solan iz (6 örnek, 0,2 sn); kalıcı parlak halka yok.
- **Çelik Siper:** toparlanma başında kılıç önünde çok kısa çelik yay (0,2–0,3 sn); temas anında tek beyaz kıvılcım ve kılıç tınısı.
- **Evrim:** kılıç sayısı/ekran kaplaması büyümez; darbenin zamanlaması belirginleşir.
- **Hareket azaltma** ayarında sallantı ve art izleri kapanır; hedef işareti ve isabet okunurluğu kalır.
- Efektler kod/shader; yalnız kılıçlar ve ikonlar sprite.

**Şerit planı (`ab-animasyon-seridi` / `ab-karakter-ekle`, tek parça gövde, `rig.armless: true`):** 8 yürüme + 1 duruş + 6 kesik (`fire_frame: 3`, sıfır tabanlı, 24 fps) + 4 toparlanma = **19 hücre**; hücre yüksekliği 320, `display_height` 200; genişlik ve `stride` manifest ölçümünden. Hareket sırasında kesişin bacakları dondurması kabul edilmez: gerekirse `walk_cast` (+6 → **25 hücre**; 8192 px sınırı hücre genişliğini ~327 px'e indirir). Uzun kılıç savuruşu bu yüzden kritik risk: **geniş kesik izi ayrı efekt** olur, gövde karesinde yalnız kılıç kalır. **İlk üretim kontrolü: kılıç pozunun hücre genişliği ve hareketli kesik okunurluğu.**

Hat: duruş referansı → sabit kameralı, sağa bakan düz yeşil zemin videoları → ffmpeg kare seçimi → yeşil silme → şerit + manifest; kare kare bağımsız görsel yok (kart notu). Ayak kayması, klip boy sapması (≤%6), aynalama, kılıç-el tutarlılığı, kılıç kenarında yeşil hale `quality.json` kapısından geçmeli. Yukarıdan inen ve süzülen kılıçlar gövde şeridinden **ayrı varlık**. Ikon: 6 aktif + 4 evrim + 6 pasif varyantı = **16** (Mıknatıs varyantı isteğe bağlı); portre 1024×1536 (`ab-gorsel-ikon-uret`). Bu fazda görsel üretilmez.

---

## 6. Maliyet ve risk

**Genel: orta-yüksek.** Karakterin listeye eklenmesi veridir; yakın dövüş davranışı JSON ile tamamlanmaz. Otomatik sıçrayış v1'de olmadığı için en riskli sim parçası çıktı.

| İş | Maliyet / temel risk |
|---|---|
| Karakter verisi, ortak pasif adları (`variants`) | Düşük |
| Kısa menzilli kesik + hareket sırasında saldırı | Yüksek: hedef seçimi, savuruş geometrisi, tek vuruş garantisi, görüntü–sim isabet örtüşmesi, duvar |
| Süzülen kılıç (tek sefer, deterministik sıra) | Orta: hedef ölmesi, menzil dışı, sefer tamamlanması, yeniden tetikleme |
| Son Hüküm (hedef geçmişi, sabit nokta, çevre hasarı) | Orta |
| Çelik Siper (temas hasarı kancası, azaltma + karşılık) | Orta: `DamageSystem` temas yoluna dokunur; tek-sefer/döngü kuralı |
| Seri/toparlanma hız penceresi | Orta: mevcut şarjör olayları kullanılabilir |
| Pasif havuz filtresi (6'ya indirme) | Orta, isteğe bağlı |
| Animasyon | Orta-yüksek: kılıç genişliği, aynalama, hareketli saldırı |
| `melee` bot + denge | Yüksek: uzak politikalar yetmez |
| *(v2 deneyi)* otomatik sıçrayış | Yüksek: altın hash, çarpışma |

**İlk doğrulanacak parça:** Ahit Kesiği + 4 kesikli ritim + hareketli saldırı + toparlanma hız penceresi. Bu tatmin edici olmadan tüm havuz üretilmez.

**Hat (`ab-karakter-ekle`):** tasarım → veri iskeleti (JSON'u sona bırak: `validate_data` eksik görsel/beceriyi reddeder) → görseller → beceriler (`ab-beceri-ekle`) → ses (`ab-ses-ekle`: metal darbe, toparlanma) → mevcut testlerin güncellenmesi → denge (`ab-denge-olcumu`) → yeni altın hash aşaması (**Gunslinger kayıtları değişmez**) → ekran öz-kontrolü → kendi cihaz listesi (`docs/dev/user-verify/`) → `bash tools/gate.sh`.

**F-ashen-bastion-060 (karakter listesini sabitleyen 4 test):** `test/unit/test_character_roster.gd:44` (`test_ids_follow_order_field`, yeni karakter `order: 3`), `test/unit/test_characters_screen.gd:273` (`test_f030_gunslinger_first_by_order_field`; Gunslinger ilk kalmalı), `test/acceptance/test_acc_v2_chars.gd:640` (`test_k10_single_character_set_works`; Zyfen'i silmek yerine gerçekten tek karakterli veri kurulmalı, beklenen sayıyı 3'e çıkarmak yanlış çözüm), `test/unit/test_v202_pool_real.gd:64` (filtresiz aktif/evrim toplamları). Öneri: veri tabanlı beklentiye çevirmek. Satır numaraları bulgu dosyasından; testler bu görevde yeniden doğrulanmadı.

**Uygulama fazında doğrulanacaklar (Sera'dan):** havuz sızıntısı, evrim yer değiştirmesi, çoklu isabet, boss itme bağışıklığı, duraklatmada zamanlayıcıların durması, deterministik hedef sırası, kalabalık performansı (Redmi Note 13 Pro; cihaz dışında doğrulanamaz), Bilenmiş Ağız çift çarpma yok.

---

## 7. Kullanıcıya kalan açık sorular (önerilerimle)

1. **S1 — Çeviklik:** joystick yönünde 0,25 sn +%25 hız yeterli mi, yoksa otomatik geri sıçrayış + kısa hasarsız pencere mi? *(Öneri: önce v1; cihazda zayıfsa v2.)*
2. **S2 — Çelik Siper:** savunma aktifi (toparlanma başında, ilk temas darbesini azaltır + karşılık) dahil mi? *(Öneri: dahil; zorunlu seçim olursa §3.1 ölçütüyle gözden geçirilir.)*
3. **S3 — Ad ve ton:** "Veyra / Son Ahit'in Nöbetçisi (the Last Oath-Warden)", sessiz cenaze muhafızı tonu uygun mu? Alternatifler: Sera, Nerya adları; daha saldırgan bir düellocu kimliği.
4. **S4 — Süzülen kılıç:** beklerken sürekli görünsün, hasarı seferlerle (hedef başına tek isabet) versin tasarımı yeterli mi, yoksa saldırı anında mı belirsin / sürekli mi vursun? *(Öneri: sürekli görünür + seferli hasar.)*
5. **S5 — Gökten düşen kılıç:** yakın dövüşle vurulmuş hedefe bağlı, sabit noktalı (kaçabilir) olması hoşuna gider mi, bağımsız mı? %30 altı için ×1,5 mi, anında ölüm mü? *(Öneri: yakın dövüş şartı + ×1,5.)*
6. **S6 — Ritim ve menzil:** 4 kesik ve 130 px (seviyeyle 145) mi, daha uzun kombo / daha uzun menzil (Nerya 170) mi?
7. **S7 — Pasif sayısı:** 6'ya indirmek için ortak havuzu karaktere göre filtrelemek (kod) mi, Mıknatıs dahil 7 ortak pasif mi? *(Öneri: kabul; filtre sonra.)*
8. **S8 — Kıyafet ve palet:** kısa yas ceketi + asimetrik omuz örtüsü + iki kumaş şeridi, palet ve tek efekt rengi (soğuk çelik beyazı) onaylı mı; daha törensel bir kıyafet mi?
9. **S9 — Erişim:** baştan açık (Zyfen gibi, Sera'nın varsayımı) mı, bir başarıma bağlı mı? *(Öneri: baştan açık.)*
10. **Cihaz notu (elde hissi):** prototipte Redmi Note 13 Pro'da menzil (130), toparlanma hız penceresi, Çelik Siper hissi, kalabalıkta efekt okunurluğu ve süzülen kılıç performansı kontrol edilecek. **Elde hissi şu an denetlenemedi.**

---

## 8. Hangi öğe nereden geldi ve neden

| Öğe | Kaynak | Neden |
|---|---|---|
| Ad Veyra / "Son Ahit'in Nöbetçisi" | Birleşik (Veyra) | Süreklilik; ad kullanıcı kararı (S3) |
| Cenaze muhafızı, mühürlü kılıçlar | Sera | İki yeteneği hikâyeye somut bağlar, dünyaya yakın |
| 4 kesik, 0,85 sn, menzil 130 → 145, can 95, hız 325 | Veyra + Sera arası | İki bağımsız Codex önerisi 4 kesikte birleşti; menzil seviyeyle büyür (Sera), Nerya'nın 5 kesik tercihi bırakıldı |
| Temel saldırı kuralları (100°, hedef sabit, kesik başına tek vuruş, hedef yokken kapasite yanmaz, 3 → 5 hedef) | Veyra + Sera | Test edilebilir, boşa kapasite yakmaz |
| Çeviklik v1: 0,25 sn +%25 hız, otomatik sıçrayış yok | Veyra + Sera | Sim'de konum değiştirme riskini v1'den çıkarır; iki öneri arası değer |
| Otomatik sıçrayış v2 deneyi | Nerya (birleşik üzerinden) | Atiklik için güçlü ama en riskli; kullanıcıya soruluyor |
| Son Hüküm: sabit nokta, en yüksek mevcut can, merkez + %40 çevre, boss'ta infaz yok | Sera | Kalabalıkta hasarı sınırlar, "kaçabilir" adalet verir |
| Son Hüküm: yakın dövüş şartı, ×1,5 (%30 altı) | Veyra (Codex) | Uzaktan öldürme aracı olmasın |
| Son Hüküm: 0,4 sn uyarı halkası | Nerya, Sera ortalaması | Mobil okunurluk; Veyra 0,45, Sera 0,35 |
| Nöbetçi Çelik: sürekli görünür süzülme + seferli hasar | Veyra (Nerya'nın sürekli görünürlüğü) + Sera | Kullanıcı brifi "yanında dönen"; hasar sınırı boss/Girdap riskini önler |
| Nöbetçi Çelik: ziyaret sırası (ziyaretsiz en yakın, eşitte düşük kimlik), tek sefer | Sera | Deterministik sim |
| Nöbetçi Çelik: 3 → 5 hedef | Veyra | Sera'nın 2 → 4'ü fazla zayıf, Veyra'nın 6'sı fazla cömert; evrimde 4 hedefe sınırlı |
| **Çelik Siper** (azaltma + karşılık) | **Sera**, VLAD notu | Savunma kimliği ekler, dokunulmazlık değil; zorunluluk riski §3.1 ölçütüyle izlenir |
| Kabza Payı (karşılık vuruşu) | Veyra, **Çelik Siper'e birleştirildi** | Aynı toparlanma anında iki ayrı aktif gereksiz |
| Son Çentik | Sera (Nerya'nın "kapanış kesiği" fikriyle örtüşür) | Ritme bağlı, ucuz, patlamasız; Dikiş Darbesi ayrı bir beceri olarak çıkarıldı |
| Kırık Yemin | Veyra | İşaret + ek hasar, yığılmaz; Açık Dikiş (yara) yeni durum sistemi gerektirdiği için bırakıldı |
| Pasif adları, Bilenmiş Ağız çift çarpma uyarısı | Veyra + Sera | Sıfır yeni sayısal pasif; ortak varyant; çift çarpma önlenir |
| Evrimler Kesin Hüküm, Sadık Çelik, Demir Sükûnet, Son Nokta | Sera (Kesin Hüküm değerleri uyarlandı) | Kılıç sayısını büyütmez, zamanlama belirginleşir; Veyra'nın Son Nöbet (6 hedef), Çifte Dikiş, Açılan Gedik bırakıldı |
| `melee` bot politikası (teğet hareket, bantlar, can < %50 `kite`) | Veyra + Sera | İkisi de aynı teşhisi koydu; bant iki öneri arası |
| Ölçüm tablosu (10/50/200, Lord'a hasar/dk, ölüm nedeni, Siper ölçütü) | Sera + yeni | Daha geniş; Siper zorunlu mu sorusu için ölçüt eklendi |
| Sayısal kabul bandı, Gunslinger ±%5 | Veyra (Nerya) + Sera hipotezi | Kabul ölçütü olmadan bot sonucu yorumlanamaz; Sera'nın %15–30'u "hipotez" olarak işaretli |
| Silüet (asimetrik omuz örtüsü, kumaş şeritleri) | Sera | Hareket okunurluğu |
| Palet hex, tek efekt rengi, ≤2 px sarsıntı, hareket azaltma | Veyra (Nerya + Codex) | Somut ve ölçülebilir; amber çok kısıtlandı |
| 19 / 25 hücre, ~327 px sınırı, kesik izi ayrı efekt, ilk kontrol | Sera + Veyra (Codex) | Genişlik riskini erkenden yakalar |
| Prototip kapısı, F-060 dört test, uygulama doğrulama listesi | Veyra + Sera | İkisi aynı; Sera'nın doğrulama listesi eklendi |
| Kullanıcı soruları (S1–S10) | Birleşik, daraltıldı | Her sorunun yanında öneri |

---

## 9. Varsayımlar ve doğrulanmayanlar

- Tüm sayılar öneridir; sim'de ölçülmedi, hiçbir test koşulmadı (yalnız Markdown).
- `agir_kursun`'un kılıç hasarına etkisi, `data_v202_pool.gd` ayrıntıları, `docs/design/v2.0.2/balance/` raporlarındaki 400 tohum gürültüsü iddiası ve test satır numaraları bu görevde **yeniden doğrulanmadı**.
- DPS bandı ve evrim çarpanları hipotezdir.
- Elde hissi denetlenemedi.
- Esin kaynağı eser adı kullanılmadı.
