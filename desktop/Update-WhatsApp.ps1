param([switch]$Force)
$ErrorActionPreference = 'Stop'
$lock = [System.Threading.Mutex]::new($false,'Local\WhatsAppPersona5Updates')
if (!$lock.WaitOne(0)) { $lock.Dispose(); exit }
try {
    $stateDir = Join-Path $env:LOCALAPPDATA 'WhatsAppPersona5'
    $stamp = Join-Path $stateDir 'last-update-check.txt'
    if (!$Force -and (Test-Path -LiteralPath $stamp)) {
        try { $last = [datetime]::Parse((Get-Content -LiteralPath $stamp -Raw)).ToUniversalTime() } catch { $last = [datetime]::MinValue }
        if (($last -le [datetime]::UtcNow) -and (([datetime]::UtcNow - $last).TotalHours -lt 24)) { exit }
    }
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    [datetime]::UtcNow.ToString('o') | Set-Content -LiteralPath $stamp
    $node = Join-Path $PSScriptRoot 'runtime\node.exe'
    if (!(Test-Path -LiteralPath $node)) { $node = (Get-Command node.exe -ErrorAction Stop).Source }
    $resultText = & $node (Join-Path $PSScriptRoot 'updater.mjs') 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar GitHub. Comprueba tu conexion e intenta de nuevo.' }
    $release = $resultText | ConvertFrom-Json
    Add-Type -AssemblyName System.Windows.Forms
    if (!$release.available) {
        if ($Force) { [System.Windows.Forms.MessageBox]::Show('Ya tienes la version mas reciente.','Persona 5 - Actualizaciones') | Out-Null }
        exit
    }
    $choice = [System.Windows.Forms.MessageBox]::Show(('Hay una nueva version del tema: ' + $release.version + ".`n`nQuieres abrir su pagina en GitHub para ver los cambios y descargar el instalador?"),'Actualizacion disponible','YesNo','Information')
    if ($choice -eq 'Yes') { Start-Process -FilePath $release.url }
} catch {
    if ($Force) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Actualizaciones','OK','Information') | Out-Null
    }
} finally { $lock.ReleaseMutex(); $lock.Dispose() }
