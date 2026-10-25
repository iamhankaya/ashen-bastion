# Zyfen efekt yenilemesi v2 — ekran görüntüleri (T20261025-57)

Üretim: `xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 -s res://tools/capture/shots_zyfen_fx.gd -- <dizin>`
(sabit tohum `SEED = 20261025`; Mesa llvmpipe, JPEG q84). `_yakin` = kamera yakınlaştırmalı kare.

- Hortum: `fx_hortum_dogus` (tabandan büyüme), `fx_hortum_ayakta*` (ayakta, akış + taşlar), `fx_hortum_sonus` (incelme)
- Tufan: `fx_tufan_dogus`, `fx_tufan_ayakta*`, `fx_tufan_simsek_yakin` (şimşek), `fx_tufan_sonus`
- Girdap: `fx_girdap_a`, `fx_girdap_yakin_a/b` (ters dönen iki katman)
- Hava Cebi: `fx_pocket*`, `fx_pocket_patlama`
- Nefes Dalgası: `fx_wave_a/b/c` (ana halka + ikinci soluk halka)
- Kasırga Patlaması: `fx_hurricane_a/b/c` (çekirdek parlaması, taşlar)
- Rüzgar Kesiği + iz: `fx_basic*`; Ay Orağı + iz + parıltı: `fx_moon*`
- Bölünen Kesik + kırılma: `fx_split*`; Hava Bıçakları: `fx_blades*`
- Delen Rüzgar + uç (isabette büyür): `fx_delen*`; Göğün Mızrağı + ışık sütunu: `fx_spear*`
- Avuç / isabet / büyük isabet: `fx_palm_cast*`, `fx_isabet_yakin`, `fx_isabet_buyuk_yakin`
- Genel: `fx_storm*` (Tufan+Hortum+Girdap), `fx_crowd` (300 düşman + bölgeler), `fx_levelup_*` bu turda yeniden alınmadı
