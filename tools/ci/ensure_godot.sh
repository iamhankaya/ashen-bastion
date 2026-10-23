#!/usr/bin/env bash
# Godot'u kurar/doğrular (idempotent). Başarıda GODOT_BIN yolunu stdout'a yazar.
# Çıkış kodları: 0 tamam, 3 ağ yok (GATE_NET), 1 diğer hata.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
V="$(tr -d '[:space:]' < "$ROOT/.godot-version")"
CACHE="${ASHEN_CACHE:-$HOME/.cache/ashen-bastion}/$V"
BIN="$CACHE/Godot_v${V}_linux.x86_64"
BASE="https://github.com/godotengine/godot-builds/releases/download/$V"
HOST="github.com"

fetch() { # fetch <dosya>
  mkdir -p "$CACHE"
  curl -fL --retry 3 -sS -o "$CACHE/$1" "$BASE/$1"
}

# Export şablonları yalnız GATE_EXPORT=1 ile (Godot zaten kuruluyken de çalışır).
ensure_templates() {
  [ "${GATE_EXPORT:-0}" = "1" ] || return 0
  local TDIR="$HOME/.local/share/godot/export_templates/${V/-/.}"
  [ -d "$TDIR" ] && return 0
  fetch "Godot_v${V}_export_templates.tpz" || { echo "GATE_NET: $HOST erişilemiyor — şablonlar indirilemedi" >&2; exit 3; }
  (cd "$CACHE" && grep "export_templates.tpz" "$ROOT/tools/ci/checksums.txt" | sha512sum -c - >&2)
  mkdir -p "$TDIR" "$CACHE/tpl" && unzip -oq "$CACHE/Godot_v${V}_export_templates.tpz" -d "$CACHE/tpl"
  cp -r "$CACHE/tpl/templates/." "$TDIR/"
}

if [ -n "${GODOT_BIN:-}" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "^${V%-stable}\.stable"; then
  ensure_templates; echo "$GODOT_BIN"; exit 0
fi
if [ -x "$BIN" ] && "$BIN" --version 2>/dev/null | grep -q "^${V%-stable}\.stable"; then
  ensure_templates; echo "$BIN"; exit 0
fi

if [ "${GATE_SIMULATE_NO_NET:-0}" = "1" ]; then
  echo "GATE_NET: $HOST erişilemiyor — Godot indirilemedi (simülasyon)" >&2; exit 3
fi

mkdir -p "$CACHE"
if ! fetch "Godot_v${V}_linux.x86_64.zip" 2>"$CACHE/curl.err"; then
  echo "GATE_NET: $HOST erişilemiyor — Godot indirilemedi ($(head -c 200 "$CACHE/curl.err"))" >&2
  exit 3
fi
(cd "$CACHE" && grep "Godot_v${V}_linux.x86_64.zip" "$ROOT/tools/ci/checksums.txt" | sha512sum -c - >&2)
(cd "$CACHE" && unzip -oq "Godot_v${V}_linux.x86_64.zip")
chmod +x "$BIN"

# Dinamik kitaplıklar eksikse (root + apt varsa) kur; yoksa paketleri listele.
if ldd "$BIN" 2>/dev/null | grep -q "not found"; then
  missing="libasound2t64 libx11-6 libxcursor1 libxi6 libxinerama1 libxrandr2 libgl1 libfontconfig1"
  SUDO=""
  [ "$(id -u)" != "0" ] && command -v sudo >/dev/null && sudo -n true 2>/dev/null && SUDO="sudo -n"
  if { [ "$(id -u)" = "0" ] || [ -n "$SUDO" ]; } && command -v apt-get >/dev/null; then
    $SUDO apt-get update -qq >&2 || true
    $SUDO apt-get install -y -qq $missing >&2 || $SUDO apt-get install -y -qq ${missing/libasound2t64/libasound2} >&2 || true
  else
    echo "Eksik kitaplıklar var; kurulması gereken paketler: $missing" >&2
  fi
fi
"$BIN" --version >/dev/null 2>&1 || { echo "Godot çalışmıyor: $BIN" >&2; exit 1; }

ensure_templates
echo "$BIN"
