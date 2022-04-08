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
		$global:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$global:scriptRoot = Convert-Path .
	}
	Set-Location $global:scriptRoot
	$global:confDir = $(Join-Path $global:scriptRoot '..\conf')
	$global:sysFile = $(Join-Path $global:confDir 'system_setting.conf')
	$global:confFile = $(Join-Path $global:confDir 'user_setting.conf')
	$global:devDir = $(Join-Path $global:scriptRoot '..\dev')
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
		. $(Convert-Path (Join-Path $global:scriptRoot '.\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $global:scriptRoot '.\tver_functions_5.ps1'))
		if (Test-Path $global:devFunctionFile) {
			Write-ColorOutput '========================================================' Green
			Write-ColorOutput '  PowerShell Coreではありません                         ' Green
			Write-ColorOutput '========================================================' Green
		}
	} else {
		. $(Convert-Path (Join-Path $global:scriptRoot '.\common_functions.ps1'))
		. $(Convert-Path (Join-Path $global:scriptRoot '.\tver_functions.ps1'))
		if (Test-Path $global:devFunctionFile) {
			. $global:devFunctionFile
			Write-ColorOutput '========================================================' Green
			Write-ColorOutput '  開発ファイルを読み込みました                          ' Green
			Write-ColorOutput '========================================================' Green
		}
	}
} catch { Write-ColorOutput '設定ファイルの読み込みに失敗しました' Green ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================
#1/3 ダウンロードが中断した際にできたゴミファイルは削除
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput 'ダウンロードが中断した際にできたゴミファイルを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
try {
	Get-ChildItem -Path $global:downloadWorkDir -Recurse -Filter 'ffmpeg_error_*.log' `
	| Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-0.5) } `
	| Remove-Item -Force -ErrorAction SilentlyContinue
} catch { Write-ColorOutput "ffmpegエラーファイルを削除できませんでした" Green }
try {
	Get-ChildItem -Path $scriptRoot -Recurse -Filter 'brightcovenew_*.lock' `
	| Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-0.5) } `
	| Remove-Item -Force -ErrorAction SilentlyContinue
} catch { Write-ColorOutput "youtube-dlのロックファイルを削除できませんでした" Green }
Write-Progress -Id 1 `
	-Activity '処理 1/3' `
	-PercentComplete $($( 1 / 3 ) * 100) `
	-Status 'ゴミファイルを削除'
Write-Progress -Id 2 -ParentId 1 `
	-Activity '1/3' `
	-PercentComplete $($( 1 / 3 ) * 100) `
	-Status $global:downloadBaseDir
deleteTrashFiles $global:downloadWorkDir '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*, *.mp4'
Write-Progress -Id 2 -ParentId 1 `
	-Activity '2/3' `
	-PercentComplete $($( 2 / 3 ) * 100) `
	-Status $global:downloadWorkDir
deleteTrashFiles $global:downloadBaseDir '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*'
Write-Progress -Id 2 -ParentId 1 `
	-Activity '3/3' `
	-PercentComplete $($( 3 / 3 ) * 100) `
	-Status $global:saveBaseDir
deleteTrashFiles $global:saveBaseDir '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*'

#======================================================================
#2/3 無視リストに入っている番組は削除
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '削除対象のビデオを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
Write-Progress -Id 1 `
	-Activity '処理 2/3' `
	-PercentComplete $($( 2 / 3 ) * 100) `
	-Status '削除対象のビデオを削除'

#ダウンロード対象外ビデオ番組リストの読み込み
$local:ignoreTitles = (Get-Content $global:ignoreFilePath -Encoding UTF8 `
	| Where-Object { !($_ -match '^\s*$') } `
	| Where-Object { !($_ -match '^;.*$') }) `
	-as [string[]]

$local:ignoreNum = 0						#無視リスト内の番号
if ($local:ignoreTitles -is [array]) {
	$local:ignoreTotal = $local:ignoreTitles.Length	#無視リスト内のエントリ合計数
} else { $local:ignoreTotal = 1 }

foreach ($local:ignoreTitle in $local:ignoreTitles) {
	$local:ignoreNum = $local:ignoreNum + 1
	Write-Progress -Id 2 -ParentId 1 `
		-Activity "$($local:ignoreNum)/$($local:ignoreTotal)" `
		-PercentComplete $($( $local:ignoreNum / $local:ignoreTotal ) * 100) `
		-Status $local:ignoreTitle

	Write-ColorOutput '----------------------------------------------------------------------'
	Write-ColorOutput "$($local:ignoreTitle)を処理中"
	try {
		$local:delTargets = Get-ChildItem -LiteralPath $global:downloadBaseDir `
			-Directory -Name -Filter "*$($local:ignoreTitle)*"
	} catch { Write-ColorOutput '削除対象を特定できませんでした' Green }
	try {
		if ($null -ne $local:delTargets) {
			foreach ($local:delTarget in $local:delTargets) {
				if (Test-Path $(Join-Path $global:downloadBaseDir $local:delTarget) -PathType Container) {
					Write-ColorOutput "  └「$(Join-Path $global:downloadBaseDir $local:delTarget)」を削除します"
					Remove-Item -Path $(Join-Path $global:downloadBaseDir $local:delTarget) `
						-Recurse -Force -ErrorAction SilentlyContinue
				}
			}
		} else {
			Write-ColorOutput '  削除対象はありませんでした'
		}
	} catch { Write-ColorOutput '削除できないファイルがありました' Green }
}

#======================================================================
#3/3 空フォルダと隠しファイルしか入っていないフォルダを一気に削除
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '空フォルダ と 隠しファイルしか入っていないフォルダを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
Write-Progress -Id 1 -Activity '処理 3/3' `
	-PercentComplete $($( 3 / 3 ) * 100) `
	-Status '空フォルダを削除'

$local:allSubDirs = @((Get-ChildItem -LiteralPath $global:downloadBaseDir -Recurse).Where({ $_.PSIsContainer })).FullName `
| Sort-Object -Descending

$local:subDirNum = 0						#サブディレクトリの番号
if ($local:allSubDirs -is [array]) {
	$local:subDirTotal = $local:allSubDirs.Length	#サブディレクトリの合計数
} else { $local:subDirTotal = 1 }

foreach ($local:subDir in $local:allSubDirs) {
	$local:subDirNum = $local:subDirNum + 1
	Write-Progress -Id 2 -ParentId 1 `
		-Activity "$($local:subDirNum)/$($local:subDirTotal)" `
		-PercentComplete $($( $local:subDirNum / $local:subDirTotal ) * 100) `
		-Status $local:subDir

	Write-ColorOutput '----------------------------------------------------------------------'
	Write-ColorOutput "$($local:subDir)を処理中"
	if (@((Get-ChildItem -LiteralPath $local:subDir -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
		try {
			Write-ColorOutput "  └「$($local:subDir)」を削除します"
			Remove-Item -LiteralPath $local:subDir `
				-Recurse -Force -ErrorAction SilentlyContinue
		} catch { Write-ColorOutput "空フォルダの削除に失敗しました: $local:subDir" Green }
	}
}

