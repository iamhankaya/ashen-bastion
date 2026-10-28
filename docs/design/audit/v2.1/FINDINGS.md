# v2.1 denetim (T20261027-37)

Kapsam: ana sayfa koşu şeridi, KOŞU ekranı, duraklatma çipleri, sonuç ekranı (çipler, Kolay notu, sıra satırı), skor sekmeleri, Sonsuz kilometre taşı bandı. Head c7f87bd (entegrasyon `vlad/T20261027-15`, U4a + U4b dahil). Karşılaştırma: `docs/design/v2.1/DESIGN.md`, `mock/`, `tokens-v2.1.md`.

**Yöntem ve sınır (önemli):** bu denetim **statik**: kod okuması (`scripts/ui/run_strip.gd`, `run_screen.gd`, `main_menu.gd`, `pause_screen.gd`, `result_screen.gd`, `highscore_screen.gd`, `milestone_band.gd`, `hud.gd`) + maketlerle karşılaştırma. **Ekran görüntüsü kanıtı yok:** Godot bu makinede çalışmıyor ve CI (`ci.yml`) `tools/capture/shots_v21*.gd`'yi koşmuyor (artifact'lar yalnız APK, gut-junit, import-evidence). Bu yüzden 1×/2× yazı ve TalkBack **metinleri** koddan doğrulandı; piksel konumu, kırpma, çakışma ve renk **görülmedi** (kanıt sütunu kod/maket gösterir). Kritik yok, yüksek yok; 5 orta, 9 düşük, 3 bilgi.

## Bulgular
| # | Önem | Ekran | Bulgu | Kanıt | Beklenen (DESIGN.md) |
|---|---|---|---|---|---|
| 1 | Orta | Skorlar | Ekran eski mor dilde: zemin `MOR_900` (#171020) + bordo parıltı, satır paneli tema `PanelRaised` (yedek `MOR_800`), vurgulu satır `MOR_800`. Maket sıcak taş/kahve; ana sayfa/KOŞU `tas_*` iken skor sekmeleri farklı oyundan görünür (v2.0.3-son #2'nin aynı deseni) | `highscore_screen.gd:245,444,513`; `mock/04-skorlar.png` | v2.0.3 §1 C1: mor yalnız XP; `tas_900` zemin, `levha`/taş satır. §0 "aynı akıştaki tüm ekranlar" |
| 2 | Orta | Skorlar, Sonuç, Duraklatma, HUD bandı | **2× yazı desteği yok:** bu dosyalarda `font_scale`/`set_font_scale` hiç geçmiyor (ana sayfa 6, KOŞU 3). §7 "sekme etiketleri 40, satır 156'ya çıkar, liste kayar", §5 "çipler iki satıra sarar" uygulanmamış; 2× kullanıcıda sekme/çip/satır yazısı 1× kalır. U4b raporu da "sonuç ekranı yazı ölçeği kullanmıyor" diyor | `grep -c font_scale`: highscore 0, result 0, pause 0, hud 0 | §5 2× bloğu, §7 2× bloğu, §9 "2×'te sarma/dikey sıra, kesilme yok" |
| 3 | Orta | Ana sayfa (2×) | Şeritte "DEĞİŞTİR ›" düşüyor, yalnız "›" kalıyor; seçilebilirlik ipucu 2×'te kayboluyor. Maket 01b "DEĞİŞTİR ›" gösteriyor ve sığıyor | `run_strip.gd:216`; `mock/01b-ana-sayfa-yazi-2x.png`; `mock/build.py:77` | §2 "2× ... hiçbir şey kesilmez"; `DEĞİŞTİR ›` her iki ölçekte |
| 4 | Orta | Sonsuz bandı | TalkBack canlı bölge yok: §9 "canlı bölge, nazik" diyor; band yalnız `accessibility_name` taşıyor (mouse IGNORE, odak almaz) ve `accessibility_live` hiçbir yerde kullanılmıyor → ekran okuyucu cümleyi **kendiliğinden okumaz**, 3,2 sn'lik bant kaçırılır | `milestone_band.gd:54`; `grep accessibility_live scripts` boş | §9 kilometre taşı bandı: canlı bölge (nazik) |
| 5 | Orta | Sonuç | +44 px kayma kombo satırlarını azaltıyor: 5 kombo artık 3 satır + "+2"; alt güvenli alan dar + başarım çipi varsa 0 satıra (yalnız "+N") iniyor; `test_result_layout` eşiği 300→150 gevşetildi. Tasarım "en kötü durumda düğmeler y≈2125'e iner, sığar" diyordu; kod o payı kullanmak yerine içeriği kırpıyor | T34 raporu "Tasarım sapmaları"; `result_screen.gd` kombo kırpma (`_shown_combos`) | §5 "Kayma": 4 kombo + Lord bonusu + Kolay notu çakışmasız; v2.0.3 4 satır + "+N" |
| 6 | Düşük | Skorlar | Sekme glifi seçili durumda da `bronz_500` (seçilmemiş rengi); `set_selected` glifi güncellemiyor. Bordo yüzeyde `bronz_500` kontrastı hesaplanmadı | `highscore_screen.gd:293,301,87-97` | §4 seçili `bronz_300`; §9 kontrast tablosunda bordo üstü `bronz_500` yok |
| 7 | Düşük | KOŞU | Seçilmemiş mod glifi hep `bronz_300` (U4a raporu da anıyor). Seçim bordo + mühür ile zaten verildiği için işlev kaybı yok | `run_screen.gd:244` | §4 seçilmemiş `bronz_500`, seçili `bronz_300` |
| 8 | Düşük | KOŞU | Mühür (56 px, y 14–70) ile 1× süre yazısı (38 px, dikey ortalı, satır 184 → y≈67–117) ~3 px çakışabilir; görülmedi, kod çıkarımı | `run_screen.gd:226`, `:256` | §3 mühür 56 px sağ üst, süre sağda; çakışma yok |
| 9 | Düşük | Sonuç | `record_note` tek satır, 936×40, sarma yok; "Hızlı · Kolay listesinde 1. sıra · Önceki en iyi: 1.234.567" ≈ 56 karakter × ~16 px (Inter 30) ≈ 900 px, kenarda | `result_screen.gd:218-220,555-566` | §5 sıra satırı Inter 30/600; taşma yok |
| 10 | Düşük | Sonuç | Altyazı (y300) ile çip satırı (y352) arası dar; DESIGN §11/7 `Y_SUB` 292 önerdi, uygulanmadı | `result_screen.gd:21-23` | §11 madde 7 |
| 11 | Düşük | Skorlar | "YENİ" etiketi 22 px; ekran kuralı min metin 26 px (v2.0.3 satır bileşeninden miras) | `highscore_screen.gd:389` | §9 "Metin: min 26 px" |
| 12 | Düşük | Sonsuz bandı | Lord sonraki dönüş ipucu boşsa (`repeat_sec ≤ 0`) alt ~64 px boş kalıyor, içerik dikey ortalanmıyor; bant opak 204 px, y300–504 oyun alanını 3,2 sn örter (tasarım kabulü) | `milestone_band.gd:38-53,89` | §6 bant 936×204, içerik dengeli |
| 13 | Düşük | KOŞU / ana sayfa | Açılışta `grab_focus` dokunmatikte amber 6 px odak çerçevesini kalıcı gösterebilir; cihazda görülmedi (varsayım) | `run_screen.gd:456-459`, `main_menu.gd` `open()` | §3 odak = klavye/D-pad; dokunmatikte çerçeve beklenmez |
| 14 | Düşük | Ana sayfa | Sürüm satırı `Sürüm 2.0.3` (`project.godot` `config/version="2.0.3"`); tasarım `Sürüm 2.1.0` | `project.godot:7`, `main_menu.gd:579` | §2 `Sürüm 2.1.0` (release öncesi yükseltilmeli) |
| 15 | Bilgi | TalkBack | Sonuç sıra metni "…listesinde 3. sıra" (rakam); tasarım "üçüncü sıra". Okunur, işlev kaybı yok | `result_screen.gd:566-567` | §9 sonuç çipleri/sıra |
| 16 | Bilgi | DESIGN iç tutarsızlık | (a) §7 sekme 3×306+2×12 = 942 > 936; kod 304 (doğru). (b) §5 örnek "Zor · Normal listesinde", kural/maket "Mod · Zorluk"; kod "Mod · Zorluk" (doğru). Belgeler düzeltilmeli, kod değil | `highscore_screen.gd:481`, `result_screen.gd` `rank_line` | DESIGN §5/§7 metinleri |
| 17 | Bilgi | Duraklatma | `GAP_H` 170→95 ve güvenli alan sıkıştırma payı 130→55 px; çentikli/kısa ekranda çip ile eylem düğmeleri yakınlaşır; CI testleri geçti, görsel doğrulanmadı | `pause_screen.gd:18,151-154`; T32 raporu | §5 pause çipleri |

## Geçenler (kod okumasıyla; görsel doğrulama yok)
- TalkBack metinleri DESIGN §9 ile uyumlu: şerit, mod satırı (seçili/değil), zorluk kartı, ayrıntı levhası (yüzde okunuşu), kural uyarısı, sekme ("üç sekmeden ikincisi"), çipler, boş sekme düğmesi, band metni (`run_strip.gd:318-365`, `highscore_screen.gd:328-342,454`, `milestone_band.gd:16`).
- Koşu şeridi 132/168, OYNA'nın 27 px üstü; ayrıntı/kural levhaları seçime göre yerinde güncelleniyor; sayılar `V21Runs.profiles()`'tan; `hareket_azalt` geçişleri anlık; kilitli durum kullanılmıyor.
- Seçim ikili kanal (bordo + ✓ mührü + "seçili" a11y), zorluk adı + kalkan sayısı; Kolay/Sonsuz uyarıları `!` rozetli; dokunma hedefleri ≥132.
- Skor satırları 10 × ~147 (pitch ≈159), y590'dan, GERİ y2196: tasarım aritmetiğiyle uyumlu; boş sekme + "BU AYARLA OYNA"; band `mouse_filter = IGNORE`, 220/400 ms, `hareket_azalt` anlık.

## Önerilen düzeltmeler
1. **#1** `highscore_screen.gd`: zemin `TAS_900`, sıcak parıltı, satır `levha`/taş, vurgulu satır taş + amber; kabul: maket `04-skorlar.png` ile aynı yüzey dili, `MOR_*` kalmaz.
2. **#2** `highscore_screen.gd`, `result_screen.gd`, `pause_screen.gd`: `set_font_scale` (`> 1,3`): sekme etiketi 40, çipler iki satıra sarar, satır 156 + kaydırma; kabul: 2× yakalamada kesilme/çakışma yok (aynı `shots_v21*.gd` senaryosuyla önce/sonra).
3. **#3** `run_strip.gd`: 2×'te "DEĞİŞTİR ›" kalsın; kabul: 2× yakalama `01b` ile uyumlu.
4. **#4** `milestone_band.gd`: band görününce nazik canlı bölge duyurusu; kabul: TalkBack bandı odaksız okur (cihaz).
5. **#5** `result_screen.gd`: kombo kırpmadan önce düğme bloğunun aşağı payını kullan (tasarım y≈2125); kabul: 5 kombo 4 satır + "+1", test eşiği 300'e döner; ya da tasarım bilerek güncellenir (karar gerekir).
6. **#6–#13** (düşük): glif renk durumları, mühür konumu, `record_note` sarma, `Y_SUB` 292, YENİ ≥26 px, band dikey denge, dokunmatikte odak çerçevesi.
7. **#14** `project.godot` sürümü 2.1.0 (release); **#16** DESIGN.md §5/§7 metinleri düzeltilir (designer işi).
8. **Altyapı (developer):** CI'a `shots_v21.gd`/`shots_v21_b.gd` koşan ve PNG'leri artifact yükleyen bir iş; görsel denetim ancak böyle doğrulanır. O zamana kadar #1–#13 kod/maket kanıtlıdır.

## Açık noktalar
- Hiçbir ekranın gerçek görüntüsü incelenmedi; 2× yerleşimler, mühür/süre çakışması, kırpma, bant görünümü ve renk doğruluğu doğrulanmadı. Cihaz ve gerçek TalkBack okuması denenmedi.
- `ui-ux-pro-max`, `impeccable`, `design-taste-frontend` yüklendi; `impeccable` yalnız `audit/critique` yönüyle (araç betikleri/web dedektörü çalıştırılmadı, DOM yok), `design-taste-frontend` rol gereği uygulama ekranlarında kullanılmadı, `search.py` çalıştırılmadı. Playwright kullanılmadı; maketler PNG olarak okundu.
