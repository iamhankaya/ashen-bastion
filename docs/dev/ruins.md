# Harabeler: katı/dekor kuralı, çarpışma, düşman etkileşimi

## Katı mı, dekor mu (görsel tutarlılık)
- Kural: **görsel yüksekliği ≥ 240 dünya px (oyuncu ≈200 px'ten uzun) olan yapı katıdır**; alçak moloz/kalıntı dekordur.
  Katı: `ruin_01–10`, `ruin_23` (meşale), `ruin_24` (çit) — gövdesi olanlar. Dekor: `ruin_11–22`.
- Görünüm: katı yapılar oyuncuyla y-sıralıdır (arkasından geçerken örter); dekor `RuinView.DECOR_Z` ile **zemin katmanıdır**
  (oyuncu/düşman/mermi hep üstünde, hiç engel olmaz). Böylece "üstünden geçilen = yerde" / "geçilemeyen = dikilen" okunur.
- `tools/art/ruin_collision.py` kuralı uygular, `solid`/`weight`/`collision` alanlarını yazar; pytest güncelliği denetler.

## Çarpışma şekli
- Katı harabe = `collision` dairelerinin birleşimi (sprite'ın en alt opak kenarı boyunca dizilen, `2r` derinliğinde şerit;
  ince direkli bayrak/meşalede yalnız direk tabanı). Tek küçük daire değil: duvar/kemer tabanının tamamı kapalıdır.
- `MapSim.resolve(pos, r)`: varlığın kapladığı **tüm** 256 px hücrelere bakar, 4 geçişle iç içe daireleri çözer; itme daire
  normali boyuncadır → yüzeye dik hareket silinir, teğet kalır (kenar boyunca kayma).
- `MapSim.slide(from, to, r)`: ≤12 px alt adım (en küçük daire 24 + oyuncu 22 ≫ 12): hızlı hareket tünelleyemez.
  Oyuncu hareketi `GameSim._phase_player_move` içinde `slide` kullanır.

## Komşu chunk'lar (F-ver-002)
Katı harabenin sarmalayan çemberi chunk kenarından `r + MIN_GAP/2` içeride durur; komşu chunk'taki iki katı harabe en az
`MIN_GAP` (70 px) ayrık kalır. Komşu içeriğine bakılmaz → üretim sırasından bağımsız, aynı tohum = aynı harita.
(Bedel: büyük harabeler chunk merkezine biraz yakın yerleşir; küçükler serbest.)

## Düşmanlar
- Mermiler harabeden geçer (plan).
- Sıradan yer düşmanı (`ai: ground`) iki adımda bir `resolve` ile itilir/kayar.
- **Elit, Lord, uçan (karga) ve hayalet muaf — bilinçli**: kovalayıcı baskı korunur, Lord/elit sıkışıp doğuş/kazanma
  akışını kilitleyemez. Düşman–harabe y-sıralaması yoktur (düşmanlar harabe katmanının altında çizilir; plan §kapsam).

## HUD: elit/Lord çubuğu
Pasif yuva satırının altında ortalı ayrı satır (700 px). Lord varsa Lord (kalın, amber), yoksa en yüksek maks. canlı elit
(bronz, ince); diğer canlı elitler ada `+N` olarak eklenir. Ad Cinzel, ≥28 px, Türkçe büyük harf (`UiKit.upper_tr`).
