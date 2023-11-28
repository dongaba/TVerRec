###################################################################################
#
#		番組リストファイル出力処理スクリプト
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

$keywords = @(Read-KeywordList)
Get-Token

$keywordNum = 0
$keywordTotal = $keywords.Count

Show-Progress2Row `
	-Text1 'キーワードから番組リスト作成中' `
	-Text2 'キーワードから番組を抽出しダウンロード' `
	-Detail1 '読み込み中...' `
	-Detail2 '読み込み中...' `
	-Tag $script:appName `
	-Duration 'long' `
	-Silent $false `
	-Group 'ListGen'

#======================================================================
#個々のキーワードチェックここから
$totalStartTime = Get-Date
foreach ($keyword in $keywords) {
	$keyword = Remove-TabSpace($keyword)

	Write-Output ('')
	Write-Output ('----------------------------------------------------------------------')
	Write-Output ('{0}' -f $keyword)

	$listLinks = @(Get-VideoLinksFromKeyword($keyword))
	$keyword = $keyword.Replace('https://tver.jp/', '')

	#URLがすでにダウンロードリストまたはダウンロード履歴に存在する場合は検索結果から除外
	if ($listLinks.Count -ne 0) { $videoLinks, $processedCount = Invoke-HistoryMatchCheck $listLinks }
	else { $videoLinks = @(); $processedCount = 0 }
	$videoTotal = $videoLinks.Count
	if ($videoTotal -eq 0) { Write-Output ('　処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }
	else { Write-Output ('　💡 処理対象{0}本　処理済{1}本' -f $videoTotal, $processedCount) }

	#処理時間の推計
	$secElapsed = (Get-Date) - $totalStartTime
	if ($keywordNum -ne 0) {
		$secRemaining1 = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $keywordNum) * ($keywordTotal - $keywordNum))
	} else { $secRemaining1 = -1 }
	$progressRate1 = [Float]($keywordNum / $keywordTotal)
	$progressRate2 = 0

	#キーワード数のインクリメント
	$keywordNum += 1

	#進捗更新
	Update-Progress2Row `
		-Activity1 $keywordNum/$keywordTotal `
		-Processing1 (Remove-TabSpace ($keyword)) `
		-Rate1 $progressRate1 `
		-SecRemaining1 $secRemaining1 `
		-Activity2 '' `
		-Processing2 '' `
		-Rate2 $progressRate2 `
		-SecRemaining2 '' `
		-Tag $script:appName `
		-Group 'ListGen'

	#----------------------------------------------------------------------
	#個々の番組の情報の取得ここから
	$videoNum = 0
	foreach ($videoLink in $videoLinks) {
		$videoNum += 1
		#進捗率の計算
		$progressRate2 = [Float]($videoNum / $videoTotal)
		#進捗更新
		Update-Progress2Row `
			-Activity1 $keywordNum/$keywordTotal `
			-Processing1 (Remove-TabSpace ($keyword)) `
			-Rate1 $progressRate1 `
			-SecRemaining1 $secRemaining1 `
			-Activity2 $videoNum/$videoTotal `
			-Processing2 $videoLink `
			-Rate2 $progressRate2 `
			-SecRemaining2 '' `
			-Tag $script:appName `
			-Group 'ListGen'
		Write-Output ('--------------------------------------------------')
		Write-Output ('{0}/{1} - {2}' -f $videoNum, $videoTotal, $videoLink)
		#TVer番組ダウンロードのメイン処理
		Update-VideoList `
			-Keyword $keyword `
			-EpisodePage $videoLink
	}
	#----------------------------------------------------------------------

}
#======================================================================

Update-ProgressToast2 `
	-Title1 'キーワードから番組リスト作成' `
	-Rate1 '1' `
	-LeftText1 '' `
	-RightText1 '完了' `
	-Title2 '番組のダウンロード' `
	-Rate2 '1' `
	-LeftText2 '' `
	-RightText2 '完了' `
	-Tag $script:appName `
	-Group 'ListGen'

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('番組リストファイル出力処理を終了しました。')
Write-Output ('💡 必要に応じてリストファイルを編集してダウンロード不要な番組を削除してください')
Write-Output ('　リストファイルパス: {0}' -f $script:listFilePath)
Write-Output ('---------------------------------------------------------------------------')
