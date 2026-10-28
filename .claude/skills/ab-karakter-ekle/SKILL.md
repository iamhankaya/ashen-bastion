---
name: ab-karakter-ekle
description: Ashen Bastion'a yeni oynanabilir karakter eklerken (yeni karakter, karakter verisi, portre, rig, başlangıç becerisi, karakter sesi, karakter kilidi) kullan; tek parça gövde yöntemiyle veri, görsel, beceri havuzu, ses ve denge kanıtı adımlarını sırayla uygular.
---

# Yeni karakter ekle (tek parça gövde)

Yeni karakter **tek parça gövde** ile yapılır: her animasyon karesi tüm karakteri içerir, kol/namlu/omuz düzeneği yoktur
(`rig.armless: true`). Örnek ve ölçüm kaynağı: **Zyfen** (`data/characters/zyfen.json`). Başlamadan: kb kartının `## Çalışma notları`
bölümünü oku; kapı komutu `bash tools/gate.sh`; Türkçe `to_upper/to_lower` yasak (`tools/gate.sh` lint grep'i).

## Gunslinger istisnası (tek not)
Gunslinger parçalı rig'dir (kolsuz gövde + kol; `rig.armless` yok, `data/characters/gunslinger.json`). Yeni karakter için parçalı rig
**önerilmez** ve Gunslinger'ın kodu/görselleri bu iş kapsamında değiştirilmez. Tek parçaya geçişi ayrı karar/pipeline'dır.

## Adımlar
1. **Tasarım belgesi:** `docs/design/<sürüm>/<tarih>-<ad>-design.md` (örnek `docs/design/v2.0.2/2026-10-24-zyfen-design.md`). Sayılar, havuz, kilit kullanıcı onayı ister. Esin kaynağı olan karakter/eser adı hiçbir yerde geçmez (public repo).
2. **Veri iskeleti:** `data/characters/<id>.json` (alanlar aşağıda; şema `docs/data-schema.md`). Dosya adı = `id`. **Sıra:** `validate_data` JSON'u görsel dosyaları (`portrait`, `rig.body`, `walk.strip`; kolsuz rig için `placeholder:` yok, gerçek şerit gerekir) ve başlangıç becerisinin havuzu (`requires_ref`) yokken `asset_missing`/`requires_ref` ile reddeder; şerit PNG'si de `godot --headless --import` yapılmadan yüklenemez. Bu yüzden JSON'u adım 3–4'ten (görseller, beceri, import) sonra bağla; ondan önce alanları taslak olarak sakla.
3. **Görseller:** portre → `ab-gorsel-ikon-uret`; yürüme/cast/gather kareleri ve şerit → `ab-animasyon-seridi`.
4. **Beceri havuzu:** `pool: "<id>"` özel aktif/evrimler → `ab-beceri-ekle`. `starting_skill` `kind: active` olmalı; havuzu karakterin kimliği ya da `common` (`requires_ref`). Depoda `common` havuzlu aktif beceri yok: yeni karakter kendi havuzlu bir başlangıç becerisi getirir.
5. **Ses:** karakter `sfx{}` sözlüğü ve beceri `cast_sfx` → `ab-ses-ekle`. Sözlük varsa anahtarı olmayan olay sessiz kalır.
6. **Kilit (isteğe bağlı):** `unlock: {"achievement": "<id>"}` → başarım `ab-basarim-ekle`.
7. **Mevcut testleri güncelle:** karakter listesi/sayısını sabitleyen testler yeni karakterde kırmızı olur (kuru denemede 4 test): `test/unit/test_character_roster.gd` (`test_ids_follow_order_field`), `test/unit/test_characters_screen.gd` (`test_f030_gunslinger_first_by_order_field`), `test/acceptance/test_acc_v2_chars.gd` (`test_k10_single_character_set_works`, zyfen silince 1 karakter kalacağını varsayar), `test/unit/test_v202_pool_real.gd` (`test_empty_character_id_keeps_old_unfiltered_behavior`, filtresiz aktif beceri sayısı). Beklenen değerleri yeni karaktere göre güncelle (kusurlu davranışı değil sayıyı).
8. **Denge:** `ab-denge-olcumu` ile Gunslinger ±%5 kanıtı (`kills5`, `hp_early`) ve yeni karakterin DPS bandı; `tools/balance/mid_run.gd` `PRIORITY_BY_CHAR`'a karakter satırı (yoksa Gunslinger önceliği kullanılır) ve `mid_all.sh` varsayılan `CHARS` listesi.
9. **Altın hash:** yeni karakter için yeni aşama kaydı (`test/fixtures/golden_hashes.json`, `tools/golden/golden_run.gd`). Gunslinger kayıtları değişmez; eşitlik zinciri testleri (ör. "u3 = u1b") korunur.
10. **Ekran öz-kontrolü:** xvfb ile `tools/capture/shots_zyfen.gd` örneği (seçim ekranı, duruş, yürüme, cast, gather, aynalama) — kendi `shots_<id>.gd`'ni onun kalıbıyla yaz.
11. **Cihaz listesi:** ortak `docs/dev/user-verify.md`'ye yazma; kendi bölüm dosyanı `docs/dev/user-verify/` altına yaz.
12. `bash tools/gate.sh` yeşil; `docs/dev/new-character.md` ile çelişki yok.

## Tek parça gövde yöntemi (Zyfen'den ölçülmüş başlangıç değerleri)
- **Şerit, AnimatedSprite2D değil:** gövde tek `MeshInstance2D` (`scripts/view/player_view.gd`), tek yatay şerit PNG, hücre = UV bölgesi. Sway shader ve rim konturu hücre dolgusuna (`PAD=12`) bağlı; doğrulayıcı hücre/doku boyutunu denetler (`scripts/sim/data_v202_rig.gd`).
- **Kare sayısı:** yürüme 8, duruş 1, cast 6 (`fire_frame` 3, `fps` 24), gather 4, isteğe bağlı `walk_cast`. Hücre sırası: yürüme, duruş, cast, gather, walk_cast (`scripts/sim/rig_frames.gd`). Zyfen 19 hücre.
- **Boyut:** hücre yüksekliği 320 px; `display_height` 200; hücre genişliği = en geniş alfa kutusu + 2·PAD (Zyfen 300; şerit 5700×320); toplam genişlik ≤ 8192; klip boy sapması ≤ %6.
- **Çapa:** pivot ayak; yürüme/duruş üst gövde ağırlık merkezi, cast/gather ayak ağırlık merkezi; `--align feet` ≤ ±24 px; `walk.stride` videoya kalibre (Zyfen 130).
- **Atış/efekt çıkış noktası:** `rig.cast_point` `[fx, fy]` (Zyfen `[0.375, -0.305]`), sola bakışta x aynalanır; mermi, beceri ve avuç efekti aynı noktadan çıkar (`PlayerRig.shot_origin`, `WindUtil.skill_origin`). Ölçüm: cast karesinde avuç pikseli → `--palm-px`; manifest `palm` ile `cast_point` farkı ≤ 0,03.
- **Veri alanları:** sayılar `id, name, max_hp, move_speed, mag_cap, reload_time, pickup_radius, collision_radius, range, starting_skill, order`; görünüm `display_upper, blurb (≤120), portrait, placeholder, sfx{}, unlock{}`; `rig`: `body, armless: true, display_height, native_facing, cast_point, action_while_moving, sway{…} (zorunlu), walk{frames, stride, strip, cell, shoulder_dev: []}, cast{frames, fire_frame, fps}, gather{frames}`. `arm`, `arm_pivot`, `muzzle`, `shoulders`, `arm_scale` **yazılmaz**.
- **Portre:** `assets/gfx/char/<id>_portrait.png`, 1024×1536, tam sahne, güvenli alan kuralı `ab-gorsel-ikon-uret`'te.
- **Bilinen sınırlar:** tek `cast_point` (iki bağımsız nişanlı silah için yetmez); kare tutarlılığı (renk/kıyafet sıçraması) elle denetlenir; iki yönlü `walk_cast` yok.

## Dokunulan dosyalar
`data/characters/<id>.json`; `assets/gfx/char/<id>_{body,strip,portrait}.png` + `.import`; `art/source/<id>/` (kare, `strip_manifest.json`, `quality.json`); `docs/data-schema.md`; `docs/dev/new-character.md`; karakter listesi sabitleyen mevcut testler (adım 7). Dokunulmaz: `scripts/ctrl/character_roster.gd` (`DEFAULT_ID = gunslinger`), Gunslinger dosyaları.

## Doğrulama
- `bash tools/gate.sh` (adım 4 `validate_data` karakter hatalarını dosya/alan olarak söyler; `test/fixtures/rig_bad_*` örnek bozuk rig'ler).
- Kolsuz karakter her karakter için otomatik taranır: `test/acceptance/test_acc_v202_rig_manifest.gd`, `test_acc_v202_rig_walk_gate.gd` (yeni testi elle yazma; `art/source/<id>/` çıktıları yeterli). Dilim `R` kapalıysa bu testler pending döner; yerelde `V202_SLICES_FORCE=R` ile zorla.
- Yürüme kalite kapısı `art/source/<id>/quality.json` `pass: true`; kırmızıysa waiver yolu `docs/design/walk-waiver-<id>.md` (tarih + kullanıcı onayı + ölçüm + gerekçe).

## Kontrol listesi (kart çalışma notlarından)
- [ ] `godot --headless --import` yapıldı, `validate_data` 0 hata; karakter listesi sabitleyen 4 mevcut test güncellendi.
- [ ] Yürüme/aksiyon kareleri **video → ffmpeg → yeşil silme** hattından; görsel üreticiyle kare kare çizilen yürüme kullanılmaz (yan görünümde bacak sırası çizilemez; tek ızgarada tutarlı döngü çıkmaz). `--preview` ile bağlamadan önce ölç.
- [ ] Bilinen açığı sabitleyen test baştan `karakterizasyon (F-xxx)` adıyla; kabul testi kusurlu davranışı beklenen değer yapmaz, bulgu kimliğine bağlı `pending` yazılır.
- [ ] Paralel fazlar ortak kayıt dosyalarına (dilim dosyaları, `removed_tests.txt`/`moved_tests.txt`) yazarsa sözleşme fazı önceden hazırlar; rapordan önce entegrasyon dalını yeniden al.
- [ ] Cihaz kontrol listesi kendi bölüm dosyana (`docs/dev/user-verify/`), ortak dosyaya değil.
- [ ] Araç/ölçüm çıktı klasörü aynı commit'te `.gitignore`'a (ör. `tools/art/_preview/`).
- [ ] Sır, imza materyali, esin kaynağı adı yok; gate'in yasaklı ad denetimi (`tools/ci/check_forbidden_names.sh`) yeşil ya da "atlandı".

## Örnek
Zyfen: `data/characters/zyfen.json`, `assets/gfx/char/zyfen_strip.png` (5700×320, 19 hücre), `art/source/zyfen/strip_manifest.json`, `scripts/view/cast_anim.gd` (cast/gather kare seçimi).
