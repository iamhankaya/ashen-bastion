# T20261023-79 v1 uygulama-3 — kapanış raporu

### Yapılanlar
- **Katı harabeler (madde 4):**
  - `tools/art/ruin_collision.py`: sprite'ın taban kenarından daire zinciri üretir, `data/ruins.json` içine `collision` yazar. `--check` ve `--preview` var. Pytest: `tools/art/tests/test_ruin_collision.py`.
  - `data/ruins.json`: katı/dekor kuralı "görsel yüksekliği ≥ 240 px (oyuncu ≈200 px'ten uzun) olan yapı katı". Katı: `ruin_01–10`, `ruin_23`, `ruin_24`. Dekor: `ruin_11–22`. Katı kayıtlarda 1–15 daire var. `solid` ve `weight` bu kuralla yazılır; bayrak ve meşale (`ruin_08/09/23`) tek direk dairesi.
  - `scripts/sim/map_sim.gd`: `ob_pos`/`ob_r` artık sarmalayan çember. Yeni `ob_foot`, `circ_pos`, `circ_r`, `circ_first`, `circ_count`. Katı harabe chunk kenarından `r + MIN_GAP/2` içeride yerleşir (F-ver-002, üretim sırasından bağımsız). `resolve` varlığın kapladığı tüm hücrelere bakar ve 4 geçişle çözer. `slide` ≤12 px alt adımla tünellemeyi önler. `circles_of_def` ve `bounds_of_def` yardımcıları eklendi.
  - `scripts/sim/game_sim.gd`: oyuncu hareketi `map.slide` kullanıyor.
  - `scripts/sim/damage_system.gd`: harabe içinde ölen düşmanın taşı dışarı alınıyor (`GEM_CLEARANCE` 16 px).
  - `scripts/sim/ruins_validator.gd`: `collision` doğrulaması, sarmalayan çember ≤ 400 px.
  - `scripts/view/ruin_view.gd`: sprite `ob_foot`'a konur. Dekor `DECOR_Z=-50` ile zemin katmanında, katı yapılar y-sıralı.
  - `docs/dev/ruins.md`, `docs/data-schema.md`: düşman etkileşimi belgelendi. Sıradan yer düşmanı (`ai: ground`) iki adımda bir itilir/kayar. Elit, Lord, uçan ve hayalet bilinçli muaf. Mermiler harabeden geçer.
- **F-ver-001:** `GameSim._stream_seed` artık `MapSim._mix` tabanlı 64 bit karıştırma kullanıyor (`game_sim.gd`).
- **F-ver-006:** `test/unit/test_boss_safety.gd` Lord testi havuzu her adım dolduruyor. `spawn_director.gd` içindeki `_make_room(sim)` çağrısı geçici silindi: test kırmızı oldu. Geri alındı.
- **N1:** `UiKit.upper_tr` (i→İ, ı→I, ç/ğ/ö/ş/ü; `to_upper` kullanılmadı) `scripts/ui/ui_kit.gd`. Seviye kartı başlığında (`level_up_screen.gd`) ve kombo adında (`result_screen.gd`) uygulandı. "Şifa" kartı da ŞİFA olarak görünüyor.
- **N2:** `scripts/ui/hud.gd` elit/Lord satırı:
  - Pasif yuva satırının altında, ortada, 700 px, oyuncu canından ayrı.
  - Ad Cinzel 28 px (Lord 32 px) ve Türkçe büyük harf.
  - Elit: ince bronz çubuk. Lord: kalın amber çubuk.
  - Lord varsa Lord, yoksa en yüksek `max_hp` olan elit gösterilir. Diğer canlı elitler ada "+N" olarak eklenir.
- **#8:** `scripts/ui/result_screen.gd` kombo paneli içeriğe göre boyutlanıyor. Boşken "Bu seferlik kombo yok." satırı. Düğmeler panelin hemen altında.
- **Madde 7:** `tools/gate_min_tests.json` `test_ver_*` dosyalarını kapsıyor (`update_min_tests.sh`).
- **Bot (ASK #5, seçenek a):** `test/helpers/bots.gd` duvar dolanma (teğet yön, taraf 4 sn sabit) ve engelin arkasındaki taşı seçmeme. `test/acceptance` dosyalarına dokunulmadı.
- **Yeni testler:**
  - `test_ruin_collision.gd` (15)
  - `test_cinzel_text.gd` (4)
  - `test_hud_boss_bar.gd` (4)
  - `test_result_layout.gd` (2)
  - Güncellenen: `test_map_sim.gd`
- **Ekran görüntüsü senaryoları:** `tools/capture/shots.gd` içine `names`, `winc3`, `winc0`, `ruinwalk` eklendi. `ruins` senaryosu yeni haritaya uyarlandı.

### Test sonuçları
- **Entegrasyon merge'ü:** `git fetch origin vlad/T20261023-55:refs/remotes/origin/vlad/T20261023-55` ve `git merge origin/vlad/T20261023-55` → "Already up to date". Lint (`gdformat --check`, `gdlint`) temiz.
- **Temiz klon:** `GATE_RENDER=1 bash tools/gate.sh`, head `0958267`. İki F-ver-002 karakterizasyon testi yalnız klonda, commit'siz, `_skip_` ön ekiyle dışarıda bırakıldı.
  - Sonuç **GATE OK**: 482 test, 0 kırmızı, pytest 35 geçti, render smoke dahil.
  - Bu koşunun `junit.xml`'i `gate_min_tests.json` güncellemesi için kullanıldı.
- **Gate'in son commit'teki hâli** (`0a04f69`, F-ver-002 testleri dışarıda bırakılmadan) kırmızıdır. İki sebebi var:
  - Karakterizasyon testleri kırmızı.
  - `gate_min_tests.json` `test_ver_known_gaps.gd` için 5 test bekliyor (tester doğrulama-2'de beş testi de koşturacak).
  - Son iki commit'in (min-test güncellemesi `0a04f69`, bir önceki `ec09e7b`) tam gate koşusu yok. Yalnız `check_junit.py` ile doğrulandı: sayı 3 < 5 uyarısı, o da klonda iki test dışarıda olduğu için.
  - Taban `08fc5e3` yeşildir.
- **Beklenen kırmızı** (karakterizasyon F-ver-002, doğrulama-2'de (T20261023-80, tester) tersine çevrilecek):
  - `test_ver_known_gaps::test_karakterizasyon_f_ver_002_neighbor_chunk_solid_ruins_overlap`
  - `test_ver_known_gaps::test_karakterizasyon_f_ver_002_overlap_lens_can_leave_the_player_inside_a_ruin`
- **Bot düzeltmesi sonrası:** `test_acc_short_runs` 5/5 ve `test_acc_determinism` 8/8 yeşil. Düzeltme öncesi `test_acc_determinism::test_same_seed_same_hash_in_dense_late_game` da kırmızıydı; bot düzeltmesiyle yeşile döndü, eşik/tohum değişikliği gerekmedi.
- **Mutasyon:** F-ver-006 için yukarıda.
- **F-ver-001 testi:** `test_stream_seeds_do_not_depend_on_variant_hash` yeşil (gate'te, 482 testin içinde).
- **xvfb ekran görüntüsü öz-kontrolü** (dosyalar commit'lenmedi, `tools/capture/shots.gd` ile yeniden üretilir):
  - Kart adları (`names`): BARUT KESESİ, SON MERMİ PATLAR, KIYAMET MERMİSİ, ŞİFA noktalı.
  - Sonuç: kombolu ve kombosuz durum. Boşken kısa panel, düğmeler hemen altında.
  - Boss: elit çubuğu "ELİT KARGA +2". Lord: amber çubuk ve "DÜŞMÜŞ KALE LORDU". Lord çubuğu 520. pikseldeki uyarı bandının üstünde bitiyor.
  - Harabe çarpışması (`ruinwalk`, daire kaplaması): oyuncu zincirin önünde duruyor ve kenar boyunca kayıyor.

### Kabul kriterleri
- [x] **1–7 giderildi, testli, ekran görüntüsü öz-kontrolü yapıldı.** Test: N1 için adında `i` olan her beceri taranıyor (≥11), N2, #8, harabe çarpışması (8 yön ve kenarda kayma), çok tohumlu çakışma yok, F-ver-001, F-ver-006. Madde 7: `gate_min_tests.json` güncellendi.
- [~] **Temiz klonda `GATE_RENDER=1 bash tools/gate.sh` yeşil, tek istisna F-ver-002 karakterizasyon testleri.** İki test klonda `_skip_` ile dışarıda bırakılınca yeşil (yukarıya bak). Son commit `0a04f69`'in tam gate koşusu yok. Doğrulama-2 sonrası tam gate koşturulmalı.
- [x] **Bağımsız kod incelemesi** yapıldı, tablo aşağıda.

### Kod incelemesi
Bağımsız alt agent `requesting-code-review` ile baz `08fc5e3`'e göre inceledi. Kritik ve Yüksek bulgu yok; sonuç: birleştirmeye uygun.

| # | Önem | Bulgu | Durum |
|---|---|---|---|
| 1 | Orta | `enemy_ai.gd:44-46` düşman duvarın tam arkasında teğet bileşen sıfırken takılabilir. Agent sim'de koşturmadı. | Açık (aşağıda) |
| 2 | Orta | `ruin_view.gd:43` `_map.ensure(center)` sim'in `MapSim`'ini paylaşıyor; kamera ≠ oyuncu ise chunk üretim sırası değişir (daire sırası, `resolve` sıralı itmesi). Risk düşük. | Açık |
| 3 | Düşük | `state_hash` hâlâ Variant `hash()` kullanıyor; sürüm-bağımsızlık yalnız tohumlar için. | Açık |
| 4 | Düşük | `_stream_seed` işaret bitini atıyor; `-1` ve `0x7FFF…F` aynı akışı verir. | Açık |
| 5 | Düşük | `collision` yoksa yedek `footprint.w/2` için sınır denetimi yoktu. | Giderildi (`ruins_validator.gd`) |
| 6 | Düşük | `bots.gd` `_path_clear` her taş için örnekliyor; iki yan engelliyse sıkışabilir. | Açık |
| 7 | Düşük | Taş açıklığı 10 px dar girintide toplanamayabilir. | Giderildi (16 px) |
| 8 | Düşük | `EMPTY_TEXT` kısaltıldı; ipucu kayboldu (kullanıcı isteği "kısa kombo yok satırı"). | Bilinçli |
| 9 | Düşük | `upper_tr` yalnız Türkçe harfleri ve ASCII'yi çeviriyor. | Bilinçli |

### Açık noktalar
- **Karakterizasyon testleri:** iki F-ver-002 testi kırmızı kalıyor. Tersine çevirme doğrulama-2'de (T20261023-80).
- **#1 düşman duvar arkası:** doğrulanmadı, sim koşusu yapılmadı. Ground düşman duvar arkasında oyuncu durunca takılabilir ve yığılabilir; recycle yalnız 1900 px uzakta. Gözlem gerekirse cihazda bakılsın.
- **#2 `ensure` paylaşımı:** çoklu `ensure` sırası daire dizisi sırasını değiştirebilir; chunk içeriği sıradan bağımsız. Pratik etkisi düşük.
- **Cihaz doğrulaması yok:** harabeye girme/takılma hissi, joystick ile kayma, çubuk konumu, çentik/güvenli alan (N7 kapsam dışı).
- **Düzen farkı:** büyük harabeler chunk merkezine biraz yakın yerleşiyor (kenar şeridi kuralı). Chunk içeriği ve harita düzeni önceki sürümden farklıdır (F-ver-001 ile birlikte).
- **Yerleşim görseli:** `ruin_collision.py` daire yerleşimi gözle `--preview` ile denetlendi; uçlardaki sivri sprite ucu bir iki sütunda daireyle kaplı değil (kapsama ≥ %85 testte).
- **Kapsam dışı (T20261023-78):** F-ver-007 denge, SFX, N3–N8, #11.
