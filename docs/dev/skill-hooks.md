# Beceri kancaları (sözleşme)

Bir beceri `SkillBehavior`'dan türeyen tek bir sınıftır (`scripts/sim/skills/<id>.gd`); `SkillRegistry.BEHAVIORS`
kimlikten sınıfa eşler (sözleşme satırları önceden eklenir, alfabetik; v2.0.2: Zyfen'in 12 davranışı). JSON'daki `behavior` buradan çözülür.
Davranış doğrudan çizim yapmaz, yalnızca `SkillApi` yüzeyini (= `GameSim` yöntemleri) kullanır.

**Değişmezlik kuralı:** kanca imzası değişmez, yalnızca SONA kanca eklenir. `test_contract_hooks.gd` bu belgedeki
tabloyu koda karşı doğrular (aşağıdaki tablo makine okunur: bir satır = bir beceri).

## Kancalar (`SkillBehavior`)

| Kanca | Ne zaman | Notlar |
|---|---|---|
| `setup(api, def, level)` | beceri eklenince / seviye değişince | `api` = `GameSim` |
| `modify_shot(ctx)` | şarjörden çıkan her kurşun | `ShotContext` alanlarını değiştirir |
| `on_last_bullet(ctx)` | son kurşun `consume()` edilince, aynı adımda | `ctx.is_last == true` |
| `on_reload_start()` | doldurma başlayınca | |
| `on_reload_tick(dt)` | doldurma süresince her adım | `mermi_firtinasi` halkaları |
| `on_reload_end()` | doldurma bitince | |
| `on_kill(enemy_id, pos)` | düşman ölünce | |
| `on_hit(enemy_id, proj_id)` | mermi düşmana vurunca | |
| `tick(dt)` | her adım (bağımsız beceriler) | şarjörsüz, soğumalı silahlar |

## SkillApi (`GameSim` yöntemleri)

`spawn_projectile(p, v, dmg, o) -> int`, `explode(pos, radius, dmg, source)` (zırhı yok sayar; `area_mult` /
`explosion_dmg_mult` uygular), `hitscan(origin, dir, range_px, dmg) -> int` (çizgi üzerindeki hepsi, mesafe sırasıyla),
`damage_enemy(id, amount, kind)`, `pick_highest_hp(from, range_px) -> int` (eşitlikte en düşük indeks), `magazine`
(`refund`), `rng_combat`, `fx` (yalnız görsel bildirimler: `beam_fired`, `volley_fired`), `kill_source_flags` (on_kill'de öldüren merminin bayrakları).

Mermi bayrakları (`ProjectilePool.FLAG_*`): `EXPLODES` (isabette), `EXPLODE_ON_EXPIRE` (kullanan beceri yok), `EXPLODE_ON_BOUNCE`
(zincirleme_patlama), `RICOCHET`, `RADIAL` (yalnız görsel), `LOB` (yay atış: düşmana çarpmaz, ömrü bitince patlar), `SHRAPNEL` (öldürdüğü düşman yeniden şarapnel saçmaz). `o` sözlüğü: `pierce, bounces, life (=1.2), flags, ex_radius,
ex_dmg, push, gun, radius (=8, `DEFAULT_RADIUS`)`. Pierce/bounce'ta mermi bir düşmana yalnızca bir kez vurur (mermi başına `hit_ids`, `HIT_SLOTS = 96` halka tampon: 96'dan fazla düşmana vuran mermide en eski kayıt ezilir).

v2.0.2 eklemeleri (Zyfen davranışlarının giriş/gözlem/tolerans satırları: `docs/design/v2.0.2/behavior-contract.md`; test itirazı yalnız oraya karşı açılır; ham DPS ölçümü: `test/helpers/dps_probe.gd`, başlangıç tablosu `docs/design/v2.0.2/balance/dps-baseline.md`): `FLAG_WIND` (rüzgar kesiği/hilal), `FLAG_SPLIT` (bölünen kesiğin çocuğu, tekrar bölünmez), `FLAG_SPLITTER` (bölünen kesiğin ebeveyni: ilk isabette biter ve çocuk doğurur; U3), `PIERCE_ALL = 99`; `ShotContext.radius/speed/life` (0 = varsayılan); `WindUtil.crescent/displace/pulse_circle/spear/skill_origin/enemies_near`, `WindSystem.cast_twisters/spawn_zone`; `sim.zones` (`ZonePool`), `sim.wind` (`WindSystem`), `fx.wind_wave/wind_cast`.

## Beceri → kanca eşlemesi

| Beceri | Kancalar | SkillApi | Bayraklar | Alanlar |
|---|---|---|---|---|
| `ay_oragi` | `modify_shot` | `spawn_projectile` | `WIND`, `SPLIT` | `radius`, `speed`, `life`, `pierce` |
| `bolunen_kesik` | `modify_shot`, `on_hit` | `spawn_projectile` | `SPLITTER`, `WIND`, `SPLIT` | `index_in_mag` |
| `cift_tabanca` | `modify_shot` | | | |
| `delen_ruzgar` | `tick` | `pick_highest_hp`, `spawn_projectile` | `WIND` | `radius`, `speed` |
| `doldurma_sacilmasi` | `on_reload_start` | `spawn_projectile` | `RADIAL` | |
| `girdap` | `tick` | `damage_enemy` | | |
| `gogun_mizragi` | `tick` | `pick_highest_hp`, `spawn_projectile` | `WIND` | `radius`, `speed` |
| `gurleyen_yelpaze` | `tick` | `spawn_projectile` | | `push` |
| `hava_bicaklari` | `tick` | `spawn_projectile` | `WIND` | `pierce` |
| `hava_cebi` | `on_kill` | `rng_combat`, `zones` | | |
| `hortum` | `tick` | `zones`, `rng_combat` | | |
| `kasirga_patlamasi` | `on_reload_start`, `on_reload_tick`, `on_reload_end` | `damage_enemy`, `fx` | | |
| `keskin_nisan` | `tick` | `pick_highest_hp`, `hitscan` | | |
| `kiyamet_mermisi` | `on_last_bullet` | `explode`, `magazine` | `EXPLODES` | `ex_radius`, `ex_dmg` |
| `mermi_firtinasi` | `on_reload_start`, `on_reload_tick` | `spawn_projectile` | `RADIAL` | |
| `nefes_dalgasi` | `on_reload_start` | `damage_enemy`, `fx` | | |
| `ruzgar_kesigi` | `modify_shot` | | `WIND` | `pierce`, `radius` |
| `sarapnel` | `on_kill` | `spawn_projectile`, `rng_combat` | `SHRAPNEL` | |
| `seken_mermi` | `modify_shot` | | `RICOCHET` | `bounces` |
| `son_mermi_patlar` | `on_last_bullet` | | `EXPLODES` | `ex_radius`, `ex_dmg` |
| `tufan` | `tick` | `zones`, `rng_combat` | | |
| `yelpaze_atis` | `tick` | `spawn_projectile` | | |
| `zincirleme_patlama` | `modify_shot` | | `RICOCHET`, `EXPLODE_ON_BOUNCE` | `bounces` |

v2.0.2 rüzgar notları (tabloda makine tarafından okunmayan ayrıntı):
- `delen_ruzgar`, `gogun_mizragi`: kesik `WindUtil.spear` (en yüksek canlı hedef, yarıçap 10, hız 1400, `PIERCE_ALL`); `girdap`, `nefes_dalgasi`, `kasirga_patlamasi`: `WindUtil.pulse_circle` (hasar `&"dot"`: zırhı yok sayar).
- `hortum`, `tufan`: `WindSystem.cast_twisters` (çağrı başına tam 1 `rng_combat.randf()`); bölge hareketi/tik/ömür sonu `WindSystem.step`.
- `hava_cebi`: `on_kill` etiket taşımaz; cep tiki ile ölen düşmandan zincir engeli `sim.wind.in_pocket_tick` bayrağıyla yapılır (bu durumda randf tüketilmez).
- `bolunen_kesik`: ebeveyn `FLAG_SPLITTER` taşır; `on_hit` ebeveyni bitirir (`pierce` 0), çocukları `FLAG_WIND | FLAG_SPLIT` ile doğurur ve ebeveynin vurduğu düşmanı çocuklara `mark_hit` ile işler. `ay_oragi` `FLAG_SPLIT` koyar (bölünmez).

Ayrıntılar (plan "Denge tabloları" ve "Sözleşme kanca eşlemesi"):

- `cift_tabanca`: temel atışı sim şarjörden çıkarır, `modify_shot` çağrılır. Atış aralığı TABANCA BAŞINA, iki tabanca
  yarım aralık faz farkıyla sırayla ateş eder.
- `seken_mermi`: `index_in_mag % N == 0` ise `bounces`, `damage ×`, RICOCHET.
- `yelpaze_atis`: soğuma, ×N yelpaze (menzil 380, kısa ömür).
- `son_mermi_patlar`: `ctx.flags |= EXPLODES`, `ex_radius/ex_dmg`.
- `doldurma_sacilmasi`: doldurma başında radyal ×N. `sarapnel`: `rng_combat` şans, ×N parça (menzil 260).
- `keskin_nisan`: `pick_highest_hp` + `hitscan` (şarjörsüz; hitscan, mermi değil).
- `kiyamet_mermisi`: devasa patlama + `magazine.refund(2)`; DÖNGÜ BAŞINA BİR (`refund_used`, `reload_finished`'te sıfırlanır).
- `mermi_firtinasi`: `on_reload_start` (2×cap salvo) + `on_reload_tick` (0,15 sn'de 6'lı halka).
- `gurleyen_yelpaze`: 13 saçma, `pierce 2`, `push 160`.

Bu eşleme bir beceriye yetmezse sözleşme sahibi SONA kanca ekler (`vlad task ask` ile sor).
