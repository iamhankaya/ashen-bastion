"""tools/ci/godot_import.sh (F-042): yalnız bilinen imza (SIGABRT/134 + içerik hatası yok) en çok 1 kez yeniden denenir."""
import os
import pathlib
import subprocess

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "godot_import.sh"

# Sahte Godot: sayaç dosyasına satır ekler; davranış dizisi FAKE_PLAN ("abrt,ok" gibi) sırayla uygulanır.
FAKE = r"""#!/usr/bin/env bash
echo x >> "$FAKE_COUNT"
n=$(wc -l < "$FAKE_COUNT")
step=$(echo "$FAKE_PLAN" | cut -d, -f"$n")
[ -d .godot ] && echo "godot_var_$n" >> "$FAKE_SEEN" || echo "godot_yok_$n" >> "$FAKE_SEEN"
echo "[ 30% ] reimport | a.png"
case "$step" in
  ok) exit 0 ;;
  abrt) kill -ABRT $$ ;;
  abrt_err) echo "ERROR: bozuk kaynak"; kill -ABRT $$ ;;
  fail) echo "SCRIPT ERROR: x"; exit 1 ;;
  kill9) kill -KILL $$ ;;
esac
"""


def run(tmp_path, plan, umask="022", summary=True):
    fake = tmp_path / "fake_godot.sh"
    fake.write_text(FAKE)
    fake.chmod(0o755)
    (tmp_path / "proj" / ".godot").mkdir(parents=True)
    (tmp_path / "proj" / ".godot" / "yarim.bin").write_text("yarim yazilmis")
    env = {
        "PATH": os.environ["PATH"], "GODOT_BIN": str(fake), "FAKE_PLAN": plan,
        "FAKE_COUNT": str(tmp_path / "count"), "FAKE_SEEN": str(tmp_path / "seen"),
    }
    if summary:
        env["GITHUB_STEP_SUMMARY"] = str(tmp_path / "summary.md")
    (tmp_path / "proj" / ".gate").mkdir(exist_ok=True)
    r = subprocess.run(
        ["bash", "-c", f"umask {umask}; bash {SCRIPT} .gate/import.log"],
        cwd=tmp_path / "proj", env=env, capture_output=True, text=True,
    )
    count = len((tmp_path / "count").read_text().split()) if (tmp_path / "count").exists() else 0
    return r, count


def test_clean_run_no_retry_no_note(tmp_path):
    r, n = run(tmp_path, "ok")
    assert r.returncode == 0 and n == 1
    assert "IMPORT_RETRY" not in r.stderr
    assert not (tmp_path / "proj" / ".gate" / "import_retry.txt").exists()


def test_single_sigabrt_is_retried_once_and_reported(tmp_path):
    r, n = run(tmp_path, "abrt,ok")
    assert r.returncode == 0 and n == 2
    assert r.stderr.count("IMPORT_RETRY") == 2  # deneme 1 çöktü + deneme 2 başarılı: ikisi de görünür
    note = (tmp_path / "proj" / ".gate" / "import_retry.txt").read_text()
    assert "SIGABRT" in note and "deneme 2 başarılı" in note
    assert "IMPORT_RETRY" in (tmp_path / "summary.md").read_text()
    assert (tmp_path / "proj" / ".gate" / "import.log.deneme1").exists()
    # yarım .godot yeniden denemeden önce silindi
    assert (tmp_path / "seen").read_text().split() == ["godot_var_1", "godot_yok_2"]


def test_second_sigabrt_stays_red_and_no_third_attempt(tmp_path):
    r, n = run(tmp_path, "abrt,abrt,ok")
    assert r.returncode == 134 and n == 2
    assert "yeniden deneme yok, gate kırmızı" in r.stderr


def test_sigabrt_with_content_error_is_not_retried(tmp_path):
    r, n = run(tmp_path, "abrt_err,ok")
    assert r.returncode == 134 and n == 1
    assert "IMPORT_RETRY" not in r.stderr


def test_other_failures_are_not_retried(tmp_path):
    r, n = run(tmp_path, "fail,ok")
    assert r.returncode == 1 and n == 1
    (tmp_path / "k").mkdir()
    r, n = run(tmp_path / "k", "kill9,ok")
    assert r.returncode == 137 and n == 1  # SIGKILL (OOM) imza değil


def test_works_under_restrictive_umask_and_stdin_script(tmp_path):
    r, n = run(tmp_path, "abrt,ok", umask="077", summary=False)
    assert r.returncode == 0 and n == 2
    # bash -s < betik: betik stdin'i tüketmemeli (sahte Godot'tan sonra hat satırı hâlâ koşar)
    fake = tmp_path / "fake_godot.sh"
    env = {"PATH": os.environ["PATH"], "GODOT_BIN": str(fake), "FAKE_PLAN": "ok",
           "FAKE_COUNT": str(tmp_path / "c2"), "FAKE_SEEN": str(tmp_path / "s2")}
    src = f"bash {SCRIPT} .gate/import.log\necho SONRAKI_SATIR\n"
    r = subprocess.run(["bash", "-s"], input=src, cwd=tmp_path / "proj", env=env, capture_output=True, text=True)
    assert "SONRAKI_SATIR" in r.stdout
