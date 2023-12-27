###################################################################################
#
#		一括ダウンロード処理スクリプト
#
###################################################################################

try { $script:guiMode = [String]$args[0] } catch { $script:guiMode = '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($script:myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Write-Error ('❗ カレントディレクトリの設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❗ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if (!$?) { exit 1 }
} catch { Write-Error ('❗ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#設定で指定したファイル・ディレクトリの存在チェック
Invoke-RequiredFileCheck
Get-Token
$keywords = @(Read-KeywordList)
$keywordNum = 0
$keywordTotal = $keywords.Count

$toastParams = @{
	Text1   = '一括ダウンロード中'
	Text2   = 'キーワードから番組を抽出しダウンロード'
	Detail1 = '読み込み中...'
	Detail2 = '読み込み中...'
	Tag     = $script:appName
	Silent  = $false
	Group   = 'Bulk'
}
Show-ProgressToast2Row @toastParams

#======================================================================
#個々のキーワードチェックここから
$totalStartTime = Get-Date
foreach ($keyword in $keywords) {
	$keyword = Remove-TabSpace($keyword)
	Write-Output ('')
	Write-Output ('----------------------------------------------------------------------')
	Write-Output ('{0}' -f $keyword)

	$resultLinks = @(Get-VideoLinksFromKeyword($keyword))
	$keyword = $keyword.Replace('https://tver.jp/', '')

	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	if ($resultLinks.Count -ne 0) { $videoLinks, $processedCount = Invoke-HistoryMatchCheck $resultLinks }
	else { $videoLinks = @(); $processedCount = 0 }
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
	$toastParams = @{
		Activity1     = "$keywordNum/$keywordTotal"
		Processing1   = (Remove-TabSpace ($keyword))
		Rate1         = [Float]($keywordNum / $keywordTotal)
		SecRemaining1 = $secRemaining1
		Activity2     = ''
		Processing2   = ''
		Rate2         = 0
		SecRemaining2 = ''
		Tag           = $script:appName
		Group         = 'Bulk'
	}
	Update-ProgressToast2Row @toastParams

	#----------------------------------------------------------------------
	#個々の番組ダウンロードここから
	$videoNum = 0
	foreach ($videoLink in $videoLinks) {
		$videoNum += 1
		#ダウンロード先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
		if (!(Test-Path $script:downloadBaseDir -PathType Container)) {
			Write-Error ('❗ 番組ダウンロード先ディレクトリにアクセスできません。終了します') ; exit 1
		}

		#進捗情報の更新
		$toastParams.Activity2 = "$videoNum/$videoTotal"
		$toastParams.Processing2 = $videoLink
		$toastParams.Rate2 = [Float]($videoNum / $videoTotal)
		Update-ProgressToast2Row @toastParams

		Write-Output ('--------------------------------------------------')
		Write-Output ('{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)

		#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
		Wait-YtdlProcess $script:parallelDownloadFileNum

		#TVer番組ダウンロードのメイン処理
		Invoke-VideoDownload `
			-Keyword $keyword `
			-EpisodePage $videoLink `
			-Force $false
	}
	#----------------------------------------------------------------------

}
#======================================================================

$toastParams = @{
	Activity1     = ''
	Processing1   = 'キーワードから番組の抽出'
	Rate1         = '1'
	SecRemaining1 = '0'
	Activity2     = ''
	Processing2   = '番組のダウンロード'
	Rate2         = '1'
	SecRemaining2 = '0'
	Tag           = $script:appName
	Group         = 'Bulk'
}
Update-ProgressToast2Row @toastParams

#youtube-dlのプロセスが終わるまで待機
Write-Output ('')
Write-Output ('ダウンロードの終了を待機しています')
Wait-DownloadCompletion

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('一括ダウンロード処理を終了しました。                                       ')
Write-Output ('---------------------------------------------------------------------------')
