param([Parameter(Mandatory=$true)][string]$Node, [Parameter(Mandatory=$true)][int]$Port, [switch]$Lite, [switch]$Startup)
$ErrorActionPreference = 'Stop'
$info = New-Object System.Diagnostics.ProcessStartInfo
$info.FileName = $Node
$info.Arguments = '"' + (Join-Path $PSScriptRoot 'apply-theme.mjs') + '" ' + $Port
if ($Lite) { $info.Arguments += ' --lite' }
if ($Startup) { $info.Arguments += ' --startup' }
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$process = [Diagnostics.Process]::Start($info)
try {
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit(130000)) {
        $process.Kill()
        throw 'El proceso del tema excedio el tiempo de espera.'
    }
    [pscustomobject]@{ Code=$process.ExitCode; Output=$stdout.Result; Error=$stderr.Result }
} finally { $process.Dispose() }
