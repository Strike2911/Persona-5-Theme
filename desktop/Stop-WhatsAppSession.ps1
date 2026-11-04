$ErrorActionPreference = 'Stop'
# Hold process handles before closing the window. A fixed sleep does not prove
# the old Store app has exited, especially while Windows restores apps at login.
$hosts = @(Get-Process WhatsApp.Root -ErrorAction SilentlyContinue)
try {
    foreach ($hostProcess in $hosts) {
        try { [void]$hostProcess.Handle; [void]$hostProcess.CloseMainWindow() }
        catch { if (!$hostProcess.HasExited) { throw } }
    }
    foreach ($hostProcess in $hosts) {
        if (!$hostProcess.WaitForExit(1500)) {
            try { $hostProcess.Kill() }
            catch { if (!$hostProcess.HasExited) { throw } }
            if (!$hostProcess.WaitForExit(5000)) { throw 'La sesion anterior de WhatsApp no termino de cerrarse.' }
        }
    }
} finally { foreach ($hostProcess in $hosts) { $hostProcess.Dispose() } }
