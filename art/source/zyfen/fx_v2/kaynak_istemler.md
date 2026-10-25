# Zyfen — tüm efektlerin yenilenmesi (ChatGPT istemleri)

13 efektin hepsini ikonlarla yan yana inceledim. Bu dosya önceki "Hortum, Tufan, Ay Orağı" dosyasının yerine geçer; o üçü de burada, bir iki küçük düzeltmeyle.

## Genel teşhis

1. **Stil uyuşmuyor.** İkonlarda net şekiller, koyu çivit gölge, ince koyu kontur ve tek bir camgöbeği parıltı var. Efektler ise kenarsız, buğulu, nane rengi bir parlama. Oyunda ikonla efekt aynı beceri gibi durmuyor. Yeni stil ikonlara yaklaşıyor. Hızlı giden mermiler okunabilsin diye yumuşak bir dış parıltı korunuyor.
2. **Üç hilal birbirinin aynısı.** Rüzgar Kesiği, Ay Orağı ve Bölünen Kesik parçası neredeyse aynı görsel; yalnız boyutları farklı. Her birine ayrı bir siluet veriyoruz.
3. **Tepeden görünüm her yerde doğru değil.** Halkalar (Girdap, Nefes Dalgası, Kasırga) tepeden kalmalı. Hortum ve Tufan ise ikondaki gibi ayakta durmalı.
4. **Animasyon yalnız "döndür ve solsun".** Yeni düzende efektler parçalardan oluşuyor ve kod onları ayrı ayrı canlandırıyor: dönen katman, akan doku, iz şeridi, yörüngede taşlar, kıvılcım. Kare sayısı artıyormuş gibi canlı, ama kareler arası titreme yok.

## Nasıl üretilir

- **İki sohbet aç:** biri mermi/vuruş efektleri için (Bölüm 1 ve 3), biri alan/hortum efektleri için (Bölüm 2). Uzun sohbette stil kayabiliyor.
- Her sohbetin ilk mesajına **referans olarak** ilgili becerilerin oyundaki ikonlarını ekle (`art/source/zyfen/icons/`), sonra stil mesajını bir kez gönder.
- Ardından her parça için yalnız tablodaki **"Next sprite: …"** satırını gönder. Her mesajda tek görsel.
- Dosyaları tablodaki adlarla kaydet. Her bölümü ayrı bir zip olarak gönderebilirsin; böylece gelen bölümü hemen kontrol edip bağlamaya başlarım.
- **Öncelik:** ★ olanlar en çok fark yaratanlar. İstersen önce yalnız onları üret.

## Stil mesajı (her sohbette bir kez)

> I'm making layered in-game effect sprites for "Zyfen, the Archmage of Ashen", a mourning wind mage in "Ashen Bastion", a dark gothic 2D mobile survival game. The camera looks down at the ground, so rings and shockwaves are drawn from directly above, while tall effects like tornadoes stand upright in a 3/4 front view. The attached skill icons are the style reference: match them closely. The game assembles and animates these parts in code (rotation, scrolling, sway, trails, orbit, scale, fade), so each sprite is ONE separate part. Generate ONE sprite per message, all in the exact same style:
> - PNG with a **transparent background**, the part centered with at least 8% empty margin on every side
> - painted game-art style like the icons: crisp pale white and mint wind shapes, deep indigo / dark violet shading on the shadow side, a thin dark indigo outline, exactly one small bright cyan glow accent, plus a soft faint outer glow so it stays readable on a dark battlefield
> - bold readable silhouette that still reads when small and moving fast on a phone screen
> - projectiles always point to the RIGHT
> - no characters, no hands, no ground plane, no background scene, no text, no frame, no drop shadow
> Keep palette, outline weight and lighting identical across all sprites. Reply only with the image.

---

## Bölüm 1 — Mermiler (sohbet 1)

### Rüzgar Kesiği (temel saldırı) ★
**Şu an:** buğulu ince hilal, ikondaki keskin kancalı bıçağa benzemiyor.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `kesik.png` | 2:1 | `Next sprite: a slim sharp crescent wind blade flying right, like the attached wind slash icon: a hooked pointed front tip, a thin trailing tail, indigo shading on the outer curve, a tiny cyan glint at the tip.` |
| `kesik_iz.png` | 4:1 | `Next sprite: a short soft afterimage trail for a crescent blade moving right: a curved ribbon of pale mint light, bright at the right end, fading to nothing on the left, no outline.` |

**Oyunda:** iz şeridi bıçağın arkasında uzar ve söner. Bıçak hafifçe titreşerek parlar. `kesik_iz` Bölünen Kesik parçalarında ve Hava Bıçakları'nda da kullanılır.

### Ay Orağı (Bölünen Kesik evrimi) ★
**Şu an:** Rüzgar Kesiği'nin büyütülmüş hali, "dev ay orağı" gibi durmuyor.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `ay_oragi.png` | 2:1 | `Next sprite: a huge crescent moon blade flying to the right, exactly like the attached crescent icon: silver-white blade with jagged wind spikes on the inner edge, deep indigo shading on the outer edge, a bright cyan star glint near one tip. Clearly bigger and more ornate than a plain wind slash.` |
| `ay_oragi_iz.png` | 4:1 | `Next sprite: a wide fading afterimage trail of a giant crescent moving right, a curved ribbon of pale silver-mint light with faint moonlight sparkles, bright at the right end, fading on the left, no outline.` |
| `parilti.png` | 1:1 küçük | `Next sprite: a small four-pointed cyan-white star sparkle, crisp, like the glint on the crescent icon.` |

**Oyunda:** hilal nabız gibi parlar, ardında geniş iz uzanır, ucundaki yıldız yanıp söner. `parilti` başka efektlerde de vurgu olarak kullanılır.

### Bölünen Kesik (parça)
**Şu an:** kesiğin küçüğü, bölünme hissi yok.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `kesik_parca.png` | 2:1 | `Next sprite: a small ragged shard of a broken crescent wind blade flying right, chipped edges, one sharp point, like the small pieces in the attached split slash icon.` |
| `kesik_kirilma.png` | 1:1 | `Next sprite: a small burst where a crescent wind blade cracks apart: a few sharp white fragments flying outward from a cyan flash point, seen from above.` |

**Oyunda:** kesik bölündüğü noktada `kesik_kirilma` bir anlık patlar. Parçalar kısa `kesik_iz` ile dağılır.

### Hava Bıçakları
**Şu an:** tek, bulanık bir yaprak. İkonda sivri hançer yaprakları var.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `hava_bicagi.png` | 2:1 | `Next sprite: a single sharp leaf-shaped wind dagger flying right, like one of the blades in the attached air blades icon: pointed tip, a central vein, indigo shaded edge, tiny cyan glint.` |

**Oyunda:** bıçak uçarken kendi ekseninde hızla döner, arkasında kısa iz. Birden çok bıçak hafif farklı açılarla çıkar.

### Delen Rüzgar (mızrak) ★
**Şu an:** düz, buğulu bir çizgi; ikondaki delici mızrak gücü yok.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `mizrak.png` | 4:1 | `Next sprite: a long piercing spear of compressed wind pointing right, like the attached piercing wind icon: a sharp bright tip, spiral wind bands wrapped around the shaft, indigo shading underneath, fading tail.` |
| `mizrak_uc.png` | 1:1 | `Next sprite: a small cone-shaped shockwave of air bursting forward to the right, like the air pushed in front of a fast spear tip, seen from above.` |

**Oyunda:** gövdedeki spiral şeritler akar (mızrak dönüyormuş gibi). Ucundaki şok konisi titrer, düşmanı delerken bir an büyür.

### Göğün Mızrağı (Delen Rüzgar evrimi) ★
**Şu an:** Delen Rüzgar'ın kopyası. İkonda gökten inen kutsal ışık mızrakları var.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `gok_mizragi.png` | 4:1 | `Next sprite: a radiant heavenly spear of wind pointing right, like the spears in the attached heaven spear icon: a white-hot light core, ornate feather-like wind fins along the shaft, a brilliant cyan tip, larger and more majestic than the normal wind spear.` |
| `gok_isik.png` | 1:2 | `Next sprite: a soft vertical beam of pale white-cyan holy light, narrow and fading at both ends, for flashing behind a heavenly spear.` |

**Oyunda:** mızrak çıkarken arkasında bir an ışık sütunu parlar. Gövde nabız gibi parlar, uçta `parilti` yanıp söner. Normal mızraktan belirgin şekilde büyük olur.

---

## Bölüm 2 — Alanlar ve hortumlar (sohbet 2)

### Hortum ★
**Şu an:** tepeden görülen bir spiral; ikondaki huni hortuma benzemiyor.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `hortum_govde.png` | 1:2 | `Next sprite: the full body of a small tornado funnel seen from the side, exactly like the attached tornado icon: wide swirling top, narrowing to a thin twisting tip at the bottom, spiral wind bands wrapping around it, a faint cyan glow inside the top opening. No debris, no ground.` |
| `hortum_akis.png` | 1:1 | `Next sprite: a seamlessly tileable square texture of diagonal swirling wind streaks, pale white and mint on transparent, no outline, evenly spread, so it can scroll inside the tornado body without visible seams.` |
| `hortum_taban.png` | 2:1 | `Next sprite: a flat ring of dust and ash swirling on the ground at the base of a tornado, seen from a 3/4 angle as a wide ellipse, open in the middle.` |
| `tas_1.png` | 1:1 küçük | `Next sprite: one small jagged dark stone chunk with a pale rim light, like the flying rocks in the tornado icon.` |
| `tas_2.png` | 1:1 küçük | `Next sprite: one flat broken slab of dark stone, different shape, same style.` |
| `tas_3.png` | 1:1 küçük | `Next sprite: one tiny sharp stone shard, same style.` |
| `tas_4.png` | 1:1 küçük | `Next sprite: one small cracked bone-grey rubble piece, same style.` |

**Oyunda:** gövdenin içinde `hortum_akis` yukarı akar, huni dönüyormuş gibi görünür. Gövde hafifçe sallanır, taban halkası döner, taşlar huninin çevresinde farklı hız ve yükseklikte yörüngede döner. Hortum doğarken tabandan büyür, sönerken incelip dağılır.

### Tufan (Hortum evrimi) ★
**Şu an:** Hortum spiralinin büyüğü.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `tufan_govde.png` | 1:2 | `Next sprite: the body of a massive storm tornado seen from the side, like the attached storm icon: a heavy dark indigo storm-cloud crown on top, a thick violent funnel below, spiral bands, a bright cyan eye inside the cloud. Bigger, darker and wilder than the small tornado. No ground.` |
| `tufan_taban.png` | 2:1 | `Next sprite: a wide, violent ground ring of ash, dust and debris at the base of a giant storm, seen from a 3/4 angle as a wide ellipse, darker than the small tornado's base.` |
| `simsek_1.png` | 1:2 | `Next sprite: a single jagged bolt of cyan-white lightning, thin and branching, for flashing inside a storm cloud.` |
| `simsek_2.png` | 1:2 | `Next sprite: a second, differently shaped jagged bolt of cyan-white lightning, same style.` |

**Oyunda:** Hortum'un akış dokusunu ve taşlarını kullanır, daha çok taş daha geniş yörüngede döner. Şimşekler bulut tepesinde rastgele çakar. Daha büyük ve daha ağır döner.

### Girdap
**Şu an:** yumuşak bir halka; ikondaki keskin kanatlı girdap değil.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `girdap.png` | 1:1 | `Next sprite: a ring of curved hooked wind blades spinning around an empty center, seen from directly above, like the attached vortex icon, a small cyan glow on one blade.` |
| `girdap_ic.png` | 1:1 | `Next sprite: a faint soft spiral of thin wind streaks seen from above, no outline, low contrast, to sit inside a spinning ring.` |

**Oyunda:** dış halka bir yöne, iç spiral ters yöne döner. Halka hafifçe nabız atar. Çekilen düşmanların yanında kısa rüzgar çizgileri çıkar.

### Hava Cebi
**Şu an:** soluk, neredeyse görünmeyen bir baloncuk.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `hava_cebi.png` | 1:1 | `Next sprite: a translucent orb of trapped swirling air seen from above, like the attached air pocket icon: a clear bright rim, curling wind streaks inside, indigo shading on one side, a small cyan highlight.` |
| `hava_cebi_patlama.png` | 1:1 | `Next sprite: the moment an orb of trapped air bursts, seen from above: a thin bright broken rim flying outward with a few wind curls.` |

**Oyunda:** iç girdap yavaş döner, küre hafifçe şişip söner. Süre bitince `hava_cebi_patlama` bir an görünür.

### Nefes Dalgası ★
**Şu an:** ince düz bir halka; ikondaki güçlü rüzgar halkası yok.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `dalga.png` | 1:1 | `Next sprite: an expanding shockwave ring of wind seen from directly above, made of several thick curved wind arcs chasing each other around the circle, like the attached breath wave icon, transparent center, one cyan glint.` |

**Oyunda:** halka büyürken hafifçe döner ve incelerek söner. Arkasından ikinci, daha soluk bir halka gelir.

### Kasırga Patlaması
**Şu an:** iyi durumda ama ikondaki enkaz ve camgöbeği çekirdek yok.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `kasirga.png` | 1:1 | `Next sprite: a violent burst ring of wind seen from above, like the attached hurricane burst icon: thick wind blades shooting outward, a bright cyan core flash in the center, small stone fragments flung out.` |

**Oyunda:** halka hızla büyür, çekirdek bir an parlar. Hortum'un taşları dışarı savrulur, kısa bir ekran sarsıntısı eşlik eder.

---

## Bölüm 3 — Atış ve isabet (sohbet 1'in sonuna)

### Avuç / isabet
**Şu an:** atış ve isabet için tek ortak bir girdap var; ikisi aynı görünüyor.

| Dosya | Oran | Gönderilecek satır |
|---|---|---|
| `avuc.png` | 1:1 | `Next sprite: a small bright gathering of wind at a point, short curling streaks spiralling inward to a cyan-white spark, for the moment a mage releases a spell from his palm.` |
| `isabet.png` | 1:1 | `Next sprite: a small sharp impact burst of wind seen from above, a few short white streaks and tiny shards flying outward from a cyan flash point.` |
| `isabet_buyuk.png` | 1:1 | `Next sprite: a bigger heavier impact burst of wind seen from above, a ring of sharp white streaks and indigo-shaded shards flying outward, a bright cyan center flash.` |

**Oyunda:** `avuc` atış anında elde toplanıp söner. `isabet` normal vuruşta, `isabet_buyuk` Ay Orağı ve mızrak vuruşlarında kullanılır.

---

## Toplam

- Bölüm 1: 12 parça
- Bölüm 2: 17 parça
- Bölüm 3: 3 parça
- Toplam 32 parça. ★ öncelikli 7 beceri (Rüzgar Kesiği, Ay Orağı, Delen Rüzgar, Göğün Mızrağı, Hortum, Tufan, Nefes Dalgası) bunların 21'ini oluşturuyor.

Her zip gelince parçaları tek tek kontrol edeceğim: şeffaflık, kenar payı, ikonla uyum, küçük ekranda okunurluk ve `hortum_akis` dokusunun dikişsiz döşenmesi. Dikiş olursa kodda düzeltirim. Sonra animasyon işi bir çalışana gider. Çalışan ekran görüntüsüyle kendini kontrol ettikten sonra debug APK linkini sana veririm.
