# CI hız notları

## Tek-test süre sınırı: 75 sn

Gate'te tek bir testin duvar saati sınırı 60 sn'den **75 sn**'ye çıkarıldı (`tools/ci/check_durations.py --limit`, `tools/gate.sh` adım mesajı, `docs/dev/setup.md`).
Bu **geçici**dir (kullanıcı kararı 2026-10-25, F-ashen-bastion-048); kalıcı çözüm testi hızlandırmaktır (ağır test `test/long/` altına taşınır).
