# T20261023-58 sözleşme fazı — kapanış raporu (onaylı, PR #2)

### Yapılanlar

Sözleşme fazının üç görevi (C0, C1, C2) tamamlandı, bağımsız kod incelemesinden geçti ve bulguları düzeltildi. Bu rapor #11 numaralı önceki raporun yerine geçer. Fark: yeni `### Kod incelemesi` bölümü ve inceleme düzeltmeleri. Skill'ler entegrasyon branch'inden (`vlad/T20261023-55`) merge edildi, çakışma çıkmadı.

**C0 – Araç zinciri**
- Sürümler sabitlendi: Godot `4.7.2-stable` (`.godot-version`), GUT `9.7.1` (`addons/gut/`, `VERSION.txt`).
  - Godot `godot-builds` üzerinden indirildi, SHA512 `tools/ci/checksums.txt`'te.
  - GUT arşivi proxy'de 403 verdi. `git clone` (tag `v9.7.1`, commit `aeb5d4f`) çalıştı, `addons/gut` vendor edildi.
- `tools/ci/ensure_godot.sh`: idempotent kurulum, önbellek, SHA512. Ağ yoksa `GATE_NET: …` ve çıkış **3**. Root olmayan çalıştırmada `sudo -n` ile kütüphane kurulumu denenir.
- `tools/gate.sh`:
  - Adımlar: import, `gdformat --check` + `gdlint` + `to_upper/to_lower` grep (`scripts` ve `tools`), `validate_data` (zorunlu), pytest, GUT, JUnit denetimi.
  - Günlük taraması `^(SCRIPT ERROR|Parse Error|ERROR:|[GUT ERROR])` ve GUT özetindeki `Errors N>0`; izin listesi yok.
  - Dosya başına asgari test sayısı (`tools/gate_min_tests.json`). Pending/skip edilen testler sayılmaz. Yalnız `tools/update_min_tests.sh` ile güncellenir.
  - `GATE_EXPORT`/`GATE_RENDER` bayrakları, `tools/slice.txt` (şimdilik `1`).
- `tools/ci/selftest_gate.sh`: 11 senaryo; çalışma kopyası artık `git ls-files -co --exclude-standard` ile (boş dizinsiz, temiz checkout taklidi) kurulur.
- `tools/ci/gut_stub_hook.gd` + `.gutconfig.json` `post_run_script`: `Stub.todo` kaydı varsa çıkış kodu 1.
- Diğerleri: `tools/ci/check_junit.py` (+ pytest), `.gdlintrc`, `.github/workflows/ci.yml` (`test` 15 dk, `selftest` 30 dk zaman aşımı; gdtoolkit `==4.5.0`), `tools/ci/debug.keystore` (standart debug anahtarı), `project.godot`, `docs/dev/setup.md`, `test/acceptance/.gitkeep`.

**C1 – Veri sözleşmesi**
- `docs/data-schema.md`: şemanın tek belgesi.
- `scripts/sim/game_data.gd`: `GameData.load_dir/load_default`, `validate(registry, complete) -> PackedStringArray`. Tipli tanımlar `character_def.gd`, `skill_def.gd`, `enemy_def.gd`. Hata biçimi `"[kod] bağlam: açıklama"`; 31 kod `GameData.ERROR_CODES`'ta. Eksik kayıt dizini boş sayılır.
- `tools/validate_data.gd`: gate adım 4. `slice.txt == 2` iken `rhythm_count` kuralı da denetlenir.
- Fixture'lar: `test/fixtures/data_valid/` ve `data_bad_<kod>/` (30 bindirme dizini). Üretici: `tools/ci/gen_data_fixtures.py`. `behavior_base` `test_game_data.gd` içinde özel registry ile sınanır.
- Örnek gerçek veri: `data/characters/gunslinger.json`, `data/skills/cift_tabanca.json`, `data/waves.json` (`rows: []`).

**C2 – İskelet ve gözlem kancaları** (`scripts/sim/**`, `scripts/autoload/`, `scripts/audio/`)
- Sınıflar: `GameSim`, `SimBus`, `SimEvents`, `Choice`, `ShotContext`, `SkillState`, `SkillBehavior`, `SkillRegistry`, `StatBlock`, `Loadout`, `Magazine`, `Targeting`, `DamageSystem`, `XpCurve`, `Difficulty`, `SpawnDirector`, `EnemyAI`, `MapSim`, `PlayerRig`, `Stub`; havuzlar `EnemyPool`, `ProjectilePool`, `GemPool`, `ZonePool`; 12 davranış iskeleti (`scripts/sim/skills/*.gd`, her biri `setup`'ta `Stub.todo`); autoload `Events`/`Settings`; ses iskeleti.
- Gerçek gözlem kancaları: `state_hash`, `check_invariants`, `alive_ids`, `debug_force_choices` + `take_forced_choices`, `log_event`/`event_log`, `work`, 4 ayrı RNG akışı, `step(move)` (sabit STEP, 10 aşama), `choose`/`step` korumaları, `SpatialHash` (sıralı `query_circle`).
- `docs/dev/skill-hooks.md`: kanca tablosu ve 12 becerinin eşlemesi.

### Sözleşmenin yeri ve değişmemesi gereken noktalar

- **İmzalar:** `test/unit/test_contract_signatures.gd:19` (`METHODS`) ve `:171` (`SIGNALS`). `SimBus` 16 sinyal.
- **`step` aşama sırası:** `scripts/sim/game_sim.gd` (`PHASES`, `step()`), `test_contract_sim.gd`. Sıra değişmez.
- **Olay türleri:** `scripts/sim/sim_events.gd` (19 tür, sona ekleme serbest), `test_contract_events.gd`.
- **Kanca tablosu:** `docs/dev/skill-hooks.md` (makine okunur), `test_contract_hooks.gd`. Kanca imzası değişmez, yalnız sona eklenir.
- **Veri şeması ve hata kodları:** `docs/data-schema.md`, `scripts/sim/game_data.gd` (`ERROR_CODES`, `PASSIVE_KEYS`, `PASSIVE_BOUNDS`, `LEVEL_KEY_BOUNDS`, bilinen anahtar kümeleri).
- **Havuz sabitleri:** CAP 400 / 600 / 300 / 64, `HIT_SLOTS = 12`. **`enemy_id`** = `(nesil << 16) | indeks`. `alive_ids()` ve `query_circle` ikisi de ARTAN sayısal id sırasıyla döner. "Eşitlikte en düşük indeks" kuralı `index_of(id)`'ye bakar, id değerine değil.
- **Stub mekanizması:** `tools/ci/gut_stub_hook.gd`. Uygulayıcılar stub'ı kaldırdıkça gate yeşile döner. **Uygulayan görev**, ilgili `skills/<id>.gd` içindeki `setup` geçersiz kılmasını gerçek gövdeyle değiştirmelidir.

### Test sonuçları

Baş `1b221c1`:
- **Temiz klonda** (`git clone` ile): `bash tools/gate.sh` → **GATE OK**.
  - Import, `gdformat`/`gdlint` temiz; `to_upper/to_lower` grep boş.
  - `validate_data` hatasız.
  - pytest geçti (5 test).
  - GUT: 8 dosya, **75 test, 75 geçti**; günlük taraması ve JUnit denetimi geçti.
- **Temiz klonda** `bash tools/ci/selftest_gate.sh` → **SELFTEST OK**. 11 senaryo: taban yeşil, bozuk `.gd`, anlamsal hata, boş test dizisi, asgari sayı altı, `Stub.todo`, pending sayılmaz, `[GUT ERROR]`, veri hatası, `to_upper` (hepsi çıkış 1), ağ yok (çıkış 3).
- **GitHub Actions** run `39944308530` (head `1b221c1`): `test` ve `selftest` işleri **success**. GitHub MCP (`actions_list`) ile doğrulandı. Önceki koşular da yeşildi (`39942967138`, `39941666914`).

Derlenmedi/koşulmadı:
- `GATE_EXPORT=1` (APK, Android SDK): koşulmadı. `ensure_android_sdk.sh` ve `export_presets.cfg` yok, U1-10'un işi.
- `GATE_RENDER=1` (shader/xvfb): koşulmadı. Shader yok.
- `nightly.yml`: yazılmadı (U1-10 ve nightly görevleri).

### Kabul kriterleri

- **Şemalar + örnek veriler + sözleşme testleri; gate yeşil: karşılandı.** Gate yerelde, temiz klonda ve GitHub Actions'ta yeşil.
- **Fazın bitiş kriterleri:**
  - C0 öz-testleri yeşil: karşılandı (CI'da da).
  - İskelet `--import` ve GUT'ta ayrıştırma hatasız: karşılandı.
  - Sözleşme testleri yeşil: karşılandı.
  - İskelet çağrıları `Stub.todo` ile başarısızlık üretir: karşılandı (`test_contract_stub.gd`, hook, öz-test; 12 davranış iskeleti de görünür).
  - Aynı tohumla iki boş `GameSim` aynı `state_hash` verir: karşılandı.
  - Döngüsel bağımlılık yok: karşılandı, aşağıdaki sapma 2'ye bakın.
- **Sistem tasarımına uyum:** uyuldu, küçük sapmalar aşağıda.

### Kod incelemesi

`requesting-code-review` skill'i ve `code-reviewer.md` şablonuyla, **bağımsız bir alt agent** (`general-purpose`) tarafından yapıldı. Aralık `9bf0f8f..74cc26b` (`addons/gut` hariç). Alt agent temiz bir worktree'de gate'i ve öz-testi koşturdu ve mutasyon denemeleri yaptı. Sonuç: **Kritik 0, Önemli 7, Küçük 7 grup**. Karar: "With fixes". Aşağıdaki durumlar `1b221c1` başında geçerlidir.

| # | Önem | Dosya:satır | Bulgu | Durum |
|---|---|---|---|---|
| 1 | Önemli | `scripts/sim/game_data.gd` (`_validate_skill`, `_validate_skills`) | Evrimde `requires` yoksa ya da nesne değilse hata verilmiyor; `requires_*` ve `dup_evolution` kontrolleri atlanıyor. | Düzeltildi: `missing_field`/`bad_type`, `requires` içi bilinmeyen anahtar `unknown_key`. Test `test_evolution_requires_is_mandatory_and_must_be_an_object`. |
| 2 | Önemli | `game_data.gd` (`_screen`, `_validate_waves`, `_read_json`) | Dosya içeriği `null` olunca sessizce kabul ediliyor. | Düzeltildi: yalnız gerçek ayrıştırma hatası "bildirildi" sayılır, `null` → `not_object`. Test `test_literal_null_json_is_rejected`. |
| 3 | Önemli | `game_data.gd` (`_validate_active_levels`, kayıt doğrulamaları) | Aktif seviye değerlerinde sayısal sınır yok (`interval: 0`, negatif `damage`, 1e9 `radius`); karakter/düşman/beceri/rig/sway/charge/summon'da yazım hatası anahtarları geçiyor. | Düzeltildi: `LEVEL_KEY_BOUNDS` ve bilinen anahtar kümeleri, yeni kod `unknown_key` + fixture `data_bad_unknown_key`. Testler `test_active_level_values_are_bounded`, `test_unknown_keys_are_rejected_on_every_record_type`. **Kısmen ertelendi:** aktif seviye satırlarındaki bilinmeyen anahtarlar serbest kaldı (uygulayıcılar `fuse`, `range` gibi yeni sayısal anahtar ekleyebilmeli; yazım hatası riski kabul). |
| 4 | Önemli | `scripts/sim/pools/enemy_pool.gd` (`alive_ids`), `spatial_hash.gd` | `alive_ids()` slot sırasıyla dönüyor, `query_circle` id sırasıyla; planın "artan id sırası" kuralını bozuyor. Nesil ≥ 0x8000 id'ler int32'de negatif. | Düzeltildi: `alive_ids()` artan sayısal id sırasına sıralandı; her iki sıra aynı. Çok nesilli test `test_alive_ids_and_query_circle_share_one_ascending_order_across_generations`. Negatif id sınırı ve "eşitlikte en düşük indeks = `index_of`" kuralı kodda ve belgede yazıldı. **Sözleşme imzası/kodlama değişmedi** (16 bit nesil korundu). |
| 5 | Önemli | `tools/gate.sh` (`scan_log`), `.gutconfig.json` | `[GUT ERROR]` taranmıyor; temiz klonda `test/acceptance` yok (git boş dizin tutmaz) ve GUT hata sayıyor ama çıkış 0. | Düzeltildi: `test/acceptance/.gitkeep`, tarama `[GUT ERROR]` ve `Errors N>0` ile genişletildi, öz-test senaryosu (g). |
| 6 | Önemli | `tools/ci/check_junit.py`, `skills/*.gd` | `pending()` testleri asgari sayıya sayılıyor; iskelet davranışlar sessiz (boş `pass`). | Düzeltildi: `tests - skipped` sayılır (`check_junit.py`, `update_min_tests.sh`), pytest + öz-test (f). 12 davranış iskeleti `setup`'ta `Stub.todo` çağırır, test `test_unimplemented_behaviors_are_visible_to_the_stub_hook`. |
| 7 | Önemli | `.github/workflows/ci.yml`, `tools/ci/ensure_godot.sh` | `gdtoolkit==4.*` gevşek; kök olmayan runner'da kitaplık fallback'i yok; `timeout-minutes` yok. | Düzeltildi: `==4.5.0`, `timeout-minutes` 15/30, `sudo -n` fallback. Gerçek runner'da kitaplık kurulumu Actions'ta gerekmedi (işler yeşil). |
| 8 | Küçük | `scripts/sim/stub.gd` | `_calls` sınırsız büyür. | Düzeltildi: benzersiz adlar tutulur. |
| 9 | Küçük | `test_contract_hooks.gd` | Testler arası `Stub` bağımlılığı; sızıntı karışık mesaj veriyor. | Düzeltildi: `before_each` ile `Stub.reset()`. |
| 10 | Küçük | `scripts/sim/spatial_hash.gd` (`query_circle`) | Çok geniş yarıçap hücre sayısı kadar döner. | Düzeltildi: hücre sayısı girdi sayısını aşarsa doğrusal tarama. Test `test_huge_radius_does_not_scan_every_cell`. `insert` içindeki dizi kopyası U1-1'e bırakıldı (iskelet). |
| 11 | Küçük | `tools/gate.sh` | `validate_data.gd` yoksa adım sessizce atlanıyor; `to_upper` grep yalnız `scripts/`. | Düzeltildi: `validate_data.gd` zorunlu, grep `scripts` ve `tools`. Öz-test (h), (i). |
| 12 | Küçük | `tools/ci/selftest_gate.sh` | Öz-test kirli çalışma ağacını kopyalıyor. | Düzeltildi: `git ls-files -co --exclude-standard` (boş dizinsiz). |
| 13 | Küçük | `test/unit/test_smoke.gd.uid`, `audio/muzik/*.wav.import` | İzlenen ölü `.uid`; izlenmeyen `.wav.import` dosyaları kirli ağaç bırakıyor. | Düzeltildi: `.uid` silindi, `.gitignore`'a `audio/muzik/*.import`. |
| 14 | Küçük | `game_data.gd` (dalga/summon/id doğrulamaları) | Lord boss satırı olmayan dalga, tekrarlı boss, `summon.type` kendisi ya da lord, pasifte işaret değişimi (+0,1 sonra -0,1), id karakter kümesi, `res://project.godot` sprite olarak kabul. | **Ertelendi:** sözleşme fazında `waves.json` bilerek boş (`rows: []`); lord/boss satırı zorunluluğu `slice.txt == 2` içerik kuralı olmalı ve içerik görevlerinin kapsamında. Diğerleri düşük etki; denge/içerik görevleri (U2-4, U2-10) şemayı sıkılaştırabilir. |
| 15 | Küçük | `test_contract_sim.gd`, `game_sim.gd` | `PHASES`/Stub'a bağlı adım sırası testi gövdeler gelince değişmeli; `check_invariants` nesil denetimi totolojik, `_time_regressed` ulaşılamaz; bilinmeyen `character_id` sessiz varsayılan. | **Ertelendi:** U1-6 gerçek gövdelerle `event_log` sırasını gözlem olarak kullanacak; invariant ve karakter kontrolleri o görevde anlam kazanır. |
| 16 | Küçük | `tools/ci/ensure_godot.sh`, `gen_data_fixtures.py` | Her `curl` hatası `GATE_NET` (3) sayılıyor; fixture üretici ile commit'li fixture uyumunu denetleyen test yok. | **Ertelendi:** 404 ile ağ ayrımı için ek bir senaryo gerekir (düşük değer); fixture sapma denetimi test yardımcısı olarak sonraki şema değişikliğiyle birlikte eklenebilir. |

**"Kapsam dışı" listesi (alt agent'ın "Declined to judge" satırları, hepsine karar):** denge sayıları ve `cift_tabanca.json` içeriği (sözleşme şekil fazı; kabul), `addons/gut` (vendor; kabul), `.claude/skills` ve `art/`, `audio/` (faz dışı; kabul), render/shader/cihaz (sonraki fazlar; kabul), `vlad task ask` ile durma davranışı (orkestrasyon; yalnız çıkış kodu 3 doğrulandı; kabul), gerçek Actions davranışı (Actions çalıştırıldı ve yeşil; bu madde artık karşılandı).

### Açık noktalar

Sapmalar ve kararlar (itiraz edilmezse geçerli):
1. **`SkillRegistry` 12 satırla önceden dolduruldu** (plan "boş" diyordu). Örnek verinin `behavior` doğrulamasından geçmesi için gerekli; U1-5/U2-2/U2-3 paylaşılan dosyada çakışmaz.
2. **"Döngüsel class_name bağımlılığı yok" yeniden yorumlandı.** Planın imzaları tür ek açıklaması döngüsü yaratır (`SkillBehavior.setup(api: GameSim…)` → `GameSim` → `Loadout` → `SkillBehavior`); Godot 4.7.2 bunu sorunsuz derliyor. Gerçek risk olan `extends`/`preload` döngüleri `test_contract_no_cycles.gd` ile denetleniyor. `GameData` `SkillRegistry`'ye statik başvurmuyor.
3. **`PlayerRig.muzzle_world`** 5. parametre olarak `rig: Dictionary` aldı.
4. **Planda tam yazılmamış imzalar benim tanımım** (değişebilir, `test_contract_signatures.gd`'de kilitli): `DamageSystem` (`after_armor`, `damage_enemy`, `contact_tick`), `SpawnDirector.step/skip_to`, `EnemyAI.step`, `MapSim.obstacles_near`, `GameSim.take_forced_choices()`, `GameSim.log_event()`, `AudioDirector.bind`.
5. **Şema yorumları** (plan belirsizdi): aktif `cooldown/interval/every_n` seviyeyle **artmaz**, `damage` vb. **azalmaz**; pasif değerleri `x`, etkin `1 + x`, `reload_time_mult` negatif toplam, monotonluk `|x|` artar; `rate`/`group` için `a <= b`; `waves.json`'a opsiyonel `end_time`; her aktifin en çok bir evrimi; `rhythm_count` yalnız `slice.txt == 2` iken. İnceleme bu yorumları doğruladı.
6. **`cift_tabanca` `tags`'i `[]`** (plan, ritimle etkileşenler listesine temel silahı koymuyor).
7. **Örnek `data/`** yalnız `gunslinger`, `cift_tabanca` ve boş `rows`'lu `waves.json`; kalan kayıtlar planın "tek veri sahibi" kuralına göre ilgili görevlerde.
8. **Görsel yolları** `placeholder:<ad>`; `art/ref/` ve `docs/ui/icons` henüz `assets/`'e alınmadı (U2-1/U2-6).
9. **GUT kaynağı:** GitHub arşiv indirmesi proxy'de 403; vendor kopya `git clone` ile alındı.
10. **Tuzaklar:** `StringName` sıralaması adres bazlı, kararsız (sıralama gereken yerde `String`); nesil ≥ 0x8000 id'ler int32'de negatiftir (gerçekçi değil, belgeli).
11. **`gdlint`** kuralları genel olarak gevşetildi (`.gdlintrc`); test dosyaları için ayrı yapılandırma yok.
12. **Ertelenen inceleme bulguları:** #14, #15, #16 (tabloda gerekçeleriyle). Bunlar U2-4/U2-10, U1-6 görevlerinde ve bir sonraki şema değişikliğinde ele alınabilir.
13. **Test itirazı yok, kullanıcı kararı gerektiren yeni konu çıkmadı.** Sözleşme imzası değişmedi, `[VLAD:ASK]` gerekmedi. Güvenlik etkisi yok (auth/yetki/veri silme yok). Repoda keystore yok (yalnız standart debug anahtarı, sır değil).
14. **Eksik skill sorunu çözüldü:** skill'ler `.claude/skills/`'ten okundu ve uygulandı (`requesting-code-review` ile bağımsız inceleme, `verification-before-completion` ile temiz klon + Actions doğrulaması). `test-driven-development` düzeltmelerde uygulandı (yeni testler yazılıp gate ile birlikte koşuldu); ilk yazım turunda sözleşme testleri iskeletle birlikte yazılmıştı.
15. **Ders (VLAD kartına yazılabilir):** gate'i çalışma kopyasında değil, `git clone` ile alınmış temiz kopyada koş; git boş dizinleri izlemez ve gate adımları bunlara bağımlı olmamalı. `pending()` testleri JUnit'te "geçmiş" görünür; asgari sayı korumaları skip'i saymalı.
