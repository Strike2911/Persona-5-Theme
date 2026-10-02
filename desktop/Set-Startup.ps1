param([switch]$Disable, [string]$StartupFolder = [Environment]::GetFolderPath('Startup'))
$ErrorActionPreference = 'Stop'
if (!$startupFolder) {
    if ($Disable) { Write-Output 'Windows no proporciona carpeta de inicio automatico; no se realizaron cambios.'; return }
    throw 'Windows no proporciona la carpeta de inicio automatico. El tema no se configurara para arrancar con Windows.'
}
$shortcutPath = Join-Path $startupFolder 'WhatsApp Persona 5.lnk'
if ($Disable) {
    if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath }
    Write-Output 'Inicio automatico de Persona 5 desactivado.'
    return
}
New-Item -ItemType Directory -Path $startupFolder -Force | Out-Null
$shell = New-Object -ComObject WScript.Shell
try {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $PSScriptRoot 'Start-WhatsApp.ps1') + '" -Startup'
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = 'Abre WhatsApp con Persona 5 al iniciar sesion en Windows'
    $shortcut.IconLocation = (Join-Path $PSScriptRoot 'assets\persona.ico') + ',0'
    $shortcut.WindowStyle = 7
    $shortcut.Save()
    Write-Output $shortcutPath
} finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
