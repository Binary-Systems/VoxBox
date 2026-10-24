#!/bin/bash
# VoxBox 2026 installer for Raspberry Pi — Binary Systems, Inc.
# Copyright (C) 2007-2026, Binary Systems, Inc.
# Installer lineage includes work Copyright (C) 2005-2025, Ward Mundy & Associates LLC.
# VoxBox rebrand and packaging Copyright (C) 2007-2025 Binary Systems, Inc.
# This program installs Asterisk, FreePBX GUI, and VoxBox utilities.
# All programs copyrighted and licensed by their respective companies.
#
# REQUIRED BASE: Debian 13 (trixie) arm64, minimal, with SSH. No desktop.
#   Raspberry Pi 4 (2 GiB or more), Raspberry Pi 400, Compute Module 4 (2 GiB or more):
#     Debian's debian-13-raspi-arm64 image, or Raspberry Pi OS Lite 64-bit.
#   Raspberry Pi 5, Raspberry Pi 500, Compute Module 5 (2 GiB or more):
#     Raspberry Pi OS Lite 64-bit. Debian 13's own raspi image does not boot these.
# Pi 1, Pi 2, Pi Zero, Pi 3, Zero 2 W, and a 1 GiB Pi 4 are refused.
# This script checks the board, then runs VoxBox2026.sh in this directory.
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
  echo "Run VoxBox2026-RasPi.sh as root."
  exit 1
fi

if [ ! -r /proc/device-tree/model ]; then
  echo "This machine has no device-tree model. VoxBox2026-RasPi.sh is for a Raspberry Pi."
  echo "On Debian 13 amd64 or arm64, run VoxBox2026.sh."
  exit 1
fi

PI_MODEL="$(tr -d '\0' < /proc/device-tree/model)"
case "$PI_MODEL" in
  *"Raspberry Pi"*) ;;
  *)
    echo "Board: ${PI_MODEL}"
    echo "VoxBox2026-RasPi.sh is for a Raspberry Pi. On other Debian 13 hosts, run VoxBox2026.sh."
    exit 1
    ;;
esac

if [ ! -f /etc/os-release ]; then
  echo "Cannot read /etc/os-release."
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  debian|raspbian) ;;
  *)
    echo "This Pi reports ID=${ID:-unknown}. Install Debian 13 or Raspberry Pi OS Lite 64-bit."
    exit 1
    ;;
esac

codename=${VERSION_CODENAME//\"/}
if [ "$codename" != "trixie" ]; then
  echo "This Pi is ${codename:-unknown}. VoxBox 2026 needs Debian 13 (trixie)."
  echo "Use Debian's debian-13-raspi-arm64 image, or Raspberry Pi OS Lite 64-bit."
  exit 1
fi

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
if [ "$ARCH" != "arm64" ]; then
  echo "This system is ${ARCH:-unknown}. VoxBox 2026 on Raspberry Pi needs the 64-bit image."
  exit 1
fi

# Pi 5 and CM5 do not boot Debian 13's raspi image. Raspberry Pi OS identifies
# itself with /etc/rpi-issue or the raspberrypi archive. A future Debian image
# that boots these boards and carries neither file would need that image's own
# marker before this check can allow it.
case "$PI_MODEL" in
  *"Raspberry Pi 5"*|*"Raspberry Pi 500"*|*"Compute Module 5"*)
    if [ ! -f /etc/rpi-issue ] \
      && [ ! -f /etc/apt/sources.list.d/raspi.list ] \
      && [ ! -f /etc/apt/sources.list.d/raspi.sources ]; then
      echo "${PI_MODEL} needs Raspberry Pi OS Lite 64-bit (Debian 13)."
      echo "Debian's debian-13-raspi-arm64 image does not boot this board."
      exit 1
    fi
    ;;
esac

mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
if [ "${mem_kb:-0}" -lt 1400000 ]; then
  echo "${PI_MODEL} has ${mem_kb:-0} kB of RAM."
  echo "VoxBox compiles Asterisk and needs a Pi 4, 400, or Compute Module 4 with at least 2 GiB,"
  echo "or a Pi 5, 500, or Compute Module 5 with at least 2 GiB."
  echo "Pi 3, Zero 2 W, and 1 GiB Pi 4 boards are too small."
  exit 1
fi

echo "VoxBox 2026 on ${PI_MODEL} (${ARCH}, ${mem_kb} kB RAM)."
if [ "${mem_kb}" -lt 3900000 ]; then
  echo "This board has under 4 GiB. VoxBox2026.sh will add a 2 GiB swap file before the compile."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "${SCRIPT_DIR}/VoxBox2026.sh" ]; then
  echo "VoxBox2026.sh is not next to this script (${SCRIPT_DIR})."
  exit 1
fi

chmod +x "${SCRIPT_DIR}/VoxBox2026.sh"
exec "${SCRIPT_DIR}/VoxBox2026.sh"
