$ErrorActionPreference = 'Stop'
$env:PSModulePath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules'
Add-Type -AssemblyName System.Windows.Forms
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
    $expected = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\WhatsAppPersona5')).TrimEnd('\')
    $isInstalled = $root -eq $expected
    $isDevelopment = Test-Path -LiteralPath (Join-Path $root '.git')
    if (!$isInstalled -and !$isDevelopment) { throw 'No se reconoce esta ubicacion del tema. No se eliminaran archivos.' }
    # Do not traverse redirected directories when deleting installation files.
    if ($isInstalled) { foreach ($item in @((Get-Item -LiteralPath $root)) + @(Get-ChildItem -LiteralPath $root -Recurse -Force)) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'La instalacion contiene un enlace de archivos. No se eliminara automaticamente.' }
    } }
    $message = 'Se quitara el tema, sus accesos y su inicio automatico. WhatsApp se reiniciara sin el tema. Tus conversaciones y WhatsApp se conservaran.'
    if ($isDevelopment) { $message += "`n`nEsta es una copia de desarrollo: se conservara la carpeta del proyecto." }
    if ([System.Windows.Forms.MessageBox]::Show($message,'Desinstalar WhatsApp Persona 5','YesNo','Question') -ne 'Yes') { return }
    # Set-Location alone does not change the native process working directory.
    # Our shortcut starts inside desktop; Windows then locks that directory.
    Set-Location -LiteralPath $env:TEMP
    [Environment]::CurrentDirectory = [IO.Path]::GetFullPath($env:TEMP)
    & (Join-Path $PSScriptRoot 'Set-Startup.ps1') -Disable | Out-Null
    $helpers = @((Join-Path $PSScriptRoot 'NotificationPopup.exe'), (Join-Path $PSScriptRoot 'runtime\node.exe'))
    Get-Process -Name 'NotificationPopup','node' -ErrorAction SilentlyContinue | ForEach-Object {
        $process = $_
        if ($process -and $process.Path -in $helpers) { Stop-Process -Id $process.Id; $process.WaitForExit(5000) | Out-Null }
    }
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $process = Start-Process -FilePath $powershell -WorkingDirectory $env:TEMP -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $PSScriptRoot 'Start-WhatsApp.ps1') + '" -Normal') -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'No se pudo restaurar WhatsApp normal. Los archivos se conservaron para volver a intentarlo.' }
    & (Join-Path $PSScriptRoot 'Remove-ThemeShortcuts.ps1')
    Set-Location -LiteralPath $env:TEMP
    if ($isInstalled) {
        for ($attempt = 0; $attempt -lt 10; $attempt++) {
            try {
                if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
                break
            } catch [IO.IOException] {
                if ($attempt -eq 9) { throw }
                Start-Sleep -Milliseconds 300
            }
        }
    }
    [System.Windows.Forms.MessageBox]::Show('Tema desinstalado. WhatsApp y tus conversaciones se conservaron.','WhatsApp Persona 5','OK','Information') | Out-Null
} catch {
    $reason = $_.Exception.Message
    $report = Join-Path $env:LOCALAPPDATA 'WhatsAppPersona5\uninstall-error.log'
    try { New-Item -ItemType Directory -Path (Split-Path $report) -Force | Out-Null; Set-Content -LiteralPath $report -Value ((Get-Date -Format o) + "`n" + ($_ | Out-String)) } catch { }
    [System.Windows.Forms.MessageBox]::Show(('La desinstalacion no termino: ' + $reason + "`nNo se eliminaron datos de WhatsApp. Registro: " + $report),'No se pudo completar','OK','Warning') | Out-Null
    exit 1
}
