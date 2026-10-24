# Yeni karakter ekleme (v2.0)

Yeni karakter **yalnız veri + görsel ekleyerek** tanımlanır; kod değişmez. Karakter, `data/characters/<id>.json` dosyası
eklenince seçim altyapısı (`CharacterRoster`), vitrin ekranı (`CharactersScreen`), seviye atlama başlığı ve koşu
(`GameSim.new(seed, id, …)`) tarafından otomatik tanınır. Bu belge `zyfen` örneğiyle yazılmıştır.

## JSON alanları

Dosya adı = `id` (`data/characters/<id>.json`). Tam şema ve doğrulama kodları: `docs/data-schema.md` "Karakter".

| Alan | Zorunlu | Açıklama |
|---|---|---|
| `id`, `name` | evet | `id` dosya adıyla aynı; `name` ekranda gösterilir (`UiKit.upper_tr` ile büyütülür) |
| `max_hp`, `move_speed`, `mag_cap`, `reload_time`, `pickup_radius`, `collision_radius`, `range` | evet | vitrin panelinde CAN · HIZ · ŞARJÖR · DOLDURMA · MENZİL · TOPLAMA olarak görünür |
| `starting_skill` | evet | var olan `kind: active` beceri id'si (ör. `cift_tabanca`); becerinin `pool`u karakterin kimliği ya da `common` olmalı (`requires_ref`) |
| `rig` | evet | koşu içi sprite; bkz. "Rig ayarı" |
| `portrait` | hayır (önerilir) | vitrin ve seviye atlama portresi, 1024×1536; yoksa yer tutucu portre / portresiz düzen |
| `blurb` | hayır | vitrin açıklaması, ≤ 120 karakter |
| `unlock` | hayır | `{"achievement": "<başarım id>"}`: o başarım açılana dek karakter kilitli (vitrinde "<ad> başarımını aç") |
| `placeholder` | hayır | `true` ise debug yapıda vitrinde "YER TUTUCU" etiketi çıkar; release'te kart/sahne portresi soğuk tonlanır ve baş harf monogramı biner |
| `display_upper` | hayır | büyük harfli ad (ör. `GUNSLINGER`); `i` içeren özel adlarda noktalı İ'yi önler |
| `order` | hayır | vitrin sırası (küçük önce); yoksa dosya adı sırasıyla sona |

`base_gun` yoktur (`unknown_key`). İki tabanca ateşi tüm karakterlerde ortaktır; karakterleri `starting_skill` ve sayılar ayırır.
Sıra `order` alanıdır (eşitlikte dosya adı sırası); varsayılan karakter (`gunslinger`) sıradan bağımsızdır.

## Görsel hazırlama

Gereksinimler (ölçüler ve kompozisyon kuralları: `docs/design/v2.0/DESIGN.md` §6.2, AI istemleri `docs/design/v2.0/prompts.md` P1–P3):

1. **Portre (P1)** — `assets/gfx/char/<id>_portrait.png`, 1024×1536 PNG, tam sahneli (yeşil zemin yok). Yüz üst üçte birde,
   alt %40 önemsiz, önemli her şey x %12–88 ve y %6–62 içinde, kenarlarda boşluk yok (vitrin nefes/sürüklenme kenar göstermemeli).
2. **Kolsuz gövde (P2)** — düz `#00FF00` zeminli kaynak `art/ref/<id>-govde.png`; `tools/art/art_manifest.json`'a
   `{"id": "<id>_body", "kind": "sprite", "src": …, "out": "assets/gfx/char/<id>_body.png", "max_side": 320}` satırı eklenir ve
   `python tools/art/process_art.py --only <id>_body` çalıştırılır (`--preview` ile yeşil/koyu zemin üstünde bakılır).
3. **Kol (P3)** — isteğe bağlı; yoksa `gunslinger_arm.png` yeniden kullanılır (`rig.arm`).
4. Yürüme kareleri gerekmez (`rig.walk.frames: 0` = prosedürel yedek). İstenirse v1.1 kare kuralı geçerlidir
   (`tools/art/make_strip.py --preview` ile bağlamadan önce ölç).
5. Godot'a tanıtmak için `godot --headless --import` çalıştırın ve oluşan `.import` dosyalarını commit'leyin.

**Görsel yokken (yer tutucu):** `python tools/art/make_placeholder.py <kaynak.png> <hedef.png>` mevcut bir görselin tonunu
kaydırarak PNG üretir (çalışma zamanında shader yoktur). `placeholder: true` yazın.

## Rig ayarı

`rig` içindeki oranlar normalize (0..1) tahmindir; **ekranda ayarlanır**: `display_height` (sprite boyu, px), `native_facing`,
`shoulders` (iki omuz noktası), `arm_pivot` (kol dönüş noktası), `muzzle` (namlu ucu; kol kutusunun içinde olmalı),
`arm_scale`, `sway` (etek/eşarp salınımı). Yeni gövdeyi `gunslinger` rig'iyle başlayıp koşuda (`tools/capture/shots.gd game`)
bakarak düzeltin. Şema sınırları `docs/data-schema.md` "rig"'dedir; sınır dışı değer `bash tools/gate.sh`'te
`validate_data` adımında hata verir.

## Doğrulama (`bash tools/gate.sh`)

```
bash tools/gate.sh
```

Gate, veri doğrulamasını (`validate_data`: bozuk alan → hata kodu), karakter kabul testlerini (her karakter 15 adım koşar,
değişmezler boş, namlu noktası kol kutusunda, başlangıç becerisi `kind: active`) ve v1/v1.1/v2.0 paketini koşar.
Yeni karaktere özel kod ya da test yazılmaz; karakter dosyası gate'te otomatik taranır. Yeşil değilse hata satırı dosya ve alanı söyler.

## Vitrine düşme

Hiçbir kayıt dosyası değişmez:

- `data/characters/<id>.json` eklendiği anda **Karakterler ekranında** kart olarak görünür (sıra: dosya adı sırası; 3'ten fazlada
  kart şeridi yatay kaydırılır), ana menüdeki KARAKTERLER alt satırı ve sürüm etiketi seçili karakterin adını gösterir.
- SEÇ → `Settings.character_id` kaydedilir; **OYNA** o karakterle başlar; **seviye atlama** başlığı `name` alanını, arka planı `portrait`'i kullanır.
- `unlock` varsa kart gri + kilit rozetli görünür, SEÇ "KİLİTLİ" olur ve nedeni (`"<başarım adı> başarımını aç"`) yazılır;
  başarım kaydı okunamazsa kilitli sayılır (güvenli yön).
- Hiç portre yoksa vitrin varsayılan portreyi, seviye atlama portresiz bordo zemini kullanır; çökme olmaz.

Kontrol: `tools/capture/shots.gd` ile `chars`, `chars_b`, `chars_lock`, `levelup_b` senaryoları (masaüstü render).

## Yer tutucudan gerçeğe geçiş

1. Gerçek PNG'leri aynı dosya adlarıyla (`<id>_portrait.png`, `<id>_body.png`, isteğe bağlı `<id>_arm.png`) `assets/gfx/char/`'a koyun
   (yeniden `--import`; `.import` dosyaları commit'lenir).
2. JSON'da `placeholder` alanını silin (ya da `false`); `blurb`, `name`, sayılar ve `starting_skill`'i gerçek tasarıma göre güncelleyin.
3. `rig` oranlarını gerçek gövdeye göre ayarlayın (omuz/pivot/namlu).
4. `bash tools/gate.sh` yeşil; cihazda vitrin ve seviye atlama ekran görüntüsü kontrolü (`docs/dev/user-verify.md` ### K).
5. Denge (sayılar) kullanıcı kararıdır; yer tutucu sayılar yalnız altyapıyı sınar.
