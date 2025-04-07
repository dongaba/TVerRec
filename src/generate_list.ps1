###################################################################################
#
#		番組リストファイル出力処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのダウンロードリストを生成するスクリプト

	.DESCRIPTION
		キーワードリストから番組を検索し、ダウンロードリストを生成します。
		以下の処理を順番に実行します：
		1. キーワードリストの読み込み
		2. 各キーワードでの番組検索
		3. ダウンロード履歴との照合
		4. ダウンロードリストの生成

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
		- keyword.confにキーワードが記載されている必要があります
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

		処理の流れ:
		1. 初期設定
		1.1 環境チェック
		1.2 キーワードリストの読み込み
		1.3 トークンの取得
		2. キーワード処理
		2.1 各キーワードでの番組検索
		2.2 ダウンロード履歴との照合
		2.3 重複チェック
		3. 並列処理
		3.1 マルチスレッド有効時は処理を分割
		3.2 子プロセスでの番組情報取得
		3.3 結果の統合
		4. リスト生成
		4.1 番組情報の整理
		4.2 ダウンロードリストの出力

	.EXAMPLE
		# 通常モードで実行
		.\generate_list.ps1

		# GUIモードで実行
		.\generate_list.ps1 gui

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

	# キーワードリストの読み込み
	$keywords = @(Read-KeywordList)
	if ($keywords.Count -eq 0) { throw 'キーワードリストが空です。処理を中断します。' }
	else { $keywordTotal = $keywords.Count }
	$keywordNum = 0

	# 進捗表示の初期化
	$toastShowParams = @{
		Text1      = $script:msg.ListCreation
		Text2      = $script:msg.ExtractAndCreateListFromKeywords
		WorkDetail = $script:msg.Loading
		Tag        = $script:appName
		Silent     = $false
		Group      = 'ListGen'
	}
	Show-ProgressToast @toastShowParams

	#======================================================================
	# ビデオリンクの収集
	#======================================================================
	$totalStartTime = Get-Date
	$allEpisodeIDs = @()

	foreach ($keyword in $keywords) {
		$keywordNum++
		$keyword = Remove-TabSpace($keyword)

		Write-Output ('')
		Write-Output ($script:msg.MediumBoldBorder)
		Write-Output ('{0}' -f $keyword)

		# 進捗情報の更新
		$secElapsed = (Get-Date) - $totalStartTime
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
			Group     = 'ListGen'
		}
		Update-ProgressToast @toastUpdateParams

		$keyword = Get-ContentWoComment($keyword.Replace('https://tver.jp/', '').Trim())
		$resultLinks = @(Get-VideoLinksFromKeyword $keyword)

		# 履歴チェックと重複排除
		if ($resultLinks.Count -ne 0) {
			if ($script:listGenHistoryCheck) { $episodeIDs, $processedCount = Invoke-HistoryAndListMatchCheck $resultLinks }
			else { $episodeIDs, $processedCount = Invoke-ListMatchCheck $resultLinks }
		} else { $episodeIDs = @() ; $processedCount = 0 }

		$videoCount = $episodeIDs.Count
		if ($videoCount -eq 0) { Write-Output ($script:msg.VideoCountWhenZero -f $videoCount, $processedCount) }
		else { Write-Output ($script:msg.VideoCountNonZero -f $videoCount, $processedCount) }

		$allEpisodeIDs += $episodeIDs
	}

	$allEpisodeIDs = $allEpisodeIDs | Sort-Object -Unique

	#======================================================================
	# 個々の番組の情報の取得
	#======================================================================
	# if ($script:enableMultithread) {
	# 	Write-Debug ('Multithread Processing Enabled')
	# 	# 並列化が有効の場合は並列化
	# 	if ($allEpisodeIDs -ne 0) {
	# 		# 配列を分割
	# 		$partitions = @{}
	# 		$totalCount = $allEpisodeIDs.Count
	# 		$partitionSize = [math]::Ceiling($totalCount / $script:multithreadNum)
	# 		for ($i = 0 ; $i -lt $script:multithreadNum ; $i++) {
	# 			$startIndex = $i * $partitionSize
	# 			$endIndex = [math]::Min(($i + 1) * $partitionSize, $totalCount)
	# 			if ($startIndex -lt $totalCount) { $partitions[$i] = $allEpisodeIDs[$startIndex..($endIndex - 1)] }
	# 		}

	# 		$paraJobSBs = @{}
	# 		$paraJobDefs = @{}
	# 		$paraJobs = @{}
	# 		Write-Output ($script:msg.DisclaimerForMultithread)
	# 		for ($i = 0 ; $i -lt $partitions.Count ; $i++) {
	# 			$links = [String]$partitions[$i]
	# 			$paraJobSBs[$i] = ("& ./generate_list_child.ps1 $keyword $links")
	# 			$paraJobDefs[$i] = [ScriptBlock]::Create($paraJobSBs[$i])
	# 			$paraJobs[$i] = Start-ThreadJob -ScriptBlock $paraJobDefs[$i]
	# 		}
	# 		do {
	# 			$completedJobs = Get-Job -State Completed
	# 			foreach ($job in $completedJobs) { Write-Output (Receive-Job -Job $job) ; Remove-Job -Job $job }
	# 			Remove-Job -State Failed, Stopped, Suspended, Disconnected
	# 			$remainingJobs = Get-Job
	# 			Start-Sleep -Milliseconds 500
	# 		} while ($remainingJobs)
	# 	}
	# } else {
	# 並列化が無効の場合は従来型処理
	$listGenStartTime = Get-Date
	$videoTotal = $allEpisodeIDs.Count
	$videoNum = 0
	foreach ($episodeID in $allEpisodeIDs) {
		$videoNum++

		# 進捗率の計算
		$secElapsed = (Get-Date) - $listGenStartTime
		if ($videoNum -ne 0) {
			$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $videoNum) * ($videoTotal - $videoNum))
			$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
		}

		$toastUpdateParams = @{
			Title     = $episodeID
			Rate      = [Float]($videoNum / $videoTotal)
			LeftText  = ('{0}/{1}' -f $videoNum, $videoTotal)
			RightText = $minRemaining
			Tag       = $script:appName
			Group     = 'ListGen'
		}
		Update-ProgressToast @toastUpdateParams

		Write-Output ('　{0}/{1} - {2}' -f $videoNum, $videoTotal, $episodeID)
		# TVer番組ダウンロードのメイン処理
		Update-VideoList -Keyword $keyword -EpisodeID $episodeID
	}
	# }
	#----------------------------------------------------------------------


	#======================================================================
	# 後処理
	#======================================================================
	$toastUpdateParams = @{
		Title     = $script:msg.ExtractingVideoFromKeywords
		Rate      = 1
		LeftText  = ''
		RightText = $script:msg.Completed
		Tag       = $script:appName
		Group     = 'ListGen'
	}
	Update-ProgressToast @toastUpdateParams

	Write-Output ('')
	Write-Output ($script:msg.LongBoldBorder)
	Write-Output ($script:msg.ListCreationCompleted)
	Write-Output ($script:msg.ListCreationCompletionMessage1)
	Write-Output ($script:msg.ListCreationCompletionMessage2 -f $script:listFilePath)
	Write-Output ($script:msg.LongBoldBorder)
} catch {
	Write-Error "Error occurred: $($_.Exception.Message)"
	Write-Error "Stack trace: $($_.ScriptStackTrace)"
	throw
} finally {
	# 変数のクリーンアップ
	Remove-Variable -Name args, keywords, keywordNum, keywordTotal, toastShowParams, totalStartTime, keyword, listLinks, videoLinks, processedCount, videoTotal, secElapsed, secRemaining1, toastUpdateParams, partitions, totalCount, partitionSize, i, startIndex, endIndex, videoNum, paraJobSBs, paraJobDefs, paraJobs, links, completedJobs, job, remainingJobs, videoLink -ErrorAction SilentlyContinue

	# ガベージコレクション
	Invoke-GarbageCollection
}
