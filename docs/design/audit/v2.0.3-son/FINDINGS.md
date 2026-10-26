# v2.0.3 son denetim (T20261026-67)

Kapsam: ana sayfa, ayarlar (+2×, sessiz/hareket azalt, lisanslar), başarım ekranı, karakter seçimi (hareketli/statik portre), oyun içi küreler. Head 0845aae (entegrasyon). Araç: Godot 4.7.2 + xvfb 1080×2400 (`tools/capture/shots*.gd`; görüntüler 540 genişlik, `screens/`), kod okuması. Karşılaştırma: `docs/design/v2.0.3/DESIGN.md`. **Kritik yok, yüksek yok**; 3 orta, 5 düşük, 1 bilgi. Ara denetimin (T65) yüksek #1'i kapanmış (BÜYÜK YAZI ayarı + 2× düzen çalışıyor).

## Bulgular
| # | Önem | Ekran | Bulgu | Kanıt | Beklenen |
|---|---|---|---|---|---|
| 1 | Orta | Başarımlar | GERİ hâlâ eski mor/indigo dolgulu + altın kenarlı; ayarlar GERİ'si taş/bronz pahlı. Yeniden tasarım turunda dışarıda kalmış, ekranlar arası dil kopuk | `screens/ach_kismi.png` vs `settings_menu.png` | §1 C1/C2: mor yalnız XP; GERİ `dugme-hayalet` taş levha |
| 2 | Orta | Karakter seçimi | Tüm ekran eski dilde: mor (`MOR_700/800/900`) kartlar, yuvarlak 18 px köşe, mor GERİ/SEÇİLİ düğmeleri; ana sayfa/ayarlar/başarımlarla aynı oyundan görünmüyor. Hareketli portre ekranın tek "yeni" öğesi | `screens/hareket_gunslinger.png`, `azalt_zyfen.png`; `characters_screen.gd:261,267,587,603,648` | §1 C1 token eşlemesi tüm ekranlar için (`tas_*`, pahlı çerçeve) |
| 3 | Orta | Ana sayfa (2× tek sütun) | Karakter zemin yaması OYNA ile KARAKTERLER arasında şerit olarak taşıyor (ara denetim #5 açık); ikonlar kart üst-soluna yaslı, metin ortada (dikey hizasız) | `screens/menu_2x.png` y≈735–750, ikonlar y≈770/880 | §2 `01d`: hizalı, yama sahne kutusuna kırpılı |
| 4 | Düşük | Başarımlar (boş) | "Henüz kademe açılmadı…" paneli listenin üst solma bandında kırpık (üst kenar kesik) | `screens/ach_bos.png` y≈265 | §4.4 `03b`: panel tam görünür, solma ilk satırın altında |
| 5 | Düşük | Başarımlar | Üstteki ilk sticky grup başlığı (THE WATCH, kısmi) solma bandı altında sönük; "4/10" okunmuyor. Kroniği mühürleri (5) aynı görünüyor: grup ilerlemesi (dolu/aktif/sönük) ayırt edilmiyor | `screens/ach_kismi.png` | §4.1 mühür 3 durumu; başlık soluklaşmaz |
| 6 | Düşük | Ana sayfa | KARAKTERLER mini portresi kartın sol kenarına bitişik, "KARAKTERLER" başlığıyla 4–6 px boşlukta, kenarı kare (yuvarlak değil, bronz halka yok) | `screens/menu.png` y≈1000 | §2 kademe 2: 68 px yuvarlak mini portre + bronz halka, ≥16 px boşluk |
| 7 | Düşük | Ayarlar | `70%` hâlâ (tasarım `%70`, ara #7 açık karar); lisanslar satırı dosya adı göstermiyor ama lisanslar ekranı içeriği doğrulanmadı (`licenses.png` bkz.); sessiz ray kontrastı ölçülmedi (ara #9) | `screens/settings_menu.png`, `settings_reduce.png` | §3 |
| 8 | Düşük | Oyun içi (küreler) | Normal küre çok küçük (~14 px @1080); kalabalıkta (300) yalnız renk/şekilden ayrılıyor, elit mor ile boss turuncu iyi ayrışıyor. Normal tür küçüklüğü dokunmatikte toplama okunurluğunu zorlar (görsel olarak yeterli; oynanış kararı değil) | `screens/orbs_zoom.png`, `orbs_crowd.png` | brif: 3 tür ayırt edilir — karşılanıyor; normal için min. ~20 px öneri |
| 9 | Düşük | Repo | `docs/review/v2.0.3-a-previews/` (~6,5 MB) kapanışta silinmeliydi | `du` | T61 açık noktası |
| 10 | Bilgi | Oyun içi | `düşman N/M taş N/M …` ve `dokun:` debug etiketleri yalnız debug build | `screens/game.png` | release'te yok |

## Geçenler (kanıtlı)
- Küreler: normal buz mavisi / elit mor / boss turuncu ateş; hem renk hem silüet farklı, koyu zeminde okunur (`orbs_zoom.png`).
- Ana sayfa: ASH AND STEEL korunmuş, `Sürüm 2.0.3`, OYNA 3 kademe hiyerarşisi, `0/53` halka; çentik payı var (`menu_notch.png`).
- Ayarlar: bölüm başlıkları + levha kartlar, AÇIK/KAPALI sözcüklü kor mührü, 2× düzende anahtar etiketin altına sarar, GERİ sabit, kaydırma çubuğu var (`settings_2x.png`).
- Başarımlar: seviye rozeti + segmentli çubuk + satır açılınca kademe yolu (tarih / ilerleme / hedef) çalışıyor; kilitli = silüet + kilit; Türkçe büyük harf doğru (`ach_satir_acik.png`).
- Hareket azalt: Zyfen statik portre yedeğine düşüyor (`azalt_zyfen.png`).

## Önerilen düzeltmeler (Developer)
1. (#1,#2) Başarımlar GERİ ve Karakter seçimi ekranını `tas_*` + pahlı çerçeve diline taşı; kabul: dört ekranda aynı GERİ bileşeni, `MOR_*` yalnız XP öğelerinde.
2. (#3) 2× tek sütun: ikon/metin dikey ortalama, zemin yamasını sahne kutusuna kırp; kabul: `menu_2x` görüntüsünde şerit yok.
3. (#4,#5) Boş durum panelini listeye taşı; mühürlere durum ver; sticky başlığı soluklaştırma.
4. (#6) Mini portre yuvarlak + bronz halka + boşluk.
5. (#7,#8,#9) Sonraki turda; #9 silinmeli.

## Denetlenemedi
Cihaz, TalkBack, akıcılık, hareketli portre/ana sayfa hareketi (tek kare), seviye atlama/ödül bildirimleri, başarım ekranının 2× hâli (senaryo yok — **bu bir boşluk**: `shots_ach.gd`'ye 2× senaryosu eklenmeli), lisanslar ekranı içeriği.
