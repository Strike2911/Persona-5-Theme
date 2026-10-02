param([switch]$Force)
$ErrorActionPreference = 'Stop'
$lock = [System.Threading.Mutex]::new($false,'Local\WhatsAppPersona5Updates')
if (!$lock.WaitOne(0)) { $lock.Dispose(); exit }
$attempted = $false
$downloadDir = $null
$stateDir = Join-Path $env:LOCALAPPDATA 'WhatsAppPersona5'
try {
    Add-Type -AssemblyName System.Windows.Forms
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot '..\.git')) {
        if ($Force) { [System.Windows.Forms.MessageBox]::Show('Esta es la copia de desarrollo. Usa Buscar actualizaciones del menu Inicio, que apunta a la instalacion.','Persona 5 - Desarrollo') | Out-Null }
        return
    }
    $stamp = Join-Path $stateDir 'last-update-check.txt'
    if (!$Force -and (Test-Path -LiteralPath $stamp)) {
        try { $last = [datetime]::Parse((Get-Content -LiteralPath $stamp -Raw)).ToUniversalTime() } catch { $last = [datetime]::MinValue }
        if (($last -le [datetime]::UtcNow) -and (([datetime]::UtcNow - $last).TotalHours -lt 24)) { return }
    }
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    $node = Join-Path $PSScriptRoot 'runtime\node.exe'
    $resultText = & $node (Join-Path $PSScriptRoot 'updater.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar GitHub. Intenta de nuevo mas tarde.' }
    $release = $resultText | ConvertFrom-Json
    [datetime]::UtcNow.ToString('o') | Set-Content -LiteralPath $stamp
    if (!$release.available) {
        if ($Force) { [System.Windows.Forms.MessageBox]::Show('Ya tienes la version mas reciente.','Persona 5 - Actualizaciones') | Out-Null }
        return
    }
    $attempted = $true
    $downloadDir = Join-Path $stateDir ('updates\' + [guid]::NewGuid().ToString('N'))
    # Check again while downloading; never execute an unverified or incomplete file.
    $resultText = & $node (Join-Path $PSScriptRoot 'updater.mjs') --download $downloadDir
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar y verificar la actualizacion. No se ejecuto el instalador.' }
    $release = $resultText | ConvertFrom-Json
    if (!$release.available) { return }
    $installer = Join-Path $downloadDir 'WhatsApp-Persona5-Instalar.exe'
    if ($release.installer -ne $installer) { throw 'Ruta de actualizacion inesperada.' }
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $release.sha256) { throw 'La huella del instalador cambio. No se ejecutara.' }
    $process = Start-Process -FilePath $installer -ArgumentList '--update' -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw ('La actualizacion no termino (codigo ' + $process.ExitCode + '). Revisa ' + (Join-Path $stateDir 'install-error.log')) }
    $installed = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'version.json') -Raw | ConvertFrom-Json).version
    if ($installed -ne $release.version) { throw 'No se pudo confirmar la nueva version instalada.' }
    # Restart only when WhatsApp was open, to restore the notification helper.
    if (Get-Process WhatsApp.Root -ErrorAction SilentlyContinue) {
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $PSScriptRoot 'Start-WhatsApp.ps1') + '"')
    }
    [System.Windows.Forms.MessageBox]::Show(('WhatsApp Persona 5 se actualizo a la version ' + $installed + '.'),'Actualizacion instalada') | Out-Null
} catch {
    $message = $_.Exception.Message
    try { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null; Add-Content -LiteralPath (Join-Path $stateDir 'update-error.log') -Value ((Get-Date -Format o) + ' ' + $message) } catch { }
    if ($Force -or $attempted) { [System.Windows.Forms.MessageBox]::Show(($message + "`nNo se modificaron las protecciones de Windows."),'No se pudo actualizar') | Out-Null }
} finally {
    if ($downloadDir -and (Test-Path -LiteralPath $downloadDir)) {
        # Only our known download files; no recursive removal.
        foreach ($name in @('WhatsApp-Persona5-Instalar.exe','WhatsApp-Persona5-Instalar.exe.part')) {
            try { Remove-Item -LiteralPath (Join-Path $downloadDir $name) -Force -ErrorAction SilentlyContinue } catch { }
        }
        try { [IO.Directory]::Delete($downloadDir) } catch { }
    }
    $lock.ReleaseMutex(); $lock.Dispose()
}
