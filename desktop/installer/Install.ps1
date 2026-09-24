param([switch]$CheckOnly, [switch]$Silent, [ValidateSet('Keep','Enable','Disable')][string]$StartupMode='Keep')
$ErrorActionPreference = 'Stop'
try {
    $payload = Join-Path $PSScriptRoot 'payload'
    $manifest = Get-Content (Join-Path $PSScriptRoot 'files.json') -Raw | ConvertFrom-Json
    $payloadRoot = [IO.Path]::GetFullPath($payload) + [IO.Path]::DirectorySeparatorChar
    foreach ($entry in $manifest) {
        $file = [IO.Path]::GetFullPath((Join-Path $payload $entry.path))
        if (!$file.StartsWith($payloadRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta de paquete no valida.' }
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256) { throw ('Archivo incompleto o modificado: ' + $entry.path) }
    }
    if ($CheckOnly) { Write-Output ('Paquete verificado: ' + $manifest.Count + ' archivos.'); exit 0 }
    Add-Type -AssemblyName System.Windows.Forms
    if (![Environment]::Is64BitOperatingSystem) { throw 'Este paquete requiere Windows de 64 bits.' }
    if (!(Get-AppxPackage 5319275A.WhatsAppDesktop)) { throw 'Instala primero WhatsApp oficial desde Microsoft Store e inicia sesion.' }
    $message = @"
Instalar el tema Persona 5 para WhatsApp oficial.

Se guardara en tu carpeta local de programas y creara tres accesos directos. Incluye Node.js; no necesitas instalarlo aparte. No incluye ni copia conversaciones o sesiones.

El acceso del tema reinicia WhatsApp y habilita depuracion SOLO en este equipo. Otros programas locales podrian acceder al contenido mientras esa sesion siga abierta. Cerrar la ventana puede dejar WhatsApp en la bandeja. Usa 'WhatsApp - Restaurar normal' para cerrar esa sesion y desactivar la depuracion.

Adaptacion no oficial. Las actualizaciones de WhatsApp pueden requerir actualizar el tema.

Deseas instalarlo?
"@
    if (!$Silent -and [System.Windows.Forms.MessageBox]::Show($message,'WhatsApp Persona 5 - Instalador','YesNo','Information') -ne 'Yes') { exit 0 }
    $destination = Join-Path $env:LOCALAPPDATA 'Programs\WhatsAppPersona5'
    foreach ($entry in $manifest) {
        $target = Join-Path $destination $entry.path
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $payload $entry.path) -Destination $target -Force
    }
    & (Join-Path $destination 'desktop\Install-Shortcuts.ps1') | Out-Null
    if ($StartupMode -eq 'Enable') { & (Join-Path $destination 'desktop\Set-Startup.ps1') | Out-Null }
    if ($StartupMode -eq 'Disable') { & (Join-Path $destination 'desktop\Set-Startup.ps1') -Disable | Out-Null }
    if (!$Silent) { [System.Windows.Forms.MessageBox]::Show('Instalado. Abre WhatsApp Persona 5 desde el escritorio. El modo Ligero desactiva animaciones. Para volver a WhatsApp sin depuracion, usa Restaurar normal.','Instalacion completa','OK','Information') | Out-Null }
} catch {
    if ($CheckOnly -or $Silent) { Write-Error $_; exit 1 }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'No se pudo instalar','OK','Error') | Out-Null
    exit 1
}
