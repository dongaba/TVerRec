###################################################################################
#  TVerRec : TVerダウンローダ
#
#		ダウンロード対象外番組削除処理スクリプト
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
	} else {
		$script:scriptRoot = Convert-Path .
	}
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '../conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '../dev')
} catch {
	Write-Error 'ディレクトリ設定に失敗しました'; exit 1
}

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
	. $script:sysFile
	if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:confFile
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/tver_functions.ps1'))
} catch { Write-Error '外部関数ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
	$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
	$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
	if (Test-Path $script:devFunctionFile) {
		. $script:devFunctionFile
		Out-Msg '開発ファイル用共通関数ファイルを読み込みました' -Fg 'Yellow'
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Out-Msg '開発ファイル用設定ファイルを読み込みました' -Fg 'Yellow'
	}
} catch { Write-Error '開発用設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#======================================================================
#1/3 ダウンロードが中断した際にできたゴミファイルは削除
Out-Msg '----------------------------------------------------------------------'
Out-Msg '処理が中断した際にできたゴミファイルを削除します'
Out-Msg '----------------------------------------------------------------------'
#進捗表示
showProgressToast `
	-Text1 'ファイルの掃除中' `
	-Text2 '　処理1/3 - ダウンロード中断時のゴミファイルを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

updateProgressToast `
	-Title $script:downloadWorkDir `
	-Rate $( 1 / 4 ) `
	-LeftText '' `
	-RightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - 半日以上前のログファイル・ロックファイルを削除
$script:ffmpegErrorLogDir = `
	Split-Path $script:ffpmegErrorLogPath `
| Convert-Path
deleteFiles `
	-Path $script:ffmpegErrorLogDir `
	-Conditions 'ffmpeg_error_*.log' `
	-DatePast -0.5
deleteFiles `
	-Path $scriptRoot `
	-Conditions 'brightcovenew_*.lock' `
	-DatePast -0.5

#進捗表示
updateProgressToast `
	-Title $script:downloadWorkDir `
	-Rate $( 2 / 4 ) `
	-LeftText '' `
	-RightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - 作業ディレクトリ
deleteFiles `
	-Path $script:downloadWorkDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*, *.mp4' `
	-DatePast 0

#進捗表示
updateProgressToast `
	-Title $script:downloadBaseDir `
	-Rate $( 3 / 4 ) `
	-LeftText '' `
	-RightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - ダウンロード先
deleteFiles `
	-Path $script:downloadBaseDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*' `
	-DatePast 0

#進捗表示
updateProgressToast `
	-Title $script:saveBaseDir `
	-Rate $( 4 / 4 ) `
	-LeftText '' `
	-RightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#処理 - 保存先
deleteFiles `
	-Path $script:saveBaseDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*' `
	-DatePast 0

#======================================================================
#2/3 ダウンロード対象外に入っている番組は削除
Out-Msg '----------------------------------------------------------------------'
Out-Msg 'ダウンロード対象外の番組を削除します'
Out-Msg '----------------------------------------------------------------------'
#進捗表示
showProgressToast `
	-Text1 'ファイルの掃除中' `
	-Text2 '　処理2/3 - ダウンロード対象外の番組を削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

#ダウンロード対象外番組の読み込み
$local:ignoreTitles = [String[]](Get-Content `
		-Path $script:ignoreFilePath `
		-Encoding UTF8 `
	| Where-Object { !($_ -match '^\s*$') } `
	| Where-Object { !($_ -match '^;.*$') })
#ダウンロード対象外内の番号
$local:ignoreNum = 0
if ($local:ignoreTitles -is [Array]) {
	#ダウンロード対象外内のエントリ合計数
	$local:ignoreTotal = $local:ignoreTitles.Length
} else { $local:ignoreTotal = 1 }

#----------------------------------------------------------------------
$local:totalStartTime = Get-Date
foreach ($local:ignoreTitle in $local:ignoreTitles) {
	#処理時間の推計
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining = -1
	if ($local:ignoreNum -ne 0) {
		$local:secRemaining = `
		($local:secElapsed.TotalSeconds / $local:ignoreNum) `
			* ($local:ignoreTotal - $local:ignoreNum)
		$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"
		$local:progressRatio = $($local:ignoreNum / $local:ignoreTotal)
	} else {
		$local:minRemaining = '計算中...'
		$local:progressRatio = 0
	}
	$local:ignoreNum = $local:ignoreNum + 1

	#進捗表示
	updateProgressToast `
		-Title $local:ignoreTitle `
		-Rate $local:progressRatio `
		-LeftText $local:ignoreNum/$local:ignoreTotal `
		-RightText "残り時間 $local:minRemaining" `
		-Tag $script:appName `
		-Group 'Delete'

	#処理
	Out-Msg "$($local:ignoreNum)/$($local:ignoreTotal) - $($local:ignoreTitle)" -NoNL $true
	try {
		$local:delTargets = `
			Get-ChildItem `
			-LiteralPath $script:downloadBaseDir `
			-Name -Filter "*$($local:ignoreTitle)*"
	} catch { Out-Msg '　削除対象を特定できませんでした' -Fg 'Green' }
	try {
		if ($null -ne $local:delTargets) {
			foreach ($local:delTarget in $local:delTargets) {
				if (Test-Path $(Join-Path $script:downloadBaseDir $local:delTarget)) {
					Out-Msg "　「$(Join-Path $script:downloadBaseDir $local:delTarget)」を削除します" -Fg 'Gray'
					Remove-Item `
						-Path $(Join-Path $script:downloadBaseDir $local:delTarget) `
						-Recurse `
						-Force `
						-ErrorAction SilentlyContinue
				} else { Out-Msg '' }
			}
		} else { Out-Msg '' }
	} catch { Out-Msg '　削除できないファイルがありました' -Fg 'Green' }
}
#----------------------------------------------------------------------

#======================================================================
#3/3 空ディレクトリと隠しファイルしか入っていないディレクトリを一気に削除
Out-Msg '----------------------------------------------------------------------'
Out-Msg '空ディレクトリを削除します'
Out-Msg '----------------------------------------------------------------------'
#進捗表示
showProgressToast `
	-Text1 'ファイルの掃除中' `
	-Text2 '　処理3/3 - 空ディレクトリを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

#処理
$local:allSubDirs = $null
try {
	$local:allSubDirs = @((Get-ChildItem -LiteralPath $script:downloadBaseDir -Recurse).`
			Where({ $_.PSIsContainer })).`
		FullName `
	| Sort-Object -Descending
} catch { Out-Msg '　ディレクトリを見つけられませんでした' -Fg 'Green' }

#サブディレクトリの番号
$local:subDirNum = 0
if ($local:allSubDirs -is [Array]) {
	#サブディレクトリの合計数
	$local:subDirTotal = $local:allSubDirs.Length
} elseif ($null -ne $local:allSubDirs) {
	$local:subDirTotal = 1
} else { $local:subDirTotal = 0 }

#----------------------------------------------------------------------
$local:totalStartTime = Get-Date

if ($local:subDirTotal -ne 0) {
	foreach ($local:subDir in $local:allSubDirs) {
		#処理時間の推計
		$local:secElapsed = (Get-Date) - $local:totalStartTime
		$local:secRemaining = -1
		if ($local:subDirNum -ne 0) {
			$local:secRemaining = `
			($local:secElapsed.TotalSeconds / $local:subDirNum) `
				* ($local:subDirTotal - $local:subDirNum)
			$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"
			$local:progressRatio = $($local:subDirNum / $local:subDirTotal)
		} else {
			$local:minRemaining = '計算中...'
			$local:progressRatio = 0
		}
		$local:subDirNum = $local:subDirNum + 1

		updateProgressToast `
			-Title $local:subDir `
			-Rate $local:progressRatio `
			-LeftText $local:subDirNum/$local:subDirTotal `
			-RightText "残り時間 $local:minRemaining" `
			-Tag $script:appName `
			-Group 'Delete'

		#処理
		Out-Msg "$($local:subDirNum)/$($local:subDirTotal) - $($local:subDir)" -NoNL $true
		if (@((Get-ChildItem -LiteralPath $local:subDir -Recurse).`
					Where({ ! $_.PSIsContainer })).Count -eq 0) {
			Out-Msg "　「$($local:subDir)」を削除します" -Fg 'Gray'
			try {
				Remove-Item `
					-LiteralPath $local:subDir `
					-Recurse `
					-Force `
					-ErrorAction SilentlyContinue
			} catch {
				Out-Msg "　空ディレクトリの削除に失敗しました: $local:subDir" -Fg 'Green'
			}
		} else {
			Out-Msg ''
		}
	}
}
#----------------------------------------------------------------------

#進捗表示
updateProgressToast `
	-Title 'ファイルの掃除' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Delete'

