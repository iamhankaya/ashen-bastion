# Ashen Bastion v2.0.3 — Tasarım (ana sayfa, ayarlar, başarımlar, ruh küreleri)

Tarih: 2026-10-26 · Görev: T20261026-58 (çatı T20261026-56) · Faz: tasarım, kod yok.
Girdiler: spec raporu T20261026-57 (kullanıcı kararlarıyla), `docs/ui/DESIGN-UI.md`, `docs/ui/tokens.json`, `docs/design/v2.0/DESIGN.md` (+`tokens-v2.0.md`), kod: `main_menu.gd`, `settings_screen.gd`, `achievements_screen.gd`, `gem_renderer.gd`; küre kaynakları `art/source/gem-orbs/`.
Maketler: `mock/` (statik HTML + Chromium ekran görüntüsü, **1080×2400**, kaynak `mock/build.py` → `python3 build.py && node shoot.js`). Token'lar: `tokens-v2.0.3.md` (+ `.json`). Küre brifi: §5.
Godot Control ağacına uygulanır (web değil); ölçüler 1080×2400 tasarım pikseli, 1 dp ≈ 2,75 px, dokunma ≥132, güvenli alan üst 96 / alt 72 / yan 36 (çentikte `apply_safe_area`). **Yeni renk/yazı tipi yok**: v2.0 + `tokens.json` yeniden kullanıldı. Etiketler: *(öneri)* = kesin değeri uygulama fazı belirler; **[AÇIK]** = kullanıcı kararı.

## 1. Temel kararlar

| # | Karar | Gerekçe |
|---|---|---|
| D1 | **Ana sayfa:** SES/TİTREŞİM satırı kalkar; yerine **EN İYİ SKORLAR \| AYARLAR** yarım düğmeleri (454×132). AYARLAR sağ-üst köşeden ana sütuna iner. | Köşe düğmesi sabit koordinatlı, 26 px yazılı, başparmaktan uzak ve güvenli alan dışıydı (spec D, `main_menu.gd:27-28,216-225`; v2.0.1 çentik hatası). Ana sütunda 132 px hedefi, aynı stil, başparmak bölgesinde. |
| D2 | **Ana görsel aynı resim, 960×960 → 960×1100** (y 560–1660). | Ayarlar satırı kalkınca 137 px boşalır; kullanıcı kararı "ana görsel değişmez" korunur (yeniden çizim yok), yalnız ölçek +%15. |
| D3 | **Sürüm satırı** `Sürüm 2.0.3 · <karakter>` y 2288–2328 (bayat `VERSION="2.0"` kalkar; sürüm tek kaynaktan, **öneri:** `ProjectSettings` `application/config/version`). | Spec D bulgusu. |
| D4 | **Ayarlar = bölümlü kartlar:** SES · DOKUNUŞ · GÖRÜNÜM · HAKKINDA; her satırın tamamı dokunur (≥132). Anahtar = 156×84 + **AÇIK/KAPALI sözcüğü**. | Düz yazı listesi yerine düzgün kontroller (görev Tanım). Renk tek başına anlam taşımaz (anahtar konumu + sözcük). |
| D5 | **Ses modeli tek anahtar + iki kaydırıcı:** `TÜM SESLER` (eski ana-sayfa SES = `sound_on`), MÜZİK, EFEKT. Anahtar kapalıyken kaydırıcılar soluk (yine okunur) ve **kaydırıcıya dokunmak sesi açar**. | Spec: SES ayarlara taşınır; üç modelin çelişkisi (`sound_on` + `music_pct` + `sfx_pct`) kullanıcıya tek yerde, mantıklı sırada gösterilir. Kapalı + kaydırıcı = "çalışmıyor" sanılmasın. |
| D6 | **HAREKETİ AZALT** anahtarı GÖRÜNÜM'de (varsayılan KAPALI; kullanıcı kararı). | Hareketli portre yalnız seçim ekranında; açıkken statik portre + nefes/sürüklenme/parçacık yok. |
| D7 | **HAKKINDA:** Sürüm + LİSANSLAR (›) alt ekranı (yazı tipleri OFL, ses `LICENSES-audio.md`). | Kullanıcı kararı "HAKKINDA". Oyun içi lisans yüzeyi yoktu. |
| D8 | **Başarım = aile, kademe = Romen rakamı + baklava + çerçeve rengi.** Kademe başına yeni ikon yok. | Kullanıcı kararı (kademe gösterimi çerçeve). 53 kademe için 53 ikon APK/üretim maliyeti; çerçeve + rakam + baklava üç kanalda anlam verir. |
| D9 | **Satır = ilerleme odaklı:** sonraki kademeye `değer/hedef` + çubuk; tamamlananda **TAMAM** çipi. "TEK KOŞU" çipi kalkar (spec: `best.*` genişler). | Kullanıcı "seviye ve ilerleme gösterimi" istedi. |
| D10 | **Satıra dokun = kademe listesini aç/kapa** (satır içi, aynı anda 1 açık). Sürükleme kaydırır. | 4 eşiğin hepsini görmek için ayrı ekran gerekmez; tarih + hedef tek yerde. |
| D11 | **Küreler:** üç tip aynı ruh-alevi ailesi; ayrım **renk + boyut (34/48/68 px) + silüet (taç, halka)**; normal kendi başına soğuk-beyaz, elit mor, boss amber. | Kullanıcı seçimi (normal/elit/boss_ruh_3). Renk körlüğü §5.3. |

## 2. Ana sayfa (`01-ana-sayfa.png`, ölçülü `01b`, ilk açılış `01c`, 2× yazı `01d`)

Sütun x 72–1008, aralık 27; **sütun üstü y 1763** (v2.0: 1556), alt sınır 2261, sürüm y 2288.

| Öğe | Boyut | y | Not |
|---|---|---|---|
| OYNA | 936×180 | 1763 | değişmedi (birincil, bordo) |
| KARAKTERLER \| BAŞARIMLAR | 454×132 ×2 | 1970 | v2.0 ile aynı; alt satır = karakter adı, **`açılan/toplam` kademe sayısı** ("31/53"; `DEFAULT_ACH_TOTAL` kalkar, `set_achievement_count(open,total)` imzası aynı) |
| EN İYİ SKORLAR \| AYARLAR | 454×132 ×2 | 2129 | ikon 52 + Cinzel 700 **34** (+0,06 em); `button_secondary`; dişli glifi `UiKit.Glyph` (yeni `gear`) |
| Sürüm | Inter 600 26 `kemik_500` (A pasif metin 5,9:1) | 2288 | tek satır, ortalı |
| Ana görsel | 960×1100 `contain` | 560–1660 | alt gradyan y 1683'te başlar |

Durumlar: varsayılan · basılı (6 px aşağı) · odak (`border_focus` 6 px; sıra OYNA → KARAKTERLER → BAŞARIMLAR → SKORLAR → AYARLAR) · ilk açılış `0/53`, Gunslinger (`01c`) · kayıt okunamadı: varsayılan karakter + `0/53`, hata iletisi yok (v2.0 ile aynı) · **2× yazı (`01d`)**: yarım düğmeler **tek sütuna** düşer (168 yüksek, etiket 56 px, alt satır 52 px), sütun üstü y 1301, ana görsel 700 yüksekliğe küçülür; OYNA 80 px. Kural: `font_scale > 1,3` ise tek sütun. Başlık (ASH AND STEEL / ASHEN BASTION) sanat işi olarak ölçeklenmez.
Güvenli alan: tüm sütun + sürüm `apply_safe_area` (AYARLAR artık sütunda; ayrı offset yok → `_place_trophy`, `SETTINGS_TOP/W/H` sabitleri kalkar).

## 3. Ayarlar (`02-ayarlar.png`, ölçülü `02a`, sessiz+hareket azalt `02b`, 2× `02c`, lisanslar `02d`)

Başlık "AYARLAR" y 130 ortalı, Cinzel 900 80 (BAŞARIMLAR ile aynı). Liste **kaydırmalı** y 260–2172 (üst/alt 80 px solma, 8 px kaydırma ipucu); GERİ **sabit** y 2196–2328 (alt 72 güvenli). Bölüm başlığı 72 yüksek, Cinzel 700 34 (+0,14 em) `bronz_300`; kart 936 genişlik, aralık 36, iç dolgu 30.

| Bölüm | İçerik | Yükseklik (varsayılan yazı) |
|---|---|---|
| SES | TÜM SESLER (anahtar) · MÜZİK `%0–100` (%5 adım) · EFEKT | 560 (sessizken +40: "Ses kapalı. Bir kaydırıcıya dokunmak sesi açar.") |
| DOKUNUŞ | TİTREŞİM + 1 satır açıklama | 176 |
| GÖRÜNÜM | HAREKETİ AZALT + 2 satır açıklama | 226 |
| HAKKINDA | SÜRÜM `2.0.3` · LİSANSLAR › | 316 |

Bileşenler:
- **Anahtar** 156×84, topuz 60; AÇIK: `bordo_700` zemin, `bronz_300` kenar, topuz sağda, sözcük `kemik_100`; KAPALI: `mor_900` zemin, `kahve_500` kenar, topuz solda `kemik_500`, sözcük `kemik_500`. Sözcük Inter 700 26. Tüm satır tek dokunma hedefi; 80 ms geri bildirim.
- **Kaydırıcı** dokunma bandı 132 (ray 20 + kenar 3, tutamak 84 `kemik_100` + 6 px `bronz_500`), dolgu `bronz_500 → bronz_300`; değer Cinzel 700 40 sağda ("%70"). Sürüklerken ses anında değişir; bırakınca kaydedilir; EFEKT bırakılınca örnek atış (mevcut davranış korunur).
- **Soluk (sessiz) durum:** dolgu `kahve_500`, tutamak `kemik_500`; **değer metni soluklaştırılmaz** (kontrast ≥4,5:1; `kemik_500/mor_800` 5,9).
- Satır etiketi Cinzel 700 36 (+0,06 em) `UiKit.upper_tr`; açıklama Inter 400 28/34 `kemik_300`.

Durumlar: varsayılan (`02`) · sessiz + hareket azalt açık + titreşim kapalı (`02b`) · **2× yazı (`02c`)**: etiketler 72 px, açıklama 56 px; anahtar etiketin **altına** sarar, kartlar uzar, liste kaydırılır, GERİ sabit kalır (kesilme yok) · LİSANSLAR alt ekranı (`02d`): kaydırmalı liste, GERİ → ayarlar · duraklatmadan açıldığında: aynı ekran, GERİ duraklatmaya döner (`pause_screen.gd` girişi korunur) · eski `settings.cfg`: `hareket_azalt=false`.
Odak/D-pad: ▲▼ satırlar, ◄► kaydırıcı (5 puan), A/Enter anahtar; varsayılan odak ilk satır; Android geri = GERİ.
Güvenli alan: `apply_safe_area` **ayarlar ekranı dahil** (spec: `_apply_safe_areas` ayarları içermiyor, kart çalışma notu ihlali); üst pay başlık + liste üstünü, alt pay GERİ'yi kaydırır, liste yüksekliği payı emer. `COL_TOP=380` sabiti kalkar.
Hata durumu yok (yerel dosya). Yükleme yok.

## 4. Başarımlar (`03-basarimlar.png`, ölçülü `03a`, boş `03b`, hepsi açık `03c`, satır açık `03d`, kademe dili `04`)

### 4.1 Ekran

| Blok | Konum / boyut | İçerik |
|---|---|---|
| Başlık | y 130 | BAŞARIMLAR Cinzel 900 80 |
| Özet | y 250 / çubuk y 340 | `31 / 53` Cinzel 700 56 + "kademe" Inter 600 32; çubuk 936×20 |
| Liste | y 400–2172 kaydırmalı | grup başlığı + aile satırları |
| Grup başlığı | 936×72 | SAĞ KALIM · KIRIM · BOSS · USTALIK · YOLCULUK (Cinzel 700 34); sağda `açılan kademe / toplam kademe` Inter 700 28, tamamlanınca `amber_glow` |
| Aile satırı | 936×**168**, aralık 12 | §4.2 |
| GERİ | y 2196 | sabit |

Grup kademe toplamları spec tablosundan kodla hesaplanır (maketteki `5/11`, `7/14` yalnız örnektir). Aile → grup eşlemesi *(öneri)*: SAĞ KALIM: Hayatta Kalma, Dokunulmaz, Nöbet · KIRIM: Kırım, Öldürme, Sınırsız Kırım, Bomba Ustası · BOSS: Boss Avcısı, Üç Elit, Kale Lordu · USTALIK: Seviye, Evrim, Tambur Ustası, Seri Ustası, Skor, Eklenti Avcısı, Tam Kadro · YOLCULUK: Yerleşik, Çifte Yol (19 aile). Aile adları spec tablosundaki Türkçe adlarla (açık nokta 2 kapanır; ≤22 harf).

### 4.2 Aile satırı anatomisi (936×168, `panel`, dolgu 24)
| Parça | Ölçü | Açık / ilerleyen | Kilitli (0 kademe) |
|---|---|---|---|
| Plaka | 108×108, 5 px kenar = **kademe rengi**, ikon 68 | + sağ-alt **Romen rakamı** rozeti 46 (Cinzel 700 28, `bordo_900` zemin) | ikon %45 gri, kenar `kahve_500`, kilit rozeti 40 |
| Ad | Cinzel 700 38/44 `upper_tr` tek satır | `kemik_100` | aynı (soluklaştırılmaz) |
| Baklavalar + etiket | 16 px baklava × kademe sayısı (dolu = açıldı, kademe rengi); "KADEME II" Inter 600 26 | | "0 / 3" |
| Açıklama | Inter 400 28/34 `kemik_300`, tek satır `…` | **sonraki** kademenin tanımı | ilk kademe |
| Sağ sütun 232 | `değer/hedef` Cinzel 700 34 + 14 px çubuk | sonraki kademeye | `0/hedef` |
| Tamamlanmış | — | kenar `bronz_500`, plaka `amber_glow`, **TAMAM** çipi (amber 3 px kenar, Inter 700 26) + son tarih; açıklama "Tüm kademeler açıldı." | — |

Değer biçimi: süre `d:ss` (≤1 sa) / `dk` / `sa`; sayılar `tr` binlik nokta; hedefi aşan `hedef/hedef`. Koşu-kapsamlı ailede değer = kalıcı **en iyi** (spec).

### 4.3 Durumlar
| Durum | Gösterim |
|---|---|
| Varsayılan (`03`) | gruplar, ilerleyen/kilitli/TAMAM karışık |
| **Boş / hepsi kilitli** (`03b`) | `0 / 53`, çubuk boş, 108 yüksek panel "Henüz kademe açılmadı. Bir koşuya başla.", tüm satırlar kilitli, hata iletisi yok |
| **Hepsi açık** (`03c`) | `53 / 53` amber, çubuk amber, panel "Tüm başarımlar açıldı.", grup sayaçları amber |
| **Satır açık** (`03d`) | satırın altında 4 kademe satırı: Romen · eşik · `✓ tarih` ya da `değer/hedef` / `Hedef N` (72 yüksek); açıkken ok yok, tekrar dokunma kapatır |
| Kademe atlama | koşu içi bildirim "BAŞARIM AÇILDI · KADEME III / ÖLDÜRME III" (`04`); çoklu eşik = tek bildirim |
| Sonuç özeti | "★ YENİ KADEME · N" çipi (v2.0 §5.3 ile aynı, metin "BAŞARIM" yerine "KADEME") |
| Bilinmeyen kimlik | gösterilmez, silinmez |

### 4.4 Kademe dili (`04-kademe-dili.png`)
| Kademe | Çerçeve | Baklava | Rakam |
|---|---|---|---|
| Kilitli | `kahve_500` | boş | kilit |
| I | `kemik_300` #CFC4AE | ◆◇◇◇ | I |
| II | `bronz_300` #D2B47E | ◆◆◇◇ | II |
| III | `amber_glow` | ◆◆◆◇ | III |
| IV | `amber_glow` + bordo plaka + `glow_amber` | ◆◆◆◆ | IV |
| TAMAM | `amber_glow` | hepsi dolu | "TAMAM" çipi |
Anlam üç kanaldan (renk + rakam + baklava); renk körü için rakam yeterli. 1–3 kademeli ailelerde baklava sayısı kademe sayısı kadar, III. kademesi son olan ailede amber = tamamlanmış çerçeve.

## 5. Ruh küreleri — görsel brif (`05-kure-gorsel-yonu.png`)

### 5.1 Yön
Üç küre **aynı ruh-alevi ailesi** (gözyaşı biçimli alev, iki boş/parlak göz, kuyruk): kullanıcı seçimi `normal_ruh_3`, `elit_ruh_3`, `boss_ruh_3` (kaynak `art/source/gem-orbs/{normal,elit,ara_boss}.png`, yeniden üretilmez). Ayrım üç kanaldan:

| Tip | Renk (ölçülen çekirdek) | Silüet | Ekran boyutu | Işıma (kodla) |
|---|---|---|---|---|
| Normal (xp<5) | soğuk beyaz-camgöbeği, RGB≈165,202,221 | küçük, ince, tek kuyruk | **34 px** (v1: 30) | yok (yalnız dokunun kendi halesi) |
| Elit (5≤xp<80) | koyu doygun mor, RGB≈126,42,171 | geniş, 3 kuyruk, yörüngede kıvılcım halkası | **48 px** | hafif mor hale, yavaş **süzülme ±3 px / 1,8 sn** |
| Ara boss (xp≥80) | sıcak altın-amber + beyaz sıcak çekirdek, RGB≈227,170,88 | en büyük, **taç** + 4 kor | **68 px** | amber hale + süzülme ±4 px / 1,4 sn |
Birleşmiş taş (`GemPool` birleşmesi): sınıf **değerden** (eşikler yukarıda), boyut sınıf içinde `scale_for_value` ile ±%10; sınıf sınırı atlamaz. **Sim değişmez**; hash yalnız `count`/`total_value` (spec).

### 5.2 Tasarım gerekçesi
- Mor XP kimliği (`xp #7C5CC4`) **elit sınıfında** korunur; XP çubuğu rengiyle tutarlı ("elit = çubuğu dolduran büyük ruh"); normal soğuk-beyaz ağırlıksızdır, boss amber `amber_glow` anlamıyla uyumlu (sıcak = güç/uyarı). Amber yalnız boss'ta kullanıldığı için "dikkat" anlamı aşınmaz.
- Süzülme yalnız elit/boss: normal binlerce olabilir (CAP 300) → tek MultiMesh, kare başına ek maliyet yok; hareket **kayma kaydırma shader'ında (`TIME + instance id`)** *(öneri)*, `hareket_azalt` açıkken kapalı (oyun içi hareket azaltma yalnız portre için kullanıcı kararı; bu madde **[AÇIK 3]**).
- Zemin üstü okunurluk: kemik/mor zemin (`#120b19`) üstünde üç küre de ≥ 3:1 parlaklık farkı taşır (L*≥36 mor, çekirdek parlak).

### 5.3 Ayırt edilebilirlik ölçümü (128 px, opak çekirdek, Machado simülasyonu)
| | L* normal | protan | deutan | tritan | alan |
|---|---|---|---|---|---|
| Normal | 79,0 | 80,4 | 78,0 | 79,1 | %11 |
| Elit | 36,2 | 36,9 | 38,0 | 37,4 | %25 |
| Boss | 74,1 | 70,6 | 76,0 | 73,1 | %23 |

- Normal–elit ΔL* ≥ 41, elit–boss ΔL* ≥ 33 (≥15 ✓, her simülasyonda).
- **Normal–boss ΔL* = 4,9 (protan 9,8) < 15 ✗.** Silüet IoU normal–elit 0,37, normal–boss 0,46, elit–boss 0,51 (≤0,6 ✓); boyut oranı 1:2 (68/34).
- **Karar önerisi:** çift kriteri "ΔL* ≥ 15 **veya** (boyut oranı ≥ 1,8 **ve** IoU ≤ 0,6)" olarak okunur; normal–boss bu ikinci yoldan geçer. Katı ΔL* gerekirse boss çekirdeği `Color(.75,.62,.5)` ile ~%28 koyulaşır (ΔL*≈15) ama "en parlak ruh" hissi azalır → **[AÇIK 1]**.
- Ölçüm yöntemi: PIL, 128 px, α>0,8 piksel ortalaması; simülasyon sRGB→doğrusal, Machado 2009 (şiddet 1,0). Maketteki CVD görselleri tarayıcı `feColorMatrix` ile yaklaşıktır.
- Uygulama B'nin yapacağı: aynı ölçümü işlenmiş 128 px atlas kareleri üzerinde yeniden koşmak (`tools/art/process_gem_orbs.py` testi).

### 5.4 Uygulama notları (B için)
İşlenmiş doku 128×128 (normal 96 ile yeterli) şeffaf PNG; kenar payı ≥%8; `assets/gfx/fx/gems/`. Tek MultiMesh yerine tip başına 3 MultiMesh (aynı `GemRenderer` API'si) ya da atlas+`INSTANCE_CUSTOM`; ikisi de sim'e dokunmaz. Mevcut `COLOR_XP`/`COLOR_XP_BRIGHT` sabitleri ve değer<=1 ayrımı kalkar.

## 6. Erişilebilirlik
- **Kontrast (v2.0/v1 tablolarından, yeni çift yok):** `kemik_100/mor_800` 13,8 · `kemik_300/mor_800` 9,8 · `kemik_500/mor_800` 5,9 · `bronz_300/mor_800` 8,5 · AÇIK anahtar sözcüğü `kemik_100/bordo_700` 10,3 · `amber/mor_800` 7,8 · kademe I/II/III çerçeve `≥3:1` (`kemik_300`, `bronz_300`, `amber` / `kahve_700`). **Kilitli/pasif/soluk (sessiz) metinler soluklaştırılmaz.**
- **Min metin 26 px**; 2× yazı: etiketler ×2 (72/56), kesilme yok (taşma = satır sarma ya da tek sütuna düşme, tablo §2, §3). Başlık/sanat metni (ASHEN BASTION) ölçeklenmez.
- **Dokunma:** tüm hedefler ≥132 (anahtar satırı 132+, kaydırıcı bandı 132, GERİ 132), aralık ≥27; başarım satırı dokunma = aç/kapa (kazara geri dönüşü yok), kaydırma sürüklemesi dokunmayı yutmaz (eşik 24 px).
- **Renk tek başına anlam taşımaz:** anahtar = konum + sözcük; kademe = rakam + baklava + çerçeve; kilit = rozet + ilerleme metni.
- **Hareket/ışık:** hiçbir yeni öğe yanıp sönmez; küre süzülmesi ≤0,7 Hz ve ≤4 px; `hareket_azalt` portre için; anahtar geçişi 140 ms.
- **Odak/klavye:** `border_focus` 6 px; sıralar §2–§3; diyalog yok.
- **TalkBack (`accessibility_name`, Godot'ta destek varsa):** "Ayarlar" · "Tüm sesler, açık" · "Müzik, yüzde 70, kaydırıcı" · "Hareketi azalt, kapalı" · "Sürüm 2.0.3" · "Başarımlar, 31 / 53 kademe" · "Öldürme, kademe 2 / 4, sonraki hedef 5.000, 2.940" · "Üç Elit, tamamlandı".
- **Türkçe büyük harf:** tüm dinamik metin `UiKit.upper_tr` (`to_upper` yasak); testte "İ/ı" (İLK, KALABALIK) denetlenir. "dk/sa" Cinzel'de büyük görünür (40 DK / 1 SA) — kabul.
- **Güvenli alan:** ana sayfa sütunu + sürüm, ayarlar (liste + GERİ), başarımlar zaten; çentik ve gezinti çubuğunda testli.

## 7. Dosya etkisi (uygulama D/C/B için girdi)
- **D:** `main_menu.gd` (SES/TİTREŞİM satırı ve `_place_trophy`, `SETTINGS_*` kalkar; 2×2 yarım düğme ızgarası; sürüm), `settings_screen.gd` (yeniden yazım, `ScrollContainer`, `apply_safe_area`), `UiKit` (yeni `gear` glifi, `switch` bileşeni — `UiKit` sahibi D), `tools/capture/shots*.gd` (ekranlar), `docs/ui/DESIGN-UI.md` §6.1'e "bkz. v2.0.3" notu. `game_controller.gd` +2 satır payı.
- **C:** `achievements_screen.gd` (aile satırı, açılır kademe listesi, grup eşlemesi), `achievement_icons.gd` (`tier_color` → kademe rengi 1–4 + tamam), `achievement_toast.gd` (rakam + baklava).
- **B:** `gem_renderer.gd`, `gem_tiers.gd`, `assets/gfx/fx/gems/*`.

## 8. Doğrulanmayanlar / varsayımlar
- Maketler Chromium'dur, Godot render'ı değil; yazı tipi ölçüleri Cinzel/Inter ile (oyundaki font yüklemesi aynı dosyalar).
- 2× yazı yalnız elle ölçeklenmiş makette gösterildi; gerçek `font_scale` Android'de Godot'ta sistem ayarından okunmaz *(Godot sürümüne bağlı)* — oyun içi 2× ölçek karşılığı **varsayım**: tüm `font_size` ×2 test modu.
- Küre süzülme/hale oyun içi perf cihazda ölçülmedi.
- Başarım eşik/grup toplamları spec'ten; örnek sayılar maket içindir.
- Skill'ler: bkz. kapanış raporu.

## 9. Açık noktalar
1. **Normal–boss küre çifti ΔL* < 15** (4,9): kriter yorumu mu, boss koyulaştırma mı (§5.3)?
2. Kademe eşik/aile adları spec tablosundan; grup eşlemesi (§4.1) kullanıcı onayı.
3. **Hareket azaltma küre süzülmesini de kapatsın mı?** (öneri: evet; kullanıcı kararı yalnız portre için.)
4. Satır içi kademe listesi (D10) onayı; alternatif: yalnız sonraki hedef.
5. `application/config/version` ile tek sürüm kaynağı (öneri) — sözleşme/D kararı.
