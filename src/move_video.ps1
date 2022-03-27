###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画移動処理スクリプト
#
#	Copyright (c) 2021 dongaba
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
		$currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$currentDir = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
		if (!$currentDir) { $currentDir = '.' }
	}
	Set-Location $currentDir
	$confDir = $(Join-Path $currentDir '..\conf')
	$sysFile = $(Join-Path $confDir 'system_setting.conf')
	$confFile = $(Join-Path $confDir 'user_setting.conf')
	$devDir = $(Join-Path $currentDir '..\dev')
	$devConfFile = $(Join-Path $devDir 'dev_setting.conf')
	$devFunctionFile = $(Join-Path $devDir 'dev_funcitons.ps1')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $sysFile -Encoding UTF8 | `
			Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
	Get-Content $confFile -Encoding UTF8 | `
			Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if (Test-Path $devConfFile) {
		Get-Content $devConfFile -Encoding UTF8 | `
				Where-Object { $_ -notmatch '^\s*$' } | `
				Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
				Invoke-Expression
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. '.\common_functions_5.ps1'
		. '.\tver_functions_5.ps1'
		if (Test-Path $devFunctionFile) { 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  PowerShell Coreではありません                         ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
			exit 1
		}
	} else {
		. '.\common_functions.ps1'
		. '.\tver_functions.ps1'
		if (Test-Path $devFunctionFile) { 
			. $devFunctionFile 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  開発ファイルを読み込みました                          ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	}
} catch { Write-Host '設定ファイルの読み込みに失敗しました'; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================
#保存先ディレクトリの存在確認
if (Test-Path $downloadBaseAbsoluteDir -PathType Container) {}
else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' ; exit 1 }
if (Test-Path $saveBaseAbsoluteDir -PathType Container) {}
else { Write-Error 'ビデオ移動先フォルダにアクセスできません。終了します。' ; exit 1 }

#======================================================================
#1/2 移動先フォルダを起点として、配下のフォルダを取得
Write-Host '==========================================================================='
Write-Host 'ビデオファイルを移動しています'
Write-Host '==========================================================================='
Write-Progress `
	-Id 1 `
	-Activity 'ビデオを移動先フォルダに移動中' `
	-PercentComplete $($( 1 / 2 ) * 100) `
	-Status '1/2個目'

$moveToPaths = Get-ChildItem $saveBaseAbsoluteDir -Recurse | `
		Where-Object { $_.PSisContainer } | `
		Sort-Object 

$moveToPathNum = 0						#移動先パス番号
if ($moveToPaths -is [array]) {
	$moveToPathTotal = $moveToPaths.Length	#移動先パス合計数
} else { $moveToPathTotal = 1 }

foreach ($moveToPath in $moveToPaths) {
	Write-Host '----------------------------------------------------------------------'
	Write-Host "$moveToPath を処理します"
	Write-Host '----------------------------------------------------------------------'
	$moveToPathNum = $moveToPathNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "「$($moveToPath)」を移動中" `
		-PercentComplete $($( $moveToPathNum / $moveToPathTotal ) * 100) `
		-Status "$($moveToPathNum)/$($moveToPathTotal)個目"

	$targetFolderName = Split-Path -Leaf $moveToPath
	#同名フォルダが存在する場合は配下のファイルを移動
	$moveFromPath = $(Join-Path $downloadBaseAbsoluteDir $targetFolderName)
	if (Test-Path $moveFromPath) {
		$moveFromPath = $moveFromPath + '\*.mp4'
		Write-Host "  $moveFromPath を $moveToPath に移動します"
		try {
			Move-Item $moveFromPath -Destination $moveToPath -Force
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
	-Activity '空フォルダと隠しファイルしか入っていないフォルダを削除' `
	-PercentComplete $($( 2 / 2 ) * 100) `
	-Status '2/2個目'

$allSubDirs = @(Get-ChildItem -Path $downloadBaseAbsoluteDir -Recurse | `
			Where-Object { $_.PSIsContainer }) | `
			Sort-Object -Descending { $_.FullName }

$subDirNum = 0						#無視リスト内の番号
if ($ignoreTitles -is [array]) {
	$subDirTotal = $allSubDirs.Length	#無視リスト内のエントリ合計数
} else { $subDirTotal = 1 }

foreach ($subDir in $allSubDirs) {
	$subDirNum = $subDirNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "「$($subDir)」を削除中" `
		-PercentComplete $($( $subDirNum / $subDirTotal ) * 100) `
		-Status "$($subDirNum)/$($subDirTotal)個目"

	if (@(Get-ChildItem `
				-Path $subDir.FullName -Recurse | `
					Where-Object { ! $_.PSIsContainer }).Count -eq 0) {
		try {
			Remove-Item `
				-Path $subDir.FullName `
				-Recurse `
				-Force `
				-ErrorAction SilentlyContinue
		} catch { Write-Host "空フォルダの削除に失敗しました: $subDir.FullName" }
	}
}

Write-Progress -Id 2 -ParentId 1 -Completed
Write-Progress -Id 1 -Completed
