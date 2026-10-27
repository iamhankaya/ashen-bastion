# Kılıçlı çevik kadın karakter — tasarım önerisi (Claude)

Tarih: 2026-10-27 · Durum: **öneri, kullanıcı onayı bekliyor** · Görev: T20261027-27 (A/B: aynı brifle ayrı bir Codex önerisi var; bu belge onu görmeden yazıldı)
Kapsam: yalnız belge. Kod, veri dosyası ve görsel yok.

Dayanak: `data/characters/{gunslinger,zyfen}.json`, `data/skills/*.json`, `data/enemies/curumus_piyade.json`, `scripts/sim/damage_system.gd`, `test/helpers/bots.gd`, `docs/design/v2.0.2/2026-10-24-zyfen-design.md`, `.claude/skills/ab-karakter-ekle/SKILL.md`. Sayılar bu dosyalardan okundu; "öneri" yazanlar tahmindir ve sim'de ayarlanır. "Barutçu olmayacak" kararı (2026-10-24) korunur.

---

## 1. Tema, ad, hikâye

| Alan | Öneri |
|---|---|
| Ad | **Nerya** (Zyfen ve Gunslinger gibi tek ad) |
| Unvan (TR) | **Son Nöbetçi** |
| Unvan (EN) | **The Last Warden** |
| Cinsiyet / yaş | Kadın, 20'lerinin sonunda |
| Silah | Tek, dar ve düz, tek elle kullanılan uzun kılıç; kın belinde |
| Ton | Kederli, kararlı, sessiz; gösterişsiz bir profesyonel |

**Kısa hikâye çekirdeği.** Kale düşmeden önce Nöbetçi Birliği, surların üstünde yüz kılıçla gece boyu nöbet tutardı. Kale karardığında birlik tek tek düştü; Nerya en genç nöbetçiydi ve ayakta kalan tek kişi oldu. Kılıçlarını yerde bıraktı, birini aldı. Her kesik dizisinden sonra kılıcını kınına sokar, "nöbet değişti" der gibi. Düşen yoldaşlarının kılıçları ona cevap verir: gökten inen ve çevresinde dönen kılıçlar, ölü birliğin son nöbetidir. Zyfen'in Lord'la ilişkisine paralel ama farklı bir yük: Zyfen bir dostu kurtarmaya, Nerya bir yemini bitirmeye gelir (hikâye tonu; derin yazım sonraya).

**Dünyaya uyum.** Palet kemik beyazı, bronz, koyu bordo ve kül grisi; mevcut gotik/manhwa çizgisi (konturlu, cel-shading) korunur. Zyfen soğuk yeşilimsi beyaz rüzgar, Gunslinger sıcak barut turuncusu taşır; Nerya'nın **imza rengi soğuk çelik beyazı + tek damla bordo** (bkz. §5), ikisiyle karışmaz.

---

## 2. Oynanış kimliği

Karakter fantezisi: **"Yaklaş, kes, sıyrıl."** Gunslinger uzaktan ateş eder, Zyfen alan/rüzgâr yönetir; Nerya risk alıp yakından vuran, hareketi ritmini belirleyen karakterdir.

### 2.1 Temel değerler (öneri; dengeleme fazında ölçülerek ayarlanır)

| Değer | Gunslinger | Zyfen | **Nerya** |
|---|---|---|---|
| Can (`max_hp`) | 100 | 85 | **90** |
| Hareket hızı | 300 | 310 | **325** |
| Dizi uzunluğu (`mag_cap`) | 6 | 8 | **5 kesik** |
| Kına koyma (`reload_time`) | 1,0 sn | 1,3 sn | **0,9 sn** |
| Menzil (`range`) | 700 | 750 | **170** |
| Temas yarıçapı | 22 | 22 | 22 |

Menzil gerekçesi: Çürümüş Piyade yarıçapı 26, oyuncu 22; temas ~48 px merkez mesafesinde başlar. 170 px, temasın yaklaşık 3,5 katı: düşmana değmeden vurulur ama 700 px'in rahatlığı yok.

### 2.2 Temel saldırı — Kenar Kesiği (menzil ve risk yönetimi)

- Tek parmak joystick, otomatik atış korunur: Nerya, menzilindeki **en yakın düşmana** kendiliğinden kesik atar (hilal şeklinde, ~110° yay).
- Kesik anında **kısa otomatik adım** (~40 px, 0,08 sn) düşmana doğru kayar; "yaklaş" hissini oyuncunun elinden almadan verir. Adım duvar/harabe çarpışmasına uyar.
- **Risk modeli:** menzil kısa olduğu için temas hasarı gerçek bir bedel. Kodda temas hasarı `CONTACT_INTERVAL = 0,6 sn`, tick başına en çok 4 temas, Çürümüş Piyade `dmg: 6`. Kalabalığın içinde teorik üst sınır ~40 can/sn; 90 canı ~2,3 sn'de eritir. Oyuncu "ne zaman girip çıkacağını" joystick'le seçer; sistem girişi kolaylaştırır, çıkışı ritim verir (§2.4).
- Kesik tek düşmanla sınırlı değildir: yay içindeki tüm düşmanlara değer (kalabalıkta ödül) ama delmez (arkadan vurmaz).

### 2.3 Çeviklik — hareket kontrolü eklemeden atılma/kaçış hissi

Yeni tuş yok; çeviklik **otomatik** ve **ritme bağlı**:

1. **Kesik adımı** (yukarıda): her kesik hafif ileri kayar.
2. **Sıyrılma:** dizi bitip kına koyma başlayınca Nerya, en yakın düşman kümesinden **otomatik geri sıçrar** (~140 px, 0,18 sn) ve bu pencerede **temas hasarı almaz** (öneri 0,2 sn; sim'e dokunan karar, bkz. §7 S1). Kaçış joystick'e bağlı değil; yönü "kümeden uzağa", engel varsa teğet.
3. Hareket hızı 325 ile en yüksek temel hız; joystick sürekli serbest. Oyuncu otomatik sıçrayışın yönünü joystick eğimiyle hafifçe bükebilir (öneri; sim'e dokunur, §7 S2).

Böylece "atılma" ve "kaçış" iki ayrı komut olmadan, **şarjör ritminin iki yarısı** olur.

### 2.4 Şarjör/ritim karşılığı — Nöbet Dizisi (imza mekanik)

Oyunun imzası şarjör/doldurma ritmidir; Nerya'da karşılığı:

| Gunslinger/Zyfen | Nerya |
|---|---|
| Şarjör (6 / 8 mermi) | **Dizi:** 5 kesik |
| Doldurma (1,0 / 1,3 sn) | **Kına koyma + sıyrılma** (0,9 sn) |
| Doldurma sırasında savunmasız | Kına koyarken **geri sıçrar, temas hasarı yok** |

- Riskin zamanlaması: **saldırı fazı** yakındır (hasar alınabilir), **kına fazı** güvenlidir. Oyuncunun öğreneceği ritim: "5 kes, çık, tekrar gir".
- Dizi sonu hissi: 5. kesik biraz daha geniş ve güçlüdür (**kapanış kesiği**, ×1,3 hasar, +20° yay); kına çıt sesi ritmi duyurur.
- Pasifler ritmi besler (Uzun Dizi +kesik, Çabuk Kın daha kısa kına).

---

## 3. Yetenek havuzu

Kural: *değer artıranlar ortak, ekranda bir şey yapanlar karaktere özel* (Zyfen tasarımı §6.3). Nerya için de geçerli.

Yapı Zyfen'le aynı: **temel saldırı (başlangıç becerisi) + 6 aktif + 6 pasif + 4 evrim çifti.** Başlangıç becerisi `kenar_kesigi` (Nerya havuzlu aktif; `ab-karakter-ekle` kuralı: başlangıç becerisi karakterin kendi havuzundan olmalı).

### 3.1 Aktifler (6)

Sayılar `levels[]` biçiminde 5 seviye; aşağıdaki L1 → L5 aralıkları öneridir (mevcut becerilerle ölçek karşılaştırması §3.4).

| # | Ad | Etki | L1 → L5 |
|---|---|---|---|
| 1 | **Gökten Düşen Kılıç** *(kullanıcı fikri)* | Düşman **kümesinin** üzerine kısa bir uyarıdan sonra tek kılıç iner; küçük alanda büyük hasar, infaz hissi: **can oranı ≤ %25 olan sıradan düşman** (boss/elit hariç) anında ölür | bekleme 5,0 → 3,4 sn; hasar 70 → 160; yarıçap 60 → 80 px; uyarı 0,6 sn |
| 2 | **Süzülen Kılıç** *(kullanıcı fikri)* | Nerya'nın yanında süzülen kılıç(lar); düşmana doğru **gezinir**, vurur, geri döner. İtme/çekme yok, nokta hasar | 1 kılıç → 2 kılıç; hasar 7 → 13; düşman başına vuruş aralığı 0,45 → 0,35 sn; gezinme menzili 260 → 320 px |
| 3 | **Sıyrılma Kesiği** | Sıyrılma sıçrayışı sırasında geçtiği çizgiyi keser (kaçışa saldırı katar) | hasar 14 → 30; çizgi genişliği 36 → 56 px |
| 4 | **Hilal Savuruşu** | Her 3. kesik, 360° geniş bir savuruş olur (kuşatılınca çıkış açar) | her 3. → her 2. kesik; hasar ×1,0 → ×1,5; yarıçap 120 → 170 px |
| 5 | **Karşı Kesik** | Temas hasarı alınca bir sonraki kesik otomatik **karşılık** olur: daha geniş, hasarı ×2 (riske ödül) | yeniden hazır olma 4,0 → 2,2 sn; hasar çarpanı ×1,8 → ×2,6 |
| 6 | **Kın Darbesi** | Kına koyarken kılıç yere vurur: kısa şok halkası, yakındakini iter ve yavaşlatır (kaçış fazı savunmasız kalmasın) | yarıçap 90 → 140 px; itme 80 → 160; yavaşlatma %20 → %40, 1,0 sn |

### 3.2 Pasifler (6)

Ortak havuz `pool: "common"` bir alt küme olarak seçilemez (`data_v202_pool.gd`: `pool` ya `common` ya karakter kimliği); yani yedi ortak pasifin hepsi her karakterde zaten gelir. Öneri: altı "kimlik pasifi"ni **ad/ikon varyantıyla** (`variants.nerya`) yeniden yorumlamak, biri karaktere özel:

| # | Ad | Tür | Etki |
|---|---|---|---|
| 1 | **Hafif Adım** | ortak varyantı (Çevik Çizme) | hız +%6 / seviye |
| 2 | **Seri Bilek** | ortak varyantı (Hızlı Parmak) | kesik hızı +%8 / seviye |
| 3 | **Çelik Kaban** | ortak varyantı (Sağlam Yelek) | +15 can, +0,25 can/sn / seviye |
| 4 | **Çabuk Kın** | ortak varyantı (Hızlı Doldurma) | kına süresi −%10 / seviye |
| 5 | **Uzun Dizi** | ortak varyantı (Fazladan Mermi) | dizi +1 kesik / seviye |
| 6 | **Keskin Kenar** | **özel** | kılıç hasarı +%10, kesik menzili +8 px / seviye |

Not: Ağır Kurşun ve Mıknatıs da ortak olduğu için havuzda kalır (isteğe bağlı varyant adı: *Ağır Kenar*, *Toplayan El*); toplam 8 pasif görünür. 6'ya indirmek ortak havuzu karaktere göre filtrelemeyi gerektirir (kod; §7 S6). Ağır Kurşun'un `bullet_dmg_mult` alanı kılıç hasarına etki etmeli; yoksa o varyant etkisiz kalır (kodda doğrulanmadı, varsayım).

### 3.3 Evrim çiftleri (4)

Kalıp mevcut: aktif seviye 5 + pasif en az seviye 1 (`evolves_from`: `active`, `active_level`, `passive`, `passive_min_level`).

| Evrim | Aktif (L5) | Pasif | Etki |
|---|---|---|---|
| **Nöbet Yağmuru** | Gökten Düşen Kılıç | Keskin Kenar | Aynı anda değil, **arka arkaya 3 kılıç** üç ayrı kümeye iner (aralık 0,25 sn); infaz eşiği %30 |
| **Çember Nöbeti** | Süzülen Kılıç | Seri Bilek | 3 kılıç; her 3. kesikte kılıçlar hedefe atılıp geri döner |
| **Gölge Çizgisi** | Sıyrılma Kesiği | Hafif Adım | Sıçrayış çizgisi 0,8 sn kalır, içinden geçen düşman hasar alır |
| **Tam Daire** | Hilal Savuruşu | Çabuk Kın | Savuruş iki kez (0,15 sn arayla); ikincisi dışarı doğru iter |

Karşı Kesik ve Kın Darbesi evrimsiz kalır (sayı 4, `ab-beceri-ekle` hattı en az dörttür); ileride 5.–6. çift eklenebilir.

### 3.4 Gunslinger, Zyfen ve mevcut havuzla ayrım

Ölçek karşılaştırması (aynı seviyede; veriden):

| Beceri | Karşılaştırma | Fark |
|---|---|---|
| Gökten Düşen Kılıç L1: 70 hasar / 5,0 sn / 60 px | Delen Rüzgar L1: 80 / 3,2 sn tek hedef; Keskin Nişan L1: 90 / 3,0 sn tek hedef | Onlar **tek hedef** (en dayanıklı); bu **alan** + uyarı daireli + infaz eşiği. Ortalama DPS daha düşük, kalabalıkta daha yüksek |
| Süzülen Kılıç L1: 7 hasar, 0,45 sn | Girdap L1: 6, 0,5 sn, yarıçap 90 | Bkz. aşağıda |
| Hilal Savuruşu: yakın 360° | Hava Bıçakları: uzak yelpaze mermi | Yakın temas vs. mermi |
| Kın Darbesi: itme + yavaşlatma | Nefes Dalgası: itme (rüzgar toplamada) | Aynı tetik (doldurma), farklı etki: Nerya yavaşlatma ekler, boy daha küçük (140 vs 320 px) |

**Zyfen çakışması (özellikle alan/dönen etkiler).** Zyfen'in dönen/alan seti: Girdap (çevrede dönen hava halkası, itme), Hortum (gezen çekim alanı), Hava Cebi (ölünce çeken küçük alan), Nefes Dalgası (ekran büyük dalga), Tufan/Göğün Mızrağı (gökten mızrak!). Ayrım kuralları:

1. **Süzülen Kılıç ≠ Girdap.** Girdap *sürekli bir halka* (yarıçap 90–135, düşmanları **iter**, alan hasarı). Süzülen Kılıç *ayrı fiziksel cisim*: 1–2 nokta, sabit halkada dönmez, **hedefe doğru gezinip geri döner**, itme/çekme **yok**, ekran kaplamaz. Sim'de ayrı davranış (`suzulen_kilic`); `WindUtil` ve rüzgâr alanı kodunu paylaşmaz.
2. **Gökten Düşen Kılıç ≠ Göğün Mızrağı/Delen Rüzgar.** Onlar anında, en yüksek canlı düşmana, çizgi boyunca **deler**. Bu: **zemin işaretli kümeye** gecikmeli, **alan** darbesi, delmez. Ad ve ses farklı ("mızrak" geçmez).
3. **Alan çakışması önlemi:** iki karakterin becerileri aynı koşuda karışmaz (havuz karaktere bağlı); yine de ekranda ayırt edilsin diye Nerya efektleri **çelik beyazı**, Zyfen'inkiler yeşilimsi beyaz (§5).
4. **Gunslinger'dan ayrım:** Keskin Nişan (tek atış infaz) ile Gökten Düşen Kılıç'ın "infaz" tonu benzer; fark menzil/hedefleme (kılıç yakın kümede, nişan en dayanıklıda). Barut/patlama dili Nerya'da **yok** (patlama yerine tok darbe + toz).

---

## 4. Denge niyeti

**Niyet:** yakın dövüşçü, bot sim'inde **Gunslinger'ın ±%5 kanıtını bozmadan** (mevcut kabul ölçütü: `kills5`, `hp_early`) ve Zyfen/Gunslinger'dan düşük-yüksek bir bantta durur: risk aldığı sürece **onlardan fazla** öldürür, risk almazsa **belirgin geride** kalır.

- **Risk/ödül:** menzil 170 vs 700; karşılığında hız +%8, kalabalıkta yay hasarı (birden çok düşman tek kesikte), Karşı Kesik ×2 ödülü, ve sıyrılma pencerelerinde güvende olma.
- **Ödül ekonomisi:** DPS hedefi, dizi/kına döngüsünde (5 kesik + 0,9 sn) Gunslinger'ın çift tabancasının **%85–95'i** (tek hedefte) ve **%110–130'u** (3+ düşmanlı kümede). Gökten Düşen/Süzülen yetenekleri bu bandı belirli seviyede tamamlar.

**Botlar uzak mesafe tutuyor.** `test/helpers/bots.gd` `_kite_dir`, `THREAT_RADIUS` içindeki düşmanlardan **uzaklaşır** (kite/strong/greedy hepsi dayanır; `mid_run.gd` `strong` de tehdit varsa kaçar). Böyle bir bot Nerya'yı hiç menzile sokmaz; ölçüm yanıltıcı olur (ya hiç öldürmez ya tutarsız). Yakın dövüşçü için **politika gereği:**

1. **Yeni politika `blade` (yakın dövüşçü botu):** düşman kümesine doğru ilerle; menzile girince dur/dön; **dizi bitince (kına fazı)** sıyrılmaya izin ver, sonra tekrar kümeye dön; can < %50 ise `kite`'a geç. Karar tamamen sim durumundan (determinizm korunur; rastgelelik yok).
2. **Her karakter kendi politikasıyla ölçülür.** `PRIORITY_BY_CHAR` zaten karakter satırı kabul ediyor (`mid_run.gd`); `ab_run.gd`/`mid_run.gd` politika argümanına `blade` eklenir.
3. **Ölçümler:** `kills5`, `hp_early` (Gunslinger kıyası), ayrıca **yeni metrikler:** temas hasarı / öldürme, menzilde geçen sürenin oranı, sıyrılma penceresinde engellenen hasar, kına fazında alınan hasar (sıfıra yakın olmalı), 10/15/20. dk can eğrisi.
4. **Kabul bandı (öneri):** `blade` politikasında Nerya `kills5` ≥ Gunslinger `kite` değerinin %90'ı, ≤ %130'u; `hp_early` Gunslinger'dan **daha düşük** (risk primi) ama koşuyu bitirebilir; `kite` politikasında ise Nerya Gunslinger'ın en fazla %60'ı (uzaktan oynamak ceza). Bandın dışı → önce katsayılar (`damage`, `range`), sonra becerilere.
5. **Dürüst sınır:** sim temas hasarını ve sıyrılmayı ölçer; **elde hissi** (menzil kısa gelir mi, otomatik adım rahatsız eder mi, kalabalıkta okunurluk) ölçülemez: kullanıcıdan cihaz notu istenir (§7).

---

## 5. Görsel ve animasyon brifi

### 5.1 Silüet ve palet

- **Silüet:** zayıf, yüksek belli, sade; dar kılıç; başın arkasında **savrulan at kuyruğu**; kısa, sağ omuzdan çapraz asılı **bordo kuşak** (tek renk damlası). Uzun palto yok (Zyfen'in silüetiyle karışmasın): kısa, parçalı kemer üstü deri ceket ve hafif plaka bilek/dirsek koruması.
- **Palet:** kül grisi (ceket), kemik beyazı (kuşak altı, kılıç kabzası), bronz (toka/koruma), **bordo** (kuşak), kılıç ve efektlerde **soğuk çelik beyazı** (#DCE6EE civarı; yeşil rüzgârla karışmaması için mavi kayık). Gunslinger turuncusu ve Zyfen yeşili kullanılmaz.
- **Yüz:** manhwa çizgisi, sakin, ifadesiz; saç koyu kestane/siyah.

### 5.2 Kareler ve üretim hattı

`ab-animasyon-seridi` / `ab-karakter-ekle` hattı (tek parça gövde, kolsuz rig yok; `rig.armless: true`); hücre 320 px yükseklik, `display_height` 200; şerit ≤ 8192 px genişlik.

| Klip | Kare | Not |
|---|---|---|
| Duruş | 1 | |
| Yürüme | 8 | hızlı adım, `stride` videoya kalibre (öneri ~125) |
| Cast (**Kenar Kesiği**) | 6 | `fire_frame` 2, `fps` 30; kılıç gövde karesinin içinde |
| Gather (**kına + sıyrılma**) | 4 | kılıcı kına sokma → geri sıçrama pozu |

- Hat: **referans görselden düz yeşil arka planlı kısa video → ffmpeg → yeşil silme** (kart çalışma notu: görsel üreticiler yan görünümde bacak sırasını çizemez; kare kare çizim yok). Kılıç ince; yeşil kenar halesi (fringe) riski var: kılıç gövde karesinde kalır ama süzülen/düşen kılıçlar **ayrı tek sprite** olur (§5.3).
- Portre: `ab-gorsel-ikon-uret` kuralları, 1024×1536, tam sahne, **bu fazda üretilmez**.
- Aynalama: sola bakışta `cast_point` x aynalanır (mevcut davranış); kılıç elinin tarafı bu yüzden sağ elde sabit, aynalamada kuşak tarafı değişir (kabul).

### 5.3 "Ölçülü gösteriş" efekt dili

İlke: **tek renk, kısa süre, küçük ekran payı, tok ses.** Bloom/ışık bombardımanı yok.

- **Gökten Düşen Kılıç:** (1) kümenin altında 0,6 sn **ince çelik beyazı halka** (alan yarıçapı kadar, alfa nabzı, dolgu yok); (2) kılıç **tek hat** halinde 0,08 sn'de iner (uzun, dar sprite; ince iz); (3) çarpışma: 2 karelik beyaz parlama + yere **çatlak çizgi** + az toz; **ekran sarsıntısı ≤ 2 px / 80 ms**; (4) kılıç 0,6 sn zeminde saplı kalıp solar (yalnız görsel). Aynı anda ekranda taban halinde en çok 1; evrimde 3 (ardışık).
- **Süzülen Kılıç:** ~24×96 px tek sprite; kod ile döner; **arkasında 6 örnekli solan iz** (0,2 sn); vurunca küçük kıvılcım yok, yalnız hit flaşı (mevcut). Parıltı/kor yok.
- **Kenar Kesiği:** ince hilal, 0,12 sn; Kapanış kesiği biraz geniş ve 1 kare uzun.
- **Sıyrılma:** 2–3 soluk hayalet (afterimage) kare; **toz yok**.
- Hepsi **kod/shader** (proje kararı: efektler kodla), yeni doku gerekmez; yalnız kılıç ve ikonlar sprite.

İkonlar: temel saldırı + 6 aktif + 1 özel pasif + 5 varyant pasif ikonu + 4 evrim ikonu (**17 ikon**; `ab-gorsel-ikon-uret`); bu fazda üretilmez.

---

## 6. Maliyet ve risk

### 6.1 Hat uygunluğu (`ab-karakter-ekle`)

Hat tek parça gövde yöntemine uyuyor (Zyfen örneği). Adımlar: tasarım (bu belge) → veri iskeleti → görseller → beceriler (`ab-beceri-ekle`) → ses (`ab-ses-ekle`) → mevcut testlerin güncellenmesi → denge (`ab-denge-olcumu`) → altın hash → ekran öz-kontrolü → cihaz listesi → `bash tools/gate.sh`. Doğrulama sırası ders: JSON'u görseller/beceri/import'tan **sonra** bağla (`validate_data` yoksa reddeder).

### 6.2 Test etkisi — F-ashen-bastion-060

Karakter listesini sabitleyen **4 test** yeni karakterde kırmızı olur ve elle güncellenir: `test/unit/test_character_roster.gd:44` (`test_ids_follow_order_field`), `test/unit/test_characters_screen.gd:273` (`test_f030_gunslinger_first_by_order_field`), `test/acceptance/test_acc_v2_chars.gd:640` (`test_k10_single_character_set_works`), `test/unit/test_v202_pool_real.gd:64` (`test_empty_character_id_keeps_old_unfiltered_behavior`). Beklenen değer sayı/sıra olarak güncellenir (kusurlu davranış sabitlenmez). F-060 önerisi: bunları veri tabanlı beklentiye çevirmek; üçüncü karakterle bu iş de yapılırsa dördüncü karakter ücretsiz olur (öneri). Skill metni test kodundan **bu görevde yeniden doğrulanmadı** (yalnız skill ve bulgu dosyasından alındı).

### 6.3 Yeni kod (Zyfen'den farkı)

Zyfen ağırlıklı **veri + efekt** işiydi; Nerya **sim'e yeni davranış** ister:

| İş | Neden yeni | Risk |
|---|---|---|
| Yakın dövüş temel saldırı (yay çarpışması, adım) | Mevcut temel saldırılar mermi/kesik ateşi | Orta: determinizm, harabe çarpışması |
| Otomatik sıçrayış (sıyrılma) + hasarsız pencere | Oyuncu pozisyonunu joystick dışında sim değiştirir | **Yüksek**: altın hash, çarpışma, bot etkisi, temas hasarı kodu |
| Uyarılı zemin darbesi (Gökten Düşen) | Gecikmeli alan hasarı | Düşük–orta |
| Süzülen kılıç (gezinen varlık) | Yeni varlık havuzu, hedef arama | Orta: perf (varlık sayısı), determinizm |
| Karşı Kesik (hasar alınca tetik) | `DamageSystem` kancası | Orta |
| `blade` bot politikası | Ölçüm için gerekli | Düşük, ama **her ölçüm bağlı** |

### 6.4 Diğer riskler

- **Altın hash:** otomatik sıçrayış/adım sim yolunu değiştirdiği için yeni aşama kaydı gerekir; **Gunslinger kayıtları değişmez** (eşitlik zincirleri korunmalı). Sıçrayış yalnız Nerya'ya özel kod yolunda olmalı.
- **Perf:** Süzülen Kılıç ve evrimli Gökten Düşen için varlık/çizim bütçesi; Xiaomi Redmi Note 13 Pro hedef. Cihaz dışında **doğrulanamaz**.
- **Okunurluk:** menzil 170'te kalabalık içinde çelik beyazı efektlerin Zyfen'in beyazıyla karışması ve düşman kalabalığında kaybolması riski.
- **Animasyon:** kılıçlı yürüme/cast karelerinde video tabanlı üretimde kılıç kenarı ve kare tutarlılığı (renk/kıyafet sıçraması) el denetimi ister; kılıçlı tek `cast_point` kesik için ele yakın seçilir, iki ucu olan silahlar sınırlı.
- **Yerel Godot yok:** yerel Windows çalışanlarında Godot çalışmıyor (kart notu); tüm doğrulama CI'da. Bu belge hiçbir testle doğrulanmadı (yalnız Markdown).
- **Kapsam:** hikâye/diyalog bu faza girmez (Zyfen kararı gibi); karakter kilidi `unlock` açık soru (§7 S7).

### 6.5 Efor (kabaca, karşılaştırma için; varsayım)

| Parça | Boyut |
|---|---|
| Veri + temel saldırı, 6 aktif, 6 pasif, 4 evrim kaydı (`ab-beceri-ekle`) | M |
| Sim: yakın dövüş + sıçrayış + 2 yeni varlık davranışı | **L** |
| Görsel: portre, şerit, 17 ikon | M–L (video hattı, el denetimi) |
| Ses | S–M |
| Denge + `blade` politikası + altın hash | M |
| Test güncellemeleri (F-060) | S |
| Toplam | Zyfen'den **daha büyük** (sim işi yüzünden); süre tahmini yok, ölçülmedi |

---

## 7. Kullanıcıya açık sorular

Karar gerektirenler (öneri varsa parantezde):

1. **S1 — Hasarsız sıyrılma:** kına/sıçrayış penceresinde temas hasarı olmasın mı? *(Önerilen: 0,2 sn.)* Hayır dersen geri sıçrayış yalnız mesafe verir; yakın dövüşçü ölçekte zayıflar.
2. **S2 — Sıçrayış yönü:** tamamen otomatik mi, joystick eğimiyle bükülebilir mi? *(Önerilen: hafif bükme.)*
3. **S3 — İnfaz kuralı:** Gökten Düşen Kılıç `can ≤ %25` sıradan düşmanı anında öldürsün mü, yoksa sadece yüksek hasar mı? *(Önerilen: öldürsün; gösteri değil dürüst infaz hissi.)*
4. **S4 — Silah:** tek düz uzun kılıç mı (öneri), eğri kılıç/katana mı, çift kılıç mı (animasyon maliyeti, `cast_point` sınırı)?
5. **S5 — Ad:** "Nerya / Son Nöbetçi (The Last Warden)" uygun mu, başka ad ister misin?
6. **S6 — Pasif sayısı:** 6 hedef için ortak havuzu karaktere göre filtreleme (kod işi) yapılsın mı, yoksa 8 pasifin görünmesi kabul mü? *(Önerilen: kabul; filtre sonra.)*
7. **S7 — Kilit:** Nerya baştan açık mı (Zyfen gibi) yoksa bir başarıma bağlı mı?
8. **S8 — Palet:** soğuk çelik beyazı + bordo imza rengi onaylı mı?
9. **Cihaz notu (elde hissi):** prototip çıkınca Redmi Note 13 Pro'da şunlara bakılması istenecek: menzil 170 kısa mı, kesik adımı/sıyrılma rahatsız ediyor mu, kalabalıkta kılıç efektleri okunuyor mu, Süzülen Kılıç perf. **Bu belge için elde hissi denetlenemedi.**

---

## 8. Varsayımlar ve doğrulanmayanlar

- Tüm sayılar öneri; sim'de ölçülmedi.
- `data_v202_pool.gd` davranışı (ortak havuz alt kümesi yok) kısa okumadan; ayrıntı doğrulanmadı.
- `Ağır Kurşun`'un kılıç hasarına etkisi kodda **doğrulanmadı**.
- Test dosya:satır numaraları F-ashen-bastion-060'tan, yeniden doğrulanmadı.
- Godot yerelde çalıştırılamadı; hiçbir şey çalıştırılmadı (yalnız belge).
- Hiçbir esin kaynağı eser adı kullanılmadı; yetenek fikirleri kullanıcı brifinden, ifadeler özgün.
