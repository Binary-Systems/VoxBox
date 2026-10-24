#!/bin/bash
# Place the signed VoxBox, System Dashboard, and User Control Panel trees.
# Dashboard and UCP install() delete the module directory, so this script
# does not run those. The VoxBox module install() publishes branding and
# its local signature. An empty System Identity, or the placeholders
# "VoIP Server" and "Dashboard", becomes this machine's hostname.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ADMIN=/var/www/html/admin/modules

find_tarball() {
  local name="$1" candidate
  for candidate in \
    "$HERE/../mirror/$name" \
    "/opt/voxbox/mirror/$name" \
    "/root/VoxBox/mirror/$name" \
    "$(pwd)/mirror/$name"
  do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

place_module() {
  local raw="$1" tarball="$2" tmp src dest
  tmp=$(mktemp -d /tmp/voxbox-mod.XXXXXX)
  if ! tar -C "$tmp" -xzf "$tarball"; then
    echo "WARNING: could not extract $tarball"
    rm -rf "$tmp"
    return 1
  fi
  src=""
  if [ -f "$tmp/$raw/module.xml" ]; then
    src="$tmp/$raw"
  elif [ -f "$tmp/module.xml" ]; then
    src="$tmp"
  fi
  if [ -z "$src" ]; then
    echo "WARNING: $tarball has no module.xml for $raw"
    rm -rf "$tmp"
    return 1
  fi
  dest="$ADMIN/$raw"
  rm -rf "$dest"
  mv "$src" "$dest"
  rm -rf "$tmp"
  chown -R asterisk:asterisk "$dest"
  echo "Placed signed $raw module from $tarball"
}

if [ ! -d "$ADMIN" ]; then
  echo "WARNING: $ADMIN is missing; signed modules were not installed"
  exit 0
fi

fail=0
for spec in "voxbox:voxbox.tgz" "dashboard:voxbox-dashboard.tgz" "ucp:voxbox-ucp.tgz"; do
  raw=${spec%%:*}
  name=${spec#*:}
  if tarball=$(find_tarball "$name"); then
    place_module "$raw" "$tarball" || fail=1
  else
    echo "WARNING: $name was not found"
    fail=1
  fi
done

if [ -d "$ADMIN/voxbox" ] && command -v fwconsole >/dev/null 2>&1; then
  fwconsole ma install voxbox || echo "WARNING: fwconsole ma install voxbox reported errors"
  fwconsole ma enable voxbox || true
fi

php << 'PHP'
<?php
function voxbox_say($label, $list)
{
    if (!is_array($list)) {
        $list = array((string) $list);
    }
    echo $label . '=' . implode(',', $list) . "\n";
}
$jobs = array(
    array('/var/www/html/admin/modules/dashboard/install/voxbox-local-signature.php', 'voxbox_dashboard_install_local_signature', '/var/www/html/admin/modules/dashboard', 'dashboard_sig'),
    array('/var/www/html/admin/modules/ucp/install/voxbox-local-signature.php', 'voxbox_ucp_install_local_signature', '/var/www/html/admin/modules/ucp', 'ucp_sig'),
    array('/var/www/html/admin/modules/voxbox/install/voxbox-local-signature.php', 'voxbox_install_local_signature', '/var/www/html/admin/modules/voxbox', 'voxbox_sig'),
);
foreach ($jobs as $job) {
    if (!is_file($job[0])) {
        echo $job[3] . "=missing\n";
        continue;
    }
    require_once $job[0];
    if (!function_exists($job[1])) {
        echo $job[3] . "=missing\n";
        continue;
    }
    voxbox_say($job[3], $job[1]($job[2]));
}
PHP

if command -v runuser >/dev/null 2>&1; then
  runuser -u asterisk -- php << 'PHP'
<?php
$bootstrap_settings['freepbx_auth'] = false;
include '/etc/freepbx.conf';
foreach (array('voxbox', 'dashboard', 'ucp') as $raw) {
    $dir = '/var/www/html/admin/modules/' . $raw . '/module.xml';
    if (!is_file($dir)) {
        echo $raw . "=absent\n";
        continue;
    }
    $xml = @simplexml_load_file($dir);
    $ver = ($xml && isset($xml->version)) ? (string) $xml->version : '';
    if ($ver !== '') {
        try {
            $st = FreePBX::Database()->prepare('UPDATE modules SET version = ? WHERE modulename = ?');
            $st->execute(array($ver, $raw));
        } catch (Throwable $e) {
            echo $raw . "_version=failed\n";
        }
    }
    try {
        $mod = module_functions::create()->updateSignature($raw);
        $status = isset($mod['status']) ? $mod['status'] : 'none';
        $details = isset($mod['details']) && is_array($mod['details']) ? count($mod['details']) : 0;
        echo $raw . " sigstatus=" . $status . " details=" . $details . "\n";
    } catch (Throwable $e) {
        echo $raw . " sigstatus=failed\n";
    }
}
try {
    $cur = trim((string) FreePBX::Config()->get('FREEPBX_SYSTEM_IDENT'));
    if ($cur === '' || $cur === 'VoIP Server' || $cur === 'Dashboard') {
        $host = gethostname();
        if (is_string($host) && trim($host) !== '') {
            FreePBX::Config()->update('FREEPBX_SYSTEM_IDENT', trim($host));
            echo "system_ident=hostname\n";
        }
    } else {
        echo "system_ident=kept\n";
    }
} catch (Throwable $e) {
    echo "system_ident=failed\n";
}
PHP
else
  echo "WARNING: runuser is missing; signatures were not refreshed"
  fail=1
fi

exit "$fail"
