param([string]$Version='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(!$Version){$Version=(Get-Content -Raw (Join-Path $root 'LITE_VERSION')).Trim()}
if($Version -notmatch '^\d+\.\d+\.\d+$'){throw 'Versão inválida'}
$app=Join-Path $root 'app'
$dist=Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist|Out-Null
& (Join-Path $PSScriptRoot 'build-lite.ps1')
$compiler='C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll ('/win32icon:'+(Join-Path $app 'fua-player-v2.ico')) ('/out:'+(Join-Path $app 'FuaPlayerLite.exe')) (Join-Path $root 'scripts/LiteLauncher.cs')
if($LASTEXITCODE -ne 0){throw 'Falha no inicializador Lite'}
& $compiler /nologo /target:exe /platform:x64 ('/out:'+(Join-Path $app 'fua-native\MediaProbe.exe')) (Join-Path $app 'fua-native\MediaProbe.cs')
if($LASTEXITCODE -ne 0){throw 'Falha no leitor de metadados'}
$files=@('FuaPlayerLite.exe','fua-player-v2.ico','fua-native/FuaPlayerLite.exe','fua-native/NAudio.dll','fua-native/MediaProbe.exe','fua-native/runtime/libmpv-2.dll','fua-native/runtime/MediaInfo.dll','fua-native/runtime/mpv.exe','fua-native/fua-ui.lua','fua-native/player-navigation.lua','fua-native/track-flags.lua','fua-native/track-policy.lua','fua-native/hdr-badge.lua','fua-native/thumbfast.lua','fua-native/fua-logo.bgra','fua-native/runtime-source.json','fua-native/thumbnail-runtime-source.json')
foreach($directory in @('fua-native/hdr-badges','fua-native/hdr-xp','fua-native/rtx-logos','fua-native/track-flags','fua-native/shaders','licenses')){
 Get-ChildItem -LiteralPath (Join-Path $app $directory) -File -Recurse|ForEach-Object{$files+=$_.FullName.Substring($app.Length+1).Replace('\','/')}
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$path=Join-Path $dist "FuaPlayerLite-Portable-$Version-Windows-x64.zip"
if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path}
$zip=[IO.Compression.ZipFile]::Open($path,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($name in ($files|Sort-Object -Unique)){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $app $name),$name,[IO.Compression.CompressionLevel]::Optimal)|Out-Null}
 $entry=$zip.CreateEntry('LEIA-ME.txt');$writer=New-Object IO.StreamWriter($entry.Open(),[Text.Encoding]::UTF8)
 try{$writer.Write("Fua Player Lite $Version`r`n`r`nExtraia toda a pasta e abra FuaPlayerLite.exe. Windows x64 com .NET Framework 4.8.`r`nAbra um vídeo com Ctrl+O, arraste para a tela inicial ou arraste sobre o executável.`r`nEsc fecha o vídeo e volta à tela inicial. Setas esquerda/direita avançam ou voltam 5 segundos.`r`nHDR XP: Shift+H. RTX HDR: H (requer GPU NVIDIA compatível). HDR XP inicia desligado.`r`nConfigurações e retomada ficam em data, dentro desta pasta, separadas da versão completa.`r`nMantém Anime4K, HDR XP, RTX HDR, áudio, legendas, prévias e capturas. Sem biblioteca, elenco, episódios, voz, Node ou WebView2.`r`nCódigo-fonte: https://github.com/danielfua/fua-player (arquivos e scripts Lite no projeto).`r`nConsulte licenses para os componentes de terceiros.`r`n")}finally{$writer.Dispose()}
}finally{$zip.Dispose()}
(Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($path)|Set-Content -Encoding ascii ($path+'.sha256')
Get-Item $path|Select-Object FullName,Length



