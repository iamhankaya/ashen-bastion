"""F-ashen-bastion-089: gen_data_fixtures.py çıktısı commit'li fixture'larla birebir aynı olmalı (sapma kapısı).

Üretici geçici dizine yazar (AB_FIXTURES_OUT); commit'li test/fixtures'a dokunulmaz. Karşılaştırma üretilen `data_*` ve
`char_bad_*` dizinleri için bayt düzeyindedir; commit'li tarafta fazladan `data_*`/`char_bad_*` dizini de sapmadır."""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools" / "ci" / "gen_data_fixtures.py"
COMMITTED = ROOT / "test" / "fixtures"
GENERATED = ("data_", "char_bad_")


def _tree(base: pathlib.Path) -> dict[str, bytes]:
    out = {}
    for d in sorted(base.iterdir()):
        if d.is_dir() and d.name.startswith(GENERATED):
            for p in sorted(d.rglob("*")):
                if p.is_file():
                    out[p.relative_to(base).as_posix()] = p.read_bytes()
    return out


def test_write_is_lf_even_with_windows_text_mode(tmp_path, monkeypatch):
    """Windows'ta metin kipi yazım "\\n"i CRLF'e çevirir (commit'li fixture LF). Üretici platformdan bağımsız LF
    yazmalı; Mac'te bunu Path.write_text'i Windows gibi davranacak şekilde yamayarak yakalarız."""
    sys.path.insert(0, str(ROOT / "tools" / "ci"))
    monkeypatch.setenv("AB_FIXTURES_OUT", str(tmp_path))
    sys.modules.pop("gen_data_fixtures", None)
    import gen_data_fixtures as gen

    real = pathlib.Path.write_text

    def win_write_text(self, data, encoding=None, errors=None, newline=None):
        return real(self, data.replace("\n", "\r\n") if newline is None else data, encoding=encoding)

    monkeypatch.setattr(pathlib.Path, "write_text", win_write_text)
    gen.write(tmp_path, "a/b.json", {"x": [1, 2]})
    gen.write(tmp_path, "a/c.txt", "satir1\nsatir2\n")
    for rel in ("a/b.json", "a/c.txt"):
        assert b"\r\n" not in (tmp_path / rel).read_bytes(), f"{rel}: CRLF yazıldı"
    sys.modules.pop("gen_data_fixtures", None)


def test_committed_fixtures_have_no_crlf():
    bad = [k for k, v in _tree(COMMITTED).items() if b"\r\n" in v]
    assert not bad, f"commit'li fixture CRLF içeriyor: {bad[:10]}"


def test_generator_output_matches_committed_fixtures(tmp_path):
    env = {**os.environ, "AB_FIXTURES_OUT": str(tmp_path)}
    r = subprocess.run([sys.executable, str(TOOL)], capture_output=True, text=True, env=env, cwd=ROOT)
    assert r.returncode == 0, r.stderr[-500:]
    gen, com = _tree(tmp_path), _tree(COMMITTED)
    assert sorted(gen) == sorted(com), f"dosya kümesi farkı: {sorted(set(gen) ^ set(com))[:10]}"
    diff = [k for k in gen if gen[k] != com[k]]
    assert not diff, f"üretilen çıktı commit'li fixture'dan sapıyor: {diff[:10]}"
