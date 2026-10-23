# T20261023-59 kabul fazı — kapanış raporu (onaylı, PR #3)

### Yapılanlar

Headless GUT kabul paketi yazıldı ve `vlad/T20261023-59`'a push edildi. Uygulama yok: kabul testleri beklendiği gibi kırmızı. Skill'ler (`test-driven-development`, `systematic-debugging`, `verification-before-completion`) ayrıca yüklenmedi. Bulut protokolü gereği `.claude/skills` okunmadı; kabul testi yazımı için gerekmedi. Bunu eksik olarak raporluyorum.

**Strateji**
- Testler yalnızca `GameSim`, `event_log`, `bus`, havuzların açık alanları, `Difficulty`, `XpCurve`, `DamageSystem.after_armor`, `PlayerRig` ve `data/**` üzerinden yazıldı. Sözleşme raporu ve plan esas alındı. Uygulamanın içine bakılmadı.
- Beklenen sayılar `test/helpers/expected_tables.gd`'ye SABİT yazıldı (plan tabloları). `test_acc_tables.gd` bunları JSON ile karşılaştırır.
- Kural testleri varsayılan olarak doğurma çizelgesi BOŞ veri kopyasıyla (`SimKit` "quiet") koşar. Tesadüfi düşman girmez. Doğurma/zorluk/kısa koşular gerçek `waves.json`'u kullanır.
- Evrim kartı/yuva mantığı ve oyun sonu öncelikleri `test/fixtures/data_valid` ile sınanır. U1'de evrim içeriği ve Lord yok, mantık ise U1-5/U1-6 kapsamında.
- Uygulama-2 içeriği (boss/Lord, halka dalgası, 5 aktifin kalanı, 4 evrimin davranışı, 8/8/4/7 sayıları) `Slice.current() < 2` iken `pending` döner. Böylece U1 bitince gate yeşile dönebilir.
- Her pozitif davranışın, boş iskelette de geçecek "negatif" kontrolü için pozitif kontrolü vardır (ör. hedef gelince ateş başlar). Böylece sahte yeşil olmaz. İskelette yalnızca veri testleri (aşağıda) ve 1 negatif test geçer.
- Sızıntı dersi: `sim`'i yakalayan lambda `sim ↔ bus` döngüsü yaratıp gate'in `ERROR: resources still in use` günlük satırını kırmızı yapıyordu. Düzeltildi (tek lambda, sayaç dizisiyle).

**Eklenen dosyalar**
- Yardımcılar: `test/helpers/{slice,expected_tables,sim_kit,bots}.gd`
- Kabul: `test/acceptance/test_acc_{tables,pistols,magazine,rhythm,levelup,evolution,difficulty,waves,damage,run_end,determinism,caps,short_runs,perf_counters,character_data}.gd`
- `tools/gate_min_tests.json` (`update_min_tests.sh` ile: acceptance dosya başına asgari sayı, toplam 191)

### Kapsam

| Alan | Önceki durum | Eklenen testler |
|---|---|---|
| Şarjör/doldurma (6 kurşun, 1,0 sn, hizli_doldurma sv5=0,5, fazladan_mermi sv3=9/sv5=11, doldururken ateş yok, kuru tetik aralığı, HUD sinyalleri, cap artışı anında) | yok | `test_acc_magazine` (10), `test_acc_pistols` (9) |
| Çift tabanca ritmi (yarım aralık faz, 6 kurşun ≈0,75 sn, hasar/aralık seviyeleri, hedefsiz ateş yok, namlu `PlayerRig` tek kaynak) | yok | `test_acc_pistols` |
| Ritim becerileri (seken_mermi N./sekme/×hasar/tekrar vurmaz, son_mermi_patlar yalnız son kurşun/zırh yok sayma/barut_kesesi, ≥2 `rhythm` aktif; doldurma_sacilmasi s2) | yok | `test_acc_rhythm` (11) |
| Seviye atlama/beceri seçimi (XP eğrisi, 3 kart, dondurma, geçersiz `choose`, çoklu seviye kuyruğu, 6+6 yuva, maks. beceri yok, Şifa, `debug_force_choices`, determinizm) | yok | `test_acc_levelup` (17) |
| Evrim koşulları (aktif sv5 + pasif sv1, kart en altta/tek, yuva yerinde değişir, `evolved_log`, olay/sinyal; 4 çift ve davranışlar s2) | yok | `test_acc_evolution` (11) |
| Zorluk eğrisi (5/10/15/20. dk çarpanları, cap noktaları, monotonluk, zamanla doğuş/canlı sayısı, doğan hp ölçeği) | yok | `test_acc_difficulty` (9), `test_acc_waves` |
| Doğurma (halka ≈1396 px, geri taşıma, `start_time`/`debug_set_time` semantiği, boss/Lord zamanları, spawn kaybı: s2) | yok | `test_acc_waves` (12) |
| Hasar (zırh formülü, temas ilk tick hemen/0,6 sn/≤4 temas/zamanla ölçek, öldürme→XP taşı→toplama) | yok | `test_acc_damage` (10) |
| Oyun sonu (ölüm, timer WON, aynı adım öncelikleri, bekleyen seviye iptali, Lord: s2) ve sonuç ekranı verisi | yok | `test_acc_run_end` (10) |
| Determinizm, global durum sızıntısı, "her oyun sıfırdan" | sözleşmede boş sim hash | `test_acc_determinism` (8) |
| Havuz CAP/kalabalık sahne (400 düşman, 600 mermi, taş birleşimi, 330 düşman + 450 mermi) | yok | `test_acc_caps` (6) |
| Kısa koşular (120 sn × 3 politika, 4× `start_time` sıçraması, 90 sn tam oyun akışı) | yok | `test_acc_short_runs` (5) |
| İş sayacı bütçesi | yok | `test_acc_perf_counters` (3) |
| Yeni karakter veriyle | yok | `test_acc_character_data` (6) |
| Tablo–JSON eşleşmesi | yok | `test_acc_tables` (13) |

### Bulunan hatalar

Üretim kodu henüz yok. Bu yüzden bu fazda ürün hatası aranmadı; kırmızı testlerin tamamı uygulanmamış iskeletten (`Stub.todo`) kaynaklanır. Sözleşme/süreç gözlemleri:

1. **`selftest` işi bu branch'te ve entegrasyonda kırmızı.**
   - Belirti: `selftest_gate.sh` "taban yeşil" senaryosu temiz kopyada gate'in 0 dönmesini bekliyor. Kabul testleri kırmızı iken bu senaryo düşer.
   - Yeniden üretme: `bash tools/ci/selftest_gate.sh` veya Actions run `39947732650` (`622c943`), `selftest` işi `failure` (2 dk 40 sn sonra).
   - Neden: kasıtlı kırmızı kabul paketi. Öz-test dosyası C0 sahipliğinde, değiştirmedim. Öneri aşağıda.
2. **Sözleşme boşlukları (`### Açık noktalar`'da):** `run_ended` `stats` anahtarları, `perf_budget.json` biçimi, slice-2 aktif seviye anahtar adları. Testler varsayımla yazıldı.

### Kırmızı bırakılan testler

Tümü uygulama yokluğundan kırmızıdır (kasıtlı). Toplam **109 kırmızı** (acceptance 138 testin 109'u... bkz. aşağıdaki dosya başına dağılım: 109 = kırmızı, 24 pending, 7 yeşil + unit'in 75'i).

Dosya başına kırmızı (hepsi `test_` önekli):
- `test_acc_caps` (6): enemy_pool_fills_to_400_and_refuses_more, reusing_a_slot_changes_the_id_and_invalidates_the_old_one, projectile_pool_caps_at_600, gem_pool_merges_at_cap_and_conserves_xp, crowd_scene_300_plus_enemies_and_hundreds_of_projectiles, full_spawn_ring_keeps_the_simulation_alive_under_the_hard_cap
- `test_acc_character_data` (3): new_character_runs_in_the_same_sim_with_its_own_stats, new_character_reload_time_and_range_come_from_data, both_characters_play_a_full_short_run_with_the_same_loop
- `test_acc_damage` (10): armor_formula_is_max_of_flat_and_twenty_percent, bullet_hit_on_armored_enemy_applies_armor, bullet_hit_on_unarmored_enemy_deals_full_damage, contact_hurts_immediately_then_every_0_6_seconds, at_most_four_contacts_count_per_tick, contact_damage_scales_with_time, no_contact_no_damage_until_contact_then_immediate_tick, kill_drops_gem_with_enemy_xp_and_collecting_gives_xp, kills_counter_matches_kill_events, higher_xp_enemy_drops_proportional_gem
- `test_acc_determinism` (8): same_seed_same_hash_every_300_steps, same_seed_same_hash_in_dense_late_game, different_seeds_diverge, event_logging_does_not_change_the_simulation, hash_changes_as_the_game_progresses, choice_stream_is_independent_of_bot_and_combat_noise, sims_do_not_share_global_state, every_run_starts_from_scratch
- `test_acc_difficulty` (9): multipliers_at_5_10_15_20_minutes, alive_cap_fixed_points, start_of_run_multipliers_are_neutral, curves_never_decrease_and_cap_is_bounded, alive_cap_exceeds_300_after_14_5_minutes, enemy_count_grows_over_time, alive_enemies_grow_over_time, spawned_enemy_hp_scales_with_difficulty, spawn_rate_matches_wave_table_roughly
- `test_acc_evolution` (5): condition_requires_max_level_active_and_matching_passive, ready_evolution_appears_as_last_card_exactly_once, choosing_the_evolution_replaces_the_raw_active_in_place, evolution_is_offered_every_level_until_taken, after_taking_it_no_more_evolution_cards
- `test_acc_levelup` (17): xp_curve_fixed_points, xp_curve_is_strictly_increasing, below_threshold_stays_running_then_crossing_levels_up, level_up_offers_three_distinct_valid_cards, sim_is_frozen_while_choosing, invalid_choose_changes_nothing, choosing_applies_the_card_and_resumes, multiple_levels_in_one_step_queue_up, loadout_slots_are_capped_at_six_and_six, no_new_cards_when_slots_are_full, maxed_skills_are_never_offered_as_upgrades, heal_card_when_nothing_is_left_to_offer, heal_never_exceeds_max_hp, debug_force_choices_is_exact_and_single_use, card_draws_are_deterministic_per_seed_and_independent_of_other_rng, new_skill_card_adds_to_loadout_and_upgrade_card_raises_level, passive_choice_changes_stats_only_via_choose
- `test_acc_magazine` (10): reload_starts_after_sixth_shot_lasts_one_second_and_refills, no_shot_while_reloading_but_dry_fire_with_target, shooting_resumes_right_after_reload_end, hud_signals_follow_the_cycle, magazine_state_readable_for_hud, hizli_doldurma_level5_halves_reload, fazladan_mermi_level3_gives_nine_round_cycles, fazladan_mermi_level5_gives_eleven, cap_increase_during_level_up_choice_adds_rounds_immediately, dry_fire_not_emitted_without_target_and_reload_not_started_when_full
- `test_acc_perf_counters` (3): budget_file_exists_and_lists_every_counter, stress_scene_stays_under_work_budget, work_counters_are_deterministic_and_cumulative
- `test_acc_pistols` (9): first_cycle_has_six_shots_alternating_guns_in_about_075_s, shot_spacing_is_half_interval_between_guns_and_full_interval_per_gun, total_fire_rate_is_two_over_interval_per_second, shot_damage_follows_active_level, level5_interval_is_022_per_gun, hizli_parmak_shortens_interval, no_target_means_no_shot_and_no_ammo_spent, enemy_out_of_range_is_not_shot, muzzle_origin_comes_from_player_rig_single_source
- `test_acc_rhythm` (9): seken_mermi_level4_boosts_every_second_shot_damage, seken_mermi_bounces_hit_extra_distinct_enemies, ricochet_never_hits_the_same_enemy_twice, son_mermi_patlar_explodes_only_on_last_bullet, explosion_damage_ignores_armor, son_mermi_patlar_level5, barut_kesesi_scales_explosion_area_and_damage, agir_kursun_scales_bullet_damage, at_least_two_rhythm_skills_react_to_the_magazine_in_slice1
- `test_acc_run_end` (7): death_ends_the_run_as_lost_and_freezes_everything, result_stats_carry_time_level_kills_and_combos, result_stats_list_the_evolutions_built, timer_mode_wins_at_end_time, timer_mode_death_on_the_same_step_is_lost, death_cancels_a_pending_level_up, win_cancels_a_pending_level_up
- `test_acc_short_runs` (4): 120_seconds_with_each_policy_keeps_invariants, greedy_bot_actually_plays_kills_levels_up_and_chooses, jump_to_late_game_and_play_30_seconds, full_demo_run_from_start_to_result
- `test_acc_tables` (5): u1_actives_match_table, u1_passives_match_table_and_are_cumulative, u1_enemies_match_table, waves_rows_1_to_3_match_table, at_least_two_active_skills_are_rhythm_tagged
- `test_acc_waves` (4): natural_spawns_appear_on_the_ring_outside_the_camera, far_enemy_is_carried_back_in_movement_direction, spawn_dropped_counter_stays_zero_in_a_normal_run, debug_set_time_rescales_difficulty

Not: kırmızı toplamı 6+3+10+8+9+5+17+10+3+9+9+7+4+5+4 = **109**. Pending 24 (slice 2): evolution 6, rhythm 2, run_end 2, short_runs 1, tables 5, waves 8. Yeşil acceptance 7: `test_acc_tables` (real_data_validates_cleanly, gunslinger_character_table, after_lord_and_end_time), `test_acc_character_data` (new_character_json_validates_without_code_changes, sim_code_has_no_hardcoded_character_ids, character_def_exposes_art_and_rig_as_data), `test_acc_run_end` (default_mode_does_not_end_the_run_by_time_alone). İlk altısı mevcut sözleşme veri/kod durumunu kilitler, sonuncusu iskelette boş geçer ve U1-6 sonrası anlamlanır.

(Önceki paragraftaki "109 = ... 138'in 109'u" ifadesi düzeltmedir: acceptance paketi 140 test. 109 kırmızı + 24 pending + 7 yeşil = 140.)

### Test sonuçları

- Entegrasyon: `git fetch origin vlad/T20261023-55` + `git merge vlad/T20261023-55` → "Already up to date" (çakışma yok). Baş `8d4bd9f`.
- `gdformat --check test` + `gdlint test`: temiz (28 dosya).
- `bash tools/gate.sh` (çalışma kopyası ve `git clone --branch vlad/T20261023-59` ile alınmış temiz klon, ilk push `622c943` başında): 1 Godot, 2 import, 3 lint, 4 veri, 5 pytest **geçti**. 6 GUT: kasıtlı kırmızı, çıkış 1.
- Son baş `8d4bd9f` çalışma kopyasında: 23 betik, **215 test**: 82 geçti, **109 kırmızı**, 24 pending. Ayrıştırma hatası yok (`SCRIPT ERROR`/`Parse Error`/sızıntı satırı yok). Süre 2,4 sn (iskelette).
- Yalnız `test/unit`: 75/75 yeşil (bozulmadı).
- GitHub Actions (GitHub MCP ile okundu):
  - run `39947732650` (`622c943`): `test` = failure (gate adım 6, kırmızı kabul testleri), `selftest` = failure ("taban yeşil").
  - run `39947901664` (`8d4bd9f`, son baş): `test` = failure (aynı sebep, adım 6, ~19 sn). `selftest` raporu yazarken `in_progress`; run 9'daki gibi "taban yeşil" nedeniyle kırmızı beklenir (doğrulanmadı).
- Koşulmayanlar: `GATE_EXPORT`, `GATE_RENDER`, `GATE_NIGHTLY`, pytest dışı Python (art/audio yok).

### Kabul kriterleri

- **Headless koşan kabul testleri (uygulama yokken beklenen biçimde kırmızı): karşılandı.**
  - 140 kabul testi (15 dosya), headless GUT, `bash tools/gate.sh` ile koşar.
  - Kırmızı olanlar uygulama yokluğundan; hiçbiri ayrıştırma/günlük hatasıyla kırmızı değil.
  - Task tanımındaki alanlar: şarjör/doldurma, seviye atlama/beceri seçimi, evrim koşulları, zorluk eğrisi, oyun sonu (ölüm, 20. dk Lord), sonuç ekranı verisi, yeni karakteri veriyle ekleme.
  - Lord/boss/evrim davranışları Slice 2'de aktifleşir.
- Üst kabul kriterlerine bağlı not: şarjör ritmi HUD'u, ≥2 ritim becerisi, 300+ düşman bütçesi, karakter veri tanımı testleri hazır; geçmeleri U1/U2 uygulamasına bağlı.

### Önerilen düzeltmeler

Developer görevi için (T20261023-60 ve sonrası), hepsi "şu testin yeşile dönmesi" biçiminde:

1. **U1-1 (hash/havuz/perf):** `test_acc_caps` 6 test, `test_acc_perf_counters` 3 test. `tools/perf_budget.json` (düz sözlük, bkz. Açık noktalar) sayaç kırılımıyla yazılmalı.
2. **U1-2 (veri):** `test_acc_tables` u1_actives/passives/enemies/waves_rows_1_to_3 + rhythm-tag testi. 3 aktif, 8 pasif, 3 düşman, `waves.json` satır 1–3 plan tablolarıyla birebir.
3. **U1-3 (şarjör/hedef/hasar):** `test_acc_magazine`, `test_acc_pistols`, `test_acc_damage`.
4. **U1-4 (zorluk/doğurma):** `test_acc_difficulty`, `test_acc_waves` (4 U1 testi), `test_acc_levelup::xp_curve_*`.
5. **U1-5 (loadout/beceriler):** `test_acc_levelup`, `test_acc_evolution` (5 mantık testi, fixture ile), `test_acc_rhythm` (9).
6. **U1-6 (`GameSim` bütünleştirme):** `test_acc_run_end` (7), `test_acc_determinism` (8), `test_acc_short_runs` (4), `test_acc_character_data` (3).
7. **Gate/öz-test (C0 sahibi veya VLAD kararı):** `selftest_gate.sh` "taban yeşil" senaryosunu kabul testleri kırmızı iken de anlamlı tutmak: ya baseline'ı yalnız `test/unit` ile koştur, ya senaryoyu kabul testleri yeşile dönene kadar `SELFTEST_ALLOW_RED_ACCEPTANCE=1` ile atla. Ben değiştirmedim (kapsam dışı).
8. **Slice 2 (U2 görevleri):** U2-1 `tools/slice.txt = 2` yapınca 24 pending test aktifleşir; U2-2/3/4 bunları yeşile çevirir.

### Açık noktalar

**Varsayımlar (test kodunda yorumlu; sözleşme/plan yazmıyor):**
1. `bus.run_ended(won, stats)` sözlüğü `time, level, kills, evolutions` anahtarlarını taşır (`test_acc_run_end`). Tasarım §5.5 ve UI §6.5'ten türetildi. Developer farklı ad seçerse VLAD hangisinin doğru olduğuna karar versin.
2. `tools/perf_budget.json` biçimi düz sözlük `{ "<work anahtarı>": <adım başına tavan> }`, zorunlu anahtarlar: `hash_inserts, hash_queries, cells_scanned, collision_tests, enemy_updates, proj_updates` (`test_acc_perf_counters`).
3. Slice-2 aktiflerinin seviye anahtar adları `ExpectedTables.ACTIVE_LEVELS`'te: yelpaze_atis `cooldown/pellets/damage`, dinamit `cooldown/count/damage/radius`, doldurma_sacilmasi `count/damage`, sarapnel `chance(0–1)/pellets/damage`, keskin_nisan `cooldown/damage`. Şema serbest bıraktığı için U2 görevleri farklı seçerse tablo ve test birlikte güncellenmeli.
4. `debug_grant` pasif/aktif verince `StatBlock` ve `Magazine.cap` yeniden kurulur (choose yolundaki gibi).
5. `explosion` olayı ve `damage.raw` çarpanlar uygulanmış nihai değerleri taşır (`barut_kesesi` testi: yarıçap ×1,6, hasar ×1,4).
6. Beceri projektilleri (`doldurma_sacilmasi`, `mermi_firtinasi`, `gurleyen_yelpaze`) `shot` olayı yazar; "tabanca gözlemi" olarak kabul edildi.
7. Karakter `range` verisi hedefleme menzilini belirler (`test_acc_character_data`).
8. Namlu çıkış noktası testi: `facing_left = dir.x < 0` ile `PlayerRig.muzzle_world`'a ±1 px uyar (hedef sağda).
9. Lord+oyuncu aynı adım ölümü (`test_lord_death_and_player_death...`), düşman ve oyuncunun aynı adımda ölmesi koşulu oluşmazsa `pending` döner (sınanamadı) ve bunu raporlar.

**Test edilemeyenler / kullanıcıda doğrulanır:** cihaz FPS, rig görünümü, shader, ses, güvenli alan; nightly 20 dk koşu/sızıntı ve ≥100 seed dağılımı (`tools/balance`); UI sahne smoke (developer). `test_acc_short_runs` botlarının (kite/greedy) oyuncu kalitesi gerçek uygulama olmadan doğrulanamadı; eşikler gevşek tutuldu (kills ≥10, level ≥2 greedy). Gerçek uygulama gelince bot eşikleri ayarlanabilir; bunu tester yapar.

**Gerçek fixture:** dış servis yok.

**Test itirazı:** yok.

**Ders (VLAD kartına yazılabilir):** testlerde `sim`'i yakalayan lambda, `sim ↔ bus` döngüsüyle sızıntı yapar ve gate'in `ERROR: resources still in use` günlük taramasını kırar. Lambda yalnız yerel dizi/sayaç yakalamalı. `pending` testler asgari sayıya girmez; slice-2 testleri bu yüzden `gate_min_tests.json`'a girmedi.

Bildirim: VLAD session'ına tek seferlik zamanlanmış görev kuruldu (`trig_01EPRoUY6f4Cke9jNwCGnvTu`, 2026-10-23T11:46:30Z, `awaiting_approval`).
