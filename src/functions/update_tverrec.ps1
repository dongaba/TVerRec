###################################################################################
#
#		TVerRec自動アップデート処理スクリプト
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
Add-Type -AssemblyName System.IO.Compression.FileSystem

#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
function unZip {
	[CmdletBinding()]
	[OutputType([System.Void])]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('File')]
		[String]$zipArchive,
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('OutPath')]
		[String]$path
	)
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipArchive, $path)
}

#----------------------------------------------------------------------
#ディレクトリの上書き
#----------------------------------------------------------------------
function moveItem() {
	[CmdletBinding()]
	[OutputType([System.Void])]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Path')]
		[String]$src,
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Destination')]
		[String]$dist
	)

	if ((Test-Path $dist) -And (Test-Path -PathType Container $src)) {
		# ディレクトリ上書き(移動先に存在 かつ ディレクトリ)は再帰的に moveItem 呼び出し
		Get-ChildItem $src | ForEach-Object {
			moveItem $_.FullName $($dist + '\' + $_.Name)
		}
		# 移動し終わったディレクトリを削除
		Remove-Item `
			-Path $src `
			-Recurse `
			-Force
	} else {
		# 移動先に対象なし または ファイルの Move-Item に -Forece つけて実行
		Write-Output "$src  →  $dist"
		Move-Item `
			-Path $src `
			-Destination $dist `
			-Force
	}
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($script:myInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$local:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition
		$local:scriptRoot = Split-Path -Parent -Path $local:scriptRoot
	} else { $local:scriptRoot = Convert-Path .. }
	Set-Location $local:scriptRoot
} catch { Write-Error '❗ ディレクトリ設定に失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-Output ''
Write-Output '==========================================================================='
Write-Output '---------------------------------------------------------------------------'
Write-Output '                          TVerRecアップデート処理                          '
Write-Output '---------------------------------------------------------------------------'
Write-Output '==========================================================================='

$local:repo = 'dongaba/TVerRec'
$local:releases = "https://api.github.com/repos/$($local:repo)/releases/latest"

#念のため過去のバージョンがあれば削除し、作業ディレクトリを作成
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output '作業ディレクトリを作成します'
$updateTemp = $(Join-Path $local:scriptRoot '../tverrec-update-temp' )
if (Test-Path $updateTemp ) {
	Remove-Item `
		-Path $updateTemp `
		-Force `
		-Recurse
}
try {
	$null = New-Item `
		-ItemType Directory `
		-Path $updateTemp
} catch { Write-Error '❗ 作業ディレクトリの作成に失敗しました' ; exit 1 }

#TVerRecの最新バージョン取得
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'TVerRecの最新版をダウンロードします'
try {
	$local:zipURL = (
		Invoke-RestMethod `
			-Uri $local:releases `
			-Method Get `
	).zipball_url
	Invoke-WebRequest `
		-Uri $local:zipURL `
		-OutFile $(Join-Path $updateTemp 'TVerRecLatest.zip')
} catch { Write-Error '❗ ダウンロードに失敗しました' ; exit 1 }

#最新バージョンがダウンロードできていたら展開
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'ダウンロードしたTVerRecを解凍します'
try {
	if (Test-Path $(Join-Path $updateTemp 'TVerRecLatest.zip') -PathType Leaf) {
		#配下に作成されるディレクトリ名は不定「dongaba-TVerRec-xxxxxxxx」
		unZip `
			-File $(Join-Path $updateTemp 'TVerRecLatest.zip') `
			-OutPath $updateTemp
	} else { Write-Error '❗ ダウンロードしたファイルが見つかりません' ; exit 1 }
} catch { Write-Error '❗ ダウンロードしたファイルの解凍に失敗しました' ; exit 1 }

#ディレクトリは上書きできないので独自関数で以下のディレクトリをループ
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'ダウンロードしたTVerRecを配置します'
try {
	$newTVerRecDir = $(Get-ChildItem -Path $updateTemp -Directory ).fullname
	Get-ChildItem -Path $newTVerRecDir -Force `
	| ForEach-Object {
		# Move-Item を行う function として moveItem 作成して呼び出す
		moveItem `
			-Path $_.FullName `
			-Destination $($(Join-Path $local:scriptRoot '../') + $_.Name)
	}
} catch { Write-Error '❗ ダウンロードしたTVerRecの配置に失敗しました' ; exit 1 }

#作業ディレクトリを削除
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'アップデートの作業ディレクトリを削除します'
try {
	if (Test-Path $updateTemp ) {
		Remove-Item `
			-Path $updateTemp `
			-Force `
			-Recurse
	}
} catch { Write-Error '❗ 作業ディレクトリの削除に失敗しました' ; exit 1 }

#過去のバージョンで使用していたファイルを削除、または移行
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output '過去のバージョンで使用していたファイルを削除、または移行します'
#tver.lockをhistory.lockに移行(v2.6.5→v2.6.6)
if (Test-Path $(Join-Path $script:scriptRoot '../db/tver.lock') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../db/tver.lock') `
		-Force
}
#tver.sample.csvをhistory.sample.csvに移行(v2.6.5→v2.6.6)
if (Test-Path $(Join-Path $script:scriptRoot '../db/tver.sample.csv') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../db/tver.sample.csv') `
		-Force
}
#tver.csvをhistory.csvに移行(v2.6.5→v2.6.6)
if (Test-Path $(Join-Path $script:scriptRoot '../db/tver.csv') -PathType Leaf) {
	Rename-Item `
		-Path $(Join-Path $script:scriptRoot '../db/tver.csv') `
		-NewName 'history.csv' `
		-Force
}
#*.batを*.cmdに移行(v2.6.9→v2.7.0)
if (Test-Path $(Join-Path $script:scriptRoot '../win/*.bat') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../win/*.bat') `
		-Force
}
#TVerRec-Logo-Low.pngを削除(v2.7.5→v2.7.6)
if (Test-Path $(Join-Path $script:scriptRoot '../img/TVerRec-Logo-Low.png') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../img/TVerRec-Logo-Low.png') `
		-Force
}
#ダウンロード用のps1をリネーム(v2.7.5→v2.7.6)
if (Test-Path $(Join-Path $script:scriptRoot 'tverrec_bulk.ps1') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot 'tverrec_bulk.ps1') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot 'tverrec_list.ps1') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot 'tverrec_list.ps1') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot 'tverrec_single.ps1') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot 'tverrec_single.ps1') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot '../win/a.download_video.cmd') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../win/a.download_video.cmd') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot '../win/y.tverrec_list.cmd') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../win/y.tverrec_list.cmd') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot '../win/z.download_single_video.cmd') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../win/z.download_single_video.cmd') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot '../unix/a.download_video.sh') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../unix/a.download_video.sh') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot '../unix/y.tverrec_list.sh') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../unix/y.tverrec_list.sh') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot '../unix/z.download_single_video.sh') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../unix/z.download_single_video.sh') `
		-Force
}
#ダウンロード用のps1をリネーム(v2.7.6→v2.7.7)
if (Test-Path $(Join-Path $script:scriptRoot '../.wsb/setup/TVerRec')) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot '../.wsb/setup/TVerRec') `
		-Recurse `
		-Force
}
#youtube-dlの旧更新スクリプトの削除(v2.8.1→v2.8.2)
if (Test-Path $(Join-Path $script:scriptRoot 'functions/update_yt-dlp.ps1') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot 'functions/update_yt-dlp.ps1') `
		-Force
}
if (Test-Path $(Join-Path $script:scriptRoot 'functions/update_ytdl-patched.ps1') -PathType Leaf) {
	Remove-Item `
		-Path $(Join-Path $script:scriptRoot 'functions/update_ytdl-patched.ps1') `
		-Force
}

#実行権限の付与
if ($IsWindows -eq $false) {
	Write-Output ''
	Write-Output '-----------------------------------------------------------------'
	Write-Output '実行権限の付与します'
	(& chmod a+x $(Join-Path $script:scriptRoot '../unix/*.sh'))
}

Write-Output ''
Write-Output '==========================================================================='
Write-Output ''
Write-Output '💡 TVerRecのアップデートを終了しました。'
Write-Output ''
Write-Output '💡 TVerRecを再起動してください。'
Write-Output ''
Write-Output '==========================================================================='

exit 0
