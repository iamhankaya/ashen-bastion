#!/usr/bin/env python3
"""precheck provası (prova fazı): her kırmızı sınıf için GERÇEK araçlarla kasıtlı ihlal -> beklenen etiket.

  prova_precheck.py --root <geçici worktree> [--godot BIN]

--root: `git worktree add --detach <geçici yol> HEAD` ile açılmış ayrı ağaç (repo kökü/altı ve geçici dizin dışı reddedilir). Her senaryo temiz ağaçta
ihlali uygular, `bash tools/precheck.sh --base HEAD` koşar, stderr'de `PRECHECK_FAIL: <ETİKET>` arar, ağacı sıfırlar.
gdformat/gdlint PATH'te yoksa `python -m gdtoolkit.*` sarmalayıcıları geçici dizine konur. Çıktı: `PROVA <etiket>: yakalandı|KAÇTI`; çıkış 0 yalnız hepsi yakalandıysa.
--godot ile USER_LEAK da denenir (içe aktarma + `gate.sh --changed`: dakikalar sürer).
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

LONG_FILE = "scripts/domain/achievement_progress_view.gd"
RENAME_FILE = "test/unit/test_catalog_achievement_dry_run.gd"


def check_root(root: Path) -> Path:
    real = root.resolve()
    tmp = Path(tempfile.gettempdir()).resolve()
    if real == REPO.resolve() or REPO.resolve() in real.parents or tmp not in real.parents and os.environ.get("PROVA_ALLOW_ROOT") != str(real):
        raise SystemExit(f"--root repo dışında ve geçici dizin altında olmalı: {real}")
    if not (real / ".git").exists():
        raise SystemExit(f"--root bir git worktree'si değil: {real}")
    return real


def git(root: Path, *args: str) -> str:
    r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise SystemExit(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def write(root: Path, rel: str, body: str, append=False) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a" if append else "w", encoding="utf-8", newline="\n") as f:
        f.write(body)


def break_sh_mode(root):
    write(root, "tools/zz_prova.sh", "#!/usr/bin/env bash\ntrue\n")
    git(root, "add", "tools/zz_prova.sh")
    git(root, "update-index", "--chmod=-x", "tools/zz_prova.sh")


def break_upper_lower(root):
    write(root, "scripts/domain/zz_upper.gd", "class_name ZzUpper\nextends RefCounted\n\n\nfunc f(s: String) -> String:\n\treturn s.to_upper()\n")


def break_gdformat(root):
    write(root, "scripts/domain/zz_fmt.gd", "class_name ZzFmt\nextends RefCounted\nfunc  f( a:int )->int:\n  return a+1\n")


def break_gdlint(root):
    write(root, "scripts/domain/zz_lint.gd", "class_name ZzLint\nextends RefCounted\n\n\nfunc BadName() -> void:\n\tpass\n")


def break_line_budget(root):
    write(root, LONG_FILE, "".join(f"# zz dolgu {i}\n" for i in range(900)), append=True)


def break_ui_rules(root):
    write(root, "scripts/ui/zz_scroll.gd", "class_name ZzScroll\nextends RefCounted\n\n\nfunc f() -> Node:\n\treturn ScrollContainer.new()\n")


def break_layers(root):
    write(root, "scripts/sim/zz_layer.gd", "class_name ZzLayer\nextends RefCounted\n\n\nfunc f() -> void:\n\tUiKit.make_scroll()\n")


def break_test_ids(root):
    p = root / RENAME_FILE
    text = p.read_text(encoding="utf-8")
    new, n = re.subn(r"^func (test_\w+)", r"func zz_disabled_\1", text, count=1, flags=re.M)
    assert n == 1, "yeniden adlandırılacak test bulunamadı"
    p.write_text(new, encoding="utf-8", newline="\n")


def break_baseline(root):
    write(root, "test/characterization/baseline/rf_ach_flows.json", "\n", append=True)


def break_user_leak(root):
    write(root, "test/unit/test_zz_leak_probe.gd", 'extends GutTest\n\n\nfunc test_zz_leak_probe() -> void:\n\tvar f := FileAccess.open("user://zz_leak_probe.txt", FileAccess.WRITE)\n\tf.store_string("x")\n\tf.close()\n\tassert_true(true)\n')


SCENARIOS = [
    ("SH_MODE", break_sh_mode), ("UPPER_LOWER", break_upper_lower), ("GDFORMAT", break_gdformat), ("GDLINT", break_gdlint),
    ("LINE_BUDGET", break_line_budget), ("UI_RULES", break_ui_rules), ("LAYERS", break_layers), ("TEST_IDS", break_test_ids),
    ("BASELINE", break_baseline),
]


def shim_dir() -> Path:
    d = Path(tempfile.mkdtemp(prefix="prova_shim_"))
    for tool, mod in (("gdformat", "gdtoolkit.formatter"), ("gdlint", "gdtoolkit.linter")):
        (d / tool).write_text(f'#!/usr/bin/env bash\nexec "{Path(sys.executable).as_posix()}" -m {mod} "$@"\n', encoding="utf-8", newline="\n")
        (d / tool).chmod(0o755)
    return d


def reset(root: Path) -> None:
    git(root, "reset", "-q", "--hard", "HEAD")
    git(root, "clean", "-fdq", "--", "scripts", "test", "tools")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True)
    ap.add_argument("--godot", default="")
    a = ap.parse_args(argv)
    root = check_root(Path(a.root))
    env = dict(os.environ)
    env.pop("GODOT_BIN", None)
    shims = None
    if not shutil.which("gdformat") or not shutil.which("gdlint"):
        shims = shim_dir()
        env["PATH"] = f"{shims}{os.pathsep}{env['PATH']}"
    scenarios = list(SCENARIOS)
    if a.godot:
        scenarios.append(("USER_LEAK", break_user_leak))
        env["GODOT_BIN"] = a.godot
    missed = 0
    try:
        for label, mutate in scenarios:
            reset(root)
            mutate(root)
            args = ["bash", "tools/precheck.sh", "--base", "HEAD"] + (["--godot"] if label == "USER_LEAK" else [])
            r = subprocess.run(args, cwd=root, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=3600)
            hit = f"PRECHECK_FAIL: {label}" in r.stderr and r.returncode == 1
            skipped = f"PRECHECK_SKIP: {label}" in r.stderr
            print(f"PROVA {label}: {'yakalandı' if hit else 'KAÇTI' + (' (araç atlandı)' if skipped else '')}")
            if not hit:
                missed += 1
                print("  stderr son satırlar: " + " | ".join(r.stderr.strip().splitlines()[-4:]))
        reset(root)
        r = subprocess.run(["bash", "tools/precheck.sh", "--base", "HEAD"], cwd=root, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
        clean = r.returncode == 0
        print(f"PROVA TEMİZ_AĞAÇ: {'yeşil' if clean else 'KIRMIZI'}")
        if not clean:
            print("  " + " | ".join(r.stderr.strip().splitlines()[-4:]))
            missed += 1
    finally:
        if shims:
            shutil.rmtree(shims, ignore_errors=True)
    return 0 if missed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
