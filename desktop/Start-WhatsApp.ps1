param([switch]$Normal, [switch]$Lite, [switch]$Startup)
$ErrorActionPreference = 'Stop'
$logDirectory = Join-Path $env:LOCALAPPDATA 'WhatsAppPersona5'
$logPath = Join-Path $logDirectory 'launch.log'
function Write-LaunchLog([string]$Message) {
    try {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        if ((Test-Path $logPath) -and (Get-Item $logPath).Length -gt 131072) {
            Move-Item -LiteralPath $logPath -Destination ($logPath + '.previous') -Force
        }
        Add-Content -LiteralPath $logPath -Value ((Get-Date -Format o) + ' ' + $Message) -Encoding UTF8
    } catch { } # Diagnostics must never prevent launching.
}
Write-LaunchLog "Launch requested; startup=$Startup; normal=$Normal"
# Allow Windows time to restore Store apps and their WebView processes.
if ($Startup) { Start-Sleep -Seconds 30 }
$launchLock = [System.Threading.Mutex]::new($false, 'Local\WhatsAppPersona5Launcher')
$ownsLock = $false
$stage = 'Preparar arranque'
try {
    try { $ownsLock = $launchLock.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $ownsLock = $true }
    if (!$ownsLock) { Write-LaunchLog 'Another launcher is active.'; return }
    if (!$Normal) {
        $node = Join-Path $PSScriptRoot 'runtime\node.exe'
        if (!(Test-Path -LiteralPath $node)) { $node = (Get-Command node.exe -ErrorAction Stop).Source }
        $major = [int]((& $node --version).TrimStart('v').Split('.')[0])
        if ($major -lt 22) { throw 'Se necesita Node.js 22 o posterior.' }
    }
    $stage = 'Localizar WhatsApp oficial'
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
    $stage = 'Cerrar la sesion anterior de WhatsApp'
    $restartAttempted = $true
    Get-Process WhatsApp.Root -ErrorAction SilentlyContinue | ForEach-Object { [void]$_.CloseMainWindow() }
    Start-Sleep -Milliseconds 1500
    # Closing the window can leave WhatsApp in the tray; end only its host.
    Get-Process WhatsApp.Root -ErrorAction SilentlyContinue | Stop-Process
    Start-Sleep -Milliseconds 1200
    Write-LaunchLog 'Activating official WhatsApp.'
    $stage = 'Activar WhatsApp oficial'
    $started = & "$PSScriptRoot\Activate-WhatsApp.ps1" -Port $port | ConvertFrom-Json
    if (!$Normal) {
        $extra = @()
        if ($Lite) { $extra += '--lite' }
        if ($Startup) { $extra += '--startup' }
        $stage = 'Aplicar tema'
        & $node "$PSScriptRoot\apply-theme.mjs" "$port" @extra 2>&1 | ForEach-Object { Write-LaunchLog ([string]$_) }
        if ($LASTEXITCODE -ne 0) { throw 'WhatsApp no permitio aplicar el tema. Se abrira normalmente.' }
        $stage = 'Comprobar puerto local de WhatsApp'
        & "$PSScriptRoot\Assert-LoopbackListener.ps1" -Port $port
        Write-LaunchLog 'Theme verified; actual TCP listeners limited to loopback (.NET, no CIM).'
        $popup = Join-Path $PSScriptRoot 'NotificationPopup.exe'
        if(Test-Path -LiteralPath $popup) {
            try { Start-Process -FilePath $node -WindowStyle Hidden -ArgumentList ('"' + (Join-Path $PSScriptRoot 'notifications-host.mjs') + '" ' + $port) }
            catch { Write-LaunchLog 'Optional notification helper could not start; native notices remain available.' }
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
    Write-LaunchLog ('Failed at ' + $stage + ': ' + $reason + '; HRESULT=' + $_.Exception.HResult + '; type=' + $_.Exception.GetType().FullName + '; source=' + $_.InvocationInfo.PositionMessage)
    # Fail closed: no debug session left behind if applying the theme fails.
    if ($restartAttempted) {
        try {
            Get-Process WhatsApp.Root -ErrorAction SilentlyContinue | Stop-Process
            Start-Sleep -Milliseconds 1200
            & "$PSScriptRoot\Activate-WhatsApp.ps1" -Port 0 | Out-Null
        } catch { Write-LaunchLog ('Normal activation also failed: ' + $_.Exception.Message) }
    }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(($reason + "`n`nRegistro del arranque: " + $logPath), 'WhatsApp Persona 5') | Out-Null
    exit 1
} finally {
    if ($ownsLock) { $launchLock.ReleaseMutex() }
    $launchLock.Dispose()
}
