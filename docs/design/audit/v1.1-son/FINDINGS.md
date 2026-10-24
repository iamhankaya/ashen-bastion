# Ashen Bastion v1.1 — Son denetim (düzeltme fazı sonrası, entegrasyon `9bd4329`)

Görev: T20261023-99 · Denetçi rolü: Senior Designer · Tarih: 2026-10-23
Kapsam: v1.1'in tüm ekranları ve animasyonları (menü, En İyi Skorlar dolu/boş, sonuç rekor/sıra/rekorsuz, HUD skor + SERİ + rozetler + ∞ tambur + ekran dışı ok + bomba fitili + Lord bandı, yerdeki eklentiler, kalabalık, elit/Lord, ölüm ve sonuç gecikmesi, seviye ön vurgusu + kart sonrası halka, yürüme/duruş/dönme/hasar/ölüm kare dizileri, gölgeler) ↔ `docs/design/v1.1/DESIGN.md` + `mock/`; ara denetim V-01…V-09'un kapanış kontrolü.
Dışında (bulgu olarak tekrar edilmedi, etkisi not edildi): omuz sapması ≈17 px (prosedürel), F-021 kaçış süresi 22–36 sn, gerçek yürüme karelerinin kalite kapısını geçememesi (prosedürel yedek, `docs/dev/v1.1-d4/`), tampon α 0,38 sabitliği.

## Yöntem

- Godot 4.7.2, `xvfb-run` + `--rendering-driver opengl3` (Mesa llvmpipe), **1080×2400 dikey**; çentik/güvenli alan varyasyonu `apply_safe_area(Vector4(48,130,48,80))` (HUD, menü, En İyi Skorlar, sonuç).
- Repo betikleri: `tools/capture/shots.gd` (menu, game, crowd, boss, lord, levelup, pause, win, lose, contrast, d3hud/d3menu/d3scores/d3scores_empty/d3result*/winc*, d1_walk/hit/die/ash/crowd), `shots_pickups.gd`, `shots_fix.gd` (shadow, float, lord, arrow, scores, menu, glow, ring, debug). `shots_walk.gd` bu denetimde yeniden koşulmadı: gerçek kareler veriye bağlı değil (D4 README), yürüme denetimi prosedürel yedek üzerindendir.
- Kendi senaryolarım (üretim koduna dokunmadı): `capture/cap_a.gd.txt` (ara denetimden; walk, stand, turn, enemywalk, hit, die, levelup, toast, notch, crowd300 — sabit 1/60 sn adım; `PlayerAnim` alanları basıldı), `capture/cap_r.gd.txt` (rekorsuz sonuç + çentikli sonuç).
- Görüntüler **540×1200'e küçültüldü** (kare dizileri/montajlar ≤1300 px genişlik), paletlendi; `screens/NN-*.png`, `screens/S*.png`. Bulgulardaki koordinatlar **orijinal 1080×2400** pikselidir (görüntü koordinatı × 2).
- Cihaz/APK yok: gerçek FPS, his, gerçek çentik → "Açık noktalar".

## Sonuç özeti

V-01…V-09'un **dokuzu da kapandı** (kanıtlı). Yeni **kritik/yüksek/orta bulgu yok**; **5 düşük** bulgu var (S-01…S-05). Tasarım dokümanına sadakat yüksek: gecikmeler, hasar/yürüme/dönme/duruş sayıları, rozet/∞ tambur, bomba, skor dökümü, rekor bandı, liste, menü maketle örtüşüyor; çentikte hiçbir HUD öğesi örtülmüyor. Düzeltme fazı önerisi gerekmiyor; S-01…S-05 son kapı listesine (`### Önerilen düzeltmeler`).

### Tasarıma uyduğu doğrulananlar (kanıtlı, son koşu)

| Kontrol | Ölçüm | Beklenen |
|---|---|---|
| Ölüm → sonuç gecikmesi | sonuç **77. adımda = 1,28 sn** (`DIE result screen at tick 77`) | 1,3 sn (§1.6, P12); sonuç "kazanma 1,8" ara denetimde 1,82 sn ölçülmüştü, değişmedi |
| Yürüme sekmesi | bob zirve **9,0 px**; temas sx 1,05/sy 0,93; havada 0,97/1,04 | 9 px, 1,05/0,93 (P2) |
| Gövde eğimi | rot 0,07–0,14 rad (4–8°) | 6°±2° (P3) |
| Dönme | `turn_x` 0,92 → 0,35 → −0,86 → −1 (3 adım ≈ 50 ms, min \|sx\| ≈ 0,35) | 70 ms, min 0,25 (P4) |
| Duruş nefesi | sy 1,000 ↔ 1,015, 2,4 sn | P1 |
| Hasar | `hit` 1,0 beş adım (≈ 83 ms); sx 1,10 / sy 0,907 → yay 12 Hz sönümlü; 220 ms sonra 1,00 | 90 ms, 1,10/0,90 (P10) |
| Ölüm dizisi | beyaz parlama → devrilme → yerde yatış, soluk ton (`S4-olum.png`); sonuç 1,28 sn | P12 |
| Rozetler / ∞ tambur / SERİ / skor | 3 rozet + ∞ tambur + toast, SERİ ×2/×5 çip, "+1.500" başlığı | §2.4, §3.2 |
| Güvenli alan | çentikli HUD, menü, skorlar, sonuç: hiçbir öğe örtülmüyor/kesilmiyor (`19-notch-hud`, `18-lord-notch`, `04/05/09/23`) | §6, N7 |
| Dokunma hedefleri | menü/skor/sonuç düğmeleri ≥132 px, GERİ alt başparmak bölgesinde; sonuç düğmeleri y>1500 | §3.3, §3.5, §6 |
| Sonuç durumları | rekor+sıra 1 (`06`), sıra N (`07`), rekorsuz "10. sıra için gereken: 891.000" (`08`), çentikli (`09`,`23`), kombolu (`10`) | §3.3, §3.4 |
| En İyi Skorlar | dolu, kısmen dolu (boş sıra kesikli), boş durum (`02`,`03`,`04`) — Türkçe "İ" doğru, çip metni 26 px | §3.5 |

## Ara denetim bulgularının durumu

| # | Durum | Kanıt (son koşu) |
|---|---|---|
| V-01 gölge okunurluğu | **KAPANDI** | `shots_fix shadow`: gölge piksellerinde ortalama koyulaşma **%41,1** (36 200 px; eski %24; kabul ≥%40 — marj ince, bkz. S-01/Açık nokta 3). `S6-golge-ac-kapa.png` (sol açık/sağ kapalı): elit piyade, elit şövalye, Lord ve oyuncu gölgesi ayağa oturuyor; `S7-elit-yakin.png`: elit şövalye gölge ayrılığı ≈8 px (kod `SHADOW_ELITE_HOVER_MAX 8`). |
| V-02 yüzen metin | **KAPANDI** | `17-lord-bandi`, `18-lord-notch`, `30-toast-3`: üç metin aynı karede ≈ **48 px** satır aralığıyla (`FloatText.ROW 48`, font 44) üst üste binmeden okunuyor. |
| V-03 Lord bandı + çentik | **KAPANDI** | `18-lord-notch.png`: bant güvenli alan payı kadar aşağıda (y≈655–780); SERİ ×5 çipi, "+1.500", yuva/pasif satırı ve boss çubuğu bandın **üstünde** kalıyor; çentiksiz `17` değişmemiş. |
| V-04 ekran dışı ok kenarı | **KAPANDI** (küçük kalıntı S-05) | `15-ok-sol`: daire kenarı ekran kenarından **36 px**; `16-ok-notch-alt`: alt payın (80) içinde (daire alt kenarı y≈2284 < 2320). |
| V-05 çip metni | **KAPANDI** | `02-skorlar-dolu`: KAZANDI/YENİLDİ 26 px (`FONT_SIZE := 26`), satırla çakışmıyor. |
| V-06 kazanç başlığı boşluğu | **KAPANDI** | `11-hud-skor-seri`, `18`: "+1.500" ile SERİ çipi arası ≈ **30 px** (≥12). |
| V-07 yaygın eklenti parlaması | **KAPANDI** | `28-yerde-parlama`: kızıl iksir/çekim taşı parlaması yumuşak additive, plaka görünümü yok. |
| V-08 seviye halkası zamanlaması | **KAPANDI** (okunurluk kalıntısı S-02) | `24-seviye-on`: yalnız altın parlama + halo, halka yok; `25-seviye-kart-sonrasi`: halka kart seçiminden sonra yayılıyor (spec P11). |
| V-09 debug etiketi | **KAPANDI** (kalıntı S-04, yalnız debug) | `12-hud-rozet-tambur`: etiket sağ altta, rozet saniyeleri okunuyor. |

## Bulgular (yeni)

Önem sıralı; hepsi **düşük** (kritik/yüksek/orta yok). Her biri kanıtlı.

| # | Önem | Ekran | Bulgu | Kanıt | Beklenen (DESIGN.md) |
|---|---|---|---|---|---|
| S-01 | Düşük (tasarım kararı değerlendirmesi) | Oyun — elit şövalye / Lord / hayalet gölgesi | **8 px süzülme sınırı sonucu:** elit şövalye ve Lord artık zeminde **duruyor** gibi okunuyor; E3/E4'ün "süzülür" karakteri (elit şövalye, ±6 px bob) zayıfladı. K1'in asıl şikâyeti ("zeminde yüzüyor") giderildi — gölge belirgin (%41), ayak–gölge ilişkisi net — ama kazanç/risk: (a) marj dar: koyulaşma 0,411, eşik 0,40; parlaklık düşük/OLED'de yeniden "yüzüyor" izlenimi riski; (b) §8-2 "bilinçli süzülür" ile çelişiyor, doküman güncellenmeli. Uçan elit karga (kuşlu) ayrılığı serbest, doğru okunuyor. | `S6-golge-ac-kapa.png`, `S7-elit-yakin.png`, `20-elit-lord.png` | E0, K1(1), §1.1-1 "gövde ondan ayrılır/ona oturur"; E3 "süzülme"; §8-2 |
| S-02 | Düşük | Seviye kart sonrası halkası | Halka (3 px, mor-mavi, ≈%25 görünür) koyu çimende **çok soluk**; ~200 ms'de yalnız ince elips olarak seçiliyor, "ödül anı" hissi vermiyor. Zamanlama doğru (V-08 kapandı). | `S8-halka-yakin.png` (sağ), `25-seviye-kart-sonrasi.png` | P11/F2 "halka dalgası 0→180 px, `xp_parlak`, 3 px" (okunurluk ölçüsü yok); §6 okunurluk |
| S-03 | Düşük | Sonuç — döküm ayrıntı metni | "en yüksek ×3", "0 evrim", "00:04", "Lord'u yen" ayrıntıları **24 px** ve çoğu satırda %35 opak; min metin 26 px. Tasarım içi tutarsızlık (§3.3 24 px ↔ §6 26 px) — V-05'in çip için çözdüğü sorun ayrıntıda duruyor. | `06-sonuc-rekor.png` (satır ayrıntıları), `09-sonuc-notch.png` | §6 "Min metin 26 px"; §3.3 "ayrıntı Inter 600 24" → doküman 26'ya güncellenmeli |
| S-04 | Düşük (yalnız debug) | Debug APK/ekran görüntüsü | Debug etiketi sağ altta başparmak bölgesinde: sonuç ekranında ANA MENÜ düğmesinin alt-sağ köşesine biniyor, alt kenara yakın ekran dışı oku (`16`) örtüyor; "(dokun)" etiketleri dokunulabilir alan olduğundan yanlış dokunma riski. Üretim yapısında yok. | `10-sonuc-kombolu.png` (sağ alt), `16-ok-notch-alt.png` | §2.4/§6 tek el, başparmak bölgesi serbest; proje notu: debug etiketi okunurluğu bozmamalı |
| S-05 | Düşük | HUD — ekran dışı ok | Dairenin kenarı 36 px'te (V-04 ✓), ama **işaret üçgeni** kenara 18–24 px yaklaşıyor; yuvarlak köşe/jest şeridinde kısmen. | `15-ok-sol.png` (x≈18–36, y≈1189–1350 orijinal) | §2.2 "güvenli alan içinde"; §5.2 "kenar 50, güvenli içi" |

## Elit şövalye süzülme sınırı — özel değerlendirme

Düzeltme fazının kararı (`SHADOW_ELITE_HOVER_MAX = 8`): gölge ayrılığı 8 px'e sınırlandı; elit şövalye ve Lord için gölge sprite genişliğinde ve ayağa oturuyor. **Değerlendirme: kabul önerilir.**
- Kazanç: V-01'in "elit/Lord zeminde yüzüyor" şikâyeti kapandı; gölge açık/kapalı farkı belirgin (`S6`).
- Kayıp: elit şövalyenin "ağır süzülme" izlenimi azaldı; Lord ağır adım (E7) ile tutarlı olduğundan sorun değil. Elit şövalye gerçek kare yürüme olmadığı için (prosedürel, ±6 px) hâlâ hafif sekiyor; gölge sabit kalıp gövde yukarı çıkınca ayrılma var ama 8 px sınırında kalıyor — "yüzme" değil "hafif adım".
- Öneri: `DESIGN.md` §8-2/E3 "elit şövalye artık zemine oturur; gölge ayrılığı ≤8 px" diye güncellenmeli; cihazda parlaklık düşükken tekrar bakılmalı (S-01).

## Önerilen düzeltmeler

Kritik/yüksek bulgu **yok**; düzeltme fazı önerilmiyor. Son kapı listesi için (öncelik sırasıyla, hepsi isteğe bağlı/küçük):

| Bulgu | Nerede | Not |
|---|---|---|
| S-01 | `DESIGN.md` E3/§8-2 güncellemesi; (isteğe bağlı) `enemy_shadow_layer.gd` `GAIN` 2,2 → ≈2,4 marj için | Cihazda doğrula; gerekmiyorsa dokunma |
| S-02 | halka kalınlığı 4–5 px / α ↑ (`player_anim.gd`/FX halka çizimi) | İsteğe bağlı |
| S-03 | `DESIGN.md` §3.3 ayrıntı 24 → 26 px | Doküman düzeltmesi; kod 26'ya çekilebilir |
| S-04 | debug etiketini sol üst/orta kenara taşı | Yalnız debug |
| S-05 | işaret üçgenini daire içine al ya da `MARGIN` + üçgen payı | İsteğe bağlı |

## Kabul kriterleri

- [x] `docs/design/audit/v1.1-son/FINDINGS.md` ve görüntüler commit'lendi; V-01…V-09 durumu işaretli; yeni bulgular S-01… numaralı, önemli, kanıtlı, DESIGN.md referanslı.
- [x] Kritik/yüksek yok → orta/düşükler son kapı listesi için `### Önerilen düzeltmeler`'de.
- [x] Üretim koduna ve testlere dokunulmadı (yalnız `docs/design/audit/v1.1-son/`).

## Açık noktalar (kullanıcıda doğrulanır)

1. **Cihaz FPS / `view_ms_avg/p95`** (stres koşusu `perf.json`): masaüstü yazılım render cihazı temsil etmez; perf yedek merdiveni eşiği ara denetimdeki öneriyle (`view_ms_avg > 4 ms` ya da `p95 > 8 ms`) cihazda karara bağlanır. Bu denetimde kalabalık sahneler (262/129 düşman) görsel olarak sorunsuz çizildi.
2. **Gerçek çentik / yuvarlak köşe**: `apply_safe_area` ile simüle edildi; cihazda `get_display_safe_area` değerleriyle (özellikle ok işaret üçgeni, S-05) bakılmalı.
3. **Gölge okunurluğu cihazda** (S-01): koyulaşma marjı dar (0,411); düşük parlaklık/OLED'de elit şövalye ve Lord gölgesi kontrol edilmeli.
4. **Dokunma/his:** hasar sarsıntısı, vuruş donması, sonuç gecikmesi hissi (1,3/1,8 sn), seviye ön vurgusu 180 ms, bomba kamera 18 px, titreşim deseni.
5. **Yürüme ayağı kayması:** gerçek kareler kalite kapısını geçemedi; prosedürel yedekte ayak–gölge ilişkisi (`S1-yurume.png`) kabul edilebilir, omuz sapması (≈17 px, bilinen) bu çekimlerde gövdeye göre gözle seçilen bir kopma yapmıyor. Gerçek kareler gelince kare-dizisi denetimi (stride/N ±3 px) tekrarlanmalı.
6. **Kalabalık okunurluğu (300):** debug dolgu sahneleri düşmanları halka/küme halinde yığar (`21`, `22`); doğal akışta oyuncu/düşman ayrımı (aynı kemik rim) cihazda kontrol edilmeli.
7. **Skor verisi:** ekranlar sentetik skorlarla alındı; gerçek `user://highscores.json` ile boş/bozuk dosya davranışı cihazda.
8. **Hareket/animasyon yalnız durağan kareyle görüldü:** buff bitişinde 2,5 Hz yanıp sönme, Lord ÖFKE anı, bomba son 250 ms nabzı, elit adım tozu/Lord şok halkası kareler halinde değil sürekli oynatımda cihazda izlenmeli (≤3 Hz sınırı kodda doğrulanmıştı, ara denetim).
9. **Kazanma sonucu (1,8 sn):** bu denetimde ölçülmedi (`shots.gd win` senaryosu zaman koşulunu tamamlamıyor); ara denetim ölçümü 1,82 sn, ilgili kod değişmedi.
10. `∞` glifi polyline ile çizildiğinden font sorunu yok; Cinzel'de U+221E gerekmiyor.
