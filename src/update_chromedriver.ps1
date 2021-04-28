###################################################################################
#  tverrec : TVerビデオダウンローダ
#
#		Windows用chromedriver最新化処理スクリプト
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

$scriptRoot = if ($PSScriptRoot -eq '') { '.' } else { $PSScriptRoot }

#chromedriver保存先相対Path
$chromeDriverRelativeDir = '..\lib'
$chromeDriverDir = $(Join-Path $scriptRoot $chromeDriverRelativeDir)
$chromeDriverFileLocation = $(Join-Path $chromeDriverDir 'chromedriver.exe')

#Chromeバージョン取得
$chromeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo('C:\Program Files (x86)\Google\Chrome\Application\chrome.exe').FileVersion
$chromeMajorVersion = $chromeVersion.split('.')[0]

#chromedriverのディレクトリがなければ作成
if (-Not (Test-Path $chromeDriverDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $chromeDriverDir
}

#chromedriverのバージョン取得
if (Test-Path $chromeDriverFileLocation -PathType Leaf) {
	# get version of current chromedriver.exe
	$chromeDriverFileVersion = (& $chromeDriverFileLocation --version)
	$chromeDriverFileVersionHasMatch = $chromeDriverFileVersion -match 'ChromeDriver (\d+\.\d+\.\d+(\.\d+)?)'
	$chromeDriverCurrentVersion = $matches[1]
	if (-Not $chromeDriverFileVersionHasMatch) { exit }
} else {
	# if chromedriver.exe not found, will download it
	$chromeDriverCurrentVersion = ''
}

#Chromeのバージョンが72以下のときの特殊ロジック
if ($chromeMajorVersion -lt 73) {
	# for chrome versions < 73 will use chromedriver v2.46 (which supports chrome v71-73)
	$chromeDriverExpectedVersion = '2.46'
	$chromeDriverVersionUrl = 'https://chromedriver.storage.googleapis.com/LATEST_RELEASE'
}
#Chromeのバージョンに合わせてchromedriverのダウンロードURLを生成
else {
	$chromeDriverExpectedVersion = $chromeVersion.split('.')[0..2] -join '.'
	$chromeDriverVersionUrl = 'https://chromedriver.storage.googleapis.com/LATEST_RELEASE_' + $chromeDriverExpectedVersion
}

#chromedriverのダウンロード
$chromeDriverLatestVersion = Invoke-RestMethod -Uri $chromeDriverVersionUrl

Write-Host "chrome version:       $chromeVersion"
Write-Host "chromedriver version: $chromeDriverCurrentVersion"
Write-Host "chromedriver latest:  $chromeDriverLatestVersion"

#ダウンロードしたchromedriverの展開
if ($chromeDriverCurrentVersion -ne $chromeDriverLatestVersion) {
	$chromeDriverZipLink = 'https://chromedriver.storage.googleapis.com/' + $chromeDriverLatestVersion + '/chromedriver_win32.zip'
	Write-Host "chromedriverをダウンロードします。 $chromeDriverZipLink"

	$chromeDriverZipFileLocation = $(Join-Path $chromeDriverDir 'chromedriver_win32.zip')

	Invoke-WebRequest -Uri $chromeDriverZipLink -OutFile $chromeDriverZipFileLocation
	Expand-Archive $chromeDriverZipFileLocation -DestinationPath $(Join-Path $scriptRoot $chromeDriverRelativeDir) -Force
	Remove-Item -Path $chromeDriverZipFileLocation -Force
	$chromeDriverFileVersion = (& $chromeDriverFileLocation --version)
	Write-Host "chromedriverをversion $chromeDriverFileVersion に更新しました。 "
} else {
	Write-Host 'chromedriverは最新です。 '
	Write-Host ''
}
