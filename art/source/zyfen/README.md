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
