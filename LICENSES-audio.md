# Ses lisansları

## Müzik (`audio/muzik/` kaynak, `assets/audio/music/*.ogg` işlenmiş)
Kullanıcı tarafından Suno Pro ile üretilmiş müzikler (kullanıcı üretimi; Pro planı ticari kullanım hakkı verir), 2026-10-24,
bkz. `audio/muzik/README.txt`. SoundFont lisans açığı (F-ashen-bastion-001) bununla kapanır.
`tools/audio/process_audio.py`: 44,1 kHz, -18 LUFS, döngülerde start_s/end_s kırpma + crossfade, OGG Vorbis.

## Ses efektleri (`audio/sfx/` kaynak, `assets/audio/sfx/*.ogg` işlenmiş)
Kullanıcı tarafından ElevenLabs ücretli planıyla üretilmiş ses efektleri (kullanıcı üretimi; ücretli plan ticari kullanım
hakkı verir), 2026-10-24, bkz. `audio/sfx/README.txt`. Kaynak 21 WAV (48 kHz stereo); oyunun kullandığı OGG'ler
`tools/audio/process_sfx.py` ile üretilir (mono, 44,1 kHz, kırpılmış, kimliğe göre LUFS, tepe <= -1 dBFS).
`dry_fire` (boş tetik) aynı kaynaktan sonradan eklendi.

## Zyfen ses efektleri (`art/source/zyfen/audio/` kaynak, `assets/audio/sfx/*.ogg` işlenmiş)
Zyfen için 21 ses (savuruş `zyfen_cast_1..3`, isabet `zyfen_wind_hit_1..2`, rüzgar toplama `zyfen_gather`/`zyfen_gather_done`,
beceri sesleri `hava_bicaklari_1..3`, `delen_ruzgar`, `girdap`, `hortum`, `hava_cebi`, `nefes_dalgasi`, `ay_oragi`,
`kasirga_patlamasi`, `gogun_mizragi`, `tufan`, evrim anları `evolution_7`/`evolution_8`), 2026-10-24. Kullanıcı üretimi
(ElevenLabs ücretli plan, yukarıdaki efekt setiyle aynı kaynak ve hak durumu); kaynak 48 kHz stereo WAV. Aynı hat
(`tools/audio/process_sfx.py`, manifest girdileri `src` ile `art/source/zyfen/audio/`'a bakar): mono, 44,1 kHz, kırpılmış,
kimliğe göre LUFS, tepe <= -1 dBFS. Boyut: işlenmiş OGG'ler toplam ~280 KB (kaynak WAV'lar APK'ya girmez).
