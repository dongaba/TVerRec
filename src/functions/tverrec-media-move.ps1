. (Join-Path $PSScriptRoot 'tverrec-media-replace.ps1')

function Move-TVerRecComparedFile {
    param([string]$SourceDirectory,[string]$DestinationDirectory,[string]$FfmpegPath,[string]$FfprobePath,[string]$StateRoot)
    if ([string]::IsNullOrWhiteSpace($SourceDirectory) -or [string]::IsNullOrWhiteSpace($DestinationDirectory)) { throw 'Move source/destination must not be empty.' }
    $source=[IO.Path]::GetFullPath($SourceDirectory)
    $destination=[IO.Path]::GetFullPath($DestinationDirectory)
    foreach ($path in @($source,$destination)) {
        $directory=[IO.DirectoryInfo]::new($path)
        if (!$directory.Exists -or $directory.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw "Move directory is unavailable or a link: $path" }
    }
    if ([string]::Equals($source.TrimEnd('\','/'),$destination.TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Move source and destination are identical.' }
    $count=0;$comparisonBudget=1
    $cursorRoot=Join-Path $StateRoot 'cursors'
    [void][IO.Directory]::CreateDirectory($cursorRoot)
    $hasher=[Security.Cryptography.SHA256]::Create()
    try {$key=([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($source)))).Replace('-','')}
    finally {$hasher.Dispose()}
    $cursorPath=Join-Path $cursorRoot ($key+'.txt');$cursor=''
    if([IO.File]::Exists($cursorPath) -and ([IO.FileInfo]::new($cursorPath)).Length -le 4096){$cursor=[IO.File]::ReadAllText($cursorPath)}
    $eligible=[string]::IsNullOrEmpty($cursor)
    foreach ($path in [IO.Directory]::EnumerateFiles($source,'*',[IO.SearchOption]::TopDirectoryOnly)) {
        if (++$count -gt 20000) { throw 'Move file count exceeds 20000.' }
        $attributes=[IO.File]::GetAttributes($path)
        if ($attributes.HasFlag([IO.FileAttributes]::Hidden)) { continue }
        if ($attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { Write-Warning "[移動保護] リンクを省略: $path"; continue }
        $target=Join-Path $destination ([IO.Path]::GetFileName($path))
        $wasCursor=[string]::Equals([IO.Path]::GetFileName($path),$cursor,[StringComparison]::OrdinalIgnoreCase)
        if($wasCursor){$eligible=$true}
        try { [IO.File]::Move($path,$target) }
        catch [IO.IOException] {
            if ([IO.File]::Exists($target)) {
                if($eligible -and -not $wasCursor -and $comparisonBudget -gt 0 -and [IO.Path]::GetExtension($path).ToLowerInvariant() -in @('.mp4','.mkv','.ts')) {
                    $comparisonBudget--
                    [IO.File]::WriteAllText($cursorPath,[IO.Path]::GetFileName($path),[Text.UTF8Encoding]::new($false))
                    if(Invoke-TVerRecMediaReplacement -SourcePath $path -DestinationPath $target -FfmpegPath $FfmpegPath -FfprobePath $FfprobePath -StateRoot $StateRoot){continue}
                }
                Write-Warning "[移動保護] 同名ファイルを保持（差異・判定不能・比較待ち）: $target"; continue
            }
            throw
        }
    }
    if($comparisonBudget -eq 1){[IO.File]::WriteAllText($cursorPath,'',[Text.UTF8Encoding]::new($false))}
}
