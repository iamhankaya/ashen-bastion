# Ashen Bastion v2.0 — Son denetim

Görev: T20261024-66 · Rol: Senior UI/UX Designer (denetçi) · Tarih: 2026-10-24
Entegrasyon: `vlad/T20261024-51` ile `Already up to date` (HEAD `3242433`: tüm v2.0 dilimleri K M B + v1.1.1 aktarımı + düzeltme payı T64).
Girdi: ara denetim `docs/design/audit/v2.0-ara/FINDINGS.md` (K-01…K-08), T64 kapanış raporu, `docs/design/v2.0/DESIGN.md` + `mock/`.
Üretim koduna dokunulmadı; yalnız `docs/design/audit/v2.0-son/` altına yazıldı.

## Yöntem

- Godot 4.7.2, `xvfb-run` + `--rendering-driver opengl3` (llvmpipe), 1080×2400, `XDG_DATA_HOME` yalıtılmış (kullanıcı kaydına yazılmaz). Betik: `capture/cap_son.gd.txt` (repoya kopyalanmadan `-s <mutlak yol>` ile koşuldu; başarım depoya 3 kayıt yazıldı, yalnız yalıtılmış dizinde).
- Ekran görüntüleri depo boyutu için **720×1600** paletlenmiş (`screens/NN-*.png`); koordinatlar bulgularda **orijinal 1080×2400** pikselidir. `screens/18-…` ham kırpıntılardır (1:1 piksel).
- Kapsam: ana menü (çentikli/çentiksiz), karakter vitrini (dolu, seçili, SEÇ, kilitli, portresiz, çentikli), seviye atlama (Gunslinger, Barutçu), oyun içi başarım bildirimi (tek + kuyruk), başarımlar ekranı (üst, kaydırılmış/yapışkan başlık, çentikli), sonuç ekranı (çipsiz, çipli, çipli+çentikli), debug etiketleri üst şeridi (oyun karesi).
- Ekstra ölçüm: `Label.get_line_count/get_line_height` ile bütün başarım açıklamaları; vitrin beceri ikonu için çerçeve gizlenerek yeniden yakalama (kök neden kanıtı).
- Masaüstü genişlik yalnız tasarım çözünürlüğüdür (1080×2400, Godot canvas); gerçek cihaz genişlikleri, 2× yazı ve hareketler **denetlenmedi** (Açık noktalar).

## Sonuç özeti

**Kritik ve yüksek bulgu yok.** Ara denetimin Yüksek bulgusu (K-01) ve iki Orta bulgusu (K-02, K-03) giderilmiş; K-04 giderilmiş, K-05 kısmen (yeni küçük kusur SD-04). K-06/K-07/K-08 açık (düşük, plana bilinçli ertelendi). T64 raporundaki "Dinamit ikonu asset'i eksik" teşhisi **yanlış**: `assets/ui/icons/dinamit.svg` ve `cift-tabanca.svg` var, vitrinde **her iki** karakterin başlangıç becerisi ikonu çerçevenin altında kalıp görünmüyor (SD-01, Orta). Yeni bulgular: 3 Orta, 3 Düşük.

## Ara bulguların durumu

| Ara # | Önem | Durum | Kanıt |
|---|---|---|---|
| K-01 | Yüksek | **Giderildi** | `02-menu-centik.png`: çentik payıyla "BASTION" ile ana görsel arasında pozitif boşluk, başlık–görsel aralığı `01`'deki ile aynı; alt düğmeler taşmıyor. |
| K-02 | Orta | **Giderildi** | `04`, `05`: SEÇ bordo birincil; GERİ mor. SEÇİLİ (`03`) ve KİLİTLİ (`06`) görünümü değişmedi. |
| K-03 | Orta | **Giderildi** | `07`: portresiz Barutçu kartı artık düz blok değil (varsayılan portre kırpması + soğuk ton + "B" monogramı). Release'te de Gunslinger'dan ayırt edilir. |
| K-04 | Düşük | **Giderildi** | `03`: "✓ SEÇİLİ" metni amber (odaktayken de). |
| K-05 | Düşük | **Kısmen** | `06`: çip kapsül, ad taban çizgisine hizalı, kilit glifi var; ama glif "K" harfine biniyor → SD-04. |
| K-06 | Düşük | **Açık** | `01`: başlık parıltısı, "A S H  A N D  S T E E L" harf aralığı, düğme gradyanı, radyal zemin yumuşatma hâlâ yok (harf aralığı Label'da motor kısıtı). |
| K-07 | Düşük | **Açık** | `01`: namlu ateşi parıltıları görsel kenarında dik kesiliyor (asset kaynaklı, kullanıcı/AI görseli). |
| K-08 | Düşük | **Açık** | `11`, `12`: seviye atlama kartlarında yuvarlak madalyon ↔ kare plaka çerçeve dili karışık (v1.1 kökenli). |
| (T64 not 5) beceri ikon çerçevesi | — | **Hatalı uygulandı** | Çerçeve geldi ama ikonu örtüyor → SD-01. |
| (T64 not 6) yapışkan grup başlığı | — | **Kısmen** | Çalışıyor ve iterek değişiyor; ama arkasından satır metni görünüyor → SD-02. |
| (T64 not 8) BounceDebug sığdırma | — | **Giderildi** | `13`: üç etiket şeridi taşmadan sığıyor ("YUMUŞAK 2/3"). |

## Tasarıma uyduğu doğrulananlar (kanıtlı)

| Kontrol | Gözlem | Beklenen |
|---|---|---|
| Ana menü | OYNA y≈1556, KARAKTERLER \| BAŞARIMLAR altında seçili ad ve `0/22`, sürüm satırı `Sürüm 2.0 · Gunslinger` (`01`) | §3 |
| Vitrin | sahne/panel/kart şeridi/SEÇ/GERİ yerleşimi, `1/2` sayacı, ✓ rozet, kilit halkası+rozet+neden satırı "İlk Kan başarımını aç" (`03`, `06`) | §4 |
| Vitrin çentik | başlık ve sahne payı emer, GERİ alt güvenli alanda (`05`) | §4.1 |
| Seviye atlama | başlık "SEVİYE 2" alt gradyanda, ad üst satırı `GUNSLINGER`/`BARUTÇU` (noktalı İ yok), kartlar taşmıyor (`11`, `12`) | §6.1 |
| Oyun içi bildirim | y≈820, 780×120, "BAŞARIM AÇILDI" + ad + kademe baklavaları; HUD ile kesişmez; ikinci bildirim kuyrukta (`13`, `14`) | §5.2 |
| Başarımlar | özet `3 / 22 açıldı`, çubuk, grup başlıkları (baklava + sayaç), açık satırda ✓ + tarih, kilitli satırda soluk ikon + kilit + `0/10` çubuk, "TEK KOŞU · Hedef N" çipi (`08`) | §5.1 |
| Başarımlar çentik | başlık payla iner, GERİ güvenli alanda (`10`) | §5.1 |
| Sonuç | çipsizde v1.1 düzeni; çipte "YENİ BAŞARIM · 3", ilk iki ad + `+1`; kombo paneli ve düğmeler sığıyor; çentikte kayma tutarlı (`15`, `16`, `17`) | §5.3 |
| Debug şeridi | `düşman N/M taş N/M`, `dokun: AÇIK kaçışta 0 girilen 0`, `dokun: AÇIK YUMUŞAK 2/3` üst şeritte, HUD üstüyle kesişmez (`13`) | proje notu |
| Konsol | script/motor hatası yok (yalnız ortam kaynaklı `ERR_CANT_OPEN` kullanıcı-verisi ve çıkışta kaynak uyarısı) | — |

## Bulgular

| # | Önem | Ekran | Bulgu | Kanıt | Beklenen (DESIGN.md referansı) |
|---|---|---|---|---|---|
| SD-01 | **Orta** | Vitrin — başlangıç becerisi | "BAŞLANGIÇ BECERİSİ" satırındaki 84 px çerçeve **boş görünüyor** (hem Çift Tabanca hem Dinamit). İkon dokusu yüklü (`cift-tabanca.svg`, 64×64, görünür) ama **çerçeve dokusu ikondan sonra eklendiği için üstte çiziliyor**; çerçevenin opak iç dolgusu ikonu örtüyor. T64 raporunun "Dinamit ikonu asset'i eksik" teşhisi yanlış (`assets/ui/icons/dinamit.svg` mevcut). | `screens/03-…png`, `18-zoom-…png` (üst kırpıntı: boş çerçeve); çerçeve gizlenince ikon göründü (ham yakalama, bu oturum). Kod: `characters_screen.gd:205–220` `_skill_icon` önce, `SkillFrame` sonra `add_child` edilir; yorum "çerçeve dokusu üstte" ters. | İkon çerçeve içinde görünür (§4.1 bilgi paneli ② "84 çerçeveli ikon"); HUD/seviye atlama ile aynı sıra: çerçeve altta, ikon üstte. |
| SD-02 | **Orta** | Başarımlar — yapışkan grup başlığı | Yapışkan başlık ("ORTA ◆◆◇◇ 0/9") **şeffaf**: altından kayan satırın adı ("SERİ USTASI") başlık bandının içinden okunuyor, "ORTA" etiketi sönük görünüyor. Sticky düğümü `_fade_top` perdesinin **altına** yerleştirilmiş (`move_child(sticky, _fade_top.get_index())`) ve zemin α 0,97; üstte kalan perde başlığı da soldurur. | `screens/09-…png` ve `18-…png` (ikinci kırpıntı: "SERİ USTASI" başlığın içinde). Kod: `achievements_screen.gd` `_update_sticky`. | Yapışkan başlık opak/okunur kalır, içerik altında kaybolur (§5.1 "yapışkan grup başlığı"; D8 okunabilirlik). |
| SD-03 | **Orta** | Başarımlar — satır açıklaması | İki açıklamanın **ikinci satırı kırpılıyor**: "İki farklı karakterle 5 dakika hayatta **kal.**" ve "Sonsuz Tambur sırasında 100 düşman öldür." (2. satır "öldür." görünmüyor — varsayım: aynı kök neden, yalnız birincisi görüntülendi). Etiket 68 px yüksek, `clip_text`, 2 satır 35×2 = 70 px gerekiyor; `get_line_count()=2`, `need=70 > h=68` yalnız bu iki açıklamada. Anlam kaybı: "5 dakika hayatta" (kal- eksik). | `screens/09-…png` (satır "ÇİFTE YOL"), `18-…png` (üçüncü kırpıntı…son); ölçüm: 40 açıklamadan yalnız 2'si >1 satır, ikisi de 70>68. Kod: `achievements_screen.gd:425–432`. | Açıklama en çok 2 satır ve **tam görünür** (§5.1.1: Inter 400 28/34, ≤60 karakter doğrulayıcı sınırı bu iki metni zaten içeriyor). |
| SD-04 | Düşük | Vitrin — "KİLİTLİ" çipi | Kilit glifi çip metnine bitişik; glif "K" harfinin üstüne biniyor (okunurluk düşük, D8 metin kaybolmuyor). | `screens/06-…png`, `18-…png` (alt-orta kırpıntı: 🔒K). Kod: `characters_screen.gd` `_chip_lock` konumu. | "🔒 KİLİTLİ" kapsül çip: glif ile metin arasında ≥ 8 px boşluk (mock `02c`). |
| SD-05 | Düşük | Vitrin — yer tutucu monogram | Barutçu sahnesinde dev translucent "B" monogramı yüzün tam üstüne biniyor ve kilitli durumda kilit halkasıyla çakışıyor (iki işaret üst üste). Yer tutucu amaçlı doğru, ancak portre/halka okunurluğunu düşürüyor. Nihai görsel gelince kalkar; kullanıcı kararı. | `screens/04-…png`, `06-…png`, `07-…png`. | Yer tutucu sahne okunur: monogram yüzden uzak (alt/sol) ya da daha soluk; kilit halkasıyla çakışmaz (§4.3 "yer tutucu", mock `07`). |
| SD-06 | Düşük | Debug etiketleri üst şeridi — çentikli cihaz (**varsayım**) | Etiket şeridi sabit `Y=6` ve güvenli alanı bilmiyor (`DebugLabels`). Üst kenarda çentik/kamera deliği ya da durum çubuğu varsa üç etiket ve 3-dokunuş hedefleri ekran dışında/delik arkasında kalır; "iki durumu karşılaştır" protokolü (AÇIK/KAPALI) cihazda uygulanamaz. Masaüstünde çentik yok → doğrulanamadı. | Kod: `scripts/debug/debug_labels.gd:9` `const Y := 6.0`; `game_controller.gd` safe-area çağrıları şeridi içermiyor. `13` (çentiksiz doğru). | Debug şeridi `UiKit.current_safe_extra().y` kadar iner (yalnız debug APK; release'te yok). |

## Önerilen düzeltmeler (Developer görevi için)

1. **SD-01 (Orta)** — `scripts/ui/characters_screen.gd` `_build` beceri satırı: `SkillFrame`'i `_skill_icon`'dan **önce** ekle (ya da ikona `move_child` ile üstte bırak); koddaki "çerçeve üstte" yorumunu düzelt. *Kabul:* vitrin render'ında Çift Tabanca ve Dinamit ikonları çerçeve içinde görünür (örnekleme: çerçeve iç alanında ikon renk pikselleri var); `test_skill_icon_has_84px_frame` korunur + yeni test `SkillIcon.get_index() > SkillFrame.get_index()`.
2. **SD-02 (Orta)** — `achievements_screen.gd` `_update_sticky`: yapışkan başlığı `_fade_top` **üstüne** al (`move_child` ile sona) ve zemini opak yap (α 1,0). *Kabul:* kaydırma `scroll_vertical=1500` render'ında başlık bandı içinde satır metni görünmez; başlık yazısı tam kontrast; mevcut `test_sticky_group_header_follows_scroll_and_hides_at_top` yeşil.
3. **SD-03 (Orta)** — `achievements_screen.gd:428` açıklama yüksekliğini 2 satıra yetecek kadar artır (≥ 72 px; satır alt payını buna göre ayarla) ya da yazı 26 px'e in. *Kabul:* tüm başarım açıklamaları için `d.get_line_count()*d.get_line_height() <= d.size.y` testi (22 kayıt); "Çifte Yol" ve "Sınırsız Kırım" iki satır tam görünür.
4. **SD-04 (Düşük)** — `_chip_lock` konumunu çip metninin sol kenarından ≥ 8 px dışarı al (çip genişliğini glif kadar büyüt). *Kabul:* `06` render'ında glif ile "K" arasında boşluk; `test_k05_*` korunur.
5. **SD-05 (Düşük)** — Kullanıcı kararı bekliyor (nihai Barutçu görseli). İstenirse monogramı alt-sol köşeye al/yüzde soluklaştır; kilit halkası varken monogramı gizle. Gerçek görsel gelince `placeholder:true` kalkar.
6. **SD-06 (Düşük, debug)** — `DebugLabels` Y'sini güvenli üst payla kaydır; cihazda doğrulama kullanıcı listesinde (G bölümü).
7. **K-06 / K-07 / K-08** — v2.0 sonrası cila listesinde kalsın (K-07 asset: kullanıcı/AI görseli).

Not: SD-01…SD-03 düzeltmesi tek küçük developer görevidir (iki dosya, üç test); sonra tester yalnız bu ekranları yeniden yakalar.

## Esin kaynağı adı kontrol listesi

| Alan | Sonuç |
|---|---|
| Kod (`scripts/`, `test/`, `tools/`) | **temiz** |
| Veri (`data/`, `assets/` dosya adları, `.import`) | **temiz** |
| Docs (`docs/`, v2.0 spec/plan/design/mock/prompts, bu denetim) | **temiz** (v1 tasarım belgesi yalnız "başka bir eserin adı geçmez" kuralını söyler) |
| Commit mesajları (`git log`, 232 commit) | **temiz** |
| Dosya adları (`git ls-files`) | **temiz** |
| Yöntem ve sınır | Görevde ad verilmediği için tarama (a) ad-bağımsız ifade desenleri (esinlenme/klon/benzeri/…-tarzı), (b) aday ad listesi ile `git grep` (kod+docs+dosya adı) ve `git log` gövde taraması olarak yapıldı. **Otomatik koruma yok**; adı bilen kişinin (VLAD/kullanıcı) tek `git grep -i`/`git log --grep` koşusuyla kesinleştirmesi önerilir (adı rapora yazmamak için denetçi çalıştırmadı). |

## Kabul kriterleri

- [x] Tüm v2.0 ekranları ve akışları gezildi (Açık noktalar hariç); ara bulguların durumu tabloda.
- [x] Kritik/yüksek yok; orta/düşük bulgular için düzeltme önerisi yazıldı.
- [x] Üretim koduna dokunulmadı: yalnız `docs/design/audit/v2.0-son/` altına yazıldı.

## Açık noktalar (denetlenemedi / kullanıcıya)

- **Gerçek cihaz:** çentik, kamera deliği, yuvarlak köşe, gerçek genişlikler (vitrin kaydırma/ok tuşu gezinmesi, ekran okuyucu `accessibility_name`) — kodla/masaüstüyle görüldü, cihazda koşulmadı. Cihaz listesi `docs/dev/user-verify.md` v2.0 bölümünde kullanıcıda.
- **Hareketler:** vitrin nefes/sürüklenme/kor, 260 ms çapraz solma, SEÇ onayı, bildirim giriş-çıkış animasyonu, başarım yapışkan başlığın akıcılığı — yalnız durağan karelerle denetlendi.
- **2× yazı / azaltılmış hareket:** repoda yazı ölçeği ve azaltılmış hareket ayarı yok → **büyük yazı denetimi yapılmadı**.
- **Gate/CI/APK:** bu görevin kapsamı dışı (tester T20261024-65 paralel doğruluyor).
- **Kullanıcı kararı:** Barutçu konsepti/adı/görseli, Dinamit/Çift Tabanca ikon sanatı (ikonlar mevcut yer tutucu SVG; nihai sanat kullanıcıdan), başarım ödülü (şu an yalnız kayıt), denge (uygulanmaz).
