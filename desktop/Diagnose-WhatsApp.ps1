param([ValidateRange(2,30)][int]$Seconds = 5)
$ErrorActionPreference = 'Stop'
$all = Get-CimInstance Win32_Process
$ids = @($all | Where-Object Name -eq 'WhatsApp.Root.exe' | ForEach-Object ProcessId)
if (!$ids.Count) { throw 'Abre WhatsApp antes de medir.' }
do {
    $added = @($all | Where-Object { $_.ParentProcessId -in $ids -and $_.ProcessId -notin $ids } | ForEach-Object ProcessId)
    $ids += $added
} while ($added.Count)
$before = @{}
Get-Process -Id $ids -ErrorAction SilentlyContinue | ForEach-Object { $before[$_.Id] = $_.CPU }
$watch = [Diagnostics.Stopwatch]::StartNew()
Start-Sleep -Seconds $Seconds
$after = @(Get-Process -Id $ids -ErrorAction SilentlyContinue)
$elapsed = $watch.Elapsed.TotalSeconds
$cpu = 0
$after | ForEach-Object { if ($before.ContainsKey($_.Id)) { $cpu += $_.CPU - $before[$_.Id] } }
$os = Get-CimInstance Win32_OperatingSystem
[pscustomobject]@{
    Time = (Get-Date).ToString('s')
    SampleSeconds = [math]::Round($elapsed,2)
    Processes = $after.Count
    WorkingSetMB = [math]::Round(($after | Measure-Object WorkingSet64 -Sum).Sum / 1MB)
    PrivateMemoryMB = [math]::Round(($after | Measure-Object PrivateMemorySize64 -Sum).Sum / 1MB)
    CpuPercent = [math]::Round(100 * $cpu / $elapsed / [Environment]::ProcessorCount,2)
    SystemFreeMemoryMB = [math]::Round($os.FreePhysicalMemory / 1024)
    Note = 'Muestra puntual. La suma de WorkingSet puede contar memoria compartida varias veces. No mide fluidez ni demuestra la causa de un bloqueo.'
} | ConvertTo-Json
