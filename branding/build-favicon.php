<?php
/**
 * Build square VoxBox favicons from branding/VoxBox-icon-clean.png.
 *
 * The source cube is not square. Browsers ignore a non-square .ico and keep
 * the cached FreePBX frog, so this pads the art onto a transparent square
 * and then scales. A smaller VoxBox-icon-*.png is used only when the clean
 * source is missing.
 *
 * Usage: php build-favicon.php <branding-dir> <output-dir>
 * Copyright (C) 2007-2026 Binary Systems, Inc.
 */
if ($argc < 3) {
	fwrite(STDERR, "usage: php build-favicon.php <branding-dir> <output-dir>\n");
	exit(1);
}
if (!function_exists('imagecreatefrompng')) {
	fwrite(STDERR, "php-gd is required to build the VoxBox favicon\n");
	exit(1);
}

$brandDir = $argv[1];
$outDir = $argv[2];
$sources = [
	'VoxBox-icon-clean.png',
	'VoxBox-icon-64.png',
	'VoxBox-icon-48.png',
	'VoxBox-icon-32.png',
	'VoxBox-icon-16.png',
	'VoxBox-icon.png',
];
$srcPath = '';
foreach ($sources as $name) {
	$path = $brandDir . '/' . $name;
	if (is_file($path)) {
		$srcPath = $path;
		break;
	}
}
if ($srcPath === '') {
	fwrite(STDERR, "no VoxBox icon source under $brandDir\n");
	exit(1);
}

$src = imagecreatefrompng($srcPath);
if ($src === false) {
	fwrite(STDERR, "could not read $srcPath\n");
	exit(1);
}
if (!imageistruecolor($src)) {
	imagepalettetotruecolor($src);
}
imagealphablending($src, false);
imagesavealpha($src, true);

$square = square_pad($src);
imagedestroy($src);

@mkdir($outDir, 0755, true);
@mkdir($outDir . '/ucp-icons', 0755, true);

$ucpSizes = [16, 60, 76, 120, 128, 152, 192];
foreach ($ucpSizes as $size) {
	write_png(scale_square($square, $size), $outDir . "/ucp-icons/{$size}x{$size}.png");
}

// Tab icon. 192 is sharp on a high-dpi tab and is a real square PNG,
// which is what browsers accept when they discard favicon.ico.
write_png(scale_square($square, 192), $outDir . '/voxbox-favicon.png');

$icoSizes = [16, 32, 48];
$blobs = [];
foreach ($icoSizes as $size) {
	$tmp = $outDir . "/.ico-$size.png";
	write_png(scale_square($square, $size), $tmp);
	$blobs[$size] = file_get_contents($tmp);
	unlink($tmp);
}
write_ico($outDir . '/favicon.ico', $blobs);
imagedestroy($square);

fwrite(STDOUT, "built favicons from $srcPath\n");
exit(0);

function new_canvas($w, $h) {
	$im = imagecreatetruecolor($w, $h);
	imagealphablending($im, false);
	imagesavealpha($im, true);
	$clear = imagecolorallocatealpha($im, 0, 0, 0, 127);
	imagefilledrectangle($im, 0, 0, $w - 1, $h - 1, $clear);
	return $im;
}

function square_pad($src) {
	$w = imagesx($src);
	$h = imagesy($src);
	$side = max($w, $h);
	$dst = new_canvas($side, $side);
	$x = intdiv($side - $w, 2);
	$y = intdiv($side - $h, 2);
	imagecopy($dst, $src, $x, $y, 0, 0, $w, $h);
	return $dst;
}

function scale_square($square, $size) {
	$dst = new_canvas($size, $size);
	imagecopyresampled(
		$dst,
		$square,
		0,
		0,
		0,
		0,
		$size,
		$size,
		imagesx($square),
		imagesy($square)
	);
	imagealphablending($dst, false);
	imagesavealpha($dst, true);
	return $dst;
}

function write_png($im, $path) {
	$dir = dirname($path);
	if (!is_dir($dir)) {
		mkdir($dir, 0755, true);
	}
	if (!imagepng($im, $path, 9)) {
		fwrite(STDERR, "could not write $path\n");
		exit(1);
	}
	imagedestroy($im);
}

function write_ico($path, array $pngBySize) {
	$count = count($pngBySize);
	$header = pack('vvv', 0, 1, $count);
	$offset = 6 + (16 * $count);
	$entries = '';
	$data = '';
	foreach ($pngBySize as $size => $blob) {
		$dim = ($size >= 256) ? 0 : $size;
		$entries .= pack('CCCCvvVV', $dim, $dim, 0, 0, 1, 32, strlen($blob), $offset);
		$offset += strlen($blob);
		$data .= $blob;
	}
	if (file_put_contents($path, $header . $entries . $data) === false) {
		fwrite(STDERR, "could not write $path\n");
		exit(1);
	}
}
