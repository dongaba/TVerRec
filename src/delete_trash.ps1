###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		無視対象ビデオ削除処理スクリプト
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$script:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
		$script:scriptName = Split-Path -Leaf -Path $MyInvocation.MyCommand.Definition
	} else {
		$script:scriptRoot = Convert-Path .
	}
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '..\conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '..\dev')

	#----------------------------------------------------------------------
	#設定ファイル読み込み
	$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
	. $script:sysFile
	if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:confFile
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\common_functions.ps1'))
	. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\tver_functions.ps1'))

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
	$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
	if (Test-Path $script:devFunctionFile) {
		. $script:devFunctionFile
		Write-ColorOutput '開発ファイル用共通関数ファイルを読み込みました' -FgColor 'Yellow'
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Write-ColorOutput '開発ファイル用設定ファイルを読み込みました' -FgColor 'Yellow'
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================


#======================================================================
#1/3 ダウンロードが中断した際にできたゴミファイルは削除
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '処理が中断した際にできたゴミファイルを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
#進捗表示
ShowProgressToast `
	-Text1 'ファイルの掃除中' `
	-Text2 '　処理1/3 - ダウンロード中断時のゴミファイルを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

UpdateProgessToast `
	-Title $script:downloadWorkDir `
	-Rate $( 1 / 4 ) `
	-LeftText '' `
	-RrightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - 半日以上前のログファイル・ロックファイルを削除
$script:ffmpegErrorLogDir = Split-Path $script:ffpmegErrorLogPath | Convert-Path
deleteFiles `
	-Path $script:ffmpegErrorLogDir `
	-Conditions 'ffmpeg_error_*.log' `
	-DatePast -0.5
deleteFiles `
	-Path $scriptRoot `
	-Conditions 'brightcovenew_*.lock' `
	-DatePast -0.5

#進捗表示
UpdateProgessToast `
	-Title $script:downloadWorkDir `
	-Rate $( 2 / 4 ) `
	-LeftText '' `
	-RrightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - 作業ディレクトリ
deleteFiles `
	-Path $script:downloadWorkDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*, *.mp4' `
	-DatePast 0

#進捗表示
UpdateProgessToast `
	-Title $script:downloadBaseDir `
	-Rate $( 3 / 4 ) `
	-LeftText '' `
	-RrightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - ダウンロード先
deleteFiles `
	-Path $script:downloadBaseDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*' `
	-DatePast 0

#進捗表示
UpdateProgessToast `
	-Title $script:saveBaseDir `
	-Rate $( 4 / 4 ) `
	-LeftText '' `
	-RrightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - 保存先
deleteFiles `
	-Path $script:saveBaseDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*' `
	-DatePast 0

#======================================================================
#2/3 無視リストに入っている番組は削除
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '削除対象のビデオを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
#進捗表示
ShowProgressToast `
	-Text1 'ファイルの掃除中' `
	-Text2 '　処理2/3 - 削除対象のビデオを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

#ダウンロード対象外ビデオ番組リストの読み込み
$local:ignoreTitles = [string[]](Get-Content $script:ignoreFilePath -Encoding UTF8 | Where-Object { !($_ -match '^\s*$') } | Where-Object { !($_ -match '^;.*$') })
#処理
$local:ignoreNum = 0						#無視リスト内の番号
if ($local:ignoreTitles -is [array]) {
	$local:ignoreTotal = $local:ignoreTitles.Length	#無視リスト内のエントリ合計数
} else { $local:ignoreTotal = 1 }

#----------------------------------------------------------------------
$local:totalStartTime = Get-Date
foreach ($local:ignoreTitle in $local:ignoreTitles) {
	#処理時間の推計
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining = -1
	if ($local:ignoreNum -ne 0) {
		$local:secRemaining = ($local:secElapsed.TotalSeconds / $local:ignoreNum) * ($local:ignoreTotal - $local:ignoreNum)
		$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"
		$local:progressRatio = $($local:ignoreNum / $local:ignoreTotal)
	} else {
		$local:minRemaining = '計算中...'
		$local:progressRatio = 0
	}
	$local:ignoreNum = $local:ignoreNum + 1

	#進捗表示
	UpdateProgessToast `
		-Title $local:ignoreTitle `
		-Rate $local:progressRatio `
		-LeftText $local:ignoreNum/$local:ignoreTotal `
		-RrightText "残り時間 $local:minRemaining" `
		-Tag $script:appName `
		-Group 'Delete'

	#処理
	Write-ColorOutput "$($local:ignoreNum)/$($local:ignoreTotal) - $($local:ignoreTitle)" -NoNewline $true
	try { $local:delTargets = Get-ChildItem -LiteralPath $script:downloadBaseDir -Name -Filter "*$($local:ignoreTitle)*" }
	catch { Write-ColorOutput '　削除対象を特定できませんでした' -FgColor 'Green' }
	try {
		if ($null -ne $local:delTargets) {
			foreach ($local:delTarget in $local:delTargets) {
				if (Test-Path $(Join-Path $script:downloadBaseDir $local:delTarget)) {
					Write-ColorOutput "　「$(Join-Path $script:downloadBaseDir $local:delTarget)」を削除します" -FgColor 'Gray'
					Remove-Item -Path $(Join-Path $script:downloadBaseDir $local:delTarget) -Recurse -Force -ErrorAction SilentlyContinue
				} else { Write-ColorOutput '' }
			}
		} else { Write-ColorOutput '' }
	} catch { Write-ColorOutput '　削除できないファイルがありました' -FgColor 'Green' }
}
#----------------------------------------------------------------------

#======================================================================
#3/3 空フォルダと隠しファイルしか入っていないフォルダを一気に削除
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '空フォルダを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
#進捗表示
ShowProgressToast `
	-Text1 'ファイルの掃除中' `
	-Text2 '　処理3/3 - 空フォルダを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

#処理
$local:allSubDirs = $null
try {
	$local:allSubDirs = @((Get-ChildItem -LiteralPath $script:downloadBaseDir -Recurse).Where({ $_.PSIsContainer })).FullName | Sort-Object -Descending
} catch { }		#配下にディレクトリがない場合のエラー対策

$local:subDirNum = 0						#サブディレクトリの番号
if ($local:allSubDirs -is [array]) { $local:subDirTotal = $local:allSubDirs.Length }		#サブディレクトリの合計数
elseif ($null -ne $local:allSubDirs) { $local:subDirTotal = 1 }
else { $local:subDirTotal = 0 }

#----------------------------------------------------------------------
$local:totalStartTime = Get-Date

if ($local:subDirTotal -ne 0) {
	foreach ($local:subDir in $local:allSubDirs) {
		#処理時間の推計
		$local:secElapsed = (Get-Date) - $local:totalStartTime
		$local:secRemaining = -1
		if ($local:subDirNum -ne 0) {
			$local:secRemaining = ($local:secElapsed.TotalSeconds / $local:subDirNum) * ($local:subDirTotal - $local:subDirNum)
			$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"
			$local:progressRatio = $($local:subDirNum / $local:subDirTotal)
		} else {
			$local:minRemaining = '計算中...'
			$local:progressRatio = 0
		}
		$local:subDirNum = $local:subDirNum + 1

		UpdateProgessToast `
			-Title $local:subDir `
			-Rate $local:progressRatio `
			-LeftText $local:subDirNum/$local:subDirTotal `
			-RrightText "残り時間 $local:minRemaining" `
			-Tag $script:appName `
			-Group 'Delete'

		#処理
		Write-ColorOutput "$($local:subDirNum)/$($local:subDirTotal) - $($local:subDir)" -NoNewline $true
		if (@((Get-ChildItem -LiteralPath $local:subDir -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
			Write-ColorOutput "　「$($local:subDir)」を削除します" -FgColor 'Gray'
			try { Remove-Item -LiteralPath $local:subDir -Recurse -Force -ErrorAction SilentlyContinue }
			catch { Write-ColorOutput "　空フォルダの削除に失敗しました: $local:subDir" -FgColor 'Green' }
		} else { Write-ColorOutput '' }
	}
}
#----------------------------------------------------------------------

#進捗表示
UpdateProgessToast `
	-Title 'ファイルの掃除' `
	-Rate '1' `
	-LeftText '' `
	-RrightText '完了' `
	-Tag $script:appName `
	-Group 'Delete'

