param([string]$OutputName="FuaPlayer.exe")
$ErrorActionPreference='Stop'
$shortcutSrc=Join-Path $PSScriptRoot 'FuaShortcuts.cs'
$settingsSrc=Join-Path $PSScriptRoot 'FuaSettings.cs'
$src=Join-Path $PSScriptRoot 'FuaNative.cs'
$out=Join-Path $PSScriptRoot $OutputName
$refs=@(('/reference:'+(Join-Path $PSScriptRoot 'NAudio.dll')),'/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',('/reference:'+(Join-Path $PSScriptRoot 'Microsoft.Web.WebView2.Core.dll')),('/reference:'+(Join-Path $PSScriptRoot 'Microsoft.Web.WebView2.WinForms.dll')))
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:winexe /platform:x64 ("/win32icon:"+(Join-Path $PSScriptRoot '..\fua-player-v2.ico')) @refs "/out:$out" $src $shortcutSrc $settingsSrc (Join-Path $PSScriptRoot "FuaHistory.cs") (Join-Path $PSScriptRoot "FuaDisplayColor.cs") (Join-Path $PSScriptRoot "FuaSystemVolume.cs") (Join-Path $PSScriptRoot "FuaCast.cs") (Join-Path $PSScriptRoot "FuaEpisodes.cs")
if($LASTEXITCODE -ne 0){throw 'Erro ao compilar'}



$thumbSrc=Join-Path $PSScriptRoot "FuaThumbnail.cs"
$thumbOut=Join-Path $PSScriptRoot "FuaThumbnail.exe"
& "C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe" /nologo /target:winexe /platform:x64 /main:FuaThumbnail /reference:System.Drawing.dll /reference:System.Web.Extensions.dll "/out:$thumbOut" $thumbSrc (Join-Path $PSScriptRoot "WindowsThumbnail.cs")
if($LASTEXITCODE -ne 0){throw "Erro ao compilar miniaturas"}

$artSrc=Join-Path $PSScriptRoot 'TitleArtwork.cs'
$artOut=Join-Path $PSScriptRoot 'TitleArtwork.exe'
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /reference:System.Drawing.dll /reference:System.Web.Extensions.dll "/out:$artOut" $artSrc
if($LASTEXITCODE -ne 0){throw 'Erro ao compilar logos dos títulos'}

$castSrc=Join-Path $PSScriptRoot 'CastArtwork.cs'
$castOut=Join-Path $PSScriptRoot 'CastArtwork.exe'
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /reference:System.Drawing.dll /reference:System.Web.Extensions.dll "/out:$castOut" $castSrc
if($LASTEXITCODE -ne 0){throw 'Erro ao compilar fotos do elenco'}

& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /platform:x64 /reference:System.Drawing.dll /reference:System.Web.Extensions.dll ("/out:"+(Join-Path $PSScriptRoot 'EpisodeArtwork.exe')) (Join-Path $PSScriptRoot 'EpisodeArtwork.cs')
if($LASTEXITCODE -ne 0){throw 'Erro ao compilar miniaturas dos episódios'}

& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /platform:x64 /reference:System.Drawing.dll ("/out:"+(Join-Path $PSScriptRoot 'WindowsThumbnail.exe')) (Join-Path $PSScriptRoot 'WindowsThumbnail.cs')
if($LASTEXITCODE -ne 0){throw 'Erro ao compilar miniaturas do Windows'}
