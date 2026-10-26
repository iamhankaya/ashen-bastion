# Yeni karakter ekleme (tek parça gövde)

Yeni karakter **tek parça gövde** yöntemiyle eklenir (karar 2026-10-26): her animasyon karesi tüm karakteri içerir, kol/namlu/omuz düzeneği yoktur
(`rig.armless: true`). Kod değişmez; karakter, `data/characters/<id>.json` dosyası eklenince seçim altyapısı (`CharacterRoster`), vitrin
ekranı (`CharactersScreen`), seviye atlama başlığı ve koşu (`GameSim.new(seed, id, …)`) tarafından otomatik tanınır. Örnek: `zyfen`.

Adım adım iş akışı repo skill'lerindedir: `.claude/skills/ab-karakter-ekle/SKILL.md` (üst akış), `ab-animasyon-seridi` (kareler ve şerit),
`ab-gorsel-ikon-uret` (portre/ikon), `ab-beceri-ekle`, `ab-ses-ekle`, `ab-basarim-ekle`, `ab-denge-olcumu`. Bu belge veri ve doğrulama başvurusudur.

> **İstisna:** Gunslinger parçalı rig'dir (kolsuz gövde + kol; `rig.armless` yok). Yeni karakter için parçalı rig kullanılmaz; Gunslinger'ın
> kodu ve görselleri bu akışta değişmez.

## JSON alanları

Dosya adı = `id` (`data/characters/<id>.json`). Tam şema ve doğrulama kodları: `docs/data-schema.md` "Karakter".

| Alan | Zorunlu | Açıklama |
|---|---|---|
| `id`, `name` | evet | `id` dosya adıyla aynı; `name` ekranda gösterilir (`UiKit.upper_tr` ile büyütülür) |
| `max_hp`, `move_speed`, `mag_cap`, `reload_time`, `pickup_radius`, `collision_radius`, `range` | evet | vitrin panelinde CAN · HIZ · ŞARJÖR · DOLDURMA · MENZİL · TOPLAMA olarak görünür |
| `starting_skill` | evet | var olan `kind: active` beceri id'si (ör. `ruzgar_kesigi`); becerinin `pool`u karakterin kimliği ya da `common` olmalı (`requires_ref`) |
| `rig` | evet | koşu içi görünüm; bkz. "Rig" |
| `portrait` | hayır (önerilir) | vitrin ve seviye atlama portresi, 1024×1536; yoksa yer tutucu portre / portresiz düzen |
| `blurb` | hayır | vitrin açıklaması, ≤ 120 karakter |
| `unlock` | hayır | `{"achievement": "<başarım id>"}`: o başarım açılana dek karakter kilitli |
| `placeholder` | hayır | `true` ise debug yapıda vitrinde "YER TUTUCU" etiketi çıkar |
| `display_upper` | hayır | büyük harfli ad; `i` içeren özel adlarda noktalı İ'yi önler |
| `order` | hayır | vitrin sırası (küçük önce); yoksa dosya adı sırasıyla sona |
| `sfx` | hayır | olay → ses kimliği sözlüğü (`shot`, `hit`, `reload_start`, `reload_end`, `dry`); anahtarı olmayan olay sessiz kalır |

`base_gun` yoktur (`unknown_key`). Karakterleri `starting_skill` ve sayılar ayırır. Varsayılan karakter (`gunslinger`) sıradan bağımsızdır.

## Rig (tek parça gövde)

```
"rig": {
  "body": "res://assets/gfx/char/<id>_body.png", "armless": true, "display_height": 200, "native_facing": "right",
  "cast_point": [fx, fy], "action_while_moving": false,
  "sway": {"hem_from_y": …, "scarf_rect": […], "amp": …, "lag": …},
  "walk": {"frames": 8, "stride": 130, "strip": "res://assets/gfx/char/<id>_strip.png", "cell": [w, 320], "shoulder_dev": []},
  "cast": {"frames": 6, "fire_frame": 3, "fps": 24},
  "gather": {"frames": 4}
}
```

- `arm`, `arm_pivot`, `muzzle`, `shoulders`, `arm_scale` **yazılmaz** (kolsuz rig).
- **Şerit:** tek yatay PNG; hücre sırası yürüme, duruş, cast, gather (+ isteğe bağlı `walk_cast`) (`scripts/sim/rig_frames.gd`). Hücre yüksekliği 320 px,
  genişlik = en geniş alfa kutusu + 2·PAD (hesaplanır), toplam ≤ 8192 px. Zyfen: 19 hücre, 5700×320.
- **`cast_point`:** atış, beceri ve avuç efektinin çıkış noktası (gövde merkezine göre kesir; sola bakışta x aynalanır). Cast karesindeki avuç
  pikselinden ölçülür (`--palm-px`); manifest `palm` ile fark ≤ 0,03.
- Şerit, duruş gövdesi, manifest ve kalite dosyası aynı araçtan çıkar:
  `python3 tools/art/make_zyfen_strip.py --src art/source/<id> …` (komut ve parametreler: `tools/art/README.md`, adımlar: `ab-animasyon-seridi`).

## Görsel hazırlama

Görseller (portre, duruş, ikon) kullanıcının makinesinde Codex ile üretilir ve repoya girmeden kullanıcıya gösterilir; onaydan sonra eklenir
(`ab-gorsel-ikon-uret`, istem şablonları `docs/design/v2.0/prompts.md`). Yürüme/cast/gather kareleri ise **video → ffmpeg kare → yeşil silme →
şerit** hattından gelir (`ab-animasyon-seridi`); görsel üreticiyle kare kare çizilen yürüme döngüsü kullanılmaz.

1. **Portre (P1)** — `assets/gfx/char/<id>_portrait.png`, 1024×1536 PNG, tam sahneli (yeşil zemin yok). Yüz üst üçte birde, alt %40 önemsiz,
   önemli her şey x %12–88 ve y %6–62 içinde, kenarlarda boşluk yok.
2. **Duruş + kareler** — `art/source/<id>/<id>_idle.png` (şeffaf, 1024×1536) ve `art/source/<id>/frames/{walk,cast,gather}/*.png`.
3. Godot'a tanıtmak için `godot --headless --import` çalıştırın ve oluşan `.import` dosyalarını commit'leyin.

**Görsel yokken (yer tutucu):** `python tools/art/make_placeholder.py <kaynak.png> <hedef.png>` mevcut bir görselin tonunu
kaydırarak PNG üretir. `placeholder: true` yazın. Yer tutucu yalnız portre/vitrin içindir; kolsuz rig için gerçek şerit gerekir.

## Doğrulama (`bash tools/gate.sh`)

```
bash tools/gate.sh
```

Gate, veri doğrulamasını (`validate_data`: bozuk alan → hata kodu, dosya ve alan adıyla), karakter kabul testlerini (her karakter 15 adım koşar,
başlangıç becerisi `kind: active`) ve her kolsuz karakter için şerit testlerini (`test/acceptance/test_acc_v202_rig_manifest.gd`,
`test_acc_v202_rig_walk_gate.gd`: manifest ↔ rig, `palm` ↔ `cast_point`, yürüme kalite kapısı, CastAnim kare seçimi) koşar. Bu testler
`art/source/<id>/` çıktılarını kimliğe göre kendiliğinden bulur; yeni karaktere özel test yazılmaz. Dilim `R` kapalıyken pending döner; yerelde
`V202_SLICES_FORCE=R` ile zorlanır. Yürüme kapısı kırmızıysa yalnız `docs/design/walk-waiver-<id>.md` (tarih, kullanıcı onayı, ölçüm, gerekçe) geçirir.

## Vitrine düşme

Hiçbir kayıt dosyası değişmez:

- `data/characters/<id>.json` eklendiği anda **Karakterler ekranında** kart olarak görünür (sıra: `order`, eşitlikte dosya adı; 3'ten fazlada
  kart şeridi yatay kaydırılır), ana menüdeki KARAKTERLER alt satırı ve sürüm etiketi seçili karakterin adını gösterir.
- SEÇ → `Settings.character_id` kaydedilir; **OYNA** o karakterle başlar; **seviye atlama** başlığı `name` alanını, arka planı `portrait`'i kullanır.
- `unlock` varsa kart gri + kilit rozetli görünür, SEÇ "KİLİTLİ" olur ve nedeni yazılır; başarım kaydı okunamazsa kilitli sayılır (güvenli yön).
- Hiç portre yoksa vitrin varsayılan portreyi, seviye atlama portresiz bordo zemini kullanır; çökme olmaz.

Kontrol: `tools/capture/shots.gd` ile `chars`, `chars_b`, `chars_lock`, `levelup_b` senaryoları ve `tools/capture/shots_zyfen.gd` örneği (duruş, yürüme, cast, gather, aynalama).

## Yer tutucudan gerçeğe geçiş

1. Gerçek PNG'leri aynı dosya adlarıyla `assets/gfx/char/`'a koyun (yeniden `--import`; `.import` dosyaları commit'lenir).
2. JSON'da `placeholder` alanını silin (ya da `false`); `blurb`, `name`, sayılar ve `starting_skill`'i gerçek tasarıma göre güncelleyin.
3. Şeridi `ab-animasyon-seridi` ile üretip `rig.walk/cast/gather/cast_point` değerlerini manifestten yazın.
4. `bash tools/gate.sh` yeşil; cihazda vitrin ve seviye atlama ekran görüntüsü kontrolü (kendi bölüm dosyanız `docs/dev/user-verify/`).
5. Denge (sayılar) kullanıcı kararıdır; `ab-denge-olcumu` ile Gunslinger ±%5 kanıtı ve karakterin DPS bandı raporlanır.
