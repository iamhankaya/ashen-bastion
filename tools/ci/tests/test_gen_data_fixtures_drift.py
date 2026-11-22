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


def test_generator_output_matches_committed_fixtures(tmp_path):
    env = {**os.environ, "AB_FIXTURES_OUT": str(tmp_path)}
    r = subprocess.run([sys.executable, str(TOOL)], capture_output=True, text=True, env=env, cwd=ROOT)
    assert r.returncode == 0, r.stderr[-500:]
    gen, com = _tree(tmp_path), _tree(COMMITTED)
    assert sorted(gen) == sorted(com), f"dosya kümesi farkı: {sorted(set(gen) ^ set(com))[:10]}"
    diff = [k for k in gen if gen[k] != com[k]]
    assert not diff, f"üretilen çıktı commit'li fixture'dan sapıyor: {diff[:10]}"
