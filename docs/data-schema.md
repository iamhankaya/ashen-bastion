# Veri şeması (sözleşme)

Veri **dosya başına kayıt** biçimindedir (birleşme çakışması yok): `data/characters/<id>.json`,
`data/skills/<id>.json`, `data/enemies/<id>.json`, `data/waves.json` (U2: `data/ruins.json`). Dosya adı = `id`.
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
