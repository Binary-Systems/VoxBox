#!/bin/bash
# VoxBox 2026 installer — Binary Systems, Inc.
# Copyright (C) 2007-2026, Binary Systems, Inc.
# Installer lineage includes work Copyright (C) 2005-2025, Ward Mundy & Associates LLC.
# VoxBox rebrand and packaging Copyright (C) 2007-2025 Binary Systems, Inc.
# This program installs Asterisk, FreePBX GUI, and VoxBox utilities.
# All programs copyrighted and licensed by their respective companies.
#
# REQUIRED BASE: Debian 13 (trixie) on amd64 or arm64, minimal, with SSH.
# Do not start from a desktop image.
# Raspberry Pi boards use VoxBox2026-RasPi.sh. That script checks the board,
# then runs this one. A direct run here still accepts Debian 13 arm64.
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

# A 2 GiB board cannot finish the Asterisk compile without swap.
# 4 GiB and larger already have enough RAM, so this does nothing there.
voxbox_ensure_swap() {
  local mem_kb swap_kb
  mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  swap_kb=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
  if [ "${mem_kb:-0}" -ge 3900000 ]; then
    return 0
  fi
  if [ "${swap_kb:-0}" -ge 1900000 ]; then
    echo "Swap is already ${swap_kb} kB."
    return 0
  fi
  echo "RAM is ${mem_kb} kB. Adding a 2 GiB swap file for the Asterisk compile."
  if [ ! -f /swapfile ]; then
    if ! fallocate -l 2G /swapfile 2>/dev/null; then
      dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
    fi
    chmod 600 /swapfile
    mkswap /swapfile
  fi
  if ! swapon --show=NAME --noheadings 2>/dev/null | grep -qx '/swapfile'; then
    if ! swapon /swapfile; then
      echo "Could not enable /swapfile. Free 2 GiB on the disk and run the installer again."
      exit 1
    fi
  fi
  if ! grep -q '^/swapfile[[:space:]]' /etc/fstab 2>/dev/null; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
}

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
case "$ARCH" in
  amd64|arm64) ;;
  *)
    echo "VoxBox2026.sh supports Debian amd64 and arm64. This host is ${ARCH:-unknown}."
    echo "On a Raspberry Pi, use VoxBox2026-RasPi.sh."
    exit 1
    ;;
esac

if [ "$ARCH" = "arm64" ]; then
  arm_codename=$(. /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME}")
  arm_codename=${arm_codename//\"/}
  if [ "$arm_codename" != "trixie" ]; then
    echo "VoxBox 2026 on arm64 needs Debian 13 (trixie). This host is ${arm_codename:-unknown}."
    echo "On a Raspberry Pi 5, 500, or Compute Module 5, install Raspberry Pi OS Lite 64-bit and run VoxBox2026-RasPi.sh."
    exit 1
  fi
  arm_mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  if [ "${arm_mem_kb:-0}" -lt 1400000 ]; then
    echo "This arm64 host has ${arm_mem_kb:-0} kB of RAM. VoxBox needs at least 2 GiB to compile Asterisk."
    if [ -r /proc/device-tree/model ]; then
      echo "Board: $(tr -d '\0' < /proc/device-tree/model)"
    fi
    echo "Pi 3, Zero 2 W, and 1 GiB Pi 4 boards are too small."
    exit 1
  fi
  voxbox_ensure_swap
fi

sed -i 's|rm -i|rm -f|' /root/.bashrc
sed -i 's|cp -i|cp -f|' /root/.bashrc
sed -i 's|mv -i|mv -f|' /root/.bashrc

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "nameserver 4.4.4.4" >> /etc/resolv.conf

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
  clear
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
  clear
fi
echo "Asterisk $MyPick will be installed..."

# Raspberry Pi OS keeps its firmware archive in sources.list.d. Copy a line out
# of sources.list before this rewrite so the Pi kernel repository stays.
if [ -f /etc/apt/sources.list ] && grep -Eq 'archive\.raspberrypi\.(com|org)' /etc/apt/sources.list; then
  if ! grep -RqsE 'archive\.raspberrypi\.(com|org)' /etc/apt/sources.list.d 2>/dev/null; then
    mkdir -p /etc/apt/sources.list.d
    grep -E 'archive\.raspberrypi\.(com|org)' /etc/apt/sources.list > /etc/apt/sources.list.d/raspi.list
    echo "Moved the Raspberry Pi archive to /etc/apt/sources.list.d/raspi.list"
  fi
fi

echo "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" > /etc/apt/sources.list
echo "deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list
echo "deb http://security.debian.org trixie-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

apt-get update -y
apt-get upgrade -y
apt-get install sudo -y

# new pieces for Debian 13
apt-get install ca-certificates curl gnupg -y
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo bash -
apt-get install nodejs npm -y
node -v
curl -fsSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
ARCH=$(dpkg --print-architecture)
cat <<EOF | tee /etc/apt/sources.list.d/php.sources
Types: deb
URIs: https://packages.sury.org/php/
Suites: ${CODENAME}
Components: main
Architectures: ${ARCH}
Signed-By: /usr/share/keyrings/deb.sury.org-php.gpg
EOF
apt-get update -y
apt-get install php8.2 php8.2-cli php8.2-common -y
apt-get install php8.2-fpm libapache2-mod-fcgid -y
a2enmod proxy_fcgi setenvif
a2enconf php8.2-fpm
systemctl enable --now php8.2-fpm
systemctl restart apache2
apt-get install php8.2-{curl,mysql,gd,mbstring,xml,zip,intl,bcmath,opcache,imagick,redis,memcached,soap} -y

# PHP 8.2 is the Sury build above. The Ubuntu ondrej PPA is not used.

apt-get install -y build-essential git wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev libjansson-dev libxml2-dev uuid-dev default-libmysqlclient-dev htop sngrep lame ffmpeg mpg123 dialog vim expect net-tools nano libedit-dev openvpn
apt-get install -y openssh-server apache2 mariadb-server mariadb-client bison flex php8.2 php8.2-curl php8.2-cli php8.2-common php8.2-mysql php8.2-gd php8.2-mbstring php8.2-intl php8.2-xml php-pear sox sqlite3 pkg-config automake libtool autoconf unixodbc-dev uuid
apt-get install -y libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev odbc-mariadb libical-dev libneon27-dev libsrtp2-dev libspandsp-dev libtool-bin python-dev-is-python3 unixodbc ipset iptables

 
apt-get install -y net-tools php8.2-common nano libedit-dev php-soap fail2ban

apt-get -y purge php8.1 php8.3
rm -rf /etc/php/8.1 /etc/php/8.3
a2enmod php8.2
update-alternatives --set php /usr/bin/php8.2
systemctl restart apache2

# Webmin is not part of VoxBox.
systemctl restart apache2

## Install emacs-nox (VoxBox default CLI editor) ##
apt-get install -y emacs-nox

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
mv *.tar.gz /tmp

if [[ "$MyPick" == "22" ]]; then
 wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
 tar xvf asterisk-22-current.tar.gz
 cd asterisk-22*/
else
 wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-23-current.tar.gz
 tar xvf asterisk-23-current.tar.gz
 cd asterisk-23*/
fi
contrib/scripts/get_mp3_source.sh
contrib/scripts/install_prereq install
voxbox_fetch "menuselect-voxbox2025.tar.gz"
tar zxvf menuselect-voxbox*
rm -rf menuselect-voxbox*
CFLAGS='-DENABLE_SRTP_AES_256 -DENABLE_SRTP_AES_GCM' 
./configure --with-pjproject-bundled --with-jansson-bundled
make menuselect.makeopts
 menuselect/menuselect --enable-category MENUSELECT_ADDONS menuselect.makeopts
 menuselect/menuselect --enable-category MENUSELECT_CODECS menuselect.makeopts
 menuselect/menuselect --disable-category MENUSELECT_TESTS menuselect.makeopts
 menuselect/menuselect --enable codec_opus menuselect.makeopts
 menuselect/menuselect --enable codec_silk menuselect.makeopts
 menuselect/menuselect --enable codec_siren7 menuselect.makeopts
 menuselect/menuselect --enable codec_siren14 menuselect.makeopts
 menuselect/menuselect --enable codec_g729a menuselect.makeopts || echo "WARN: codec_g729a is not in this Asterisk build."
make menuselect.makeopts
make
make install
make samples
make config
ldconfig

groupadd asterisk
useradd -r -d /var/lib/asterisk -g asterisk asterisk
usermod -aG audio,dialout asterisk
chown -R asterisk:asterisk /etc/asterisk
chown -R asterisk:asterisk /var/{lib,log,spool}/asterisk
for astlib in /usr/lib/asterisk /usr/lib64/asterisk; do
  if [ -d "$astlib" ]; then
    chown -R asterisk:asterisk "$astlib"
  fi
done

sed -i 's|#AST_USER|AST_USER|' /etc/default/asterisk
sed -i 's|#AST_GROUP|AST_GROUP|' /etc/default/asterisk
sed -i 's|;runuser|runuser|' /etc/asterisk/asterisk.conf
sed -i 's|;rungroup|rungroup|' /etc/asterisk/asterisk.conf
ldconfig

systemctl restart asterisk

sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/8.2/apache2/php.ini
sed -i 's/\(emory_limit = \).*/\1256M/' /etc/php/8.2/apache2/php.ini
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
a2enmod rewrite
systemctl restart apache2
rm /var/www/html/index.html

case "$ARCH" in
  arm64) multiarch=aarch64-linux-gnu ;;
  *) multiarch=x86_64-linux-gnu ;;
esac
MAODBC="/usr/lib/${multiarch}/odbc/libmaodbc.so"
if [ ! -f "$MAODBC" ]; then
  MAODBC="$(find /usr/lib /usr/lib64 -name 'libmaodbc.so' 2>/dev/null | head -1)"
fi
if [ -z "$MAODBC" ]; then
  echo "WARN: libmaodbc.so was not found. ODBC CDR will need a Driver path in /etc/odbcinst.ini."
  MAODBC="/usr/lib/${multiarch}/odbc/libmaodbc.so"
fi
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
Socket = /var/run/mysqld/mysqld.sock
Option = 3
EOF

systemctl stop asterisk
systemctl disable asterisk
killall asterisk
touch cdr.conf

apt-get update
apt-get install sudo -y
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y nodejs

cd /usr/src/
apt-get install cron -y
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
rm freepbx-backup-20240725-17.0.17.1.tar.gz

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

mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'passw0rd';"


echo "
<Directory /var/www/html/admin/licenses>
	Options Indexes FollowSymLinks
	AllowOverride All
	Require all granted
</Directory>
" >> /etc/apache2/apache2.conf
systemctl restart apache2

fwconsole setting HTTPTLSBINDADDRESS 127.0.0.1
fwconsole setting HTTPBINDADDRESS 127.0.0.1
A=$SRANDOM$SRANDOM$SRANDOM$SRANDOM
B=${A:1:15}
fwconsole setting FPBX_ARI_USER $B
A=$SRANDOM$SRANDOM$SRANDOM$SRANDOM
C=${A:0:30}
fwconsole setting FPBX_ARI_PASSWORD $C
rm /tmp/*

mysql -u root -ppassw0rd asterisk -e "update freepbx_settings SET value = '1' where keyword='CDR_BATCH_ENABLE';"
mysql -u root -ppassw0rd asterisk -e "update admin SET value = 'true' where variable='need_reload';"

chmod +x /usr/bin/python3.11
asterisk -rx "database put blacklist dest app-blackhole,no-service,1"
#IPtables Setup
cd /root
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get install -y iptables-persistent dialog
#cd /etc/init.d
voxbox_fetch "iptables-persistent-U.tar.gz"
tar zxvf iptables-persistent-U.tar.gz
rm iptables-persistent-U.tar.gz
cd /root

# server IP address is?
serverip=`ifconfig | grep "inet " | head -1 | cut -f 2 -d ":" | tr -s " " | cut -f 3 -d " "`
# user IP address while logged into SSH is?
userip=`echo $SSH_CONNECTION | cut -f 1 -d " "`
# public IP address in case we're on private LAN
publicip=`curl https://ipinfo.io/ip`
# WhiteList all of them by replacing 8.8.4.4 and 8.8.8.8 and 74.86.213.25 entries
cp /etc/iptables/rules.v4 /etc/iptables/rules.v4.orig
cd /etc/iptables
cp /etc/iptables/rules.v4 /etc/iptables/rules.v4.orig
voxbox_fetch "iptables4-ubuntu18.04.2.tar.gz"
tar zxvf iptables4-ubuntu18.04.2.tar.gz
rm iptables4-ubuntu18.04.2.tar.gz
mv iptables-custom /usr/local/sbin
mv openssl.cnf /etc/ssl
cp rules.v4.tm3 rules.v4
sed -i 's|8.8.4.4|'$serverip'|' /etc/iptables/rules.v4
sed -i 's|8.8.8.8|'$userip'|' /etc/iptables/rules.v4
sed -i 's|74.86.213.25|'$publicip'|' /etc/iptables/rules.v4

badline=`grep -n "\-s  \-p" /etc/iptables/rules.v4 | cut -f1 -d: | tail -1`
while [[ "$badline" != "" ]]; do
sed -i "${badline}d" /etc/iptables/rules.v4
badline=`grep -n "\-s  \-p" /etc/iptables/rules.v4 | cut -f1 -d: | tail -1`
done
sed -i 's|-A INPUT -s  -j|#-A INPUT -s  -j|g' /etc/iptables/rules.v4
#sed -i 's|#-A INPUT -p tcp -m tcp --dport 22|-A INPUT -p tcp -m tcp --dport 22|' rules.v4
ln -s /etc/init.d/iptables-persistent /etc/init.d/iptables
echo "/usr/sbin/iptables -A INPUT -s 100.64.0.0/10 -j ACCEPT" >> /usr/local/sbin/iptables-custom

sed -i 's|/usr/sbin/iptables -A INPUT -p udp -m udp -s sip1.v1voip|#/usr/sbin/iptables -A INPUT -p udp -m udp -s sip1.v1voip|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -p udp -m udp -s sip2.v1voip|#/usr/sbin/iptables -A INPUT -p udp -m udp -s sip2.v1voip|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -p udp -m udp -s sip.v1voip|#/usr/sbin/iptables -A INPUT -p udp -m udp -s sip.v1voip|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -s sip.nexmo.com|#/usr/sbin/iptables -A INPUT -s sip.nexmo.com|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -I INPUT -s api.nexmo.com|#/usr/sbin/iptables -I INPUT -s api.nexmo.com|' /usr/local/sbin/iptables-custom
sed -i 's|/usr/sbin/iptables -A INPUT -s sip.signalwire|#/usr/sbin/iptables -A INPUT -s sip.signalwire|' /usr/local/sbin/iptables-custom

/usr/local/sbin/iptables-custom
systemctl restart iptables
/usr/local/sbin/iptables-custom

cd /
voxbox_fetch "rootfiles-debian10.tar.gz"
tar zxvf rootfiles-debian10.tar.gz
rm rootfiles-debian10.tar.gz
chattr -i /root/up*

cd /usr/local/sbin
voxbox_fetch "pbxstatus-2027D"
mv pbxstatus-2027D pbxstatus
chmod +x pbxstatus

apt-get install fail2ban -y

# kill all the endless Fail2Ban alerts
sed -i 's|you@example.com|devnull@localhost|' /etc/fail2ban/jail.conf
sed -i 's|#allowipv6 = auto|allowipv6 = no|' /etc/fail2ban/fail2ban.conf
sed -i 's|sshd_log = %(syslog_authpriv)s|sshd_log = /var/log/sshd.log|' /etc/fail2ban/paths-common.conf
mkdir /var/log/sshd.log
sed -i 's|%(sshd_log)s|/var/log/sshd.log|' /etc/fail2ban/jail.conf
#echo "sshd_backend = systemd" >> /etc/fail2ban/paths-debian.conf
sed -i 's|fail2ban-client -x start|#fail2ban-client -x start|' /etc/fail2ban/paths-debian.conf

systemctl enable fail2ban
systemctl start fail2ban

# remove CentOS fax installer
rm -f /root/incrediblefax*   # legacy upstream leftover names

# Binary Systems VoxBox logos replace the upstream VoxBox branding module.
# Menu bar: cube favicon opens the Dashboard. Items: Admin, Applications, Connectivity, Reports, Settings, UCP. VoxBox Overview fiber GIF links to https://www.binary-systems.com/VoxBox/.
if [ -f "${SCRIPT_DIR}/branding/apply-voxbox-branding.sh" ]; then bash "${SCRIPT_DIR}/branding/apply-voxbox-branding.sh" || echo "WARNING: VoxBox branding apply failed"; fi
# Install visual branding from repo branding/ (SCRIPT_DIR, /root/VoxBox, or cwd).
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
  # Upgrade-safe FreePBX admin greyscale (BRAND_CSS_CUSTOM overlay — no Framework fork)
  if [ -f "$BRANDING_DIR/voxbox.css" ]; then
    cp -f "$BRANDING_DIR/voxbox.css" /var/www/html/admin/voxbox.css
    chown asterisk:asterisk /var/www/html/admin/voxbox.css 2>/dev/null || true
  fi
  chown -R asterisk:asterisk /var/www/html/admin/images /var/www/html/admin/assets/images /var/www/html/images 2>/dev/null || true
  echo "Installed VoxBox branding assets from $BRANDING_DIR"
  # Full branding apply (settings + VIEW_LOGIN + logo resize + endpointman enable)
  if [ -x "$BRANDING_DIR/apply-voxbox-branding.sh" ]; then
    "$BRANDING_DIR/apply-voxbox-branding.sh" || echo "WARNING: apply-voxbox-branding.sh reported errors (will retry later)"
  elif [ -f "$BRANDING_DIR/apply-voxbox-branding.sh" ]; then
    bash "$BRANDING_DIR/apply-voxbox-branding.sh" || echo "WARNING: apply-voxbox-branding.sh reported errors (will retry later)"
  fi
else
  echo "WARNING: branding/ not found beside installer, /root/VoxBox, or cwd; skipping logo copy."
fi
./sig-fix
./sig-fix

# CentOS-like color scheme for ls
echo "export LS_OPTIONS='--color=auto'
eval \"\`dircolors\`\"
alias ls='ls \$LS_OPTIONS'
alias ll='ls -l \$LS_OPTIONS'" >> /etc/bash.bashrc

cd /var/www/html/admin
voxbox_fetch "iPBX-licenses.tar.gz"
tar zxvf iPBX-licenses.tar.gz
rm iPBX-licenses.tar.gz


# Checking for IPv6
#test=`ifconfig | grep inet6`
#if [ -z "$test" ]; then
# echo "IPv6 not enabled."
#else
 echo "Disabling IPv6..."
 echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/70-disable-ipv6.conf
 sysctl -p -f /etc/sysctl.d/70-disable-ipv6.conf
 echo "IPv6 has been disabled."
#fi

/usr/local/sbin/iptables-custom
iptables-save

if [ -e "/usr/sbin/fwconsole" ]; then
 echo " "
else
 ln -s /var/lib/asterisk/bin/fwconsole /usr/sbin/fwconsole
fi

rm -f /root/upgrade-asterisk16
rm -f /root/upgrade-asterisk18
sed -i 's|7.3|8.2|' /root/timezone-setup

# Debian 13 has no ntp package. Use the site router for time. A remote
# phone uses the NTP server advertised by its own router.
apt-get install chrony -y
mkdir -p /etc/chrony/sources.d
rm -f /etc/chrony/conf.d/voxbox-phones.conf
gw=$(ip -4 route show default | awk '{print $3; exit}')
if [ -n "$gw" ]; then
cat > /etc/chrony/sources.d/voxbox-router.sources << EOF
server ${gw} iburst prefer
EOF
fi
systemctl enable chrony
systemctl restart chrony

echo "# .bash_profile
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi
# User specific environment and startup programs
PATH=$PATH:$HOME/bin
export PATH
pbxstatus -p" > /root/.bash_profile

mysql -u root -ppassw0rd asterisk -e 'UPDATE freepbx_settings SET `value` = "Latest-17" WHERE `keyword` = "MIRROR_BRAND_VERSION" LIMIT 1'

systemctl restart mysqld
fwconsole chown
fwconsole reload
fwconsole restart

echo '[Unit]
Description=openvpn-voxbox
ConditionPathExists=/etc/openvpn-start
After=rclocal.service
[Service]
Type=forking
ExecStart=/etc/openvpn-start /etc/voxbox2027.ovpn  # upstream package source filename
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
PermissionsStartOnly=true
SysVStartPriority=99
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/openvpn2027.service
chmod +x /etc/systemd/system/openvpn2027.service
cp -p /root/openvpn-start /etc/openvpn-start
systemctl enable openvpn2027.service
systemctl restart openvpn2027.service

# Watson STT fix
sed -i 's|/usr/local/sbin/we-dont-have-tech-support.wav|/var/lib/asterisk/sounds/en/we-dont-have-tech-support.gsm|' /usr/local/sbin/watson-test
clear

# pbxstatus history fix
sed -i 's|clear|clear -x|' /usr/local/sbin/pbxstatus
cd /usr/local/sbin
voxbox_fetch "pbxstatus-2027"
mv pbxstatus-2027 pbxstatus
chmod +x pbxstatus

 mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'passw0rd';"
 sed -i 's|mysqld|mariadbd|' /usr/local/sbin/pbxstatus
 systemctl restart apache2
 systemctl restart mysqld
 sed -i 's|Bullseye|Bookworm|' /usr/local/sbin/pbxstatus
# sed -i 's|lastupdateDEB|lastupdate2020|' /root/update-VoxBox


apt-get install -y sendmail mailutils
systemctl enable sendmail
systemctl start sendmail

### Install knockd ###

apt-get install knockd -y
sed -i 's|START_KNOCKD=0|START_KNOCKD=1|' /etc/default/knockd
test=`ifconfig | grep eth0`
if [ -z "$test" ]; then
 test2=`ifconfig | grep wlan0`
 if [ -z "$test2" ]; then
  devport=`ifconfig | head -n 1 | cut -f 1 -d ":"`
  echo "KNOCKD_OPTS=\"-i $devport\"" >> /etc/default/knockd
 else
  echo 'KNOCKD_OPTS="-i wlan0"' >> /etc/default/knockd
 fi
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
# randomize ports here
lowest=6001
highest=9950
knock1=$[ ( $RANDOM % ( $[ $highest - $lowest ] + 1 ) ) + $lowest ]
knock2=$[ ( $RANDOM % ( $[ $highest - $lowest ] + 1 ) ) + $lowest ]
knock3=$[ ( $RANDOM % ( $[ $highest - $lowest ] + 1 ) ) + $lowest ]
sed -i 's|7:udp|'$knock1':tcp|' /etc/knockd.conf
sed -i 's|8:udp|'$knock2':tcp|' /etc/knockd.conf
sed -i 's|9:udp|'$knock3':tcp|' /etc/knockd.conf
systemctl restart knockd
systemctl enable knockd
echo " "
echo "Knock ports for access to $publicip set to TCP: $knock1 $knock2 $knock3" > /root/knock.FAQ
echo "UPnP activation attempted for UDP 5060 and your knock ports above." >> /root/knock.FAQ
echo "To enable knockd on your server, issue the following commands:" >> /root/knock.FAQ
echo "  chkconfig --level 2345 knockd on" >> /root/knock.FAQ
echo "  service knockd start" >> /root/knock.FAQ
echo "To enable remote access, issue these commands after yum -y install nmap:" >> /root/knock.FAQ
echo "nmap -p $knock1 --max-retries 0 $publicip && nmap -p $knock2 --max-retries 0 $publicip && nmap -p $knock3 --max-retries 0 $publicip" >> /root/knock.FAQ
echo "Or install iOS PortKnock or Android DroidKnocker on remote device." >> /root/knock.FAQ

echo "#!/bin/sh -e
service knockd start
sleep 5
/usr/local/sbin/iptables-restart
sleep 30
fwconsole restart
exit 0
" > /etc/rc.local
chattr +i /etc/rc.local

sed -i 's|; max_input_vars = 1000|max_input_vars = 5000|' /etc/php/8.2/apache2/php.ini
# systemctl restart apache2.service

rm -f /root/ucp-*
rm -f /root/switch-to-php*
rm -f /root/*.deb
rm -f /root/*.rpm

# gTTS update
apt-get update
apt-get -y install jq libsox-fmt-all
apt-get -y install python3-pip
pip install --upgrade pip
pip3 install --upgrade pip
ln -s /usr/bin/pip3 /usr/bin/pip
pip install gTTS
cd /var/lib/asterisk/agi-bin
voxbox_fetch "today3.tar.gz"
tar zxvf today3.tar.gz
rm -f today3.tar.gz
/var/lib/asterisk/agi-bin/nv-today.php
chown asterisk:asterisk /tmp/today.*
echo "08 01 * * * asterisk /var/lib/asterisk/agi-bin/nv-today.php" >> /etc/crontab
echo "*/10 5-22 * * * root /root/ipchecker > /dev/null 2>&1" >> /etc/crontab
crontab /etc/crontab

sed -i 's|127.0.0.1|127.0.0.1\tnoreply.voxbox.local|' /etc/hosts
echo 'noreply.voxbox.local' > /etc/hostname
hostname noreply.voxbox.local

# VoxBox 2026 identity stamps (Binary Systems) — keep Debian os-release intact aside from PRETTY_NAME overlay
cat > /etc/motd <<'VOXMOTD'
VoxBox 2026 — Binary Systems, Inc.
Secure, Private Communication Infrastructure
VOXMOTD
echo 'VoxBox 2026 \n \l' > /etc/issue
echo 'VoxBox 2026' > /etc/issue.net
if [ -f /etc/os-release ]; then
  if grep -q '^PRETTY_NAME=' /etc/os-release; then
    sed -i 's|^PRETTY_NAME=.*|PRETTY_NAME="VoxBox 2026 (Binary Systems / Debian)"|' /etc/os-release
  else
    echo 'PRETTY_NAME="VoxBox 2026 (Binary Systems / Debian)"' >> /etc/os-release
  fi
fi

## Install Faxing Prep ##
apt-get update
apt-get install libtiff-tools -y
apt-get install ghostscript -y
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

### Get rid of Sendmail and Add Postfix ###

cd /root 
voxbox_fetch "enable-gmail-smarthost-with-postfix"
rm -f enable-gmail-smarthost-for-sendmail
chmod +x enable-gmail-smarthost-with-postfix

/usr/local/sbin/iptables-custom
chattr -i /etc/rc.local
chmod +x /etc/rc.local
chattr +i /etc/rc.local

### Set up log rotation for Asterisk log files ###
touch /etc/logrotate.d/asterisk
echo "/var/log/asterisk/queue_log {
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
/usr/sbin/asterisk -rx ‘logger reload’ > /dev/null 2> /dev/null
endscript
}
" > /etc/logrotate.d/asterisk


/root/admin-pw-change

mysql -u root -ppassw0rd asterisk -e 'update freepbx_settings set value = 1 where keyword = "USERESMWIBLF"'
# VoxBox branding settings via upgrade-safe apply script (freepbx_settings + VIEW_LOGIN + CSS)
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
fwconsole reload

apt-get install postfix -y

sed -i "s|deb http|deb [trusted=yes] http|" /etc/apt/sources.list

cd /
voxbox_fetch "ipbx2024.tar.gz"
tar zxvf ipbx2024.tar.gz
voxbox_fetch "iPBX-custom.tar.gz"
tar zxvf iPBX-custom.tar.gz
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
sed -i 's|bookworm|trixie|' /etc/apt/sources.list
apt-get update
fwconsole reload

# new bug fixes for Debian 13
sed -i 's|www-data|asterisk|' /etc/php/8.2/fpm/pool.d/www.conf
systemctl restart php8.2-fpm.service
fwconsole reload --verbose
sed -i 's|2025|2026|' /etc/pbx/.version
sed -i 's|SendMail| Postfix|' /usr/local/sbin/pbxstatus
chmod 755 /var/lib/asterisk/keys/stir_shaken
rm -rf /etc/asterisk/integration
mkdir -p /etc/asterisk/keys/integration
chown -R asterisk:asterisk /etc/asterisk/keys
chmod -R 775 /etc/asterisk/keys
apt-get update
apt-get install redis-server redis-tools -y
systemctl start redis-server
systemctl enable redis-server
systemctl start redis.service
systemctl enable redis.service
cd /
chattr -i /etc/rc.local
voxbox_fetch "PKCS-Debian13.tar.gz"
tar zxvf PKCS-Debian13.tar.gz
rm -f PKCS-Debian13.tar.gz
chattr +i /etc/rc.local
systemctl restart apache2
fwconsole ma refreshsignatures
systemctl daemon-reload
systemctl restart php8.2-fpm.service
systemctl enable php8.2-fpm.service
mysql -u root -ppassw0rd asterisk -e "DELETE FROM modules WHERE modulename = 'restart';"
mysql -u root -ppassw0rd asterisk -e "DELETE FROM module_xml WHERE id = 'restart';"
fwconsole chown
fwconsole reload
fwconsole certificates --delete 1
fwconsole certificates --delete 0

if [[ "$MyPick" == "22" ]]; then
 cd /root
 voxbox_fetch "upgrade-asterisk"
 chmod +x upgrade-asterisk
 echo "upgrade-asterisk script added for easy Asterisk 23 upgrade, if desired."
fi

test=`cat os-release | grep Ubuntu`
if [ -z "$test" ]; then
 echo "Debian platform."
else
echo '[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/rc-local.service
systemctl daemon-reload
systemctl enable rc-local
fi


## VoxBox: tftpd-hpa + VoxBox Endpoint Manager (FreePBX 17) + Polycom legacy templates ##
echo "=== VoxBox: installing tftpd-hpa and VoxBox Endpoint Manager ==="

# --- A) tftpd-hpa ---
apt-get install -y tftpd-hpa
mkdir -p /tftpboot
if id asterisk >/dev/null 2>&1; then
  chown -R asterisk:asterisk /tftpboot
else
  chown -R root:root /tftpboot
fi
chmod 775 /tftpboot
cat > /etc/default/tftpd-hpa << 'TFTPEOF'
# /etc/default/tftpd-hpa
TFTP_USERNAME="asterisk"
TFTP_DIRECTORY="/tftpboot"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
TFTPEOF
# Fall back if asterisk user somehow missing for tftpd
if ! id asterisk >/dev/null 2>&1; then
  sed -i 's/^TFTP_USERNAME=.*/TFTP_USERNAME="tftp"/' /etc/default/tftpd-hpa
fi
systemctl enable --now tftpd-hpa || systemctl restart tftpd-hpa
systemctl is-active tftpd-hpa >/dev/null 2>&1 && echo "tftpd-hpa is active (TFTP_DIRECTORY=/tftpboot)" || echo "WARNING: tftpd-hpa may not be active; check systemctl status tftpd-hpa"

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

# --- C) Polycom legacy firmware attempt (non-fatal) ---
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
   and/or serve them from /tftpboot/ (tftpd-hpa is enabled with TFTP_DIRECTORY=/tftpboot).

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
echo "=== VoxBox: tftpd-hpa + OSS EPM + Polycom template setup complete ==="

read -p "Press Enter to reboot or Ctrl-C to exit..."

## Quawk / IAX2 relay — LAN ACCEPT UDP 4569 ##
# Per-device FreePBX IAX2 extensions; requirecalltoken=yes by default (see Quawk/).
if command -v iptables >/dev/null 2>&1; then
  for cidr in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    iptables -C INPUT -p udp --dport 4569 -s "$cidr" -j ACCEPT 2>/dev/null ||       iptables -I INPUT -p udp --dport 4569 -s "$cidr" -j ACCEPT
  done
  echo "Firewall: LAN ACCEPT UDP 4569 (IAX2 / Quawk)"
fi

# Optional Quawk relay helpers (from-Quawk dialplan, Avahi _Quawk._udp)
SCRIPT_DIR_QUAWK=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
if [ -x "$SCRIPT_DIR_QUAWK/Quawk/install-Quawk-relay.sh" ]; then
  "$SCRIPT_DIR_QUAWK/Quawk/install-Quawk-relay.sh" || echo "WARN: Quawk/install-Quawk-relay.sh failed (non-fatal)"
elif [ -x /root/VoxBox/Quawk/install-Quawk-relay.sh ]; then
  /root/VoxBox/Quawk/install-Quawk-relay.sh || echo "WARN: Quawk relay helper failed (non-fatal)"
fi

/usr/local/sbin/reboot
