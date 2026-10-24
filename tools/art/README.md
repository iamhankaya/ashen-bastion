# Sanat işleme hattı (`tools/art/`)

`art/ref/**` (düz yeşil zeminli PNG) -> `assets/gfx/**` + `assets/gfx/manifest.json`.

```
python tools/art/process_art.py [--only <id>] [--preview] [--verify]
python3 -m pytest -q -p no:cacheprovider tools/art/tests      # birim + tests/health
```
Varlık listesi ve hedef boyutlar `art_manifest.json`'dadır. `--preview` kontakt sayfalarını
`tools/art/_preview/` altına yazar (yeşil | #171019 yan yana, commit'lenmez). `--verify` yazmadan çıktıları denetler.

## Algoritma (`chroma_key.py`, `process_art.py`)
1. `d = G - max(R,B)`, `alpha = 1 - clamp((d-30)/(110-30), 0, 1)`. Arka plan d≈125-200, zeytin/yosun d≤~20.
2. Yarı saydam pikselde zemin karışımı çıkarılır (`F=(I-(1-a)B)/a`, B = en yakın kesin zemin pikseli; harabe sayfasında zemin tekdüze değil).
3. Despill: yarı saydam pikseller `G<=min((R+B)/2, max(R,B))`, kenara 2 px içindeki opaklar `G<=max(R,B)+6`. İç bölgeler (bitki) dokunulmaz.
4. 30 px'ten küçük izole lekeler silinir; alpha<=0.5 piksellerin rengi en yakın güvenilir opak pikselden doldurulur.
5. Alpha bbox kırpma, premultiplied LANCZOS (float) küçültme, çıktıda saydam piksel rengi komşudan doldurulur (halo yok).
6. `components` (harabe): 1 px genişletilmiş maske üstünde bağlı bileşen; <1500 px parçalar 60 px içindeki en yakın büyük bileşene eklenir, uzaktakiler atılır. Okuma sırasıyla `ruin_01..` (24 adet). `ruins_manifest.json`: `id`, `file` (`res://...`), `size`, `foot` (normalize; alt %12 şeridin alpha ağırlıklı merkezi), `src_bbox`; scale 0,45.
7. `three_poses` (kargalar): 3 poz kanatları birbirine değmeyen ama bbox'ları iç içe olduğundan bağlı bileşenle ayrılır (yan yana değil, 2 üst + 1 alt), soldan sağa sıralanır; kare başı eşit boyut (192 en), pozlar karede ortalı.
8. Zemin: 1254² -> 768² `wrap_resize` (np.pad wrap + Lanczos, 209 px = tam 128 px çıktı kenarı). Kaynak döşenebilir değil (kenar farkı ort. 14,6/255, tek sütun maks 84). Eşik (ort. <6, tek sütun maks <=40) için `seam_blend`: kenardan 24 px içeride karşı kenarın aynalı piksel karışımı (w=0,5 kenarda -> 0), kenar sütunları birebir eşitlenir. Bedeli: kenar şeritlerinde hafif hayalet/kontrast düşüşü (döşemede 768 px'te bir ağ görünebilir; zemin koyu ve gürültülü olduğundan kabul edildi).

## Bulgular / kararlar
- Kumaş delikleri (palto, pelerin, zırh) yeşil gösteriyordu; küresel anahtar bunları şeffaf yapar (istenen).
- Duman: şövalye ve lord çevresindeki duman yeşille karıştığından anahtar sonrası koyu yeşilimsi opak kalıyordu (halo gibi). `smoke_cleanup` (yalnız bu ikisi): yeşil tonlu koyu (`max<=120, d>=2`) veya alpha<0,9 pikseller aday; aday olmayan opak piksellerin açılması+genişletmesi "çekirdek"; çekirdek dışı adaylar silinir, içindekiler yeşilden arındırılır. Yeşil tonu taşımayan koyu mor/siyah duman parçaları (koyu zırhtan ayırt edilemez) **kalır**: ince, düşük kontrastlı aura olarak bırakıldı; GPUParticles2D duman bunun üstüne eklenir. Lord'un kor/kömür bulutları gövdenin parçası sayıldı.
- İlk deneme (yalnız koyuluk eşiği) gövdeyi de siliyordu; koyuluk tek başına ölçüt yapılmadı.
- Harabe sayfasında yosun/bitki korunur (alpha>=0,95 oranı health testinde kontrol edilir). İki küçük parça (çömlek kırıkları, yan yatmış kazık) ayrı bileşen kaldı.
- Çıktılar #171019 ve yeşil zemin üstünde gözle denetlendi: kenarlarda yeşil halo yok; `G-max(R,B)>40` kalan piksel yok (health testi).

## Testler
- `tests/test_art_units.py`: sentetik fixture (zeytin (95,105,35) korunur, saf yeşil (3,157,8) şeffaf, kenar sızıntısı, boyut/manifest, bileşen, üç poz, wrap-aware küçültme, dikiş harmanlama).
- `tests/health/`: gerçek görseller (yeşil kalıntı, bitki-ton >=%95, harabe 20-30, karga 3 kare, zemin dikişi, hedef boyutlar, commit'li `assets/gfx/manifest.json` taze çıktıyla aynı mı). Ihlal = hata.

## Uygulama ikonu (`make_icons.py`)
`python tools/art/make_icons.py [--preview] [--verify]`: `art/ref/uygulama-ikonu-kaynak.png` (cam çerçeveli) -> çerçevesiz kırpma -> `assets/icon/{main_192x192,foreground_432x432,background_432x432,monochrome_432x432}.png` (+ `--preview`: `docs/dev/icon-preview.png`). Bağlantılar: `export_presets.cfg` `launcher_icons/*`, `project.godot` `config/icon`.
- Katman ayrımı temiz olmadığından tam sanat `background`, `foreground` tamamen saydam. Sanat tuvalin %64'ü (ortadaki 288 px maske penceresine sığar), çevre aynı sanatın bulanık/koyu hâli.
- `monochrome`: kaba elle çizilmiş çokgen silüet (şapkalı karakter) + ay halkası, 264 px güvenli bölgede; beyaz + alfa.
- Testler: `tests/test_icons.py` (boyut/kanal/güvenli bölge/taze çıktı eşitliği).

## Yürüme şeridi (`make_strip.py`, v1.1 D4)
`python tools/art/make_strip.py --sheet <png> [--rows N|y0:y1] [--cells N] [--grid CxR] [--drop-dup-last] --kind player|enemy --stand <png> --out <şerit.png> --manifest <json> [--preview]`
(ya da `--frames a.png b.png ...`). Başlık şeridi/ayırıcı atılır; kareler **ortak ölçekle** (duruş alfa boyu / karelerin ortanca boyu)
ayak çizgisi alt kenarda, yatay hiza gövde üst yarısının ağırlık merkezine göre hizalanır. Oyuncu şeridi N yürüme + 1 duruş hücresi
(indeks N), düşman şeridi yalnız N hücre. Manifest: `frames, cell, scale, display_scale_hint, shoulder_dev (oyuncu), quality{foot_dev_px_1536,
height_dev_pct, width_dev_pct, foot_slide}`. `foot_slide` basan ayağın kare başına `stride/N` geriye gidip gitmediğini ölçer (kapı: ≥N−2 çift ≤3 px).
Kalite kapısı sonuçları ve komutlar: `docs/dev/v1.1-d4/README.md`. Testler: `tests/test_make_strip.py` (sentetik 7 hücreli sayfa).


## Zyfen şeridi (v2.0.2 U2)

`python3 tools/art/make_zyfen_strip.py --src art/source/zyfen --out assets/gfx/char/zyfen_strip.png --body-out assets/gfx/char/zyfen_body.png --manifest art/source/zyfen/strip_manifest.json --quality art/source/zyfen/quality.json [--stride 130] [--align feet|torso] [--walk-cast '<glob>'] [--preview]`

19 hücre (8 yürüme, 1 duruş, 6 cast, 4 gather; `--walk-cast` ile + N). Hücre genişliği tüm klip alfa kutularından hesaplanır
(320 px boy). Yürüme kareleri varsayılan olarak basan ayağa göre hizalanır (`--align feet`; kare başına ≤24 px kaydırma); kapı
`foot_slide` ≥ N-2 çift ≤3 px, klip boy sapması ≤%6, toplam genişlik ≤8192. Kapı kırmızıysa çıkış kodu 1 ve `quality.json`
`pass: false` (sessiz yedek yok; `test_make_zyfen_strip.py` depodaki çıktıyı denetler). `stride`, `zyfen.json` `walk.stride` ile aynı olmalıdır.
Yöntem kb notu: kareler video kareleridir; üretici araç yan görünümde bacak sırasını değiştiremediği için video yöntemi kullanıldı.
