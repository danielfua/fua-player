param([string]$Version='1.0.0')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$app=Join-Path $root 'app'
$dist=Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
& (Join-Path $app 'fua-native/build.ps1')
$compiler='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$probeSource=Join-Path $app 'fua-native/MediaProbe.cs'
$probeOutput=Join-Path $app 'fua-native/MediaProbe.exe'
& $compiler /nologo /target:exe /platform:x64 "/out:$probeOutput" $probeSource
if($LASTEXITCODE -ne 0){throw 'Falha ao compilar o leitor de metadados'}
$launcherSource=Join-Path $PSScriptRoot 'Launcher.cs'
$launcherOutput=Join-Path $app 'FuaPlayer.exe'
$icon=Join-Path $app 'fua-player-v2.ico'
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll "/win32icon:$icon" "/out:$launcherOutput" $launcherSource
if($LASTEXITCODE -ne 0){throw 'Falha ao compilar o inicializador'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$payload=Join-Path $dist 'fua-payload.zip'
if(Test-Path -LiteralPath $payload){Remove-Item -LiteralPath $payload}
$files=@('FuaPlayer.exe','node.exe','library.html','library.css','library.js','library-meta.cjs','library-enrich.cjs','app-config.cjs','backup.cjs','media.cjs','native-server.cjs','native-launcher.cjs','fua-player-v2.ico','free-my-tv-rounded.ico','fua-native/FuaPlayer.exe','fua-native/FuaNative.cs','fua-native/FuaShortcuts.cs','fua-native/FuaSettings.cs','fua-native/MediaProbe.cs','fua-native/MediaProbe.exe','fua-native/bridge.cjs','fua-native/runtime-source.json','fua-native/fua-ui.lua','fua-native/track-policy.lua','fua-native/fua-logo.bgra','fua-native/Microsoft.Web.WebView2.Core.dll','fua-native/Microsoft.Web.WebView2.WinForms.dll','fua-native/WebView2Loader.dll','fua-native/runtime/libmpv-2.dll','fua-native/runtime/MediaInfo.dll','licenses/THIRD-PARTY.md','licenses/mpv-Copyright.txt','licenses/mpv-GPL.txt','licenses/MediaInfo.html','licenses/WebView2.txt','licenses/Node.txt','licenses/GPL-3.0.txt','licenses/FreeMyTV-MIT.txt')
$zip=[IO.Compression.ZipFile]::Open($payload,[IO.Compression.ZipArchiveMode]::Create)
try{foreach($name in $files){$source=Join-Path $app $name;if(!(Test-Path -LiteralPath $source)){throw "Dependência ausente: $name"};[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$source,$name,[IO.Compression.CompressionLevel]::Optimal)|Out-Null}}finally{$zip.Dispose()}
$setupSource=Join-Path $PSScriptRoot 'Setup.cs'
$setupOutput=Join-Path $dist "FuaPlayer-Setup-$Version.exe"
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:Microsoft.CSharp.dll "/win32icon:$icon" "/resource:$payload,fua-payload.zip" "/out:$setupOutput" $setupSource
if($LASTEXITCODE -ne 0){throw 'Falha ao compilar o instalador'}
Get-FileHash -Algorithm SHA256 -LiteralPath $setupOutput | Format-List
