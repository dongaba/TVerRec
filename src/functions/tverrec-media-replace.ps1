# Serialized collision handling. Old versions are retained; unknown media stays untouched.
. (Join-Path $PSScriptRoot 'tverrec-media-compare.ps1')

function Assert-TVerRecPlainPath([string]$Path) {
    $cursor=[IO.Path]::GetFullPath($Path)
    for($depth=0;$depth -lt 64;$depth++) {
        if(([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)) -and ([IO.File]::GetAttributes($cursor)).HasFlag([IO.FileAttributes]::ReparsePoint)){throw 'Path contains a link'}
        $parent=[IO.Path]::GetDirectoryName($cursor.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar))
        if([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor){return}
        $cursor=$parent
    }
    throw 'Path depth exceeds bound'
}

function Invoke-TVerRecAtomicReplace([string]$Stage,[string]$Destination,[string]$Backup) {
    [IO.File]::Replace($Stage,$Destination,$Backup)
}

function Write-TVerRecReplacementManifest([string]$Path,[hashtable]$Record) {
    [IO.File]::WriteAllText($Path,($Record|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}

function Invoke-TVerRecMediaReplacement {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$DestinationPath,
        [string]$FfmpegPath,[string]$FfprobePath,[string]$StateRoot=(Join-Path $PSScriptRoot '../../db/media-replacement'))
    $gate=$null;$sourceGuard=$null;$destinationGuard=$null;$stage=$null;$backup=$null;$recovery=$null;$manifest=$null;$record=$null
    try {
        foreach($path in @($SourcePath,$DestinationPath,$StateRoot)){Assert-TVerRecPlainPath $path}
        foreach($path in @($SourcePath,$DestinationPath)) {
            $item=Get-Item -LiteralPath $path -ErrorAction Stop
            if($item.PSIsContainer -or $item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)){throw 'Unsafe collision path'}
        }
        $SourcePath=[IO.Path]::GetFullPath($SourcePath);$DestinationPath=[IO.Path]::GetFullPath($DestinationPath)
        if([string]::Equals($SourcePath,$DestinationPath,[StringComparison]::OrdinalIgnoreCase)){throw 'Identical paths'}
        if([IO.Path]::GetExtension($SourcePath).ToLowerInvariant() -notin @('.mp4','.mkv','.ts')){return $false}
        [void][IO.Directory]::CreateDirectory($StateRoot)
        try {$gate=[IO.File]::Open((Join-Path $StateRoot 'comparison.lock'),'OpenOrCreate','ReadWrite','None')}
        catch [IO.IOException] {Write-Warning '[比較置換] 他の比較処理が実行中のため今回の移動を保留';return $false}
        $share=[IO.FileShare]::Read -bor [IO.FileShare]::Delete
        $sourceGuard=[IO.File]::Open($SourcePath,'Open','Read',$share)
        $destinationGuard=[IO.File]::Open($DestinationPath,'Open','Read',$share)
        $sourceInfo=[IO.FileInfo]::new($SourcePath);$destinationInfo=[IO.FileInfo]::new($DestinationPath)
        $sourceHash=(Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
        $destinationHash=(Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
        $sourceWins=$sourceInfo.LastWriteTimeUtc -ge $destinationInfo.LastWriteTimeUtc
        $cacheKey=$sourceHash+'-'+$destinationHash+'-'+$(if($sourceWins){'s'}else{'d'})
        $cacheDirectory=Join-Path $StateRoot 'decisions';[void][IO.Directory]::CreateDirectory($cacheDirectory)
        $cachePath=Join-Path $cacheDirectory ($cacheKey+'.json')
        if([IO.File]::Exists($cachePath)) {
            if(([IO.FileInfo]::new($cachePath)).Length -gt 64KB){throw 'Comparison cache exceeds bound'}
            $decision=[IO.File]::ReadAllText($cachePath)|ConvertFrom-Json
            if($decision.policy -ne 'near-v1' -or $decision.sourceHash -ne $sourceHash -or $decision.destinationHash -ne $destinationHash){throw 'Comparison cache identity mismatch'}
            $comparison=$decision.result
        } else {
            Write-Information ('[比較置換] 同名動画を比較: {0}' -f [IO.Path]::GetFileName($DestinationPath)) -InformationAction Continue
            $preferred=if($sourceWins){$SourcePath}else{$DestinationPath}
            $other=if($sourceWins){$DestinationPath}else{$SourcePath}
            $comparison=Compare-TVerRecMedia -SourcePath $preferred -DestinationPath $other -FfmpegPath $FfmpegPath -FfprobePath $FfprobePath -WorkRoot $StateRoot
            if($comparison.Equivalent -eq $true -or $comparison.Reason -in @('video difference','audio difference')) {
                $decision=@{policy='near-v1';sourceHash=$sourceHash;destinationHash=$destinationHash;result=$comparison}
                $cacheTemp=$cachePath+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
                try {
                    [IO.File]::WriteAllText($cacheTemp,($decision|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
                    [IO.File]::Move($cacheTemp,$cachePath,$true)
                } finally {if([IO.File]::Exists($cacheTemp)){[IO.File]::Delete($cacheTemp)}}
            }
        }
        if($comparison.Equivalent -isnot [bool] -or $comparison.Equivalent -ne $true){Write-Warning ('[比較置換] 差異または判定不能のため両方保持: {0}' -f $comparison.Reason);return $false}
        # Backups are outside title folders so a title can be aggregated cleanly.
        $destinationDirectory=[IO.Path]::GetDirectoryName($DestinationPath)
        $title=[IO.Path]::GetFileName($destinationDirectory)
        $archiveRoot=Join-Path ([IO.Path]::GetDirectoryName($destinationDirectory)) '.tverrec-replaced'
        $archive=Join-Path $archiveRoot $title
        Assert-TVerRecPlainPath $archive
        [void][IO.Directory]::CreateDirectory($archive)
        if($IsWindows){[IO.File]::SetAttributes($archiveRoot,([IO.File]::GetAttributes($archiveRoot) -bor [IO.FileAttributes]::Hidden))}
        if(([IO.DirectoryInfo]::new($archiveRoot)).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) -or ([IO.DirectoryInfo]::new($archive)).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)){throw 'Backup directory is a link'}
        $suffix=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')+'-'+[guid]::NewGuid().ToString('N')
        $backup=Join-Path $archive ($suffix+[IO.Path]::GetExtension($DestinationPath))
        $manifest=Join-Path $archive ($suffix+'.json')
        $record=@{status='pending';source=$SourcePath;destination=$DestinationPath;sourceHash=$sourceHash;destinationHash=$destinationHash;backup=$backup;sourceWins=$sourceWins;comparison=$comparison;at=[DateTime]::UtcNow.ToString('o')}
        Write-TVerRecReplacementManifest $manifest $record
        if((Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash -ne $sourceHash -or (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash -ne $destinationHash){throw 'Collision input changed before commit'}
        if(-not $sourceWins) {
            # Retire the older source without deleting its data; leave the newer destination in place.
            [IO.File]::Move($SourcePath,$backup)
            if((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $sourceHash -or (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash -ne $destinationHash) {
                if(-not [IO.File]::Exists($SourcePath)){[IO.File]::Move($backup,$SourcePath)}
                throw 'Retirement commit raced with an input replacement; originals retained'
            }
            Write-Information "[比較置換] 移動先の新しい版を保持、元を退避: $backup" -InformationAction Continue
            $record.status='committed';Write-TVerRecReplacementManifest $manifest $record
            return $true
        }
        $stage=Join-Path $archive ($suffix+'.pending')
        # Moving to a recoverable stage first avoids deleting source after a pathname race.
        [IO.File]::Move($SourcePath,$stage)
        if([IO.File]::Exists($SourcePath)){throw "Source could not be retired; both copies retained: $stage"}
        if((Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash -ne $sourceHash){throw "Source changed; recoverable stage retained: $stage"}
        if((Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash -ne $destinationHash){throw "Destination changed; recoverable stage retained: $stage"}
        # Keep an independent source copy even if an unrelated writer overwrites
        # the destination immediately after the atomic commit.
        $recovery=Join-Path $archive ($suffix+'.source-recovery')
        [IO.File]::Copy($stage,$recovery,$false)
        if((Get-FileHash -LiteralPath $recovery -Algorithm SHA256).Hash -ne $sourceHash){throw 'Source recovery copy verification failed'}
        # Windows ReplaceFile requires access incompatible with the read guards.
        # Release at the last moment; validate the retired file and roll back below.
        $sourceGuard.Dispose();$sourceGuard=$null;$destinationGuard.Dispose();$destinationGuard=$null
        Invoke-TVerRecAtomicReplace $stage $DestinationPath $backup
        # FileShare.Delete permits atomic nameswaps. Validate what was actually retired,
        # then roll back an external nameswap instead of accepting an un-compared file.
        if((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $destinationHash) {
            if((Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash -eq $sourceHash) {
                Invoke-TVerRecAtomicReplace $backup $DestinationPath $stage
            }
            throw "Replacement commit raced with destination update; recovery stage: $stage"
        }
        $stage=$null
        $record.status='committed';$record.recovery=$recovery;Write-TVerRecReplacementManifest $manifest $record
        Write-Information "[比較置換] 新しい版へ置換、旧版を退避: $backup" -InformationAction Continue
        return $true
    } catch {
        Write-Warning ('[比較置換] 置換を完了できませんでした。データは削除していません: {0}' -f $_.Exception.Message)
        if($stage -and [IO.File]::Exists($stage)) {
            try {if(-not [IO.File]::Exists($SourcePath)){[IO.File]::Move($stage,$SourcePath);$stage=$null}}
            catch {Write-Warning "[比較置換] 復旧用ファイルを保持: $stage"}
        }
        if($recovery -and [IO.File]::Exists($recovery) -and -not [IO.File]::Exists($SourcePath)) {
            try {[IO.File]::Copy($recovery,$SourcePath,$false)}
            catch {Write-Warning "[比較置換] 原本の復旧用コピーを保持: $recovery"}
        }
        # ReplaceFile can fail after renaming the original destination to backup.
        if($backup -and [IO.File]::Exists($backup) -and -not [IO.File]::Exists($DestinationPath)) {
            try {
                if((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -eq $destinationHash){[IO.File]::Move($backup,$DestinationPath)}
            } catch {Write-Warning "[比較置換] 移動先の復旧用ファイルを保持: $backup"}
        }
        if($manifest -and $record) {
            try {$record.status='failed';$record.recovery=$recovery;$record.stage=$stage;$record.backupExists=[IO.File]::Exists($backup);Write-TVerRecReplacementManifest $manifest $record}
            catch {Write-Warning "[比較置換] 復旧記録の更新に失敗: $manifest"}
        }
        return $false
    } finally {
        if($sourceGuard){$sourceGuard.Dispose()};if($destinationGuard){$destinationGuard.Dispose()};if($gate){$gate.Dispose()}
    }
}
