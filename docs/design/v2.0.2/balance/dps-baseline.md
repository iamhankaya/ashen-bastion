# v2.0.2 başlangıç DPS tablosu (S2)

Ölçüm: `tools/balance/dps_table.gd` (`test/helpers/dps_probe.gd`); 12 hareketsiz kukla (`curumus_piyade`, can 1e7,
zırhsız), 20 sn, tohum 1, oyuncu ölümsüz. Birim: kukla başına değil, **toplam hasar / sn** (12 kukla toplamı).
Düzenler: halka (260 px yarıçap), çizgi (tek eksende 160 px'ten 40 px aralıkla; delme), küme (sıkı 4×3 küme).

Yeniden üretim:

```
godot --headless -s res://tools/balance/dps_table.gd -- gunslinger,zyfen 20 docs/design/v2.0.2/balance/dps-baseline.table.md
```

**Okuma notları**

- Bu tablo S2 anındaki kodla ölçüldü: Zyfen'in 12 davranışı S1 no-op gövdeleridir. Zyfen "ham temel" satırı Rüzgar Kesiği
  yerine **varsayılan mermi** DPS'idir; Zyfen evrim satırları (ay_oragi, gogun_mizragi, kasirga_patlamasi, tufan) ham temelden
  farksızdır (davranış yok). Bu satırlar U2/U3'ten sonra D fazında yeniden ölçülür; şimdiki değerleri denge verisi sayma.
- Havuz süzgeci U1'e kadar Gunslinger'a özel becerileri etiketlemediği için Zyfen satırlarında ortak evrimler
  (`gurleyen_yelpaze`, `kiyamet_mermisi`, `mermi_firtinasi`, `zincirleme_patlama`) görünür; U1'den sonra bu satırlar düşer.
- Gunslinger sütunları v2.0.1 ile aynıdır (S1 altın hash'i eşit); U1/U2/U3 sonrası değişiklik beklenmez.
- Bu tablo bot dengesi değil, **ham hasar kapasitesi** ölçer; hedef seçimi ve hareket sabittir.

## Tablo (toplam hasar / sn, 12 kukla)

| karakter | satır | halka | çizgi | küme |
|---|---|---|---|---|
| gunslinger | ham temel (başlangıç becerisi sv1) | 51.0 | 51.0 | 51.0 |
| gunslinger | evrim: gurleyen_yelpaze | 153.4 | 164.4 | 219.4 |
| gunslinger | evrim: kiyamet_mermisi | 2060.8 | 2860.8 | 4860.8 |
| gunslinger | evrim: mermi_firtinasi | 307.5 | 83.5 | 97.5 |
| gunslinger | evrim: zincirleme_patlama | 1393.5 | 3283.5 | 6879.8 |
| zyfen | ham temel (başlangıç becerisi sv1) | 51.8 | 52.5 | 51.8 |
| zyfen | evrim: ay_oragi | 55.2 | 56.0 | 55.2 |
| zyfen | evrim: gogun_mizragi | 54.0 | 54.0 | 54.0 |
| zyfen | evrim: gurleyen_yelpaze | 154.2 | 166.0 | 220.2 |
| zyfen | evrim: kasirga_patlamasi | 54.0 | 54.0 | 54.0 |
| zyfen | evrim: kiyamet_mermisi | 1660.0 | 2300.0 | 3900.0 |
| zyfen | evrim: mermi_firtinasi | 306.0 | 85.0 | 92.0 |
| zyfen | evrim: tufan | 51.8 | 52.5 | 51.8 |
| zyfen | evrim: zincirleme_patlama | 1310.3 | 3354.0 | 6980.9 |
