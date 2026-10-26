# Gunslinger kaynakları (v2.0.3 A)

## Yürüme şeridi (F-038)
- **Araç/model:** Gemini API Interactions, `gemini-omni-1.1-flash` (Veo 3.1 uçları 2026-10-26'da kapalı), `tools/art/gen_video.py`, 2026-10-26.
- **Referans:** `assets/gfx/char/gunslinger_body.png` (kolsuz gövde) 720×1280 düz yeşil (#00FF00) tuvale, kare boyunu dolduracak şekilde
  yerleştirildi (`art/source/gunslinger/video/ref_green_tall.png`; video klasörü .gitignore'da, repoya girmez).
- **İstem (özet):** düz kroma yeşil zemin, sabit kamera, gölge yok; referanstaki karakter KOLSUZ kalır (kol/el/silah ekleme),
  yan görünümde sağa doğru yerinde yürür (treadmill), net sıralı bacak adımları, palto ve eşarp hafif sallanır, tüm boy karede, 6 sn.
  Kullanıcı onayı: VLAD cevabı #7 (2026-10-26).
- **Kare seçimi:** 24 fps, bir tam adım çevrimi ≈ 29,3 kare (kare 20 ↔ 108, bacak silueti farkı ölçümü). Eşit aralıkla 8 kare: video kare
  indeksleri (0 tabanlı) 20, 24, 27, 31, 35, 38, 42, 46 → `frames/walk/w_00..07.png`.
- **Yeşil silme:** `tools/art/chroma_key.py` `key_image` (varsayılan eşikler), ortak kutuya kırpılmış (8 px pay).
- **Şerit:** `python3 tools/art/make_zyfen_strip.py --src art/source/gunslinger --idle assets/gfx/char/gunslinger_body.png --out assets/gfx/char/gunslinger_body_walk.png --body-out <geçici> --manifest art/source/gunslinger/strip_manifest.json --quality art/source/gunslinger/quality.json --display-height 200 --stride 110 --align feet`
  `--stride` taraması (basan ayak ≤3 px çift sayısı): 150 → 5/8, 136 → 5/8, 130 → 5/8, 120 → 7/8, **110 → 8/8** (seçildi).

## Hareketli portre
- **Araç/model:** aynı (`gemini-omni-1.1-flash`), kaynak `assets/ui/portre-seviye-atlama.png`, 4 sn 720×1280 çıktı.
- **İstem (özet):** ağız tamamen kapalı ve hareketsiz (konuşma/gülme yok); yalnız nefes, göz kırpma/kirpik, saç-palto-eşarp rüzgârı,
  ateş ışığı ve kıvılcım; poz ve kadraj neredeyse sabit; döngü.
- **İşleme:** üstten 720×1080 (2:3; alt kısım modelin uzattığı bölgedir) kırp → 576×864 → 20 fps → ileri + geri (ping-pong, 7,95 sn; baş
  eğimi başta/sonda farklı olduğu için) → Theora q4, GOP 40: `assets/video/portrait/gunslinger.ogv` (≈1,3 MB).
  Kullanıcı onayı: VLAD cevabı #7 (ping-pong dahil).
