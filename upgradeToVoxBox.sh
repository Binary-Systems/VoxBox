#!/bin/bash
# upgradeToVoxBox.sh — bring an existing Asterisk / FreePBX / Incredible PBX
# host up to VoxBox 2026, or refresh a host that is already VoxBox.
#
# Order: back up the configuration, upgrade the OS to the current VoxBox
# requirements, restore that backup, then apply the latest VoxBox overlay.
# This does not run VoxBox2026.sh. It does not restore the stock demo
# backup, change the hostname, rewrite the firewall, or reset passwords.
#
# Copyright (C) 2007-2026, Binary Systems, Inc.
# Asterisk, FreePBX, and Incredible PBX remain under their own licenses.
#
# Usage (as root), from a checkout that also contains branding/ and protel/:
#   ./upgradeToVoxBox.sh
#
# Environment:
#   VOXBOX_FORCE_DIST_UPGRADE=1
#       On FreePBX 16 or older, also walk Debian forward to trixie.
#       Without this, those hosts only get package updates for the
#       release they are already on. Debian 13 removes the PHP those
#       older GUIs run on.
#   VOXBOX_SKIP_OS_UPGRADE=1
#       Skip apt/dnf. Backup, restore, and the VoxBox overlay still run.

set -u
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

LOG=/root/voxbox-upgrade-log.txt
STAMP=$(date -u +%Y%m%d-%H%M%S)
BACKUP_DIR=/var/backups/voxbox-upgrade/${STAMP}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MYSQL_CNF=""
AST_RUNNING=0
OS_FAMILY=""
OS_ID=""
OS_VERSION=""
OS_CODENAME=""
OS_MAJOR=0
ALREADY=0
FW_VERSION=""
FW_MAJOR=0

mkdir -p /root /var/lib/voxbox
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG") 2>&1

say() { printf '%s\n' "$*"; }
die() { say "ERROR: $*"; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
  die "Run upgradeToVoxBox.sh as root."
fi

if [ -z "${BASH_VERSION:-}" ]; then
  die "Run this script with bash."
fi

# ---------------------------------------------------------------------------
# Detect the host
# ---------------------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
  die "Cannot read /etc/os-release."
fi
# shellcheck disable=SC1091
. /etc/os-release
OS_ID=${ID:-unknown}
OS_VERSION=${VERSION_ID:-0}
OS_CODENAME=${VERSION_CODENAME:-}
OS_MAJOR=${OS_VERSION%%.*}
case "$OS_ID ${ID_LIKE:-}" in
  *debian*|*ubuntu*) OS_FAMILY=debian ;;
  *rhel*|*fedora*|*centos*|*rocky*|*almalinux*) OS_FAMILY=el ;;
  *) die "Unsupported OS ${OS_ID}. This upgrade supports Debian, Ubuntu, and RHEL-family hosts." ;;
esac

pbx=0
[ -f /etc/freepbx.conf ] && pbx=1
[ -x /usr/sbin/asterisk ] && pbx=1
[ -d /etc/asterisk ] && pbx=1
[ -d /etc/pbx ] && pbx=1
[ "$pbx" -eq 1 ] || die "No Asterisk, FreePBX, or Incredible PBX installation was found."

if [ -f /var/www/html/admin/voxbox.css ] || grep -q 'VoxBox' /etc/os-release 2>/dev/null; then
  ALREADY=1
fi

if [ -x /usr/sbin/fwconsole ]; then
  FW_VERSION=$(fwconsole ma list 2>/dev/null | awk -F'|' '/\|[[:space:]]*framework[[:space:]]*\|/ { gsub(/ /, "", $3); print $3; exit }')
fi
FW_MAJOR=${FW_VERSION%%.*}
case "$FW_MAJOR" in
  ''|*[!0-9]*) FW_MAJOR=0 ;;
esac

if pgrep -x asterisk >/dev/null 2>&1; then
  AST_RUNNING=1
fi

say "VoxBox upgrade ${STAMP}"
say "Host: ${PRETTY_NAME:-$OS_ID} (${OS_FAMILY}), FreePBX framework ${FW_VERSION:-none}"
if [ "$ALREADY" -eq 1 ]; then
  say "VoxBox is already installed. This run upgrades the OS and the VoxBox overlay."
else
  say "Converting this Asterisk/FreePBX/Incredible PBX host to VoxBox 2026."
fi
say "Asterisk was $([ "$AST_RUNNING" -eq 1 ] && echo running || echo stopped) at the start."

# ---------------------------------------------------------------------------
# MySQL
# ---------------------------------------------------------------------------

php_is_82() {
  php -r 'exit((PHP_MAJOR_VERSION==8 && PHP_MINOR_VERSION==2) ? 0 : 1);' 2>/dev/null
}

write_mysql_cnf() {
  local dest=$1
  MYSQL_CNF=$dest
  umask 077
  # Debian MariaDB accepts root on the local socket. Prefer that so the
  # backup does not store a copy of the FreePBX database password.
  if mysql --protocol=socket -u root -N -e 'SELECT 1' >/dev/null 2>&1; then
    # Do not set database= here. mysqldump treats that key as --databases
    # and then ignores the real --databases list on the command line.
    printf '[client]\nuser=root\nprotocol=socket\n' > "$dest"
    chmod 600 "$dest"
    return 0
  fi
  local parser=${BACKUP_DIR}/read-ampdb.php
  cat > "$parser" << 'PHP'
<?php
$src = @file_get_contents('/etc/freepbx.conf');
if ($src === false) {
    exit(1);
}
function amp($src, $key) {
    $k = preg_quote($key, '/');
    $patterns = array(
        "/\\['$k'\\]\\s*=\\s*'((?:\\\\'|[^'])*)'/",
        "/\\[\"$k\"\\]\\s*=\\s*\"((?:\\\\\"|[^\"])*)\"/",
    );
    foreach ($patterns as $i => $re) {
        if (preg_match($re, $src, $m)) {
            if ($i === 0) {
                return str_replace("\\'", "'", $m[1]);
            }
            return stripcslashes($m[1]);
        }
    }
    return '';
}
foreach (array('AMPDBHOST', 'AMPDBUSER', 'AMPDBPASS', 'AMPDBNAME') as $key) {
    echo amp($src, $key), "\n";
}
PHP
  php "$parser" > "${dest}.raw" 2>/dev/null || true
  rm -f "$parser"
  local host user pass name
  host=$(sed -n '1p' "${dest}.raw")
  user=$(sed -n '2p' "${dest}.raw")
  pass=$(sed -n '3p' "${dest}.raw")
  name=$(sed -n '4p' "${dest}.raw")
  rm -f "${dest}.raw"
  [ -n "$user" ] || return 1
  [ -n "$host" ] || host=localhost
  [ -n "$name" ] || name=asterisk
  {
    printf '[client]\n'
    printf 'host=%s\n' "$host"
    printf 'user=%s\n' "$user"
    printf 'password=%s\n' "$pass"
  } > "$dest"
  chmod 600 "$dest"
  mysql --defaults-extra-file="$dest" -N -e 'SELECT 1' >/dev/null 2>&1
}

mysql_q() {
  mysql --defaults-extra-file="$MYSQL_CNF" asterisk -N -e "$1"
}

# ---------------------------------------------------------------------------
# Asterisk process
# ---------------------------------------------------------------------------

halt_asterisk() {
  # Stop the respawner before Asterisk, or it starts the PBX again immediately.
  if pgrep -f '/usr/sbin/safe_asterisk' >/dev/null 2>&1; then
    pkill -TERM -f '/usr/sbin/safe_asterisk' >/dev/null 2>&1 || true
    sleep 1
  fi
  if [ -x /usr/sbin/asterisk ] && pgrep -x asterisk >/dev/null 2>&1; then
    /usr/sbin/asterisk -rx "core stop now" >/dev/null 2>&1 || true
    sleep 2
  fi
  if pgrep -x asterisk >/dev/null 2>&1; then
    pkill -TERM -x asterisk >/dev/null 2>&1 || true
    sleep 2
  fi
  if pgrep -f '/usr/sbin/safe_asterisk' >/dev/null 2>&1; then
    pkill -KILL -f '/usr/sbin/safe_asterisk' >/dev/null 2>&1 || true
  fi
}

stop_pbx() {
  [ "$AST_RUNNING" -eq 1 ] || return 0
  halt_asterisk
}

start_pbx() {
  [ "$AST_RUNNING" -eq 1 ] || return 0
  if pgrep -x asterisk >/dev/null 2>&1; then
    return 0
  fi
  if [ -x /usr/sbin/fwconsole ]; then
    fwconsole start || true
  fi
  if ! pgrep -x asterisk >/dev/null 2>&1 && [ -x /etc/init.d/asterisk ]; then
    /etc/init.d/asterisk start || true
  fi
  if ! pgrep -x asterisk >/dev/null 2>&1 && [ -x /usr/sbin/safe_asterisk ]; then
    /usr/sbin/safe_asterisk -U asterisk -G asterisk >/dev/null 2>&1 &
    sleep 2
  fi
  if pgrep -x asterisk >/dev/null 2>&1; then
    say "Asterisk is running again."
  else
    say "WARN: Asterisk was running before the upgrade and did not come back."
  fi
}

# ---------------------------------------------------------------------------
# Backup and restore
# ---------------------------------------------------------------------------

count_or_na() {
  local sql=$1
  local out
  out=$(mysql_q "$sql" 2>/dev/null || true)
  if [ -z "$out" ]; then
    printf 'NA\n'
  else
    printf '%s\n' "$out"
  fi
}

write_fingerprint() {
  local dest=$1
  {
    printf 'users=%s\n' "$(count_or_na 'SELECT COUNT(*) FROM users')"
    printf 'trunks=%s\n' "$(count_or_na 'SELECT COUNT(*) FROM trunks')"
    printf 'incoming=%s\n' "$(count_or_na 'SELECT COUNT(*) FROM incoming')"
  } > "$dest"
  mysql_q 'SELECT extension FROM users ORDER BY extension' > "${dest}.extensions" 2>/dev/null || : > "${dest}.extensions"
  chmod 600 "$dest" "${dest}.extensions"
}

fingerprint_matches() {
  local saved=$1 now=$2
  local line key sval nval
  [ -f "$saved" ] && [ -f "$now" ] || return 1
  while IFS= read -r line; do
    key=${line%%=*}
    sval=${line#*=}
    nval=$(awk -F= -v k="$key" '$1==k {print substr($0, index($0,"=")+1)}' "$now")
    [ "$sval" = "NA" ] && continue
    if [ "$sval" != "$nval" ]; then
      say "Configuration mismatch: ${key} was ${sval} and is now ${nval:-empty}."
      return 1
    fi
  done < "$saved"
  if [ -s "${saved}.extensions" ] && ! cmp -s "${saved}.extensions" "${now}.extensions"; then
    say "Configuration mismatch: the extension list changed."
    return 1
  fi
  return 0
}

backup_all() {
  say "Backing up configuration to ${BACKUP_DIR}"
  install -d -m 700 "$BACKUP_DIR"
  write_mysql_cnf "${BACKUP_DIR}/mysql.cnf" || die "Cannot log in to MySQL. Refusing to upgrade without a backup."
  write_fingerprint "${BACKUP_DIR}/fingerprint"
  say "Saved fingerprint: $(tr '\n' ' ' < "${BACKUP_DIR}/fingerprint")"
  if [ -f /etc/freepbx.conf ] && grep -q '^users=NA$' "${BACKUP_DIR}/fingerprint"; then
    die "Could not read the FreePBX users table. Refusing to upgrade without that count."
  fi

  local dbs=(asterisk)
  if mysql_q "SHOW DATABASES LIKE 'asteriskcdrdb'" 2>/dev/null | grep -q asteriskcdrdb; then
    dbs+=(asteriskcdrdb)
  fi
  mysqldump --defaults-extra-file="$MYSQL_CNF" \
    --single-transaction --routines --triggers \
    --default-character-set=utf8mb4 \
    --databases "${dbs[@]}" > "${BACKUP_DIR}/databases.sql"
  chmod 600 "${BACKUP_DIR}/databases.sql"
  [ -s "${BACKUP_DIR}/databases.sql" ] || die "Database dump is empty."

  if [ -f /var/lib/asterisk/astdb.sqlite3 ]; then
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 /var/lib/asterisk/astdb.sqlite3 ".backup '${BACKUP_DIR}/astdb.sqlite3'" \
        || cp -a /var/lib/asterisk/astdb.sqlite3 "${BACKUP_DIR}/astdb.sqlite3"
    else
      cp -a /var/lib/asterisk/astdb.sqlite3 "${BACKUP_DIR}/astdb.sqlite3"
    fi
    chmod 600 "${BACKUP_DIR}/astdb.sqlite3" 2>/dev/null || true
  fi

  local paths=()
  local p
  for p in \
    etc/freepbx.conf etc/amportal.conf etc/asterisk etc/pbx \
    etc/apache2/sites-available etc/apache2/sites-enabled \
    etc/httpd/conf etc/httpd/conf.d \
    tftpboot var/lib/asterisk/agi-bin var/lib/asterisk/sounds/custom var/lib/asterisk/moh
  do
    [ -e "/$p" ] && paths+=("$p")
  done
  tar -C / -czf "${BACKUP_DIR}/configs.tgz" "${paths[@]}" || die "Could not archive configuration files."
  chmod 600 "${BACKUP_DIR}/configs.tgz"
  {
    echo "stamp=${STAMP}"
    echo "os=${PRETTY_NAME:-$OS_ID}"
    echo "framework=${FW_VERSION:-none}"
    echo "php=$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo missing)"
    echo "asterisk=$(/usr/sbin/asterisk -V 2>/dev/null | head -1 || echo missing)"
    echo "asterisk_was_running=${AST_RUNNING}"
  } > "${BACKUP_DIR}/manifest"
  chmod 600 "${BACKUP_DIR}/manifest"
  ln -sfn "$BACKUP_DIR" /var/backups/voxbox-upgrade/latest
  say "Backup complete."
}

restore_configs() {
  say "Restoring configuration from ${BACKUP_DIR}"
  [ -s "${BACKUP_DIR}/databases.sql" ] || die "Backup ${BACKUP_DIR} has no database dump."
  stop_pbx
  mysql --defaults-extra-file="$MYSQL_CNF" < "${BACKUP_DIR}/databases.sql" \
    || die "Database restore failed. Backup kept at ${BACKUP_DIR}."
  tar -C / -xzf "${BACKUP_DIR}/configs.tgz" \
    || die "File restore failed. Backup kept at ${BACKUP_DIR}."
  if [ -f "${BACKUP_DIR}/astdb.sqlite3" ]; then
    if id asterisk >/dev/null 2>&1; then
      install -o asterisk -g asterisk -m 644 "${BACKUP_DIR}/astdb.sqlite3" /var/lib/asterisk/astdb.sqlite3
    else
      install -m 644 "${BACKUP_DIR}/astdb.sqlite3" /var/lib/asterisk/astdb.sqlite3
    fi
  fi
  if id asterisk >/dev/null 2>&1; then
    chown -R asterisk:asterisk /etc/asterisk /tftpboot /var/lib/asterisk/agi-bin 2>/dev/null || true
  fi
  start_pbx
  say "Restore finished."
}

verify_restored() {
  local now=${BACKUP_DIR}/fingerprint.now
  write_fingerprint "$now"
  if fingerprint_matches "${BACKUP_DIR}/fingerprint" "$now"; then
    say "Configuration matches the backup ($(tr '\n' ' ' < "$now"))."
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# OS upgrade
# ---------------------------------------------------------------------------

apt_upgrade_release() {
  apt-get update -y || say "WARN: apt-get update reported errors. Continuing."
  apt-get -y \
    -o Dpkg::Options::=--force-confold \
    -o Dpkg::Options::=--force-confdef \
    upgrade \
    || say "WARN: apt-get upgrade reported errors. Continuing."
}

advance_debian_codename() {
  local old=$1 new=$2 f
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
    [ -f "$f" ] || continue
    if grep -qE 'deb\.debian\.org|security\.debian\.org|packages\.sury\.org' "$f"; then
      sed -i "s/${old}/${new}/g" "$f"
      say "Updated ${f}: ${old} -> ${new}"
    fi
  done
}

debian_next() {
  case "$1" in
    buster) echo bullseye ;;
    bullseye) echo bookworm ;;
    bookworm) echo trixie ;;
    *) echo "" ;;
  esac
}

upgrade_debian_os() {
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" = "ubuntu" ]; then
    say "Ubuntu stays on ${VERSION_ID}. Updating packages in place. VoxBox 2026's Debian base is Debian 13."
    apt_upgrade_release
    return 0
  fi
  local major=${VERSION_ID%%.*}
  if [ "$major" -ge 13 ]; then
    say "Debian ${VERSION_ID} already meets the VoxBox 2026 OS requirement. Updating packages."
    apt_upgrade_release
    return 0
  fi
  if [ "$FW_MAJOR" -lt 17 ] && [ "${VOXBOX_FORCE_DIST_UPGRADE:-0}" != "1" ]; then
    say "FreePBX ${FW_VERSION:-unknown} stays on Debian ${VERSION_ID}."
    say "Debian 13 does not ship the PHP release this GUI uses. Package update only."
    say "Set VOXBOX_FORCE_DIST_UPGRADE=1 to walk the OS forward anyway. The backup is ${BACKUP_DIR}."
    apt_upgrade_release
    return 0
  fi
  local guard=0
  while [ "$major" -lt 13 ]; do
    guard=$((guard + 1))
    [ "$guard" -le 4 ] || die "Debian release walk did not reach 13."
    # shellcheck disable=SC1091
    . /etc/os-release
    local next
    next=$(debian_next "${VERSION_CODENAME:-}")
    [ -n "$next" ] || die "No Debian upgrade path from ${VERSION_CODENAME:-unknown}."
    say "Upgrading Debian ${VERSION_CODENAME} to ${next}."
    advance_debian_codename "$VERSION_CODENAME" "$next"
    apt-get update -y || die "apt-get update failed after the ${next} source change."
    apt-get -y \
      -o Dpkg::Options::=--force-confold \
      -o Dpkg::Options::=--force-confdef \
      full-upgrade \
      || die "Debian upgrade to ${next} failed. Backup is ${BACKUP_DIR}."
    if [ -f /var/run/reboot-required ]; then
      say "Debian ${next} is installed and a reboot is required before another release step."
      say "Reboot, then run upgradeToVoxBox.sh again. Backup: ${BACKUP_DIR}"
      exit 0
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    major=${VERSION_ID%%.*}
  done
  say "Debian is now ${VERSION_ID}."
}

upgrade_el_os() {
  if [ "$OS_MAJOR" -lt 8 ]; then
    die "EL ${OS_VERSION} cannot take the VoxBox 2026 package set. Backup is ${BACKUP_DIR}. Rebuild on EL 8 or newer, or on Debian 13, and restore this backup there."
  fi
  if ! command -v dnf >/dev/null 2>&1; then
    die "dnf is not installed. Backup is ${BACKUP_DIR}."
  fi
  say "Updating ${OS_ID} ${OS_VERSION} packages. Firewall and SELinux settings are left as they are."
  dnf -y upgrade || say "WARN: dnf upgrade reported errors. Continuing."
}

ensure_php82() {
  if php_is_82; then
    say "PHP $(php -r 'echo PHP_VERSION;') is the VoxBox 8.2 line."
    if [ "$OS_FAMILY" = "debian" ] && [ -x /usr/bin/php8.2 ]; then
      update-alternatives --set php /usr/bin/php8.2 >/dev/null 2>&1 || true
    fi
    return 0
  fi
  say "Installing PHP 8.2. FreePBX 17 needs that release."
  if [ "$OS_FAMILY" = "debian" ]; then
    apt-get install -y ca-certificates curl gnupg || true
    if [ ! -f /usr/share/keyrings/deb.sury.org-php.gpg ]; then
      curl -fsSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg \
        || die "Could not download the PHP repository key."
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    local arch
    arch=$(dpkg --print-architecture)
    cat > /etc/apt/sources.list.d/php.sources << EOF
Types: deb
URIs: https://packages.sury.org/php/
Suites: ${VERSION_CODENAME}
Components: main
Architectures: ${arch}
Signed-By: /usr/share/keyrings/deb.sury.org-php.gpg
EOF
    apt-get update -y || true
    apt-get install -y php8.2 php8.2-cli php8.2-common php8.2-fpm \
      php8.2-curl php8.2-mysql php8.2-gd php8.2-mbstring php8.2-xml \
      php8.2-zip php8.2-intl php8.2-bcmath php8.2-opcache php8.2-soap \
      || die "PHP 8.2 packages failed to install."
    update-alternatives --set php /usr/bin/php8.2 >/dev/null 2>&1 || true
    if command -v a2enmod >/dev/null 2>&1 && [ -d /etc/apache2 ]; then
      a2enmod proxy_fcgi setenvif >/dev/null 2>&1 || true
      a2enconf php8.2-fpm >/dev/null 2>&1 || true
      systemctl enable --now php8.2-fpm >/dev/null 2>&1 || true
    fi
  else
    # shellcheck disable=SC1091
    . /etc/os-release
    local el_major=${VERSION_ID%%.*}
    if [ "${ID:-}" = "fedora" ]; then
      dnf -y install "https://rpms.remirepo.net/fedora/remi-release-${el_major}.noarch.rpm" || true
      dnf -y module reset php || true
      dnf -y module enable php:remi-8.2 || true
    elif [ "$el_major" = "9" ]; then
      dnf -y module reset php || true
      dnf -y module enable php:8.2 \
        || dnf -y install "https://rpms.remirepo.net/enterprise/remi-release-${el_major}.rpm" \
        || true
      dnf -y module enable php:remi-8.2 || true
    else
      dnf -y install "https://rpms.remirepo.net/enterprise/remi-release-${el_major}.rpm" || true
      dnf -y module reset php || true
      dnf -y module enable php:remi-8.2 || dnf -y module enable php:8.2 || true
    fi
    dnf -y install php php-cli php-common php-fpm php-mysqlnd php-gd php-mbstring \
      php-xml php-intl php-bcmath php-opcache php-soap php-process php-pear php-zip php-curl \
      || true
    if ! php_is_82 && [ -x /opt/remi/php82/root/usr/bin/php ]; then
      ln -sfn /opt/remi/php82/root/usr/bin/php /usr/bin/php
    fi
  fi
  php_is_82 || die "PHP 8.2 is not the active php binary. Backup is ${BACKUP_DIR}."
  say "PHP $(php -r 'echo PHP_VERSION;') is now active."
}

upgrade_os() {
  if [ "${VOXBOX_SKIP_OS_UPGRADE:-0}" = "1" ]; then
    say "VOXBOX_SKIP_OS_UPGRADE=1, so package updates were skipped."
    return 0
  fi
  if [ "$OS_FAMILY" = "debian" ]; then
    upgrade_debian_os
  else
    upgrade_el_os
  fi
  ensure_php82
  if [ -f /var/run/reboot-required ]; then
    say "The OS asked for a reboot. Finish this upgrade first. Reboot when you can."
  fi
}

# ---------------------------------------------------------------------------
# Latest VoxBox overlay (does not replace customer trunks, routes, or users)
# ---------------------------------------------------------------------------

find_payload() {
  local name=$1 c
  for c in \
    "${SCRIPT_DIR}/mirror/${name}" \
    "/opt/voxbox/mirror/${name}" \
    "/root/VoxBox/mirror/${name}" \
    "$(pwd)/mirror/${name}"
  do
    if [ -f "$c" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

install_endpointman() {
  [ "$FW_MAJOR" -ge 17 ] || {
    say "Endpoint Manager 17 stays uninstalled. FreePBX ${FW_VERSION:-unknown} is older than 17."
    return 0
  }
  [ -x /usr/sbin/fwconsole ] || {
    say "WARN: fwconsole is missing. Skipping Endpoint Manager."
    return 0
  }
  local epm ossepm tmp src found sig
  epm=$(find_payload voxbox-endpointman.tgz || true)
  if [ -z "$epm" ]; then
    epm=/tmp/voxbox-endpointman.tgz
    rm -f "$epm"
    say "Downloading VoxBox Endpoint Manager."
    wget -O "$epm" --timeout=30 --tries=2 \
      "https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/voxbox-endpointman.tgz" \
      || rm -f "$epm"
  fi
  if [ ! -s "${epm:-}" ]; then
    say "WARN: VoxBox Endpoint Manager package was not found."
    return 0
  fi
  tmp=$(mktemp -d /tmp/voxbox-epm.XXXXXX)
  tar -C "$tmp" -xzf "$epm"
  src=""
  if [ -f "$tmp/endpointman/module.xml" ]; then
    src=$tmp/endpointman
  elif [ -f "$tmp/module.xml" ]; then
    src=$tmp
  else
    found=$(find "$tmp" -name module.xml -print -quit || true)
    [ -n "$found" ] && src=$(dirname "$found")
  fi
  if [ -z "$src" ] || [ ! -f "$src/module.xml" ]; then
    say "WARN: module.xml was not in the Endpoint Manager package."
    rm -rf "$tmp"
    return 0
  fi
  rm -rf /var/www/html/admin/modules/endpointman
  mv "$src" /var/www/html/admin/modules/endpointman
  rm -rf "$tmp"
  ossepm=$(find_payload ossepm16.tgz || true)
  if [ -n "$ossepm" ]; then
    tmp=$(mktemp -d /tmp/ossepm16.XXXXXX)
    if tar -C "$tmp" -xzf "$ossepm" _ep_phone_modules; then
      mkdir -p /var/www/html/admin/modules/_ep_phone_modules
      cp -a "$tmp/_ep_phone_modules/." /var/www/html/admin/modules/_ep_phone_modules/
    else
      say "WARN: could not read phone templates from ${ossepm}."
    fi
    rm -rf "$tmp"
  else
    say "WARN: ossepm16.tgz was not found. Existing phone templates were left in place."
  fi
  sig=$(fwconsole setting SIGNATURECHECK 2>/dev/null | sed -n 's/.*\[\(.*\)\].*/\1/p' | head -1)
  fwconsole setting SIGNATURECHECK 0 || true
  fwconsole ma install endpointman || say "WARN: fwconsole ma install endpointman reported errors."
  fwconsole setting SIGNATURECHECK "${sig:-1}" || true
  if [ -f /var/www/html/admin/modules/endpointman/install/voxbox-provisioner.php ]; then
    # The provisioner can print SIP account material. Keep that off this log.
    install -d -m 700 "${BACKUP_DIR}"
    php /var/www/html/admin/modules/endpointman/install/voxbox-provisioner.php \
      > "${BACKUP_DIR}/provisioner.out" 2> "${BACKUP_DIR}/provisioner.err" \
      || say "WARN: Endpoint Manager provisioner returned an error. See ${BACKUP_DIR}/provisioner.err."
    chmod 600 "${BACKUP_DIR}/provisioner.out" "${BACKUP_DIR}/provisioner.err" 2>/dev/null || true
  fi
  chown -R asterisk:asterisk /var/www/html/admin/modules/endpointman /var/www/html/admin/modules/_ep_phone_modules 2>/dev/null || true
  if [ -d /tftpboot ] && [ -d /var/www/html/admin/modules/_ep_phone_modules ] \
      && [ ! -e /var/www/html/admin/modules/_ep_phone_modules/tftpboot ]; then
    ln -sfn /tftpboot /var/www/html/admin/modules/_ep_phone_modules/tftpboot
  fi
  say "Endpoint Manager files are in place."
}

ensure_tftp() {
  if [ "$OS_FAMILY" = "debian" ]; then
    if ! dpkg -s tftpd-hpa >/dev/null 2>&1; then
      apt-get install -y tftpd-hpa || say "WARN: tftpd-hpa did not install."
    fi
    mkdir -p /tftpboot
    if [ ! -f /etc/default/tftpd-hpa ]; then
      cat > /etc/default/tftpd-hpa << 'EOF'
TFTP_USERNAME="asterisk"
TFTP_DIRECTORY="/tftpboot"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
EOF
      systemctl enable --now tftpd-hpa || true
    fi
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install tftp-server >/dev/null 2>&1 || true
    mkdir -p /tftpboot
  fi
  if id asterisk >/dev/null 2>&1 && [ -d /tftpboot ]; then
    chown asterisk:asterisk /tftpboot
    chmod 775 /tftpboot
  fi
}

apply_voxbox() {
  say "Applying the latest VoxBox overlay."
  if [ "$OS_FAMILY" = "debian" ]; then
    apt-get install -y emacs-nox wget ca-certificates || say "WARN: emacs-nox install reported errors."
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install emacs-nox wget ca-certificates tar || say "WARN: emacs-nox install reported errors."
  fi
  if [ -x "${SCRIPT_DIR}/protel/install-protel.sh" ]; then
    bash "${SCRIPT_DIR}/protel/install-protel.sh" || say "WARN: PROTEL install failed. The PBX upgrade continues."
  else
    say "WARN: protel/install-protel.sh was not next to this script."
  fi
  ensure_tftp
  # Install Endpoint Manager before branding so the branding step can enable it.
  install_endpointman
  if [ -f /var/www/html/admin/modules/framework/module.xml ] && [ -x "${SCRIPT_DIR}/branding/apply-voxbox-branding.sh" ]; then
    bash "${SCRIPT_DIR}/branding/apply-voxbox-branding.sh" || say "WARN: branding apply reported errors."
  else
    say "WARN: branding/apply-voxbox-branding.sh or the FreePBX admin tree is missing."
  fi
  if [ -x /usr/sbin/fwconsole ] && [ "$FW_MAJOR" -ge 17 ]; then
    fwconsole ma upgradeall || say "WARN: fwconsole ma upgradeall reported errors."
    fwconsole chown || true
    # Upgrade can replace dashboard and UCP. Put the signed trees back after it.
    # chown runs first so it does not take the root-owned signature files.
    if [ -f "${SCRIPT_DIR}/branding/install-signed-modules.sh" ]; then
      bash "${SCRIPT_DIR}/branding/install-signed-modules.sh" || say "WARN: signed VoxBox modules were not fully installed."
    fi
    fwconsole reload || say "WARN: fwconsole reload reported errors."
  fi
  date -u +%Y-%m-%dT%H:%M:%SZ > /var/lib/voxbox/upgraded
  chmod 644 /var/lib/voxbox/upgraded
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

cleanup() {
  if [ "${AST_RUNNING:-0}" -eq 1 ] && ! pgrep -x asterisk >/dev/null 2>&1; then
    start_pbx || true
  fi
}
trap cleanup EXIT

backup_all
upgrade_os
restore_configs
if ! verify_restored; then
  say "ERROR: The restored configuration does not match the backup. VoxBox was not applied."
  say "Backup kept at ${BACKUP_DIR}"
  start_pbx
  exit 1
fi
apply_voxbox
# Phone files in /tftpboot belong to the customer. Put that tree back if the
# overlay regenerated it, then reload once more so Asterisk matches the database.
if [ -d /tftpboot ] && tar -tzf "${BACKUP_DIR}/configs.tgz" tftpboot >/dev/null 2>&1; then
  tar -C / -xzf "${BACKUP_DIR}/configs.tgz" tftpboot
  chown -R asterisk:asterisk /tftpboot 2>/dev/null || true
fi
if [ "$AST_RUNNING" -eq 1 ]; then
  start_pbx
else
  if pgrep -x asterisk >/dev/null 2>&1; then
    halt_asterisk
  fi
fi
if ! verify_restored; then
  say "ERROR: Extension, trunk, or inbound counts changed while VoxBox was applied."
  say "Restoring the backup again. Backup: ${BACKUP_DIR}"
  restore_configs
  exit 1
fi
say "Done. Backup kept at ${BACKUP_DIR}"
say "Log: ${LOG}"
if [ -f /var/run/reboot-required ]; then
  say "A reboot is required to finish the OS package update."
fi
