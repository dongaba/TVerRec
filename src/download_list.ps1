###################################################################################
#
#		リストダウンロード処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのダウンロードリストから番組をダウンロードするスクリプト

	.DESCRIPTION
		download_list.txtに記載された番組URLを順次ダウンロードします。
		以下の処理を順番に実行します：
		1. ダウンロードリストの読み込み
		2. ダウンロード履歴との照合
		3. 番組の一括ダウンロード
		4. 一時ファイルの削除

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。

	.NOTES
		前提条件:
		- Windows環境で実行する必要があります
		- PowerShell 7.0以上を推奨です
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- download_list.txtにダウンロードしたい番組のURLが記載されている必要があります
		- 十分なディスク容量が必要です

		処理の流れ:
		1. 初期設定
		1.1 環境チェック
		1.2 トークンの取得
		2. ダウンロードリストの処理
		2.1 リストファイルの読み込み
		2.2 ダウンロード履歴との照合
		2.3 ダウンロード対象の特定
		3. ダウンロード処理
		3.1 空き容量のチェック
		3.2 並列ダウンロードの制御
		3.3 個別番組のダウンロード
		4. 後処理
		4.1 ダウンロード完了の待機
		4.2 一時ファイルの削除

	.EXAMPLE
		# 通常モードで実行
		.\download_list.ps1

		# GUIモードで実行
		.\download_list.ps1 gui

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
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Invoke-RequiredFileCheck
Suspend-Process
Get-Token
# ダウンロードリストを読み込み
$listLinks = @(Get-LinkFromDownloadList)
if ($null -eq $listLinks) { Write-Warning ($script:msg.DownloadListZero) ; exit 0 }
$keyword = $script:msg.KeywordForListDownload

# URLがすでにダウンロード履歴に存在する場合は検索結果から除外
if ($listLinks.Count -ne 0) { $videoLinks, $processedCount = Invoke-HistoryMatchCheck $listLinks }
else { $videoLinks = @() ; $processedCount = 0 }
$videoTotal = $videoLinks.Count
Write-Output ('')
if ($videoTotal -eq 0) { Write-Output ($script:msg.VideoCountWhenZero -f $videoTotal, $processedCount) }
else { Write-Output ($script:msg.VideoCountNonZero -f $videoTotal, $processedCount) }

# 処理時間の推計
$totalStartTime = Get-Date
$secRemaining = -1

$toastShowParams = @{
	Text1      = $script:msg.ListDownloading
	Text2      = $script:msg.ExtractAndDownloadVideoFromLists
	WorkDetail = $script:msg.Loading
	Tag        = $script:appName
	Silent     = $false
	Group      = 'List'
}
Show-ProgressToast @toastShowParams

# ジョブを管理
$script:jobList = @()

# スクリプト終了時にジョブを停止
Register-EngineEvent PowerShell.Exiting -Action {
	foreach ($jobId in $script:jobList) {
		Stop-Job -Id $jobId -Force -ErrorAction SilentlyContinue
		Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
	}
} | Out-Null

#----------------------------------------------------------------------
# 個々の番組ダウンロードここから
$videoNum = 0
foreach ($videoLink in $videoLinks) {
	$videoNum++
	# ダウンロード先ディレクトリの存在確認先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (!(Test-Path $script:downloadBaseDir -PathType Container)) { throw ('❌️ 番組ダウンロード先ディレクトリにアクセスできません。終了します') }

	# 空き容量少ないときは中断
	if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
	if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

	# 進捗率の計算
	$secElapsed = (Get-Date) - $totalStartTime
	if ($videoNum -ne 0) {
		$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $videoNum) * ($videoTotal - $videoNum))
		$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
	}

	# 進捗情報の更新
	$toastUpdateParams = @{
		Title     = $script:msg.ListDownloading
		Rate      = [Float]($videoNum / $videoTotal)
		LeftText  = ('{0}/{1}' -f $videoNum, $videoTotal)
		RightText = $minRemaining
		Tag       = $script:appName
		Group     = 'List'
	}
	Update-ProgressToast @toastUpdateParams

	Write-Output ($script:msg.ShortBoldBorder)
	Write-Output ('{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)
	# youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	Wait-YtdlProcess $script:parallelDownloadFileNum
	Suspend-Process

	# TVer番組ダウンロードのメイン処理
	Invoke-VideoDownload -Keyword $keyword -episodeID $videoLink.Replace('https://tver.jp/episodes/', '') -Force $false
}
#----------------------------------------------------------------------

# youtube-dlのプロセスが終わるまで待機
Write-Output ('')
Write-Output ($script:msg.WaitingDownloadCompletion)
Wait-DownloadCompletion

# リネームに失敗したファイルを削除
Write-Output ('')
Write-Output ($script:msg.DeleteFilesFailedToRename)
Remove-UnRenamedTempFile

$toastUpdateParams = @{
	Title     = $script:msg.ListDownloading
	Rate      = '1'
	LeftText  = ''
	RightText = $script:msg.Completed
	Tag       = $script:appName
	Group     = 'List'
}
Update-ProgressToast @toastUpdateParams

Remove-Variable -Name args, listLinks, keyword, videoLinks, processedCount, videoTotal, totalStartTime, secRemaining, toastShowParams, videoNum, videoLink, secElapsed, minRemaining, toastUpdateParams -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.ListDownloadCompleted)
Write-Output ($script:msg.LongBoldBorder)
