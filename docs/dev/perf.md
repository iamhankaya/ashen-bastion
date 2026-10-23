# Performans (U1-1)

Bütçe iddiası yoktur; ölçüm üç katmanlıdır (plan "Sistem tasarımı > Performans yaklaşımı").

1. **Gate'te deterministik iş sayaçları** — `GameSim.work` (`hash_inserts`, `hash_queries`, `cells_scanned`,
   `collision_tests`, `enemy_updates`, `proj_updates`, `explosions`; kümülatif, adım başına ortalaması alınır).
   Tavanlar `tools/perf_budget.json` (`per_step_max`) içindedir; U1-1 ölçümü +%25. Stres senaryosu:
   `scripts/debug/stress_scenario.gd` (tohum 20261023, 400 düşman + ~500 mermi, 600 adım, başlangıç zamanı 900 sn).
2. **Masaüstü mikro-ölçüm** — `godot --headless -s res://tools/perf/micro.gd`. Zaman yalnızca bilgidir.
3. **Cihaz içi** — debug APK'da 60 sn stres koşusu (`scripts/debug/stress_run.gd`), sonuç `user://perf.json`.

## Mikro-ölçüm sonucu (bulut konteyneri, headless, Godot 4.7.2, 600 adım)

| Sayaç (adım başına) | Ölçülen | Tavan (+%25) |
|---|---|---|
| hash_inserts | 400,0 | 500 |
| hash_queries | 501,1 | 640 |
| cells_scanned | 2079,4 | 2600 |
| collision_tests | 214,7 | 270 |
| enemy_updates | 399,9 | 500 |
| proj_updates | 500,2 | 630 |

Bilgi amaçlı süre: ≈3,0 ms/adım ortalama, en kötü adım ≈9,5 ms (masaüstü, headless; render yok). Cihaz için bir
çarpan **varsayılmaz**; cihaz ölçümünü kullanıcı paylaşır.

## Tasarım kararları

- `SpatialHash`: 1024 kovalı tablo + bağlı liste (Dictionary/dizi tahsisi yok); her adım yeniden kurulur; sorgu sonucu
  artan id sıralıdır. Aynı kovaya düşen hücreler sorguda bir kez gezilir.
- `EnemyPool` sıkıştırılmaz (kimlik/nesil kuralı). `ProjectilePool` ve `GemPool` kompakttır (0..count-1, çıkarma için
  ters sırayla gezin); mermi kimliği yoktur, `hit_ids` halka tampon (12) ile mermi başına tutulur.
- Sıcak yolda `Array`/`Dictionary` oluşturulmaz (istisna: `hitscan` / `pick_highest_hp`, U2 becerileri ve seyrek çağrılar).
- Sayaçların sıcak yol kopyaları `GameSim.w_*` tamsayılarıdır; `work` sözlüğü adım sonunda yazılır.

## Yedek merdiveni (sırayla)

1. `alive_cap` / mermi CAP düşür (düşman 400→300, mermi 600→400).
2. Hash hücresi 96→128, ayrıştırma 4 karede bir.
3. Mermi–düşman çarpışmasını iki kareye böl.
4. Karga/hayalet çarpışma yok sayma.

GDExtension bulutta derlenemediği için kapsam dışıdır. "300+" hedefinin altına inilirse karar kullanıcıya gider.
