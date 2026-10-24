<?php
/**
 * VoxBox branding module.
 *
 * Analogous to IncrediblePBX: install and enable point FreePBX at the
 * views, stylesheet, and images that ship in this module. Disable and
 * uninstall put those settings back to their FreePBX defaults.
 * IncrediblePBX is removed and later install attempts are rejected.
 *
 * Copyright (C) 2007-2026 Binary Systems, Inc.
 * License: AGPLv3+
 */
namespace FreePBX\modules;

class Voxbox implements \BMO
{
    private $FreePBX;

    public function __construct($freepbx = null)
    {
        if (!is_object($freepbx)) {
            throw new \Exception('Not given a FreePBX Object');
        }
        $this->FreePBX = $freepbx;
    }

    public function install()
    {
        $this->publishSignature();
        $this->removeIncrediblepbx();
        $this->applyBranding();
        return true;
    }

    public function uninstall()
    {
        $this->resetBranding();
        return true;
    }

    public function enable()
    {
        $this->applyBranding();
        return true;
    }

    public function disable()
    {
        $this->resetBranding();
        return true;
    }

    /**
     * Settings this module owns. Paths are relative to the admin web root
     * unless they start with a slash. UCP is served from /ucp/, so the cube
     * and the icon folder stay absolute.
     * VIEW_UCP_FOOTER_CONTENT stays inside the User Control Panel module.
     */
    private function brandSettings()
    {
        return array(
            'BRAND_TITLE' => 'VoxBox Admin',
            'BRAND_IMAGE_FAVICON' => 'modules/voxbox/assets/images/voxbox-favicon.png',
            'BRAND_IMAGE_TANGO_LEFT' => '/admin/modules/voxbox/assets/images/voxbox-favicon.png',
            'BRAND_FREEPBX_ALT_LEFT' => 'VoxBox',
            'BRAND_FREEPBX_ALT_FOOT' => 'Binary Systems, Inc.',
            'BRAND_IMAGE_FREEPBX_LINK_LEFT' => '/admin/config.php?display=index',
            'BRAND_IMAGE_FREEPBX_LINK_FOOT' => 'http://www.binary-systems.com/',
            'BRAND_IMAGE_FREEPBX_FOOT' => 'modules/voxbox/assets/images/binary_systems_si_animated.gif',
            'BRAND_CSS_CUSTOM' => 'modules/voxbox/assets/css/voxbox.css',
            'BRAND_IMAGE_SPONSOR_LINK_FOOT' => '',
            'BRAND_SPONSOR_ALT_FOOT' => '',
            'VIEW_LOGIN' => 'modules/voxbox/views/login.php',
            'VIEW_MENU' => 'modules/voxbox/views/menu.php',
            'VIEW_FOOTER_CONTENT' => 'modules/voxbox/views/footer_content.php',
            'VIEW_UCP_FOOTER_CONTENT' => 'views/voxbox_footer_content.php',
            'VIEW_UCP_ICONS_FOLDER' => '/admin/modules/voxbox/assets/images/voxbox-icons',
            'RSSFEEDS' => '',
            'UCPRSSFEEDS' => '',
            'SIPUSERAGENT' => 'VoxBox',
            'DASHBOARD_FREEPBX_BRAND' => 'VoxBox 2026',
            'USE_FREEPBX_MENU_CONF' => '1',
        );
    }

    private function applyBranding()
    {
        $this->publishLinks();
        $this->hideStockWiki();
        $this->writeSettings($this->brandSettings());
        $this->clearIncredibleStrings();
    }

    private function resetBranding()
    {
        $keys = array_keys($this->brandSettings());
        $present = $this->presentKeywords($keys);
        if (!$present) {
            return;
        }
        $this->FreePBX->Config->reset_conf_settings($present, true);
    }

    private function writeSettings($wanted)
    {
        $present = $this->presentKeywords(array_keys($wanted));
        $config = $this->FreePBX->Config;
        foreach ($wanted as $key => $value) {
            if (!in_array($key, $present, true)) {
                continue;
            }
            if ((string) $config->get($key) === (string) $value) {
                continue;
            }
            $config->set_conf_values(array($key => $value), true, true);
        }
    }

    private function presentKeywords($keys)
    {
        $keys = array_values($keys);
        if (!$keys) {
            return array();
        }
        $marks = implode(',', array_fill(0, count($keys), '?'));
        $stmt = $this->FreePBX->Database->prepare(
            "SELECT keyword FROM freepbx_settings WHERE keyword IN ($marks)"
        );
        $stmt->execute($keys);
        $rows = $stmt->fetchAll(\PDO::FETCH_COLUMN);
        return is_array($rows) ? $rows : array();
    }

    private function clearIncredibleStrings()
    {
        $sql = 'UPDATE freepbx_settings SET value = REPLACE(value, ?, ?) WHERE value LIKE ?';
        $stmt = $this->FreePBX->Database->prepare($sql);
        $pairs = array(
            array('Incredible PBX', 'VoxBox', '%Incredible PBX%'),
            array('IncrediblePBX', 'VoxBox', '%IncrediblePBX%'),
            array('incrediblepbx.com', 'binary-systems.com', '%incrediblepbx.com%'),
        );
        foreach ($pairs as $pair) {
            $stmt->execute($pair);
        }
    }

    private function publishSignature()
    {
        $sig = __DIR__ . '/install/voxbox-local-signature.php';
        if (!is_file($sig)) {
            return;
        }
        require_once $sig;
        if (function_exists('voxbox_install_local_signature')) {
            voxbox_install_local_signature(__DIR__);
        }
    }

    /**
     * Paths the signed User Control Panel still requests by their old URLs.
     * The files live in this module. The links keep those URLs working.
     */
    private function publishLinks()
    {
        $admin = rtrim($this->FreePBX->Config->get('AMPWEBROOT'), '/') . '/admin';
        $mod = $admin . '/modules/voxbox';
        $links = array(
            $admin . '/voxbox.css' => $mod . '/assets/css/voxbox.css',
            $admin . '/assets/js/copyright.js' => $mod . '/assets/js/copyright.js',
            $admin . '/assets/images/badge.png' => $mod . '/assets/images/voxbox-favicon.png',
            $admin . '/assets/images/voxbox-icons' => $mod . '/assets/images/voxbox-icons',
            $admin . '/images/voxbox-favicon.png' => $mod . '/assets/images/voxbox-favicon.png',
            $admin . '/images/VoxBox-fiber.gif' => $mod . '/assets/images/VoxBox-fiber.gif',
            $admin . '/images/VoxBox-fiber-dark.gif' => $mod . '/assets/images/VoxBox-fiber-dark.gif',
            $admin . '/images/voxbox-logo.gif' => $mod . '/assets/images/VoxBox-fiber.gif',
            $admin . '/images/binary_systems_si_animated.gif' => $mod . '/assets/images/binary_systems_si_animated.gif',
            $admin . '/images/binary_systems_si_animated@2x.gif' => $mod . '/assets/images/binary_systems_si_animated@2x.gif',
            $admin . '/images/binary_systems_si_animated_reverse-clear.gif' => $mod . '/assets/images/binary_systems_si_animated_reverse-clear.gif',
            $admin . '/images/binary_systems_si_animated_reverse-clear@2x.gif' => $mod . '/assets/images/binary_systems_si_animated_reverse-clear@2x.gif',
            $admin . '/images/binary_systems_si_still.png' => $mod . '/assets/images/binary_systems_si_still.png',
            $admin . '/images/binary_systems_si_still@2x.png' => $mod . '/assets/images/binary_systems_si_still@2x.png',
            $admin . '/images/binary_systems_si_still_reverse-clear.png' => $mod . '/assets/images/binary_systems_si_still_reverse-clear.png',
            $admin . '/images/binary_systems_si_still_reverse-clear@2x.png' => $mod . '/assets/images/binary_systems_si_still_reverse-clear@2x.png',
        );
        foreach ($links as $link => $target) {
            $this->linkTo($link, $target);
        }
    }

    private function linkTo($link, $target)
    {
        if (!file_exists($target)) {
            return;
        }
        $real = realpath($target);
        if ($real === false) {
            return;
        }
        if (is_link($link)) {
            if (readlink($link) === $real) {
                return;
            }
            unlink($link);
        } elseif (is_dir($link)) {
            $this->removeTree($link);
        } elseif (file_exists($link)) {
            unlink($link);
        }
        $dir = dirname($link);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        symlink($real, $link);
    }

    private function removeTree($dir)
    {
        $admin = rtrim($this->FreePBX->Config->get('AMPWEBROOT'), '/') . '/admin';
        $allowed = $admin . '/assets/images/voxbox-icons';
        if (is_link($dir) || !is_dir($dir)) {
            return;
        }
        $real = realpath($dir);
        if ($real !== $allowed) {
            return;
        }
        $items = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($real, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::CHILD_FIRST
        );
        foreach ($items as $item) {
            if ($item->isDir()) {
                rmdir($item->getPathname());
            } else {
                unlink($item->getPathname());
            }
        }
        rmdir($real);
    }

    private function hideStockWiki()
    {
        $etc = $this->FreePBX->Config->get('ASTETCDIR');
        if (!$etc) {
            $etc = '/etc/asterisk';
        }
        $path = rtrim($etc, '/') . '/freepbx_menu.conf';
        $text = is_file($path) ? (string) file_get_contents($path) : '';
        if (preg_match('/^\[wiki\]/m', $text)) {
            return;
        }
        $block = "\n; VoxBox: hide stock FreePBX Support wiki menu item on login navbar\n[wiki]\nremove = 1\n";
        file_put_contents($path, $text . $block);
    }

    /**
     * Drop IncrediblePBX before branding settings are written.
     * Its uninstall puts the shared brand settings back to FreePBX defaults.
     * A directory that is not installed is removed without that reset.
     */
    private function removeIncrediblepbx()
    {
        $admin = rtrim($this->FreePBX->Config->get('AMPWEBROOT'), '/') . '/admin';
        $dir = $admin . '/modules/incrediblepbx';
        if (is_link($dir)) {
            unlink($dir);
        }
        if (is_dir($dir) || is_file($dir . '/module.xml')) {
            try {
                $mf = \module_functions::create();
                $mf->delete('incrediblepbx', true);
            } catch (\Throwable $e) {
                // The directory is removed below when delete did not finish.
            }
        }
        if (is_link($dir)) {
            unlink($dir);
        } elseif (is_dir($dir)) {
            $parent = realpath($admin . '/modules');
            $real = realpath($dir);
            if ($parent && $real && $real === $parent . '/incrediblepbx') {
                exec('rm -r ' . escapeshellarg($real));
            }
        }
        try {
            $stmt = $this->FreePBX->Database->prepare(
                'DELETE FROM modules WHERE modulename = ?'
            );
            $stmt->execute(array('incrediblepbx'));
        } catch (\Throwable $e) {
            // The row is already gone.
        }
    }
}
