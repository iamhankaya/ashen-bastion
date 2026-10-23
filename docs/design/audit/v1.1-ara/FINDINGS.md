# Ashen Bastion v1.1 — Ara denetim (D1 sonrası, entegrasyon `2de5677`)

Görev: T20261023-93 · Denetçi rolü: Senior Designer · Tarih: 2026-10-23
Kapsam: D1 (animasyon, gölge, hayalet, FX) + D2 (eklentiler, rozetler, ekran dışı ok, ∞ tambur, bomba) + D3 (skor bloğu, SERİ çipi, sonuç, En İyi Skorlar, menü düğmesi) görünümleri ↔ `docs/design/v1.1/DESIGN.md` + `mock/`.
Dışında: bilinen kullanıcı kararları (omuz sapması ≈17 px; F-021 kaçış 22–36 sn) ve F-ashen-bastion-022 tekrar edilmedi.

## Yöntem

- Godot 4.7.2, `xvfb-run` + `--rendering-driver opengl3` (Mesa llvmpipe), 1080×2400 dikey. Repo betikleri `tools/capture/shots.gd`, `shots_pickups.gd` + kendi senaryolarım (`capture/cap_a.gd.txt`, `capture/mont.py.txt`; üretim koduna dokunulmadı).
- Animasyon: `GameController` `set_process(false)` ile 1/60 sn'lik sabit adımla sürüldü (sim adımı + `_update_views`); kare dizileri `screens/S*.png`. Sayısal okuma: `PlayerAnim` alanları (bob, rot, sx, sy, hit) her karede basıldı.
- Çentik/güvenli alan: `apply_safe_area(Vector4(48,130,48,80))` (HUD, menü, skor ekranı).
- Ekran görüntüleri depo boyutu için **720×1600'e küçültülüp** paletlendi (`screens/NN-*.png`); bulgulardaki koordinatlar **orijinal 1080×2400** pikselidir (görüntü koordinatı × 1,5).
- Ölçüm: `anim_micro.gd` (headless) + kodda sabit okuması. **Cihaz yok**: view_ms, gerçek çentik, his → "Açık noktalar".

## Sonuç özeti

D1–D3 genel olarak tasarıma **sadık**: gecikmeler, hasar parlaması, bob/eğim, bomba fitili, rozet/∞ tambur, skor dökümü, rekor bandı, liste ve menü maketle örtüşüyor. **Kritik/yüksek bulgu yok.** 4 orta, 5 düşük bulgu var; en önemlileri: gölgenin zayıf okunması (V-01, "süzülme" çözümünün temel taşı), yüzen metinlerin üst üste binmesi (V-02) ve çentikli cihazda "KALE LORDU GELİYOR" bandının HUD'u örtmesi (V-03).

### Tasarıma uyduğu doğrulananlar (kanıtlı)

| Kontrol | Ölçüm | Beklenen |
|---|---|---|
| Ölüm → sonuç gecikmesi | 78 adım = **1,30 sn** | 1,3 sn (§1.6, P12) |
| Kazanma → sonuç gecikmesi | 109 adım = **1,82 sn** | 1,8 sn (E10) |
| Oyuncu yürüme sekmesi | bob **9,0 px** zirve, sx 1,05/sy 0,93 temas, sx 0,97/sy 1,04 havada | 9 px, 1,05/0,93 (P2) |
| Gövde eğimi | rot 0,07–0,14 rad (4–8°); dönmede 3 adımda (≈50 ms) `turn_x` 1→−1 | 6°±2°, 70 ms (P3/P4) |
| Duruş nefesi | sy 1,000→1,015, 2,4 sn | P1 |
| Hasar tepkisi | beyaz parlama **5 adım ≈ 83 ms**, sx 1,10/sy 0,91, bordo ton ~200 ms | 90 ms, 1,10/0,90 (P10) |
| Hasar parlaması sıklığı | `HIT_FLASH_GAP` 0,34 sn ≈ **2,9/sn** | ≤3/sn, ≥150 ms (§1.1-6) |
| Yanıp sönmeler | rozet/eklenti `BLINK_HZ` 2,5; nadir nabız 1,4 Hz | ≤3 Hz (§2.2, §2.4) |
| Bomba fitili | halka+dolgu büyür, patlama **48. adımda** (0,8 sn), önizleme halkası patlamada kapanır | K8, §2.5 |
| Toplama toast | "+25 CAN" Cinzel ~44 px, yükselir, `+` parçacıkları | §2.3 |
| ∞ tambur | polyline ∞, 6 yuva amber, amber halka | §2.4 |
| Menü / En İyi Skorlar / sonuç | düğmeler ≥132 px; GERİ başparmak bölgesinde; sonuç düğmeleri y>1500 | §3.3, §3.5, §6 |
| Perf (masaüstü, 300 düşman) | enemy_refresh 0,65 ms ort / 1,18 ms en kötü; player_view 0,05; fx 0,015; hayalet 0,10 | ≤0,4 + 0,15 ek (perf.md; cihaz temsil etmez) |

Bilinen etkiler (tekrar bulgu değil): **omuz sapması** — yürüme şeridinde (`S1-yurume.png`) tabancalar gövdeye göre gözle fark edilir kayma yapmıyor; yedek bob'la görünüm kabul edilebilir, kare gelince (D4) yeniden ölçülmeli. **F-021** — ekran görüntülerinde etkisi yok.

## Bulgular

| # | Önem | Ekran | Bulgu | Kanıt | Beklenen (DESIGN.md) |
|---|---|---|---|---|---|
| V-01 | **Orta** | Oyun — düşman yer gölgesi | Düşman gölgesi koyu zeminde zor okunuyor: gölge pikselleri ortalama yalnız **%24 koyulaşıyor** (oran 0,76; lum ≈40→≈30); elit piyadede ayak–gölge ilişkisi gözle seçilmiyor, elit/Lord "zeminde yüzüyor" izlenimi sürüyor. Gölgeyi kapat/aç farkı yalnız ~4 600 px (6 düşman). Oyuncu gölgesi de ince (≈ koyu halka). | `screens/S7-golge-ac-kapa.png`, `S8-golge-fark-x10.png` (fark ×10), `15-elit-golge.png` | E0 "tüm türler, **en yüksek öncelik**"; K1 (1) "yer gölgesi"; §1.1-1 "yer gölgesi sabit kalır, gövde ondan ayrılır/ona oturur"; α 0,38 *(öneri)* |
| V-02 | **Orta** | HUD — yüzen metin | Aynı anda/700 ms içinde birden çok eklenti toplanınca **FloatText üst üste biniyor**: "SINIRSIZ ŞARJÖR" + "HASAR ARTTI" + "ATIŞ HIZI ARTTI" aynı konumda, okunmaz bir harf yığını (Lord görüntüsünün üstünde de). Satır kaydırma/kuyruk yok. | `05-lord-banner.png` (y≈1000–1030), `06-notch-hud.png`; senaryo `capture/cap_a.gd.txt` `notch` | §2.3 "kayan metin … 700 ms" her eklenti için; §6 okunurluk; Aynı tür tekrar alınma ve ardışık alma kuralı metin için boşluk bırakmalı |
| V-03 | **Orta** | HUD — çentikli cihaz + "KALE LORDU GELİYOR" bandı | Lord duyuru bandı güvenli alan payını **izlemiyor** (y≈520–650 sabit); üst boşluk 130 px olunca HUD (SKOR, SERİ çipi, rozet satırı, Elit/Lord satırı) 110 px aşağı kayıyor ve **bandın altında kalıyor**: SERİ çipi, `+1.500` başlığı, yuva ikonları ve boss çubuğu okunmuyor. Çentiksiz cihazda çakışma yok (bant boss çubuğunun hemen altında). | `06-notch-hud.png` ↔ `05-lord-banner.png` | §6 Güvenli alan (N7: tüm katmanlar `safe_extra`); §3.2 çakışma notu (Elit/Lord satırı çipin 10 px altında) |
| V-04 | **Orta** | HUD — ekran dışı eklenti oku | Ok, ekran kenarına **8 px** yakın (daire merkezi kenardan 50 px; daire 84 px). Güvenli alan içinde değil: yuvarlak köşe/jest şeridine girer. Çentik payı eklenince 8 px'lik boşluk korunuyor (x 56), yani `SAFE_EDGE` (36) uygulanmıyor. | `05-lord-banner.png` (sol alt, x 8–92, y≈1915–2000 orijinal), `06-notch-hud.png`, `16-ekran-disi-ok.png` | §2.2 "kenarda 84 px yuvarlak ok … **güvenli alan içinde**"; §5.2 "kenar 50, güvenli içi"; §6 güvenli alan |
| V-05 | Düşük | En İyi Skorlar | Sonuç çipi metni (**KAZANDI / YENİLDİ**) kodda **22 px** (`highscore_screen.gd:63`); min metin 26 px. Dekoratif çipte renk+✓+metin kuralı sağlanıyor ama boyut altı. (Tasarım içi tutarsızlık: §3.3 döküm ayrıntısı 24 px da <26.) | `09-skorlar.png` (çip y≈ 250–265 orijinal), kod satırı | §6 "Min metin 26 px"; §3.5 çip 34 px yükseklik |
| V-06 | Düşük | HUD — kazanç başlığı | `+1.500` kazanç başlığı SERİ çipine **bitişik** (0 px boşluk, x 722 / çip 720) ve ruine/zemine karışıyor (bronz_300 ince, gölge zayıf). | `05-lord-banner.png` (y≈ 410–420), `04-hud-skor-seri.png` | §3.2 "çipin solu, top 394, Inter 700 28, bronz_300" (boşluk belirtilmedi; 12–16 px önerilir) |
| V-07 | Düşük | Oyun — eklenti yerde parlaması | Yaygın (kemik) eklentinin zemin parlaması additive ışık yerine **düz gri elips plaka** gibi okunuyor; Seyrek/Nadir'de (kıvılcım, sütun) iyi. Yaygın ≈ "taş zemin". | `01-eklenti-yerde.png` (iksir, çekim taşı) | §2.2 "Parlama elips 140×80, nadirlik rengi, α 0,55, **additive**" |
| V-08 | Düşük | Seviye atlama ön vurgusu | Mor halka dalgası **ön vurgu sırasında** (180 ms, sim durmuşken) yayılıyor; spec halkayı kart seçildikten sonraya koyuyor. Halka 3 px mor, koyu zeminde çok zayıf. Kart sonrası ikinci halka oynuyor mu kullanıcıda doğrulanır. | `S4-seviye-vurgu.png` (kare 1–3) | P11 "Ön: altın parlama + halo ×1,3 … **Devam:** kart seçilince halka dalgası", F2 |
| V-09 | Düşük | Debug APK/ekran görüntüsü | Debug sayaç etiketi ("düşman N/M … kesme düzeltmesi: AÇIK …") sol alt **rozet saniye sayılarının üstüne biniyor** (rozet x≈230–530, etiket x≥250); kullanıcı doğrulama sırasında rozet sayısını okuyamaz. Yalnız debug katmanı. | `02-hud-rozet-tambur.png`, `S9-rozet-bitis.png` | §2.4 rozet; proje notu: aç/kapa etiketi standart ama okunurluğu bozmamalı |

## Önerilen düzeltmeler

Faz ayrımı: **D4 (T92)** yalnız kareli yürüme/atlas/PlayerView alanını yazıyor; HUD/Fx/eklenti dosyalarına dokunmaz. Aşağıdakilerden yalnız V-01'in ayak çizgisi/gölge ölçüsü D4 ile temas eder.

| Bulgu | Nerede | Faz | Kabul kriteri |
|---|---|---|---|
| V-01 | `enemy_shadow_layer.gd` (`SHADOW_ALPHA`), `enemy_renderer.gd` (`SHADOW_H`, elit genişlik), `player_view.gd` `Shadow` | **Düzeltme fazı**; D4 atlas/kare değişince ayak çizgisi ofsetini yeniden ölç | Aynı sahnede gölge açık/kapalı farkı: gölge piksellerinde ortalama koyulaşma ≥ %40; elit piyade/şövalyede gölge ayağın ≤10 px altında görünür (kare dizisi kanıtı); kalabalık (300) ek maliyet ≤ +0,05 ms |
| V-02 | `float_text.gd` (+ `GameController` toplama kancası) | **Düzeltme fazı** | Aynı karede 3 eklenti toplandığında metinler 44–50 px dikey aralıkla ya da 120 ms'lik kuyrukla sıralı; hiçbir iki satır örtüşmez (ekran görüntüsü) |
| V-03 | `hud.gd` Lord bandı (bant üstü `safe` katmanına ya da `safe_extra.y` kadar kaydır) | **Düzeltme fazı** | `apply_safe_area(Vector4(48,130,48,80))` ile SERİ çipi, rozet satırı ve boss çubuğu bandın altında kalmaz (ekran görüntüsü), çentiksiz görünüm değişmez |
| V-04 | `offscreen_arrow.gd` `MARGIN` (= SAFE_EDGE + SIZE/2 ≈ 78) | **Düzeltme fazı** | Çentiksiz 1080×2400'de ok dairesi kenara ≥ 36 px; çentik payıyla birlikte ≥ 36 + pay |
| V-05 | `highscore_screen.gd` çip metni 26 px (çip yüksekliği büyütülerek) | **Düzeltme fazı** (düşük öncelik) | Çip metni ≥ 26 px, satırla çakışmaz |
| V-06 | `score_block.gd` kazanç başlığı | **Düzeltme fazı** | Başlık–çip boşluğu ≥ 12 px |
| V-07 | `pickup_renderer.gd` yaygın parlama | **Düzeltme fazı** (isteğe bağlı) | Yaygın eklenti parlaması additive, plaka gibi görünmez |
| V-08 | `player_anim.gd`/`aura` seviye halkası zamanlaması | **Düzeltme fazı** (isteğe bağlı) | Halka kart seçimi sonrası başlar (ya da tasarım güncellenir) |
| V-09 | debug etiketleri (`_render_label`/`_escape_label` konumu) | **Düzeltme fazı** | Debug etiketi rozet/tambur bölgesini örtmez |

### Perf yedek merdiveni (docs/dev/perf.md) görüşü

**İlk adım (>200 canlıda θ/squash atlama) şu an gerekmiyor.** Masaüstü headless ölçüm 300 düşmanda `enemy_refresh` 0,65 ms ort / 1,18 ms en kötü (perf.md'deki 0,37 ms'ye göre bu konteynerde yüksek ama masaüstü, cihazı temsil etmez); player_view 0,05, fx 0,015, hayalet 0,10 ms; bütçeyi (≤0,4+0,15 ek) aşan tek kalem `enemy_refresh`, ancak "zaman yalnız bilgi" kuralı ve D4'ün ekleyeceği ≈ +0,15 ms (kare seçimi) hesaba katılmalı. Karar kullanıcıda ölçülecek `view_ms_avg/p95` (debug APK stres koşusu) ile verilir: **önerilen eşik** — `view_ms_avg > 4 ms` ya da `p95 > 8 ms` orta sınıf cihazda → merdivenin 1. adımı (dalı yalnız kalabalık LOD'u olarak, elit/Lord/oyuncu etkilenmez); yoksa dokunma. Görsel kayıp riski düşük (kalabalıkta θ/squash zaten okunmuyor, bkz. `14-kalabalik-300.png`).

## Kabul kriterleri

- [x] `docs/design/audit/v1.1-ara/FINDINGS.md` ve ekran görüntüleri commit'lendi; bulgular numaralı, önemli, kanıtlı, DESIGN.md referanslı.
- [x] `### Önerilen düzeltmeler` hangi faza gideceğini söylüyor.
- [x] Üretim koduna/testlere dokunulmadı (yalnız `docs/design/audit/v1.1-ara/`).

## Açık noktalar (kullanıcıda doğrulanır)

1. **view_ms / gerçek FPS** (stres koşusu `perf.json`): masaüstü yazılım render cihazı temsil etmez; perf yedek merdiveni kararı buna bağlı.
2. **Gerçek çentik / yuvarlak köşe**: `apply_safe_area` ile simüle edildi (V-03, V-04); cihazda `get_display_safe_area` değerleriyle bakılmalı.
3. **Dokunma/his**: hasar sarsıntısı, vuruş donması, sonuç gecikmesinin hissi (1,3/1,8 sn), seviye ön vurgusu (180 ms), bomba "kamera 18 px" sarsıntısı, titreşim deseni.
4. **Kalabalık okunurluğu (300)**: `debug_fill/debug_spawn` sahneleri düşmanları üst üste yığar (spiral/yoğun küme); doğal akışta oyuncu/düşman ayrımı (aynı bone rim rengi) ve gölge görünürlüğü cihazda kontrol edilmeli (`14-kalabalik-300.png` en kötü durum).
5. **Ekran parlaklığı/OLED**: V-01 ve yaygın eklenti parlaması parlaklık ayarına bağlı; ilk kez kullanıcıda doğrulanmalı.
6. **Düşman yürüme**: prosedürel yedek çalışıyor (bob ±5 px, eğim); "ayak kayması" hissi yalnız D4 kareleriyle çözülür; D4 sonrası aynı kare-dizisi denetimi tekrarlanmalı.
7. **∞ glifi / font**: polyline ile çizildiği için sorun yok; Cinzel'de U+221E gerek yok.
8. **Skor ekranı verisi**: ekranlar sentetik skorlarla alındı (tarih 2025/2026); gerçek `user://highscores.json` ile boş/bozuk dosya davranışı cihazda.
9. Seviye atlama halkası, buff bitişi (son 3 sn yanıp sönme) ve "ÖFKE" etiketi yalnız kısmen görüntülendi; 2,5 Hz sınırı kodda doğrulandı, görsel his cihazda.
