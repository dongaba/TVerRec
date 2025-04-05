###################################################################################
#
#		番組整合性チェック処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecでダウンロードした番組の整合性をチェックするスクリプト

	.DESCRIPTION
		ダウンロードした番組ファイルの整合性チェックとダウンロード履歴の管理を行います。
		以下の処理を順番に実行します：
		1. ダウンロード履歴のクリーンアップ
		2. 古い履歴レコードの削除
		3. 重複レコードの削除
		4. 番組ファイルの整合性チェック
		5. 未検証ファイルの再チェック

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。

	.NOTES
		前提条件:
		- Windows環境で実行する必要があります
		- PowerShell 7.0以上が必要です
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- ffmpegがインストールされている必要があります
		- ダウンロード履歴ファイルが存在する必要があります

		処理の流れ:
		1. 履歴ファイルの管理
		1.1 破損レコードの削除
		1.2 古いレコードの削除（設定された保持期間に基づく）
		1.3 重複レコードの削除
		2. 整合性チェック
		2.1 未検証ファイルの特定
		2.2 ffmpegによる動画ファイルの検証
		2.3 検証結果の記録
		3. 再検証処理
		3.1 検証中断ファイルの状態リセット
		3.2 未検証ファイルの再チェック
		4. 最終クリーンアップ
		4.1 履歴ファイルの最適化
		4.2 結果の確認

		検証内容:
		- 動画ファイルの存在確認
		- ffmpegによる動画ファイルのデコード確認
		- ファイルサイズの確認
		- 動画の再生時間確認

	.EXAMPLE
		# 通常モードで実行
		.\validate_video.ps1

		# GUIモードで実行
		.\validate_video.ps1 gui

	.OUTPUTS
		System.Void
		各処理の実行結果をコンソールに出力します。
		進捗状況はトースト通知でも表示されます。
		検証結果はダウンロード履歴ファイルに記録されます。
#>

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

if ($script:disableValidation) { Write-Warning ($script:msg.DisclaimerForNotValidating) ; exit 0 }

#======================================================================
# 未検証のファイルが0になるまでループ
if (Test-Path $script:histFilePath -PathType Leaf) {
	# videoPageごとに最新のdownloadDateを持つレコードを取得
	$latestHists = Get-LatestHistory
	# videoValidatedが「0:未チェック」のものをカウント
	$videoNotValidatedNum = ($latestHists.Where({ ($_.videoPath -ne '-- IGNORED --') -and ($_.videoValidated -eq '0') })).Count
} else { $videoNotValidatedNum = 0 }

while ($videoNotValidatedNum -ne 0) {
	#======================================================================
	# ダウンロード履歴から番組チェックが終わっていないものを読み込み
	Write-Output ('')
	Write-Output ($script:msg.MediumBoldBorder)
	Write-Output ($script:msg.IntegrityCheck)

	$latestHists = Get-LatestHistory
	$videoHists = $latestHists.Where({ $_.videoPath -ne '-- IGNORED --' }).Where({ $_.videoValidated -eq '0' })

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
		# videoPageごとに最新のdownloadDateを持つレコードを取得
		$latestHists = Get-LatestHistory
		# videoValidatedが「2:チェック中」のものをフィルタリングして、「0:未チェック」のレコード追加
		$newRecords = $latestHists.Where({ $_.videoValidated -eq '2' }).ForEach({
				$_.videoValidated = '0'
				$_.downloadDate = Get-TimeStamp
				$_
			})
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		try { $newRecords | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
		catch { Throw ($script:msg.UpdateFailed -f $script:msg.HistFile) }
		finally { Unlock-File $script:histLockFilePath | Out-Null }
		# videoPageごとに最新のdownloadDateを持つレコードを取得
		$latestHists = Get-LatestHistory
		# videoValidatedが「0:未チェック」のものをカウント
		$videoNotValidatedNum = ($latestHists.Where({ ($_.videoPath -ne '-- IGNORED --') -and ($_.videoValidated -eq '0') -and ($_.videoValidated -ne '3') })).Count
	} else { $videoNotValidatedNum = 0 }
}

# ダウンロード履歴の重複削除
Repair-HistoryFile

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
