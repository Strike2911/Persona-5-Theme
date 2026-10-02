param([switch]$CheckOnly, [switch]$Silent, [ValidateSet('Keep','Enable','Disable')][string]$StartupMode='Keep')
$ErrorActionPreference = 'Stop'
$installStage = 'Verificar paquete'
$filesCopied = $false
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

Se guardara en tu carpeta local de programas y creara accesos en el menu Inicio y, si esta disponible, en el escritorio. Incluye Node.js; no necesitas instalarlo aparte. No incluye ni copia conversaciones o sesiones.

El acceso del tema reinicia WhatsApp y habilita depuracion SOLO en este equipo. Otros programas locales podrian acceder al contenido mientras esa sesion siga abierta. Cerrar la ventana puede dejar WhatsApp en la bandeja. Usa 'WhatsApp Persona 5 - Desinstalar' para quitar el tema y restaurar WhatsApp normal.

Adaptacion no oficial. Las actualizaciones de WhatsApp pueden requerir actualizar el tema.

Deseas instalarlo?
"@
    if (!$Silent -and [System.Windows.Forms.MessageBox]::Show($message,'WhatsApp Persona 5 - Instalador','YesNo','Information') -ne 'Yes') { exit 0 }
    $destination = Join-Path $env:LOCALAPPDATA 'Programs\WhatsAppPersona5'
    # Cerrar unicamente los componentes de la instalacion que se actualiza.
    $installedHelpers = @((Join-Path $destination 'desktop\NotificationPopup.exe'), (Join-Path $destination 'desktop\runtime\node.exe'))
    Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath -in $installedHelpers } | ForEach-Object {
        $running = Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
        if ($running -and $running.Path -in $installedHelpers) {
            Stop-Process -Id $running.Id -ErrorAction Stop
            $running.WaitForExit(5000) | Out-Null
        }
    }
    foreach ($entry in $manifest) {
        $target = Join-Path $destination $entry.path
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        # Windows puede tardar brevemente en liberar un ejecutable cerrado.
        for ($attempt = 0; $attempt -lt 10; $attempt++) {
            try {
                Copy-Item -LiteralPath (Join-Path $payload $entry.path) -Destination $target -Force
                break
            } catch [IO.IOException] {
                if ($attempt -eq 9) { throw }
                Start-Sleep -Milliseconds 300
            }
        }
    }
    $filesCopied = $true
    $pending = New-Object 'System.Collections.Generic.List[string]'
    $shortcutsFailed = $false
    $installStage = 'Crear accesos directos'
    try {
        & (Join-Path $destination 'desktop\Install-Shortcuts.ps1') 3>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.WarningRecord]) { $pending.Add($_.Message) }
        }
    } catch {
        $shortcutsFailed = $true
        $pending.Add(('Accesos directos: ' + $_.Exception.Message + ' HRESULT: ' + $_.Exception.HResult))
    }
    $installStage = 'Configurar inicio automatico'
    if ($shortcutsFailed -and $StartupMode -eq 'Enable') {
        $pending.Add('No se intento activar el inicio automatico porque fallo la creacion de accesos. No se cambiaron las protecciones.')
    } else {
        try {
            if ($StartupMode -eq 'Enable') { & (Join-Path $destination 'desktop\Set-Startup.ps1') | Out-Null }
            if ($StartupMode -eq 'Disable') { & (Join-Path $destination 'desktop\Set-Startup.ps1') -Disable | Out-Null }
        } catch { $pending.Add(('Inicio automatico: ' + $_.Exception.Message + ' HRESULT: ' + $_.Exception.HResult)) }
    }
    if ($pending.Count -gt 0) {
        $detail = 'Los archivos del tema se copiaron. Quedo pendiente:' + [Environment]::NewLine + ($pending -join [Environment]::NewLine)
        [Console]::Error.WriteLine($detail)
        if (!$Silent) { [System.Windows.Forms.MessageBox]::Show($detail,'Instalacion con pendientes','OK','Warning') | Out-Null }
        exit 2
    }
    if (!$Silent) { [System.Windows.Forms.MessageBox]::Show('Instalado. Abre WhatsApp Persona 5 desde el menu Inicio o el escritorio. Los otros accesos permiten buscar actualizaciones y desinstalar el tema conservando WhatsApp.','Instalacion completa','OK','Information') | Out-Null }
} catch {
    $failure = $_
    $report = @(
        ('Fecha local: ' + (Get-Date -Format o)),
        ('Paso: ' + $installStage),
        ('Archivos copiados: ' + $filesCopied),
        ('Tipo: ' + $failure.Exception.GetType().FullName),
        ('HRESULT: 0x{0:X8}' -f $failure.Exception.HResult),
        ('Mensaje: ' + $failure.Exception.Message),
        ('Detalle: ' + $failure.Exception.ToString()),
        ('Origen: ' + $failure.InvocationInfo.PositionMessage),
        ('Pila: ' + $failure.ScriptStackTrace)
    ) -join [Environment]::NewLine
    if ($filesCopied) { $report += [Environment]::NewLine + 'Los archivos se copiaron, pero la configuracion no termino. No se abrira el tema automaticamente.' }
    if ($CheckOnly -or $Silent) { [Console]::Error.WriteLine($report); exit 1 }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'No se pudo instalar','OK','Error') | Out-Null
    exit 1
}
