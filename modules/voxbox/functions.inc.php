<?php
/**
 * Reject IncrediblePBX if someone tries to install it while VoxBox is enabled.
 * FreePBX calls voxbox_module_install_check_callback() before the other module
 * is marked installed. Returning a string rejects the install.
 *
 * Copyright (C) 2007-2026 Binary Systems, Inc.
 */

function voxbox_module_install_check_callback($modules)
{
    if (!is_array($modules) || !isset($modules['incrediblepbx'])) {
        return true;
    }
    return 'IncrediblePBX is not part of VoxBox and cannot be installed.';
}
