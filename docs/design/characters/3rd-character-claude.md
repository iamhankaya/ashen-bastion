# 3. karakter önerisi — Vessa, Kıskaç Avcısı (Claude önerisi)

Durum: **öneri, kullanıcı onayı bekler.** Yalnız belge; kod, veri ve görsel yok. Codex A/B önerisi ayrı dosyadadır ve bu belge yazılırken okunmadı.
Hazırlayan: Game Director (T20261027-24). Tarih: 2026-10-27.

## 0. Neden bu karakter

Piyasa araştırması (`docs/review/market-research.md`, T20261027-06, `vlad/T20261027-06`) en sık şikâyeti "koşular birbirine benziyor" olarak buldu (örnekte 6/6 oyun) ve 3. karakteri "farklı oyun hissi" ile öneriyor (E3, öneri #3).

Bugün iki karakter de aynı fiili yapıyor: **düşmana doğru bir şey fırlatıyor.** Gunslinger kurşun, Zyfen rüzgâr kesiği atar; ikisi de "hedef seç → ateş et → şarjör bitince bekle" döngüsüdür. Farklı bir fiil gerekir.

Öneri: **düşmana değil, düşmanın gideceği yere hazırlık yapan** bir karakter. Oyuncu parmağıyla yalnız yürüdüğü için (otomatik ateş), karakterin gücü **nereye yürüdüğünden** çıkar. Bu, mevcut iki karakterden ayrı bir karar yeri açar: kurşunun nereye gideceğine karar verilemez, ama tuzağın nereye düşeceği ve düşmanın oraya nasıl yönlendirileceği oyuncunun yürüyüş çizgisiyle belirlenir.

Seçilen eksen: **tuzakçı avcı** (T20261027-07 oylama seçeneklerinden). Şövalye ve ruh çağıran rahip 7. bölümde kısa alternatif olarak durur.

## 1. Tema, ad, hikâye

| | |
|---|---|
| Ad (EN) | **Vessa, the Snare Warden** |
| Ad (TR) | **Vessa, Kıskaç Avcısı** |
| `id` | `vessa` |
| `display_upper` | `VESSA` |
| `blurb` (≤120) | "Tuzak kurar, sürüyü yönlendirir; kıskaçlar kapanınca kalabalık kıpırdayamaz." (76 karakter) |

**Hikâye (kısa).** Kale düşmeden önce Vessa surların altındaki kuyularda ve avlu kapılarında tuzak kuran bekçiydi; kapı bekçilerinin en alttaki, en az görüneniydi. Kale küle dönünce ölüleri yenmeye gücü yetmedi, ama onlardan **kaçmayı ve onları kaçırmayı** bildi. Her sürüyü bir yere sıkıştırmanın bir yolu olduğuna ve o yolun tek bir demir diş ile tek bir sağlam ayak izine bağlı olduğuna inanır. Bastion'a düşmanı yenmek için değil, **sürüyü doğru yere götürmek** için gelir.

**Ton uyumu.** Kısıtlı, kuru, işçi tavrı: gösterişli büyücü ya da kovboy değil; paslı demir, deri, kül. Mevcut dünyayla (taş-kahve palet, gotik/manhwa çizgi, karanlık fantastik) çelişmez. Büyü yoktur; mekanik düzeneklerle iş görür, böylece Zyfen'in doğaüstü diliyle de karışmaz.

## 2. Oynanış kimliği

### 2.1 Fiil: "kur, yönlendir, kapat"
Gunslinger: *vur*. Zyfen: *savur, topla*. Vessa: **kur → yönlendir → kapat.**

### 2.2 Temel saldırı — Demir Kıskaç (başlangıç becerisi `demir_kiskac`)
- Otomatik: menzildeki en kalabalık/yaklaşan kümeyi seçer; **hedefin önüne**, onunla kendisi arasındaki yola kıskaç bırakır (düşmanı vurmaz, yoluna koyar).
- Kıskaç 0,35 sn'de kurulur, bir düşman değince kapanır: hasar + **1,0 sn kök** (elit/boss'ta kök yerine %40 yavaşlatma, süre kısalmaz).
- Ömür 8 sn; tetiklenmezse kendiliğinden kaybolur.
- Yerleştirme menzili Gunslinger'dan kısa (`range` 520 önerisi); yani düşmana yakın oynar, ama temas ederek değil, **onun önünde yürüyerek**.

### 2.3 Şarjör karşılığı — "Kemer" (oyunun imza mekaniğinin çevirisi)
Oyunun imzası şarjör/yeniden doldurma ritmi. Vessa'da bu **kıskaç kemeri**dir:
- `mag_cap` 5 = kemerdeki kıskaç sayısı. Her yerleştirme bir kıskaç harcar.
- Kemer boşalınca **Kurma** (yeniden doldurma karşılığı, 1,5 sn): yeni kıskaç yerleştirilmez.
- **Çekiş kuralı (ritim kararı):** Kurma başlarken önceki döngüden hâlâ tetiklenmemiş kıskaçlar **ipten çekilip patlar** (%50 hasar, kök yok). Yani:
  - Tetiklenmeyen kıskaç boşa gitmez ama değeri düşer.
  - Oyuncu ister kıskaçların düşman tarafından tetiklenmesini bekler (tam hasar + kök), ister kemeri boşaltıp çekişi bilerek kullanır.
  - Kurma süresince en yakın düşmandan uzaklaşma kararı (kaçış penceresi) mevcut iki karakterdeki "doldurma anı" gerilimine denk gelir.
- `rhythm` etiketi: kemer/Kurma ile etkileşen beceriler bu etiketi taşır (içerik tamamlandı modunda ≥2 rhythm aktif şartı ayrıca sağlanır; bkz. 3.1).

### 2.4 Tek parmak, dikey ekran uyumu
- Girdi değişmez: ekrana dokun, sanal joystick, parmak kalkınca dur. Yeni düğme, çift dokunma, sürükle-bırak **yok.**
- Güç, yürüyüş çizgisinden çıkar. Üç kullanım örneği:
  1. **Daire çizerek kaçmak:** sürü peşinden gelirken kıskaçlar arkada kalır ve sürünün ön sırasını kökler.
  2. **Duvara yaslanıp bekleme:** kıskaçlar dar geçidi tıkar (harabeler yola yaklaştırır; dikey ekranda dar şerit bu davranışı güçlendirir).
  3. **Yem Feneri ile çekip kaçmak** (3.2 madde 5).
- Hareket ederken kıskaç bırakabilir (`action_while_moving: true`); Zyfen'deki gibi durup cast yapma zorunluluğu yoktur. Bu, tek parmak kontrolde "dur-bırak" cezasını kaldırır.

### 2.5 Mevcut iki karakterden ayrım

| | Gunslinger | Zyfen | **Vessa** |
|---|---|---|---|
| Fiil | vur | savur, topla | **kur, yönlendir, kapat** |
| Hasar nerede | hedefte | hedefin hattında (delici) | **hedefin gideceği yerde** |
| Karar | şarjör ritmi | doldurma/toplama anı | **nereye yürüdüğüm** |
| Güçlü zaman | erken-orta | geç (kaos) | **orta; kalabalık yoğun, dar alan** |
| Zayıf | zırhlı tek hedef | hareket halinde cast | **uçan düşman, tek tek koşan** |
| Menzil | 700 | 750 | **520** |

## 3. Yetenek havuzu

Havuz kimliği `pool: "vessa"`. Aktif/pasif kimlikleri Türkçe karaktersiz, mevcut adlandırmaya uygun. Sayılar öneridir; kesin değerler denge fazında ölçülür.

### 3.1 Aktifler (6)

| # | `id` | Ad | Davranış | Etiket | Mevcut havuzdan ayrım |
|---|---|---|---|---|---|
| 1 | `demir_kiskac` | Demir Kıskaç (başlangıç) | 2.2'deki temel kıskaç. Seviye: hasar, kök süresi 1,0→1,6 sn, yarıçap | rhythm | Yeni; kurşun/kesik değil, zemin nesnesi |
| 2 | `dikenli_tel` | Dikenli Tel | Yürürken arkada **2,5 sn kalan tel izi** bırakır; üstünden geçen düşman kanama (süreli hasar) alır | — | Hortum/Girdap kovalar ya da döner; bu **oyuncunun izini** silaha çevirir |
| 3 | `pusu_oku` | Pusu Oku | Atış yönünde kısa menzilli yaydan ok: **köklü veya uçan** hedefi önceler, köklü hedefe ×2,5 hasar | rhythm | Keskin Nişan "en dayanıklı"ya gider; bu **kıskaçla tamamlanan** hedefi seçer; uçanlara cevap (4.2) |
| 4 | `koz_tuzagi` | Köz Tuzağı | Her N. kıskaç kapanınca zemini yakar (birkaç sn yanan yama) | rhythm | Hava Cebi/Şarapnel ölümde tetikler; bu **kıskaç kapanışında** tetikler |
| 5 | `yem_feneri` | Yem Feneri | Bekleme süreli (≈12 sn): fener bırakır; yakın düşmanlar 3 sn fenere yönelir | — | Çeken/iten beceriler hasar vurur; bu **konumlandırma aracı** (hasarı kıskaç yapar) |
| 6 | `av_cukuru` | Av Çukuru | Uzun bekleme (≈20 sn): öne büyük çukur açılır; içindeki sıradan düşmanları eşiğin altındaysa yutar, elit/boss'a yüzde hasar | — | Geç oyun kararı: tek büyük kapanış; boss'a özel yüzde hasar |

### 3.2 Pasifler (6)

Yeni sayısal anahtar (kod) gerektirmemesi için mevcut pasif anahtarlarına bağlanır; `variants` ile Vessa'ya özel ad ve açıklama verilir (`pool: common` pasifte, `docs/data-schema.md` `variants`).

| # | Ad | Yol | Etki |
|---|---|---|---|
| 1 | Fazladan Kıskaç | `fazladan_mermi` varyantı | Kemer +1…+5 kıskaç (`mag_add`) |
| 2 | Hızlı Kurma | `hizli_doldurma` varyantı | Kurma süresi −%10…−%50 (`reload_time_mult`) |
| 3 | Ağır Diş | `agir_kursun` varyantı | Kıskaç/ok hasarı +%10…+%50 (`bullet_dmg_mult`) |
| 4 | Çevik Çizme | `cevik_cizme` (ortak, değişmez) | Hareket hızı +%6…+%30 |
| 5 | Av Gözü | özel `vessa` | Yerleştirme menzili +%…(`range_mult`) |
| 6 | Geniş Ağız | özel `vessa` | Kıskaç/çukur/yama alanı +%12…+%60 (`area_mult`) |

Sağlam Yelek, Mıknatıs, Keskin Nişan gibi ortak/diğer havuz seçenekleri olduğu gibi kalır; Vessa'nın 6 pasifi yukarıdaki listedir, ortak havuz ek seçenek olarak devam eder.

### 3.3 Evrim çiftleri (5; en az 4 şartı karşılar)

Evrim kuralı mevcut şemayla aynı: aktif seviye 5 + pasif seviye ≥1.

| # | Aktif + Pasif | Evrim | Etki |
|---|---|---|---|
| E1 | Demir Kıskaç + Fazladan Kıskaç | **Ölüm Kemeri** | Aynı kemerdeki kıskaçlar telle bağlanır; biri kapanınca yakındaki komşular da kapanır |
| E2 | Dikenli Tel + Çevik Çizme | **Kor Tel** | İz yanar, süre ve uzunluk hareket hızıyla artar (hızlı yürüyen çok iz bırakır) |
| E3 | Pusu Oku + Av Gözü | **Gölge Salvosu** | Ardışık 4 ok; her biri köklü/uçan hedefe gider |
| E4 | Köz Tuzağı + Geniş Ağız | **Cehennem Dişi** | Yanan yama komşu kıskaçlara atlar; alan büyür |
| E5 | Yem Feneri + Hızlı Kurma | **Karanlık Mıknatıs** | Fener düşmanı tutar; her kurma bitişinde fener sıfırlanır |

Av Çukuru bilerek evrimsizdir (geç oyun tek karar noktası olarak sade kalsın). Kesinti gerekirse E5 çıkarılır; 4 çift şartı korunur.

### 3.4 Havuz ayrımı özeti
- Aktiflerin hiçbiri mevcut Gunslinger veya Zyfen aktifini kopyalamaz; ortak davranış yalnız "zemine bırakılan nesne" kavramındadır (Hava Cebi benzeri), ayrıntıda farklıdır.
- Gunslinger ve Zyfen havuzları değişmez; Vessa becerileri `pool: vessa` ile onlara görünmez.

## 4. Denge niyeti

### 4.1 Temel değerler (öneri)

| Alan | Gunslinger | Zyfen | **Vessa** |
|---|---|---|---|
| `max_hp` | 100 | 85 | **95** |
| `move_speed` | 300 | 310 | **320** |
| `mag_cap` | 6 | 8 | **5** |
| `reload_time` | 1,0 | 1,3 | **1,5** |
| `range` | 700 | 750 | **520** |
| `pickup_radius` / `collision_radius` | 110 / 22 | 110 / 22 | 110 / 22 |

Gerekçe: yüksek hareket hızı, kısa menzil ve uzun Kurma birlikte "hareketle oyna" kararını zorlar; orta can, tek başına duran kıskaçlara güvenmeyi gerektirir.

### 4.2 Güçlü / zayıf

| Güçlü | Zayıf |
|---|---|
| Yoğun yer sürüleri (Çürümüş Piyade, Şövalye Hayaleti öbekleri) | **Uçan düşman** (Leş Kargası): kıskaç yalnız yer düşmanını tutar (varsayım, 5. bölüm); Pusu Oku, Dikenli Tel dışı cevap yok |
| Dar alan, harabe yanı, geçit | Açık alanda erken oyun: ilk dakikada DPS düşük (kıskaç düşmanı bekler) |
| Elit/boss'u yavaşlatıp oyuncunun kaçış alanını yönetmek | Tek hızlı hedef (kıskaç ıskalanır) |
| Hareketle birlikte büyüyen güç (Kor Tel, tel izi) | Oyuncu durursa hasar çıkışı düşer (kendi kendine öğreten ceza) |

Denge niyeti: **ilk 3 dk Gunslinger'dan zayıf, 5–12 dk eşit ya da hafif üstün, 12+ dk yoğun alanlarda belirgin güçlü; ama uçanlarda sınırlı.** Böylece "koşu aynı hissediyor" şikâyetinin karşılığı yalnız kozmetik değil, **zayıf yanı olan**, bu yüzden farklı yol seçtiren bir karakter olur.

### 4.3 Sim'de ölçüm (`ab-denge-olcumu` hattı)
1. **Gunslinger ±%5 kanıtı:** `kills5`, `hp_early`; tohum A 1001–1060, B 2001–2060 (taban değişmez). Vessa ekleme Gunslinger'ı kaydırmamalı.
2. **Vessa DPS bandı:** `tools/balance/dps_density.gd` ve `test/long/test_ver_v202_band.gd`; hedef bant Gunslinger'a göre: 5. dk `kills5` %65–85, 10. dk %90–110, 15. dk %105–130. (Bantlar öneri; Zyfen için ölçülen bandın aynı aralıkları ilk veri olarak okunur.)
3. **Bot politikası:** `tools/balance/mid_run.gd` `PRIORITY_BY_CHAR` satırı; kıskaç için `kite` politikası (daire çizerek kaçış) varsayılan, `strong` ikincil. Bot yürüyüş çizgisi karakterin gücünü belirlediği için bot "yerinde duran" olursa Vessa hep zayıf çıkar; ölçümün geçerliliği için bot hareket kalitesi önce doğrulanmalı (ana risk).
4. **Yeni ölçütler (bilgi amaçlı):** kıskaç tetiklenme oranı (kapanan/yerleştirilen; hedef %55–75), çekişle patlayan oran, uçana karşı hasar payı. Bu üçü karar ölçütü olmaz.
5. **Lord bütçesi:** `tools/balance/lord_budget.gd`; Kale Lordu'na kök yerine yavaşlatma uygulandığı doğrulanmalı.
6. **Altın hash:** Vessa için yeni aşama kaydı; Gunslinger kayıtları değişmez.

## 5. Görsel ve animasyon brifi

### 5.1 Silüet ve tanınırlık
- **Silüet:** geniş omuzlu, hafif çömelmiş; sırtında **demir diş kemeri** (5 kıskaç; kemer doluluğu = `mag_cap`, gözle okunur). Kısa pelerin ya da deri önlük; eller dolu (zincir/halka), omuza asılı yay.
- Gunslinger'ın uzun paltosundan ve Zyfen'in uzun paltosu/rüzgâr silüetinden ayrılır: **kısa ve geniş**, yere yakın.
- Duruş yüksekliği `display_height` 200, mevcut ikisiyle aynı ölçek.

### 5.2 Palet
- Ana: kül grisi deri, pas turuncusu (demir dişler), koyu kahve. Vurgu: sönük sarı fener ışığı (Yem Feneri ile eşleşir).
- Mevcut taş-kahve zeminden ayrışsın diye çok doymuş renk yok; pas turuncusu tek canlı renktir ve kıskaçlarla aynı tonda tutulur (oyuncu karakteri ve tuzağı aynı renkten tanır).

### 5.3 Kareler (`ab-animasyon-seridi`, tek parça gövde)
Zyfen yöntemi: tek parça gövde, `rig.armless: true`, hücre yüksekliği 320, toplam şerit ≤ 8192.

| Klip | Kare | Not |
|---|---|---|
| Yürüme | 8 | Yan görünüm, hafif çömelik yürüyüş; video → ffmpeg → yeşil silme |
| Duruş | 1 | Kemer görünür |
| Cast (kıskaç bırakma) | 6 (`fire_frame` 3, 24 fps) | Eğilip yere bırakma; **hareket halinde de çalışmalı** → isteğe bağlı `walk_cast` klibi (hat bunu destekler, `action_while_moving: true`) |
| Gather (Kurma) | 4 | Kemere yeni dişleri dizme |

Toplam ≈ 19 hücre (Zyfen ile aynı). Atış noktası `cast_point` el hizasında, yere yakın (Zyfen `[0.375, -0.305]` ters yönde; ölçüm: avuç/el pikseli).

### 5.4 Efekt/kıskaç görseli (görsel üretim fazı)
Kıskaç, yarı kapalı/açık/kapalı 3 durum; kurulum halkası (0,35 sn); kök göstergesi (düşman ayağında demir halka). Yama (Köz Tuzağı), tel izi (Dikenli Tel) shader/kod ile (`ab-efekt-shader`), ayrı sprite şart değil.

### 5.5 Üretilebilirlik
Hat Zyfen'de kanıtlı; yeni araç gerekmez. Bilinen sınır: tek `cast_point` (iki el bağımsız değil) — Vessa tek elle bırakır, **sorun yok.** Dikkat: yürüme videosunda çömelik duruş ayak çapasını (`--align feet` ≤ ±24 px) zorlayabilir; üretimden önce `--preview` ölçümü.

## 6. Maliyet ve risk

### 6.1 `ab-karakter-ekle` hattına uygunluk
Hat tek parça gövdeyi önerir; Vessa tamamen bu hatta oturur (parçalı rig gerekmez). Adımlar 1–12 uygulanabilir.

### 6.2 Karakter listesini sabitleyen testler (F-ashen-bastion-060)
Yeni karakter eklendiğinde şu 4 test kırmızı olur ve beklenen değerler yeni karaktere göre güncellenir (kusurlu davranışı değil sayıyı):
1. `test/unit/test_character_roster.gd` — `test_ids_follow_order_field`
2. `test/unit/test_characters_screen.gd` — `test_f030_gunslinger_first_by_order_field`
3. `test/acceptance/test_acc_v2_chars.gd` — `test_k10_single_character_set_works`
4. `test/unit/test_v202_pool_real.gd` — `test_empty_character_id_keeps_old_unfiltered_behavior`

Ek: `tools/gate_min_tests.json`, `tools/balance/mid_all.sh` `CHARS`, altın hash kaydı. Bu liste hattın mevcut skill'inden alındı; güncel sayı uygulama sırasında yeniden doğrulanır.

### 6.3 Efor ve risk tablosu

| Kalem | Efor | Risk | Not |
|---|---|---|---|
| Veri (karakter + 6 aktif + 2 özel pasif + 3 varyant + 5 evrim) | M | Düşük | Şema hazır; `variants` yeni kod istemez |
| **Yeni davranışlar** (`SkillBehavior`: kıskaç nesnesi, tel izi, çukur, fener) | **L** | **Yüksek** | Mevcut iki karakterden farklı olarak **zemin nesnesi + tetikleme + kök** gerekir; kök durumu (düşman hareketi) sim'e dokunur |
| Kök/yavaşlatma altyapısı | M | Orta | Elit/boss ve uçan/hayalet düşmanla etkileşim kuralı |
| Sim determinizmi / altın hash | S | Orta | Yeni nesne sıralaması deterministik olmalı (`String` sıralama uyarısı) |
| Görsel + animasyon (portre, şerit, kıskaç ikonu, 6+6+5 ikon) | L | Orta | Hat kanıtlı; ikon sayısı fazla (17 yeni ikon) |
| Ses | M | Düşük | `sfx` sözlüğü + beceri `cast_sfx`; evrim sesleri `evolution_9…` (Zyfen 5–8 aldı) |
| Denge ölçümü | M | **Yüksek** | Bot "durarak oynarsa" Vessa yapay zayıf çıkar |
| Kilit (isteğe bağlı) | S | Düşük | `unlock.achievement`; D-3 kararı bekliyor |

**Toplam:** Zyfen'den daha pahalı (Zyfen de yeni rüzgâr davranışları getirdi, ama kıskaç sistemi sim'e yeni bir **kalıcı zemin nesnesi + düşman durumu** ekler). Tahmin: Zyfen eforunun 1,3–1,6 katı (**varsayım**, ölçülmedi).

### 6.4 Açık varsayımlar (doğrulanmadı)
- Leş Kargası (`air`) ve Elit Karga'nın kıskaçtan etkilenmeyeceği; Şövalye Hayaleti (`ghost`) için kuralın ne olduğu veri/koddan okunmadı. Kök durumunun `ground` dışında nasıl davranacağı tasarım kararı bekler.
- Elit/boss'a kök yerine %40 yavaşlatma kuralı denge niyetidir; mevcut kodda elit için "bağışıklık" mekanizması var mı bakılmadı.
- Dikey ekranda kıskaç görünürlüğü ve parmağın karakteri örtmesi **elde hissi** olarak denetlenemez; cihaz notu gerekir.
- Esin kaynağı adı hiçbir yerde kullanılmadı; yasaklı ad denetimi (`tools/ci/check_forbidden_names.sh`) uygulamada koşulmalı.

## 7. Alternatif konseptler

**A. Nöbetçi Şövalye — Kale Nöbetçisi "Ordan" (yakın dövüş / siper).** Kalenin son nöbetçisi; kalkanı ve ağır kılıcıyla yürüyen bir siper. Temel saldırı, yürürken etrafında sallanan kılıç yayı; şarjörün karşılığı "Soluk" göstergesi: dolu iken vuruşlar sertleşir, boşalınca 1,2 sn kalkan kaldırıp savunmaya geçer (hasarı azaltır, vuramaz). Tek parmak uyumu: yön, kılıcın baktığı yayı belirler; düşmana yaklaşmak güçtür, kaçmak zayıflıktır — mevcut iki menzilli karakterin tam tersi. Zayıf: uçan ve uzaktan vuran düşman. Risk: yakın dövüş için çarpışma/itme ve temas hasarı dengesi; sim ve bot için en zor ölçüm. Görsel: ağır zırh silüeti, hat uygun (tek parça gövde).

**B. Ruh Çağıran Rahip — "Maren" (yardımcı çağırma).** Düşenlerin ruhlarını kandil ışığıyla toplayan rahip. Temel saldırı yok denecek kadar zayıf; **öldürülen düşman bir ruh bırakır**, ruhlar Maren etrafında döner ve şarjör dolunca ("Dua" ritmi) hedefe salınır. Tek parmak uyumu: ruhları toplamak için ölüm olan yere yürümek gerekir (risk-ödül hareketi). Fark: güç, düşman ölümüne bağlı (sürü büyükse güçlüdür, boş ekranda zayıf). Risk: Şarapnel/Hava Cebi gibi ölüm-tetikli becerilerle mekanik örtüşme ve ruh nesnelerinin sim yükü. Görsel: uzun cüppe, Zyfen'in uzun silüetine yakın olduğu için ayrışma çabası gerekir.

## 8. Kullanıcı kararı bekleyenler

1. Vessa (kıskaç) mı, alternatiflerden biri mi?
2. Kök mekaniği: elit/boss'ta yavaşlatma kuralı onayı.
3. Uçan düşmana karşı cevap: yalnız Pusu Oku (önerilen) mi, kıskacın uçanı da tutması mı?
4. Kilit: baştan açık mı, başarıma bağlı mı?
5. Sayılar (4.1 temel değerler) yalnız öneridir; denge fazında ölçülerek ayarlanır.
