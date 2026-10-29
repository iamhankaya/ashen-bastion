"""BASELINE_CHANGED: test/characterization/baseline/** içeriği baseline_changes.txt kaydıyla uyuşmalı (T20261028-35)."""
import hashlib
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = ROOT / "test" / "characterization" / "baseline"
CHANGES = ROOT / "tools" / "ci" / "baseline_changes.txt"


def _latest() -> dict[str, str]:
    out: dict[str, str] = {}
    for line in CHANGES.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        assert len(parts) == 4, f"BASELINE_CHANGED: kayıt biçimi bozuk: {line}"
        out[parts[0]] = parts[1]  # son satır geçerli (append-only)
    return out


def _files() -> list[pathlib.Path]:
    return sorted(p for p in BASE.glob("**/*") if p.is_file() and p.name != ".gitkeep")


def test_every_baseline_file_has_a_matching_change_record():
    latest = _latest()
    for p in _files():
        rel = p.relative_to(ROOT).as_posix()
        sha = hashlib.sha256(p.read_bytes()).hexdigest()
        assert rel in latest, f"BASELINE_CHANGED: {rel} baseline_changes.txt'te kayıtlı değil"
        assert latest[rel] == sha, f"BASELINE_CHANGED: {rel} sha256 kayıtla uyuşmuyor"


def test_every_change_record_points_to_an_existing_baseline():
    for rel in _latest():
        assert (ROOT / rel).is_file(), f"BASELINE_CHANGED: kayıtlı baz dosyası yok: {rel}"
