# v2.0.2 Zyfen — Davranış sözleşmesi

Kaynak: `docs/plan/v2.0.2-zyfen-plan.md` Arayüzler §7. Aşağıdaki bölüm plandan **aynen** alınmıştır; sayılar ve
cümleler değiştirilmez. Bu belge değişirse plan da değişmiş sayılır (sahibi VLAD). U fazları bu satırlara karşı kod
yazar, K fazı bu satırlara karşı kabul testi yazar.

**Kullanım kuralları**

- Test itirazı yalnız bu satırlara karşı açılır (gerekçe: satır, gözlem, ölçülen değer).
- "Tol." sütunu testin kabul edeceği en geniş sapmadır; daha gevşek tolerans testle birlikte itiraz konusudur.
- "adım" = sim adımı (60 Hz, 1/60 sn). "sv5" = beceri seviyesi 5; "sv1" = seviye 1.
- Sayısal değerlerin kaynağı `data/skills/*.json`'dur (plan §6); bu tablo davranışı tarif eder, sayıyı yinelemez
  (yalnız kesin sabitler: yarıçap, hız, açı).

## Sözleşme tablosu

Test itirazı yalnız bu satırlara karşı açılır. "Tol." = tolerans.

| Beceri | Giriş durumu | Beklenen gözlem | Tol. |
|---|---|---|---|
| Rüzgar Kesiği | Zyfen, tek eksen üzerinde hizalı 20 düşman, sv1 | Tek kesik `PIERCE_ALL`, `FLAG_WIND`, yarıçap 14; her düşmana en çok 1 `DAMAGE` | Hasar ±%1 |
| Hava Bıçakları | menzil 380 içinde ≥5 düşman | `pellets` kadar kesik, toplam açı 0,70 rad, simetrik; her biri `pierce` değerinde biter | Açı ±0,01 rad |
| Girdap | 100 px'e düşman | Her `interval` sn'de tam 1 darbe (hasar + dışa itme `push` px); yarıçap = taban × `area_mult` **her adım**; elit hasar alır ama itilmez | Tik ±1 adım |
| Hortum | sv1, düşman kümesi | `count` bölge, `life × wind_time_mult` sn yaşar, tik 0,4 sn; çekme merkeze, ömür sonunda savurma yok (kullanıcı kararı 2026-10-25), düşman konumunda kalır; 2× bitiş tik hasarı; hedef değişimi `retarget_every`'de 1 `randf()`; **oyuncudan uzakta doğar ve gelmez** (kullanıcı kararı 2026-10-25): doğuş merkezi oyuncudan ≥ `min_spawn_dist` (300 px; uzak düşman kümesi, yoksa bu uzaklıkta yedek nokta), hedef seçiminde oyuncuya `keep_out` (250 px) içindeki düşman elenir, hareket bölgeyi oyuncuya `keep_out`'tan fazla yaklaştırmaz, `max_dist` ile oyuncuya dönme yok | Konum ±2 px / adım |
| Delen Rüzgar | menzil 850 içinde farklı HP'li düşmanlar | En yüksek HP'liyi seçer; kesik `PIERCE_ALL`, radius 10, hız 1400; zırh uygulanır | Hasar ±%1 |
| Bölünen Kesik | Her `every_n`'inci kesik | İlk isabette ebeveyn biter (`pierce` 0) ve `count` çocuk doğar (3 için -0,5/0/+0,5 rad); çocuk hasarı ebeveyn × 0,6, `pierce` 3, ebeveynin vurduğu düşmana vurmaz; **çocuk bölünmez**; aynı karede 2 düşmana çarpan ebeveyn yalnız 1 kez bölünür; menzil sonunda bölünme yok; çocuk `rad/hız/ömür` ebeveynden miras | Açı ±0,01 rad |
| Hava Cebi | Düşman ölür | Olasılık `chance`, kill başına tam 1 `randf()`; cep ömrü `life`; **cep tiki ile ölen düşman yeni cep doğurmaz**; CAP rezervi dolu ise doğmaz (sayaç artar) | Olasılık testi 1000 kill, ±%5 |
| Nefes Dalgası | Doldurma başlar | O adımda `radius` içi tek dalga (hasar + itme); `wind_wave` sinyali; Sonsuz Tambur'da tetiklenmez; elit itilmez | Adım ±0 |
| Fırtına Gözü | sv5 | Girdap yarıçapı ×1,60, Hortum/Hava Cebi/Tufan alan ×1,60, ömür ×1,50 | ±%0,5 |
| Ay Orağı | Her 2. kesik | Dev hilal: radius 40, hız 1300, menzil 1100, hasar ×3,5, `PIERCE_ALL`, bölünmez; 60 düşmanlı çizgide çift hasar ölçülür | Çift hasar = 0 ya da belgelenmiş sınır |
| Kasırga Patlaması | Doldurma başı | Doldurma başında ve `min(0,5; doldurma×0,8)` sn sonra ekran boyu dalga (`big`); doldurma kesilirse (ölüm, seviye atlama ekranı, duraklatma) ikinci dalga zamanlayıcısı ilerlemez/iptal olur | Adım ±1 |
| Göğün Mızrağı | cooldown biter | Art arda 4 mızrak, 0,12 sn arayla, her biri o anki en yüksek HP'li hedefe | Aralık ±1 adım |
| Tufan | cooldown biter | 3 `KIND_GIANT` hortum (`count` 3), yarıçap 190, ömür 8 × `wind_time_mult`; CAP dolu iken **kaybolmaz** (rezerv); Hortum ile aynı doğuş/`keep_out` kuralları (kullanıcı kararı 2026-10-25) | Konum ±2 px |
