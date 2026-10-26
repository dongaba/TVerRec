###################################################################################
#
#		TVerRec固有関数スクリプト(ffmpegの起動、字幕の修復、番組ファイルの整合性チェック)
#
###################################################################################
<#
	.SYNOPSIS
		ffmpegの起動、字幕の修復、番組ファイルの整合性チェックの関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region 整合性チェック関連処理
#----------------------------------------------------------------------
# ダウンロードプロセスの待機
#----------------------------------------------------------------------
function Wait-DownloadProcess {
	<#
		.SYNOPSIS
			ダウンロードプロセスが完了するまで待機します。

		.DESCRIPTION
			現在実行中のダウンロードプロセス（yt-dlpとffmpeg）が
			すべて完了するまで待機します。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在のダウンロードプロセス数を取得
			2. プロセス数が0になるまで60秒ごとにチェック
			3. プロセス数が0になったら待機を終了
	#>
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ytdlCount = [Int](Get-YtdlProcessCount)
	# ffmpegでのダウンロード機能を有効化時に必要
	$ffmpegCount = [Int](Get-FfmpegProcessCount)
	while (($ytdlCount + $ffmpegCount) -ne 0) {
		Write-Output ($script:msg.WaitingDownloadProcess -f ($ytdlCount + $ffmpegCount))
		Start-Sleep -Seconds 60
		$ytdlCount = [Int](Get-YtdlProcessCount)
		# ffmpegでのダウンロード機能を有効化時に必要
		$ffmpegCount = [Int](Get-FfmpegProcessCount)
	}
}

#----------------------------------------------------------------------
# ffmpeg/ffprobeプロセスの起動
#----------------------------------------------------------------------
function Invoke-FFmpegProcess {
	<#
		.SYNOPSIS
			ffmpegまたはffprobeプロセスを起動します。

		.DESCRIPTION
			ffmpegまたはffprobeプロセスを起動し、指定された引数で実行します。
			エラーログを記録し、プロセスの終了コードを返します。

		.PARAMETER filePath
			実行するffmpegまたはffprobeのパスを指定します。

		.PARAMETER ffmpegArgs
			ffmpegまたはffprobeに渡す引数を指定します。

		.PARAMETER execName
			実行するコマンドの名前（'ffmpeg'または'ffprobe'）を指定します。

		.OUTPUTS
			[Int]
			プロセスの終了コードを返します。

		.EXAMPLE
			Invoke-FFmpegProcess -filePath 'ffmpeg' -ffmpegArgs '-i input.mp4 output.mp4' -execName 'ffmpeg'

		.NOTES
			この関数は以下の処理を行います：
			1. プロセス起動用のパラメータを設定
			2. エラーログの出力先を設定
			3. プロセスを起動し、終了を待機
			4. プロセスの終了コードを返す
	#>
	param (
		[String]$filePath,
		[String]$ffmpegArgs,
		[String]$execName
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$commonParams = @{
		FilePath              = $filePath
		ArgumentList          = $ffmpegArgs
		PassThru              = $true
		RedirectStandardError = $script:ffmpegErrorLogPath
		Wait                  = $true
	}
	Invoke-StatisticsCheck -Operation 'validate'
	if ($IsWindows) { $commonParams.WindowStyle = $script:windowShowStyle }
	else { $commonParams.RedirectStandardOutput = '/dev/null' }
	try {
		# プロセスの開始
		$process = Start-Process @commonParams
		$process.Handle | Out-Null  # プロセスハンドルをキャッシュ。PS7.4.0の終了コードを捕捉しないバグのために必要
		$process.WaitForExit()
	} catch { Write-Warning ($script:msg.ExecFailed -f $execName) ; return }
	return $process.ExitCode
}

#----------------------------------------------------------------------
# SRT字幕の「0秒字幕」を次の字幕にマージ
#----------------------------------------------------------------------
function Merge-ZeroDurationSubtitle {
	<#
		.SYNOPSIS
			SRT字幕の中で表示時間が0秒になっている字幕を、同時刻に始まる次の字幕へマージします。

		.DESCRIPTION
			yt-dlpで字幕をmp4に埋め込むと、同一タイミングの字幕(2行表示)のうち1つ目が
			「開始時刻 --> 開始時刻」の0秒字幕になり、表示されなくなることがあります。
			0秒字幕と、同じ開始時刻を持つ直後の字幕を1つにまとめ、テキストを改行でつなぎます。
			マージ対象がない場合は、内容を変更しません。

		.PARAMETER SrtText
			SRT形式の字幕テキスト全体を指定します。

		.OUTPUTS
			[PSCustomObject]
			Content: マージ後のSRTテキスト、MergedCount: マージした件数

		.EXAMPLE
			$result = Merge-ZeroDurationSubtitle -SrtText (Get-Content -LiteralPath 'a.srt' -Raw -Encoding UTF8)
	#>
	[OutputType([PSCustomObject])]
	Param ([Parameter(Mandatory = $true)][AllowEmptyString()][String]$SrtText)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$timePattern = '^\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{3})'
	$cues = [System.Collections.Generic.List[PSCustomObject]]::new()
	foreach ($block in ($SrtText.Trim() -split '(?:\r?\n){2,}')) {
		$lines = @($block -split '\r?\n')
		$timeLineIndex = -1
		for ($i = 0; $i -lt [Math]::Min($lines.Count, 2); $i++) {
			if ($lines[$i] -match $timePattern) { $timeLineIndex = $i ; break }
		}
		if ($timeLineIndex -lt 0) { continue }
		$null = $lines[$timeLineIndex] -match $timePattern
		$cues.Add([PSCustomObject]@{
				Start = $Matches[1]
				End   = $Matches[2]
				Text  = @($lines | Select-Object -Skip ($timeLineIndex + 1))
			})
	}

	$merged = [System.Collections.Generic.List[PSCustomObject]]::new()
	$mergedCount = 0
	$idx = 0
	while ($idx -lt $cues.Count) {
		$cue = $cues[$idx]
		# 0秒字幕が連続していても、同じ開始時刻の字幕であれば順にたぐり寄せる
		while (($cue.Start -eq $cue.End) -and (($idx + 1) -lt $cues.Count) -and ($cues[$idx + 1].Start -eq $cue.Start)) {
			$next = $cues[$idx + 1]
			$cue = [PSCustomObject]@{ Start = $cue.Start ; End = $next.End ; Text = @($cue.Text) + @($next.Text) }
			$mergedCount++
			$idx++
		}
		$merged.Add($cue)
		$idx++
	}

	$sb = [System.Text.StringBuilder]::new()
	$no = 1
	foreach ($cue in $merged) {
		$null = $sb.Append(('{0}' -f $no)).Append("`n")
		$null = $sb.Append(('{0} --> {1}' -f $cue.Start, $cue.End)).Append("`n")
		foreach ($line in $cue.Text) { $null = $sb.Append($line).Append("`n") }
		$null = $sb.Append("`n")
		$no++
	}
	return [PSCustomObject]@{ Content = $sb.ToString() ; MergedCount = $mergedCount }
}

#----------------------------------------------------------------------
# 番組ファイルに埋め込まれた字幕の「0秒字幕」を修復
#----------------------------------------------------------------------
function Repair-SubtitleTiming {
	<#
		.SYNOPSIS
			mp4に埋め込まれた字幕から0秒字幕を検出し、マージして埋め込み直します。

		.DESCRIPTION
			ffprobeで字幕ストリームを調べ、ffmpegでSRTとして取り出して0秒字幕をマージします。
			マージ対象があった場合のみ、映像・音声はコピーのまま字幕だけを差し替えます。
			いずれかの手順に失敗した場合は、元のファイルを変更しません。

		.PARAMETER VideoPath
			対象のmp4ファイルのフルパスを指定します。

		.OUTPUTS
			[Boolean]
			字幕を修復してファイルを差し替えた場合は$true、それ以外は$falseを返します。

		.NOTES
			この関数は以下の処理を行います：
			1. ffprobeで字幕ストリームと言語を取得
			2. 各字幕ストリームをSRTとして一時ディレクトリに書き出し
			3. 0秒字幕をマージ(対象がなければ終了)
			4. 映像・音声をコピーしつつ、マージ後の字幕で新しいmp4を作成
			5. 同じディレクトリに複製してから元のファイルを置き換え
	#>
	[OutputType([Boolean])]
	Param ([Parameter(Mandatory = $true)][String]$VideoPath)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-Path -LiteralPath $VideoPath -PathType Leaf)) { return $false }
	if (!(Test-Path -LiteralPath $script:ffprobePath -PathType Leaf)) { return $false }
	$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tverrec_sub_{0}' -f [Guid]::NewGuid().ToString('N'))
	$stagedPath = ('{0}.subfix.tmp' -f $VideoPath)
	try {
		New-Item -ItemType Directory -Path $workDir -Force | Out-Null

		# 字幕ストリームの一覧(出現順のindexと言語)を取得
		$probeOutPath = Join-Path $workDir 'probe.txt'
		$probeArgs = ('-v error -select_streams s -show_entries stream=index:stream_tags=language -of csv=p=0 "{0}"' -f $VideoPath)
		Write-Debug ($script:msg.ExecCommand -f 'ffprobe', $script:ffprobePath, $probeArgs)
		$probe = Start-Process -FilePath $script:ffprobePath -ArgumentList $probeArgs -RedirectStandardOutput $probeOutPath -NoNewWindow -Wait -PassThru
		if (($probe.ExitCode -ne 0) -or !(Test-Path -LiteralPath $probeOutPath)) { return $false }
		$languages = @(Get-Content -LiteralPath $probeOutPath -Encoding UTF8 | Where-Object { $_.Trim() -ne '' } | ForEach-Object { ($_ -split ',')[1] })
		if ($languages.Count -eq 0) { return $false }

		# 字幕を取り出して0秒字幕をマージ
		$totalMerged = 0
		for ($i = 0 ; $i -lt $languages.Count ; $i++) {
			$srtPath = Join-Path $workDir ('sub{0}.srt' -f $i)
			$extractArgs = ('-hide_banner -v error -y -i "{0}" -map 0:s:{1} -c:s srt "{2}"' -f $VideoPath, $i, $srtPath)
			Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $extractArgs)
			$extract = Start-Process -FilePath $script:ffmpegPath -ArgumentList $extractArgs -NoNewWindow -Wait -PassThru
			if (($extract.ExitCode -ne 0) -or !(Test-Path -LiteralPath $srtPath)) { return $false }
			$result = Merge-ZeroDurationSubtitle -SrtText (Get-Content -LiteralPath $srtPath -Raw -Encoding UTF8)
			[System.IO.File]::WriteAllText($srtPath, $result.Content, [System.Text.UTF8Encoding]::new($false))
			$totalMerged += $result.MergedCount
		}
		if ($totalMerged -eq 0) { return $false }

		# 映像・音声などはそのまま、字幕のみ差し替えた新しいmp4を作成
		$outPath = Join-Path $workDir 'out.mp4'
		$inputArgs = ('-i "{0}"' -f $VideoPath)
		# * チャプターはデータストリームとしても複製されるため、-map_chapters側に任せてデータストリームは除外する
		$mapArgs = '-map 0 -map -0:s -map -0:d'
		for ($i = 0 ; $i -lt $languages.Count ; $i++) {
			$inputArgs += (' -i "{0}"' -f (Join-Path $workDir ('sub{0}.srt' -f $i)))
			$mapArgs += (' -map {0}:0' -f ($i + 1))
		}
		$metaArgs = ''
		for ($i = 0 ; $i -lt $languages.Count ; $i++) {
			if ($languages[$i] -and ($languages[$i] -ne 'und')) { $metaArgs += (' -metadata:s:s:{0} language={1}' -f $i, $languages[$i]) }
		}
		$remuxArgs = ('-hide_banner -v error -y {0} {1} -map_metadata 0 -map_chapters 0 -c copy -c:s mov_text{2} "{3}"' -f $inputArgs, $mapArgs, $metaArgs, $outPath)
		Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $remuxArgs)
		$remux = Start-Process -FilePath $script:ffmpegPath -ArgumentList $remuxArgs -NoNewWindow -Wait -PassThru
		if (($remux.ExitCode -ne 0) -or !(Test-Path -LiteralPath $outPath)) { return $false }
		if ((Get-Item -LiteralPath $outPath).Length -lt ((Get-Item -LiteralPath $VideoPath).Length * 0.9)) { return $false }

		# 字幕ストリーム数が変わっていないことを確認してから置き換え
		$checkOutPath = Join-Path $workDir 'check.txt'
		$checkArgs = ('-v error -select_streams s -show_entries stream=index -of csv=p=0 "{0}"' -f $outPath)
		$check = Start-Process -FilePath $script:ffprobePath -ArgumentList $checkArgs -RedirectStandardOutput $checkOutPath -NoNewWindow -Wait -PassThru
		if (($check.ExitCode -ne 0) -or (@(Get-Content -LiteralPath $checkOutPath | Where-Object { $_.Trim() -ne '' }).Count -ne $languages.Count)) { return $false }

		Copy-Item -LiteralPath $outPath -Destination $stagedPath -Force
		Move-Item -LiteralPath $stagedPath -Destination $VideoPath -Force
		return $true
	} catch {
		Write-Warning ($script:msg.SubtitleTimingRepairFailed)
		Write-Verbose $_.Exception.Message
		return $false
	} finally {
		Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
		Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}

#----------------------------------------------------------------------
# 番組の整合性チェック
#----------------------------------------------------------------------
function Invoke-IntegrityCheck {
	<#
		.SYNOPSIS
			ダウンロードした番組の整合性をチェックします。

		.DESCRIPTION
			ダウンロードした番組の整合性をチェックします。
			ffmpegまたはffprobeを使用して、ビデオファイルのエラーを検出します。

		.PARAMETER videoHist
			チェックする番組の履歴情報を指定します。

		.PARAMETER decodeOption
			デコードオプションを指定します。デフォルトは空文字列です。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオファイルのパスを取得
			2. チェックステータスを確認
			3. ffmpegまたはffprobeを使用してエラーを検出
			4. エラー数に基づいてチェック結果を記録
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)]$videoHist,
		[Parameter(Mandatory = $false)][String]$decodeOption = ''
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ffmpegProcessExitCode = 0
	$errorCount = 0
	$videoFilePath = Join-Path (Convert-Path $script:downloadBaseDir) $videoHist.videoPath
	try { New-Item -Path $script:ffmpegErrorLogPath -ItemType File -Force -ErrorAction Stop | Out-Null }
	catch { Write-Warning ($script:msg.FfmpegErrFileInitializeFailed) ; return }

	# これからチェックする番組のステータスをチェック
	$latestHists = Get-LatestHistory
	$targetHist = $latestHists.Where({ $_.videoPage -eq $videoHist.videoPage }) | Select-Object -First 1
	if ($targetHist) {
		$checkStatus = $targetHist.videoValidated
		if ($null -ne $checkStatus) {
			# 0:未チェック、1:チェック済、2:チェック中、3:チェック失敗、レコードなしは履歴が削除済み
			switch ($checkStatus) {
				# 「0:未チェック」のレコードは「2:チェック中」に変更したレコードを追記。(downloadDateは現在日時)
				'0' {
					# 該当のレコードを複製
					$targetHist.downloadDate = Get-TimeStamp
					$targetHist.videoValidated = '2'
					Wait-FileLock $script:histLockFilePath
					try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
					catch { Write-Warning ($script:msg.HistUpdateFailed) ; return }
					finally { Unlock-File $script:histLockFilePath | Out-Null }
					break
				}
				# 「0:未チェック」以外のステータスの際はスキップして次を処理
				'1' { Write-Output ($script:msg.ValidationCompleted) ; return }
				'2' { Write-Output ($script:msg.ValidationInProgress) ; return }
				'3' { Write-Output ($script:msg.ValidationFailed) ; return }
				default { Write-Warning ($script:msg.HistRecordRemoved -f $videoHist.videoPage) ; return }
			}
		}
	}

	if ($script:simplifiedValidation) {
		# ffprobeを使った簡易検査
		$ffprobeArgs = ('-hide_banner -v error -err_detect explode -i "{0}"' -f $videoFilePath)
		Write-Debug ($script:msg.ExecCommand -f 'ffprobe', $script:ffprobePath, $ffprobeArgs)
		$ffmpegProcessExitCode = Invoke-FFmpegProcess -filePath $script:ffprobePath -ffmpegArgs $ffprobeArgs -execName 'ffprobe'
	} else {
		# ffmpegを使った完全検査
		$ffmpegArgs = ('-hide_banner -v error -xerror {0} -i "{1}" -f null - ' -f $decodeOption, $videoFilePath)
		Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $ffmpegArgs)
		$ffmpegProcessExitCode = Invoke-FFmpegProcess -filePath $script:ffmpegPath -ffmpegArgs $ffmpegArgs -execName 'ffmpeg'
	}
	# ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffmpegErrorLogPath) {
			$errorCount = (Get-Content -LiteralPath $script:ffmpegErrorLogPath -ErrorAction Stop | Measure-Object -Line).Lines
			Get-Content -LiteralPath $script:ffmpegErrorLogPath -Encoding UTF8 -ErrorAction Stop | Write-Debug
		}
	} catch { Write-Warning ($script:msg.ErrorCountFailed) ; $errorCount = 9999999 }
	# エラーをカウントしたらファイルを削除
	try { if (Test-Path $script:ffmpegErrorLogPath) { Remove-Item -LiteralPath $script:ffmpegErrorLogPath -Force -ErrorAction Stop | Out-Null } }
	catch { Write-Warning ($script:msg.DeleteErrorFailed) }

	$latestHists = Get-LatestHistory
	$targetHist = $latestHists.Where({ $_.videoPage -eq $videoHist.videoPage }) | Select-Object -First 1
	if ($targetHist) {
		# 終了コードが0以外 または エラーが一定以上
		if ( ($ffmpegProcessExitCode -ne 0) -or ($errorCount -gt 30)) {
			Write-Warning ($script:msg.ValidationNG) ; Write-Verbose ($script:msg.ErrorCount -f $ffmpegProcessExitCode, $errorCount)
			# 「3:チェック失敗」に変更したレコードを追記。(downloadDateは現在日時)
			$targetHist.downloadDate = Get-TimeStamp
			$targetHist.videoValidated = '3'
			Wait-FileLock $script:histLockFilePath
			try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
			catch { Write-Warning ($script:msg.HistUpdateFailed) }
			finally { Unlock-File $script:histLockFilePath | Out-Null }
			# ファイルを削除
			try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction Stop | Out-Null }
			catch { Write-Warning ($script:msg.DeleteVideoFailed -f $videoFilePath) }
		} else {
			# 終了コードが0のときはダウンロード履歴にチェック済フラグを立てる
			Write-Output ($script:msg.ValidationOK)
			$targetHist.downloadDate = Get-TimeStamp
			$targetHist.videoValidated = '1'
			Wait-FileLock $script:histLockFilePath
			try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
			catch { Write-Warning ($script:msg.HistUpdateFailed) }
			finally { Unlock-File $script:histLockFilePath | Out-Null }
		}
	} else {
		Write-Warning ($script:msg.HistRecordNotFound)
		# 該当のレコードがない場合は履歴が削除済み。念の為ファイルも消しておく
		try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction Stop | Out-Null }
		catch { Write-Warning ($script:msg.DeleteVideoFailed -f $videoFilePath) }
	}
	Remove-Variable -Name videoFilePath, ffmpegProcessExitCode, errorCount, targetHist, checkStatus, latestHists -ErrorAction SilentlyContinue
}
#endregion 整合性チェック関連処理
