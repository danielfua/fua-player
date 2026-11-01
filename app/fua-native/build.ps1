param([string]$OutputName="FuaPlayer.exe")
$ErrorActionPreference='Stop'
$shortcutSrc=Join-Path $PSScriptRoot 'FuaShortcuts.cs'
$settingsSrc=Join-Path $PSScriptRoot 'FuaSettings.cs'
$src=Join-Path $PSScriptRoot 'FuaNative.cs'
$out=Join-Path $PSScriptRoot $OutputName
$refs=@('/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',('/reference:'+(Join-Path $PSScriptRoot 'Microsoft.Web.WebView2.Core.dll')),('/reference:'+(Join-Path $PSScriptRoot 'Microsoft.Web.WebView2.WinForms.dll')))
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:winexe /platform:x64 @refs "/out:$out" $src $shortcutSrc $settingsSrc
if($LASTEXITCODE -ne 0){throw 'Erro ao compilar'}


