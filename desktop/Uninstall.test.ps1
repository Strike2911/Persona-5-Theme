$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('p5-uninstall-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Uninstall.ps1') -Raw
foreach ($case in @('installed','development','restore-fails')) {
    $local = Join-Path $testRoot $case
    $app = Join-Path $local 'Programs\WhatsAppPersona5'
    if ($case -eq 'development') { $app = Join-Path $local 'source-project' }
    $desktop = Join-Path $app 'desktop'
    New-Item -ItemType Directory -Path $desktop -Force | Out-Null
    if ($case -eq 'development') { New-Item -ItemType Directory -Path (Join-Path $app '.git') | Out-Null }
    $prelude = "`$env:LOCALAPPDATA = '" + $local.Replace("'","''") + "'`n" + @'
Add-Type 'public static class TestDialogs { public static string Show(string a,string b,string c,string d) { return "Yes"; } }'
'@
    $body = $source.Replace('Add-Type -AssemblyName System.Windows.Forms','').Replace('[System.Windows.Forms.MessageBox]','[TestDialogs]')
    Set-Content -LiteralPath (Join-Path $desktop 'Uninstall.ps1') -Value ($prelude + "`n" + $body)
    Set-Content -LiteralPath (Join-Path $desktop 'Set-Startup.ps1') -Value 'param([switch]$Disable)'
    Set-Content -LiteralPath (Join-Path $desktop 'Remove-ThemeShortcuts.ps1') -Value '# Test fixture: no actual user shortcuts.'
    $status = if ($case -eq 'restore-fails') { 1 } else { 0 }
    Set-Content -LiteralPath (Join-Path $desktop 'Start-WhatsApp.ps1') -Value ('exit ' + $status)
    Set-Content -LiteralPath (Join-Path $local 'whatsapp-data-sentinel.txt') -Value 'keep'
    $process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WorkingDirectory $desktop -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $desktop 'Uninstall.ps1') + '"') -Wait -PassThru
    if ($case -eq 'installed' -and ((Test-Path -LiteralPath $app) -or $process.ExitCode -ne 0)) { throw 'Uninstall from locked working directory failed' }
    if ($case -eq 'development' -and (!(Test-Path -LiteralPath (Join-Path $desktop 'Uninstall.ps1')) -or $process.ExitCode -ne 0)) { throw 'Development source not preserved' }
    if ($case -eq 'restore-fails' -and (!(Test-Path -LiteralPath $app) -or $process.ExitCode -ne 1)) { throw 'Failed restore did not preserve files' }
    if (!(Test-Path -LiteralPath (Join-Path $local 'whatsapp-data-sentinel.txt'))) { throw 'Unrelated data removed' }
    Write-Output ('PASS uninstall ' + $case)
}
