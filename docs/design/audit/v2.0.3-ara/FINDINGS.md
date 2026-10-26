# v2.0.3 ara denetim — ana sayfa ve ayarlar (T20261026-65)

Kapsam: uygulama D (head 5c899e1). Araç: xvfb 1080×2400, `tools/capture/shots.gd` (menu, menu_notch, menu_2x, settings_menu, settings_reduce, licenses), kod okuması (`settings_screen.gd`, `main_menu.gd`), piksel kontrastı (WCAG). Görüntüler 540×1200 küçültülmüş: `screens/`. Karşılaştırma: `docs/design/v2.0.3/DESIGN.md` §2–§3, §8. Kritik bulgu yok; 1 yüksek.

| # | Önem | Ekran | Bulgu | Kanıt | Beklenen |
|---|---|---|---|---|---|
| 1 | **Yüksek** | Ana sayfa / ayarlar (2× yazı) | 2× yazı düzeni kodda var (`set_font_scale`) ama çağıran yok (Godot Android'de yazı ölçeğini vermiyor): cihazda 2× kullanıcı hiç tek sütun almaz; ayarlarda 2× düzeni (02c) hiç yok | `main_menu.gd:9` çağıran yok; `settings_screen.gd` font_scale yok; `menu_2x.png` yalnız zorlanmış durumda | §2 `01d`, §3 `02c`, §8 "2× yazıda sarma, kesilme yok": ölçek kaynağı bağlanmalı (ör. Android `Settings.System.font_scale` köprüsü ya da oyun içi "BÜYÜK YAZI" ayarı) ve ayarlar 2× düzeni eklenmeli |
| 2 | Orta | Lisanslar | Kart kaydırmasız (`ScrollContainer` yalnız ana liste); 2× ya da içerik artınca GERİ'nin altına taşar | kod: tek `ScrollContainer` (satır 132); `licenses.png` | §3: liste kaydırılır, GERİ sabit |
| 3 | Orta | Ayarlar (sessiz) | Üzeri çizili hoparlör simgesi yok; sessizlik yalnız metin + ton + anahtar | `settings_reduce.png` (TÜM SESLER KAPALI) | §3 S3: ana satırda çizili hoparlör (`can_kritik`) |
| 4 | Orta | Ana sayfa | Mini portre yerine genel kişi ikonu; BAŞARIMLAR halkası boş yıldız (0/22; tasarım 0/53 kademe) | `menu.png` düğme satırı | §2 kademe 2: 68 px mini portre; ilerleme halkası `31/53` biçiminde (C beslemesine bağlı) |
| 5 | Orta | Ana sayfa (2× tek sütun) | Düğme ikonları kartın üstüne yaslı, metin ortada: dikey hizasız; OYNA ile KARAKTERLER arasında zemin yaması şeridi görünür | `menu_2x.png` (y≈1240–1260 / 1300) | §2 01d: hiçbir şey kesilmez, hizalı; zemin yaması sahne kutusuna kırpılmalı |
| 6 | Düşük | Ana sayfa (1×) | Karakter koyu mor palto, harabe yığını üstünde; kemer ışığı yok, silüet zayıf (yalnız namlu ışığı ayırıyor) | `menu.png` | §2 katman 2–3: kapı arkası ışığı karakterin ARKASINDA olmalı |
| 7 | Düşük | Ayarlar | `%70` yerine `70%` (açık karar); düz kahverengi degrade, taş duvar dokusu yok; liste solması/kaydırma ipucu yok (içerik sığıyor, 2×'te gerekir) | `settings_menu.png` | §3 atmosfer, 8 px kaydırma ipucu |
| 8 | Düşük | Lisanslar | "LICENSES-audio.md" dosya adı kullanıcıya gösteriliyor (cihazda açılamaz); zemin düz, ayarlardaki sıcak ışık yok; yalnız lisans adı, atıf metni yok | `licenses.png` | §3 02d; lisans özeti ya da repo dışı erişilebilir metin |
| 9 | Düşük | Ayarlar sessiz | Sönük ray/tutamak (`muhur`/`ray-dolgu-sessiz`) düşük kontrastlı; tutamak metni ölçülü 5,35:1 (geçer), ray ölçülmedi | `settings_reduce.png` | §3: değer soluklaşmaz (karşılanıyor) |
| 10 | Bilgi | Tüm | `düşman 1/1 taş 0/0 …` etiketi (yalnız `OS.is_debug_build()`) görüntülerde; release'te yok | `game_controller.gd:179` | debug APK'ya özgü; bulgu değil |

## Geçenler (kanıtlı)
- Çentik: başlık ~100 px iner, düğmeler sabit (`menu_notch.png`); ayarlar/lisanslar `apply_safe_area` kapsamında (kod 547–575).
- Kontrast (ölçüldü): sürüm `kemik_500`/void 6,93:1; açıklama 10,05:1; Gunslinger alt satırı 8,44:1; sessiz notu 10,05:1 — hepsi ≥4,5.
- Dokunma: ROW_H/SLIDER_H/BACK_H 132 px (kod), ana sayfa yarım düğmeler ≈454×132.
- Türkçe büyük harf: İ/Ş/Ü doğru (BAŞARIMLAR, EN İYİ SKORLAR, TİTREŞİM, LİSANSLAR); AÇIK/KAPALI sözcüğü anahtarla birlikte (renk tek kanal değil).
- Hareket azalt açıkken ayarlar ekranı doğru; anahtar durumu görünür.

## Önerilen düzeltmeler (Developer)
1. (#1) 2× kaynağını bağla (Android köprüsü ya da oyun içi büyük yazı ayarı), ayarlar 2× düzeni + testi; kabul: `menu_2x`/`settings_2x` görüntüsünde kesilme yok, GERİ sabit.
2. (#2) Lisans kartını `ScrollContainer`'a al; kabul: 2× simülasyonda GERİ görünür.
3. (#3) Çizili hoparlör simgesi (`frames/`); kabul: sessizde simge + metin.
4. (#4) Mini portre + ilerleme halkası (C verisi gelince); kabul: 31/53 biçimi.
5. (#5) 2× tek sütunda ikon dikey ortalama ve zemin yaması kırpma.
6. (#6–#9) sonraki turda; #8'de dosya adını kaldır.

## Denetlenemedi
Cihaz/TalkBack/dokunmatik his, performans, hareketli sahne (kül/meşale/sancak) tek kare, ayarlar 2×, başarımlar ve karakter seçim ekranı (kapsam dışı).
