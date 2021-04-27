$scriptRoot = if ($PSScriptRoot -eq '') { '.' } else { $PSScriptRoot }

#githubの設定
$repo = 'ytdl-org/youtube-dl'
$file = 'youtube-dl.exe'
$releases = "https://api.github.com/repos/$repo/releases"

#youtube-dl保存先相対Path
$youtubedlRelativeDir = '..\bin'
$youtubedlDir = $(Join-Path $scriptRoot $youtubedlRelativeDir)
$youtubedlFile = $(Join-Path $youtubedlDir 'youtube-dl.exe')

#youtube-dlのディレクトリがなければ作成
if (-Not (Test-Path $youtubedlDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $youtubedlDir
}

#youtube-dlのバージョン取得
if (Test-Path $youtubedlFile -PathType Leaf) {
	# get version of current youtube-dl.exe
	$youtubedlCurrentVersion = (& $youtubedlFile --version)
} else {
	# if youtube-dl.exe not found, will download it
	$youtubedlCurrentVersion = ''
}

#youtube-dlの最新バージョン取得
$latestVersion = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name

Write-Host 'youtube-dl current:' $youtubedlCurrentVersion
Write-Host 'youtube-dl latest:' $latestVersion

#youtube-dlのダウンロード
if ($latestVersion -ne $youtubedlCurrentVersion) {
	#ダウンロード
	$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
	$download = "https://github.com/$repo/releases/download/$tag/$file"
	$youtubedlFileLocation = $(Join-Path $youtubedlDir $file)

	Write-Host "youtube-dlをダウンロードします。 $download"
	Invoke-WebRequest $download -Out $youtubedlFileLocation

	#バージョンチェック
	$youtubedlCurrentVersion = (& $youtubedlFile --version)
	Write-Host "youtube-dlをversion $youtubedlCurrentVersion に更新しました。 "
} else {
	Write-Host 'youtube-dlは最新です。 '
	Write-Host ''
}





