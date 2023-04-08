###################################################################################
#  TVerRec : TVerダウンローダ
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
function Unzip {
	[OutputType([System.Void])]
	param(
		[Parameter(Mandatory = $true)]
		[Alias('Path')]
		[string]$zipArchive,
		[Parameter(Mandatory = $true)]
		[Alias('OutFile')]
		[string]$outpath
	)
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipArchive, $outpath)
}

#----------------------------------------------------------------------
#ディレクトリの上書き
#----------------------------------------------------------------------
function moveItem() {
	[OutputType([System.Void])]
	param(
		[Parameter(Mandatory = $true)]
		[Alias('Path')]
		[string]$src,
		[Parameter(Mandatory = $true)]
		[Alias('Destination')]
		[string]$dist
	)

	if ((Test-Path $dist) -and (Test-Path -PathType Container $src)) {
		# フォルダ上書き(移動先に存在 かつ フォルダ)は再帰的に moveItem 呼び出し
		Get-ChildItem $src | ForEach-Object {
			moveItem $_.FullName $($dist + '\' + $_.Name);
		}
		# 移動し終わったフォルダを削除
		Remove-Item $src -Recurse -Force;
		#Write-Output "$src  ->  $dist"
		#Move-Item $src -Destination $dist -Force;
	} else {
		# 移動先に対象なし または ファイルの Move-Item に -Forece つけて実行
		Write-Output "$src  ->  $dist"
		Move-Item $src -Destination $dist -Force;
	}
}

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
} catch { Write-Error 'ディレクトリ設定に失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-Output ''
Write-Output '==========================================================================='
Write-Output '---------------------------------------------------------------------------'
Write-Output '                          TVerRecアップデート処理                          '
Write-Output '---------------------------------------------------------------------------'
Write-Output '==========================================================================='

$progressPreference = 'silentlyContinue'

#念のため過去のバージョンがあれば削除し、作業フォルダを作成
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output '作業フォルダを作成します'
$updateTemp = $(Join-Path $script:scriptRoot '..\tverrec-update-temp' )
if (Test-Path $updateTemp ) { Remove-Item -Path $updateTemp -Force -Recurse }
New-Item -ItemType Directory -Path $updateTemp

#TVerRecの最新バージョン取得
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'TVerRecの最新版をダウンロードします'
$local:repo = 'dongaba/TVerRec'
$local:releases = "https://api.github.com/repos/$($local:repo)/releases/latest"
try {
	$local:zipURL = $((Invoke-WebRequest -Uri $local:releases).content | ConvertFrom-Json).zipball_url
	Invoke-WebRequest -Uri $local:zipURL -OutFile $(Join-Path $updateTemp 'New.zip')
} catch { return }

#最新バージョンがダウンロードできていたら展開
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'ダウンロードしたTVerRecを解凍します'
if (Test-Path $(Join-Path $updateTemp 'New.zip') -PathType Leaf) {
	#配下に作成されるフォルダ名は不定「dongaba-TVerRec-xxxxxxxx」
	Unzip -Path $(Join-Path $updateTemp 'New.zip') -OutFile $updateTemp
}

#フォルダは上書きできないので独自関数で以下のフォルダをループ
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'ダウンロードしたTVerRecdを配置します'
$newTVerRecDir = $(Get-ChildItem $updateTemp -Directory ).fullname
Get-ChildItem $newTVerRecDir | ForEach-Object {
	# Move-Item を行う function として moveItem 作成して呼び出す
	moveItem $_.FullName -Destination $($( Convert-Path $(Join-Path $script:scriptRoot '..\')) + $_.Name)
}

#作業フォルダを削除
Write-Output ''
Write-Output '-----------------------------------------------------------------'
Write-Output 'アップデートの作業フォルダを削除します'
if (Test-Path $updateTemp ) { Remove-Item -Path $updateTemp -Force -Recurse }

$progressPreference = 'Continue'

Write-Output ''
Write-Output 'TVerRecのアップデートを終了しました。'
Write-Output ''
Write-Output '==========================================================================='

exit
