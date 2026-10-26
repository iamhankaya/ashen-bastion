# Zyfen kaynak görselleri (v2.0.2)

Kullanıcı üretimi (ChatGPT görsel, Gemini/ChatGPT video), VLAD kontrolünden geçti (2026-10-24). Tasarım: `docs/design/v2.0.2/2026-10-24-zyfen-design.md`.

- `zyfen_concept.png`: seçilen kıyafet taslağı (referans).
- `zyfen_idle.png`: duruş, 1024x1536, şeffaf.
- `zyfen_portrait.png`: karakter seçim portresi, 1024x1536, arka planlı (hareketli sürüm sonra gelecek).
- `frames/walk/` 8 kare: `video/walk.mp4` içinden bir tam adım döngüsü (24 fps'de kare 155–182, eşit aralık), yeşil arka plan silindi.
- `frames/cast/` 6 kare: `video/cast.mp4` kare 57, 61, 64, 67, 73, 79 (hazırlık → savuruş → açık avuç = atış anı kare 4 → tutuş → geri çekiş).
- `frames/gather/` 4 kare: `video/gather.mp4` kare 13, 22, 40, 63 (rüzgar toplama: eller kalkar → birlikte → tutuş → iner).
- Yeşil silme: alfa = 1 − clamp((G − max(R,B) − 20)/40); yarı saydam piksellerde G ≤ max(R,B)+8 (yansıma temizliği). Botların altında hafif gölge izi ve yeşilimsi ton kalabilir; bağlama fazı `tools/art/chroma_key.py` ile yeniden işleyebilir (kaynak videolar burada).
- `_reddedilen/`: görsel üreticiyle tek tek çizilen ilk 3 yürüme karesi (bacak sırası çizilemediği için video yöntemine geçildi); kullanılmaz.
- Kol düzeneği yok: Zyfen tek parça tam gövde karelerle çizilir (tasarım §7).

## Hareketli portre (v2.0.3 A)
- **Araç/model:** Gemini API Interactions, `gemini-omni-1.1-flash`, `tools/art/gen_video.py`, 2026-10-26; kaynak `zyfen_portrait.png`.
- **İstem (özet):** 4 sn döngü, sabit kamera; nefes, gümüş saç ve paltonun rüzgârı, sarılı elin çevresindeki yeşil-beyaz rüzgâr
  girdaplarının yavaş dönüşü, kıvılcımlar, ateş titremesi; poz/kadraj sabit. Kullanıcı onayı: VLAD cevabı #5 (2026-10-26).
- **İşleme:** üstten 720×1080 kırp → 576×864 → 20 fps → Theora q4, GOP 40: `assets/video/portrait/zyfen.ogv` (≈0,87 MB, 4 sn, döngüde oynar).
