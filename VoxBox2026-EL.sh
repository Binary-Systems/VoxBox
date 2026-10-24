#!/bin/bash
# VoxBox 2026 installer for Rocky, Fedora, RHEL, and derivatives — Binary Systems, Inc.
# Copyright (C) 2007-2026, Binary Systems, Inc.
# Installer lineage includes work Copyright (C) 2005-2025, Ward Mundy & Associates LLC.
# VoxBox rebrand and packaging Copyright (C) 2007-2025 Binary Systems, Inc.
# This program installs Asterisk, FreePBX GUI, and VoxBox utilities.
# All programs copyrighted and licensed by their respective companies.
#
# REQUIRED BASE: a minimal Rocky, AlmaLinux, RHEL, CentOS Stream, Oracle Linux,
# Fedora, or other RHEL-family system, with a root password and SSH.
# Do not start from a desktop image. amd64 is the published architecture.
# Raspberry Pi boards use VoxBox2026-RasPi.sh.
#
# EL habits follow the Incredible PBX Rocky / AlmaLinux installer:
#   dnf, EPEL, CRB (EL9+) or PowerTools (EL8), PHP 8.2 from AppStream or Remi,
#   SELinux disabled, firewalld replaced by iptables-services.
# The telephony stack matches VoxBox2026.sh: Asterisk 22 or 23, FreePBX 17, PHP 8.2.
#
# Portions Copyright (C) 1999-2022, Digium, Inc.
# Portions Copyright (C) 2005-2025, Sangoma Technologies, Inc.
# Portions Copyright (C) 2005-2025, Ward Mundy & Associates LLC
# Portions Copyright (C) 2014-2016, Eric Teeter teetere@charter.net
# Portions Copyright (C) 2020-2025, Joe McConnaughey, @kenn10
# Portions Copyright (C) 2007-2025, Binary Systems, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
# After install, licenses can be found at /var/www/html/admin/licenses.
#

if [ "$(id -u)" -ne 0 ]; then
  echo "Run VoxBox2026-EL.sh as root."
  exit 1
fi

if [ ! -f /etc/os-release ]; then
  echo "Cannot read /etc/os-release. This installer is for Rocky, Fedora, RHEL, and derivatives."
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
EL_FAMILY=0
case "${ID:-}" in
  rocky|almalinux|rhel|centos|fedora|ol|eurolinux|miraclelinux) EL_FAMILY=1 ;;
esac
case "${ID_LIKE:-}" in
  *rhel*|*fedora*|*centos*) EL_FAMILY=1 ;;
esac
if [ "$EL_FAMILY" -ne 1 ]; then
  echo "VoxBox2026-EL.sh installs on Rocky, AlmaLinux, RHEL, CentOS Stream, Oracle Linux, Fedora, and other RHEL derivatives."
  echo "This host reports ID=${ID:-unknown} ID_LIKE=${ID_LIKE:-}."
  echo "For Debian 13, run VoxBox2026.sh."
  exit 1
fi

EL_MAJOR="${VERSION_ID%%.*}"
ARCH="$(uname -m)"
version="2026-EL"
PHP_INI=/etc/php.ini
PHP_FPM_POOL=/etc/php-fpm.d/www.conf
PHP_FPM_SERVICE=php-fpm
PHP_FPM_SOCK=/run/php-fpm/www.sock

exec > >(tee -i /root/voxbox-install-log.txt)
exec 2>&1

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
export PATH

# Resolve installer location so branding/ and ossepm16.tgz can be found when run from repo root,
# the same directory as this script, or a common /root/VoxBox checkout.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Payloads are stored in mirror/. Remote lookup tries GitHub first
# (https://github.com/Binary-Systems/VoxBox), then the Gitea mirror.
# Set VOXBOX_MIRROR_BASE to force one remote and skip the fallback.
VOXBOX_MIRROR_GITHUB="${VOXBOX_MIRROR_GITHUB:-https://github.com/Binary-Systems/VoxBox/raw/main/mirror}"
VOXBOX_MIRROR_GITEA="${VOXBOX_MIRROR_GITEA:-https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror}"
voxbox_fetch() {
  local name="$1"
  local dest="${2:-$name}"
  local src="" candidate
  for candidate in \
      "${SCRIPT_DIR:-}/mirror/${name}" \
      "/opt/voxbox/mirror/${name}" \
      "/root/VoxBox/mirror/${name}" \
      "$(pwd)/mirror/${name}"
  do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      src="$candidate"
      break
    fi
  done
  if [ -n "$src" ]; then
    if [ "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")" != "$(pwd)/$(basename "$dest")" ]; then
      cp -f "$src" "$dest"
    fi
    return 0
  fi
  local enc="${name//+/%2B}"
  local bases=() base url headbytes
  if [ -n "${VOXBOX_MIRROR_BASE:-}" ]; then
    bases=("${VOXBOX_MIRROR_BASE}")
  else
    bases=("${VOXBOX_MIRROR_GITHUB}" "${VOXBOX_MIRROR_GITEA}")
  fi
  for base in "${bases[@]}"; do
    url="${base}/${enc}"
    echo "Fetching ${name} from ${url}"
    rm -f "$dest"
    if [ -n "${VOXBOX_GIT_TOKEN:-}" ] && [[ "$url" == *gitea.binary-systems.com* ]]; then
      wget --header="Authorization: token ${VOXBOX_GIT_TOKEN}" -O "$dest" "$url" || true
    else
      wget -O "$dest" "$url" || true
    fi
    if [ ! -s "$dest" ]; then
      rm -f "$dest"
      continue
    fi
    headbytes=$(head -c 24 "$dest" 2>/dev/null || true)
    case "$headbytes" in
      *"<"*|*"Not Found"*)
        echo "Download of ${name} from ${url} was not a payload"
        rm -f "$dest"
        continue
        ;;
    esac
    return 0
  done
  echo "WARNING: could not download ${name}"
  return 1
}

voxbox_httpd() {
  systemctl restart httpd || true
}

voxbox_db() {
  systemctl restart mariadb || systemctl restart mysqld || true
}

voxbox_php_limits() {
  local ini="$1"
  [ -f "$ini" ] || return 0
  sed -i -E 's/^;?[[:space:]]*upload_max_filesize[[:space:]]*=.*/upload_max_filesize = 120M/' "$ini"
  sed -i -E 's/^;?[[:space:]]*memory_limit[[:space:]]*=.*/memory_limit = 256M/' "$ini"
  sed -i -E 's/^;?[[:space:]]*max_input_vars[[:space:]]*=.*/max_input_vars = 5000/' "$ini"
}

voxbox_banner() {
  echo "__     __                 ____"
  echo "\\ \\   / /  ___   __  __  | __ )    ___   __  __"
  echo " \\ \\ / /  / _ \\  \\ \\/ /  |  _ \\   / _ \\  \\ \\/ /"
  echo "  \\ V /  | (_) |  >  <   | |_) | | (_) |  >  <"
  echo "   \\_/    \\___/  /_/\\_\\  |____/   \\___/  /_/\\_\\"
  echo "VoxBox v $version"
  echo "Copyright (c) 2007-2026 Binary Systems, Inc."
  echo "Portions derived from WARD MUNDY & ASSOCIATES LLC."
}

# Incredible PBX Rocky habit: turn SELinux off before Apache and Asterisk are built.
if [ -f /etc/selinux/config ]; then
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
fi
setenforce 0 2>/dev/null || true

sed -i 's|rm -i|rm -f|' /root/.bashrc 2>/dev/null || true
sed -i 's|cp -i|cp -f|' /root/.bashrc 2>/dev/null || true
sed -i 's|mv -i|mv -f|' /root/.bashrc 2>/dev/null || true

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "nameserver 4.4.4.4" >> /etc/resolv.conf

if [ -t 0 ] && [ "${VOXBOX_NONINTERACTIVE:-}" != "1" ]; then
  COLUMNSIZE=$(echo -e "cols" | tput -S 2>/dev/null || echo 0)
  LINESIZE=$(echo -e "lines" | tput -S 2>/dev/null || echo 0)
  if [[ "${COLUMNSIZE:-0}" -lt 82 ]] || [[ "${LINESIZE:-0}" -lt 30 ]]; then
    echo " "
    echo "****** WARNING WARNING WARNING WARNING ******"
    echo "Window size is too small: ${COLUMNSIZE} x ${LINESIZE}"
    echo "Resize the console window to at least 82 x 30."
    echo "Otherwise, Asterisk may fail to compile."
    echo "****** WARNING WARNING WARNING WARNING ******"
    echo " "
  fi
  clear || true
  voxbox_banner
  echo " "
  echo "WARNING: This install erases ALL existing configurations on ${NAME:-this host} ${VERSION_ID:-}."
  echo " "
  echo "BY USING VOXBOX, YOU AGREE TO ASSUME ALL RESPONSIBILITY"
  echo "FOR USE OF THE PROGRAMS INCLUDED IN THIS INSTALLATION. NO WARRANTIES,"
  echo "EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY AND FITNESS FOR A"
  echo "PARTICULAR USE, ARE PROVIDED. YOU ASSUME ALL RISKS KNOWN AND UNKNOWN"
  echo "AND AGREE TO HOLD BINARY SYSTEMS, INC. HARMLESS FROM ANY AND ALL LOSS"
  echo "OR DAMAGE WHICH RESULTS FROM YOUR USE OF THIS SOFTWARE. AS CONFIGURED,"
  echo "THIS SOFTWARE CANNOT BE USED TO PLACE 911 CALLS, AND YOU AGREE TO"
  echo "PROVIDE AN ALTERNATE PHONE CAPABLE OF MAKING EMERGENCY CALLS. IF ANY"
  echo "OF THESE TERMS AND CONDITIONS ARE RULED TO BE UNENFORCEABLE, YOU AGREE"
  echo "TO ACCEPT ONE DOLLAR IN U.S. CURRENCY AS COMPENSATORY AND PUNITIVE"
  echo "LIQUIDATED DAMAGES FOR ANY AND ALL CLAIMS YOU AND ANY USERS OF THIS"
  echo "SOFTWARE MIGHT HAVE."
  echo " "
  echo "If you do not agree with these terms and conditions of use, press Ctrl-C now."
  read -p "Otherwise, press Enter to proceed at your own risk..."
fi

# Noninteractive (Harvester/cloud-init): set VOXBOX_ASTERISK=22|23 or VOXBOX_NONINTERACTIVE=1 (defaults to 22).
if [[ -n "${VOXBOX_ASTERISK:-}" ]]; then
  case "$VOXBOX_ASTERISK" in
    22|23) MyPick="$VOXBOX_ASTERISK" ;;
    *) echo "VOXBOX_ASTERISK must be 22 or 23"; exit 1 ;;
  esac
elif [[ "${VOXBOX_NONINTERACTIVE:-}" == "1" ]] || [[ ! -t 0 ]]; then
  MyPick=22
  echo "Noninteractive install: defaulting to Asterisk 22 LTS"
else
  clear || true
  temp=true
  while $temp; do
     read -p "Asterisk 22 LTS is installed by default. Would you prefer Asterisk 23? (y/n): " choice
          case "$choice" in
              [Yy]* )
                  temp=false
                  MyPick=23
                  ;;
              [Nn]* )
                  temp=false
                  MyPick=22
                  ;;
              * )
                  echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                  ;;
          esac
  done
  clear || true
fi
echo "Asterisk $MyPick will be installed on ${NAME:-EL} ${VERSION_ID:-}..."

if [ -t 0 ] && [ "${VOXBOX_NONINTERACTIVE:-}" != "1" ]; then
  clear || true
  voxbox_banner
  echo " "
  echo "Installing VoxBox 2026. Please wait. Asterisk's prerequisite script may"
  echo "ask for your ITU-T telephone country code. Enter it (1 for the North"
  echo "American Numbering Plan), then leave the keyboard alone until the"
  echo "FreePBX admin password prompt or the final reboot prompt."
  echo " "
  read -p "Read the above. Then press Enter to proceed at your own risk..."
fi

echo "Preparing ${NAME:-EL} ${VERSION_ID:-} (dnf, EPEL, CRB/PowerTools)..."
dnf -y install dnf-plugins-core ca-certificates curl wget tar sudo which || true

if [ "${ID:-}" != "fedora" ]; then
  dnf -y install epel-release \
    || dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${EL_MAJOR}.noarch.rpm" \
    || echo "WARN: EPEL was not installed. fail2ban, knockd, and some codecs may be missing."
  if command -v crb >/dev/null 2>&1; then
    crb enable || true
  fi
  dnf config-manager --set-enabled crb \
    || dnf config-manager --set-enabled powertools \
    || dnf config-manager --set-enabled PowerTools \
    || true
  if command -v subscription-manager >/dev/null 2>&1; then
    subscription-manager repos --enable "codeready-builder-for-rhel-${EL_MAJOR}-${ARCH}-rpms" || true
  fi
fi

dnf -y upgrade || echo "WARN: dnf upgrade reported errors (continuing)"

# Incredible PBX Rocky habit: firewalld off, iptables-services on.
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
systemctl mask firewalld 2>/dev/null || true
dnf -y install iptables iptables-services ipset || echo "WARN: iptables-services install failed"

# ffmpeg, lame, and mpg123 live in RPM Fusion on this family. Missing codecs are non-fatal.
if [ "${ID:-}" = "fedora" ]; then
  dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    || echo "WARN: RPM Fusion (Fedora) was not installed"
else
  dnf -y install "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${EL_MAJOR}.noarch.rpm" \
    || echo "WARN: RPM Fusion (EL ${EL_MAJOR}) was not installed"
fi
dnf -y install ffmpeg lame mpg123 || echo "WARN: ffmpeg, lame, or mpg123 is missing. Asterisk MP3 helpers may be skipped."

echo "Installing Node.js..."
if ! curl -fsSL https://rpm.nodesource.com/setup_24.x | bash -; then
  echo "WARN: NodeSource 24 setup failed. Trying Node.js 22."
  curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - || echo "WARN: NodeSource 22 setup failed"
fi
dnf -y install nodejs || echo "WARN: nodejs package install failed"
node -v || true

voxbox_install_php82() {
  if [ "${ID:-}" = "fedora" ]; then
    dnf -y install "https://rpms.remirepo.net/fedora/remi-release-${EL_MAJOR}.noarch.rpm" \
      || echo "WARN: Remi Fedora repo was not installed"
    dnf -y module reset php || true
    dnf -y module enable php:remi-8.2 || true
  elif [ "$EL_MAJOR" = "9" ]; then
    dnf -y module reset php || true
    if ! dnf -y module enable php:8.2; then
      echo "AppStream php:8.2 was not enabled. Trying Remi."
      dnf -y install "https://rpms.remirepo.net/enterprise/remi-release-${EL_MAJOR}.rpm" || true
      dnf -y module reset php || true
      dnf -y module enable php:remi-8.2 || true
    fi
  else
    dnf -y install "https://rpms.remirepo.net/enterprise/remi-release-${EL_MAJOR}.rpm" \
      || echo "WARN: Remi EL${EL_MAJOR} repo was not installed"
    dnf -y module reset php || true
    dnf -y module enable php:remi-8.2 || dnf -y module enable php:8.2 || true
  fi

  # Fedora without modularity: Remi ships a php82 software collection.
  if ! dnf -y install \
      php php-cli php-common php-fpm php-mysqlnd php-gd php-mbstring \
      php-xml php-intl php-bcmath php-opcache php-soap php-process \
      php-pear php-devel php-zip php-curl; then
    echo "Distro php packages failed. Trying the Remi php82 collection."
    dnf -y install \
      php82-php php82-php-cli php82-php-common php82-php-fpm php82-php-mysqlnd \
      php82-php-gd php82-php-mbstring php82-php-xml php82-php-intl \
      php82-php-bcmath php82-php-opcache php82-php-soap php82-php-process \
      php82-php-pear php82-php-devel php82-php-zip php82-php-cli php82-runtime \
      || return 1
  fi
  dnf -y install php-json php-pecl-imagick php-pecl-redis5 php-pecl-memcached || true

  voxbox_use_remi_php82() {
    if [ ! -x /opt/remi/php82/root/usr/bin/php ]; then
      return 1
    fi
    ln -sfn /opt/remi/php82/root/usr/bin/php /usr/bin/php
    ln -sfn /opt/remi/php82/root/usr/bin/pear /usr/bin/pear 2>/dev/null || true
    PHP_INI=/etc/opt/remi/php82/php.ini
    PHP_FPM_POOL=/etc/opt/remi/php82/php-fpm.d/www.conf
    PHP_FPM_SERVICE=php82-php-fpm
    PHP_FPM_SOCK=/var/opt/remi/php82/run/php-fpm/www.sock
    systemctl disable --now php-fpm 2>/dev/null || true
    return 0
  }

  local got
  got=$(php -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;' 2>/dev/null || true)
  if [ "$got" != "8.2" ]; then
    echo "Distro PHP is '${got:-missing}'. Trying the Remi php82 collection."
    dnf -y install \
      php82-php php82-php-cli php82-php-common php82-php-fpm php82-php-mysqlnd \
      php82-php-gd php82-php-mbstring php82-php-xml php82-php-intl \
      php82-php-bcmath php82-php-opcache php82-php-soap php82-php-process \
      php82-php-pear php82-php-devel php82-php-zip php82-runtime \
      php82-php-pecl-imagick php82-php-pecl-redis5 \
      || true
    voxbox_use_remi_php82 || true
    got=$(php -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;' 2>/dev/null || true)
  elif [ -x /opt/remi/php82/root/usr/bin/php ] && [ ! -x /usr/bin/php ]; then
    voxbox_use_remi_php82 || true
    got=$(php -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;' 2>/dev/null || true)
  fi
  if [ "$got" != "8.2" ]; then
    echo "PHP is '${got:-missing}'. FreePBX 17 needs PHP 8.2. Stopping before the PBX install."
    php -v || true
    return 1
  fi
  echo "PHP $got is installed. ini=$PHP_INI fpm=$PHP_FPM_SERVICE"
  return 0
}

if ! voxbox_install_php82; then
  exit 1
fi

# Export the pool paths the function may have retargeted. The function runs
# in this shell (not a subshell), so the assignments above are already visible.

dnf -y groupinstall "Development Tools" || dnf -y group install "Development Tools" || true

dnf -y install \
  git wget curl tar sudo which \
  gcc gcc-c++ make automake autoconf libtool pkgconfig \
  patch kernel-headers glibc-devel redhat-rpm-config \
  newt-devel openssl-devel ncurses-devel \
  subversion sqlite-devel jansson-devel libxml2-devel libuuid-devel \
  vim-enhanced nano dialog expect net-tools \
  libedit-devel openssh-server \
  httpd mod_ssl \
  mariadb-server mariadb \
  bison flex sox sqlite \
  unixODBC unixODBC-devel \
  alsa-lib-devel libogg-devel libvorbis-devel libicu-devel libcurl-devel \
  mariadb-connector-odbc \
  libical-devel libsrtp-devel \
  python3 python3-devel python3-pip \
  iptables iptables-services ipset \
  emacs-nox chrony jq \
  ghostscript libtiff-tools \
  fail2ban cronie \
  postfix cyrus-sasl cyrus-sasl-plain \
  initscripts chkconfig \
  speex-devel gsm-devel opus-devel libtool-ltdl-devel \
  neon-devel lua-devel \
  perl-interpreter procps-ng \
  mailx \
  || echo "WARN: one or more build packages failed. See the log above."

dnf -y install mariadb-connector-c-devel || dnf -y install mariadb-devel || true
dnf -y install sngrep htop openvpn spandsp-devel || echo "WARN: sngrep, htop, openvpn, or spandsp-devel is missing (non-fatal)"

if [ -f "$PHP_FPM_POOL" ]; then
  sed -i -E 's/^user[[:space:]]*=.*/user = asterisk/' "$PHP_FPM_POOL"
  sed -i -E 's/^group[[:space:]]*=.*/group = asterisk/' "$PHP_FPM_POOL"
  sed -i -E 's/^;?listen\.owner[[:space:]]*=.*/listen.owner = asterisk/' "$PHP_FPM_POOL"
  sed -i -E 's/^;?listen\.group[[:space:]]*=.*/listen.group = asterisk/' "$PHP_FPM_POOL"
  sed -i -E 's/^;?listen\.mode[[:space:]]*=.*/listen.mode = 0660/' "$PHP_FPM_POOL"
fi
# asterisk user is created after the compile. php-fpm is restarted then.

# When PHP comes from the Remi php82 collection, drop the distro handler so
# Apache does not keep speaking to a different php-fpm.
if [ "$PHP_FPM_SERVICE" = "php82-php-fpm" ] && [ -f /etc/httpd/conf.d/php.conf ]; then
  mv -f /etc/httpd/conf.d/php.conf /etc/httpd/conf.d/php.conf.voxbox-disabled
fi
if [ "$PHP_FPM_SERVICE" = "php82-php-fpm" ] || ! grep -Rqs 'proxy:unix:.*php-fpm\|proxy:unix:.*php82' /etc/httpd/conf /etc/httpd/conf.d /etc/httpd/conf.modules.d 2>/dev/null; then
  cat > /etc/httpd/conf.d/voxbox-php-fpm.conf << EOF
<FilesMatch \\.php$>
    SetHandler "proxy:unix:${PHP_FPM_SOCK}|fcgi://localhost"
</FilesMatch>
EOF
fi

systemctl enable --now "$PHP_FPM_SERVICE" || true
systemctl enable --now httpd || true
voxbox_httpd

# Webmin is not part of VoxBox.
voxbox_httpd

## Install emacs-nox (VoxBox default CLI editor) ##
dnf -y install emacs-nox || true

## Install latest PROTEL (Pc compiler, Pb beautifier, Emacs protel-mode) ##
# Binary Systems PROTEL 2026 — https://github.com/vincente666/PROTEL
SCRIPT_DIR_PROTEL=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
if [ -x "$SCRIPT_DIR_PROTEL/protel/install-protel.sh" ]; then
  "$SCRIPT_DIR_PROTEL/protel/install-protel.sh" || echo "WARN: PROTEL install failed (non-fatal)"
elif [ -x /root/VoxBox/protel/install-protel.sh ]; then
  /root/VoxBox/protel/install-protel.sh || echo "WARN: PROTEL install failed (non-fatal)"
else
  echo "WARN: protel/install-protel.sh not found; skip PROTEL toolchain"
fi

### Set up VIM for root user ###
echo "
set hlsearch
set mouse=r" > /root/.vimrc

cd /usr/src
voxbox_fetch "iksemel-1.4.tar.gz"
tar zxvf iksemel-1.4.tar.gz
cd iksemel-1.4
./configure --prefix=/usr --with-libgnutls-prefix=/usr
make
make check
make install
echo "/usr/local/lib" > /etc/ld.so.conf.d/iksemel.conf
ldconfig
cd /usr/src
mv *.tar.gz /tmp 2>/dev/null || true

if [[ "$MyPick" == "22" ]]; then
 wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
 tar xvf asterisk-22-current.tar.gz
 cd asterisk-22*/
else
 wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-23-current.tar.gz
 tar xvf asterisk-23-current.tar.gz
 cd asterisk-23*/
fi
contrib/scripts/get_mp3_source.sh || echo "WARN: get_mp3_source.sh failed (non-fatal)"
contrib/scripts/install_prereq install || echo "WARN: install_prereq reported errors (continuing)"
voxbox_fetch "menuselect-voxbox2025.tar.gz"
tar zxvf menuselect-voxbox*
rm -rf menuselect-voxbox*
CFLAGS='-DENABLE_SRTP_AES_256 -DENABLE_SRTP_AES_GCM'
export CFLAGS
./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled
make menuselect.makeopts
 menuselect/menuselect --enable-category MENUSELECT_ADDONS menuselect.makeopts
 menuselect/menuselect --enable-category MENUSELECT_CODECS menuselect.makeopts
 menuselect/menuselect --disable-category MENUSELECT_TESTS menuselect.makeopts
 menuselect/menuselect --enable codec_opus menuselect.makeopts
 menuselect/menuselect --enable codec_silk menuselect.makeopts
 menuselect/menuselect --enable codec_siren7 menuselect.makeopts
 menuselect/menuselect --enable codec_siren14 menuselect.makeopts
 menuselect/menuselect --enable codec_g729a menuselect.makeopts
make menuselect.makeopts
make
make install
make samples
make config
ldconfig

getent group asterisk >/dev/null || groupadd asterisk
id asterisk >/dev/null 2>&1 || useradd -r -d /var/lib/asterisk -g asterisk asterisk
usermod -aG audio,dialout asterisk || true
chown -R asterisk:asterisk /etc/asterisk
chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk
chown -R asterisk:asterisk /usr/lib64/asterisk 2>/dev/null || true

if [ -f /etc/default/asterisk ]; then
  sed -i 's|#AST_USER|AST_USER|' /etc/default/asterisk
  sed -i 's|#AST_GROUP|AST_GROUP|' /etc/default/asterisk
fi
if [ -f /etc/sysconfig/asterisk ]; then
  sed -i 's|#AST_USER|AST_USER|' /etc/sysconfig/asterisk
  sed -i 's|#AST_GROUP|AST_GROUP|' /etc/sysconfig/asterisk
  grep -q '^AST_USER' /etc/sysconfig/asterisk || echo 'AST_USER="asterisk"' >> /etc/sysconfig/asterisk
  grep -q '^AST_GROUP' /etc/sysconfig/asterisk || echo 'AST_GROUP="asterisk"' >> /etc/sysconfig/asterisk
fi
sed -i 's|;runuser|runuser|' /etc/asterisk/asterisk.conf
sed -i 's|;rungroup|rungroup|' /etc/asterisk/asterisk.conf
ldconfig

# Pool user is asterisk now that the account exists.
if [ -f "$PHP_FPM_POOL" ]; then
  sed -i -E 's/^user[[:space:]]*=.*/user = asterisk/' "$PHP_FPM_POOL"
  sed -i -E 's/^group[[:space:]]*=.*/group = asterisk/' "$PHP_FPM_POOL"
fi
systemctl enable --now "$PHP_FPM_SERVICE" || true
systemctl restart "$PHP_FPM_SERVICE" || true

systemctl restart asterisk || true

voxbox_php_limits "$PHP_INI"
if [ -f /etc/httpd/conf/httpd.conf ]; then
  sed -i 's/^User .*/User asterisk/' /etc/httpd/conf/httpd.conf
  sed -i 's/^Group .*/Group asterisk/' /etc/httpd/conf/httpd.conf
  sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
fi
mkdir -p /etc/httpd/conf.d
echo 'ServerName noreply.voxbox.local' > /etc/httpd/conf.d/voxbox-servername.conf
rm -f /etc/httpd/conf.d/welcome.conf /var/www/html/index.html
mkdir -p /var/lib/php/session /var/log/httpd /run/httpd
chown -R asterisk:asterisk /var/lib/php /var/log/httpd /run/httpd 2>/dev/null || true
echo 'd /run/httpd 0710 asterisk asterisk -' > /etc/tmpfiles.d/httpd-asterisk.conf
systemd-tmpfiles --create /etc/tmpfiles.d/httpd-asterisk.conf 2>/dev/null || true
voxbox_httpd

MAODBC="$(find /usr/lib64 /usr/lib -name 'libmaodbc.so' 2>/dev/null | head -1)"
if [ -z "$MAODBC" ]; then
  echo "WARN: libmaodbc.so was not found. ODBC CDR will need a Driver path in /etc/odbcinst.ini."
  MAODBC=/usr/lib64/libmaodbc.so
fi
systemctl enable --now mariadb || true
MYSQL_SOCK="$(mysql -N -u root -e "SHOW VARIABLES LIKE 'socket';" 2>/dev/null | awk '{print $2}')"
if [ -z "$MYSQL_SOCK" ]; then
  for candidate in /var/lib/mysql/mysql.sock /var/run/mysqld/mysqld.sock /run/mysqld/mysqld.sock; do
    if [ -S "$candidate" ]; then
      MYSQL_SOCK="$candidate"
      break
    fi
  done
fi
MYSQL_SOCK="${MYSQL_SOCK:-/var/lib/mysql/mysql.sock}"

cat <<EOF > /etc/odbcinst.ini
[MySQL]
Description = ODBC for MySQL (MariaDB)
Driver = ${MAODBC}
FileUsage = 1
EOF

cat <<EOF > /etc/odbc.ini
[MySQL-asteriskcdrdb]
Description = MySQL connection to 'asteriskcdrdb' database
Driver = MySQL
Server = localhost
Database = asteriskcdrdb
Port = 3306
Socket = ${MYSQL_SOCK}
Option = 3
EOF

systemctl stop asterisk || true
systemctl disable asterisk || true
killall asterisk 2>/dev/null || true
touch /root/cdr.conf

cd /usr/src/
dnf -y install cronie || true
systemctl enable --now crond || true
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-17.0-latest.tgz
tar zxvf freepbx-17.0-latest.tgz
cd /usr/src/freepbx/
./start_asterisk start
if [[ "$MyPick" == "23" ]]; then
 sed -i 's|22<|22, 23<|' /usr/src/freepbx/install.php
 sed -i 's|23"|24"|' /usr/src/freepbx/install.php
 sed -i 's|22<|22, 23<|' /usr/src/freepbx/installlib/installcommand.class.php
 sed -i 's|23"|24"|' /usr/src/freepbx/installlib/installcommand.class.php
fi
./install -n
fwconsole ma installall
fwconsole ma enablerepo standard extended unsupported
fwconsole ma downloadinstall superfecta queueprio miscdests miscapps outcnam dynroute extensionsettings disa allowlist
fwconsole ma remove firewall synologyabb
# The old GUI module is not installed. Logos and admin skin come from branding/.

echo "Now downloading and restoring FreePBX backup of core VoxBox system."
cd /tmp
voxbox_fetch "freepbx-backup-20240725-17.0.17.1.tar.gz"
fwconsole backup --restore /tmp/freepbx-backup-20240725-17.0.17.1.tar.gz
rm -f freepbx-backup-20240725-17.0.17.1.tar.gz

# Extension 53669 is Lenny. The restored device dials a retired external SIP
# URI, and this stack does not load chan_sip. Host the prompts locally.
voxbox_fetch "itslenny.tar.gz"
rm -rf /tmp/itslenny
tar -xzf itslenny.tar.gz -C /tmp
rm -rf /tmp/itslenny/.git
rm -rf /var/www/html/admin/modules/itslenny
cp -a /tmp/itslenny /var/www/html/admin/modules/itslenny
chown -R asterisk:asterisk /var/www/html/admin/modules/itslenny
lenny_sig=$(fwconsole setting SIGNATURECHECK | sed -n 's/.*\[\(.*\)\].*/\1/p' | head -1)
fwconsole setting SIGNATURECHECK 0
fwconsole ma install itslenny
fwconsole setting SIGNATURECHECK "${lenny_sig:-1}"
ln -sfn /var/www/html/admin/modules/itslenny/sounds/lenny /var/lib/asterisk/sounds/en/lenny
chown -h asterisk:asterisk /var/lib/asterisk/sounds/en/lenny || true
mysql -u root -ppassw0rd asterisk -e "UPDATE itslenny SET enable='CHECKED' WHERE id=1; UPDATE devices SET dial='Local/s@app-nv-itslenny/n' WHERE id='53669';"
rm -f itslenny.tar.gz
rm -rf /tmp/itslenny

fwconsole reload
asterisk -rx "database put DEVICE/53669 dial Local/s@app-nv-itslenny/n"
fwconsole restart

cat <<EOF > /etc/systemd/system/freepbx.service
[Unit]
Description=FreePBX VoIP Server
After=mariadb.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start -q
ExecStop=/usr/sbin/fwconsole stop -q
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable freepbx

mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'passw0rd';" \
  || mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('passw0rd');"

echo "
<Directory /var/www/html/admin/licenses>
	Options Indexes FollowSymLinks
	AllowOverride All
	Require all granted
</Directory>
" >> /etc/httpd/conf/httpd.conf
voxbox_httpd

fwconsole setting HTTPTLSBINDADDRESS 127.0.0.1
fwconsole setting HTTPBINDADDRESS 127.0.0.1
A=$SRANDOM$SRANDOM$SRANDOM$SRANDOM
B=${A:1:15}
fwconsole setting FPBX_ARI_USER $B
A=$SRANDOM$SRANDOM$SRANDOM$SRANDOM
C=${A:0:30}
fwconsole setting FPBX_ARI_PASSWORD $C
rm -rf /tmp/tmp.* /tmp/*.tar.gz 2>/dev/null || true

mysql -u root -ppassw0rd asterisk -e "update freepbx_settings SET value = '1' where keyword='CDR_BATCH_ENABLE';"
mysql -u root -ppassw0rd asterisk -e "update admin SET value = 'true' where variable='need_reload';"

if [ -e /usr/bin/python3.11 ]; then
  chmod +x /usr/bin/python3.11 || true
fi
asterisk -rx "database put blacklist dest app-blackhole,no-service,1" || true

# IPtables setup. Rules are the Travelin' Man file from the VoxBox mirror.
# iptables-services reads /etc/sysconfig/iptables. /etc/iptables/rules.v4 is kept
# so the same file the Debian installer writes is on disk too.
mkdir -p /etc/iptables /etc/ssl /usr/local/sbin
cd /etc/iptables
voxbox_fetch "iptables4-ubuntu18.04.2.tar.gz"
tar zxvf iptables4-ubuntu18.04.2.tar.gz
rm -f iptables4-ubuntu18.04.2.tar.gz
if [ -f iptables-custom ]; then
  mv -f iptables-custom /usr/local/sbin/iptables-custom
fi
if [ -f openssl.cnf ]; then
  mv -f openssl.cnf /etc/ssl/openssl.cnf
fi
cp -f rules.v4.tm3 rules.v4

# Prefer a non-loopback address. ifconfig on EL often lists lo first, and the
# older "inet addr:" cut misses the modern "inet 192.0.2.10" layout.
serverip=$(ifconfig | awk '/inet / { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+\./ && $i !~ /^127\./) { print $i; exit } }')
userip=$(echo "$SSH_CONNECTION" | cut -f 1 -d " ")
publicip=$(curl -fsS https://ipinfo.io/ip || true)
sed -i 's|8.8.4.4|'"$serverip"'|' /etc/iptables/rules.v4
sed -i 's|8.8.8.8|'"$userip"'|' /etc/iptables/rules.v4
sed -i 's|74.86.213.25|'"$publicip"'|' /etc/iptables/rules.v4

badline=$(grep -n "\-s  \-p" /etc/iptables/rules.v4 | cut -f1 -d: | tail -1)
while [[ "$badline" != "" ]]; do
  sed -i "${badline}d" /etc/iptables/rules.v4
  badline=$(grep -n "\-s  \-p" /etc/iptables/rules.v4 | cut -f1 -d: | tail -1)
done
sed -i 's|-A INPUT -s  -j|#-A INPUT -s  -j|g' /etc/iptables/rules.v4
chmod 755 /usr/local/sbin/iptables-custom 2>/dev/null || true
echo "/usr/sbin/iptables -A INPUT -s 100.64.0.0/10 -j ACCEPT" >> /usr/local/sbin/iptables-custom

sed -i 's|/usr/sbin/iptables -A INPUT -p udp -m udp -s sip1.v1voip|#/usr/sbin/iptables -A INPUT -p udp -m udp -s sip1.v1voip|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -p udp -m udp -s sip2.v1voip|#/usr/sbin/iptables -A INPUT -p udp -m udp -s sip2.v1voip|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -p udp -m udp -s sip.v1voip|#/usr/sbin/iptables -A INPUT -p udp -m udp -s sip.v1voip|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -s sip.nexmo.com|#/usr/sbin/iptables -A INPUT -s sip.nexmo.com|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -I INPUT -s api.nexmo.com|#/usr/sbin/iptables -I INPUT -s api.nexmo.com|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -s sip.signalwire|#/usr/sbin/iptables -A INPUT -s sip.signalwire|' /usr/local/sbin/iptables-custom

cp -f /etc/iptables/rules.v4 /etc/sysconfig/iptables
systemctl enable iptables || true
systemctl restart iptables || iptables-restore < /etc/sysconfig/iptables || true
/usr/local/sbin/iptables-custom || true

cd /
voxbox_fetch "rootfiles-debian10.tar.gz"
tar zxvf rootfiles-debian10.tar.gz
rm -f rootfiles-debian10.tar.gz
chattr -i /root/up* 2>/dev/null || true

cd /usr/local/sbin
voxbox_fetch "pbxstatus-2027D"
mv -f pbxstatus-2027D pbxstatus
chmod +x pbxstatus

dnf -y install fail2ban || true
sed -i 's|you@example.com|devnull@localhost|' /etc/fail2ban/jail.conf 2>/dev/null || true
sed -i 's|#allowipv6 = auto|allowipv6 = no|' /etc/fail2ban/fail2ban.conf 2>/dev/null || true
mkdir -p /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/voxbox-sshd.local << 'EOF'
[sshd]
enabled = true
backend = systemd
EOF
systemctl enable fail2ban || true
systemctl restart fail2ban || true

# remove CentOS fax installer leftovers from older payloads
rm -f /root/incrediblefax*

# Binary Systems VoxBox logos replace the upstream VoxBox branding module.
# Menu bar: cube favicon opens the Dashboard. Items: Admin, Applications, Connectivity, Reports, Settings, UCP. VoxBox Overview fiber GIF links to https://www.binary-systems.com/VoxBox/.
if [ -f "${SCRIPT_DIR}/branding/apply-voxbox-branding.sh" ]; then bash "${SCRIPT_DIR}/branding/apply-voxbox-branding.sh" || echo "WARNING: VoxBox branding apply failed"; fi
BRANDING_DIR=""
for candidate in "${SCRIPT_DIR}/branding" "/root/VoxBox/branding" "$(pwd)/branding"; do
  if [ -d "$candidate" ]; then
    BRANDING_DIR="$candidate"
    break
  fi
done
if [ -n "$BRANDING_DIR" ]; then
  mkdir -p /var/www/html/admin/images /var/www/html/admin/assets/images /var/www/html/images
  for logo in VoxBox-fiber.gif VoxBox-fiber-dark.gif binary_systems_si_animated.gif binary_systems_si_animated@2x.gif voxbox-favicon.png VoxBox-icon-clean.png favicon.ico; do
    if [ -f "$BRANDING_DIR/$logo" ]; then
      # Framework signs admin/images/favicon.ico. Leave that file stock.
      if [ "$logo" != "favicon.ico" ]; then
        cp -f "$BRANDING_DIR/$logo" /var/www/html/admin/images/
      fi
      cp -f "$BRANDING_DIR/$logo" /var/www/html/admin/assets/images/
      cp -f "$BRANDING_DIR/$logo" /var/www/html/images/
      cp -f "$BRANDING_DIR/$logo" /var/www/html/
    fi
  done
  if [ -f "$BRANDING_DIR/voxbox.css" ]; then
    cp -f "$BRANDING_DIR/voxbox.css" /var/www/html/admin/voxbox.css
    chown asterisk:asterisk /var/www/html/admin/voxbox.css 2>/dev/null || true
  fi
  chown -R asterisk:asterisk /var/www/html/admin/images /var/www/html/admin/assets/images /var/www/html/images 2>/dev/null || true
  echo "Installed VoxBox branding assets from $BRANDING_DIR"
  if [ -x "$BRANDING_DIR/apply-voxbox-branding.sh" ]; then
    "$BRANDING_DIR/apply-voxbox-branding.sh" || echo "WARNING: apply-voxbox-branding.sh reported errors (will retry later)"
  elif [ -f "$BRANDING_DIR/apply-voxbox-branding.sh" ]; then
    bash "$BRANDING_DIR/apply-voxbox-branding.sh" || echo "WARNING: apply-voxbox-branding.sh reported errors (will retry later)"
  fi
else
  echo "WARNING: branding/ not found beside installer, /root/VoxBox, or cwd; skipping logo copy."
fi
if [ -x /root/sig-fix ]; then
  /root/sig-fix || true
  /root/sig-fix || true
fi

# CentOS-like color scheme for ls. EL reads /etc/bashrc, not /etc/bash.bashrc.
cat >> /etc/bashrc << 'EOF'

# VoxBox ls colors
export LS_OPTIONS='--color=auto'
alias ls='ls $LS_OPTIONS'
alias ll='ls -l $LS_OPTIONS'
EOF

cd /var/www/html/admin
voxbox_fetch "iPBX-licenses.tar.gz"
tar zxvf iPBX-licenses.tar.gz
rm -f iPBX-licenses.tar.gz
chown -R asterisk:asterisk /var/www/html/admin/licenses 2>/dev/null || true

echo "Disabling IPv6..."
echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/70-disable-ipv6.conf
sysctl -p -f /etc/sysctl.d/70-disable-ipv6.conf || true
echo "IPv6 has been disabled."

/usr/local/sbin/iptables-custom || true

if [ ! -e "/usr/sbin/fwconsole" ] && [ -e /var/lib/asterisk/bin/fwconsole ]; then
  ln -s /var/lib/asterisk/bin/fwconsole /usr/sbin/fwconsole
fi

rm -f /root/upgrade-asterisk16
rm -f /root/upgrade-asterisk18
# timezone-setup from the Debian root payload edits /etc/php/7.3/... .
# On this family the live file is /etc/php.ini, and the web server is httpd.
if [ -f /root/timezone-setup ]; then
  sed -i 's|^#sed -i|sed -i|' /root/timezone-setup
  sed -i '\|/etc/php/7.3/|d' /root/timezone-setup
  sed -i 's|systemctl restart apache2|systemctl restart httpd|' /root/timezone-setup
fi

# Prefer the site router for time. A remote phone uses the NTP server
# advertised by its own router, so this host does not serve NTP.
dnf -y install chrony || true
rm -f /etc/chrony/conf.d/voxbox-phones.conf /etc/chrony.d/voxbox-phones.conf
gw=$(ip -4 route show default | awk '{print $3; exit}')
if [ -n "$gw" ] && [ -f /etc/chrony.conf ]; then
  awk -v gw="$gw" '
    $0 == "# VoxBox site router" { next }
    $0 == ("server " gw " iburst prefer") { next }
    { print }
  ' /etc/chrony.conf > /tmp/chrony.conf.voxbox
  {
    echo "# VoxBox site router"
    echo "server ${gw} iburst prefer"
    echo
    cat /tmp/chrony.conf.voxbox
  } > /etc/chrony.conf
  rm -f /tmp/chrony.conf.voxbox
fi
systemctl enable --now chronyd || true
systemctl restart chronyd || true

echo "# .bash_profile
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi
# User specific environment and startup programs
PATH=\$PATH:\$HOME/bin
export PATH
pbxstatus -p" > /root/.bash_profile

mysql -u root -ppassw0rd asterisk -e 'UPDATE freepbx_settings SET `value` = "Latest-17" WHERE `keyword` = "MIRROR_BRAND_VERSION" LIMIT 1'

voxbox_db
fwconsole chown
fwconsole reload
fwconsole restart

echo '[Unit]
Description=openvpn-voxbox
ConditionPathExists=/etc/openvpn-start
After=network-online.target
[Service]
Type=forking
ExecStart=/etc/openvpn-start /etc/voxbox2027.ovpn
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/openvpn2027.service
chmod +x /etc/systemd/system/openvpn2027.service
if [ -f /root/openvpn-start ]; then
  cp -p /root/openvpn-start /etc/openvpn-start
  chmod +x /etc/openvpn-start
  systemctl enable openvpn2027.service || true
  systemctl restart openvpn2027.service || true
fi

if [ -f /usr/local/sbin/watson-test ]; then
  sed -i 's|/usr/local/sbin/we-dont-have-tech-support.wav|/var/lib/asterisk/sounds/en/we-dont-have-tech-support.gsm|' /usr/local/sbin/watson-test
fi
clear || true

if [ -f /usr/local/sbin/pbxstatus ]; then
  sed -i 's|clear|clear -x|' /usr/local/sbin/pbxstatus || true
fi
cd /usr/local/sbin
voxbox_fetch "pbxstatus-2027"
mv -f pbxstatus-2027 pbxstatus
chmod +x pbxstatus

mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'passw0rd';" \
  || mysql -u root -ppassw0rd -e "SELECT 1;" >/dev/null
sed -i 's|mysqld|mariadbd|' /usr/local/sbin/pbxstatus
sed -i 's|/usr/sbin/apache2|/usr/sbin/httpd|g' /usr/local/sbin/pbxstatus
sed -i "s|^TITLE=.*|TITLE=\"VoxBox \$version for ${NAME} ${VERSION_ID}\"|" /usr/local/sbin/pbxstatus
sed -i "s|OSrelease=\"Debian |OSrelease=\"${NAME} |" /usr/local/sbin/pbxstatus
voxbox_httpd
voxbox_db
sed -i 's|SendMail| Postfix|' /usr/local/sbin/pbxstatus

# Postfix is installed above. Sendmail and Postfix conflict on RPM systems,
# so this path does not install Sendmail first.
systemctl enable --now postfix || true

### Install knockd ###
# EPEL ships knock-server (binary still named knockd). Options live in
# /etc/sysconfig/knockd, which is the EL equivalent of /etc/default/knockd.
dnf -y install knock-server || dnf -y install knock || echo "WARN: knockd package was not installed"
test=$(ifconfig 2>/dev/null | grep eth0 || true)
KNOCK_IF=""
if [ -z "$test" ]; then
  test2=$(ifconfig 2>/dev/null | grep wlan0 || true)
  if [ -z "$test2" ]; then
    KNOCK_IF=$(ifconfig 2>/dev/null | head -n 1 | cut -f 1 -d ":" | tr -d ' ')
  else
    KNOCK_IF=wlan0
  fi
else
  KNOCK_IF=eth0
fi
if [ -n "$KNOCK_IF" ]; then
  echo "OPTIONS=\"-i $KNOCK_IF\"" > /etc/sysconfig/knockd
fi

echo "[options]" > /etc/knockd.conf
echo "       logfile = /var/log/knockd.log" >> /etc/knockd.conf
echo "" >> /etc/knockd.conf
echo "[opencloseALL]" >> /etc/knockd.conf
echo "        sequence      = 7:udp,8:udp,9:udp" >> /etc/knockd.conf
echo "        seq_timeout   = 15" >> /etc/knockd.conf
echo "        tcpflags      = syn" >> /etc/knockd.conf
echo "        start_command = /usr/sbin/iptables -I INPUT -s %IP% -j ACCEPT" >> /etc/knockd.conf
echo "        cmd_timeout   = 3600" >> /etc/knockd.conf
echo "        stop_command  = /usr/sbin/iptables -D INPUT -s %IP% -j ACCEPT" >> /etc/knockd.conf
chmod 640 /etc/knockd.conf
lowest=6001
highest=9950
knock1=$(( ( RANDOM % ( highest - lowest + 1 ) ) + lowest ))
knock2=$(( ( RANDOM % ( highest - lowest + 1 ) ) + lowest ))
knock3=$(( ( RANDOM % ( highest - lowest + 1 ) ) + lowest ))
sed -i 's|7:udp|'"$knock1"':tcp|' /etc/knockd.conf
sed -i 's|8:udp|'"$knock2"':tcp|' /etc/knockd.conf
sed -i 's|9:udp|'"$knock3"':tcp|' /etc/knockd.conf
systemctl restart knockd || true
systemctl enable knockd || true
echo " "
echo "Knock ports for access to $publicip set to TCP: $knock1 $knock2 $knock3" > /root/knock.FAQ
echo "UPnP activation attempted for UDP 5060 and your knock ports above." >> /root/knock.FAQ
echo "To enable knockd on your server, issue the following commands:" >> /root/knock.FAQ
echo "  systemctl enable knockd" >> /root/knock.FAQ
echo "  systemctl start knockd" >> /root/knock.FAQ
echo "To enable remote access, issue these commands after dnf -y install nmap:" >> /root/knock.FAQ
echo "nmap -p $knock1 --max-retries 0 $publicip && nmap -p $knock2 --max-retries 0 $publicip && nmap -p $knock3 --max-retries 0 $publicip" >> /root/knock.FAQ
echo "Or install iOS PortKnock or Android DroidKnocker on remote device." >> /root/knock.FAQ

echo "#!/bin/sh -e
service knockd start
sleep 5
/usr/local/sbin/iptables-restart
sleep 30
systemctl restart ${PHP_FPM_SERVICE}
fwconsole restart
exit 0
" > /etc/rc.local
chmod +x /etc/rc.local
chattr +i /etc/rc.local

voxbox_php_limits "$PHP_INI"

rm -f /root/ucp-*
rm -f /root/switch-to-php*
rm -f /root/*.rpm

# gTTS update
dnf -y install jq sox python3-pip || true
pip3 install --upgrade pip || true
pip3 install gTTS || pip3 install --break-system-packages gTTS || echo "WARN: gTTS was not installed"
if [ ! -e /usr/bin/pip ] && [ -e /usr/bin/pip3 ]; then
  ln -s /usr/bin/pip3 /usr/bin/pip
fi
cd /var/lib/asterisk/agi-bin
voxbox_fetch "today3.tar.gz"
tar zxvf today3.tar.gz
rm -f today3.tar.gz
/var/lib/asterisk/agi-bin/nv-today.php || true
chown asterisk:asterisk /tmp/today.* 2>/dev/null || true
echo "08 01 * * * asterisk /var/lib/asterisk/agi-bin/nv-today.php" >> /etc/crontab
echo "*/10 5-22 * * * root /root/ipchecker > /dev/null 2>&1" >> /etc/crontab
systemctl enable --now crond || true

sed -i 's|127.0.0.1|127.0.0.1\tnoreply.voxbox.local|' /etc/hosts
echo 'noreply.voxbox.local' > /etc/hostname
hostname noreply.voxbox.local

# VoxBox 2026 identity stamps (Binary Systems)
cat > /etc/motd <<'VOXMOTD'
VoxBox 2026 — Binary Systems, Inc.
Secure, Private Communication Infrastructure
VOXMOTD
echo 'VoxBox 2026 \n \l' > /etc/issue
echo 'VoxBox 2026' > /etc/issue.net
if [ -f /etc/os-release ]; then
  if grep -q '^PRETTY_NAME=' /etc/os-release; then
    sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"VoxBox 2026 (Binary Systems / ${NAME})\"|" /etc/os-release
  else
    echo "PRETTY_NAME=\"VoxBox 2026 (Binary Systems / ${NAME})\"" >> /etc/os-release
  fi
fi

## Install Faxing Prep ##
dnf -y install libtiff-tools ghostscript || true
sed -i '/^\[custom-fax/,/^$/d' /etc/asterisk/extensions_custom.conf
echo '
[ext-group](+)
exten => fax,1,Noop(Fax detected)
exten -> fax,2,Goto(custom-fax-iaxmodem,s,1)

[custom-fax-iaxmodem]
exten => s,1,Answer
exten => s,n,Wait(1)
exten => s,n,Verbose(3,Incoming Fax)
exten => s,n,Set(FAXEMAIL=)     ; fax email address of recipient
exten => s,n,Set(FAXDEST=/tmp)  ; folder where faxes will be stored
exten => s,n,Set(tempfax=${STRFTIME(,,%C%y%m%d%H%M)})
exten => s,n,ReceiveFax(${FAXDEST}/${tempfax}.tif)
exten => s,n,System(/usr/bin/tiff2pdf -o "${FAXDEST}/${tempfax}.pdf" "${FAXDEST}/${tempfax}.tif")
exten => s,n,System(/usr/bin/echo "Incoming fax is attached." | /usr/bin/mail -s "Incoming FAX  Received" -A "${FAXDEST}/${tempfax}.pdf" "${FAXEMAIL}")
exten => s,n,Hangup

' >> /etc/asterisk/extensions_custom.conf

###  Add the update checker program  ###
cd /root
voxbox_fetch "root-folder-update.tar.gz"
tar zxvf root-folder-update.tar.gz
rm -f root-folder-update.tar.gz

### Gmail smarthost helper ###
# The mirror copy drives Debian debconf. Rewrite the package commands for dnf
# and install Postfix directly. The sasl_passwd steps that follow are unchanged.
cd /root
voxbox_fetch "enable-gmail-smarthost-with-postfix"
rm -f enable-gmail-smarthost-for-sendmail
chmod +x enable-gmail-smarthost-with-postfix
python3 - << 'PY'
from pathlib import Path
p = Path("/root/enable-gmail-smarthost-with-postfix")
t = p.read_text()
t = t.replace("apt-get install expect -y", "dnf -y install expect")
t = t.replace("apt-get install mailutils -y", "dnf -y install mailx || dnf -y install s-nail")
t = t.replace("apt-get install libsasl2-modules -y", "dnf -y install cyrus-sasl cyrus-sasl-plain")
start = t.find("echo '#!/usr/bin/expect -f'")
end = t.find("sleep 10\n")
if start != -1 and end != -1:
    t = t[:start] + "dnf -y install postfix\nsystemctl enable --now postfix\n" + t[end:]
p.write_text(t)
PY
# Also keep the Rocky-named helper archive next to it when the mirror has it.
voxbox_fetch "enable-gmail-smarthost-rocky8.tar.gz" || true

/usr/local/sbin/iptables-custom || true
chattr -i /etc/rc.local
chmod +x /etc/rc.local
chattr +i /etc/rc.local

### Set up log rotation for Asterisk log files ###
cat > /etc/logrotate.d/asterisk << 'EOF'
/var/log/asterisk/queue_log {
su asterisk asterisk
daily
missingok
rotate 30
notifempty
sharedscripts
create 0640 asterisk asterisk
}

/var/log/asterisk/freepbx_dbug{
su asterisk asterisk
size 500M
missingok
rotate 7
notifempty
sharedscripts
create 0640 asterisk asterisk
}

/var/log/asterisk/prosody_debug.log
/var/log/asterisk/prosody.log
/var/log/asterisk/ucp_err.log
/var/log/asterisk/ucp_forever.log
/var/log/asterisk/ucp_out.log
/var/log/asterisk/freepbx_debug
/var/log/asterisk/freepbx.log
/var/log/asterisk/freepbx_security.log {
su asterisk asterisk
size 100M
missingok
rotate 7
notifempty
sharedscripts
create 0640 asterisk asterisk
}

/var/spool/mail/asterisk
/var/log/asterisk/messages
/var/log/asterisk/event_log
/var/log/asterisk/full
/var/log/asterisk/dtmf
/var/log/asterisk/fail2ban {
su asterisk asterisk
daily
missingok
rotate 7
notifempty
sharedscripts
create 0640 asterisk asterisk
postrotate
/usr/sbin/asterisk -rx "logger reload" > /dev/null 2> /dev/null
endscript
}
EOF

/root/admin-pw-change || true

mysql -u root -ppassw0rd asterisk -e 'update freepbx_settings set value = 1 where keyword = "USERESMWIBLF"'
BRANDING_DIR=""
for candidate in "${SCRIPT_DIR}/branding" "/root/VoxBox/branding" "$(pwd)/branding"; do
  if [ -d "$candidate" ]; then
    BRANDING_DIR="$candidate"
    break
  fi
done
if [ -n "$BRANDING_DIR" ] && [ -f "$BRANDING_DIR/apply-voxbox-branding.sh" ]; then
  bash "$BRANDING_DIR/apply-voxbox-branding.sh" || echo "WARNING: apply-voxbox-branding.sh failed"
else
  mysql -u root -ppassw0rd asterisk -e 'update freepbx_settings set value = "VoxBox 2026" where keyword = "DASHBOARD_FREEPBX_BRAND"'
  mysql -u root -ppassw0rd asterisk -e 'UPDATE freepbx_settings SET value = "voxbox.css", readonly = 0 WHERE keyword = "BRAND_CSS_CUSTOM" LIMIT 1'
fi
# Menu mark is the cube and opens the Dashboard. The fiber GIF above the welcome line links to the VoxBox page.
mysql -u root -ppassw0rd asterisk -e "UPDATE freepbx_settings SET value='images/voxbox-favicon.png' WHERE keyword IN ('BRAND_IMAGE_TANGO_LEFT','BRAND_IMAGE_FAVICON');"
# Signed dashboard, UCP, and VoxBox module. This replaces the stock trees
# with the widget, footer, and signature files. It runs after the favicon
# SQL so the VoxBox module can publish its own brand paths.
if [ -n "$BRANDING_DIR" ] && [ -f "$BRANDING_DIR/install-signed-modules.sh" ]; then
  bash "$BRANDING_DIR/install-signed-modules.sh" || echo "WARNING: signed VoxBox modules were not fully installed"
fi
echo "2026" > /etc/pbx/.version
fwconsole reload || true

dnf -y install postfix || true
systemctl enable --now postfix || true

cd /
# ipbx2024 carries AGI helpers and also a Debian apt sources.list. Keep the AGIs.
# Do not leave that sources.list in place on an EL host.
APT_SOURCES_SAVED=0
if [ -f /etc/apt/sources.list ]; then
  cp -a /etc/apt/sources.list /tmp/sources.list.voxbox-save
  APT_SOURCES_SAVED=1
fi
voxbox_fetch "ipbx2024.tar.gz"
tar zxvf ipbx2024.tar.gz
voxbox_fetch "iPBX-custom.tar.gz"
tar zxvf iPBX-custom.tar.gz
if [ "$APT_SOURCES_SAVED" = "1" ]; then
  mv -f /tmp/sources.list.voxbox-save /etc/apt/sources.list
else
  rm -f /etc/apt/sources.list
fi
# Asteridex is not part of VoxBox. Drop leftovers from the FreePBX backup or custom bundles.
if command -v fwconsole >/dev/null 2>&1; then
  fwconsole ma disable asteridex 2>/dev/null || true
  fwconsole ma uninstall asteridex 2>/dev/null || true
fi
rm -rf /var/www/html/asteridex4 /var/www/html/asteridex17 /var/www/html/admin/modules/asteridex
rm -f /var/lib/asterisk/agi-bin/asteridex.php \
  /var/lib/asterisk/agi-bin/nv-callwho.php \
  /var/lib/asterisk/agi-bin/nv-callwho2.php \
  /var/lib/asterisk/agi-bin/getnumber.sh \
  /var/lib/asterisk/agi-bin/speeddial.txt \
  /var/lib/asterisk/agi-bin/ibm-411.txt \
  /etc/pbx/httpdconf/asteridex.conf \
  /var/www/html/admin/modules/superfecta/sources/source-Asteridex.module
mysql -u root -ppassw0rd -e "DROP DATABASE IF EXISTS asteridex;" || true
if [ -f /etc/asterisk/extensions_custom.conf ]; then
  sed -i '\:// BEGIN AsteriDex SpeedDial:,\:// END AsteriDex SpeedDial:d' /etc/asterisk/extensions_custom.conf
  sed -i '\:// BEGIN Call by Code:,\:// END Call by Code:d' /etc/asterisk/extensions_custom.conf
  sed -i '\:// BEGIN Call by Name:,\:// END Call by Name:d' /etc/asterisk/extensions_custom.conf
fi
if [ -f /etc/odbc.ini ]; then
  awk '
    /^\[MySQL-asteridex\]/ {skip=1; next}
    /^\[MySQL-asteidex\]/ {skip=1; next}
    /^\[/ {skip=0}
    !skip {print}
  ' /etc/odbc.ini > /tmp/odbc.ini.voxbox && mv /tmp/odbc.ini.voxbox /etc/odbc.ini
fi
if [ -f /etc/asterisk/func_odbc.conf ]; then
  awk '
    /^\[ASTERIDEX\]/ {skip=1; next}
    /^\[SQLITE3ASTERIDEX\]/ {skip=1; next}
    /^\[/ {skip=0}
    !skip {print}
  ' /etc/asterisk/func_odbc.conf > /tmp/func_odbc.conf.voxbox && mv /tmp/func_odbc.conf.voxbox /etc/asterisk/func_odbc.conf
fi
fwconsole reload || true

# PKCS bundle is a Debian tree (php8.2-fpm, apache2 envvars, rc.local).
# Keep the PHP class patches. Put the fpm sandbox override on this host's
# php-fpm unit, and keep the EL rc.local written above.
chattr -i /etc/rc.local
cp -a /etc/rc.local /tmp/rc.local.voxbox-el
cd /
voxbox_fetch "PKCS-Debian13.tar.gz"
tar zxvf PKCS-Debian13.tar.gz
rm -f PKCS-Debian13.tar.gz
cp -a /tmp/rc.local.voxbox-el /etc/rc.local
chmod +x /etc/rc.local
chattr +i /etc/rc.local
mkdir -p "/etc/systemd/system/${PHP_FPM_SERVICE}.service.d"
cat > "/etc/systemd/system/${PHP_FPM_SERVICE}.service.d/override.conf" << 'EOF'
[Service]
ProtectSystem=false
ProtectHome=false
PrivateTmp=false
ReadWritePaths=/etc/asterisk /var/www/html /var/log/asterisk /var/run/asterisk
EOF
systemctl daemon-reload
voxbox_httpd
fwconsole ma refreshsignatures || true
systemctl restart "$PHP_FPM_SERVICE" || true
systemctl enable "$PHP_FPM_SERVICE" || true
mysql -u root -ppassw0rd asterisk -e "DELETE FROM modules WHERE modulename = 'restart';" || true
mysql -u root -ppassw0rd asterisk -e "DELETE FROM module_xml WHERE id = 'restart';" || true
fwconsole chown || true
fwconsole reload || true
fwconsole certificates --delete 1 || true
fwconsole certificates --delete 0 || true

# rc-local is not enabled on a minimal EL install. This unit is what reloads
# knockd, iptables, and FreePBX after reboot.
cat > /etc/systemd/system/rc-local.service << 'EOF'
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable rc-local.service || true

if [[ "$MyPick" == "22" ]]; then
 cd /root
 voxbox_fetch "upgrade-asterisk"
 chmod +x upgrade-asterisk
 echo "upgrade-asterisk script added for easy Asterisk 23 upgrade, if desired."
fi

dnf -y install redis || true
systemctl enable --now redis || true

sed -i 's|2025|2026|' /etc/pbx/.version 2>/dev/null || true
sed -i 's|SendMail| Postfix|' /usr/local/sbin/pbxstatus
chmod 755 /var/lib/asterisk/keys/stir_shaken 2>/dev/null || true
rm -rf /etc/asterisk/integration
mkdir -p /etc/asterisk/keys/integration
chown -R asterisk:asterisk /etc/asterisk/keys
chmod -R 775 /etc/asterisk/keys

## VoxBox: tftp-server + VoxBox Endpoint Manager (FreePBX 17) + Polycom legacy templates ##
echo "=== VoxBox: installing tftp-server and VoxBox Endpoint Manager ==="

dnf -y install tftp-server || echo "WARN: tftp-server package was not installed"
mkdir -p /tftpboot
if id asterisk >/dev/null 2>&1; then
  chown -R asterisk:asterisk /tftpboot
else
  chown -R root:root /tftpboot
fi
chmod 775 /tftpboot
mkdir -p /etc/systemd/system/tftp.service.d
# in.tftpd -s is the secure chroot, same directory tftpd-hpa uses on Debian.
TFTP_BIN=/usr/sbin/in.tftpd
if [ ! -x "$TFTP_BIN" ]; then
  TFTP_BIN=$(command -v in.tftpd || true)
fi
if [ -n "$TFTP_BIN" ]; then
  cat > /etc/systemd/system/tftp.service.d/voxbox.conf << EOF
[Service]
ExecStart=
ExecStart=${TFTP_BIN} -s /tftpboot -u asterisk
EOF
  systemctl daemon-reload
  systemctl enable --now tftp.socket || systemctl restart tftp.socket || true
  systemctl is-active tftp.socket >/dev/null 2>&1 && echo "tftp.socket is active (directory /tftpboot)" || echo "WARNING: tftp.socket may not be active; check systemctl status tftp.socket"
else
  echo "WARNING: in.tftpd was not found"
fi

# --- B) VoxBox Endpoint Manager + phone templates from ossepm16.tgz ---
OSSEPM_TGZ=""
for candidate in "${SCRIPT_DIR}/mirror/ossepm16.tgz" "/opt/voxbox/mirror/ossepm16.tgz" "/root/VoxBox/mirror/ossepm16.tgz" "$(pwd)/mirror/ossepm16.tgz" "${SCRIPT_DIR}/ossepm16.tgz" "/root/ossepm16.tgz"; do
  if [ -f "$candidate" ]; then
    OSSEPM_TGZ="$candidate"
    break
  fi
done

EPM_TGZ=""
for candidate in "${SCRIPT_DIR}/mirror/voxbox-endpointman.tgz" "/opt/voxbox/mirror/voxbox-endpointman.tgz" "/root/VoxBox/mirror/voxbox-endpointman.tgz" "$(pwd)/mirror/voxbox-endpointman.tgz"; do
  if [ -f "$candidate" ]; then
    EPM_TGZ="$candidate"
    break
  fi
done
if [ -z "$EPM_TGZ" ]; then
  EPM_TGZ=/tmp/voxbox-endpointman.tgz
  rm -f "$EPM_TGZ"
  echo "Local VoxBox Endpoint Manager package not found; trying GitHub, then Gitea"
  for epmurl in \
    "${VOXBOX_MIRROR_GITHUB}/voxbox-endpointman.tgz" \
    "https://github.com/Binary-Systems/VoxBox-EndpointMan/archive/refs/heads/main.tar.gz" \
    "${VOXBOX_MIRROR_GITEA}/voxbox-endpointman.tgz" \
    "https://gitea.binary-systems.com/binary-systems.com/VoxBox-EndpointMan/archive/main.tar.gz"
  do
    echo "Trying $epmurl"
    if wget -O "$EPM_TGZ" --timeout=30 --tries=2 "$epmurl"; then
      headbytes=$(head -c 24 "$EPM_TGZ" 2>/dev/null || true)
      case "$headbytes" in
        *"<"*|*"Not Found"*)
          echo "Download from $epmurl was not a package"
          rm -f "$EPM_TGZ"
          ;;
        *)
          [ -s "$EPM_TGZ" ] && break
          ;;
      esac
    else
      rm -f "$EPM_TGZ"
    fi
  done
  if [ ! -s "$EPM_TGZ" ]; then
    echo "WARNING: VoxBox Endpoint Manager download failed"
  fi
fi

if [ ! -s "$EPM_TGZ" ]; then
  echo "ERROR: VoxBox Endpoint Manager package was not found"
else
  EPM_TMP=$(mktemp -d /tmp/voxbox-epm.XXXXXX)
  tar -C "$EPM_TMP" -xzf "$EPM_TGZ"
  EPM_SRC=""
  if [ -f "$EPM_TMP/endpointman/module.xml" ]; then
    EPM_SRC="$EPM_TMP/endpointman"
  elif [ -f "$EPM_TMP/module.xml" ]; then
    EPM_SRC="$EPM_TMP"
  else
    found=$(find "$EPM_TMP" -name module.xml -print -quit || true)
    if [ -n "$found" ]; then
      EPM_SRC=$(dirname "$found")
    fi
  fi
  if [ -z "$EPM_SRC" ] || [ ! -f "$EPM_SRC/module.xml" ]; then
    echo "ERROR: module.xml was not found in $EPM_TGZ"
  else
    rm -rf /var/www/html/admin/modules/endpointman
    mv "$EPM_SRC" /var/www/html/admin/modules/endpointman
    echo "Installed VoxBox Endpoint Manager into modules/endpointman"
  fi
  rm -rf "$EPM_TMP"
fi

# Phone brand templates from ossepm16. Do not install the FreePBX 16 endpointman/ inside that archive.
if [ -n "$OSSEPM_TGZ" ]; then
  echo "Using ossepm16.tgz at $OSSEPM_TGZ for _ep_phone_modules (Polycom splm etc.)"
  mkdir -p /var/www/html/admin/modules
  OSSEPM_TMP=$(mktemp -d /tmp/ossepm16.XXXXXX)
  tar -C "$OSSEPM_TMP" -xzf "$OSSEPM_TGZ" _ep_phone_modules
  mkdir -p /var/www/html/admin/modules/_ep_phone_modules
  cp -a "$OSSEPM_TMP/_ep_phone_modules/." /var/www/html/admin/modules/_ep_phone_modules/
  rm -rf "$OSSEPM_TMP"
  if [ -d /var/www/html/admin/modules/_ep_phone_modules/endpoint/polycom/splm ]; then
    echo "Polycom splm templates present (SoundPoint IP 301/501/600/601/4000)"
  else
    echo "WARNING: Polycom splm templates missing after ossepm16 extract"
  fi
else
  echo "WARNING: ossepm16.tgz not found in mirror/; Polycom templates not installed"
fi

fwconsole ma install endpointman || echo "WARNING: fwconsole ma install endpointman reported errors"
if [ -f /var/www/html/admin/modules/endpointman/install/voxbox-provisioner.php ]; then
  php /var/www/html/admin/modules/endpointman/install/voxbox-provisioner.php || echo "WARNING: VoxBox Endpoint Manager provisioner fix failed"
fi

chown -R asterisk:asterisk /var/www/html/admin/modules/endpointman /var/www/html/admin/modules/_ep_phone_modules 2>/dev/null || true
chmod -R g+w /var/www/html/admin/modules/endpointman /var/www/html/admin/modules/_ep_phone_modules 2>/dev/null || true
chown -R asterisk:asterisk /tftpboot 2>/dev/null || true
chmod 775 /tftpboot

php -r '
$bootstrap_settings["freepbx_auth"] = false;
if (!@include_once("/etc/freepbx.conf")) { fwrite(STDERR, "freepbx.conf missing\n"); exit(1); }
try {
  $epm = FreePBX::Endpointman();
  $epm->setConfig("config_location", "/tftpboot/");
  $epm->setConfig("update_server", "https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/");
  echo "EPM config_location=/tftpboot/ update_server=https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/\n";
} catch (Throwable $e) {
  fwrite(STDERR, "WARNING: could not set EPM package server via PHP: ".$e->getMessage()."\n");
  fwrite(STDERR, "Set Package Server in FreePBX GUI: Settings -> VoxBox Endpoint Manager -> Advanced Settings to https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/\n");
  exit(0);
}
' || echo "WARNING: PHP EPM config failed; set Package Server in GUI to https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/"

if [ -d /var/www/html/admin/modules/_ep_phone_modules ] && [ ! -e /var/www/html/admin/modules/_ep_phone_modules/tftpboot ]; then
  ln -sfn /tftpboot /var/www/html/admin/modules/_ep_phone_modules/tftpboot
fi

fwconsole reload || true

echo "=== VoxBox: attempting Polycom splm_firmware.tgz download ==="
SPLM_FW_OK=0
SPLM_FW_TMP=/tmp/splm_firmware.tgz
SPLM_FW_LOG=/tmp/voxbox-splm-firmware-attempts.txt
: > "$SPLM_FW_LOG"
for fwurl in \
  "${VOXBOX_MIRROR_GITHUB}/splm_firmware.tgz" \
  "${VOXBOX_MIRROR_GITEA}/splm_firmware.tgz" \
  "https://raw.githubusercontent.com/billsimon/provisioner/packaging/endpoint/polycom/splm_firmware.tgz"
do
  echo "Trying $fwurl" | tee -a "$SPLM_FW_LOG"
  rm -f "$SPLM_FW_TMP"
  if wget -O "$SPLM_FW_TMP" --timeout=20 --tries=2 "$fwurl" 2>>"$SPLM_FW_LOG"; then
    if file "$SPLM_FW_TMP" | grep -qiE 'gzip|tar|archive'; then
      mkdir -p /var/www/html/admin/modules/_ep_phone_modules/endpoint/polycom/splm
      tar -C /var/www/html/admin/modules/_ep_phone_modules/endpoint/polycom/splm -xzf "$SPLM_FW_TMP" && SPLM_FW_OK=1
      echo "Extracted splm_firmware.tgz from $fwurl" | tee -a "$SPLM_FW_LOG"
      chown -R asterisk:asterisk /var/www/html/admin/modules/_ep_phone_modules/endpoint/polycom/splm 2>/dev/null || true
      break
    else
      echo "Download from $fwurl was not a tarball (likely HTML/landing); ignoring" | tee -a "$SPLM_FW_LOG"
      rm -f "$SPLM_FW_TMP"
    fi
  else
    echo "FAILED $fwurl" | tee -a "$SPLM_FW_LOG"
  fi
done

if [ "$SPLM_FW_OK" -ne 1 ]; then
  cat > /root/VOXBOX-POLYCOM-FIRMWARE.txt << 'FWDOC'
VoxBox 2026 — Polycom legacy firmware (splm) not installed automatically
=======================================================================

Status
------
- VoxBox Endpoint Manager (FreePBX module endpointman 17.1.4) is installed.
- Polycom splm *templates* for SoundPoint IP 301/501/600/601 and SoundStation IP 4000
  were installed from ossepm16.tgz (_ep_phone_modules/endpoint/polycom/splm).
- Binary firmware package splm_firmware.tgz is not in the VoxBox mirror.
  The previous public URLs did not serve that archive.

How to obtain firmware
----------------------
1. Place splm_firmware.tgz in mirror/ of binary-systems.com/VoxBox and re-run, or
   copy a Polycom-licensed firmware tree into the provisioner/TFTP paths below.
2. Manually place Polycom-licensed firmware blobs into the provisioner/TFTP tree,
   typically under:
     /var/www/html/admin/modules/_ep_phone_modules/endpoint/polycom/splm/
   and/or serve them from /tftpboot/ (tftp.socket is enabled with directory /tftpboot).

Notes
-----
- Templates alone allow EPM to generate phone configs; phones still need vendor firmware
  appropriate to your Polycom license and model.
- Installer attempt log (if present): /tmp/voxbox-splm-firmware-attempts.txt
FWDOC
  cp -f "$SPLM_FW_LOG" /root/voxbox-splm-firmware-attempts.txt 2>/dev/null || true
  echo "Polycom firmware not downloaded; wrote /root/VOXBOX-POLYCOM-FIRMWARE.txt"
else
  echo "Polycom splm_firmware.tgz installed into polycom/splm templates tree"
fi

fwconsole chown || true
fwconsole reload || true
echo "=== VoxBox: tftp-server + OSS EPM + Polycom template setup complete ==="

if [ -t 0 ] && [ "${VOXBOX_NONINTERACTIVE:-}" != "1" ]; then
  read -p "Press Enter to reboot or Ctrl-C to exit..."
else
  echo "Noninteractive install: continuing to Quawk setup, then rebooting."
fi

## Quawk / IAX2 relay — LAN ACCEPT UDP 4569 ##
# Persist the allows in iptables-custom so iptables.service + rc.local keep them.
# The base rules live in /etc/sysconfig/iptables and are reloaded before custom.
if command -v iptables >/dev/null 2>&1; then
  for cidr in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    iptables -C INPUT -p udp --dport 4569 -s "$cidr" -j ACCEPT 2>/dev/null || \
      iptables -I INPUT -p udp --dport 4569 -s "$cidr" -j ACCEPT
    if ! grep -q "dport 4569 -s $cidr" /usr/local/sbin/iptables-custom 2>/dev/null; then
      echo "/usr/sbin/iptables -C INPUT -p udp --dport 4569 -s $cidr -j ACCEPT 2>/dev/null || /usr/sbin/iptables -I INPUT -p udp --dport 4569 -s $cidr -j ACCEPT" >> /usr/local/sbin/iptables-custom
    fi
  done
  echo "Firewall: LAN ACCEPT UDP 4569 (IAX2 / Quawk)"
fi

SCRIPT_DIR_QUAWK=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
if [ -x "$SCRIPT_DIR_QUAWK/Quawk/install-Quawk-relay.sh" ]; then
  "$SCRIPT_DIR_QUAWK/Quawk/install-Quawk-relay.sh" || echo "WARN: Quawk/install-Quawk-relay.sh failed (non-fatal)"
elif [ -x /root/VoxBox/Quawk/install-Quawk-relay.sh ]; then
  /root/VoxBox/Quawk/install-Quawk-relay.sh || echo "WARN: Quawk relay helper failed (non-fatal)"
fi

/usr/local/sbin/reboot
