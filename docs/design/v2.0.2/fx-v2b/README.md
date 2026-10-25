# Zyfen efekt ince ayarı — ekran görüntüleri (T20261025-58)

Üretim: `xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 -s res://tools/capture/shots_zyfen_fx.gd -- <dizin> ayar_kalabalik,ayar_binme,ayar_tufan,ayar_girdap,ayar_taban,ayar_donus`
(sabit tohum `SEED = 20261025`; Mesa llvmpipe, JPEG q84).

- `onceki_sonra_*`: solda fx-v2 (önce), sağda bu tur (sonra): `kalabalik`, `girdap`, `hortum`, `tufan`.
- `ayar_kalabalik`: 142 düşman (alive tavanı) + Tufan + Hortum + Girdap; düşmanlar ve küreler bölgenin önünde okunur.
- `ayar_binme*`: üst üste binen 3 hortum (ek hortumlar soluk). `ayar_tufan_buyuk`: yarıçap 420 Tufan (gövde ekranın ~%35'inde).
- `ayar_girdap*`: sade Girdap. `ayar_taban_yakin`: soluk, kül tonlu Hortum tabanı.
- `donus_3kare` / `ayar_donus_0..2`: art arda 8 sim adımı aralıklı 3 kare (akış dokusu yatay kayar).
- Notlar: llvmpipe; kalabalık karesi sim'in alive tavanı (142) kadar düşman içerir, 300 değil. Göz kararı kare karşılaştırması, cihazda doğrulanmadı.
