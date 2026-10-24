# VoxBox branding

Source: http://www.binary-systems.com/VoxBox/ (captured 2026-09-11)

## Assets

| File | Role |
|------|------|
| `VoxBox-fiber.gif` | Animated wordmark above the VoxBox Overview welcome line |
| `VoxBox-fiber-dark.gif` | Night-mode copy of the wordmark: same 40 frames and Aqua line, letters recoloured as soft sculpted grey. `voxbox.css` swaps it in only inside `prefers-color-scheme: dark` |
| `voxbox-favicon.png` | Menu-bar mark and browser favicon (square cube) |
| `voxbox-logo.png` | Generated first frame of the fiber GIF; not the menu mark |
| `binary_systems_si_animated.gif` | BSI animated logo (admin and UCP footers) |
| `binary_systems_si_animated_reverse-clear.gif` (+ `@2x`) | Night-mode copy of the BSI logo: white artwork on transparent (black matte), same 20 frames / 100 ms. The footer view serves it through `<picture>` with `prefers-color-scheme: dark`, and `voxbox.css` drops the white box behind `#footer_logo1` in dark mode only |
| `binary_systems_si_still.png`, `binary_systems_si_still_reverse-clear.png` (+ `@2x`) | Frame-0 stills of the two footer logos for `prefers-reduced-motion: reduce` |
| `views/voxbox_login.php` | Owned login landing (VIEW_LOGIN) |
| `voxbox.css` | FreePBX admin CSS overlay (menu-bar buttons, Aqua accents) |
| `apply-voxbox-branding.sh` | Idempotent installer / re-apply |

## Positioning (from historic page, updated for 2026)

**Tagline (banner):** Secure, Private Communication Infrastructure

**One-liner:** VoxBox is an Open, Simple, and Standard package for VoIP PBXs.

**Product line:** VoxBox 2026 — ultra-small Debian-based (or smaller) VM with Asterisk, FreePBX, emacs-nox, and Endpoint Manager for Polycom SoundPoint IP phones (including the 501, 601, and 670), VVX 500, VVX 1500, and related phones.

**Principles carried forward from VoxBox 1.4:**

- Major system components of a phone system should just work.
- Upgrade major components in a standard way — without the "bling" of other Asterisk-based distributions.
- As clean as building the system yourself from scratch; core components in native/customary locations; Asterisk compiled from source to match hardware.
- Not locked into a proprietary or semi-open solution.
- Easy provisioning for Polycom phones and common SIP trunks/gateways.

**Name origin:** VoxBox was Binary Systems' voice-synthesis / voice-enabled SCADA platform from the late 1970s. The PBX keeps that theme.

**Historic stack (VoxBox 1.4):** CentOS 5.2, Asterisk 1.4.21, FreePBX 2.4, Webmin 1.4 — HTTPS default for web config.

**Copyright:** Copyright © 2007–2026 Binary Systems, Inc.

## FreePBX admin theme (upgrade-safe)

FreePBX admin uses a **Binary Systems white / black / grey** overlay — **not a Framework fork**.

| Piece | Role |
|-------|------|
| `voxbox.css` | Overlay stylesheet (BSI menu-bar buttons, Apple Aqua accents) |
| `views/voxbox_login.php` | Login landing: VoxBox Administration + UCP only |
| `apply-voxbox-branding.sh` | Installs assets + `freepbx_settings` + enables endpointman |
| Installer (`VoxBox2026.sh`) | Copies CSS/logos then runs `apply-voxbox-branding.sh` |

### freepbx_settings (skin)

| Keyword | Value |
|---------|-------|
| `BRAND_TITLE` | `VoxBox Admin` |
| `BRAND_IMAGE_FAVICON` | `images/voxbox-favicon.png` (square cube built from `VoxBox-icon-clean.png`; replaces the FreePBX frog) |
| `VIEW_UCP_ICONS_FOLDER` | `/admin/assets/images/voxbox-icons` |
| `BRAND_IMAGE_TANGO_LEFT` | `/admin/images/voxbox-favicon.png` (square cube; the animated fiber wordmark is not the menu mark). The word is opaque white so it stays readable on the dark bar. In the admin menu the cube opens the Dashboard (`config.php?display=index`). UCP uses the same file in the upper left. |
| `BRAND_IMAGE_FREEPBX_LINK_LEFT` | `/admin/config.php?display=index` (UCP header logo). An admin session opens the Dashboard. With no admin session that address is the FreePBX login page. The admin cube does not use this setting. |
| `BRAND_IMAGE_FREEPBX_LINK_FOOT` | `http://www.binary-systems.com/` |
| `BRAND_FREEPBX_ALT_LEFT` / `_FOOT` | `VoxBox` |
| `BRAND_CSS_CUSTOM` | `voxbox.css` |
| `VIEW_LOGIN` | `views/voxbox_login.php` |
| `VIEW_FOOTER_CONTENT` | `views/voxbox_footer_content.php` |
| `VIEW_UCP_FOOTER_CONTENT` | `views/voxbox_footer_content.php` (relative to `modules/ucp/htdocs`; the apply script copies the view there) |
| `RSSFEEDS` / `UCPRSSFEEDS` | empty (no Nerd Vittles / FreePBX / Sangoma feeds) |
| `SIPUSERAGENT` | `VoxBox` |
| `DASHBOARD_FREEPBX_BRAND` | `VoxBox 2026` |

FreePBX loads the CSS via **Advanced Settings → Optional Additional CSS Stylesheet**. Framework module upgrades do **not** overwrite `voxbox.css` or `views/voxbox_login.php`. Do not edit files under the Framework module tree for theming.

`build-favicon.php` makes the tab icon. It pads `VoxBox-icon-clean.png` (or, if that file is missing, `VoxBox-icon-64.png`, `48`, `32`, or `16`) onto a transparent square, then writes `images/voxbox-favicon.png`, a 16/32/48 `favicon.ico`, and the UCP sizes. The letters in that source are filled white; the cube outside the word stays transparent. `apply-voxbox-branding.sh` runs that builder. The checked-in PNG and ICO are the fallback when PHP GD cannot run. A non-square `.ico` is what lets the browser keep the FreePBX frog. The same cube is the UCP mark: the dashboard reads `BRAND_IMAGE_TANGO_LEFT`, and the login page gets `a.voxbox-ucp-mark` from the UCP header. Both links open `/admin/config.php?display=index` in this window. Night mode on UCP uses the admin dark surfaces from `voxbox.css`.

`views/voxbox_menu.php` includes the stock FreePBX menu and reprints the top-level bar as Admin, Applications, Connectivity, Reports, Settings, UCP. The Dashboard category is removed. The cube in the menu bar opens the Dashboard in this window. Stock FreePBX would open `BRAND_IMAGE_FREEPBX_LINK_LEFT` in a new tab from a click on that image; the menu view stops that click. Dropdown entries stay inside their category. Framework `menu_items.php` is not edited. If a translation or a missing module means one of those six labels is absent, the stock order is kept and a Dashboard item is still removed.

### Login landing

Only two icons: **VoxBox Administration** and **User Control Panel**. Get Support and Operator Panel are removed in `voxbox_login.php`. CSS also hides `#login_support` and Sangoma support navbar links if a stock view leaks through.

The Administration control is a button. Username and password markup stays in a `<template>` until that button opens one dialog, with `autocomplete="username"` and `autocomplete="current-password"`. Safari Passwords then fills the dialog the user is looking at. A hidden form on the landing page is what made Passwords submit a second copy and skip the credential fields.

### Palette (from binary-systems.com)

`#fff` / `#333` / `#CCC` / `#eee` / `#ccc` — link `#005FA5`. Buttons and the admin menu use the www.binary-systems.com menu bar: `#9d9d9d` down to black, lettering `#CCC`, hover `#FFF`. Accents (tabs, progress, panels, table borders, login tiles) stay Apple Aqua (`#2d78c8`). Delete and warning buttons stay off that bar. The same Aqua replaces UCP's green (`#3b8c62`) on navigation, tabs, primary buttons, and active rows. Admin buttons stay on the grey menu bar.

Appearance follows the viewing computer. `voxbox.css` is light by default and switches inside `@media (prefers-color-scheme: dark)`. That query is what a browser reports for a static Dark setting, and for Auto while the computer is in its dark period. A static Light setting stays light. If the browser has no preference, or does not understand the query, the page stays light. There is no VoxBox setting that forces Light or Dark. Installation is Auto because nothing pins a scheme.

Night mode readability: the dark block in `voxbox.css` sets zebra tables, tabs, form rows, widgets (`.displaybox`) and widget title bars to dark surfaces with text at 4.5:1 or better, and keeps the Aqua accents. The dashboard Statistics and Live Network Usage charts are CanvasJS canvases, which CSS cannot restyle, so `views/voxbox_menu.php` carries a small script that fills in dark chart options only while the browser reports dark. The night wordmark (`VoxBox-fiber-dark.gif`) and the menu-bar cube rim are also dark-only. Light mode is unchanged.

Green is reserved for success notices (`.alert-success`, notie success, success toasts). Red is reserved for failure notices (`.alert-danger`, notie error, error toasts). Warning stays amber. Buttons, badges, labels, progress bars, and ordinary `.text-success` are not green.

`apply-voxbox-branding.sh` installs this overlay by copying `voxbox.css` and `views/voxbox_footer_content.php`. The same footer view is copied to `modules/ucp/htdocs/views/` for the signed-out User Control Panel. Leave `BRAND_CSS_CUSTOM` set to `voxbox.css`. FreePBX requests that file as `voxbox.css?load_version=<framework>`, which does not change when the file changes. The footer view adds `/admin/voxbox.css?v=<filemtime>` on admin and UCP pages.

The apply script also marks `modules/ucp/htdocs/views/header.php` with `VOXBOX_UCP_CSS` so signed-in UCP loads the same sheet and sets `html.voxbox-ucp`. A UCP module upgrade replaces that header; run the apply script again to put the link back. UCP centers the footer, sizes the logo at 70px, and pads every footer `div`. The footer view includes its own style so the Binary Systems logo stays on the left at 42px, the copyright lines stay centered with no gap under the first line, and the empty sponsor slot stays hidden. Logged-in UCP does not show this footer; the header link is what styles that screen. The footer's inline colors include a dark `prefers-color-scheme` block so the copyright line is not stuck on `#333`.

The overlay also turns info bars and Yes/No choices Aqua, recolors the codec up/down arrows, and sets the Statistics widget menus to 12px. Those rules ship in `voxbox.css`, so a new install applies them with the branding script.

### Re-apply anytime

```bash
branding/apply-voxbox-branding.sh
# or on a live box:
ADMIN_ROOT=/var/www/html/admin branding/apply-voxbox-branding.sh
```

## Dashboard widgets

`dashboard/VoxBox.class.php` adds six widgets to the FreePBX System Dashboard (`config.php`). Each one uses the stock widget chrome: title bar, drag handle, and reload button. The class is copied into `modules/dashboard/sections/` and Framework files are left unchanged. Each of these six is two columns (1105px): two stock cards plus the 5px dashboard gap.

| Widget | What it shows |
|--------|----------------|
| Active Channels | Channel, location, state, application |
| Active SIP Channels | Peer, user, call id, sequence, format, hold, last message |
| SIP Peers | Endpoint name, host, dynamic, NAT, ACL, port, status |
| SIP Registry | Outbound registration host, username, refresh, state, time |
| IAX2 Peers | `iax2 show peers`, the same table Asterisk Info shows under Peers: name, host, dynamic/static, mask, port, status |
| IAX2 Registry | `iax2 show registry` |

System Vitals and Hardware Information are not their own cards. The VoxBox Overview card shows canonical hostname, listening address, WAN address, then one CPU line with the model, speed, and core count, then kernel, distro, uptime, logged-in users, and load, below the system-name line and above Summary. The card keeps the FreePBX class name `Overview`, rawname `Overview`, and section id `overview`, and the title bar says VoxBox Overview, so layout, AJAX reload, and the fiber wordmark stay on `#page_Main_Overview_overview`. Alerts, notifications, and the service summary still come from the FreePBX class. `views/sections/overview.php` is not edited.

`apply-voxbox-branding.sh` saves that FreePBX class as `modules/dashboard/classes/VoxBoxOverviewStock.class.php` (renamed `OverviewStock`, outside the section glob) and installs `dashboard/Overview.class.php` over `sections/Overview.class.php`. The overlay extends the saved class, titles the card VoxBox Overview, and inserts the vitals rows. A second run sees the marker `VOXBOX_OVERVIEW_OVERLAY` and does not archive the overlay as if it were upstream. A System Dashboard module upgrade replaces `sections/` and `classes/`, which removes the overlay, the saved parent, `VoxBox.class.php`, and restores Uptime. The Overview card is stock FreePBX until `apply-voxbox-branding.sh` is run again.

WAN IP is a public address on this host when it has one. Otherwise the lookup asks `api.ipify.org`, then `ipv4.icanhazip.com`, and keeps the last answer for 15 minutes. A failed lookup is retried after a minute and the last good address stays on screen.

The stock Uptime widget is removed. VoxBox Overview already shows uptime. The Hardware Information widget is removed. VoxBox Overview has one CPU line with the model, speed, and core count.

`voxbox.css` draws `images/VoxBox-fiber.gif` above the “Welcome to VoxBox 2026” line inside `#page_Main_Overview_overview`. The menu script replaces that drawing with a link to `https://www.binary-systems.com/VoxBox/`. The menu bar uses the cube favicon instead, and that cube opens the Dashboard.

VoxBox Endpoint Manager (`endpointman`) is left **Enabled**.

## Typography (BSI brand)

Default UI/body stack:

`"Lucida Grande", "Lucida Sans Unicode", Arial, Verdana, sans-serif`

Monospace stays for code, logs, terminals, and config editors. Themeable surfaces only — no Framework fork for fonts.

## Live parity (installer must match)

Canonical apply path for a fresh install or rebuild:

`branding/apply-voxbox-branding.sh` — FreePBX freepbx_settings, views, `voxbox.css`, logos, and favicon.

`VoxBox2026.sh` must keep calling that script. Webmin is not part of VoxBox.

`sign-voxbox-module.sh` re-signs `modules/voxbox` (`signatures/voxbox.local.sig` and `module.sig`, key `55D46506ED591342`). Run it as root on the host that holds the key in `/etc/freepbx.secure/gnupg`, then rebuild `mirror/voxbox.tgz`. The private key stays on that host.
