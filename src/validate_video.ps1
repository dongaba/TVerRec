###################################################################################
#
#		番組整合性チェック処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Invoke-RequiredFileCheck
Suspend-Process

#======================================================================
# ダウンロード履歴ファイルのクリーンアップ
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.DeleteCorruptedRecords)

$toastShowParams = @{
	Text1      = $script:msg.CheckingIntegrity
	Text2      = $script:msg.IntegrityCheckStep1
	WorkDetail = ''
	Tag        = $script:appName
	Silent     = $false
	Group      = 'Validate'
}
Show-ProgressToast @toastShowParams

# ダウンロード履歴の破損レコード削除
Optimize-HistoryFile

Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.DeleteOldRecords)

$toastShowParams.Text2 = ($script:msg.IntegrityCheckStep2 -f $script:histRetentionPeriod)
Show-ProgressToast @toastShowParams

# 指定日以上前に処理したものはダウンロード履歴から削除
Limit-HistoryFile -RetentionPeriod $script:histRetentionPeriod

Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.RemoveDuplicates)

$toastShowParams.Text2 = $script:msg.IntegrityCheckStep3
Show-ProgressToast @toastShowParams

# ダウンロード履歴の重複削除
Repair-HistoryFile

if ($script:disableValidation) {
	Write-Warning ($script:msg.DisclaimerForNotValidating)
	exit 0
}

#======================================================================
# 未検証のファイルが0になるまでループ
$videoNotValidatedNum = 0
if (Test-Path $script:histFilePath -PathType Leaf) {
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		# videoPageごとに最新のdownloadDateを持つレコードを取得
		$latestHists = $videoHists | Group-Object -Property 'videoPage' | ForEach-Object {
			$_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1
		}
		# videoValidatedが「0:未チェック」のものをカウント
		$videoNotValidatedNum = @($latestHists.Where({ $_.videoValidated -eq '0' })).Count
	} catch { Throw ($script:msg.LoadFailed -f $script:msg.HistFile) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
} else { $videoNotValidatedNum = 0 }

while ($videoNotValidatedNum -ne 0) {
	#======================================================================
	# ダウンロード履歴から番組チェックが終わっていないものを読み込み
	Write-Output ('')
	Write-Output ($script:msg.MediumBoldBorder)
	Write-Output ($script:msg.IntegrityCheck)

	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$videoHists = @((Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Where({ $_.videoPath -ne '-- IGNORED --' }).Where({ $_.videoValidated -eq '0' }) )
	} catch { Write-Warning ($script:msg.LoadFailed -f $script:msg.HistFile) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }

	if (($null -eq $videoHists) -or ($videoHists.Count -eq 0)) {
		# チェックする番組なし
		Write-Output ($script:msg.AllValidated)
		Write-Output ('')
	} else {
		# ダウンロードファイルをチェック
		$validateTotal = 0
		$validateTotal = $videoHists.Count
		# ffmpegのデコードオプションの設定
		if ($script:forceSoftwareDecodeFlag) { $decodeOption = '' }
		else {
			if ($script:ffmpegDecodeOption) {
				Write-Output ($script:msg.MediumBoldBorder)
				Write-Output ($script:msg.NotifyFfmpegOptions1)
				Write-Output ('　　　{0}' -f $ffmpegDecodeOption)
				Write-Output ($script:msg.NotifyFfmpegOptions2)
				Write-Output ($script:msg.NotifyFfmpegOptions3)
				Write-Output ($script:msg.NotifyFfmpegOptions4)
				Write-Output ($script:msg.MediumBoldBorder)
			}
			$decodeOption = $script:ffmpegDecodeOption
		}

		$toastShowParams.Text2 = $script:msg.IntegrityCheckStep4
		$toastShowParams.WorkDetail = $script:msg.CalculatingRemainingTime
		Show-ProgressToast @toastShowParams

		#----------------------------------------------------------------------
		$totalStartTime = Get-Date
		$validateNum = 0
		foreach ($videoHist in $videoHists) {
			# 処理時間の推計
			$secElapsed = (Get-Date) - $totalStartTime
			$secRemaining = -1
			if ($validateNum -ne 0) {
				$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $validateNum) * ($validateTotal - $validateNum))
				$minRemaining = ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($secRemaining / 60)))
				$progressRate = [Float]($validateNum / $validateTotal)
			} else { $minRemaining = '' ; $progressRate = 0 }
			$validateNum++

			$toastUpdateParams = @{
				Title     = $videoHist.videoName
				Rate      = $progressRate
				LeftText  = ('{0}/{1}' -f $validateNum, $validateTotal)
				RightText = $minRemaining
				Tag       = $script:appName
				Group     = 'Validate'
			}
			Update-ProgressToast @toastUpdateParams

			if (!(Test-Path $script:downloadBaseDir -PathType Container)) { Throw ($script:msg.DownloadDirNotAccessible) }
			# 番組の整合性チェック
			Write-Output ('{0}/{1} - {2}' -f $validateNum, $validateTotal, $videoHist.videoPath)
			Invoke-IntegrityCheck -VideoHist $videoHist -DecodeOption $decodeOption
			Suspend-Process
			Start-Sleep -Seconds 1
		}
		#----------------------------------------------------------------------
	}

	#======================================================================
	# ダウンロード履歴から整合性検証が終わっていないもののステータスを初期化
	Write-Output ('')
	Write-Output ($script:msg.MediumBoldBorder)
	Write-Output ($script:msg.ClearValidationStatus)

	$toastShowParams.Text2 = $script:msg.IntegrityCheckStep5
	$toastShowParams.WorkDetail = ''
	Show-ProgressToast @toastShowParams

	if (Test-Path $script:histFilePath -PathType Leaf) {
		try {
			while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
			$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			# videoPageごとに最新のdownloadDateを持つレコードを取得
			$latestHists = $videoHists | Group-Object -Property 'videoPage' | ForEach-Object {
				$_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1
			}
			# videoValidatedが「2:チェック中」のものをフィルタリングして、「0:未チェック」のレコード追加
			$newRecords = $latestHists | Where-Object { $_.videoValidated -eq '2' } | ForEach-Object {
				$_.videoValidated = '0'
				$_.downloadDate = Get-TimeStamp
				$_
			}
			$newRecords | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append
			Start-Sleep -Seconds 1

			$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			# videoPageごとに最新のdownloadDateを持つレコードを取得
			$latestHists = $videoHists | Group-Object -Property 'videoPage' | ForEach-Object {
				$_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1
			}
			# videoValidatedが「0:未チェック」のものをカウント
			$videoNotValidatedNum = @($latestHists.Where({ $_.videoValidated -eq '0' })).Count
		} catch { Throw ($script:msg.UpdateFailed -f $script:msg.HistFile) }
		finally { Unlock-File $script:histLockFilePath | Out-Null }
	} else { $videoNotValidatedNum = 0 }
}

#======================================================================
# 完了処理
$toastUpdateParams = @{
	Title     = $script:msg.ValidateVideo
	Rate      = '1'
	LeftText  = ''
	RightText = $script:msg.Completed
	Tag       = $script:appName
	Group     = 'Validate'
}
Update-ProgressToast @toastUpdateParams

Remove-Variable -Name args, toastShowParams, videoNotValidatedNum, videoHists, videoHist, uncheckedVideo, validateTotal, decodeOption, totalStartTime, validateNum, secElapsed, secRemaining, minRemaining, progressRate, toastUpdateParams -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.IntegrityCheckCompleted)
Write-Output ($script:msg.LongBoldBorder)
