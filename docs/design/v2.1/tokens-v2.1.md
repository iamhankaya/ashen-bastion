# Ashen Bastion v2.1 — token tablosu (yeni)

Kaynak: `docs/design/v2.0.3/tokens-v2.0.3.md` (yüzey/renk ailesi **değişmez**; yeni renk token'ı yok). Developer `tokens.json`/`UiKit` sabitlerine taşır (designer koda yazmaz). Makine okunur kopya: `tokens-v2.1.json`. Birim: tasarım pikseli (1080×2400), ms.

## 1. Renk takma adları (mevcut ham renklerin yeni kullanımı)
| Token | Değer | Kullanım |
|---|---|---|
| `sel_on_surface` | `dugme-birincil` 9-slice (bordo_500→bordo_700) | seçili mod satırı / zorluk kartı / sekme |
| `sel_off_surface` | `levha` (tas_800) · sekme: `dugme-dolu` (tas_600) | seçilmemiş |
| `sel_mark` | `muhur-dolu` 56 px, sağ üst −8/−8 | seçili ✓ (mod satırı, zorluk kartı) |
| `sel_tab_line` | `amber_glow`, 6 px, alt kenardan 10, yanlardan 14 | seçili sekme |
| `glyph_on` / `glyph_off` | `bronz_300` / `bronz_500` (kenar `bordo_900` 2,5) | mod ve zorluk glifleri |
| `chip_fill` / `chip_border` | `void α0,5` / `bronz_500` 3 px (kare köşe) | koşu çipi |
| `warn` | `amber_glow` (`!` rozeti), metin `kemik_100` 600 | kural/sonuç uyarısı |
| `warn_bar` | `amber_glow` 6 px sol çizgi, zemin `bordo_900 α0,55` | sonuç ekranı Kolay notu |
| `lock_ring` | `tas_500` kenar + `kemik_100` ad + kilit rozeti 48 | kilitli (rezerve) |

## 2. Tipografi (yeni kullanımlar; min 26)
| Kullanım | Yazı | Boyut / ağırlık |
|---|---|---|
| Şerit ana satır | Cinzel | 34/700 (+0,06 em); 2× 50 |
| Şerit alt satır / DEĞİŞTİR | Inter | 26/600 · 26/700 (+0,08 em); 2× 40 |
| Mod adı / süre | Cinzel | 44/700 (+0,06 em) · 38/700; 2× 64 · 56 |
| Mod açıklaması | Inter | 28/400; 2× 44 |
| Zorluk adı / açıklama | Cinzel 40/700 · Inter 26/400; 2× satır: 64 · 44 |
| Ayrıntı satırı etiketi / değer | Inter 32/600 · Cinzel 36/700; 2× 46 · 50 |
| Kural levhası | Inter 28/400 (nötr) · 28/600 (uyarı); 2× 44 |
| Sekme | Cinzel 34/700 (+0,08 em); seçili 900 |
| Koşu çipi | Inter 28/700 (+0,06 em) |
| Sıra satırı (sonuç) | Inter 30/600 |
| Kilometre taşı başlığı / alt | Cinzel 54/900 (+0,1 em) · Inter 32/600 |
| Skorlar başlığı | Cinzel 96/900 |

## 3. Ölçü
| Token | Değer | Konum |
|---|---|---|
| `run_strip` | 936×132 (2×: 168), y1604 (2×: sütunun ilk öğesi, sütun y1106) | ana sayfa |
| `run_strip_gap` | 27 (OYNA'ya) | |
| `home_hero_scale_2x` | 0,5 (v2.0.3: 0,8) | 2× yazı |
| `mode_row` | 936×184 (2×: 336), aralık 16, glif 84 (2×: 112) | KOŞU |
| `diff_card` | 296×272, aralık 24, kalkan 84×28 (2×: satır 936×260, kalkan 120) | KOŞU |
| `diff_detail` | `levha`, 4 satır × 76 (2×: 110) | KOŞU |
| `rule_plate` | `levha`, satır başına ≈64 (2×: 110+) | KOŞU |
| `run_scroll` | y250–2172 kayar; GERİ y2196 sabit | KOŞU |
| `tab` | 306×132, aralık 12, iki sıra y290 / y434 | skorlar |
| `hs_row` | 936×146, pitch 158, ilk satır y590 (v2.0.3: 156 / y360) | skorlar |
| `result_chip` | 48 yüksek, y352, aralık 16, ortalı | sonuç |
| `result_shift` | +44 (Y_DIV 380→424 ve altı) | sonuç |
| `result_note_kolay` | 936×96, aralık 20 | sonuç |
| `milestone_band` | 936×204, y300, 3200 ms | oyun içi |

## 4. Hareket (ms) — hepsi `hareket_azalt` açıkken anlık
| Token | Değer |
|---|---|
| `sel_change` | 140 (levha içeriği çapraz geçiş) |
| `milestone_in` / `milestone_out` | 220 kayma / 400 soluma; görünme 3200 |
| `hs_new_slide` | 260 (v2.0.3 `SLIDE_SEC` 0,26) |
| `tap_feedback` | 80 (her zaman açık) |
