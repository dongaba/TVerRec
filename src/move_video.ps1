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
		$global:currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$global:currentDir = Convert-Path .
	}
	Set-Location $global:currentDir
	$global:confDir = $(Join-Path $global:currentDir '..\conf')
	$global:sysFile = $(Join-Path $global:confDir 'system_setting.conf')
	$global:confFile = $(Join-Path $global:confDir 'user_setting.conf')
	$global:devDir = $(Join-Path $global:currentDir '..\dev')
	$global:devConfFile = $(Join-Path $global:devDir 'dev_setting.conf')
	$global:devFunctionFile = $(Join-Path $global:devDir 'dev_funcitons.ps1')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $global:sysFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression
	Get-Content $global:confFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if (Test-Path $global:devConfFile) {
		Get-Content $global:devConfFile -Encoding UTF8 `
		| Where-Object { $_ -notmatch '^\s*$' } `
		| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
		| Invoke-Expression
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $global:currentDir '.\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $global:currentDir '.\tver_functions_5.ps1'))
		if (Test-Path $global:devFunctionFile) { 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  PowerShell Coreではありません                         ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	} else {
		. $(Convert-Path (Join-Path $global:currentDir '.\common_functions.ps1'))
		. $(Convert-Path (Join-Path $global:currentDir '.\tver_functions.ps1'))
		if (Test-Path $global:devFunctionFile) { 
			. $global:devFunctionFile 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  開発ファイルを読み込みました                          ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	}
} catch { Write-Host '設定ファイルの読み込みに失敗しました' -ForegroundColor Green ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================
#保存先ディレクトリの存在確認
if (Test-Path $global:downloadBaseDir -PathType Container) {}
else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' -ForegroundColor Green ; exit 1 }
if (Test-Path $global:saveBaseDir -PathType Container) {}
else { Write-Error 'ビデオ移動先フォルダにアクセスできません。終了します。' -ForegroundColor Green ; exit 1 }

#======================================================================
#1/2 移動先フォルダを起点として、配下のフォルダを取得
Write-Host '==========================================================================='
Write-Host 'ビデオファイルを移動しています'
Write-Host '==========================================================================='
Write-Progress `
	-Id 1 `
	-Activity '処理 1/2' `
	-PercentComplete $($( 1 / 4 ) * 100) `
	-Status 'フォルダ一覧を作成中'

$local:moveToPaths = Get-ChildItem $global:saveBaseDir -Recurse `
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
	Write-Host '----------------------------------------------------------------------'
	Write-Host "$local:moveToPath を処理中"
	$local:moveToPathNum = $local:moveToPathNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "$($local:moveToPathNum)/$($local:moveToPathTotal)" `
		-PercentComplete $($( $local:moveToPathNum / $local:moveToPathTotal ) * 100) `
		-Status $local:moveToPath

	$local:targetFolderName = Split-Path -Leaf $local:moveToPath
	#同名フォルダが存在する場合は配下のファイルを移動
	$local:moveFromPath = $(Join-Path $global:downloadBaseDir $local:targetFolderName)
	if (Test-Path $local:moveFromPath) {
		$local:moveFromPath = $local:moveFromPath + '\*.mp4'
		Write-Host "  └「$($local:moveFromPath)」を移動します"
		try {
			Move-Item $local:moveFromPath -Destination $local:moveToPath -Force
		} catch {}
	}
}

#======================================================================
#2/2 空フォルダと隠しファイルしか入っていないフォルダを一気に削除
Write-Host '----------------------------------------------------------------------'
Write-Host '空フォルダ と 隠しファイルしか入っていないフォルダを削除します'
Write-Host '----------------------------------------------------------------------'
Write-Progress `
	-Id 1 `
	-Activity '処理 2/2' `
	-PercentComplete $($( 2 / 2 ) * 100) `
	-Status '空フォルダを削除'

$local:allSubDirs = @((Get-ChildItem -Path $global:downloadBaseDir -Recurse).Where({ $_.PSIsContainer })).FullName `
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

	Write-Host '----------------------------------------------------------------------'
	Write-Host "$($local:subDir)を処理中"
	if (@((Get-ChildItem -LiteralPath $local:subDir -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
		try {
			Write-Host "  └「$($local:subDir)」を削除します"
			Remove-Item `
				-LiteralPath $local:subDir `
				-Recurse -Force -ErrorAction SilentlyContinue
		} catch { Write-Host "空フォルダの削除に失敗しました: $local:subDir" -ForegroundColor Green }
	}
}

