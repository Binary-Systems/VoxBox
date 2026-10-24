<?php
/**
 * VoxBox menu — stock FreePBX navbar in a fixed order.
 * Admin, Applications, Connectivity, Reports, Settings, UCP.
 * The cube mark opens the Dashboard. Dashboard is not a menu item.
 * freepbx_settings: VIEW_MENU = views/voxbox_menu.php
 * Copyright (C) 2007-2026 Binary Systems, Inc.
 */

global $amp_conf;
global $_item_sort;

if (!function_exists('voxbox_reorder_nav')) {
	/**
	 * Top-level bar only. Dropdown entries stay inside their category.
	 * Stock FreePBX leaves dropdown <li class="nav-item"> tags unclosed,
	 * so categories are split on the next nav-item, not on </li>.
	 * When every expected label is present, that order is the whole bar.
	 * Dashboard is never a top-level item; the cube opens it.
	 * Otherwise leave FreePBX's order and only drop Dashboard and Webmin.
	 */
	function voxbox_nav_is_dashboard($label, $chunk) {
		if ($label === 'Dashboard') {
			return true;
		}
		if (strpos($chunk, '<ul') !== false) {
			return false;
		}
		return (bool) preg_match('/href=(["\'])config\\.php\\?display=index\\1/', $chunk);
	}
	function voxbox_reorder_nav($html) {
		$order = array(
			'Admin' => 0,
			'Applications' => 1,
			'Connectivity' => 2,
			'Reports' => 3,
			'Settings' => 4,
			'UCP' => 5,
		);
		$parts = preg_split('/(?=<li\s+class=["\']nav-item\b)/', $html);
		if ($parts === false) {
			return $html;
		}
		$items = array();
		foreach ($parts as $part) {
			if (!preg_match('/^<li\s+class=["\']nav-item\b/', $part)) {
				continue;
			}
			$label = '';
			if (preg_match('/<a\b[^>]*>(.*?)<\/a>/s', $part, $am)) {
				$label = trim(preg_replace('/\s+/', ' ', strip_tags($am[1])));
			}
			$items[] = array($label, $part);
		}
		if (!$items) {
			return $html;
		}
		$kept = array();
		foreach ($items as $part) {
			if (voxbox_nav_is_dashboard($part[0], $part[1]) || $part[0] === 'Webmin') {
				continue;
			}
			$kept[] = $part;
		}
		$found = array();
		foreach ($kept as $part) {
			$found[$part[0]] = true;
		}
		$complete = true;
		foreach ($order as $name => $unused) {
			if (empty($found[$name])) {
				$complete = false;
				break;
			}
		}
		$out = array();
		if ($complete) {
			$ranked = array();
			foreach ($kept as $part) {
				if (isset($order[$part[0]])) {
					$ranked[] = array($order[$part[0]], $part[1]);
				}
			}
			usort($ranked, function ($a, $b) {
				return $a[0] <=> $b[0];
			});
			foreach ($ranked as $row) {
				$out[] = $row[1];
			}
		} else {
			foreach ($kept as $part) {
				$out[] = $part[1];
			}
		}
		return implode('', $out);
	}
}
?>
<div class="freepbx-navbar">
	<nav class="navbar navbar-expand-lg fixed-top" role="navigation">
		<button type="button" class="navbar-toggler" data-toggle="collapse" data-target="#fpbx-menu-collapse">
			<span class="sr-only">Toggle navigation</span>
			<span class="icon-bar"></span>
			<span class="icon-bar"></span>
			<span class="icon-bar"></span>
		</button>
		<a class="navbar-brand" href="config.php?display=index" title="<?php echo _('Dashboard'); ?>">
			<img src="<?php echo $amp_conf['BRAND_IMAGE_TANGO_LEFT']; ?>" alt="<?php echo $amp_conf['BRAND_FREEPBX_ALT_LEFT']; ?>" title="<?php echo _('Dashboard'); ?>" id="MENU_BRAND_IMAGE_TANGO_LEFT" />
		</a>
		<div class="collapse navbar-collapse" id="fpbx-menu-collapse">
			<ul class="navbar-nav mr-auto">
				<?php
				ob_start();
				include_once(__DIR__ . '/menu_items.php');
				echo voxbox_reorder_nav(ob_get_clean());
				?>
			</ul>
		</div>
		<ul class="stuck-right">
			<?php if(FreePBX::create()->astman->connected()) {?>
				<li><a id="button_reload" class="btn btn-danger nav-button reload-btn"><?php echo _('Apply Config'); ?></a></li>
			<?php } else { ?>
				<li><a class="btn btn-danger nav-button reload-btn"><?php echo _('Cannot Connect to Asterisk'); ?></a></li>
			<?php } ?>
			<?php if ( isset($_SESSION['AMP_user']) ) { ?>
				<?php if($amp_conf['SHOWLANGUAGE']) { ?>
					<li class="dropdown admin-btn">
						<button class="btn dropdown-toggle nav-button" data-toggle="dropdown"><i class="fa fa-language"></i></button>
						<ul id="fpbx_lang" class="dropdown-menu" role="menu">
							<?php foreach ($language as $langKey => $lang) {
									$class = $pointer='';
									if ($langKey === $_COOKIE['lang']) {
										$class = 'class="dropdown-item disabled text-muted"';
										$pointer='style="cursor: not-allowed"';
									} ?>
								<li <?php echo $pointer; ?> data-lang="<?php echo $langKey; ?>"><a href="#" <?php echo $class; ?>><?php echo $lang; ?></a></li>
							<?php } ?>
						</ul>
					</li>
				<?php } ?>
				<button id="search-btn" class="btn nav-button"><i class="fa fa-search"></i></button>
				<?php if($authtype != 'none') {?>
					<li class="dropdown admin-btn">
						<button class="btn dropdown-toggle nav-button" data-toggle="dropdown"><i id="settings-cog" class="fa fa-cog"></i></button>
						<ul class="dropdown-menu" role="menu">
							<li role="presentation" ><a><?php echo _('Hello, ') . (isset($_SESSION['AMP_user']->username) ? $_SESSION['AMP_user']->username : 'ERROR'); ?></a></li>
							<li role="presentation" class="divider"></li>
							<li role="presentation" class="nav-bar-show"><a title="<?php echo _("Nav. Bar is always shown by default or not.") ?>"><?php echo _("Keep Nav Bar Expanded") ?></a></li>
							<li><a id="user_logout" href="#"><?php echo _('Logout'); ?></a></li>
						</ul>
					</li>
				<?php } ?>
			<?php } ?>
		</ul>
	</nav>
</div>
<?php if (isset($display) && $display != "noauth") { ?>
	<div class="<?php echo empty($_COOKIE['searchHide']) ? 'in' : ''?>" id='fpbxsearch'>
		<i class="fa fa-search"></i>
		<input type="text" class="form-control typeahead" placeholder="<?php echo _('Search')?>" title="<?php echo _("Quick Search '/'")?>">
	</div>
<?php } ?>
<script>
(function () {
	var dash = "config.php?display=index";
	document.addEventListener("click", function (e) {
		var node = e.target;
		if (!node || !node.closest) {
			return;
		}
		var link = node.closest("a.navbar-brand");
		if (!link) {
			return;
		}
		e.stopPropagation();
		if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
			return;
		}
		e.preventDefault();
		window.location.assign(link.getAttribute("href") || dash);
	}, true);

	var fiberHref = "https://www.binary-systems.com/VoxBox/";
	function placeFiber() {
		var heads = document.querySelectorAll("#page_Main_Overview_overview .h5.pt-2");
		for (var i = 0; i < heads.length; i++) {
			var head = heads[i];
			if (head.querySelector("a.voxbox-fiber-link")) {
				continue;
			}
			var a = document.createElement("a");
			a.className = "voxbox-fiber-link";
			a.href = fiberHref;
			a.target = "_blank";
			a.rel = "noopener noreferrer";
			var img = document.createElement("img");
			img.src = "/admin/images/VoxBox-fiber.gif";
			img.alt = "VoxBox";
			a.appendChild(img);
			head.insertBefore(a, head.firstChild);
		}
	}
	function watch() {
		placeFiber();
		var root = document.getElementById("page_body") || document.body;
		if (!root || !window.MutationObserver) {
			return;
		}
		var pending = false;
		var obs = new MutationObserver(function () {
			if (pending) {
				return;
			}
			pending = true;
			window.requestAnimationFrame(function () {
				pending = false;
				placeFiber();
			});
		});
		obs.observe(root, {childList: true, subtree: true});
	}
	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", watch);
	} else {
		watch();
	}
})();
</script>
<script>
(function () {
	/* VoxBox night mode for the dashboard charts (CanvasJS draws on a canvas,
	   so CSS cannot reach the plot, axis text, legend or gridlines). While the
	   browser reports prefers-color-scheme: dark, options are filled in for
	   every new CanvasJS.Chart. Values a chart sets itself are kept. Light mode
	   never changes. Owned file only; FreePBX modules are not edited. */
	if (!window.matchMedia) {
		return;
	}
	var mq = window.matchMedia("(prefers-color-scheme: dark)");
	var FONT = '"Lucida Grande","Lucida Sans Unicode",Arial,Verdana,sans-serif';
	var TEXT = "#e6e6e8", LABEL = "#c8c8cc", GRID = "#3a3a3e", AXIS = "#6b6b72";
	var SERIES = ["#4fc3d9", "#ff6b66", "#b48ad0", "#a5d63f", "#a2d1cf", "#f0b04a", "#6aa9ee", "#e58bb8", "#d9d9de", "#ff9d5c"];
	function put(o, k, v) {
		if (o[k] === undefined || o[k] === null) {
			o[k] = v;
		}
	}
	function night(o) {
		var axes = ["axisX", "axisY"], i, a;
		put(o, "backgroundColor", "#1c1c1e");
		put(o, "colorSet", "voxboxNight");
		if (o.title && typeof o.title === "object") {
			put(o.title, "fontColor", TEXT);
			put(o.title, "fontFamily", FONT);
		}
		for (i = 0; i < axes.length; i++) {
			if (!o[axes[i]] || typeof o[axes[i]] !== "object") {
				o[axes[i]] = {};
			}
			a = o[axes[i]];
			put(a, "labelFontColor", LABEL);
			put(a, "titleFontColor", LABEL);
			put(a, "labelFontFamily", FONT);
			put(a, "titleFontFamily", FONT);
			put(a, "lineColor", AXIS);
			put(a, "tickColor", AXIS);
			put(a, "gridColor", GRID);
		}
		if (o.legend && typeof o.legend === "object") {
			put(o.legend, "fontColor", TEXT);
			put(o.legend, "fontFamily", FONT);
		}
		if (!o.toolTip || typeof o.toolTip !== "object") {
			o.toolTip = {};
		}
		put(o.toolTip, "backgroundColor", "#2a2a2c");
		put(o.toolTip, "fontColor", TEXT);
		put(o.toolTip, "fontFamily", FONT);
		put(o.toolTip, "borderColor", "#3d8ad4");
		return o;
	}
	function install() {
		var C = window.CanvasJS, Orig, W, k;
		if (!C || typeof C.Chart !== "function") {
			return false;
		}
		if (C.Chart.voxNight) {
			return true;
		}
		Orig = C.Chart;
		W = function (id, opts) {
			opts = opts || {};
			if (mq.matches) {
				night(opts);
			}
			return new Orig(id, opts);
		};
		W.prototype = Orig.prototype;
		for (k in Orig) {
			if (Object.prototype.hasOwnProperty.call(Orig, k)) {
				W[k] = Orig[k];
			}
		}
		W.voxNight = true;
		if (typeof C.addColorSet === "function") {
			C.addColorSet("voxboxNight", SERIES);
		}
		C.Chart = W;
		/* Charts built before this ran: restyle and redraw once. */
		try {
			var live = [window.currentchart, window.Netchart && window.Netchart.chart], j;
			for (j = 0; j < live.length; j++) {
				if (mq.matches && live[j] && live[j].options && typeof live[j].render === "function") {
					night(live[j].options);
					live[j].render();
				}
			}
		} catch (e) { /* leave the chart as drawn */ }
		return true;
	}
	if (!install()) {
		var tries = 0, t = window.setInterval(function () {
			if (install() || ++tries > 600) {
				window.clearInterval(t);
			}
		}, 100);
	}
})();
</script>

<div id="page_body">
