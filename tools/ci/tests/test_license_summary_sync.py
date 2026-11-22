"""F-ashen-bastion-084: LİSANSLAR ekranının elle yazılmış özeti (settings_screen.gd LICENSE_ROWS) ile kaynak lisans
dosyaları aynı şeyi söylemeli. Kaynak değişirse (ör. farklı lisans sürümü, sağlayıcı) bu test özetin güncellenmesini ister."""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCREEN = ROOT / "scripts" / "ui" / "settings_screen.gd"
FONT_LICENSES = {"CINZEL": ROOT / "assets/fonts/LICENSE-Cinzel-OFL.txt", "INTER": ROOT / "assets/fonts/LICENSE-Inter-OFL.txt"}
AUDIO = ROOT / "LICENSES-audio.md"


def rows() -> dict[str, str]:
    src = SCREEN.read_text(encoding="utf-8")
    block = re.search(r"const LICENSE_ROWS := \[(.*?)\n\]\n", src, re.S)
    assert block, "LICENSE_ROWS bulunamadı"
    pairs = re.findall(r'\[\s*"([^"]+)",\s*"([^"]+)"\s*\]', block.group(1), re.S)
    assert len(pairs) >= 4, pairs
    return dict(pairs)


def test_font_rows_match_the_ofl_files():
    r = rows()
    for name, path in FONT_LICENSES.items():
        text = path.read_text(encoding="utf-8")
        assert "SIL Open Font License, Version 1.1" in text, f"{path.name}: lisans sürümü beklenenden farklı"
        assert "SIL Open Font License 1.1" in r[name], f"{name} özeti lisans dosyasıyla uyuşmuyor: {r[name]}"


def test_audio_rows_name_the_providers_documented_in_licenses_audio():
    r = rows()
    audio = AUDIO.read_text(encoding="utf-8")
    assert "Suno Pro" in audio and "Suno Pro" in r["MÜZİK"]
    assert "ElevenLabs" in audio and "ElevenLabs" in r["SES EFEKTLERİ"]


def test_a_changed_source_is_detected():
    """Mutasyon: lisans dosyası farklı sürüm söylerse karşılaştırma kırmızı olur (kontrol mantığı sınanır)."""
    changed = FONT_LICENSES["INTER"].read_text(encoding="utf-8").replace("Version 1.1", "Version 2.0")
    assert "SIL Open Font License, Version 1.1" not in changed
