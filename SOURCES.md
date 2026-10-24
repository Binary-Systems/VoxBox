# VoxBox sources

Installers and the files they download live in this repo (`binary-systems.com/VoxBox` on Gitea).

## Installers

| File | Role |
|------|------|
| `VoxBox2026.sh` | Primary installer. Debian 13 netinst minimal, amd64 or arm64, FreePBX 17, Asterisk 22 or 23. |
| `VoxBox2026-RasPi.sh` | Raspberry Pi check, then `VoxBox2026.sh`. Pi 4, 400, and CM4: Debian 13 `debian-13-raspi-arm64` or Raspberry Pi OS Lite 64-bit. Pi 5, 500, and CM5: Raspberry Pi OS Lite 64-bit. Procedure: `docs/INSTALLATION.md` section 4b. |
| `VoxBox2026-EL.sh` | Same VoxBox 2026 stack on Rocky, Fedora, RHEL, and derivatives. |

Payloads are in `mirror/`. Each installer calls `voxbox_fetch`, which copies from `mirror/` when the repo is checked out. Otherwise it tries the GitHub mirror first, then Gitea:

`https://github.com/Binary-Systems/VoxBox/raw/main/mirror/<file>`

`https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/<file>`

Set `VOXBOX_GIT_TOKEN` when the Gitea URL needs authentication. Set `VOXBOX_MIRROR_BASE` to force a single remote. Harvester first-boot clones the repo, so the local copies are used.

## Mirror

| Item | Notes |
|------|--------|
| `mirror/voxbox-endpointman.tgz` | VoxBox Endpoint Manager, a FreePBX 17 module (`endpointman` 17.1.4). Source: `binary-systems.com/VoxBox-EndpointMan`. |
| `mirror/ossepm16.tgz` | Phone templates (`_ep_phone_modules/`), including Polycom splm. Do not install its bundled FreePBX 16 `endpointman/` on FreePBX 17. |
| `mirror/itslenny.tar.gz` | Lenny module. VoxBox 2026 installs it and points extension 53669 at the local prompts. |
| `mirror/freepbx-backup-20240725-17.0.17.1.tar.gz` | FreePBX backup restored by `VoxBox2026.sh`. |
| `mirror/lastupdate2024.tar.gz`, `mirror/update20241.tar.gz` through `mirror/update202415.tar.gz` | Update bundles applied by `/root/update-VoxBox`. |
| `mirror/menuselect-voxbox2025.tar.gz` | Asterisk menuselect options for the 2026 installer. |

`splm_firmware.tgz` is not in the mirror. The old public URLs did not serve it.

These still come from their own projects, not from `mirror/`:

- Asterisk source (`downloads.asterisk.org`)
- FreePBX framework (`mirror.freepbx.org`)
- VoxBox Endpoint Manager is prepackaged as `mirror/voxbox-endpointman.tgz`. Source: `https://gitea.binary-systems.com/binary-systems.com/VoxBox-EndpointMan`
- PROTEL (`github.com/vincente666/PROTEL`)
- Debian/PHP package repositories

## Copyright

Installer lineage includes work Copyright Ward Mundy & Associates LLC, licensed under the GPL, plus component copyrights (Digium, Sangoma, and others). VoxBox packaging and branding are Copyright Binary Systems, Inc.

## Not stored

- Proxmox `vzdump-qemu-ipbx2026d.vma.zst` and VirtualBox `.ova` images (multi-gigabyte VM images)
- Polycom `splm_firmware.tgz` (not published at the old download URLs)
