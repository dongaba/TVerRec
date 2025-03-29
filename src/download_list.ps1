###################################################################################
#
#		リストダウンロード処理スクリプト
#
###################################################################################
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

#----------------------------------------------------------------------
# 個々の番組ダウンロードここから
$videoNum = 0
foreach ($videoLink in $videoLinks) {
	$videoNum++
	# ダウンロード先ディレクトリの存在確認先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (!(Test-Path $script:downloadBaseDir -PathType Container)) { Throw ('❌️ 番組ダウンロード先ディレクトリにアクセスできません。終了します') }

	# 空き容量少ないときは中断
	if((Get-RemainingCapacity $script:downloadWorkDir) -lt 100 ){ Write-Warning ($script:msg:NoEnoughCapacity -f $script:downloadWorkDir ) ; break }
	if((Get-RemainingCapacity $script:downloadBaseDir) -lt 100 ){ Write-Warning ($script:msg:NoEnoughCapacity -f $script:downloadBaseDir ) ; break }

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
	Invoke-VideoDownload -Keyword ([Ref]$keyword) -VideoLink ([Ref]$videoLink) -Force $false
}
#----------------------------------------------------------------------

# youtube-dlのプロセスが終わるまで待機
Write-Output ('')
Write-Output ($script:msg.WaitingDownloadCompletion)
Wait-DownloadCompletion

# リネームに失敗したファイルを削除
Write-Output ('')
Write-Output ($script:msg.DeleteFilesFailedToRename)
Get-ChildItem -LiteralPath $script:downloadBaseDir -Recurse -File -Filter 'ep*.*' |
	ForEach-Object {
		if ($_.BaseName -cmatch '^ep[a-z0-9]{8}$' -and ($_.Extension -eq '.mp4' -or $_.Extension -eq '.ts')) {
			Remove-Item -LiteralPath $_.FullName -Force
		}
	}

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
