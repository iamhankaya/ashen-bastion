# Ashen Bastion v1 — Son tasarım denetimi — Bulgular

Görev: T20261023-65 · Rol: Senior UI/UX Designer (denetim) · Tarih: 2026-10-23 · Denetlenen: entegrasyon branch'i `vlad/T20261023-55` (merge: "Already up to date"; HEAD `08fc5e3` = uygulama-2 + PR #9 sonrası).
Girdiler: `docs/design/2026-10-23-ashen-bastion-v1-design.md`, `docs/ui/DESIGN-UI.md`, `docs/pipeline/T20261023-62-uygulama-2-raporu.md`, `docs/design/audit/ara-denetim/FINDINGS.md`. (`T20261023-61-*` raporu yok; ara denetimin kendisi okundu.)

## Yöntem
- Godot 4.7.2, xvfb + `--rendering-driver opengl3`, 1080×2400 dikey (Mesa llvmpipe). Senaryolar: `tools/capture/shots.gd` (menu, game, crowd, ruins, boss, lord, levelup, pause, win, lose, contrast) + bu denetimin ek betikleri `capture/audit1–4.gd.txt` (gerçekçi/doğal doğuş, düşük can, evrim kartı, Şifa kartı, onay diyaloğu, kombolu kazandın, joystick). `.txt` uzantısı: Godot projeye almasın; çalıştırmak için `.gd` yapıp proje dışından `-s` ile verin.
- Görüntüler 1080×2400'den 540×1200'e küçültüldü (`screens/01…18`); **`K1…K5` 1× (kırpma, küçültme yok)**. Küçültülmüş görüntü ile 1× kırpmalar gözle karşılaştırıldı: glif ve kontur bulguları (#N1, #N5) yalnız 1× kırpmada ayırt edilir.
- Dokunma hedefleri düğüm dikdörtgenlerinden (`get_global_rect`) ölçüldü. 1 dp ≈ 2,75 px varsayımı → 48 dp = 132 px.
- Skill'ler: `ui-ux-pro-max` ve `impeccable` (yalnız audit/critique) kullanılabilir listedeydi; denetim kriterleri (kontrast, dokunma hedefi, güvenli alan, durumlar, Türkçe) bunlara ve DESIGN-UI §8'e göre uygulandı. Kod değiştirilmedi.
- Betik yapaylıkları (bulgu sayılmadı): `shots.gd`'nin `crowd`/`game` senaryoları can'ı 1e9 yapar (HUD sayısı taşar) ve düşmanları halka/spiral dizer; bu yüzden gerçekçi kare için `audit2` (doğal doğuş, 14:25) ayrıca alındı. Sonuç ekranlarındaki sayılar 600 ms sayma animasyonundadır (ara değer görünebilir).

## Bulgu özeti
Yeni: Kritik 0 · Yüksek 1 (N1) · Orta 1 (N2) · Düşük 6 (N3–N8). Ara denetim #1–#11: 9 giderildi, 2 açık (#8 kısmen, #11). Kapı: aşağıda.

## A. Ara denetim #1–#11 durumu

| # | Önem (ara) | Durum | Doğrulama / kanıt |
|---|---|---|---|
| 1 | Yüksek | **Giderildi** | Düşman ve oyuncu açık kontur (rim) taşıyor; rim rengi `#BDA478` ≈ zemin `#1E1818`'e göre **≈7,3:1** (hesaplandı), `test_contrast.gd` ≥3:1 yeşil. Kalabalıkta ve 6'lı karga/piyade/şövalye dizisinde tüm düşmanlar ayrışıyor. `screens/18-kontrast-6-dusman.jpg`, `03-hud-gec-oyun.jpg`, `K4-rim-kontur-1x.jpg` |
| 2 | Orta | **Giderildi** (cihaz hissi doğrulanmadı) | `MAX_RADIUS` 195, `DEAD_ZONE_PX` 24 (sabitler `input_gate.gd` içinde). Ekranda taban çapı ≈390 px; 140,−80 px sapma → hareket (0,70; −0,40), ölü bölge altı sıfır. `screens/09-joystick.jpg` |
| 3 | Orta | **Giderildi** (cihazda doğrulanmadı; bkz. #N7) | Ölçüm: rozet sol ≈38 px, XP çubuğu sağ 1044 (kenar 36), Duraklat sağ 1044 (36), yuvalar/tambur ≥36. Güvenli alan payı `UiKit.safe_extra` + `get_display_safe_area` ile HUD'da uygulanıyor; masaüstünde pay 0 olduğundan çentik davranışı görüntülenemedi. `K2-hud-elit-cubuk-1x.jpg`, `02-hud-baslangic.jpg` |
| 4 | Orta | **Giderildi** | DEVAM ET y=1228–1384 (maket ≈1200–1355), ANA MENÜ y=1729–1861 (maket ≈1730–1860); düğme aralığı 27 px. Başlık HUD yuva satırlarının hemen altında (başlık kutusu y=380; pasif yuva alt kenarı ≈434 → kutu örtüşüyor ama harfler %80 scrim altında ayrışıyor), okunur. `13-duraklatma.jpg`, `14-duraklatma-onay.jpg` |
| 5 | Orta | **Giderildi** | Oyuncu 200 px, rim + sıcak ışık halkası; zeminde net. Harabe önünde zayıflama için bkz. #N5. `02`, `03`, `09`, `K3` |
| 6 | Düşük | **Giderildi** | Süre etiketi kutusu y=134–232, XP çubuğu alt kenarı y=136 (ara denetimde 124'tü): rakamlar çubuktan görünür biçimde ayrık. `K2` |
| 7 | Düşük | **Giderildi** | Joystick HUD'ın altında çiziliyor; tambur joystick tabanının üstünde kalıyor. `09-joystick.jpg` |
| 8 | Düşük | **Kısmen / açık** | Kazandın alt başlığı kullanıcı kararıyla duruyor (✓ doğrulandı). Boş durumda kombo paneli hâlâ ≈460 px yüksek (2 satır içerik), panel→düğme arası ≈375 px ölü boşluk; 3 kombolu durumda panel kısalıyor ama boşluk ≈375 px kalıyor. Raporda "yapılmadı" olarak belirtilmişti. `15`, `16`, `17` |
| 9 | Düşük | **Giderildi** | SES 454×132 / TİTREŞİM 458×132, açık/kapalı eşit genişlik (kod: eşit genişlik). "ASH AND STEEL" kullanıcı kararıyla uygulanmış (✓, `main_menu.gd:89`; Cinzel'de glif sorunu yok). Ana görsel menüde yerinde. `01-ana-menu.jpg` |
| 10 | Düşük | **Giderildi** | Duraklat `FOCUS_ALL`, seviye kartlarında ilk kart odakta (altın kenar `10`, `11`'de görünüyor), menüde OYNA, duraklatmada DEVAM ET, onayda VAZGEÇ varsayılan odak. |
| 11 | Düşük | **Açık** | Şarjör kapasitesi için görsel üst sınır tanımı yok (raporda "yapılmadı"). Değişmedi; düşük. |

## B. Yeni bulgular

| # | Önem | Ekran | Bulgu | Kanıt | Beklenen |
|---|---|---|---|---|---|
| N1 | **Yüksek** | Seviye atlama kartı, kazandın kombo listesi (ve her yerde beceri adı gösteren Cinzel etiketi) | **Türkçe `i` noktasız çiziliyor.** Beceri adları karışık harfli veriden geliyor (`data/skills/*.json`: "Barut Kesesi", "Son Mermi Patlar"); Cinzel'de küçük harf yok, küçük harf `i` küçük-büyük harf olarak **`I`** çiziliyor. Sonuç: **BARUT KESESI, SON MERMI PATLAR, KIYAMET MERMISI, MERMI FIRTINASI, ŞIFA** (doğrusu İ). Etkilenen 20 becerinin **11'i**: Barut Kesesi, Çevik Çizme, Çift Tabanca, Dinamit, Fazladan Mermi, Keskin Nişan, Kıyamet Mermisi, Mermi Fırtınası, Seken Mermi, Son Mermi Patlar, Zincirleme Patlama; ayrıca "Şifa" kartı. Aynı kartta etiket "YENİ"/"ŞİFA" (Inter) doğru noktalı → tutarsızlık. Başlıklarda `SEVİYE`, `AKTİF` doğru (kodda büyük harf yazılmış). Harf anlam değiştirir ("MERMI" ≠ "MERMİ"). Ara denetim "Türkçe doğrulandı" demişti; veri kaynaklı adlar o zaman ekranlanamamıştı. | `screens/K1-kart-basliklari-1x.jpg` (1×), `10`, `11`, `12-sifa-karti.jpg` (ŞIFA vs etiket ŞİFA), `17-kazandin-kombolu.jpg` (KIYAMET MERMISI, MERMI FIRTINASI) | Cinzel ile gösterilen her dinamik ad Türkçe büyük harfe çevrilmeli (`i→İ`, `ı→I`; `to_upper()` değil — gate yasaklıyor) ya da adlar veride büyük harfle yazılmalı; Cinzel 700 ile kontrol et. Yeni beceri eklendiğinde yakalayan bir test (adda `i` varsa görüntüde `İ`). |
| N2 | Orta | Oyun HUD'ı (elit/Lord can çubuğu) | **Boss/Lord çubuğu zayıf ve oyuncu canına yapışık.** Çubuk 460×32 px, adı 24 px (DESIGN-UI min 26), x=420–880, y=220–252: oyuncu can çubuğunun (x 60–420) hemen sağında **boşluksuz** (bordo üstüne bordo → tek uzun çubuk gibi okunuyor), üstte süre rakamlarının hemen altında. Sayı/yüzde yok. Kale Lordu (20 dk finali) elit ile aynı boy ve stilde — final dövüşünde "bu bir boss" hissi yok. En yüksek `max_hp`'li tek elit gösteriliyor (iki elit varsa diğeri çubuksuz; `06-elit-uc-tur` üç elit, tek çubuk). | `07-lord-bandi-cubuk.jpg`, `K2-hud-elit-cubuk-1x.jpg`, `06-elit-uc-tur.jpg`; kod `hud.gd:217-233` | Çubuk oyuncu canından ayrı bir satıra (süre altı, ortada, tam genişlik ~700 px) ya da ayrı renk (amber/mor kenar + boss ikonu); ad ≥26 px; Lord için daha kalın çubuk. Tasarım kararı (kullanıcı onayı): DESIGN-UI'da bu çubuk tarif edilmemiş, yeni eklenmiş. |
| N3 | Düşük | Oyun alanı (kalabalık) | **Rim konturu inceltildikten sonra da kalabalıkta belirgin.** Kullanıcı kararı uygulandı (✓: düşman 2,2→1,5, elit/Lord 3,6→2,5, oyuncu 3,0→2,1 px; ≈%30–32). Ölçüm: oyun alanının **%0,6'sı** (14:25 doğal doğuş, 84 düşman) ila **%2,35'i** (143 düşmanlı yapay yığın) kontur renginde; yığılmada konturlar tel kafes/"çıkartma" gibi birleşiyor. Tek tek düşmanda kontur ince ve zarif; 40–80 düşmanda hâlâ sahnenin en parlak öğesi (zemin lum ≈23/255, kontur ≈160/255). Önem düşük: okunurluğa zarar vermiyor, fayda 7,3:1 ile fazlasıyla yeterli. | `04-kalabalik-yapay.jpg`, `03-hud-gec-oyun.jpg`, `K4-rim-kontur-1x.jpg` | Cihazda bakılsın; gerekirse kontur opaklığı ≈%70'e (kontrast ≥3:1 kalır) ya da yalnız yakın düşmana tam kontur. `RIM_*` sabitleri. |
| N4 | Düşük | Seviye atlama | "GUNSLINGER" etiketinin **R harfi tabanca namlusuna değiyor**, "SEVİYE 2" başlığı namlu ve saç üzerinden geçiyor (portre kırpması başlıkla yarışıyor). Okunur (açık kemik / koyu üst gradyan) ama gürültülü; bronz etiket parlak namlu üstünde 3:1'in altına düşebilir (ölçülmedi). | `K5-seviye-baslik-1x.jpg`, `10` | Başlık bloğunu namlunun soluna sıkıştır ya da portreyi 60–80 px sağa kaydır; etikete 3 px gölge/koyu perde. |
| N5 | Düşük | Oyun alanı | **Oyuncu harabe/yapı önünde silüetini kaybediyor.** Oyuncu rim rengi (`0.80,0.72,0.56`) ile düşman rimi (`0.74,0.64,0.47`) aynı sıcak ailede; harabenin açık taşları önünde (14:25 karesi) palto ve rim taş dokusuna karışıyor, tek ayırıcı ayak ışığı. `test_contrast.gd` yalnız zemin dokusuna karşı ölçüyor. | `K3-oyuncu-harabe-onunde-1x.jpg`, `03-hud-gec-oyun.jpg` | Oyuncu rimini düşmandan ayır (daha açık/soğuk beyaz-kemik) ya da harabe önünde oyuncunun altına ışık/gölge; testi harabe dokularıyla genişlet. Cihazda gözle doğrula. |
| N6 | Düşük | Boss/elit (oyun alanı) | **Elit/Lord rimi beyaza kaçıyor**: Lord'un pelerin kenarı neredeyse saf beyaz ve kalın tırtıklı, diğer düşmanlardaki bronz kontur ve oyuncu rimiyle tutarsız (Lord "kesilmiş kağıt" gibi duruyor). Bant (KALE LORDU GELİYOR) üstünü kısmen örtüyor (geçici). | `07-lord-bandi-cubuk.jpg` | Elit/Lord rimini aynı bronz/amber tonda tut, yalnız kalınlıkla ayır. |
| N7 | Düşük | Menü, seviye atlama, duraklatma, sonuç | **Güvenli alan yalnız HUD'da uygulanıyor** (`apply_safe_area` tek çağrı, `hud.gd:130`; menü/duraklatma/seviye atlama/sonuç `safe_extra` kullanmıyor). Üst içerik y≥130 px (seviye atlama başlığı y=130, menü üst yazı y=150) → 96 px varsayılan çentik payının üstünde; ama çentik/durum çubuğu >130 px olan cihazda ve HUD için de pay Android'de pencere boyutu oturmadan hesaplanırsa 0 kalır (rapordaki "yeniden uygulanmıyor" küçük bulgusu). Cihazda doğrulanmadı. | `01`, `10`, `13`, `16`; kod `hud.gd:130,262` | Tüm tam ekran ekranlar aynı güvenli alan katmanından geçsin; `size_changed`/`window_resized` ile yeniden uygula. Redmi Note 13 Pro'da doğrula. |
| N8 | Düşük | Duraklatma | Eylem sıralaması: başparmak bölgesinde (y>1440) en altta **yıkıcı** ANA MENÜ ve BAŞTAN BAŞLA, en üstte birincil DEVAM ET (y merkez 1306 = %54; başparmakla ikinci sıra). Makete uygun ve onay diyaloğu koruyor (VAZGEÇ odakta), ama tek elle sağ başparmak için en rahat bölge yıkıcı eylemlerde. | `13-duraklatma.jpg`, `14-duraklatma-onay.jpg`; ölçüm: DEVAM ET 1228–1384, ANA MENÜ 1729–1861 | Düşük: DEVAM ET'i alt bölgeye al (maket değişikliği) ya da yıkıcıları ayır. Onay diyaloğu yeterli kabul edilebilir. |

## C. Ekran ekran durum özeti

| Ekran | Durum | Not |
|---|---|---|
| Ana menü (`01`) | Uygun | "ASH AND STEEL" ✓; OYNA 939×180, SES/TİTREŞİM 454/458×132, aralık 27 px, tümü alt %20'de; ana görsel Cinzel başlıkla uyumlu; sürüm satırı okunur. Namlu alevleri ekran kenarında kesik (bilinçli, belge). |
| HUD (`02`,`03`,`05`) | Uygun | Üst %18 + sol alt; oyun alanı serbest. Debug etiketi ("düşman N/M … kesme düzeltmesi") yalnız debug derlemede (`OS.is_debug_build()`); release'te yok, ama sol altta tambur yanında 26 px dokunulabilir alan kaplıyor (debug). |
| Joystick (`09`) | Uygun | HUD altında; ikinci parmak/ölü bölge ara denetimde doğrulanmıştı, değişmedi. |
| Düşük can (`08`) | Uygun | Kırmızı vinyet + sayı `18 / 100` + çubuk rengi; renk bağımsız (sayı + vinyet). |
| Seviye atlama (`10`,`11`,`12`) | **N1, N4** | Kartlar 984×324, aralık 27 px, evrim kartı sekizgen + amber ışıma + "EVRİM"/"Yeni form" etiketi ✓ (renk bağımsız), en alta konuyor ✓, ilk kartta odak ✓, Şifa tek kart ✓. |
| Duraklatma + onay (`13`,`14`) | Uygun (N8) | Diyalog: VAZGEÇ odakta, ANA MENÜYE DÖN bordo; metin Türkçe doğru. |
| Boss uyarısı ve çubuk (`07`) | **N2, N6** | Bant 132 px, KALE LORDU GELİYOR amber çizgili; ARA BOSS metni de var. Çubuk zayıf. |
| Oyun bitti / Kazandın (`15`–`17`) | Uygun (#8 açık) | Alt başlık ✓ ("Şafak söktü; kale seni yutamadı."); istatistik simgeleri + sayılar ✓; kombo satırlarında N1 glif sorunu; düğmeler 156/132 px, 800 ms kilit. |
| Kontrast (`18`) | Uygun | 3 tür × 2 düşman ve oyuncu zeminden net. |

## D. Doğrulananlar
- **Dokunma hedefleri ≥132 px (≥48 dp) ve aralık ≥27 px:** menü OYNA 939×180, SES/TİTREŞİM 454/458×132; duraklatma DEVAM ET 939×156, SES/TİTREŞİM 454/458×132, BAŞTAN BAŞLA/ANA MENÜ 939×132; diyalog 864×132; seviye kartları 984×324; sonuç TEKRAR OYNA 936×156, ANA MENÜ 936×132; Duraklat 132×132. Hiçbir eksik hedef yok. Tek elle: menü ve sonuç eylemleri alt yarıda, kartlar alt %50'de, Duraklat üst sağda (kazara basılmaz).
- **Kullanıcı kararları uygulanmış:** menü üst yazısı "ASH AND STEEL"; kazanma alt başlığı "Şafak söktü; kale seni yutamadı."; rim ≈%30 ince (1,5/2,5/2,1 px).
- **Türkçe:** İ/ı/Ş/Ğ/Ç/Ö/Ü doğru — **istisna #N1** (Cinzel'de dinamik adlardaki küçük harf `i`).
- **Görsel tutarlılık:** karanlık gotik zemin/harabe + manhwa portre/oyuncu; bordo/mor/bronz/kemik paleti ve amber yalnız ritim/evrim/uyarıda kullanılıyor; gerçek düşman atlasları, portre ve menü ana görseli yerinde; yer tutucu daire düşman görülmedi.

## Kapsam dışı / doğrulanamayanlar (bulgu değil)
- SFX yok (bilinen). Harita chunk sınırı harabe çakışması (bilinen) — denetimde çakışma yakalanmadı.
- Cihaz: FPS, gerçek dokunma/joystick hissi, çentik/güvenli alan, shader derlemesi, rim görünümü, TalkBack. xvfb yazılım GL cihazı temsil etmez.
- Lord faz değişimi (%50 can) ve Lord dövüşünün tamamı oynanmadı; yalnız uyarı bandı ve çubuk görüldü.
- 1–2 kartlı seviye atlama: 1 kart (Şifa) görüldü; 2 kart ayrıca ekranlanmadı (kod yolu aynı).
- `T20261023-61-*` raporu repoda yok.

## Gate
Bu görev yalnız `docs/design/audit/son-denetim/` altına dosya ekledi (`.gdignore` ile Godot dışı bırakıldı). `bash tools/gate.sh` sonucu raporda.
