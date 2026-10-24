#!/bin/bash
# Re-sign the VoxBox FreePBX module (local signature, module.sig type=local).
# Run as root on the host that holds the signing key. The private key never
# leaves that host; only the two signed text files are written:
#   <module>/signatures/voxbox.local.sig  clearsigned SHA-256 list of every module file
#   <module>/module.sig                   clearsigned, holds the SHA-256 of voxbox.local.sig
# install/voxbox-local-signature.php later copies voxbox.local.sig to
# /etc/freepbx.secure/voxbox.sig. Rebuild mirror/voxbox.tgz after signing.
#
# Usage: sudo branding/sign-voxbox-module.sh [MODULE_DIR]
#   MODULE_DIR          default: <repo>/modules/voxbox
#   VOXBOX_SIGN_KEY     default: 55D46506ED591342
#   VOXBOX_GNUPGHOME    default: /etc/freepbx.secure/gnupg
# Copyright (C) 2007-2026 Binary Systems, Inc.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
MOD=$(cd "${1:-$HERE/../modules/voxbox}" && pwd)
KEY="${VOXBOX_SIGN_KEY:-55D46506ED591342}"
export GNUPGHOME="${VOXBOX_GNUPGHOME:-/etc/freepbx.secure/gnupg}"
SIGNEDBY="'Binary Systems, Inc. <modules@binary-systems.com>'"

[[ -f "$MOD/module.xml" ]] || { echo "ERROR: $MOD has no module.xml" >&2; exit 1; }
[[ -d "$GNUPGHOME" ]] || { echo "ERROR: GNUPGHOME $GNUPGHOME missing" >&2; exit 1; }
gpg --batch --list-secret-keys "$KEY" >/dev/null 2>&1 \
  || { echo "ERROR: secret key $KEY not available in $GNUPGHOME" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. File list: every regular file except the two signature outputs and dotfiles.
{
  printf '[config]\nversion=2\nhash=sha256\nsignedwith=%s\nsignedby=%s\nrepo=standard\n[hashes]\n' "$KEY" "$SIGNEDBY"
  (cd "$MOD" && find . -type f ! -name '.*' ! -path ./module.sig ! -path ./signatures/voxbox.local.sig -printf '%P\n' | LC_ALL=C sort) |
  while IFS= read -r f; do
    printf '%s = %s\n' "$f" "$(sha256sum "$MOD/$f" | cut -d' ' -f1)"
  done
} > "$tmp/local.txt"
gpg --batch --yes --local-user "$KEY" --digest-algo SHA256 --clearsign -o "$tmp/local.sig" "$tmp/local.txt"

# 2. module.sig: type=local, carries the hash of the local list.
lhash=$(sha256sum "$tmp/local.sig" | cut -d' ' -f1)
ts=$(date +%s.%N | cut -c1-15)
printf '[config]\nversion=2\nhash=sha256\ntype=local\nsignedwith=%s\nsignedby=%s\nrepo=standard\ntimestamp=%s\n[hashes]\nvoxbox.sig = %s\n' \
  "$KEY" "$SIGNEDBY" "$ts" "$lhash" > "$tmp/module.txt"
gpg --batch --yes --local-user "$KEY" --digest-algo SHA256 --clearsign -o "$tmp/module.sig" "$tmp/module.txt"

gpg --batch --verify "$tmp/local.sig" 2>/dev/null
gpg --batch --verify "$tmp/module.sig" 2>/dev/null

install -m 0644 "$tmp/local.sig" "$MOD/signatures/voxbox.local.sig"
install -m 0644 "$tmp/module.sig" "$MOD/module.sig"
echo "Signed $(grep -c ' = ' "$tmp/local.txt") files in $MOD with $KEY"
echo "voxbox.sig = $lhash"
