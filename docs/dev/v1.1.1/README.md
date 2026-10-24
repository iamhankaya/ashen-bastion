# v1.1.1 oyuncu animasyonu — önce/sonra kare şeritleri

Kaynak: kullanıcı ekran kaydı 2026-10-24. 24 fps görünüm saati, 720×720, her 2. kare (12 kare/şerit). Üretim:

```
xvfb-run -a -s "-screen 0 720x720x24" godot --path . --rendering-driver opengl3 --resolution 720x720 \
  -s res://tools/capture/shots_anim.gd -- <dizin> <walk|walk8|slow|shoot|reload> [kademe]
python3 tools/capture/anim_montage.py <dizin> <senaryo> docs/dev/v1.1.1/<senaryo>_after.png 2
```

`*_before.png` = v1.1 (ebc24c8), `*_after.png` = v1.1.1. Şerit başlığı: kare no, durum, sol tabanca dünya açısı (derece, + = aşağı).

| Şerit | Senaryo |
|---|---|
| walk_* | sağa 8 kare, sola 8 (yön değiştirme), dur 8 (hedefsiz; sim, hareket varken `gun_aim = hareket açısı` yazar) |
| walk8_* | sağ-yukarı çapraz 8, dur 4, yürü-dur 4, sol-aşağı çapraz 8 |
| slow_* | 60 px/sn düşük hız yürüme, 24 kare (1 sn, 58 px): bob fazı yola bağlı mı |
| shoot_* | sağa bakarken eski hedef sol-aşağı (150°) kalmış; 14. karede sağda hedef belirir, atış |
| reload_* | hedef var, doldurma 1 sn; 12. karede hedef sol-yukarıya geçer (uç durum) |

Ölçüm (kare başına en büyük sol-kol açı değişimi, derece):

| Senaryo | v1.1 | v1.1.1 |
|---|---|---|
| doldurma (reload) | 47,4 (aim sabitken 3 karede 70° iniş) | 22,6 (uç durum: aim 165° atlıyor) |
| bekleme→atış (shoot) | 150,1 | 22,6 |
| yürüme (walk) | 180,0 | 15,0 |
| yürüme çapraz (walk8) | 135,0 | 15,0 |

Düşük hız (slow): 58 px yolda v1.1 ≈ 1,1 çevrim = 2,2 bob (zamana bağlı, hız 0,5'e kenetli → 26 px/bob); v1.1.1 0,44 çevrim = yaklaşık 0,9 bob (faz = yol / stride 136 → 68 px/bob), yani adım uzunluğuyla senkron.

Yürüme gövdesi (rig): eğim tepe 8,0° → 5,0°; bob 8,1 px → 4,1 px; temas squash sx 1,05 → 1,03, sy 0,93 → 0,96.

Sekme kademeleri tek yerde: `PlayerAnim.BOUNCE_TIERS` (scripts/view/player_anim.gd). Debug APK'da sağ alttaki
"sekme: …" etiketine dokunmak ESKİ v1.1 → YUMUŞAK (varsayılan) → SAKİN arasında döndürür.
