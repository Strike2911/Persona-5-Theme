$ErrorActionPreference = 'Stop'
$fixture = Join-Path $env:TEMP ('p5-launcher-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-WhatsApp.ps1') -Destination $fixture
    Set-Content -LiteralPath (Join-Path $fixture 'Stop-WhatsAppSession.ps1') -Value @'
$global:events.Add('stop')
'@
    Set-Content -LiteralPath (Join-Path $fixture 'Activate-WhatsApp.ps1') -Value @'
param([int]$Port)
$global:events.Add(('activate:' + ($Port -gt 0)))
'{"pid":1}'
'@
    Set-Content -LiteralPath (Join-Path $fixture 'Invoke-ThemeProcess.ps1') -Value @'
param($Node,$Port,[switch]$Lite,[switch]$Startup)
$global:events.Add('apply')
$global:applies++
$code = if ($global:scenario -eq 'timeout' -and $global:applies -eq 1) { 2 } else { 0 }
[pscustomobject]@{Code=$code;Output='';Error=''}
'@
    Set-Content -LiteralPath (Join-Path $fixture 'Assert-LoopbackListener.ps1') -Value @'
param($Port)
$global:events.Add('verify')
$global:checks++
if ($global:scenario -eq 'unsafe') { throw 'unsafe listener' }
if (($global:scenario -eq 'missingOnce' -and $global:checks -eq 1) -or $global:scenario -eq 'missingAlways') {
    $error = [InvalidOperationException]::new('listener disappeared')
    $error.Data['P5Retryable'] = $true
    throw $error
}
'@
    # Avoid using the real package, log directory, dialogs, updates or WhatsApp.
    function Get-AppxPackage { [pscustomobject]@{Version='test'} }
    function Add-Type { throw 'Expected launcher failure; suppress test dialog' }
    $savedLocalAppData = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = $fixture
    try {
        foreach ($case in @(
            @{Name='ready';Expected='stop,activate:True,apply,verify'},
            @{Name='missingOnce';Expected='stop,activate:True,apply,verify,stop,activate:True,apply,verify'},
            @{Name='timeout';Expected='stop,activate:True,apply,stop,activate:True,apply,verify'},
            @{Name='unsafe';Expected='stop,activate:True,apply,verify,stop,activate:False'},
            @{Name='missingAlways';Expected='stop,activate:True,apply,verify,stop,activate:True,apply,verify,stop,activate:False'}
        )) {
            $global:scenario=$case.Name; $global:applies=0; $global:checks=0
            $global:events=New-Object 'System.Collections.Generic.List[string]'
            try { & (Join-Path $fixture 'Start-WhatsApp.ps1') } catch {
                if ($_.Exception.Message -ne 'Expected launcher failure; suppress test dialog') { throw }
            }
            $actual=$global:events -join ','
            if ($actual -ne $case.Expected) { throw ($case.Name + ': ' + $actual) }
            Write-Output ('PASS launcher ' + $case.Name)
        }
    } finally { $env:LOCALAPPDATA=$savedLocalAppData }
} finally {
    # This generated fixture is always a direct child of the temp directory.
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($fixture)) -ne [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')) { throw 'Unsafe fixture cleanup path' }
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
