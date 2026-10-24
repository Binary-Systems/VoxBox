<?php
/**
 * VoxBox login landing — Binary Systems, Inc.
 * Owned VIEW_LOGIN skin (upgrade-safe). Do not edit Framework login.php.
 * Ships in the VoxBox module.
 * freepbx_settings: VIEW_LOGIN = modules/voxbox/views/login.php
 *
 * Changes vs stock Framework login.php:
 *   - "FreePBX Administration" → "VoxBox Administration"
 *   - Keep User Control Panel when ucp module present
 *   - Remove Operator Panel block
 *   - Remove Get Support (help.sangoma.com) block entirely
 *   - VoxBox Administration uses stock sys-admin.png (wrench); no Webmin on landing
 *   - Credentials live in a <template> until the Administration icon opens one dialog.
 *     Safari Passwords will not fill or submit a hidden copy of the form.
 *
 * Copyright (C) 2007-2026 Binary Systems, Inc.
 */
?>
<?php if($errors) {?>
	<span class="obe_error">
		<?php echo _('Please correct the following errors:')?>
		<?php echo ul($errors);?>
	</span>
<?php } ?>
<div id="login_form"></div>
<template id="voxbox-login-template">
	<form id="loginform" method="post" action="config.php" autocomplete="on">
		<h3><?php echo _('To get started, please enter your credentials:')?></h3>
		<div class="form-group">
			<input type="text" name="username" class="form-control" value="" placeholder="username" autocomplete="username" autocapitalize="none" spellcheck="false">
		</div>
		<div class="form-group">
			<input type="password" name="password" class="form-control" value="" placeholder="password" autocomplete="current-password">
		</div>
		<div style="text-align:center;padding:15px 0">
			<button type="button" id="customContinue" class="ui-button ui-corner-all ui-widget btn"><?php echo _('Continue')?></button>
			<button type="button" id="customCancel" class="ui-button ui-corner-all ui-widget btn"><?php echo _('Cancel')?></button>
		</div>
		<?php
			if (\FreePBX::Modules()->checkStatus('pbxsaml') && $PBXSAML_LICENSED) {
				$webrootpath = \FreePBX::Config()->get('AMPWEBROOT');
				include $webrootpath . '/admin/modules/pbxsaml/views/adminlogin.php';
			}
		?>
	</form>
</template>

<?php
	if (\FreePBX::Modules()->checkStatus('pbxmfa') && $PBXMFA_LICENSED) {
		$webrootpath = \FreePBX::Config()->get('AMPWEBROOT');
		include $webrootpath . '/admin/modules/pbxmfa/views/mfa/otpModal.php';
	}
?>
<div id="login_icon_holder">
	<div class="login_item_title">
		<button type="button" class="login_item" id="login_admin" style="background-image: url(assets/images/sys-admin.png);">&nbsp;</button>
		<span class="login_item_text" style="display: block;width: 160px;text-align: center;">
			<?php echo _('VoxBox Administration')?>
		</span>
	</div>
	<?php if (\FreePBX::Modules()->checkStatus('ucp')) { ?>
		<div class="login_item_title">
			<a href="/ucp" class="login_item" id="login_ari" style="background-image: url(assets/images/user-control.png);">&nbsp;</a>
			<span class="login_item_text" style="display: block;width: 160px;text-align: center;">
				<?php echo _('User Control Panel')?>
			</span>
		</div>
	<?php } ?>

	<?php /* Operator Panel and Get Support intentionally omitted for VoxBox */ ?>
	<br/>
	<br/>
	<br/>
	<br/>
	<br/>
	<div id="key" style="color: white;font-size:small">
		<?php echo session_id();?>
	</div>
</div>
<script type="text/javascript" src="assets/js/views/login.js"></script>
<?php
	if (\FreePBX::Modules()->checkStatus('userman')) {
?>
	<script type="text/javascript" src="/admin/modules/userman/assets/js/adminPwdExpReminder.js"></script>
<?php
	}
?>
<script>
(function () {
	var nativeSubmit = HTMLFormElement.prototype.submit;
	function voxboxOpenLogin() {
		if (document.querySelector(".ui-dialog #loginform")) {
			return;
		}
		var tpl = document.getElementById("voxbox-login-template");
		if (!tpl || !window.jQuery || !jQuery.fn.dialog) {
			return;
		}
		var $dialog = jQuery("<div></div>").html(tpl.innerHTML).dialog({
			title: (typeof _ === "function") ? _("Login") : "Login",
			resizable: false,
			width: 400,
			modal: true,
			buttons: [],
			close: function () {
				jQuery(this).dialog("destroy").remove();
			}
		});
		var form = $dialog.find("#loginform").get(0);
		if (!form) {
			return;
		}
		form.submit = function () {};
		if ("requestSubmit" in form) {
			form.requestSubmit = function () {};
		}
		form.addEventListener("submit", function (e) {
			if (!form.getAttribute("data-voxbox-allow-submit")) {
				e.preventDefault();
			}
		});
		function finish($form) {
			form.setAttribute("data-voxbox-allow-submit", "1");
			nativeSubmit.call(form);
		}
		$dialog.on("click", "#customContinue", function () {
			var $form = jQuery(this).closest("form");
			if (typeof checkPasswordReminder === "function") {
				if (jQuery(".resetPasswordButton").length && typeof resetAdminPassswordWithToken === "function") {
					resetAdminPassswordWithToken($form);
					return;
				}
				checkPasswordReminder($form).then(function (ok) {
					if (ok) {
						finish($form);
					}
				});
				return;
			}
			finish($form);
		});
		$dialog.on("click", "#customCancel", function () {
			$dialog.dialog("close");
		});
		$dialog.on("keydown", function (e) {
			if (e.key === "Enter") {
				e.preventDefault();
				$dialog.find("#customContinue").trigger("click");
			}
		});
		setTimeout(function () {
			$dialog.find("input[name='username']").trigger("focus");
		}, 0);
	}
	document.addEventListener("click", function (e) {
		var node = e.target && e.target.closest ? e.target.closest("#login_admin") : null;
		if (!node) {
			return;
		}
		e.preventDefault();
		e.stopPropagation();
		voxboxOpenLogin();
	}, true);
	if (window.jQuery) {
		jQuery(function () {
			jQuery("#login_admin").on("click", function (e) {
				e.preventDefault();
				e.stopImmediatePropagation();
				voxboxOpenLogin();
			});
		});
	}
})();
</script>
