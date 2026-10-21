param([Parameter(Mandatory=$true)][string]$Node)
$ErrorActionPreference = 'Stop'
$fixture = Join-Path $env:TEMP ('p5-process-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-ThemeProcess.ps1') -Destination $fixture
foreach ($code in @(0,1,2)) {
    Set-Content -LiteralPath (Join-Path $fixture 'apply-theme.mjs') -Value ('console.log("output");console.error("fetch failed");process.exitCode=' + $code + ';')
    $result = & (Join-Path $fixture 'Invoke-ThemeProcess.ps1') -Node $Node -Port 1234
    if ($result.Code -ne $code -or !$result.Output.Contains('output') -or !$result.Error.Contains('fetch failed')) { throw 'Native stderr/exit handling failed' }
}
Write-Output 'PASS: stderr does not abort recovery; native exit codes 0, 1 and 2 preserved.'
