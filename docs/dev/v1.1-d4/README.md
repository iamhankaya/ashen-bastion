# D4 — kareli yürüme: ölçümler ve görseller

Tüm görseller bu klasörde (commit'li). Üretim komutları sonunda.

| Dosya | İçerik |
|---|---|
| `gs34_walk_preview.png` | `art/ref/v1.1/oyuncu-yurume-34.jpg` (3/4, kolsuz, 3×2) → `make_strip.py --preview` (üst: yeşil zemin, alt: koyu mor; kırmızı = ayak çizgisi, turkuaz = hücre ortası, son hücre = duruş) |
| `piyade_walk_preview.png` | `art/ref/v1.1/kareler-ilk-deneme.png` piyade satırı (7 hücre) → `--preview` |
| `ingame_walk_synthetic.png` + `.json` | **Oyun içi** kare dizisi, sentetik şerit: oyuncu her kare `stride/N = 22,67 px` ilerler; basan ayak renkli blok (macenta/turkuaz). Blok zeminde sabit kalır |
| `ingame_walk_real_candidate.png` | Aynı oyun içi dizi, gerçek 3/4 kareler (veriye BAĞLANMADI; yalnız kapıyı göstermek için) |

## Oyun içi ayak kilidi (sentetik şerit, `tools/capture/shots_walk.gd`)
Basan ayağın dünya x'i (ölçülen), kare sırası 1,2,3,4,5,0,1,2,3,4,5,0:
`41.4 40.4 | 107.0 106.2 105.6 | 172.5 172.1 171.7 | 238.9 238.8 238.7 | 306.0 305.9 306.0`
→ stans içinde kareden kareye ≤1,0 px kayma (kabul ±3 px). Oyuncuya göre ayak kare başına −22,67 px (= stride/N) gider.
Not: ilk ölçümde 3 px/kare kayma vardı; nedeni shader'daki adım-fazı etek salınımıydı (`walk_phase`, ±3 px, ayak dahil).
Kare modunda bu terim kapatıldı (`player_sway.gdshader`: `cells > 1.5`).

## Omuz uyumu (kare modu, 300 px/sn, test `test_player_view_frames.gd`)
Kenetsiz: 10,08 / 10,22 px (eğim 3,6° × omuz-ayak 0,8H). `SHOULDER_TOL = 4,5` kenetlemesiyle ≤4,5 px (kabul ≤5). Kalan
~5,6 px sapma gövde dikişinde kalır (kol sim omzuna yakın tutulur; sim/namlu değişmez).

## Gerçek kareler: kalite kapısı (prompts.md C1) — SONUÇ: KALDI → prosedürel yedek
`oyuncu-yurume-34.jpg` (6 kare, `make_strip.py --grid 3x2`, ölçek 0,562, hücre 190×323):

| Madde | Ölçüm | Sonuç |
|---|---|---|
| 1 Ayak hizası (±8 px@1536) | kaynakta 17,2 px (satır içi en büyük fark; araç sonra hizalar) | kaldı (araçla düzeltilebilir) |
| 2 Boy (±%3) | −0,09 / **−3,25** / +0,79 / +0,09 / −1,49 / +0,44 % | sınırda (kare 2) |
| 3 Omuz (±%1) | landmark tahmini ≤ 0,025 H (≈5 px @200) | ölçüm güvenilmez; `shoulder_dev` verilmedi |
| 4 Kolsuz | görsel: temiz omuz dikişi | geçti |
| 5 Palto/atkı | boy tutarlı, kenar şekli kareden kareye değişiyor (genişlik −8 … +7,7 %) | zayıf |
| 8 **Basan ayak kayması (stride/N ±3 px)** | basan ayak konumu (dünya px, ort.'ya göre): −23,4 / +6,2 / +15,9 / −23,7 / +22,8 / +25,0; çift hataları 52 / 32 / 17 / 69 / 25 / 26 px, **0/6 çift ≤3 px** | **KALDI** |

Neden: 6 karede yalnız 3 poz (A B C A' B' C') tekrarlanıyor ve basan ayak sıçrıyor; gerçek bir yürüme için basan ayağın
gövdeye göre kare başına tek yönde (geriye) eşit adım gitmesi gerekir. Bu veriyle oyunda ayak ±25–70 px kayardı
(`ingame_walk_real_candidate.png`). Piyade 7 hücre (`kareler-ilk-deneme.png`): boy +%10,6 (kare 2), 0/7 çift ≤3 px → kaldı.
`kareler-ilk-deneme.png` oyuncu satırı yan profil olduğundan kullanılmadı (görev kararı).

Kapanış: `rig.walk.frames: 0`, manifest `frames: 1` kaldı; kod yolu sentetik şeritle tam sınandı.

## Komutlar
```
python3 tools/art/make_strip.py --sheet art/ref/v1.1/oyuncu-yurume-34.jpg --grid 3x2 --kind player \
  --stand assets/gfx/char/gunslinger_body.png --out <şerit.png> --manifest <json> --preview --preview-dir docs/dev/v1.1-d4
python3 tools/art/make_strip.py --sheet art/ref/v1.1/kareler-ilk-deneme.png --rows 1 --cells 7 --drop-dup-last --kind enemy \
  --stand assets/gfx/enemies/curumus_piyade.png --display-height 104 --out <şerit.png> --manifest <json> --preview
xvfb-run -a -s "-screen 0 720x720x24" godot --path . --rendering-driver opengl3 --resolution 720x720 \
  -s res://tools/capture/shots_walk.gd -- <dizin> synthetic            # ya da: real <şerit.png> <manifest.json>
python3 tools/capture/walk_montage.py <dizin> <montaj.png> 6
```
