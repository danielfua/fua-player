$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$app=Join-Path $root 'app'
$cache=Join-Path $root '.deps'
New-Item -ItemType Directory -Force $cache,(Join-Path $app 'fua-native/runtime'),(Join-Path $app 'licenses')|Out-Null
$lock=Get-Content -Raw (Join-Path $root 'dependencies.lock.json')|ConvertFrom-Json
foreach($dependency in $lock){$archive=Join-Path $cache $dependency.file;if(!(Test-Path -LiteralPath $archive)){Invoke-WebRequest -Uri $dependency.url -OutFile $archive};$digest=(Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant();if($digest -ne $dependency.sha256){throw "SHA-256 inválido: $($dependency.id)"};$destination=Join-Path $cache $dependency.id;New-Item -ItemType Directory -Force $destination|Out-Null;& tar.exe -xf $archive -C $destination;if($LASTEXITCODE -ne 0){throw "Falha ao extrair $($dependency.id)"}}
Copy-Item -LiteralPath (Join-Path $cache 'node/node-v24.22.1-win-x64/node.exe') -Destination (Join-Path $app 'node.exe') -Force
Copy-Item -LiteralPath (Join-Path $cache 'mpv/libmpv-2.dll') -Destination (Join-Path $app 'fua-native/runtime/libmpv-2.dll') -Force
$media=Get-ChildItem -LiteralPath (Join-Path $cache 'mediainfo') -Filter MediaInfo.dll -Recurse|Select-Object -First 1
if(!$media){throw 'MediaInfo.dll não encontrada no pacote'}
Copy-Item -LiteralPath $media.FullName -Destination (Join-Path $app 'fua-native/runtime/MediaInfo.dll') -Force
foreach($name in @('Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll')){Copy-Item -LiteralPath (Join-Path $cache ('webview/lib/net462/'+$name)) -Destination (Join-Path $app ('fua-native/'+$name)) -Force}
Copy-Item -LiteralPath (Join-Path $cache 'webview/runtimes/win-x64/native/WebView2Loader.dll') -Destination (Join-Path $app 'fua-native/WebView2Loader.dll') -Force
Copy-Item (Join-Path $root 'licenses/*') (Join-Path $app 'licenses') -Force
Write-Output 'Dependências verificadas e prontas.'
