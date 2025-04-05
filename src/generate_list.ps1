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

	.NOTES
		前提条件:
		- Windows環境で実行する必要があります
		- PowerShell 7.0以上が必要です
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- keyword_list.txtにキーワードが記載されている必要があります

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
		各処理の実行結果をコンソールに出力します。
		進捗状況はトースト通知でも表示されます。
		download_list.txtにダウンロードリストが生成されます。
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 初回呼び出し時
$keywords = @(Read-KeywordList)
Get-Token
$keywordNum = 0
$keywordTotal = $keywords.Count

$toastShowParams = @{
	Text1   = $script:msg.ListCreation
	Text2   = $script:msg.ExtractAndCreateListFromKeywords
	Detail1 = $script:msg.Loading
	Detail2 = $script:msg.Loading
	Tag     = $script:appName
	Silent  = $false
	Group   = 'ListGen'
}
Show-ProgressToast2Row @toastShowParams

#======================================================================
# 個々のキーワードチェックここから
$totalStartTime = Get-Date
foreach ($keyword in $keywords) {
	$keyword = Remove-TabSpace($keyword)

	Write-Output ('')
	Write-Output ($script:msg.ShortBoldBorder)
	Write-Output ('{0}' -f $keyword)

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
		Group      = 'ListGen'
	}
	Update-ProgressToast2Row @toastUpdateParams

	$keyword = (Get-ContentWoComment($keyword.Replace('https://tver.jp/', '').Trim()))
	$listLinks = @(Get-VideoLinksFromKeyword $keyword)

	# URLがすでにダウンロードリストやダウンロード履歴に存在する場合は検索結果から除外
	if ($listLinks.Count -ne 0) {
		if ($script:listGenHistoryCheck) { $videoLinks, $processedCount = Invoke-HistoryAndListMatchCheck $listLinks }
		else { $videoLinks, $processedCount = Invoke-ListMatchCheck $listLinks }
	} else { $videoLinks = @() ; $processedCount = 0 }
	$videoTotal = $videoLinks.Count
	if ($videoTotal -eq 0) { Write-Output ($script:msg.VideoCountWhenZero -f $videoTotal, $processedCount) }
	else { Write-Output ($script:msg.VideoCountNonZero -f $videoTotal, $processedCount) }

	#----------------------------------------------------------------------
	# 個々の番組の情報の取得ここから
	if ($script:enableMultithread) {
		Write-Debug ('Multithread Processing Enabled')
		# 並列化が有効の場合は並列化
		if ($videoLinks -ne 0) {
			# 配列を分割
			$partitions = @{}
			$totalCount = $videoLinks.Count
			$partitionSize = [math]::Ceiling($totalCount / $script:multithreadNum)
			for ($i = 0 ; $i -lt $script:multithreadNum ; $i++) {
				$startIndex = $i * $partitionSize
				$endIndex = [math]::Min(($i + 1) * $partitionSize, $totalCount)
				if ($startIndex -lt $totalCount) { $partitions[$i] = $videoLinks[$startIndex..($endIndex - 1)] }
			}

			$paraJobSBs = @{}
			$paraJobDefs = @{}
			$paraJobs = @{}
			Write-Output ($script:msg.DisclaimerForMultithread)
			for ($i = 0 ; $i -lt $partitions.Count ; $i++) {
				$links = [String]$partitions[$i]
				$paraJobSBs[$i] = ("& ./generate_list_child.ps1 $keyword $links")
				$paraJobDefs[$i] = [ScriptBlock]::Create($paraJobSBs[$i])
				$paraJobs[$i] = Start-ThreadJob -ScriptBlock $paraJobDefs[$i]
			}
			do {
				$completedJobs = Get-Job -State Completed
				foreach ($job in $completedJobs) { Write-Output (Receive-Job -Job $job) ; Remove-Job -Job $job }
				Remove-Job -State Failed, Stopped, Suspended, Disconnected
				$remainingJobs = Get-Job
				Start-Sleep -Milliseconds 500
			} while ($remainingJobs)
		}
	} else {
		# 並列化が無効の場合は従来型処理
		$videoNum = 0
		foreach ($videoLink in $videoLinks) {
			$videoNum++
			# 進捗情報の更新
			$toastUpdateParams.Title2 = $videoLink
			$toastUpdateParams.Rate2 = [Float]($videoNum / $videoTotal)
			$toastUpdateParams.LeftText2 = ('{0}/{1}' -f $videoNum, $videoTotal)
			Update-ProgressToast2Row @toastUpdateParams
			Write-Output ('　{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)
			# TVer番組ダウンロードのメイン処理
			Update-VideoList -Keyword $keyword -VideoLink $videoLink
		}
	}
	#----------------------------------------------------------------------

}
#======================================================================

$toastUpdateParams = @{
	Title1     = $script:msg.ExtractingVideoFromKeywords
	Rate1      = 1
	LeftText1  = ''
	RightText1 = '0'
	Title2     = $script:msg.GenerateList
	Rate2      = 1
	LeftText2  = ''
	RightText2 = '0'
	Tag        = $script:appName
	Group      = 'ListGen'
}
Update-ProgressToast2Row @toastUpdateParams

Remove-Variable -Name args, keywords, keywordNum, keywordTotal, toastShowParams, totalStartTime, keyword, listLinks, videoLinks, processedCount, videoTotal, secElapsed, secRemaining1, toastUpdateParams, partitions, totalCount, partitionSize, i, startIndex, endIndex, videoNum, paraJobSBs, paraJobDefs, paraJobs, links, completedJobs, job, remainingJobs, videoLink -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.ListCreationCompleted)
Write-Output ($script:msg.ListCreationCompletionMessage1)
Write-Output ($script:msg.ListCreationCompletionMessage2 -f $script:listFilePath)
Write-Output ($script:msg.LongBoldBorder)
