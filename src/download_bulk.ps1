###################################################################################
#
#		一括ダウンロード処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecの一括ダウンロード処理を実行するスクリプト

	.DESCRIPTION
		TVerRecの一括ダウンロード処理を実行するスクリプトです。
		以下の処理を順番に実行します：
		1. キーワードリストの読み込み
		2. 各キーワードに対する動画検索
		3. ダウンロード履歴との照合
		4. 動画のダウンロード処理
		5. リネームに失敗したファイルの削除

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。

	.NOTES
		前提条件:
		- Windows環境で実行する必要があります
		- PowerShell 7.0以上が必要です
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 十分なディスク容量が必要です

		処理の流れ:
		1. 環境設定の読み込み
		2. キーワードリストの読み込み
		3. 各キーワードに対する処理
		3.1 動画リンクの取得
		3.2 ダウンロード履歴との照合
		3.3 動画のダウンロード
		4. ダウンロード完了待機
		5. リネーム失敗ファイルの削除

	.EXAMPLE
		# 通常モードで実行
		.\download_bulk.ps1

		# GUIモードで実行
		.\download_bulk.ps1 gui

	.OUTPUTS
		System.Void
		各処理の実行結果をコンソールに出力します。
		進捗状況はトースト通知でも表示されます。
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
Get-Token
$keywords = @(Read-KeywordList)
$keywordNum = 0
$keywordTotal = $keywords.Count

$toastShowParams = @{
	Text1   = $script:msg.BulkDownloading
	Text2   = $script:msg.ExtractAndDownloadVideoFromKeywords
	Detail1 = $script:msg.Loading
	Detail2 = $script:msg.Loading
	Tag     = $script:appName
	Silent  = $false
	Group   = 'Bulk'
}
Show-ProgressToast2Row @toastShowParams

# ジョブを管理
$script:jobList = @()

# スクリプト終了時にジョブを停止
Register-EngineEvent PowerShell.Exiting -Action {
	foreach ($jobId in $script:jobList) {
		Stop-Job -Id $jobId -Force -ErrorAction SilentlyContinue
		Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
	}
} | Out-Null

#======================================================================
# 個々のキーワードチェックここから
$totalStartTime = Get-Date
foreach ($keyword in $keywords) {
	$keyword = Remove-TabSpace($keyword)
	Write-Output ('')
	Write-Output ($script:msg.MediumBoldBorder)
	Write-Output ('{0}' -f $keyword)

	# 空き容量少ないときは中断
	if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
	if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

	# 処理時間の推計
	$secElapsed = (Get-Date) - $totalStartTime
	if ($keywordNum -ne 0) { $secRemaining1 = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $keywordNum) * ($keywordTotal - $keywordNum)) }
	else { $secRemaining1 = '' }

	# キーワード数のインクリメント
	$keywordNum++

	# 進捗情報の更新
	$toastUpdateParams = @{
		Title1     = (Remove-TabSpace ($keyword))
		Rate1      = [Float]($keywordNum / $keywordTotal)
		LeftText1  = ('{0}/{1}' -f $keywordNum, $keywordTotal)
		RightText1 = $secRemaining1
		Title2     = ''
		Rate2      = 0
		LeftText2  = ''
		RightText2 = ''
		Tag        = $script:appName
		Group      = 'Bulk'
	}
	Update-ProgressToast2Row @toastUpdateParams

	$keyword = (Get-ContentWoComment($keyword.Replace('https://tver.jp/', '').Trim()))
	$resultLinks = @(Get-VideoLinksFromKeyword $keyword)

	# URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	if ($resultLinks.Count -ne 0) { $videoLinks, $processedCount = Invoke-HistoryMatchCheck $resultLinks }
	else { $videoLinks = @() ; $processedCount = 0 }
	$videoTotal = $videoLinks.Count
	if ($videoTotal -eq 0) { Write-Output ($script:msg.VideoCountWhenZero -f $videoTotal, $processedCount) }
	else { Write-Output ($script:msg.VideoCountNonZero -f $videoTotal, $processedCount) }

	#----------------------------------------------------------------------
	# 個々の番組ダウンロードここから
	$videoNum = 0
	foreach ($videoLink in $videoLinks) {
		$videoNum++
		# ダウンロード先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
		if (!(Test-Path $script:downloadBaseDir -PathType Container)) { Throw ($script:msg.DownloadDirNotAccessible) }

		# 空き容量少ないときは中断
		if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
		if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

		# 進捗情報の更新
		$toastUpdateParams.Title2 = $videoLink
		$toastUpdateParams.Rate2 = [Float]($videoNum / $videoTotal)
		$toastUpdateParams.LeftText2 = ('{0}/{1}' -f $videoNum, $videoTotal)
		Update-ProgressToast2Row @toastUpdateParams

		Write-Output ($script:msg.ShortBoldBorder)
		Write-Output ('{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)

		# youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
		Wait-YtdlProcess $script:parallelDownloadFileNum
		Suspend-Process

		# TVer番組ダウンロードのメイン処理
		Invoke-VideoDownload -Keyword $keyword -episodeID $videoLink.Replace('https://tver.jp/episodes/', '') -Force $false
	}
	#----------------------------------------------------------------------

}
#======================================================================

# youtube-dlのプロセスが終わるまで待機
Write-Output ('')
Write-Output ($script:msg.WaitingDownloadCompletion)
Wait-DownloadCompletion

# リネームに失敗したファイルを削除
Write-Output ('')
Write-Output ($script:msg.DeleteFilesFailedToRename)
Remove-UnRenamedTempFile

$toastUpdateParams = @{
	Title1     = $script:msg.ExtractingVideoFromKeywords
	Rate1      = 1
	LeftText1  = ''
	RightText1 = 0
	Title2     = $script:msg.DownloadingVideo
	Rate2      = 1
	LeftText2  = ''
	RightText2 = '0'
	Tag        = $script:appName
	Group      = 'Bulk'
}
Update-ProgressToast2Row @toastUpdateParams

Remove-Variable -Name args, keywords, keywordNum, keywordTotal, toastShowParams, totalStartTime, keyword, resultLinks, processedCount, videoLinks, videoTotal, secElapsed, secRemaining1, videoLink, toastUpdateParams, videoNum -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.BulkDownloadCompleted)
Write-Output ($script:msg.LongBoldBorder)
