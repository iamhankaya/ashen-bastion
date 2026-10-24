# Ashen Bastion v2.0 — AI görsel istemleri (isteğe bağlı)

**Hepsi isteğe bağlıdır:** görsel gelmezse yer tutucu stili çalışır (`DESIGN.md` §6.3). Görseli kullanıcı üretir; yerleştirme `docs/dev/new-character.md` (K9). Öncelik: **P1 → P2 → P4 → P3**.
İsimler **çalışma adıdır** (Barutçu); kullanıcı konsepti değiştirirse yalnız "Karakter tarifi" bloğu değişir, kurallar aynı kalır. Esin kaynağı olan bir karakterin/eserin adı **istemde ve repoda geçmez** (public repo).

## Ortak kurallar (v1.1 `prompts.md` ile aynı çizgi)

- **Referans görsel(ler)i ekle** (image/character reference): gunslinger dosyaları dünya stilini ve oranı sabitler; yeni karakterin *yüzü ve kıyafeti* P1'in çıktısıyla sabitlenir (P2/P3 için P1'i referans ver).
- **Stil (ortak, İngilizce):** `dark gothic fantasy, manhwa-style illustration, clean confident ink contour lines, cel-shaded with soft painterly gradients, muted palette of dark violet, burgundy, bone white, dark brown and bronze, single warm amber accent, worn fabric and leather, subtle metal highlights, high detail, no text, no logo, no watermark`
- **Negatif (ortak):** `text, watermark, logo, frame, border, extra limbs, extra fingers, extra weapons, blurry, low contrast, photorealistic, 3d render, anime chibi, modern clothing`
- **Kare kare üret:** her görsel ayrı üretilir, **tek ızgarada/şeritte toplu istenmez** (v1.1 dersi: toplu ızgarada tutarlılık bozuldu). Aynı tohum/aynı referanslarla, yalnız poz/konu cümlesi değişir.
- Çıktı PNG. Yönlendirme: gövde ve kol **sağa** bakar (oyun aynalar); portre kompozisyonu serbest ama aşağıdaki güvenli alan kuralına uyar.

## Karakter tarifi — Barutçu (varsayılan konsept A; çalışma adı)

> broad-shouldered soot-stained gunpowder demolitionist, short cropped dark hair with a streak of ash grey, heavy stubble, tired but amused expression, brass-rimmed goggles pushed up on his forehead, thick dark-brown leather coat with a high collar and burn marks, charcoal-grey shirt, a bandolier of dynamite sticks and small powder kegs across the chest, heavy bronze-buckled belts, thick leather gloves, a lit fuse spark as the single amber accent; palette of dark brown, charcoal, bronze and muted burgundy (clearly different from the violet-and-red Gunslinger), slower and heavier build than the Gunslinger

Rol/oyun tarzı (yalnız bilgi): yavaş, dayanıklı, alan hasarı; başlangıç becerisi Dinamit.

## P1 — Portre (vitrin + seviye atlama) — en yüksek değer

**Kullanım:** `portrait` alanı; hem vitrin sahnesi hem seviye atlama arka planı (`DESIGN.md` §4, §6.1). **Tuval: 1024×1536 (2:3).** Tam sahneli resim (**yeşil zemin yok**): arkada yıkık gotik kale/sis, kor ışığı.
**Referanslar:** `art/ref/portre-seviye-atlama.png` (**ana**: kamera, ışık, ölçek, arka plan dili), `art/ref/karakter-konsept.png` (dünya stili).

**Kompozisyon kuralları (ölçülebilir):**
1. **Yüz üst üçte birde:** göz hizası tuval yüksekliğinin **%24–30**'unda; baş tepesi **%10–16**.
2. **Alt %40 önemsiz:** y > %62'de yüz, el, silah ve karakter ayırt edici hiçbir ayrıntı olmasın (koyu gradyan ve başlık orayı örter; kıyafet/karanlık serbest).
3. **Güvenli kutu:** önemli her şey x **%12–88**, y **%6–62** içinde; kenarlara dayanan kol/silah olabilir ama yüz ve ana prop kutuda.
4. **Tam taşma:** kenarda şeffaf/boş şerit yok (vitrin nefes ve 8 px sürüklenmesiyle kenar göstermemeli); köşeler arka plan resmiyle dolu.
5. Işık: yüzün sağ-alt tarafı koyu, arkada sıcak kor ışığı (gunslinger portresiyle aynı); **kontrast:** en parlak bölge yüz/ellerde, başlık bölgesi (x %5–55, y %57–68) orta-koyu kalsın.
6. Namlu/prop yüz önünden **geçmesin** (v1.1 N4 dersi); silah/dinamit varsa yüzün yanında ve %62 çizgisinin üstünde.

**İstem (Barutçu):** `Three-quarter bust portrait of {Karakter tarifi}, head tilted slightly, looking at the viewer from slightly below, one gloved hand holding a lit stick of dynamite beside his face (the prop stays left of the face and above 60% of the canvas height), ruined gothic fortress and drifting ash smoke behind him, warm ember glow from the lower background, moody cinematic lighting, {Stil}. Vertical 2:3 composition: eyes at 27% from the top, head top at 12% from the top, nothing important below 62% of the height, subject fully inside the central safe area, background filling every edge of the canvas.`
**Negatif:** ortak + `face covered by a prop, weapon crossing the face, cropped head, empty margins, green background, studio backdrop`.

**Kontrol listesi (kullanıcı):** ☐ göz y ≈ %24–30 ☐ alt %40'ta yüz/el/prop yok ☐ kenarlarda boşluk yok ☐ gunslinger portresinin yanına koyunca aynı çizgi/ışık ☐ yüzde yeşil/çıplak ışık sızıntısı yok ☐ 1024×1536 ☐ başlık bölgesi (sol-alt) aşırı parlak değil.

## P2 — Kolsuz gövde (koşu içi sprite)

**Kullanım:** `rig.body` (`new-character.md`; `tools/art/process_art.py`). Kollar/tabancalar oyundaki ayrı kol görselidir (çizime katılmaz).
**Referanslar:** `art/ref/parca-govde-kolsuz.png` (**ana**: duruş, ölçek, kamera), P1 çıktısı (yüz/kıyafet).
**Tuval: 1024×1536**, **düz parlak yeşil `#00FF00` zemin**, gölgesiz, geçişsiz; özne kenarı keskin; öznede yeşil ton/yansıma yok; özne ortada, çevresinde ≥ %8 boşluk. **Ayak çizgisi alt kenardan %6 (≈92 px)**; gövde yatay merkezi tuval ortasında; omuz seviyesi referansla aynı (±%1).
**İstem:** `The exact same character as the references: {Karakter tarifi}. **The character has NO ARMS and no hands visible: both shoulders end cleanly at the shoulder seam under the coat (the arms are separate sprites).** Full body, standing idle, facing right in three-quarter view, weight on both feet, same scale, camera angle and proportions as the body reference, {Stil}, flat solid #00FF00 background, no ground, no shadow.`
**Negatif:** ortak + `arms, hands, fingers, weapon in hand, green clothing, green glow, green rim light, drop shadow on background, ground plane, floor, running pose, different outfit`.
**Kontrol:** ☐ kolsuz (omuz dikişi temiz) ☐ ayak tabanı alttan %6 ☐ referansla boy ±%3 ☐ yeşil kenar yansıması yok ☐ yüz P1 ile aynı kişi ☐ Gunslinger ile yan yana siluet **belirgin farklı** (daha geniş/ağır).
Yürüme kareleri (6) **gerekmez**; ister­sen v1.1 `prompts.md` §C1 kuralı (kare kare, ayna kuralı, `make_strip.py --preview`) aynen geçerli.

## P3 — Kol (isteğe bağlı)

Mevcut `gunslinger_arm.png` tüm karakterlerde kullanılabilir (iki tabanca ateşi sim'de ortak). Yalnız **farklı kol/eldiven** istenirse: v1.1 `prompts.md` §B3'teki kol ölçüsü ve yeşil zemin kuralı (1774×887, tek kol, namlu sağda, omuz pivotu sol-orta) geçerli; eldiven/kol bandı Barutçu paletinde, tabanca aynı model.

## P4 — Başarım ikonları (isteğe bağlı, 22 adet)

**Kullanım:** `data/achievements.json` → ikon (isteğe bağlı `icon`; yoksa yer tutucu eşlemesi, `DESIGN.md` §6.3). Plaka çerçevesini oyun çizer; **ikon yalnız simgedir**.
**Tuval: 512×512** (kare), **düz `#00FF00` zemin**, özne ortada, çevresinde **≥ %12 boşluk**, **tek simge**, çerçeve/rozet/yazı **yok**. **Üretim: simge başına ayrı görsel**, aynı tohum/referans. Okunurluk: küçük (68 px) boyutta tanınmalı — 3 renkten fazla kullanma, ince çizgi yok, kalın kontur.
**Stil (ikon):** `flat-ish game icon, bold dark outline, bone-white and bronze main shapes, one amber accent, readable at 68 px, centered single emblem, no text` (+ ortak negatif + `frame, border, badge, ring, number, letters`).
**Referans:** `assets/ui/icons/*.svg` (çizgi/palet dili), `docs/design/v1.1/mock/pickups/*.svg`.
**Şablon:** `A single bold emblem of {konu}, {ikon stili}, flat solid #00FF00 background, no shadow, centered with 12% margin.`

| # | Kimlik | Konu (`{konu}`) |
|---|---|---|
| 1 | ilk_kan | a single drop of blood on a bone-white skull |
| 2 | beş_dakika | a pocket watch with the hand at five minutes |
| 3 | seviye_10 | a glowing violet crystal with a small "X" notch mark (no letters) |
| 4 | yerleşik | a bronze cartridge standing upright like a monument |
| 5 | tambur_ustası | a revolver cylinder with all chambers loaded |
| 6 | altı_silah | six small slots arranged in a ring, all filled |
| 7 | kırım | a pile of skulls with crossed revolvers |
| 8 | on_dakika | a pocket watch with a cracked glass at ten minutes |
| 9 | seri_ustası | a chain of five linked rings glowing amber |
| 10 | ara_boss_avcısı | a horned bone helmet pierced by a bullet |
| 11 | eklenti_avcısı | a satchel overflowing with small potions and charms |
| 12 | dokunulmaz | an unscratched bone-white shield |
| 13 | seviye_20 | two stacked glowing violet crystals |
| 14 | kalabalık_kesici | a scythe crossed with a revolver over many small skulls |
| 15 | çifte_yol | two crossing paths ending in a single star |
| 16 | on_beş_dakika | an hourglass with ash instead of sand |
| 17 | üç_elit | three horned helmets in a row |
| 18 | ilk_evrim | a bullet transforming into a burning star |
| 19 | skor_100k | a stack of bronze coins with an amber flame |
| 20 | sınırsız_kırım | an infinity loop made of bullets |
| 21 | kale_lordu_devrildi | a broken crown over a fallen castle tower |
| 22 | bomba_ustası | a lit black bomb with a long burning fuse |

Adlar plan fazında değişirse yalnız ilk iki sütun güncellenir; konu cümlesi korunur. **Kontrol:** ☐ 68 px'e küçültünce tanınıyor ☐ tek simge, çerçeve/yazı yok ☐ 22'si aynı kalınlıkta kontur ve aynı palette ☐ yeşil kenar yansıması yok ☐ özne kenardan ≥ %12 içeride.

## Yer tutucu stili (görsel gelene kadar)

Bkz. `DESIGN.md` §6.3 ve `mock/07-yer-tutucu-stili.png`: Gunslinger dosyası + ton kaydırma (sepya %55, ton −18°, doygunluk ×0,75, parlaklık ×0,92); üretimde yazı yok, debug yapıda "YER TUTUCU" etiketi; ikon yoksa `stat` ailesine göre mevcut ikon.
