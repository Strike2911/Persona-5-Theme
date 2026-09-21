$ErrorActionPreference = 'Stop'
$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$package = Get-AppxPackage 5319275A.WhatsAppDesktop
foreach ($entry in @(
    @{Name='WhatsApp Persona 5';Args='';Description='WhatsApp oficial con tema Persona 5 y efectos breves'},
    @{Name='WhatsApp Persona 5 - Ligero';Args=' -Lite';Description='WhatsApp oficial con tema Persona 5 sin transiciones'},
    @{Name='WhatsApp - Restaurar normal';Args=' -Normal';Description='Reinicia WhatsApp sin tema ni depuracion local'},
    @{Name='WhatsApp Persona 5 - Buscar actualizaciones';Args=' -Force';Script='Update-WhatsApp.ps1';Description='Busca nuevas versiones del tema en GitHub'}
)) {
    $shortcut = $shell.CreateShortcut((Join-Path $desktop ($entry.Name + '.lnk')))
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $scriptName = if ($entry.Script) { $entry.Script } else { 'Start-WhatsApp.ps1' }
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $PSScriptRoot $scriptName) + '"' + $entry.Args
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = $entry.Description
    if ($package) { $shortcut.IconLocation = (Join-Path $package.InstallLocation 'WhatsApp.Root.exe') + ',0' }
    $shortcut.Save()
    Write-Output (Join-Path $desktop ($entry.Name + '.lnk'))
}
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
