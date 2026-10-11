Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'src/functions/tverrec-media-replace.ps1')
$fixture=Join-Path $root ('.diagnostics/replacement-fixture-'+[guid]::NewGuid().ToString('N'))
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
function New-Case([string]$Name,[string]$Source,[string]$Destination,[bool]$SourceNewer=$true) {
    $folder=Join-Path $fixture $Name;$from=Join-Path $folder 'from/title';$to=Join-Path $folder 'to/title';$state=Join-Path $folder 'state'
    foreach($p in @($from,$to,$state)){[void][IO.Directory]::CreateDirectory($p)}
    $s=Join-Path $from 'test.mp4';$d=Join-Path $to 'test.mp4'
    [IO.File]::WriteAllText($s,$Source);[IO.File]::WriteAllText($d,$Destination)
    [IO.File]::SetLastWriteTimeUtc($s,[DateTime]::UtcNow.AddHours($(if($SourceNewer){-1}else{-3})))
    [IO.File]::SetLastWriteTimeUtc($d,[DateTime]::UtcNow.AddHours(-2))
    @{SourcePath=$s;DestinationPath=$d;StateRoot=$state;FfmpegPath='unused';FfprobePath='unused'}
}
try {
    $case=New-Case exact 'SAME' 'SAME'
    Assert (Invoke-TVerRecMediaReplacement @case) 'Exact replacement failed'
    Assert (-not [IO.File]::Exists($case.SourcePath)) 'Exact source still present'
    Assert ([IO.File]::ReadAllText($case.DestinationPath) -eq 'SAME') 'Exact destination changed'
    $backups=@([IO.Directory]::EnumerateFiles((Join-Path $fixture 'exact/to/.tverrec-replaced/title'),'*.mp4'))
    Assert ($backups.Count -eq 1 -and [IO.File]::ReadAllText($backups[0]) -eq 'SAME') 'Original backup absent'
    $case=New-Case exactNoTools 'SAME' 'SAME';$case.FfmpegPath='';$case.FfprobePath=''
    Assert (Invoke-TVerRecMediaReplacement @case) 'Exact files require decoders unnecessarily'
    function Compare-TVerRecMedia {param($SourcePath,$DestinationPath,$FfmpegPath,$FfprobePath,$WorkRoot);[pscustomobject]@{Equivalent=$true;Reason='fixture near';Mode='near'}}
    $case=New-Case newer 'NEW' 'OLD'
    Assert (Invoke-TVerRecMediaReplacement @case) 'Near replacement failed'
    Assert ([IO.File]::ReadAllText($case.DestinationPath) -eq 'NEW') 'Newer source not selected'
    $backup=@([IO.Directory]::EnumerateFiles((Join-Path $fixture 'newer/to/.tverrec-replaced/title'),'*.mp4'))
    Assert ([IO.File]::ReadAllText($backup[0]) -eq 'OLD') 'Old destination lost'
    $case=New-Case older 'OLD' 'NEW' $false
    Assert (Invoke-TVerRecMediaReplacement @case) 'Older source retirement failed'
    Assert ([IO.File]::ReadAllText($case.DestinationPath) -eq 'NEW') 'Older source overwrote new destination'
    $backup=@([IO.Directory]::EnumerateFiles((Join-Path $fixture 'older/to/.tverrec-replaced/title'),'*.mp4'))
    Assert ([IO.File]::ReadAllText($backup[0]) -eq 'OLD') 'Older source lost'
    function Compare-TVerRecMedia {param($SourcePath,$DestinationPath,$FfmpegPath,$FfprobePath,$WorkRoot);[pscustomobject]@{Equivalent=$false;Reason='fixture difference';Mode='near'}}
    $case=New-Case different 'SOURCE' 'DESTINATION'
    Assert (-not (Invoke-TVerRecMediaReplacement @case -WarningAction SilentlyContinue)) 'Different files accepted'
    Assert ([IO.File]::ReadAllText($case.SourcePath) -eq 'SOURCE' -and [IO.File]::ReadAllText($case.DestinationPath) -eq 'DESTINATION') 'Different files modified'
    function Compare-TVerRecMedia {param($SourcePath,$DestinationPath,$FfmpegPath,$FfprobePath,$WorkRoot);[pscustomobject]@{Equivalent=$false;Reason='process timeout';Mode='near'}}
    $case=New-Case transient 'SOURCE' 'DESTINATION'
    Assert (-not (Invoke-TVerRecMediaReplacement @case -WarningAction SilentlyContinue)) 'Transient error accepted'
    function Compare-TVerRecMedia {param($SourcePath,$DestinationPath,$FfmpegPath,$FfprobePath,$WorkRoot);[pscustomobject]@{Equivalent=$true;Reason='fixture near';Mode='near'}}
    Assert (Invoke-TVerRecMediaReplacement @case) 'Transient error cached permanently'
    $case=New-Case busy 'SOURCE' 'DESTINATION'
    $gate=[IO.File]::Open((Join-Path $case.StateRoot 'comparison.lock'),'OpenOrCreate','ReadWrite','None')
    try{Assert (-not (Invoke-TVerRecMediaReplacement @case -WarningAction SilentlyContinue)) 'Busy comparison gate accepted'}finally{$gate.Dispose()}
    function Compare-TVerRecMedia {param($SourcePath,$DestinationPath,$FfmpegPath,$FfprobePath,$WorkRoot);[pscustomobject]@{Equivalent=$true;Reason='fixture near';Mode='near'}}
    $case=New-Case readonly 'SOURCE' 'DESTINATION'
    if($IsWindows) {
        [IO.File]::SetAttributes($case.DestinationPath,[IO.FileAttributes]::ReadOnly)
        try{Assert (-not (Invoke-TVerRecMediaReplacement @case -WarningAction SilentlyContinue)) 'Read-only target replacement accepted'}finally{[IO.File]::SetAttributes($case.DestinationPath,[IO.FileAttributes]::Normal)}
        Assert ([IO.File]::ReadAllText($case.SourcePath) -eq 'SOURCE' -and [IO.File]::ReadAllText($case.DestinationPath) -eq 'DESTINATION') 'Failed replacement lost input'
    }
    $case=New-Case race 'SOURCE' 'DESTINATION'
    $script:raceInjected=$false
    function Invoke-TVerRecAtomicReplace {
        param($Stage,$Destination,$Backup)
        if(-not $script:raceInjected){[IO.File]::WriteAllText($Destination,'FOREIGN');$script:raceInjected=$true}
        [IO.File]::Replace($Stage,$Destination,$Backup)
    }
    Assert (-not (Invoke-TVerRecMediaReplacement @case -WarningAction SilentlyContinue)) 'Uncompared destination update accepted'
    Assert ([IO.File]::ReadAllText($case.SourcePath) -eq 'SOURCE') 'Race rollback lost source'
    Assert ([IO.File]::ReadAllText($case.DestinationPath) -eq 'FOREIGN') 'Race rollback lost external update'
    $case=New-Case doubleRace 'SOURCE' 'DESTINATION'
    function Invoke-TVerRecAtomicReplace {
        param($Stage,$Destination,$Backup)
        [IO.File]::WriteAllText($Destination,'FOREIGN_1')
        [IO.File]::Replace($Stage,$Destination,$Backup)
        [IO.File]::WriteAllText($Destination,'FOREIGN_2')
    }
    Assert (-not (Invoke-TVerRecMediaReplacement @case -WarningAction SilentlyContinue)) 'Double race accepted'
    Assert ([IO.File]::ReadAllText($case.SourcePath) -eq 'SOURCE') 'Double race lost original source'
    Assert ([IO.File]::ReadAllText($case.DestinationPath) -eq 'FOREIGN_2') 'Double race lost newest external update'
    $case=New-Case partialReplace 'SOURCE' 'DESTINATION'
    function Invoke-TVerRecAtomicReplace {
        param($Stage,$Destination,$Backup)
        [IO.File]::Move($Destination,$Backup)
        throw 'injected partial ReplaceFile failure'
    }
    Assert (-not (Invoke-TVerRecMediaReplacement @case -WarningAction SilentlyContinue)) 'Partial replace accepted'
    Assert ([IO.File]::ReadAllText($case.SourcePath) -eq 'SOURCE') 'Partial replace lost source'
    Assert ([IO.File]::ReadAllText($case.DestinationPath) -eq 'DESTINATION') 'Partial replace lost original destination name'
    'PASS media replacement: exact/near/older/difference/busy/failed commit preserve originals'
    "Fixture evidence: $fixture"
} finally {
    # Keep bounded fixtures as evidence; no live media is touched.
}
