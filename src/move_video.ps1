###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画移動処理スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
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
	$script:confDir = $(Join-Path $script:scriptRoot '..\conf')
	$script:sysFile = $(Join-Path $script:confDir 'system_setting.conf')
	$script:confFile = $(Join-Path $script:confDir 'user_setting.conf')
	$script:devDir = $(Join-Path $script:scriptRoot '..\dev')
	$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.conf')
	$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $script:sysFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression
	Get-Content $script:confFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if (Test-Path $script:devConfFile) {
		Get-Content $script:devConfFile -Encoding UTF8 `
		| Where-Object { $_ -notmatch '^\s*$' } `
		| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
		| Invoke-Expression
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '.\tver_functions_5.ps1'))
		if (Test-Path $script:devFunctionFile) {
			Write-ColorOutput '========================================================' white DarkGreen
			Write-ColorOutput '  PowerShell Coreではありません                         ' white DarkGreen
			Write-ColorOutput '========================================================' white DarkGreen
		}
	} else {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\common_functions.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '.\tver_functions.ps1'))
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '========================================================' white DarkGreen
			Write-ColorOutput '  開発ファイルを読み込みました                          ' white DarkGreen
			Write-ColorOutput '========================================================' white DarkGreen
		}
	}
} catch { Write-ColorOutput '設定ファイルの読み込みに失敗しました' Green ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================
#保存先ディレクトリの存在確認
if (Test-Path $script:downloadBaseDir -PathType Container) {}
else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' Green ; exit 1 }
if (Test-Path $script:saveBaseDir -PathType Container) {}
else { Write-Error 'ビデオ移動先フォルダにアクセスできません。終了します。' Green ; exit 1 }

#======================================================================
#1/2 移動先フォルダを起点として、配下のフォルダを取得
Write-ColorOutput '==========================================================================='
Write-ColorOutput 'ビデオファイルを移動しています'
Write-ColorOutput '==========================================================================='
Write-Progress `
	-Id 1 `
	-Activity '処理 1/2' `
	-PercentComplete $($( 1 / 4 ) * 100) `
	-Status 'フォルダ一覧を作成中'

$local:moveToPaths = Get-ChildItem $script:saveBaseDir -Recurse `
| Where-Object { $_.PSisContainer } `
| Sort-Object

$local:moveToPathNum = 0						#移動先パス番号
if ($local:moveToPaths -is [array]) {
	$local:moveToPathTotal = $local:moveToPaths.Length	#移動先パス合計数
} else { $local:moveToPathTotal = 1 }

Write-Progress `
	-Id 1 `
	-Activity '処理 1/2' `
	-PercentComplete $($( 1 / 2 ) * 100) `
	-Status 'ファイルを移動中'

foreach ($local:moveToPath in $local:moveToPaths) {
	Write-ColorOutput '----------------------------------------------------------------------'
	Write-ColorOutput "$local:moveToPath を処理中"
	$local:moveToPathNum = $local:moveToPathNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "$($local:moveToPathNum)/$($local:moveToPathTotal)" `
		-PercentComplete $($( $local:moveToPathNum / $local:moveToPathTotal ) * 100) `
		-Status $local:moveToPath

	$local:targetFolderName = Split-Path -Leaf $local:moveToPath
	#同名フォルダが存在する場合は配下のファイルを移動
	$local:moveFromPath = $(Join-Path $script:downloadBaseDir $local:targetFolderName)
	if (Test-Path $local:moveFromPath) {
		$local:moveFromPath = $local:moveFromPath + '\*.mp4'
		Write-ColorOutput "  └「$($local:moveFromPath)」を移動します"
		try {
			Move-Item $local:moveFromPath -Destination $local:moveToPath -Force
		} catch { Write-ColorOutput '移動できないファイルがありました' Green }
	}
}

#======================================================================
#2/2 空フォルダと隠しファイルしか入っていないフォルダを一気に削除
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '空フォルダ と 隠しファイルしか入っていないフォルダを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
Write-Progress `
	-Id 1 `
	-Activity '処理 2/2' `
	-PercentComplete $($( 2 / 2 ) * 100) `
	-Status '空フォルダを削除'

$local:allSubDirs = @((Get-ChildItem -Path $script:downloadBaseDir -Recurse).Where({ $_.PSIsContainer })).FullName `
| Sort-Object -Descending

$local:subDirNum = 0						#サブディレクトリの番号
if ($local:allSubDirs -is [array]) {
	$local:subDirTotal = $local:allSubDirs.Length	#サブディレクトリの合計数
} else { $local:subDirTotal = 1 }

foreach ($local:subDir in $local:allSubDirs) {
	$local:subDirNum = $local:subDirNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "$($local:subDirNum)/$($local:subDirTotal)" `
		-PercentComplete $($( $local:subDirNum / $local:subDirTotal ) * 100) `
		-Status $local:subDir

	Write-ColorOutput '----------------------------------------------------------------------'
	Write-ColorOutput "$($local:subDir)を処理中"
	if (@((Get-ChildItem -LiteralPath $local:subDir -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
		try {
			Write-ColorOutput "  └「$($local:subDir)」を削除します"
			Remove-Item `
				-LiteralPath $local:subDir `
				-Recurse -Force -ErrorAction SilentlyContinue
		} catch { Write-ColorOutput "空フォルダの削除に失敗しました: $local:subDir" Green }
	}
}

