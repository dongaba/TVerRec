Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../../src/functions/tverrec-media-compare.ps1')
$ffmpeg=(Get-Command ffmpeg).Source;$ffprobe=(Get-Command ffprobe).Source
$root=Join-Path ([IO.Path]::GetTempPath()) ('tverrec-compare-test-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $root
function Make([string]$name,[string]$video,[string]$audio,[string]$duration='30') {
 $path=Join-Path $root ($name+'.mp4')
 $r=[TVerRec.MediaComparison]::Run($ffmpeg,@('-v','error','-nostdin','-y','-f','lavfi','-i',$video,'-f','lavfi','-i',$audio,'-t',$duration,'-c:v','libx264','-threads','1','-preset','ultrafast','-crf','14','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k',$path),120)
 if($r.ExitCode -ne 0){throw $r.Error};return $path
}
function Check([string]$name,[string]$a,[string]$b,[bool]$expected,[string]$decoder=$ffmpeg) {
 $r=Compare-TVerRecMedia -SourcePath $a -DestinationPath $b -FfmpegPath $decoder -FfprobePath $ffprobe -WorkRoot $root
 if($r.Equivalent -ne $expected){throw "$name expected $expected : $($r|ConvertTo-Json -Compress)"}
 Write-Output "PASS $name : $($r.Reason)"
}
try {
 $base=Make 'base' 'testsrc2=size=640x360:rate=30' 'sine=frequency=440:sample_rate=48000'
 $copy=Join-Path $root 'exact.mp4';Copy-Item -LiteralPath $base -Destination $copy
 Check 'exact' $base $copy $true
 $near=Join-Path $root 'near.mp4'
 $r=[TVerRec.MediaComparison]::Run($ffmpeg,@('-v','error','-nostdin','-y','-i',$base,'-c:v','libx264','-threads','1','-preset','fast','-crf','14','-c:a','copy',$near),120)
 if($r.ExitCode -ne 0){throw $r.Error}
 Check 'near reencode' $base $near $true
 $different=Make 'audio' 'testsrc2=size=640x360:rate=30' 'sine=frequency=880:sample_rate=48000'
 Check 'different audio' $base $different $false
 $audioEdit=Join-Path $root 'audio-edit.mp4'
 $r=[TVerRec.MediaComparison]::Run($ffmpeg,@('-v','error','-nostdin','-y','-i',$base,'-c:v','copy','-af',"volume=0:enable='between(t,10,10.04)'",'-c:a','aac','-b:a','192k',$audioEdit),120)
 if($r.ExitCode -ne 0){throw $r.Error}
 Check 'local audio edit' $base $audioEdit $false
 $edited=Make 'edited' "testsrc2=size=640x360:rate=30,drawbox=x=0:y=0:w=iw:h=ih:color=red:t=fill:enable='between(t,10,12)'" 'sine=frequency=440:sample_rate=48000'
 Check 'two second video edit' $base $edited $false
 $short=Make 'short' 'testsrc2=size=640x360:rate=30' 'sine=frequency=440:sample_rate=48000' '29'
 Check 'duration' $base $short $false
 $silent=Make 'silent' 'testsrc2=size=640x360:rate=30' 'anullsrc=r=48000:cl=mono'
 Check 'silent audio' $base $silent $false
 Check 'decoder unavailable' $base $near $false (Join-Path $root 'missing.exe')
 foreach($bad in @('0/0','1/0','0/1')) {
  $failed=$false;try{$null=ConvertTo-TVerRecValidatedRate $bad '30/1'}catch{$failed=$true}
  if(-not $failed){throw "Invalid FPS accepted: $bad"}
 }
 Write-Output 'PASS NaN/infinite/zero FPS rejected'
 function Remove-Item {param($LiteralPath,[switch]$Recurse,[switch]$Force,$ErrorAction);throw 'injected cleanup failure'}
 try {
  $cleanup=Compare-TVerRecMedia $base $near $ffmpeg $ffprobe $root
  if($cleanup.Equivalent -or $cleanup.Reason -ne 'comparison cleanup failed; temporary evidence retained'){throw 'Cleanup exception escaped failclosed result'}
 } finally {Microsoft.PowerShell.Management\Remove-Item Function:\Remove-Item}
 Write-Output 'PASS cleanup failure returns a rejected decision'
 Write-Output 'ALL MEDIA COMPARISON TESTS PASSED'
} finally {Remove-Item -LiteralPath $root -Recurse -Force}
