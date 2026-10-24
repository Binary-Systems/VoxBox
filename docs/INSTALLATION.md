# VoxBox Installation Manual

**Binary Systems, Inc.**

**VoxBox** is an Open, Simple, and Standard package for VoIP PBXs.

*Secure, Private Communication Infrastructure*

This manual covers a new install of **VoxBox 2026**. It is written for the person who builds the machine, runs the installer, and brings the PBX up to a first working login.

| | |
|---|---|
| Product | VoxBox 2026 (current) |
| Publisher | Binary Systems, Inc. |
| GUI | FreePBX 17, VoxBox Administration skin |
| Telephony | Asterisk 22 LTS (default) or Asterisk 23, built from source |
| Base system | Debian 13 (trixie) on amd64 or arm64, Raspberry Pi as in section 4b, or Rocky / Fedora / RHEL and derivatives, minimal |
| Manual date | 23 October 2026 |

Copyright © 2007–2026 Binary Systems, Inc.

---

## 1. What you are installing

VoxBox 2026 is a small system with the pieces of a serious PBX already wired together. The current installer is `VoxBox2026.sh` on Debian 13, and `VoxBox2026-EL.sh` on Rocky, Fedora, RHEL, and derivatives.

| Component | What VoxBox installs |
|-----------|----------------------|
| Asterisk | 22 LTS or 23, compiled on the host with the VoxBox menuselect set (Opus, SILK, Siren, G.729a, SRTP AES-256 / GCM) |
| FreePBX | 17, from the FreePBX module mirror, then a Binary Systems backup of the core configuration |
| Endpoint Manager | VoxBox Endpoint Manager 17.1.4, plus Polycom templates, including SoundPoint IP 301 / 501 / 600 / 601 / 670, SoundStation IP 4000, VVX 500, and VVX 1500 |
| TFTP | `/tftpboot`. Debian uses `tftpd-hpa`. Rocky, Fedora, and RHEL use `tftp.socket` |
| PROTEL 2026 | `Pc`, `Pb`, `Pc!`, and Emacs `protel-mode` |
| Editors | `emacs-nox` (CLI default), vim for root |
| Mail | Postfix, with an optional Gmail smarthost helper |
| Firewall | iptables, default **DROP**, plus `knockd` |
| Quawk | IAX2 relay helpers for push-to-talk (UDP 4569) |
| Identity | Hostname `noreply.voxbox.local`, login banner **VoxBox 2026 — Binary Systems, Inc.** |

VoxBox keeps Asterisk, Apache, and MariaDB in their ordinary locations and compiles Asterisk for the machine it is running on. Branding is an overlay. FreePBX is the stock program with Binary Systems logos, colors, and login screens applied on top. Webmin is not installed.

### Where the procedure comes from

VoxBox 2026 is an amalgamation of the original VoxBox ISO distribution, feature set, and skin from 2007, now updated for 2026. Binary Systems shipped that image as its own PBX: the Asterisk feature set of that generation, the VoxBox administration skin, desk-phone provisioning, voicemail, and DUNDi. VoxBox 2026 is that product on a current base. The installer, the FreePBX version, and the operating system are the 2026 generation of the same package. The product name on the machine is VoxBox.

**FreePBX 17** (Sangoma) is the administration GUI inside that package. Sangoma’s own installer targets a fresh **Debian 12** system, **PHP 8.2 only**, and current Asterisk (21 or newer; 22 is the long-term release VoxBox uses). VoxBox 2026 follows that stack. On **Debian 13**, PHP 8.2 comes from the Sury repository. On **Rocky, Fedora, RHEL, and derivatives**, PHP 8.2 comes from AppStream (`php:8.2` on EL 9) or the Remi repository (EL 8, EL 10, and Fedora when the distro PHP is newer than 8.2). Both paths install Node.js, Apache, and MariaDB. The FreePBX framework tarball still comes from `mirror.freepbx.org`. Day-to-day GUI work — Apply Config, extensions, trunks, routes, Asterisk SIP Settings — is ordinary FreePBX. Sangoma’s install notes live at [Install FreePBX](https://sangomakb.atlassian.net/wiki/spaces/FP/pages/9732130/Install+FreePBX) and the Debian 12 script is [FreePBX/sng_freepbx_debian_install](https://github.com/FreePBX/sng_freepbx_debian_install).

**Incredible PBX** (Ward Mundy & Associates LLC) supplied installer habits this manual keeps:

- One script, run as root, on a minimal OS, then reboot.
- `/root/admin-pw-change`, `/root/apache-pw-change`, `/root/timezone-setup`.
- A default-DROP firewall, port knocking, and `/root/add-ip` to trust a host.
- `pbxstatus` when root logs in, and `/root/update-VoxBox` for later patches.
- Demo extensions **701–705** restored from the VoxBox FreePBX backup.

On Rocky, AlmaLinux, RHEL, and the other derivatives, `VoxBox2026-EL.sh` uses a minimal image, `dnf` (or `yum`), EPEL, SELinux disabled, and firewalld replaced by iptables. It installs the VoxBox 2026 stack (Asterisk 22 or 23, FreePBX 17, PHP 8.2).

Default passwords and the commands that reset them are in section 3 and section 8.2 of this manual. Those programs remain under the GPL. Copyright notices for Ward Mundy & Associates LLC, Digium, Sangoma, and the other contributors stay in the installer and under `/var/www/html/admin/licenses`.

---

## 2. Choose an installer

Use **VoxBox 2026** for every new system.

| Installer | Base operating system | Telephony | When to use it |
|-----------|----------------------|-----------|----------------|
| `VoxBox2026.sh` | Debian 13 (trixie), amd64 or arm64, netinst minimal | Asterisk 22 or 23, FreePBX 17 | Current product on Debian. Bare metal, VM, or Harvester. |
| `VoxBox2026-RasPi.sh` | Debian 13 arm64 on a Raspberry Pi 4, 400, or Compute Module 4. Raspberry Pi OS Lite 64-bit (Debian 13) on those boards and on a Pi 5, 500, or Compute Module 5. 2 GiB of RAM or more. | Asterisk 22 or 23, FreePBX 17 | A Raspberry Pi. The script checks the board, then runs `VoxBox2026.sh`. |
| `VoxBox2026-EL.sh` | Rocky, AlmaLinux, RHEL, CentOS Stream, Oracle Linux 8/9/10, Fedora, and other RHEL derivatives. Minimal, amd64. | Asterisk 22 or 23, FreePBX 17 | Current product on that family. |

`VoxBox2026.sh`, `VoxBox2026-RasPi.sh`, and `VoxBox2026-EL.sh` do not check for a previous install. Run each one on a new system only. Debian 13 uses section 4 and section 5. A Raspberry Pi uses section 4b. Rocky, Fedora, RHEL, and derivatives use section 4a.

### Upgrading an existing PBX

`upgradeToVoxBox.sh` is the path for a machine that already runs Asterisk with FreePBX or Incredible PBX, and for a machine that is already VoxBox. It does not run the fresh installer and it does not load the stock demo backup.

Run it as root from a checkout of this repository:

```bash
chmod +x upgradeToVoxBox.sh
./upgradeToVoxBox.sh
```

The script saves the FreePBX databases, Asterisk configuration, AstDB, and `/tftpboot` under `/var/backups/voxbox-upgrade/`. It then updates the operating system to the current VoxBox 2026 requirement: Debian 13 package updates, or `dnf upgrade` on EL 8 and newer. A Debian host older than 13 is walked forward to trixie when FreePBX is already 17. A FreePBX 16 host stays on its current Debian release unless `VOXBOX_FORCE_DIST_UPGRADE=1` is set, because Debian 13 does not ship that GUI's PHP. EL 7 and older are backed up and then refused.

After the OS step the script restores the backup and checks that the extension, trunk, and inbound-route counts match. It then applies the current VoxBox overlay: PHP 8.2 when that is not already the `php` on the path, Emacs, PROTEL, branding, Endpoint Manager on FreePBX 17, and `fwconsole ma upgradeall`. Hostname, firewall, knock ports, and passwords are left alone. The log is `/root/voxbox-upgrade-log.txt`.

---

## 3. Requirements

### Hardware

FreePBX 17’s published floor is about **1 vCPU, 2 GiB RAM, and 20 GiB disk**. VoxBox compiles Asterisk and can install PROTEL, so use the next size up.

| Profile | CPU | RAM | Disk | Use |
|---------|-----|-----|------|-----|
| Lab | 2 | 2 GiB | 20 GiB | Compile will be slow and can run out of memory. |
| **Recommended** | **4** | **4 GiB** | **40 GiB** | New VoxBox 2026 systems. |
| Raspberry Pi | 4 | 4 GiB | 64 GB card | Pi 4, 400, CM4, Pi 5, 500, or CM5. A 2 GiB board gets a swap file (section 4b). |
| Production | 4 or more | 8 GiB | 80 GiB | Recordings, more simultaneous calls, PROTEL builds. |

Architecture for VoxBox 2026 is **amd64** or **arm64**. `VoxBox2026.sh` accepts either on Debian 13. `VoxBox2026-EL.sh` accepts the host when `/etc/os-release` names this family. The published EL path is a minimal amd64 image. Raspberry Pi boards use `VoxBox2026-RasPi.sh` (section 4b).

### Network

Give the PBX an address that phones can reach. On a virtual machine, use a **bridged** adapter or a VLAN bridge. Masqueraded NAT puts SIP, RTP, and TFTP in a corner they do not belong in.

Plan on these ports. The host firewall (section 9) still decides who may use them.

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH |
| 80, 443 | TCP | VoxBox Administration (FreePBX) and the User Control Panel |
| 5060, 5061 | UDP | SIP |
| 10000–20000 | UDP | RTP media |
| 69 | UDP | TFTP for phone provisioning |
| 4569 | UDP | IAX2, including Quawk |
| 4520 | UDP | DUNDi. Asterisk listens here when `/etc/asterisk/dundi.conf` leaves `port` at **4520**. |

The machine needs outbound internet for the whole install: operating-system packages, Asterisk source, the FreePBX tarball, Node.js, PHP 8.2, PROTEL, and the VoxBox mirror. On Rocky, Fedora, and RHEL that also means EPEL, CRB or PowerTools, and (when AppStream has no PHP 8.2) the Remi repository.

### DUNDi

DUNDi is the peer-discovery protocol from the original VoxBox feature set. Asterisk’s module is `res_dundi`. The port is **UDP 4520**.

The sample `[general]` section in `/etc/asterisk/dundi.conf` is:

```ini
[general]
bindaddr = 0.0.0.0
port = 4520
```

`bindaddr = 0.0.0.0` listens on every interface. Set `bindaddr` to one address of this machine when DUNDi should listen on that interface only. `port` stays **4520** so the firewall rules in this manual match the daemon. Each remote PBX is its own section in that file: the peer’s entity id, the department and organization you share, and the include context that peer is allowed to look up. Those values come from the two administrators. This manual does not ship a shared key.

After you edit the file:

```bash
asterisk -rx "module reload res_dundi.so"
asterisk -rx "dundi show peers"
```

Private LAN ranges are already accepted by the host firewall (section 9), so two VoxBox machines on the same LAN can exchange DUNDi without an extra rule. UDP 4520 is not open to the public Internet in the base rules. A peer on another network needs both of these:

1. On the PBX, add one line to `/usr/local/sbin/iptables-custom` for that peer’s address. The address below is a documentation address. Use the peer you actually have.

```bash
/usr/sbin/iptables -A INPUT -p udp -m udp -s 203.0.113.20 --dport 4520 -j ACCEPT
```

Then run `/usr/local/sbin/iptables-custom`. The installer runs that file at boot, so the allow comes back after a reboot.

2. On the edge firewall, a forward of UDP **4520** to the VoxBox address, limited to that peer. The OPNsense row is in the example below. Leave the forward out when every DUNDi peer is on the LAN.

### Internal and external addresses

Every example below uses documentation addresses. Substitute your own.

| Role | Example | What you need |
|------|---------|----------------|
| OPNsense LAN gateway | `192.168.50.1/24` | The firewall address phones use as their default gateway. |
| Internal LAN prefix | `192.168.50.0/24` | The subnet VoxBox and the phones share. This is FreePBX **Local Networks**. |
| VoxBox internal address | `192.168.50.10` | A static address or a DHCP reservation. Phones, TFTP, and the GUI use this on the LAN. |
| Web server internal address | `192.168.50.20` | Only when this firewall also publishes websites. |
| Phone pool | `192.168.50.100`–`192.168.50.200` | DHCP for handsets. Keep the VoxBox address outside the pool. |
| External WAN address | `203.0.113.10` | The public IPv4 on OPNsense. Carriers and remote phones send SIP, IAX, and RTP here. This is FreePBX **External Address**. |
| External DNS name | `pbx.example.com` | Optional. Publish it for remote SIP. Keep the administration GUI on the internal address. |
| Admin source | `198.51.100.20` | Optional. A single public address allowed to reach SSH. |

Give VoxBox the internal address on a bridged LAN or VLAN. Put the external address on OPNsense, and forward only the voice ports inward.

| Direction | Destination | Ports |
|-----------|-------------|--------|
| Phones and admins on the LAN | `192.168.50.10` | TCP 22, 80, 443. UDP 69, 5060–5061, 4569, 4520, 10000–20000. |
| Internet → VoxBox | `203.0.113.10` forwarded to `192.168.50.10` | UDP 4569 (IAX), 5060–5061 (SIP), 4520 (DUNDi, from peer addresses only), 10000–20000 (RTP). TCP 22 only from addresses you mean to allow. |
| Internet → websites | `203.0.113.10` answered by OPNsense | TCP 80 and 443 stay on the firewall reverse proxy, then go to the web server `192.168.50.20`. |
| Administration GUI | `http://192.168.50.10/` | LAN, VPN, or an SSH tunnel. |

When TCP 80 and 443 on the public address belong to a reverse proxy (Caddy or nginx on OPNsense), leave them there. A port forward of those two ports to VoxBox takes the proxy off the public address and the websites with it.

### OPNsense example

The clicks below match OPNsense 25.x with the sample table. **Firewall → Apply Changes** after the NAT and rule pages. In VoxBox, **Settings → Asterisk SIP Settings** then uses the same two addresses: external `203.0.113.10`, local network `192.168.50.0/24`, RTP `10000–20000`.

**1. Pin the internal address.** **Services → DHCPv4 → LAN → DHCP Static Mappings for this interface.**

| Field | Value |
|-------|--------|
| MAC address | `02:00:00:00:00:10` (the VM or NIC you actually have) |
| IP address | `192.168.50.10` |
| Hostname | `voxbox` |

A static address configured inside Debian works the same way. Keep `192.168.50.10` out of the dynamic pool.

**2. Name the hosts.** **Firewall → Aliases.**

| Name | Type | Content |
|------|------|---------|
| `voxbox_host` | Host | `192.168.50.10` |
| `web_host` | Host | `192.168.50.20` |
| `voice_lan` | Network | `192.168.50.0/24` |
| `wan_admins` | Host | `198.51.100.20` |

**3. Forward voice ports.** **Firewall → NAT → Port Forward.** Each row: interface **WAN**, destination **WAN address**, redirect target **voxbox_host**, filter rule association **Add associated filter rule**.

| Description | Protocol | Destination port | Redirect port |
|-------------|----------|------------------|---------------|
| VoxBox SIP | UDP | `5060` to `5061` | `5060` |
| VoxBox IAX | UDP | `4569` | `4569` |
| VoxBox DUNDi | UDP | `4520` | `4520` |
| VoxBox RTP | UDP | `10000` to `20000` | `10000` |

Add the DUNDi row only when a peer outside this LAN must query this PBX. Set **Source** on that row to the peer’s address. Leave it out when every DUNDi peer is on the LAN.

Add these only when an administrator needs them from the Internet. Set **Source** to `wan_admins`.

| Description | Protocol | Destination port | Redirect port |
|-------------|----------|------------------|---------------|
| VoxBox SSH | TCP | `22` | `22` |

Create no WAN port forward for TCP 80 or TCP 443 toward `192.168.50.10`.

**4. Check the WAN rules.** **Firewall → Rules → WAN.** OPNsense adds a pass rule for each forward. The voice rules should land on `192.168.50.10` and only on the ports in the table.

**5. LAN.** A default “LAN net to any” rule already lets phones reach `192.168.50.10`. On a locked-down LAN, add one pass rule: interface **LAN**, source `voice_lan`, destination `voxbox_host`, TCP `22`, `80`, `443`, UDP `69`, `5060`, `5061`, `4569`, `4520`, `10000:20000`.

**6. Outbound NAT, static port.** **Firewall → NAT → Outbound.** Set the mode to **Hybrid outbound NAT**. Add a rule above the automatic ones:

| Field | Value |
|-------|--------|
| Interface | WAN |
| Source | `192.168.50.10/32` |
| Translation / target | Interface address (`203.0.113.10`) |
| Static port | checked |

Static port keeps the RTP source port the carrier expects. Use **Firewall → NAT → One-to-One** only when `203.0.113.10` belongs to VoxBox alone. A shared public address stays on the port forwards above so the websites can keep 80 and 443.

**7. Websites on the same public address.** Install the Caddy plugin and open **Services → Caddy Web Server**. Bind HTTP and HTTPS on the WAN address, ports 80 and 443. Add a reverse proxy:

| Domain | Upstream |
|--------|----------|
| `www.example.com` | `192.168.50.20` |

That upstream is a connection from OPNsense to the web server. It is separate from a WAN port forward. Leave VoxBox off this page.

**8. Internal name for the GUI.** **Services → Unbound DNS → Overrides → Host Overrides.**

| Host | Domain | Value |
|------|--------|--------|
| `pbx` | `example.com` | `192.168.50.10` |

LAN browsers then open `http://pbx.example.com/`. External DNS for `pbx.example.com` may still point at `203.0.113.10` for remote SIP. Phones on the LAN should register to `192.168.50.10`. If a phone must use the public address from inside the LAN, enable **NAT reflection** on the three voice port forwards.

**9. GUI from outside, without publishing it.** From a workstation, tunnel through OPNsense (SSH to the firewall, then to the LAN address):

```bash
ssh -L 8080:192.168.50.10:80 root@203.0.113.10
```

Open `http://127.0.0.1:8080/` on that workstation. When TCP 22 is forwarded to VoxBox itself, the same idea is:

```bash
ssh -L 8080:127.0.0.1:80 root@203.0.113.10
```

### Time and access

A full VoxBox 2026 install is typically **45 to 120 minutes** on a PC, most of it the Asterisk compile. On a Raspberry Pi 4, plan on several hours for that compile. Stay with the session until the script asks you to reboot.

You need:

- The Debian 13 netinst image, the Raspberry Pi image in section 4b, or a minimal Rocky, Fedora, RHEL, or derivative image, for the installer you chose.
- A root shell on that machine.
- A clone of the VoxBox repository, or a Gitea token that can read `binary-systems.com/VoxBox`. The repository is private. Payloads live in `mirror/`. If that directory is not on the machine, the installer tries  
  `https://github.com/Binary-Systems/VoxBox/raw/main/mirror/<file>`  
  and then  
  `https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/<file>`  
  Set `VOXBOX_GIT_TOKEN` when the installer has to download a file from Gitea instead of copying it from a local `mirror/`.

### Emergency calls

Have a separate telephone that can place emergency calls, and test it. Finish and test an emergency route on this PBX with your own carrier before anyone depends on it. The installer lineage states that the platform, as delivered, is not an emergency-call service.

### Installer constants you will meet again

Write these down before you start. Change the ones that are yours. Leave the database root password alone unless you are ready to edit every helper that uses it.

| Item | Value | What to do |
|------|--------|------------|
| Linux `root` | The password you set in the OS installer. There is no VoxBox default. | Shell login. Change it with `passwd` when the install image used a published default. Reset procedure: section 8.2. |
| FreePBX GUI user | `admin`. No factory password. The install prompt sets it. A prompt with no terminal stores a blank password. | Set or reset with `/root/admin-pw-change`. Full steps are in section 8.2. |
| Apache web-app user | `admin`. No password until you set one. | `/root/apache-pw-change`. File `/etc/pbx/wwwpasswd`. Telephone Reminders and the other helper web apps use this login. |
| MariaDB `root` | `passw0rd` | Set by the installer. `/root/admin-pw-change`, `/root/show-passwords`, and the other root helpers pass this password. MariaDB listens on localhost. Leave it in place unless you edit every helper that uses it. |
| FreePBX database | User and password created by `./install -n` | Written in `/etc/freepbx.conf` as `AMPDBUSER` and `AMPDBPASS`. Read them there. They are not a published constant. |
| Demo extensions | **701, 702, 703, 704, 705**, plus Lenny at **53669** | Restored from the backup in this repository, so treat every secret in that backup as public. The installers then point 53669 at the local Lenny prompts. Reset with section 8.2 before a phone outside the trusted LAN can register. |
| AvantFax `admin` | None until AvantFax is installed | `/root/avantfax-pw-change`. VoxBox 2026 does not start AvantFax. The helper is on the box for sites that do. |
| Hostname | `noreply.voxbox.local` | Written by the installer. |
| Install log | `/root/voxbox-install-log.txt` | Full transcript of the script. |

---

## 4. Install Debian 13

This is the base for VoxBox 2026 on a PC or a virtual machine. Use the **netinst** image, not a live desktop image and not a cloud image, unless you are following the Harvester path in section 6. A Raspberry Pi uses section 4b.

1. Download the Debian 13 (trixie) amd64 netinst ISO from [debian.org](https://www.debian.org/distrib/netinst).
2. Boot it on the hardware or in a new virtual machine. Give the VM the size in section 3 and a bridged NIC.
3. Set language, location, and keyboard.
4. Set the hostname and domain to anything you like. The VoxBox installer later sets the hostname to `noreply.voxbox.local`.
5. **Set a root password.** If the Debian installer is left with an empty root password, root is locked and only a sudo user is created. VoxBox runs as root.
6. Create an ordinary user as well, so you can still log in if root SSH is key-only.
7. Partition the disk. Guided use of the entire disk is appropriate for a PBX appliance. Put at least 40 GiB on the root filesystem.
8. At the software selection, select **SSH server** and **standard system utilities**. Leave every desktop environment unselected.
9. Install GRUB, remove the ISO, and reboot.
10. Log in as root on the console. From another machine, SSH as the ordinary user and run `su -` if `sshd` refuses password logins for root (Debian’s usual `PermitRootLogin prohibit-password`).

Confirm the release before you continue:

```bash
cat /etc/os-release
```

`VERSION_CODENAME` should be `trixie`.

---

## 4a. Rocky, Fedora, RHEL, and derivatives

`VoxBox2026-EL.sh` installs the same VoxBox 2026 stack as section 5: Asterisk 22 or 23, FreePBX 17, PHP 8.2, Node.js, PROTEL, VoxBox Endpoint Manager, knockd, and the default-DROP iptables rules.

Start from a minimal image. The script is one run as root, then a reboot. Afterward set the passwords with `/root/admin-pw-change` and `/root/apache-pw-change`, and set the clock with `/root/timezone-setup` (section 8.2). The script turns SELinux off and replaces firewalld with iptables. It installs Asterisk 22 or 23 with FreePBX 17.

EPEL, CRB, PowerTools, Remi, NodeSource, and RPM Fusion change their repository layout more often than Debian. When PHP is not 8.2 after that setup, the script stops and prints the version it found. The transcript is `/root/voxbox-install-log.txt`.

### Supported bases

| System | What to install |
|--------|-----------------|
| Rocky Linux, AlmaLinux, RHEL, CentOS Stream, Oracle Linux | Version 8, 9, or 10. Minimal install, amd64, root password, SSH. |
| Fedora | A current release whose repositories can supply PHP 8.2 (the distro build, or Remi). Minimal install, amd64. |
| Other derivatives | Any host whose `/etc/os-release` `ID` or `ID_LIKE` contains `rhel`, `fedora`, or `centos`. |

### Install the base system

1. Boot the minimal ISO for the distribution you chose. Leave every desktop environment unselected.
2. Set a root password. VoxBox runs as root. Create an ordinary user as well, so you can still log in if root SSH is key-only.
3. Leave SELinux and firewalld as the image set them. The installer writes `SELINUX=disabled`, runs `setenforce 0`, stops firewalld, and masks it. iptables-services then owns the host firewall, with the same default-DROP rules as the Debian installer.
4. Set the hostname to anything you like. The installer later sets `noreply.voxbox.local`.
5. Partition the disk with at least 40 GiB on the root filesystem.
6. Reboot, log in as root, and confirm the family:

```bash
cat /etc/os-release
```

### Run the installer

```bash
dnf -y install git ca-certificates
cd /root
git clone --depth 1 --branch main \
  https://gitea.binary-systems.com/binary-systems.com/VoxBox.git
cd /root/VoxBox
chmod +x VoxBox2026-EL.sh
./VoxBox2026-EL.sh
```

Use a token when Gitea asks for credentials. A local clone already contains `mirror/`, so the installer copies payloads from disk.

The script prints the VoxBox terms and waits for Enter. It then asks the same Asterisk question as section 5.2. To skip both prompts:

```bash
export VOXBOX_ASTERISK=22          # or 23
export VOXBOX_NONINTERACTIVE=1
./VoxBox2026-EL.sh
```

While Asterisk’s `install_prereq` runs it can ask for the ITU-T telephone country code. Enter your code (`1` for the North American Numbering Plan). Then leave the keyboard alone until `/root/admin-pw-change` or the final reboot prompt.

The shared sequence — Asterisk compile, FreePBX 17, the VoxBox backup, firewall, branding, knockd, Endpoint Manager, Quawk — is the list in section 5.3. On this family the script does the following in place of the Debian package steps:

| Piece | What the EL installer uses |
|-------|----------------------------|
| Packages | `dnf`, EPEL, and CRB (EL 9 and newer) or PowerTools (EL 8) |
| PHP 8.2 | AppStream module `php:8.2` on EL 9. Remi `php:remi-8.2`, or the Remi `php82` collection, when the distro PHP is not 8.2 |
| Web server | `httpd`, running as the `asterisk` user. PHP runs in `php-fpm` |
| PHP settings | `/etc/php.ini` (or `/etc/opt/remi/php82/php.ini` when the Remi collection is in use) |
| Database | `mariadb`. Root password `passw0rd`, same as section 3 |
| Firewall | `iptables-services`. The rule file is `/etc/sysconfig/iptables` and a copy is kept at `/etc/iptables/rules.v4`. firewalld is masked |
| Port knock | `knockd` from EPEL. Options are in `/etc/sysconfig/knockd` |
| TFTP | `tftp.socket`, directory `/tftpboot`, `in.tftpd -s` |
| Clock | `chronyd`. The preferred source is the default gateway. The PBX does not serve NTP |
| Cache | `redis` |
| Mail | Postfix. The Gmail smarthost helper in `/root` is rewritten so its package commands use `dnf` |
| Codecs | `ffmpeg`, `lame`, and `mpg123` from RPM Fusion when that repository answers. A missing helper is logged and the install continues |
| Status screen | `pbxstatus` looks for `/usr/sbin/httpd` and titles the screen with the host’s own OS name |
| Boot | `rc-local.service` runs `/etc/rc.local`, which starts knockd, reloads iptables, restarts PHP, and runs `fwconsole restart` |

Press Enter at the reboot prompt. On the next boot, give the machine a full minute before you open the GUI. Then follow section 8. The noninteractive run has no keyboard for `/root/admin-pw-change`. Set the GUI password after reboot:

```bash
/root/admin-pw-change
/root/timezone-setup
```

Check TFTP with:

```bash
systemctl status tftp.socket
ss -ulpn | grep ':69'
```

---

## 4b. Raspberry Pi

`VoxBox2026-RasPi.sh` is the Raspberry Pi installer. Run it as root. It checks the board and the operating system, then runs `VoxBox2026.sh`. The telephony stack is the same one as section 5: Asterisk 22 or 23 compiled on the Pi, FreePBX 17, PHP 8.2 from the Sury repository, Node.js 24, PROTEL, VoxBox Endpoint Manager, knockd, and the default-DROP iptables rules. Service names after install are the Debian names in section 17.

Use a card of at least **64 GB** and a wired Ethernet connection. Leave the desktop uninstalled. When the kernel reports under about 3.7 GiB of RAM, `VoxBox2026.sh` adds a 2 GiB swap file at `/swapfile` and a line in `/etc/fstab`. Every 2 GiB board takes that path. A 4 GiB board usually does not.

| Board | RAM | Image |
|-------|-----|--------|
| Raspberry Pi 4 Model B | 4 GiB or 8 GiB | Debian 13 raspi image, or Raspberry Pi OS Lite 64-bit |
| Raspberry Pi 4 Model B | 2 GiB | Same images. The installer adds swap. The compile is slow and can still run out of memory. |
| Raspberry Pi 400 | 4 GiB | Same images as the Pi 4 |
| Compute Module 4 | 4 GiB or 8 GiB | Same images as the Pi 4, on a carrier with Ethernet |
| Compute Module 4 | 2 GiB | Same images, with the swap file |
| Raspberry Pi 5 | 4 GiB, 8 GiB, or 16 GiB | Raspberry Pi OS Lite 64-bit |
| Raspberry Pi 500 | 8 GiB | Raspberry Pi OS Lite 64-bit |
| Compute Module 5 | 4 GiB or more | Raspberry Pi OS Lite 64-bit, on a carrier with Ethernet |

Debian’s own Raspberry Pi image does not boot a Pi 5, a Pi 500, or a Compute Module 5. Those boards use Raspberry Pi OS Lite 64-bit, which is Debian 13. A 2 GiB Pi 5 or Compute Module 5 gets the same swap file as a 2 GiB Pi 4. The installer refuses Pi 1, Pi 2, Pi Zero, Pi 3, Zero 2 W, a 1 GiB Pi 4, a 1 GiB Compute Module 4, and 32-bit Raspberry Pi OS. It also refuses a system whose `VERSION_CODENAME` is not `trixie`.

### Debian 13 image (Pi 4, Pi 400, Compute Module 4)

This image is arm64, with no desktop and no SSH server. The first login is on the HDMI console or the serial console.

1. Download the image and its checksum:

```bash
wget https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-raspi-arm64.tar.xz
sha512sum -c SHA512SUMS --ignore-missing
```

2. Find the card with `lsblk`. Write to that device, not to the disk that holds the machine you are typing on. This erases the card. Replace `sdX` with the card.

```bash
tar -xOf debian-13-raspi-arm64.tar.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

3. Boot the Pi on Ethernet. At the console login, the user is `root` and the password is empty. Press Enter.
4. Set a root password before you do anything else. VoxBox runs as root.

```bash
passwd
```

5. Confirm the release:

```bash
cat /etc/os-release
dpkg --print-architecture
```

`VERSION_CODENAME` is `trixie`. The architecture is `arm64`. Stay on this console for the install. The image has no ordinary user, and Debian’s SSH daemon does not accept the root password. `VoxBox2026.sh` installs OpenSSH during the run. After the reboot, add an SSH key for root, or create a user, before you expect a remote shell.

### Raspberry Pi OS Lite 64-bit (every board in the table)

1. Use Raspberry Pi Imager. Choose **Raspberry Pi OS Lite (64-bit)**. That image is Debian 13. Do not choose a desktop image, and do not choose the 32-bit image.
2. In Imager’s settings, enable SSH and create the user this image asks for. Set the hostname to anything you like. The VoxBox installer later sets `noreply.voxbox.local`.
3. Boot on Ethernet. The first start may grow the root filesystem and reboot once. Let it finish. Log in as the user you created, then become root and set a root password:

```bash
sudo -i
passwd
```

4. Confirm `trixie` and `arm64` with the same two commands as the Debian image.

### Run the installer

On the Debian image, run this on the console as root. On Raspberry Pi OS, run it in the root shell from `sudo -i`.

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

Use a token when Gitea asks for credentials. The script prints the board name and the RAM it sees, then asks the same Asterisk 22 or 23 question as `VoxBox2026.sh`. The log is `/root/voxbox-install-log.txt`. Leave the session open through the compile. At the end the script reboots. Then follow section 8. Set the GUI password with `/root/admin-pw-change` when that prompt had no terminal. The administration page is on the Pi’s LAN address. The firewall in section 9 still decides who may connect.

The Debian installer rewrites `/etc/apt/sources.list` to the Debian 13 lines. It leaves `/etc/apt/sources.list.d/raspi.list` and `raspi.sources` in place, and copies a Raspberry Pi archive line out of `sources.list` before that rewrite. PHP 8.2 comes from the Sury repository for arm64. The ODBC driver path follows the architecture. The G.729a menuselect option is requested; when that codec is not in the Asterisk source, the build continues and the log says so.

---

## 5. Run the VoxBox 2026 installer

This section is the Debian 13 run. A Raspberry Pi uses section 4b and `VoxBox2026-RasPi.sh`, which then runs this installer. Rocky, Fedora, RHEL, and derivatives use section 4a and `VoxBox2026-EL.sh`.

### 5.1 Get the repository

On the new host, as root:

```bash
apt-get update
apt-get install -y git ca-certificates
cd /root
git clone --depth 1 --branch main \
  https://gitea.binary-systems.com/binary-systems.com/VoxBox.git
cd /root/VoxBox
```

Use a token when Gitea asks for credentials. A local clone already contains `mirror/`, so the installer copies payloads from disk.

If the repository is already on the machine somewhere else, run `VoxBox2026.sh` from that directory. The script looks for `mirror/` and `branding/` next to itself, in `/root/VoxBox`, and in `/opt/voxbox`.

### 5.2 Start it

```bash
cd /root/VoxBox
chmod +x VoxBox2026.sh
./VoxBox2026.sh
```

The script logs everything to `/root/voxbox-install-log.txt` as it runs.

The first question is the telephony version:

```text
Asterisk 22 LTS is installed by default. Would you prefer Asterisk 23? (y/n):
```

Answer `n` for Asterisk 22 LTS. Answer `y` only when you want Asterisk 23. To skip the question:

```bash
export VOXBOX_ASTERISK=22          # or 23
export VOXBOX_NONINTERACTIVE=1
./VoxBox2026.sh
```

`VOXBOX_NONINTERACTIVE=1` also selects 22 when `VOXBOX_ASTERISK` is unset. A script with no terminal (cloud-init, a pipe) takes the same default.

### 5.3 What the script does, in order

You do not type these steps. They are here so a long, quiet compile still looks like progress. Watch the log if the console is still.

1. Turns off IPv6 and points `/etc/resolv.conf` at `8.8.8.8`, `1.1.1.1`, and `4.4.4.4`.
2. Writes a Debian 13 apt list (`main`, `contrib`, `non-free`, `non-free-firmware`) and upgrades the base system.
3. Installs Node.js 24, PHP 8.2 and the extensions FreePBX needs, then removes other PHP versions. FreePBX 17 speaks PHP 8.2.
4. Installs the build tools, Apache, MariaDB, ODBC, and the Asterisk libraries.
5. Installs `emacs-nox` and the PROTEL 2026 toolchain from GitHub (`Pc`, `Pb`, `Pc!`, Emacs mode). A PROTEL failure is logged and does not stop the PBX install.
6. Builds iksemel, then downloads Asterisk 22 or 23 from `downloads.asterisk.org`, loads `mirror/menuselect-voxbox2025.tar.gz`, and compiles with bundled pjproject and jansson.
7. Creates the `asterisk` user, then installs FreePBX 17 with `./install -n` and the standard module set (`superfecta`, `queueprio`, `miscdests`, `miscapps`, `outcnam`, `dynroute`, `extensionsettings`, `disa`, `allowlist`, and the rest of `installall`).
8. Restores `mirror/freepbx-backup-20240725-17.0.17.1.tar.gz`. That backup carries the VoxBox core configuration, including demo extensions 701–705 and the Lenny extension 53669. The backup dials a retired external SIP URI for 53669. The installer then installs `mirror/itslenny.tar.gz` and points 53669 at the local prompts (`Local/s@app-nv-itslenny/n`), including the Asterisk database entry a reload does not rewrite.
9. Sets the MariaDB root password, generates the FreePBX ARI credentials, and loads the firewall rules. The address of the host, the address you are SSH’d from, and the host’s public address are trusted completely.
10. Installs Fail2Ban, the Binary Systems logos, `voxbox.css`, and the VoxBox login, menu, and footer.
11. Installs `knockd` and writes three random TCP knock ports to `/root/knock.FAQ`.
12. Sets the hostname, issue banner, and `/etc/motd` to VoxBox 2026. The message of the day is two lines: “VoxBox 2026 — Binary Systems, Inc.” and “Secure, Private Communication Infrastructure.”
14. Runs `/root/admin-pw-change` and asks you for the FreePBX `admin` password. Choose a long one. This is the password for the GUI.
15. Installs Postfix, Redis, the PKCS bundle, and `tftpd-hpa`.
16. Installs VoxBox Endpoint Manager from `mirror/voxbox-endpointman.tgz` and merges Polycom templates from `mirror/ossepm16.tgz`. The package server is the VoxBox mirror.
17. Tries to fetch Polycom `splm_firmware.tgz`. When that file is absent, templates are still installed and `/root/VOXBOX-POLYCOM-FIRMWARE.txt` explains where to put firmware you are licensed to use.
18. Opens LAN access for IAX2 (UDP 4569) and, when the repo is present, runs `Quawk/install-Quawk-relay.sh`.
19. Asks you to press Enter, then reboots.

While Asterisk’s `install_prereq` runs it can ask:

```text
Enter the ITU-T telephone code for your country:
```

Enter your code. The code for the North American Numbering Plan is `1`. Then leave the keyboard alone until the FreePBX password prompt or the final reboot prompt.

### 5.4 Reboot prompt

```text
Press Enter to reboot or Ctrl-C to exit...
```

Press Enter. Ctrl-C leaves the machine installed and running, and you reboot yourself when you are ready:

```bash
/usr/local/sbin/reboot
```

On the next boot, `/etc/rc.local` starts knockd, reloads the firewall, waits about half a minute, and runs `fwconsole restart`. Give the machine a full minute before you open the GUI.

---

## 6. Harvester (cloud-init)

Use this when the PBX is a VM on a Harvester cluster. First boot clones the private repository and runs `VoxBox2026.sh` without questions. The manifests live in [`harvester/`](../harvester/README.md).

### 6.1 Before you apply anything

1. A Harvester cluster network on the voice VLAN (example: `voice` on `192.168.50.0/24`).
2. `kubectl` aimed at the Harvester management cluster, or the Harvester UI.
3. A Gitea token with **read** access to `binary-systems.com/VoxBox`.
4. Your SSH public key.
5. The size in `harvester/vm-voxbox-from-secret.yaml`: **4 vCPU, 4 GiB RAM, 40 GiB** disk. Other sizes are listed in `harvester/sizes.yaml`.

Edit `harvester/user-data.yaml`:

- `ssh_authorized_keys` — your key. The cloud user is `voxbox` and has passwordless sudo.
- `VOXBOX_GIT_TOKEN` — the Gitea token. A token left as `REPLACE_WITH_GITEA_TOKEN` makes first boot exit. The error is in `/var/log/voxbox-firstboot.log`.
- `VOXBOX_ASTERISK` — `22` or `23`.

Edit `networkName` in `harvester/vm-voxbox-from-secret.yaml` so it names your real Harvester network.

### 6.2 Bring the VM up

```bash
cd harvester
kubectl apply -f image-debian13.yaml
# wait until the VirtualMachineImage is ready
./render-secret.sh
kubectl apply -f vm-voxbox-from-secret.yaml
kubectl -n default get vmi,vm,pvc | grep voxbox
```

The image manifest downloads Debian’s generic cloud image:

`https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2`

You can upload that file yourself with **Images → Create** instead of `kubectl apply`.

### 6.3 Watch first boot

```bash
ssh voxbox@<vm-ip>
sudo tail -f /var/log/voxbox-firstboot.log
```

Cloud-init enables SSH and the guest agent, writes `/etc/voxbox/install.env`, clones the repo to `/opt/voxbox`, and starts `VoxBox2026.sh` in the background. The clone URL has the token in it only for the clone. The script then points `origin` back at the token-free URL.

When the log says the first boot finished, reboot if the installer has not already done so. Then open VoxBox Administration on the **LAN address**.

The noninteractive run does not have a keyboard for `/root/admin-pw-change`. After the reboot, become root and set the GUI password before anyone else uses the box:

```bash
sudo -i
/root/admin-pw-change
```

Revoke the bootstrap token once the machine is up, or keep it read-only and scoped to this repository.

A second VM needs its own names: `metadata.name`, the PVC name, and the hostname. Clone the YAML. Do not boot two guests with the same identity.

---

## 8. First boot checklist

Do this on the console or over SSH as root, after the reboot, before you put phones on the system.

### 8.1 Let the login scripts finish

Root’s `~/.bash_profile` runs two commands:

1. `/root/update-VoxBox` — downloads `lastupdate2024` from the VoxBox mirror and runs it. That bundle applies `update20241` through `update202415`.
2. `pbxstatus -p` — prints the platform summary.

The updater stops and asks you to press Enter. Read the prompt. The bundle is tested before it is published, and it is still applied at your own risk. Press Enter to take the updates, or Ctrl-C to skip them for this login. `pbxstatus` still runs.

When you want the same update later:

```bash
/root/update-VoxBox
```

### 8.2 Passwords and how to reset them

The defaults are in section 3. Every reset below is run as root on the PBX. None of them is a web link.

| Account | Default | Reset |
|---------|---------|--------|
| Linux `root` | The password from the OS installer. VoxBox does not set one. | `passwd`. Type the new password twice. |
| FreePBX GUI `admin` | Whatever you typed at the install prompt. Blank if that prompt had no terminal. | `/root/admin-pw-change` |
| Apache helper apps `admin` | None until the command below has been run. | `/root/apache-pw-change` |
| MariaDB `root` | `passw0rd` | Leave this value. The helpers pass it on the command line. |
| FreePBX database user | The user and password in `/etc/freepbx.conf`. | Read `/etc/freepbx.conf`. Change it only together with that file. |
| Extensions 701–705 | The secrets in the published backup. Treat them as public. | `/root/reset-extension-passwords`, then the GUI if the extension is PJSIP. |
| Voicemail PINs | Printed by `/root/show-passwords`. | The extension’s Voicemail tab, or the user dials `*98`. |
| Conference `2663` | Printed by `/root/show-passwords`. | **Applications → Conferences**. |
| AvantFax `admin` | None until AvantFax is installed. | `/root/avantfax-pw-change` |

**FreePBX Administration.** `/root/admin-pw-change` asks for a new password, asks you to press Enter, and stores the SHA1 of what you typed in `asterisk.ampusers` for username `admin`. It then prints the GUI URL. Blank input is a blank password. Type a real one.

FreePBX 17 checks a separate `password` column on that row before it checks the SHA1. When the GUI still rejects the password you just set, clear that column and run the script again:

```bash
mysql -u root -ppassw0rd asterisk -e "UPDATE ampusers SET password='' WHERE username='admin' LIMIT 1;"
/root/admin-pw-change
```

Log in, then set the lasting password under **Admin → Administrators**. That page writes the hash FreePBX 17 uses from then on. The `admin` user remains the one this script updates.

**Linux root.** `passwd` changes the shell password. It does not change the GUI.

**Apache helper apps.** `/root/apache-pw-change` asks for a password and refuses a blank one. It runs `htpasswd -cb /etc/pbx/wwwpasswd admin <password>` and replaces the `admin` line in that file. Telephone Reminders and the other helper web pages use this login. The same job by hand:

```bash
htpasswd -cb /etc/pbx/wwwpasswd admin 'new-password'
```

**Extension secrets.** `/root/show-passwords` asks for a start and end extension. Press Enter to accept **701** and **705**. It prints the SIP secret and the voicemail PIN for each extension in that range, the user and admin PINs for conference **2663**, the Telephone Reminders authenticate code, and the Anveo outbound PIN when one is configured.

`/root/reset-extension-passwords` writes new secrets for extensions **701** through **705** into the chan_sip `sip` table, reloads FreePBX, and then runs `/root/show-passwords`. VoxBox 2026 creates ordinary extensions as PJSIP. When the extension’s secret in **Applications → Extensions** does not match what the script printed, set a new secret on that page and Apply Config. Do that before any of these extensions can register from outside the trusted LAN.

**AvantFax.** `/root/avantfax-pw-change` asks for a password, asks you to press Enter, and stores the MD5 of that password for AvantFax user `admin`. Skip it when AvantFax is not installed. VoxBox 2026 does not start AvantFax.

**MariaDB.** The installer sets the database root password to `passw0rd`. Confirm with:

```bash
mysql -u root -ppassw0rd -e "SELECT 1;"
```

Changing it without editing `/root/admin-pw-change`, `/root/show-passwords`, `/root/reset-extension-passwords`, `/root/avantfax-pw-change`, and the other root helpers leaves those scripts unable to log in. The database listens on localhost. The host firewall stays in front of it.

### 8.3 Clock

```bash
/root/timezone-setup
```

The helper is the interactive zone picker shipped with the platform. On Debian you can do the same job with:

```bash
dpkg-reconfigure tzdata
```

Confirm with `date`. Call detail records and provisioning files follow this clock.

### 8.4 Extension secrets

The restored backup includes extensions **701–705** and **53669** (Lenny). Treat every secret in that backup as public, because the backup is in the repository. The installer rewrites 53669 so it plays the local Lenny prompts.

Print and reset those secrets with the commands in section 8.2 (`/root/show-passwords` and `/root/reset-extension-passwords`). On a PJSIP extension, set the secret again under **Applications → Extensions** and Apply Config. Voicemail PINs are changed on the extension’s Voicemail tab, or by the user dialing `*98` and the extension number.

### 8.5 Status

`pbxstatus` (no arguments) prints the platform picture: Asterisk, FreePBX, trunks, and the services the banner knows about. Run it whenever you log in as root. A healthy box shows Asterisk and Apache up, and FreePBX at the 2026 version stamp (`/etc/pbx/.version` contains `2026`).

---

## 9. Firewall, knocking, and trusted hosts

The ruleset is the one shipped with this installer lineage (Travelin’ Man style). Policy on the INPUT chain is **DROP**.

These sources may reach every port:

- Loopback.
- `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` (private LAN).
- `10.8.0.0/24` (the OpenVPN range the rules expect).
- `100.64.0.0/10` (added by the installer for carrier-grade NAT).
- Three addresses captured at install time: the host’s own address, the SSH client you installed from, and the public address reported by `ipinfo.io`. They are written into `/etc/iptables/rules.v4`. On Rocky, Fedora, and RHEL the same file is also installed as `/etc/sysconfig/iptables`, which `iptables.service` loads. firewalld is masked on that path.

From any other address, the rules accept a short list that includes **UDP 4569** (IAX) and **UDP 10000–20000** (RTP). **SSH (TCP 22), the GUI (TCP 80 and 443), SIP (UDP 5060), and DUNDi (UDP 4520) are not open to the world** in the base rules. They work from the LAN and from the three addresses captured at install time. A remote DUNDi peer is allowed with the UDP 4520 line in section 3.

That is why a PBX you installed from the office may refuse you from home. Trust the new address, or knock.

### Trust an address

```bash
/root/add-ip office 203.0.113.10
```

The name has no spaces. The second argument is one IPv4 address (four decimal octets). The script explains that it opens SIP and IAX toward that address and asks you to press Enter. Read it. A trusted address is a full hole in the PBX firewall.

SIP providers belong in `/usr/local/sbin/iptables-custom`, which the installer re-runs at boot. Sample provider lines in that file are commented out. Add the provider addresses you actually use, then run:

```bash
/usr/local/sbin/iptables-custom
```

### Port knocking

`knockd` is enabled. During install it picks three TCP ports between 6001 and 9950 and writes them to `/root/knock.FAQ`. A correct sequence from a host inserts an ACCEPT rule for that host. The rule is removed after **3600 seconds**.

Read the file on the server:

```bash
cat /root/knock.FAQ
```

From the remote machine, with `nmap` installed, knock in the order the file lists (`$knock1`, then `$knock2`, then `$knock3`):

```bash
nmap -p <knock1> --max-retries 0 <pbx-public-ip> \
  && nmap -p <knock2> --max-retries 0 <pbx-public-ip> \
  && nmap -p <knock3> --max-retries 0 <pbx-public-ip>
```

The same sequence is what iOS PortKnock and Android DroidKnocker send. Knocking opens the host to that source address. It is not a substitute for a password.

If you lock yourself out and you cannot knock, use the virtual-machine console or the physical keyboard. The LAN ranges stay accepted, so a console session on the box can always repair `/etc/iptables/rules.v4`.

### Fail2Ban

Fail2Ban is installed and started. Its alert address is set to `devnull@localhost` so an unconfigured mailer does not generate a stream of notices. Point it at a real mailbox when outbound mail works.

---

## 10. Sign in

Wait until `pbxstatus` shows Asterisk and Apache running.

### VoxBox Administration (FreePBX)

On a machine that the firewall trusts:

```text
http://<lan-address>/
```

The landing page is the VoxBox login. It offers two destinations:

- **VoxBox Administration** — the FreePBX GUI, user `admin`, password from `/root/admin-pw-change`.
- **User Control Panel** — the FreePBX UCP, for extension users.

The administration GUI itself is also at `http://<lan-address>/admin`.

The page title is **VoxBox Admin**. The dashboard brand is **VoxBox 2026**. The navbar logo is the cube favicon, and it opens the Dashboard. The menu bar is Admin, Applications, Connectivity, Reports, Settings, UCP. The VoxBox Overview widget shows the animated fiber wordmark above “Welcome to VoxBox 2026”, and that wordmark opens `https://www.binary-systems.com/VoxBox/`. Colors are the Binary Systems white, black, and grey, with link blue `#005FA5`.

If the browser is redirected and the certificate is unknown, that is FreePBX’s certificate manager. You can proceed to the LAN address you just installed, or use plain HTTP on the LAN while you load a certificate you control.

Bookmarks:

| What | Where |
|------|--------|
| Administration | `http://<lan-address>/admin` |
| User Control Panel | `http://<lan-address>/ucp` |

### Shell

```bash
ssh root@<lan-address>
# or: ssh voxbox@<lan-address> && sudo -i     # Harvester cloud image
pbxstatus
fwconsole status
asterisk -rx "core show version"
```

Asterisk is started by `freepbx.service` (`fwconsole start`), not by a separate enabled `asterisk.service`. The installer disables the stock Asterisk unit so FreePBX owns the start and stop.

---

## 11. First configuration in the GUI

This is standard FreePBX work, done on the VoxBox skin. Change one area, press the red **Apply Config** button, and confirm the bar goes away before you start the next area.

### 11.1 Confirm the platform

1. Sign in to VoxBox Administration.
2. Read the dashboard. It should identify **VoxBox 2026** and a running Asterisk 22 (or 23).
3. Open **Admin → Module Admin**. Let it refresh. Install updates you intend to run. Leave commercial Sangoma modules you do not have a license for uninstalled.
4. Apply Config.

Module updates replace FreePBX files. They do not replace `/var/www/html/admin/voxbox.css` or the VoxBox login view. If a later update restores the stock look, re-apply branding (section 14).

### 11.2 Asterisk SIP Settings

Phones on a private LAN, and any trunk that sends media to a public address, need this page filled in. FreePBX does not guess the NAT layout.

1. **Settings → Asterisk SIP Settings**.
2. On the **General SIP Settings** / **chan_pjsip** tabs, set:
   - **External Address** — the public address clients outside your LAN should use, or leave it empty when every phone and trunk is on the same LAN.
   - **Local Networks** — the LAN CIDR, for example `192.168.50.0/24`.
3. Set the UDP media range to **10000–20000**, which matches the firewall.
4. Submit, then Apply Config.

### 11.3 Extensions

1. **Applications → Extensions → Add Extension**.
2. Choose **chan_pjsip** (labeled PJSIP / SIP) for ordinary desk phones. Choose **IAX2** for Quawk and other IAX clients.
3. Set the extension number, display name, and a unique secret. The secret is the phone’s password.
4. On the Voicemail tab, set a PIN that is not the extension number.
5. Submit, then Apply Config.

For each restored demo extension (701–705), open it and replace the secret, or delete the extension if you will not use it. Extension 53669 is Lenny. A 2026 install points it at the local prompts. Leave that dial string in place.

Codec order for ordinary SIP phones can stay on the FreePBX defaults. For a Quawk handset, disallow everything and allow **ulaw**, then **alaw**. Leave **require call token** on for IAX2. Turn it off on that one extension only when the client is unpatched libiax2, which does not implement Asterisk CALLTOKEN. Details are in [`Quawk/README.md`](../Quawk/README.md).

### 11.4 Trunks and routes

1. **Connectivity → Trunks → Add Trunk**. Use the PJSIP trunk your carrier documents. Put the carrier’s signaling addresses in `/usr/local/sbin/iptables-custom` (section 9) when those addresses are outside the LAN.
2. **Connectivity → Outbound Routes**. Point a route at the trunk. Put emergency and local patterns where your dial plan expects them, and test from a handset you control.
3. **Connectivity → Inbound Routes**. Point each DID at an extension, ring group, or IVR.
4. Apply Config after each of those pages.

### 11.5 A phone, end to end

1. Reset one extension secret and Apply Config.
2. On the phone, set the SIP server to the VoxBox LAN address, the user to the extension, the password to the secret, and the transport to UDP.
3. Watch the registration:

   ```bash
   asterisk -rx "pjsip show contacts"
   ```

4. Call another extension, or call the feature codes `pbxstatus` and **Admin → Feature Codes** list. Two-way audio confirms RTP. One-way audio almost always means the local network or the external address on the SIP Settings page is wrong, or UDP 10000–20000 is blocked on a firewall in front of this host.

### 11.6 Administrators

**Admin → Administrators** adds people who may use VoxBox Administration. The `admin` user remains the one `/root/admin-pw-change` updates.

---

## 12. Phones and Endpoint Manager

VoxBox 2026 installs this for you. Use the GUI to attach a phone. Use the notes below when a phone does not pull a config.

| Item | Value |
|------|--------|
| TFTP daemon | `tftpd-hpa` on Debian. `tftp.socket` on Rocky, Fedora, and RHEL |
| TFTP root | `/tftpboot` |
| Bind | `0.0.0.0:69`, option `--secure` |
| File owner | `asterisk` |
| Module | VoxBox Endpoint Manager 17.1.4 at **Settings → VoxBox Endpoint Manager** |
| Templates | `/var/www/html/admin/modules/_ep_phone_modules`, including Polycom `splm` |
| Package server | `https://gitea.binary-systems.com/binary-systems.com/VoxBox/raw/branch/main/mirror/` |

The package server is the VoxBox Gitea mirror. The FreePBX 16 copy of Endpoint Manager that sits inside `ossepm16.tgz` is not installed. Only its phone-brand templates are copied in.

Polycom firmware is a separate file, `splm_firmware.tgz`, and it is not in the mirror. Templates still install. When the firmware fetch fails, read `/root/VOXBOX-POLYCOM-FIRMWARE.txt`. Place firmware you are licensed to serve under:

```text
/var/www/html/admin/modules/_ep_phone_modules/endpoint/polycom/splm/
```

and the files the phone requests under `/tftpboot/`.

Check the daemon:

```bash
systemctl status tftpd-hpa       # Debian
systemctl status tftp.socket     # Rocky, Fedora, RHEL
ss -ulpn | grep ':69'
```

Point the phone’s provisioning server at the VoxBox LAN address, protocol TFTP. In Endpoint Manager, assign the extension to the Polycom template, save, and reboot the phone. The SoundPoint IP 670, VVX 500, and VVX 1500 are in the `spipm` templates. The legacy `splm` set remains SoundPoint IP 301 / 501 / 600 / 601 and SoundStation IP 4000.

---

## 13. PROTEL

VoxBox 2026 installs PROTEL from <https://github.com/vincente666/PROTEL> when `protel/install-protel.sh` is next to the installer.

| Command | Role |
|---------|------|
| `Pc` | PROTEL compiler |
| `Pb` | PROTEL beautifier |
| `Pc!` | Shebang runner |
| Emacs | `protel-mode`, loaded from `/etc/emacs/site-start.d/50protel-mode.el` |

Files live in `/usr/local/protel`, with symlinks in `/usr/local/bin`. That directory is already on the default shell path, including `sudo`, so every account can run the commands. `Pc` writes generated C++ in `/usr/local/protel/build`, which the installer creates mode `1777` (sticky and writable by every user). Confirm with:

```bash
Pc --version
Pb --version
```

To install it again later, on a finished host:

```bash
/root/VoxBox/protel/install-protel.sh
```

A failure during the main installer is non-fatal. The PBX still comes up. The message in `/root/voxbox-install-log.txt` is `WARN: PROTEL install failed`.

---

## 14. Branding

Logos, the grey stylesheet, and the login page are applied by the installer from the `branding/` directory. FreePBX stores the skin in **Advanced Settings** (`BRAND_CSS_CUSTOM` = `voxbox.css`, `VIEW_LOGIN` = the VoxBox login, `VIEW_MENU` = the VoxBox menu). Framework upgrades leave those files in place.

Re-apply FreePBX branding:

```bash
bash /root/VoxBox/branding/apply-voxbox-branding.sh
```

FreePBX 17 installs then replace the stock System Dashboard, User Control Panel, and VoxBox module with the signed packages in `mirror/`. That step is `branding/install-signed-modules.sh`. It keeps the Node card, the wide Notepad, the "VoxBox Statistics" title, and the footer logo mat, and it installs the local signatures. It does not run the Dashboard or User Control Panel `install()` methods. An empty System Identity, or the placeholders VoIP Server and Dashboard, becomes the machine hostname.

The product page linked from the GUI is <http://www.binary-systems.com/VoxBox/>.

---

## 15. Mail, fax, time, and updates

### Mail

Postfix is installed. Sendmail is present earlier in the install and is then superseded. To relay through Gmail, the helper shipped on the box is:

```bash
/root/enable-gmail-smarthost-with-postfix
```

Run it only when you have a Gmail account and an app password ready to paste in. Until you do, local mail (Fail2Ban, fax-to-email) stays on the machine.

### Fax

The installer adds `libtiff-tools` and Ghostscript, and a `[custom-fax-iaxmodem]` context in `/etc/asterisk/extensions_custom.conf`. `FAXEMAIL` in that context is empty until you set the address that should receive incoming faxes. VoxBox 2026 does not start HylaFAX or AvantFax, and the installer removes the old Incredible Fax scripts.

### Clock sync

`chrony` is installed. On Debian the unit is `chrony` and the preferred source is `/etc/chrony/sources.d/voxbox-router.sources`. On Rocky, Fedora, and RHEL the unit is `chronyd` and the preferred source is the first `server` line in `/etc/chrony.conf`. That source is the host’s default gateway. Combined with `/root/timezone-setup`, this is the clock FreePBX and CDR use. The PBX does not serve NTP. A phone uses the NTP server advertised by the router at its own site.

### Later Asterisk 23

When you installed Asterisk 22, the file `/root/upgrade-asterisk` is placed on the box for a later move to Asterisk 23. Read the script before you run it. It is a major upgrade, and it belongs in a maintenance window.

### Updates

`/root/update-VoxBox` pulls the current update bundle from the VoxBox mirror and runs it. Run it from a console session you can watch. The first root login already offers it (section 8.1).

FreePBX module updates are a separate step: **Admin → Module Admin**, or from the shell:

```bash
fwconsole ma upgradeall
fwconsole reload
```

Take a FreePBX backup (**Admin → Backup & Restore**) before a module upgrade on a system people are using.

---

## 16. Quawk push-to-talk

VoxBox can relay Quawk iOS push-to-talk clients over IAX2.

| Item | Value |
|------|--------|
| Port | UDP **4569** |
| Account | One FreePBX **IAX2** extension per device. There is no guest peer. |
| Call token | `requirecalltoken=yes`, except on an extension used by unpatched libiax2 |
| Codecs | ulaw, then alaw |
| Dialplan context | `from-Quawk` |
| Discovery | Avahi service `_Quawk._udp` |

The 2026 installer opens UDP 4569 from private LAN ranges and runs `Quawk/install-Quawk-relay.sh` when that file is in the tree. To run the helper again:

```bash
/root/VoxBox/Quawk/install-Quawk-relay.sh
```

`QUAWK_WAN=1` in front of that command also allows UDP 4569 from anywhere. Do that only when those handsets are not on the LAN. Publishing IAX is already how the base firewall treats UDP 4569. Trunk secrets still have to be strong.

Create the extension in the GUI (section 11.3). On the phone: host is the VoxBox address, user and secret are the extension, port is 4569. The iPhone and iPad steps are in the [End User Manual](END-USER-MANUAL.md), in the Quawk section before Zoiper.

---

## 17. Services, files, and logs

| Unit | Role |
|------|------|
| `apache2` | VoxBox Administration and UCP |
| `mariadb` | FreePBX configuration and CDR |
| `php8.2-fpm` | PHP for Apache |
| `freepbx.service` | `fwconsole start` / `fwconsole stop` |
| `tftpd-hpa` | Phone firmware and configs |
| `knockd` | Port knock listener |
| `fail2ban` | SSH and service jails |
| `redis-server` | FreePBX cache |
| `postfix` | Outbound mail |
| `chrony` | Clock. The unit is `chrony` on Debian and `chronyd` on Rocky, Fedora, and RHEL. The source is the default gateway. The PBX does not serve NTP |
| `iptables` / `iptables-persistent` | Host firewall on Debian. Rocky, Fedora, and RHEL use `iptables.service` from iptables-services |

On Rocky, Fedora, RHEL, and derivatives those units are named `httpd`, `php-fpm`, `tftp.socket`, `redis`, and `chronyd`. A Raspberry Pi uses the Debian names.

| Path | What it is |
|------|------------|
| `/root/voxbox-install-log.txt` | Installer transcript |
| `/var/log/voxbox-firstboot.log` | Harvester first boot |
| `/root/knock.FAQ` | This host’s knock ports |
| `/root/VOXBOX-POLYCOM-FIRMWARE.txt` | Written when Polycom firmware was not downloaded |
| `/etc/pbx/.version` | `2026` on the current line |
| `/etc/freepbx.conf` | FreePBX database credentials created by `install -n` |
| `/var/log/asterisk/full` | Asterisk log |
| `/var/www/html/admin/licenses` | Third-party license texts |
| `/usr/local/sbin/pbxstatus` | Status screen |
| `/usr/local/sbin/iptables-custom` | Extra firewall allows, re-applied at boot |

Useful shell commands:

```bash
fwconsole status
fwconsole reload
fwconsole restart
asterisk -rx "core show version"
asterisk -rx "pjsip show endpoints"
systemctl status apache2 mariadb tftpd-hpa knockd chrony
# Rocky, Fedora, RHEL:
systemctl status httpd mariadb php-fpm tftp.socket knockd chronyd
```

---

## 18. Troubleshooting

| What you see | What to do |
|--------------|------------|
| Installer stops or the console looks frozen during `make` | Leave it. A 2-vCPU box can spend a long time in the Asterisk compile. A Raspberry Pi 4 can spend several hours there. Follow `/root/voxbox-install-log.txt`. |
| Compile dies with `Killed` | The machine ran out of RAM. Use 4 GiB, or add a swap file and run a **new** install. On a Pi, a board under about 3.7 GiB already received `/swapfile`. Move to a 4 GiB or larger board and start from a new card. A half-finished 2026 install is not designed to be resumed. |
| `VoxBox2026-RasPi.sh` exits before it installs anything | Read the line it printed. The board is under about 1.5 GiB, the image is 32-bit, or `VERSION_CODENAME` is not `trixie`. Pi 5, Pi 500, and Compute Module 5 need Raspberry Pi OS Lite 64-bit (section 4b). |
| The Debian Pi image has no SSH | That image logs in as `root` with an empty password on the HDMI or serial console. Set a password with `passwd` and run the installer there. OpenSSH arrives during `VoxBox2026.sh`. |
| `VOXBOX_ASTERISK must be 22 or 23` | Export exactly `22` or `23`. |
| Harvester first boot exits immediately | `/var/log/voxbox-firstboot.log` will say the Gitea token is missing. Fix `/etc/voxbox/install.env` or the cloud-init secret and remove `/var/lib/voxbox-firstboot.done` only when you intend to run the installer again on a clean image. |
| GUI does not load from your desk | You are not on a trusted address (section 9). Use the LAN, `add-ip`, or the knock sequence in `/root/knock.FAQ`. |
| GUI loads and the password is rejected | Run `/root/admin-pw-change` on the server and type a new password. A noninteractive install may have stored an empty one. |
| Dashboard still says FreePBX, or the login page is the stock one | `bash branding/apply-voxbox-branding.sh`, then `fwconsole reload`. |
| `tftpd-hpa` is inactive | On Debian: `systemctl status tftpd-hpa`. Confirm `/etc/default/tftpd-hpa` contains `TFTP_DIRECTORY="/tftpboot"` and `TFTP_USERNAME="asterisk"`. On Rocky, Fedora, and RHEL the unit is `tftp.socket`, and the directory is still `/tftpboot`. |
| Phone provisions, then boots the wrong firmware | Templates are installed. Firmware is a separate licensed file. See `/root/VOXBOX-POLYCOM-FIRMWARE.txt`. |
| One-way audio | **Settings → Asterisk SIP Settings**: local network and external address. Confirm UDP 10000–20000 is open on every firewall between the phone and VoxBox. |
| SIP trunk registers and then goes silent from the public internet | Add the provider’s addresses to `/usr/local/sbin/iptables-custom` and run that script. UDP 5060 is not open to the world. |
| IPv6-only DNS or an internal resolver stopped working | The installer wrote public resolvers into `/etc/resolv.conf`. Put your resolvers back and confirm they are still there after a reboot. `systemd-resolved` on Debian 13, and NetworkManager on Rocky, Fedora, and RHEL, may own that file. |
| `PHP is not 8.2` and the EL installer stops | FreePBX 17 needs PHP 8.2. Read the Remi or AppStream errors above that line in `/root/voxbox-install-log.txt`. Enable CRB or PowerTools, confirm the Remi release RPM for your major version, and run the script again on a fresh image. |
| You need the installer to run a second time | Install the base system again and start over. `VoxBox2026.sh` and `VoxBox2026-EL.sh` on a machine that already has FreePBX will fight the existing Apache, MariaDB, and Asterisk layout. |
| `pbxstatus` or a helper says it cannot talk to MariaDB | The helpers use MariaDB user `root` with the installer password from section 3. Resetting that database password without editing the helpers breaks them. |

---

## 19. Upstream documents

Use these when you need the vendor’s own words for a component. When they disagree with this manual about **how to install the base system**, follow this manual. VoxBox owns the install path. FreePBX owns the GUI once the system is up.

| Topic | Document |
|-------|----------|
| FreePBX install overview | <https://sangomakb.atlassian.net/wiki/spaces/FP/pages/9732130/Install+FreePBX> |
| FreePBX 17 Debian installer | <https://github.com/FreePBX/sng_freepbx_debian_install> |
| FreePBX 17 on Debian 12, manual build (PHP 8.2, Asterisk, `./install -n`) | <https://wiki.freepbx.org/display/FOP/How+to+Install+FreePBX+17+on+Debian+12+with+Asterisk+20> |
| Asterisk source | <https://downloads.asterisk.org/pub/telephony/asterisk/> |
| Debian Raspberry Pi image | <https://cloud.debian.org/images/cloud/trixie/latest/debian-13-raspi-arm64.tar.xz> and <https://raspi.debian.net/> |
| Raspberry Pi OS | <https://www.raspberrypi.com/software/operating-systems/> |
| Passwords and reset commands | Section 3 and section 8.2 of this manual |
| VoxBox repository layout and mirror files | [`SOURCES.md`](../SOURCES.md) |
| Harvester manifests | [`harvester/README.md`](../harvester/README.md) |
| Branding apply | [`branding/BRANDING.md`](../branding/BRANDING.md) |
| Quawk | [`Quawk/README.md`](../Quawk/README.md) |

---

## 20. Licenses

VoxBox packaging, branding, PROTEL integration, and this manual are Copyright © 2007–2026 Binary Systems, Inc.

The installer is free software under the GNU General Public License, version 2 or later. Portions are Copyright Ward Mundy & Associates LLC, Copyright Digium, Inc., Copyright Sangoma Technologies, Inc., and other contributors named in the header of `VoxBox2026.sh`, `VoxBox2026-RasPi.sh`, and `VoxBox2026-EL.sh`. There is no warranty. See `/root/COPYING` after install and the files in `/var/www/html/admin/licenses`.

Incredible PBX is a trademark of Ward Mundy & Associates LLC. Asterisk, FreePBX, and Sangoma are trademarks of Sangoma Technologies. Debian is a trademark of Software in the Public Interest, Inc. Raspberry Pi is a trademark of its owner. Rocky Linux, Fedora, and Red Hat are trademarks of their owners. Polycom is a trademark of its owner. They appear here to name the software and base systems VoxBox installs on.

VoxBox and the Binary Systems name and marks are used by Binary Systems, Inc.

Product page: <http://www.binary-systems.com/VoxBox/>
