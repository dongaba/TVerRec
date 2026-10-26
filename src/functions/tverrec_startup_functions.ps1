###################################################################################
#
#		TVerRec固有関数スクリプト(起動時の確認処理)
#
###################################################################################
<#
	.SYNOPSIS
		起動時の確認処理(バージョン確認、更新確認、必須ファイル・ディレクトリの確認)の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region 起動時関連
#----------------------------------------------------------------------
# TVerRec Logo表示
#----------------------------------------------------------------------
function Show-Logo {
	<#
		.SYNOPSIS
			TVerRecのロゴを表示します。

		.DESCRIPTION
			TVerRecのロゴをコンソールに表示します。

		.EXAMPLE
			Show-Logo
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# [Console]::ForegroundColor = 'Red'
	foreach ($line in $script:logoLines) { Write-Output $line }
	# [Console]::ResetColor()
	Write-Output (" {0,$(72 - $script:appVersion.Length)}Version. {1}  " -f ' ', $script:appVersion)
}

#----------------------------------------------------------------------
# バージョン比較
#----------------------------------------------------------------------
function Compare-Version {
	<#
		.SYNOPSIS
			バージョン文字列を比較します。

		.DESCRIPTION
			2つのバージョン文字列を比較し、大小関係を返します。

		.PARAMETER remote
			比較対象のリモートバージョン文字列です。

		.PARAMETER local
			比較対象のローカルバージョン文字列です。

		.OUTPUTS
			[int] バージョンの大小関係を示す整数値。
			リモートバージョンが新しい場合は1、ローカルバージョンが新しい場合は-1、同じ場合は0を返します。

		.EXAMPLE
			$result = Compare-Version -remote "1.2.3" -local "1.2.2"
			Write-Output $result

		.NOTES
			この関数は、バージョン文字列を"."でユニットに切り分け、ユニット毎に比較します。
			ユニット数が少ない方の表記に探索幅を合わせ、探索幅に従ってユニット毎に比較していきます。
			個々のユニットが完全に一致している場合は、ユニット数が多い方が大きいとします。
	#>
	param (
		[String]$remote,
		[String]$local
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($remote -eq $local) { return 0 }
	# バージョンを"."でユニットに切り分ける
	$remoteUnits = ($remote -split '\.').ForEach{ [int]$_ }
	$localUnits = ($local -split '\.').ForEach{ [int]$_ }
	# ユニット数が少ない方の表記に探索幅を合わせる
	$unitLength = [Math]::Min($remoteUnits.Count, $localUnits.Count)
	# 探索幅に従ってユニット毎に比較していく
	for ($i = 0; $i -lt $unitLength; $i++) {
		if ($remoteUnits[$i] -gt $localUnits[$i]) { return 1 }
		if ($remoteUnits[$i] -lt $localUnits[$i]) { return -1 }
	}
	# 個々のユニットが完全に一致している場合はユニット数が多い方が大きいとする
	return [Math]::Sign($remoteUnits.Count - $localUnits.Count)
}

#----------------------------------------------------------------------
# PowerShellの新バージョンの確認
#----------------------------------------------------------------------
function Invoke-PowerShellUpdateCheck {
	<#
		.SYNOPSIS
			PowerShellの新しいバージョンが公開されているかを確認し、あれば案内を表示します。

		.DESCRIPTION
			GitHubのPowerShellリポジトリから最新の正式版を取得し、実行中のPowerShellと比較します。
			PowerShellはインストール方法が複数あるため、自動更新は行わず、新しいバージョンがあることの案内だけを表示します。
			GitHubへの問い合わせは24時間に1回とし、結果は`log/powershell_update_check.txt`に保存します。
			(それ以外の起動時は保存した結果で判定します)
			取得に失敗した場合は何も表示せず、処理を継続します。

		.OUTPUTS
			[Void]

		.NOTES
			`$script:disableCheckPowerShellUpdate`が`$true`の場合は確認しません。
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($script:disableCheckPowerShellUpdate) { return }
	$cachePath = Join-Path $script:logDir 'powershell_update_check.txt'
	$latestVersion = $null
	$checkedAt = [DateTime]::MinValue
	try {
		if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
			$lines = @(Get-Content -LiteralPath $cachePath -TotalCount 2)
			if ($lines.Count -ge 2) {
				$checkedAt = [DateTime]::Parse($lines[0], [CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
				$latestVersion = $lines[1].Trim()
			}
		}
	} catch { $latestVersion = $null ; $checkedAt = [DateTime]::MinValue }
	$elapsedHours = ([DateTime]::UtcNow - $checkedAt.ToUniversalTime()).TotalHours
	if (!$latestVersion -or $elapsedHours -ge 24 -or $elapsedHours -lt 0) {
		$progressPreference = 'SilentlyContinue'
		try {
			$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -Method 'GET' -TimeoutSec $script:timeoutSec
			$latestVersion = ([String]$release.tag_name).Trim('v', ' ')
			if ($latestVersion -match '^\d+\.\d+\.\d+$') {
				Set-Content -LiteralPath $cachePath -Value @([DateTime]::UtcNow.ToString('o'), $latestVersion) -ErrorAction SilentlyContinue
			}
		} catch { Write-Debug $_ ; return }
		finally { $progressPreference = 'Continue' }
	}
	if ($latestVersion -notmatch '^\d+\.\d+\.\d+$') { return }
	$localVersion = $PSVersionTable.PSVersion.ToString().Split('-')[0]	# 7.6.0-preview.1 → 7.6.0
	if ((Compare-Version $latestVersion $localVersion) -gt 0) {
		[Console]::ForegroundColor = 'Green'
		Write-Output ('')
		Write-Warning ($script:msg.ToolOutdated -f 'PowerShell')
		Write-Warning ($script:msg.ToolLocalVersion -f $localVersion)
		Write-Warning ($script:msg.ToolRemoteVersion -f $latestVersion)
		Write-Warning ($script:msg.PowerShellUpdateHint)
		Write-Output ('')
		[Console]::ResetColor()
	}
}

#----------------------------------------------------------------------
# TVerRec最新化確認
#----------------------------------------------------------------------
function Invoke-TVerRecUpdateCheck {
	<#
		.SYNOPSIS
			TVerRecの最新バージョンを確認し、必要に応じて更新を促します。

		.DESCRIPTION
			GitHubのリリースページからTVerRecの最新バージョンを取得し、
			現在のバージョンと比較します。新しいバージョンが存在する場合は、
			更新を促すメッセージを表示し、変更履歴を表示します。

		.EXAMPLE
			Invoke-TVerRecUpdateCheck

		.NOTES
			この関数は以下の処理を行います：
			1. GitHubから最新リリース情報を取得
			2. 現在のバージョンと比較
			3. 新しいバージョンがある場合は更新を促す
			4. 変更履歴を表示
			5. 必要に応じてアップデーターを取得
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$progressPreference = 'silentlyContinue'
	Invoke-StatisticsCheck -Operation 'launch'
	# TVerRecの最新バージョン取得
	$repo = 'dongaba/TVerRec'
	$releases = ('https://api.github.com/repos/{0}/releases' -f $repo)
	try {
		$appReleases = (Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec).where{ !$_.prerelease }
		if (!$appReleases) { Write-Warning ($script:msg.ToolLatestNotIdentified -f 'TVerRec') ; return }
	} catch { Write-Warning ($script:msg.ToolLatestNotRetrieved -f 'TVerRec') ; return }
	finally { $progressPreference = 'Continue' }
	# GitHub側最新バージョンの整形
	$latestVersion = $appReleases[0].Tag_Name.Trim('v', ' ')	# v1.2.3 → 1.2.3
	$latestMajorVersion = $latestVersion.split(' ')[0]			# 1.2.3 beta 4 → 1.2.3
	# ローカル側バージョンの整形
	$appMajorVersion = $script:appVersion.split(' ')[0]			# 1.2.3 beta 4 → 1.2.3
	# バージョン判定
	$versionUp = (Compare-Version $latestMajorVersion $appMajorVersion) -gt 0
	# バージョンアップメッセージ
	if ($versionUp) {
		[Console]::ForegroundColor = 'Green'
		Write-Output ('')
		Write-Warning ($script:msg.ToolOutdated -f 'TVerRec')
		Write-Warning ($script:msg.ToolLocalVersion -f $script:appVersion)
		Write-Warning ($script:msg.ToolRemoteVersion -f $latestVersion)
		Write-Output ('')
		[Console]::ResetColor()
		# 変更履歴の表示
		foreach ($appRelease in @($appReleases.where({ (Compare-Version $_.Tag_Name.Trim('v', ' ').split(' ')[0] $appMajorVersion) -gt 0 }))) {
			[Console]::ForegroundColor = 'Green'
			Write-Output ($script:msg.MediumBoldBorder)
			Write-Output ($script:msg.ToolUpdateLog -f $appRelease.tag_name)
			Write-Output ($script:msg.MediumBoldBorder)
			Write-Output $appRelease.body.Replace('###', '■')
			Write-Output ('')
			[Console]::ResetColor()
		}
		# 最新のアップデータを取得
		$latestUpdater = 'https://raw.githubusercontent.com/dongaba/TVerRec/master/src/functions/update_tverrec.ps1'
		Invoke-WebRequest -Uri $latestUpdater -OutFile (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1') -TimeoutSec $script:timeoutSec
		if (!($IsLinux)) { Unblock-File -LiteralPath (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1') }
		# アップデート実行
		Write-Warning ($script:msg.ToolUpdateInstruction -f 'TVerRec', 'update_tverrec')
		foreach ($i in (1..10)) {
			$complete = ('█' * $i) * 5
			$remaining = ('▁' * (10 - $i)) * 5
			Write-Warning ($script:msg.SecWaitRemaining -f $complete, $remaining, (10 - $i) )
			Start-Sleep -Second 1
		}
	}
	Remove-Variable -Name versionUp, repo, releases, appReleases, latestVersion, latestMajorVersion, appMajorVersion, appRelease, latestUpdater, i, complete, remaining -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ytdl/ffmpegの最新化確認
#----------------------------------------------------------------------
function Invoke-ToolUpdateCheck {
	<#
		.SYNOPSIS
			ytdlまたはffmpegの更新スクリプトを実行します。

		.DESCRIPTION
			指定されたツールの更新スクリプトを実行し、更新処理を行います。
			更新に失敗した場合はエラーをスローします。

		.PARAMETER scriptName
			実行する更新スクリプトの名前を指定します。

		.PARAMETER targetName
			更新対象のツール名を指定します。

		.EXAMPLE
			Invoke-ToolUpdateCheck -scriptName "update_ytdl.ps1" -targetName "youtube-dl"

		.NOTES
			この関数は以下の処理を行います：
			1. 指定された更新スクリプトを実行
			2. 更新の成功/失敗を確認
			3. 失敗した場合はエラーをスロー
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$scriptName,
		[Parameter(Mandatory = $true)][String]$targetName
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	& (Join-Path $scriptRoot ('functions/{0}' -f $scriptName) )
	if (!$?) { throw ($script:msg.ToolUpdateFailed -f $targetName) }
	Remove-Variable -Name scriptName, targetName -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# pycryptodomex(暗号化ストリームの復号に必要)の導入確認
#----------------------------------------------------------------------
function Test-YtdlCryptoModule {
	<#
		.SYNOPSIS
			yt-dlpが使うPythonにpycryptodomexが導入されているかを確認し、未導入なら警告します。

		.DESCRIPTION
			AES-128で暗号化された動画ストリームは、pycryptodomexがないとyt-dlp内蔵の
			ダウンローダーで処理できず、ffmpegに処理が引き渡されます。
			その場合、証明書チェック回避設定がffmpegに引き継がれず、SSL証明書の検証エラーで
			番組が取得できなくなります。
			yt-dlpのshebangからPythonを特定し、Cryptodomeモジュールをimportできるかを確認します。
			確認のみで、環境の変更は行いません。Windowsではyt-dlp.exeが依存を同梱しているため対象外です。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. Windows、またはyt-dlp系以外のツールの場合は何もしない
			2. yt-dlpの1行目(shebang)から使用されるPythonを特定
			3. 特定したPythonでCryptodomeをimportできるか確認
			4. importできない場合のみ警告を表示(Pythonを特定できない場合は何もしない)
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($IsWindows) { return }
	if ($script:preferredYoutubedl -notin @('yt-dlp', 'yt-dlp-nightly')) { return }
	if (!(Test-Path -LiteralPath $script:ytdlPath -PathType Leaf)) { return }

	# yt-dlpの1行目(shebang)から使用されるPythonを特定
	$shebang = ''
	try {
		$stream = [System.IO.File]::OpenRead($script:ytdlPath)
		try {
			$buffer = New-Object byte[] 256
			$readLength = $stream.Read($buffer, 0, $buffer.Length)
			$shebang = ([System.Text.Encoding]::ASCII.GetString($buffer, 0, $readLength) -split '\r?\n')[0]
		} finally { $stream.Dispose() }
	} catch { Write-Debug $_ ; return }
	if ($shebang -notmatch '^#!\s*(\S+)(?:\s+(\S+))?') { return }
	$interpreter = $Matches[1]
	if ((Split-Path -Leaf $interpreter) -eq 'env' -and $Matches[2]) { $interpreter = $Matches[2] }
	$pythonCommand = Get-Command -Name $interpreter -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
	if (!$pythonCommand) { Write-Debug ('Python not found: {0}' -f $interpreter) ; return }

	# Cryptodomeをimportできるか確認
	try {
		& $pythonCommand.Source -c 'import Cryptodome' *> $null
		$exitCode = $LASTEXITCODE
	} catch { Write-Debug $_ ; return }
	if ($exitCode -ne 0) { Write-Warning ($script:msg.CryptoModuleNotFound -f $pythonCommand.Source) }

	Remove-Variable -Name shebang, stream, buffer, readLength, interpreter, pythonCommand, exitCode -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ファイル・ディレクトリの存在チェック、なければサンプルファイルコピー
#----------------------------------------------------------------------
function Invoke-TverrecPathCheck {
	<#
		.SYNOPSIS
			指定されたパスのファイルまたはディレクトリの存在を確認し、必要に応じてサンプルファイルをコピーします。

		.DESCRIPTION
			指定されたパスのファイルまたはディレクトリが存在するか確認します。
			存在しない場合、サンプルファイルが指定されていればそれをコピーします。
			サンプルファイルも存在しない場合は、エラーメッセージを表示します。

		.PARAMETER path
			確認するファイルまたはディレクトリのパスを指定します。

		.PARAMETER errorMessage
			パスが存在しない場合に表示するエラーメッセージを指定します。

		.PARAMETER isFile
			パスがファイルかディレクトリかを指定します。デフォルトはディレクトリです。

		.PARAMETER sampleFilePath
			サンプルファイルのパスを指定します。省略可能です。

		.PARAMETER continue
			エラーが発生した場合に処理を続行するかどうかを指定します。デフォルトは$falseです。

		.EXAMPLE
			Invoke-TverrecPathCheck -path "C:\TVerRec\config" -errorMessage "設定ディレクトリ" -isFile $false

		.NOTES
			この関数は以下の処理を行います：
			1. 指定されたパスの存在確認
			2. 存在しない場合、サンプルファイルのコピーを試みる
			3. サンプルファイルも存在しない場合、エラーメッセージを表示
	#>
	Param (
		[Parameter(Mandatory = $true )][String]$path,
		[Parameter(Mandatory = $true )][String]$errorMessage,
		[Parameter(Mandatory = $false)][Switch]$isFile,
		[Parameter(Mandatory = $false)][String]$sampleFilePath,
		[Parameter(Mandatory = $false)][Boolean]$continue
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	$pathType = if ($isFile) { 'Leaf' } else { 'Container' }
	if (!(Test-Path $path -PathType $pathType)) {
		if (!($sampleFilePath -and (Test-Path $sampleFilePath -PathType 'Leaf'))) {
			if ($continue) { Write-Warning ($script:msg.NotExistContinue -f $errorMessage) ; return }
			else { throw ($script:msg.NotExist -f $errorMessage) }
		}
		Copy-Item -LiteralPath $sampleFilePath -Destination $path -Force | Out-Null
	}
	Remove-Variable -Name path, errorMessage, isFile, sampleFilePath, continue, pathType -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 作業ディレクトリとダウンロード先ディレクトリの重複判定
#----------------------------------------------------------------------
function Test-WorkDirOverlap {
	<#
		.SYNOPSIS
			作業ディレクトリがダウンロード先ディレクトリと同一、またはダウンロード先ディレクトリを含むかを判定します。

		.DESCRIPTION
			不要ファイル削除処理は作業ディレクトリ配下の`*.jpg`や`*.part*`などを再帰的に削除するため、
			作業ディレクトリがダウンロード先と同一、またはダウンロード先を含むフォルダだと、
			ダウンロード済みの他のファイルまで削除する恐れがあります。
			そのような設定を検出するための判定を行います。
			パスの大文字小文字はWindowsとmacOSでは区別せず、Linuxでは区別します。

		.PARAMETER BaseDir
			ダウンロード先ディレクトリのパスを指定します。

		.PARAMETER WorkDir
			作業ディレクトリのパスを指定します。

		.OUTPUTS
			System.Boolean. 同一または包含している場合は$true、それ以外は$falseを返します。
	#>
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $true)][String]$BaseDir,
		[Parameter(Mandatory = $true)][String]$WorkDir
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$sep = [IO.Path]::DirectorySeparatorChar
	$comparison = if ($IsWindows -or $IsMacOS) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
	$base = [IO.Path]::GetFullPath($BaseDir).TrimEnd('\', '/')
	$work = [IO.Path]::GetFullPath($WorkDir).TrimEnd('\', '/')
	if ($base -eq '' -or $work -eq '') { return $true }	# ルート直下指定は常に包含とみなす
	if ([String]::Equals($base, $work, $comparison)) { return $true }
	return $base.StartsWith(($work + $sep), $comparison)
}

#----------------------------------------------------------------------
# 設定で指定したファイル・ディレクトリの存在チェック
#----------------------------------------------------------------------
function Invoke-RequiredFileCheck {
	<#
		.SYNOPSIS
			設定で指定された必須ファイルとディレクトリの存在を確認します。

		.DESCRIPTION
			設定ファイルで指定された必須のファイルとディレクトリが存在するか確認します。
			存在しない場合はエラーをスローします。

		.EXAMPLE
			Invoke-RequiredFileCheck

		.NOTES
			この関数は以下のファイルとディレクトリの存在を確認します：
			1. ダウンロードベースディレクトリ
			2. 作業ディレクトリ
			3. 保存ベースディレクトリ
			4. youtube-dl実行ファイル
			5. ffmpeg実行ファイル
			6. ffprobe実行ファイル（簡易検証、字幕の確認に使用）
			7. キーワードファイル
			8. 無視ファイル
			9. 履歴ファイル
			10. リストファイル
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:downloadBaseDir) { throw ($script:msg.DirNotSpecified -f $script:msg.DownloadDir) }
	else { Invoke-TverrecPathCheck -Path $script:downloadBaseDir -errorMessage $script:msg.DownloadDir }
	$script:downloadBaseDir = $script:downloadBaseDir.TrimEnd('\/')
	if (!$script:downloadWorkDir) { throw ($script:msg.DirNotSpecified -f $script:msg.WorkDir) }
	else { Invoke-TverrecPathCheck -Path $script:downloadWorkDir -errorMessage $script:msg.WorkDir }
	$script:downloadWorkDir = $script:downloadWorkDir.TrimEnd('\/')
	if (Test-WorkDirOverlap -BaseDir $script:downloadBaseDir -WorkDir $script:downloadWorkDir) { throw ($script:msg.WorkDirOverlap -f $script:downloadWorkDir, $script:downloadBaseDir) }
	if ($script:saveBaseDir) {
		$script:saveBaseDirArray = $script:saveBaseDir.split(';').Trim().TrimEnd('\/')
		foreach ($saveDir in $script:saveBaseDirArray) { Invoke-TverrecPathCheck -Path $saveDir.Trim() -errorMessage $script:msg.SaveDir -continue $true }
	}
	Invoke-TverrecPathCheck -Path $script:ytdlPath -errorMessage 'youtube-dl' -isFile
	Invoke-TverrecPathCheck -Path $script:ffmpegPath -errorMessage 'ffmpeg' -isFile
	Invoke-TverrecPathCheck -Path $script:ffprobePath -errorMessage 'ffprobe' -isFile
	Invoke-TverrecPathCheck -Path $script:keywordFilePath -errorMessage $script:msg.KeywordFile -isFile -sampleFilePath $script:keywordFileSamplePath
	Invoke-TverrecPathCheck -Path $script:ignoreFilePath -errorMessage $script:msg.IgnoreFile -isFile -sampleFilePath $script:ignoreFileSamplePath
	Invoke-TverrecPathCheck -Path $script:histFilePath -errorMessage $script:msg.HistFile -isFile -sampleFilePath $script:histFileSamplePath
	Invoke-TverrecPathCheck -Path $script:listFilePath -errorMessage $script:msg.ListFile -isFile -sampleFilePath $script:listFileSamplePath
	# 履歴に字幕の有無を記録する列(subtitle)がなければ追加(v3.4.9のレイアウト。通常はupdate_tverrec.ps1で追加済み)
	switch (Add-HistorySubtitleColumn) {
		'Added' { Write-Output ($script:msg.HistorySubtitleColumnAdded) }
		'Failed' { Write-Warning ($script:msg.HistorySubtitleColumnAddFailed) ; $script:redownloadWhenSubtitleAdded = $false }
	}
	Remove-Variable -Name saveDir -ErrorAction SilentlyContinue
}
#endregion 起動時関連
