###################################################################################
#  tverrec : TVerビデオダウンローダ
#		Windows用ffmpeg最新化処理スクリプト
###################################################################################

$scriptRoot = if ($PSScriptRoot -eq '') { '.' } else { $PSScriptRoot }

#ffmpeg保存先相対Path
$ffmpegRelativeDir = '..\bin'
$ffmpegDir = $(Join-Path $scriptRoot $ffmpegRelativeDir)
$ffmpegFile = $(Join-Path $ffmpegDir 'ffmpeg.exe')

#ffmpegのディレクトリがなければ作成
if (-Not (Test-Path $ffmpegDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $ffmpegDir
}

#ffmpegのバージョン取得
if (Test-Path $ffmpegFile -PathType Leaf) {
	# get version of current ffmpeg.exe
	$ffmpegFileVersion = (& $ffmpegFile -version)
	$null = $ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
	$ffmpegCurrentVersion = $matches[1]
} else {
	# if ffmpeg.exe not found, will download it
	$ffmpegCurrentVersion = ''
}

#ffmpegの最新バージョン取得
$latestVersion = Invoke-RestMethod -Uri https://www.gyan.dev/ffmpeg/builds/release-version

Write-Host 'ffmpeg current:' $ffmpegCurrentVersion
Write-Host 'ffmpeg latest:' $latestVersion

#ffmpegのダウンロード
if ($latestVersion -ne $ffmpegCurrentVersion) {
	#ダウンロード
	$ffmpegZipLink = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
	Write-Host "ffmpegをダウンロードします。 $ffmpegZipLink"
	$ffmpegZipFileLocation = $(Join-Path $ffmpegDir 'ffmpeg-release-essentials.zip')
	Invoke-WebRequest -Uri $ffmpegZipLink -OutFile $ffmpegZipFileLocation

	#展開
	Expand-Archive $ffmpegZipFileLocation -DestinationPath $(Join-Path $scriptRoot $ffmpegRelativeDir) -Force

	#配置
	$extractedDir = $(Join-Path $scriptRoot $ffmpegRelativeDir)
	$extractedDir = $extractedDir + '\ffmpeg-*-essentials_build'
	$extractedFiles = $extractedDir + '\bin\*.exe'
	Move-Item $extractedFiles $(Join-Path $scriptRoot $ffmpegRelativeDir)

	#ゴミ掃除
	Remove-Item -Path $extractedDir -Force -Recurse
	Remove-Item -Path $ffmpegZipFileLocation -Force

	#バージョンチェック
	$ffmpegFileVersion = (& $ffmpegFile -version)
	$null = $ffmpegFileVersion[0].ToChar -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
	$ffmpegCurrentVersion = $matches[1]
	Write-Host "ffmpegをversion $ffmpegCurrentVersion に更新しました。 "
} else {
	Write-Host 'ffmpegは最新です。 '
	Write-Host ''
}
