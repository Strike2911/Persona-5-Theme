param([switch]$Normal, [switch]$Lite, [switch]$Startup)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules'
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
$launchLock = [System.Threading.Mutex]::new($false, 'Local\WhatsAppPersona5Launcher')
$ownsLock = $false
$stage = 'Preparar arranque'
try {
    try { $ownsLock = $launchLock.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $ownsLock = $true }
    if (!$ownsLock) { Write-LaunchLog 'Another launcher is active.'; return }
    # Include the startup delay in the lock so two login launches cannot queue
    # up and restart an already themed WhatsApp a second time.
    if ($Startup) { Start-Sleep -Seconds 30 }
    if (!$Normal) {
        $node = Join-Path $PSScriptRoot 'runtime\node.exe'
        if (!(Test-Path -LiteralPath $node)) { $node = (Get-Command node.exe -ErrorAction Stop).Source }
        $major = [int]((& $node --version).TrimStart('v').Split('.')[0])
        if ($major -lt 22) { throw 'Se necesita Node.js 22 o posterior.' }
    }
    $stage = 'Localizar WhatsApp oficial'
    $package = Get-AppxPackage 5319275A.WhatsAppDesktop
    if (!$package) { throw 'No se encontro WhatsApp de Microsoft Store.' }
    $stage = 'Cerrar la sesion anterior de WhatsApp'
    $restartAttempted = $true
    & "$PSScriptRoot\Stop-WhatsAppSession.ps1"
    # Release an ephemeral loopback port immediately before starting WebView2.
    $port = 0
    if (!$Normal) {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()
    }
    Write-LaunchLog 'Activating official WhatsApp.'
    $stage = 'Activar WhatsApp oficial'
    $started = & "$PSScriptRoot\Activate-WhatsApp.ps1" -Port $port | ConvertFrom-Json
    if (!$Normal) {
        $stage = 'Aplicar tema'
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            $result = & "$PSScriptRoot\Invoke-ThemeProcess.ps1" -Node $node -Port $port -Lite:$Lite -Startup:($Startup -and $attempt -eq 1)
            if ($result.Output) { Write-LaunchLog $result.Output.Trim() }
            if ($result.Error) { Write-LaunchLog $result.Error.Trim() }
            if ($result.Code -eq 0) {
                $stage = 'Comprobar puerto local de WhatsApp'
                try {
                    & "$PSScriptRoot\Assert-LoopbackListener.ps1" -Port $port
                    break
                } catch {
                    # A restored WebView can disappear just after injection.
                    # Retry a missing listener, but never a non-loopback one.
                    if (!$_.Exception.Data['P5Retryable'] -or $attempt -eq 2) { throw }
                    Write-LaunchLog 'Debug listener disappeared after applying the theme; recovering once.'
                }
            } elseif ($result.Code -ne 2 -or $attempt -eq 2) {
                throw ('No se pudo conectar o aplicar el tema tras ' + $attempt + ' intento(s). Se intentara abrir WhatsApp normal. Detalle: ' + $result.Error.Trim())
            }
            Write-LaunchLog 'Local startup not ready; restarting official WhatsApp once for recovery.'
            & "$PSScriptRoot\Stop-WhatsAppSession.ps1"
            $started = & "$PSScriptRoot\Activate-WhatsApp.ps1" -Port $port | ConvertFrom-Json
            $stage = 'Aplicar tema (recuperacion)'
        }
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
            & "$PSScriptRoot\Stop-WhatsAppSession.ps1"
            & "$PSScriptRoot\Activate-WhatsApp.ps1" -Port 0 | Out-Null
        } catch { Write-LaunchLog ('Normal activation also failed: ' + $_.Exception.Message) }
    }
    # Release before showing a modal error: dismissing it must not block a new launch.
    if ($ownsLock) { $launchLock.ReleaseMutex(); $ownsLock = $false }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(($reason + "`n`nRegistro del arranque: " + $logPath), 'WhatsApp Persona 5') | Out-Null
    exit 1
} finally {
    if ($ownsLock) { $launchLock.ReleaseMutex() }
    $launchLock.Dispose()
}
