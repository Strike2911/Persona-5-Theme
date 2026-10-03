$ErrorActionPreference = 'Stop'
# A broken CIM provider must never be consulted by the new check.
function Get-NetTCPConnection { throw 'Clase no valida (simulada)' }
function Check-Listener([System.Net.IPAddress]$Address, [bool]$Allowed) {
    $listener = [System.Net.Sockets.TcpListener]::new($Address, 0)
    try {
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $rejected = $false
        try { & "$PSScriptRoot\Assert-LoopbackListener.ps1" -Port $port } catch { $rejected = $true }
        if ($rejected -eq $Allowed) { throw ('Resultado inesperado: ' + $Address) }
        Write-Output ('PASS listener ' + $Address)
    } finally { $listener.Stop() }
    $rejected = $false
    try { & "$PSScriptRoot\Assert-LoopbackListener.ps1" -Port $port } catch { $rejected = $true }
    if (!$rejected) { throw 'Se acepto un puerto cerrado.' }
}
Check-Listener ([System.Net.IPAddress]::Loopback) $true
Check-Listener ([System.Net.IPAddress]::Any) $false
if ([System.Net.Sockets.Socket]::OSSupportsIPv6) {
    Check-Listener ([System.Net.IPAddress]::IPv6Loopback) $true
    Check-Listener ([System.Net.IPAddress]::IPv6Any) $false
}
Write-Output 'PASS: puertos cerrados rechazados; no depende de CIM.'
