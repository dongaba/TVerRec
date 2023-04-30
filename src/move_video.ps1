###################################################################################
#  TVerRec : TVerダウンローダ
#
#		番組移動処理スクリプト
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
	Write-Error 'ディレクトリ設定に失敗しました' ; exit 1
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

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#======================================================================
#ディレクトリの存在確認
if (!(Test-Path $script:downloadWorkDir -PathType Container)) {
	Write-Error 'ダウンロード作業ディレクトリが存在しません。終了します。' ; exit 1
}
if (!(Test-Path $script:downloadBaseDir -PathType Container)) {
	Write-Error '番組ダウンロード先ディレクトリにアクセスできません。終了します。' -Fg 'Green' ; exit 1
}
foreach ($local:saveDir in $script:saveBaseDirArray) {
	if (!(Test-Path $local:saveDir -PathType Container)) {
		Write-Error '番組移動先ディレクトリが存在しません。終了します。' ; exit 1
	}
}

#======================================================================
#1/2 移動先ディレクトリを起点として、配下のディレクトリを取得
Out-Msg '----------------------------------------------------------------------'
Out-Msg '移動先ディレクトリの一覧を作成しています'
Out-Msg '----------------------------------------------------------------------'

#進捗表示
showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理1/2 - ディレクトリ一覧を作成' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false


#======================================================================
#2/2 移動先ディレクトリと同名のディレクトリ配下の番組を移動
Out-Msg '----------------------------------------------------------------------'
Out-Msg 'ダウンロードファイルを移動しています'
Out-Msg '----------------------------------------------------------------------'


#進捗表示
showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理2/2 - ダウンロードファイルを移動' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

#処理
$local:moveToPaths = $null

foreach ($local:saveDir in $script:saveBaseDirArray) {
	$local:moveToPaths += Get-ChildItem `
		-Path $local:saveDir `
		-Recurse `
	| Where-Object { $_.PSIsContainer } `
	| Sort-Object
}

#移動先パス合計数
if ($local:moveToPaths -is [Array]) {
	$local:moveToPathTotal = $local:moveToPaths.Length
} elseif ($null -ne $local:moveToPaths) {
	$local:moveToPathTotal = 1
} else { $local:moveToPathTotal = 0 }

#----------------------------------------------------------------------
if ($local:moveToPathTotal -ne 0) {

	$local:moveToPaths.FullName | ForEach-Object -Parallel {
		#処理
		Write-Output "$($([Array]::IndexOf($using:local:moveToPaths.FullName, $_)) + 1)/$($using:local:moveToPaths.Count) - $($_)"
		$targetFolderName = Split-Path -Leaf $_
		if ($script:sortVideoByMedia) {
			$mediaName = Split-Path -Leaf $(Split-Path -Parent $_)
			$targetFolderName = $(Join-Path $mediaName $targetFolderName)
		}
		#同名ディレクトリが存在する場合は配下のファイルを移動
		$moveFromPath = $(Join-Path $using:script:downloadBaseDir $targetFolderName)
		if (Test-Path $moveFromPath) {
			$moveFromPath = $moveFromPath + '\*.mp4'
			Write-Host "　「$($local:moveFromPath)」を「$($_)」に移動します"
			try {
				Move-Item `
					-Path $local:moveFromPath `
					-Destination $_ `
					-Force
			} catch { Write-Output '　移動できないファイルがありました' }
		}
	} -ThrottleLimit 10

}
#----------------------------------------------------------------------

#進捗表示
updateProgressToast `
	-Title '番組の移動' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Move'
