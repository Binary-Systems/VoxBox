# Spin up VoxBox on Harvester

Easy path: import a **Debian 13 cloud image**, create a sized VM with **cloud-init**, and let first boot clone this repo and run `VoxBox2026.sh` noninteractively.

## Recommended size

| Profile | vCPU | RAM | Disk | When |
|---------|------|-----|------|------|
| Lab | 2 | 2 Gi | 20 Gi | Tight; compile may struggle |
| **Recommended** | **4** | **4 Gi** | **40 Gi** | Default manifests |
| Production | 4+ | 8 Gi | 80 Gi | Busier PBX / recordings |

FreePBX wants roughly ≥2 Gi / ≥20 Gi; VoxBox also compiles Asterisk and can install PROTEL, so **4 vCPU / 4 Gi / 40 Gi** is the default.

**Network:** use a **bridged VLAN** (example `voice` / `192.168.50.0/24`) so SIP (UDP 5060), RTP, TFTP (69), IAX (4569), and FreePBX are reachable from phones on that LAN. Masquerade/NAT is a poor fit for a PBX.

## Addresses

Use your own numbers. The samples below are documentation addresses, also used in the [installation manual](../docs/INSTALLATION.md).

| Role | Example |
|------|---------|
| Internal LAN | `192.168.50.0/24` (OPNsense LAN `192.168.50.1`) |
| VoxBox internal address | `192.168.50.10` |
| Web server internal address | `192.168.50.20` |
| External WAN address | `203.0.113.10` |

Phones and the GUI use the internal address: `http://192.168.50.10/`. Carriers use the external address. In FreePBX, **External Address** is `203.0.113.10` and **Local Networks** is `192.168.50.0/24`.

When that public address is also the website address, OPNsense Caddy (or nginx) answers **TCP 80 and 443** and reverse-proxies to the web server. Forward voice UDP to VoxBox. Leave TCP 80 and 443 off the VoxBox port-forward list. A forward of those two ports takes the reverse proxy off the public address.

| Scope | Where it goes |
|-------|----------------|
| WAN → VoxBox | UDP **4569**, **5060–5061**, **10000–20000** → `192.168.50.10`. TCP **22** only if you intend to publish it. |
| WAN → websites | Caddy on TCP **80** and **443**, upstream `192.168.50.20`. |
| FreePBX UI | LAN: `http://192.168.50.10/` or an SSH tunnel. |

Click path (OPNsense 25.x), same forwards as the installation manual:

1. **Services → DHCPv4 → LAN** — static map `192.168.50.10` for the VoxBox MAC.
2. **Firewall → Aliases** — host `voxbox_host` = `192.168.50.10`.
3. **Firewall → NAT → Port Forward** — WAN address, UDP `5060–5061`, `4569`, and `10000–20000`, redirect target `voxbox_host`, **Add associated filter rule**.
4. **Firewall → NAT → Outbound** — Hybrid mode, source `192.168.50.10/32`, translation **Interface address**, **Static port** checked.
5. **Services → Caddy Web Server** — `www.example.com` upstream `192.168.50.20`. No VoxBox handler on 80 or 443.

## Prerequisites

1. Harvester cluster with a VLAN / cluster network (example: `default/voice`).
2. `kubectl` configured for the Harvester management cluster (or use the UI).
3. A Gitea token that can **read** private repo `binary-systems.com/VoxBox`.
4. Your SSH public key.

## Steps

### 1. Edit cloud-init

```bash
cd harvester
cp user-data.yaml user-data.local.yaml   # optional local copy
# Set:
#   ssh_authorized_keys → your key
#   VOXBOX_GIT_TOKEN → Gitea token (repo read)
#   VOXBOX_ASTERISK=22 (or 23)
```

Also edit `vm-voxbox-from-secret.yaml`: set `networkName` to your real Harvester network.

### 2. Import Debian 13 image

```bash
kubectl apply -f image-debian13.yaml
# Wait until VirtualMachineImage is ready in the Harvester UI / kubectl get vmimage
```

Or upload `debian-13-generic-amd64.qcow2` via **Images → Create** in the UI.

### 3. Create cloud-init Secret

```bash
# After editing user-data.yaml + network-data.yaml:
./render-secret.sh
# or: NAMESPACE=default ./render-secret.sh
```

### 4. Create the VM

```bash
kubectl apply -f vm-voxbox-from-secret.yaml
kubectl -n default get vmi,vm,pvc | grep voxbox
```

In the Harvester UI: open the VM console or use SSH once DHCP assigns an address:

```bash
ssh voxbox@<vm-ip>
sudo tail -f /var/log/voxbox-firstboot.log
```

First boot installs packages, clones VoxBox, and runs the full installer (can take a long time). When finished, reboot if prompted by the installer, then use FreePBX on the **LAN address** (example `http://192.168.50.10/`). Keep the GUI off the public port-forward list when TCP 80 and 443 belong to the reverse proxy.

### 5. Firewall / ports

#### On the voice VLAN (LAN reachability — phones, admins)

| Port | Use |
|------|-----|
| TCP 22 | SSH |
| TCP 80 / 443 | FreePBX (LAN/BSI only) |
| UDP 5060–5061 | SIP |
| UDP 10000–20000 | RTP (typical) |
| UDP 69 | TFTP (OSS EPM / Polycom) |
| UDP 4569 | IAX2 (Quawk) |

#### On WAN (OPNsense port forward to the VoxBox internal address, example `192.168.50.10`)

| Port | Use |
|------|-----|
| UDP 4569 | IAX2 |
| UDP 5060–5061 | SIP |
| UDP 10000–20000 | RTP |
| TCP 22 | SSH (optional, limit the source) |
| TCP 80 / 443 | Leave these on OPNsense Caddy when the public address also serves websites. Upstream is the web server (example `192.168.50.20`), not VoxBox. |

## Files

| File | Purpose |
|------|---------|
| `user-data.yaml` | cloud-init user-data (hostname, user, firstboot installer) |
| `network-data.yaml` | DHCP on primary NIC |
| `image-debian13.yaml` | Harvester `VirtualMachineImage` for Debian 13 cloud |
| `vm-voxbox-from-secret.yaml` | Sized VM (4/4 Gi/40 Gi) + cloud-init Secret |
| `sizes.yaml` | Lab / recommended / production profiles |
| `render-secret.sh` | Apply Secret from the YAML files |
| `cloudinit-secret.yaml.example` | Alternate Secret shape |

## Noninteractive installer

`VoxBox2026.sh` accepts:

- `VOXBOX_NONINTERACTIVE=1` — skip prompts (Asterisk **22** default)
- `VOXBOX_ASTERISK=22|23` — force Asterisk version

Cloud-init sets these via `/etc/voxbox/install.env`.

## Notes

- The VoxBox Gitea repo is **private** — without a valid `VOXBOX_GIT_TOKEN`, firstboot exits with an error (logged under `/var/log/voxbox-firstboot.log`).
- Rotate/revoke the token after bring-up if it was only for bootstrap; prefer a fine-scoped read-only token.
- For a second node, clone the YAML, change `metadata.name` / PVC name / hostname.
