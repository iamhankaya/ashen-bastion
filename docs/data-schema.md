# Veri şeması (sözleşme)

Veri **dosya başına kayıt** biçimindedir (birleşme çakışması yok): `data/characters/<id>.json`,
`data/skills/<id>.json`, `data/enemies/<id>.json`, `data/waves.json` (U2: `data/ruins.json`;
v1.1: `data/pickups.json`, `data/score.json`). Dosya adı = `id`.
Yükleme ve doğrulama: `scripts/sim/game_data.gd` (`GameData`, autoload DEĞİL). Komut satırı:
`godot --headless -s res://tools/validate_data.gd [-- <kök>]` (gate adım 4). `tools/slice.txt = 2` ise "içerik
tamamlandı" kuralları da denetlenir.

```gdscript
var g := GameData.load_default()               # res://data, önbellekli
var g2 := GameData.load_dir("res://test/...")  # başka kök (test fixture'ı)
var errs: PackedStringArray = g.validate()     # boş = geçerli
g.get_character(&"gunslinger") -> CharacterDef; g.get_skill(id) -> SkillDef; g.get_enemy(id) -> EnemyDef
g.character_ids / skill_ids / enemy_ids        # dosya adı sırasında (String sırası)
g.waves                                        # ham waves.json sözlüğü
g.pickup_ids / g.get_pickup(id) -> PickupDef   # v1.1: pickups.json `kinds` DİZİ sırasında (PickupPool.kind_idx bu sıra)
g.pickup_cfg                                   # v1.1: ham pickups.json sözlüğü {spawn, kinds}; dosya yoksa {}
g.score_table -> ScoreTable                    # v1.1: score.json; dosya yoksa varsayılan (puan yok)
```

**Hata biçimi:** her satır `"[kod] bağlam: açıklama"`. Kodlar `GameData.ERROR_CODES`'tadır; her kodun
`test/fixtures/data_bad_<kod>/` bindirme fixture'ı vardır (`behavior_base` hariç: `test_game_data.gd` içinde sınanır).

**Dikkat:** `StringName` sıralaması adres bazlıdır, kararsızdır. Sonuca etki eden sıralamada `String` kullan.

## Karakter — `characters/<id>.json`

| Alan | Tür / aralık | Not |
|---|---|---|
| `id`, `name` | metin | `id` = dosya adı |
| `max_hp` | sayı 1..10000 | |
| `move_speed` | sayı 50..1000 | px/sn |
| `mag_cap` | tamsayı 1..20 | ortak şarjör |
| `reload_time` | sayı 0,35..5 | sn |
| `pickup_radius`, `collision_radius` | sayı 0..1000, 1..200 | |
| `starting_skill` | beceri id | var olan, `kind:active` |
| `range` | sayı 100..2000 | temel menzil (kodda `attack_range`) |
| `rig` | nesne | aşağıda |

`rig`: `body`, `arm` (görsel yolu), `display_height` (1..1000), `native_facing` (`left|right`), `shoulders` (iki `[x,y]`, 0..1),
`arm_pivot`, `muzzle` (`[x,y]`, 0..1), `arm_scale` (0,01..5), `sway`: `hem_from_y` 0..1, `scarf_rect` `[x0,y0,x1,y1]` (0..1, x0<x1, y0<y1),
`amp` 0..100, `lag` 0..1. Omuz/pivot/namlu normalize tahmindir; ekranda ayarlanır.

`rig.walk` (v1.1, isteğe bağlı; `CharacterDef.walk`): kareli yürüme. Anahtarlar `WALK_KEYS`:

| Alan | Tür / aralık | Not |
|---|---|---|
| `frames` | tamsayı: **0** ya da 2..12 | 0 = kare yok, prosedürel yedek (varsayılan). >0 = kare modu |
| `stride` | sayı 20..600 | bir yürüme döngüsünün yer değiştirmesi (px); kare başına ayak kayması = `stride / frames` |
| `strip` | görsel yolu | `frames > 0` ise zorunlu ve var olmalı (`asset_missing`); yatay şerit: `frames` yürüme hücresi + 1 duruş hücresi (indeks `frames`) |
| `cell` | `[w, h]` pozitif tamsayı | `frames > 0` ise zorunlu; şerit hücre boyutu (px) |
| `shoulder_dev` | `[]` ya da `(frames+1)` adet `[dx, dy]` | −0,2..0,2 (display_height kesri); sola bakışta `dx` aynalanır |

## Beceri — `skills/<id>.json`

```json
{"id": "...", "kind": "active|passive|evolution", "name": "...", "icon": "...", "max_level": 5,
 "tags": [], "behavior": "<SkillRegistry anahtarı>", "levels": [{...}], "desc": ["..."],
 "requires": {"active": "...", "active_level": 5, "passive": "...", "passive_min_level": 1}}
```

- `max_level` 1..8 tamsayı; **evrimde 1**. `levels` ve `desc` uzunluğu = `max_level`.
- `behavior`: aktif/evrimde zorunlu, `SkillRegistry.BEHAVIORS`'ta olmalı ve `SkillBehavior`'dan türemeli; **pasifte yok**.
- `requires`: yalnız evrimde (zorunlu). `active` = `kind:active` beceri, `active_level` = o becerinin `max_level`'ı,
  `passive` = `kind:passive` beceri, `passive_min_level` 1..pasifin `max_level`'ı. Her aktifin en çok bir evrimi olur.
- `tags`: metin dizisi. `rhythm` = şarjör ritmiyle etkileşir. **İçerik tamamlandı (slice 2)** modunda `rhythm` etiketli
  **aktif** sayısı ≥ 2 (`rhythm_count`).
- `levels[i]` sayısal değerlerden oluşan nesnedir; **tüm seviyelerde aynı anahtar kümesi** (`levels_keys`).
- **Aktif seviye monotonluğu** (anahtar adına göre): azalmayan `damage, count, radius, pellets, chance, bounces, ex_damage, ex_radius, damage_mult, pierce, push`; artmayan
  `cooldown, interval, every_n`. Diğer anahtarlar serbest sayı.
- **Pasif `levels[i]` o seviyedeki TOPLAM değerdir** (seviye 3 = 3 seviyenin toplamı). Anahtarlar sabit küme (bilinmeyen = `passive_key`):

| Anahtar | Tür | Aralık | Uygulama |
|---|---|---|---|
| `bullet_dmg_mult`, `fire_rate_mult`, `area_mult`, `explosion_dmg_mult`, `move_speed_mult`, `pickup_mult`, `range_mult` | x | -0,9..5 | etkin = `1 + x`, farklı pasifler toplanır |
| `reload_time_mult` | x | -0,9..0 | etkin = `1 + x` (negatif = daha kısa); `Magazine` min 0,35 sn uygular |
| `mag_add` | tamsayı | 0..20 | şarjöre eklenir |
| `max_hp_add` | sayı | 0..1000 | |
| `regen` | sayı | 0..50 | can/sn |

  Monotonluk: |toplam| seviyeyle azalmaz (`reload_time_mult` -0,1, -0,2, … geçerli).
- Görsel yolu (`icon`, `sprite`, `rig.body/arm`): `placeholder:<ad>` ya da var olan dosya (`res://…` ya da `assets/` altında; `.png/.svg/.webp`).

## Düşman — `enemies/<id>.json`

`id, name, hp (1..1e6), speed (0..2000), dmg (temas, 0..1e5), radius (1..500), armor (0..1000), xp (tamsayı 0..1e5),
ai (ground|air|ghost|elite|lord), scales_with_time (bool), sprite, display_height (1..2000), tint ("#rrggbb")`.
Opsiyonel `charge {every, duration, speed}` ve `summon {type, every, count 1..50, [enrage_hp_frac, enrage_speed_mult, enrage_every]}`
(`summon.type` var olan düşman).

**`anim` (v1.1, isteğe bağlı; `EnemyDef.anim`).** Yoksa `{"kind": "none"}`: hareket ve gölge yok. Anahtarlar `ANIM_KEYS`;
`kind` zorunlu, diğerleri isteğe bağlı (yoksa görünüm varsayılanı). Sim `anim`'i kullanmaz; yalnız görünüm okur.

| Alan | Tür / aralık | Not |
|---|---|---|
| `kind` | `crawl\|flap\|float\|stomp\|none` | `bad_kind` |
| `hz` | sayı 0..20 | adım/kanat/yüzme frekansı (Hz) |
| `bob`, `hover` | sayı 0..100, 0..300 | px; `hover` uçan/hayalet türlerde zeminden yükseklik (gölge sabit zeminde) |
| `rot`, `lean`, `hit_rot` | derece 0..15, 0..45, 0..45 | `rot` ≤ 15: sin/cos yaklaşımı bu sınıra dayanır |
| `sq`, `hit_sq` | sayı 0..0,5 | yürüme / vurulma squash oranı |
| `knock` | sayı 0..100 | vurulma itmesi (px) |
| `cycle` | sayı 1..2000 | px; yalnız `crawl` + çok kareli atlasta (mesafe tabanlı kare) |
| `death` | `collapse\|fall\|ash_up\|ash_big\|lord` | `bad_kind` |
| `death_ms` | sayı 50..5000 | ölüm animasyonu süresi |
| `alpha` | `[a, b]`, 0..1 | alfa aralığı (hayalet 0,9–1,0) |

## Eklentiler — `pickups.json` (v1.1, isteğe bağlı)

Dosya yoksa tablo boştur (doğuş yok); "içerik tamamlandı" modunda zorunludur (`missing_file`). Süreler **saniye**
yazılır, sim bunları tam sayı adıma çevirir (`roundi(sn × 60)`). Tür sırası = `kinds` dizi sırası (`GameData.pickup_ids`).

```json
{"spawn": {"first": [30, 45], "interval": [45, 60], "dist": [450, 700], "clearance": 40,
           "life": 25, "blink_last": 5, "collect_radius": 72, "max_alive": 2},
 "kinds": [{"id": "kizil_iksir", "name": "Kızıl İksir", "rarity": "common", "weight": 30,
            "effect": "heal", "amount": 25, "toast": "+25 Can", "icon": "res://assets/ui/icons/pickups/iksir.svg"}]}
```

- `spawn`: `first`, `interval` (min ≤ max; 0..3600 / 1..3600), `dist` (min ≤ max; 1..2000), `clearance` 0..500, `life` 1..600 ve
  `life > blink_last ≥ 0`, `collect_radius` 1..500, `max_alive` tamsayı 1..8 (`PickupPool.CAP`). Aralık hataları `out_of_range`.
- `kinds[i]`: `id` (dosya içinde tekil: `dup_id`), `name` (karışık harf; görüntüde `UiKit.upper_tr`), `rarity`
  `common|uncommon|rare`, `effect` `heal|magnet|buff|bomb` (ikisi de `bad_kind`), `weight` 0..1000, `toast` (metin, boş olabilir),
  `icon` (görsel yolu, `asset_missing`). Ağırlık toplamı > 0 olmalı (**`pickup_weight`**).
- Efekte göre zorunlu alanlar (`missing_field`): `heal` → `amount` 1..10000; `buff` → `buff` (`damage|fire_rate|unlimited`,
  `bad_kind`) + `duration` 0,1..600 + `mult` 1..10 (`unlimited`'ta `mult` yok); `bomb` → `radius` 1..1000, `fuse` 0,1..10,
  `dmg` 0..100000, isteğe bağlı `elite_frac` 0..1, `elite_min` 0..100000. `magnet` ek alan istemez.
- Bilinmeyen anahtar: `unknown_key`.

## Skor — `score.json` (v1.1, isteğe bağlı)

Dosya yoksa varsayılan tablo (puan yok); "içerik tamamlandı" modunda zorunludur ve **her düşman** için `kill_points` kaydı gerekir.

```json
{"kill_points": {"curumus_piyade": 10, "kale_lordu": 10000},
 "streak": {"window": 3.0, "tiers": [[0, 1], [10, 2], [25, 3], [50, 4], [100, 5]]},
 "evolution_bonus": 2000, "survival_per_sec": 5, "lord_bonus": 25000, "display_cap": 99999999}
```

- `kill_points`: anahtar = var olan düşman id'si (`unknown_enemy`), değer tamsayı ≥ 0.
- `streak.window` 0,5..30 sn (sim: `ScoreTable.window_steps`). `streak.tiers`: `[min_seri, çarpan]` tamsayı çiftleri; ilk eleman `[0, 1]`,
  eşikler ve çarpanlar **kesin artan** (**`score_tiers`**).
- `evolution_bonus`, `survival_per_sec`, `lord_bonus`: tamsayı 0..1.000.000. `display_cap`: tamsayı 1..99.999.999 (yalnız UI ve kayıt).

## Dalgalar — `waves.json`

```json
{"end_time": 1200,
 "rows": [
  {"kind": "rate",  "type": "...", "from": 0, "to": 1200, "rate": [0.8, 3.5]},
  {"kind": "group", "type": "...", "from": 90, "to": 1200, "group": [6, 14], "every": [26, 12]},
  {"kind": "burst", "type": "...", "at": 480, "count": 50, "ring": true},
  {"kind": "boss",  "type": "...", "at": 300, "warn": 5}],
 "after_lord": {"piyade_rate_mult": 0.5, "karga_stop": true}}
```

- `end_time` opsiyonel (varsayılan 1200). Üst düzey anahtarlar yalnız `rows, after_lord, end_time`.
- `rate`/`group`/`burst` türü `ground|air|ghost` düşman olmalı; `boss` türü `elite|lord`.
- `rate` ve `group`: `from < to` (0..`end_time`); `[a, b]` = aralık başındaki ve sonundaki değer (doğrusal). `rate` için `a <= b`,
  `group` için `a <= b` (1..400); `every` her iki değer 0,1..600 (azalabilir).
- `burst`: `count` tamsayı 1..400, `ring` bool. `boss`: `at >= warn` (varsayılan 5 sn); `lord` için `at == end_time`, elit için `at < end_time`.
- `after_lord` anahtarları yalnız `piyade_rate_mult` (0..1) ve `karga_stop` (bool).

## Kapsam dışı (sözleşmede değil)

Beklenen kayıt sayıları (8 aktif + 8 pasif + 4 evrim, 7 düşman) şemada değil, kabul testindedir. Sayı dengesi `data/**`
kayıtlarının sahibi görevlerdedir; ayar yalnız denge görevinde yapılır.

## Harabeler — `ruins.json` (isteğe bağlı)

Dizi; her kayıt: `id` (benzersiz), `sprite` (`res://assets/gfx/map/ruins/*.png` ya da `placeholder:`), `display_scale`
(0,1..20), `foot` `[x, y]` (0..1, sprite'ta ayak noktası), `footprint {w, h}` (görsel taban izi ölçüsü), `weight`
(chunk içi seçim ağırlığı), `solid` (bool: oyuncuyu ve yer düşmanlarını iter; mermiler her zaman geçer) ve katı
kayıtlarda `collision` `[{x, y, r}, …]` (1..32 daire; `foot` noktasına göre dünya px; sprite'ın taban izini kaplayan
daire zinciri; yoksa foot'ta `footprint.w/2` yarıçaplı tek daire). Sarmalayan çember ≤ 400 px. `collision`'ı elle
düzenlemeyin: `python3 tools/art/ruin_collision.py` (kural: görsel yüksekliği ≥ 240 px olan yapı katıdır, alçak
parçalar dekordur; bkz. `docs/dev/ruins.md`). Dosya yoksa harita
boştur. Doğrulama: `scripts/sim/ruins_validator.gd`; sprite ve ölçüler `tools/art/process_art.py` çıktısından
(`assets/gfx/map/ruins_manifest.json`) üretilir.
