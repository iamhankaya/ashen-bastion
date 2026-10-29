---
name: ab-basarim-ekle
description: Ashen Bastion'a başarım eklerken veya karakter kilidi bağlarken (data/achievements.json aile/kademe, data/achievements/<stat>.json metrik kaydı, reducer eklentisi, kapalı sabitler, ikon, kayıt göçü) kullan.
---

# Başarım ekle (aile / kademe + metrik kaydı, v2.0.3 + R8)

İki ayrı kayıt vardır; ikisi birlikte bir başarımı tanımlar:
- **Aile** (`data/achievements.json`): ad, açıklama, `steps` (1..5 kademe), `group`, ikon. "10/50/250 düşman öldür" = tek aile, 3 kademe.
- **Metrik** (`data/achievements/<stat>.json`, R8): stat'ın **nereden beslendiği** ve **nereye yazıldığı** (dosya adı = `stat`; şu an 21 dosya). `AchievementTracker` olay kodu taşımaz, bu kayıttan kurulur.

Şema ve göç kuralları: `docs/data-schema.md` ("Başarım — aile/kademe", "C fazı notları", **"Başarım metrik kaydı (R8)"**).

## Adımlar
1. **Aile kaydı:** `data/achievements.json` — `id` (aile; `[a-z0-9_]`), `name` (≤ 22, **İngilizce, sabit büyük harf**; `upper_tr` kullanılmaz), `desc` (≤ 60, Türkçe), `stat`, `scope` (`total|run`, stat'ın kapsamıyla aynı), `steps` (1..5 kesin artan eşik), `group` (`THE WATCH|THE CULLING|THE CROWNED|THE ARMORY|THE ROAD`), `icon` (isteğe bağlı). `target`/`tier` aile kaydında YASAK. Örnek: `reaper`. `legacy` yalnız v2.0.2'nin 22 eski kimliği içindir. Aile sayısı **12..30**, toplam kademe **≤ 80**.
2. **Stat'ı seç — üç yol (kod gereksinimi artan sırayla):**
   - **a) Mevcut stat'a yeni aile:** metrik dosyası zaten var; yalnız adım 1. Ancak stat'ı paylaşan aileler birbirinin tracker testini kirletir (ör. `total_kills` ↔ `reaper`): ayrı ilerleme istiyorsan yeni stat aç.
   - **b) Veriyle yeni stat (kod yok):** mevcut bir SimBus olayına bağlı yerleşik toplam/en büyük/sayım → `data/achievements/<yeni_stat>.json` (`order`, `icon_family`, `persist`, `source` + `aggregate`) + adım 1'deki aile. Olay kümesi `MetricSchema.EVENTS` (`enemy_killed{type_id}`, `level_up`, `score_changed`, `reload_started`, `streak_changed`, `pickup_collected{kind_id}`, `player_damaged`, `evolution_gained`, `buff_started/ended`, `bomb_hits`). Hata kodu `metric_schema` (`StatMetricsValidator`).
   - **c) Durumlu/koşullu stat (yeni reducer):** `scripts/ctrl/achievement_reducers/<ad>_reducer.gd` (`extends AchievementReducer`, `value()`; dosya + `.uid`) + metrik JSON'unda `reducer` + `events` (`poll`/`finish` isteğe bağlı). Mevcut `.gd` değişmez. Örnekler: `clean_secs_reducer.gd`, `elite_kinds_reducer.gd`, `unlimited_kills_reducer.gd`, `chars_five_reducer.gd`.
3. **Kapalı sabitlerin sınıflandırması (kuru denemede neyin "yalnız veri" sayıldığı):**
   - **Yalnız veri yeter (kod değişmez):** `AchievementDef.STATS` ve tracker `S_*` yerleşik 21 stat için sabittir, kayıttaki yeni stat'lar `GameData`/`DataV2` (`_has_metric`/`_scope_of`) ve tracker (`_build`) tarafından ardına eklenir; `AchievementRow.GOAL_TEXT` yoksa hedef metni "Hedef N" olur; `AchievementIcons.FAMILY` yoksa ikon aile kaydındaki `icon` alanından gelir. Bu üçü yalnız kozmetik cilalama: istenirse tabloya satır ekle (kod), eklenmese de akış çalışır.
   - **Kod eklentisi gerekir — kuru denemede "yalnız veri" yolu SAYILMAZ:** (i) kalıcı `totals/best` anahtarı: `AchievementDef.TOTAL_KEY/BEST_KEY` + `AchievementStore.TOTAL_KEYS/BEST_KEYS` (kayıt biçimi sabit; `AchievementProgress.of` ve `AchievementMigration._seed` bunlara bakar); veriyle eklenen stat bugün `persist: null` = yalnız koşu içi, koşular arası toplam için sabitleri güncelle ve **kayıt göçü testi** ekle; (ii) yeni SimBus olayı/poll/finish türü: sim kodu + `MetricSchema.EVENTS/POLLS`, ayrı iş.
   - **Açık nokta (tasarım kararı):** aile satırı (`data/achievements.json`) MEVCUT bir dosyadır; metrik dizinine taşınmadı. `prova_dry_run.py` bu yüzden aileyi varsayılan olarak eklemez (`--with-family` ile "degisen" sayısında görünür). Aile eklemek her zaman mevcut dosyayı değiştirir.
4. **İkon:** `assets/ui/achievements/<id>.png` (`ab-gorsel-ikon-uret`; `mipmaps/generate=true`). Kademe için ayrı ikon YOK: plaka silüeti + Roma rozeti + segment (`AchievementPlate`, `AchievementRow`).
5. **Karakter kilidi:** karakter JSON'unda `unlock: {"achievement": "<aile>"}` (kademe ≥ 1 açar; `ab-karakter-ekle`).
6. **Testler:** `test/unit/test_catalog_achievement_real.gd` (yerleşik 21 stat için metrik dosyası ↔ sabitler birebir; sözleşme "tüm kimlikler için", yeni metrik kırmaz), `test_catalog_achievement_dry_run.gd` (veriyle ekleme, yeni reducer dosyası, sentetik `order` sırası; yeni deseni buradan kopyala; sıra/sınır testlerinde `CatalogFixtures.metrics` / `AchKit`, gerçek katalogda sayı ya da sıra sabitleme), `test_achievement_reducers.gd`, `test_v203_c_*` (adım aritmetiği, göç, tracker, ekran), `test_achievement_icons.gd`. Sayıya bağlı testler artık **veriden türetilir** (`test_achievements_screen`, `test_data_v2`, `test_v203_c_zz_schema`); tester'ın kabul testleri (`test_acc_v203_screens`, `test_acc_v2_ach_screen` `ExpectedTablesV2.STATS`, `test_acc_v2_ach_tracker`, `test_acc_v203_ach_data`) sabit liste taşıyabilir: kırılırsa kendin değiştirme, `vlad task ask` ile "Test itirazı". Yeni test dosyası/kimlik değişimi → `ab-test-ve-kapi` (`removed_tests.txt`/`moved_tests.txt`). v2.0 tek eşikli kayıt testleri `AchKit.legacy_data()` (`test/fixtures/ach_v20/`) üzerinde koşar; gerçek veriye bağlama.
7. **Karakterizasyon:** olay akışı ve göç bazları (`rf_ach_flows*.json`, `rf_save_ach_*.json`, `test_acc_rf_achievements`, `test_acc_rf_save`) davranış değişmediği sürece **değişmez**; yeni stat mevcut senaryoların sırasını/`order`'ını bozarsa `BASELINE_CHANGED` çıkar. `order` değeri kademe açılış sırasını belirler: yeni stat'a mevcut en büyük `order`'dan büyük bir değer ver (ayrıntı `ab-test-ve-kapi` adım 7).
8. **Kuru deneme:** `git worktree add --detach <geçici dizin> HEAD`, sonra `python tools/ci/prova_dry_run.py --root <o worktree> --scenario ach_data` ve `--scenario ach_reducer` (`--godot <godot> --gut-dirs unit,acceptance`): sahte metrik yalnız YENİ dosyalarla eklenir, tam GUT koşar; beklenen `kırık=0`, `degisen=0`. Kırılan sabit listeli test veri tabanlı beklentiye çevrilir (gerçek katalog: "tüm kimlikler için X"; yerleşik 21 stat kümesi sabit kalır, fazlası geçerli). Aile satırı bu araca dahil değildir (adım 3, açık nokta).
9. **Doğrulama:** `bash tools/precheck.sh` (+ `--godot`), push, CI (`ab-test-ve-kapi`).

## Dokunulan dosyalar
`data/achievements.json`, `data/achievements/<stat>.json`, `scripts/ctrl/achievement_reducers/` (yeni reducer), `scripts/sim/achievement_def.gd` (yalnız kalıcı anahtar için TOTAL_KEY/BEST_KEY), `scripts/sim/catalog/metric_schema.gd` (yeni olay), `scripts/ctrl/{achievement_tracker,achievement_metric_registry,achievement_reducer}.gd`, `scripts/store/achievement_{store,migration}.gd`, `scripts/domain/achievement_{step,progress}.gd`, `scripts/ui/achievements_screen.gd`, `achievement_{row,plate,chronicle,toast,icons}.gd`, `assets/ui/achievements/`, testler.

## Kontrol listesi
- [ ] Aile 12..30, kademe toplamı ≤ 80, `steps` kesin artan.
- [ ] Yeni stat için metrik JSON'u var, `stat` aile kaydıyla eşleşiyor; kalıcı anahtar gerekiyorsa kapalı sabitler (`TOTAL_KEYS` vb.) ve göç testi güncel.
- [ ] Eşiği değiştirilen/yeniden bölünen kimlik için kayıtlı kademe geri alınmıyor (`reconcile` sessiz verir); eski kayıt gerekiyorsa göç testi.
- [ ] Başarım kaydı/ayar durumuna yazan test `after_each` ile geri alır (`AchKit.cleanup`).
- [ ] Başarım ekranı yeni öğe için `apply_safe_area` kapsamında; ekran görüntüsü (`tools/capture/shots_ach.gd`).
- [ ] İngilizce adlar sabit büyük harf; `to_upper`/`upper_tr` kullanılmadı.
- [ ] İkon `.import` commit'li; lisansı belirsiz görsel yok.
- [ ] `baseline/` değişmedi ya da gerekçeli (`baseline_changes.txt`); `scripts/**` dosyaları ≤ 800 satır (`achievement_tracker.gd` ~560).
