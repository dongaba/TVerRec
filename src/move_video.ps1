###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画移動処理スクリプト
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
} catch { Write-Error 'ディレクトリ設定に失敗しました' ; exit 1 }

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
	. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\common_functions.ps1'))
	. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\tver_functions.ps1'))
} catch { Write-Error '外部関数ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
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
} catch { Write-Error '開発用設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================
#保存先ディレクトリの存在確認
if (Test-Path $script:downloadBaseDir -PathType Container) { }
else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' -FgColor 'Green' ; exit 1 }
if (Test-Path $script:saveBaseDir -PathType Container) { }
else { Write-Error 'ビデオ移動先フォルダにアクセスできません。終了します。' -FgColor 'Green' ; exit 1 }

#======================================================================
#1/2 移動先フォルダを起点として、配下のフォルダを取得
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '移動先フォルダの一覧を作成しています'
Write-ColorOutput '----------------------------------------------------------------------'

#進捗表示
ShowProgressToast `
	-Text1 '動画の移動中' `
	-Text2 '　処理1/2 - フォルダ一覧を作成' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false


#======================================================================
#2/2 移動先フォルダと同名のフォルダ配下の動画を移動
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput 'ビデオファイルを移動しています'
Write-ColorOutput '----------------------------------------------------------------------'

#進捗表示
ShowProgressToast `
	-Text1 '動画の移動中' `
	-Text2 '　処理2/2 - 動画ファイルを移動' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

#処理
$local:moveToPaths = $null
$local:moveToPaths = Get-ChildItem $script:saveBaseDir -Recurse | Where-Object { $_.PSIsContainer } | Sort-Object

$local:moveToPathNum = 0						#移動先パス番号
if ($local:moveToPaths -is [array]) { $local:moveToPathTotal = $local:moveToPaths.Length }		#移動先パス合計数
elseif ($null -ne $local:moveToPaths) { $local:moveToPathTotal = 1 }
else { $local:moveToPathTotal = 0 }

#----------------------------------------------------------------------
$local:totalStartTime = Get-Date

if ($local:moveToPathTotal -ne 0) {
	foreach ($local:moveToPath in $local:moveToPaths.FullName) {

		#処理時間の推計
		$local:secElapsed = (Get-Date) - $local:totalStartTime
		$local:secRemaining = -1
		if ($local:moveToPathNum -ne 0) {
			$local:secRemaining = ($local:secElapsed.TotalSeconds / $local:moveToPathNum) * ($local:moveToPathTotal - $local:moveToPathNum)
			$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"
			$local:progressRatio = $($local:moveToPathNum / $local:moveToPathTotal)
		} else {
			$local:minRemaining = '計算中...'
			$local:progressRatio = 0
		}
		$local:moveToPathNum = $local:moveToPathNum + 1

		#進捗表示
		UpdateProgessToast `
			-Title $local:moveToPath `
			-Rate $local:progressRatio `
			-LeftText $local:moveToPathNum/$local:moveToPathTotal `
			-RrightText "残り時間 $local:minRemaining" `
			-Tag $script:appName `
			-Group 'Move'

		#処理
		Write-ColorOutput "$($local:moveToPathNum)/$($local:moveToPathTotal) - $($local:moveToPath)" -NoNewline $true
		$local:targetFolderName = Split-Path -Leaf $local:moveToPath
		#同名フォルダが存在する場合は配下のファイルを移動
		$local:moveFromPath = $(Join-Path $script:downloadBaseDir $local:targetFolderName)
		if (Test-Path $local:moveFromPath) {
			$local:moveFromPath = $local:moveFromPath + '\*.mp4'
			Write-ColorOutput "　「$($local:moveFromPath)」を移動します" -FgColor 'Gray'
			try { Move-Item $local:moveFromPath -Destination $local:moveToPath -Force }
			catch { Write-ColorOutput '　移動できないファイルがありました' -FgColor 'Green' }
		} else { Write-ColorOutput '' }
	}
}
#----------------------------------------------------------------------

#進捗表示
UpdateProgessToast `
	-Title '動画の移動' `
	-Rate '1' `
	-LeftText '' `
	-RrightText '完了' `
	-Tag $script:appName `
	-Group 'Move'
