# v2.1 denge ölçümü (U1a)

> Bot dengesi ölçülüyor, oyun dengesi değil. Godot yalnız CI'da koşar; bu belge CI'ı nasıl tetikleyeceğini ve çıktıyı nasıl okuyacağını anlatır.

## Politikalar ve çıktı

`tools/balance/mid_run.gd -- <politika> <karakter> <ilk> <sayı> <çıktı.jsonl> [mod] [zorluk]`

- `strong_lord`: Lord yokken `strong` ile birebir aynı (kart seçimi dahil); Lord yaşarken Lord'a **250–400 px** bandında kalır
  (uzaksa yaklaş, yakınsa kaç, bandın içinde teğet). Bant `LORD_BAND_MIN/MAX` sabitleri; `bots.gd` değişmez.
- Mod verilmezse profilsiz legacy koşu (`mode=normal`, `diff=hard`). Yalnız mod verilirse zorluk `normal`.
- `MAX_STEPS` 144000 (2400 sn: Lord dövüşü dahil); Sonsuz 216000 (3600 sn). 10–20 dk can penceresi legacy ile aynı (1200 sn adımına kadar).
- Yeni alanlar: `mode, diff, won, milestone_won, end_reason (died|won|timeout), reached_lord, lord_spawn_t, lord_alive_secs,
  lord_end (killed|player_died|timeout|none), lord_hp_frac_end, lord_hit_frac, lords_killed, post_lord_secs, level_at_1200, level_at_end, kills`.
  `lord_hit_frac` = ilk Lord yaşarken Lord'un can kaybettiği adımların oranı (silah ritmi nedeniyle 1'e yaklaşmaz; karşılaştırma içindir).

## Raporlar

- `python3 tools/balance/mid_report.py <dizin> [--diff normal:easy normal:hard] [--level-ratio quick:normal normal:normal] [--sanity --cell normal:easy --policy strong_lord]`
  Kazanma %, Lord'a ulaşma %, medyan Lord süresi (yalnız `lord_end=killed`; sansürlü sayısı ayrı), vur oranı, hücre farkı için bootstrap %95 GA, Hızlı–Normal seviye oranı.
- `--sanity`: Kolay'da Lord'a ulaşanların medyan `lord_hp_frac_end ≤ 0,5` değilse çıkış kodu 1. Başarısızsa `strong_lord` en çok **2 tur** yeniden
  ayarlanır (`LORD_BAND_*`, yaklaşma kuralı); sonra kullanıcıya açık nokta olarak yazılır.
- `compare_baseline.py`: eşleştirme anahtarı `(mod, zorluk, karakter, politika, tohum)`; `--base-cell`/`--new-cell` (varsayılan `normal:hard`).
  Sabitler mod bazlı (`mid_rows.MODE_CONSTS`: Normal 1200/1199, Hızlı 600/599). `strong_lord` doğrudan `strong` baseline'ı ile
  karşılaştırılmaz; referans aynı politikayla legacy Zor'dan üretilir (`baseline-lord-A400.jsonl`).

## CI'da tetikleme (Lord'lu legacy baseline)

Actions → **balance** → *Run workflow* (varsayılan `first_seed=3001`, `policies=strong_lord`, `chars=gunslinger`): 4 alt iş × 100 tohum (A400 = 3001–3400),
sonra `merge` işi `baseline-jsonl` artifact'ını üretir (`baseline.jsonl`, `report.md`). `baseline.jsonl` bu dizine
`baseline-lord-A400.jsonl` adıyla commit'lenir. Aynısı yerelde: `POLICIES=strong_lord CHARS=gunslinger bash tools/balance/mid_all.sh .balance/lord 3001 400`
ardından `python3 tools/balance/merge_rows.py .balance/lord docs/design/v2.1/balance/baseline-lord-A400.jsonl`.
Ham çıktı klasörü `.balance/` `.gitignore`'dadır. Matris (mod × zorluk × politika) U1b'dedir.
