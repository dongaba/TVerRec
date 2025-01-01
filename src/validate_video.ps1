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
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません') }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Invoke-RequiredFileCheck
Suspend-Process

#======================================================================
# ダウンロード履歴ファイルのクリーンアップ
Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('ダウンロード履歴の不整合レコードを削除します')

$toastShowParams = @{
	Text1      = 'ダウンロードファイルの整合性検証中'
	Text2      = '　処理1/5 - 破損レコードを削除'
	WorkDetail = ''
	Tag        = $script:appName
	Silent     = $false
	Group      = 'Validate'
}
Show-ProgressToast @toastShowParams

# ダウンロード履歴の破損レコード削除
Optimize-HistoryFile

Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('古いダウンロード履歴を削除します')

$toastShowParams.Text2 = ('　処理2/5 - {0}日以上前のダウンロード履歴を削除' -f $script:histRetentionPeriod)
Show-ProgressToast @toastShowParams

# 指定日以上前に処理したものはダウンロード履歴から削除
Limit-HistoryFile -RetentionPeriod $script:histRetentionPeriod

Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('ダウンロード履歴の重複レコードを削除します')

$toastShowParams.Text2 = '　処理3/5 - ダウンロード履歴の重複レコードを削除'
Show-ProgressToast @toastShowParams

# ダウンロード履歴の重複削除
Repair-HistoryFile

if ($script:disableValidation) {
	Write-Warning ('⚠️ ダウンロードファイルの整合性検証が無効化されているので、検証せずに終了します')
	exit 0
}

#======================================================================
# 未検証のファイルが0になるまでループ
$script:validationFailed = $false
$videoNotValidatedNum = 0
if (Test-Path $script:histFilePath -PathType Leaf) {
	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$videoNotValidatedNum = @((Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Where({ $_.videoPath -ne '-- IGNORED --' }).Where({ $_.videoValidated -eq '0' })).Count
	} catch { Throw ('❌️ ダウンロード履歴の読み込みに失敗しました') }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
} else { $videoNotValidatedNum = 0 }

while ($videoNotValidatedNum -ne 0) {
	#======================================================================
	# ダウンロード履歴から番組チェックが終わっていないものを読み込み
	Write-Output ('')
	Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
	Write-Output ('整合性検証が終わっていない番組を検証します')

	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$videoHists = @((Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Where({ $_.videoPath -ne '-- IGNORED --' }).Where({ $_.videoValidated -eq '0' }) )
	} catch { Write-Warning ('⚠️ ダウンロード履歴の読み込みに失敗しました') }
	finally { Unlock-File $script:histLockFilePath | Out-Null }

	if (($null -eq $videoHists) -or ($videoHists.Count -eq 0)) {
		# チェックする番組なし
		Write-Output ('✅️ すべての番組を検証済です')
		Write-Output ('')
	} else {
		# ダウンロードファイルをチェック
		$validateTotal = 0
		$validateTotal = $videoHists.Count
		# ffmpegのデコードオプションの設定
		if ($script:forceSoftwareDecodeFlag) { $decodeOption = '' }
		else {
			if ($script:ffmpegDecodeOption -ne '') {
				Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
				Write-Output ('💡 ffmpegのデコードオプションが設定されてます')
				Write-Output ('　　　{0}' -f $ffmpegDecodeOption)
				Write-Output ('💡 もし整合性検証がうまく進まない場合は、以下のどちらかをお試しください')
				Write-Output ('　・user_setting.ps1 でデコードオプションを変更する')
				Write-Output ('　・user_setting.ps1 で $script:forceSoftwareDecodeFlag = $true と設定する')
				Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
			}
			$decodeOption = $script:ffmpegDecodeOption
		}

		$toastShowParams.Text2 = '　処理4/5 - ファイルを検証'
		$toastShowParams.WorkDetail = '残り時間計算中'
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
				$minRemaining = ('残り時間 {0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
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

			if (!(Test-Path $script:downloadBaseDir -PathType Container)) { Throw ('❌️ 番組ダウンロード先ディレクトリにアクセスできません。終了します。') }
			# 番組の整合性チェック
			Write-Output ('{0}/{1} - {2}' -f $validateNum, $validateTotal, $videoHist.videoPath)
			Invoke-ValidityCheck -VideoHist $videoHist -DecodeOption $decodeOption
			Suspend-Process
			Start-Sleep -Seconds 1
		}
		#----------------------------------------------------------------------
	}

	#======================================================================
	# ダウンロード履歴から整合性検証が終わっていないもののステータスを初期化
	Write-Output ('')
	Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
	Write-Output ('ダウンロード履歴から検証が終わっていない番組のステータスを変更します')

	$toastShowParams.Text2 = '　処理5/5 - 未検証のファイルのステータスを変更'
	$toastShowParams.WorkDetail = ''
	Show-ProgressToast @toastShowParams

	if (Test-Path $script:histFilePath -PathType Leaf) {
		try {
			while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$videoHists = @(Import-Csv -Path $script:histFilePath -Encoding UTF8)
			foreach ($uncheckedVideo in ($videoHists).Where({ $_.videoValidated -eq 2 })) { $uncheckedVideo.videoValidated = '0' }
			$videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
			$videoNotValidatedNum = @((Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Where({ $_.videoPath -ne '-- IGNORED --' }).Where({ $_.videoValidated -eq '0' })).Count
		} catch { Throw ('❌️ ダウンロード履歴の更新に失敗しました') }
		finally { Unlock-File $script:histLockFilePath | Out-Null }
	} else { $videoNotValidatedNum = 0 }
}

#======================================================================
# 完了処理
$toastUpdateParams = @{
	Title     = 'ダウンロードファイルの整合性検証中'
	Rate      = '1'
	LeftText  = ''
	RightText = '完了'
	Tag       = $script:appName
	Group     = 'Validate'
}
Update-ProgressToast @toastUpdateParams

Remove-Variable -Name args, toastShowParams, videoNotValidatedNum, videoHists, videoHist, uncheckedVideo, validateTotal, decodeOption, totalStartTime, validateNum, secElapsed, secRemaining, minRemaining, progressRate, toastUpdateParams -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('番組整合性チェック処理を終了しました。')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
