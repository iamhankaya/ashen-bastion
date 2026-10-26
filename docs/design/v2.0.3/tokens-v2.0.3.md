# Ashen Bastion v2.0.3 — token tablosu (yeni / değişen)

Kaynak: `docs/ui/tokens.json` + `docs/design/v2.0/tokens-v2.0.md`. **Yeni ham renk yok**; takma ad, ölçü, hareket. Developer `tokens.json` / `UiKit` sabitlerine taşır (designer koda yazmaz). Birim: tasarım pikseli (1080×2400), ms. Makine okunur kopya: `tokens-v2.0.3.json`.

## Renk (takma ad)
| Token | Değer | Kullanım |
|---|---|---|
| `tier_1` | `#CFC4AE` (=`kemik_300`) | kademe I çerçeve/rakam |
| `tier_2` | `#D2B47E` (=`bronz_300`) | kademe II |
| `tier_3` | `#E8A24A` (=`amber_glow`) | kademe III |
| `tier_4` | `#E8A24A` + `glow_amber` + plaka `#5C1D26` (=`bordo_700`) | kademe IV |
| `tier_locked` | `#4A3830` (=`kahve_500`) | kilitli plaka kenarı |
| `tier_done` | `#E8A24A` + kenar `bronz_500` | TAMAM satırı |
| `switch_on_bg / edge / label` | `bordo_700` / `bronz_300` / `kemik_100` | anahtar AÇIK |
| `switch_off_bg / edge / label` | `mor_900` / `kahve_500` / `kemik_500` | anahtar KAPALI |
| `slider_fill` | `bronz_500 → bronz_300` | kaydırıcı dolgu |
| `slider_fill_muted` / `slider_knob_muted` | `kahve_500` / `kemik_500` | sessiz durumda |
| `orb_normal` | ölçülen RGB≈165,202,221 (kaynak PNG) | normal küre (renk dokudan; kodda boyama yok) |
| `orb_elit` | RGB≈126,42,171 | elit küre |
| `orb_boss` | RGB≈227,170,88 | ara boss küre |
Kaldırılan: `COLOR_XP`, `COLOR_XP_BRIGHT` (`gem_renderer.gd:8-9`) — küre rengi dokudan gelir.

## Tipografi (mevcut ölçeğin yeni kullanımları; min 26)
| Kullanım | Yazı | Boyut / ağırlık |
|---|---|---|
| Ayarlar satır etiketi | Cinzel | 36 / 700 (+0,06 em), `upper_tr` |
| Ayarlar açıklama | Inter | 28/34 / 400 |
| Ayarlar değer (%70) | Cinzel | 40 / 700 |
| Anahtar sözcüğü | Inter | 26 / 700 (+0,08 em) |
| Bölüm başlığı | Cinzel | 34 / 700 (+0,14 em) |
| Yarım düğme (SKORLAR, AYARLAR) | Cinzel | 34 / 700 (+0,06 em) |
| Başarım özet | Cinzel 56 / 700 · Inter 32 / 600 | |
| Kademe rozeti rakamı | Cinzel | 28 / 700 |
| Kademe etiketi ("KADEME II") | Inter | 26 / 600 |
| Başarım satır adı / açıklama | Cinzel 38/44 / 700 · Inter 28/34 / 400 | v2.0 ile aynı |
| TAMAM çipi | Inter | 26 / 700 (+0,1 em) |
| 2× yazı modu | etiket 72 · açıklama 56 · düğme 56 · OYNA 80 | |

## Ölçü
| Token | Değer | Konum |
|---|---|---|
| `menu_col_top` | **1763** (v2.0: 1556) | ana sayfa sütun üstü |
| `menu_row_ids` | OYNA 1763 · KARAKTER\|BAŞARIM 1970 · SKOR\|AYAR 2129 | |
| `menu_half_btn` | 454×132, aralık 27 | |
| `menu_hero_box` | **960×1100** (v2.0: 960×960) | x 60, y 560 |
| `menu_version_y` | 2288 (h 40) | |
| `settings_list` | y 260–2172, kaydırmalı; GERİ y 2196 sabit | |
| `settings_card` | 936 × (SES 560, DOKUNUŞ 176, GÖRÜNÜM 226, HAKKINDA 316), dolgu 30, aralık 36 | |
| `settings_sec_h` | 72 | bölüm başlığı |
| `switch` | 156×84, topuz 60, kenar 5 | |
| `slider_touch` | 132; ray 20; tutamak 84 | |
| `row_min` | 132 | ayar satırı |
| `ach_row` | 936×**168** (v2.0: 156) | |
| `ach_plate` | 108, kenar 5; rozet 46 | |
| `ach_right_col` | 232 | |
| `ach_step_row` | 72 | satır içi kademe listesi |
| `ach_summary` | `N / 53 kademe` y 250; çubuk 936×20 y 340 | |
| `orb_px` | normal 34 · elit 48 · boss 68 | oyun içi ekran boyutu |
| `orb_texture` | 128×128 şeffaf (normal ≥96) | işlenmiş doku |
| `font_scale_stack` | `font_scale > 1,3` → ana sayfa tek sütun | |

## Hareket (ms)
| Token | Değer |
|---|---|
| `switch_toggle` | 140 (topuz kayması, `cubic-out`) |
| `row_expand` | 180 |
| `orb_bob_elit` | ±3 px, 1800 |
| `orb_bob_boss` | ±4 px, 1400 |
| `screen_in` | 220 (mevcut) |
