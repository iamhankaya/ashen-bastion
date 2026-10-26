# Exp küreleri (v2.0.3) — kaynak görseller

Kullanıcı onaylı seçim (2026-10-26, T20261026-57 spec kapısı). İşleme ve oyuna bağlama uygulama B fazında (`ab-gorsel-ikon-uret`, `ab-efekt-shader`).

| Dosya | Tip | Değer eşiği (görünüm) |
|---|---|---|
| `normal.png` | normal | xp < 5 |
| `elit.png` | elit | 5 ≤ xp < 80 |
| `ara_boss.png` | ara boss | xp ≥ 80 |

- Araç/model: Codex CLI 0.164.0, yerleşik görsel üretim aracı (ChatGPT hesabı), tek deneme; 2026-10-26.
- Çıktı: 1254x1254 (normal, ara boss) ve 1024x1024 (elit), RGBA şeffaf.
- Ortak istem: `game XP pickup icon for a dark gothic 2D mobile game. <tip tarifi> Dark gothic fantasy, manhwa-style illustration, clean ink contour lines, cel-shaded with soft painterly gradients. Transparent background (alpha), no ground, no shadow, centered, 12% empty margin, 1024x1024. No text, no letters, no frame, no border, no badge, no green. Must read clearly when scaled down to 64 pixels: simple bold silhouette.`
- Tip tarifleri:
  - normal: `A tiny will-o'-the-wisp soul: a small pale cyan-white teardrop spirit flame with two small dark hollow eyes, a short curling wispy tail below, a few tiny floating soul sparks around it, cute but eerie, cold color, delicate and small.`
  - elit: `A medium violet soul spirit: the same teardrop will-o'-the-wisp spirit design but larger and fiercer, deep violet-magenta spectral flame body with two glowing narrow eyes, three swirling wisp tails, a faint ring of violet soul sparks orbiting it, clearly more powerful than a small cyan soul.`
  - ara boss: `A large golden-amber soul spirit: the same teardrop will-o'-the-wisp spirit design but big and majestic, golden-amber flame body with a white-hot core and two blazing eyes, a small floating crown of embers above it, burgundy ember sparks and ash around, the brightest and most powerful soul.`
