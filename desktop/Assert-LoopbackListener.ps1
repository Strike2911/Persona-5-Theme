param([Parameter(Mandatory=$true)][ValidateRange(1,65535)][int]$Port)
$ErrorActionPreference = 'Stop'
# Read the actual IPv4/IPv6 listener table through .NET/Win32, without CIM.
try {
    $listeners = @([System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | Where-Object { $_.Port -eq $Port })
} catch { throw ('No se pudo comprobar el puerto de WhatsApp: ' + $_.Exception.Message) }
if ($listeners.Count -eq 0) { throw 'No se encontro el puerto de depuracion de WhatsApp. Se abrira sin tema.' }
foreach ($endpoint in $listeners) {
    if (![System.Net.IPAddress]::IsLoopback($endpoint.Address)) {
        throw 'La conexion de depuracion no esta limitada al equipo. Se abrira WhatsApp sin tema.'
    }
}
