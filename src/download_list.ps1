###################################################################################
#
#		リストダウンロード処理スクリプト
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
#ダウンロードリストを読み込み
$listLinks = @(Get-LinkFromDownloadList)
if ($null -eq $listLinks) { Write-Warning ('💡 ダウンロードリストが0件です') ; exit 0 }
$keyword = 'リスト指定'


#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
if ($listLinks.Count -ne 0) { $videoLinks, $processedCount = Invoke-HistoryMatchCheck $listLinks }
else { $videoLinks = @(); $processedCount = 0 }
$videoTotal = $videoLinks.Count
Write-Output ('')
if ($videoTotal -eq 0) { Write-Output ('　処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }
else { Write-Output ('　💡 処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }


#処理時間の推計
$totalStartTime = Get-Date
$secRemaining = -1

$toastParams = @{
	Text1      = 'リストからの番組のダウンロード'
	Text2      = 'リストファイルから番組をダウンロード'
	WorkDetail = '読み込み中...'
	Tag        = $script:appName
	Silent     = $false
	Group      = 'Bulk'
}
Show-ProgressToast @toastParams

#----------------------------------------------------------------------
#個々の番組ダウンロードここから
$videoNum = 0
foreach ($videoLink in $videoLinks) {
	$videoNum += 1
	#ダウンロード先ディレクトリの存在確認先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (!(Test-Path $script:downloadBaseDir -PathType Container)) {
		Write-Error ('❗ 番組ダウンロード先ディレクトリにアクセスできません。終了します') ; exit 1
	}

	#進捗率の計算
	$secElapsed = (Get-Date) - $totalStartTime
	if ($videoNum -ne 0) {
		$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $videoNum) * ($videoTotal - $videoNum))
		$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
	}

	#進捗情報の更新
	$toastParams = @{
		Title     = 'リストからの番組のダウンロード'
		Rate      = [Float]($videoNum / $videoTotal)
		LeftText  = $videoNum / $videoTotal
		RightText = $minRemaining
		Tag       = $script:appName
		Group     = 'List'
	}
	Update-ProgressToast @toastParams

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

$toastParams.Rate = '1'
$toastParams.LeftText = ''
$toastParams.RightText = '完了'
Update-ProgressToast @toastParams

#youtube-dlのプロセスが終わるまで待機
Write-Output ('')
Write-Output ('ダウンロードの終了を待機しています')
Wait-DownloadCompletion

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('リストダウンロード処理を終了しました。                                     ')
Write-Output ('---------------------------------------------------------------------------')

