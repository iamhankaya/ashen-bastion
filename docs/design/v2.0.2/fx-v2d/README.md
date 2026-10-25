# Hava Cebi görsel ayarı (T20261025-81)

`karsilastirma.jpg`: sol sütun **önce** (fx-v2c), sağ sütun **sonra** (fx-v2d); satırlar: harita zemini, açık düz zemin, koyu düz zemin.
Aynı tohum (`SEED=20261025`) ve an (Hava Cebi doğuşundan 30 adım sonra), yakın plan 2×, Mesa llvmpipe.
Üretim: `xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 -s res://tools/capture/shots_zyfen_fx.gd -- <dizin> ayar_cebi` (görüntüler 420x400 kırpıldı).

| Parametre (`scripts/view/wind_renderer.gd`) | Önce | Sonra |
|---|---|---|
| `ALPHA_POCKET` (küre alfası) | 0.85 | 0.68 (yaklaşık %20 düşüş) |
| iç girdap alfası (`POCKET_INNER`, küre alfasına çarpan) | 0.7 | 0.56 (0.7 × 0.8) |
| `POCKET_TINT` (küre, iç girdap, patlama; `GIRDAP_TINT` ile aynı yön) | beyaz | (0.93, 0.89, 0.84) |

Genel `ZyfenFx.grade` (parlaklık 0.93, doygunluk 0.9, kül tonu) v2c'den beri zaten uygulanıyordu; değişmedi.
Yalnız görsel: sim, oynanış verisi (`data/skills/hava_cebi.json`) ve asset'ler değişmedi.
