# Ashen Bastion v2.0.3 — Tasarım (yeniden tasarım turu: ana sayfa, ayarlar, başarımlar, satır açık)

Tarih: 2026-10-26 · Görev: T20261026-58 (çatı T20261026-56) · Faz: tasarım, değişiklik turu. Kod yazılmadı.
Girdiler: `docs/review/v2.0.3-ui-direction.md` (Game Director brifi, **bağlayıcı**), kullanıcı kararları (2026-10-26), ilk tur tasarımı (git geçmişi `7a7f763`), `docs/ui/DESIGN-UI.md`, `docs/ui/tokens.json`, `docs/design/v2.0/`, oyun sanatı `art/ref/harita/{harabe-parcalari,zemin-doku}.png`, `art/ui/frames/`, `art/source/gem-orbs/`.
Çıktı: `mock/` (maketler, 1080×2400), `frames/` (Godot 9-slice SVG kaynakları), `tokens-v2.0.3.md` + `.json`. Maketleri yeniden üretmek: `python3 mock/make_assets.py && python3 mock/build.py && node mock/shoot.js`; çerçeveler: `python3 frames/make_frames.py`.
Uygulama dili **Godot Control / StyleBoxTexture (9-slice) / TextureRect / Label / Shader**; CSS'e özgü filtre/blur yok. Maketlerde yalnız şu iki yaklaşık kısayol var, ikisi de Godot karşılığıyla belirtildi: kilitli ikonun koyulaşması (`CanvasItem.modulate`), renk körlüğü paneli (tarayıcı matrisi; asıl sayılar Python ölçümü).

## 0. Skill'ler (bu tur ZORUNLU; ne katkı verdi)
| Skill | Durum | Katkı |
|---|---|---|
| `ui-ux-pro-max` | yüklendi; `search.py` çalıştırıldı | `--domain ux` ile dokunma hedefi/aralığı (Android 48 dp, ≥8 px) ve reduced-motion kuralları doğrulandı → 132 px hedef, `hareket_azalt` kapsamı. `--design-system "dark fantasy mobile game menu"` jenerik çıktı verdi (Hero+Features+CTA, yeşil/altın palet); **uygunsuz bulundu, uygulanmadı** (oyun menüsü, web landing değil). Pre-delivery kontrol listesi (kontrast, safe area, ikon, dokunma geri bildirimi) §8'e alındı. |
| `design-taste-frontend` | yüklendi; **app screen** kolu (`references/app-screens.md`) | Ayarlar/başarımlar için "renk veriye, krom'a değil", "KPI tip, tile değil" (özet `31 / 53` tipografi + kroniği, kart yok), "dürüst boş durum" (sıfırlar sıfır yazar), "ürüne yüz ver" (kimlik palet/doku/silüetten). Web sayfa kuralları (gradyan/gölge/ince çizgi yasağı) oyun menüsüne **uygulanmadı**: ışık/zemin/meşale oyun sanatının kendisidir; yasak olan "jenerik şablon" (mor degrade + 18 px yuvarlak + hap) kaldırıldı. Ayrıca "içi boş alanı süsle doldurma; ölçek/içerik/gerçek görsel ile doldur" ilkesiyle ana sayfada yeni görsel üretilmedi, mevcut oyun sanatı kullanıldı. |
| `impeccable` | yüklendi (`shape`, `critique`, `document` yönü; kod değiştiren komutlar yok) | `shape`: ekran başına tek soru + öncelik (§1); `critique`: ilk tur maketlerine Director bulgularıyla çift okuma, heuristik skor (§1 tablo "ilk tur → şimdi"); `document`: bu belge + token tabloları. **Sınır:** `impeccable context/detect` CLI (web DOM dedektörü) çalıştırılmadı; Godot render'ı olmadığı için eleştiri maketler + kod okumasıyla yapıldı. |
Yüklenemeyen skill yok.

## 1. Yön özeti ve brifle eşleşme
Director'ın özeti: işlev sağlam, görsel kimlik jenerik. **Yön:** işlevi koru, yüzeyi ve metaforu değiştir; menüler "kalenin içinden" okunsun (kapı/kemer, sancak, taş levha, kor, kül, mühür).

| Brif | Karar (bu tur) | Nerede |
|---|---|---|
| C1 palet | token düzeyi: `mor_*` yüzeyler → `tas_*`; mor yalnız XP + ikincil vurgu; tüm ekranlar için eşleme + kontrast yeniden hesaplandı | `tokens-v2.0.3.md` §1–3 |
| C2 köşe dili | 18 px yuvarlak + degrade + hap → **pahlı (chamfer) 9-slice levha/düğme**, köşe perçini; yeni `frames/` SVG'leri | `frames/`, `mock/*` |
| C3 hareket | yalnız ana sayfa hareketli (kül/kor, meşale, sancak, nefes); ayarlar/başarımlar sakin | §2, §6 |
| C4 metin | üst yazı **ASH AND STEEL kalır** (kullanıcı); sürüm satırında karakter adı kalktı → `Sürüm 2.0.3` | §2 |
| C5 başlık | bronz ayraçlı üst yazı + taş oyma harf (2 geçiş gölge) | §2 |
| A1 karakter asılı | kapı önünde, zemin yaması + kül halkası + sert gölge; namlu alevi kenar kesiği eritme + ışımayla örtüldü | §2 |
| A2 düğme hiyerarşisi | 3 kademe: OYNA (sancak tepeli bordo) › KARAKTERLER\|BAŞARIMLAR (dolu, mini portre / ilerleme halkası) › SKORLAR\|AYARLAR (hayalet) | §2 |
| A3 OYNA | sivri tepe süsü (`oyna-tepe`) + basılı kor parlaması | §2 |
| S1/S2 telefon ayarı gibi | taş duvar dokulu "sakin oda", lento başlık, oyma levha bölümler | §3 |
| S3 sessiz durumu | ton + **üzeri çizili hoparlör simgesi** + açıklayıcı satır | §3 |
| S4 gesture | kaydırıcı: ilk 12 px yatay ağırlıklıysa tutamak yakalanır; anahtar satırında 24 px eşik | §3, §8 |
| B1 satır aşırı yüklü | kademe iki kanala indi: plaka (silüet + Roma rozeti) + segmentli çubuk; "KADEME II" etiketi kalktı | §4 |
| B2 kademe renkleri yakın | ayrım **silüet** (yalın · perçin · köşebent · taç); gri tonlama sınaması `mock/04b` | §4.4 |
| B3 özet | "kale kroniği": 5 grup mührü zincirde | §4 |
| B5 hızlı atlama | mühüre dokun → gruba kay + sticky grup başlığı | §4 |
| B4 kilitli ikon | koyu silüet (`modulate`) + kilit rozeti 48; ad soluklaştırılmaz | §4 |
| D1–D3 satır açık | tek nesne: satır + panel birleşik `levha-yuksek`; kademe yolu = zincirle bağlı mühürler; çubuk kaybolur | §4.3 |
| Skor tablosu | "ilk tur → şimdi": jenerik şablon riski yüksek → düşük; satır bileşen sayısı 7 → 5 | — |

**Bilinçli sapmalar (gerekçeli):**
1. Brif "baklavalar plakanın alt kenarına bütünleşik" dedi; maketlerde plaka alt kenarına sığdırınca 12 px baklavalar çerçeveyle yarıştı. Aynı bilgi **segmentli çubuğa** taşındı (kademe sayısı kadar segment, dolu = geçilen). Kanallar hâlâ iki: plaka + segment.
2. Brif "çubuk kaybolsun ya da yolun üst ucuna dönüşsün": seçenek 1 (kaybolur; değer yolun aktif mührüne taşınır).
3. Ana sayfada "kapıdan bakış" için `harabe-parcalari`'ndan **kemer, kule, sur, 2 sancak, meşale** yeşil perdesi silinerek (kod dışı, `mock/make_assets.py`) kırpıldı; **yeni görsel üretilmedi**. Uygulama C/D bu kırpmaları `tools/art` ile aynı yöntemle kalıcı dokulara çevirir (aşağıda §7).
4. Üst yazı İngilizce kalır (kullanıcı); başlık altı ayraç `ayrac.svg`'dir.

## 2. Ana sayfa (`01-ana-sayfa`, ölçülü `01b`, hareket azalt `01c`, 2× yazı `01d`, ilk açılış `01e`)

**Soru:** "Oynamaya hazır mıyım?" → OYNA başparmak bölgesinde, sahne karakteri sahnede gösterir.

Katmanlar (alttan üste, hepsi `Control` ağacında `TextureRect`/`Sprite2D`; z-sırası bu sıradır):
1. zemin: `void→tas_900` dikey geçiş; üstte/altta `scene_fog` perdesi.
2. **kapı arkası ışığı:** `scene_glow` additive radyal doku (Godot: `Sprite2D` + `CanvasItemMaterial blend_mode = ADD` ya da `PointLight2D`; kapı arkası y≈700–1500).
3. uzak sahne (parlaklık %32–55, derin sis): kule (x −90), sur (x 650), **kemer** (680 genişlik, ortada, %78); alt 150 px sise erir (alfa maskesi dokuya pişirilir).
4. sancaklar (x 28 / x 906), meşale (x 120, zemin üstü).
5. **zemin yaması:** `zemin-doku`dan eliptik, kenarı yumuşak maskeli doku (1000×400) + kül halkası (2 px, `kemik_300 α0,16`) + karakter altında sert gölge (siyah radyal).
6. **karakter** 640×932, `ana_gorsel` kaynağı, yatay 56 px alfa eritme; her iki namlu ucunda 140 px additive ışıma (kenar kesiği örtülür). Karakter **kutuya konmaz**.
7. kül/kor parçacıkları (≤40; `amber_glow` %60, `kemik_300` %40).
8. üst vinyet (başlık okunurluğu), alt vinyet (düğmeler).

Başlık: ASH AND STEEL (Cinzel 34, +0,5 em, `bronz_300`) iki yanında `ayrac`; ASHEN BASTION Cinzel 132/900, `kemik_100`, **taş oyma** (üst-sol 2 px açık, alt-sağ 3–4 px koyu: iki `Label` ya da `shadow_*` iki geçiş), kırmızı sis yok. Başlık içi "kül→kemik" degrade **öneri** (shader; yoksa düz `kemik_100`). Işık kaynağı kapının arkasındadır.

Düğme sütunu (x 72–1008, aralık 27):
| Kademe | Öğe | Boyut / y | Yüzey | İçerik |
|---|---|---|---|---|
| 1 | OYNA | 936×180 · 1763 | `dugme-birincil` (bordo) + `oyna-tepe` üst orta | Cinzel 68/900; basılı: 6 px iniş + `dugme-basili` + 80 ms kor parlaması |
| 2 | KARAKTERLER \| BAŞARIMLAR | 454×132 · 1970 | `dugme-dolu` (taş) | KARAKTERLER: 68 px yuvarlak **mini portre** (bronz halka) + ad; BAŞARIMLAR: 68 px **ilerleme halkası** (`amber_glow` / `bordo_900`, 31/53) + `31/53` |
| 3 | EN İYİ SKORLAR \| AYARLAR | 454×132 · 2129 | `dugme-hayalet` (dolgusuz, `bronz_500` kenar) | ikon 48 + Cinzel 32 |
| — | Sürüm | Inter 26 `kemik_500` · 2288 | | `Sürüm 2.0.3` (karakter adı yok) |

Hedef boyutları aynı (≥132); ağırlık hiyerarşisi görsel. AYARLAR sütunda (üst köşe zor; D1 korunur). Sütun alt sınırı 2261, sürüm 2288–2328 (güvenli alan 72).
**Durumlar:** varsayılan · basılı/odak (`border_focus` 6 px, sıra OYNA → KARAKTERLER → BAŞARIMLAR → SKORLAR → AYARLAR) · `hareket_azalt` AÇIK (`01c`): tüm hareket durur (§6), sahne statik, ışıma sabit düşük · ilk açılış (`01e`): `0/53`, halka boş · **2× yazı (`01d`)**: `font_scale > 1,3` → yarım düğmeler tek sütuna düşer (168 yüksek), karakter %80'e, kemer %74'e küçülür; başlık/OYNA arasında kalır, hiçbir şey kesilmez · kayıt okunamadı: `0/53` + varsayılan karakter, hata iletisi yok.
Güvenli alan: `apply_safe_area`; çentikte başlık bloğu üst payla iner, sahne yüksekliği payı emer.

## 3. Ayarlar (`02-ayarlar`, ölçülü `02a`, sessiz + hareketi azalt `02b`, 2× yazı `02c`, lisanslar `02d`)

**Soru:** "Sesi/titreşimi/hareketi hızla ayarlayabilir miyim?" — "sakin oda": hareketli arka plan yok.

- **Atmosfer:** `tas_900` zemin + çok düşük kontrastlı (≤%8) taş duvar dokusu (256×256 döşeme; **yeni doku**, önce kod/gürültü ile üretilir, görsel gerekiyorsa `[VLAD:ASK]`) + üstten sıcak tek ışık (`amber_glow α0,16`); alt 500 px `void`'e söner.
- **Başlık:** "AYARLAR" `lento` (520×120, 9-slice margin 60/0/60/0) üstünde, Cinzel 64/900, y 96.
- **Bölümler** (SES · DOKUNUŞ · GÖRÜNÜM · HAKKINDA): başlık Cinzel 34 + bronz çizgi (`StyleBoxFlat` 3 px, `bronz_700`) uzanır; kart = `levha` (9-slice margin 40; içerik dolgusu 28 + perçin köşeler).
- **Satır:** etiket + tek açıklama (≤2 satır); satırın tamamı tek dokunma hedefi (≥132). Etiket Cinzel 36, açıklama Inter 28 `kemik_300`.
- **Anahtar = kor mührü** (156×84, `anahtar-ac/kapali`): AÇIK = bordo levha, `bronz_300` halka, yuvada amber kor + sağda mühür; KAPALI = taş levha, `demir` halka, sönük yuva + sol mühür; sözcük **AÇIK/KAPALI** solda (renk tek kanal değil). Geçiş 140 ms + 200 ms kıvılcım (`hareket_azalt`'ta anlık).
- **Kaydırıcı:** ray `ray.svg` (9-slice, 28 yüksek), dolgu `ray-dolgu` (kor: bordo→bronz→amber), tutamak `tutamak` madalyon 84; dokunma bandı 132; değer `%70` Cinzel 40. %5 adım çentikleri çok soluk (maket çizmedi; **öneri**).
- **Sessiz durum** (TÜM SESLER KAPALI): ana satırda **üzeri çizili hoparlör** simgesi (kırmızı çarpı `can_kritik`), altında 76 yüksek satır "Ses kapalı. Bir kaydırıcıya dokunmak sesi açar."; kaydırıcılar soluk (`ray-dolgu-sessiz`, `tutamak-sessiz`) ama değer metni soluklaştırılmaz. **Kural korunur:** kaydırıcıya dokunmak ana anahtarı açar.
- **GÖRÜNÜM → HAREKETİ AZALT** açıklaması: "Hareketli portreleri ve ekran efektlerini durdurur." (kapsam kullanıcı kararı: hepsi, §6).
- **HAKKINDA:** SÜRÜM `2.0.3` · LİSANSLAR › (alt ekran `02d`; GERİ ayarlara döner).
- **GERİ** 936×132, y 2196, sabit; liste y 250–2172 kaydırılır (alt 100 px solma, 8 px kaydırma ipucu; ilk kaydırmada 600 ms görünür).
- **Gesture kuralı:** kaydırıcı bandında dokunuş yatay ağırlıklıysa (ilk 12 px) tutamak yakalanır, aksi hâlde liste kayar; anahtar satırında 24 px eşiği (kayan dokunuş = tetikleme yok). Test: kaydırırken kazara anahtar tetiklenmez.
**Durumlar:** varsayılan · sessiz + hareket azalt AÇIK + titreşim KAPALI (`02b`) · **2× yazı (`02c`)**: etiketler 72, açıklama 56, anahtar etiketin altına sarar, kartlar uzar, liste kayar, GERİ sabit · duraklatmadan açılış: aynı ekran, GERİ duraklatmaya döner · eski `settings.cfg`: `hareket_azalt=false`. Hata/yükleme yok (yerel dosya).
Güvenli alan: ayarlar ekranı dahil `apply_safe_area` (üst pay lento+liste, alt pay GERİ).

## 4. Başarımlar (`03`, ölçülü `03a`, boş `03b`, hepsi açık `03c`, satır açık `03d`, kademe dili `04` + gri `04b`)

**Soru:** "Sıradaki hedefim ne, ne kadar kaldı?" — kimlik: kale kroniği.

### 4.1 Üst alan
Başlık BAŞARIMLAR (Cinzel 80/900, y 96). Özet `31 / 53 kademe` (Cinzel 56) + **kroniği şeridi**: bronz zincir üzerinde **5 grup mührü** (84 px; `muhur-dolu` = grup tamam amber ✓, `muhur-aktif` = ilerliyor, `muhur-sonuk` = hiç yok) ve altında kısa etiket (WATCH · CULLING · CROWNED · ARMORY · ROAD, Inter 26). Mühür dokunma = o gruba kay (hedef 187×132). Metin korunur (erişilebilirlik, kontrast).

### 4.2 Grup ve satır
- **Grup başlığı** sticky: Cinzel 34 `bronz_300` + çizgi + sağda `açılan / toplam` (tamamlanınca amber).
- **Aile satırı 936×150** (`levha`, margin 40 → içerik 20 px dolgu): plaka 108 · ad (Cinzel 38, tek satır) · **sonraki hedef** tek satır (Inter 28) · sağda `değer/hedef` (Cinzel 34) + **segmentli çubuk** 232×14 (kademe sayısı kadar segment; geçilenler dolu, aktif kısmi, gelecek boş; segment rengi = geçilen kademe rengi).
- **Kademe iki kanalda:** (a) plaka silüeti + Roma rozeti, (b) segmentler. Ayrı "KADEME II" etiketi ve baklava satırı **yok**.
- **Plaka silüeti** (`frames/plaka-*.svg`, yapısal fark): I yalın demir çerçeve (`demir`) · II 4 köşe perçini (`bronz_300`) · III köşebentler (`amber_glow`) · IV bordo plaka + amber köşebent + **taç** (üstte 14 px taşar; doku 108×122) + halo. Gri tonlama sınaması: `mock/04b` (I, II, III, IV, kilitli birbirinden ayırt edilir; II/III parlaklık yakın ama silüet farklı).
- **Kilitli:** `plaka-kilitli` (`tas_500` kenar) + ikon **koyu silüet** (`modulate Color(.34,.30,.27)`) + kilit rozeti 48; ad `kemik_100` (soluk değil).
- **Tamamlanan aile:** kenar `bronz_500`, plaka son kademe silüeti, tüm segmentler amber, **TAMAM** çipi (`dugme-hayalet` amber modulate), açıklama "Tüm kademeler açıldı. <tarih>".
- Grup eşlemesi (öneri, spec ailelerine): THE WATCH: Hayatta Kalma, Dokunulmaz, Nöbet · THE CULLING: Kırım, Öldürme, Sınırsız Kırım, Bomba Ustası · THE CROWNED: Boss Avcısı, Üç Elit, Kale Lordu · THE ARMORY: Seviye, Evrim, Tambur Ustası, Seri Ustası, Skor, Eklenti Avcısı, Tam Kadro · THE ROAD: Yerleşik, Çifte Yol (19 aile). Aile adları şimdilik Türkçe (kullanıcı İngilizce seçimini yapınca değişir, §9).

### 4.3 Satır açık (`03d`)
Satıra dokun = tek nesne büyür: `levha-yuksek` içinde başlık satırı + **kademe yolu**: 4 mühür zincirle bağlı (`muhur-dolu` ✓ tarih · `muhur-aktif` kısmi, `2.940 / 5.000` amber · `muhur-sonuk` `Hedef 25.000` `kemik_500`, okunur). Üstteki segmentli çubuk **kaybolur** (değer yalnız aktif mührün yanında); sağda `˄` (kapat). Aynı genişlik, kenar boşluğu yok, ayrı gölge/yuvarlak kart yok; 180 ms (`hareket_azalt`'ta anlık); aynı anda 1 açık; açarken ses/titreşim yok. `accessibility_name`: "Öldürme, kademe 2 / 4, açık" / "kapalı".

### 4.4 Durumlar
Varsayılan · **boş/hepsi kilitli (`03b`)**: `0 / 53`, mühürler sönük, 108 yüksek panel "Henüz kademe açılmadı. Bir koşuya başla.", hata iletisi yok · **hepsi açık (`03c`)**: `53 / 53` amber, mühürler dolu, panel "Tüm başarımlar açıldı." · satır açık · koşu içi bildirim ("BAŞARIM AÇILDI · KADEME III / ÖLDÜRME III", `04`) ve sonuç özeti ("YENİ KADEME · 2") **aynı kaynak**: bildirim çıktıysa liste aynı karede açık (test) · bilinmeyen kimlik gösterilmez, silinmez · çoklu eşik = tek bildirim, en yüksek kademe.

## 5. Ruh küreleri
İlk tur brifi geçerlidir (kaynaklar `art/source/gem-orbs/`, 34/48/68 px, ölçüm: normal–elit ΔL* ≥41, elit–boss ≥33, normal–boss 4,9; IoU 0,37/0,46/0,51). Bu turda eklenenler: görsel yön `mock/05-kure-gorsel-yonu` yeni palet üzerinde yeniden çizildi; elit sınıfı mor kimliği XP çubuğuyla tutarlı (`xp` mor korunur). **`hareket_azalt` AÇIKken küre süzülmesi durur** (kullanıcı kararı). Normal–boss kriteri için karar önerisi hâlâ açık (§9-1).

## 6. `hareket_azalt` kapsamı (kullanıcı kararı: hepsi durur)
| Hareket | Açıkken |
|---|---|
| Hareketli portre (seçim ekranı) | statik portre |
| Elit/boss küre süzülmesi (±3/±4 px) | sabit |
| Ana sayfa kül/kor parçacıkları | görünmez (parçacık düğümü `visible=false`, `emitting=false`) |
| Meşale titremesi | sabit düşük parlaklık |
| Sancak sallanma (shader) | sabit |
| Karakter nefesi (`ShowcaseMotion`) | sabit |
| Anahtar kıvılcımı, satır açılma animasyonu | anlık (animasyonsuz) |
| Dokunma geri bildirimi (80 ms), ekran girişi (220 ms) | **çalışır** (girdi/duran geçiş; titreme değil) — *öneri; ekran girişi de kapatılabilir* |
Ayar satırı metni buna uyar; varsayılan KAPALI.

## 7. Varlıklar ve kaynakları (mock/ ve frames/)
- `mock/assets/*.png`: `art/ref/harita/harabe-parcalari.png` (yeşil perde silinmiş kırpmalar) ve `zemin-doku.png` (eliptik maske) ile `docs/ui/mockups/assets/gunslinger-atis-keyed.png` (kenar eritme) **türevleridir**; yeni görsel yok. Uygulama için kalıcı doku üretimi `tools/art` işidir (developer).
- `frames/*.svg`: yeni, elle yazıldı; 9-slice kenar payları `frames/README.md`.
- Taş duvar dokusu (ayarlar/başarım zemini): maketteki SVG desen **yalnız maket**; gerçek doku yeni görseldir → kullanıcıya gösterilmeden repoya girmez (§9-5).
- `mock/` ve `frames/` için `docs/design/v2.0.3/.gdignore` var (APK'ya/içe aktarmaya girmez); commit'li `*.png.import` dosyaları silindi.

## 8. Erişilebilirlik ve uygulama notları
- **Kontrast:** `tokens-v2.0.3.md` §3 (hesaplandı). Kilitli/pasif/soluk metin soluklaştırılmaz; `tas_600` üstünde `kemik_500` metin yok (4,5, sınır).
- **Dokunma:** tüm hedef ≥132, aralık ≥27 (ayarlar kartları aralığı 30); mühür bandı 187×132; satır dokunma = aç/kapa, kaydırma eşiği 24 px.
- **Metin:** min 26 px; 2× yazıda sarma/tek sütun, kesilme yok.
- **Renk dışı kanal:** anahtar = konum + sözcük; kademe = silüet + rozet + segment; kilit = rozet + metin; sessiz = çizili hoparlör + açıklama.
- **Odak/D-pad:** `border_focus` 6 px; sıralar §2–§4; mühür şeridi ◄► ile gezilir.
- **TalkBack (`accessibility_name`):** "Ses, kapalı" · "Müzik, yüzde 70" · "Hareketi azalt, kapalı" · "Başarımlar, 31 / 53 kademe" · "THE WATCH, 5 / 10" · "Öldürme, kademe 2 / 4, sonraki hedef 5.000, 2.940" · "Üç Elit, tamamlandı".
- **Türkçe büyük harf:** Türkçe metin `UiKit.upper_tr`. **İngilizce grup/aile adları sabit büyük harf yazılır, `upper_tr` KULLANILMAZ** ("i"→"İ" olur). `to_upper` yasak (gate).
- **Kabul/test (uygulama için):** namlu alevi kenarda kesilmez (kutu içi sınır testi); `hareket_azalt` AÇIK = parçacık/titreme/nefes/süzülme yok; 2× yazıda başlık kesilmez; kaydırıcı sürüklerken anahtar tetiklenmez; güvenli alan testi ayarlar dahil; kademe ayrımı gri tonlama ekran görüntüsünde de ayırt edilir; bildirim–liste tutarlılığı; satır açık/kapalı `accessibility_name`; sticky başlık.
- **ui-ux-pro-max pre-delivery kontrolü:** emoji ikon yok (SVG/PNG) ✓ · dokunma geri bildirimi (basılı durum + 80 ms) ✓ · kontrast tablosu ✓ · safe area ✓ · reduced motion ✓ · tutarlı ikon dili ✓.

## 9. Açık noktalar (kullanıcı kararı gerektirenler)
1. **Normal–boss küre çifti ΔL* 4,9 (<15):** kriter yorumu (ΔL* **veya** boyut ≥1,8× + IoU ≤0,6) mi, boss koyultma mı?
2. **Başarım GRUP adları — İngilizce (seçilecek):** aşağıdaki setlerden biri (ya da karışık). Görünüm: `mock/06-isim-onerileri`.

| Grup (TR) | A · "THE …" (önerilen) | B · eylem | C · yalın |
|---|---|---|---|
| SAĞ KALIM | THE WATCH | LAST STAND | SURVIVAL |
| KIRIM | THE CULLING | BODY COUNT | CARNAGE |
| BOSS | THE CROWNED | THRONE BREAKERS | WARLORDS |
| USTALIK | THE ARMORY | MASTERY | CRAFT |
| YOLCULUK | THE ROAD | PILGRIMAGE | JOURNEY |
   Gerekçe: A seti kale/harabe metaforuyla tutarlı tek kalıp (çatı, nöbet, taç, cephanelik, yol); B eylem odaklı ama uzunluk değişken (THRONE BREAKERS 15 harf); C en yalın/en az karakter.
3. **Aile adları — İngilizce karşılık (isteğe bağlı; ilk öneri):** Hayatta Kalma → Endure / Last Light · Seviye → Ascendant / Rise · Kırım → Rampage / Onslaught · Öldürme → Reaper / Slayer · Boss Avcısı → Bossbane / Giant Slayer · Üç Elit → Elite Trio / Triple Crown · Evrim → Ascension / Rebirth · Tambur Ustası → Quick Hands / Spinner · Seri Ustası → Unbroken / Streak · Skor → Renown / Tally · Bomba Ustası → Demolisher / Bombardier · Eklenti Avcısı → Scavenger / Relic Hunter · Dokunulmaz → Untouched / Ghostwalk · Yerleşik → Garrison / Returning · Tam Kadro → Full Arsenal / Loaded · Sınırsız Kırım → Unbound / Limitless · Kale Lordu → Lordslayer / Usurper · Nöbet → Vigil / Night Watch · Çifte Yol → Two Roads / Dual Path. Aile adları Türkçe kalırsa grup başlıkları İngilizce, satır adları Türkçe olur (maketteki hâl).
4. Kademe yolu satırı içi açılma (dokun-aç) ve mühüre dokun → gruba kay: onay (alternatif: yalnız sonraki hedef; yalnız sticky başlık).
5. **Taş duvar dokusu** (ayarlar/başarım zemini) ve kalıcı sahne dokuları (kemer/kule/sur/sancak/meşale, zemin yaması) yeni görsel gerektirir: kod/gürültü ile mi, `harabe-parcalari` işlemesiyle mi, yoksa Codex üretimi mi? (Üretim olursa repoya girmeden `[VLAD:ASK]`.)
6. Ekran girişi (220 ms) `hareket_azalt`'ta da kalsın mı (öneri: evet; yalnız dekoratif hareket kapanır).
7. Başlık harf içi "kül→kemik" degrade (shader) isteniyor mu, düz `kemik_100` + taş oyma yeterli mi?
8. Tek sürüm kaynağı (`application/config/version`).
9. **Varsayımlar / doğrulanamayanlar:** maketler Chromium'dur, Godot render'ı değil (yazı tipi/9-slice yaklaşık); cihazda perf (≤40 parçacık, shader, p95) ölçülmedi; 2× yazı makette elle ölçeklendi; rakip ekranları (Brotato vb.) görsel olarak doğrulanamadı (Director brifi de aynısını belirtti); `impeccable` web dedektörü çalıştırılmadı; dokunmatik elde hissi denetlenemedi (v2.0.3 kullanıcı listesine eklenmeli: kaydırıcıda liste kayması, anahtar kazara tetik, ana sayfa akıcılığı Redmi Note 13 Pro).
