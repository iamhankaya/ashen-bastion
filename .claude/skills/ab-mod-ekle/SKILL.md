---
name: ab-mod-ekle
description: Ashen Bastion'a yeni koşu modu veya zorluk eklerken (data/run_modes/<id>.json, data/difficulties/<id>.json, RunCatalog, run_profiles.json, rf_runs_* karakterizasyon bazları, yeni bitiş türü sınırı) kullan.
---

# Koşu modu / zorluk ekle (R7 `RunCatalog`)

Mod ve zorluk **dosya başına bir kayıt**tır; dilim dosyası, sabit kimlik listesi ya da kayıt dosyası yoktur. `RunCatalog.default()` (`scripts/sim/catalog/run_catalog.gd`) dizinleri okur; `RunProfiles`, `RunStrip`, `Settings`, `Highscores`, `AchievementRules` ve `V21Runs.set_selection` kimlik kümesini buradan alır. Şema: `docs/data-schema.md` "Mod kataloğu (R7)".

## Adımlar
1. **Dosya:** mod → `data/run_modes/<id>.json`, zorluk → `data/difficulties/<id>.json` (dosya adı = `id`; uyuşmazlık `RUN_CATALOG: ... kimlik dosya adıyla aynı olmalı`). Örnekler: `data/run_modes/quick.json`, `data/difficulties/hard.json`.
   - **Mod alanları:** `id`, `order`, `name` ("Hızlı"), `label` ("HIZLI", **büyük harf elle yazılır**: Türkçe i/İ), `description` (Lord dakikası için `%d`), `ending` (`lord|endless`), `icon_key` (`quick|normal|endless`; bilinmeyen anahtar kum saati çizer), `profile` (`time_scale` 0,25..4, `xp_mult` 1..5, `lord_hp_mult` 0,1..5, `rate_mult` 0,25..4; `ending=endless` ise ek alanlar: `lord_repeat_sec`, `lord_repeat_hp_mult`, `lord_hp_cap_mult`, `enrage_after_sec`, `enrage_dmg_per_min`; `lord` bitişte bunlar yasak: `profile_cross`).
   - **Zorluk alanları:** `id`, `order`, `name`, `label`, `description`, `spoken` (TalkBack metni), `shields` (0..3), `values` (`enemy_hp`, `enemy_dmg`, `spawn_density`, `xp`, `lord_hp`; 0,1..5 / `xp` 1..5), `achievements` (`block_lord_bound`, `totals`: `runs_playsecs_only|all`).
   - Sıra `(order, id)`; varsayılan `"default": true` olan kayıt, yoksa sıradaki ilk.
2. **`data/run_profiles.json`** yalnız `v` ve `achievements.lord_bound_tier_ids` taşır. Yeni zorluk "Lord'a bağlı kademe" kuralını değiştirecekse (`"<aile>:<kademe>"`) buraya dokun; aksi halde dokunma.
3. **Yeni bitiş türü** (`RunCatalog.ENDING_KINDS`; `lord|endless` dışı) **sim kodu** ister: bu skill'in kapsamı değil, kabulden ayrı iş. `RunStrip.rule_lines` Kolay notu hâlâ `easy` kimliğine bağlıdır (açık bulgu): yeni zorluğun kural notu gerekiyorsa orada kod gerekir.
4. **Doğrulama (eklenti):** `scripts/sim/validators/run_catalog_validator.gd` (`RUN_CATALOG: <id>: <neden>`) `GameData.validate` içinde otomatik koşar (keşif için bkz. `docs/data-schema.md` "Doğrulayıcı eklentileri": `validators/` altında doğrudan `DataValidator` alt sınıfı; merkezi liste yok). Yerelde: `godot --headless -s res://tools/validate_data.gd`.
5. **Karakterizasyon bazı:** `test_acc_rf_runs` mod/zorluk 3×3 testleri **sabit listelidir** (`MODES`/`DIFFS`), yeni mod/zorluk onları değiştirmez (`rf_runs_profile_values`, `rf_runs_strip_texts`, `rf_runs_highscores` aynı kalır). Tüm birleşik profil sözlüğünü yükleyen `rf_runs_profiles_file` bazı ise yeni kayıtla **değişir** (beklenen): CI JUnit'inden `tools/ci/rf_extract_baselines.py` ile yeniden üret ve `tools/ci/baseline_changes.txt`'e gerekçeli satır ekle ("yeni mod eklendi: <id>"; `BASELINE_CHANGED`, ayrıntı `ab-test-ve-kapi` adım 7). Golden hash ya da başka baz değişirse sim bozulmuştur. Yeni modu 3×3 testine de katmak istersen `MODES`/`DIFFS` tester dosyasıdır: `vlad task ask`.
6. **Test:** `test/unit/test_catalog_add_mode_data_only.gd` kalıbı (geçici veri kökü; gerçek katalogun kopyası + sahte `zz_*` dosyası). Gerçek mod için `test_v21_u6_run.gd` ve `test/acceptance/test_acc_v21_*` kimlik beklentileri; sayılar/kimlikler katalogdan türetilir, sabit liste bulursan veriden türet (tester'ın kabul testiyse `vlad task ask` ile "Test itirazı").
7. **Kayıt uyumu:** `Highscores` ve `Settings` katalog kimliğini kullanır; silinen/yeniden adlandırılan kimlik kayıtlı skoru/ayarı yetim bırakır. Yeni kimlik ekle, mevcut kimliği yeniden adlandırma (gerekirse göç testi, `rf_save_highscores_v1`).
8. **Doğrulama:** `bash tools/precheck.sh` (+ `--godot`), push, CI (`ab-test-ve-kapi`).

## Dokunulan dosyalar
`data/run_modes/<id>.json`, `data/difficulties/<id>.json`, (nadiren) `data/run_profiles.json`, `test/characterization/baseline/rf_runs_profiles_file.json` + `tools/ci/baseline_changes.txt`, `docs/data-schema.md` (yeni alan/kural varsa), testler. Kod gerekirse: `scripts/sim/catalog/run_catalog.gd` (`ENDING_KINDS`), `scripts/ui/run_strip.gd`.

## Kontrol listesi
- [ ] Dosya adı = `id`; etiketler elle büyük harf (Türkçe i/İ); `description` mod için `%d` içeriyor.
- [ ] `validate_data` 0 hata; `RUN_CATALOG` hatası yok.
- [ ] `rf_runs_profiles_file` bazı yalnız yeni mod/zorluk nedeniyle değişti ve `baseline_changes.txt` satırı var; golden hash değişmedi.
- [ ] Yeni bitiş türü eklenmedi (eklendiyse sim kodu + ayrı kabul).
- [ ] `UiKit.make_scroll`/`apply_safe_area` dışında UI koduna dokunulmadı; UI gerekiyorsa `ab-ui-ekrani-ekle`.
- [ ] Mevcut mod/zorluk kimliği yeniden adlandırılmadı.
