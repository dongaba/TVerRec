###################################################################################
#
#		一括ダウンロード処理スクリプト
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
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません') }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
if (!$?) { Throw ('❌️ TVerRecの初期化処理に失敗しました') }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Invoke-RequiredFileCheck
Suspend-Process
Get-Token
$keywords = @(Read-KeywordList)
$keywordNum = 0
$keywordTotal = $keywords.Count

$toastShowParams = @{
	Text1   = '一括ダウンロード中'
	Text2   = 'キーワードから番組を抽出しダウンロード'
	Detail1 = '読み込み中...'
	Detail2 = '読み込み中...'
	Tag     = $script:appName
	Silent  = $false
	Group   = 'Bulk'
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
	$resultLinks = @(Get-VideoLinksFromKeyword ([ref]$keyword))

	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	if ($resultLinks.Count -ne 0) { $videoLinks, $processedCount = Invoke-HistoryMatchCheck $resultLinks }
	else { $videoLinks = @() ; $processedCount = 0 }
	$videoTotal = $videoLinks.Count
	if ($videoTotal -eq 0) { Write-Output ('　処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }
	else { Write-Output ('　💡 処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }

	#処理時間の推計
	$secElapsed = (Get-Date) - $totalStartTime
	if ($keywordNum -ne 0) { $secRemaining1 = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $keywordNum) * ($keywordTotal - $keywordNum)) }
	else { $secRemaining1 = '' }

	#キーワード数のインクリメント
	$keywordNum++

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
		Group      = 'Bulk'
	}
	Update-ProgressToast2Row @toastUpdateParams

	#----------------------------------------------------------------------
	#個々の番組ダウンロードここから
	$videoNum = 0
	foreach ($videoLink in $videoLinks) {
		$videoNum++
		#ダウンロード先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
		if (!(Test-Path $script:downloadBaseDir -PathType Container)) { Throw ('❌️ 番組ダウンロード先ディレクトリにアクセスできません。終了します') }

		#進捗情報の更新
		$toastUpdateParams.Title2 = $videoLink
		$toastUpdateParams.Rate2 = [Float]($videoNum / $videoTotal)
		$toastUpdateParams.LeftText2 = ('{0}/{1}' -f $videoNum, $videoTotal)
		Update-ProgressToast2Row @toastUpdateParams

		Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━')
		Write-Output ('{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)

		#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
		Wait-YtdlProcess $script:parallelDownloadFileNum
		Suspend-Process

		#TVer番組ダウンロードのメイン処理
		Invoke-VideoDownload -Keyword ([ref]$keyword) -VideoLink ([ref]$videoLink) -Force $false
	}
	#----------------------------------------------------------------------

}
#======================================================================

$toastUpdateParams = @{
	Title1     = 'キーワードから番組の抽出'
	Rate1      = 1
	LeftText1  = ''
	RightText1 = 0
	Title2     = '番組のダウンロード'
	Rate2      = 1
	LeftText2  = ''
	RightText2 = '0'
	Tag        = $script:appName
	Group      = 'Bulk'
}
Update-ProgressToast2Row @toastUpdateParams

#youtube-dlのプロセスが終わるまで待機
Write-Output ('')
Write-Output ('ダウンロードの終了を待機しています')
Wait-DownloadCompletion

Remove-Variable -Name args, keywords, keywordNum, keywordTotal, toastShowParams, totalStartTime, keyword, resultLinks, processedCount, videoLinks, videoTotal, secElapsed, secRemaining1, videoLink, toastUpdateParams, videoNum -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('一括ダウンロード処理を終了しました。')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
