###################################################################################
#
#		番組リストファイル出力処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Write-Error ('❌️ カレントディレクトリの設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❌️ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if (!$?) { Write-Error ('❌️ TVerRecの初期化処理に失敗しました') ; exit 1 }
} catch { Write-Error ('❌️ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Invoke-RequiredFileCheck

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#初回呼び出し時
$keywords = @(Read-KeywordList)
Get-Token
$keywordNum = 0
$keywordTotal = $keywords.Count

$toastShowParams = @{
	Text1   = 'キーワードから番組リスト作成中'
	Text2   = 'キーワードから番組を抽出しダウンロード'
	Detail1 = '読み込み中...'
	Detail2 = '読み込み中...'
	Tag     = $script:appName
	Silent  = $false
	Group   = 'ListGen'
}
Show-ProgressToast2Row @toastShowParams

#======================================================================
#個々のキーワードチェックここから
$totalStartTime = Get-Date
foreach ($keyword in $keywords) {
	$keyword = Remove-TabSpace($keyword)

	Write-Output ('')
	Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
	Write-Output ('{0}' -f $keyword)

	$keyword = (Remove-Comment($keyword.Replace('https://tver.jp/', '').Trim()))
	$listLinks = @(Get-VideoLinksFromKeyword($keyword))

	#URLがすでにダウンロードリストやダウンロード履歴に存在する場合は検索結果から除外
	if ($listLinks.Count -ne 0) {
		if ($script:listGenHistoryCheck) { $videoLinks, $processedCount = Invoke-HistoryAndListMatchCheck $listLinks }
		else { $videoLinks, $processedCount = Invoke-ListMatchCheck $listLinks }
	} else { $videoLinks = @(); $processedCount = 0 }
	$videoTotal = $videoLinks.Count
	if ($videoTotal -eq 0) { Write-Output ('　処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }
	else { Write-Output ('　💡 処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }

	#処理時間の推計
	$secElapsed = (Get-Date) - $totalStartTime
	if ($keywordNum -ne 0) {
		$secRemaining1 = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $keywordNum) * ($keywordTotal - $keywordNum))
	} else { $secRemaining1 = '' }

	#キーワード数のインクリメント
	$keywordNum += 1

	#進捗情報の更新
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

	#----------------------------------------------------------------------
	#個々の番組の情報の取得ここから
	if ($script:enableMultithread) {
		Write-Debug ('Multithread Processing Enabled')
		#並列化が有効の場合は並列化
		if ($videoLinks -ne 0) {
			# 配列を分割
			$partitions = @{}
			$totalCount = $videoLinks.Count
			$partitionSize = [math]::Ceiling($totalCount / $script:multithreadNum)
			for ($i = 0; $i -lt $script:multithreadNum; $i++) {
				$startIndex = $i * $partitionSize
				$endIndex = [math]::Min(($i + 1) * $partitionSize, $totalCount)
				if ($startIndex -lt $totalCount) { $partitions[$i] = $videoLinks[$startIndex..($endIndex - 1)] }
			}

			$paraJobSBs = @{}
			$paraJobDefs = @{}
			$paraJobs = @{}
			Write-Output ('　並列処理をするため進捗状況は順不同で表示されます')
			for ($i = 0; $i -lt $partitions.Count; $i++) {
				$links = [string]$partitions[$i]
				$paraJobSBs[$i] = ("& ./generate_list_child.ps1 $keyword $links")
				$paraJobDefs[$i] = [scriptblock]::Create($paraJobSBs[$i])
				$paraJobs[$i] = Start-ThreadJob -ScriptBlock $paraJobDefs[$i]
			}
			do {
				$completedJobs = Get-Job -State Completed
				foreach ($job in $completedJobs) {
					Write-Output (Receive-Job -Job $job)
					Remove-Job -Job $job
				}
				Remove-Job -State Failed, Stopped, Suspended, Disconnected
				$remainingJobs = Get-Job
				Start-Sleep -Milliseconds 500
			} while ($remainingJobs)
			# $null = Get-Job | Wait-Job
			# Write-Output (Get-Job | Receive-Job)
			# Get-Job | Remove-Job
		}
	} else {
		#並列化が無効の場合は従来型処理
		$videoNum = 0
		foreach ($videoLink in $videoLinks) {
			$videoNum += 1
			#進捗情報の更新
			$toastUpdateParams.Title2 = $videoLink
			$toastUpdateParams.Rate2 = [Float]($videoNum / $videoTotal)
			$toastUpdateParams.LeftText2 = ('{0}/{1}' -f $videoNum, $videoTotal)
			Update-ProgressToast2Row @toastUpdateParams
			Write-Output ('　{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)
			#TVer番組ダウンロードのメイン処理
			Update-VideoList -Keyword $keyword -EpisodePage $videoLink
		}
	}
	#----------------------------------------------------------------------

}
#======================================================================

$toastUpdateParams = @{
	Title1     = 'キーワードから番組の抽出'
	Rate1      = 1
	LeftText1  = ''
	RightText1 = '0'
	Title2     = '番組リストの作成'
	Rate2      = 1
	LeftText2  = ''
	RightText2 = '0'
	Tag        = $script:appName
	Group      = 'ListGen'
}
Update-ProgressToast2Row @toastUpdateParams

Remove-Variable -Name guiMode, args, scriptRoot, keywords, keywordNum, keywordTotal, toastShowParams, totalStartTime, keyword, listLinks, videoLinks, processedCount, videoTotal, secElapsed, secRemaining1, toastUpdateParams, partitions, totalCount, partitionSize, i, startIndex, endIndex, videoNum, paraJobSBs, paraJobDefs, links, completedJobs, job, remainingJobs, videoLink -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('番組リストファイル出力処理を終了しました。')
Write-Output ('💡 必要に応じてリストファイルを編集してダウンロード不要な番組を削除してください')
Write-Output ('　リストファイルパス: {0}' -f $script:listFilePath)
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
