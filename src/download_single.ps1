###################################################################################
#
#		個別ダウンロード処理スクリプト
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

try { $local:uiMode = [String]$args[0] } catch { $local:uiMode = '' }

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

#GUI起動を判定
if ($local:uiMode -ne 'GUI') { $local:uiMode = 'CUI' }

$local:keywordName = '個別指定'
#ダウンロード対象外番組の読み込み
$script:ignoreTitles = loadIgnoreList

getToken

#----------------------------------------------------------------------
#無限ループ
while ($true) {
	#いろいろ初期化
	$local:videoPageURL = ''
	#移動先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (Test-Path $script:downloadBaseDir -PathType Container) {}
	else { Write-Error ('❗ 番組ダウンロード先ディレクトリにアクセスできません。終了します') ; exit 1 }
	#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum
	#ダウンロード履歴ファイルのデータを読み込み
	try {
		while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$script:historyFileData = Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8
	} catch { Write-Warning ('❗ ダウンロード履歴を読み込めなかったのでスキップしました') ; continue }
	finally { $null = fileUnlock $script:historyLockFilePath }
	if ($local:uiMode -eq 'CUI') {
		$local:videoPageURL = (Read-Host '番組URLを入力してください。何も入力しないで Enter を押すと終了します。').Trim()
	} else {
		#アセンブリの読み込み
		$null = [System.Reflection.Assembly]::Load('Microsoft.VisualBasic, Version=8.0.0.0, Culture=Neutral, PublicKeyToken=b03f5f7f11d50a3a')
		#インプットボックスの表示
		$local:videoPageURL = [String][Microsoft.VisualBasic.Interaction]::InputBox("番組URLを入力してください。`n何も入力しないで OK を押すと終了します。", 'TVerRec個別ダウンロード').Trim()
		Write-Output ('{0}' -f $local:videoPageURL)

	}
	#正しいURLが入力されるまでループ
	if ($videoPageURL -ne '') {
		if ($local:videoPageURL -notmatch '^https://tver.jp/(/?.*)') {
			continue
		} else {
			$local:videoLink = $local:videoPageURL.Replace('https://tver.jp', '').Trim()
			$local:videoPageURL = ('https://tver.jp{0}' -f $local:videoLink)
			Write-Output ('{0}' -f $local:videoPageURL)
			#TVer番組ダウンロードのメイン処理
			downloadTVerVideo `
				-Keyword $local:keywordName `
				-URL $local:videoPageURL `
				-Link $local:videoLink
			[System.GC]::Collect()
			[System.GC]::WaitForPendingFinalizers()
			[System.GC]::Collect()
		}
	} else { break }
}
#----------------------------------------------------------------------

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('ダウンロード処理を終了しました。                                           ')
Write-Output ('---------------------------------------------------------------------------')
