# VoxBox 2026

**VoxBox** is an Open, Simple, and Standard package for VoIP PBXs from **Binary Systems, Inc.**

**Tagline:** *Secure, Private Communication Infrastructure*

**VoxBox 2026** is an ultra-small Debian-based VM with Asterisk, FreePBX, emacs-nox, PROTEL (Pc/Pb + Emacs mode), and Endpoint Manager — tuned for serious enterprise deployments and Polycom SoundPoint IP 501/601 fleets, the SoundPoint IP 670, and VVX 500 and VVX 1500, without the bling of other Asterisk distributions.

## Debian 13 base + quick install

Start from **Debian 13 (trixie) netinst** with a **minimal** selection (SSH server + standard system utilities). Do not use a desktop/live image.

```bash
# On a fresh Debian 13 netinst minimal host (as root):
cd /root
# Place or clone this repo (e.g. /root/VoxBox), then:
chmod +x VoxBox2026.sh
./VoxBox2026.sh
```

The installer offers Asterisk 22 LTS (default) or Asterisk 23, builds Asterisk from source, installs FreePBX 17, emacs-nox, PROTEL toolchain, firewall/knockd, and VoxBox defaults. Progress is logged to `/root/voxbox-install-log.txt`. Reboot when prompted; admin password setup runs during install (`admin-pw-change`).

## Raspberry Pi

Pi 4, Pi 400, and Compute Module 4 (2 GiB or more) can use Debian’s `debian-13-raspi-arm64` image or Raspberry Pi OS Lite 64-bit. Pi 5, Pi 500, and Compute Module 5 use Raspberry Pi OS Lite 64-bit. The Debian image logs in as `root` with an empty password on the HDMI or serial console and has no SSH server. Raspberry Pi OS uses the user created in Imager; become root with `sudo -i`. Image write, the checksum, and the refused boards are in the installation manual, section 4b.

```bash
apt-get update
apt-get install -y git ca-certificates
cd /root
git clone --depth 1 --branch main \
  https://gitea.binary-systems.com/binary-systems.com/VoxBox.git
cd /root/VoxBox
chmod +x VoxBox2026-RasPi.sh
./VoxBox2026-RasPi.sh
```

## Rocky, Fedora, RHEL, and derivatives

On a minimal Rocky, AlmaLinux, RHEL, CentOS Stream, Oracle Linux, or Fedora system, run `VoxBox2026-EL.sh` instead. It is the same VoxBox 2026 stack, with `dnf`, EPEL, PHP 8.2, SELinux disabled, and firewalld replaced by iptables. Details are in the installation manual.

```bash
dnf -y install git ca-certificates
cd /root/VoxBox
chmod +x VoxBox2026-EL.sh
./VoxBox2026-EL.sh
```

## Existing Asterisk, FreePBX, or Incredible PBX

`upgradeToVoxBox.sh` backs up the PBX, updates the OS to the current VoxBox 2026 requirements, restores that backup, and applies the latest VoxBox overlay. If VoxBox is already installed, the same script upgrades the OS and VoxBox and then restores the configuration. It does not run the fresh installer.

```bash
chmod +x upgradeToVoxBox.sh
sudo ./upgradeToVoxBox.sh
```

The full procedure — base OS, Raspberry Pi, Harvester, first boot, firewall, and the EL installer — is in the [VoxBox Installation Manual](docs/INSTALLATION.md).

Phone users: feature codes, voicemail, Polycom sets (including the SoundPoint IP 670, VVX 500, and VVX 1500), Quawk, and Zoiper are in the [VoxBox End User Manual](docs/END-USER-MANUAL.md). Quawk’s steps are before Zoiper.


`BSI-VoxBox` is for Binary Systems configuration. `Client-VoxBox` is for other clients. Both stay on Gitea. Do not add a GitHub remote to either one, and do not enable a Gitea push mirror.

```bash
git clone --recurse-submodules https://gitea.binary-systems.com/binary-systems.com/VoxBox.git
```

The public GitHub repository is a separate history. Its first commit is the current tree, and later publishes add commits on that line only. It does not include the private submodule links or any older Gitea commits. `scripts/publish-github.sh` pushes that `github` branch to GitHub `main`. It does not push Gitea `main` or tags.

```bash
git clone https://github.com/Binary-Systems/VoxBox.git
```

## Polycom / Endpoint Manager

By default, `VoxBox2026.sh` (after FreePBX is up) will:

1. **Install and enable `tftpd-hpa`** with `TFTP_DIRECTORY=/tftpboot`, `TFTP_ADDRESS=0.0.0.0:69`, and `TFTP_OPTIONS=--secure`.
2. **Install VoxBox Endpoint Manager** from `mirror/voxbox-endpointman.tgz` (FreePBX module `endpointman` 17.1.4, [binary-systems.com/VoxBox-EndpointMan](https://gitea.binary-systems.com/binary-systems.com/VoxBox-EndpointMan)). Do not install the FreePBX 16 module bundled inside `ossepm16.tgz`.
3. **Merge phone brand/templates from `ossepm16.tgz`** (`_ep_phone_modules/`), including **Polycom `splm`** templates for SoundPoint IP **501/601** (and 301/600/4000), and **`spipm`** templates for the SoundPoint IP **670**, **VVX 500**, and **VVX 1500**.
4. Point EPM’s package server (`update_server`) at the VoxBox mirror on Gitea (`mirror/` in this repo).

**Firmware note:** Polycom binary firmware (`splm_firmware.tgz`) was not available from the old public URLs, so it is not in `mirror/`. Template install still succeeds. If firmware download fails, the installer writes `/root/VOXBOX-POLYCOM-FIRMWARE.txt`.

Phone templates come from `mirror/ossepm16.tgz`.

## Branding

The installer deploys Binary Systems assets from [`branding/`](branding/) (the fiber wordmark and the cube favicon) into FreePBX/web paths. Admin UI greyscale comes from [`branding/voxbox.css`](branding/voxbox.css) via FreePBX `BRAND_CSS_CUSTOM` (overlay only — no Framework fork). The menu bar is Admin, Applications, Connectivity, Reports, Settings, UCP. The cube opens the Dashboard. See [`branding/BRANDING.md`](branding/BRANDING.md).

## Sources

See [`SOURCES.md`](SOURCES.md) for download origins of seed installers, Lenny module, and Endpoint Manager archives.




## Harvester (VM spin-up)

To run VoxBox as a VM on a **Harvester** node (Debian 13 cloud image + cloud-init + sized instance):

See [`harvester/README.md`](harvester/README.md) — default **4 vCPU / 4 Gi RAM / 40 Gi disk**, bridged VLAN, first-boot installs from this repo.

## PROTEL toolchain

VoxBox installs the latest **PROTEL 2026** toolchain from [vincente666/PROTEL](https://github.com/vincente666/PROTEL) during `VoxBox2026.sh`:

- **`Pc`** — PROTEL compiler
- **`Pb`** — PROTEL beautifier
- **`Pc!`** — shebang runner
- **`protel-mode`** — GNU Emacs major mode (loaded via `/etc/emacs/site-start.d/`)

Install root: `/usr/local/protel` (commands symlinked into `/usr/local/bin`, already on the default shell path for every account). Generated C++ goes in `/usr/local/protel/build` (mode `1777`).  
Helper: [`protel/install-protel.sh`](protel/install-protel.sh) (shallow-clones `main`, runs `make install-system`).

## Quawk IAX Push-to-Talk relay

VoxBox can relay **Quawk** iOS P2T clients over **IAX2 (UDP 4569)**. What to type in the app is in the [End User Manual](docs/END-USER-MANUAL.md), before Zoiper.

- Per-device FreePBX IAX2 extensions + secrets (no guest)
- Default `requirecalltoken=yes` (libiax2/iaxclient spike may need `no` until confirmed — see `Quawk/README.md`)
- Codecs: ulaw first, then alaw; opus optional
- Optional Avahi discovery: `_Quawk._udp`
- Context `from-Quawk` sets Alert-Info `Ring Answer`, then continues the call in `from-internal`

Installer opens LAN UDP 4569 and runs `Quawk/install-Quawk-relay.sh` when present. Details: [`Quawk/README.md`](Quawk/README.md).

## Payloads

Installer downloads (configs, sounds, menuselect, FreePBX backup, and update bundles) live in [`mirror/`](mirror/). A clone of this repo uses those local files. Otherwise the installer tries the GitHub mirror first, then Gitea:

`https://github.com/Binary-Systems/VoxBox/raw/main/mirror/`

`https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/`

`VOXBOX_GIT_TOKEN` is used only when a payload has to be downloaded from the private Gitea remote. Set `VOXBOX_MIRROR_BASE` to force a single remote.

Asterisk source and the FreePBX framework tarball still come from their upstream project sites.

## Lineage

`VoxBox2026.sh`, `VoxBox2026-RasPi.sh`, and `VoxBox2026-EL.sh` are Binary Systems installers. Portions of the installer lineage are Copyright Ward Mundy & Associates LLC. Keep the GPL notices and third-party copyrights (Digium, Sangoma, and contributors).

Copyright © 2007–2026 Binary Systems, Inc.
