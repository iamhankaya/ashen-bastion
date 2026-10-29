---
name: ab-ses-ekle
description: Ashen Bastion'a ses efekti veya müzik eklerken (sfx_manifest, process_sfx.py, karakter sfx sözlüğü, beceri/evrim sesi, lisans kaydı) kullan.
---

# Ses efekti / müzik

Yeni ses üretmez, lisansı belirsiz ses eklemezsin; belirsizlik açık noktaya.

## Adımlar
1. **Kaynak + lisans:** kaynak WAV `audio/sfx/` (müzik `audio/muzik/`); lisans kaydı `LICENSES-audio.md` (ve `audio/sfx/README.txt` varsa oraya).
2. **Manifest:** `tools/audio/sfx_manifest.json` satırı eklenir.
3. **İşle:** `python3 tools/audio/process_sfx.py [--only <id>] [--verify] [--report]` → `assets/audio/sfx/<id>.ogg`. Müzik: `tools/audio/process_audio.py`, `check_music.py`, `tools/audio/audio_manifest.json`.
4. **Bağla:** karakter `sfx{shot,hit,reload_start,reload_end,dry}` sözlüğü (`scripts/sim/data_v2.gd` `SFX_EVENTS`); sözlük varsa anahtarı olmayan olay sessiz kalır. Beceri `cast_sfx`; evrim `sfx: evolution_N`. Eşzamanlı sınır / en kısa tekrar aralığı gerekiyorsa `data/sfx_rules.json` (`limits`, `min_gap_ms`); `sfx.gd` düzenlenmez. Varyasyon seçimi sunum RNG'sinde (sim RNG'sine dokunma).
5. **İçe aktar:** `godot --headless --import`; `.import` dosyaları commit'lenir.
6. Araç geçici çıktısı varsa aynı commit'te `.gitignore`.

## Dokunulan dosyalar
`tools/audio/{sfx_manifest.json,process_sfx.py,audio_manifest.json,process_audio.py,check_music.py}`, `assets/audio/sfx/`, `LICENSES-audio.md`, `data/characters/<id>.json` `sfx`, `data/skills/<id>.json` `cast_sfx`.

## Doğrulama
`python3 -m pytest -q -p no:cacheprovider tools/audio/tests`; `bash tools/gate.sh` (adım 4 veri doğrulama bilinmeyen ses kimliğini yakalar); cihaz listesi (SFX kalabalığı) kendi bölüm dosyanda.

## Kontrol listesi
- [ ] Lisans kaydı eklendi; belirsiz lisans yok.
- [ ] `.import` commit'lendi; manifest ↔ dosya tutarlı (`--verify`).
- [ ] Kabul testi önbelleğe yazıyorsa geri aldı.
- [ ] Cihaz maddesi ortak `docs/dev/user-verify.md`'ye değil kendi bölüm dosyana.

## Örnek
Zyfen: `data/characters/zyfen.json` `sfx` (`zyfen_cast`, `zyfen_wind_hit`, `zyfen_gather`, `zyfen_gather_done`).
