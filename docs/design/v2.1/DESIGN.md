# Ashen Bastion v2.1 — Tasarım (koşu modu + zorluk seçimi)

Tarih: 2026-10-27 · Görev: T20261027-17 (çatı T20261027-15) · Faz: tasarım. Kod yazılmadı.
Girdiler: spec fazı kapanış raporu (T20261027-16) ve **kullanıcı kararı (2026-10-27 11:58): K1–K6 hepsi önerilen; eski highscore girişleri Normal**; `docs/design/v2.0.3/` (DESIGN, token'lar, `frames/`), UI yön brifi `docs/review/v2.0.3-ui-direction.md` (T20261026-69), mevcut ekran kodları (`main_menu.gd`, `result_screen.gd`, `highscore_screen.gd`).
Çıktı: `mock/` (maketler 1080×2400 PNG + HTML), `tokens-v2.1.md` + `.json`. Yeniden üretmek: `cd mock && python3 build.py && python3 shoot.py` (headless Chrome/Edge; ek bağımlılık yok). Yüzey çerçeveleri v2.0.3 `frames/`'ten gelir; **yeni SVG çerçeve yok**.
Uygulama dili Godot Control / `StyleBoxTexture` (9-slice) / Label; maketler Chromium'dur (yazı tipi ve 9-slice yaklaşık).

## 0. Skill'ler
| Skill | Durum | Katkı |
|---|---|---|
| `ui-ux-pro-max` | yüklendi | Dokunma hedefi ≥132 px (48 dp), seçili durumun yalnız renkle verilmemesi, tek-parmak/alt-bölge kuralı, kontrast hesabı (§7). `search.py` çalıştırılmadı: v2.0.3'te aynı alan için jenerik (web landing) çıktı verdiği ve uygunsuz bulunduğu belgelenmişti; yeni bir sorgu bilgi eklemedi. |
| `impeccable` | yüklendi (yalnız `shape`/`document` yönü) | Ekran başına tek soru (§2–§5), bu belge + token tabloları. `impeccable context/detect` (web DOM dedektörü) çalıştırılmadı: Godot ekranı, DOM yok. |
| `design-taste-frontend` | yüklendi, **uygulanmadı** | Rol kuralı: yalnız halka açık web sayfaları için. Oyun menüsü/uygulama ekranı. Web yasakları (gradyan/gölge/ince çizgi) v2.0.3 gibi oyun sanatına uygulanmadı. |
Yüklenemeyen skill yok.

## 1. Karar: seçim nerede?
**Soru:** koşu modu + zorluk karakter seçiminden sonra mı, ana sayfada mı? **Karar: ana sayfada tek "koşu şeridi", ayrıntı `KOŞU` alt ekranında.** Spec K1 de "ana sayfada seçilir, koşuda kilitli" der.

| Seçenek | Artı | Eksi | Karar |
|---|---|---|---|
| A. Ana sayfada şerit → `KOŞU` ekranı (seçilen) | Tekrar oynayan oyuncu için **0 ek dokunma** (OYNA son seçimle başlar); seçim görünür (neyi oynayacağını görür); karakter akışına dokunmaz | Ana sayfaya bir öğe daha (OYNA'nın üstü doluyor) | **Seçildi** |
| B. OYNA → ek "koşu hazırlığı" ekranı | Ana sayfa değişmez | Her koşuda +1 ekran/dokunma (market araştırması: "kasmasız" fırsatı) | Hayır |
| C. Karakter seçiminden sonra | Karakter başına zorluk (spec dışı) | Karakter ekranı zaten dolu; 2 karakter varken her koşuda ek adım | Hayır |
| D. Ana sayfada 6 satır (3+3 düğme) | Sıfır ek ekran | 2× yazıda sığmaz, hiyerarşiyi bozar | Hayır |

Tek soru ana sayfada: "Neyi oynayacağım?" → şerit cevaplar; "Oynamaya hazır mıyım?" (v2.0.3) → OYNA cevaplar. Seçim **anında kaydedilir** (`settings.cfg` `zorluk`, `mod`; varsayılan `normal`/`normal`), `KOŞU` ekranında onay düğmesi yok: tek düğme GERİ (ayarlar ekranıyla aynı model).
**Koşuda kilitli:** koşu başlayınca değişmez; HUD'da seçim UI'ı yok. Duraklatma ekranı yalnız bilgi çipleri gösterir (§5).

## 2. Ana sayfa (`mock/01-ana-sayfa`, anatomi `01a`, 2× yazı `01b`)
**Değişiklik:** OYNA'nın 27 px üstüne **koşu şeridi** (936×132, y 1604–1736). v2.0.3'ün diğer her şeyi aynı (OYNA y1763, 454×132 yarım düğmeler, sürüm). Sürüm satırı `Sürüm 2.1.0`.
- Yüzey: `levha` 9-slice (taş); OYNA'dan **bilinçli geri planda**: ana eylem OYNA kalır (bordo = tek birincil), şerit bilgi + ikincil kontrol. Kenar `bronz_700`'ün dekoratif tonu seçilebilirliği taşımaz; seçilebilirlik sağdaki **`DEĞİŞTİR ›`** yazısı + tüm şeridin tek dokunma hedefi olmasıyla verilir.
- İçerik: sol mod glifi 64 (§4) · `NORMAL · 20 DK` (Cinzel 34/700, `kemik_100`) · alt satır `Zorluk: Normal` + 1–3 kalkan (Inter 26/600, `kemik_300`) · sağ `DEĞİŞTİR ›` (Inter 26/700 +0,08 em, `bronz_300`).
- Sonsuz: `SONSUZ` (süre yok, `· ∞` yazılmaz).
- Basılı: `dugme-basili` benzeri 6 px iniş + 80 ms; odak sırası **şerit → OYNA → KARAKTERLER → BAŞARIMLAR → SKORLAR → AYARLAR**.
- **Durumlar:** varsayılan (Normal/Normal) · seçim değişmiş (Hızlı/Kolay vb., aynı yerleşim) · ilk açılış/kayıt okunamadı: Normal/Normal, hata iletisi yok · `hareket_azalt`: etkilenmez (şeritte hareket yok).
- Sahne etkisi: şerit zemin yamasının alt kenarına biner (yama y1410–1810); karakter ayakları y≈1532'de, çakışma yok.
- **2× yazı (`01b`, `font_scale > 1,3`):** şerit 168 yüksek, glif 80, yazı 50/40; sütun şeritle başlar (şerit 168 + OYNA 180 + 4×168 + aralıklar = 1222 → sütun üstü **y1106**, v2.0.3'te 1301); karakter ölçeği 0,5'e iner (v2.0.3: 0,8 → 0,5; başlık ile şerit arasında kalır). Hiçbir şey kesilmez.
- Güvenli alan: şerit sütunun parçası, `apply_safe_area` zaten kapsar.

## 3. `KOŞU` ekranı (`02`, anatomi `02a`, Hızlı+Kolay `02b`, Sonsuz+Zor `02c`, 2× yazı `02d`)
**Soru:** "Hangi koşuyu, ne kadar zorlukta oynayacağım?" Atmosfer ayarlar ekranı gibi **sakin oda** (hareket yok): `tas_900` + üstten sıcak ışık, lento başlık `KOŞU` (Cinzel 64/900, y96).
Düzen (y250–2172 kaydırılabilir alan; GERİ y2196 sabit 936×132):
1. **MOD** bölüm başlığı (Cinzel 34 `bronz_300` + çizgi; y250). Üç **mod satırı** 936×184, aralık 16: glif 84 · ad (Cinzel 44/700) + tek satır açıklama (Inter 28 `kemik_300`) · sağda süre (`10 DK` / `20 DK` / `∞`, Cinzel 38). Metinler: HIZLI "Kısa koşu. Lord 10. dakikada gelir." · NORMAL "Klasik koşu. Lord 20. dakikada gelir." · SONSUZ "Lord devrilince koşu sürer; ölene kadar."
2. **ZORLUK** başlığı. Üç **zorluk kartı** 296×272, yan yana, aralık 24 (3×296+2×24 = 936): 1–3 kalkan (84×28) · ad (Cinzel 40) · ≤3 satır açıklama (Inter 26). KOLAY "Daha az ve zayıf düşman." · NORMAL "Dengeli koşu." · ZOR "Yoğun ve sert düşman."
3. **Ayrıntı levhası** (`levha`, 936×~308): **seçili zorluğun** 4 satırı: Düşman canı · Düşman hasarı · Düşman sayısı · Kazanılan XP; sağda değişim (`−%30`, `+%25`, `aynı`, Zor'da `tam`). Değerler `data/difficulty.json`'dan okunur (tek kaynak); maketteki sayılar spec K1 başlangıç TAHMİN'idir (Kolay hasar ×0,55, HP ×0,70, doğuş ×0,70, XP ×1,25; Normal ×0,75/×0,85/×0,85/×1,0; Zor = bugünkü eğri = "tam").
4. **Kural levhası** (`levha`, yüksekliği içeriğe göre): her zaman 1. satır "Skorun bu mod ve zorluğun kendi listesine yazılır." (nötr, `kemik_300`); **uyarı satırları** yalnız gerektiğinde, `!` rozeti + `kemik_100` 600 ağırlık: Kolay → "Kolay'da Lord başarımları ve toplam sayaçlar ilerlemez." (K6-B); Sonsuz → "İlk Lord'u devirmek zaferdir; koşu sen ölene kadar sürer." (K4-A).
5. **GERİ** (ortak GERİ bileşeni, v2.0.3 kuralı).

**Etkileşim:** her satır/kart tek dokunma hedefi; dokun = seç + anında kaydet; seçimi değiştirmek ayrıntı ve kural levhalarını yerinde günceller (140 ms çapraz geçiş; `hareket_azalt`'ta anlık). Seçim **ikili kanal**: bordo yüzey (`dugme-birincil` 9-slice) **+** sağ üstte onay mührü (`muhur-dolu` ✓, 56 px) **+** `accessibility` "seçili". Bordo ile taş arasındaki parlaklık farkı küçük olduğundan (gri tonlamada ayrım zayıf) mühür zorunludur; gri sınaması `mock/06-durumlar` alt blokta.
**Durumlar:** varsayılan · seçili · basılı (`dugme-basili` + 80 ms) · odak (`border_focus` 6 px; sıra mod satırları → zorluk kartları → GERİ; D-pad ◄► kartlar arası) · **kilitli (rezerve, v2.1'de kullanılmaz):** satır/kart kenarı `tas_500`, ad `kemik_100` (soluk değil), sağda 48 px kilit rozeti + tek satır neden ("Normal'i bir kez bitir."); seçilemez, dokunma TalkBack'te nedeni okur — gelecek bir kilit-açma kararı için hazır (`06-durumlar`) · boş/yükleniyor/hata yok (yerel ayar). 
**2× yazı (`02d`):** mod satırı 336 (ad 64, açıklama 44 iki satır, süre 56), zorluk kartları **dikey sıraya** düşer (936×260 satır: kalkan 120 · ad 64 · açıklama 44); ayrıntı + kural levhaları 110/satır; liste kayar, GERİ sabit, alt 136 px solma. Seçili satır kayarken görünür kalır (ilk açılışta seçili öğe görünüme kaydırılır).

## 4. Glifler (SVG/`Glyph`, emoji yok)
| Anlam | Glif | Not |
|---|---|---|
| HIZLI | çift ok `»` (iki dolu yön) | hız |
| NORMAL | kum saati | süre |
| SONSUZ | sonsuz halkası (`∞`, 7 px çizgi) | döngü |
| KOLAY/NORMAL/ZOR | 1/2/3 dolu kalkan + kalan boş kalkan (84×28, toplam 3) | sayı = zorluk; renk tek kanal değil (ad + sayı + kalkan) |
| uyarı | `!` üçgen (amber) | kural levhası, sonuç notu |
Seçilmemiş glif `bronz_500`, seçili `bronz_300`; çerçeve `bordo_900` 2,5 px.

## 5. Sonuç ekranı (`03` yenildi, `03b` Hızlı zafer, `03c` Sonsuz zafer, `03d` Kolay)
**Soru:** "Hangi koşuydu, nasıl bitti, nerede sıralandım?"
- **Koşu şeridi (yeni):** altyazının (y300) altında, y352'de ortalı **2–3 çip** (48 yüksek): `[mod glifi] MOD · SÜRE` · `[kalkan] ZORLUK` · Sonsuz'da üçüncü `LORD ×N` (amber glif). Çip = kare köşe (chamfer değil, v2.0.3 "keskin köşe"), 3 px `bronz_500` kenar, `void α0,5` dolgu, Inter 28/700 +0,06 em `kemik_100`. Çipler **yalnız bilgi** (dokunma yok).
- **Kayma:** v2.0.3 sonuç yerleşimine **+44 px** (çip satırı + ayraç): `Y_DIV` 380→424; altındaki tüm bloklar (`Y_HERO`, `Y_RECORD`, `Y_BREAKDOWN`, `Y_STRIP`, `Y_COMBOS`) +44. Düğmeler `max(içerik_alt + 24, 1500)` kuralıyla zaten dinamik; **4 kombo + Lord bonusu satırı + Kolay notu** en kötü durumda düğmeler y≈2125'e iner (sığar). Developer testi: bu en kötü durumda bloklar çakışmaz.
- **Sıra satırı:** rekor/sıra metni (`record_note`) artık "**Zor · Normal listesinde 3. sıra**" (Mod · Zorluk listesinde N. sıra, Inter 30/600 `kemik_300`). Sıra, **o (mod, zorluk) çiftinin** listesinden hesaplanır (K5-A). YENİ REKOR damgası da aynı liste içindir.
- **Başlık/alt başlık:** kayıp: OYUN BİTTİ / "Kale seni yuttu." · kazanç (Hızlı/Normal): KAZANDIN / "Düşmüş Kale Lordu devrildi." · **Sonsuz, Lord devrildiyse:** KAZANDIN / "Lord'u devirdin; sonra M:SS daha dayandın." (süre = Lord ölümünden ölüme) · Sonsuz, Lord'dan önce ölürse: OYUN BİTTİ (won=false).
- **Süre/Seviye/Öldürme şeridi:** değişmez; Sonsuz'da Süre toplam süredir (27:48).
- **Kolay notu (yalnız Kolay):** şerit ile kombolar arası 96 yüksek satır: amber 6 px sol çizgi, `!`, "Kolay: bu koşu Lord başarımlarına ve toplam sayaçlara yazılmadı." (K6-B; yazılmayan başarım yoksa da gösterilir: kuralı hatırlatır). Başarım çipi ("YENİ KADEME") varsa not onun altında.
- **Durumlar:** kayıp · kazanç · Sonsuz zafer (LORD ×N çipi) · Kolay (not) · rekor yok/top10/dışında (v2.0.3 değişmez; sıra metni "Zor · Normal listesinde 10 dışı" yerine satır gizlenir) · 2× yazı: çipler iki satıra sarar (satır +56), geri kalan v2.0.3.
- **Pause ekranı (maketlenmedi, tarif):** "DURAKLATILDI" altında aynı çip bileşeni (mod + zorluk), salt bilgi; koşu içi değiştirme yok.

## 6. Sonsuz kilometre taşı (oyun içi, `05-sonsuz-zafer-ani`)
Sonsuz modda Lord ilk kez ölünce: üstte **bant 936×204** (`dugme-birincil` 9-slice, y300, 3,2 sn): "KALE LORDU DÜŞTÜ" (Cinzel 54/900) + "ZAFER SAYILDI · Koşu sürüyor" (Inter 32/600 `amber_glow`); altında 28 px "Lord 5:00 sonra daha güçlü döner." (K4: her 5 dk'da HP ×1,5). Bant **dokunmayı engellemez**, duraklatmaz, joystick'e dokunmaz; giriş 220 ms kayma, çıkış 400 ms soluma (`hareket_azalt`'ta anlık, görünme süresi aynı). Sonraki Lord dönüşleri mevcut 5 sn Lord uyarısını yeniden kullanır (yeni UI yok). Ses/titreşim: mevcut zafer tınısı + tek titreşim (öneri).

## 7. Skorlar ekranı (`04`, anatomi `04a`, boş sekme `04b`)
**Soru:** "Bu mod ve zorlukta en iyilerim neler?" (K5-A: (mod, zorluk) başına 10'luk liste.)
- Başlık `EN İYİ SKORLAR` (y150). Altyazı ve ayraç kalkar (sekmeler yerine geçer).
- **İki sekme sırası** (her biri 3×306×132, aralık 12): MOD (`HIZLI | NORMAL | SONSUZ`, y290) ve ZORLUK (`KOLAY | NORMAL | ZOR`, y434). Seçili sekme = bordo yüzey + **6 px amber kor çizgisi** (alt) + 900 ağırlık yazı; seçilmemiş = taş yüzey + `kemik_300` 700 yazı. Hücrede glif 40 + ad (Cinzel 34/+0,08 em).
- **Satırlar:** v2.0.3 satır bileşeni (sıra rozeti, skor, KAZANDI/YENİLDİ çipi, süre, tarih, YENİ etiketi); sütun y590'dan, **10 satır × 146 (pitch 158)** → y2168; `_layout`'taki uyarlanan `ROW_H` (146 ≥ `ROW_MIN_H` 120) zaten buna izin verir; `Y_ROWS` 360 → 590. GERİ y2196.
- **Açılış sekmesi:** ana sayfadan → **geçerli seçim** (mod, zorluk); sonuç ekranından → **biten koşunun çifti**; sonra kullanıcı sekme değiştirir (kalıcı değil).
- **Eski girişler (v1):** göç sonrası Normal/Normal listesinde görünür (kullanıcı kararı); ayrı etiket yok.
- **Boş sekme (`04b`):** büyük soluk mod glifi + "HENÜZ SKOR YOK" + "Sonsuz · Zor listesinde kayıt yok. / Bu ayarla oynayıp ilk skoru yaz." + **`BU AYARLA OYNA`** (180 yüksek, birincil): sekmenin çiftini seçip koşuyu başlatır (ayar da o çifte geçer; etiket bunu söyler). Sekmeler boş durumda da görünür/etkindir.
- **Durumlar:** dolu · boş (sekme) · tüm sekmeler boş (ilk açılış: Normal/Normal sekmesi boş durumu) · bozuk veri = boş · yeni rekor vurgusu (YENİ etiketi + 260 ms kayma) · 2× yazı: sekme etiketleri 40, hücre yüksekliği 132 korunur (3 sütun yeterli: "SONSUZ" ≈180 px < 306); satır içi yazı v2.0.3 kuralıyla büyür, satır 156'ya çıkar ve liste kayar.

## 8. Bileşen envanteri
| Bileşen | Varyant | Durum |
|---|---|---|
| Koşu şeridi | varsayılan, 2× (168) | **yeni** (v2.0.3 `levha` + glif + etiket) |
| Mod satırı | varsayılan, seçili, basılı, odak, kilitli (rezerve), 2× | **yeni** |
| Zorluk kartı | varsayılan, seçili, basılı, odak, kilitli (rezerve), 2× satır biçimi | **yeni** |
| Segmentli sekme | seçili/seçilmemiş, iki sıra | **yeni** (`dugme-dolu`/`dugme-birincil` 9-slice + kor çizgisi) |
| Koşu çipi | mod, zorluk, Lord ×N | **yeni**, `ResultChip` ailesi (kare köşe) |
| Ayrıntı levhası, kural levhası | zorluk/mod'a göre | **yeni** (`levha` + satır) |
| Kilometre taşı bandı | tek | **yeni** (`dugme-birincil` 9-slice) |
| Glifler (mod 3, zorluk 3 kalkan, uyarı) | seçili/seçilmemiş | **yeni** (`UiKit.Glyph` ailesi) |
| `levha`, `dugme-*`, `lento`, `muhur-dolu`, GERİ, `border_focus`, satır bileşeni, sonuç blokları | — | **mevcut** (v2.0.3) |

## 9. Erişilebilirlik
- **Dokunma:** tüm hedefler ≥132 (şerit 132/168, mod satırı 184/336, kart 272/260, sekme 132); aralık ≥12 (sekmeler/kartlar bitişik hedef olduğundan 12–24; tek parmak büyük hedef, kazara dokunma riski düşük çünkü seçim geri alınabilir ve koşuyu başlatmaz); GERİ y2196 başparmak bölgesi.
- **Renk dışı kanal:** seçili = bordo + ✓ mührü (kart/satır) ya da kor çizgisi + kalın yazı (sekme); zorluk = ad + kalkan sayısı; uyarı = `!` + 600 ağırlık metin; kilit = rozet + neden metni.
- **Kontrast (WCAG, hesaplandı; metin ≥4,5 · bileşen ≥3):** `kemik_100`/`bordo_500` 6,7 · `kemik_300`/`bordo_700` 7,3 · `kemik_300`/`bordo_500` 4,8 (seçili kartın gradyan üst ucu, açıklama) · `kemik_300`/`tas_800` 10,1 · `kemik_300`/`tas_600` 7,4 (seçilmemiş sekme) · `kemik_100`/`tas_600` 10,4 · `bronz_300`/`tas_800` 8,7 (DEĞİŞTİR) · `bronz_500`/`tas_800` 5,3 (seçilmemiş glif) · `bronz_500`/`tas_600` 3,9 (seçilmemiş sekme glifi, bileşen ≥3 ✓) · `amber_glow`/`bordo_500` 3,8 (kor çizgisi, bileşen ≥3 ✓) · `amber_glow`/`bordo_900` 8,2 (✓/çip) · `kemik_100`/`void` 16,1 (çip). Hiçbir çift v2.0.3 tablosunun altına inmez; `tas_600` üstünde `kemik_500` metin yok.
- **Metin:** min 26 px; 2× yazıda sarma/dikey sıra, kesilme yok.
- **Klavye/D-pad/odak:** `border_focus` 6 px; sıralar §2, §3, §7; sekme satırında ◄► komşu sekmeye, ▲▼ sıralar arası.
- **Hareket:** bu turun tüm geçişleri (140 ms çapraz, 220 ms bant girişi, 260 ms YENİ kayması) `hareket_azalt` açıkken anlık; dokunma geri bildirimi (80 ms) her zaman açık.
- **TalkBack (`accessibility_name`):**
  - Şerit: "Koşu: Normal, yirmi dakika. Zorluk: Normal. Değiştirmek için çift dokun."
  - Mod satırı: "Hızlı mod, on dakika, Lord on dakikada gelir, seçili" / "…, seçili değil". Sonsuz: "Sonsuz mod, Lord devrilince koşu sürer, ölene kadar".
  - Zorluk kartı: "Kolay zorluk, bir kalkan üç üzerinden, daha az ve zayıf düşman, seçili değil".
  - Ayrıntı levhası (okunur bölge): "Kolay zorluk ayrıntıları: düşman canı yüzde otuz az, düşman hasarı yüzde kırk beş az, düşman sayısı yüzde otuz az, kazanılan XP yüzde yirmi beş fazla."
  - Kural levhası uyarısı: "Uyarı: Kolay'da Lord başarımları ve toplam sayaçlar ilerlemez."
  - Sekme: "Mod sekmesi, Normal, seçili, üç sekmeden ikincisi"; "Zorluk sekmesi, Zor, seçili değil".
  - Sonuç çipleri: "Mod: Normal, yirmi dakika. Zorluk: Zor." · sıra: "Normal modda, Zor listesinde üçüncü sıra."
  - Kilometre taşı bandı (canlı bölge, nazik): "Kale Lordu düştü. Zafer sayıldı, koşu sürüyor."
  - Boş sekme düğmesi: "Sonsuz modda, Zor zorlukta oyna".
- **Türkçe büyük harf:** `UiKit.upper_tr` (`to_upper` yasak, gate); "HIZLI", "KOŞU", "DÜŞTÜ" gibi dizeler Türkçe `i/İ` kuralına uyar.
- **ui-ux-pro-max kontrol listesi:** emoji yok ✓ · dokunma geri bildirimi ✓ · kontrast tablosu ✓ · safe area (şerit sütunda; `KOŞU`/skor ekranı `apply_safe_area` kapsamına eklenmeli — §10 test) ✓ · reduced motion ✓ · tutarlı ikon dili (kalkan/glif aynı dolgu-kenar dili) ✓.

## 10. Uygulama ve test notları (developer/tester için)
- Yeni ekran `KOŞU` (alt sayfa) ana sayfa/skorlar gibi `apply_safe_area` ve 2× yazı testinden geçmeli; `Settings.store_path` geçici yola alınır (kart çalışma notu: ayar kaydı USER_LEAK üretir).
- Şerit metni tek kaynaktan: `Settings.mod/zorluk` → `RunOptions`; opts'suz sim varsayılanı değişmez (altın hash, spec).
- Skorlar: sekme çifti → `Highscores` (mod, diff) sorgusu; sonuç ekranı sıra metni aynı sorgudan; v1 girişleri Normal/Normal.
- Sonuç ekranı en kötü durum testi (4 kombo + Lord bonusu + Kolay notu + başarım çipi) çakışmasız.
- Kilometre taşı bandı: `hareket_azalt` açık/kapalı; dokunmayı geçirir (`mouse_filter = IGNORE`).
- Kabul görüntüsü: aynı yakalama senaryosuyla önce/sonra (kart çalışma notu, 2026-10-26).

## 11. Açık noktalar (kullanıcı kararı / varsayım)
1. **Sonsuz'da "LORD ×N" çipi:** sim `lords_killed` sayacı gerekir (spec'te yok); istenmezse çip düşer, ekran değişmez. (düşük)
2. **Seviye adları:** Kolay/Normal/Zor ve mod adları Hızlı/Normal/Sonsuz varsayıldı (kullanıcı K1–K3'ü önerilenle onayladı; ad itirazı gelmedi). Hızlı süresi **10 dk sabit** (K3-A; 8–12 aralığı sorusu açık kaldı, UI "10 DK" yazar, değişirse tek dize).
3. **Ayrıntı levhası sayıları:** spec K1 TAHMİN'i; sim ayarı sonrası `data/difficulty.json` değişirse levha kendiliğinden güncellenir. Zor'un "tam" gösterimi, Zor = bugünkü eğri varsayımına bağlı (spec açık noktası).
4. **Kilitli durum:** v2.1'de kullanılmıyor (hiçbir mod/zorluk kilitli değil); bileşen hazır tanımlandı, ne zaman kullanılacağı ayrı karar (ör. Sonsuz'u Normal'i bitirince açmak).
5. **Karakter × zorluk:** şerit karakterden bağımsız (spec: karakter başına baseline düşük öncelik).
6. **Doğrulanamayanlar:** maketler Chromium (Godot render değil); cihazda elde hissi (şerit ile OYNA yakınlığı, kazara dokunma), 2× yazıda karakter ölçeği 0,5'in yeterliliği, sonuç ekranında +44 px kayma ve skorlarda 146 px satırın okunurluğu **Redmi Note 13 Pro**'da denenmedi; v2.1 kullanıcı doğrulama listesine eklenmeli. `impeccable` web dedektörü çalıştırılmadı.
7. **Sonuç ekranı çip satırı konumu:** altyazı (y300) ile çip (y352) arasında 10 px boşluk dar; developer Godot'ta `Y_SUB`'ı 292'ye çekebilir (+8) — görsel doğrulama gerek.
