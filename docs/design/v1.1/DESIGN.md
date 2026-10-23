# Ashen Bastion v1.1 — Tasarım

Tarih: 2026-10-23 · Görev: T20261023-85 (çatı T20261023-84) · Aşama: yalnız tasarım, kod yok.
Girdiler: `docs/design/2026-10-23-ashen-bastion-v1-design.md`, `docs/ui/DESIGN-UI.md` (+ `tokens.json`), `docs/design/audit/son-denetim/FINDINGS.md`, `art/ref/`, kod: `scripts/view/player_view.gd`, `assets/shaders/player_sway.gdshader`, `data/characters/gunslinger.json`, `scripts/view/enemy_renderer.gd`, `enemy_atlas.gd`, `assets/shaders/enemy_flash.gdshader`, `scripts/view/fx_renderer.gd`, `scripts/ui/hud.gd`, `result_screen.gd`, `main_menu.gd`.
Maketler: `mock/` (statik HTML + Chromium ekran görüntüsü, 1080×2400). AI görsel promptları: `prompts.md`.

**Etiketler.** *(öneri)* = denge/sayı önerisi, kesin değeri plan fazı belirler. **[AÇIK]** = kullanıcı kararı bekliyor (§8). Tüm ölçüler 1080×2400 tasarım pikseli; 1 dp ≈ 2,75 px varsayımı, dokunma hedefi ≥ 132 px (DESIGN-UI §5).

## 0. Özet ve temel kararlar

| # | Karar | Gerekçe |
|---|---|---|
| K1 | "Resim gibi süzülme"nin nedeni: oyuncu zıplaması 4 px (%2) ve %4 squash; düşmanda yürüme hareketi hiç yok (tek `transform`, yalnız yöne bakma + vurulma parlaması); yerle temas gölgesi yok. Çözüm sırası: **(1) yer gölgesi, (2) ağırlık merkezi eğimi + daha büyük bob/squash, (3) tepki (vurulma/ölüm), (4) vurgu anları.** | Gölge ve eğim olmadan genlik artırmak "daha çok zıplayan resim" üretir. |
| K2 | Animasyonların **tamamı ek görselsiz** (a) tasarlandı; (b) kare ihtiyaçları isteğe bağlı kalite yükseltmesidir ve öncelik sırasıyla `prompts.md`'de. | Görsel üretimi kullanıcıya bağlı; tasarım onu beklemeden uygulanabilir olmalı. |
| K3 | Düşman hareketi **MultiMesh örnek dönüşümünden** (dönme, ölçek, öteleme) ve mevcut `INSTANCE_CUSTOM.r` (vurulma değeri) türetilir; ölüm için ayrı küçük bir "hayalet" MultiMesh. Sim'e dokunulmaz (itme yalnız görseldir). | 300+ düşman bütçesi; çarpışma/yol bulma bozulmaz. |
| K4 | Eklentiler yerde **80 px ikon + parlama + gölge + kayan nabız**; nadirlik = renk + parlama biçimi + nabız hızı (tek başına renk değil). | DESIGN-UI ilke 5 ve §2 "renk tek başına anlam taşımaz". |
| K5 | Süreli etki göstergesi **sol alt, tamburun sağında** (108 px yuvarlak rozet, kalan süre yayı + saniye sayısı). | Üst bölge dolu (süre, can, yuvalar, boss satırı); alt-sol zaten bilgi bölgesi ve dokunulmaz; sağ-alt başparmak bölgesidir. |
| K6 | Skor HUD'da **sağ sütun, Duraklat'ın altı** (y 284–436). Süre altı ortası yuva satırlarıyla çakışır (x 36–558). | `02-hud-anatomi.png`. |
| K7 | "Kombo" oyunda "evrim" demek (Kurulan kombolar). Skor çarpanına **SERİ** adı verildi. | İsim çakışması önlenir. **[AÇIK-6]** |
| K8 | Bomba: **toplanınca toplama noktasında 0,8 sn fitil, sonra yarıçaplı patlama; oyuncuya zarar yok.** Alternatif: oyuncunun üstünde anında. | Yarıçap göstergesi anlam kazanır; konumlanma oyunu. **[AÇIK-1]** |

---

## 1. Animasyon dili

### 1.1 İlkeler (tüm hareket için)

1. **Ağırlık merkezi ayakta.** Tüm dönme/ölçeklemeler ayak noktasından (oyuncu: gövde merkezinden +100 px aşağı; düşman: quad alt-orta) yapılır; yer gölgesi sabit kalır, gövde ondan ayrılır/ona oturur.
2. **Anticipation → vuruş → toparlanma.** Her tepki üç parçadır; en kısa tepki 80 ms.
3. **Squash/stretch hacmi korur:** `sx · sy ≈ 1` (örn. sx 1,10 ↔ sy 0,90).
4. **Kalabalıkta senkron yok:** düşman fazı `hash(id)·2π`, hız çarpanı ±%15.
5. **Okunurluk > süs:** 300 düşmanda her şey küçük ve ucuz kalır; büyük gösteri yalnız elit/Lord/oyuncuda.
6. **Işık/titreşim:** hiçbir tepki >3 Hz yanıp sönmez; temas hasarı zaten 0,6 sn aralıklı (1,7 Hz). Ekran sarsıntısı ≤ 18 px, ≤ 200 ms (mevcut `CameraRig.shake` sınırı).
7. **Azaltılmış hareket (öneri, v1.1 dışı seçenek):** ileride `reduce_motion` açılırsa tüm sarsıntı/devrilme genliği %0, parlama kalır.

**Mekanizma sınıfları:** (a) = mevcut rig + shader + kod, görsel kare gerekmez; (b) = ek görsel kare ister (`prompts.md`).

### 1.2 Oyuncu (Gunslinger, 200 px boy)

Mevcut: `BOB_PX 4`, `SQUASH 0,04`, `BOB_HZ 2,2` (|sin| → 4,4 adım/sn), `RECOIL_TIME 0,06`, `RECOIL_ROT 0,12 rad`, `RECOIL_PX 6`, `FLASH_TIME 0,06`, shader `amp 14` / `scarf_amp 5`. Duruyorken hiç hareket yok.

**Yeni rig yapısı (a):** `Rig` (Node2D, pivot ayak noktası = gövde merkezi + (0, 100)) altına `FarArm`, `Body`, `NearArm` taşınır (yerel konumlar −100 px kayar). Eğim, devrilme ve squash bu düğümden yapılır. `Shadow`, `Glow`, `ReloadRing`, `MuzzleFlash` dışarıda kalır. `player_sway.gdshader`'a eklenecek uniform'lar: `hit` (0–1 parlama), `tint_amt`/`tint` (bordo ton), `desat` (0–1), `walk_phase` (etek), `scarf_amp` (kod her kare yazar).

| ID | Hareket | Tetikleyici | Zamanlama / eğri | Genlik | Sınıf |
|---|---|---|---|---|---|
| P1 | **Nefes (duruş)** | hız < 5 px/sn | 2,4 sn sinüs, sürekli | gövde sy 1,000→1,015; kol ±1,5°; atkı `scarf_amp` 3 px | (a) |
| P2 | **Yürüme sekmesi + squash/stretch** | hız ≥ 5 px/sn; frekans = 2,2 Hz × clamp(hız/300, 0,5, 1) | `h = |sin(πφ)|^0,8` (temasta keskin); temas anında 60 ms squash | bob **9 px** (4'ten); temas: sx 1,05 / sy 0,93; havada: sx 0,97 / sy 1,04 | (a) |
| P3 | **Gövde eğimi (lean)** | harekette | hız yönüne eğim, 120 ms lag (cubic-out); adım senkronlu ±2° sallanma | `6° × clamp(vx/300, −1, 1)` + ±2° | (a) |
| P4 | **Yön çevirme (turn)** | `facing_left` değişince, 8 px histerezis | 70 ms: `scale.x` 1 → 0,25 → −1 (orta noktada ayna), cubic-in-out | min |sx| 0,25 | (a) |
| P5 | **Etek/atkı ikincil hareketi** | sürekli | etek: mevcut `sway` + adım fazlı sinüs; atkı: koşuda `scarf_amp` 6,5 px, duruşta 3 px | etek ±3 px ek; atkı 3–6,5 px | (a) shader |
| P6 | **Geri tepme (tabanca başına ayrı)** | `shot_fired(gun)` | **40 ms** kol +8° yukarı & omuzdan 10 px geri & kol boyu %94 (cubic-out) → **110 ms** toparlanma (quad-out, −1,5° aşma, sonra 0). Yeni atış zamanlayıcıyı sıfırlar; genlik birikmez (tavan 1,25×) | kol 8°, 10 px, %6 kısalma; gövde karşı −1,2° ve 2 px geri (tabanca başına yarısı) | (a) |
| P7 | **Namlu alevi** | `shot_fired` | 80 ms (60'tan), 3 karelik titreşim: dönme ±8°, ölçek 0,8–1,2 rastgele, `MuzzleFlash` | yarıçap 14→4 px (mevcut) | (a) |
| P8 | **Boş kovan** | `shot_fired` | 350 ms yay: yan-geri 30–50 px, 6 px yükselip düşer, bronz 4×2 px dörtgen, FxRenderer'da halka tampon (16) | — | (a) |
| P9 | **Doldurma** | `reload_started(duration)` → `reload_finished` | 0–12 %: iki kol göğse iner (aim → aşağı 70°, quad-in); 12–70 %: ±10° titreme 8 Hz, gövde sy 0,97; 80–100 %: kollar **+6° aşarak** geri kalkar (cubic-out). Tamamlanınca halka 1→1,5 ölçek + solma 150 ms + tık anında amber nabız | kol 70°; titreme ±10°; sy 0,97 | (a); (b) isteğe bağlı: silindiri açık kol karesi |
| P10 | **Hasar (sarsıntı + parlama)** | `player_damaged(amount, hp)` | 0–90 ms **kemik-beyaz** parlama (`hit`=1, `#EFE7D6`), sonra 200 ms'de **bordo ton** (`tint #E0584F`, %35) söner. t=50 ms: **8 px geri** (fiziksel olmayan itme, ayakta kalır) + sx 1,10 / sy 0,90; sonra 12 Hz sönümlü yay 220 ms. Atkı `scarf_amp ×2,5` 300 ms sönüm. Kamera `shake(min(amount·0,4, 10))`. Beyaz parlama en çok 150 ms'de bir | 8 px · %10 · 10 px kamera | (a) |
| P11 | **Seviye atlama vurgusu** | `level_up` | **Ön:** 180 ms, sim durmuşken (görünüm kendi zamanında): gövde altın parlama (`#E8A24A`→kemik), halo ×1,3. **Sonra** ekran 220 ms girer (portre kaplar). **Devam:** kart seçilince halka dalgası 0→180 px, 450 ms (cubic-out), `xp_parlak` renk, ince 3 px; HUD rozeti 1→1,35→1 (260 ms) | halka 180 px | (a) |
| P12 | **Ölüm** | durum `LOST` | 0–120 ms **vuruş donması** + beyaz parlama; 120–720 ms gövde ayak pivotunda **devrilme** −75° (quad-in), 720'de ±4° sekme; kollar 350 ms'de sarkar (aim → ~100°); `desat` 0→0,6, amber ışık 600 ms'de söner; 720–1300 ms kül solması. Dokunma = atla. **Sonuç ekranı 1,3 sn gecikmeyle girer** | −75°, ~8 px yere gömülme | (a); (b) isteğe bağlı: yığılma karesi |
| P13 | **Süreli etki aurası** | eklenti etkin | ayak halkası: Hasar = bordo 4 px halka + parlama (0,8 Hz nabız); Atış hızı = bronz dönen yaylar; Sınırsız = amber çift halka + kol kenar ışığı amber | halka 80×28 px elips | (a) |

Devrilmede yön: son hasarın geldiği yönün tersine (bilinmiyorsa bakış yönünün tersi). Kazanınca (Lord ölümü) oyuncu animasyonu yok; yalnız Lord ölümü oynar (§1.4), sonuç **1,8 sn** gecikmeli.

### 1.3 Düşmanlar (MultiMesh, ek kare yok)

Ortak: örnek dönüşümü `rotate(θ) · scale(sx, sy)` ayak noktası etrafında; öteleme `(0, −bob)`. **Hesap maliyeti:** tür başına sabit tablo + 256 girişli sinüs LUT; hedef ek maliyet ≤ 0,4 ms/kare @ 300 düşman (cihazda doğrulanır).

**E0 — Yer gölgesi (tüm türler, en yüksek öncelik):** ikinci bir MultiMesh (`EnemyShadowRenderer`, tek çizim), yumuşak elips (`PlaceholderArt.soft_circle`), `genişlik = 0,8×quad genişliği`, `yükseklik = 0,2×genişlik`, α 0,38. Uçan/hayalet türlerde gölge sabit yerde, düşman yukarıda: kaymayla `α` ve ölçek bob'la değişir (yükseklik arttıkça %15 küçük, α %30 düşük).

| ID | Tür | Hareket | Tetikleyici | Zamanlama / eğri | Genlik | Sınıf |
|---|---|---|---|---|---|---|
| E1 | **Çürümüş Piyade** (104 px, 95 px/sn) | Sürünen yürüyüş | sürekli | 1,1 Hz; `θ = 5°(0,6 sin φ + 0,4 sin 2φ)` (topallama); bob \|sin\|; ileri eğim 4° | bob 5 px; sx/sy ±%5; θ ±5° | (a) |
| E2 | **Leş Kargası** (64 px) | Uçuş salınımı | sürekli | kanat: mevcut 3 kare, **[0,1,2,1] ping-pong @ 12 kare/sn** (şimdi 9 kare/sn döngü); gövde 3 Hz dikey salınım; yatış = yanal hızın ±12°'si | ±7 px, ±12°; hızda sx 1,10 | (a) |
| E3 | **Şövalye Hayaleti** (150 px, 70 px/sn) | Süzülme | sürekli | 0,7 Hz sinüs dikey; 0,9 Hz sy ±%3 "ağır adım"; yavaş θ ±2,5°; α 0,9–1,0 | ±6 px | (a) |
| E4 | **Elitler** (230–270 px) | Tür hareketi, yavaşlatılmış | sürekli | frekans × √(h₀/h) (≈ ×0,67); genlik % olarak aynı (px büyür); **adım temasında toz** (FxRenderer puff, sn'de ≤ 4) ve yakında (<400 px) kamera 1,5 px | — | (a) |
| E4b | **Elit Karga şarjı** | Ön hazırlık | `ai_timer < 0,35` (okunabilir) | 350 ms: kanatlar geri (sx 0,9), oyuncuya dönük −10° yatış, kırmızı göz nabzı (tint ×1,3); şarj: sx 1,25, 3 kare artçı iz (FxRenderer çizgi) | — | (a) |
| E5 | **Vurulma tepkisi** (hepsi) | Geri itilme + parlama + vuruş squash | `flash` değeri (hasarda 1,0 → 8/sn sönüm = **125 ms**); ayrı durum yok | itme = `(düşman − oyuncu)` yönünde `itme_px × flash²`; squash `1 ± k·flash` | piyade **10 px**, karga **14 px** + ±15° dönme, hayalet **4 px**, elit **2 px**, Lord **0 px** (yalnız parlama %50 + sy 0,985); k 0,12 / 0,12 / 0,04 / 0,03 / 0,015 | (a) |
| E6 | **Ölüm (dağılma/kül)** | Hayalet havuz | `enemy_killed(type, pos)` | piyade **220 ms** çöküş (sy 0,55, sx 1,12) + 200 ms kül; karga **420 ms** (40 px düşüş, 80° dönme, solma); hayalet **700 ms** yukarı akan kül (sy 1,15, 22 px yükselme); elit **900 ms** + 2 küçük patlama puf'u. Kül shader'ı: gürültü eşiği `t=yaş/ömür`, kenarda amber 0,06 şerit → kül `#3A322E` → saydam. Havuz 64, taşarsa en eski; **>150 canlı düşmanda LOD:** 150 ms düz solma | — | (a) |
| E7 | **Kale Lordu — yürüyüş** | Ağır adım | sürekli | 0,55 Hz; bob 6 px; θ ±2,5°; ayak temasında şok toz + kamera 3 px | — | (a) |
| E8 | **Lord — çağırma (12 piyade)** | Ön hazırlık → vuruş | `ai_timer < 0,6` (okunabilir) | **Ön 600 ms:** sy 1,10 (yükselme), −6° geri yaslanma, zemine 12 kor noktası çıkar (doğma noktaları), ışıma 2 nabız. **Vuruş 120 ms:** sy 0,88/sx 1,10, şok halkası 0→360 px 450 ms, kamera 10 px/200 ms, noktalarda kor patlaması | — | (a); (b) isteğe bağlı: kollar yukarı karesi |
| E9 | **Lord — ÖFKE anı** | Eşik geçişi | `ai_aux > 0` ilk görüldüğünde | 900 ms: 2 nabız (sy 1,15, 350 ms), vuruş donması 80 ms, kamera 16 px; **kalıcı:** ton `#E0584F ×1,15`, kor aurası (≤20 parçacık/sn), HUD boss çubuğu amber → `can_kritik` + **"ÖFKE" etiketi** | — | (a) |
| E10 | **Lord — ölüm** | Final | `enemy_killed(kale_lordu)` | vuruş donması 150 ms + beyaz parlama; 900 ms içinde 3 patlama (FxRenderer) rastgele ±120 px; 700 ms kül; görünüm yavaş çekim 0,4× (1,2 sn); sonuç **1,8 sn** gecikmeli | kamera 18 px | (a) |

### 1.4 Efektler (FxRenderer / yeni)

| ID | Efekt | Tetikleyici | Süre / ölçü |
|---|---|---|---|
| F1 | Ölüm kıvılcımı/kül | E6 | yukarıda |
| F2 | Seviye halkası | P11 | 450 ms, 0→180 px |
| F3 | Şok halkası (Lord, bomba, elit adımı) | E8/E4 | 360 px / 320 px, 450 ms |
| F4 | Boş kovan | P8 | 350 ms, tampon 16 |
| F5 | Zemin kömürü (bomba izi) | `bomb_exploded` | yarıçap 0,7R elips, α 0,35, 4 sn solma, en çok 8 |

### 1.5 (b) sınıfı: ek kare ihtiyacı (hepsi isteğe bağlı, öncelik sırasıyla)

| Sıra | İhtiyaç | Neden (a) yetmez | Kare sayısı / boyut | Prompt |
|---|---|---|---|---|
| B1 | Piyade yürüme karesi "adım B" | Dönme-eğim bacak değişimini veremez; en sık görülen düşman | 1 ek kare (mevcut = A), 1312×1199 | `prompts.md` §B1 |
| B2 | Oyuncu ölüm yığılma karesi ×2 | −75° devrilme "tahta" gibi durur | 2 kare, 1536×1024 | §B2 |
| B3 | Doldurma kolları ×2 (silindir açık / kapanıyor) | Namlu küçük, silindir hareketi görünmez | 2 kol karesi, 1774×887 (mevcut kolla aynı) | §B3 |
| B4 | Lord "kollar yukarı" karesi | Çağırma ön hazırlığı görsel olarak güçlenir | 1 kare, 1312×1199 | §B4 |
| B5 | Eklenti ikonları (hero kalite) | SVG önerisi (`mock/pickups/`) yeterli; AI ancak parlak sürüm ister | 6 ikon, 512×512 | §B5 |

**Atlas etkisi (B1/B4):** `EnemyAtlas` çok kareli dosyayı (`frames` > 1) zaten destekler; manifest `frames` artırılır. Kare seçimi: piyade A/B = yürüme fazı `φ`'nin işaretine göre (2,2 kare/sn ≈ 1,1 Hz).

### 1.6 Sim/denetleyiciden beklenenler (tasarım gereksinimi, kod değil)

- Okunabilir olması yeterli: `EnemyPool.ai_timer` (elit karga şarjı, Lord çağırması), `ai_aux` (öfke) — **yeni sinyal gerekmez**.
- Yeni sinyaller (eklentiler ve skor için): `pickup_collected(kind, pos)`, `buff_started(kind, duration)`, `buff_ended(kind)`, `bomb_planted(pos, radius, fuse)`, `bomb_exploded(pos, radius)`, `score_changed(score, mult, gain)`, `streak_changed(mult, left)`.
- Denetleyici: ölüm/kazanma sonrası sonuç ekranını **1,3 / 1,8 sn geciktir** (dokunma = hemen göster); sim durumu `LOST/WON` kalır, yalnız görünüm zamanı akar.

---

## 2. Harita eklentileri (pickup)

### 2.1 Katalog (ad ve sayılar *öneri*)

| Eklenti | Nadirlik | Etki | Süre | Ikon (`mock/pickups/`) | Yerde renk |
|---|---|---|---|---|---|
| **Kızıl İksir** | Yaygın | +25 can (maks. canı aşmaz) | anında | `iksir.svg` | kemik `#CFC4AE` halka |
| **Çekim Taşı** | Yaygın | ekrandaki tüm XP taşlarını çeker (`pulled=1`) | anında | `cekim-tasi.svg` | kemik halka |
| **Öfke Barutu** | Seyrek | hasar +%50 | 12 sn | `ofke-barutu.svg` | bronz `#D2B47E` halka + 4 kıvılcım |
| **Kızgın Namlu** | Seyrek | atış hızı +%40 | 12 sn | `kizgin-namlu.svg` | bronz halka |
| **Kara Bomba** | Seyrek | yarıçap **320 px** alan hasarı (zırh yok sayar; oyuncuya zarar yok); fitil 0,8 sn | anında | `kara-bomba.svg` | bronz halka |
| **Sonsuz Tambur** | **Nadir** | sınırsız şarjör (şarjör azalmaz, doldurma yok) | 10 sn | `sonsuz-tambur.svg` | **amber** `#E8A24A` halka + ışık sütunu |

Adlar mevcut beceri adlarıyla çakışmaz (Mıknatıs, Hızlı Parmak, Sağlam Yelek, Dinamit zaten beceri). Tüm dinamik adlar `UiKit.upper_tr` ile büyütülür: KIZIL İKSİR, ÇEKİM TAŞI, ÖFKE BARUTU, KIZGIN NAMLU, KARA BOMBA, SONSUZ TAMBUR.
Bomba hasarı *(öneri)*: normal düşmana 600 sabit; elit/Lord'a maks. canın %8'i (en az 600) — Lord tek vuruşta bitmesin.
Doğma *(öneri)*: 45–60 sn'de bir, oyuncudan 450–700 px, ağırlık: İksir 30 · Çekim 20 · Barut 15 · Namlu 15 · Bomba 15 · Sonsuz 5. Yerde ömür 25 sn (son 5 sn 2,5 Hz yanıp söner). Toplama yarıçapı 72 px (XP mıknatısı çekmez; yürüyerek alınır).

### 2.2 Yerdeki görünüm (`03-eklenti-katalogu.png`, `01-hud-skor-eklenti.png`)

Katman sırası (alttan): zemin parlaması → gölge → [ışık sütunu: yalnız Nadir] → ikon.

| Parça | Değer |
|---|---|
| İkon | 80×80 px dünya ölçüsü (XP taşı 30, oyuncu 200, karga 64, piyade 104); 3,5 px `#2B0E14` kontur + 2 px dış kenar `#BDA478` (düşman rim ailesi) + nadirlik renginde 12 px dış ışıma |
| Parlama | elips 140×80, nadirlik rengi, α 0,55, additive |
| Gölge | elips 60×16, α 0,45 |
| Süzülme | dikey ±6 px, 0,9 Hz sinüs; faz = id'den |
| Nabız (ışıma α) | Yaygın 0,8 Hz · Seyrek 1,0 Hz (+ 4 kıvılcım yörüngede) · Nadir 1,4 Hz (+ 140 px ışık sütunu, α 0,55→0, dönen çift halka). Hepsi ≤ 3 Hz |
| Doğma | ölçek 0→1,15→1 (260 ms, cubic-out) + halka 0→90 px 300 ms |
| Süre bitiyor | son 5 sn: α 1↔0,45, 2,5 Hz; sonra 150 ms solma |
| Ekran dışı gösterge | oyuncuya en yakın, ekran dışı eklenti için kenarda 84 px yuvarlak ok (ikon 50 px, nadirlik renk kenarı), güvenli alan içinde, α 0,7; aynı anda en çok 1 *(öneri; kapsam-küçük)* |

### 2.3 Toplama geri bildirimi

| Eklenti | Anlık | Dünyada | HUD |
|---|---|---|---|
| İksir | ikon oyuncuya uçar (120 ms ease-in, ölçek 0,4) | 6 adet `+` (kemik/bordo) yükselir 0,5 sn + gövde parlaması; **kayan metin "+25 CAN"** (Cinzel 44, 3 px gölge, 60 px yükselir, 700 ms) | can çubuğu kemik 200 ms parlar, kalp 1→1,3 nabız |
| Çekim Taşı | aynı | mor halka oyuncudan 0→1400 px, 500 ms; taşlar hıza göre uzar (sx ×1,8, yöne döner) ve hızlanır | XP çubuğu dolarken `xp_parlak` parlama |
| Hasar / Hız | aynı; metin "HASAR ARTTI" / "ATIŞ HIZI ARTTI" | ayak aurası (P13) | rozet **pop** (1→1,15) ve yay sıfırdan dolu |
| Sınırsız | aynı; "SINIRSIZ ŞARJÖR"; amber nabız | amber çift halka; kollar amber | tambur: **∞** + amber halka (aşağıda) |
| Bomba | ikon yerinde kalır, fitil yanar | §2.5 | — |

Aynı tür etkin eklenti tekrar alınırsa **süre tazelenir (yığılmaz)**; rozet pop yapar.

### 2.4 Süreli etki göstergesi (HUD)

Sol alt, tamburla aynı alt hizada. `01-hud-skor-eklenti.png`, `02-hud-anatomi.png`.

| Öğe | Değer |
|---|---|
| Rozet | 108×108 daire (bilgi amaçlı, dokunulmaz); konum x = 231 + n·120, alt 72 px; en çok 3 (Hasar, Hız, Sınırsız) |
| Yay | dış 8 px halka: kalan oranı **saat yönünde azalan** nadirlik renginde, kalan kısım `mermi_bos #3A2E28` |
| İç | `mor_900` daire, 3 px `#2B0E14` kenar; ikon 46 px; **kalan saniye** Inter 700 26 px (min metin) 3 px gölge |
| Son 3 sn | rozet α 1↔0,55 yanıp söner **2,5 Hz** + yay incelir; sayı aynı |
| Kapanış | 220 ms ölçek 1→0,6 + solma, kalanlar sola kayar 180 ms |
| Sınırsız şarjör | tambur ortasındaki sayı yerine **∞** (Cinzel/Inter'de U+221E glifi doğrulanmadı → `draw_polyline` ile çiz), halka amber 6 px, tüm 6 yuva dolu amber; doldurma halkası yok |

Renk tek başına değil: ikon + saniye sayısı + yay.

### 2.5 Bomba: yarıçap göstergesi ve patlama

| Aşama | Görünüm |
|---|---|
| Yerde | normal eklenti; oyuncu **500 px'e** yaklaşınca yarıçap önizlemesi (kesikli halka α 0,35, r 320) belirir (konumlanmayı planlatmak için), uzaklaşınca solar |
| Fitil (0,8 sn) | ikonda kıvılcım titreşir; **kesikli halka** r=320, 5 px `#E0584F`, 26/18 px kesikli, 20°/sn döner, iç dolgu `can_kritik→bordo` α 0,08 → 0,28 (doğrusal); son 250 ms halka ölçek nabzı ±%3 (yanıp sönme yok) |
| Patlama | FxRenderer patlaması (mevcut) R=320: parlama + halka + çekirdek, 380 ms; kamera **18 px**, vuruş donması 60 ms; zemin kömürü F5; içerdeki hayatta kalanlar parlama 1,0 + 24 px itme (görsel) ; ölenler E6 |
| Güvenlik | oyuncu patlamadan zarar görmez; XP taşları etkilenmez |

---

## 3. Skor ve yerel en iyi 10

### 3.1 Skor kuralı *(öneri; kesin plan fazı)*

| Bileşen | Öneri |
|---|---|
| Öldürme puanı | Piyade 10 · Karga 8 · Şövalye Hayaleti 50 · Elit Piyade 400 · Elit Şövalye 1.200 · Elit Karga 1.500 · Kale Lordu 10.000 |
| **SERİ çarpanı** (öldürme puanına) | ardışık öldürmeler arasında ≤ 3 sn: ×1 (0–9) · ×2 (10) · ×3 (25) · ×4 (50) · ×5 (100); 3 sn öldürme yoksa **ya da hasar alınırsa** seri sıfırlanır *(hasar kuralı [AÇIK-5])* |
| Evrim bonusu | 2.000 / evrim (kombo = evrim, K7) |
| Hayatta kalma | 5 puan/sn |
| Lord bonusu | 25.000 (Lord öldürülürse) |
| Gösterim | `UiKit.format_thousands` (nokta ayracı), en çok 8 hane ("99.999.999"), tabular rakam; tavan aşılırsa "99.999.999" |

Dökümde "Seri çarpanı" satırı = (çarpanlı toplam − taban toplam). Toplam = taban + seri + evrim + hayatta kalma + Lord.

### 3.2 HUD skoru (`01`, `02`)

| Öğe | Konum (güvenli katman içinde) | Boyut / tip | Davranış |
|---|---|---|---|
| "SKOR" etiketi | sağ 36, üst 284 | Inter 700 26 px, `bronz_300`, +0,16 em | sabit |
| Skor değeri | sağ 36, üst 312 | Cinzel 700 60 px, `kemik_100`, 3 px gölge, sağa hizalı | gösterilen değer gerçeğe 180 ms'de yaklaşır (çubuk ease'i) |
| SERİ çipi | sağ 36, üst 388, yükseklik 48 | Inter 700 28 "SERİ" + Cinzel 34 "×3"; 3 px `bronz_500` kenar, `void` α 0,7 | alt kenarda 5 px ince **kalan süre** çubuğu (3 sn → 0); çarpan ×1 iken **gizli** |
| Kazanç başlığı | çipin solu, top 394 | Inter 700 28 `bronz_300` | yalnız tek kazanç ≥ 400 (elit, Lord, evrim): "+1.500" 900 ms'de solar |

Boyut gerekçesi: skor Süre'den sonra ikinci okuma; 60 px yuvarlak durum için yeterli, 9 hane sığar (≈ 400 px < sütun 460 px). Çakışma: Duraklat (y 140–272) altında 12 px boşluk, aktif yuva satırı x 36–558 → sağ sütun x ≥ 600; Elit/Lord satırı (y 446) çipin 10 px altında, çip x ≥ 780 / satır x ≤ 890 → dikeyde 10 px kopuk (denetim N2 düzeni korunur).

| Durum | Görünüm |
|---|---|
| Sıradan artış | sayı kayar (lerp 180 ms); pop **yalnız** son pop'tan ≥ 300 ms ve artış ≥ 50 ise: ölçek 1→1,08 (80 ms out) →1 (160 ms) |
| Büyük kazanç ≥ 400 | pop 1,18 + 300 ms `bronz_300→kemik` parlama + "+N" başlığı |
| Seri basamağı artar | çip pop 1→1,25→1 (180 ms); çip rengi: ×2 `kemik_300` kenar · ×3–×4 `bronz_300` kenar · **×5 amber kenar + amber ışıma** (ritim ödülü, en yüksek basamak) |
| Seri bozulur | çip 220 ms ölçek 1→0,8 + solma (hafif 4 px sallanma) |
| Oyun duraklı | skor görünür kalır |

### 3.3 Sonuç ekranı skor dökümü (`04`, `04b`, `04c`)

Akış (mevcut ekranın genişletilmesi; ölçü 1080×2400, kolon x 72–1008):

| Blok | y | İçerik |
|---|---|---|
| Başlık + alt başlık + çizgi | 170–400 | mevcut (OYUN BİTTİ / KAZANDIN) |
| **SKOR** hero | 404–570 | "SKOR" (sec-t 34) + değer Cinzel 900 **120 px**; kazanınca ve rekorda amber, kaybedince kemik |
| **YENİ REKOR** | 590–740 | bkz. 3.4 |
| **Döküm paneli** | rekor bandına göre (≈ 760) | 5 satır × 84 px + 24: ikon 48 · etiket Inter 600 32 · ayrıntı Inter 600 24 `kemik_500` · değer Cinzel 700 44 sağa hizalı: **Öldürme**, **Seri çarpanı** (ayrıntı "en yüksek ×5"), **Evrim bonusu** ("2 evrim"), **Hayatta kalma** ("20:00"), **Lord bonusu** |
| İstatistik şeridi | döküm +24 | 3 sütun: Süre · Seviye · Öldürme (ikon 44 · Cinzel 48 · Inter 26 etiket), yükseklik 170 |
| Kurulan kombolar | şerit +24 | slot 80 px + ad Cinzel 36 (`upper_tr`) + çift Inter 26; satır 96; en çok 4 satır görünür (v1 hedefi ~4 evrim), 5.'de "+1" |
| Düğmeler | içeriğin 24 px altı, **en erken y 1500** | TEKRAR OYNA 936×156, ANA MENÜ 936×132, aralık 27 (mevcut) |

Kaybedilen Lord bonusu satırı **%35 opak "—"** ve ayrıntı "Lord'u yen" (boş yuva kuralı, suçlayıcı değil). Evrim yoksa satır %35 opak.
Sığma kontrolü (4 kombo): içerik ≈ 1930'a biter, düğmeler 1954–2269 < 2328 (alt güvenli alan).

**Giriş sırası** (t=0 ekran girişi 220 ms'den sonra; dokunma = hepsini bitir): skor değeri 0→N **900 ms** cubic-out · döküm satırları 300 ms'den başlayıp **120 ms arayla** kayarak girer, her değer 400 ms sayar · YENİ REKOR damgası **1250 ms**'de · düğmeler **1300 ms**'de etkin (atlanırsa 400 ms sonra; kazara basmayı önler, mevcut 800 ms kilit kuralı sürer).

### 3.4 "YENİ REKOR" anı

| Durum | Gösterim |
|---|---|
| Sıra 1 | 936×96 bant: bordo zemin, üst/alt 4 px amber çizgi, ★ ikonu ×2 + "YENİ REKOR" Cinzel 900 56 px, amber ışıma; altında "Önceki en iyi: 154.200" Inter 30. Animasyon: damga — ölçek 1,30→1,0 (280 ms cubic-out) + tek seferlik 600 ms parlak şerit geçişi; titreşim açıksa 40+30+80 ms desen |
| Sıra 2–10 | pill: "EN İYİ 10'A GİRDİN · 4. SIRA" Cinzel 700 38, bronz 4 px kenar; animasyon yalnız 200 ms giriş |
| Dışında | tek satır "10. sıra için gereken: 62.400" Inter 30 `kemik_500` (motive eder, suçlamaz) |
| İlk oyun | liste boşken tüm skorlar rekor sayılır → "YENİ REKOR" |

Işık: tek atımlık, ≤3 Hz kuralı korunur. Kazan/kaybet fark etmez: ölünce de rekor olabilir (başlık "OYUN BİTTİ" kalır, skor amber).

### 3.5 En İyi Skorlar ekranı (`05`, `05b`, `06`)

**Erişim:** Ana menüde OYNA'nın hemen altında yeni ikincil düğme **EN İYİ SKORLAR** (936×132, kupa ikonu 52 px). Menü düzeni: OYNA 180 → 27 → EN İYİ SKORLAR 132 → 27 → SES / TİTREŞİM (454 px) → sürüm. Düğme sütunu üstü 120 + 40 + 132+27 + 132 + 27 + 180 ≈ 2400−685 = y **1715**; ana görsel kutusu 960×1200 → **960×1020** (y 660–1680) küçülür (mevcut kutu 1715'e taşardı). Geri: Android geri tuşu = ekrandan çık; ekranda **GERİ** düğmesi (936×132, alt 72, başparmak bölgesi).

**Düzen** (1080×2400): başlık "EN İYİ SKORLAR" Cinzel 900 80 px y150, alt başlık "Bu cihazdaki en iyi 10 sonuç" Inter 32, çizgi; 10 satır **936×156**, aralık 12, y 360'tan; GERİ altta. Satırlar dokunulmaz (bilgi), kaydırma yok (10 satır sığar: 360–2028).

| Satır parçası | Tip |
|---|---|
| **Sıra rozeti** (x 24) | 84 daire, Cinzel 900 44; 1–3 kalın halka (`bronz_300`, `kemik_300`, `bronz_500`, 8 px), 4–10 ince `bronz_700` 5 px. Renge ek olarak **rakam** |
| **Skor** | Cinzel 700 56 `kemik_100` |
| **Sonuç çipi + süre** | çip 34 px: "✓ KAZANDI" (amber kenar) / "YENİLDİ" (bordo dolgu); yanında süre Inter 600 28 `MM:SS`. Renk + metin + ✓ |
| **Tarih** (sağ) | Inter 600 26 `kemik_500`, "GG.AA.YYYY" |
| **Yeni giriş vurgusu** | sonuç ekranından geliniyorsa o satır 5 px amber kenar + ışıma + "YENİ" etiketi; ekran açılırken o satıra 260 ms kayma-giriş |
| **Boş sıra** | kesikli kenar, %50 opak, "—" |

| Durum | Gösterim |
|---|---|
| Normal / kısmen dolu | yukarıdaki; kalan sıralar boş yuva satırları |
| **Boş (hiç skor yok)** | ortada kesikli yıldız çemberi 160 px, "HENÜZ SKOR YOK" Cinzel 700 56, "İlk oyunundan sonra en iyi on sonucun burada listelenir." Inter 34; **OYNA** birincil düğmesi (180, y 1500) + GERİ |
| Veri bozuk/okunamıyor | boş durum gibi davranır (sessiz) *(öneri; hata iletisi yok, çevrimdışı oyun)* |

**Veri kuralı** *(öneri)*: `user://highscores.json`, `{"v":1,"entries":[{"score","time","won","level","unix"}]}`; skor azalan, **eşitlikte eski kayıt önde**; en çok 10; sonuç ekranından önce yazılır (çökme riski için). Tarih yerel saatten `GG.AA.YYYY`. "Skorları sil" v1.1'de yok **[AÇIK-4]**.

---

## 4. Ekran durumları (özet)

| Ekran | Durumlar |
|---|---|
| Oyun HUD | varsayılan · seri çipi gizli/×2/×3/×4/×5/bozuluyor · skor pop/büyük kazanç · rozet 0–3 · son 3 sn yanıp sönme · ∞ tambur · bomba fitili (dünya) · ekran dışı eklenti oku |
| Oyuncu | duruş · yürüme · dönme · atış · doldurma · hasar · seviye vurgusu · ölüm |
| Sonuç | kazan+rekor#1 (`04`) · kaybet+sıra N (`04b`) · kaybet+rekorsuz (`04c`) · kombosuz · Lord bonusu yok · sayma animasyonu / atlanmış |
| En İyi Skorlar | dolu (rekor vurgulu / menüden) · kısmen dolu · boş |
| Ana menü | varsayılan · düğme basılı (6 px aşağı) · odak: OYNA |

## 5. Token ve ölçü tabloları

### 5.1 Yeni token'lar (mevcut `tokens.json`'a eklenir; yeni renk icat edilmedi)

| Token | Değer | Kaynak |
|---|---|---|
| `rarity_common` | `#CFC4AE` | kemik_300 |
| `rarity_uncommon` | `#D2B47E` | bronz_300 |
| `rarity_rare` | `#E8A24A` | amber_glow |
| `bomb_ring` | `#E0584F` | can_kritik |
| `buff_track` | `#3A2E28` | mermi_bos |
| `record` | `#E8A24A` | amber_glow |
| `shadow_ground` | `#000000` α 0,38 | — |
| `ash` | `#3A322E` | yeni nötr (kahve ailesi, yalnız ölüm külü) |
| `mock_note` | `#8DB58A` | dogru (yalnız maket ölçü işareti) |

Tip: skor 60 (Cinzel 700) · skor hero 120 (Cinzel 900) · rozet saniye 26 (Inter 700, min) · SERİ 28/34 · döküm değer 44 (Cinzel 700) · sıra rozeti 44 · liste skoru 56.

### 5.2 Ölçü tablosu (px, 1080×2400)

| Öğe | Boyut | Konum |
|---|---|---|
| Skor sütunu | 220×96 | sağ 36, üst 284 |
| SERİ çipi | ≥160×48 | sağ 36, üst 388 |
| Etki rozeti | 108×108, aralık 12 | x 231 + n·120, alt 72 |
| Yerdeki eklenti | ikon 80, parlama 140×80, gölge 60×16 | — |
| Ekran dışı ok | 84 daire | kenar 50, güvenli içi |
| Bomba yarıçapı | 320 (çap 640) | dünya |
| Ana menü yeni düğme | 936×132 | y 1715+180+27 |
| Sonuç skor hero | 120 px yazı | y 404–570 |
| Rekor bandı | 936×96 | y 590 |
| Döküm satırı | 864×84 (panel 936 − 2×36 iç boşluk) | panel içi |
| Skor listesi satırı | 936×156, aralık 12 | y 360 + n·168 |
| GERİ düğmesi | 936×132 | alt 72 |

### 5.3 Hareket token'ları (ms)

`recoil_kick 40` · `recoil_back 110` · `muzzle_flash 80` · `hit_flash 90` · `hit_tint 200` · `hit_knock 50` · `hit_spring 220 (12 Hz)` · `turn 70` · `levelup_preroll 180` · `levelup_ring 450` · `death_freeze 120` · `death_fall 600` · `death_total 1300` · `win_total 1800` · `enemy_flash 125` · `enemy_death 220/420/700/900` · `lord_telegraph 600` · `lord_slam 120` · `lord_enrage 900` · `bomb_fuse 800` · `pickup_fly 120` · `pickup_toast 700` · `score_ease 180` · `score_pop 80+160` · `result_count 900` · `result_row_stagger 120` · `record_stamp 280` · `result_buttons 1300`. Easing: mevcut `cubic-out`; ölüm devrilme `quad-in`.

## 6. Erişilebilirlik

- **Renk tek başına anlam taşımaz:** nadirlik = renk + parlama biçimi + nabız hızı; rozet = ikon + saniye + yay; sonuç çipi = ✓/metin; bomba yarıçapı = kesikli halka + dolgu; Lord öfkesi = renk + "ÖFKE" etiketi; sıra = rakam.
- **Kontrast:** yeni metinler Inter/Cinzel `kemik_100/300` ve `bronz_300` zeminleri `mor_700/800/900` üzerinde (DESIGN-UI tablosundaki ≥ 8,4:1 çiftler); `kemik_500` yalnız ikincil (tarih/ayrıntı, 6,5:1).
- **Min metin 26 px**; rozet saniyesi 26, skor etiketi 26.
- **Dokunma:** yeni dokunulabilirler: EN İYİ SKORLAR (936×132), GERİ (132), OYNA boş durumda (180); hepsi ≥ 132 px, aralık 27. HUD'daki skor/rozet/ok bilgi amaçlıdır, dokunulmaz → başparmak bölgesi serbest.
- **Tek el:** yeni eylemler alt yarıda; Lord/boss gibi üst bilgiler değişmez.
- **Işık/hareket:** hiçbir şey >3 Hz; ekran sarsıntısı ≤ 18 px; vuruş donması ≤ 150 ms; hasar parlaması ≥150 ms aralıklı. Azaltılmış hareket önerisi §1.1-7.
- **Türkçe:** Cinzel ile gösterilen tüm dinamik metin (eklenti adları, rekor pill'i, boss/öfke etiketi, tür adları) `UiKit.upper_tr` (i→İ, ı→I); `to_upper()` yasak (FINDINGS N1). Sabit etiketler büyük harfle yazılı: "EN İYİ SKORLAR", "YENİ REKOR", "KAZANDI", "YENİLDİ", "GERİ". Test önerisi: eklenti/etiket adında `i` varsa görüntüde `İ`.
- **Güvenli alan:** FINDINGS N7'ye uygun, yeni tam ekran (En İyi Skorlar) ve menü düğmesi de `safe_extra` katmanından geçmeli; HUD skor sütunu mevcut `safe` katmanındadır.
- **Odak:** En İyi Skorlar'da varsayılan odak GERİ; boş durumda OYNA.
- **Ekran okuyucu:** `accessibility_name` (varsa): "Skor 184.350", "Seri çarpanı 3", "Hasar artışı, 7 saniye kaldı".

## 7. Maket dizini (`mock/`)

| Dosya | İçerik |
|---|---|
| `01-hud-skor-eklenti.png` | HUD: skor, SERİ, eklentiler, bomba halkası, rozetler, toast, ok |
| `02-hud-anatomi.png` | aynı + ölçü kutuları |
| `03-eklenti-katalogu.png` | 6 eklenti × 3 durum |
| `04-sonuc-skor-rekor.png` · `04b-…-sira.png` · `04c-…-rekorsuz.png` | sonuç ekranı durumları |
| `05-en-iyi-skorlar.png` · `05b-…-bos.png` | liste ve boş durum |
| `06-ana-menu.png` | yeni düğme ile menü |
| `07-animasyon-oyuncu-pozlar.png` · `08-animasyon-dusman-pozlar.png` | anahtar pozlar (gerçek görsellerle CSS dönüşümü, yaklaşık) |
| `09-animasyon-egriler.png` | zaman eğrileri |
| `pickups/*.svg` | eklenti ikon önerileri (96×96, DESIGN-UI §9 diliyle) |
| `*.html`, `mock.css` | kaynak (`docs/ui/mockups/ui.css`'i kullanır) |

Maket notları: Chromium ile üretildi (`--headless --screenshot`), Godot render'ı değildir; HUD sayıları kod (`hud.gd` TOP=96) değerleridir. Maketler ve kaynak `.gdignore` ile Godot dışı bırakıldı. Pose maketleri CSS dönüşümüdür; mesh/shader etkileri (etek, atkı, kül) gösterilmemiştir.

## 8. Açık noktalar (kullanıcı kararı gerekir)

1. **Bomba davranışı:** önerilen "toplanınca toplama noktasında 0,8 sn fitil" mi, yoksa "oyuncunun üstünde anında" mı? (Etki: yarıçap önizleme ve oyun hissi.)
2. **Eklenti doğma kuralı** (aralık, ağırlık) ve sayılar *öneri*; kesin değer plan/denge fazı.
3. **Ekran dışı eklenti oku**: v1.1'e dahil mi (öneri: evet, küçük) ya da yalnız yerdeki görünüm mü?
4. **Skorları sil** seçeneği v1.1'de yok; istenirse En İyi Skorlar'a "SIFIRLA" (onay diyaloglu) eklenebilir.
5. **Seri hasarda bozulsun mu?** (öneri: evet; yalnız 3 sn zaman aşımı daha az cezalandırıcıdır.)
6. **İsimlendirme:** "kombo" = evrim; çarpana "SERİ" dedik. Sonuç dökümündeki "kombo/evrim" satırı "Evrim bonusu" yazıldı. Onay?
7. **Sonuç gecikmesi:** ölüm 1,3 sn / kazanma 1,8 sn (dokunma ile atlanır). Onay?
8. **Sonuç ekranından "SIRALAMAYI GÖR"** bağlantısı v1.1'de yok (düğme bütçesi); istenirse rekor bandına 132 px'lik dokunulabilir hale getirilir.
9. **Cihaz doğrulaması** gerekenler: düşman animasyon maliyeti (≤0,4 ms), ∞ glifi, gölge MultiMesh maliyeti, kenar oku güvenli alan.
10. (b) görseller isteğe bağlı: B1 en değerli; hiçbiri uygulamayı bloke etmez.
