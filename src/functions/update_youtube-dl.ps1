###################################################################################
#
#		Windows用youtube-dl最新化処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	[CmdletBinding()]
	[OutputType([void])]
	Param(
		[Parameter(Mandatory = $true)][string]$path,
		[Parameter(Mandatory = $true)][string]$destination
	)

	if (Test-Path -Path $path) {
		Write-Verbose ('{0}を{1}に展開します' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('{0}を展開しました' -f $path)
	} else { Write-Error (❌️ '{0}が見つかりません' -f $path) }

	Remove-Variable -Name path, destination -ErrorAction SilentlyContinue
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$scriptRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $myInvocation.MyCommand.Definition)
	} else { $scriptRoot = Convert-Path .. }
	Set-Location $script:scriptRoot
} catch { Write-Error ('❌️ ディレクトリ設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❌️ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }

#設定ファイル読み込み
try {
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	. (Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		. (Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
	} elseif ($IsWindows) {
		while (!( Test-Path (Join-Path $script:confDir 'user_setting.ps1')) ) {
			Write-Output ('ユーザ設定ファイルを作成する必要があります')
			& 'gui/gui_setting.ps1'
		}
		if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
			. (Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
		}
	} else {
		Write-Error ('❌️ ユーザ設定が完了してません') ; exit 1
	}
} catch { Write-Error ('❌️ 設定ファイルの読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#githubの設定
$lookupTable = @{
	'yt-dlp'       = 'yt-dlp/yt-dlp'
	'ytdl-patched' = 'ytdl-patched/ytdl-patched'
}
if ($lookupTable.ContainsKey($script:preferredYoutubedl)) { $repo = $lookupTable[$script:preferredYoutubedl] }
else { Write-Error '❌️ youtube-dlの取得元の指定が無効です'; exit 1 }
$releases = ('https://api.github.com/repos/{0}/releases' -f $repo)

#youtube-dl移動先相対Path
if ($IsWindows) { $ytdlPath = Join-Path $script:binDir 'youtube-dl.exe' }
else { $ytdlPath = Join-Path $script:binDir 'youtube-dl' }

#youtube-dlのバージョン取得
try {
	if (Test-Path $ytdlPath -PathType Leaf) { $currentVersion = (& $ytdlPath --version) }
	else { $currentVersion = '' }
} catch { $currentVersion = '' }

#youtube-dlの最新バージョン取得
try { $latestVersion = (Invoke-RestMethod -Uri $releases -Method 'GET')[0].Tag_Name }
catch { Write-Warning ('⚠️ youtube-dlの最新バージョンを特定できませんでした') ; return }

#youtube-dlのダウンロード
if ($latestVersion -eq $currentVersion) {
	Write-Output ('')
	Write-Output ('✅️ youtube-dlは最新です。')
	Write-Output ('　Local version: {0}' -f $currentVersion)
	Write-Output ('　Latest version: {0}' -f $latestVersion)
} else {
	Write-Warning ('')
	Write-Warning ('⚠️ youtube-dlが古いため更新します。')
	Write-Warning ('　Local version: {0}' -f $currentVersion)
	Write-Warning ('　Latest version: {0}' -f $latestVersion)
	if (!$IsWindows) {
		#githubの設定
		$fileBeforeRrename = $script:preferredYoutubedl
		$fileAfterRename = 'youtube-dl'
	} else {
		#githubの設定
		$fileBeforeRrename = ('{0}.exe' -f $script:preferredYoutubedl)
		$fileAfterRename = 'youtube-dl.exe'
	}

	Write-Output ('youtube-dlの最新版をダウンロードします')
	try {
		#ダウンロード
		$tag = (Invoke-RestMethod -Uri $releases -Method 'GET')[0].Tag_Name
		$downloadURL = ('https://github.com/{0}/releases/download/{1}/{2}' -f $repo, $tag, $fileBeforeRrename)
		$ytdlFileLocation = Join-Path $script:binDir $fileAfterRename
		Invoke-WebRequest -UseBasicParsing -Uri $downloadURL -Out $ytdlFileLocation
	} catch { Write-Error ('❌️ youtube-dlのダウンロードに失敗しました') ; exit 1 }

	if (!$IsWindows) { (& chmod a+x $ytdlFileLocation) }

	#バージョンチェック
	try {
		$currentVersion = (& $ytdlPath --version)
		Write-Output ('💡 youtube-dlをversion {0}に更新しました。' -f $currentVersion)
	} catch { Write-Error ('❌️ 更新後のバージョン取得に失敗しました') ; exit 1 }


}

Remove-Variable -Name lookupTable, releases, ytdlPath, currentVersion, latestVersion, file, fileAfterRename, tag, downloadURL, ytdlFileLocation -ErrorAction SilentlyContinue
