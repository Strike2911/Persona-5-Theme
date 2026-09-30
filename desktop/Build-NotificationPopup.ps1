param([string]$OutputPath=(Join-Path $PSScriptRoot 'NotificationPopup.exe'))
$ErrorActionPreference='Stop'
$framework=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319'
& "$framework\csc.exe" /nologo /target:exe /platform:x64 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll "/reference:$framework\WPF\PresentationCore.dll" "/reference:$framework\WPF\WindowsBase.dll" "/out:$OutputPath" "$PSScriptRoot\NotificationPopup.cs"
if($LASTEXITCODE -ne 0){throw 'No se pudo compilar el aviso Persona 5.'}
