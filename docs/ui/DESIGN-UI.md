# Ashen Bastion v1 — Arayüz Tasarım Notu

Tarih: 2026-10-23 · Görev: T20261023-56 · Girdi: `docs/design/2026-10-23-ashen-bastion-v1-design.md` (§5.2 kontrol, §5.3 şarjör, §5.6 ekranlar) · Görseller: `art/ref/`

Bu belge developer'ın Godot 4'te doğrudan uygulayabileceği somutlukta yazıldı. Maketler `docs/ui/mockups/*.html` (1080×2400 sanat tahtası), ekran görüntüleri `docs/ui/screenshots/`, token'lar `docs/ui/tokens.json` (+ `tokens.css`, `ashen-bastion-theme.tres`), ikonlar `art/ui/`.

## 1. Tasarım ilkeleri (gerekçeli)

1. **Oyun alanı kutsaldır.** Oyuncu tek elle, başparmakla oynar; ekranın alt-orta %75'i boş kalır. HUD yalnızca üst ~%18'de ve sol alt köşede (şarjör). Ölçülen kaplama ≈ %7 (`08-hud-anatomi`).
2. **Başparmak bölgesi dokunulmaz.** Joystick her yerde belirir (spec §5.2); bu yüzden alt-orta bölgede etkileşimli HUD öğesi yok. Etkileşimli tek HUD öğesi: Duraklat (sağ üst, başparmakla zor erişilir → kazara duraklatma olmaz).
3. **Ritim görünür olmalı.** Şarjör sayacı sol altta, en son bakılan göz hizası yakınında; doldurma anında amber halka dolar + sayaç `↻` olur. Ek olarak karakterin üstünde dünya-uzayı doldurma halkası önerilir (§5.4).
4. **Gotik ama okunur.** Başlık/sayılar Cinzel (gotik his), gövde Inter (küçük metinde okunurluk). Dekor yalnızca çerçeve ve kenarlıkta; metin altına desen konmaz.
5. **Aşırı kullanımı önle.** Amber yalnızca "ritim/evrim/uyarı" anlamı taşır (doldurma, evrim kartı, boss uyarısı, kazanma başlığı); bordo = birincil eylem + can; mor = yüzey + XP; bronz = kenarlık/vurgu.

## 2. Palet (konsept sayfası: koyu mor, bordo, kemik beyazı, koyu kahve, bronz)

Konsept sayfasındaki 5 örnek (`art/ref/karakter-konsept.png`, sağ alt) piksel olarak örneklendi: mor ≈ `#30252E`, bordo ≈ `#592524`, kemik ≈ `#ABA29C`, kahve ≈ `#2D2422`, bronz ≈ `#89715A`. Ekran arayüzünde bu değerler doğrudan kullanılırsa kontrast yetmediği için **aynı tonlar, UI için ayarlanmış kademelerle** kullanıldı (kemik açıldı, bronz parlatıldı, mor biraz doygunlaştırıldı). Tam liste `tokens.json`.

| Token | Hex | Kullanım |
|---|---|---|
| void | `#0D0910` | en koyu zemin, çubuk içi, scrim |
| mor_900 / 800 / 700 / 500 | `#171020` `#211832` `#2F2342` `#4D3A6B` | ekran zemini / panel / yükseltilmiş panel / ikincil buton |
| bordo_900 / 700 / 500 / 400 | `#2B0E14` `#5C1D26` `#8F2A36` `#B8404A` | evrim zemini, birincil buton, buton üst tonu, can dolgusu |
| kemik_100 / 300 / 500 | `#EFE7D6` `#CFC4AE` `#A39883` | birincil metin / ikincil metin / pasif metin |
| kahve_900 / 700 / 500 | `#1C1411` `#2E211C` `#4A3830` | devre dışı buton, ikon zemini |
| bronz_700 / 500 / 300 | `#7A6045` `#A88A5C` `#D2B47E` | panel kenarı / buton kenarı / odak, başlık vurgusu, dolu mermi |
| amber_glow | `#E8A24A` | doldurma, evrim, boss uyarısı (ışık/ateş sıcaklığı, spec: "sıcak amber ışık") |
| can_kritik | `#E0584F` | can < %25 kenarlık/vinyet |
| xp / xp_parlak | `#7C5CC4` `#A98BEF` | XP çubuğu ve taşı |
| dogru | `#8DB58A` | yalnızca maketlerde ölçü işareti |

### Kontrast (WCAG 2.1, hesaplandı)
| Çift | Oran | Sonuç |
|---|---|---|
| kemik_100 / mor_900 | 15,1 | AAA |
| kemik_100 / mor_700 | 11,9 | AAA |
| kemik_300 / mor_700 (kart açıklaması) | 8,4 | AAA |
| kemik_500 / mor_900 (pasif metin) | 6,5 | AA |
| bronz_300 / mor_800 (bölüm başlığı) | 8,5 | AAA |
| kemik_100 / bordo_700 (birincil buton) | 10,3 | AAA |
| kemik_100 / mor_500 (ikincil buton) | 8,0 | AAA |
| bordo_900 / amber (EVRİM etiketi) | 8,3 | AAA |
| kemik_100 / can_dolu (can çubuğu yazısı, 28 px kalın) | 4,4 | büyük metin eşiği (≥3) geçer; yazıya 3 px siyah gölge eklenir |
| bronz_500 / mor_900 (buton/ikon kenarı) | 5,7 | UI bileşeni ≥3 geçer |
| bronz_700 / mor_800 (kart kenarı) | 2,9 | **yalnızca dekoratif**; kartın sınırı arka plan farkı + gölgeyle de okunur, seçilebilirlik kenarlığa bağlı değil |

Renk tek başına anlam taşımaz: evrim kartı renkle birlikte **sekizgen çerçeve + "EVRİM" etiketi**, düşük can renkle birlikte **vinyet + sayı** ile, doldurma renkle birlikte **`↻` + halka** ile belirtilir.

## 3. Tipografi

| Rol | Font | Boyut (px, 1080 genişlik) | Not |
|---|---|---|---|
| Ana başlık | Cinzel 900 | 132 (menü) / 96 (ekran başlığı) | harf aralığı +0,08 em, büyük harf |
| Süre | Cinzel 700 | 72 | rakamlar |
| Buton | Cinzel 700 | 46 (birincil 64 menüde) / 40 küçük | büyük harf, +0,08 em |
| Kart başlığı | Cinzel 700 | 46 | |
| Gövde | Inter 400/600 | 32 (kart açıklaması), 36 (diyalog) | satır 1,3–1,4 |
| Etiket/HUD küçük | Inter 600–700 | 28 (min 26; 22 yalnızca ikon rozeti) | |

- **Lisans:** Cinzel — SIL Open Font License 1.1; Inter — SIL OFL 1.1. İkisi de ticari/ücretsiz dağıtımda serbest, APK'ya gömülebilir, kaynak (lisans metni) ile birlikte dağıtılmalı. Lisans metinleri `docs/ui/fonts/` içinde.
- **Türkçe glifler doğrulandı:** İ ı Ş ş Ğ ğ Ç ç Ö ö Ü ü hem Cinzel (latin + latin-ext alt kümeleri) hem Inter'de çizilir; ekran görüntülerinde "SEVİYE", "BAŞTAN BAŞLA", "TİTREŞİM" doğru görünür. Büyük `İ` Cinzel'de noktalıdır. **Dikkat:** Godot'ta `uppercase` için `String.to_upper()` kullanılırsa `i → I` olur; Türkçe büyük harf gereken yerlerde (buton etiketleri) metni **zaten büyük harfle** (`BAŞTAN BAŞLA`, `TİTREŞİM`) çeviri tablosuna yazın, kod ile büyütmeyin.
- Godot için TTF gerekir (maketlerde WOFF2 kullanıldı): Cinzel → Google Fonts (`Cinzel[wght].ttf`, değişken) ya da statik Bold; Inter → `Inter-Regular/SemiBold.ttf`. Yer: `res://assets/fonts/`. Geçici/yedek: Godot varsayılan fontu (Türkçe karakter destekler).
- Cinzel'de küçük harf yoktur (küçük büyük harf gibi çizilir); 32 px altı gövde metninde kullanılmaz.

## 4. Boşluk, köşe, gölge, hareket

- **Boşluk (px):** 6 · 12 · 18 · 27 · 36 · 54 · 81 (≈ 2,2–29 dp). Ekran yan kenar boşluğu **36 px**, kart dışı kenar 48 px.
- **Köşe:** küçük 8, panel/buton 18, büyük 27. Çerçeve köşeleri bilerek keskin/oyma (gotik); tam yuvarlak yalnızca daire (seviye rozeti, pasif yuva, duraklat).
- **Kenarlık:** 3 / 4 / 5–6 px. **Gölge:** panel `0 12 36 #000B`; amber ışıma `0 0 30 #E8A24A99` (yalnızca evrim kartı ve doldurma).
- **Hareket** (ms): dokunma geri bildirimi 80 · ekran girişi 220 · kart girişi 260 (70 ms kademeli) · kart seçimi 140 · çubuk ease 180 · hasar vinyeti 120 · doldurma nabzı 220; easing `cubic-out`. Ayarlarda "azaltılmış hareket" v1'de yok; ancak ışıma/nabız süreleri kısa ve titreşimsizdir (saniyede 3'ten fazla yanıp sönme yok).

## 5. Ölçü sistemi ve dokunma hedefleri

- Referans viewport **1080×2400**, Godot `stretch_mode = canvas_items`, `aspect = expand`, dikey. Redmi Note 13 Pro için **varsayım: 1 dp ≈ 2,75 px** (~440 dpi). Bu cihazda 48 dp ≈ **132 px**; tüm etkileşimli hedefler ≥ 132 px (rahat 156 px). Yoğunluk 2,47'ye düşse de (≈395 ppi) 132 px ≥ 53 dp'dir.
- **Güvenli alan:** üst 96 px (kamera deliği/durum çubuğu), alt 72 px (hareket çubuğu), yan 36 px. Godot'ta `DisplayServer.get_display_safe_area()` ile çalışma anında doğrulanmalı; sabit değerler yalnızca varsayılan.
- Etkileşimli öğeler: Duraklat 132×132 · butonlar yükseklik 132–180 × tam genişlik · seviye kartları 984×324. Hedefler arası boşluk ≥ 27 px. Becerı yuvaları HUD'da **yalnızca bilgidir** (dokunulmaz), bu nedenle 78/66 px görsel boyutu hedef kuralını ihlal etmez.

## 6. Ekranlar, durumlar ve akış

Akış: **Ana Menü → Oyna → Oyun (HUD) ⇄ Seviye Atlama / Duraklatma → Oyun Bitti | Kazandın → Tekrar Oyna / Ana Menü.** Karakter seçimi ekranı yok (spec §3). Kalıcı ilerleme yok (spec §2) → ana menüde "devam et" yok.

### 6.1 Ana Menü — `01-ana-menu`
Ana görsel (`ana-gorsel-atis.png`, yeşil arka plan silinmiş halde) ekranın ortasında, üstte oyun adı, altta başparmak bölgesinde **OYNA** (180 px yüksek, birincil) ve iki ikincil anahtar (Ses, Titreşim; her biri 132 px, tek dokunuşla açık/kapalı). Alt: sürüm + karakter adı. Durumlar: varsayılan; anahtar kapalı (etiket "Ses: Kapalı", ikon üstü çizili); dokunma (pressed: koyu ton + 6 px aşağı). Boş/hata durumu yok (çevrimdışı, veri yüklemesi yok).
- Görsel kırpma notu: karakterin silahları ekran kenarına taşar; namlu alevi kenarda kesilebilir, bilinçli (hareket hissi).

### 6.2 Oyun HUD — `02-hud-oyun`, `03-hud-doldurma`, `08-hud-anatomi`
Üstten alta (px, 1080×2400):
| Öğe | Konum | Boyut | Davranış |
|---|---|---|---|
| Seviye rozeti | sol üst (24,84) | 84 daire | seviye sayısı Cinzel 40 |
| XP çubuğu | (132,100) → sağ 36 px | 24 yük. | bronz kenarlı, mor dolgu; dolum 180 ms; taş toplanınca kısa parlama |
| Süre | üst orta, y=128 | Cinzel 72 | `MM:SS`, sabit genişlik (tabular) |
| Duraklat | sağ üst, (948,128) | 132×132 (görsel 96) | tek dokunuş → duraklatma; boss/seviye animasyonu sırasında da çalışır |
| Can | (36,196), 360×44 + kalp | | `86 / 120` yazısı; < %25: dolgu `can_kritik` + tüm ekran kenar vinyeti (kırmızı, 120 ms nabız) |
| Aktif yuvalar | (36,278) | 6 × 78 px, 9 px aralık | kare çerçeve; sağ altta seviye rozeti; boş yuva %35 opaklık; evrim kazanınca sekizgen evrim çerçevesi |
| Pasif yuvalar | (42,368) | 6 × 66 px | daire çerçeve; aynı kurallar |
| Şarjör | sol alt (36, alt 72) | 168 px | 6 yuvalı tambur: dolu = bronz mermi, boş = koyu; ortada sayı `4 / 6` |
| Joystick | dokunulan yerde | taban 300, topuz 132, max yarıçap 150 | taban %28, topuz %55 opak; parmak kalkınca 120 ms'de solar |

**Şarjör durumları:** (a) 6→1 dolu: her atışta bir yuva sönük olur, 80 ms sönme animasyonu; (b) **son mermi**: sayı `1` amber, tambur 220 ms nabız (Son Mermi Patlar becerisi için ipucu); (c) **doldurma**: yuvalar boş, sayı yerine amber `↻`, dış halka 0→%100 amber ilerler (süre = doldurma süresi, başlangıç ≈ 1 sn); (d) bitince 6 yuva sırayla 40 ms arayla dolar + tık sesi. Tüm durumlar renkten bağımsız (sayı + halka).
**Boss uyarısı** (5/10/15/20. dk): y≈520'de 132 px bant, `ARA BOSS YAKLAŞIYOR` / `KALE LORDU GELİYOR`, 2,4 sn görünür, oyun durmaz, dokunuşu engellemez.
**Düşman/mermi yoğunluğunda okunurluk:** HUD yarı saydam panel zemini taşımaz; metinlere 3 px siyah gölge (`Label` tema) verilir. Yoğunluk sırasında HUD opaklığı sabit %85 (sahne hareketinden bağımsız).
**Sayı-parçacıkları (hasar sayıları):** HUD kapsamı dışında; v1 için önerilmez (kalabalıkta okunmaz, performans).
- Yuvalar sabit: yeni beceri soldan sağa dolar. **Evrim:** ham beceri yuvası sekizgen evrim çerçevesine döner, ikon yeni evrim ikonuna; 300 ms amber parlama (bir kez).

### 6.3 Seviye Atlama — `04-seviye-atlama`
Oyun duraklar, sahne %80 koyulaşır, **portre alanı** üstte (y 60–1100): karakter büyük portresi (v1'de ana görsel yer tutucu; kullanıcı portre promptu ile gelecek — kutu 760×1000 sağa dayalı, sol üstte "GUNSLINGER / SEVİYE N"). Altta **3 kart** (984×324, aralık 27): ikon çerçevesi 180 px, ad (Cinzel 46), etiket (`YENİ` mor, `YÜKSELT` bordo, `EVRİM` amber dolgu) + seviye geçişi (`Sv. 4 → 5`), açıklama 1–2 satır (≤ 60 karakter).
- **Etkileşim:** karta dokun = seçilir ve ekran kapanır (onay adımı yok; hız önemli). **Kazara dokunmayı önlemek için** ekran açıldıktan sonra **500 ms giriş kilidi**; bu sürede kartlar %60 opak, kilit bitince tam opak + hafif nabız. Basılı tutma yok. Kart pressed: 6 px aşağı + parlak kenar.
- **Evrim kartı:** sekizgen çerçeve, amber kenarlık + ışıma, açıklama hangi çifte dayandığını yazar. Bir evrim kartı varsa her zaman 3 seçenekten biridir ve en alta konur (parmağın en kolay ulaştığı yer) — *öneri*; ilk iki sıra rastgele.
- **Kenar durumları:** (a) 3'ten az seçenek kaldı (tüm yuvalar dolu/maks.) → kalan sayıda kart, ortaya hizalı; (b) hiç seçenek yok → ekran açılmaz, yerine "Şifa" sabit kartı (+%25 can, ikon `hud-can`) tek kart olarak gösterilir (*öneri; oyun tasarımı kararı*); (c) yuvalar dolu ve yeni beceri yok: yalnızca yükseltme kartları.
- Hata durumu yok.

### 6.4 Duraklatma — `05-duraklatma`, `05b-duraklatma-onay`
Sahne %80 scrim, başlık `DURAKLATILDI`, **mevcut beceriler** paneli (yuvalar + seviyeler; 1,25× büyütülmüş, bilgi amaçlı), ardından **DEVAM ET** (birincil), Ses/Titreşim anahtarları, **BAŞTAN BAŞLA**, **ANA MENÜ** (kenarı bordo). Baştan Başla / Ana Menü **onay diyaloğu** açar (`05b`): "Ana menüye dönülsün mü? Bu oyundaki ilerleme kaybolur. Her oyun sıfırdan başlar." — `VAZGEÇ` (ikincil, üstte, varsayılan odak) / `ANA MENÜYE DÖN` (bordo, altta). Geri tuşu (Android) = Devam Et; diyalogda geri = Vazgeç. Uygulama arka plana alınınca otomatik duraklat.
- Devam Et sonrası **3-2-1 geri sayım yok**; 600 ms'de joystick tekrar etkinleşir (kazara hareketi engeller).

### 6.5 Oyun Bitti / Kazandın — `06-oyun-bitti`, `06b-oyun-bitti-kombosuz`, `07-kazandin`
Başlık (`OYUN BİTTİ` kemik + bordo ışıma; `KAZANDIN` amber + amber ışıma), alt başlık (`Kale seni yuttu.` / `Düşmüş Kale Lordu devrildi.`), **istatistik paneli** (Süre `MM:SS`, Seviye, Öldürme — binlik ayracı nokta), **Kurulan kombolar** (evrim çerçeveli ikon + ad + hangi çiftten) ve **TEKRAR OYNA** (birincil) / **ANA MENÜ** (ikincil).
- **Boş durum (`06b`):** kombo yoksa panelde "Bu seferlik kombo kurulmadı. Bir aktif beceriyi en üst seviyeye çıkarıp eşini bul." (öğretici, suçlayıcı değil).
- Çok kombo: panel 5'e kadar satır gösterir (v1 ~4 evrim), taşarsa kaydırma yok (v1 hedefi aşılmaz).
- Giriş animasyonu 220 ms; sayılar 600 ms'de 0'dan sayarak artar (atlanabilir: dokun = bitir). Düğmeler 800 ms sonra etkinleşir (kazara "tekrar oyna" önlenir).

## 7. Bileşen envanteri

| Bileşen | Varyantlar | Durum | Godot karşılığı |
|---|---|---|---|
| Buton | birincil, ikincil, tehlikeli (bordo), küçük | normal / hover(odak) / pressed / disabled | `Button` + tema tipleri `Button`, `ButtonSecondary` |
| Panel | normal, yükseltilmiş, evrim | – | `PanelContainer`, `PanelRaised`, `PanelEvrim` |
| İlerleme çubuğu | XP, Can (normal/kritik) | – | `ProgressBar` + `ProgressBarHP` |
| Beceri yuvası | aktif (kare), pasif (daire), evrim (sekizgen) × dolu/boş | rozet = seviye | `TextureRect` ×3 + `Label` |
| Şarjör tamburu | 6 yuva; normal/son mermi/doldurma | | özel `Control` (draw) |
| Sanal joystick | taban + topuz | gizli/etkin | özel `Control` |
| Seviye kartı | yükselt/yeni/evrim | giriş kilitli/etkin/pressed | `PanelContainer` + `Button` |
| Bant (uyarı) | boss | | `Control` + tween |
| Diyalog | onay | | `PanelContainer` |
| Anahtar (toggle) | ses, titreşim | açık/kapalı | `Button` (toggle_mode) |
| Başlık/etiket | Title, Timer, Accent, Secondary | | `Label` tipleri |

Projede önceden UI yoktu; yeni sistem, tek token kaynağı `tokens.json`.

## 8. Erişilebilirlik (mobil oyun bağlamı)

- Metin kontrastı ≥ 4,5:1 (tablo §2); büyük metin ≥ 3:1. En küçük metin 26 px (≈ 9,5 dp) — HUD'da sadece rozet sayıları 20 px (dekoratif, bilgi başka yerde de var: yuva kartı/duraklatma ekranı).
- Anlam yalnızca renkle verilmez (§2 sonu). Kırmızı/yeşil çiftine dayanan bilgi yok.
- Hedefler ≥ 132 px; hedefler arası ≥ 27 px; kazara dokunma korumaları (kart kilidi, buton gecikmesi).
- **Odak/klavye:** telefon birincil, ancak masaüstü testi ve harici gamepad için tüm düğmelerde `focus` stili (6 px bronz_300 dış kenar) tanımlı; odak sırası yukarıdan aşağı; diyalogta varsayılan odak güvenli seçenek (Vazgeç).
- **Ekran okuyucu (TalkBack):** Godot 4'te sınırlı; maketlerde `aria-label` alanları developer için erişilebilir ad rehberi olarak yazıldı (ör. "Şarjör 4 / 6", "Duraklat"). Godot 4.5+'daki `accessibility_name` desteği varsa bu adlar atanır; yoksa v1'de kapsam dışı (açık nokta).
- Titreşim anahtarı menü + duraklatmada; seslerin açık/kapalı durumu tek tuşla.
- Işık/yanıp sönme: doldurma nabzı ≤ 3 Hz; hasar vinyeti tek atımlık.
- Renk körlüğü: can (bordo) ↔ XP (mor) ↔ doldurma (amber) ayrımı hem renk hem **yer/ikon/sayı** ile.

## 9. Beceri/evrim ikon stili (`art/ui/`)

- **Format:** SVG, 96×96 görünüm kutusu, tek parça, gömülü font yok. Çerçeveler 112×112 (`art/ui/frames/`).
- **Dil:** yüksek kontrastlı siluet + **düz dolgu**, mermi/barut gibi nesneler kemik/amber/bordo; kontur **4 px koyu bordo-siyah (`#2B0E14`)** — manhwa karakterin kontur diline eşlenir; gradyan ve ince detay yok (54 px'te okunmalı).
- **Palet:** kemik `#EFE7D6/#CFC4AE`, bronz `#D2B47E/#7A6045`, bordo `#B8404A/#8F2A36`, kahve `#4A3830/#2E211C`, tek vurgu amber `#E8A24A`. Her ikonda **en çok bir** amber odak noktası (ışık/kıvılcım/ateş).
- **Kompozisyon:** merkezde tek nesne + en çok 1 hareket işareti (kesikli bronz yol, ok, kıvılcım). Köşelere 8 px kenar payı. Yeni ikonlar aynı kuralla çizilir.
- **Çerçeve rolü tür gösterir:** kare = aktif beceri, daire = pasif, sekizgen + amber = evrim. Çerçeve ve glif ayrı dosya → ikon değişince çerçeve yeniden kullanılır.
- **Minimum boyut:** glif 46 px (HUD pasif yuva), tercihen ≥ 54 px; HUD'da seviye rozeti ile birlikte.
- **Örnekler (13 SVG + 3 çerçeve):** Seken Mermi, Yelpaze Atış, Dinamit, Son Mermi Patlar (aktif); Barut Kesesi, Hızlı Doldurma, Fazladan Mermi (pasif); Zincirleme Patlama (evrim); HUD: can, XP, mermi, öldürme, süre, duraklat. Tüm örnek adlar tasarım belgesi §5.3–5.4'ten.
- *Not:* Tasarım belgesi "ikonlar Claude Design ile" der; bulutta Claude Design olmadığı için SVG'ler elle yazıldı ve **stil referansı/temel** niteliğindedir. Claude Design bu belgeyi stil girdisi olarak alabilir; son ikonlar aynı dosya adlarıyla değiştirilir.

## 10. Godot'a aktarım

1. `tokens.json` → `ashen-bastion-theme.tres` (bu dizinde; Theme tipleri: `Button`, `ButtonSecondary`, `Label`, `LabelTitle`, `LabelTimer`, `LabelAccent`, `LabelSecondary`, `PanelContainer`, `PanelRaised`, `PanelEvrim`, `ProgressBar`, `ProgressBarHP`). **Godot'ta açılıp doğrulanmadı** (bulutta Godot yok); söz dizimi Godot 4 Theme biçimine göre elle yazıldı — açılışta hata verirse `tokens.json` esas alınır.
2. Fontlar `res://assets/fonts/` altına konup `ext_resource` yolları güncellenir.
3. İkonlar `art/ui/` → `res://assets/ui/`; Godot SVG'yi import eder (`svg/scale = 2`, 96 px → 192 px doku önerilir).
4. Düzen: tüm ekranlar `Control` kökü, çapa (anchor) tabanlı; yüzdelik değil, bu belgedeki px (1080×2400 referans) → `canvas_items` gerisini ölçekler.

## 11. Açık noktalar / varsayımlar

- **Varsayım:** 1 dp = 2,75 px (cihaz yoğunluğu doğrulanmadı; gerçek cihaz testi kullanıcıda).
- **Varsayım:** Konsept sayfasındaki 5 renk örneği piksel olarak okundu; UI kademeleri bu tonlardan türetildi (kullanıcı onayı ister).
- Seviye atlama portresi için kullanıcıdan gelecek görselin kırpma oranı bilinmiyor: yer tutucu 760×1000 (3:4), farklı gelirse portre kutusu ölçeklenir.
- Ayarlar ekranı spec'te yok; yalnızca Ses ve Titreşim anahtarları önerildi (menü + duraklatma). Müzik/efekt ayrı kaydırıcı v1 dışı.
- "Şifa" yedek kartı (seçenek kalmadığında) ve evrim kartının hep son sırada olması **oyun tasarımı kararıdır**; öneri olarak yazıldı.
- Düşman/harita görselleri yer tutucu daire/dikdörtgen; yalnızca HUD yerleşimini göstermek içindir.
- Ekran okuyucu desteği Godot sürümüne bağlı (§8).
- Skill durumu: `ui-ux-pro-max` yüklenemedi (bulut ortamında yok); `impeccable`, `design-taste-frontend` denenmedi (listede yoktu). Rol kurallarıyla devam edildi.
