# T20261023-80 v1 doğrulama-2 — kapanış raporu

### Yapılanlar
- Entegrasyon: `git fetch origin vlad/T20261023-55:refs/remotes/origin/vlad/T20261023-55` + `git merge origin/vlad/T20261023-55` → "Already up to date".
- **F-ver-002 karakterizasyon testleri tersine çevrildi** (`test_ver_known_gaps.gd`): `test_f_ver_002_fixed_no_neighbor_chunk_solid_ruin_overlap` (20 tohum, 9×9 chunk, çapraz/aynı chunk çakışma = 0) ve `test_f_ver_002_fixed_player_is_never_left_inside_a_solid_ruin` (20 tohum, tüm daire merkezleri + 300 rastgele nokta/tohum, `resolve` sonrası daire içinde kalan = 0). Dosyada 5 test, `gate_min_tests.json` değeri 5 korundu.
- Yeni kabul testleri: `test_ver_solid_ruins.gd` (4), `test_ver_enemy_behind_ruin.gd` (2, bilinçli kırmızı).
- `gate_min_tests.json`: iki yeni dosya eklendi (4 ve 2).
- Bağımsız yeniden doğrulama (N1, N2, #8, F-ver-001, F-ver-006, uçtan uca, Lord, determinizm, kalabalık performansı): geliştirici ve önceki doğrulama testleri tam gate içinde koştu (aşağıda). Üretim kodu değiştirilmedi.

### Kapsam
| Alan | Test |
|---|---|
| F-ver-002 giderildi (çok tohum) | `test_ver_known_gaps` (2 ters çevrilmiş) |
| Katı harabe: 3 tohum × 4 harabe × 8 yön, GameSim ile yürüyüş; içeri girme yok | `test_ver_solid_ruins::test_player_never_enters_…` (12×8=96 yürüyüş) |
| Kenar boyunca kayma, titreme yok: 5 px/adım (normal) ve 15 px/adım (3×); 50 px/adım (10×) tünelleme yok | `test_ver_solid_ruins::test_slide_at_normal_speed…`, `…high_speed…` |
| Dekor geçilebilir; katı/dekor kuralı (görsel yükseklik ≥240 px) veriyle tutarlı | `test_ver_solid_ruins::test_decor_ruins_are_passable…` |
| F-ashen-bastion-020 ölçümü | `test_ver_enemy_behind_ruin` (2, kırmızı) |
| N1, N2, #8, F-ver-001, F-ver-006, uçtan uca, Lord, determinizm, kalabalık | mevcut `test_cinzel_text`, `test_hud_boss_bar`, `test_result_layout`, `test_ruin_collision::stream_seeds`, `test_boss_safety`, `test_ver_end_to_end`, `test_ver_boss_lord`, `test_ver_determinism_full`, `test_ver_crowd_perf`, `test_acc_determinism` (gate'te yeşil) |
- Karakterizasyon (F-xxx) olarak kalan testler: F-ver-003 (SFX yok) ve F-ver-004 (HUD güvenli alan) — değişmedi. F-ver-002 artık karakterizasyon değil, düzeltme testi.

### Bulunan hatalar
| # | Önem | Bulgu |
|---|---|---|
| F-ver2-001 (= F-ashen-bastion-020) | **Orta–Yüksek** | Sıradan yer düşmanı (`curumus_piyade`), oyuncu–düşman doğrultusu katı harabenin sarmalayan çemberinin merkezinden geçerken harabenin arkasında **kalıcı takılıyor**. Sim ölçümü (seed 1,2,3; her biri 14 katı harabe, oyuncu sabit ve ölümsüz, düşman canı sonsuz, 25 sn): **tek düşman 14/42 durumda (%33) oyuncuya hiç ulaşmadı**; takılanlar oyuncuya 380–580 px kala duruyor, son 5 sn'de yer değişimi ≈1,6 px (yani sabit). **8'li grup 21/42 durumda (%50) tümü ulaşamadı**; takılan düşmanlar harabe yüzünde yığılıyor. Takılma yok durumundaki ilk temas 5–15 sn. Kök neden (`enemy_ai.gd:44-46`): düşman doğrudan oyuncuya yürür, `resolve` itmesi yalnız daire normali yönündedir; hedef yönü normal ile hizalıyken teğet bileşen sıfır olduğundan düşman kayamaz. Etki: harabe arkasında durarak (bot da) düşmanları etkisiz bırakmak mümkün, kalabalık baskısı yapay düşer. Kapsam: yalnız katı harabe zinciri (ob_r içindeki geniş çemberler, merkez doğrultusu); gerçek oyunda oyuncu hareketli olduğu için süre kısalır. Sabit durma/kamp sırasında ortaya çıkar. |
| F-ver2-002 | Düşük | 10× hızda (50 px/adım, gerçekçi değil) duvara yaslanırken 12 harabeden 3'ünde yön titremesi. 3× hızda (15 px/adım) ve normalde (5 px/adım) yok. Bilgi amaçlı, test sadece 3×'i iddia ediyor. |
Kritik 0, yüksek 0 (F-ver2-001'in yüksek sayılıp sayılmayacağı VLAD/ürün kararı: oyuncu bir harabenin arkasına geçip düşmanları kilitleyebiliyor).

### Kırmızı bırakılan testler
- `test_ver_enemy_behind_ruin.gd::test_f_ashen_bastion_020_single_ground_enemy_reaches_player_from_directly_behind_solid_ruin` (14/42 takılı)
- `test_ver_enemy_behind_ruin.gd::test_f_ashen_bastion_020_enemy_group_reaches_player_from_directly_behind_solid_ruin` (21/42 takılı)
- Bu yüzden branch'te gate **kırmızıdır** (yalnız bu iki test). Üretim düzeltmesiyle yeşile döner.

### Test sonuçları
- Temiz klon (head `bad07e6`, F-020 testleri dahil), `GATE_RENDER=1 bash tools/gate.sh`: lint, veri, pytest 35 geçti; GUT 490 test, 488 geçti, **2 kırmızı (yalnız F-020)** → `GATE FAIL: GUT çıkış kodu 1`.
- Temiz klon, yalnız `test_ver_enemy_behind_ruin.gd` klonda silinerek (commit'siz): `GATE_RENDER=1 bash tools/gate.sh` → **GATE OK**, 488 test, 0 kırmızı, min-test denetimi ve render smoke dahil.
- Tek commit'lik son `gate_min_tests.json` güncellemesi bu ikinci koşuda doğrulandı (klonda F-020 girdisi çıkarıldı).

### Kabul kriterleri
- [x] F-ver-002 testleri tersine çevrildi; temiz klonda gate sonucu yukarıda.
- [~] "Kırmızı test yoksa gate tam yeşil": kırmızı test **var** (F-020, bilinçli); onsuz gate tam yeşil.
- [x] Doğrulama raporu ve güncel cihaz listesi.

### Denge gözlemi
Sayılara dokunulmadı; `tools/balance/sim_run.gd`, 4 tohum, yeni harita düzeni, ölümlü (bot naif).
| Politika | Sonuç |
|---|---|
| kite | 4/4 öldü: 533 / 675 / 577 / 631 sn (seviye 7–11, en çok eşzamanlı düşman 114–219) |
| smart | 3 öldü (619 / 619 / 517 sn), 1 kazandı (seed 3, 1364 sn, düşük can oranı 0,45) |
Önceki doğrulamada hedef-yönelimli bot 6 koşunun 3'ünü kazanmıştı; burada 4'ün 1'i. Bot ve harita düzeni farklı (F-ver-001), küçük örnek: kesin değişim iddiası yok. F-ver-007 backlog'da (T20261023-78).

### Önerilen düzeltmeler
1. **F-ver2-001:** `enemy_ai.gd` yer düşmanı için teğet yön: `resolve` düşmanı ittiğinde (konum değişimi > eşik) düşmana sabit bir kayma yönü (id'ye göre sol/sağ) ver ve birkaç adım o yönde bir kayma bileşeni ekle; ya da hedef yönünü daire normali ile hizalıyken küçük sabit sapma uygula. Doğrulama: `test_ver_enemy_behind_ruin` yeşile dönmeli.
2. F-ver2-002 isteğe bağlı (gerçekçi olmayan hız).
3. Kod incelemesi #2/#6 (açık, düşük) izlemede.

### Cihaz kontrol listesi
1. Debug APK kurulumu (CI artifact `ashen-bastion-debug-apk`); menü Türkçe harfler, "ASH AND STEEL" başlığın üstüne sığıyor.
2. Tam oyun akışı: joystick, ateş, şarjör tamburu + `↻` halkası, XP taşı, seviye atlama (500 ms kilit), evrim kartı en altta, duraklat/geri tuşu/arka plan duraklatma, TEKRAR OYNA/ANA MENÜ.
3. 5/10/15. dk "ARA BOSS YAKLAŞIYOR" bandı + elit; 20. dk "KALE LORDU GELİYOR"; Lord'u yenince KAZANDIN + "Şafak söktü; kale seni yutamadı."; ölümde OYUN BİTTİ + "Kale seni yuttu." ve kombo listesi.
4. **Yeni — Katı harabeler:** yüksek yapılara (kule, bayrak, meşale direği) joystick ile 8 yönden gir; içinden geçilmemeli, kenarda kayma akıcı olmalı, takılma/titreme yok. Alçak (dekor) harabelerden geçilebiliyor.
5. **Yeni — Düşman/harabe:** harabeyi arkana alıp dur; düşmanlar yanından dolanıyor mu yoksa arkasında yığılıyor mu (F-ver2-001'in cihaz karşılığı).
6. **Yeni — Seviye kartı/sonuç yazıları:** adında `i` olan kartlar İ ile (ŞİFA, BARUT KESESİ, KIYAMET MERMİSİ…), kombo adları büyük harf.
7. **Yeni — Elit/Lord çubuğu:** pasif yuvaların altında ortada; elit ince bronz, Lord kalın amber; ad okunur (≥26 px); Lord çubuğu uyarı bandının üstünde; "+N" eki.
8. **Yeni — Sonuç paneli:** kombosuz durum ("Bu seferlik kombo yok.") kısa panel + düğmeler hemen altında; 5 kombo ekrana sığıyor.
9. Görünüm: rim konturu, oyuncu ~200 px okunur, çentik/güvenli alan (yan ≥36 px), joystick (ölü bölge 24, yarıçap 195), dokunma hedefleri.
10. Debug etiketi `düşman N/M taş N/M` (F-002 cihazda çözüldü; kontrol amaçlı ~2 dk).
11. Stres ölçümü: menüde sürüm etiketine 3 dokunuş → 60 sn; p95 ≤16,7 ms; geç oyun (15+ dk) kalabalığı akıcı mı.
12. Ses: müzik döngüsü, geçişler, boss uyarısında kısma; SFX hâlâ yok (beklenen); titreşim.
13. Denge hissi (kullanıcı kararı bekliyor): geç oyun tehdidi (F-ver-007, backlog), Lord zorluğu.
14. APK imzalama (release) ve aynı anahtarla güncelleme.

### Açık noktalar
- F-ver2-001 düzeltilene kadar gate kırmızı (2 test); düzeltme sonrası `tools/update_min_tests.sh` gerekmez (sayılar zaten girildi).
- Ölçüm sabit oyuncu ve ölümsüz düşman ile yapıldı; hareketli oyuncuda takılma süresi/oranı cihazda gözlenmeli.
- Ekran görüntüsü/render testleri bu turda yeniden çekilmedi (render smoke geçti); cihaz doğrulaması, FPS, APK imzalama, ses duyumu koşulmadı.
- Kapsam dışı (T20261023-78): F-ver-007, SFX, N3–N8, #11.
