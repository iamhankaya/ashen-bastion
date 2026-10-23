# Beceri kancaları (sözleşme)

Bir beceri `SkillBehavior`'dan türeyen tek bir sınıftır (`scripts/sim/skills/<id>.gd`); `SkillRegistry.BEHAVIORS`
kimlikten sınıfa eşler (sözleşme 12 satırı önceden ekler, alfabetik). JSON'daki `behavior` buradan çözülür.
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
(`refund`), `rng_combat`.

Mermi bayrakları (`ProjectilePool.FLAG_*`): `EXPLODES` (isabette), `EXPLODE_ON_EXPIRE` (dinamit), `EXPLODE_ON_BOUNCE`
(zincirleme_patlama), `RICOCHET`, `RADIAL` (yalnız görsel). `o` sözlüğü: `pierce, bounces, life (=1.2), flags, ex_radius,
ex_dmg, push, gun`. Pierce/bounce'ta mermi bir düşmana yalnızca bir kez vurur (mermi başına `hit_ids`, `HIT_SLOTS = 12`).

## Beceri → kanca eşlemesi

| Beceri | Kancalar | SkillApi | Bayraklar | Alanlar |
|---|---|---|---|---|
| `cift_tabanca` | `modify_shot` | | | |
| `dinamit` | `tick` | `spawn_projectile` | `EXPLODE_ON_EXPIRE` | |
| `doldurma_sacilmasi` | `on_reload_start` | `spawn_projectile` | `RADIAL` | |
| `gurleyen_yelpaze` | `tick` | `spawn_projectile` | | `push` |
| `keskin_nisan` | `tick` | `pick_highest_hp`, `hitscan` | | |
| `kiyamet_mermisi` | `on_last_bullet` | `explode`, `magazine` | `EXPLODES` | `ex_radius`, `ex_dmg` |
| `mermi_firtinasi` | `on_reload_start`, `on_reload_tick` | `spawn_projectile` | `RADIAL` | |
| `sarapnel` | `on_kill` | `spawn_projectile`, `rng_combat` | | |
| `seken_mermi` | `modify_shot` | | `RICOCHET` | `bounces` |
| `son_mermi_patlar` | `on_last_bullet` | | `EXPLODES` | `ex_radius`, `ex_dmg` |
| `yelpaze_atis` | `tick` | `spawn_projectile` | | |
| `zincirleme_patlama` | `modify_shot` | | `RICOCHET`, `EXPLODE_ON_BOUNCE` | `bounces` |

Ayrıntılar (plan "Denge tabloları" ve "Sözleşme kanca eşlemesi"):

- `cift_tabanca`: temel atışı sim şarjörden çıkarır, `modify_shot` çağrılır. Atış aralığı TABANCA BAŞINA, iki tabanca
  yarım aralık faz farkıyla sırayla ateş eder.
- `seken_mermi`: `index_in_mag % N == 0` ise `bounces`, `damage ×`, RICOCHET.
- `yelpaze_atis`: soğuma, ×N yelpaze (menzil 380, kısa ömür). `dinamit`: soğuma, yay atış (fitil 0,8 sn).
- `son_mermi_patlar`: `ctx.flags |= EXPLODES`, `ex_radius/ex_dmg`.
- `doldurma_sacilmasi`: doldurma başında radyal ×N. `sarapnel`: `rng_combat` şans, ×N parça (menzil 260).
- `keskin_nisan`: `pick_highest_hp` + `hitscan` (şarjörsüz; hitscan, mermi değil).
- `kiyamet_mermisi`: devasa patlama + `magazine.refund(2)`; DÖNGÜ BAŞINA BİR (`refund_used`, `reload_finished`'te sıfırlanır).
- `mermi_firtinasi`: `on_reload_start` (2×cap salvo) + `on_reload_tick` (0,15 sn'de 6'lı halka).
- `gurleyen_yelpaze`: 13 saçma, `pierce 2`, `push 160`.

Bu eşleme bir beceriye yetmezse sözleşme sahibi SONA kanca ekler (`vlad task ask` ile sor).
