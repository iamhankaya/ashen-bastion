---
name: ab-kure-ekle
description: Ashen Bastion'a yeni XP küre tipi (GemTiers kademesi) eklerken veya küre boyutunu/dokusunu değiştirirken (gem_tiers.gd COUNT/ORB_PX/tier_of, process_gem_orbs.py, atlas, gem_orb.gdshader, test_v203_b_*, test_acc_v203_orbs) kullan.
---

# Küre tipi ekle / değiştir (v2.0.3 `GemTiers`)

Küre tipi XP değerinden türer (`GemTiers.tier_of`); görünüm sınıfıdır, **sim ve altın hash değişmez** (hash yalnız `count` ve `total_value` kullanır). Çizim: tek `GemRenderer` MultiMesh, tek yatay atlas (`TILE_PX = 128` × tip sayısı).

## Boyut tuzağı (F-075)
`ORB_PX` kutunun kenarıdır, görünen küre değil. Görünen genişlik = `ORB_PX × (opak genişlik / 128)`. İşlenmiş normal küre dokusunun opak kutusu 52×100 / 128 olduğundan 34 px kutuda ~14 px görünür. Boyut değiştirirken önce `PIL` ile `getbbox()` (alfa ≥ 128) ölç; yalnız `ORB_PX`e bakma. `process_gem_orbs.py` kaynağı kırpmadan 1024 → 128 küçültür; kaynaktaki boş pay oranı doğrudan görünür boyutu belirler.

## Adımlar
1. **Kaynak görsel:** `art/source/gem-orbs/<ad>.png` (kullanıcıya gösterilip onaylanır; `ab-gorsel-ikon-uret`). `art/` export dışıdır.
2. **İşleme:** `tools/art/process_gem_orbs.py` içindeki `NAMES` listesine adı ekle; `python tools/art/process_gem_orbs.py` → `assets/gfx/fx/gems/<ad>.png` (128×128 RGBA, `.import` commit'li). `--check` güncellik denetler; `tools/art/tests/test_process_gem_orbs.py` ad listesini/sayıyı sabitler (`pg.NAMES == [...]` ve çift döngüsü `range(i + 1, 3)`: yeni tipte ikisini de güncelle). `CROP` kümesi opak kutuya kırpılacak adları, `PAD` kırpmadaki kenar payını (kare kenarının oranı) belirler; yeni tipin kaynağında boş pay büyükse adı `CROP`'a ekle, yoksa görünür boyut küçük kalır (Boyut tuzağı).
3. **`scripts/view/gem_tiers.gd`:** enum'a tip (sıra = atlas kutusu sırası), `COUNT`, eşik sabiti (`ELIT_MIN`/`BOSS_MIN` gibi), `TEXTURES` ve `ORB_PX` (üçü de `COUNT` uzunluğunda), `tier_of` sınıflaması. Sınıfı değiştirirsen düşman `xp` eşlemesini (`test_enemy_xp_values_land_in_the_agreed_tiers`) gözden geçir.
4. **Atlas:** `GemRenderer.atlas_texture()` `GemTiers.COUNT` kadar kutu birleştirir (otomatik); atlas genişliği `128 × COUNT`.
5. **Gölgelendirici:** `assets/shaders/gem_orb.gdshader` atlas UV'sini sabit `/ 3.0` ile böler ve süzülme genliğini tipe göre sabitler (`elit * 3.0 + boss * 4.0`, `step(0.5/1.5, tier)`). Yeni tipte böleni `COUNT`'a ve genlik/`step` mantığını yeni tipe güncelle; unutulursa yeni küre yanlış kutudan okunur.
6. **Testleri güncelle:**
   - `test/unit/test_v203_b_zz_contract.gd`: `COUNT`, `ORB_PX` değer eşitliği, `tier_of` sınırları, düşman `xp` eşlemesi.
   - `test/unit/test_v203_b_orbs.gd`: üç-tip varsayımları (`tiers.size() == 3`, atlas `TILE_PX * 3`, kutu döngüleri).
   - `test/acceptance/test_acc_v203_orbs.gd` **tester'ındır**: `ORB_PX` değer sabiti (`[44, 48, 80]`), `_distinct` çiftleri (normal–elit, elit–boss, normal–boss), boyut oranı `>= 1,8` ve boss koyultmama. Değişmesi gerekiyorsa `vlad task ask` ile "Test itirazı" aç; kendin değiştirme. Kural: her çift ΔL* ≥ 15 **veya** boyut oranı ≥ 1,8 + IoU ≤ 0,6; ölçüm kuralı sabit (ORB_PX'e indir, 80 px tuvale ortala, opak = alfa ≥ 0,5). Not: `ORB_PX` en büyüğü ölçüm tuvaline (`CANVAS`, şu an 80) sığmalı; boss büyürse `CANVAS` da güncellenir.
   - Dokümanlar: `docs/data-schema.md:209` (`GemTiers` satırı: eşikler, `tier_of` sınıfları) ve `docs/design/v2.0.3/DESIGN.md` §5 (tip sayısı, px değerleri, ölçüm sonuçları).
   - Kayıt dosyaları: yeni test dosyası eklersen `ab-test-ve-kapi` (`tools/v2_slices.txt`, `gate_min_tests.json`, `test_map.json` yeniden üretimi).
7. **Kuru deneme (zorunlu):** sahte tip ekle (ör. `DRYRUN`, ≥ 200 xp, 80 px, `ara_boss.png` kopyası), `python tools/art/process_gem_orbs.py --check` + ilgili GUT dosyalarını koş, kırılan listeyi çıkar, sonra **tümünü geri al** (repoya girmez). T20261026-66'daki denemede kırılanlar: `COUNT`/`ORB_PX` sabitleri, `tier_of` (3 test), atlas boyutu (512×128 ≠ 384×128), sayım testleri.
8. **Ekran görüntüsü:** `tools/capture/shots_orbs.gd` (xvfb, 1080×2400; `orbs_three`, `orbs_crowd` 300 küre, `orbs_still`) ile önce/sonra al; **kullanıcıya göster, onaydan sonra kesinleştir.** Çıktıyı commit'leme. Küre sayısı arttıkça `refresh` µs/kare çıktısına bak (perf).
9. `bash tools/gate.sh`.

## Kontrol listesi
- [ ] Görünen (opak) boyut ölçüldü; ana küre 1080 genişlikte ≥ ~20 px görünür.
- [ ] `TEXTURES`, `ORB_PX`, atlas kutusu ve shader böleni aynı `COUNT`'ta.
- [ ] Üç/dört tip ayırt edilebilir (`test_acc_v203_orbs`); boss koyultularak ayırt edilmedi.
- [ ] Sim hash değişmedi (`test_orb3_*`, altın hash `test_g1_*`).
- [ ] `hareket_azalt` AÇIKken süzülme yok (`test_orb4_*`).
- [ ] Kuru deneme geri alındı; geçici çıktılar `.gitignore`'da.
