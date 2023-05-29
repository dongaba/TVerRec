###################################################################################
#
#		TVer固有関数スクリプト
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

#アイコンを設定
$script:iconBase64 = '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'

$script:logoBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAK0AAAA+CAYAAABZXZuuAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAA/BSURBVHhe7Z0JcBRVGscfSTjDLQYvPEAODxSQNXJoAFEuBdZSQRAFD7xAhXJhVRCiKLCCgiC64IWCooCACoKRq2QFRBRFLQ4tOUUBDXLlmgn7fi/dodN5PdOZmQRCvV9V1/R0T6a76f/73nf1IAwGg8FgMBgMBoPBYDAYDAaDwXBCKWO9+ubmm2+uuG/fvg7BYDD52LFjtXJzc609BoM/ypcvnyNfNsnXJZLNeVv941u0KSkpCVKog6VIh0qx1rQ2GwxRER8fn5aYmDhIivdHa1NYfIm2S5cuNdLT0+dJsaZYmwyGWJJZuXLlfmlpabOs9yEJK1osbHZ2dppcbcP7uLg4cf3114s2bdqIs88+W5QtW5bNJYIcNOLQoUPihx9+EB9++KHYtWuXtcdwChCoVq1at8WLFy+y3nsSVrQtWrQYKl/GsF6jRg0xduxYcemll/L2hJKTkyMmTJgg5s2bZ20xlHakq7C3Xr16DadPn37A2qQl3nrVct111yVmZWXNLVOmTEX5heKll14Sl1xyibX3xML5tGrVSvz8889i+/bt1lZDaUbOpIlHjhw5uG3btlXWJi1x1quWjIyMzlKwNVjv1KmTuPjii9X2k4lBgwYpARtODWSwf7u16klI90BasvG5ubmDWX/xxRdFcnKy2g5TpkyJ2KeUA0H5wtWrVxd16tRR1rtBgwbKX46EBx98UGzYsMF6ZyjNoI0rrrii2qRJkw5amwoRUrQtW7acKU12L9bnzp0rzjzzTLUd7rrrLrFp0ybrXfTUrFlTdOjQgTxwgeP4YfTo0eLjjz+23hlKO7Vr1244f/78LdbbQoQ0bUTrNtFkCThIvfgyon3ZONGzfLzoK5c+culaLk40S4gTleXQ+euvv8R7770nevTooay69G3y/tgHJZnBMBQ/u3fvttb0RDYf+6SGNPU9pDgnJJYVwyomiN5yvYMUbopc2snln+XixcAK8WKi3D9Y7m8shR0IBMTs2bNFnz59xE8//WR9k8FwnGIRLWERVnRsYoLoKMVZJUxijZNAsAh3qFxqx5URv//+u3jooYfEF198kfchg8Ei5qJFoEOk8LCikUzajaR4R8q/byrdhqysLDFs2DCxdu1aa6/BEGPRIth/S8E1kMKLhgryzwdItyFZCpciwvDhw8P6ObGAyDUhIcF6ZzhZCamuFi1azJQvKnvw0UcfiVq1arGqcGcPcAmY2utHKVgnAbn8JyMgtgaPicsuu0y88sorSlhuxo0bp8q6Ttq3b69SYQR4lH4zMzNFdna2oCuNhdxuxYoVRZUqVUTVqlVFtWrV1LJ48WJV9Zs5c6YKRLH2LPztt99+K9544w3rCMfhOKTsypcvr76zQoUKYt++fWLgwIHWJ4qfe++9V1x11VXq2OXKlVPBKQOQhWslnRgMBsXBgwfFtm3bxJo1a8Snn35apIC3pJBxTcN169ZFlj0oCl2lOxBLwQI2r7+0uFje77//Xnz22Wd5O3xw7rnnijPOOEMVRMgvp6SkUOFTaTUKJfRPXH311aJJkyaibt264rTTTlM3GMvODefvzzvvPCXGxo0bkztU6zrYf+WVV4rLL79cfYa/Peecc6y9JUO9evXERRddJC644ALVE5KUlKTSiAzIxMRENZgqV64szjrrLFKZYvDgwWLOnDni2muvtb6h9BAT0daSgVNnGXgVB7WkZe1cNq/i9eabbxZIw4WCGxYJWCMvFyEjI8NaK4iup5jvKUkOHz5srfmHmeXpp59WA7k0EROldSobp6xicUF+t6K0tjt27BDffPONtTU0jRo1staKBmJnetXhJQydaHXbihOvARUO3C2sLta4tBC1aMkQtJABU3GCYJtbx1i+fLl6DQU3AuHRTEN5d+XKlUL6SNbeguDXkRdetGiRWLFihRoYXqLFH9Shs6olbWnxu9388ccfqjfjvvvuE0OGDFHFG3xzN/j1uEqlhajVhh+LqIqbJpa/vH79evUaClyIO+64Qy0ESY8//rj44IMPrL0Fwa+jAjdq1CjxxBNPiKlTp8bE0nqJFtcD3/eGG24QN910k+pU82vldEGoDb64GwYg6cKNGzeKVatWiUmTJqmStw78eh2nn366aNu2rTrXLl26iPr161t7QsO54l9fc801ol27duqaCRJjQdSipTxbEtSNzzvVnTt3aq1KOHQ3FajAufEqC3tNwTo/2y1kbuKtt94qFixYoLIgDJDHHntMPP/886pvon///gV8aW4wQRIDj5TfjBkzxLRp09Q+gimyBfwtYgLddei2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'

#----------------------------------------------------------------------
#TVerRec最新化確認
#----------------------------------------------------------------------
function checkLatestTVerRec {
	[OutputType([System.Void])]
	Param ()

	$progressPreference = 'silentlyContinue'
	goAnal -Event 'launch'
	$local:versionUp = $false

	#TVerRecの最新バージョン取得
	$local:repo = 'dongaba/TVerRec'
	$local:releases = "https://api.github.com/repos/$($local:repo)/releases"
	try {
		$local:appReleases = (Invoke-RestMethod `
				-Uri $local:releases `
				-Method Get `
		)
	} catch { return }

	#GitHub側最新バージョンの整形
	# v1.2.3 → 1.2.3
	$local:latestVersion = $($local:appReleases)[0].Tag_Name.Trim('v', ' ')
	# v1.2.3 beta 4 → 1.2.3
	$local:latestMajorVersion = $local:latestVersion.split(' ')[0]

	#ローカル側バージョンの整形
	# v1.2.3 beta 4 → 1.2.3
	$local:appMajorVersion = $script:appVersion.split(' ')[0]

	#バージョン判定
	#最新バージョンのメジャーバージョンが大きい場合
	if ($local:latestMajorVersion -gt $local:appMajorVersion ) { $local:versionUp = $true }
	elseif ($local:latestMajorVersion -eq $local:appMajorVersion ) {
		#マイナーバージョンが設定されている場合
		if ( $local:appMajorVersion -ne $script:appVersion) { $local:versionUp = $true }
		#バージョンが完全に一致する場合
		else { $local:versionUp = $false }
		#ローカルバージョンの方が新しい場合
	} else { $local:versionUp = $false }

	$progressPreference = 'Continue'

	#バージョンアップメッセージ
	if ($local:versionUp -eq $true ) {
		[Console]::ForegroundColor = 'Green'
		Write-Warning 'TVerRecの更新版があるようです。'
		Write-Warning "　Local Version $script:appVersion "
		Write-Warning "　Latest Version  $local:latestVersion"
		Write-Output ''
		[Console]::ResetColor()

		#変更履歴の表示
		for ($i = 0; $i -lt $local:appReleases.Length; $i++) {
			if ($local:appReleases[$i].Tag_Name.Trim('v', ' ') -ge $local:appMajorVersion ) {
				[Console]::ForegroundColor = 'Green'
				Write-Output '----------------------------------------------------------------------'
				Write-Output "$($local:appReleases[$i].Tag_Name.Trim('v', ' ')) の更新内容"
				Write-Output '----------------------------------------------------------------------'
				Write-Output $local:appReleases[$i].body.Replace('###', '■')
				Write-Output ''
				[Console]::ResetColor()
			}
		}

		#アップデート実行
		Write-Warning '10秒後にTVerRecをアップデートします。中止したい場合は Ctrl+C で中断してください'
		foreach ($i in (1..10)) {
			Write-Progress `
				-Activity "残り$(10 - $i)秒..." `
				-PercentComplete ([int]((100 * $i) / 10))
			Start-Sleep -Second 1
		}
		. $(Join-Path $script:scriptRoot './functions/update_tverrec.ps1')

		#再起動のため強制終了
		exit 1

	}

}

#----------------------------------------------------------------------
#ytdlの最新化確認
#----------------------------------------------------------------------
function checkLatestYtdl {
	[OutputType([System.Void])]
	Param ()

	$progressPreference = 'silentlyContinue'

	if ($script:disableUpdateYoutubedl -eq $false) {
		if ($script:preferredYoutubedl -eq 'yt-dlp')
		{ . $(Convert-Path (Join-Path $scriptRoot './functions/update_yt-dlp.ps1')) }
		elseif ($script:preferredYoutubedl -eq 'ytdl-patched')
		{ . $(Convert-Path (Join-Path $scriptRoot './functions/update_ytdl-patched.ps1')) }
		else { Write-Error 'youtube-dlの取得元の指定が無効です' ; exit 1 }
		if ($? -eq $false) { Write-Error 'youtube-dlの更新に失敗しました' ; exit 1 }
	}

	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#ffmpegの最新化確認
#----------------------------------------------------------------------
function checkLatestFfmpeg {
	[OutputType([System.Void])]
	Param ()

	$progressPreference = 'silentlyContinue'

	if ($script:disableUpdateFfmpeg -eq $false) {
		. $(Convert-Path (Join-Path $scriptRoot './functions/update_ffmpeg.ps1'))
		if ($? -eq $false) { Write-Error 'ffmpegの更新に失敗しました' ; exit 1 }
	}

	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#設定で指定したファイル・ディレクトリの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	[OutputType([System.Void])]
	Param ()

	if (!(Test-Path $script:downloadBaseDir -PathType Container))
	{ Write-Error '番組ダウンロード先ディレクトリが存在しません。終了します。' ; exit 1 }
	if (!(Test-Path $script:downloadWorkDir -PathType Container))
	{ Write-Error 'ダウンロード作業ディレクトリが存在しません。終了します。' ; exit 1 }
	if ($script:saveBaseDir -ne '') {
		$script:saveBaseDirArray = @()
		$script:saveBaseDirArray = $script:saveBaseDir.split(';').Trim()
		foreach ($saveDir in $script:saveBaseDirArray) {
			if (!(Test-Path $saveDir.Trim() -PathType Container))
			{ Write-Error '番組移動先ディレクトリが存在しません。終了します。' ; exit 1 }
		}
	}
	if (!(Test-Path $script:ytdlPath -PathType Leaf))
	{ Write-Error 'youtube-dlが存在しません。終了します。' ; exit 1 }
	if (!(Test-Path $script:ffmpegPath -PathType Leaf))
	{ Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if ((!(Test-Path $script:ffprobePath -PathType Leaf)) -And ($script:simplifiedValidation -eq $true))
	{ Write-Error 'ffprobeが存在しません。終了します。' ; exit 1 }

	#過去のバージョンで使用していたファイルを削除、または移行
	#tver.lockをhistory.lockに移行(v2.6.5→v2.6.6)
	if (Test-Path $(Join-Path $script:dbDir './tver.lock') -PathType Leaf) {
		Move-Item `
			-Path $(Join-Path $script:dbDir './tver.lock') `
			-Destination $script:historyLockFilePath `
			-Force
	}
	#tver.sample.csvをhistory.sample.csvに移行(v2.6.5→v2.6.6)
	if (Test-Path $(Join-Path $script:dbDir './tver.sample.csv') -PathType Leaf) {
		Move-Item `
			-Path $(Join-Path $script:dbDir './tver.sample.csv') `
			-Destination $script:historyFilePath `
			-Force
	}
	#tver.csvをhistory.csvに移行(v2.6.5→v2.6.6)
	if (Test-Path $(Join-Path $script:dbDir './tver.csv') -PathType Leaf) {
		Rename-Item `
			-Path $(Join-Path $script:dbDir './tver.csv') `
			-NewName history.csv `
			-Force
	}
	#*.batを*.cmdに移行(v2.6.9→v2.7.0)
	if (Test-Path "$($script:winDir)/*.bat" -PathType Leaf) {
		Remove-Item `
			-Path "$($script:winDir)/*.bat" `
			-Force
	}
	#TVerRec-Logo-Low.pngを削除(v2.7.5→v2.7.6)
	if (Test-Path $(Join-Path $script:imgDir './TVerRec-Logo-Low.png') -PathType Leaf) {
		Remove-Item `
			-Path $(Join-Path $script:imgDir './TVerRec-Logo-Low.png') `
			-Force
	}

	#ファイルが存在しない場合はサンプルファイルをコピー
	if (!(Test-Path $script:keywordFilePath -PathType Leaf)) {
		if (!(Test-Path $script:keywordFileSamplePath -PathType Leaf))
		{ Write-Error 'ダウンロード対象キーワードファイル(サンプル)が存在しません。終了します。' ; exit 1 }
		Copy-Item `
			-Path $script:keywordFileSamplePath `
			-Destination $script:keywordFilePath `
			-Force
	}
	if (!(Test-Path $script:ignoreFilePath -PathType Leaf)) {
		if (!(Test-Path $script:ignoreFileSamplePath -PathType Leaf))
		{ Write-Error 'ダウンロード対象外番組ファイル(サンプル)が存在しません。終了します。' ; exit 1 }
		Copy-Item `
			-Path $script:ignoreFileSamplePath `
			-Destination $script:ignoreFilePath `
			-Force
	}
	if (!(Test-Path $script:historyFilePath -PathType Leaf)) {
		if (!(Test-Path $script:historyFileSamplePath -PathType Leaf))
		{ Write-Error 'ダウンロード履歴ファイル(サンプル)が存在しません。終了します。' ; exit 1 }
		Copy-Item `
			-Path $script:historyFileSamplePath `
			-Destination $script:historyFilePath `
			-Force
	}
	if (!(Test-Path $script:listFilePath -PathType Leaf)) {
		if (!(Test-Path $script:listFileSamplePath -PathType Leaf))
		{ Write-Error 'ダウンロードリストファイル(サンプル)が存在しません。終了します。' ; exit 1 }
		Copy-Item `
			-Path $script:listFileSamplePath `
			-Destination $script:listFilePath `
			-Force
	}

	#念のためチェック
	if (!(Test-Path $script:keywordFilePath -PathType Leaf))
	{ Write-Error 'ダウンロード対象キーワードファイルが存在しません。終了します。' ; exit 1 }
	if (!(Test-Path $script:ignoreFilePath -PathType Leaf))
	{ Write-Error 'ダウンロード対象外番組ファイルが存在しません。終了します。' ; exit 1 }
	if (!(Test-Path $script:historyFilePath -PathType Leaf))
	{ Write-Error 'ダウンロード履歴ファイルが存在しません。終了します。' ; exit 1 }
	if (!(Test-Path $script:listFilePath -PathType Leaf))
	{ Write-Error 'ダウンロードリストファイルが存在しません。終了します。' ; exit 1 }
}

#----------------------------------------------------------------------
#ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function loadKeywordList {
	[OutputType([String[]])]
	Param ()

	try {
		$local:keywordNames = `
			[String[]](Get-Content $script:keywordFilePath -Encoding UTF8 `
			| Where-Object { !($_ -match '^\s*$') } `	#空行を除く
			| Where-Object { !($_ -match '^#.*$') })	#コメント行を除く
	} catch { Write-Error 'ダウンロード対象キーワードの読み込みに失敗しました' ; exit 1 }

	return $local:keywordNames
}

#----------------------------------------------------------------------
#ダウンロードリストの読み込み
#----------------------------------------------------------------------
function loadDownloadList {
	[OutputType([String[]])]
	Param ()

	try {
		#ロックファイルをロック
		while ($(fileLock $script:listLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$local:videoLinks = `
			Import-Csv `
			-Path $script:listFilePath `
			-Encoding UTF8 `
		| Select-Object episodeID `						#EpisodeIDのみ抽出
		| Where-Object { !($_ -match '^\s*$') } `		#空行を除く
		| Where-Object { !($_.episodeID -match '^#') }	#ダウンロード対象外を除く
	} catch { Write-Error 'ダウンロードリストの読み込みに失敗しました' ; exit 1
	} finally { $null = fileUnlock $script:listLockFilePath }

	return $local:videoLinks
}

#----------------------------------------------------------------------
#ダウンロード対象外番組の読み込み
#----------------------------------------------------------------------
function getIgnoreList {
	[OutputType([String[]])]
	Param ()

	try {
		#ロックファイルをロック
		while ($(fileLock $script:ignoreLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$local:ignoreTitles = `
			[String[]](Get-Content $script:ignoreFilePath -Encoding UTF8 `
			| Where-Object { !($_ -match '^\s*$') } `		#空行を除く
			| Where-Object { !($_ -match '^;.*$') })		#コメント行を除く
	} catch { Write-Error 'ダウンロード対象外の読み込みに失敗しました' ; exit 1
	} finally { $null = fileUnlock $script:ignoreLockFilePath }

	return $local:ignoreTitles
}

#----------------------------------------------------------------------
#ダウンロード対象外番組の読み込(正規表現判定用)
#----------------------------------------------------------------------
function getRegexIgnoreList {
	[OutputType([String[]])]
	Param ()

	try {
		#ロックファイルをロック
		while ($(fileLock $script:ignoreLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$local:ignoreRegexTitles = @()
		$local:ignoreRegexTitles = `
			[String[]](Get-Content $script:ignoreFilePath -Encoding UTF8 `
			| Where-Object { !($_ -match '^\s*$') } `		#空行を除く
			| Where-Object { !($_ -match '^;.*$') })		#コメント行を除く
	} catch { Write-Error 'ダウンロード対象外の読み込みに失敗しました' ; exit 1
	} finally { $null = fileUnlock $script:ignoreLockFilePath }

	if ($null -ne $local:ignoreRegexTitles ) {
		for ($i = 0; $i -lt $local:ignoreRegexTitles.Length; $i++) {
			#正規表現用のエスケープ
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('\', '\\')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('*', '\*')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('+', '\+')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('.', '\.')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('?', '\?')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('{', '\{')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('}', '\}')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('(', '\(')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace(')', '\)')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('[', '\[')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace(']', '\]')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('^', '\^')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('$', '\$')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('-', '\-')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('|', '\|')
			$local:ignoreRegexTitles[$i] = $local:ignoreRegexTitles[$i].Replace('/', '\/')
		}
	}

	return $local:ignoreRegexTitles
}

#----------------------------------------------------------------------
#ダウンロード対象外番組のソート(使用したものを上に移動)
#----------------------------------------------------------------------
function sortIgnoreList {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('ignoreTitle')]
		[String]$local:ignoreTitle
	)

	$local:ignoreListNew = @()
	$local:ignoreComment = @()
	$local:ignoreTarget = @()
	$local:ignoreElse = @()

	#正規表現用のエスケープ解除
	$local:ignoreTitle = $local:ignoreTitle.Replace('\\', '\')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\*', '*')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\+', '+')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\.', '.')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\?', '?')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\{', '{')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\}', '}')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\(', '(')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\)', ')')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\[', '[')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\]', ']')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\^', '^')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\$', '$')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\-', '-')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\|', '|')
	$local:ignoreTitle = $local:ignoreTitle.Replace('\/', '/')

	try {
		#ロックファイルをロック
		while ($(fileLock $script:ignoreLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$local:ignoreLists = (Get-Content $script:ignoreFilePath -Encoding UTF8).`
			Where( { !($_ -match '^\s*$') }).`		#空行を除く
		Where( { !($_ -match '^;;.*$') })		#ヘッダ行を除く
	} catch { Write-Error 'ダウンロード対象外リストの読み込みに失敗しました' ; exit 1
	} finally { $null = fileUnlock $script:ignoreLockFilePath }

	$local:ignoreComment = (Get-Content $script:ignoreFileSamplePath -Encoding UTF8)
	$local:ignoreTarget = $ignoreLists | Where-Object { $_ -eq $local:ignoreTitle }
	$local:ignoreElse = $ignoreLists | Where-Object { $_ -ne $local:ignoreTitle }

	$local:ignoreListNew += $local:ignoreComment
	$local:ignoreListNew += $local:ignoreTarget
	$local:ignoreListNew += $local:ignoreElse

	try {
		#ロックファイルをロック
		while ($(fileLock $script:ignoreLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		#改行コードLFを強制
		$local:ignoreListNew | ForEach-Object { $_ + "`n" } | Out-File `
			-Path $script:ignoreFilePath `
			-Encoding UTF8 `
			-NoNewline
		Write-Debug 'ダウンロード対象外リストのソート更新完了'
	} catch {
		Copy-Item `
			Path $($script:ignoreFilePath + '.' + $local:timeStamp) `
			-Destination $script:ignoreFilePath `
			-Force
		Write-Error 'ダウンロード対象外リストのソートに失敗しました' ; exit 1
	} finally {
		$null = fileUnlock $script:ignoreLockFilePath
		#ダウンロード対象外番組の読み込み
		$script:ignoreRegExTitles = getRegExIgnoreList
	}

}


#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function getToken () {
	[OutputType([System.Void])]
	Param ()

	$local:tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$local:requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded'
	}
	$local:requestBody = 'device_type=pc'
	$local:tokenResponse = `
		Invoke-RestMethod `
		-Uri $local:tverTokenURL `
		-Method 'POST' `
		-Headers $local:requestHeader `
		-Body $local:requestBody `
		-TimeoutSec $script:timeoutSec
	$script:platformUID = $local:tokenResponse.Result.platform_uid
	$script:platformToken = $local:tokenResponse.Result.platform_token
}

#----------------------------------------------------------------------
#キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function getVideoLinksFromKeyword {
	[OutputType([System.Object[]])]
	Param ([String]$local:keywordName)

	$script:requestHeader = @{
		'x-tver-platform-type' = 'web'
		'Origin'               = 'https://tver.jp'
		'Referer'              = 'https://tver.jp'
	}
	$script:tverLinks = @()
	if ( $local:keywordName.IndexOf('https://tver.jp') -eq 0) {
		#URL形式の場合番組ページのLinkを取得
		try {
			$local:keywordNamePage = Invoke-WebRequest `
				-Uri $local:keywordName `
				-TimeoutSec $script:timeoutSec
		} catch { Write-Warning '情報取得エラー。スキップします Err:00' ; continue }
		try {
			$script:tverLinks = (
				$local:keywordNamePage.Links `
				| Where-Object { `
					(href -Like '*lp*') `
						-Or (href -Like '*corner*') `
						-Or (href -Like '*series*') `
						-Or (href -Like '*episode*') `
						-Or (href -Like '*feature*')`
				} `
				| Select-Object href
			).href
		} catch { Write-Warning '情報取得エラー。スキップします Err:01'; continue }

	} elseif ($local:keywordName.IndexOf('series/') -eq 0) {
		#番組IDによる番組検索から番組ページのLinkを取得
		$local:seriesID = trimComment($local:keywordName).Replace('series/', '').Trim()
		goAnal -Event 'search' -Type 'series' -ID $local:seriesID
		try { $script:tverLinks = getLinkFromSeriesID ($local:seriesID) }
		catch { Write-Warning '情報取得エラー。スキップします Err:02' ; continue }

	} elseif ($local:keywordName.IndexOf('talents/') -eq 0) {
		#タレントIDによるタレント検索から番組ページのLinkを取得
		$local:talentID = trimComment($local:keywordName).Replace('talents/', '').Trim()
		goAnal -Event 'search' -Type 'talent' -ID $local:talentID
		try { $script:tverLinks = getLinkFromTalentID ($local:talentID) }
		catch { Write-Warning '情報取得エラー。スキップします Err:03' ; continue }

	} elseif ($local:keywordName.IndexOf('tag/') -eq 0) {
		#ジャンルなどのTag情報から番組ページのLinkを取得
		$local:tagID = trimComment($local:keywordName).Replace('tag/', '').Trim()
		goAnal -Event 'search' -Type 'tag' -ID $local:tagID
		try { $script:tverLinks = getLinkFromTag ($local:tagID) }
		catch { Write-Warning '情報取得エラー。スキップします Err:04'; continue }

	} elseif ($local:keywordName.IndexOf('new/') -eq 0) {
		#新着番組から番組ページのLinkを取得
		$local:genre = trimComment($local:keywordName).Replace('new/', '').Trim()
		goAnal -Event 'search' -Type 'new' -ID $local:genre
		try { $script:tverLinks = getLinkFromNew ($local:genre) }
		catch { Write-Warning '情報取得エラー。スキップします Err:05'; continue }

	} elseif ($local:keywordName.IndexOf('ranking/') -eq 0) {
		#ランキングによる番組ページのLinkを取得
		$local:genre = trimComment($local:keywordName).Replace('ranking/', '').Trim()
		goAnal -Event 'search' -Type 'ranking' -ID $local:genre
		try { $script:tverLinks = getLinkFromRanking ($local:genre) }
		catch { Write-Warning '情報取得エラー。スキップします Err:06'; continue }

	} elseif ($local:keywordName.IndexOf('toppage') -eq 0) {
		#トップページから番組ページのLinkを取得
		goAnal -Event 'search' -Type 'toppage'
		try { $script:tverLinks = getLinkFromTopPage }
		catch { Write-Warning '情報取得エラー。スキップします Err:07'; continue }

	} elseif ($local:keywordName.IndexOf('title/') -eq 0) {
		#番組名による新着検索から番組ページのLinkを取得
		$local:titleName = trimComment($local:keywordName).Replace('title/', '').Trim()
		goAnal -Event 'search' -Type 'title' -ID $local:titleName
		Write-Warning '番組名検索は廃止されました。スキップします Err:08'
		continue

	} else {
		#タレント名や番組名などURL形式でない場合APIで検索結果から番組ページのLinkを取得
		goAnal -Event 'search' -Type 'free' -ID $local:keywordName
		try { $script:tverLinks = getLinkFromFreeKeyword ($local:keywordName) }
		catch { Write-Warning '情報取得エラー。スキップします Err:09'; continue }
	}

	$script:tverLinks = $script:tverLinks | Sort-Object | Get-Unique

	if ($script:tverLinks -is [Array]) {
		for ( $i = 0; $i -lt $script:tverLinks.Length; $i++) {
			$script:tverLinks[$i] = 'https://tver.jp' + $script:tverLinks[$i]
		}
	} elseif ($null -ne $script:tverLinks)
	{ $script:tverLinks = 'https://tver.jp' + $script:tverLinks }

	return $script:tverLinks
}

#----------------------------------------------------------------------
#SeriesIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSeriesID {
	[OutputType([System.Object[]])]
	Param ([String]$local:seriesID)

	$local:seasonLinks = @()
	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/'

	#まずはSeries→Seasonに変換
	$local:callSearchURL =
	$local:callSearchBaseURL + $local:seriesID.Replace('series/', '') `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++)
	{ $local:seasonLinks += $local:searchResults[$i].Content.Id }

	#次にSeason→Episodeに変換
	foreach ( $local:seasonLink in $local:seasonLinks)
	{ $script:tverLinks += getLinkFromSeasonID ($local:seasonLink) }
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTalentID {
	[OutputType([System.Object[]])]
	Param ([String]$local:talentID)

	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callTalentEpisode/'
	$local:callSearchURL = `
		$local:callSearchBaseURL + $local:talentID.Replace('talents/', '') `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#タグから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTag {
	[OutputType([System.Object[]])]
	Param ([String]$local:tagID)

	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callTagSearch'
	$local:callSearchURL = `
		$local:callSearchBaseURL + '/' + $local:tagID.Replace('tag/', '') `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#新着から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromNew {
	[OutputType([System.Object[]])]
	Param ([String]$local:genre)

	$local:callSearchBaseURL = `
		'https://service-api.tver.jp/api/v1/callNewerDetail'
	$local:callSearchURL = `
		$local:callSearchBaseURL + '/' + $local:genre.Replace('new/', '') `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#ランキングから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromRanking {
	[OutputType([System.Object[]])]
	Param ([String]$local:genre)

	$local:callSearchBaseURL = `
		'https://service-api.tver.jp/api/v1/callEpisodeRanking'
	if ($local:genre -eq 'all') {
		$local:callSearchURL = `
			$local:callSearchBaseURL `
			+ '?platform_uid=' + $script:platformUID `
			+ '&platform_token=' + $script:platformToken
	} else {
		$local:callSearchURL = `
			$local:callSearchBaseURL `
			+ 'Detail/' + $local:genre.Replace('ranking/', '') `
			+ '?platform_uid=' + $script:platformUID `
			+ '&platform_token=' + $script:platformToken
	}
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTopPage {
	[OutputType([System.Object[]])]
	Param ()

	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callHome'
	$local:callSearchURL = `
		$local:callSearchBaseURL + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Components
	$local:searchResultCount = $local:searchResults.Length
	for ($i = 0; $i -lt $local:searchResultCount; $i++) {
		if ($local:searchResults[$i].Type -eq 'horizontal' `
				-Or $local:searchResults[$i].Type -eq 'ranking' `
				-Or $local:searchResults[$i].Type -eq 'talents' `
				-Or $local:searchResults[$i].type -eq 'billboard' `
				-Or $local:searchResults[$i].type -eq 'episodeRanking' `
				-Or $local:searchResults[$i].type -eq 'newer' `
				-Or $local:searchResults[$i].type -eq 'ender' `
				-Or $local:searchResults[$i].type -eq 'talent' `
				-Or $local:searchResults[$i].type -eq 'special') {
			#横スクロール型 or 総合ランキング or 注目タレント or 特集
			$local:searchSectionResultCount = $local:searchResults[$i].Contents.Length
			for ($j = 0; $j -lt $local:searchSectionResultCount; $j++) {
				switch ($local:searchResults[$i].contents[$j].type) {
					'episode' {
						$script:tverLinks += `
							'/episodes/' + $local:searchResults[$i].contents[$j].Content.Id
						break
					}
					'season' {
						$script:tverLinks += `
							getLinkFromSeasonID ($local:searchResults[$i].contents[$j].Content.Id)
						break
					}
					'series' {
						$script:tverLinks += `
							getLinkFromSeriesID ($local:searchResults[$i].contents[$j].Content.Id)
						break
					}
					'talent' {
						$script:tverLinks += `
							getLinkFromTalentID ($local:searchResults[$i].contents[$j].Content.Id)
						break
					}
					'live' { break }
					'specialMain' {
						#特集ページ。パース方法不明
						#https://tver.jp/specials/$($local:searchResults[4].contents.content.id)
						#$local:searchResults[4].contents.content.id
						#callSpecialContentsDetailを再帰的に呼び出す必要がありそう
						#https://platform-api.tver.jp/service/api/v1/callSpecialContents/drama-digest?require_data=mylist[special][drama-digest]
						#を呼んで得られたspecialContents>[TypeがSpecialのもの]>contents.content.idを使って、再度以下のように呼び出し。(以下の例ではsum22-latterhal)
						#https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/sum22-latterhalf?sort_key=newer&require_data=mylist, later
						#他にはないと思われるが念のため
						break
					}
					default {
						$script:tverLinks += `
							'/' + $local:searchResults[$i].contents[$j].type `
							+ '/' + $local:searchResults[$i].contents[$j].Content.Id
						break
					}
				}
			}
		} elseif ($local:searchResults[$i].type -eq 'topics') {
			$local:searchSectionResultCount = $local:searchResults[$i].Contents.Length
			for ($j = 0; $j -lt $local:searchSectionResultCount; $j++) {
				$local:searchSectionResultCount = $local:searchResults[$i].Contents.Length
				for ($j = 0; $j -lt $local:searchSectionResultCount; $j++) {
					switch ($local:searchResults[$i].contents[$j].Content.Content.type) {
						'episode' {
							$script:tverLinks += `
								'/episodes/' + $local:searchResults[$i].contents[$j].Content.Content.Content.Id
							break
						}
						'season' {
							$script:tverLinks += `
								getLinkFromSeasonID ($local:searchResults[$i].contents[$j].Content.Content.Content.Id)
							break
						}
						'series' {
							$script:tverLinks += `
								getLinkFromSeriesID ($local:searchResults[$i].contents[$j].Content.Content.Content.Id)
							break
						}
						'talent' {
							$script:tverLinks += `
								getLinkFromTalentID ($local:searchResults[$i].contents[$j].Content.Content.Content.Id)
							break
						}
						'live' { break }
						#他にはないと思われるが念のため
						default {
							$script:tverLinks += `
								'/' + $local:searchResults[$i].contents[$j].type `
								+ '/' + $local:searchResults[$i].contents[$j].Content.Content.Content.Id
							break
						}
					}
				}
			}
		} elseif ($local:searchResults[$i].type -eq 'banner') {
			#広告
			#URLは $($local:searchResults[$i].contents.content.targetURL)
			#$local:searchResults[$i].contents.content.targetURL
		} elseif ($local:searchResults[$i].type -eq 'resume') {
			#続きを見る
			#ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} else {}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
function getLinkFromFreeKeyword {
	[OutputType([System.Object[]])]
	Param ([String]$local:keywordName)

	$local:tverSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'
	$local:tverSearchURL = `
		$local:tverSearchBaseURL `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken `
		+ '&keyword=' + $local:keywordName
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:tverSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += '/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSeasonID {
	[OutputType([System.Object[]])]
	Param ([String]$local:SeasonID)

	$local:tverSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/'
	$local:callSearchURL = `
		$local:tverSearchBaseURL + $local:SeasonID.Replace('season/', '') `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function waitTillYtdlProcessGetFewer {
	[OutputType([System.Void])]
	Param ([Int32]$local:parallelDownloadFileNum)

	$local:psCmd = 'ps'

	switch ($script:preferredYoutubedl) {
		'yt-dlp' { $local:processName = 'yt-dlp' ; break }
		'ytdl-patched' { $local:processName = 'youtube-dl' ; break }
	}

	#youtube-dlのプロセスが設定値を超えたら一時待機
	try {
		switch ($true) {
			$IsWindows {
				$local:ytdlCount = [Math]::Round(
					(Get-Process -ErrorAction Ignore -Name youtube-dl).`
						Count / 2, [MidpointRounding]::AwayFromZero)
				break
			}
			$IsLinux {
				$local:ytdlCount = `
				@(Get-Process -ErrorAction Ignore -Name $local:processName).Count
				break
			}
			$IsMacOS {
				$local:ytdlCount = `
				(& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
				break
			}
			default { $local:ytdlCount = 0 ; break }
		}
	} catch { $local:ytdlCount = 0 }			#プロセス数が取れなくてもとりあえず先に進む

	Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)"

	while ([int]$local:ytdlCount -ge [int]$local:parallelDownloadFileNum ) {
		Write-Output "ダウンロードが $local:parallelDownloadFileNum 多重に達したので一時待機します。 ($(getTimeStamp))"
		Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)"
		Start-Sleep -Seconds 60			#1分待機
		try {
			switch ($true) {
				$IsWindows {
					$local:ytdlCount = [Math]::Round(
						(Get-Process -ErrorAction Ignore -Name youtube-dl).`
							Count / 2, [MidpointRounding]::AwayFromZero)
					break
				}
				$IsLinux {
					$local:ytdlCount = `
					@(Get-Process -ErrorAction Ignore -Name $local:processName).Count
					break
				}
				$IsMacOS {
					$local:ytdlCount = `
					(& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
					break
				}
			}
		} catch { Write-Debug 'youtube-dlのプロセス数の取得に失敗しました'; $local:ytdlCount = 0 }
	}
}

#----------------------------------------------------------------------
#TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function downloadTVerVideo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Keyword')]
		[String]$script:keywordName,

		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('URL')]
		[String]$script:videoPageURL,

		[Parameter(Mandatory = $true, Position = 2)]
		[Alias('Link')]
		[String]$script:videoLink
	)

	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$script:newVideo = $null
	$script:ignore = $false ; $script:skip = $false

	#TVerのAPIを叩いて番組情報取得
	goAnal -Event 'getinfo' -Type 'link' -ID $script:videoLink
	try { getVideoInfo -Link $script:videoLink }
	catch { Write-Warning '情報取得エラー。スキップします Err:10'; continue }

	#ダウンロードファイル情報をセット
	$script:videoName = getVideoFileName `
		-Series $script:videoSeries `
		-Season $script:videoSeason `
		-Episode $script:videoEpisode `
		-Title $script:videoTitle `
		-Date $script:broadcastDate

	$script:videoFileDir = getSpecialCharacterReplaced (
		getNarrowChars $($script:videoSeries + ' ' + $script:videoSeason)).Trim(' ', '.')
	if ($script:sortVideoByMedia -eq $true) {
		$script:videoFileDir = $(
			Join-Path $script:downloadBaseDir $(getFileNameWoInvChars $script:mediaName) `
			| Join-Path -ChildPath $(getFileNameWoInvChars $script:videoFileDir)
		)
	} else {
		$script:videoFileDir = $(
			Join-Path $script:downloadBaseDir $(getFileNameWoInvChars $script:videoFileDir)
		)
	}
	$script:videoFilePath = $(Join-Path $script:videoFileDir $script:videoName)
	$script:videoFileRelPath = $script:videoFilePath.`
		Replace($script:downloadBaseDir, '').Replace('\', '/')
	$script:videoFileRelPath = $script:videoFileRelPath.`
		Substring(1, $($script:videoFileRelPath.Length - 1))

	#番組情報のコンソール出力
	showVideoInfo `
		-Name $script:videoName `
		-Date $script:broadcastDate `
		-Media $script:mediaName `
		-Description $descriptionText
	if ($DebugPreference -ne 'SilentlyContinue') {
		showVideoDebugInfo `
			-URL $script:videoPageURL `
			-SeriesURL $script:videoSeriesPageURL `
			-Keyword $script:keywordName `
			-Series $script:videoSeries `
			-Season $script:videoSeason `
			-Episode $script:videoEpisode `
			-Title $script:videoTitle `
			-Path $script:videoFilePath `
			-Time $(getTimeStamp) `
			-EndTime $script:endTime
	}

	#番組タイトルが取得できなかった場合はスキップ次の番組へ
	if ($script:videoName -eq '.mp4')
	{ Write-Warning '番組タイトルを特定できませんでした。スキップします'; continue }

	#ファイルが既に存在する場合はスキップフラグを立ててダウンロード履歴に書き込み処理へ
	if (Test-Path $script:videoFilePath) {

		#リストファイルにチェック済の状態で存在するかチェック
		$local:historyMatch = $script:historyFileData `
		| Where-Object { $_.videoPath -eq $script:videoFileRelPath } `
		| Where-Object { $_.videoValidated -eq '1' }

		#結果が0件ということは未検証のファイルがあるということ
		if ( $null -eq $local:historyMatch) {
			Write-Warning 'すでにダウンロード済ですが未検証の番組です。ダウンロード履歴に追加します'
			$script:skip = $true
		} else { Write-Warning 'すでにダウンロード済・検証済の番組です。スキップします'; continue }

	} else {

		Write-Debug "$(Get-Date) Ignore Check Start"
		foreach ($local:ignoreRegexTitle in $script:ignoreRegexTitles) {
			$script:ignore = checkIfIgnored `
				-ignoreRegexText $local:ignoreRegexTitle `
				-seriesTitle $script:videoSeries `
				-fileName $script:videoName
			if ($script:ignore -eq $true) { break }
		}
		Write-Debug "$(Get-Date) Ignore Check End"
		Write-Debug "Ignored: $($script:ignore)"

	}

	#スキップフラグが立っているかチェック
	if ($script:ignore -eq $true) {
		Write-Output '　ダウンロード対象外としたファイルをダウンロード履歴に追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL
			videoSeriesPage = $script:videoSeriesPageURL
			genre           = $script:keywordName
			series          = $script:videoSeries
			season          = $script:videoSeason
			title           = $script:videoTitle
			media           = $script:mediaName
			broadcastDate   = $script:broadcastDate
			downloadDate    = $(getTimeStamp)
			videoDir        = $script:videoFileDir
			videoName       = '-- IGNORED --'
			videoPath       = '-- IGNORED --'
			videoValidated  = '0'
		}
	} elseif ($script:skip -eq $true) {
		Write-Output '　ダウンロード済の未検証のファイルをダウンロード履歴に追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL
			videoSeriesPage = $script:videoSeriesPageURL
			genre           = $script:keywordName
			series          = $script:videoSeries
			season          = $script:videoSeason
			title           = $script:videoTitle
			media           = $script:mediaName
			broadcastDate   = $script:broadcastDate
			downloadDate    = $(getTimeStamp)
			videoDir        = $script:videoFileDir
			videoName       = '-- SKIPPED --'
			videoPath       = $videoFileRelPath
			videoValidated  = '0'
		}
	} else {
		Write-Output '　ダウンロードするファイルをダウンロード履歴に追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL
			videoSeriesPage = $script:videoSeriesPageURL
			genre           = $script:keywordName
			series          = $script:videoSeries
			season          = $script:videoSeason
			title           = $script:videoTitle
			media           = $script:mediaName
			broadcastDate   = $script:broadcastDate
			downloadDate    = $(getTimeStamp)
			videoDir        = $script:videoFileDir
			videoName       = $script:videoName
			videoPath       = $script:videoFileRelPath
			videoValidated  = '0'
		}
	}

	#ダウンロード履歴CSV書き出し
	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$script:newVideo | Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8 `
			-Append
		Write-Debug 'ダウンロード履歴を書き込みました'
	} catch { Write-Warning 'ダウンロード履歴を更新できませんでした。スキップします'; continue
	} finally { $null = fileUnlock $script:historyLockFilePath }
	$script:historyFileData = `
		Import-Csv `
		-Path $script:historyFilePath `
		-Encoding UTF8

	#スキップやダウンロード対象外でなければyoutube-dl起動
	if (($script:ignore -eq $true) -Or ($script:skip -eq $true)) {
		#スキップ対象やダウンロード対象外は飛ばして次のファイルへ
		continue
	} else {
		#移動先ディレクトリがなければ作成
		if (-Not (Test-Path $script:videoFileDir -PathType Container)) {
			try {
				$null = New-Item `
					-ItemType Directory `
					-Path $script:videoFileDir `
					-Force
			} catch { Write-Warning '移動先ディレクトリを作成できませんでした'; continue }
		}

		#youtube-dl起動
		try { executeYtdl $script:videoPageURL }
		catch { Write-Warning 'youtube-dlの起動に失敗しました' }
		#5秒待機
		Start-Sleep -Seconds 5

	}

}

#----------------------------------------------------------------------
#TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function generateTVerVideoList {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Keyword')]
		[String]$script:keywordName,

		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Link')]
		[String]$script:videoLink
	)

	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$local:ignoreWord = ''
	$script:newVideo = $null
	$script:ignore = $false ; $script:skip = $false

	#TVerのAPIを叩いて番組情報取得
	goAnal -Event 'getinfo' -Type 'link' -ID $script:videoLink
	try { getVideoInfo -Link $script:videoLink }
	catch { Write-Warning '情報取得エラー。スキップします Err:10'; continue }

	#ダウンロード対象外に入っている番組の場合はリスト出力しない
	foreach ($local:ignoreRegexTitle in $script:ignoreRegexTitles) {

		if ($(getNarrowChars $script:videoSeries) -match $(getNarrowChars $local:ignoreRegexTitle)) {
			$local:ignoreWord = $local:ignoreRegexTitle
			sortIgnoreList $local:ignoreRegexTitle
			$script:ignore = $true
			#ダウンロード対象外と合致したものはそれ以上のチェック不要
			break
		} elseif ($(getNarrowChars $script:videoTitle) -match $(getNarrowChars $local:ignoreRegexTitle)) {
			$local:ignoreWord = $local:ignoreRegexTitle
			sortIgnoreList $local:ignoreRegexTitle
			$script:ignore = $true
			#ダウンロード対象外と合致したものはそれ以上のチェック不要
			break
		}
	}

	#スキップフラグが立っているかチェック
	if ($script:ignore -eq $true) {
		Write-Output '　番組をコメントアウトした状態でリストファイルに追加します'
		$script:newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = '#' + $($script:videoLink.Replace('https://tver.jp/episodes/', ''))
			media         = $script:mediaName
			provider      = $script:providerName
			broadcastDate = $script:broadcastDate
			endTime       = $script:endTime
			keyword       = $script:keywordName
			ignoreWord    = $local:ignoreWord
		}
	} else {
		Write-Output '　番組をリストファイルに追加します'
		$script:newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = $($script:videoLink.Replace('https://tver.jp/episodes/', ''))
			media         = $script:mediaName
			provider      = $script:providerName
			broadcastDate = $script:broadcastDate
			endTime       = $script:endTime
			keyword       = $script:keywordName
			ignoreWord    = ''
		}
	}

	#ダウンロードリストCSV書き出し
	try {
		#ロックファイルをロック
		while ($(fileLock $script:listLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$script:newVideo | Export-Csv `
			-Path $script:listFilePath `
			-NoTypeInformation `
			-Encoding UTF8 `
			-Append
		Write-Debug 'ダウンロードリストを書き込みました'
	} catch { Write-Warning 'ダウンロードリストを更新できませんでした。スキップします'; continue
	} finally { $null = fileUnlock $script:listLockFilePath }
	$script:listFileData = `
		Import-Csv `
		-Path $script:listFilePath `
		-Encoding UTF8

}

#----------------------------------------------------------------------
#TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
function getVideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Link')]
		[String]$local:videoLink
	)

	$local:episodeID = $local:videoLink.`
		Replace('https://tver.jp/', '').`
		Replace('https://tver.jp', '').`
		Replace('/episodes/', '').`
		Replace('episodes/', '')

	#----------------------------------------------------------------------
	#番組説明以外
	$local:tverVideoInfoBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$local:requestHeader = @{
		'x-tver-platform-type' = 'web'
	}
	$local:tverVideoInfoURL = `
		$local:tverVideoInfoBaseURL + $local:episodeID + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:response = `
		Invoke-RestMethod `
		-Uri $local:tverVideoInfoURL `
		-Method 'GET' `
		-Headers $local:requestHeader `
		-TimeoutSec $script:timeoutSec

	#シリーズ
	#	$response.Result.Series.Content.Title
	#	$response.Result.Episode.Content.SeriesTitle
	#		Series.Content.Titleだと複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがある
	#		Episode.Content.SeriesTitleだとSeries名+Season名が設定される番組もある
	#	なのでSeries.Content.TitleとEpisode.Content.SeriesTitleの短い方を採用する
	if ($local:response.Result.Episode.Content.SeriesTitle.Length `
			-le $local:response.Result.Series.Content.Title.Length ) {
		$script:videoSeries = $(getSpecialCharacterReplaced (getNarrowChars (
					$local:response.Result.Episode.Content.SeriesTitle))).Trim()
	} else {
		$script:videoSeries = $(getSpecialCharacterReplaced (getNarrowChars (
					$local:response.Result.Series.Content.Title))).Trim()
	}
	$script:videoSeriesID = $local:response.Result.Series.Content.Id
	$script:videoSeriesPageURL = `
		'https://tver.jp/series/' + $local:response.Result.Series.Content.Id

	#シーズン
	#Season Name
	#	$response.Result.Season.Content.Title
	$script:videoSeason = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Season.Content.Title))).Trim()
	$script:videoSeasonID = $local:response.Result.Season.Content.Id

	#エピソード
	#	$response.Result.Episode.Content.Title
	$script:videoTitle = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Episode.Content.Title))).Trim()
	$script:videoEpisodeID = $local:response.Result.Episode.Content.Id

	#放送局
	#	$response.Result.Episode.Content.BroadcasterName
	#	$response.Result.Episode.Content.ProductionProviderName
	$script:mediaName = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Episode.Content.BroadcasterName))).Trim()
	$script:providerName = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Episode.Content.ProductionProviderName))).Trim()

	#放送日
	#	$response.Result.Episode.Content.BroadcastDateLabel
	$script:broadcastDate = $(getNarrowChars (
			$response.Result.Episode.Content.BroadcastDateLabel).`
			Replace('ほか', '').Replace('放送分', '放送')).Trim()

	#配信終了日時
	#	$response.Result.Episode.Content.endAt
	$script:endTime = $(getNarrowChars ($response.Result.Episode.Content.endAt)).Trim()
	$script:endTime = $(unixTimeToDateTime ($script:endTime)).AddHours(9)

	#----------------------------------------------------------------------
	#番組説明
	$local:versionNum = $local:response.result.episode.content.version
	$local:tverVideoInfoBaseURL = `
		'https://statics.tver.jp/content/episode/'
	$local:requestHeader = @{
		'origin'  = 'https://tver.jp'
		'referer' = 'https://tver.jp'
	}
	$local:tverVideoInfoURL = `
		$local:tverVideoInfoBaseURL `
		+ $local:episodeID + '.json?v=' + $local:versionNum
	$local:videoInfo = `
		Invoke-RestMethod `
		-Uri $local:tverVideoInfoURL `
		-Method 'GET' `
		-Headers $local:requestHeader `
		-TimeoutSec $script:timeoutSec
	$script:descriptionText = $(getNarrowChars ($local:videoInfo.Description).`
			Replace('&amp;', '&')).Trim()
	$script:videoEpisode = getNarrowChars ($local:videoInfo.No)

	#----------------------------------------------------------------------
	#各種整形

	#「《」と「》」で挟まれた文字を除去
	if ($script:removeSpecialNote -eq $true) {
		if ($script:videoSeries -match '(.*)(《.*》)(.*)')
		{ $script:videoSeries = $($Matches[1] + $Matches[3]).Replace('  ', ' ').Trim() }
		if ($script:videoSeason -match '(.*)(《.*》)(.*)')
		{ $script:videoSeason = $($Matches[1] + $Matches[3]).Replace('  ', ' ').Trim() }
		if ($script:videoTitle -match '(.*)(《.*》)(.*)')
		{ $script:videoTitle = $($Matches[1] + $Matches[3]).Replace('  ', ' ').Trim() }
	}

	#シーズン名が本編の場合はシーズン名をクリア
	if ($script:videoSeason -eq '本編') { $script:videoSeason = '' }

	#シリーズ名がシーズン名を含む場合はシーズン名をクリア
	if ($script:videoSeries -like $('*' + $script:videoSeason + '*' ))
	{ $script:videoSeason = '' }

	#放送日を整形
	$local:broadcastYMD = $null
	if ($script:broadcastDate -match '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
		#当年だと仮定して放送日を抽出
		$local:broadcastYMD = [DateTime]::ParseExact(
			(Get-Date -Format 'yyyy') `
				+ $Matches[1].padleft(2, '0') `
				+ $Matches[3].padleft(2, '0'), 'yyyyMMdd', $null)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の番組と判断する
		#(年末の番組を年初にダウンロードするケース)
		if ((Get-Date).AddDays(+1) -lt $local:broadcastYMD)
		{ $script:broadcastDate = (Get-Date).AddYears(-1).ToString('yyyy') + '年' }
		else { $script:broadcastDate = (Get-Date).ToString('yyyy') + '年' }
		$script:broadcastDate += `
			$Matches[1].padleft(2, '0') + $Matches[2] `
			+ $Matches[3].padleft(2, '0') + $Matches[4] `
			+ $Matches[6]
	}

}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function getVideoFileName {
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('Series')]
		[String]$local:videoSeries,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Season')]
		[String]$local:videoSeason,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Episode')]
		[String]$local:videoEpisode,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('Title')]
		[String]$local:videoTitle,

		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('Date')]
		[String]$local:broadcastDate
	)

	#ファイル名を生成
	if ($script:addEpisodeNumber -eq $true) {
		$local:videoName = `
			$local:videoSeries `
			+ ' ' + $local:videoSeason `
			+ ' ' + $local:broadcastDate `
			+ ' Ep' + $local:videoEpisode `
			+ ' ' + $local:videoTitle
	} else {
		$local:videoName = `
			$local:videoSeries `
			+ ' ' + $local:videoSeason `
			+ ' ' + $local:broadcastDate `
			+ ' ' + $local:videoTitle
	}

	#ファイル名にできない文字列を除去
	$local:videoName = $(getFileNameWoInvChars (getSpecialCharacterReplaced (
				getNarrowChars $local:videoName))).Replace('  ', ' ').Trim()

	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング
	$local:videoNameTemp = ''
	#youtube-dlの中間ファイル等を考慮して安全目の上限値
	$local:fileNameLimit = $script:fileNameLengthMax - 25
	$local:videoNameByte = [System.Text.Encoding]::UTF8.GetByteCount($local:videoName)

	#ファイル名を1文字ずつ増やしていき、上限に達したら残りは「……」とする
	if ($local:videoNameByte -gt $local:fileNameLimit) {
		for ($i = 1 ; [System.Text.Encoding]::UTF8.`
				GetByteCount($local:videoNameTemp) -lt $local:fileNameLimit ; $i++) {
			$local:videoNameTemp = $local:videoName.Substring(0, $i)
		}
		#ファイル名省略の印
		$local:videoName = $local:videoNameTemp + '……'
	}

	$local:videoName = $local:videoName + '.mp4'
	if ($local:videoName.Contains('.mp4') -eq $false)
	{ Write-Error '　ダウンロードファイル名の設定がおかしいです' }

	return $local:videoName
}

#----------------------------------------------------------------------
#番組情報表示
#----------------------------------------------------------------------
function showVideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('Name')]
		[String]$local:videoName,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Date')]
		[String]$local:broadcastDate,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Media')]
		[String]$local:mediaName,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('Description')]
		[String]$local:descriptionText
	)

	Write-Output "　番組名 :$local:videoName"
	Write-Output "　放送日 :$local:broadcastDate"
	Write-Output "　テレビ局:$local:mediaName"
	Write-Output "　番組説明:$local:descriptionText"
}
#----------------------------------------------------------------------
#番組情報デバッグ表示
#----------------------------------------------------------------------
function showVideoDebugInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('URL')]
		[String]$local:videoPageURL,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('SeriesURL')]
		[String]$local:videoSeriesPageURL,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Keyword')]
		[String]$local:keywordName,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('Series')]
		[String]$local:videoSeries,

		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('Season')]
		[String]$local:videoSeason,

		[Parameter(Mandatory = $false, Position = 5)]
		[Alias('Episode')]
		[String]$local:videoEpisode,

		[Parameter(Mandatory = $false, Position = 6)]
		[Alias('Title')]
		[String]$local:videoTitle,

		[Parameter(Mandatory = $false, Position = 7)]
		[Alias('Path')]
		[String]$local:videoFilePath,

		[Parameter(Mandatory = $false, Position = 8)]
		[Alias('Time')]
		[String]$local:processedTime,

		[Parameter(Mandatory = $false, Position = 9)]
		[Alias('EndTime')]
		[String]$local:endTime
	)

	Write-Debug	"番組エピソードページ:$local:videoPageURL"
	Write-Debug	"番組シリーズページ :$local:videoSeriesPageURL"
	Write-Debug	"キーワード :$local:keywordName"
	Write-Debug	"シリーズ :$local:videoSeries"
	Write-Debug	"シーズン :$local:videoSeason"
	Write-Debug	"エピソード :$local:videoEpisode"
	Write-Debug	"サブタイトル :$local:videoTitle"
	Write-Debug	"ファイル :$local:videoFilePath"
	Write-Debug	"取得日付 :$local:processedTime"
	Write-Debug	"配信終了 :$local:endTime"
}

#----------------------------------------------------------------------
#youtube-dlプロセスの起動
#----------------------------------------------------------------------
function executeYtdl {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('URL')]
		[String]$local:videoPageURL
	)

	goAnal -Event 'download'

	$local:tmpDir = '"temp:' + $script:downloadWorkDir + '"'
	$local:saveDir = '"home:' + $script:videoFileDir + '"'
	$local:subttlDir = '"subtitle:' + $script:downloadWorkDir + '"'
	$local:thumbDir = '"thumbnail:' + $script:downloadWorkDir + '"'
	$local:chaptDir = '"chapter:' + $script:downloadWorkDir + '"'
	$local:descDir = '"description:' + $script:downloadWorkDir + '"'
	$local:saveFile = '"' + $script:videoName + '"'
	$local:ffmpegPath = '"' + $script:ffmpegPath + '"'

	$local:ytdlArgs = '--format mp4'
	$local:ytdlArgs += ' --console-title'
	$local:ytdlArgs += ' --no-mtime'
	$local:ytdlArgs += ' --retries 10'
	$local:ytdlArgs += ' --fragment-retries 10'
	$local:ytdlArgs += ' --abort-on-unavailable-fragment'
	$local:ytdlArgs += ' --no-keep-fragments'
	$local:ytdlArgs += ' --abort-on-error'
	$local:ytdlArgs += ' --no-continue'
	$local:ytdlArgs += ' --windows-filenames'
	$local:ytdlArgs += ' --newline'
	$local:ytdlArgs += " --concurrent-fragments $script:parallelDownloadNumPerFile"
	$local:ytdlArgs += ' --embed-thumbnail'
	$local:ytdlArgs += ' --all-subs'
	$local:ytdlArgs += ' --embed-subs'
	$local:ytdlArgs += ' --embed-metadata'
	$local:ytdlArgs += ' --embed-chapters'
	$local:ytdlArgs += " --paths $local:saveDir"
	$local:ytdlArgs += " --paths $local:tmpDir"
	$local:ytdlArgs += " --paths $local:subttlDir"
	$local:ytdlArgs += " --paths $local:thumbDir"
	$local:ytdlArgs += " --paths $local:chaptDir"
	$local:ytdlArgs += " --paths $local:descDir"
	$local:ytdlArgs += " --ffmpeg-location $local:ffmpegPath"
	$local:ytdlArgs += " --output $local:saveFile"
	$local:ytdlArgs += " $local:videoPageURL"

	if ($IsWindows) {
		try {
			Write-Debug "youtube-dl起動コマンド:$script:ytdlPath $local:ytdlArgs"
			$null = Start-Process `
				-FilePath $script:ytdlPath `
				-ArgumentList $local:ytdlArgs `
				-PassThru `
				-WindowStyle $script:windowShowStyle
		} catch { Write-Error 'youtube-dlの起動に失敗しました' ; return }
	} else {
		Write-Debug "youtube-dl起動コマンド:nohup $script:ytdlPath $local:ytdlArgs"
		try {
			$null = Start-Process `
				-FilePath nohup `
				-ArgumentList ($script:ytdlPath, $local:ytdlArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null `
				-RedirectStandardError /dev/zero
		} catch { Write-Error '　youtube-dlの起動に失敗しました' ; return }
	}
}

#----------------------------------------------------------------------
#youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function waitTillYtdlProcessIsZero () {
	[OutputType([System.Void])]
	Param ()

	$local:psCmd = 'ps'

	switch ($script:preferredYoutubedl) {
		'yt-dlp' { $local:processName = 'yt-dlp' ; break }
		'ytdl-patched' { $local:processName = 'youtube-dl' ; break }
	}

	try {
		switch ($true) {
			$IsWindows {
				$local:ytdlCount = [Math]::Round(
					(Get-Process -ErrorAction Ignore -Name youtube-dl).`
						Count / 2, [MidpointRounding]::AwayFromZero )
				break
			}
			$IsLinux {
				$local:ytdlCount = @(Get-Process -ErrorAction Ignore -Name $local:processName).Count
				break
			}
			$IsMacOS {
				$local:ytdlCount = (& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
				break
			}
			default { $local:ytdlCount = 0 ; break }
		}
	} catch { $local:ytdlCount = 0 }

	while ($local:ytdlCount -ne 0) {
		try {
			Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)"
			Start-Sleep -Seconds 60			#1分待機
			switch ($true) {
				$IsWindows {
					$local:ytdlCount = [Math]::Round(
						(Get-Process -ErrorAction Ignore -Name youtube-dl).`
							Count / 2, [MidpointRounding]::AwayFromZero )
					break
				}
				$IsLinux {
					$local:ytdlCount = @(Get-Process -ErrorAction Ignore -Name $local:processName).Count
					break
				}
				$IsMacOS {
					$local:ytdlCount = (& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
					break
				}
				default { $local:ytdlCount = 0 ; break }
			}
		} catch { $local:ytdlCount = 0 }
	}
}

#----------------------------------------------------------------------
#ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function cleanDB {
	[OutputType([System.Void])]
	Param ()

	$local:historyData0 = @()
	$local:historyData1 = @()
	$local:historyData2 = @()
	$local:mergedHistoryData = @()

	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }

		#ファイル操作
		#videoValidatedが空白でないもの
		$local:historyData = ((Import-Csv -Path $script:historyFilePath -Encoding UTF8).`
				Where({ $null -ne $_.videoValidated }))
		$local:historyData0 = (($local:historyData).Where({ $_.videoValidated -eq '0' }))
		$local:historyData1 = (($local:historyData).Where({ $_.videoValidated -eq '1' }))
		$local:historyData2 = (($local:historyData).Where({ $_.videoValidated -eq '2' }))

		$local:mergedHistoryData += $local:historyData0
		$local:mergedHistoryData += $local:historyData1
		$local:mergedHistoryData += $local:historyData2
		$local:mergedHistoryData | Sort-Object -Property downloadDate `
		| Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8

	} catch { Write-Warning 'ダウンロード履歴の更新に失敗しました'
	} finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#30日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function purgeDB {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('RetentionPeriod')]
		[Int32]$local:retentionPeriod
	)

	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$local:purgedHist = ((Import-Csv -Path $script:historyFilePath -Encoding UTF8).`
				Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt $(Get-Date).`
						AddDays(-1 * [Int32]$local:retentionPeriod) }))
		$local:purgedHist | Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8
	} catch { Write-Warning 'ダウンロード履歴のクリーンアップに失敗しました'
	} finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function uniqueDB {
	[OutputType([System.Void])]
	Param ()

	$local:uniquedHist = @()

	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }

		#videoPageで1つしかないもの残す
		$local:uniquedHist = `
			Import-Csv `
			-Path $script:historyFilePath `
			-Encoding UTF8 `
		| Group-Object -Property 'videoPage' `
		| Where-Object count -EQ 1 `
		| Select-Object -ExpandProperty group

		#ダウンロード日時でソートし出力
		$local:uniquedHist | Sort-Object -Property downloadDate `
		| Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8

	} catch { Write-Warning 'ダウンロード履歴の更新に失敗しました'
	} finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#番組の整合性チェック
#----------------------------------------------------------------------
function checkVideo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('DecodeOption')]
		[String]$local:decodeOption,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Path')]
		[String]$local:videoFileRelPath
	)

	$local:errorCount = 0
	$local:checkStatus = 0
	$local:videoFilePath = Join-Path $script:downloadBaseDir $local:videoFileRelPath
	try {
		$null = New-Item `
			-Path $script:ffpmegErrorLogPath `
			-ItemType File `
			-Force
	} catch { Write-Warning 'ffmpegエラーファイルを初期化できませんでした' ; return }

	#これからチェックする番組のステータスをチェック
	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$local:videoHists = `
			Import-Csv `
			-Path $script:historyFilePath `
			-Encoding UTF8
		$local:checkStatus = $(($local:videoHists).`
				Where({ $_.videoPath -eq $local:videoFileRelPath })).videoValidated
	} catch { Write-Warning "　既にダウンロード履歴から削除されたようです: $local:videoFileRelPath"; return
	} finally { $null = fileUnlock $script:historyLockFilePath }

	#0:未チェック、1:チェック済、2:チェック中
	if ($local:checkStatus -eq 2 ) { Write-Warning '他プロセスでチェック中です';	return
	} elseif ($local:checkStatus -eq 1 ) { Write-Warning '他プロセスでチェック済です'; return
	} else {
		#該当の番組のチェックステータスを"2"にして後続のチェックを実行
		try {
			$local:videoHists `
			| Where-Object { $_.videoPath -eq $local:videoFileRelPath } `
			| Where-Object { $_.videoValidated = '2' }
		} catch { Write-Warning "　該当のレコードが見つかりませんでした: $local:videoFileRelPath"; return }
		try {
			#ロックファイルをロック
			while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
			{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
			#ファイル操作
			$local:videoHists | Export-Csv `
				-Path $script:historyFilePath `
				-NoTypeInformation `
				-Encoding UTF8
		} catch { Write-Warning "　ダウンロード履歴を更新できませんでした: $local:videoFileRelPath"; return
		} finally { $null = fileUnlock $script:historyLockFilePath }
	}

	$local:checkFile = '"' + $local:videoFilePath + '"'
	goAnal -Event 'validate'

	if ($script:simplifiedValidation -eq $true) {
		#ffprobeを使った簡易検査
		$local:ffprobeArgs = ' -hide_banner -v error -err_detect explode' + " -i $local:checkFile "

		Write-Debug "ffprobe起動コマンド:$script:ffprobePath $local:ffprobeArgs"
		try {
			if ($IsWindows) {
				$local:proc = Start-Process `
					-FilePath $script:ffprobePath `
					-ArgumentList ($local:ffprobeArgs) `
					-PassThru `
					-WindowStyle $script:windowShowStyle `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			} else {
				$local:proc = Start-Process `
					-FilePath $script:ffprobePath `
					-ArgumentList ($local:ffprobeArgs) `
					-PassThru `
					-RedirectStandardOutput /dev/null `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			}
		} catch { Write-Error '　ffprobeを起動できませんでした' ; return }
	} else {
		#ffmpegeを使った完全検査
		$local:ffmpegArgs = "$local:decodeOption " `
			+ ' -hide_banner -v error -xerror' + " -i $local:checkFile -f null - "

		Write-Debug "ffmpeg起動コマンド:$script:ffmpegPath $local:ffmpegArgs"
		try {
			if ($IsWindows) {
				$local:proc = Start-Process `
					-FilePath $script:ffmpegPath `
					-ArgumentList ($local:ffmpegArgs) `
					-PassThru `
					-WindowStyle $script:windowShowStyle `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			} else {
				$local:proc = Start-Process `
					-FilePath $script:ffmpegPath `
					-ArgumentList ($local:ffmpegArgs) `
					-PassThru `
					-RedirectStandardOutput /dev/null `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			}
		} catch { Write-Error '　ffmpegを起動できませんでした' ; return }
	}

	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			$local:errorCount = (Get-Content -LiteralPath $script:ffpmegErrorLogPath `
				| Measure-Object -Line).Lines
			Get-Content `
				-LiteralPath $script:ffpmegErrorLogPath `
				-Encoding UTF8 `
			| ForEach-Object { Write-Debug $_ }
		}
	} catch { Write-Warning 'ffmpegエラーの数をカウントできませんでした'; $local:errorCount = 9999999 }

	#エラーをカウントしたらファイルを削除
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			Remove-Item `
				-LiteralPath $script:ffpmegErrorLogPath `
				-Force `
				-ErrorAction SilentlyContinue
		}
	} catch { Write-Warning 'ffmpegエラーファイルを削除できませんでした' }

	if ($local:proc.ExitCode -ne 0 -Or $local:errorCount -gt 30) {

		#終了コードが"0"以外 または エラーが一定以上 はダウンロード履歴とファイルを削除
		Write-Warning 'チェックNGでした'
		Write-Warning "　exit code: $($local:proc.ExitCode) error count: $local:errorCount"

		#破損しているダウンロードファイルをダウンロード履歴から削除
		try {
			#ロックファイルをロック
			while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
			{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
			#ファイル操作
			$local:videoHists = `
				Import-Csv `
				-Path $script:historyFilePath `
				-Encoding UTF8
			#該当の番組のレコードを削除
			$local:videoHists `
			| Where-Object { $_.videoPath -ne $local:videoFileRelPath } `
			| Export-Csv `
				-Path $script:historyFilePath `
				-NoTypeInformation `
				-Encoding UTF8
		} catch { Write-Warning "　ダウンロード履歴の更新に失敗しました: $local:videoFileRelPath"
		} finally { $null = fileUnlock $script:historyLockFilePath }

		#破損しているダウンロードファイルを削除
		try {
			Remove-Item `
				-LiteralPath $local:videoFilePath `
				-Force `
				-ErrorAction SilentlyContinue
		} catch { Write-Warning "　ファイル削除できませんでした: $local:videoFilePath" }

	} else {

		#終了コードが"0"のときはダウンロード履歴にチェック済フラグを立てる
		Write-Output '　チェックOKでした'
		try {
			#ロックファイルをロック
			while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
			{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
			#ファイル操作
			$local:videoHists = `
				Import-Csv `
				-Path $script:historyFilePath `
				-Encoding UTF8
			#該当の番組のチェックステータスを"1"に
			$local:videoHists `
			| Where-Object { $_.videoPath -eq $local:videoFileRelPath } `
			| Where-Object { $_.videoValidated = '1' }
			$local:videoHists | Export-Csv `
				-Path $script:historyFilePath `
				-NoTypeInformation `
				-Encoding UTF8
		} catch { Write-Warning "　ダウンロード履歴を更新できませんでした: $local:videoFileRelPath"
		} finally { $null = fileUnlock $script:historyLockFilePath }

	}

}

#----------------------------------------------------------------------
#番組が無視されているかチェック
#----------------------------------------------------------------------
function checkIfIgnored {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('ignoreRegexText')]
		[String]$local:ignoreRegexTitle,

		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('seriesTitle')]
		[String]$local:videoSeries,

		[Parameter(Mandatory = $true, Position = 2)]
		[Alias('fileName')]
		[String]$local:videoName
	)

	#ダウンロード対象外と合致したものはそれ以上のチェック不要
	if ($(getNarrowChars $local:videoName) -match $(getNarrowChars $local:ignoreRegexTitle)) {
		sortIgnoreList $local:ignoreRegexTitle
		$script:ignore = $true ; break
	} elseif ($(getNarrowChars $local:videoSeries) -match $(getNarrowChars $local:ignoreRegexTitle)) {
		sortIgnoreList $local:ignoreRegexTitle
		$script:ignore = $true ; break
	}

}
