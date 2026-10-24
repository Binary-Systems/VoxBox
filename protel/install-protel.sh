#!/bin/bash
# Install latest PROTEL 2026 toolchain (Pc, Pb, Pc!) + Emacs protel-mode on VoxBox.
# Source: https://github.com/vincente666/PROTEL
set -euo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

PROTEL_REPO=${PROTEL_REPO:-https://github.com/vincente666/PROTEL.git}
PROTEL_REF=${PROTEL_REF:-main}
PROTEL_SRC=${PROTEL_SRC:-/usr/src/PROTEL}
SYSPREFIX=${SYSPREFIX:-/usr/local/protel}

echo "VoxBox: installing latest PROTEL from ${PROTEL_REPO} (${PROTEL_REF})"

# Build/runtime deps for Pc/Pb and install-system.
# Debian uses apt. Rocky, Fedora, RHEL, and derivatives use dnf.
if command -v apt-get >/dev/null 2>&1; then
  # A broken third-party source (for example an old Webmin list) must not
  # abort the toolchain install. Debian's own lists are enough for these packages.
  apt-get update -qq || echo "WARN: apt-get update reported errors; continuing" >&2
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git make python3 python3-venv python3-pip \
    g++ gcc build-essential \
    emacs-nox
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install \
    git make python3 python3-pip python3-setuptools \
    gcc gcc-c++ \
    emacs-nox
else
  echo "WARN: neither apt-get nor dnf is available; cannot install PROTEL build tools" >&2
  exit 1
fi

# Fresh shallow clone of latest requested ref
rm -rf "$PROTEL_SRC"
git clone --depth 1 --branch "$PROTEL_REF" "$PROTEL_REPO" "$PROTEL_SRC"
cd "$PROTEL_SRC"

make install-system SYSPREFIX="$SYSPREFIX"

# install-system creates a root-owned tree. Other accounts must be able to
# read the toolkit and re-exec into its virtualenv. Pc also writes generated
# C++ under $SYSPREFIX/build and cannot create that directory when the prefix
# is not writable, so create it sticky and world-writable (same idea as /tmp).
chmod -R a+rX "$SYSPREFIX"
mkdir -p "$SYSPREFIX/build"
chmod 1777 "$SYSPREFIX/build"

# --- Emacs protel-mode (site-wide for emacs-nox) ---
SITE_LISP=/usr/local/share/emacs/site-lisp
SITE_START_D=/etc/emacs/site-start.d
mkdir -p "$SITE_LISP" "$SITE_START_D"
install -m 644 "$PROTEL_SRC/emacs/protel-mode.el" "$SITE_LISP/protel-mode.el"
# Also keep a copy next to the toolkit (install-system already copies emacs/)
if [ -d "$SYSPREFIX/emacs" ]; then
  install -m 644 "$PROTEL_SRC/emacs/protel-mode.el" "$SYSPREFIX/emacs/protel-mode.el"
fi

cat > "$SITE_START_D/50protel-mode.el" << ELS
;;; VoxBox site-start: PROTEL 2026 Emacs mode
(add-to-list 'load-path "$SITE_LISP")
(setq protel-root "$SYSPREFIX")
(require 'protel-mode)
ELS
chmod 644 "$SITE_START_D/50protel-mode.el" "$SITE_LISP/protel-mode.el"

# /usr/local/bin is already on the default login path and on sudo's secure_path.
if ! command -v Pc >/dev/null 2>&1 || ! command -v Pb >/dev/null 2>&1 || ! command -v Pc! >/dev/null 2>&1; then
  echo "WARN: Pc, Pb, or Pc! not on PATH after install-system" >&2
  exit 1
fi
Pc --version
Pb --version
echo "PROTEL installed: Pc/Pb/Pc! -> $SYSPREFIX (symlinks in /usr/local/bin)"

# Prove a non-root shell can compile when one exists. A fresh VoxBox install
# runs this before the asterisk account is created, so a missing user is fine.
smoke_user=""
if id voxbox >/dev/null 2>&1; then
  smoke_user=voxbox
fi
if [ -z "$smoke_user" ]; then
  while IFS=: read -r name _ uid _ _ _ shell; do
    [ "$uid" -ge 1000 ] || continue
    case "$shell" in
      */nologin|*/false|"") continue ;;
    esac
    smoke_user=$name
    break
  done < /etc/passwd
fi
if [ -n "$smoke_user" ]; then
  echo "PROTEL smoke test as ${smoke_user}"
  runuser -u "$smoke_user" -- Pc --version
  runuser -u "$smoke_user" -- Pb --version
  smoke_dir=$(mktemp -d /tmp/protel-smoke.XXXXXX)
  chown "$smoke_user" "$smoke_dir"
  chmod 755 "$smoke_dir"
  runuser -u "$smoke_user" -- Pc "$SYSPREFIX/examples/Hello.P" -o "$smoke_dir/Hello" --run
  rm -rf "$smoke_dir"
  rm -f "$SYSPREFIX/build/Hello.cpp" "$SYSPREFIX/build/Hello.o"
fi

if command -v emacs >/dev/null 2>&1; then
  emacs --batch --eval '(unless (featurep '\''protel-mode) (kill-emacs 1))'
fi
echo "Emacs protel-mode: $SITE_LISP/protel-mode.el (+ $SITE_START_D/50protel-mode.el)"
echo "Shared build directory: $SYSPREFIX/build (mode 1777)"
echo "Done."
