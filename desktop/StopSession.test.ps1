param([Parameter(Mandatory=$true)][string]$Node)
$ErrorActionPreference = 'Stop'
$selected = Start-Process -FilePath $Node -WindowStyle Hidden -ArgumentList '-e "setTimeout(()=>{},60000)"' -PassThru
$unrelated = Start-Process -FilePath $Node -WindowStyle Hidden -ArgumentList '-e "setTimeout(()=>{},60000)"' -PassThru
try {
    # Exercise real Windows process handles without closing the user's app.
    $testHost = [Diagnostics.Process]::GetProcessById($selected.Id)
    [void]$testHost.Handle
    function Get-Process { $testHost }
    & (Join-Path $PSScriptRoot 'Stop-WhatsAppSession.ps1')
    if (!$selected.HasExited) { throw 'The selected host was not stopped.' }
    if ($unrelated.HasExited) { throw 'An unrelated process was stopped.' }
    # Already-exited hosts must not turn a normal close into a launch failure.
    $selected.Dispose()
    $selected = Start-Process -FilePath $Node -WindowStyle Hidden -ArgumentList '-e "setTimeout(()=>{},500)"' -PassThru
    $testHost = [Diagnostics.Process]::GetProcessById($selected.Id)
    [void]$testHost.Handle
    $selected.WaitForExit()
    & (Join-Path $PSScriptRoot 'Stop-WhatsAppSession.ps1')
    function Get-Process { }
    & (Join-Path $PSScriptRoot 'Stop-WhatsAppSession.ps1')
    Write-Output 'PASS: selected host exits before activation; unrelated processes and already-exited hosts handled.'
} finally {
    foreach ($testProcess in @($selected,$unrelated)) {
        if (!$testProcess.HasExited) { $testProcess.Kill(); $testProcess.WaitForExit() }
        $testProcess.Dispose()
    }
}
