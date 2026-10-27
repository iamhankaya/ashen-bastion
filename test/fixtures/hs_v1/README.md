# hs_v1 — v2.0.x biçimli highscores.json örnekleri (v2.1 kayıt göçü kabul testleri)

Kaynak: `Highscores.VERSION = 1` biçimi (`scripts/store/highscores.gd`, `{"v":1,"entries":[{score,time,won,level,unix}]}`);
2026-10-27'de el ile/betikle üretildi. Gerçek bir cihaz dosyası DEĞİLDİR (cihazdan örnek alınmadı; açık nokta).

- `v1_full.json`: 10 geçerli giriş (skor azalan; ilk ikisi `won`).
- `v1_mixed.json`: geçerli 3 giriş (biri 12 haneli skor -> 99999999 tavanına kırpılır; iki girişte skor eşit, `unix` küçük
  olan önde) ve atılması gereken 4 bozuk giriş (negatif skor, negatif süre, `won` alanı yok, dizge).
- `v1_empty.json`: giriş yok.

Testler bu dosyaları `user://` altında geçici yola kopyalar; fixture'a yazılmaz.
