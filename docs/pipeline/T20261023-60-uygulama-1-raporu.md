# T20261023-60 uygulama-1 — kapanış raporu (onaylı, PR #5)

### Yapılanlar
(Bulut çalışanı REPORT #4, branch vlad/T20261023-60 head `057e713`; VLAD tarafından işlendi.)
İlk oynanabilir dilim (U1-1…U1-11): hareket → ateş/doldurma → öldür → XP → seviye atla → seç; görseller geçici.
- Sim çekirdeği `scripts/sim/**`: game_sim (10 aşamalı sabit adım, ateş, çarpışma, seviye kuyruğu, oyun sonu, doğurma, debug kancaları, SkillApi), havuzlar, spatial_hash (1024 kova), magazine, stat_block, targeting, damage_system, loadout (6+6, evrim, roll_choices), spawn_director, enemy_ai, xp_curve, difficulty, player_rig (namlu tek kaynak); beceriler cift_tabanca, seken_mermi, son_mermi_patlar, zincirleme_patlama.
- Veri: 3 düşman, 3 aktif + 8 pasif, waves satır 1–3, gunslinger.
- Performans: stres senaryosu (400 düşman + ~500 mermi), cihaz içi 60 sn koşu → user://perf.json (ana menüde sürüm etiketine 3 dokunuş, yalnız debug), micro ölçüm, perf_budget.json, docs/dev/perf.md.
- Görünüm/UI/kontrol (alt agent): tür başına MultiMesh, INSTANCE_CUSTOM gl_compatibility'de çalıştı; tema, fontlar, ikonlar; input_gate, pause_logic, game_controller; JoystickView (yerleşik sınıf çakışması).
- Settings (JSON), ses köprüsü (sessiz), bus düzeni Master→Music/SFX/UI; docs/dev/user-verify.md.
- Debug APK hattı: export_presets, ensure_android_sdk, ci.yml export-debug işi (standart debug keystore), artifact ashen-bastion-debug-apk.
- 17 yeni birim test dosyası; sözleşme testleri gerçek gövdelere göre güncellendi.

### Test sonuçları
- gate (çalışma kopyası ve temiz klon, 057e713): GATE OK — 366 test: 342 geçti, 24 pending (slice 2), 0 kırmızı.
- selftest_gate.sh: SELFTEST OK.
- GitHub Actions run 39953473007 (057e713): test, selftest, export-debug success; APK artifact 30,6 MB, apksigner verify geçti.
- 300+ düşman (400 düşman + ~500 mermi): deterministik sayaçlar tavan altında (hash_inserts 400/500, hash_queries 501/640, cells_scanned 2079/2650, collision_tests 215/470, enemy_updates 400/500, proj_updates 500/630). Bilgi: headless ≈2,5–3,0 ms/adım (en kötü ≈9,5 ms); xvfb yazılım GL 29,5 FPS ort., 144 draw call (cihazı temsil etmez).
- Ekran görüntüsü öz-kontrolü (xvfb, commit'lenmedi): menü, HUD, doldurma, seviye atlama, duraklatma, oyun bitti, kazandın, stres; konsol hatası yok.
- Koşulmadı: cihaz (FPS, dokunma, çentik, shader), GATE_RENDER/NIGHTLY.

### Kod incelemesi
Bağımsız alt agent: kritik 1 (stres ölçümü hemen serbest bırakılıyordu — düzeltildi), önemli 5 (çift tabanca faz kaybı, sıcak yol tahsisleri, oyun sonu/XP sırası, perf_budget denetimsizdi — düzeltildi; enemy_type — ASK #3 ile onaylı), küçük 5 (portre APK'da yoktu — düzeltildi; temas hasarı çarpanı doğma anında, Lord önceliği U2, taş birleştirme O(CAP), negatif id — açık nokta).

### Kabul kriterleri
- Oynanabilir döngü: karşılandı (cihazda el ile oynanış kullanıcıda).
- CI yeşil, debug APK, gate yeşil: karşılandı.
- Ekran görüntüleri + performans ölçümü: karşılandı (cihaz FPS'i kullanıcıda).

### Açık noktalar
1. Sapmalar: enemy_type; zincirleme_patlama U1'e çekildi (veri kaydı U2-3); evrime dönüşen ham aktif yeniden önerilmiyor; şarjör dolunca ilk kurşun bir adım sonra; perf_budget düz sözlük; run_ended anahtarları time/level/kills/evolutions.
2. SkillRegistry: 4 davranış gerçek, 8'i Stub (U2).
3. Temas hasarı çarpanı doğma anında (plan tick anı diyor) — karar gerekebilir.
4. Lord modu/kazanma önceliği U2.
5. Cihazda: FPS/p95, ısınma, shader, dokunma, çentik, rig pivotları.
6. Kazanma alt başlığı "Şafak söktü; kale seni yutamadı." (alt agent seçimi); oyuncu display_height 112 küçük olabilir.
7. Ana menüde ana görsel yerine amblem (U2-6).
8. Kart `›` işareti (fontta ok yok).
9. Ses çalma katmanı yok (U2-8); CC0 SFX bulutta indirilemedi, synth_sfx.py yedeği.
10. Güvenlik etkisi yok; yalnız standart debug anahtarı.
11. .import/.uid dosyaları commit'lendi.

## VLAD notları (kullanıcı onayı bekleyenler)
- Temas hasarı çarpanı tick anında hesaplanmalı (plan); uygulama-2'ye girer (VLAD önerisi).
- Kazanma alt başlığı "Şafak söktü; kale seni yutamadı." kullanıcı onayı bekliyor.
