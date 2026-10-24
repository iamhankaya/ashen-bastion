# Ashen Bastion v2.0 — Ara denetim (K dilimi sonrası)

Görev: T20261024-63 · Rol: Senior UI/UX Designer (denetçi) · Tarih: 2026-10-24
Entegrasyon: `vlad/T20261024-51` ile `Already up to date` (HEAD `48c9733`, K = `7b949cb`).
Kapsam: ana menü yeni düzeni, Karakterler vitrini (dolu / seçili / kilitli / tek karakter / portre yok), seviye atlama başlığı ve portresi (Gunslinger, Barutçu) ↔ `docs/design/v2.0/DESIGN.md` §3–§6 + `mock/01`, `02*`, `05*`.
Dışında: B (başarımlar) ve M dilimleri; bilinen/kayıtlı konular tekrar edilmedi ("GUNSLİNGER" noktalı İ, vitrin sırası Barutçu önce, başlangıç becerisi ikon çerçevesi yok).

## Yöntem

- Godot 4.7.2, `xvfb-run` + `--rendering-driver opengl3` (llvmpipe), 1080×2400. Repo betiği `tools/capture/shots.gd` (`menu`, `chars`, `chars_b`, `chars_lock`, `levelup`, `levelup_b`) + kendi betiğim `capture/cap_k.gd.txt` (çentik, tek karakter, portresiz; geçici olarak `tools/capture/` altına kopyalanıp çalıştırıldı ve **silindi**; üretim koduna ve veriye dokunulmadı, test GameData kopyası `load_dir("res://data")` ile).
- Çentik payı: `apply_safe_area(Vector4(48,130,48,80))` (menü, vitrin, seviye atlama).
- Ekran görüntüleri depo boyutu için **720×1600**'e küçültülüp paletlendi (`screens/NN-*.png`); bulgulardaki koordinatlar **orijinal 1080×2400** pikselidir (görüntü koordinatı × 1,5).
- Mock karşılaştırması: `docs/design/v2.0/mock/*.png`.
- Kod okuması yalnız kanıt/kök neden içindir; düzeltme yazılmadı.

## Sonuç özeti

K dilimi vitrin ve seviye atlama, mock'a **büyük ölçüde sadık**: sahne/panel/kart şeridi/düğme yerleşimi, kilit durumu (gri sahne, halka, rozet, neden satırı), seçili durum, tek karakterde şerit+sayaç gizleme, portre yokken çökmeme, seviye atlama başlık bloğu ve gradyan okunurluğu doğrulandı. **Kritik bulgu yok. 1 yüksek, 2 orta, 5 düşük bulgu var.** En önemlisi: **çentikli cihazda ana menü başlığı ana görselle çakışıyor (K-01)**; ikincisi vitrinde **SEÇ düğmesinin birincil (bordo) stilini kaybetmesi (K-02)**.

### Tasarıma uyduğu doğrulananlar (kanıtlı)

| Kontrol | Gözlem | Beklenen |
|---|---|---|
| Vitrin yerleşimi | başlık y≈135, sahne y≈190–1250, panel 936 geniş, kart şeridi ortalı 2 kart, SEÇ y≈2013, GERİ y≈2196 (`03`) | §4 |
| Seçili durum | amber kenar+ışıma, ✓ rozeti kartta, "✓ SEÇİLİ" çip (`03`) | §4 / 02b |
| Kilitli durum | sahne gri+karanlık, 240'lık halka+kilit, kartta kilit rozeti, "KİLİTLİ" düğme + "İlk Kan başarımını aç" satırı okunuyor; neden satırı ölçülen kontrast: en açık piksel (239,231,214) / zemin (33,24,50) ≈ 13:1 (`05`) | §4 / 02c, kontrast ≥ 9,8:1 |
| Tek karakter | kart şeridi ve sayaç gizli; alt boşluk mock `02d` ile **aynı** (`07`) | 02d |
| Portre alanı boş / dosya yok | sahne varsayılan portreye düşer, çökmez (`08`, `09`) | §4 durum tablosu |
| Çentik — vitrin | başlık üst pay kadar iner, sahne payı emer, alt düğmeler ≥156 px alt boşlukla (GERİ alt kenarı y≈2244) (`06`) | N7 |
| Seviye atlama başlığı | üst yazı + "SEVİYE N" gradyan üzerinde okunuyor (Gunslinger `10`, Barutçu `11`); kartlar taşmıyor | §6.1 |
| Seviye atlama çentik | alt pay kartları+ipucunu yukarı alır, başlık yerinde (`12`) | N7 |
| Seviye atlama portresiz | bordo radyal zemin, başlık aynı yerde (`13`) | 05c |
| Min metin 26 px | çip 26, panel etiketleri 26, neden satırı 28 (kod) | §8 |
| Konsol | xvfb koşularında script hatası yok (yalnız ses sürücüsü uyarısı: ortam) | — |

## Bulgular

| # | Önem | Ekran | Bulgu | Kanıt | Beklenen (DESIGN.md referansı) |
|---|---|---|---|---|---|
| K-01 | **Yüksek** | Ana menü, çentikli cihaz | Üst güvenli alan 130 px verilince başlık bloğu ≈76 px aşağı iniyor, ana görsel (alt paya göre konumlanıyor) yerinde kalıyor: "BASTION" satırı (y≈490–600) ile ana görselin kafası (y≈535'ten itibaren) **≈65 px üst üste biniyor**; "TION" harfleri karakterin saçına biniyor. Çentiksiz görünümde (`01`) çakışma yok. | `screens/02-menu-centik.png` (çakışma) ↔ `screens/01-menu.png`. Kod: `main_menu.gd:305` `_head.offset_top = HEAD_TOP + maxf(0, e.y − 54)` başlığı üst paya göre kaydırır; `:308–310` `hero` yalnız `up` (alt pay) ile kayar — başlık–görsel aralığı üst payı hesaba katmıyor. | Başlık ile ana görsel arasında çentikte de boşluk korunur; üst pay görseli ve/veya başlığı birlikte kaydırır ya da görsel küçülür (menü maketi `01`, N7 "üst pay etkilemez/başlığı iter" kuralı; DESIGN-UI üst güvenli alan 96). |
| K-02 | Orta | Vitrin — SEÇ durumu (odak seçili değil) | "SEÇ" birincil eylem olmasına rağmen **bordo birincil stilini kaybediyor**: düğme GERİ ile aynı mor, yalnız amber ışıma farkı. Mock'ta SEÇ bordo (`02`). Üç durumda (SEÇ / SEÇİLİ / KİLİTLİ) düğmeler aynı mor ailesinde; "şimdi eylem var" sinyali yok. | `screens/04-vitrin-barutcu.png` ↔ `mock/02-karakterler.png`. Kod: `characters_screen.gd:144` düğme `&"primary"` ile kurulur, `:495` SEÇ durumunda `theme_type_variation = &""` ile varyasyonu siliyor; `:534–537` stil geçersiz kılmaları da kaldırılıyor. | SEÇ = birincil (bordo), SEÇİLİ = mor_700 + amber, KİLİTLİ = pasif mor_800 (§4 durum tablosu, `02`/`02b`/`02c`). |
| K-03 | Orta | Vitrin — kart şeridi, portresiz/eksik portreli karakter | Sahne portresi yoksa varsayılan portreye düşüyor ama **kart şeridindeki kart düz kahverengi blok** (≈ #7A5A3C) kalıyor: görsel yok, yalnız ad. Ek: release'te "YER TUTUCU" etiketi yok → Barutçu sahnesi Gunslinger'ın renk ayarlı kopyası olarak görünüyor (`04`). | `screens/08-vitrin-portresiz-barutcu.png`, `09-vitrin-portre-dosyasi-yok.png` (sol kart düz blok). | Kartta da aynı varsayılan portre kırpması (ya da tutarlı nötr yer tutucu); §4 "portre yoksa varsayılan portreye düşer, çökmez" kartları da kapsamalı. |
| K-04 | Düşük | Vitrin — "✓ SEÇİLİ" düğmesi | Düğme metni **krem**, tasarım **amber** (7,8:1) istiyor. Kod `font_color` amber veriyor ama odaktaki düğme `font_focus_color` kullanıyor (SEÇİLİ durumunda odak var), bu geçersiz kılınmamış. | `screens/03-vitrin-gunslinger.png` ↔ `mock/02b-karakterler-secili.png`. Kod: `characters_screen.gd:540–543` font_color/hover/pressed/disabled var, `font_focus_color` yok (varsayım: kök neden). | amber metin (§4, `02b`). |
| K-05 | Düşük | Vitrin — ad yanı çip | "✓ SEÇİLİ" / "KİLİTLİ" çipi mock'taki kapsül/rozet değil **düz metin**; kilit durumunda 🔒 glifi yok (renk+metin var, D8 karşılanıyor). Çip taban çizgisi adın taban çizgisinin ≈27 px üstünde kalıyor. | `screens/05-vitrin-kilitli.png` (y≈1120 çip, ad y≈1150) ↔ `mock/02c-karakterler-kilitli.png`. | "🔒 KİLİTLİ" kapsül çip (§4 durum tablosu); ad ile alt hizalı. |
| K-06 | Düşük | Ana menü | Maketle küçük farklar: başlık dış parıltısı ve "A S H  A N D  S T E E L" geniş harf aralığı yok; düğmeler maketteki dikey gradyan yerine düz dolgu; ana görselin arkasındaki radyal zeminin dairesel kenarı hafifçe seçiliyor (yumuşak sönümlenme yok). | `screens/01-menu.png` ↔ `mock/01-ana-menu.png`. | `01` mock'u: parıltı, aralık, gradyan, yumuşak zemin. |
| K-07 | Düşük | Ana menü — ana görsel | Namlu ateşi parıltıları görsel kutusunun dikey kenarında **dik kesiliyor** (x≈198 ve x≈882). Maketteki aynı asset'te de var; asset kaynaklı, v1.1'den miras. | `screens/01-menu.png`. | Parıltı yumuşak biter (asset kenar boşluğu/solma). |
| K-08 | Düşük | Seviye atlama — kartlar | Aynı listede iki ikon çerçevesi dili karışık: yuvarlak madalyon (Barut Kesesi, Mıknatıs, Çevik Çizme) ↔ kare plaka (Şarapnel, Dinamit, Seken Mermi). K dilimi değil, v1.1 kökenli; seviye atlama başlık/portre denetimi sırasında görüldü. | `screens/10-seviye-gunslinger.png`, `11-seviye-barutcu.png`. | Tek çerçeve dili (seviye atlama §6). |

## Önerilen düzeltmeler (Developer görevi için)

1. **K-01 (Yüksek)** — `scripts/ui/main_menu.gd` `apply_safe_area`: başlık üst payla indiğinde ana görsel kutusunu aynı üst pay farkı kadar aşağı al (ya da boşluk yetmezse görseli ölçekle). *Kabul:* `apply_safe_area(Vector4(48,130,48,80))` render'ında "BASTION" alt kenarı ile görselin üst kenarı arasında ≥ çentiksiz aralık (`01`'deki ≈ 0 px örtüşme değil, pozitif aralık); çentiksiz görünüm bayt olarak değişmez; alt düğmeler çentikte taşmaz. Test: menü düzeni için üst/alt pay birim testi.
2. **K-02 (Orta)** — `characters_screen.gd` `_refresh_state` SEÇ dalı: `theme_type_variation`'ı `&"primary"` olarak koru (SEÇİLİ/KİLİTLİ'de stil geçersiz kılmaları zaten ayrı). *Kabul:* SEÇ durumu render'ı `mock/02`'deki bordo birincil düğmeyle eşleşir; SEÇİLİ ve KİLİTLİ görünümü değişmez; `select_button_state` testleri yeşil.
3. **K-03 (Orta)** — Kart (`_make_card`) portre yoksa varsayılan portre kırpmasını kullansın (sahnedeki düşme ile aynı kaynak). *Kabul:* `08` ve `09` senaryosunda kart düz blok değil; çökme yok; kilitli+portresiz kombinasyonu okunur.
4. **K-04 (Düşük)** — SEÇİLİ stilinde `font_focus_color`'ı da amber yap. *Kabul:* düğme metni amber (≥7,8:1).
5. **K-05 (Düşük)** — Ad çipini kapsül stile ve ad taban çizgisine hizala; kilitli çipe kilit glifi ekle. *Kabul:* `05` render'ı `02c` ile eşleşir.
6. **K-06 / K-07 / K-08 (Düşük)** — M dilimi cila turuna al; v1.1 cila listesine ekle (K-07 görsel asset düzeltmesi kullanıcı/AI görseli gerektirebilir).

## Kabul kriterleri

- [x] Numaralı, kanıtlı bulgular: K-01…K-08, ekran görüntüleri `screens/` altında.
- [x] Üretim koduna dokunulmadı: yalnız `docs/design/audit/v2.0-ara/` altına yazıldı; geçici yakalama betiği silindi (`git status` temiz).

## Açık noktalar (denetlenemedi / kullanıcıya)

Cihaz gerektirenler (kullanıcı listesine):
- Gerçek çentikli cihazda menü/vitrin/seviye atlama yerleşimi (K-01 doğrulaması).
- Vitrin hareketleri: nefes, sürüklenme, kor parçacıkları, 260 ms çapraz solma, SEÇ onay animasyonu, 12 parçacıkla cihaz kare süresi — yalnız durağan karelerle denetlendi.
- Yatay sürükleme/ok tuşu ile gezinme ve ekran okuyucu (`accessibility_name`) davranışı — kod okundu, çalıştırılamadı.
- 2× yazı boyutu: depoda bir yazı ölçeği ayarı yok; **büyük yazı denetimi yapılmadı** (masaüstü render yalnız 1×).
- "Azaltılmış hareket" ayarı repoda yok (K raporunda da not edildi).

Kullanıcı kararı gerektirenler (uygulanmaz):
- **Barutçu görseli/adı/konsepti:** release'te vitrin ve seviye atlama portresi, Gunslinger portresinin renk ayarlı kopyası ve "YER TUTUCU" etiketi yalnız debug yapıda görünür (`11`) → oyuncu iki karakteri portreden ayıramaz; gerçek görsel gelene kadar bilinçli yer tutucu (K-03 ile birlikte düşünülmeli).
- Mock'taki Gunslinger-önce sıra ve noktalı İ: kayıtlı, tekrar edilmedi.

Ortam notları: Godot 4.7.2 ilk koşuda `--import` gerektirdi (sınıf önbelleği yok); bu repo dosyalarını değiştirmedi (`git status` yalnız denetim dizini). Önceki yakalama denemelerinde `GameData.load_default()` paylaşılan önbelleği bozduğundan kendi betiğim `load_dir` kopyasına geçti (harness hatası, ürün bulgusu değil).
