# Ashen Bastion v2.0 — Tasarım

Tarih: 2026-10-24 · Görev: T20261024-53 (çatı T20261024-51) · Aşama: yalnız tasarım, kod yok.
Girdiler: `docs/spec/v2.0-spec.md` (T20261024-52), `docs/design/v1.1/DESIGN.md` (+ `mock/`), `docs/ui/DESIGN-UI.md`, `docs/ui/tokens.json`, `docs/design/audit/v1.1-son/FINDINGS.md` (S-01…S-05), `docs/design/audit/son-denetim/FINDINGS.md` (N4, N7), kod: `scripts/ui/{main_menu,level_up_screen,hud,result_screen}.gd`, `scripts/ctrl/pause_logic.gd`, `data/characters/gunslinger.json`.
Maketler: `mock/` (statik HTML + Chromium ekran görüntüsü, **1080×2400**, kaynak `mock/build.py`). Token tablosu: `tokens-v2.0.md` (+ `tokens-v2.0.json`). AI görsel istemleri: `prompts.md`.

**Etiketler.** *(öneri)* = sayı önerisi, kesin değeri plan fazı belirler. **[AÇIK]** = kullanıcı kararı bekliyor (§11). Ölçüler 1080×2400 tasarım pikseli; 1 dp ≈ 2,75 px; dokunma hedefi ≥ 132 px; üst güvenli alan 96, alt 72, yan 36 (DESIGN-UI). **Yeni renk/yazı tipi icat edilmedi**; v1.1 + `tokens.json` yeniden kullanıldı.

**Kullanıcı kararı gelene kadar varsayılanlar (VLAD notu):** ikinci karakter = **Barutçu** (çalışma adı, yer tutucu görsel) · başarım ödülü = **yalnız kayıt** (kilit açma kullanılmaz ama ekran durumu tasarlandı) · denge dokunulmaz.

## 1. Temel kararlar

| # | Karar | Gerekçe |
|---|---|---|
| D1 | **Ana menü:** OYNA'nın altına tek satır, iki yarım düğme: **KARAKTERLER \| BAŞARIMLAR** (454×132 her biri). SES/TİTREŞİM satırı **yerinde kalır**; ana görsel kutusu 960×1020 → **960×960** (y 560–1520) ve yukarı alınır. | Spec'in önerisi. Alternatif (SES/TİTREŞİM'i köşe ikonlarına almak) menü yerleşimini değiştirmezdi ama v1.1 alışkanlığını bozar, ikon-yalnız düğmede durum yalnız şekille anlatılır, ayrıca ayar kodunu da değiştirir → reddedildi. Hero yalnız %6 küçülür (figür yüksekliği 1020 → 960). |
| D2 | **Düğme alt satırı bilgi taşır:** KARAKTERLER'in altında seçili karakter adı, BAŞARIMLAR'ın altında `açılan/toplam` ("8/22"). | Seçim menüden okunur (sürüm satırı yetmez); ek ekran/kayıt gerekmez (`achievements.json`'dan hesaplanır). "Yeni/okunmadı" rozeti **yok** (ek `seen` kaydı gerektirir → §11-4). |
| D3 | **Vitrin = portre.** Sahne `portrait` dosyasıyla (1024×1536, seviye atlama ile aynı dosya) kurulur; `PlayerView`/rig kullanılmaz. Animasyon: nefes + sürüklenme + 12 kor parçacığı. | Spec açık noktası "PlayerView sim'siz bağlanabilir mi" çözülür: rig'e bağlanmak gerekmez. Yeni karakter için **tek ek görsel** (portre) yeterli; sim/RNG yok, ≤1,5 ms/kare bütçesi kolay. |
| D4 | **SEÇ ekrandan çıkmaz.** SEÇ → düğme "✓ SEÇİLİ"ye döner, kartta ✓ rozeti; menüye dönüş GERİ / geri tuşu. | Spec S2. Oyuncu karakterleri gezip karar verir; kazara çıkış yok. |
| D5 | **Seviye atlama başlığı (N4):** başlık bloğu üstten **alt gradyana** (y 880–1050) taşınır; portrenin üst 880 px'i başlıksız kalır. | Her portre için güvenli: namlu/yüz/saç başlıkla yarışmaz; başlık koyu gradyan üzerinde (ölçüm §8). Karakter başına farklı kompozisyon yazılsa da düzen bozulmaz. |
| D6 | **Bildirim = üst-orta değil, oyun alanı üst çeyreği:** y **820** (+ üst güvenli pay), 780×120. | HUD üstü tamamen dolu (§5.2); Lord bandı çentikte bile y 782'de biter; oyuncu y≈1200'de, bildirim onu örtmez. |
| D7 | **Başarım ekranı zorluğa göre gruplu, yapışkan başlıklı kaydırmalı liste.** Satır ilerleme göstermiyorsa (koşu-kapsamlı ve kayıtlı en iyisi yoksa) "TEK KOŞU · Hedef N" etiketi. | 22 satır tek ekrana sığmaz; kayıtta yalnız `totals` + `best{score,time,level}` var (spec). Bilinmeyen ilerlemeyi uydurmak yok. |
| D8 | **Renk tek başına anlam taşımaz:** zorluk = çerçeve rengi + **1–4 baklava** + grup başlığı; kilit = kilit simgesi + soluk ikon + ilerleme; seçili = ✓ + metin. | DESIGN-UI ilke / v1.1 §6. |

## 2. Ekranlar ve akış

```
ANA MENÜ ──KARAKTERLER──▶ KARAKTERLER (Screen.CHARACTERS) ──GERİ/geri tuşu──▶ ANA MENÜ
   │  ├──BAŞARIMLAR──▶ BAŞARIMLAR (Screen.ACHIEVEMENTS) ──GERİ/geri tuşu──▶ ANA MENÜ
   │  └──EN İYİ SKORLAR (v1.1) · SES · TİTREŞİM
   └──OYNA──▶ KOŞU (HUD + başarım bildirimi) ──seviye──▶ SEVİYE ATLAMA (karakter başlığı/portresi)
                                     └──bitiş──▶ SONUÇ (+ "Yeni başarım" özeti) ──▶ TEKRAR OYNA / ANA MENÜ
```
Yeni ekran enum değerleri **sona** eklenir (`CHARACTERS`, `ACHIEVEMENTS`); `back_action` ikisi için `TO_MENU` (spec K4). Odak: menüde varsayılan OYNA; vitrinde **SEÇ** (kilitliyse GERİ); başarımlarda GERİ.

| Ekran | Amaç | Spec senaryosu | Maket |
|---|---|---|---|
| Ana menü | iki yeni giriş + seçili karakter + başarım sayısı | 1, 2 | `01`, `01b`, `01c` |
| Karakterler | vitrin + seçim; kilit nedeni | 1–8, K10 | `02`, `02a`, `02b`, `02c`, `02d` |
| Başarımlar | liste, ilerleme, tarih | 11–13, 17 | `03`, `03a`, `03b` |
| HUD bildirimi | koşu içi kısa bildirim | 9, 15, 16 | `04`, `04a`, `04b` |
| Seviye atlama | karakter başlığı/portre (N4) | 4, 5 | `05`, `05a`, `05b`, `05c` |
| Sonuç | "Yeni başarım: N" özeti | 10 | `06`, `06a` |
| Yer tutucu | ikinci karakter / ikon geri düşüşü | — | `07` |

## 3. Ana menü (`01-ana-menu.png`, `01b` ölçülü, `01c` ilk açılış)

Sütun (x 72–1008, aralık 27) — **sütun üstü y 1556** (v1.1: 1715; +159 = bir 132'lik satır + aralık):

| Öğe | Boyut | Konum | Not |
|---|---|---|---|
| OYNA | 936×180 | y 1556 | değişmedi |
| KARAKTERLER \| BAŞARIMLAR | 454×132 ×2, aralık 27 | y 1763 | ikon 52 + iki satır: Cinzel 700 **34** (+0,06 em) etiket; Inter 600 **26** `kemik_300` alt satır. İkincil düğme stili (`button_secondary`). |
| EN İYİ SKORLAR | 936×132 | y 1922 | v1.1 |
| SES \| TİTREŞİM | 454×132 ×2 | y 2081 | v1.1 |
| Sürüm | Inter 600 26 | y 2240 | `Sürüm 2.0 · <ad>`; ad en çok 24 harf, taşarsa `…` |
| Ana görsel | 960×960 | x 60, **y 560–1520** | `contain`; alt gradyan y 1470'ten başlar (v1.1: 1640) |

Ad, ikon, sayaç: KARAKTERLER alt satırı `display_name` (büyük/küçük harf veriden gelir, Inter'de `upper_tr` gerekmez), BAŞARIMLAR alt satırı `açılan/toplam` (kayıt yoksa `0/22`). Ana görsel **seçili karaktere göre değişmez** (marka görseli, spec dışı); seçim düğme alt satırından ve sürüm satırından okunur.

Durumlar: varsayılan · basılı (6 px aşağı, v1.1) · odak (`border_focus`) · ilk açılış `0/22`, `Gunslinger` (`01c`) · kayıt/ayar okunamadı → varsayılan karakter + `0/22`, **hata iletisi yok** (sessiz, spec S5/S12) · geçersiz kayıtlı karakter kimliği → ilk geçerli karakter görünür, bir sonraki kayıtta düzelir.

## 4. Karakterler ekranı — vitrin + seçim (`02-karakterler.png`, ölçülü `02a`)

### 4.1 Düzen

| Blok | Konum / boyut | İçerik |
|---|---|---|
| Başlık | x 72, y 112 | "KARAKTERLER" Cinzel 900 64; sağda sayaç `2 / 2` Inter 700 28 `bronz_300` (**tek karakterde gizli**) |
| Vitrin sahnesi | tam genişlik, **y 190–1250** | portre `cover`, **tam taşma** (kenar boşluğu yok; nefes/sürüklenme kenarı göstermesin); alt gradyan: y 1250'de `void` %100 → üstte şeffaf (y ≈ 1000) |
| Ad bloğu | x 72, y 1060 | Ad Cinzel 900 **96** (`UiKit.upper_tr`, 6 px gölge) + sağında durum çipi: **"✓ SEÇİLİ"** (amber kenar) veya **"🔒 KİLİTLİ"** (bronz kenar) |
| Bilgi paneli | 936×**446** (x 72, y 1250); içerik büyürse yukarı uzar, sahne en çok 100 px kısalır | `panel` stili; ① blurb Inter 400 **32/42** `kemik_100`, en çok 4 satır (≤120 karakter, doğrulayıcı) ② **Başlangıç becerisi**: 84 çerçeveli ikon + "BAŞLANGIÇ BECERİSİ" Inter 700 26 `bronz_300` + beceri adı Cinzel 700 38 (`upper_tr`) ③ 3×2 istatistik karosu 282×78 (etiket Inter 700 26 `kemik_300`, değer Cinzel 700 40): **CAN · HIZ · ŞARJÖR · DOLDURMA · MENZİL · TOPLAMA** (`max_hp, move_speed, mag_cap, reload_time, range, pickup_radius`; çarpışma yarıçapı gösterilmez) |
| Kart şeridi | y **1722–1986**, kart **252×264**, aralık 27, ortalı; 3'ten fazlada yatay kaydırma (anında yapışma) | kart: portre kırpması (yüz), alt perdede ad Cinzel 700 28; odak kartı 6 px `bronz_300` kenar + `glow_amber`; seçili kartta sağ üstte ✓ rozeti (56, amber dolgu, koyu ✓); kilitli kartta gri portre + 56'lık kilit rozeti |
| SEÇ düğmesi | 936×156, **y 2013** | durumlar §4.3 |
| GERİ | 936×132, **y 2196–2328** (alt 72) | ikincil; başparmak bölgesi |

Sığma: 1986 + 27 = 2013; 2013 + 156 + 27 = 2196; 2196 + 132 = 2328 (= alt güvenli sınır). Çentik/güvenli alan payı (`apply_safe_area`): üst pay başlık ve sahne üstünü, alt pay SEÇ/GERİ'yi kaydırır; sahne yüksekliği payı emer (içerik 10 px bile örtülmez).

### 4.2 Hareket (vitrin) — bütçe ≤ 1,5 ms/kare, sim/RNG yok

| ID | Hareket | Değer | Not |
|---|---|---|---|
| V1 | Nefes | portre ölçeği 1,000 → 1,015, **2,4 sn** sinüs, orijin alt-orta | v1.1 P1 ile aynı ritim |
| V2 | Sürüklenme | x ±8 px, **6 sn** sinüs; y sabit | yalnız vitrin; kenar taşması için portre tam-taşma |
| V3 | Kor parçacıkları | en çok **12** yuvarlak (6–10 px, additive, `amber_glow` α 0,5); alttan 60–110 px/sn yükselir, ömür 3 sn, sinüs sapma | tek MultiMesh/`CPUParticles2D`; LOD gerekmez |
| V4 | Karakter değişimi | 260 ms: eski sahne solar + 40 px kayar (kaydırma yönünde), yeni sahne gelir; kart odağı 140 ms | `cubic-out` |
| V5 | SEÇ onayı | düğme "SEÇİLİ"ye 140 ms çapraz geçiş; ✓ rozeti 1,25 → 1 (180 ms); titreşim açıksa 30 ms | ses yok |

Ekran gizliyken `_process` kapalı (spec K5). Azaltılmış hareket (v1.1 §1.1-7) açılırsa V1–V3 kapanır, sahne durağan.
**Giriş:** sahne ekran girişi 220 ms (v1.1 `screen_in`); ilk açılışta odak = **seçili karakter**.

### 4.3 Durumlar

| Durum | Gösterim (maket) |
|---|---|
| **Dolu, odak ≠ seçili** (`02`) | SEÇ birincil (bordo, 156); ad çipi yok |
| **Odak = seçili** (`02b`) | düğme **"✓ SEÇİLİ"**: `mor_700` zemin, 5 px amber kenar + ışıma, amber metin (7,8:1); dokunma işlevsiz (odaktan çıkmaz) |
| **Kilitli** (`02c`) | sahne **gri + %50 parlaklık** (portre görünür kalır: ne açılacağını göster), ortada 240'lık kilit halkası; ad yanında "🔒 KİLİTLİ"; düğme **KİLİTLİ** (pasif: `mor_800` zemin, `kahve_500` kenar, metin `kemik_300` 9,8:1) + alt satır **“<başarım adı> başarımını aç”** Inter 600 28 (`unlock.achievement` → `name`). Pasif metin soluklaştırılmaz, kontrast korunur. Kilitli kart yine odaklanır/incelenir |
| **Tek karakter** (`02d`) | kart şeridi ve sayaç gizli, SEÇ "✓ SEÇİLİ"; panel aynı yerde kalır |
| **Portre yok / bozuk** | yer tutucu (§6.3); düzen aynı, çökme yok (spec S4) |
| **Kayıtlı kimlik geçersiz** | ilk geçerli karakter odak + seçili; ileti yok |
| **`unlock` var ama başarım kaydı okunamadı** | kilitli say (güvenli yön) |

Etkileşim: sahnede **yatay kaydırma** = önceki/sonraki; kart dokunma = odak; Android geri = menü; D-pad/klavye: ◄/► karakter, ▲/▼ SEÇ ↔ GERİ.
Sıra: `data/characters` **dosya adı sırası** (spec S1). Kayıt: SEÇ'te `Settings.character_id`, ekran kapanışında değil.

## 5. Başarımlar

### 5.1 Ekran (`03-basarimlar.png`, ölçülü `03a`, boş `03b`)

| Blok | Konum / boyut | İçerik |
|---|---|---|
| Başlık | y 130 ortalı | "BAŞARIMLAR" Cinzel 900 80 |
| Özet | y 262 / bar y 340 | `8 / 22` Cinzel 700 56 + "açıldı" Inter 600 32; ilerleme çubuğu 936×**20**, `bronz_500 → bronz_300` dolgu |
| Liste görünümü | **y 400–2172**, kaydırmalı | üst/alt 80 px solma perdesi; sağ kenarda 8 px kaydırma ipucu (kaydırınca 600 ms görünür); yapışkan grup başlığı |
| Grup başlığı | 936×**72** | "KOLAY / ORTA / ZOR / ÇOK ZOR" Cinzel 700 34 (+0,14 em) `bronz_300` + 1–4 baklava (16 px, dolu = bu kademe) + sağda `açılan / toplam` Inter 700 28 |
| Satır | 936×**156**, aralık 12 (adım 168), grup başlığı sonrası 12 | §5.1.1 |
| GERİ | 936×132, y 2196 | ikincil, odak varsayılan |

Kaydırma uzunluğu 22 satır ≈ 22×168 + 4×84 ≈ **4 030 px** (görünür 1 772); güvenli alan payı listeyi küçültür, **kaydırma tutamacı** (≥132 px dokunma yüksekliği satırın kendisi, kaydırmayı yutmaz) korunur. Satırlar dokunulmaz (bilgi); sürükleme listeyi kaydırır.

#### 5.1.1 Satır anatomisi (936×156, `panel`, dolgu 24)

| Parça | Ölçü | Açık | Kilitli |
|---|---|---|---|
| İkon plakası | 108×108 (`cerceve-aktif` / `cerceve-pasif`), ikon 68 | tam renk, çerçeve kademe rengi | ikon **%45** + gri ton, kilit rozeti (40, sağ-alt) |
| Ad | Cinzel 700 **38/44**, `upper_tr`, tek satır, `…` | `kemik_100` | `kemik_100` (**soluklaştırılmaz**) |
| Açıklama | Inter 400 28/34 `kemik_300`, en çok **2 satır** | aynı | aynı |
| Sağ sütun (240) | — | ✓ rozeti (44, `dogru` dolgu) + **tarih** `GG.AA.YYYY` Inter 600 26 `kemik_500` | **ilerleme biliniyorsa** `34/500` Cinzel 700 34 + 14 px çubuk; **bilinmiyorsa** "TEK KOŞU" çipi (Inter 700 26) + "Hedef 500" |
| Kenar | 4 px | kademe: kolay/orta `bronz_700`, zor `bronz_500`, çok zor `amber_glow` + `glow_amber` | `kahve_500` (dekoratif; anlam metinde) |

Kademe → renk + baklava: kolay `rarity_common`·1 · orta `rarity_uncommon`·2 · zor `rarity_rare`·3 · çok zor `record` + ışıma·4. Sayı biçimi `tr` (binlik nokta); değer hedefi aşarsa `hedef/hedef` (çubuk dolu). Doğrulayıcı sınırı *(öneri)*: ad ≤ **22** harf (bildirimde tam sığar), açıklama ≤ **60** karakter (2 satıra sığar).

Veri şemasına tasarım isteği *(opsiyonel, §11-3)*: `achievements.json` kaydına isteğe bağlı `icon` (yol); yoksa `stat` ailesine göre yer tutucu (§6.3).

### 5.1.2 Durumlar

| Durum | Gösterim |
|---|---|
| Dolu / kısmen dolu (`03`) | yukarıdaki; açıklar kademe başına üstte değil, **tanım sırasında** (kolaydan zora; grup içi: açıklar önce) |
| **Hepsi kilitli** — kayıt yok/bozuk/boş (`03b`) | özet `0 / 22`, çubuk boş; listenin üstünde 108'lik bilgi paneli "Henüz açılan başarım yok. Bir koşuya başla." (Inter 600 32 `kemik_300`); **hata iletisi yok** |
| **Tümü açık** | özet "22 / 22" `amber_glow`, çubuk amber; panel "Tüm başarımlar açıldı." |
| Grup tamam | başlıkta sayaç amber + ✓ |
| Tanım dosyası yüklenemedi (gate engeller; çalışma zamanı güvenliği) | tam ekran boş durum: "Başarım listesi yüklenemedi" Inter 34 + GERİ |
| Bilinmeyen kimlik (kayıtta var, tanımda yok) | gösterilmez, silinmez (spec) |
| Yükleme | yok (yerel dosya, senkron) |

### 5.2 Koşu içi bildirim (`04-hud-basarim-bildirimi.png`, ölçülü `04a`, durumlar `04b`)

**Yer seçimi (spec açık noktası):** HUD haritası (y): rozet/XP/süre 84–260 · yuvalar ≈270–340 (x 36–558) · **skor sütunu 284–436** (x 584–1044) · elit/Lord satırı **506–604** · **Lord bandı 520–652** (çentikte +pay, ≈ 650–782) · tambur/rozet satırı **2160–2328** · ekran dışı ok kenarlarda. Bildirim **y 820 + `safe_top`**: bantın en alçak halinin (782) **38 px** altında, oyuncunun (≈1100+) üstünde, hiçbir HUD öğesiyle kesişmez.

| Öğe | Değer |
|---|---|
| Kutu | **780×120**, x 150–930 (ortalı), radius 18 (`radius_m`), 4 px kenar, zemin `mor_800` **α 0,94** |
| Kenar | kolay/orta: `bronz_500`; zor/çok zor: `amber_glow` + `glow_amber` |
| İçerik | 84'lük çerçeveli ikon (x 24) · üst satır **"BAŞARIM AÇILDI"** Inter 700 **26** `bronz_300` (+0,14 em, 8,5:1) · ad Cinzel 700 **38** `kemik_100` (`upper_tr`, tek satır, `…`; **≤22 harf** tam sığar) · **baklavalar etiket satırında sağda** |
| Etkileşim | `mouse_filter = IGNORE` (dokunma/joystick kesilmez); odak almaz |
| Hareket | giriş **220 ms** (24 px yukarıdan kayma + solma, `cubic-out`) · bekleme **2 100 ms** · çıkış **180 ms** = **2 500 ms**; yanıp sönme yok |
| Kuyruk | aynı anda **1** görünür; sıradaki 150 ms boşluk sonra; kuyruk en çok **3**; taşan **sessizce** sonuç özetine gider |
| Duraklama | duraklatma/seviye atlama/onay açıkken sayaç **durur**, bildirim kalan süresiyle bekler; sonuç ekranı gelirse kuyruk atılır (özet sayar) |
| Ses | **yok** (spec B9); titreşim yok *(öneri; hafif 25 ms istenirse ayar kapalıyken çalışmaz)* |
| Çentik | `y = 820 + safe_top`, `x` payları yan güvenli alan içinde (780 ≪ 1008) |

Geometri testi girdisi (B4): kutu dikdörtgeninin skor sütunu, SERİ çipi, elit satırı, Lord bandı (güvenli üst payla), yuva satırı, tambur/rozet satırı, joystick tabanı ve ekran dışı oklarla kesişimi **boş**.

### 5.3 Sonuç özeti (`06-sonuc-yeni-basarim.png`, ölçülü `06a`)

Koşuda ≥1 başarım açıldıysa istatistik şeridi ile "Kurulan kombolar" arasına **936×96 özet çipi** girer (y = şerit alt + 24 ≈ 1418): `panel`, **amber 4 px kenar**, ★ ikonu 44 + **"YENİ BAŞARIM · N"** Cinzel 700 30 `amber_glow` + ilk iki ad Inter 600 28 `kemik_300` ("İlk Kan, Beş Dakika"; N>2 ise "+k"), taşarsa `…`. Dokunulmaz. Girişi: döküm satırlarından sonra **1 100 ms**, 200 ms kayma-giriş (dokunma = atla).
**Sığma kuralı:** özet varken kombolar **en çok 3 satır** (4. satır "+N" olur) → kombolar 1538–1838, düğmeler **1866–2181** (< 2328). Özet yokken v1.1 düzeni aynen (4 kombo, düğmeler ≥ y 1500). Ayrıntı yazısı **26 px** (S-03). `accessibility_name`: "2 yeni başarım: İlk Kan, Beş Dakika".

## 6. Seviye atlama, görsel kurallar, yer tutucu

### 6.1 Seviye atlama (`05`, `05b`, `05c`, ölçülü `05a`)

| Öğe | v1.1 | v2.0 |
|---|---|---|
| Üst yazı | "GUNSLINGER" sabit, y 130 | **`sim.character.display_name`** → `UiKit.upper_tr`, Cinzel 700 **34** (+0,18 em) `bronz_300`, **y 880**, 3 px gölge |
| Başlık | "SEVİYE N" Cinzel 900 104, y ≈ 164 | aynı boyut, **y ≈ 924–1030** (üst yazının hemen altı, aralık −6/+8) |
| Portre | 1080×1620 `cover`, perde üstte 0,85→0 (y 0–420) | **üst perde kalkar**; alt gradyan duraklı: **y 560: 0 → y 860: 0,72 → y 1000: 0,90 → y 1150: 1,0** (`void`) |
| Kartlar | 984×324, aralık 27, alt pay 200 | değişmez (3 kartta ilk kart y 1174) |
| Güvenli alan (N7) | yok | alt pay kartları/ipucunu yukarı alır; üst pay etkilemez (başlık y 880) |

Kontrast (ölçüldü, gerçek portre, en parlak piksel dahil): etiket `bronz_300` ≥ **5,0:1** (p99: 6,5), başlık `kemik_100` ≥ **10,2:1** — N4'ün "<3:1 olabilir" şüphesi giderildi. **Portre yoksa** (`05c`): üst alan `bordo` radyal zemin (`#5C1D26` α 0,55 → `void`), başlık bloğu **aynı yerde**; çökmez. Seviye halkası: §9 (M4).

### 6.2 Karakter görsel gereksinimi (yeni karakter = veri + bunlar)

| Dosya | Boyut | Zorunlu | Kural |
|---|---|---|---|
| `portrait` | 1024×1536 PNG | **evet** (yoksa yer tutucu) | yüz üst üçte birde; **alt %40 önemsiz** (gradyan örter); önemli her şey x %12–88, y %6–62 içinde; tam taşma (şeffaf kenar yok); yeşil zemin **yok** (tam sahneli resim) |
| `rig.body` | kolsuz gövde, referans 1024×1536 → `process_art.py` | evet | `docs/dev/new-character.md` |
| `rig.arm` | tabanca kolu (mevcut kol yeniden kullanılabilir) | hayır | iki tabanca ateşi tüm karakterlerde ortak (spec) |
| `walk.*` kareler | 6 kare | hayır | prosedürel yedek yeterli |

### 6.3 Yer tutucu stili (`07-yer-tutucu-stili.png`)

- **Portre/gövde yoksa:** Gunslinger dosyası, **shader ile ton kaydırılmış**: doygunluk ×0,75, sepya %55, ton −18°, parlaklık ×0,92 (maket CSS karşılığı: `sepia(.55) hue-rotate(-18deg) saturate(.75) brightness(.92)`). Kullanıcı gerçek görseli verince yalnız dosya + `rig` sayıları değişir.
- **Üretim yapısında yazı yok**; **debug yapıda** sağ-üst köşede 26 px "YER TUTUCU" etiketi (dokunulmaz) — cihaz kontrol listesine "yer tutucu görsel" notu (spec).
- **Başarım ikonu yoksa** (`icon` alanı yok/dosya yok): `stat` ailesine göre **mevcut ikon**, plaka çerçevesi aynı: öldürme/elit/kırım→`hud-oldurme` · süre→`hud-sure` · seviye/skor/seri→`hud-xp` · koşu sayısı→`hud-duraklat` · doldurma/şarjör→`hud-mermi` · yuva/silah→`cift-tabanca` · eklenti/can→`hud-can` · evrim→`zincirleme-patlama` · bomba→`dinamit` · bilinmeyen→`hud-xp`.
- Kullanıcı AI görseli üretirse istemler `prompts.md`'de.

## 7. Token'lar ve ölçüler

Tam liste: `tokens-v2.0.md` (kod: developer `tokens.json`/`UiKit`'e taşır). Özet — **yeni renk yok**, 14 yeni ölçü/hareket token'ı:

| Grup | Token'lar |
|---|---|
| Renk (takma ad) | `tier_kolay=rarity_common`, `tier_orta=rarity_uncommon`, `tier_zor=rarity_rare`, `tier_cok_zor=record`, `ach_open=dogru`, `locked_edge=kahve_500` |
| Ölçü | `char_card 252×264`, `char_panel_h 446`, `char_stage 190–1250`, `ach_row 936×156`, `ach_group_h 72`, `toast 780×120`, `toast_y 820`, `result_chip_h 96` |
| Hareket | `showcase_breath 2400`, `showcase_drift 6000`, `showcase_swap 260`, `toast_in 220`, `toast_hold 2100`, `toast_out 180`, `toast_gap 150`, `select_confirm 140/180` |

## 8. Erişilebilirlik

- **Kontrast (ölçüldü):** `kemik_100/mor_800` 13,8 · `kemik_300/mor_800` 9,8 · `kemik_300/mor_500` (düğme alt satırı) **5,7** · `kemik_500/mor_800` (tarih, ikincil) 5,9 · `bronz_300/mor_800` 8,5 · `amber/mor_800` 7,8 · `dogru` ✓ rozeti 7,3 · seviye atlama başlık/etiket §6.1 · bildirim halka/kenar `bronz_500/mor_900` 5,7 (≥3:1 bileşen). Kilitli satır ve pasif düğme **metni soluklaştırılmaz**.
- **Min metin 26 px**; yeni küçük metinlerin hepsi 26+ (düğme alt satırı, çip, tarih, "BAŞARIM AÇILDI", istatistik etiketi).
- **Renk tek başına anlam taşımaz:** bkz. D8; sonuç/karakter durumu daima metin/✓/kilit simgesi ile.
- **Dokunma:** KARAKTERLER/BAŞARIMLAR 454×132, SEÇ 156, GERİ 132, kartlar 252×264 (tümü ≥132, aralık ≥27). Bildirim ve başarım satırları dokunulmaz → başparmak bölgesi serbest. Yeni eylemler alt yarıda.
- **Işık/hareket:** hiçbir yeni öğe yanıp sönmez (bildirim tek geçiş); vitrin hareketi ≤ %1,5 ölçek, 8 px; ≤3 Hz kuralı korunur; ses yok.
- **Odak/D-pad:** menü: OYNA → KARAKTERLER → BAŞARIMLAR → EN İYİ SKORLAR → SES → TİTREŞİM; vitrin: kart şeridi ◄► ↔ SEÇ ↔ GERİ; başarımlar: liste (kaydırma) ↔ GERİ. Odak halkası `border_focus` 6 px.
- **Ekran okuyucu (`accessibility_name`):** "Karakterler, seçili: Barutçu" · "Başarımlar, 8 / 22 açıldı" · "Barutçu, kilitli. Beş Dakika başarımını aç" · "Seç" / "Seçili" · "İlk Kan, açıldı 23.10.2026" · "Yerleşik, kilitli, 6 / 10" · bildirim: "Başarım açıldı: Beş Dakika" (canlı bölge, kibar).
- **Türkçe:** Cinzel ile gösterilen dinamik tüm metin (`display_name`, beceri adı, başarım adı, bildirim adı) `UiKit.upper_tr`; `to_upper()` yasak (gate). Test: adda `i` varsa `İ`.
- **Güvenli alan (N7):** yeni ekranlar ve seviye atlama/duraklatma `apply_safe_area`; HUD bildirimi `safe_top` ekler.

## 9. Bakım maddelerinin tasarım kararları (S-01…S-05, F-016/N-serisi)

| # | Bulgu | Karar (tasarım) | Belge/kod |
|---|---|---|---|
| S-01 | elit şövalye/Lord süzülme vs gölge | **Zemine oturur** kararı kabul; gölge ayrılığı ≤ 8 px; ölçüm eşiği 0,40 + **≥0,02 pay**; `GAIN` 2,2 cihazda | `docs/design/v1.1/DESIGN.md` E3 + §8-2 **güncellendi** |
| S-02 | seviye halkası soluk | kalınlık **3 → 4 px**, başlangıç **α 0,9 → 0** (450 ms), yanına 8 px yumuşak ışıma; renk `xp_parlak` zemini üzerinde **5,7:1** (≥3:1) | v1.1 P11 satırı **güncellendi**; kod M4 |
| S-03 | ayrıntı metni 24 px | **26 px** (§3.3); `%35 opak` satırlarda da ≥ 26 | v1.1 §3.3 **güncellendi**; kod M5 |
| S-04 | debug etiketi başparmak bölgesinde | etiket **ekranın üst kenarına** (y 6–40, 26 px), `mouse_filter = IGNORE`, hiçbir düğme/ok dikdörtgeniyle kesişmez; "(dokun)" etiketleri yalnız HUD'da; sonuç/duraklatmada dokunulmaz | kod M6 (yalnız debug) |
| S-05 | ok üçgeni kenara yakın | **tüm glif** (üçgen ucu dahil) kenardan **≥ 36 px**: daire kenarı ≥ 62 px; çentik payı eklenir | v1.1 §5.2 **güncellendi**; kod M7 |
| N4 | başlık–namlu çakışması | D5 / §6.1 | — |
| N6 | Lord/elit rim tonu | bronz/amber ailesi (`bronz_300`/`amber_glow`), kemik değil | renk sabiti testi (M2) |
| N7 | güvenli alan | §8 | — |
| N3, N5, N8 | kalabalık rim, oyuncu harabe önü, yıkıcı düğme konumu | **cihaz değerlendirmesi**; onay diyaloğu korunur, tasarım değişikliği yok | cihaz listesi |

## 10. Maket dizini (`mock/`)

| Dosya | İçerik |
|---|---|
| `01-ana-menu.png` · `01b-…-anatomi` · `01c-…-ilk-acilis` | menü (Barutçu seçili, 8/22) · ölçüler · ilk açılış (Gunslinger, 0/22) |
| `02-karakterler.png` · `02a-…-anatomi` | vitrin (Barutçu odakta, Gunslinger seçili) · ölçüler |
| `02b-…-secili` · `02c-…-kilitli` · `02d-…-tek` | seçili · kilitli (unlock) · tek karakter |
| `03-basarimlar.png` · `03a-…-anatomi` · `03b-…-bos` | liste (kolay + orta) · ölçüler · hepsi kilitli |
| `04-hud-basarim-bildirimi.png` · `04a-…-anatomi` · `04b-bildirim-durumlari` | HUD'da bildirim · çakışma haritası · 5 kademe + zamanlama |
| `05-seviye-atlama.png` · `05a` · `05b-…-barutcu` · `05c-…-portresiz` | N4 düzeni · ölçüler · Barutçu (yer tutucu) · portresiz |
| `06-sonuc-yeni-basarim.png` · `06a` | özet çipi + 3 kombo kuralı · ölçüler |
| `07-yer-tutucu-stili.png` | gerçek ↔ yer tutucu portre |
| `*.html`, `mock.css`, `build.py`, `shoot.js` | kaynak (`python3 build.py && node shoot.js`) |

Notlar: Chromium ile üretildi, Godot render'ı değildir; HUD arka planı v1.1 maketinden alındı (gerçek oyun çerçevesi). Maketler `.gdignore` ile Godot dışında. Gunslinger kartında/Barutçu yer tutucusunda kullanılan görsel `art/ref/portre-seviye-atlama.png`; "Barutçu" **çalışma adıdır**, başarım adları plan fazında kesinleşir.

## 11. Kapanan kararlar ve açık noktalar

**Bu tasarımda kapananlar:** menü düzeni (D1) · bildirim yeri (§5.2) · vitrin = portre, rig yok (D3) · seviye atlama başlığı (D5) · sonuç özeti sığması (§5.3) · yer tutucu kuralı (§6.3).

**Açık (kullanıcı / sonraki faz):**
1. **İkinci karakter konsepti/adı/becerisi ve görselleri** — spec kararı 1 (varsayılan: Barutçu, yer tutucu). `prompts.md` hazır.
2. **Başarım ödülü** — varsayılan "yalnız kayıt"; C seçilirse `02c` kilitli düzen kullanılır (tasarım hazır).
3. Başarım ikonları: AI (`prompts.md` §P4) mü yer tutucu mu; `achievements.json`'a isteğe bağlı `icon` alanı plan fazının kararı.
4. "Yeni/okunmadı" rozeti istenirse `seen` listesi kayda eklenmeli (kapsam dışı bırakıldı).
5. Koşu-kapsamlı başarımların "ilerleme çubuğu" ancak `best{…}` genişletilirse çizilir; şimdilik "TEK KOŞU" etiketi (D7).
6. **Cihazda doğrulanacak:** vitrin kare süresi (≤1,5 ms), bildirimin düşman kalabalığı üstünde okunurluğu, `y 820` konumunun başparmakla örtüşmemesi, çentikli cihazda düzen, yer tutucu tonu, 2× yazı boyutu (bu ortamda 2× görüntü üretilmedi).
7. Menü ana görseli seçili karakterle değişmiyor (marka görseli); karakter başına menü görseli istenirse ayrı iş.
8. Bildirimde titreşim: varsayılan yok.
