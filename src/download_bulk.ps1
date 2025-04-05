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
		- PowerShell 7.0以上を推奨です
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
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	# 必須ファイルのチェックとトークンの取得
	Write-Output ($script:msg.LongBoldBorder)
	Invoke-RequiredFileCheck
	Suspend-Process
	Get-Token

	# キーワードリストの読み込み
	$keywords = @(Read-KeywordList)
	if ($keywords.Count -eq 0) { throw 'キーワードリストが空です。処理を中断します。' }
	else { $keywordTotal = $keywords.Count }
	$keywordProcessed = 0

	# 進捗表示の初期化
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

	# ジョブ管理の初期化
	$script:jobList = @()
	Register-EngineEvent PowerShell.Exiting -Action {
		foreach ($jobId in $script:jobList) {
			Stop-Job -Id $jobId -Force -ErrorAction SilentlyContinue
			Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
		}
	} | Out-Null

	#======================================================================
	# ビデオリンクの収集
	#======================================================================
	$totalStartTime = Get-Date
	$uniqueVideoLinks = [System.Collections.Generic.HashSet[string]]::new()
	$videoKeywordMap = @{}

	Write-Output ($script:msg.LongBoldBorder)
	Write-Information 'キーワードからビデオリンクを収集中...'
	foreach ($keyword in $keywords) {
		$keywordProcessed++
		$keyword = Remove-TabSpace($keyword)

		Write-Output ('')
		Write-Output ($script:msg.MediumBoldBorder)
		Write-Output ('{0}' -f $keyword)

		# 空き容量少ないときは中断
		if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
		if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

		# 進捗情報の更新
		$secElapsed = (Get-Date) - $totalStartTime
		$secRemaining = if ($keywordProcessed -ne 0) { [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $keywordProcessed) * ($keywordTotal - $keywordProcessed)) }
		else { '' }

		$toastUpdateParams = @{
			Title1     = (Remove-TabSpace ($keyword))
			Rate1      = [Float]($keywordProcessed / $keywordTotal)
			LeftText1  = ('{0}/{1}' -f $keywordProcessed, $keywordTotal)
			RightText1 = $secRemaining
			Title2     = ''
			Rate2      = 0
			LeftText2  = ''
			RightText2 = ''
			Tag        = $script:appName
			Group      = 'Bulk'
		}
		Update-ProgressToast2Row @toastUpdateParams

		# キーワードの正規化とビデオリンク取得
		$keyword = Get-ContentWoComment($keyword.Replace('https://tver.jp/', '').Trim())
		$resultLinks = @(Get-VideoLinksFromKeyword $keyword)

		# 履歴チェックと重複排除
		if ($resultLinks.Count -ne 0) {
			$videoLinks, $processedCount = Invoke-HistoryMatchCheck $resultLinks
			foreach ($link in $videoLinks) {
				if ($uniqueVideoLinks.Add($link)) {
					$videoKeywordMap[$link] = $keyword
				}
			}
		} else { $videoLinks = @() ; $processedCount = 0 }

		# 結果の表示
		$videoCount = $videoLinks.Count
		if ($videoCount -eq 0) { Write-Output ($script:msg.VideoCountWhenZero -f $videoCount, $processedCount) }
		else { Write-Output ($script:msg.VideoCountNonZero -f $videoCount, $processedCount) }
	}

	#======================================================================
	# ビデオのダウンロード
	#======================================================================
	$videoTotal = $uniqueVideoLinks.Count
	$videoProcessed = 0

	Write-Output ('')
	Write-Output ($script:msg.LongBoldBorder)
	Write-Output ('全 {0} 件のビデオをダウンロードします' -f $videoTotal)

	foreach ($videoLink in $uniqueVideoLinks) {
		$videoProcessed++
		$keyword = $videoKeywordMap[$videoLink]

		# ディレクトリの存在確認
		if (!(Test-Path $script:downloadBaseDir -PathType Container)) { throw $script:msg.DownloadDirNotAccessible }

		# 空き容量少ないときは中断
		if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
		if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

		# 進捗情報の更新
		$toastUpdateParams.Title2 = $videoLink
		$toastUpdateParams.Rate2 = [Float]($videoProcessed / $videoTotal)
		$toastUpdateParams.LeftText2 = ('{0}/{1}' -f $videoProcessed, $videoTotal)
		Update-ProgressToast2Row @toastUpdateParams

		Write-Output ($script:msg.ShortBoldBorder)
		Write-Output ('{0}/{1} - {2}' -f $videoProcessed, $videoTotal, $videoLink)

		# ダウンロードプロセスの制御
		Wait-YtdlProcess $script:parallelDownloadFileNum
		Suspend-Process

		# ビデオのダウンロード
		Invoke-VideoDownload -Keyword $keyword -episodeID $videoLink.Replace('https://tver.jp/episodes/', '') -Force $false
	}

	#======================================================================
	# 後処理
	#======================================================================
	# youtube-dlのプロセスが終わるまで待機
	Write-Output ('')
	Write-Output ($script:msg.WaitingDownloadCompletion)
	Wait-DownloadCompletion

	# リネームに失敗したファイルを削除
	Write-Output ('')
	Write-Output ($script:msg.DeleteFilesFailedToRename)
	Remove-UnRenamedTempFile

	# 最終進捗表示
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

	# 完了メッセージ
	Write-Output ('')
	Write-Output ($script:msg.LongBoldBorder)
	Write-Output ($script:msg.BulkDownloadCompleted)
	Write-Output ($script:msg.LongBoldBorder)
} catch {
	Write-Error "Error occurred: $($_.Exception.Message)"
	Write-Error "Stack trace: $($_.ScriptStackTrace)"
	throw
} finally {
	# 変数のクリーンアップ
	Remove-Variable -Name args, keywords, keywordTotal, keywordProcessed, toastShowParams,
	totalStartTime, keyword, resultLinks, processedCount, videoLinks, videoCount,
	secElapsed, secRemaining, videoLink, toastUpdateParams, videoProcessed,
	uniqueVideoLinks, videoKeywordMap, errorCount, maxErrors -ErrorAction SilentlyContinue

	# ガベージコレクション
	Invoke-GarbageCollection
}
