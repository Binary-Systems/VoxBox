<?php
// VoxBox panels for VoxBox System Dashboard.
// Copyright (C) 2007-2026 Binary Systems, Inc.
//
// This file ships in modules/dashboard/sections/VoxBox.class.php.
// FreePBX loads every *.class.php in that directory when the dashboard
// opens, so these panels load with the module.
//
// System Vitals is not one of those widgets. vitalsBlock() is the HTML
// the VoxBox Overview overlay places below the system-name line. That
// block includes one CPU line: model, speed, and core count.
//
// The field lists follow the VoxBox 1.4 system and Asterisk pages.
// SIP Peers are endpoints. SIP Registry is outbound registration.
// IAX2 Peers is the same `iax2 show peers` table Asterisk Info shows.

namespace FreePBX\modules\Dashboard\Sections;

class VoxBox {
	public $rawname = 'VoxBox';

	public function getSections($order) {
		$saved = is_array($order) ? $order : [];
		// Stock FreePBX cards are 550px. The dashboard gutter is 5px, so a
		// card that fills two columns is 1105px. 1000px stops short of that pair.
		$defs = [
			['active_channels', _('Active Channels'), 4, '1105px'],
			['active_sip_channels', _('Active SIP Channels'), 5, '1105px'],
			['sip_peers', _('SIP Peers'), 6, '1105px'],
			['sip_registry', _('SIP Registry'), 7, '1105px'],
			['iax2_peers', _('IAX2 Peers'), 8, '1105px'],
			['iax2_registry', _('IAX2 Registry'), 9, '1105px'],
		];
		$out = [];
		foreach ($defs as $d) {
			$out[] = [
				'title' => $d[1],
				'group' => _('VoxBox'),
				'width' => $d[3],
				'order' => $saved[$d[0]] ?? $d[2],
				'section' => $d[0],
			];
		}
		return $out;
	}

	public function getContent($section) {
		try {
			$snap = self::snapshot();
		} catch (\Throwable $e) {
			return self::wrap('<p class="text-center">' . self::e(_('Status is unavailable.')) . '</p>');
		}
		switch ((string) $section) {
			case 'system_vitals':
				// No longer registered. A reload of a card opened before the
				// merge still receives the same rows.
				return self::renderVitals($snap['vitals'], $snap['hardware'] ?? []);
			case 'hardware':
				// No longer registered. A reload of a card opened before it
				// was removed still receives the old hardware page.
				return self::renderHardware($snap['hardware']);
			case 'active_channels':
				return self::renderChannels($snap['asterisk']);
			case 'active_sip_channels':
				return self::renderSipChannels($snap['asterisk']);
			case 'sip_peers':
				return self::renderPeers($snap['asterisk']);
			case 'sip_registry':
				return self::renderRegistry($snap['asterisk']);
			case 'iax2_peers':
				return self::renderIaxPeers($snap['asterisk']);
			case 'iax2_registry':
				return self::renderIax($snap['asterisk']);
			default:
				return '';
		}
	}

	public static function vitalsBlock(): string {
		try {
			$snap = self::snapshot();
		} catch (\Throwable $e) {
			return self::wrap('<p class="text-center">' . self::e(_('Status is unavailable.')) . '</p>');
		}
		if (!isset($snap['vitals']) || !is_array($snap['vitals'])) {
			return self::wrap('<p class="text-center">' . self::e(_('Status is unavailable.')) . '</p>');
		}
		$hardware = (isset($snap['hardware']) && is_array($snap['hardware'])) ? $snap['hardware'] : [];
		return self::renderVitals($snap['vitals'], $hardware);
	}

	private static function snapshot(): array {
		$lockPath = sys_get_temp_dir() . '/voxbox-dash-snap.lock';
		$lock = @fopen($lockPath, 'c');
		if ($lock) {
			@flock($lock, LOCK_EX);
		}
		try {
			$cache = null;
			try {
				$cache = \FreePBX::Cache()->cloneByNamespace('voxboxdash');
				$cached = $cache->fetch('snap');
				if (is_array($cached) && isset($cached['ts']) && (time() - (int) $cached['ts']) < 4) {
					return $cached;
				}
			} catch (\Throwable $e) {
				$cache = null;
			}
			$snap = self::collect();
			$snap['ts'] = time();
			if ($cache) {
				try {
					$cache->save('snap', $snap, 4);
				} catch (\Throwable $e) {
				}
			}
			return $snap;
		} finally {
			if ($lock) {
				@flock($lock, LOCK_UN);
				@fclose($lock);
			}
		}
	}

	private static function collect(): array {
		$snap = [
			'vitals' => self::collectVitals(),
			'hardware' => self::collectHardware(),
			'asterisk' => ['up' => false],
		];
		try {
			$snap['asterisk'] = self::collectAsterisk();
		} catch (\Throwable $e) {
			$snap['asterisk'] = ['up' => false];
		}
		return $snap;
	}

	private static function collectVitals(): array {
		$hostname = function_exists('gethostname') ? (string) gethostname() : '';
		if ($hostname === '') {
			$hostname = trim((string) @file_get_contents('/proc/sys/kernel/hostname'));
		}
		$kernel = php_uname('r');
		if (stripos(php_uname('v'), 'SMP') !== false) {
			$kernel .= ' (SMP)';
		}
		$distro = 'Linux';
		$os = @file('/etc/os-release', FILE_IGNORE_NEW_LINES);
		if (is_array($os)) {
			foreach ($os as $line) {
				if (str_starts_with($line, 'PRETTY_NAME=')) {
					$distro = trim(substr($line, 12), "\"' \t\r\n");
					break;
				}
			}
		}
		$uptime = 'unknown';
		$rawUp = @file_get_contents('/proc/uptime');
		if (is_string($rawUp) && preg_match('/^([\d.]+)/', $rawUp, $m)) {
			$uptime = self::formatUptime((int) $m[1]);
		}
		$users = 0;
		$who = shell_exec('who 2>/dev/null');
		if (is_string($who) && trim($who) !== '') {
			$users = substr_count(trim($who), "\n") + 1;
		}
		$load = 'unknown';
		$rawLoad = @file_get_contents('/proc/loadavg');
		if (is_string($rawLoad)) {
			$p = explode(' ', trim($rawLoad));
			if (count($p) >= 3) {
				$load = number_format((float) $p[0], 2) . ' ' . number_format((float) $p[1], 2) . ' ' . number_format((float) $p[2], 2);
			}
		}
		return [
			'hostname' => $hostname !== '' ? $hostname : 'unknown',
			'ip' => self::listeningIp(),
			'wan' => self::wanIp(),
			'kernel' => $kernel,
			'distro' => $distro,
			'uptime' => $uptime,
			'users' => (string) $users,
			'load' => $load,
		];
	}

	private static function wanIp(): string {
		$local = self::localPublicIp();
		if ($local !== null) {
			return $local;
		}
		$path = sys_get_temp_dir() . '/voxbox-wan-ip';
		$cachedIp = '';
		$checked = 0;
		$raw = @file_get_contents($path);
		if (is_string($raw) && preg_match('/^(\d+)(?:\s+(\S+))?/', trim($raw), $m)) {
			$checked = (int) $m[1];
			if (isset($m[2]) && self::publicIpv4($m[2])) {
				$cachedIp = $m[2];
			}
		}
		$age = time() - $checked;
		if ($cachedIp !== '' && $age >= 0 && $age < 900) {
			return $cachedIp;
		}
		if ($cachedIp === '' && $checked > 0 && $age >= 0 && $age < 60) {
			return 'unknown';
		}
		$found = self::discoverWanIp();
		$store = $found ?? $cachedIp;
		@file_put_contents($path, time() . ($store !== '' ? ' ' . $store : '') . "\n", LOCK_EX);
		return $store !== '' ? $store : 'unknown';
	}

	private static function localPublicIp(): ?string {
		$want = null;
		$route = @file('/proc/net/route', FILE_IGNORE_NEW_LINES);
		if (is_array($route)) {
			foreach (array_slice($route, 1) as $line) {
				$f = preg_split('/\s+/', trim($line));
				if (isset($f[1]) && $f[1] === '00000000' && ($f[0] ?? '') !== '') {
					$want = $f[0];
					break;
				}
			}
		}
		if (!function_exists('net_get_interfaces')) {
			return null;
		}
		$ifs = @net_get_interfaces();
		if (!is_array($ifs)) {
			return null;
		}
		$fallback = null;
		foreach ($ifs as $name => $d) {
			if ($name === 'lo' || empty($d['unicast']) || !is_array($d['unicast'])) {
				continue;
			}
			foreach ($d['unicast'] as $u) {
				$addr = $u['address'] ?? '';
				if (!is_string($addr) || !self::publicIpv4($addr)) {
					continue;
				}
				if ($want !== null && $name === $want) {
					return $addr;
				}
				$fallback ??= $addr;
			}
		}
		return $fallback;
	}

	private static function discoverWanIp(): ?string {
		$urls = [
			'https://api.ipify.org',
			'https://ipv4.icanhazip.com',
		];
		foreach ($urls as $url) {
			$out = shell_exec('curl -4 -fsS --max-time 2 ' . escapeshellarg($url) . ' 2>/dev/null');
			$ip = is_string($out) ? trim($out) : '';
			if (self::publicIpv4($ip)) {
				return $ip;
			}
		}
		return null;
	}

	private static function publicIpv4(string $ip): bool {
		if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4 | FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
			return false;
		}
		$packed = @inet_pton($ip);
		if ($packed === false) {
			return false;
		}
		$n = unpack('N', $packed)[1];
		// 100.64.0.0/10 is carrier NAT, not the internet-facing address.
		return ($n & 0xFFC00000) !== 0x64400000;
	}

	private static function listeningIp(): string {
		$want = null;
		$route = @file('/proc/net/route', FILE_IGNORE_NEW_LINES);
		if (is_array($route)) {
			foreach (array_slice($route, 1) as $line) {
				$f = preg_split('/\s+/', trim($line));
				if (isset($f[1]) && $f[1] === '00000000' && ($f[0] ?? '') !== '') {
					$want = $f[0];
					break;
				}
			}
		}
		if (!function_exists('net_get_interfaces')) {
			return 'unknown';
		}
		$ifs = @net_get_interfaces();
		if (!is_array($ifs)) {
			return 'unknown';
		}
		$pick = [];
		$fallback = [];
		foreach ($ifs as $name => $d) {
			if ($name === 'lo' || empty($d['unicast']) || !is_array($d['unicast'])) {
				continue;
			}
			foreach ($d['unicast'] as $u) {
				$addr = $u['address'] ?? '';
				if (!is_string($addr) || !filter_var($addr, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
					continue;
				}
				if ($addr === '127.0.0.1' || str_starts_with($addr, '169.254.')) {
					continue;
				}
				$fallback[] = $addr;
				if ($want !== null && $name === $want) {
					$pick[] = $addr;
				}
			}
		}
		$list = $pick ?: $fallback;
		return $list ? implode(', ', array_unique($list)) : 'unknown';
	}

	private static function collectHardware(): array {
		$cpus = 0;
		$model = '';
		$mhz = '';
		$cache = '';
		$bogo = 0.0;
		$cpuinfo = @file('/proc/cpuinfo', FILE_IGNORE_NEW_LINES);
		if (is_array($cpuinfo)) {
			foreach ($cpuinfo as $line) {
				if (!str_contains($line, ':')) {
					continue;
				}
				[$k, $v] = explode(':', $line, 2);
				$k = strtolower(trim($k));
				$v = trim($v);
				if ($k === 'processor' && is_numeric($v)) {
					$cpus++;
				} elseif ($k === 'model name' && $model === '') {
					$model = $v;
				} elseif ($k === 'hardware' && $model === '') {
					$model = $v;
				} elseif ($k === 'cpu mhz' && $mhz === '') {
					$mhz = $v;
				} elseif ($k === 'cache size' && $cache === '') {
					$cache = $v;
				} elseif ($k === 'bogomips') {
					$bogo += (float) $v;
				}
			}
		}
		$speed = 'unknown';
		if ($mhz !== '' && is_numeric($mhz)) {
			$mhzF = (float) $mhz;
			if ($mhzF >= 1000) {
				$ghz = rtrim(rtrim(number_format($mhzF / 1000, 2), '0'), '.');
				$speed = $ghz . ' GHz';
			} else {
				$speed = rtrim(rtrim(number_format($mhzF, 2), '0'), '.') . ' MHz';
			}
		}
		$pci = [];
		$lspci = shell_exec('lspci 2>/dev/null');
		if (is_string($lspci)) {
			foreach (preg_split('/\n/', trim($lspci)) as $line) {
				$line = trim($line);
				if ($line === '') {
					continue;
				}
				$pci[] = preg_replace('/^[0-9a-fA-F:.]+ /', '', $line);
			}
		}
		$ide = [];
		$scsi = [];
		$disks = [];
		foreach (glob('/sys/block/*') ?: [] as $path) {
			$name = basename($path);
			if (preg_match('/^(loop|ram|fd)/', $name)) {
				continue;
			}
			$sectors = (int) trim((string) @file_get_contents($path . '/size'));
			// Skip empty nodes and the tiny cloud-init seed disk.
			if ($sectors < 65536) {
				continue;
			}
			$modelDisk = trim((string) @file_get_contents($path . '/device/model'));
			$vendor = strtolower(trim((string) @file_get_contents($path . '/device/vendor')));
			if ($modelDisk === '' && $vendor === '0x1af4') {
				$modelDisk = 'VirtIO';
			} elseif ($modelDisk === '' && $vendor !== '') {
				$modelDisk = $vendor;
			} elseif ($modelDisk === '') {
				$modelDisk = 'disk';
			}
			$label = $name . ': ' . $modelDisk . ' (' . self::humanSectors($sectors) . ')';
			if (str_starts_with($name, 'hd') || str_starts_with($name, 'sr')) {
				$ide[] = $label;
			} elseif (str_starts_with($name, 'sd')) {
				$scsi[] = $label;
			} else {
				$disks[] = $label;
			}
		}
		$usb = [];
		foreach (glob('/sys/bus/usb/devices/[0-9]*') ?: [] as $path) {
			$prod = trim((string) @file_get_contents($path . '/product'));
			if ($prod === '') {
				continue;
			}
			$class = trim((string) @file_get_contents($path . '/bDeviceClass'));
			if ($class === '09') {
				continue;
			}
			$man = trim((string) @file_get_contents($path . '/manufacturer'));
			if ($man !== '' && stripos($prod, $man) !== 0) {
				$prod = $man . ' ' . $prod;
			}
			$usb[] = $prod;
		}
		return [
			'processors' => (string) ($cpus > 0 ? $cpus : 1),
			'model' => $model !== '' ? $model : 'unknown',
			'speed' => $speed,
			'cache' => $cache !== '' ? $cache : 'unknown',
			'bogomips' => number_format($bogo, 2),
			'pci' => $pci,
			'disks' => $disks,
			'ide' => $ide,
			'scsi' => $scsi,
			'usb' => $usb,
		];
	}

	private static function collectAsterisk(): array {
		$out = [
			'up' => false,
			'pjsip' => false,
			'iax' => true,
			'channel_rows' => [],
			'channel_lines' => [],
			'sip_rows' => [],
			'sip_summary' => '0 active SIP channels',
			'peer_rows' => [],
			'peer_summary' => '0 sip peers [Monitored: 0 online, 0 offline Unmonitored: 0 online, 0 offline]',
			'reg_rows' => [],
			'reg_summary' => '0 sip registrations.',
			'iax_rows' => [],
			'iax_summary' => '0 IAX2 registrations.',
			'iax_peer_rows' => [],
			'iax_peer_summary' => '0 iax2 peers [0 online, 0 offline, 0 unmonitored]',
			'iax_missing' => false,
		];
		try {
			$ast = \FreePBX::astman();
		} catch (\Throwable $e) {
			return $out;
		}
		if (!is_object($ast) || !$ast->connected()) {
			return $out;
		}
		$out['up'] = true;

		$coreText = self::amiCommand($ast, 'core show channels');
		$activeChannels = null;
		$activeCalls = null;
		if (preg_match('/(\d+) active channels/', $coreText, $m)) {
			$activeChannels = (int) $m[1];
		}
		if (preg_match('/(\d+) active calls/', $coreText, $m)) {
			$activeCalls = (int) $m[1];
		}

		$stats = self::parseChannelStats(self::amiCommand($ast, 'pjsip show channelstats'));
		$rawChannels = [];
		try {
			$listed = $ast->CoreShowChannels();
			if (is_array($listed)) {
				$rawChannels = $listed;
			}
		} catch (\Throwable $e) {
			$rawChannels = [];
		}

		$sipCount = 0;
		foreach ($rawChannels as $ch) {
			if (!is_array($ch)) {
				continue;
			}
			$channel = (string) ($ch['Channel'] ?? '');
			if ($channel === '') {
				continue;
			}
			$exten = (string) ($ch['Exten'] ?? '');
			$context = (string) ($ch['Context'] ?? '');
			if ($exten !== '' && $context !== '') {
				$location = $exten . '@' . $context;
			} elseif ($exten !== '') {
				$location = $exten;
			} else {
				$location = $context;
			}
			$app = (string) ($ch['Application'] ?? '');
			$data = (string) ($ch['ApplicationData'] ?? '');
			$appCell = $data !== '' ? $app . '(' . $data . ')' : $app;
			$state = (string) ($ch['ChannelStateDesc'] ?? '');
			$out['channel_rows'][] = [$channel, $location, $state, $appCell];

			if (!preg_match('/^(?:PJSIP|SIP)\//', $channel)) {
				continue;
			}
			$sipCount++;
			$peer = $channel;
			if (preg_match('/^(?:PJSIP|SIP)\/([^-]+)/', $channel, $pm)) {
				$peer = $pm[1];
			}
			$cidName = trim((string) ($ch['CallerIDName'] ?? ''));
			$cidNum = trim((string) ($ch['CallerIDNum'] ?? ''));
			if ($cidName !== '' && $cidNum !== '' && $cidName !== $cidNum) {
				$user = $cidName . ' <' . $cidNum . '>';
			} elseif ($cidNum !== '') {
				$user = $cidNum;
			} else {
				$user = $cidName;
			}
			$callId = (string) ($ch['Uniqueid'] ?? '');
			if ($sipCount <= 15) {
				try {
					$var = $ast->GetVar($channel, 'CHANNEL(pjsip,call-id)');
					if (is_array($var) && ($var['Response'] ?? '') === 'Success' && ($var['Value'] ?? '') !== '') {
						$callId = (string) $var['Value'];
					}
				} catch (\Throwable $e) {
				}
			}
			$stat = $stats[$channel] ?? $stats[preg_replace('/^PJSIP\//', '', $channel)] ?? null;
			$seq = '—';
			$format = '—';
			if (is_array($stat)) {
				if (($stat['codec'] ?? '') !== '' && $stat['codec'] !== 'direct') {
					$format = $stat['codec'];
				}
				if (($stat['rx'] ?? '') !== '' || ($stat['tx'] ?? '') !== '') {
					$seq = ($stat['tx'] ?? '0') . '/' . ($stat['rx'] ?? '0');
				} elseif (($stat['codec'] ?? '') === 'direct') {
					$seq = 'direct';
					$format = 'direct';
				}
			}
			$hold = (stripos($state, 'hold') !== false) ? 'Yes' : 'No';
			$out['sip_rows'][] = [$peer, $user, $callId, $seq, $format, $hold, $appCell !== '' ? $appCell : '—'];
		}
		if ($activeChannels === null) {
			$activeChannels = count($out['channel_rows']);
		}
		if ($activeCalls === null) {
			$activeCalls = 0;
		}
		$out['channel_lines'] = [
			$activeChannels . ' active channels',
			$activeCalls . ' active calls',
		];
		$out['sip_summary'] = $sipCount . ' active SIP channels';

		$contacts = self::parseContacts(self::amiCommand($ast, 'pjsip show contacts'));
		$regText = self::amiCommand($ast, 'pjsip show registrations');
		if (str_contains($regText, 'No such command')) {
			$out['pjsip'] = false;
		} else {
			$out['pjsip'] = true;
			$regs = self::parseRegistrations($regText);
			foreach ($regs as $reg) {
				$out['reg_rows'][] = [$reg['host'], $reg['username'], $reg['refresh'], $reg['state'], $reg['regtime']];
			}
			$out['reg_summary'] = count($out['reg_rows']) . ' sip registrations.';
		}

		$peers = self::buildPeers($contacts);
		$monOn = 0;
		$monOff = 0;
		$unOn = 0;
		$unOff = 0;
		foreach ($peers as $peer) {
			$out['peer_rows'][] = [
				$peer['name'],
				$peer['host'],
				$peer['dyn'],
				$peer['nat'],
				$peer['acl'],
				$peer['port'],
				$peer['status'],
			];
			if ($peer['monitored']) {
				if ($peer['online']) {
					$monOn++;
				} else {
					$monOff++;
				}
			} elseif ($peer['online']) {
				$unOn++;
			} else {
				$unOff++;
			}
		}
		$nPeers = count($peers);
		$out['peer_summary'] = $nPeers . ' sip peers [Monitored: ' . $monOn . ' online, ' . $monOff . ' offline Unmonitored: ' . $unOn . ' online, ' . $unOff . ' offline]';

		$iaxText = self::amiCommand($ast, 'iax2 show registry');
		$iaxPeerText = self::amiCommand($ast, 'iax2 show peers');
		if (str_contains($iaxText, 'No such command') || str_contains($iaxPeerText, 'No such command')) {
			$out['iax_missing'] = true;
			$out['iax'] = false;
		} else {
			$iax = self::parseIaxRegistry($iaxText);
			$out['iax_rows'] = $iax['rows'];
			$out['iax_summary'] = $iax['summary'] !== '' ? $iax['summary'] : (count($iax['rows']) . ' IAX2 registrations.');
			$iaxPeers = self::parseIaxPeers($iaxPeerText);
			$out['iax_peer_rows'] = $iaxPeers['rows'];
			$out['iax_peer_summary'] = $iaxPeers['summary'] !== '' ? $iaxPeers['summary'] : (count($iaxPeers['rows']) . ' iax2 peers [0 online, 0 offline, 0 unmonitored]');
		}
		return $out;
	}

	private static function buildPeers(array $contacts): array {
		$base = '/etc/asterisk/';
		$endpoints = self::readSections([
			$base . 'pjsip.endpoint.conf',
			$base . 'pjsip.endpoint_custom.conf',
			$base . 'pjsip.endpoint_custom_post.conf',
		]);
		$aors = self::readSections([
			$base . 'pjsip.aor.conf',
			$base . 'pjsip.aor_custom.conf',
			$base . 'pjsip.aor_custom_post.conf',
		]);
		$auths = self::readSections([
			$base . 'pjsip.auth.conf',
			$base . 'pjsip.auth_custom.conf',
			$base . 'pjsip.auth_custom_post.conf',
		]);
		$peers = [];
		foreach ($endpoints as $id => $ep) {
			if (($ep['type'] ?? '') !== 'endpoint' || $id === '' || $id === '0') {
				continue;
			}
			$authId = $ep['auth'] ?? ($ep['outbound_auth'] ?? '');
			$authId = trim(explode(',', $authId)[0]);
			$username = $auths[$authId]['username'] ?? '';
			if ($username === '') {
				$username = $id;
			}
			$aorId = trim(explode(',', (string) ($ep['aors'] ?? $id))[0]);
			$aor = $aors[$aorId] ?? [];
			$qualify = (int) ($aor['qualify_frequency'] ?? 0);
			$staticUri = trim((string) ($aor['contact'] ?? ''));
			$dyn = $staticUri === '' ? 'D' : '';
			$nat = 'no';
			if (strcasecmp($ep['rewrite_contact'] ?? '', 'yes') === 0 || strcasecmp($ep['force_rport'] ?? '', 'yes') === 0) {
				$nat = 'yes';
			}
			$aclVal = strtolower(trim((string) ($ep['acl'] ?? '')));
			$acl = ($aclVal !== '' && $aclVal !== 'no' && $aclVal !== '0') ? 'yes' : 'no';

			$host = '(Unspecified)';
			$port = '0';
			$status = 'UNKNOWN';
			$online = false;
			$monitored = false;
			$live = $contacts[$aorId] ?? $contacts[$id] ?? [];
			if ($live) {
				$chosen = $live[0];
				foreach ($live as $c) {
					if (strcasecmp($c['status'], 'Avail') === 0 || strcasecmp($c['status'], 'NonQual') === 0) {
						$chosen = $c;
						break;
					}
				}
				if ($chosen['host'] !== '') {
					$host = $chosen['host'];
				}
				if ($chosen['port'] !== '') {
					$port = $chosen['port'];
				}
				$status = self::contactStatus($chosen);
				$online = ($status === 'OK' || str_starts_with($status, 'OK '));
				$st = strtolower($chosen['status']);
				$monitored = ($qualify > 0) || $st === 'avail' || $st === 'unavail';
				if ($st === 'nonqual') {
					$monitored = false;
				}
			} elseif ($staticUri !== '') {
				[$host, $portNum] = self::sipHost($staticUri);
				$port = $portNum !== '' ? $portNum : '5060';
				$status = $qualify > 0 ? 'UNREACHABLE' : 'UNKNOWN';
				$monitored = $qualify > 0;
				$online = false;
			} else {
				// qualify with no contact is a monitored peer that is offline.
				$status = $qualify > 0 ? 'UNREACHABLE' : 'UNKNOWN';
				$monitored = $qualify > 0;
				$online = false;
			}
			$peers[] = [
				'name' => $id . '/' . $username,
				'host' => $host,
				'dyn' => $dyn,
				'nat' => $nat,
				'acl' => $acl,
				'port' => $port,
				'status' => $status,
				'online' => $online,
				'monitored' => $monitored,
			];
		}
		usort($peers, function ($a, $b) {
			return strnatcasecmp($a['name'], $b['name']);
		});
		return $peers;
	}

	private static function contactStatus(array $c): string {
		$s = strtolower((string) ($c['status'] ?? ''));
		if ($s === 'avail' || $s === 'nonqual') {
			$rtt = $c['rtt'] ?? '';
			if (is_numeric($rtt)) {
				return 'OK (' . (string) (int) round((float) $rtt) . ' ms)';
			}
			return 'OK';
		}
		if ($s === 'unavail') {
			return 'UNREACHABLE';
		}
		return 'UNKNOWN';
	}

	private static function amiCommand($ast, string $cmd): string {
		try {
			$r = $ast->Command($cmd);
		} catch (\Throwable $e) {
			return '';
		}
		if (!is_array($r)) {
			return '';
		}
		$data = (string) ($r['data'] ?? '');
		$data = preg_replace('/^Privilege:\s*Command\s*/', '', $data);
		return trim((string) $data);
	}

	private static function parseContacts(string $text): array {
		$out = [];
		foreach (preg_split('/\n/', $text) as $line) {
			if (!preg_match('/Contact:\s+(\S+)\/(sips?:\S+)\s+\S+\s+(\S+)\s+(\S+)/i', $line, $m)) {
				continue;
			}
			[$host, $port] = self::sipHost($m[2]);
			$out[$m[1]][] = [
				'host' => $host,
				'port' => $port,
				'status' => $m[3],
				'rtt' => $m[4],
			];
		}
		return $out;
	}

	private static function parseRegistrations(string $text): array {
		$rows = [];
		if ($text === '' || str_contains($text, 'No objects found') || str_contains($text, 'No such command')) {
			return $rows;
		}
		foreach (preg_split('/\n/', $text) as $line) {
			$t = trim($line);
			if ($t === '' || $t[0] === '<' || str_starts_with($t, '=') || str_starts_with($t, 'Objects found')) {
				continue;
			}
			if (!preg_match('/^(\S+)\/(\S+)\s+(\S+)\s+(\S+)\s*(.*)$/', $t, $m)) {
				continue;
			}
			$exp = trim($m[5]);
			$refresh = '—';
			if (preg_match('/(\d+)\s*s/', $exp, $em)) {
				$refresh = $em[1];
			}
			[$host, $port] = self::sipHost($m[2]);
			if ($port !== '' && !str_contains($host, ':')) {
				$host .= ':' . $port;
			}
			$rows[] = [
				'host' => $host,
				'username' => $m[3],
				'refresh' => $refresh,
				'state' => $m[4],
				'regtime' => $exp !== '' ? $exp : '—',
			];
		}
		return $rows;
	}

	private static function parseChannelStats(string $text): array {
		$out = [];
		foreach (preg_split('/\n/', $text) as $line) {
			if (stripos($line, 'direct media') !== false && preg_match('/^\s*(\S+)\s+direct media/', $line, $m)) {
				$out[$m[1]] = ['codec' => 'direct', 'rx' => '', 'tx' => ''];
				continue;
			}
			if (!preg_match('/^\s*\S+\s+(\S+)\s+\d+:\d+:\d+\s+(\S+)\s+(\d+K?)\s+\S+\s+\S+\s+\S+\s+(\d+K?)\b/', $line, $m)) {
				continue;
			}
			$row = ['codec' => $m[2], 'rx' => $m[3], 'tx' => $m[4]];
			$out[$m[1]] = $row;
			$out['PJSIP/' . $m[1]] = $row;
		}
		return $out;
	}

	private static function parseIaxPeers(string $text): array {
		$rows = [];
		$summary = '';
		// chan_iax2.c PEERS_FORMAT, which is what `iax2 show peers` prints
		// and what Asterisk Info shows for IAX2. The header uses a different
		// width, so rows are sliced from the data format, not the heading.
		foreach (preg_split('/\n/', $text) as $line) {
			if (preg_match('/^\s*\d+ iax2 peers\b/i', $line)) {
				$summary = trim($line);
				continue;
			}
			if (strlen($line) < 120 || str_starts_with(ltrim($line), 'Name/Username')) {
				continue;
			}
			$name = trim(substr($line, 0, 15));
			if ($name === '') {
				continue;
			}
			$flags = [];
			foreach ([58, 111, 115] as $at) {
				$flag = trim(substr($line, $at, 3));
				if ($flag !== '') {
					$flags[] = $flag;
				}
			}
			$rows[] = [
				$name,
				trim(substr($line, 17, 40)),
				implode(' ', $flags),
				trim(substr($line, 63, 40)),
				trim(substr($line, 105, 6)),
				trim(substr($line, 120, 11)),
				trim(substr($line, 132)),
			];
		}
		return ['rows' => $rows, 'summary' => $summary];
	}

	private static function parseIaxRegistry(string $text): array {
		$rows = [];
		$summary = '';
		$header = null;
		$pos = [];
		foreach (preg_split('/\n/', $text) as $line) {
			if (preg_match('/^\s*\d+ IAX2 registrations\.?\s*$/', $line)) {
				$summary = trim($line);
				continue;
			}
			if ($header === null && str_contains($line, 'Host') && str_contains($line, 'State')) {
				$header = $line;
				foreach (['Host', 'dnsmgr', 'Username', 'Perceived', 'Refresh', 'State'] as $key) {
					$at = strpos($header, $key);
					$pos[$key] = $at === false ? null : $at;
				}
				continue;
			}
			if ($header === null || trim($line) === '' || $pos['Host'] === null) {
				continue;
			}
			$slice = function ($key, $next) use ($line, $pos) {
				$start = $pos[$key];
				if ($start === null || strlen($line) <= $start) {
					return '';
				}
				$end = $pos[$next] ?? null;
				$len = ($end !== null && $end > $start) ? $end - $start : null;
				$bit = $len === null ? substr($line, $start) : substr($line, $start, $len);
				return trim($bit);
			};
			$host = $slice('Host', 'dnsmgr');
			if ($host === '' || strcasecmp($host, 'Host') === 0) {
				continue;
			}
			$rows[] = [
				$host,
				$slice('dnsmgr', 'Username'),
				$slice('Username', 'Perceived'),
				$slice('Perceived', 'Refresh'),
				$slice('Refresh', 'State'),
				$slice('State', ''),
			];
		}
		return ['rows' => $rows, 'summary' => $summary];
	}

	private static function sipHost(string $uri): array {
		$u = preg_replace('#^sips?:#i', '', trim($uri));
		$at = strrpos($u, '@');
		if ($at !== false) {
			$u = substr($u, $at + 1);
		}
		if (str_starts_with($u, '[')) {
			if (preg_match('/^\[([^\]]+)\](?::(\d+))?/', $u, $m)) {
				return [$m[1], $m[2] ?? ''];
			}
		}
		if (preg_match('/^([^:;]+)(?::(\d+))?/', $u, $m)) {
			return [$m[1], $m[2] ?? ''];
		}
		return [$uri, ''];
	}

	private static function readSections(array $paths): array {
		$sections = [];
		$cur = null;
		foreach ($paths as $path) {
			if (!is_readable($path)) {
				continue;
			}
			$lines = file($path, FILE_IGNORE_NEW_LINES);
			if ($lines === false) {
				continue;
			}
			foreach ($lines as $line) {
				$line = trim($line);
				if ($line === '' || $line[0] === ';' || $line[0] === '#') {
					continue;
				}
				if ($line[0] === '[' && str_ends_with($line, ']')) {
					$cur = substr($line, 1, -1);
					if (!isset($sections[$cur])) {
						$sections[$cur] = [];
					}
					continue;
				}
				if ($cur === null || !str_contains($line, '=')) {
					continue;
				}
				[$k, $v] = explode('=', $line, 2);
				$k = strtolower(trim($k));
				if ($k === 'password' || $k === 'md5_cred' || $k === 'refresh_token' || $k === 'oauth_secret') {
					continue;
				}
				$v = trim($v);
				if (str_contains($v, ' ;')) {
					$v = trim(substr($v, 0, strpos($v, ' ;')));
				}
				$sections[$cur][$k] = $v;
			}
		}
		return $sections;
	}

	private static function renderVitals(array $v, array $h = []): string {
		$rows = [
			[_('Canonical Hostname'), $v['hostname']],
			[_('Listening IP'), $v['ip']],
			[_('WAN IP'), $v['wan']],
			[_('CPU'), self::cpuLine($h)],
			[_('Kernel Version'), $v['kernel']],
			[_('Distro Name'), $v['distro']],
			[_('Uptime'), $v['uptime']],
			[_('Current Users'), $v['users']],
			[_('Load Averages'), $v['load']],
		];
		return self::kvTable($rows);
	}

	private static function cpuLine(array $h): string {
		$parts = [];
		$model = trim((string) ($h['model'] ?? ''));
		$speed = trim((string) ($h['speed'] ?? ''));
		$cores = trim((string) ($h['processors'] ?? ''));
		if ($model !== '' && strcasecmp($model, 'unknown') !== 0) {
			$parts[] = $model;
		}
		if ($speed !== '' && strcasecmp($speed, 'unknown') !== 0) {
			$parts[] = $speed;
		}
		if ($cores !== '' && ctype_digit($cores)) {
			$n = (int) $cores;
			$parts[] = $n === 1 ? '1 Core' : ($n . ' Cores');
		}
		return $parts !== [] ? implode(', ', $parts) : 'unknown';
	}

	private static function renderHardware(array $h): string {
		$rows = [
			[_('Processors'), $h['processors']],
			[_('Model'), $h['model']],
			[_('CPU Speed'), $h['speed']],
			[_('Cache Size'), $h['cache']],
			[_('System Bogomips'), $h['bogomips']],
		];
		$html = self::kvTable($rows, false);
		$html .= self::deviceBlock(_('PCI Devices'), $h['pci']);
		$html .= self::deviceBlock(_('Disk Devices'), $h['disks']);
		$html .= self::deviceBlock(_('IDE Devices'), $h['ide']);
		$html .= self::deviceBlock(_('SCSI Devices'), $h['scsi']);
		$html .= self::deviceBlock(_('USB Devices'), $h['usb']);
		return self::wrap($html);
	}

	private static function renderChannels(array $a): string {
		if (empty($a['up'])) {
			return self::note(_('Asterisk Manager is not connected.'));
		}
		return self::dataTable(
			[_('Channel'), _('Location'), _('State'), _('Application(Data)')],
			$a['channel_rows'],
			$a['channel_lines']
		);
	}

	private static function renderSipChannels(array $a): string {
		if (empty($a['up'])) {
			return self::note(_('Asterisk Manager is not connected.'));
		}
		if (empty($a['pjsip']) && !$a['sip_rows']) {
			return self::note(_('PJSIP is not loaded.'));
		}
		return self::dataTable(
			[_('Peer'), _('User/ANR'), _('Call ID'), _('Seq (Tx/Rx)'), _('Format'), _('Hold'), _('Last Message')],
			$a['sip_rows'],
			[$a['sip_summary']]
		);
	}

	private static function renderPeers(array $a): string {
		if (empty($a['up'])) {
			return self::note(_('Asterisk Manager is not connected.'));
		}
		return self::dataTable(
			[_('Name/username'), _('Host'), _('Dyn'), _('Nat'), _('ACL'), _('Port'), _('Status')],
			$a['peer_rows'],
			[$a['peer_summary']]
		);
	}

	private static function renderRegistry(array $a): string {
		if (empty($a['up'])) {
			return self::note(_('Asterisk Manager is not connected.'));
		}
		if (empty($a['pjsip'])) {
			return self::note(_('PJSIP is not loaded.'));
		}
		return self::dataTable(
			[_('Host'), _('Username'), _('Refresh'), _('State'), _('Reg.Time')],
			$a['reg_rows'],
			[$a['reg_summary']]
		);
	}

	private static function renderIaxPeers(array $a): string {
		if (empty($a['up'])) {
			return self::note(_('Asterisk Manager is not connected.'));
		}
		if (!empty($a['iax_missing'])) {
			return self::note(_('IAX2 is not loaded.'));
		}
		return self::dataTable(
			[_('Name/Username'), _('Host'), _('Flags'), _('Mask'), _('Port'), _('Status'), _('Description')],
			$a['iax_peer_rows'] ?? [],
			[$a['iax_peer_summary'] ?? '']
		);
	}

	private static function renderIax(array $a): string {
		if (empty($a['up'])) {
			return self::note(_('Asterisk Manager is not connected.'));
		}
		if (!empty($a['iax_missing'])) {
			return self::note(_('IAX2 is not loaded.'));
		}
		return self::dataTable(
			[_('Host'), _('dnsmgr'), _('Username'), _('Perceived'), _('Refresh'), _('State')],
			$a['iax_rows'],
			[$a['iax_summary']]
		);
	}

	private static function kvTable(array $rows, bool $wrap = true): string {
		$html = '<table class="table table-condensed table-striped"><tbody>';
		foreach ($rows as $row) {
			$html .= '<tr><td style="width:42%"><strong>' . self::e($row[0]) . '</strong></td><td>' . self::e($row[1]) . '</td></tr>';
		}
		$html .= '</tbody></table>';
		return $wrap ? self::wrap($html) : $html;
	}

	private static function deviceBlock(string $title, array $items): string {
		$html = '<p style="margin:8px 0 2px"><strong>' . self::e($title) . '</strong></p>';
		if (!$items) {
			return $html . '<p>none</p>';
		}
		$html .= '<ul class="list-unstyled">';
		foreach ($items as $item) {
			$html .= '<li>- ' . self::e($item) . '</li>';
		}
		$html .= '</ul>';
		return $html;
	}

	private static function dataTable(array $headers, array $rows, array $lines): string {
		$html = '<div class="table-responsive"><table class="table table-condensed table-striped"><thead><tr>';
		foreach ($headers as $h) {
			$html .= '<th>' . self::e($h) . '</th>';
		}
		$html .= '</tr></thead><tbody>';
		foreach ($rows as $row) {
			$html .= '<tr>';
			foreach ($row as $cell) {
				$html .= '<td>' . self::e($cell) . '</td>';
			}
			$html .= '</tr>';
		}
		$html .= '</tbody></table></div>';
		if ($lines) {
			$html .= '<p class="text-center"><small>';
			foreach (array_values($lines) as $i => $line) {
				if ($i) {
					$html .= '<br>';
				}
				$html .= self::e($line);
			}
			$html .= '</small></p>';
		}
		return self::wrap($html);
	}

	private static function note(string $text): string {
		return self::wrap('<p class="text-center">' . self::e($text) . '</p>');
	}

	private static function wrap(string $inner): string {
		return '<div class="container-fluid voxbox-dash"><style>.voxbox-dash td,.voxbox-dash th{font-size:12px;vertical-align:top}.voxbox-dash ul{margin:0}</style>' . $inner . '</div>';
	}

	private static function e($value): string {
		return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
	}

	private static function formatUptime(int $secs): string {
		if ($secs < 0) {
			$secs = 0;
		}
		$days = intdiv($secs, 86400);
		$hours = intdiv($secs % 86400, 3600);
		$mins = intdiv($secs % 3600, 60);
		$parts = [];
		if ($days === 1) {
			$parts[] = '1 day';
		} elseif ($days > 1) {
			$parts[] = $days . ' days';
		}
		if ($hours === 1) {
			$parts[] = '1 hour';
		} elseif ($hours > 1) {
			$parts[] = $hours . ' hours';
		}
		if ($mins === 1) {
			$parts[] = '1 minute';
		} elseif ($mins > 1 || !$parts) {
			$parts[] = $mins . ' minutes';
		}
		return implode(', ', $parts);
	}

	private static function humanSectors(int $sectors): string {
		$bytes = $sectors * 512;
		if ($bytes >= 1073741824) {
			return rtrim(rtrim(number_format($bytes / 1073741824, 2), '0'), '.') . ' GB';
		}
		if ($bytes >= 1048576) {
			return rtrim(rtrim(number_format($bytes / 1048576, 2), '0'), '.') . ' MB';
		}
		return rtrim(rtrim(number_format($bytes / 1024, 2), '0'), '.') . ' KB';
	}
}
