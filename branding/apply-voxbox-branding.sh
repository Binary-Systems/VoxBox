#!/bin/bash
# Apply VoxBox FreePBX branding (upgrade-safe). Idempotent.
# Uses freepbx_settings + owned VIEW_* + CSS overlay — does NOT fork Framework.
# When modules/voxbox is installed, that module owns these files and settings.
# Copying onto its links would change the signed module.
# Copyright (C) 2007-2026 Binary Systems, Inc.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ADMIN_ROOT="${ADMIN_ROOT:-/var/www/html/admin}"
IMAGES_DIR="$ADMIN_ROOT/images"
VIEWS_DIR="$ADMIN_ROOT/views"
MYSQL_CMD="${MYSQL_CMD:-}"
LOGO_SRC=""
FIBER_GIF="VoxBox-fiber.gif"

echo "==> VoxBox FreePBX branding apply (from $SCRIPT_DIR)"

if [[ ! -d "$ADMIN_ROOT" ]]; then
  echo "ERROR: FreePBX admin root missing: $ADMIN_ROOT" >&2
  exit 1
fi

# Resolve MySQL client (live target uses: sudo mysql --password=passw0rd)
if [[ -z "$MYSQL_CMD" ]]; then
  if command -v mysql >/dev/null 2>&1; then
    if mysql --password=passw0rd -e 'SELECT 1' asterisk >/dev/null 2>&1; then
      MYSQL_CMD='mysql --password=passw0rd asterisk'
    elif sudo mysql --password=passw0rd -e 'SELECT 1' asterisk >/dev/null 2>&1; then
      MYSQL_CMD='sudo mysql --password=passw0rd asterisk'
    elif mysql -u root -ppassw0rd -e 'SELECT 1' asterisk >/dev/null 2>&1; then
      MYSQL_CMD='mysql -u root -ppassw0rd asterisk'
    else
      MYSQL_CMD='mysql asterisk'
    fi
  else
    echo "ERROR: mysql client not found" >&2
    exit 1
  fi
fi

sql() {
  # shellcheck disable=SC2086
  $MYSQL_CMD -e "$1"
}

set_setting() {
  local key="$1"
  local val="$2"
  # Escape single quotes for SQL
  local esc=${val//\'/\'\'}
  sql "UPDATE freepbx_settings SET value='${esc}', readonly=0 WHERE keyword='${key}' LIMIT 1"
  # Insert if missing (some skins add VIEW_* later)
  local n
  n=$(sql "SELECT COUNT(*) FROM freepbx_settings WHERE keyword='${key}'" | tail -1 | tr -d '[:space:]')
  if [[ "$n" == "0" ]]; then
    sql "INSERT INTO freepbx_settings (keyword, value, readonly) VALUES ('${key}', '${esc}', 0)"
  fi
  echo "  set $key=$val"
}

# The VoxBox module owns the cube, theme, login, menu, footer, and the
# settings that point at them. A copy here follows those links and rewrites
# the signed files. Dashboard and User Control Panel repairs stay below.
if [[ ! -f "$ADMIN_ROOT/modules/voxbox/module.xml" ]]; then

mkdir -p "$IMAGES_DIR" "$ADMIN_ROOT/assets/images" /var/www/html/images "$VIEWS_DIR"

# Fiber GIF is the System Overview wordmark (voxbox.css, above the welcome
# line). The menu bar uses the cube favicon, set below as BRAND_IMAGE_TANGO_LEFT.
# voxbox-logo.gif / voxbox-logo.png keep the same GIF for older links; they are
# not the menu mark.
LOGO_GIF=""
for candidate in "$SCRIPT_DIR/$FIBER_GIF" "$IMAGES_DIR/$FIBER_GIF"; do
  [[ -f "$candidate" ]] && LOGO_GIF=$candidate && break
done
if [[ -n "$LOGO_GIF" ]]; then
  cp -f "$LOGO_GIF" "$IMAGES_DIR/VoxBox-fiber.gif"
  cp -f "$LOGO_GIF" "$IMAGES_DIR/voxbox-logo.gif"
  if [[ -f "$SCRIPT_DIR/VoxBox-fiber-dark.gif" ]]; then
    # Night mode wordmark (voxbox.css, prefers-color-scheme: dark).
    cp -f "$SCRIPT_DIR/VoxBox-fiber-dark.gif" "$IMAGES_DIR/VoxBox-fiber-dark.gif"
    cp -f "$SCRIPT_DIR/VoxBox-fiber-dark.gif" "$ADMIN_ROOT/assets/images/VoxBox-fiber-dark.gif" 2>/dev/null || true
    echo "  installed night-mode wordmark $IMAGES_DIR/VoxBox-fiber-dark.gif"
  fi
  cp -f "$LOGO_GIF" "$ADMIN_ROOT/assets/images/VoxBox-fiber.gif" 2>/dev/null || true
  if command -v convert >/dev/null 2>&1; then
    convert "${LOGO_GIF}[0]" -resize "160x40>" "$IMAGES_DIR/voxbox-logo.png" || true
  fi
  echo "  installed System Overview wordmark $IMAGES_DIR/VoxBox-fiber.gif"
else
  echo "WARNING: $FIBER_GIF not found"
fi

# Binary Systems animated logo (admin and UCP footers)
BSI_GIF="binary_systems_si_animated.gif"
if [[ -f "$SCRIPT_DIR/$BSI_GIF" ]]; then
  cp -f "$SCRIPT_DIR/$BSI_GIF" "$IMAGES_DIR/$BSI_GIF"
  echo "  installed footer BSI animated gif"
  # 2x file for high-density displays (srcset in voxbox_footer_content.php)
  if [[ -f "$SCRIPT_DIR/binary_systems_si_animated@2x.gif" ]]; then
    cp -f "$SCRIPT_DIR/binary_systems_si_animated@2x.gif" "$IMAGES_DIR/binary_systems_si_animated@2x.gif"
    echo "  installed footer BSI animated gif @2x"
  fi
  # Night-mode (reverse-clear) and reduced-motion (still) variants, used by
  # voxbox_footer_content.php through <picture> media queries.
  for v in binary_systems_si_animated_reverse-clear.gif binary_systems_si_animated_reverse-clear@2x.gif \
           binary_systems_si_still.png binary_systems_si_still@2x.png \
           binary_systems_si_still_reverse-clear.png binary_systems_si_still_reverse-clear@2x.png; do
    if [[ -f "$SCRIPT_DIR/$v" ]]; then
      cp -f "$SCRIPT_DIR/$v" "$IMAGES_DIR/$v"
      echo "  installed footer BSI $v"
    else
      echo "WARNING: $v not found" >&2
    fi
  done
else
  echo "WARNING: $BSI_GIF not found" >&2
fi

# Cube icon → favicon + login tile art.
# Browsers ignore a non-square favicon.ico and keep the cached FreePBX frog.
# build-favicon.php pads VoxBox-icon-clean.png (or a smaller VoxBox-icon-*.png)
# onto a transparent square, then writes the tab PNG, /favicon.ico, and the
# UCP sizes. Checked-in files are only the fallback when PHP GD
# cannot run. Header.php hardcodes assets/images/badge.png for apple-touch-icon.
if [[ -f "$SCRIPT_DIR/VoxBox-icon.png" ]]; then
  cp -f "$SCRIPT_DIR/VoxBox-icon.png" "$IMAGES_DIR/VoxBox-icon.png"
  cp -f "$SCRIPT_DIR/VoxBox-icon.png" "$ADMIN_ROOT/assets/images/VoxBox-icon.png" 2>/dev/null || true
fi
if [[ -f "$SCRIPT_DIR/VoxBox-icon.bmp" ]]; then
  cp -f "$SCRIPT_DIR/VoxBox-icon.bmp" "$IMAGES_DIR/VoxBox-icon.bmp"
fi
FAV_BUILD=""
if [[ -f "$SCRIPT_DIR/build-favicon.php" ]] && command -v php >/dev/null 2>&1; then
  FAV_BUILD=$(mktemp -d)
  if ! php "$SCRIPT_DIR/build-favicon.php" "$SCRIPT_DIR" "$FAV_BUILD"; then
    echo "WARNING: favicon build failed; using checked-in icons" >&2
    rm -rf "$FAV_BUILD"
    FAV_BUILD=""
  fi
fi
FAV_PNG="$SCRIPT_DIR/voxbox-favicon.png"
FAV_ICO="$SCRIPT_DIR/favicon.ico"
UCP_ICONS_SRC="$SCRIPT_DIR/ucp-icons"
if [[ -n "$FAV_BUILD" && -f "$FAV_BUILD/voxbox-favicon.png" ]]; then
  FAV_PNG="$FAV_BUILD/voxbox-favicon.png"
  FAV_ICO="$FAV_BUILD/favicon.ico"
  UCP_ICONS_SRC="$FAV_BUILD/ucp-icons"
fi
if [[ -f "$FAV_PNG" ]]; then
  cp -f "$FAV_PNG" "$IMAGES_DIR/voxbox-favicon.png"
  mkdir -p "$ADMIN_ROOT/assets/images"
  cp -f "$FAV_PNG" "$ADMIN_ROOT/assets/images/badge.png"
  echo "  installed voxbox-favicon.png"
fi
# admin/images/favicon.ico is covered by the Framework signature.
# Replacing it turns the Framework row red. The tab icon is
# BRAND_IMAGE_FAVICON. The cube .ico stays at the web root and /admin/favicon.ico.
if [[ -f "$FAV_ICO" ]]; then
  cp -f "$FAV_ICO" "$ADMIN_ROOT/favicon.ico" 2>/dev/null || true
  cp -f "$FAV_ICO" /var/www/html/favicon.ico 2>/dev/null || true
  echo "  installed favicon.ico (VoxBox cube)"
fi
UCP_ICONS_DST="$ADMIN_ROOT/assets/images/voxbox-icons"
if [[ -d "$UCP_ICONS_SRC" ]]; then
  mkdir -p "$UCP_ICONS_DST"
  cp -f "$UCP_ICONS_SRC/"*.png "$UCP_ICONS_DST/"
  echo "  installed UCP icons → $UCP_ICONS_DST"
fi
if [[ -n "$FAV_BUILD" ]]; then
  rm -rf "$FAV_BUILD"
fi

# --- CSS overlay ---
if [[ -f "$SCRIPT_DIR/voxbox.css" ]]; then
  cp -f "$SCRIPT_DIR/voxbox.css" "$ADMIN_ROOT/voxbox.css"
  echo "  installed $ADMIN_ROOT/voxbox.css"
else
  echo "WARNING: voxbox.css missing beside apply script" >&2
fi

# Dynamic copyright end year (same .bsi-year hook as www.binary-systems.com).
if [[ -f "$SCRIPT_DIR/copyright.js" ]]; then
  mkdir -p "$ADMIN_ROOT/assets/js"
  cp -f "$SCRIPT_DIR/copyright.js" "$ADMIN_ROOT/assets/js/copyright.js"
  echo "  installed $ADMIN_ROOT/assets/js/copyright.js"
fi

# --- Owned login view ---
# The Administration icon opens one credential dialog. The password fields
# stay in a <template> until that click, so Safari Passwords cannot submit
# a hidden copy of the form.
if [[ -f "$SCRIPT_DIR/views/voxbox_login.php" ]]; then
  cp -f "$SCRIPT_DIR/views/voxbox_login.php" "$VIEWS_DIR/voxbox_login.php"
  echo "  installed $VIEWS_DIR/voxbox_login.php"
else
  echo "WARNING: views/voxbox_login.php missing" >&2
fi

if [[ -f "$SCRIPT_DIR/views/voxbox_footer_content.php" ]]; then
  cp -f "$SCRIPT_DIR/views/voxbox_footer_content.php" "$VIEWS_DIR/voxbox_footer_content.php"
  echo "  installed $VIEWS_DIR/voxbox_footer_content.php"
  # UCP login footer is a different file. VIEW_UCP_FOOTER_CONTENT is relative
  # to modules/ucp/htdocs, so the same view has to live there too.
  UCP_VIEWS="$ADMIN_ROOT/modules/ucp/htdocs/views"
  if [[ -d "$UCP_VIEWS" ]]; then
    cp -f "$SCRIPT_DIR/views/voxbox_footer_content.php" "$UCP_VIEWS/voxbox_footer_content.php"
    echo "  installed $UCP_VIEWS/voxbox_footer_content.php"
  fi
else
  echo "WARNING: views/voxbox_footer_content.php missing" >&2
fi

# Logged-in UCP does not use the footer view. Its header is the reliable
# place for /admin/voxbox.css. VoxBox User Control Panel ships that header.
# A stock UCP package replaces header.php; running this script again puts
# the marker back. Do not edit getCss().
UCP_HEADER="$ADMIN_ROOT/modules/ucp/htdocs/views/header.php"
if [[ -f "$UCP_HEADER" ]]; then
  UCP_HEADER="$UCP_HEADER" php << 'PHP'
<?php
$path = getenv("UCP_HEADER");
$text = file_get_contents($path);
if ($text === false) {
  fwrite(STDERR, "WARNING: cannot read UCP header\n");
  exit(0);
}
if (strpos($text, "VOXBOX_UCP_CSS") !== false) {
  echo "  UCP header already loads voxbox.css\n";
  exit(0);
}
$needle = "compiled/modules/";
$idx = strpos($text, $needle);
if ($idx === false) {
  fwrite(STDERR, "WARNING: UCP header has no compiled/modules stylesheet; voxbox.css not injected\n");
  exit(0);
}
/* The link is split across lines and the PHP tag inside it contains "?>",
   so the first ">" is not the end of the element. */
$close = 'type="text/css">';
$end = strpos($text, $close, $idx);
if ($end === false) {
  fwrite(STDERR, "WARNING: UCP header stylesheet link is incomplete\n");
  exit(0);
}
$end = $end + strlen($close) - 1;
$insert = <<<'HTML'

	<?php /* VOXBOX_UCP_CSS */
	global $amp_conf;
	$voxCss = '/var/www/html/admin/voxbox.css';
	if (!empty($amp_conf['AMPWEBROOT'])) {
		$voxCss = rtrim($amp_conf['AMPWEBROOT'], '/') . '/admin/voxbox.css';
	}
	$voxCssVer = @filemtime($voxCss);
	?>
	<script>document.documentElement.classList.add('voxbox-ucp');</script>
	<link rel="stylesheet" href="/admin/voxbox.css?v=<?php echo $voxCssVer ? (int) $voxCssVer : time(); ?>">
HTML;
$text = substr($text, 0, $end + 1) . $insert . substr($text, $end + 1);
if (file_put_contents($path, $text) === false) {
  fwrite(STDERR, "WARNING: could not write UCP header\n");
  exit(0);
}
echo "  UCP header loads /admin/voxbox.css\n";
PHP
else
  echo "WARNING: UCP header.php missing; signed-in UCP will not load voxbox.css" >&2
fi

# Login has no brand slot. This mark covers that page; voxbox.css hides
# it when the dashboard bar is present. The cube opens the FreePBX admin
# Dashboard. With no admin session that same address is the login page.
UCP_DASH="/admin/config.php?display=index"
if [[ -f "$UCP_HEADER" ]]; then
  UCP_HEADER="$UCP_HEADER" UCP_DASH="$UCP_DASH" php << 'PHP'
<?php
$path = getenv("UCP_HEADER");
$dash = getenv("UCP_DASH");
$text = file_get_contents($path);
if ($text === false) {
  fwrite(STDERR, "WARNING: cannot read UCP header for the logo\n");
  exit(0);
}
$mark = '<a class="voxbox-ucp-mark" href="' . $dash . '" aria-label="VoxBox"><img src="/admin/images/voxbox-favicon.png" alt="VoxBox"></a>';
if (strpos($text, "VOXBOX_UCP_MARK") !== false) {
  if (strpos($text, 'href="' . $dash . '"') !== false) {
    echo "  UCP header already has the cube mark\n";
    exit(0);
  }
  $updated = preg_replace(
    '#<a class="voxbox-ucp-mark" href="[^"]*" aria-label="VoxBox"><img src="/admin/images/voxbox-favicon.png(?:\?[^"]*)?" alt="VoxBox"></a>#',
    $mark,
    $text,
    1,
    $count
  );
  if ($count === 1 && $updated !== $text) {
    file_put_contents($path, $updated);
    echo "  UCP cube mark opens the admin Dashboard\n";
  } else {
    echo "  UCP header already has the cube mark\n";
  }
  exit(0);
}
$needle = "<body>";
$idx = strpos($text, $needle);
if ($idx === false) {
  fwrite(STDERR, "WARNING: UCP header has no body; cube mark not injected\n");
  exit(0);
}
$insert = "<body>\n\t<!-- VOXBOX_UCP_MARK -->\n\t" . $mark;
$text = substr($text, 0, $idx) . $insert . substr($text, $idx + strlen($needle));
if (file_put_contents($path, $text) === false) {
  fwrite(STDERR, "WARNING: could not write UCP cube mark\n");
  exit(0);
}
echo "  UCP header has the cube mark\n";
PHP
fi

# Logged-in UCP draws the cube from dashboard-header.php. VoxBox User
# Control Panel ships that link. Point it at the admin Dashboard and do
# not open a new tab. A stock UCP package restores the stock link until
# this script runs again.
UCP_DASH_HEADER="${ADMIN_ROOT}/modules/ucp/htdocs/views/dashboard-header.php"
if [[ -f "$UCP_DASH_HEADER" ]]; then
  UCP_DASH_HEADER="$UCP_DASH_HEADER" UCP_DASH="$UCP_DASH" php << 'PHP'
<?php
$path = getenv("UCP_DASH_HEADER");
$dash = getenv("UCP_DASH");
$text = file_get_contents($path);
if ($text === false) {
  fwrite(STDERR, "WARNING: cannot read UCP dashboard header\n");
  exit(0);
}
$anchor = '<a href="' . $dash . '">';
if (strpos($text, $anchor) !== false && strpos($text, "ucp__logo") !== false) {
  echo "  UCP dashboard cube already opens the admin Dashboard\n";
  exit(0);
}
$updated = preg_replace(
  '#<a href="<\?php echo \$amp_conf\[\'BRAND_IMAGE_FREEPBX_LINK_LEFT\'\]; \?>" target="_blank">#',
  $anchor,
  $text,
  1,
  $count
);
if ($count !== 1) {
  fwrite(STDERR, "WARNING: UCP dashboard logo link was not found\n");
  exit(0);
}
file_put_contents($path, $updated);
echo "  UCP dashboard cube opens the admin Dashboard\n";
PHP
fi

if [[ -f "$SCRIPT_DIR/views/voxbox_menu.php" ]]; then
  cp -f "$SCRIPT_DIR/views/voxbox_menu.php" "$VIEWS_DIR/voxbox_menu.php"
  echo "  installed $VIEWS_DIR/voxbox_menu.php"
else
  echo "WARNING: views/voxbox_menu.php missing" >&2
fi

# --- freepbx_settings ---
echo "==> Updating freepbx_settings"
set_setting "BRAND_TITLE" "VoxBox Admin"
# Menu bar mark and tab icon: square cube, not the fiber wordmark.
# Absolute path: UCP is served from /ucp/, so images/voxbox-favicon.png 404s there.
set_setting "BRAND_IMAGE_TANGO_LEFT" "/admin/images/voxbox-favicon.png"
set_setting "BRAND_IMAGE_FAVICON" "images/voxbox-favicon.png"
# Leading slash: UCP pages live under /ucp/, so a relative path would miss
# /admin/assets. This URL still works after a UCP module upgrade.
set_setting "VIEW_UCP_ICONS_FOLDER" "/admin/assets/images/voxbox-icons"
# UCP's stock logo reads this setting. The admin cube does not.
# No admin session: FreePBX shows the login page at this same address.
set_setting "BRAND_IMAGE_FREEPBX_LINK_LEFT" "/admin/config.php?display=index"
set_setting "BRAND_IMAGE_FREEPBX_FOOT" "images/binary_systems_si_animated.gif"
set_setting "BRAND_IMAGE_FREEPBX_LINK_FOOT" "http://www.binary-systems.com/"
set_setting "BRAND_FREEPBX_ALT_FOOT" "Binary Systems, Inc."
set_setting "BRAND_FREEPBX_ALT_LEFT" "VoxBox"
set_setting "BRAND_CSS_CUSTOM" "voxbox.css"
set_setting "VIEW_LOGIN" "views/voxbox_login.php"
set_setting "VIEW_MENU" "views/voxbox_menu.php"
set_setting "VIEW_FOOTER_CONTENT" "views/voxbox_footer_content.php"
set_setting "VIEW_UCP_FOOTER_CONTENT" "views/voxbox_footer_content.php"
set_setting "BRAND_IMAGE_SPONSOR_LINK_FOOT" ""
set_setting "BRAND_SPONSOR_ALT_FOOT" ""
set_setting "RSSFEEDS" ""
set_setting "UCPRSSFEEDS" ""
set_setting "SIPUSERAGENT" "VoxBox"
set_setting "DASHBOARD_FREEPBX_BRAND" "VoxBox 2026"

# Optional: blank sponsor / footer brand image noise
for k in BRAND_IMAGE_SPONSOR_FOOT VIEW_FOOTER_ITEM; do
  n=$(sql "SELECT COUNT(*) FROM freepbx_settings WHERE keyword='${k}'" | tail -1 | tr -d '[:space:]')
  if [[ "$n" != "0" ]]; then
    set_setting "$k" ""
  fi
done
# Keep VIEW_FOOTER_CONTENT = views/voxbox_footer_content.php (set above)

# Soft-replace Incredible PBX leftover strings in settings values (not Framework files)
sql "UPDATE freepbx_settings SET value = REPLACE(value, 'Incredible PBX', 'VoxBox') WHERE value LIKE '%Incredible PBX%'"
sql "UPDATE freepbx_settings SET value = REPLACE(value, 'IncrediblePBX', 'VoxBox') WHERE value LIKE '%IncrediblePBX%'"
sql "UPDATE freepbx_settings SET value = REPLACE(value, 'incrediblepbx.com', 'binary-systems.com') WHERE value LIKE '%incrediblepbx.com%'"


# --- Hide stock FreePBX Support wiki menu (core module.xml) via freepbx_menu.conf ---
ASTETCDIR=$(sql "SELECT value FROM freepbx_settings WHERE keyword='ASTETCDIR' LIMIT 1" | tail -1 | tr -d '[:space:]')
ASTETCDIR=${ASTETCDIR:-/etc/asterisk}
mkdir -p "$ASTETCDIR"
MENU_CONF="$ASTETCDIR/freepbx_menu.conf"
if [[ ! -f "$MENU_CONF" ]] || ! grep -q '^\[wiki\]' "$MENU_CONF" 2>/dev/null; then
  cat >> "$MENU_CONF" <<'INI'

; VoxBox: hide stock FreePBX Support wiki menu item on login navbar
[wiki]
remove = 1
INI
  echo "  wrote $MENU_CONF [wiki] remove=1"
else
  echo "  $MENU_CONF already has [wiki]"
fi
set_setting "USE_FREEPBX_MENU_CONF" "1"

else
  echo "==> VoxBox module owns branding files, settings, and the IncrediblePBX block"
fi

# --- Dashboard widgets (FreePBX section classes) ---
# VoxBox System Dashboard ships these files and the dashboard loads every
# sections/*.class.php itself. A stock dashboard package replaces
# modules/dashboard/sections and modules/dashboard/classes. That drops
# VoxBox.class.php, drops the saved stock Overview parent, restores
# sections/Overview.class.php, and restores the stock Uptime widget.
# Run this script again after that kind of upgrade.
DASH_SECTIONS="$ADMIN_ROOT/modules/dashboard/sections"
DASH_CLASSES="$ADMIN_ROOT/modules/dashboard/classes"
STOCK_OVERVIEW="$DASH_CLASSES/VoxBoxOverviewStock.class.php"
OVERVIEW_LIVE="$DASH_SECTIONS/Overview.class.php"
OVERVIEW_MARKER='VOXBOX_OVERVIEW_OVERLAY'

if command -v php >/dev/null 2>&1; then
  php -l "$SCRIPT_DIR/dashboard/VoxBox.class.php"
  php -l "$SCRIPT_DIR/dashboard/Overview.class.php"
  php -l "$SCRIPT_DIR/dashboard/Enterprise.class.php"
  php -l "$SCRIPT_DIR/dashboard/Notepad.class.php"
  php -l "$SCRIPT_DIR/dashboard/Statistics.class.php"
fi
if [[ -f "$SCRIPT_DIR/dashboard/VoxBox.class.php" && -d "$DASH_SECTIONS" ]]; then
  cp -f "$SCRIPT_DIR/dashboard/VoxBox.class.php" "$DASH_SECTIONS/VoxBox.class.php"
  echo "  installed $DASH_SECTIONS/VoxBox.class.php"
else
  echo "WARNING: VoxBox dashboard widgets not installed (missing class or $DASH_SECTIONS)" >&2
fi
if [[ -f "$SCRIPT_DIR/dashboard/Enterprise.class.php" && -d "$DASH_SECTIONS" ]]; then
  cp -f "$SCRIPT_DIR/dashboard/Enterprise.class.php" "$DASH_SECTIONS/Enterprise.class.php"
  echo "  installed $DASH_SECTIONS/Enterprise.class.php"
fi
if [[ -f "$SCRIPT_DIR/dashboard/Notepad.class.php" && -d "$DASH_SECTIONS" ]]; then
  cp -f "$SCRIPT_DIR/dashboard/Notepad.class.php" "$DASH_SECTIONS/Notepad.class.php"
  echo "  installed $DASH_SECTIONS/Notepad.class.php"
fi
if [[ -f "$SCRIPT_DIR/dashboard/Statistics.class.php" && -d "$DASH_SECTIONS" ]]; then
  cp -f "$SCRIPT_DIR/dashboard/Statistics.class.php" "$DASH_SECTIONS/Statistics.class.php"
  echo "  installed $DASH_SECTIONS/Statistics.class.php"
fi
DASH_CLASS="$ADMIN_ROOT/modules/dashboard/Dashboard.class.php"
if [[ -f "$DASH_CLASS" ]] && ! grep -q "sections/Enterprise.class.php" "$DASH_CLASS"; then
  php -r '
    $path = $argv[1];
    $text = file_get_contents($path);
    $old = "public function doConfigPageInit() {\n\t}";
    $new = "public function doConfigPageInit(\$display = \"\") {\n"
      . "\t\t\$file = __DIR__ . \"/sections/Enterprise.class.php\";\n"
      . "\t\tif (is_file(\$file)) {\n"
      . "\t\t\tinclude_once \$file;\n"
      . "\t\t\t\$class = \\FreePBX\\modules\\Dashboard\\Sections\\Enterprise::class;\n"
      . "\t\t\tif (class_exists(\$class, false) && method_exists(\$class, \"handlePost\")) {\n"
      . "\t\t\t\t\$class::handlePost();\n"
      . "\t\t\t}\n"
      . "\t\t}\n"
      . "\t}";
    if (strpos($text, $old) === false) {
      fwrite(STDERR, "dashboard page init was not patched\n");
      exit(1);
    }
    file_put_contents($path, str_replace($old, $new, $text));
  ' "$DASH_CLASS"
  echo "  patched $DASH_CLASS enterprise upload"
fi
# One System Overview card. When the live class is still stock FreePBX,
# rename it and store it outside sections/ so the dashboard glob does not
# load two Overview classes. Then install the thin overlay. A second run
# sees VOXBOX_OVERVIEW_OVERLAY and keeps the saved parent. After an upgrade
# the live file is stock again, so the new parent is saved first.
if [[ -f "$OVERVIEW_LIVE" && -d "$DASH_CLASSES" ]] && ! grep -q "$OVERVIEW_MARKER" "$OVERVIEW_LIVE"; then
  sed -E 's/^class Overview([[:space:]]*\{)/class OverviewStock\1/' "$OVERVIEW_LIVE" > "$STOCK_OVERVIEW.tmp"
  if command -v php >/dev/null 2>&1; then
    php -l "$STOCK_OVERVIEW.tmp"
  fi
  if grep -q '^class OverviewStock[[:space:]]*{' "$STOCK_OVERVIEW.tmp"; then
    mv -f "$STOCK_OVERVIEW.tmp" "$STOCK_OVERVIEW"
    echo "  saved stock Overview as $STOCK_OVERVIEW"
  else
    rm -f "$STOCK_OVERVIEW.tmp"
    echo "WARNING: could not rename stock Overview; left $OVERVIEW_LIVE unchanged" >&2
  fi
elif [[ -f "$STOCK_OVERVIEW" ]]; then
  echo "  stock Overview parent already saved"
fi
if [[ -f "$SCRIPT_DIR/dashboard/Overview.class.php" && -f "$STOCK_OVERVIEW" && -d "$DASH_SECTIONS" ]]; then
  cp -f "$SCRIPT_DIR/dashboard/Overview.class.php" "$OVERVIEW_LIVE"
  echo "  installed $OVERVIEW_LIVE"
elif [[ -d "$DASH_SECTIONS" ]]; then
  echo "WARNING: System Overview overlay not installed (missing parent or overlay). If the parent file was removed, reinstall the dashboard module and run this script again." >&2
fi
# System Overview already shows uptime. Drop the stock Uptime card.
if [[ -f "$DASH_SECTIONS/Uptime.class.php" ]]; then
  rm -f "$DASH_SECTIONS/Uptime.class.php"
  echo "  removed $DASH_SECTIONS/Uptime.class.php"
fi

# --- Permissions ---
chown asterisk:asterisk "$ADMIN_ROOT/voxbox.css" \
  "$ADMIN_ROOT/assets/js/copyright.js" \
  "$VIEWS_DIR/voxbox_login.php" \
  "$VIEWS_DIR/voxbox_footer_content.php" \
  "$ADMIN_ROOT/modules/ucp/htdocs/views/voxbox_footer_content.php" \
  "$ADMIN_ROOT/modules/ucp/htdocs/views/header.php" \
  "$DASH_SECTIONS/VoxBox.class.php" \
  "$DASH_SECTIONS/Enterprise.class.php" \
  "$DASH_SECTIONS/Notepad.class.php" \
  "$DASH_SECTIONS/Statistics.class.php" \
  "$DASH_SECTIONS/Overview.class.php" \
  "$DASH_CLASSES/VoxBoxOverviewStock.class.php" \
  "$IMAGES_DIR/voxbox-logo.png" \
  "$IMAGES_DIR/voxbox-logo.gif" \
  "$IMAGES_DIR/VoxBox-fiber.gif" \
  "$IMAGES_DIR/VoxBox-fiber-dark.gif" \
  "$IMAGES_DIR/voxbox-favicon.png" \
  "$ADMIN_ROOT/assets/images/badge.png" \
  "$IMAGES_DIR/VoxBox-icon.png" 2>/dev/null || true
chown -R asterisk:asterisk "$ADMIN_ROOT/assets/images/voxbox-icons" 2>/dev/null || true
chown -R asterisk:asterisk "$IMAGES_DIR" 2>/dev/null || true

# --- Keep VoxBox Endpoint Manager enabled ---
if command -v fwconsole >/dev/null 2>&1; then
  echo "==> Enabling endpointman + reload"
  fwconsole ma enable endpointman 2>/dev/null || echo "WARNING: fwconsole ma enable endpointman failed (may already be enabled)"
  # A restored backup can still register the Asteridex module. Remove it.
  fwconsole ma disable asteridex 2>/dev/null || echo "WARNING: could not disable asteridex"
  fwconsole ma uninstall asteridex 2>/dev/null || true
  fwconsole reload || echo "WARNING: fwconsole reload reported errors"
else
  echo "WARNING: fwconsole not in PATH; skip enable/reload"
fi

echo "==> Done. Key settings:"
sql "SELECT keyword,value FROM freepbx_settings WHERE keyword IN ('BRAND_TITLE','BRAND_IMAGE_TANGO_LEFT','BRAND_IMAGE_FREEPBX_LINK_LEFT','BRAND_CSS_CUSTOM','VIEW_LOGIN','RSSFEEDS','UCPRSSFEEDS','SIPUSERAGENT','DASHBOARD_FREEPBX_BRAND') ORDER BY keyword"
