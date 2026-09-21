param([Parameter(Mandatory=$true)][string]$NodePath, [string]$OutputDirectory)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (!$OutputDirectory) { $OutputDirectory=Join-Path $repoRoot 'dist' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stage=Join-Path $OutputDirectory ('build-'+[guid]::NewGuid().ToString('N'))
$payload=Join-Path $stage 'payload'
New-Item -ItemType Directory -Path "$payload\desktop\runtime","$payload\desktop\assets","$payload\desktop\installer","$payload\icons" -Force | Out-Null
$expectedHash='C6335D08331C23D68B9F2B18ADB102002D76EF150B47248E954C507E0D033664'
if ((Get-FileHash -LiteralPath $NodePath -Algorithm SHA256).Hash -ne $expectedHash) { throw 'El runtime no coincide con Node.js oficial 24.17.0 x64.' }
Copy-Item -LiteralPath $NodePath -Destination "$payload\desktop\runtime\node.exe"
Copy-Item -LiteralPath "$repoRoot\desktop\assets\NODE-LICENSE.txt" -Destination "$payload\desktop\runtime\LICENSE.txt"
Get-ChildItem "$repoRoot\desktop" -File | Where-Object { $_.Extension -in '.ps1','.mjs','.css','.json','.md' } | Copy-Item -Destination "$payload\desktop"
foreach($name in @('city-mono.jpg','wordmark.svg','sidebar-city.svg','comic-edge.svg','chat-badge.svg')) { Copy-Item -LiteralPath "$repoRoot\desktop\assets\$name" -Destination "$payload\desktop\assets\$name" }
foreach($name in @('img.svg','img2.svg','imgBGW.svg')) { Copy-Item -LiteralPath "$repoRoot\icons\$name" -Destination "$payload\icons\$name" }
Copy-Item -Path "$PSScriptRoot\*.ps1","$PSScriptRoot\*.cs" -Destination "$payload\desktop\installer"
Copy-Item -LiteralPath "$repoRoot\LICENSE" -Destination "$payload\LICENSE"
Copy-Item -LiteralPath "$PSScriptRoot\Install.ps1" -Destination "$stage\Install.ps1"
$manifest=@(Get-ChildItem $payload -Recurse -File | ForEach-Object { @{path=$_.FullName.Substring($payload.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
ConvertTo-Json -InputObject $manifest | Set-Content -Encoding UTF8 "$stage\files.json"
& "$payload\desktop\runtime\node.exe" --test "$payload\desktop\theme.test.mjs" "$payload\desktop\updater.test.mjs"
if($LASTEXITCODE -ne 0){throw 'Pruebas fallidas.'}
Get-ChildItem $payload -Filter *.ps1 -Recurse | ForEach-Object { $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors);if($errors){throw ($errors|Out-String)} }
$zip=Join-Path $stage 'package.zip'
Compress-Archive -Path "$stage\payload","$stage\files.json","$stage\Install.ps1" -DestinationPath $zip
$exe=Join-Path $OutputDirectory 'WhatsApp-Persona5-Instalar.exe'
& "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /platform:x64 /target:winexe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/resource:$zip,package.zip" "/out:$exe" "$PSScriptRoot\Setup.cs"
if($LASTEXITCODE -ne 0){throw 'Compilacion fallida.'}
$p=Start-Process -FilePath $exe -ArgumentList '--verify' -WindowStyle Hidden -Wait -PassThru
if($p.ExitCode -ne 0){throw 'El instalador no paso la verificacion interna.'}
((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()+'  WhatsApp-Persona5-Instalar.exe') | Set-Content -Encoding ascii ($exe+'.sha256')
Write-Output $exe
