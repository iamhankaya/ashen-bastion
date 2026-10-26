---
name: ab-animasyon-seridi
description: Karakter için yürüme/atış/toplama animasyon karelerini üretirken (video, ffmpeg kare çıkarma, yeşil silme, şerit, yürüme kalite kapısı, cast_point ölçümü) kullan.
---

# Animasyon karelerinden şerit (tek parça gövde)

Girdi: duruş görseli + üç kısa video. Çıktı: `assets/gfx/char/<id>_strip.png`, `<id>_body.png`, `art/source/<id>/strip_manifest.json`, `quality.json`. Üst akış: `ab-karakter-ekle`. Örnek: Zyfen (`art/source/zyfen/README.md`).

## Adımlar
1. **Duruş referansı:** şeffaf 1024×1536 PNG → `art/source/<id>/<id>_idle.png` (aracın varsayılan duruş adı `<src dizin adı>_idle.png`; başka ad için `--idle`). Görsel kullanıcı makinesinde Codex ile üretilir, repoya girmeden kullanıcıya gösterilir (bkz. `ab-gorsel-ikon-uret`).
2. **Üç kısa video (kullanıcıdan):** yürüme, cast, gather. Düz yeşil zemin, sabit kamera, yan görünüm, sağa bakar, 24 fps. Videolar repoya girmez (`art/source/zyfen/` altında yoktur).
3. **Kare çıkarma (öneri, repoda betik yok):** `ffmpeg -i walk.mp4 -vf "select='eq(n,155)+eq(n,159)+…'" -vsync 0 f_%02d.png`. Zyfen değerleri: yürüme bir tam adım döngüsü, eşit aralıkla 8 kare (24 fps'de kare 155–182); cast 6 kare (57, 61, 64, 67, 73, 79; açık avuç 4. kare = atış anı); gather 4 kare (13, 22, 40, 63). Hangi kareleri seçtiğini `art/source/<id>/README.md`'ye yaz.
4. **Yeşil silme:** `tools/art/chroma_key.py` (`key_image`). Zyfen: alfa = 1 − clamp((G − max(R,B) − 20)/40); yarı saydam pikselde G ≤ max(R,B)+8. Çıktı: `art/source/<id>/frames/{walk,cast,gather}/*.png`.
5. **Şerit:**
   ```
   python3 tools/art/make_zyfen_strip.py --src art/source/<id> --out assets/gfx/char/<id>_strip.png \
     --body-out assets/gfx/char/<id>_body.png --manifest art/source/<id>/strip_manifest.json \
     --quality art/source/<id>/quality.json --display-height <rig.display_height> --stride <walk.stride> \
     --align feet --palm-px X,Y [--idle <png>] [--native-facing left] [--preview]
   ```
   Araç karakterden bağımsızdır (dosya adı Zyfen döneminden kalmadır); kimlik `--src` dizin adından gelir.
6. **Kalite kapısı:** `foot_slide` ≥ N−2 çift ≤ 3 px, klip boy sapması ≤ %6, toplam genişlik ≤ 8192. Kırmızıysa çıkış 1 ve `quality.json` `pass:false`; sessiz yedek yok. Sıra: kullanıcıya sor → ayak çapası (`--align feet`, ≤ ±24 px) → `--stride` taraması (Zyfen 150'de 5/8, 130'da 8/8) → waiver `docs/design/walk-waiver-<id>.md` (tarih, kullanıcı onayı, ölçüm, gerekçe).
7. **`cast_point`:** cast karesinden avuç pikseli → `--palm-px`; manifest `palm.point` ile `rig.cast_point` farkı ≤ 0,03 (`docs/data-schema.md` "Manifest palm ↔ cast_point"). Zyfen `[0.375, -0.305]`.
8. **Veriyi bağla:** `data/characters/<id>.json` `rig.walk{frames,stride,strip,cell}`, `cast{frames,fire_frame,fps}`, `gather{frames}`; hücre boyutu manifestten. `godot --headless --import`, `.import` dosyaları commit'lenir.
9. **Görsel denetim:** `--preview` (`tools/art/_preview/`), `python3 tools/capture/walk_montage.py`, `tools/capture/anim_montage.py`, xvfb ile `tools/capture/shots_zyfen.gd` kalıbı. Klipler arası renk/kıyafet sıçramasına bak (F-059: Zyfen cast/gather'da palto astarı farkı).
10. `python3 -m pytest -q -p no:cacheprovider tools/art/tests` ve `bash tools/gate.sh`.

## Dokunulan dosyalar
`tools/art/make_zyfen_strip.py`, `tools/art/chroma_key.py`, `tools/art/tests/test_make_zyfen_strip.py`, `tools/art/README.md`, `art/source/<id>/`, `assets/gfx/char/`, `scripts/view/art_loader.gd`. `tools/art/make_strip.py` Gunslinger/piyade içindir; yeni karakterde kullanılmaz.

## Doğrulama
`pytest tools/art/tests`; `test/acceptance/test_acc_v202_rig_walk_gate.gd` ve `test_acc_v202_rig_manifest.gd` her kolsuz karakteri tarar (yerelde `V202_SLICES_FORCE=R`); gate; user-verify maddesi (cast_point hizası, el savurma hissi) kendi bölüm dosyasında.

## Kontrol listesi
- [ ] Yürüme **video + ffmpeg + yeşil silme**; kare kare AI çizimi değil (yan görünümde bacak sırası değişmez).
- [ ] `--preview` ölçümü bağlamadan önce; kapı kırmızıysa gerekçesiz geçilmez.
- [ ] `tools/art/_preview/` `.gitignore`'da (aynı commit).
- [ ] Hücre genişliği hesaplanır, elle yazılmaz; `walk.cell` manifestle aynı.
- [ ] Video ve ham kare dışı geçici dosya repoya girmez.
