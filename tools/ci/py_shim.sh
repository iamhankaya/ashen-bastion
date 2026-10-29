# Kaynaklanır (source), çalıştırılmaz. Windows/Git Bash: `python3` Microsoft Store kısayolu çalışmaz ("Python bulunamad", çıkış 49) ve
# gate.sh / checks.d `python3` çağırır. Çalışan python3 yoksa ama `python` çalışıyorsa python3 işlevi `python`a yönlendirir ve alt bash
# süreçlere aktarılır (export -f). Çalışan python3 olan ortamda (CI/Linux) hiçbir şey yapmaz. Prova bulgusu (T20261029-19).
if ! python3 -c "" >/dev/null 2>&1 && python -c "" >/dev/null 2>&1; then
  python3() { python "$@"; }
  export -f python3
fi
