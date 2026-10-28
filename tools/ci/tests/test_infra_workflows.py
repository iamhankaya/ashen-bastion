"""Altyapı-A: tüm workflow'larda timeout, H1/H2/H10 bağlantıları, nightly tam koşu (süzgeçsiz)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WF = ROOT / ".github" / "workflows"
CI = (WF / "ci.yml").read_text(encoding="utf-8")
NIGHTLY = (WF / "nightly.yml").read_text(encoding="utf-8")
H1_PATTERN = r"tools/|\.github/|project\.godot$|\.gutconfig\.json$|\.godot-version$|export_presets\.cfg$|addons/|scripts/ci"


def jobs(text):
    """{iş_adı: gövde}; yalnız `jobs:` altındaki 2 girintili anahtarlar."""
    body = text.split("\njobs:\n", 1)[1]
    parts = re.split(r"^  ([\w-]+):[ \t]*$", body, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def block(job):
    return jobs(CI)[job]


def test_every_job_in_every_workflow_has_timeout():
    for f in sorted(WF.glob("*.yml")):
        for name, body in jobs(f.read_text(encoding="utf-8")).items():
            if re.search(r"^    uses:", body, re.M):
                continue  # yeniden kullanılan workflow: sınırlar çağrılan dosyadadır
            assert re.search(r"^    timeout-minutes:\s*\d+", body, re.M), f"{f.name}:{name} timeout-minutes yok"


def test_import_cache_holds_only_imported_and_uid_cache():
    for job in ("static", "gut"):
        b = block(job)
        assert "~/.cache/ashen-bastion" in b
        m = re.search(r"path:\s*\|\s*\n\s*\.godot/imported\s*\n\s*\.godot/uid_cache\.bin", b)
        assert m, f"{job}: önbellek yolu yalnız .godot/imported + .godot/uid_cache.bin olmalı"
    assert not re.search(r"path:\s*\.godot\s*$", CI, re.M), "tüm .godot önbelleğe girmemeli (class cache her koşuda yenilenir)"
    code = chr(10).join(l for l in CI.splitlines() if not l.strip().startswith("#"))
    assert "global_script_class_cache" not in code


def test_import_cache_key_keeps_audio_and_has_no_scripts_hash():
    keys = re.findall(r"key:\s*godot-import-\$\{\{ hashFiles\(([^)]*)\) \}\}", CI)
    assert keys, "godot-import anahtarı yok"
    for k in keys:
        assert "'audio/**'" in k and "'.godot-version'" in k and "'project.godot'" in k and "'**/*.import'" in k
        assert "scripts" not in k


def test_selftest_filters_taban_yesil_by_paths_with_safe_fallback():
    b = block("selftest")
    assert "fetch-depth: 0" in b
    assert "bash tools/ci/path_filter.sh" in b and H1_PATTERN in b
    assert "SELFTEST_SKIP_TABAN" in b and "steps.taban.outputs.run" in b
    assert "godot-import-" in b, "selftest .godot/imported önbelleğini geri yüklemeli (H2 aktarımı)"


def test_export_debug_and_release_prova_are_path_filtered():
    for job in ("export-debug", "release-prova"):
        b = block(job)
        assert "bash tools/ci/path_filter.sh" in b and "fetch-depth: 0" in b, job
        assert "steps.pf.outputs.run == '1'" in b, job
        assert "uses: actions/checkout" in b


def test_nightly_runs_full_ci_without_filter():
    # kapsam kanıtı: nightly CI'ı yeniden kullanır; push dışı olay path_filter'da her zaman run=1 verir
    assert re.search(r"^on:\s*\n(?:.*\n)*?\s+workflow_call:", CI, re.M), "ci.yml workflow_call sunmalı"
    j = jobs(NIGHTLY)
    assert "full" in j and re.search(r"uses:\s*\./\.github/workflows/ci\.yml", j["full"])
    assert "secrets: inherit" in j["full"]
    assert "long" in j


def test_ci_concurrency_group_is_per_ref_and_event():
    head = CI.split("\njobs:\n")[0]
    assert "group: ci-${{ github.ref }}-${{ github.event_name }}" in head
