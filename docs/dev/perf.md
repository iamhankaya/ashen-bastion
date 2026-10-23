# Performans (U1-1)

Bütçe iddiası yoktur; ölçüm üç katmanlıdır (plan "Sistem tasarımı > Performans yaklaşımı").

1. **Gate'te deterministik iş sayaçları** — `GameSim.work` (`hash_inserts`, `hash_queries`, `cells_scanned`,
   `collision_tests`, `enemy_updates`, `proj_updates`, `explosions`; kümülatif, adım başına ortalaması alınır).
   Tavanlar `tools/perf_budget.json` içindedir (düz sözlük `{sayaç: adım başına tavan}`); iki senaryonun (bizimki ve
   `test_acc_perf_counters` stres sahnesi) büyük ölçümü +%25. Stres senaryosu:
   `scripts/debug/stress_scenario.gd` (tohum 20261023, 400 düşman + ~500 mermi, 600 adım, başlangıç zamanı 900 sn).
2. **Masaüstü mikro-ölçüm** — `godot --headless -s res://tools/perf/micro.gd`. Zaman yalnızca bilgidir.
3. **Cihaz içi** — debug APK'da 60 sn stres koşusu (`scripts/debug/stress_run.gd`), sonuç `user://perf.json`.

## Mikro-ölçüm sonucu (bulut konteyneri, headless, Godot 4.7.2, 600 adım)

| Sayaç (adım başına) | Ölçülen | Tavan (+%25) |
|---|---|---|
| hash_inserts | 400,0 | 500 |
| hash_queries | 501,1 | 640 |
| cells_scanned | 2079,4 (tester: 2082) | 2650 |
| collision_tests | 214,7 (tester senaryosu: 361–375) | 470 |
| enemy_updates | 399,9 | 500 |
| proj_updates | 500,2 | 630 |

Bilgi amaçlı süre: ≈3,0 ms/adım ortalama, en kötü adım ≈9,5 ms (masaüstü, headless; render yok). Cihaz için bir
çarpan **varsayılmaz**; cihaz ölçümünü kullanıcı paylaşır.

## Tasarım kararları

- `SpatialHash`: 1024 kovalı tablo + bağlı liste (Dictionary/dizi tahsisi yok); her adım yeniden kurulur; sorgu sonucu
  artan id sıralıdır. Aynı kovaya düşen hücreler sorguda bir kez gezilir.
- `EnemyPool` sıkıştırılmaz (kimlik/nesil kuralı). `ProjectilePool` ve `GemPool` kompakttır (0..count-1, çıkarma için
  ters sırayla gezin); mermi kimliği yoktur, `hit_ids` halka tampon (12) ile mermi başına tutulur.
- Sıcak yolda olay sözlükleri yalnız `log_events` açıkken kurulur (`GameSim.logging()`); patlama/sekme sorguları kalıcı
  scratch dizileri kullanır. Kalan tahsisler: atış başına `ShotContext` + mermi seçenek sözlüğü, `Magazine.consume()` sonucu,
  `SpawnDirector.step` satır okumaları (ölçüm: bkz. sayaçlar; zaman tavan değildir). `hitscan` / `pick_highest_hp` U2 becerileri içindir.
- Sayaçların sıcak yol kopyaları `GameSim.w_*` tamsayılarıdır; `work` sözlüğü adım sonunda yazılır.

## Yedek merdiveni (sırayla)

1. `alive_cap` / mermi CAP düşür (düşman 400→300, mermi 600→400).
2. Hash hücresi 96→128, ayrıştırma 4 karede bir.
3. Mermi–düşman çarpışmasını iki kareye böl.
4. Karga/hayalet çarpışma yok sayma.

GDExtension bulutta derlenemediği için kapsam dışıdır. "300+" hedefinin altına inilirse karar kullanıcıya gider.

## Render notları (U1-7)

- **`INSTANCE_CUSTOM` prototipi (gl_compatibility) çalıştı.** Deneme: `MultiMeshInstance2D` + `use_colors` + `use_custom_data`, canvas_item shader'ında `vertex()` içinde `INSTANCE_CUSTOM.r` → varying → `fragment()`'ta beyaza karışım. `xvfb-run` + `--rendering-driver opengl3` (Mesa llvmpipe, OpenGL 4.5 Compatibility) ile ekrandan okunan piksellerde custom=0 örnek kendi rengini, custom=1 örnek beyazı verdi. **Karar:** vurulma parlaması `INSTANCE_CUSTOM.r`'de (`assets/shaders/enemy_flash.gdshader`); COLOR kanalı tür rengine (tint) kalır. Yedek (parlama COLOR'da, karga kareleri 3 ayrı MultiMesh) gerekmedi. Gerçek cihaz GPU'sunda (Adreno/Mali GLES3) doğrulama **kullanıcıda** (prova).
- **Tampon düzeni** (`MultiMesh.buffer`, 2B): örnek başına 8 dönüşüm (`x.x, y.x, 0, origin.x, x.y, y.y, 0, origin.y`) + 4 renk (+ 4 custom yalnız düşmanda) = düşman 16, mermi/taş 12 float.
- **Kural:** tür başına tek `MultiMeshInstance2D` (`EnemyRenderer` CAP 400, `ProjectileRenderer` 600, `GemRenderer` 300); `instance_count = CAP` sabit, kare başına kalıcı `PackedFloat32Array`'a doğrudan indeks yazımı + tek `multimesh.buffer` ataması; `visible_instance_count = canlı sayı`. Düşman taraması `for i in EnemyPool.CAP: if alive[i] == 1` (artan indeks; `alive_ids()` sıralaması kullanılmaz). Hot path'te sözlük/Array oluşturma yok (tür ölçek/renk tabloları `bind` sırasında Packed dizilere kurulur).
- **Çizim sırası:** zemin → taşlar → düşmanlar → y-sıralı aktör katmanı (oyuncu) → mermiler. Düşman–oyuncu y-sort yok (plan: kasıtlı sınır).
- **2B dörtgen:** `QuadMesh` 2B'de UV'yi dikey ters çevirdiği için `PlaceholderArt.quad_mesh()` elle kurulan `ArrayMesh` kullanır.
- Masaüstü yazılım GL'de (llvmpipe) 46 düşman + HUD ile ekran görüntüsü alındı; FPS ölçümü yapılmadı (yazılım render anlamlı değil). Cihaz içi ölçüm U1-10 stres koşusunda.

## Render'lı stres koşusu (bilgi; bulut, Mesa llvmpipe yazılım GL, xvfb, 540x1200, 40 sn)

`StressRun` (400 düşman + ~485 mermi, `gl_compatibility`): ort. 33,9 ms/kare (≈29,5 FPS), p95 69,7 ms, en çok 144 draw
call, 2048 nesne, 64 MB statik bellek. **Yazılım rasterleştirici olduğu için cihaz hakkında hiçbir şey söylemez**; yalnızca
sahnenin çalıştığını, draw call sayısının düşük (tür başına tek MultiMesh) kaldığını gösterir. Cihaz FPS'i kullanıcıda ölçülür
(`docs/dev/user-verify.md`).

## Uygulama-2 notları

- **Sim maliyeti (masaüstü, headless, stres senaryosu, bilgi):** U1 ≈3,3–3,9 ms/adım → U2 ≈4,4–5,0 ms/adım. Artış:
  yer düşmanları için harabe engeli (`MapSim.resolve`, iki adımda bir), tür sınıfı sorgusu, elit/Lord kancaları,
  büyük düşmanların (yarıçap > 40) ızgara dışı ayrı denetimi (`GameSim.SMALL_ENEMY_RADIUS`/`_big_ids`; Lord yarıçapı 72
  olduğu için ızgara sorgu yarıçapını büyütmek `cells_scanned`/`collision_tests` bütçesini 3-7 kat aşırıyordu).
  Gate sayaç tavanları (`tools/perf_budget.json`) değişmedi.
- **Render:** düşmanlar tek atlas dokusu + tek MultiMesh (INSTANCE_CUSTOM: parlama, hücre, kontur, elit), quad yalnız
  sprite + 16 px pay kadar (`EnemyAtlas.rects`); kontur (rim) opak piksellerde erken çıkar. xvfb/llvmpipe yazılım GL'de
  stres koşusu ≈133 ms/kare (düşmanlar gizliyken ≈107 ms): cihazı temsil ETMEZ, yalnız göreli karşılaştırma içindir.
  Cihaz FPS'i kullanıcıda (docs/dev/user-verify.md §4).
- **F-ashen-bastion-002:** `RenderFix` (özel kesme dikdörtgeni) varsayılan AÇIK; debug APK'da etiketle kapatılabilir.
- Yedek merdiveni (yukarıdaki) hâlâ geçerli; ilk adım: `ProjectilePool.CAP`/`alive_cap` düşürme.
