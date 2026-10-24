# Ashen Bastion v2.0 — token tablosu

Kaynak: `docs/ui/tokens.json` + v1.1 (`docs/design/v1.1/DESIGN.md` §5.1). **Yeni renk icat edilmedi**; aşağıdakiler takma ad / ölçü / hareket token'larıdır. Developer `tokens.json` ve `UiKit` sabitlerine taşır (designer koda yazmaz). Birim: tasarım pikseli (1080×2400), ms.

## Renk (takma ad)

| Token | Değer | Kullanım |
|---|---|---|
| `tier_kolay` | `#CFC4AE` (=`rarity_common`) | KOLAY çerçeve/başlık vurgusu |
| `tier_orta` | `#D2B47E` (=`rarity_uncommon`) | ORTA |
| `tier_zor` | `#E8A24A` (=`rarity_rare`) | ZOR |
| `tier_cok_zor` | `#E8A24A` + `glow_amber` + bordo plaka (=`record`) | ÇOK ZOR |
| `ach_open` | `#8DB58A` (=`dogru`) | açık başarım ✓ rozeti |
| `locked_edge` | `#4A3830` (=`kahve_500`) | kilitli satır/pasif düğme kenarı (dekoratif) |
| `toast_bg` | `#211832` α 0,94 (=`mor_800`) | koşu içi bildirim zemini |
| `placeholder_tint` | sepya 0,55 · ton −18° · doygunluk ×0,75 · parlaklık ×0,92 | yer tutucu portre/gövde (shader) |
| `stage_scrim` | `void #0D0910`; duraklar y560:0 · y860:0,72 · y1000:0,90 · y1150:1 (seviye atlama) | seviye atlama alt gradyanı |
| `vitrin_scrim` | `void`; alttan y1250:1 → y≈1000:0 | karakter sahnesi alt gradyanı |

## Tipografi (mevcut ölçeğin yeni kullanımları; min 26)

| Kullanım | Yazı | Boyut / ağırlık |
|---|---|---|
| Ekran başlığı (KARAKTERLER) | Cinzel | 64 / 900 (BAŞARIMLAR 80 / 900, v1.1 skorlar gibi) |
| Karakter adı (vitrin) | Cinzel | 96 / 900, `upper_tr` |
| Düğme etiketi (yarım düğme) | Cinzel | 34 / 700 (+0,06 em) |
| Düğme alt satırı | Inter | 26 / 600, `kemik_300` |
| Blurb | Inter | 32/42 / 400 |
| İstatistik etiketi / değeri | Inter 26 / 700 · Cinzel 40 / 700 | |
| Başarım adı / açıklama | Cinzel 38/44 / 700 · Inter 28/34 / 400 | `upper_tr`, ≤22 harf · ≤60 karakter |
| İlerleme / tarih | Cinzel 34 / 700 · Inter 26 / 600 | |
| Bildirim etiketi / adı | Inter 26 / 700 (+0,14 em) · Cinzel 38 / 700 | |
| Özet çipi | Cinzel 30 / 700 · Inter 28 / 600 | |
| Seviye atlama üst yazı | Cinzel 34 / 700 (+0,18 em) | (v1.1: 34; konum değişti) |

## Ölçü

| Token | Değer | Konum |
|---|---|---|
| `menu_col_top` | 1556 | menü düğme sütunu üstü (v1.1: 1715) |
| `menu_half_btn` | 454×132, aralık 27 | KARAKTERLER \| BAŞARIMLAR, y 1763 |
| `menu_hero_box` | 960×960 | x 60, y 560 |
| `char_stage` | 1080×1060 | y 190–1250, tam taşma |
| `char_name_y` | 1060 | ad bloğu |
| `char_panel` | 936×446 (esnek) | y 1250 |
| `char_stat_tile` | 282×78, aralık 12 | 3×2 |
| `char_card` | 252×264, aralık 27 | y 1722–1986 |
| `char_select_btn` | 936×156 | y 2013 |
| `back_btn` | 936×132 | y 2196 (alt 72) |
| `ach_summary` | `N / 22` y 262; çubuk 936×20 y 340 | |
| `ach_list` | y 400–2172 | kaydırmalı |
| `ach_group_h` | 936×72 | yapışkan |
| `ach_row` | 936×156, aralık 12 | dolgu 24 |
| `ach_plate` | 108×108, ikon 68 | |
| `ach_right_col` | 240 | ilerleme/tarih |
| `toast` | 780×120, radius 18, kenar 4 | x 150, **y 820 + safe_top** |
| `toast_icon` | 84 | |
| `result_chip` | 936×96 | y = şerit alt + 24 |
| `result_combo_max` | 4; özet varken **3** | |
| `levelup_title_y` | 880 (etiket) / 924 (başlık) | v1.1: 130 |
| `levelup_ring` | 4 px, α 0,9→0, 450 ms | S-02 |
| `arrow_glyph_margin` | ≥ 36 (üçgen ucu dahil) | S-05 |
| `debug_label_y` | 6–40, üst kenar | S-04 |

## Hareket (ms)

| Token | Değer |
|---|---|
| `showcase_breath` | 2400 (ölçek 1→1,015) |
| `showcase_drift` | 6000 (x ±8) |
| `showcase_embers` | ≤12 parçacık, 60–110 px/sn, ömür 3000 |
| `showcase_swap` | 260 (+40 px kayma) |
| `char_focus` | 140 |
| `select_confirm` | 140 çapraz geçiş + 180 rozet pop (1,25→1) |
| `toast_in` / `toast_hold` / `toast_out` / `toast_gap` | 220 / 2100 / 180 / 150 (toplam 2500) |
| `result_chip_in` | giriş t=1100, 200 kayma |
| Easing | `cubic-out` (mevcut) |

## Sayı sınırları (doğrulayıcı önerisi)

`blurb` ≤120 · başarım `name` ≤22 · `desc` ≤60 · kuyruk 3 · eşzamanlı bildirim 1 · ana görsel 960×960.
