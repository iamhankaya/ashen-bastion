---
name: ab-gorsel-ikon-uret
description: Ashen Bastion için portre, beceri/başarım ikonu, efekt dokusu veya UI görseli üretirken (Codex ile görsel, kullanıcı makinesi veya bulut, düz yeşil zemin, tools/art işleme hattı, APK boyutu) kullan.
---

# Görsel ve ikon hattı

Kural (kararlar 2026-10-25, 2026-10-26): görsel ve ikon **Codex ile üretilir** (`codex exec`; kullanıcı makinesinde de bulut çalışanında da) ve **repoya girmeden kullanıcıya gösterilir**; onaydan sonra eklenir. Kısa video Gemini ile (bulutta `GEMINI_API_KEY`). Araç yoksa uydurma, açık nokta yaz. Kaynak/model notu `art/source/<ad>/README.md`'ye (araç, istem, tarih).

## Codex kullanımı
- Bulutta oturum yoksa `codex login --device-auth` çalıştır, cihaz kodunu `[VLAD:ASK]` ile kullanıcıya ilet (yerelde `vlad task ask`); giriş yapılmadan üretme.
- Çıktı `~/.codex/generated_images/<oturum>/` altına düşer; hedefe (`art/source/<ad>/`) kopyala.
- Paralel `codex exec` zaman aşımına uğrar: görselleri **tek tek** üret.
- Üretilen her görsel repoya girmeden kullanıcıya gösterilir (yol/önizleme + seçenekler); onaysız eklenmez. Onaylı kaynak repoda zaten varsa yeniden üretme, README'deki onay notuna dayan.

## Adımlar
1. **İstem:** `docs/design/v2.0/prompts.md` şablonları (ortak stil, negatif, kare kare üretim). Esin kaynağı adı istemde geçmez. Portre güvenli alanı P1: 1024×1536, yüz üst üçte birde (göz %24–30), alt %40 önemsiz, önemli her şey x %12–88 ve y %6–62.
2. **Onay:** üretilen görsel kullanıcıya gösterilir (yol/önizleme + seçenekler); onaysız repoya girmez.
3. **İşleme (`tools/art/`):**
   - sprite/zemin/harabe: `python3 tools/art/process_art.py [--only <id>] [--preview|--verify]` (`tools/art/art_manifest.json` satırı gerekir).
   - beceri ikonu: alfa kutusuna kırp, uzun kenar %80, 256 px kare tuval → `assets/ui/icons/<id-tireli>.png` (Zyfen: `python3 tools/art/process_zyfen_fx.py [--check]`; Gunslinger: `tools/art/process_gunslinger_icons.py`).
   - efekt dokusu: `ab-efekt-shader`. Başarım ikonu: `assets/ui/achievements/<id>.png` (`ab-basarim-ekle`).
4. **Veri bağlama:** `data/skills/*.json` `icon`; yedek arama `scripts/ui/ui_kit.gd` `skill_icon`.
5. **İçe aktarma:** `godot --headless --import`; `.import` dosyaları commit'lenir; başarım ikonu `mipmaps/generate=true`.
6. **Boyut:** kaynak PNG toplamını raporla; `art/` ve `docs/` APK dışında mı `export_presets.cfg` `exclude_filter`'dan doğrula (doğrulayamazsan "doğrulanmadı" yaz).
7. `python3 -m pytest -q -p no:cacheprovider tools/art/tests`, `process_art.py --verify`, `bash tools/precheck.sh` (+ CI; `ab-test-ve-kapi`), ekran görüntüsü (`tools/capture/`).

## Dokunulan dosyalar
`tools/art/{process_art.py,art_manifest.json,process_zyfen_fx.py,process_gunslinger_icons.py,make_icons.py}`, `tools/art/tests/`, `assets/gfx/manifest.json`, `assets/ui/icons/`, `assets/ui/achievements/`, `scripts/ui/ui_kit.gd`, `.gitignore`.

## Kontrol listesi
- [ ] Lisansı belirsiz görsel/ikon eklenmez; belirsizlik açık noktaya.
- [ ] Yürüme karesi isteniyorsa tek ızgarada değil, `ab-animasyon-seridi` (video) hattıyla.
- [ ] Kare kare ayrı üret; toplu ızgara istenmez (tutarlılık bozulur).
- [ ] Araç geçici çıktı klasörü (`tools/art/_preview/`) aynı commit'te `.gitignore`'da.
- [ ] Esin kaynağı adı ve sır repoya girmedi (`tools/ci/check_forbidden_names.sh`).

## Örnek
Zyfen becerileri: `art/source/zyfen/icons/*.png` → `process_zyfen_fx.py` → `assets/ui/icons/ruzgar-kesigi.png` benzeri; portre `assets/gfx/char/zyfen_portrait.png`.
