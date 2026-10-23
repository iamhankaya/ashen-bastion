# Ashen Bastion v1.1 — AI görsel promptları (isteğe bağlı)

Hepsi **isteğe bağlıdır**: `DESIGN.md` §1'deki animasyonlar bunlar olmadan uygulanabilir. Öncelik sırası B1 → B5.

## Ortak kurallar (her prompta eklenir)

- **Referans görsel(ler)i prompta ekle** (aracın "image reference / character reference" alanı): ilgili `art/ref/` dosyaları aşağıda her bölümde yazılı. Amaç: çizgi, renk ve oran tutarlılığı.
- **Arka plan:** tek düz parlak yeşil, tam `#00FF00`, gölgesiz, geçişsiz, dokusuz; öznede yeşil ton, yeşil yansıma ve yeşil kenar ışıması yok; özne kenarı keskin (yumuşak/yarı saydam kenar yok); kare dışına taşma yok.
- **Stil (ortak, İngilizce):** `dark gothic fantasy, manhwa-style illustration, clean confident ink contour lines, cel-shaded with soft painterly gradients, muted palette of dark violet, burgundy, bone white, dark brown and bronze, single warm amber accent, worn torn fabric, subtle metal highlights, high detail, no text, no logo, no watermark`
- **Olumsuz (negatif) prompt:** `green clothing, green glow, green rim light, drop shadow on background, ground plane, floor, text, watermark, frame, border, extra limbs, extra weapons, blurry, low contrast, photorealistic, 3d render`
- Çıktı: PNG, belirtilen tuval; özne tuvalin ortasında, çevresinde ≥ %8 boşluk. Kullanıcıdan gelen yeşil arka plan mevcut boru hattında silinir.
- Yönlendirme: tüm özneler **sağa** bakar/gider (oyun gerekince aynalar).

## B1 — Çürümüş Piyade, "adım B" yürüme karesi (en yüksek değer)

**Referans:** `art/ref/dusmanlar/curumus-piyade.png` (mevcut kare = "adım A"). **Tuval:** 1312×1199, tek özne. **Kare sayısı:** 1 (mevcutla birlikte 2 karelik yürüme döngüsü).

> The same undead infantry soldier as the reference image — identical armor, rags, skull face with glowing red eye, same proportions, same scale and same feet position on the canvas — in the opposite walking pose: the other leg stepping forward and the arms swung the opposite way (the arm that was forward is now back), torso leaning slightly forward, shambling gait. Same lighting and same level of detail as the reference. Keep the silhouette height identical to the reference so the two frames alternate without the character jumping. Dark gothic fantasy, manhwa-style illustration, clean ink contour lines, cel-shaded with soft painterly gradients, muted dark palette of rust brown, burgundy and bone, single warm amber accent. Single character, centered, full body, on a flat solid #00FF00 green background, no shadow, no ground, no text.

## B2 — Gunslinger ölüm yığılma karesi (2 kare)

**Referans:** `art/ref/karakter-konsept.png`, `art/ref/parca-govde-kolsuz.png`, `art/ref/sprite-durus-kosu.png`. **Tuval:** 1536×1024 (yatay, çünkü yere yatar). **Kare sayısı:** 2 (ayrı görsel olarak üret). Kollar ve tabancalar gövdeyle **birlikte** çizilir (bu karelerde parça rig kullanılmaz).

> Frame 1 of 2 — "collapse": the same character as the reference sheet (ash-grey messy hair, torn purple noble coat, red scarf, dark trousers and boots, two ornate revolvers) in the middle of falling backwards, knees buckling, head tilted back, both arms thrown out and loose, revolvers slipping from his fingers, coat tails and scarf whipping upward, three-quarter view facing right. Same face, costume and proportions as the reference. Frame 2 of 2 (separate image) — "down": the same character lying on his back on the ground, body slightly angled, arms limp at his sides, one revolver lying near his open hand, scarf and torn coat spread out on the ground, eyes closed, calm and defeated, not gory. Full body visible, character fills about 85% of the canvas width. Dark gothic fantasy, manhwa-style illustration, clean ink contour lines, cel-shaded, muted palette of dark violet, burgundy, bone white, dark brown and bronze. Flat solid #00FF00 green background, no shadow, no ground plane, no text.

## B3 — Doldurma kolları (2 kare, tek kol)

**Referans:** `art/ref/parca-kol-tabanca.png` (mevcut kol, yatay, sağa uzanmış). **Tuval:** 1774×887, mevcut kolla **aynı ölçek, aynı omuz/pivot noktası ve aynı konum** (pivot kolun sol-orta kısmı). **Kare sayısı:** 2. Sol kol yine bunun aynası olacağı için yalnız sağ kolu üret.

> The same horizontal arm holding an ornate revolver as the reference image — identical sleeve, torn cuff, fingerless glove, same revolver design, same scale and same shoulder end position on the canvas — but in a reloading pose. Frame 1 of 2: the revolver's cylinder is swung out to the side, open and empty, the thumb on the ejector rod, the barrel pointing slightly downward. Frame 2 of 2 (separate image): the cylinder is half-closed with fresh bullets visible in the chambers, the wrist flicking to snap it shut, barrel pointing slightly downward. Keep the arm extending to the right, shoulder end on the left. Dark gothic fantasy, manhwa-style illustration, clean ink contour lines, cel-shaded, muted colors with silver metal highlights. Single arm only, no body, flat solid #00FF00 green background, no shadow, no text.

## B4 — Kale Lordu "kollar yukarı" (çağırma ön hazırlığı)

**Referans:** `art/ref/dusmanlar/kale-lordu.png`. **Tuval:** 1312×1199. **Kare sayısı:** 1 (mevcutla aynı ayak/ağırlık noktası).

> The same Fallen Castle Lord as the reference image — identical crowned spiked helmet, ember-lit blackened armor, tattered crimson cape and glowing red eyes, same proportions and the same feet position on the canvas — in a summoning pose: both arms raised and spread wide, head tilted back, chest open, the cape billowing upward, glowing embers and dark smoke rising from the hands and from the ground around the feet. Slightly taller silhouette than the reference. Same lighting and detail level. Dark gothic fantasy, manhwa-style illustration, clean ink contour lines, cel-shaded with painterly gradients, palette of rust, burgundy, ash and bone with warm ember-orange accents. Single character, centered, full body, flat solid #00FF00 green background, no shadow, no ground, no text.

## B5 — Eklenti ikonları, "hero" kalite (isteğe bağlı; SVG önerisi `mock/pickups/` yeterli)

**Referans:** `art/ui/icons/*.svg` (ör. `dinamit.svg`, `hud-can.svg`) ve `docs/ui/DESIGN-UI.md` §9. **Tuval:** 512×512, **6 ayrı ikon**, her biri kare ortasında tek nesne. İkon dili: yüksek kontrastlı siluet, düz dolgu, kalın koyu bordo-siyah kontur (`#2B0E14`), gradyan yok, 54 px'te okunur.

> Flat vector-style game pickup icon, bold dark burgundy-black outline (#2B0E14), solid flat color fills, no gradients, no fine detail, readable at 54 px, one object centered with 8% padding, one single small amber (#E8A24A) accent. Dark gothic fantasy palette: bone white, bronze, burgundy, dark violet. Subject: **[one of]** (1) a small round-bellied glass vial with a cork, red liquid and a bone-white cross; (2) a horseshoe magnet in violet (#A98BEF) with bone-white tips and tiny sparks; (3) a flaming bullet casing in bronze with a burgundy flame and an amber spark; (4) a revolver cylinder in dark brown with bronze chambers and speed lines, one amber chamber; (5) a round black bomb with a burgundy band and a short fuse with an amber spark; (6) a dark revolver cylinder ringed in amber with an amber infinity symbol in the center. Flat solid #00FF00 green background, no shadow, no text.

## Dosya adlandırma ve teslim

`art/ref/v1.1/` altına (kullanıcı ekler): `piyade-adim-b.png`, `gunslinger-olum-1.png`, `gunslinger-olum-2.png`, `kol-doldurma-1.png`, `kol-doldurma-2.png`, `kale-lordu-kollar-yukari.png`, `eklenti-*.png`. Piyade "adım B" gelince `assets/gfx/manifest.json` `frames: 2`, `curumus_piyade.png` yatay iki kare şerit olur (kargadaki gibi).
