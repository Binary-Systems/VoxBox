<?php
/**
 * VoxBox footer — same layout as stock FreePBX footer_content.php:
 * left brand logo (Binary Systems animated GIF → www.binary-systems.com),
 * centered copyright text, empty right sponsor slot.
 * freepbx_settings: VIEW_FOOTER_CONTENT = modules/voxbox/views/footer_content.php
 * Copyright (C) 2007- Binary Systems, Inc. The displayed end year is filled
 * in by the browser, the same way as www.binary-systems.com.
 */
global $amp_conf;
$html = '';
$version = get_framework_version();
$version = $version ? $version : getversion();
$version_tag = '?load_version=' . urlencode($version);
if (!empty($amp_conf['FORCE_JS_CSS_IMG_DOWNLOAD'])) {
	$version_tag .= '.' . time();
}
$baseUrl = isset($baseUrl) ? $baseUrl : '';

// The head tag always requests voxbox.css?load_version=<framework>, so a
// browser can keep an older copy after the file changes. This second link
// uses the file's mtime and is printed in the page body, which is not cached.
$voxCssFile = '/var/www/html/admin/modules/voxbox/assets/css/voxbox.css';
if (!empty($amp_conf['AMPWEBROOT'])) {
	$voxCssFile = rtrim($amp_conf['AMPWEBROOT'], '/') . '/admin/modules/voxbox/assets/css/voxbox.css';
}
$voxCssVer = @filemtime($voxCssFile);
/* Admin and UCP both load this sheet. Logged-in UCP gets it from the
   header inject (VOXBOX_UCP_CSS). This link covers the signed-out footer
   and replaces a copy cached under ?load_version=<framework>. UCP's own
   stylesheet centers the footer and sizes the logo at 70px, so the layout
   rules below stay. */
$scriptName = isset($_SERVER['SCRIPT_NAME']) ? $_SERVER['SCRIPT_NAME'] : '';
if (strpos($scriptName, '/ucp') !== false) {
	$html .= '<script>document.documentElement.classList.add("voxbox-ucp");</script>';
}
$html .= '<link rel="stylesheet" href="/admin/modules/voxbox/assets/css/voxbox.css?v=' . ($voxCssVer ? $voxCssVer : time()) . '">';
$html .= '<style>'
	. 'footer[data-footer-content="1"] #footer-content{display:flex !important;flex-wrap:nowrap !important;align-items:center !important;justify-content:flex-start !important;width:100% !important;max-width:none !important;margin:0 !important;font-family:"Lucida Grande","Lucida Sans Unicode",Arial,Verdana,sans-serif !important;color:#333 !important;}'
	. 'footer[data-footer-content="1"] #footer__left__logo__wrapper{display:flex !important;flex:0 0 auto !important;justify-content:flex-start !important;align-items:center !important;width:auto !important;max-width:240px !important;text-align:left !important;padding:6px 12px !important;}'
	. 'footer[data-footer-content="1"] #footer-content #footer_logo1{display:inline-block !important;height:auto !important;max-height:42px !important;width:auto !important;max-width:220px !important;margin:0 !important;background-color:#ffffff !important;}'
	. 'footer[data-footer-content="1"] #footer_text{flex:1 1 auto !important;width:auto !important;max-width:none !important;text-align:center !important;color:#333 !important;}'
	. 'footer[data-footer-content="1"] #footer_text .voxbox-copyright{display:block !important;margin:0 !important;padding:0 !important;line-height:1.25 !important;text-align:center !important;white-space:nowrap;color:#333;}'
	. 'footer[data-footer-content="1"] #footer_text a{display:inline !important;color:#005fa5 !important;}'
	. 'footer[data-footer-content="1"] #footer__right__logo__wrapper{display:none !important;}'
	. '@media (prefers-color-scheme: dark){'
	. 'footer[data-footer-content="1"] #footer-content,footer[data-footer-content="1"] #footer_text,footer[data-footer-content="1"] #footer_text .voxbox-copyright{color:#d0d0d0 !important;}'
	. 'footer[data-footer-content="1"] #footer_text a{color:#7eb6ef !important;}'
	. '}'
	. '</style>';

$foot_img = !empty($amp_conf['BRAND_IMAGE_FREEPBX_FOOT'])
	? $amp_conf['BRAND_IMAGE_FREEPBX_FOOT']
	: 'modules/voxbox/assets/images/binary_systems_si_animated.gif';
$foot_link = !empty($amp_conf['BRAND_IMAGE_FREEPBX_LINK_FOOT'])
	? $amp_conf['BRAND_IMAGE_FREEPBX_LINK_FOOT']
	: 'http://www.binary-systems.com/';
$foot_alt = !empty($amp_conf['BRAND_FREEPBX_ALT_FOOT'])
	? $amp_conf['BRAND_FREEPBX_ALT_FOOT']
	: 'Binary Systems, Inc.';

// Left — brand logo (FreePBX logo slot)
$html .= '<div class="col-md-4" id="footer__left__logo__wrapper">';
$html .= '<a target="_blank" rel="noopener" href="' . htmlspecialchars($foot_link, ENT_QUOTES) . '">';
// The 2x file sits beside the 1x file (binary_systems_si_animated@2x.gif).
$foot_img_2x = preg_replace('/\.gif$/i', '@2x.gif', $foot_img);
$foot_srcset = ($foot_img_2x !== $foot_img)
	? ' srcset="' . htmlspecialchars($baseUrl . '/admin/' . $foot_img_2x . $version_tag, ENT_QUOTES) . ' 2x"'
	: '';
// Night mode (prefers-color-scheme: dark, the same switch voxbox.css uses): the reverse-clear logo,
// white artwork on transparent with a black matte, shown straight on the dark footer bar with no white
// box behind it. prefers-reduced-motion: frame-0 stills. Light mode keeps the original GIF unchanged.
// The variants sit beside $foot_img: <name>_reverse-clear.gif, <name>@2x ..., and
// binary_systems_si_still[_reverse-clear][@2x].png. Only used for the stock .gif logo name.
$foot_pic = '';
if (preg_match('/binary_systems_si_animated\.gif$/i', $foot_img)) {
	// Stock logo only: drop the white box in night mode. Custom logos keep it.
	$html .= '<style>@media (prefers-color-scheme: dark){footer[data-footer-content="1"] #footer-content #footer_logo1{background-color:transparent !important;}}</style>';
	$u = function ($p) use ($baseUrl, $version_tag) { return htmlspecialchars($baseUrl . '/admin/' . $p . $version_tag, ENT_QUOTES); };
	$rc  = preg_replace('/\.gif$/i', '_reverse-clear.gif', $foot_img);
	$rc2 = preg_replace('/\.gif$/i', '_reverse-clear@2x.gif', $foot_img);
	$st  = preg_replace('/_animated\.gif$/i', '_still.png', $foot_img);
	$st2 = preg_replace('/_animated\.gif$/i', '_still@2x.png', $foot_img);
	$rs  = preg_replace('/_animated\.gif$/i', '_still_reverse-clear.png', $foot_img);
	$rs2 = preg_replace('/_animated\.gif$/i', '_still_reverse-clear@2x.png', $foot_img);
	$foot_pic .= '<source media="(prefers-color-scheme: dark) and (prefers-reduced-motion: reduce)" srcset="' . $u($rs) . ' 1x, ' . $u($rs2) . ' 2x">';
	$foot_pic .= '<source media="(prefers-color-scheme: dark)" srcset="' . $u($rc) . ' 1x, ' . $u($rc2) . ' 2x">';
	$foot_pic .= '<source media="(prefers-reduced-motion: reduce)" srcset="' . $u($st) . ' 1x, ' . $u($st2) . ' 2x">';
}
$html .= '<picture>' . $foot_pic;
$html .= '<img id="footer_logo1" src="' . htmlspecialchars($baseUrl . '/admin/' . $foot_img . $version_tag, ENT_QUOTES) . '"' . $foot_srcset . ' alt="' . htmlspecialchars($foot_alt, ENT_QUOTES) . '"/>';
$html .= '</picture>';
$html .= '</a></div>';

// Three centered lines. copyright.js replaces .bsi-year with the browser's
// current year. date('Y') is the text shown if that script has not run.
$html .= '<div class="col-md-4" id="footer_text" style="text-align:center;">';
$html .= '<div class="voxbox-copyright">';
$html .= '<a href="http://www.binary-systems.com/VoxBox/">VoxBox</a>';
$html .= ' - Copyright &copy; 2007-<span class="bsi-year">' . date('Y') . '</span> ';
$html .= '<a id="BSI" href="http://www.binary-systems.com">Binary Systems, Inc.</a>.';
$html .= '</div>';
$html .= 'FreePBX is a registered trademark of Sangoma Technologies Inc.' . br();
$html .= sprintf('FreePBX %s is licensed under the GPL', $version);
$html .= '<script src="/admin/modules/voxbox/assets/js/copyright.js"></script>';
$html .= '</div>';

// Right — keep empty (no Sangoma sponsor)
$html .= '<div class="col-md-4" id="footer__right__logo__wrapper"></div>';
echo $html;
