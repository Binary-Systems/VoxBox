<?php
// VOXBOX_OVERVIEW_OVERLAY
// VoxBox Overview for VoxBox System Dashboard.
// Copyright (C) 2007-2026 Binary Systems, Inc.
//
// This file ships as modules/dashboard/sections/Overview.class.php and loads
// with the dashboard. The class name, rawname, and section id stay
// Overview / overview, so layout, AJAX reload, and
// #page_Main_Overview_overview stay valid. Alerts, notifications, and the
// service summary still come from the FreePBX parent. System Vitals rows
// are inserted in that same card, below the system-name line and above
// Summary. Do not edit views/sections/overview.php.
//
// The parent is classes/VoxBoxOverviewStock.class.php: the FreePBX Overview
// class, renamed OverviewStock and stored outside sections/ so the dashboard
// glob does not load it a second time. A stock dashboard package restores
// sections/Overview.class.php; apply-voxbox-branding.sh saves that new
// parent and copies this file back.

namespace FreePBX\modules\Dashboard\Sections;

$voxboxOverviewStock = dirname(__DIR__) . '/classes/VoxBoxOverviewStock.class.php';
if (is_file($voxboxOverviewStock)) {
	require_once $voxboxOverviewStock;
}
$voxboxDashboardClass = __DIR__ . '/VoxBox.class.php';
if (is_file($voxboxDashboardClass)) {
	require_once $voxboxDashboardClass;
}

#[\AllowDynamicProperties]
class Overview extends OverviewStock {
	public $rawname = 'Overview';

	public function getSections($order) {
		$sections = parent::getSections($order);
		foreach ($sections as $i => $section) {
			if (($section['section'] ?? '') === 'overview') {
				$sections[$i]['title'] = _('VoxBox Overview');
			}
		}
		return $sections;
	}

	public function getContent($section) {
		$html = parent::getContent($section);
		if ((string) $section !== 'overview' || !class_exists(VoxBox::class, false)) {
			return $html;
		}
		return self::insertVitals($html, VoxBox::vitalsBlock());
	}

	private static function insertVitals(string $html, string $vitals): string {
		// Drop the extra container so the table lines up with the stock rows.
		$vitals = preg_replace(
			'/^<div class="container-fluid voxbox-dash">/',
			'<div class="voxbox-dash">',
			$vitals,
			1
		);
		$block = "<div class='row'><div class='col-sm-12'>" . $vitals . '</div></div>';
		$summaryAt = self::markerPos($html, ['class="summary"', "class='summary'"]);
		if ($summaryAt === null) {
			return $html . $block;
		}
		// Stock overview.php nests Summary in a row inside the row that also
		// holds SysInfo. Insert before that outer row.
		$innerRow = self::lastRowOpen($html, $summaryAt);
		$outerRow = $innerRow === null ? null : self::lastRowOpen($html, $innerRow);
		$at = $outerRow ?? $innerRow;
		if ($at === null) {
			return $html . $block;
		}
		return substr($html, 0, $at) . $block . substr($html, $at);
	}

	private static function markerPos(string $html, array $needles): ?int {
		foreach ($needles as $needle) {
			$pos = strpos($html, $needle);
			if ($pos !== false) {
				return $pos;
			}
		}
		return null;
	}

	private static function lastRowOpen(string $html, int $before): ?int {
		$slice = substr($html, 0, $before);
		$at = null;
		foreach (["<div class='row'>", '<div class="row">'] as $needle) {
			$pos = strrpos($slice, $needle);
			if ($pos !== false && ($at === null || $pos > $at)) {
				$at = $pos;
			}
		}
		return $at;
	}
}
