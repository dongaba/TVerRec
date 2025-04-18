###################################################################################
#
#		リストダウンロード処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのダウンロードリストから番組をダウンロードするスクリプト

	.DESCRIPTION
		list.csvに記載された番組URLを順次ダウンロードします。
		以下の処理を順番に実行します：
		1. ダウンロードリストの読み込み
		2. ダウンロード履歴との照合
		3. 番組の一括ダウンロード
		4. 一時ファイルの削除

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。
		- 指定なし: 通常モードで実行
		- 'gui': GUIモードで実行
		- その他の値: 通常モードで実行

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- list.csvにダウンロードしたい番組のURLが記載されている必要があります
		- 十分なディスク容量が必要です
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

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
		このスクリプトは以下の出力を行います：
		- コンソールへの進捗状況の表示
		- トースト通知による進捗状況の表示
		- エラー発生時のエラーメッセージ
		- 処理完了時のサマリー情報
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
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	# 必須ファイルのチェックとトークンの取得
	Invoke-RequiredFileCheck
	Suspend-Process
	Get-Token

	# ダウンロードリストを読み込み
	$resultLinks = @(Get-LinkFromDownloadList)
	if ($null -eq $resultLinks) { Write-Warning ($script:msg.DownloadListZero) ; exit 0 }
	$resultLinks = $resultLinks -ne ''
	$keyword = $script:msg.KeywordForListDownload

	# 履歴チェックと重複排除
	if ($resultLinks.Count -ne 0) { $episodeIDs, $processedCount = Invoke-HistoryMatchCheck $resultLinks }
	else { $episodeIDs = @() ; $processedCount = 0 }
	$videoTotal = $episodeIDs.Count
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
	foreach ($episodeID in $episodeIDs) {
		$videoNum++
		# ディレクトリの存在確認
		if (!(Test-Path $script:downloadBaseDir -PathType Container)) { throw $script:msg.DownloadDirNotAccessible }

		# 空き容量少ないときは中断
		if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
		if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

		# 進捗率の計算
		$secElapsed = (Get-Date) - $totalStartTime
		if ($videoNum -ne 0) {
			$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $videoNum) * ($videoTotal - $videoNum))
			$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
		} else { $minRemaining = '' }

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
		Write-Output ('{0}/{1} - {2}' -f $videoNum, $videoTotal, $episodeID)

		# ダウンロードプロセスの制御
		Wait-YtdlProcess $script:parallelDownloadFileNum
		Suspend-Process

		# TVer番組ダウンロードのメイン処理
		Invoke-VideoDownload -Keyword $keyword -episodeID $episodeID -Force $false
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

	Write-Output ('')
	Write-Output ($script:msg.LongBoldBorder)
	Write-Output ($script:msg.ListDownloadCompleted)
	Write-Output ($script:msg.LongBoldBorder)
} catch {
	Write-Error "Error occurred: $($_.Exception.Message)"
	Write-Error "Stack trace: $($_.ScriptStackTrace)"
	throw
} finally {
	# 変数のクリーンアップ
	Remove-Variable -Name args, listLinks, keyword, videoLinks, processedCount, videoTotal,
	totalStartTime, secRemaining, toastShowParams, videoNum, videoLink, secElapsed,
	minRemaining, toastUpdateParams -ErrorAction SilentlyContinue

	# ガベージコレクション
	Invoke-GarbageCollection
}
