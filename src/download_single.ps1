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

try { $script:uiMode = [String]$args[0] } catch { $script:uiMode = '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($script:myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path ./ }
	else { $script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
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

$keyword = '個別指定'
Get-Token

#GUI起動を判定
if ($script:uiMode -ne 'GUI') { $script:uiMode = 'CUI' }


#----------------------------------------------------------------------
#無限ループ
while ($true) {
	#いろいろ初期化
	$videoPageURL = ''
	#移動先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (Test-Path $script:downloadBaseDir -PathType Container) {}
	else { Write-Error ('❗ 番組ダウンロード先ディレクトリにアクセスできません。終了します') ; exit 1 }
	#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	Wait-YtdlProcess $script:parallelDownloadFileNum
	if ($script:uiMode -eq 'CUI') {
		$videoPageURL = (Read-Host '番組URLを入力してください。何も入力しないで Enter を押すと終了します。').Trim()
	} else {
		#アセンブリの読み込み
		$null = [System.Reflection.Assembly]::Load('Microsoft.VisualBasic, Version=8.0.0.0, Culture=Neutral, PublicKeyToken=b03f5f7f11d50a3a')
		#インプットボックスの表示
		$videoPageURL = [String][Microsoft.VisualBasic.Interaction]::InputBox("番組URLを入力してください。`n何も入力しないで OK を押すと終了します。", 'TVerRec個別ダウンロード').Trim()
	}

	#正しいURLが入力されるまでループ
	if ($videoPageURL -ne '') {
		if ($videoPageURL -notmatch '^https://tver.jp/(/?.*)') {
			# Tver以外には変数セットして youtube-dl起動
			$script:videoFileDir = $script:downloadBaseDir
			$script:videoName = $script:ytdlNonTVerFileName

			Write-Output ('{0}{1}' -f 'ダウンロード：', $videoPageURL)

			try { Invoke-NonTverYtdl $videoPageURL }
			catch { Write-Warning ('❗ youtube-dlの起動に失敗しました') }
			#5秒待機
			Start-Sleep -Seconds 5
		} else {
			Write-Output ('{0}' -f $videoPageURL)
			#TVer番組ダウンロードのメイン処理
			Invoke-VideoDownload `
				-Keyword $keyword `
				-EpisodePage $videoPageURL `
				-Force $script:forceSingleDownload
			Invoke-GarbageCollection
		}
	} else { break }
}

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('ダウンロード処理を終了しました。                                           ')
Write-Output ('---------------------------------------------------------------------------')
