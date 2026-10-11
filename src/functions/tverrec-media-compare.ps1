# Near-equivalence only. Caller must serialize calls and preserve replaced originals.
if (-not ('TVerRec.MediaComparison' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Threading.Tasks;
namespace TVerRec {
 public sealed class RunResult { public int ExitCode; public string Output; public string Error; }
 public sealed class AudioResult { public double Snr; public double Correlation; public double MinimumBlockSnr=double.PositiveInfinity; public double MinimumBlockCorrelation=1; public long Samples; public bool BlocksPassed=true; }
 public static class MediaComparison {
  static Process Start(string exe,string[] args,string directory=null) {
   var si=new ProcessStartInfo(exe) {UseShellExecute=false,RedirectStandardOutput=true,RedirectStandardError=true,CreateNoWindow=true};
   if(directory!=null)si.WorkingDirectory=directory;
   foreach(var a in args) si.ArgumentList.Add(a);
   return Process.Start(si) ?? throw new Exception("process start failed");
  }
  static async Task<string> Drain(StreamReader reader,int limit) {
   var b=new char[4096]; var s=new StringBuilder(); int n;
   while((n=await reader.ReadAsync(b,0,b.Length))>0) { if(s.Length+n>limit) throw new Exception("output limit exceeded"); s.Append(b,0,n); } return s.ToString();
  }
  static void Kill(Process p) { try {if(!p.HasExited)p.Kill(true);}catch{} }
  static void WaitTasks(int seconds,params Task[] tasks) {
   var remaining=new List<Task>(tasks);var watch=Stopwatch.StartNew();
   while(remaining.Count>0) {
    int milliseconds=Math.Max(1,(int)((seconds-watch.Elapsed.TotalSeconds)*1000));
    var next=Task.WhenAny(remaining);
    if(!next.Wait(milliseconds))throw new Exception("process timeout");
    var finished=next.Result;finished.GetAwaiter().GetResult();remaining.Remove(finished);
    if(watch.Elapsed.TotalSeconds>=seconds&&remaining.Count>0)throw new Exception("process timeout");
   }
  }
  public static RunResult Run(string exe,string[] args,int seconds) {return RunAt(exe,args,seconds,null);}
  public static RunResult RunAt(string exe,string[] args,int seconds,string directory) {
   using(var p=Start(exe,args,directory)) {
    try {
     var o=Drain(p.StandardOutput,1048576); var e=Drain(p.StandardError,1048576);
     WaitTasks(seconds,o,e,p.WaitForExitAsync());
     return new RunResult{ExitCode=p.ExitCode,Output=o.Result,Error=e.Result};
    } finally {Kill(p);p.WaitForExit();}
   }
  }
  static async Task<int> Block(Stream s,byte[] b) {int total=0,n; while(total<b.Length&&(n=await s.ReadAsync(b,total,b.Length-total))>0)total+=n;return total;}
  static double Snr(double energy,double difference) {return difference==0?double.PositiveInfinity:10*Math.Log10(energy/difference);}
  static double Corr(long count,double sx,double sy,double xx,double yy,double xy) {
   double a=xx-sx*sx/count,b=yy-sy*sy/count;
   if(a<=1e-12||b<=1e-12)return double.NaN;
   return (xy-sx*sy/count)/Math.Sqrt(a*b);
  }
  public static AudioResult Audio(string exe,string source,string destination,int seconds,long maxSamples,int channels) {
   if(channels<1||channels>2)throw new Exception("unsupported audio channels");
   string[] Args(string path)=>new[]{"-v","error","-nostdin","-threads","1","-i",path,"-map","0:a:0","-vn","-threads","1","-ac",channels.ToString(),"-ar","16000","-f","s16le","pipe:1"};
   using(var p=Start(exe,Args(source))) {
    Process q=null;
    try {
     q=Start(exe,Args(destination));
     var pe=Drain(p.StandardError,1048576);var qe=Drain(q.StandardError,1048576);
     var work=Task.Run(async()=>{
      var r=new AudioResult();var x=new byte[32000*channels];var y=new byte[32000*channels];
      double sx=0,sy=0,xx=0,yy=0,xy=0,dd=0;
      while(true){
       var reads=await Task.WhenAll(Block(p.StandardOutput.BaseStream,x),Block(q.StandardOutput.BaseStream,y));
       int n=reads[0];if(n!=reads[1]||n%2!=0)throw new Exception("PCM length mismatch");if(n==0)break;
       long count=n/2;r.Samples+=count;if(r.Samples>maxSamples)throw new Exception("PCM limit exceeded");
       double bsx=0,bsy=0,bxx=0,byy=0,bxy=0,bdd=0;
       for(int i=0;i<n;i+=2){double a=(short)(x[i]|x[i+1]<<8),b=(short)(y[i]|y[i+1]<<8);bsx+=a;bsy+=b;bxx+=a*a;byy+=b*b;bxy+=a*b;bdd+=(a-b)*(a-b);}
       double snr=Snr(bxx,bdd),corr=Corr(count,bsx,bsy,bxx,byy,bxy);
       // Exact silent blocks are permitted; a silent whole track is rejected below.
       bool exact=bdd==0;
       if(!exact&&!(snr>=24||corr>=0.999))r.BlocksPassed=false;
       if(!double.IsNaN(snr))r.MinimumBlockSnr=Math.Min(r.MinimumBlockSnr,snr);
       if(!double.IsNaN(corr))r.MinimumBlockCorrelation=Math.Min(r.MinimumBlockCorrelation,corr);
       sx+=bsx;sy+=bsy;xx+=bxx;yy+=byy;xy+=bxy;dd+=bdd;
      }
      if(r.Samples==0||xx/r.Samples<1||yy/r.Samples<1)throw new Exception("silent or empty audio");
      r.Snr=Snr(xx,dd);r.Correlation=Corr(r.Samples,sx,sy,xx,yy,xy);return r;
     });
     WaitTasks(seconds,work,pe,qe);
     if(!p.WaitForExit(10000)||!q.WaitForExit(10000)||p.ExitCode!=0||q.ExitCode!=0||pe.Result.Length!=0||qe.Result.Length!=0)throw new Exception("audio decoder failure");
     return work.Result;
    }finally{Kill(p);p.WaitForExit();if(q!=null){Kill(q);q.WaitForExit();q.Dispose();}}
   }
  }
 }
}
'@
}

function ConvertTo-TVerRecValidatedRate([string]$Average,[string]$Nominal) {
 $values=@()
 foreach($text in @($Average,$Nominal)) {
  $parts=$text.Split('/');if($parts.Count -ne 2){throw 'variable or invalid frame rate'}
  $rate=[double]$parts[0]/[double]$parts[1]
  if([double]::IsNaN($rate) -or [double]::IsInfinity($rate) -or $rate -le 0 -or $rate -gt 240){throw 'variable or invalid frame rate'}
  $values+=,$rate
 }
 if([math]::Abs($values[0]-$values[1]) -gt 0.001){throw 'variable or invalid frame rate'}
 $values[0]
}

function Compare-TVerRecMedia {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$DestinationPath,
       [Parameter(Mandatory)][AllowEmptyString()][string]$FfmpegPath,[Parameter(Mandatory)][AllowEmptyString()][string]$FfprobePath,
       [Parameter(Mandatory)][string]$WorkRoot)
 $result=[ordered]@{Equivalent=$false;Reason='unstarted';Mode='near';VideoMean=$null;VideoMinimum=$null;AudioSnr=$null;AudioCorrelation=$null;AudioMinimumBlockSnr=$null;AudioMinimumBlockCorrelation=$null}
 Set-StrictMode -Version Latest
 $temp=$null; $clock=[Diagnostics.Stopwatch]::StartNew()
 try {
  $source=Get-Item -LiteralPath $SourcePath -ErrorAction Stop
  $destination=Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
  if($source.PSIsContainer -or $destination.PSIsContainer -or $source.Length -eq 0 -or $destination.Length -eq 0){throw 'invalid input'}
  $identity=@($source.Length,$source.LastWriteTimeUtc.Ticks,$destination.Length,$destination.LastWriteTimeUtc.Ticks)
  if((Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $destination.FullName -Algorithm SHA256).Hash){
   $result.Equivalent=$true;$result.Reason='whole-sha256';$result.Mode='exact'
  } else {
   if([string]::IsNullOrWhiteSpace($FfmpegPath) -or [string]::IsNullOrWhiteSpace($FfprobePath)){throw 'decoder tools unavailable'}
   $probes=@()
   foreach($file in @($source,$destination)) {
    $probe=[TVerRec.MediaComparison]::Run($FfprobePath,@('-v','error','-show_streams','-show_format','-of','json',$file.FullName),60)
    if($probe.ExitCode -ne 0 -or $probe.Error.Length -gt 0){throw 'probe failure'}
    $p=$probe.Output|ConvertFrom-Json
    $video=@($p.streams|Where-Object {$_.codec_type -eq 'video' -and $_.disposition.attached_pic -eq 0})
    $audio=@($p.streams|Where-Object {$_.codec_type -eq 'audio'})
    if($video.Count -ne 1 -or $audio.Count -ne 1){throw 'requires one video and one audio stream'}
    $v=$video[0];$duration=[double]::Parse([string]$p.format.duration,[cultureinfo]::InvariantCulture)
    if([double]::IsNaN($duration) -or [double]::IsInfinity($duration) -or $duration -le 0 -or $duration -gt 14400 -or $v.codec_name -notin @('h264','hevc','mpeg4','vp9','av1')){throw 'unsupported media'}
    $fps=ConvertTo-TVerRecValidatedRate ([string]$v.avg_frame_rate) ([string]$v.r_frame_rate)
    $audioStream=$audio[0]
    if($audioStream.channels -notin @(1,2) -or $audioStream.codec_name -notin @('aac','mp3','ac3','eac3','opus','vorbis','flac','pcm_s16le','pcm_s24le')){throw 'unsupported audio codec or channels'}
    $probes+=@{Video=$v;Audio=$audioStream;Duration=$duration;Fps=$fps}
   }
   $a=$probes[0];$b=$probes[1]
   if($a.Video.width -lt $b.Video.width -or $a.Video.height -lt $b.Video.height -or [math]::Abs($a.Fps-$b.Fps) -gt 0.001 -or [math]::Abs($a.Duration-$b.Duration) -gt 0.05){throw 'geometry, frame rate or duration mismatch'}
   if($a.Audio.channels -ne $b.Audio.channels -or [math]::Abs([double]$a.Audio.start_time-[double]$b.Audio.start_time) -gt 0.05 -or [math]::Abs([double]$a.Video.start_time-[double]$b.Video.start_time) -gt 0.05){throw 'stream layout or start time mismatch'}
   foreach($kind in @('Video','Audio')) {
    $ad=[double]::Parse([string]$a[$kind].duration,[cultureinfo]::InvariantCulture)
    $bd=[double]::Parse([string]$b[$kind].duration,[cultureinfo]::InvariantCulture)
    if($ad -le 0 -or $bd -le 0 -or [math]::Abs($ad-$bd) -gt 0.05){throw 'stream duration mismatch'}
   }
   $temp=Join-Path $WorkRoot ('media-compare-'+[guid]::NewGuid().ToString('N'))
   $null=New-Item -ItemType Directory -Path $temp -Force
   $stats=Join-Path $temp 'ssim.log'
   # Use a relative stats path to avoid ffmpeg filter escaping of Windows drive colons.
   $filter="[0:$($a.Video.index)]setpts=PTS-STARTPTS,fps=1,scale=640:360:flags=bicubic,format=yuv420p[a];[1:$($b.Video.index)]setpts=PTS-STARTPTS,fps=1,scale=640:360:flags=bicubic,format=yuv420p[b];[a][b]ssim=stats_file=ssim.log[out]"
   $run=[TVerRec.MediaComparison]::RunAt($FfmpegPath,@('-v','error','-nostdin','-threads','1','-i',$source.FullName,'-threads','1','-i',$destination.FullName,'-filter_complex_threads','1','-filter_complex',$filter,'-map','[out]','-an','-t','14400','-f','null','-'),[math]::Max(1,3600-[int]$clock.Elapsed.TotalSeconds),$temp)
   if($run.ExitCode -ne 0 -or $run.Error.Length -gt 0){throw 'video decoder failure'}
   $info=Get-Item -LiteralPath $stats
   if($info.Length -gt 64MB){throw 'temporary output limit exceeded'}
   $sum=0.0;$minimum=1.0;$count=0
   foreach($line in [IO.File]::ReadLines($stats)) {
    if($line -notmatch 'All:([0-9]+(?:\.[0-9]+)?)\s'){throw 'invalid SSIM statistics'}
    $value=[double]::Parse($Matches[1],[cultureinfo]::InvariantCulture);$sum+=$value;$minimum=[math]::Min($minimum,$value);$count++
   }
   if($count -lt [math]::Floor([math]::Min($a.Duration,$b.Duration))-1 -or $count -gt [math]::Ceiling([math]::Max($a.Duration,$b.Duration))+1 -or $count -eq 0){throw 'incomplete SSIM statistics'}
   $result.VideoMean=$sum/$count;$result.VideoMinimum=$minimum
   if($result.VideoMean -lt 0.995 -or $minimum -lt 0.98){throw 'video difference'}
   $pcm=[TVerRec.MediaComparison]::Audio($FfmpegPath,$source.FullName,$destination.FullName,[math]::Max(1,3600-[int]$clock.Elapsed.TotalSeconds),230400000*[long]$a.Audio.channels,[int]$a.Audio.channels)
   $result.AudioSnr=$pcm.Snr;$result.AudioCorrelation=$pcm.Correlation;$result.AudioMinimumBlockSnr=$pcm.MinimumBlockSnr;$result.AudioMinimumBlockCorrelation=$pcm.MinimumBlockCorrelation
   if(-not $pcm.BlocksPassed -or -not ($pcm.Snr -ge 28 -or $pcm.Correlation -ge 0.999)){throw 'audio difference'}
   $result.Equivalent=$true;$result.Reason='near thresholds satisfied'
  }
  $s=Get-Item -LiteralPath $source.FullName;$d=Get-Item -LiteralPath $destination.FullName
  if($s.Length -ne $identity[0] -or $s.LastWriteTimeUtc.Ticks -ne $identity[1] -or $d.Length -ne $identity[2] -or $d.LastWriteTimeUtc.Ticks -ne $identity[3]){throw 'input changed during comparison'}
 } catch {$result.Equivalent=$false;$result.Reason=$_.Exception.Message}
 finally {
  try {if($temp -and (Test-Path -LiteralPath $temp)){Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction Stop}}
  catch {$result.Equivalent=$false;$result.Reason='comparison cleanup failed; temporary evidence retained'}
  $clock.Stop()
 }
 [pscustomobject]$result
}
