Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../../src/functions/tverrec-media-move.ps1')
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('tverrec-move-'+[guid]::NewGuid().ToString('N'))
foreach($dir in @('from/title','to/title','state')){[void][IO.Directory]::CreateDirectory((Join-Path $fixture $dir))}
$source=Join-Path $fixture 'from/title';$destination=Join-Path $fixture 'to/title';$state=Join-Path $fixture 'state'
foreach($pair in @(@('a.mp4','A','B'),@('b.mp4','SAME','SAME'),@('c.txt','TEXT',''))) {
    [IO.File]::WriteAllText((Join-Path $source $pair[0]),$pair[1])
    if($pair[2]){[IO.File]::WriteAllText((Join-Path $destination $pair[0]),$pair[2])}
}
function Compare-TVerRecMedia {
    param($SourcePath,$DestinationPath,$FfmpegPath,$FfprobePath,$WorkRoot)
    [pscustomobject]@{Equivalent=([IO.File]::ReadAllText($SourcePath) -eq [IO.File]::ReadAllText($DestinationPath));Reason='video difference';Mode='fixture'}
}
try {
    for($round=0;$round -lt 4;$round++){Move-TVerRecComparedFile -SourceDirectory $source -DestinationDirectory $destination -FfmpegPath '' -FfprobePath '' -StateRoot $state -WarningAction SilentlyContinue}
    if(-not [IO.File]::Exists((Join-Path $source 'a.mp4'))){throw 'Different source removed'}
    if([IO.File]::Exists((Join-Path $source 'b.mp4'))){throw 'First unequal collision starved later matching file'}
    if([IO.File]::ReadAllText((Join-Path $destination 'b.mp4')) -ne 'SAME'){throw 'Matching destination changed'}
    if([IO.File]::ReadAllText((Join-Path $destination 'c.txt')) -ne 'TEXT'){throw 'Normal file move failed'}
    'PASS compared move: round-robin collisions and ordinary no-overwrite move'
} finally {Remove-Item -LiteralPath $fixture -Recurse -Force}
