# v2.0.2 K fazı: kabul testleri (tester notu)

Kapsam: plan `#### K — Kabul testleri ve ayar turları`. Testler yalnız davranış sözleşmesine
(`behavior-contract.md`) ve planın arayüz/tablolarına karşı yazıldı; uygulama zaten vardı (U1+U2+U3+A4 birleşik, `d913d47`).
Tüm testler `V202Slice.require` ile dilim işaretine bağlıdır: `tools/v202_slices.txt` kapalıyken **pending** döner (gate yeşil).

## Dosyalar

| Dosya | Dilim | Test | Ne sınar |
|---|---|---|---|
| `test_acc_v202_pool_cards.gd` | P | 10 | kart havuzu süzgeci, çapraz sızıntı yok, evrim süzgeci, havuz tükenme, `character == null`, havuz sayıları |
| `test_acc_v202_pool_names.gd` | P | 7 | ortak pasiflerin Zyfen/Gunslinger adı-ikonu-açıklaması (Derin Nefes), 18 karakter sınırı, kart içeriği |
| `test_acc_v202_pool_passives.gd` | P | 8 | ortak pasiflerin Zyfen'deki sv5 etkileri, yığma sınırları (şarjör 13, doldurma 0,65), NaN yok |
| `test_acc_v202_pool_migration.gd` | P | 7 | Barutçu göçü + negatifler, `chars5` bayt eşitliği, üretim dosyalarında Barutçu/dinamit anması |
| `test_acc_v202_pool_golden.gd` | P | 7 | altın hash zinciri `v201 = s1 = u1a ≠ u1b`, `u2 = u1b`, `zyfen_u3` canlı koşu, karşılaştırıcı duyarlılığı |
| `test_acc_v202_pool_ui.gd` | P | 4 | HUD/pause ikonu, `UiKit.combo_rows` karakter parametresi |
| `test_acc_v202_rig_pierce.gd` | R | 6 | delme (20 hizalı düşman, 60 düşmanlı çizgi), kolsuz atış noktası, aynalama kuralı |
| `test_acc_v202_rig_manifest.gd` | R | 7 | manifest ↔ rig, `palm`, RigFrames hücre düzeni, CastAnim (iki `action_while_moving` değeri) |
| `test_acc_v202_rig_walk_gate.gd` | R | 6 | yürüme kalite kapısı + waiver kuralı, doku sınırı, hücre içeriği |
| `test_acc_v202_wind_skills.gd` | W/Z/E | 28 | davranış sözleşmesi tablosu satır satır (Hava Bıçakları ... Tufan) |
| `test_acc_v202_wind_tables.gd` | W/Z/E/R | 6 | plan §6 sayısal tablolar (`test/helpers/expected_tables_v202.gd`, elle kopya) |
| `test_acc_v202_wind_cadence.gd` | W/Z/E | 4 | cooldown ritmi |
| `test_acc_v202_wind_knobs.gd` | Z | 5 | Hortum/Tufan JSON düğmeleri (`speed`, `retarget_every`, `max_dist`, `boss_mult`) |
| `test_acc_v202_wind_feel.gd` | W | 3 | kesik başına isabet >= 5, hız/yarıçap Gunslinger'dan farklı |
| `test_acc_v202_wind_determinism.gd` | W/Z/E | 5 | aynı tohum aynı hash/RNG, gözlemci bağlı/bağsız |
| `test_acc_v202_wind_elite.gd` | Z/E | 5 | elit/Lord itilmez + hasar, Lord HP bütçesi (dakikada <= yüzde 25) |
| `test_acc_v202_wind_pickups.gd` | W/Z | 5 | Öfke Barutu, Kızgın Namlu, Sonsuz Tambur |
| `test_acc_v202_wind_cap.gd` | Z/E | 5 | CAP 64 / rezerv 8, Tufan kaybolmaz, kayıp sayacı |
| `test_acc_v202_wind_bounds.gd` | Z | 5 | merkez mesafe 0, büyük yarıçap, harabe içine gömülme, yüklü alan dışı |
| `test_acc_v202_wind_evolution.gd` | E | 6 | evrim kartı Zyfen'de var / Gunslinger'da yok |
| `test_acc_v202_wind_perf.gd` | W/Z | 4 | sayaç tabanlı bütçe (`test/fixtures/perf_budget_wind_v202.json`) |

Yardımcılar: `test/helpers/acc_v202.gd` (`AccV202`), `test/helpers/expected_tables_v202.gd` (`ExpectedTablesV202`).
Dilim başına test sayısı (işaret açılırken `tools/gate_min_tests.json`'a dosya başına eklenecek): P 43, R 21, W 20, Z 42, E 17
(dosya başı dağılım için yukarıdaki tablo; karma dosyalarda simge başına sayı `grep "^func test_<simge>"` ile alınır).

## Tur planı (ayar turları)

İşaret açma önkoşulu: o dilimin tüm kabul testleri gerçek kodda yeşil, `user_leak` temiz, `gate_min_tests.json` yükseltilmiş.

| Tur | Simge | Önkoşul (kırmızı kalemler) |
|---|---|---|
| T-P | P | `pool_ui` p3 (`UiKit.combo_rows` karakter parametresi), `pool_migration` p7 (yorum/SVG artıkları) |
| T-R | R | `rig_manifest` r2 (`palm` alanı) |
| T-W/Z | W, Z | `wind_knobs` z1 + z3 (Hortum/Tufan JSON alanları ve `retarget_every`) |
| T-E | E | yok (kırmızı yok) |

## Kırmızı bırakılan testler (işaretler `V202_SLICES_FORCE="P R W Z E"` ile zorlanınca)

Bkz. kapanış raporu; her biri plan maddesi + dosya:satır ile gerekçelidir.

## Mutasyon kontrolü (kanıt)

Üretim kodu geçici bozuldu, ilgili test dosyası koşuldu, geri alındı (`git checkout`; commit'te üretim değişikliği yok).

| # | Bozulan değer | Kırmızı olan testler |
|---|---|---|
| M1a | `ProjectilePool.HIT_SLOTS` 96 → 2 | `rig_pierce` r2 |
| M1b | `ProjectilePool.PIERCE_ALL` 99 → 1 | `rig_pierce` r1, r2, r3 |
| M2 | `SkillDef.available_to` her zaman `true` (havuz süzgeci kapalı) | `pool_cards` p1, p2, p4, p5, p6 |
| M3 | `GameSim.BULLET_SPEED` 900 → 901 (altın hash) | `pool_golden` p4, p5 |
| M5 | Bölünen Kesik çocuğu `FLAG_SPLIT` yerine `FLAG_SPLITTER` taşır (çocuk bölünür) | `wind_skills` w6, w7, w8 |
| M4' | Kasırga ikinci dalga zamanlayıcısı 0 | `wind_skills` e2, e3 |
| M7 | Hava Cebi zincir koruması (`in_pocket_tick`) kapalı | `wind_skills` z8 |
| M8 | `ZonePool` rezervi kapalı | `wind_skills` z9, `wind_cap` z1 |
| M9 | `WindUtil.displace` elit denetimi kapalı | `wind_elite` z1, z2; `wind_skills` z1, z10 |
| M10 | Girdap `area_mult`'u yok sayar | `wind_skills` z3, z13 |

Eşdeğer mutant (kırmızı vermez, bilinçli): Kasırga `on_reload_end`'deki `_waves_left = 0` silinirse hiçbir test kırılmaz;
doldurma kesilince `on_reload_tick` zaten çağrılmadığı ve sonraki `on_reload_start` sayacı yeniden kurduğu için davranış aynıdır.

## Varsayımlar

- Zyfen ortak pasif adları plan Açık nokta #4 gereği öneridir; `ExpectedTablesV202.COMMON_NAMES` onay gelirse güncellenir.
- Evrim `sfx` kimlikleri planda yer tutucuydu; A4 gerçek sesleri bağladığı için tabloda yoktur.
- Lord bütçesi eşiği planın yazdığı yüzde 25/dk'dır (D'de ayarlanır); ölçüm 30 sn'lik en kötü durum (Lord hep kümenin içinde) × 2.
- `perf_budget_wind_v202.json` bu K fazının ölçümüdür (+yüzde 25); D fazı gerekçeyle güncelleyebilir.
