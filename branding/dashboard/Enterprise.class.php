<?php
// Node image card for VoxBox System Dashboard.
// Copyright (C) 2007-2026 Binary Systems, Inc.
//
// This file ships as modules/dashboard/sections/Enterprise.class.php.
// FreePBX loads every *.class.php in that directory when the dashboard opens.
// The dashboard page does not call Dashboard::doConfigPageInit, because the
// menu key is dashboard while the display is index. getSections() runs while
// that page is being built, and that is where the upload is saved.
// An animated GIF is kept as a GIF. Flattening it to one PNG frame drops
// the animation, and the first frame of this logo is not the picture.
// Transparent pixels use a white box the same size as the image. A full-width
// pad would paint past the picture and hide a black logo at night.
// The title bar is "Node - " plus FREEPBX_SYSTEM_IDENT. System Identity
// and Upload sit behind Change, and Upload writes the name with the picture.
// An empty name is filled with this machine's hostname. A saved name is
// left alone until that form sets a new one.
// With no uploaded picture, the card shows the VoxBox favicon. Until that
// default is replaced, the closed card shows only the Change button.
// Opening Change widens the form to the card and asks Packery to measure
// the new height so the fields are not covered by the next card.

namespace FreePBX\modules\Dashboard\Sections;

class Enterprise {
	public $rawname = 'Enterprise';

	public function getSections($order) {
		self::handlePost();
		self::publishNotice();
		$saved = is_array($order) ? $order : [];
		return [[
			'title' => self::cardTitle(),
			'group' => _('VoxBox'),
			'width' => '550px',
			'order' => $saved['enterprise'] ?? 0,
			'section' => 'enterprise',
		]];
	}

	public function getContent($section) {
		if ((string) $section !== 'enterprise') {
			return '';
		}
		$notice = self::pullNotice();
		$shown = self::shownFile();
		$fallback = $shown ? null : self::defaultImage();

		$html = '<div class="voxbox-enterprise" style="padding:4px 8px 8px;">';
		if ($shown) {
			$html .= self::imageHtml(
				'images/voxbox-enterprise.' . $shown['ext'],
				$shown['path'],
				_('Node')
			);
		} elseif ($fallback) {
			$html .= self::imageHtml($fallback['src'], $fallback['path'], _('VoxBox'));
		} else {
			$html .= '<p class="text-center text-muted" style="margin:18px 0;">'
				. self::e(_('No image yet.'))
				. '</p>';
		}
		$open = $notice !== ''
			&& $notice !== _('Image saved.')
			&& $notice !== _('Image removed.')
			&& $notice !== _('Name saved.');
		$html .= '<style>'
			. '.voxbox-node-change{display:inline-block;vertical-align:middle;}'
			. '.voxbox-node-change>summary{list-style:none;cursor:pointer;display:inline-block;}'
			. '.voxbox-node-change>summary::-webkit-details-marker{display:none;}'
			. '.voxbox-node-change[open]{display:block;width:100%;}'
			. '</style>';
		$html .= '<form method="post" enctype="multipart/form-data" action="config.php?display=index" style="margin-top:12px;text-align:center;">';
		$html .= '<input type="hidden" name="voxbox_enterprise" value="1">';
		$html .= '<details class="voxbox-node-change"' . ($open ? ' open' : '')
			. ' ontoggle="var el=this;setTimeout(function(){var p=el.closest(\'.page\');if(window.jQuery&&p){window.jQuery(p).packery(\'layout\');}},0)">';
		$html .= '<summary class="btn btn-sm btn-default">' . self::e(_('Change')) . '</summary>';
		$html .= '<div style="margin-top:8px;text-align:left;">';
		$html .= '<label for="voxbox_system_ident" style="display:block;margin-bottom:4px;">'
			. self::e(_('System Identity'))
			. '</label>';
		$html .= '<input class="form-control" type="text" id="voxbox_system_ident" name="voxbox_system_ident" maxlength="255" autocomplete="off" value="'
			. self::e(self::identFieldValue())
			. '">';
		$html .= '<input class="form-control" type="file" name="enterprise_image" accept="image/png,image/jpeg,image/gif,image/webp" style="margin-top:8px;">';
		$html .= '<div style="margin-top:8px;text-align:center;">';
		$html .= '<button type="submit" class="btn btn-sm btn-default" name="voxbox_enterprise_action" value="upload">'
			. self::e(_('Upload'))
			. '</button>';
		$html .= '</div></div></details>';
		if ($notice !== '') {
			$html .= ' <span style="margin-left:8px;vertical-align:middle;">' . self::e($notice) . '</span>';
		}
		$html .= '</form></div>';
		return $html;
	}

	public static function handlePost(): void {
		if (($_POST['voxbox_enterprise'] ?? '') !== '1') {
			return;
		}
		if (empty($_SESSION['AMP_user']) && (!defined('FREEPBX_IS_AUTH') || FREEPBX_IS_AUTH !== 'TRUE')) {
			return;
		}
		$action = (string) ($_POST['voxbox_enterprise_action'] ?? '');
		try {
			if ($action === 'remove') {
				$failed = false;
				foreach (self::storedFiles() as $path) {
					if (is_file($path) && !@unlink($path)) {
						$failed = true;
					}
				}
				$_SESSION['voxbox_enterprise_notice'] = $failed
					? _('The image could not be removed.')
					: _('Image removed.');
			} elseif ($action === 'upload') {
				$_SESSION['voxbox_enterprise_notice'] = self::savePictureAndIdent($_FILES['enterprise_image'] ?? null);
			} elseif ($action === 'name') {
				$_SESSION['voxbox_enterprise_notice'] = self::saveIdentOnly();
			}
		} catch (\Throwable $e) {
			$_SESSION['voxbox_enterprise_notice'] = _('The image could not be saved.');
		}
		header('Location: config.php?display=index', true, 303);
		exit;
	}

	/**
	 * @param array<string,mixed>|null $file
	 */
	public static function storeUpload($file): string {
		if (!is_array($file)) {
			return _('Choose an image first.');
		}
		$err = (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE);
		if ($err === UPLOAD_ERR_NO_FILE) {
			return _('Choose an image first.');
		}
		if ($err === UPLOAD_ERR_INI_SIZE || $err === UPLOAD_ERR_FORM_SIZE) {
			return _('That image is larger than 2 MB.');
		}
		if ($err !== UPLOAD_ERR_OK) {
			return _('The image could not be saved.');
		}
		$tmp = (string) ($file['tmp_name'] ?? '');
		if ($tmp === '' || !is_uploaded_file($tmp)) {
			return _('The image could not be saved.');
		}
		$size = (int) ($file['size'] ?? 0);
		if ($size < 1 || $size > 2 * 1024 * 1024) {
			return _('That image is larger than 2 MB.');
		}
		$info = @getimagesize($tmp);
		if (!is_array($info) || empty($info['mime']) || empty($info[0]) || empty($info[1])) {
			return _('Choose a PNG, JPEG, GIF, or WebP image.');
		}
		if ((int) $info[0] * (int) $info[1] > 16000000) {
			return _('That image is too large to use.');
		}
		$mime = (string) $info['mime'];
		if ($mime === 'image/gif' && self::isAnimatedGif($tmp)) {
			return self::storeGifFile($tmp);
		}
		return self::writeImage($tmp, $mime);
	}

	public static function writeImage(string $source, string $mime): string {
		$src = self::loadImage($source, $mime);
		if (!$src) {
			return _('Choose a PNG, JPEG, GIF, or WebP image.');
		}
		$w = imagesx($src);
		$h = imagesy($src);
		if ($w < 1 || $h < 1) {
			imagedestroy($src);
			return _('The image could not be read.');
		}
		$max = 1200;
		$scale = min(1, $max / max($w, $h));
		$nw = max(1, (int) round($w * $scale));
		$nh = max(1, (int) round($h * $scale));
		$dst = imagecreatetruecolor($nw, $nh);
		if (!$dst) {
			imagedestroy($src);
			return _('The image could not be saved.');
		}
		imagealphablending($dst, false);
		imagesavealpha($dst, true);
		$clear = imagecolorallocatealpha($dst, 0, 0, 0, 127);
		imagefilledrectangle($dst, 0, 0, $nw, $nh, $clear);
		imagecopyresampled($dst, $src, 0, 0, 0, 0, $nw, $nh, $w, $h);
		imagedestroy($src);

		$path = self::imagePath();
		$dir = dirname($path);
		if (!is_dir($dir) || !is_writable($dir)) {
			imagedestroy($dst);
			return _('The image could not be saved.');
		}
		$tmpOut = $dir . '/voxbox-enterprise-' . bin2hex(random_bytes(4)) . '.tmp';
		$written = imagepng($dst, $tmpOut, 6);
		imagedestroy($dst);
		if (!$written || !is_file($tmpOut)) {
			@unlink($tmpOut);
			return _('The image could not be saved.');
		}
		chmod($tmpOut, 0644);
		if (!rename($tmpOut, $path)) {
			@unlink($tmpOut);
			return _('The image could not be saved.');
		}
		chmod($path, 0644);
		self::removeExcept('png');
		return _('Image saved.');
	}

	public static function storeGifFile(string $source): string {
		$info = @getimagesize($source);
		if (!is_array($info) || ($info['mime'] ?? '') !== 'image/gif' || !self::isAnimatedGif($source)) {
			return _('Choose a PNG, JPEG, GIF, or WebP image.');
		}
		if (filesize($source) > 2 * 1024 * 1024) {
			return _('That image is larger than 2 MB.');
		}
		$path = self::fileFor('gif');
		$dir = dirname($path);
		if (!is_dir($dir) || !is_writable($dir)) {
			return _('The image could not be saved.');
		}
		$tmpOut = $dir . '/voxbox-enterprise-' . bin2hex(random_bytes(4)) . '.tmp';
		if (!copy($source, $tmpOut)) {
			return _('The image could not be saved.');
		}
		chmod($tmpOut, 0644);
		if (!rename($tmpOut, $path)) {
			@unlink($tmpOut);
			return _('The image could not be saved.');
		}
		chmod($path, 0644);
		self::removeExcept('gif');
		return _('Image saved.');
	}

	public static function imagePath(): string {
		return self::fileFor('png');
	}

	/**
	 * Move the upload message out of the session when the dashboard page is built.
	 * The card request shows it once. A later page load finds neither copy.
	 */
	public static function publishNotice(): void {
		if (empty($_SESSION['voxbox_enterprise_notice'])) {
			return;
		}
		$notice = (string) $_SESSION['voxbox_enterprise_notice'];
		unset($_SESSION['voxbox_enterprise_notice']);
		try {
			$cache = \FreePBX::Cache()->cloneByNamespace('voxboxenterprise');
			$cache->save(self::noticeKey(), $notice, 120);
		} catch (\Throwable $e) {
			$_SESSION['voxbox_enterprise_notice'] = $notice;
		}
	}

	public static function pullNotice(): string {
		try {
			$cache = \FreePBX::Cache()->cloneByNamespace('voxboxenterprise');
			$key = self::noticeKey();
			$notice = $cache->fetch($key);
			if (is_string($notice) && $notice !== '') {
				$cache->delete($key);
				return $notice;
			}
		} catch (\Throwable $e) {
		}
		if (!empty($_SESSION['voxbox_enterprise_notice'])) {
			$notice = (string) $_SESSION['voxbox_enterprise_notice'];
			unset($_SESSION['voxbox_enterprise_notice']);
			return $notice;
		}
		return '';
	}

	private static function noticeKey(): string {
		$id = session_id();
		if ($id === '') {
			$id = 'anon';
		}
		return 'notice-' . $id;
	}

	public static function shownFile(): ?array {
		foreach (array('gif', 'png') as $ext) {
			$path = self::fileFor($ext);
			if (is_file($path)) {
				return array('path' => $path, 'ext' => $ext);
			}
		}
		return null;
	}

	/**
	 * The VoxBox cube, used only when no Node picture has been uploaded.
	 * The module file is the real favicon. admin/images/voxbox-favicon.png
	 * on a live PBX can be a tiny placeholder, so it is used only when it
	 * is an actual image.
	 *
	 * @return array{path:string,src:string}|null
	 */
	private static function defaultImage(): ?array {
		$root = rtrim((string) \FreePBX::Config()->get('AMPWEBROOT'), '/');
		$candidates = array(
			array(
				'path' => $root . '/admin/modules/voxbox/assets/images/voxbox-favicon.png',
				'src' => 'modules/voxbox/assets/images/voxbox-favicon.png',
			),
			array(
				'path' => $root . '/admin/images/voxbox-favicon.png',
				'src' => 'images/voxbox-favicon.png',
			),
		);
		foreach ($candidates as $item) {
			if (!is_file($item['path'])) {
				continue;
			}
			$dim = @getimagesize($item['path']);
			if (!is_array($dim) || empty($dim[0]) || empty($dim[1])) {
				continue;
			}
			return $item;
		}
		return null;
	}

	private static function imageHtml(string $src, string $path, string $alt): string {
		$dim = @getimagesize($path);
		$wh = '';
		if (is_array($dim) && !empty($dim[0]) && !empty($dim[1])) {
			$wh = ' width="' . (int) $dim[0] . '" height="' . (int) $dim[1] . '"';
		}
		$url = $src;
		if (is_file($path)) {
			$url .= '?v=' . (string) filemtime($path);
		}
		return '<div style="text-align:center;">'
			. '<span style="display:inline-block;max-width:100%;line-height:0;background-color:#ffffff;">'
			. '<img src="' . self::e($url) . '" alt="' . self::e($alt) . '"' . $wh . ' '
			. 'style="display:block;max-width:100%;height:auto;background-color:#ffffff;">'
			. '</span></div>';
	}

	private static function fileFor(string $ext): string {
		$root = rtrim((string) \FreePBX::Config()->get('AMPWEBROOT'), '/');
		return $root . '/admin/images/voxbox-enterprise.' . $ext;
	}

	private static function storedFiles(): array {
		return array(self::fileFor('gif'), self::fileFor('png'));
	}

	private static function removeExcept(string $keep): void {
		foreach (array('gif', 'png') as $ext) {
			if ($ext === $keep) {
				continue;
			}
			$path = self::fileFor($ext);
			if (is_file($path)) {
				@unlink($path);
			}
		}
	}

	private static function isAnimatedGif(string $path): bool {
		$head = file_get_contents($path, false, null, 0, 6);
		if ($head !== 'GIF87a' && $head !== 'GIF89a') {
			return false;
		}
		$data = file_get_contents($path);
		if ($data === false) {
			return false;
		}
		return substr_count($data, "\x21\xF9\x04") > 1;
	}

	private static function loadImage(string $source, string $mime) {
		switch ($mime) {
			case 'image/png':
				return @imagecreatefrompng($source);
			case 'image/jpeg':
				return @imagecreatefromjpeg($source);
			case 'image/gif':
				return @imagecreatefromgif($source);
			case 'image/webp':
				if (!function_exists('imagecreatefromwebp')) {
					return false;
				}
				return @imagecreatefromwebp($source);
			default:
				return false;
		}
	}

	private static function cardTitle(): string {
		$title = _('Node');
		$name = self::systemName();
		if ($name !== '') {
			$title .= ' - ' . $name;
		}
		return self::e($title);
	}

	/**
	 * @param array<string,mixed>|null $file
	 */
	private static function savePictureAndIdent($file): string {
		$check = self::checkIdent((string) ($_POST['voxbox_system_ident'] ?? ''));
		if ($check !== '') {
			return $check;
		}
		$notice = self::storeUpload($file);
		if ($notice !== _('Image saved.')) {
			return $notice;
		}
		if (!self::saveSystemIdent(self::cleanIdent((string) ($_POST['voxbox_system_ident'] ?? '')))) {
			return _('The image was saved, but the name could not be saved.');
		}
		return _('Image saved.');
	}

	private static function saveIdentOnly(): string {
		$check = self::checkIdent((string) ($_POST['voxbox_system_ident'] ?? ''));
		if ($check !== '') {
			return $check;
		}
		if (!self::saveSystemIdent(self::cleanIdent((string) ($_POST['voxbox_system_ident'] ?? '')))) {
			return _('The name could not be saved.');
		}
		return _('Name saved.');
	}

	private static function checkIdent(string $raw): string {
		$name = self::cleanIdent($raw);
		if ($name === '') {
			return _('Enter a system identity.');
		}
		$length = function_exists('mb_strlen') ? mb_strlen($name, 'UTF-8') : strlen($name);
		if ($length > 255) {
			return _('That system identity is too long.');
		}
		return '';
	}

	private static function cleanIdent(string $raw): string {
		$name = preg_replace('/[\x00-\x1F\x7F]/u', '', $raw);
		if (!is_string($name)) {
			return '';
		}
		return trim($name);
	}

	private static function identFieldValue(): string {
		$name = trim((string) \FreePBX::Config()->get('FREEPBX_SYSTEM_IDENT'));
		if ($name !== '') {
			return $name;
		}
		return self::hostname();
	}

	private static function saveSystemIdent(string $name): bool {
		if (self::checkIdent($name) !== '') {
			return false;
		}
		$current = trim((string) \FreePBX::Config()->get('FREEPBX_SYSTEM_IDENT'));
		if ($current === $name) {
			return true;
		}
		try {
			\FreePBX::Config()->update('FREEPBX_SYSTEM_IDENT', $name);
		} catch (\Throwable $e) {
			return false;
		}
		return trim((string) \FreePBX::Config()->get('FREEPBX_SYSTEM_IDENT')) === $name;
	}

	private static function systemName(): string {
		$name = trim((string) \FreePBX::Config()->get('FREEPBX_SYSTEM_IDENT'));
		if ($name !== '') {
			return $name;
		}
		$host = self::hostname();
		if ($host === '') {
			return '';
		}
		try {
			\FreePBX::Config()->update('FREEPBX_SYSTEM_IDENT', $host);
		} catch (\Throwable $e) {
		}
		return $host;
	}

	private static function hostname(): string {
		$host = gethostname();
		if (!is_string($host)) {
			return '';
		}
		return trim($host);
	}

	private static function e(string $text): string {
		return htmlspecialchars($text, ENT_QUOTES, 'UTF-8');
	}
}
