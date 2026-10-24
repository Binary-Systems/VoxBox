#!/bin/bash
# Idempotent Quawk IAX relay helpers for VoxBox 2026
set -euo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
QUAWK_WAN=${QUAWK_WAN:-0}

echo "VoxBox Quawk relay: configuring UDP 4569 / dialplan / optional Avahi"

# --- firewall: LAN ACCEPT UDP 4569 ---
if command -v iptables >/dev/null 2>&1; then
  for cidr in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    if ! iptables -C INPUT -p udp --dport 4569 -s "$cidr" -j ACCEPT 2>/dev/null; then
      iptables -I INPUT -p udp --dport 4569 -s "$cidr" -j ACCEPT
      echo "iptables: ACCEPT UDP 4569 from $cidr"
    fi
  done
  if [ "$QUAWK_WAN" = "1" ]; then
    if ! iptables -C INPUT -p udp --dport 4569 -j ACCEPT 2>/dev/null; then
      iptables -I INPUT -p udp --dport 4569 -j ACCEPT
      echo "iptables: ACCEPT UDP 4569 from WAN (QUAWK_WAN=1)"
    fi
  fi
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save 2>/dev/null || true
  elif [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
  fi
else
  echo "WARN: iptables not found; open UDP 4569 manually"
fi

# --- from-Quawk dialplan ---
mkdir -p /etc/asterisk
cp -f "$SCRIPT_DIR/extensions_Quawk.conf" /etc/asterisk/extensions_Quawk.conf
CUSTOM=/etc/asterisk/extensions_custom.conf
touch "$CUSTOM"
if ! grep -q 'extensions_Quawk.conf' "$CUSTOM" 2>/dev/null; then
  printf '\n; Quawk P2T IAX dialplan\n#include extensions_Quawk.conf\n' >> "$CUSTOM"
  echo "Included extensions_Quawk.conf from extensions_custom.conf"
fi

# --- Avahi _Quawk._udp ---
if command -v apt-get >/dev/null 2>&1; then
  apt-get install -y avahi-daemon >/dev/null 2>&1 || apt-get install -y avahi-daemon
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install avahi || echo "WARN: avahi not installed"
fi
if [ -d /etc/avahi/services ]; then
  cp -f "$SCRIPT_DIR/avahi-Quawk.service" /etc/avahi/services/Quawk.service
  systemctl enable --now avahi-daemon 2>/dev/null || true
  systemctl restart avahi-daemon 2>/dev/null || true
  echo "Avahi: published _Quawk._udp on port 4569"
else
  echo "WARN: /etc/avahi/services missing; skip mDNS"
fi

# --- reload dialplan ---
if command -v asterisk >/dev/null 2>&1 && asterisk -rx "core show version" >/dev/null 2>&1; then
  asterisk -rx "dialplan reload" || true
fi

cat <<'MSG'

Quawk relay helpers installed.
Create per-device FreePBX IAX2 extensions (secret, context from-Quawk or from-internal).
Default requirecalltoken=yes — use no only for unpatched libiax2/iaxclient until confirmed.
Codecs: ulaw first, then alaw; opus optional.
See Quawk/README.md
MSG
