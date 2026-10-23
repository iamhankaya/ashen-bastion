# T20261023-62 v1 uygulama-2 — kapanış raporu

### Yapılanlar
**F-ashen-bastion-002 (A+B+C)**
- **A:** `scripts/view/render_fix.gd` her kare değişen AABB yerine sabit kesme dikdörtgeni kuruyor (`canvas_item_set_custom_rect`). `enemy_renderer.gd`, `gem_renderer.gd` ve `projectile_renderer.gd` içinde `apply_cull_fix()` çağrılıyor.
- **B:** `scripts/ctrl/game_controller.gd:120-170` (`_build_render_debug`) yalnız debug derlemede çalışıyor. Etikette `düşman N/M taş N/M` ve `kesme düzeltmesi: AÇIK|KAPALI (dokun)` yazıyor, dokunmak düzeltmeyi açıp kapatıyor. Ayar `Settings.cull_fix` ile saklanıyor.
- **C:** `test/unit/test_render_cull.gd` 600 adım koşturup her adım sonrası `visible_count == canlı sayı` ve buffer konumlarının canlı konumlara eşit olduğunu denetliyor. Toplama ile ölümün aynı adımda olması dahil, düzeltme açık ve kapalı iki durumda da çalışıyor.

**Denetim bulguları**
- **#1 ve #5 (kontrast):** düşmanlara ve oyuncuya açık kontur (rim) eklendi. `assets/shaders/rim.gdshaderinc`, `enemy_flash.gdshader`, `player_sway.gdshader`, `rim_sprite.gdshader`. `test/unit/test_contrast.gd` gerçek zemin dokusuna karşı her düşman türü ve oyuncu için ≥3:1'i doğruluyor. Oyuncu boyu 112 px'ten 200 px'e çıktı.
- **#2:** joystick sabitleri `scripts/ctrl/input_gate.gd:9-13` içinde (`MAX_RADIUS` 195, `DEAD_ZONE_PX` 24). Taban çapı `virtual_joystick.gd` içinde bunlardan türüyor.
- **#3:** güvenli alan `UiKit.safe_extra` ve `get_display_safe_area()` ile uygulanıyor. Yan boşluk ≥36 px, kalp x=30 dışında kalan öğeler ≥36 px. `hud.gd` içinde `Safe` katmanı var.
- **#4:** pause düğme sütunu aşağı alındı (`pause_screen.gd`: `offset_top` 380, `gap` 170).
- **Düşükler:**
  - #6: süre etiketi aşağı alındı.
  - #7: joystick HUD'ın altında çiziliyor.
  - #9: anahtar düğmeleri eşit genişlikte.
  - #10: duraklat düğmesinde odak, seviye atlamada ilk kartta varsayılan odak.
  - #8 ve #11'e dokunulmadı.
- **Temas çarpanı:** artık tick anında hesaplanıyor (`damage_system.gd`, `game_sim.gd:spawn_enemy`). Testi `test/unit/test_damage.gd` içinde.

**Oyun içeriği**
- **Beceriler:** 5 aktif (`yelpaze_atis`, `dinamit`, `doldurma_sacilmasi`, `sarapnel`, `keskin_nisan`) ve 4 evrim (`zincirleme_patlama`, `kiyamet_mermisi`, `mermi_firtinasi`, `gurleyen_yelpaze`) davranış ve JSON olarak eklendi. Şarjör ritmiyle etkileşen 7 beceri `rhythm` etiketli.
- **Düşmanlar:** 4 yeni kayıt (`elit_piyade`, `elit_sovalye`, `elit_karga`, `kale_lordu`). Elit karga 4 sn'de bir 0,8 sn şarj atıyor. Lord 8 sn'de bir 12 piyade çağırıyor, canı %50'nin altına inince hız ×1,4 ve çağırma 5 sn oluyor. Kod `scripts/sim/enemy_ai.gd`.
- **Doğurma:** `spawn_director.gd` halka dalgalarını (480/720/960), boss uyarısı (5 sn önce) ve doğuşu, `after_lord` ve `skip_to` semantiğini yönetiyor.
- **Lord ölümü:** `game_sim.gd:_phase_status` içinde `hp<=0` kontrolünden önce WON yapıyor. Oyun artık 20 dk `lord` modunda (`game_controller.gd`).
- **Veri:** `data/waves.json` satır 4–6, `data/ruins.json` (24 harabe).

**Görseller ve efektler**
- **Sanat hattı:** `tools/art/*` ve `assets/gfx/**`, yeşil arka plan temizliği dahil. Alt agent yazdı, ben merge ettim ve ek olarak `ana_gorsel` ekledim.
- **Düşmanlar:** `EnemyAtlas` + tek MultiMesh. Kargalar 3 kareli kanat animasyonuyla çiziliyor.
- **Karakter rig'i:** `player_view.gd` gerçek gövde ve kol dokularıyla çalışıyor. Omuz, pivot ve namlu değerleri `data/characters/gunslinger.json` içinde. Atkı ve palto dalgası `player_sway.gdshader` ile, rim ve sıcak ışık eklendi. `PlayerRig.solve_aim` namlu çıkışını hedefle hizalıyor.
- **Zemin ve harita:** zemin gerçek dokuyla karartılarak çiziliyor. Harita `MapSim` (chunk üretimi, engel itme) ve `RuinView` ile çalışıyor.
- **Efektler:** `fx_renderer.gd` patlama, keskin nişan çizgisi, ölüm tozu ve XP kıvılcımını çiziyor. `atmosphere.gdshader` sis, vinyet ve oyuncu ışığını veriyor.
- **UI:** menüde ana görsel, 12 yeni SVG ikon, HUD'da elit/Lord can çubuğu.

**Ses**
- `tools/audio/process_audio.py` 7 parçayı 44,1 kHz, −18 LUFS ve döngü crossfade ile `assets/audio/music/*.ogg` olarak üretiyor.
- `MusicPlan`, `AudioDirector` (crossfade, boss uyarısı + kısma, duraklatmada −8 dB) ve `Sfx` havuzu hazır. SFX dosyası olmadığı için sessiz, dosya konunca çalar. `LICENSES-audio.md` yazıldı.

**Araçlar ve belgeler**
- `tools/capture/shots.gd` (ekran görüntüsü aracı), `tools/balance/sim_run.gd` (bot denge koşusu).
- `docs/dev/user-verify.md` ve `docs/dev/perf.md` güncellendi; ruins.json `docs/data-schema.md` içinde.
- `export_presets.cfg`: `include_filter="*.json"` eklendi, aksi halde veri dosyaları APK'ya girmeyebilir.
- Entegrasyonla gelen `vlad/T20261023-55` değişikliklerine (release hattı) dokunmadım.

### Test sonuçları
- **Temiz klon:** `git clone` ardından `GATE_RENDER=1 bash tools/gate.sh` → **GATE OK**. 411 test, 0 kırmızı, 0 pending (başlangıçta 366 test, 24 pending). Render smoke dahil geçti.
- **pytest:** `tools/ci/tests`, `tools/art/tests`, `tools/audio/tests` → 33 geçti.
- **Entegrasyon merge'ü:** `git fetch origin vlad/T20261023-55:...` ve `git merge origin/vlad/T20261023-55` çakışmasız (9b5703e). Ardından lint + gate yeşil.
- **Lint:** `gdformat --check` ve `gdlint` temiz.
- **Ekran görüntüsü öz-kontrolü** (xvfb + opengl3, commit'lenmedi): menü, oyun, kalabalık, harabe, boss, Lord, seviye atlama, duraklatma, kazandın, kaybettin, kontrast. Konsol hatası yok. Bulgu ve düzeltmeleri bu raporda.
- **Bot koşuları** (gate dışı, `tools/balance/sim_run.gd`, tohum 1–4):

| Politika | Ölüm süresi | Not |
|---|---|---|
| idle | 155–198 sn | hedef aralıkta |
| kite | 477–667 sn | |
| greedy | ~313–326 sn | |
| smart | 581–917 sn | 4 koşuda 1 evrim, hiçbiri 20. dk'ya ulaşmadı |

  Botlar naif; gerçek oyuncu bu rakamlardan daha iyi olur. Lord dövüşü botla ölçülmedi.
- **Koşulmadı:** cihaz (FPS, dokunma, çentik, shader derlemesi), APK derleme ve imzalama (`GATE_EXPORT`), `GATE_NIGHTLY` (20 dk koşu, sızıntı, 100 tohum dağılımı), ses duyum kontrolleri.

### Kabul kriterleri
- **Baştan sona oyun; kabul testleri yeşil; gate yeşil:** karşılandı. Cihazda elle oynanış kullanıcıda.
- **Ara denetim kritik/yüksek bulguları:** karşılandı. Kritik 0; yüksek #1 testle ve ekran görüntüsüyle kapandı. Orta #2, #3, #4 ve #5 yapıldı. Düşük #8 ve #11 yapılmadı.
- **F-ashen-bastion-002 için A+B+C:** kod ve test olarak karşılandı. Cihazda düzeltmenin gerçekten işe yaradığı kullanıcıda doğrulanacak.

### Kod incelemesi
Bağımsız alt agent `dbffc4f..HEAD` farkını inceledi, ben düzeltmeleri `eca8df6`'da yaptım.

| Bulgu | Önem | Durum |
|---|---|---|
| Havuz doluyken Lord doğmuyor, oyun kazanılamıyor | Kritik | Düzeltildi: doğuş rezervi (24 slot), Lord için en uzak sıradan düşmanı sessizce kaldırma, atlanmış Lord satırı artık doğuyor. Testi `test_boss_safety.gd`. |
| `gurleyen_yelpaze` elit ve Lord'u geri itiyor | Önemli | Düzeltildi: elitler itilmiyor. |
| `Targeting.pick` her tick tahsis yapıyor | Önemli | Düzeltildi: ortak sorgu tamponu. |
| `state_hash` AI durumunu ve doğuş ilerlemesini kapsamıyor | Önemli | Düzeltildi. |
| Harita tohumu `hash([...])` ile sürüm/platform bağımlı | Önemli | Düzeltildi: elle yazılmış tamsayı karıştırma. |
| Komşu chunk'lardaki katı harabeler çakışabiliyor | Önemli | Düzeltilmedi (aşağıda). |
| `sim_run.gd` Lord'u ölçemiyor | Önemli | Düzeltildi: 1500 sn'ye çıkarıldı. |
| Şarj durumu okuma sırası, `audio_lib` sınır durumları, ölü dal | Küçük | Düzeltildi. |
| HUD güvenli alan yeniden uygulanmıyor, `cell_rect[16]` sınırı, `OS.delay_msec(150)` | Küçük | Düzeltilmedi; belgelendi. |

### Açık noktalar
**Kullanıcı kararı bekleyenler (değiştirilmedi):**
- Kazanma alt başlığı "Şafak söktü; kale seni yutamadı." artık Lord galibiyetinde de gösteriliyor. Tasarımdaki "Düşmüş Kale Lordu devrildi." kullanılmadı.
- Menüdeki "KÜL VE ÇELİK" üst yazısı duruyor.
- Müzik lisansı: kaynak ve ticari kullanım hakkı kullanıcıya ait (repo public).
- Rim konturu bilinçli bir görsel tercih. Kalabalıkta hat çok belirgin; cihazda beğenilmezse kalınlık veya renk `EnemyRenderer.RIM_*` sabitlerinden ayarlanır.

**Cihazda doğrulanacaklar:**
- Düşman ve XP taşı kaybolması (F-002): debug APK etiketiyle düzeltme açık/kapalı karşılaştırması (`docs/dev/user-verify.md` §5).
- FPS ve p95. Sim süresi U1'e göre ≈3,5 → ≈4,5 ms/adım çıktı. xvfb yazılım GL'de stres koşusu ≈133 ms/kare, cihazı temsil etmez.
- Rig pivotları ve namlu hizası, rim görünümü, shader derlemesi, güvenli alan ve çentik, dokunma hissi.
- Ses: döngü dikişi, geçişler, boss uyarısında kısma.
- APK derlemesi ve imzalama.

**Bilinen eksikler:**
- **SFX yok.** Atış, doldurma, patlama ve XP çınlaması sessiz yer tutucu. İndirme yapılmadı, `assets/audio/sfx/<kimlik>.ogg` konunca çalar.
- **Denge:** botlar 20. dakikaya ulaşamadı. Plan tabloları test altında olduğu için sayılara dokunmadım, ayar kullanıcı geri bildirimiyle yapılacak.
- **Harita:** komşu chunk sınırında iki büyük harabe birbirine geçebilir. Çizim çakışır, oyuncu veya düşman kesişimde sıkışıp titreyebilir. Düşmanlar harabelerin üstünden değil altından çiziliyor (planlı sınır). Elit ve Lord engelden etkilenmiyor.
- Çok kareli sprite hücre sayısı shader'da 16 ile sınırlı (şu an 6 kullanılıyor).

**Varsayımlar ve sapmalar:**
- Oyuncu `display_height` 200, `BODY_ASPECT` 0.553, `ARM_ASPECT` 0.296 (gerçek görsel oranları), omuz, pivot ve namlu değerleri görselden elle okundu.
- `GameSim` artık hedefsizken her adım hedef arıyor (gecikmesiz ilk atış). Lord'un ilk çağırması doğuştan ~3,2 sn sonra (`ai_timer` ×0,4).
- `Difficulty.alive_cap` değişmedi; doğuş yöneticisi sürekli doğuşta 24 slot rezerv bırakıyor (en çok 376 düşman).
- `tools/gate.sh` render smoke adımına `--audio-driver Dummy` ve `--quit-after 60` eklendi. ALSA yokken hata veriyordu, kapanış yarışı da vardı.
- `test_contract_*` birim testleri uygulanan becerilere göre güncellendi, yeni testler eklendi. Kabul testlerine dokunulmadı.
- Güvenlik etkisi yok; yalnız standart debug anahtarı (`tools/ci/debug.keystore`) repoda, release anahtarı yalnız GitHub secret'ta. İncelemede sır bulunmadı.

## Ek iş (kullanıcı kararları; PR #9)

### Yapılanlar
- **Menü yazısı:** üst yazı "KÜL VE ÇELİK" yerine "ASH AND STEEL" oldu (`scripts/ui/main_menu.gd:89`). Cinzel fontunda glif sorunu yok, yazı başlığın üstüne tam sığıyor. Test veya belgelerde eski metne bağlı bir yer çıkmadı.
- **Rim konturu ~%30 inceltildi:**
  - Düşman: 2,2 → 1,5 px (`enemy_renderer.gd`).
  - Elit ve Lord: 3,6 → 2,5 px.
  - Oyuncu ve kollar: 3,0 → 2,1 px (`player_view.gd`).
  - Düşmanda kalınlığın alt sınırı 2,0 → 1,0 doku pikseline indi, yoksa küçük sprite'larda azalma görünmüyordu.
- **Kazanma alt başlığı:** "Şafak söktü; kale seni yutamadı." aynen duruyor.
- **Entegrasyon:** `git fetch origin vlad/T20261023-55:...` ardından `git merge origin/vlad/T20261023-55` fast-forward oldu (5da40df).

### Test sonuçları
- **Temiz klon:** `git clone` ardından `GATE_RENDER=1 bash tools/gate.sh` → **GATE OK**, 411 test, 0 kırmızı, render smoke dahil.
- **`test_contrast.gd`:** ≥3:1 eşiği yeşil. Test renk oranlarına bakıyor, kalınlığa değil; kalınlığın etkisi ekran görüntüsünde kontrol edildi.
- **Ekran görüntüsü öz-kontrolü** (xvfb + opengl3, commit'lenmedi): menü ve kalabalık sahnesi.
  - Başlık yazısı doğru görünüyor ve genişlik sorunu yok.
  - İnce kontur kalabalıkta ve oyuncuda hâlâ zeminden net ayrışıyor.
- **Koşulmadı:** cihaz, APK imzalama, `GATE_NIGHTLY`.

### Açık noktalar
- Kalabalıkta kontur hâlâ belirgin. Daha fazla incelmesi istenirse `EnemyRenderer.RIM_SCREEN_PX`, `RIM_ELITE_SCREEN_PX` ve `PlayerView.RIM_SCREEN_PX` değerlerini düşürmek yeterli; en ince noktada 3:1 eşiği renk oranından geldiği için yeşil kalır.
- Önceki rapordaki cihaz doğrulamaları ve bilinen eksikler (SFX yok, harita chunk sınırı çakışması, denge) aynen geçerli.
