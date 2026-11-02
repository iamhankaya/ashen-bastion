"""F-153: pytest ile GUT aynı ağaçta eşzamanlı koşar. Ağacın GUT'u etkileyen özeti: izlenen dosya değişiklikleri (git diff HEAD)
+ GUT'un okuduğu dizinlerdeki izlenmeyen dosya adları. `.gate/` ve diğer izlenmeyen çıktılar özete girmez. Git yoksa None."""
import hashlib
import subprocess
from pathlib import Path

GUT_DIRS = ("test", "scripts", "data", "addons")


def _git(root, *args):
    r = subprocess.run(["git", *args], cwd=root, capture_output=True)
    return r.stdout if r.returncode == 0 else None


def digest(root):
    root = Path(root)
    top = _git(root, "rev-parse", "--show-toplevel")
    if top is None or Path(top.decode().strip()).resolve() != root.resolve():
        return None
    diff = _git(root, "diff", "HEAD", "--binary")
    new = _git(root, "ls-files", "-o", "--exclude-standard", "--", *GUT_DIRS)
    if diff is None or new is None:
        return None
    return hashlib.sha256(diff + b"\0" + new).hexdigest()
