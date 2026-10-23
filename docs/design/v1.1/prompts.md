# Ashen Bastion v1.1 — AI görsel promptları (isteğe bağlı)

Hepsi **isteğe bağlıdır**: `DESIGN.md` §1'deki animasyonlar bunlar olmadan uygulanabilir. Öncelik sırası **C1 → C2 → B2 → B3 → B4 → B5** (C = kareli yürüme döngüsü, DESIGN.md §1.7; B1 C2 ile birleştirildi).

## Ortak kurallar (her prompta eklenir)

- **Referans görsel(ler)i prompta ekle** (aracın "image reference / character reference" alanı): ilgili `art/ref/` dosyaları aşağıda her bölümde yazılı. Amaç: çizgi, renk ve oran tutarlılığı.
- **Arka plan:** tek düz parlak yeşil, tam `#00FF00`, gölgesiz, geçişsiz, dokusuz; öznede yeşil ton, yeşil yansıma ve yeşil kenar ışıması yok; özne kenarı keskin (yumuşak/yarı saydam kenar yok); kare dışına taşma yok.
- **Stil (ortak, İngilizce):** `dark gothic fantasy, manhwa-style illustration, clean confident ink contour lines, cel-shaded with soft painterly gradients, muted palette of dark violet, burgundy, bone white, dark brown and bronze, single warm amber accent, worn torn fabric, subtle metal highlights, high detail, no text, no logo, no watermark`
- **Olumsuz (negatif) prompt:** `green clothing, green glow, green rim light, drop shadow on background, ground plane, floor, text, watermark, frame, border, extra limbs, extra weapons, blurry, low contrast, photorealistic, 3d render`
- Çıktı: PNG, belirtilen tuval; özne tuvalin ortasında, çevresinde ≥ %8 boşluk. Kullanıcıdan gelen yeşil arka plan mevcut boru hattında silinir.
- Yönlendirme: tüm özneler **sağa** bakar/gider (oyun gerekince aynalar).

## C1 — Gunslinger kolsuz gövde YÜRÜME DÖNGÜSÜ (6 kare) — en yüksek değer

**Amaç:** ayak kayması ("resim gibi süzülme") sorununu bitirmek. Ayrıntı: `DESIGN.md` §1.7. Kolsuz gövde kullanılır; kollar/tabancalar oyundaki ayrı kol görselidir (çizime katılmaz).

**Yüklenecek referanslar (image-to-image / character reference):**
1. `art/ref/parca-govde-kolsuz.png` — **ana referans** (duruş karesi, ölçek ve kamera açısı bu).
2. `art/ref/karakter-konsept.png` — kostüm/yüz tutarlılığı.
3. `art/ref/sprite-durus-kosu.png` — oran/renk.
4. `docs/design/v1.1/mock/10-yurume-dongusu-kareler.png` — bacak pozu kılavuzu (aracın "pose / sketch / control image" girişi varsa o karenin kırpmasını ver; yoksa yalnızca metni kullan).

**Üretim şekli (önerilen):** **kare kare** üret (6 ayrı görsel), her biri 1024×1536 (2:3, duruş görseliyle aynı tuval). Tek 6'lı şerit önerilmez (araçlar genelde ~2048 px'i aşan çıktıda tutarlılığı kaybeder; birleştirme araçla yapılır). Her kare **aynı tohum/aynı referanslarla** ve aynı temel prompt + yalnız poz cümlesi değişerek üretilir.

**Ortak temel prompt (her karede aynı, sonuna kare pozu eklenir):**

> The exact same character as the reference image: ash-grey messy hair, pale face with calm tired expression, red torn scarf, torn dark-purple noble long coat with ornate trim and ragged hem, white shirt, dark brown leather straps and holsters with revolvers on both hips, dark trousers, tall dark-brown lace-up leather boots. **The character has NO ARMS and no hands visible: both shoulders end cleanly at the shoulder seam under the coat (the arms are separate sprites).** Full body, three-quarter front view facing right, exactly the same camera angle, same scale, same proportions, same lighting and same line style as the reference image. Walking pose. The torso leans very slightly forward (about 4 degrees). The torn coat tails and the scarf hang in a calm natural drape, moving slightly with the step, but **identical in length and shape in every frame** (do not change the coat or scarf design). Dark gothic fantasy, manhwa-style illustration, clean confident ink contour lines, cel-shaded with soft painterly gradients, muted palette of dark violet, burgundy, bone white, dark brown and bronze. Single character, centered, **both feet fully visible, the lowest foot touching the same invisible ground line at the same height from the bottom edge of the canvas in every frame (about 6% above the bottom edge)**, margins of at least 8% on all sides. Flat solid #00FF00 green background, no shadow, no ground, no text.

**Kare pozları (temel prompta eklenir; "right/left" = karakterin kendi sağı/solu, ekrana göre sağa bakan):**

| Kare | Poz cümlesi |
|---|---|
| 1 sağ temas | `Frame 1 of 6, right-foot contact: the right leg is stretched forward with the heel just touching the ground, the left leg is behind with the toe pushing off; stride is at its widest; body height normal.` |
| 2 sağ aşağı | `Frame 2 of 6, right-foot down: the weight is on the right foot which is now flat on the ground under the front of the body, the right knee slightly bent, the left leg lifting off behind; the body is at its lowest point (about 3% shorter than frame 1).` |
| 3 geçiş | `Frame 3 of 6, passing: the right leg is straight and vertical under the hips carrying the weight, the left leg swings forward past it with the knee bent and the foot lifted slightly; the body is at its highest point (about 3% taller than frame 1).` |
| 4 sol temas | `Frame 4 of 6, left-foot contact: mirror of frame 1 — the left leg stretched forward with the heel just touching the ground, the right leg behind with the toe pushing off; stride at its widest; body height normal.` |
| 5 sol aşağı | `Frame 5 of 6, left-foot down: mirror of frame 2 — weight on the flat left foot, left knee slightly bent, right leg lifting behind; body at its lowest.` |
| 6 geçiş | `Frame 6 of 6, passing: mirror of frame 3 — left leg straight under the hips carrying the weight, right leg swinging forward with the knee bent; body at its highest.` |

**Negatif prompt:** ortak negatif + `arms, hands, fingers, sleeves hanging, weapon in hand, running pose, jumping, different outfit, different hair, different boots, changed scarf, extra belt, short coat, motion blur, speed lines`.

**Ölçü ve hizalama işareti:** her karenin tuvali 1024×1536; **ayak çizgisi alt kenardan 6% (≈ 92 px)**, gövde yatay merkezi tuvalin ortasında (omuz seviyesi tüm karelerde aynı x). Aracın cetvel/ızgara özelliği varsa tuvale 92 px yukarıda yatay bir ipucu çizgisi koyup üretimden sonra sil. Üretim sonrası karelerdeki omuz noktasının x,y değerleri ±%1 (±15 px @1536) içinde kalmalı; kalmıyorsa `DESIGN.md` §1.7.4'teki kare başı omuz tablosu ölçülerek verilir.

**Üretim sonrası kontrol listesi (kullanıcı):**
1. **Ayak hizası:** 6 karede de en alçak ayağın tabanı aynı yükseklikte (aynı piksel sırası ±8 px @1536).
2. **Boy:** baştan tabana boy duruş görseliyle ±%3; "aşağı" karesi ≈ %3 kısa, "geçiş" ≈ %3 uzun (daha fazlası zıplama gibi görünür).
3. **Omuz noktası** 6 karede aynı yerde (yan yana koyup üst üste bindirerek bak).
4. **Kolsuz:** hiçbir karede el/kol/silah yok (omuz dikişi temiz).
5. **Palto ve atkı** boyu/şekli kareler arasında aynı (şekil değişirse oyunda zıplar).
6. **Işık ve renk** aynı; sol/sağ bacak ayrımı net; yüz aynı kişi.
7. Arka plan düz `#00FF00`; ayakkabı kenarında yeşil yansıma yok.
8. Sırayla (1→6→1) hızlıca değiştirince **ayak zeminde sabit, vücut hafifçe iniyor-çıkıyor** hissi; aksi halde o kareyi yeniden üret.

## C2 — Çürümüş Piyade YÜRÜME DÖNGÜSÜ (6 kare)

**Referans:** `art/ref/dusmanlar/curumus-piyade.png` (**ana**: ölçek, kamera, ışık), `docs/design/v1.1/mock/10-yurume-dongusu-kareler.png` (alt şerit = piyade bacak kılavuzu). **Tuval:** 1312×1199 (mevcutla aynı). **Üretim:** kare kare, 6 ayrı görsel, aynı tohum/referans. Elit Piyade aynı kareleri oyunda renk/ölçekle kullanır (ayrı üretim gerekmez). Mevcut görsel ek olarak duruş yedeği olarak kalır.

**Ortak temel prompt:**

> The exact same undead infantry soldier as the reference image — the same rusted pauldron and armor plates, tattered crimson rags, bandaged skeletal face with glowing red eye, long clawed arms hanging low, hunched shambling posture — with identical design, identical proportions, same scale, same camera angle (slightly from the front, facing right), same lighting and same line style. Walking cycle pose. The torso is hunched forward about 22 degrees, head forward, arms swinging loosely and **the same in design in every frame**. **Both feet fully visible; the lowest foot touches the same invisible ground line at the same height from the bottom edge of the canvas in every frame (about 6% above the bottom edge).** Silhouette width and design never change between frames; only the legs, the arm swing and a slight body height change. Dark gothic fantasy, manhwa-style illustration, clean ink contour lines, cel-shaded with soft painterly gradients, muted palette of rust brown, burgundy, bone, single warm amber accent. Single character, centered, margins at least 8%, flat solid #00FF00 green background, no shadow, no ground, no text.

**Kare pozları:** C1 tablosundakilerle aynı 6 poz cümlesi (temas → aşağı → geçiş → mirror), ek olarak: `the arm on the same side as the forward leg swings back, the opposite arm swings forward (cross-body swing)`; gövde yüksekliği farkı **±%3** (aşağı/geçiş) aynı.

**Negatif prompt:** ortak negatif + `running, jumping, weapon, different armor, different face, clean armor, standing straight, motion blur, speed lines`.

**Ölçü / hizalama:** tuval 1312×1199, ayak çizgisi alt kenardan 6% (≈ 72 px), gövde yatay merkezi tuvalin ortası.

**Kontrol listesi:** C1'in 1–8 maddeleri; ek: **siluet genişliği** kareler arasında ±%8 (kollar savrulunca genişlik değişir, ama zırh/pelerin tasarımı değişmemeli); kare başına dosya adı `piyade-yurume-1..6.png`.

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

`art/ref/v1.1/` altına (kullanıcı ekler): `oyuncu-yurume-1..6.png`, `piyade-yurume-1..6.png`, `gunslinger-olum-1.png`, `gunslinger-olum-2.png`, `kol-doldurma-1.png`, `kol-doldurma-2.png`, `kale-lordu-kollar-yukari.png`, `eklenti-*.png`. Piyade 6 kare gelince `assets/gfx/manifest.json` `curumus_piyade.png` → `frames: 6` (yatay şerit, kargadaki gibi); oyuncu 6 kare `gunslinger_body_walk.png` yatay şerit olur (`rig.walk.frames: 6`, `rig.walk.stride: 136`). Şeridi birleştirme ve manifest güncellemesi plan fazı görevidir (`tools/art/`).
