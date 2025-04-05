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
	$keywordNum = 0

	# 進捗表示の初期化
	$toastShowParams = @{
		Text1      = $script:msg.BulkDownloading
		Text2      = $script:msg.ExtractAndDownloadVideoFromKeywords
		WorkDetail = $script:msg.Loading
		Tag        = $script:appName
		Silent     = $false
		Group      = 'Bulk'
	}
	Show-ProgressToast @toastShowParams

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
	$linkCollectionStartTime = Get-Date
	$uniqueVideoLinks = [System.Collections.Generic.HashSet[string]]::new()
	$videoKeywordMap = @{}

	Write-Output ($script:msg.LongBoldBorder)
	Write-Information 'キーワードからビデオリンクを収集中...'
	foreach ($keyword in $keywords) {
		$keywordNum++
		$keyword = Remove-TabSpace($keyword)

		Write-Output ('')
		Write-Output ($script:msg.MediumBoldBorder)
		Write-Output ('{0}' -f $keyword)

		# 空き容量少ないときは中断
		if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
		if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

		# 進捗情報の更新
		$secElapsed = (Get-Date) - $linkCollectionStartTime
		if ($keywordNum -ne 0) {
			$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $keywordNum) * ($keywordTotal - $keywordNum))
			$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
		} else { $minRemaining = '' }

		$toastUpdateParams = @{
			Title     = (Remove-TabSpace ($keyword))
			Rate      = [Float]($keywordNum / $keywordTotal)
			LeftText  = ('{0}/{1}' -f $keywordNum, $keywordTotal)
			RightText = $minRemaining
			Tag       = $script:appName
			Group     = 'Bulk'
		}
		Update-ProgressToast @toastUpdateParams

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
	$downloadStartTime = Get-Date
	$videoTotal = $uniqueVideoLinks.Count
	$videoNum = 0

	Write-Output ('')
	Write-Output ($script:msg.LongBoldBorder)
	Write-Output ('全 {0} 件のビデオをダウンロードします' -f $videoTotal)

	foreach ($videoLink in $uniqueVideoLinks) {
		$videoNum++
		$keyword = $videoKeywordMap[$videoLink]

		# ディレクトリの存在確認
		if (!(Test-Path $script:downloadBaseDir -PathType Container)) { throw $script:msg.DownloadDirNotAccessible }

		# 空き容量少ないときは中断
		if ((Get-RemainingCapacity $script:downloadWorkDir) -lt $script:minDownloadWorkDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
		if ((Get-RemainingCapacity $script:downloadBaseDir) -lt $script:minDownloadBaseDirCapacity ) { Write-Warning ($script:msg.NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

		# 進捗率の計算
		$secElapsed = (Get-Date) - $downloadStartTime
		if ($videoNum -ne 0) {
			$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $videoNum) * ($videoTotal - $videoNum))
			$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
		}

		# 進捗情報の更新
		$toastUpdateParams = @{
			Title     = $videoLink
			Rate      = [Float]($videoNum / $videoTotal)
			LeftText  = ('{0}/{1}' -f $videoNum, $videoTotal)
			RightText = $minRemaining
			Tag       = $script:appName
			Group     = 'Bulk'
		}
		Update-ProgressToast @toastUpdateParams

		Write-Output ($script:msg.ShortBoldBorder)
		Write-Output ('{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)

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
		Title     = $script:msg.ExtractingVideoFromKeywords
		Rate      = 1
		LeftText  = ''
		RightText = $script:msg.Completed
		Tag       = $script:appName
		Group     = 'Bulk'
	}
	Update-ProgressToast @toastUpdateParams

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
	Remove-Variable -Name args, keywords, keywordTotal, keywordNum, toastShowParams,
	totalStartTime, keyword, resultLinks, processedCount, videoLinks, videoCount,
	secElapsed, secRemaining, videoLink, toastUpdateParams, videoProcessed,
	uniqueVideoLinks, videoKeywordMap, errorCount, maxErrors -ErrorAction SilentlyContinue

	# ガベージコレクション
	Invoke-GarbageCollection
}
