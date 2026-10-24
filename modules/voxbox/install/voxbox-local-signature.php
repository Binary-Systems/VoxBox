<?php
/**
 * Install the root-owned local signature FreePBX uses for the VoxBox module.
 *
 * module.sig says type=local. FreePBX then checks /etc/freepbx.secure/voxbox.sig,
 * which must be owned by root and match the hash inside module.sig.
 * The signing key is not a Sangoma key, so it stays untrusted in GPG.
 * Ultimate trust would skip this local check and look for a file named voxbox.sig
 * inside the module.
 *
 * Safe to run more than once. Only root can publish the secure file.
 */

function voxbox_install_local_signature($module_dir)
{
    $notes = array();
    if (!function_exists('posix_geteuid') || posix_geteuid() !== 0) {
        return array('local signature install skipped (not root)');
    }

    $module_dir = rtrim((string) $module_dir, '/');
    $src = $module_dir . '/signatures/voxbox.local.sig';
    if (!is_file($src)) {
        return array('local signature payload missing');
    }

    $sec = '/etc/freepbx.secure';
    if (is_link($sec)) {
        return array('refusing to use a linked /etc/freepbx.secure');
    }
    if (!is_dir($sec) && !mkdir($sec, 0755)) {
        return array('could not create /etc/freepbx.secure');
    }

    $dst = $sec . '/voxbox.sig';
    if (is_link($dst)) {
        return array('refusing to replace a linked voxbox.sig');
    }
    if (!copy($src, $dst)) {
        return array('could not copy the local signature');
    }

    chown($sec, 0);
    chgrp($sec, 0);
    chmod($sec, 0755);
    chown($dst, 0);
    chgrp($dst, 0);
    chmod($dst, 0644);
    $notes[] = 'installed /etc/freepbx.secure/voxbox.sig';

    $pub = $module_dir . '/signatures/voxbox.asc';
    if (!is_file($pub)) {
        $notes[] = 'public key missing';
        return $notes;
    }

    $gpghome = '/var/lib/asterisk/.gnupg';
    $cmd = 'runuser -u asterisk -- gpg --homedir ' . escapeshellarg($gpghome)
        . ' --batch --import ' . escapeshellarg($pub) . ' >/dev/null 2>&1';
    exec($cmd, $out, $rc);
    $notes[] = ($rc === 0) ? 'imported the signature public key' : 'public key import failed';
    return $notes;
}
