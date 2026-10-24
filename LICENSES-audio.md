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
