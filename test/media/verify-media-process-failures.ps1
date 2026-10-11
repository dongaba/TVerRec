Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$module=Join-Path $root 'src/functions/tverrec-media-compare.ps1'
. $module
$fixture=Join-Path $root ('.diagnostics/process-fixture-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$ffmpeg=(Get-Command ffmpeg).Source
$audio=Join-Path $fixture 'tone.wav'
$run=[TVerRec.MediaComparison]::Run($ffmpeg,@('-v','error','-nostdin','-f','lavfi','-i','sine=frequency=440:sample_rate=16000:duration=30','-c:a','pcm_s16le',$audio),60)
if($run.ExitCode -ne 0){throw 'Audio fixture generation failed'}
$corrupt=Join-Path $fixture 'corrupt.wav';[IO.File]::WriteAllText($corrupt,'not media')
$watch=[Diagnostics.Stopwatch]::StartNew();$failed=$false
try{$null=[TVerRec.MediaComparison]::Audio($ffmpeg,$corrupt,$audio,30,480000,1)}catch{$failed=$true}
if(-not $failed -or $watch.Elapsed.TotalSeconds -ge 10){throw 'Audio decoder failure did not fail promptly'}
$watch.Restart();$failed=$false
try{$null=[TVerRec.MediaComparison]::Run((Get-Command pwsh).Source,@('-NoProfile','-Command','[Console]::Error.Write(("x" * 1200000)); Start-Sleep 60'),30)}catch{$failed=$true}
if(-not $failed -or $watch.Elapsed.TotalSeconds -ge 10){throw 'Drain overflow did not fail promptly'}
# Inject second-process startup failure in a separate test-only namespace.
$text=[IO.File]::ReadAllText($module)
$start=$text.IndexOf("@'`n");if($start -lt 0){$start=$text.IndexOf("@'`r`n")}
$end=$text.IndexOf("'@",$start+2)
$csharp=$text.Substring($start+2,$end-$start-2).Trim().Replace('namespace TVerRec {','namespace TVerRecStartupFixture {')
$csharp=$csharp.Replace('return Process.Start(si) ?? throw new Exception("process start failed");','if(++Calls==2)throw new Exception("injected second start failure");var p=Process.Start(si) ?? throw new Exception("process start failed");FirstPid=p.Id;return p;')
$csharp=$csharp.Replace('public static class MediaComparison {','public static class MediaComparison { public static int Calls=0; public static int FirstPid=0;')
Add-Type -TypeDefinition $csharp
$failed=$false
try{$null=[TVerRecStartupFixture.MediaComparison]::Audio($ffmpeg,$audio,$audio,30,480000,1)}catch{$failed=$true}
if(-not $failed){throw 'Startup failure injection ineffective'}
try{$process=[Diagnostics.Process]::GetProcessById([TVerRecStartupFixture.MediaComparison]::FirstPid);if(-not $process.HasExited){throw 'First decoder leaked after second startup failed'}}catch [ArgumentException]{Write-Verbose 'First decoder already exited and was reaped'}
'PASS media process failures: early decoder failure, drain overflow, second-start cleanup'
"Fixture evidence: $fixture"
