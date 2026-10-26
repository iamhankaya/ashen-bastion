# Ashen Bastion v2.0.3 — token tablosu (yeni / değişen)

Kaynak: `docs/ui/tokens.json` (v1) + `docs/design/v2.0/tokens-v2.0.md`. **Palet token düzeyinde değişir** (kullanıcı kararı 2026-10-26): yüzey ailesi soğuk mor → sıcak/nötr taş-kahve; mor yalnız XP + ikincil vurgu. Developer `tokens.json`, `tokens.css`, `ashen-bastion-theme.tres` ve `UiKit` sabitlerine taşır (designer koda/tema dosyasına yazmaz). Makine okunur kopya: `tokens-v2.0.3.json`. Birim: tasarım pikseli (1080×2400), ms.

## 1. Yüzey ailesi (değişen: mor → taş)
Konsept sayfası örnekleri: mor ≈ `#30252E` (ton 311°, doygunluk %13), kahve ≈ `#2D2422` (ton 11°, %14). v1 `mor_*` bunları 2,5× doygunlaştırmıştı (`#211832`: ton 261°, %35); yeni `tas_*` konsept doygunluğuna döner.

| Yeni token | Değer | Eski (kalkan) | Kullanım |
|---|---|---|---|
| `void` | `#0C0908` | `#0D0910` | en koyu zemin, scrim, çubuk içi |
| `tas_900` | `#151110` | `mor_900 #171020` | ekran zemini |
| `tas_800` | `#1F1917` | `mor_800 #211832` | panel/kart/levha |
| `tas_700` | `#2D2422` | `mor_700 #2F2342` | yükseltilmiş panel, seviye kartı, açık satır |
| `tas_600` | `#3B302C` | `mor_500 #4D3A6B` | ikincil düğme yüzü, ayraç, iç çizgi |
| `tas_500` | `#4C3E38` | — | güçlü kenar, kapalı anahtar, kilitli plaka |
| `overlay_dim` | `#0C0908CC` | `#0D0910CC` | duraklat/seviye atlama perdesi |

**Mor yalnızca:** `xp #7C5CC4`, `xp_parlak #A98BEF` (XP çubuğu, XP kürelerinin elit sınıf kimliği) ve `mor_vurgu #4D3A6B` (eski `mor_500`; XP çubuğu içi/ikincil vurgu). Yeni `mor_iz #2F2342` (eski `mor_700`) yalnız XP çubuk zemini. Bordo, kemik, bronz, amber, can, kahve **değişmedi**.

## 2. Diğer ekranlara etkisi (token düzeyi kararı, kullanıcı: tüm ekranlar uyumlu)
| Ekran / öğe | Eski | Yeni |
|---|---|---|
| HUD panelleri, yuva zemini, şarjör tamburu zemini | `mor_900/800` | `tas_900/800` |
| XP çubuğu: zemin / dolgu | `mor_700` / `xp` | `mor_iz` / `xp` (değişmez) |
| Duraklatma: panel, ikincil düğmeler | `mor_800`, `mor_700→mor_900` | `tas_800`, `tas_600→tas_800` |
| Seviye atlama kartı zemin / basılı | `mor_700` / `mor_900` | `tas_700` / `tas_900` |
| Seviye atlama kartı etiketi `YENİ` | `mor_500` zemin | `mor_vurgu` (ikincil vurgu olarak korunur) |
| Oyun bitti / kazandın panelleri | `mor_800` | `tas_800` |
| Karakterler ekranı (v2.0) panel, SEÇ pasif | `mor_800`, `mor_700` | `tas_800`, `tas_700` |
| Başarım bildirimi zemini | `mor_800 α0,94` | `tas_800 α0,94` |
Doğrulama: uygulama fazı `tokens.json` değerlerini değiştirir, `test/` renk sabitlerini ve `tools/capture` görüntülerini yeniler; **bu faz HUD'u maketlemedi** (kontrast aşağıdaki tablo, ekran görüntüsü değil).

## 3. Kontrast (WCAG 2.1, hesaplandı; eşik: metin ≥4,5 · büyük metin/bileşen ≥3)
| Çift | Oran | Karar |
|---|---|---|
| `kemik_100` / `tas_900` | 15,2 | AAA |
| `kemik_100` / `tas_800` | 14,1 | AAA (eski mor_800: 13,8) |
| `kemik_100` / `tas_700` | 12,3 | AAA (kart başlığı) |
| `kemik_100` / `tas_600` | 10,4 | AAA (düğme yüzü) |
| `kemik_300` / `tas_800` · `tas_700` · `tas_600` | 10,1 · 8,8 · 7,4 | AAA (açıklama metni) |
| `kemik_500` / `tas_900` · `tas_800` · `tas_700` | 6,6 · 6,1 · 5,3 | AA (pasif/ikincil metin) |
| `kemik_500` / `tas_600` | **4,5** | sınırda: **`tas_600` üstünde `kemik_500` metin kullanma** (düğme alt satırı `kemik_300`) |
| `bronz_300` / `tas_800` · `tas_700` · `tas_600` | 8,7 · 7,6 · 6,4 | AAA (bölüm başlığı) |
| `amber_glow` / `tas_800` · `tas_700` · `void` | 8,0 · 7,0 · 9,2 | AAA |
| `amber_glow` / `bordo_700` (IV plakası, rozet) | 5,8 | AA |
| `bronz_300` / `bordo_700` | 6,4 | AA |
| `kemik_100` / `bordo_700` (OYNA) | 10,3 | AAA |
| `kemik_100` / `bordo_500` (OYNA üst ton) | 6,7 | AA |
| `bronz_500` / `tas_800` (kenar, çerçeve) | 5,3 | bileşen ≥3 ✓ |
| `bronz_700` / `tas_800` · `tas_700` (levha dış kenar) | 3,0 · 2,6 | **yalnız dekoratif**; seçilebilirlik kenara bağlı değil (DESIGN-UI ile aynı kural) |
| `demir` (kademe I çerçevesi) / `tas_800` · `tas_700` | 4,7 · 4,1 | bileşen ≥3 ✓ |
| `can_kritik` / `tas_900` | 5,1 | AA |
| `xp` / `tas_900` · `xp_parlak` / `tas_800` | 3,7 · 6,3 | çubuk dolgusu bileşen ≥3 ✓ |
Önceki tablodaki (`mor_*`) tüm satırlar bu tabloyla **değiştirilir**; hiçbir çift v1'in altına düşmedi (`kemik_500` pasif metin 6,5 → 6,1; hâlâ AA).

## 4. Yeni renk takma adları
| Token | Değer | Kullanım |
|---|---|---|
| `demir` | `#8C8379` (L* 55) | kademe I çerçevesi, kapalı anahtar halkası (yeni ham renk **değil**: `kemik_500` ile `bronz_700` arası nötr; kimlik süs/dokudan) |
| `tier_1` | `demir` | I: yalın demir plaka |
| `tier_2` | `bronz_300 #D2B47E` | II: perçinli |
| `tier_3` | `amber_glow #E8A24A` | III: köşebentli |
| `tier_4` | `amber_glow` + plaka `bordo_700` + `glow_amber` | IV: taçlı |
| `tier_locked` | `tas_500 #4C3E38` | kilitli plaka (+ ikon `modulate (0,34 / 0,30)`) |
| `switch_on` | levha `bordo_700`, halka `bronz_300`, yuva `amber_glow` | kor mührü AÇIK |
| `switch_off` | levha `tas_800`, halka `demir`, yuva `void` | KAPALI |
| `slider_fill` | `bordo_500 → bronz_500 → amber_glow` (kor) | kaydırıcı dolgu |
| `slider_fill_muted` / `knob_muted` | `tas_500` / `kemik_500` | sessiz |
| `scene_glow` | `amber_glow α0,30` (+ `bordo_500 α0,12`) | kapı arkası ışık (additive) |
| `scene_fog` | `void` | sahne alt/üst perde |
Ton ayrımı notu: II (L* 74,7) ve III (71,9) parlaklıkta yakın; ayrım **silüet (perçin ↔ köşebent) + Roma rozeti + segment** (gri tonlama sınaması `mock/04b`).

## 5. Tipografi (mevcut ölçeğin yeni kullanımları; min 26)
| Kullanım | Yazı | Boyut / ağırlık |
|---|---|---|
| Ana başlık ASHEN BASTION | Cinzel | 132 / 900, +0,08 em, **taş oyma**: 2 px açık üst-sol + 3-4 px koyu alt-sağ gölge (2 geçiş), düz `kemik_100` |
| Üst yazı ASH AND STEEL | Cinzel | 34 / 700 (+0,5 em), iki yanında `ayrac` |
| OYNA | Cinzel | 68 / 900 (+0,16 em); 2× yazıda 80 |
| Yarım düğme | Cinzel 32 / 700 (+0,05 em) + alt satır Inter 26 / 600 `kemik_300` | |
| Ayar başlığı (lento) | Cinzel | 64 / 900 |
| Bölüm başlığı | Cinzel | 34 / 700 (+0,14 em) `bronz_300` |
| Ayar satır etiketi / değer | Cinzel 36 / 700 (+0,06 em) · Cinzel 40 / 700 | |
| Anahtar sözcüğü | Inter | 26 / 700 (+0,08 em) |
| Başarım grup başlığı (EN) | Cinzel | 34 / 700 (+0,14 em); **sabit büyük harf, `upper_tr` yok** |
| Kroniği mühür etiketi | Inter | 26 / 700 (+0,06 em) |
| Satır adı / hedef / değer | Cinzel 38/46 / 700 · Inter 28/34 / 400 · Cinzel 34 / 700 | |
| Rozet rakamı | Cinzel | 28 / 700 |
| 2× yazı modu | etiket 72 · açıklama 56 · düğme 56 · OYNA 80 | |

## 6. Ölçü
| Token | Değer | Konum |
|---|---|---|
| `menu_col_top` | 1763 | OYNA 1763 · KARAKTER\|BAŞARIM 1970 · SKOR\|AYAR 2129 · sürüm 2288 |
| `menu_half_btn` | 454×132, aralık 27 | |
| `menu_char` | 640×932 (kaynak ×0,625) | x 220, y 600; kenar eritme 56 px |
| `menu_floor` | zemin yaması 1000×400 + kül halkası + gölge | y 1410–1810 |
| `menu_scene_y` | 530–1700 | kapı/kule/sur/sancak/meşale |
| `menu_particles` | ≤40 | kül/kor |
| `settings_title` | lento 520×120 | y 96 |
| `settings_list` | y 250–2172 kaydırmalı; GERİ y 2196 sabit | |
| `settings_card` | SES 548 (+76 sessizken) · DOKUNUŞ 196 · GÖRÜNÜM 232 · HAKKINDA 308; aralık 30 | levha 9-slice margin 40 |
| `switch` | 156×84 (kor mührü), sözcük 100 | |
| `slider` | band 132; ray 28; madalyon 84 | |
| `ach_title` | y 96 | |
| `ach_chronicle` | y 240–440: `31 / 53` + 5 mühür (84) + etiket; mühür dokunma 187×132 | |
| `ach_group_h` | 72, sticky | y 470 |
| `ach_row` | 936×**150** (v2.0.3 ilk tur 168), aralık 12 | plaka 108, çubuk 232 |
| `ach_seg` | segment 14 yüksek, aralık 4; kademe sayısı kadar (1–4) | |
| `ach_open_step` | 96 / adım; mühür 72; zincir 6 | |
| `orb_px` | normal 34 · elit 48 · boss 68 | (değişmedi) |

## 7. Hareket (ms) — hepsi `hareket_azalt` açıkken kapalı
| Token | Değer | Not |
|---|---|---|
| `menu_embers` | ≤40 parçacık, 40–90 px/sn, ömür 3–5 sn | ana sayfa |
| `menu_torch` | ±8 % parlaklık, 1600–2400 ms rastgele aralık | ≤3 Hz altı |
| `menu_banner` | sancak sallanma ±2°, 3500 ms | shader |
| `menu_breath` | ölçek 1→1,015, 2400 ms | `ShowcaseMotion.scale_at` |
| `switch_toggle` | 140 + kıvılcım 200 | azaltılmışta anlık |
| `row_expand` | 180 | azaltılmışta anlık |
| `orb_bob` | elit ±3 px/1800 · boss ±4 px/1400 | azaltılmışta durur |
| `portrait_loop` | 3–4 sn video | azaltılmışta statik |
| `tap_feedback` | 80 | (mevcut; her zaman açık — girdi geri bildirimi) |
