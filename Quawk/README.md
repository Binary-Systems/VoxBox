# Quawk ↔ VoxBox IAX relay

VoxBox 2026 packaging notes for **QuawkBot** (iOS Push-to-Talk over IAX2), using this PBX as the relay.

## Defaults

| Item | Value |
|------|--------|
| Protocol | IAX2 (`chan_iax2`) |
| Port | **UDP 4569** |
| Auth | Per-device FreePBX **IAX2 extension** + secret (MD5 challenge) |
| Guest / shared peer | **No** |
| Call token | **`requirecalltoken=yes`** (template default) |
| Codecs | **ulaw** first, then alaw; opus optional if Asterisk was built with it |
| Dialplan | Context `from-Quawk`. Sets `Alert-Info: Ring Answer` so a VoxBox-Polycom auto-answers in intercom, then continues the call in `from-internal` |
| Discovery | Optional Avahi **`_Quawk._udp`** (not `_iax._udp`). MVP: manual host/IP |

## Call token vs libiax2

- Template / production default: **`requirecalltoken=yes`** (FreePBX-style).
- **Confirmed (2026-09-11):** stock **libiax2 / iaxclient** does **not** implement Asterisk CALLTOKEN (no IE 54 / frame type 40 in public mirrors). Protocol IE table tops out at 51.
- For testing stock libiax2 today: set **`requirecalltoken=no` on that FreePBX IAX2 extension only** (do not change the global production default).
- Longer-term client paths: patch CALLTOKEN into libiax2, or use token-aware Rust `iax2` (Qhawaq).
- Libiax2 codecs available: ulaw / alaw / gsm / speex (**no opus**). Keep opus optional in Asterisk for token-aware clients later.

## Operator setup (per device)

1. FreePBX → Applications → Extensions → Add **IAX2** extension.
2. Set a strong secret; context `from-Quawk` (or `from-internal` until P2T dialplan is ready).
3. Codecs: disallow all, allow `ulaw` (and `alaw`; add `opus` if available).
4. Ensure **require call token = yes** unless using an unpatched libiax2 client.
5. On the phone/app: host = VoxBox IP/DNS, user = extension, secret = extension secret, port 4569. The iPhone and iPad steps are in [`docs/END-USER-MANUAL.md`](../docs/END-USER-MANUAL.md), before Zoiper.

## Install helper

On a finished VoxBox host (as root), from this repo:

```bash
chmod +x Quawk/install-Quawk-relay.sh
./Quawk/install-Quawk-relay.sh          # LAN ACCEPT UDP 4569 + Avahi + from-Quawk dialplan
QUAWK_WAN=1 ./Quawk/install-Quawk-relay.sh   # also allow UDP 4569 from WAN (optional)
```

`VoxBox2026.sh` opens LAN UDP 4569 during install and runs this helper when present.

## Files

- `extensions_Quawk.conf` — `from-Quawk` dialplan. Sets Alert-Info `Ring Answer`, then continues in `from-internal`
- `avahi-Quawk.service` — mDNS `_Quawk._udp` on 4569
- `iax-Quawk-hints.conf` — sample `iax_custom.conf` snippets
- `install-Quawk-relay.sh` — idempotent post-install
