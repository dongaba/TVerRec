###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		無視対象ビデオ削除処理スクリプト
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
#1/3 ダウンロードが中断した際にできたゴミファイルは削除
Write-Host '----------------------------------------------------------------------'
Write-Host 'ダウンロードが中断した際にできたゴミファイルを削除します'
Write-Host '----------------------------------------------------------------------'
Write-Progress `
	-Id 1 `
	-Activity '処理 1/3' `
	-PercentComplete $($( 1 / 3 ) * 100) `
	-Status 'ゴミファイルを削除'
Write-Progress `
	-Id 2 `
	-ParentId 1 `
	-Activity '1/3' `
	-PercentComplete $($( 1 / 3 ) * 100) `
	-Status "$($downloadBaseDir)"
deleteTrashFiles $downloadBaseDir '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*'
Write-Progress `
	-Id 2 `
	-ParentId 1 `
	-Activity '2/3' `
	-PercentComplete $($( 2 / 3 ) * 100) `
	-Status "$($downloadWorkDir)"
deleteTrashFiles $downloadWorkDir '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*, *.mp4'
Write-Progress `
	-Id 2 `
	-ParentId 1 `
	-Activity '3/3' `
	-PercentComplete $($( 3 / 3 ) * 100) `
	-Status "$($saveBaseDir)"
deleteTrashFiles $saveBaseDir '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*'

#======================================================================
#2/3 無視リストに入っている番組は削除
Write-Host '----------------------------------------------------------------------'
Write-Host '削除対象のビデオを削除します'
Write-Host '----------------------------------------------------------------------'
Write-Progress `
	-Id 1 `
	-Activity '処理 2/3' `
	-PercentComplete $($( 2 / 3 ) * 100) `
	-Status '削除対象のビデオを削除'

#ダウンロード対象外ビデオ番組リストの読み込み
$ignoreTitles = (Get-Content $ignoreFilePath -Encoding UTF8 | `
			Where-Object { !($_ -match '^\s*$') } | `
			Where-Object { !($_ -match '^;.*$') }) `
	-as [string[]]

$ignoreNum = 0						#無視リスト内の番号
if ($ignoreTitles -is [array]) {
	$ignoreTotal = $ignoreTitles.Length	#無視リスト内のエントリ合計数
} else { $ignoreTotal = 1 }

foreach ($ignoreTitle in $ignoreTitles) {
	$ignoreNum = $ignoreNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "$($ignoreNum)/$($ignoreTotal)" `
		-PercentComplete $($( $ignoreNum / $ignoreTotal ) * 100) `
		-Status "$($ignoreTitle)"

	Write-Host '----------------------------------------------------------------------'
	Write-Host "$($ignoreTitle)を処理中"
	try {
		$delTargets = Get-ChildItem `
			-Path $downloadBaseDir `
			-Directory `
			-Name `
			-Include "*$ignoreTitle*"
		if ($null -ne $delTargets) {
			Write-Host "  └「$($delTargets)」を削除します"
			foreach ($delTarget in $delTargets) {
				Remove-Item `
					-Path $delTarget `
					-Force `
					-ErrorAction SilentlyContinue
			}
		} else {
			Write-Host '  削除対象はありませんでした'
		}
	} catch { Write-Host '削除できないファイルがありました' }
}

#======================================================================
#3/3 空フォルダと隠しファイルしか入っていないフォルダを一気に削除
Write-Host '----------------------------------------------------------------------'
Write-Host '空フォルダ と 隠しファイルしか入っていないフォルダを削除します'
Write-Host '----------------------------------------------------------------------'
Write-Progress `
	-Id 1 `
	-Activity '処理 3/3' `
	-PercentComplete $($( 3 / 3 ) * 100) `
	-Status '空フォルダを削除'

$allSubDirs = @((Get-ChildItem -Path $downloadBaseDir -Recurse).Where({ $_.PSIsContainer })).FullName | `
		Sort-Object -Descending

$subDirNum = 0						#サブディレクトリの番号
if ($allSubDirs -is [array]) {
	$subDirTotal = $allSubDirs.Length	#サブディレクトリの合計数
} else { $subDirTotal = 1 }

foreach ($subDir in $allSubDirs) {
	$subDirNum = $subDirNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "$($subDirNum)/$($subDirTotal)" `
		-PercentComplete $($( $subDirNum / $subDirTotal ) * 100) `
		-Status "$($subDir)"

	Write-Host '----------------------------------------------------------------------'
	Write-Host "$($subDir)を処理中"
	if (@((Get-ChildItem -Path $subDir -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
		try {
			Write-Host "  └「$($subDir)」を削除します"
			Remove-Item `
				-Path $subDir `
				-Recurse `
				-Force `
				-ErrorAction SilentlyContinue
		} catch { Write-Host "空フォルダの削除に失敗しました: $subDir" }
	}
}

