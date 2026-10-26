# Veri şeması (sözleşme)

Veri **dosya başına kayıt** biçimindedir (birleşme çakışması yok): `data/characters/<id>.json`,
`data/skills/<id>.json`, `data/enemies/<id>.json`, `data/waves.json` (U2: `data/ruins.json`;
v1.1: `data/pickups.json`, `data/score.json`; v2.0: `data/achievements.json`). Dosya adı = `id`.
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
g.achievement_ids / g.achievements             # v2.0: achievements.json, dosya sırasında (AchievementDef); dosya yoksa boş
g.get_achievement(id) -> AchievementDef        # null olabilir
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
| `blurb` | metin ≤ 120 karakter, isteğe bağlı (v2.0) | vitrin açıklaması (`out_of_range`) |
| `portrait` | görsel yolu, isteğe bağlı (v2.0) | vitrin ve seviye atlama portresi; var olmalı (`asset_missing`); yoksa portresiz düzen |
| `unlock` | `{"achievement": "<id>"}`, isteğe bağlı (v2.0) | karakter bu başarım açılana dek kilitli; yoksa açık. Başarım var olmalı (`unknown_ref`); başka anahtar `unknown_key` |
| `placeholder` | bool, isteğe bağlı (v2.0) | `true` = görsel yer tutucu; yalnız debug yapıda "YER TUTUCU" etiketi. Release'te de kartta/sahnede soğuk ton + baş harf monogramı gösterilir |
| `display_upper` | metin ≤ 22 karakter, isteğe bağlı (v2.0 düzeltme) | büyük harfli ad; özel adlarda `upper_tr` noktalı İ üretir ("GUNSLİNGER"), boşsa `upper_tr(name)` |
| `order` | sayı, isteğe bağlı (v2.0 düzeltme) | vitrin sırası (küçük önce; eşitlikte dosya adı sırası); yoksa 1000 |
| `sfx` | nesne, isteğe bağlı (v2.0.2 A4) | olay -> ses: anahtarlar `shot`, `hit`, `reload_start`, `reload_end`, `dry` (başkası `unknown_key`); değer ses kimliği ya da kimlik dizisi (`shot` dizisi silah indeksiyle seçilir). Kimlik `assets/audio/sfx/<id>.ogg` ya da `<id>_1.ogg` varyasyonu olarak var olmalı (`asset_missing`). Sözlük VARSA anahtarı olmayan olay sessizdir (Gunslinger'a özgü sesler Zyfen'de çalmaz); sözlük YOKSA eski varsayılan sesler |

`base_gun` v2.0'da YOKTUR (JSON'da görülürse `unknown_key`). Yeni karakter yalnız veri + görsel ekleyerek tanımlanır;
sıra `order` alanıdır, eşitlikte dosya adı sırası (`character_ids`).

`rig`: `body`, `arm` (görsel yolu), `display_height` (1..1000), `native_facing` (`left|right`), `shoulders` (iki `[x,y]`, 0..1),
`arm_pivot`, `muzzle` (`[x,y]`, 0..1), `arm_scale` (0,01..5), `sway`: `hem_from_y` 0..1, `scarf_rect` `[x0,y0,x1,y1]` (0..1, x0<x1, y0<y1),
`amp` 0..100, `lag` 0..1. Omuz/pivot/namlu normalize tahmindir; ekranda ayarlanır.

`rig.armless` (v2.0.2, isteğe bağlı bool; `DataV202Rig`): `true` = tek parça gövde, kol düzeneği yok. `arm, arm_pivot, muzzle, shoulders,
arm_scale` zorunlu değildir, verilirse yok sayılır. Kolsuz rigde ek alanlar (kollu rigde bunlar `unknown_key`):

| Alan | Tür / aralık | Not |
|---|---|---|
| `cast_point` | `[fx, fy]`, ±0,5 | **zorunlu**. Atış (el) noktası: `display_height` kesri, gövde kutusu merkezine göre, +x = bakılan yön, +y aşağı (`PlayerRig.cast_point_world`; aynalamada x işareti tersine). Başlangıç değeri tahmindir, cast karesinde ölçülür |
| `action_while_moving` | bool, varsayılan `false` | cast/gather kareleri hareket ederken de mi gösterilir (yalnız görünüm; sim/hash'e girmez) |
| `cast` | `{frames 2..8, fire_frame 0..frames-1, fps 8..60}` | savuruş kareleri; bozuk = `out_of_range`/`missing_field`/`unknown_key` |
| `gather` | `{frames 2..8}` | rüzgar toplama (doldurma) kareleri |
| `walk_cast` | `cast` ile aynı şema | yürürken savuruş kareleri (isteğe bağlı üçüncü küme) |

`cast`/`gather`/`walk_cast` varsa `walk.strip` ve `walk.cell` zorunludur (`walk.frames` 0 olabilir: yürüme prosedürel, kümeler yine geçerli).
Hücre sırası (`RigFrames`): yürüme `0..W-1`, duruş `W`, cast, gather, walk_cast; toplam `W+1+C+G+WC`. Kabul: toplam hücre × hücre genişliği
≤ 8192 (`out_of_range`); şerit dokusu varsa boyutu `toplam × w` × `h` olmalı (`bad_type`).

**Manifest `palm` ↔ `cast_point` (v2.0.2):** `strip_manifest.json` `palm: {fire_frame, point:[fx, fy]}` atış karesindeki (`cast.fire_frame`) avucun
`cast_point` ile AYNI uzaydaki karşılığıdır. `--palm-px X,Y` kaynak kare görselindeki (kırpılmamış) avuç pikselidir; dönüşüm
(`make_zyfen_strip.palm_to_cast_point`): hücre px = (palm − karenin alfa kutusu başı) × klip ölçeği + karenin hücredeki yeri (x = hücre içi
konum, kare alt kenara oturur: üst = 320 − kare boyu); `fx = (hücre_x − hücre_genişliği/2) / 320`, `fy = (hücre_y − 160) / 320`
(hücre 320 px = `display_height`, hücre merkezi = gövde merkezi; `native_facing: left` ise `fx` işareti çevrilir). Gate testi
`|palm − cast_point| ≤ 0,03` (≈ 6 dünya px) bekler; `cast_point` değeri değişirse `--palm-px` yeniden ölçülür.

Şerit, gövde görseli, manifest ve kalite raporu `tools/art/make_zyfen_strip.py` ile üretilir (hücre genişliği girdiden hesaplanır, `walk.cell`
buraya yazılır; kapı: `foot_slide`, klip yükseklik sapması, toplam genişlik;
bkz. `tools/art/README.md`). Çıktı kalite raporu `art/source/zyfen/quality.json` yürüme kalite kapısı testinin girdisidir.

`rig.walk` (v1.1, isteğe bağlı; `CharacterDef.walk`): kareli yürüme. Anahtarlar `WALK_KEYS`:

| Alan | Tür / aralık | Not |
|---|---|---|
| `frames` | tamsayı: **0** ya da 2..12 | 0 = kare yok, prosedürel yedek (varsayılan). >0 = kare modu |
| `stride` | sayı 20..600 | bir yürüme döngüsünün yer değiştirmesi (px); kare başına ayak kayması = `stride / frames` |
| `strip` | görsel yolu | `frames > 0` ise zorunlu ve var olmalı (`asset_missing`); yatay şerit: `frames` yürüme hücresi + 1 duruş hücresi (indeks `frames`) |
| `cell` | `[w, h]` pozitif tamsayı | `frames > 0` ise zorunlu; şerit hücre boyutu (px) |
| `shoulder_dev` | `[]` ya da `(frames+1)` adet `[dx, dy]` | −0,2..0,2 (display_height kesri); sola bakışta `dx` aynalanır |

## Başarım — `achievements.json` (v2.0, isteğe bağlı)

Kök dizi; her kayıt `AchievementDef` (`scripts/sim/achievement_def.gd`). Doğrulama: `scripts/sim/data_v2.gd`.

| Alan | Tür / aralık | Not |
|---|---|---|
| `id` | `[a-z0-9_]{1,40}` | tekil (`dup_id`); ASCII |
| `name` | metin ≤ 22 karakter | `out_of_range` |
| `desc` | metin ≤ 60 karakter | iki satır sınırı |
| `stat` | kapalı küme `AchievementDef.STATS` (21 ad; v2.0.3: `total_boss_kills` sona eklendi) | bilinmeyen = `unknown_stat` |
| `target` | tamsayı 1..999 999 999 | |
| `scope` | `run` \| `total` | `stat`'ın kapsamıyla AYNI olmalı (`scope_mismatch`); `total_*` = koşular arası, gerisi tek koşu |
| `tier` | `kolay` \| `orta` \| `zor` \| `cok_zor` | ASCII |
| `icon` | görsel yolu, isteğe bağlı | var olmalı (`asset_missing`); yoksa stat ailesine göre mevcut ikon |

Bilinmeyen anahtar `unknown_key`. "İçerik tamamlandı" modunda dosya zorunlu (`missing_file`), kayıt (aile) adedi 12..30 (`ach_count`; v2.0.3, eskiden 15..25),
eski şemada her zorlukta en az bir kayıt (`tier_missing`; aile kayıtları varsa aranmaz). Kayıt dosyası şeması (`user://achievements.json`) belge değil kod
sözleşmesidir: `docs/plan/v2.0-plan.md` "Kayıt dosyası".

Aşamalı (aile/kademe) şema için aşağıdaki "Başarım — aile/kademe (v2.0.3)" bölümüne bak.

**Atlas sınırı (F-013):** düşman sayısı 16'yı aşarsa `atlas_cells` hatası (shader `cell_rect[16]`).

Yeni hata kodları (v2.0): `unknown_stat`, `ach_count`, `tier_missing`, `scope_mismatch`, `atlas_cells`, `unknown_ref`
(her birinin `test/fixtures/data_bad_<kod>/` fixture'ı vardır). Karakter v2.0 alanı bindirmeleri
`test/fixtures/char_bad_<durum>/` altındadır (`blurb_long`, `portrait_missing`, `unlock_unknown`, `unlock_key`,
`placeholder_type`, `base_gun`); `tools/ci/gen_data_fixtures.py` hepsini üretir.

## Başarım — aile/kademe (v2.0.3)

SÖZLEŞME (T20261026-59). Bir kayıt = bir **aile**; `steps` ile 1..5 kademe taşır. `steps` yoksa kayıt v2.0 biçimindedir
(`target` + `tier` = tek kademe, `AchievementDef.thresholds()` `[target]` döner); iki biçim aynı dosyada birlikte durabilir,
böylece C fazı veriyi aileye bölerken oyun her an çalışır. Uygulama: `scripts/sim/achievement_def.gd`, doğrulama
`scripts/sim/data_v2.gd` (`_validate_family`).

| Alan | Tür / aralık | Not |
|---|---|---|
| `id`, `name` ≤ 22, `desc` ≤ 60, `stat`, `scope`, `icon` | v2.0 ile aynı | `id` aile kimliği (ör. `reaper`); `unlock.achievement` = aile, "kademe ≥ 1" |
| `steps` | 1..5 elemanlı, kesin artan tamsayı dizisi (her biri 1..999 999 999) | aile kaydını belirler; dizi boş/artmayan/5'ten uzunsa `steps_invalid` |
| `group` | `THE WATCH` \| `THE CULLING` \| `THE CROWNED` \| `THE ARMORY` \| `THE ROAD` | aile kaydında zorunlu (`missing_field`/`bad_type`); sabit büyük harf, `upper_tr` kullanılmaz |
| `legacy` | `{eski_kimlik: kademe}`, isteğe bağlı | anahtar `AchievementDef.LEGACY_IDS`'ten (22 eski kimlik), değer 1..`steps` uzunluğu; aksi `legacy_unknown`; bir eski kimlik tek ailede geçer |
| `target`, `tier` | — | `steps` varken YASAK (`steps_invalid`); `group`/`legacy` de `steps` olmadan yasak |

Dosya düzeyi (tamamlandı modu): aile adedi 12..30 (`ach_count`), toplam kademe ≤ 80 (`steps_invalid`; eski biçimli kayıt 1 sayılır).
Yeni stat yalnız `total_boss_kills` (indeks 20; tracker sabiti `S_TOTAL_BOSS_KILLS`). **Sayacı besleme (elit tür ölümünde
`add_total`) ve depo alanı C fazının işidir; şu an bu stat'ı kullanan kayıt yoktur.**

Yeni hata kodları: `steps_invalid`, `legacy_unknown` (fixture: `test/fixtures/data_bad_steps_invalid/`, `data_bad_legacy_unknown/`).

### Kayıt göçü (imza)

`user://achievements.json` v1 -> v2 (`AchievementStore.VERSION_V2`). Sözleşme yalnız imzaları koyar; okuma/yazma `VERSION = 1` ile
sürer ve C fazı geçişi yapar:

- `StoreIo.read_versioned_any(path, versions: PackedInt32Array)`: listedeki her `v` kabul; sonuca `version` eklenir; başka `v` bozuk (`.bad`).
  `read_versioned(path, version)` aynen korunur.
- `AchievementStore.migrate_v1(raw: Dictionary, defs: Array) -> Dictionary`: saf, idempotent, girdiyi değiştirmez. Şu an girdinin kopyasını döner
  (taslak); C gövdeyi doldurur. Yedek: ilk v2 yazımından önce `<yol>.v1.bak` (`BACKUP_SUFFIX`).
- DEĞİŞMEMESİ gerekenler: bu üç imza, `VERSION_V2 = 2`, `BACKUP_SUFFIX`, `MAX_UNLOCKED = 64`, 256 KB sınırı, `COUNTER_CAP`.

### C fazı notları

(C fazı doldurur: eşik tablosu, göç kuralları, ekran davranışı. Bu bölüm dışındaki satırlara dokunmaz.)

## Karakter ve ayar alanları (v2.0.3)

| Alan | Tür / aralık | Not |
|---|---|---|
| `characters/<id>.json` `portrait_video` | `.ogv` yolu (`res://assets/video/portrait/<id>.ogv` ya da `placeholder:…`), isteğe bağlı | hareketli portre (yalnız karakter seçim ekranı); `.ogv` değilse `bad_type`, dosya yoksa `asset_missing`. Alan yoksa/yüklenemezse statik `portrait` (fixture: `test/fixtures/char_bad_portrait_video_missing/`) |
| `user://settings.cfg` `hareket_azalt` | bool, varsayılan `false` | `Settings.hareket_azalt`; açıkken dekoratif hareket durur (hareketli portre, küre süzülmesi, ana sayfa kül/kor/meşale/sancak). Eski dosyada anahtar yoksa `false`. Ekran girişi (220 ms) kalır |
| `GemTiers` (`scripts/view/gem_tiers.gd`) | sabitler | küre tipi: xp < 5 normal, 5..79 elit, ≥ 80 ara boss (`tier_of`); `TEXTURES` ve `ORB_PX` tip sırasıyla veri alanlarıdır. Sim ve hash değişmez |

### A fazı notları

- **Gunslinger yürüme (F-038, F-064):** bölünmüş rig (gövde yürür, tabancalı kol `gunslinger_arm.png` ayrı parça; `rig.armless` YOK).
  `rig.walk{frames: 8, stride: 110, cell: [202, 320], strip: gunslinger_body_walk.png, shoulder_dev: []}`; şerit = 8 yürüme + 1 duruş hücresi
  (`PlayerView` bölünmüş rig düzeni). Üretim: `tools/art/make_zyfen_strip.py` yalnız-yürüme kipi (cast/gather kare dizini yoksa); duruş
  `gunslinger_body.png` AYNEN kalır (`--body-out` depoya yazılmaz). Kalite: `art/source/gunslinger/quality.json` `pass:true`
  (foot_slide 8/8 çift ≤3 px, boy sapması %1,83, genişlik 1818). `stride` 136 → 110: videonun gerçek adımı; yalnız görünüm, sim değişmez.
- **Hareketli portre:** `assets/video/portrait/<id>.ogv` (Theora, 576×864, 20 fps; Gunslinger ping-pong 7,95 sn, Zyfen 4 sn).
  `PortraitPlayer` (`scripts/ui/portrait_player.gd`): hareket azalt açık / dosya yok / yüklenemez / 1,5 sn'de ilk kare yok → görünmez, statik portre kalır.
  Kaynak, model ve istem: `art/source/<id>/README.md`.

## Beceri — `skills/<id>.json`

```json
{"id": "...", "kind": "active|passive|evolution", "name": "...", "icon": "...", "max_level": 5,
 "tags": [], "behavior": "<SkillRegistry anahtarı>", "levels": [{...}], "desc": ["..."],
 "requires": {"active": "...", "active_level": 5, "passive": "...", "passive_min_level": 1},
 "sfx": "evolution_3"}
```

- `max_level` 1..8 tamsayı; **evrimde 1**. `levels` ve `desc` uzunluğu = `max_level`.
- `behavior`: aktif/evrimde zorunlu, `SkillRegistry.BEHAVIORS`'ta olmalı ve `SkillBehavior`'dan türemeli; **pasifte yok**.
- `requires`: yalnız evrimde (zorunlu). `active` = `kind:active` beceri, `active_level` = o becerinin `max_level`'ı,
  `passive` = `kind:passive` beceri, `passive_min_level` 1..pasifin `max_level`'ı. Her aktifin en çok bir evrimi olur.
- `sfx` (isteğe bağlı, **yalnız evrimde**): evrim kazanılınca çalan ses kimliği; `assets/audio/sfx/<sfx>.ogg` var olmalı
  (hatalar: evrim dışında `unknown_key`, boş/metin değil `bad_type`, dosya yok `asset_missing`). Alan yoksa `evolution_1` çalar.
  Dört evrime `evolution_1…4` atanmıştır; Zyfen'in evrimleri `evolution_5…8` kullanır (Ay Orağı 5, Göğün Mızrağı 6,
  Kasırga Patlaması 7, Tufan 8).
- `cast_sfx` (isteğe bağlı, aktif ve evrimde; pasifte `unknown_key`): becerinin ateşlenme/doğuş sesi (`SimFx.skill_sfx`
  ile çalar). Tek dosya ya da `_1..N` varyasyon; yoksa `asset_missing`. Sürekli bölgeler (hortum, tufan) doğuşta tek
  seferlik, Girdap 4 sn'de bir; `Sfx.MIN_GAP_MS` aynı sesin en kısa tekrar aralığını sınırlar.
- `tags`: metin dizisi. `rhythm` = şarjör ritmiyle etkileşir. **İçerik tamamlandı (slice 2)** modunda `rhythm` etiketli
  **aktif** sayısı ≥ 2 (`rhythm_count`).
- `levels[i]` sayısal değerlerden oluşan nesnedir; **tüm seviyelerde aynı anahtar kümesi** (`levels_keys`). İstisna: `target_mode` (Hortum/Tufan, `"cluster"`) metindir; hız/hedefleme düğmeleri `speed`, `retarget_every` (sn; yoksa türe göre yedek), `max_dist` (kullanılmaz), `min_spawn_dist` (doğuşta oyuncudan en az uzaklık, px), `keep_out` (oyuncuya en fazla yaklaşma, px; `min_spawn_dist >= keep_out`), `boss_mult` sayıdır.
- **Aktif seviye monotonluğu** (anahtar adına göre): azalmayan `damage, count, radius, pellets, chance, bounces, ex_damage, ex_radius, damage_mult, pierce, push`; artmayan
  `cooldown, interval, every_n`. Diğer anahtarlar serbest sayı.
- **Pasif `levels[i]` o seviyedeki TOPLAM değerdir** (seviye 3 = 3 seviyenin toplamı). Anahtarlar sabit küme (bilinmeyen = `passive_key`):

| Anahtar | Tür | Aralık | Uygulama |
|---|---|---|---|
| `bullet_dmg_mult`, `fire_rate_mult`, `area_mult`, `explosion_dmg_mult`, `move_speed_mult`, `pickup_mult`, `range_mult`, `wind_time_mult` (v2.0.2) | x | -0,9..5 | etkin = `1 + x`, farklı pasifler toplanır. `wind_time_mult`: rüzgar bölgesi/toplama süresi; alan için mevcut `area_mult` yeniden kullanılır |
| `reload_time_mult` | x | -0,9..0 | etkin = `1 + x` (negatif = daha kısa); `Magazine` min 0,35 sn uygular |
| `mag_add` | tamsayı | 0..20 | şarjöre eklenir |
| `max_hp_add` | sayı | 0..1000 | |
| `regen` | sayı | 0..50 | can/sn |

  Monotonluk: |toplam| seviyeyle azalmaz (`reload_time_mult` -0,1, -0,2, … geçerli).
- `pool` (v2.0.2, isteğe bağlı; `DataV202Pool`): `"common"` (varsayılan; her karakter) ya da var olan karakter kimliği (yalnız o karakter görür:
  `SkillDef.available_to`, `Loadout` süzgeci). Bilinmeyen karakter `unknown_ref`, metin değil `bad_type`. Evrimin havuzu `requires.active`
  becerisininkiyle aynı olmalı, `starting_skill` havuzu karakterinki ya da `common` olmalı (`requires_ref`).
- `variants` (v2.0.2, isteğe bağlı, **yalnız `pool: common`**; özel havuzda `unknown_key`): `{"<karakter>": {name, icon, desc}}`, hepsi isteğe bağlı;
  karakter var olmalı (`unknown_ref`), `name` ≤ 18 karakter, `desc` verilirse uzunluğu `max_level` (`out_of_range`), `icon` görsel yolu (`asset_missing`).
  Çözüm: `SkillDef.name_for/icon_for/desc_for(character_id)`; variant yoksa ortak değer.
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
