param([switch]$Normal, [switch]$Lite)
$ErrorActionPreference = 'Stop'
$launchLock = [System.Threading.Mutex]::new($false, 'Local\WhatsAppPersona5Launcher')
if (!$launchLock.WaitOne(0)) { $launchLock.Dispose(); exit }
try {
    if (!$Normal) {
        $node = Join-Path $PSScriptRoot 'runtime\node.exe'
        if (!(Test-Path -LiteralPath $node)) { $node = (Get-Command node.exe -ErrorAction Stop).Source }
        $major = [int]((& $node --version).TrimStart('v').Split('.')[0])
        if ($major -lt 22) { throw 'Se necesita Node.js 22 o posterior.' }
    }
    $package = Get-AppxPackage 5319275A.WhatsAppDesktop
    if (!$package) { throw 'No se encontro WhatsApp de Microsoft Store.' }
    # Release an ephemeral loopback port immediately before starting WebView2.
    $port = 0
    if (!$Normal) {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()
    }
    $restartAttempted = $true
    Get-Process WhatsApp.Root -ErrorAction SilentlyContinue | ForEach-Object { [void]$_.CloseMainWindow() }
    Start-Sleep -Milliseconds 1500
    # Closing the window can leave WhatsApp in the tray; end only its host.
    Get-Process WhatsApp.Root -ErrorAction SilentlyContinue | Stop-Process
    Start-Sleep -Milliseconds 1200
    $started = & "$PSScriptRoot\Activate-WhatsApp.ps1" -Port $port | ConvertFrom-Json
    if (!$Normal) {
        $extra = @()
        if ($Lite) { $extra += '--lite' }
        & $node "$PSScriptRoot\apply-theme.mjs" "$port" @extra
        if ($LASTEXITCODE -ne 0) { throw 'WhatsApp no permitio aplicar el tema. Se abrira normalmente.' }
        $binding = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop
        if (@($binding | Where-Object { $_.LocalAddress -notin @('127.0.0.1', '::1') }).Count -gt 0) {
            throw 'La conexion de depuracion no esta limitada al equipo.'
        }
        # A separate, short-lived check never delays opening WhatsApp.
        try {
            $updateScript = Join-Path $PSScriptRoot 'Update-WhatsApp.ps1'
            if (Test-Path -LiteralPath $updateScript) {
                Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $updateScript + '"')
            }
        } catch { } # Offline/update errors must not restart WhatsApp.
    }
} catch {
    $reason = $_.Exception.Message
    # Fail closed: no debug session left behind if applying the theme fails.
    if ($restartAttempted) {
        Get-Process WhatsApp.Root -ErrorAction SilentlyContinue | Stop-Process
        Start-Sleep -Milliseconds 1200
        & "$PSScriptRoot\Activate-WhatsApp.ps1" -Port 0 | Out-Null
    }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($reason, 'WhatsApp Persona 5') | Out-Null
    exit 1
} finally {
    $launchLock.ReleaseMutex()
    $launchLock.Dispose()
}
