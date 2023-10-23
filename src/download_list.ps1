###################################################################################
#
#		リストダウンロード処理スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the MIT License;
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in
#	all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#	THE SOFTWARE.
#
###################################################################################

try { $script:uiMode = [String]$args[0] } catch { $script:uiMode = '' }

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
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
} catch { Write-Error ('❗ カレントディレクトリの設定に失敗しました') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if ($? -eq $false) { exit 1 }
} catch { Write-Error ('❗ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#いろいろ初期化
$local:videoLink = ''
$local:videoLinks = [System.Collections.Generic.List[String]]::new()

$local:videoNum = 0

$local:keywordName = 'リスト指定'
#ダウンロード対象外番組の読み込み
$script:ignoreTitles = loadIgnoreList

getToken

Write-Output ('----------------------------------------------------------------------')
Write-Output ('ダウンロードリストを読み込みます')
$local:listLinks = @()
$local:listLinks = @(loadDownloadList)
if ($null -eq $local:listLinks) { Write-Warning ('💡 ダウンロードリストが0件です') ; exit 0 }

$local:listTotal = 0
$local:listTotal = $script:listLinks.Count
if ($local:listTotal -eq 0) { Write-Warning ('💡 ダウンロードリストが0件です') ; exit 0 }
Write-Output ('　リスト件数{0}件' -f $local:listTotal)

Write-Output ('')
Write-Output ('----------------------------------------------------------------------')
Write-Output ('ダウンロード履歴を読み込みます')
#ダウンロード履歴ファイルのデータを読み込み
try {
	while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
	$script:historyFileData = Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8
} catch { Write-Warning ('❗ ダウンロード履歴を読み込めなかったのでスキップしました') ; continue }
finally { $null = fileUnlock $script:historyLockFilePath }

Write-Output ('')
Write-Output ('----------------------------------------------------------------------')
Write-Output ('ダウンロード履歴に含まれる番組を除外します')
#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
foreach ($local:listLink in $local:listLinks.episodeID) {
	if ($null -ne $script:historyFileData) {
		$local:historyMatch = $script:historyFileData.Where{ $_.videoPage -eq $local:listLink }
		if ($local:historyMatch.Count -eq 0) { $local:videoLinks.Add($local:listLink) }
	} else { $local:videoLinks.Add($local:listLink) }
}

$local:videoTotal = $local:videoLinks.Count
Write-Output ('💡 ダウンロード対象{0}件' -f $local:videoTotal)

#処理時間の推計
$local:totalStartTime = Get-Date
$local:secRemaining = -1

showProgressToast `
	-Text1 'リストからの番組のダウンロード' `
	-Text2 'リストファイルから番組をダウンロード' `
	-WorkDetail '読み込み中...' `
	-Duration 'long' `
	-Silent $false `
	-Tag $script:appName `
	-Group 'List'

#----------------------------------------------------------------------
#個々の番組ダウンロードここから
foreach ($local:videoLink in $local:videoLinks) {
	$local:videoNum += 1
	#移動先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (Test-Path $script:downloadBaseDir -PathType Container) {}
	else { Write-Error ('❗ 番組ダウンロード先ディレクトリにアクセスできません。終了します') ; exit 1 }
	#進捗率の計算
	$local:progressRate = [Float]($local:videoNum / $local:videoTotal)
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining = [Int][Math]::Ceiling(($local:secElapsed.TotalSeconds / $local:videoNum) * ($local:videoTotal - $local:videoNum))
	$local:minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($local:secRemaining / 60)))
	#進捗更新
	updateProgressToast `
		-Title 'リストからの番組のダウンロード' `
		-Rate $local:progressRate `
		-LeftText $local:videoNum/$local:videoTotal `
		-RightText $local:minRemaining `
		-Tag $script:appName `
		-Group 'List'
	Write-Output ('--------------------------------------------------')
	Write-Output ('{0}/{1} - {2}' -f $local:videoNum, $local:videoTotal, $local:videoLink)
	#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum
	#TVer番組ダウンロードのメイン処理
	downloadTVerVideo `
		-Keyword $local:keywordName `
		-URL ('https://tver.jp/episodes/{0}' -f $local:videoLink) `
		-Link ('/episodes/{0}' -f $local:videoLink) `
		-Single $false
}
#----------------------------------------------------------------------

updateProgressToast `
	-Title 'リストからの番組のダウンロード' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'List'

#youtube-dlのプロセスが終わるまで待機
Write-Output ('ダウンロードの終了を待機しています')
waitTillYtdlProcessIsZero

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('リストダウンロード処理を終了しました。                                     ')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('💡 必要に応じてリストファイルを編集してダウンロード不要な番組を削除してください')
Write-Output ('　リストファイルパス: {0}' -f $script:listFilePath)

