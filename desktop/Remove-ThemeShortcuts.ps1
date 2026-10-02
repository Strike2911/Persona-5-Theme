param([string[]]$Names = @('WhatsApp Persona 5','WhatsApp Persona 5 - Ligero','WhatsApp - Restaurar normal','WhatsApp Persona 5 - Buscar actualizaciones','WhatsApp Persona 5 - Desinstalar'))
$ErrorActionPreference = 'Stop'
$directories = @([Environment]::GetFolderPath('DesktopDirectory'))
$programs = [Environment]::GetFolderPath('Programs')
if ($programs) { $directories += Join-Path $programs 'WhatsApp Persona 5' }
$shell = New-Object -ComObject WScript.Shell
try {
    foreach ($directory in $directories) {
        if (!$directory) { continue }
        foreach ($name in $Names) {
            $path = Join-Path $directory ($name + '.lnk')
            if (!(Test-Path -LiteralPath $path)) { continue }
            $link = $shell.CreateShortcut($path)
            try {
                # Only remove shortcuts pointing into this installation.
                if ($link.Arguments.IndexOf(('"' + $PSScriptRoot + '\'), [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    Remove-Item -LiteralPath $path -Force
                }
            } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($link) }
        }
    }
} finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
