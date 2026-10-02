$ErrorActionPreference = 'Stop'
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
    & (Join-Path $PSScriptRoot 'Set-Startup.ps1') -Disable | Out-Null
    $helpers = @((Join-Path $PSScriptRoot 'NotificationPopup.exe'), (Join-Path $PSScriptRoot 'runtime\node.exe'))
    Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath -in $helpers } | ForEach-Object {
        $process = Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
        if ($process -and $process.Path -in $helpers) { Stop-Process -Id $process.Id; $process.WaitForExit(5000) | Out-Null }
    }
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $process = Start-Process -FilePath $powershell -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $PSScriptRoot 'Start-WhatsApp.ps1') + '" -Normal') -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'No se pudo restaurar WhatsApp normal. Los archivos se conservaron para volver a intentarlo.' }
    & (Join-Path $PSScriptRoot 'Remove-ThemeShortcuts.ps1')
    Set-Location -LiteralPath $env:TEMP
    if ($isInstalled) { Remove-Item -LiteralPath $root -Recurse -Force }
    [System.Windows.Forms.MessageBox]::Show('Tema desinstalado. WhatsApp y tus conversaciones se conservaron.','WhatsApp Persona 5','OK','Information') | Out-Null
} catch {
    [System.Windows.Forms.MessageBox]::Show(('La desinstalacion no termino: ' + $_.Exception.Message + "`nPuedes volver a ejecutarla. No se eliminaron datos de WhatsApp."),'No se pudo completar','OK','Warning') | Out-Null
    exit 1
}
