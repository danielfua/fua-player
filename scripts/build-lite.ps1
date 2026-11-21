param([string]$OutputName='FuaPlayerLite.exe')
$ErrorActionPreference='Stop'
$native=Join-Path $PSScriptRoot '../app/fua-native'
$compiler='C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$sources=@('FuaNative.cs','FuaSettings.cs','FuaShortcuts.cs','FuaHistory.cs','FuaDisplayColor.cs','FuaSystemVolume.cs','FuaCast.cs','FuaLite.cs') | ForEach-Object {Join-Path $native $_}
$refs=@('/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',('/reference:'+(Join-Path $native 'NAudio.dll')))
& $compiler /nologo /target:winexe /platform:x64 /define:FUA_LITE ('/win32icon:'+(Join-Path $native '../fua-player-v2.ico')) @refs ('/out:'+(Join-Path $native $OutputName)) @sources
if($LASTEXITCODE -ne 0){throw 'Falha ao compilar o Fua Player Lite'}
