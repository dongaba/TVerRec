###################################################################################
#
#		TVerRec固有関数スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecの主要な機能を提供する関数群を定義します。

	.DESCRIPTION
		TVerRecアプリケーションの中核となる機能を提供する関数群を定義します。
		主に以下の4つのカテゴリの機能を提供します：
		1. TVer APIアクセス関連
		- APIトークンの取得と管理
		- 番組情報の取得と解析
		2. ダウンロード管理関連
		- 番組のダウンロード処理
		- ダウンロードリストの管理
		- ダウンロード履歴の管理
		3. ファイル管理関連
		- ダウンロードファイルの命名規則
		- ファイルの整合性チェック
		- 一時ファイルの管理
		4. システム管理関連
		- 設定の管理
		- 統計情報の収集
		- 環境情報の管理

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 十分なディスク容量が必要です
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

		主要な機能：
		- TVer番組の検索とダウンロード
		- ダウンロードリストの作成と管理
		- ダウンロード履歴の管理
		- ファイルの整合性チェック
		- システム設定の管理
		- 統計情報の収集

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
Add-Type -AssemblyName 'System.Globalization' | Out-Null

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

#region ダウンロード履歴関連
#----------------------------------------------------------------------
# ダウンロード履歴の最新履歴を取得
#----------------------------------------------------------------------
function Get-LatestHistory {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルから各ビデオページの最新の履歴を取得します。

		.DESCRIPTION
			ダウンロード履歴ファイルを読み込み、各ビデオページごとに
			最新のダウンロード日時を持つレコードを取得します。

		.OUTPUTS
			[PSCustomObject[]] 各ビデオページの最新履歴レコードの配列

		.EXAMPLE
			$latestHists = Get-LatestHistory

		.NOTES
			この関数は以下の処理を行います：
			1. 履歴ファイルをロック
			2. CSVファイルとして読み込み
			3. ビデオページごとにグループ化
			4. 各グループから最新のレコードを取得
			5. ロックを解除
	#>
	[OutputType([PSCustomObject])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$latestHists = @()
	try {
		Wait-FileLock $script:histLockFilePath
		# videoPageごとに最新のdownloadDateを持つレコードを取得
		$latestHists = (Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8) |
			Group-Object -Property 'videoPage' |
			ForEach-Object { $_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1 }
	} catch { throw ($script:msg.LoadFailed -f $script:msg.HistFile) }	# * 履歴を読めないまま空で続行すると全番組を未ダウンロード扱いにしてしまうため、他のRead系関数と同様に例外とする
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	return $latestHists
}

#----------------------------------------------------------------------
# ダウンロード履歴の最新レコードを取得(一括ダウンロード中はキャッシュを使用)
#----------------------------------------------------------------------
function Get-LatestHistoryCached {
	<#
		.SYNOPSIS
			ダウンロード履歴の最新レコードを取得します。キャッシュがあればキャッシュを返します。

		.DESCRIPTION
			`$script:histCache`が設定されている場合は、履歴ファイルを読み直さずにその内容を返します。
			設定されていない場合は`Get-LatestHistory`で履歴ファイルを読み込みます。
			一括ダウンロードで番組ごとに履歴ファイル(CSV)の全件読み込みが走るのを避けるために使用します。

		.OUTPUTS
			[PSCustomObject[]] 各ビデオページの最新履歴レコードの配列

		.NOTES
			キャッシュは呼び出し元(download_bulk.ps1)が設定・破棄します。
			キャッシュ中は、他のPCが履歴ファイルに追記した内容は反映されません。
	#>
	[OutputType([PSCustomObject])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ((Test-Path Variable:Script:histCache) -and ($null -ne $script:histCache)) { return $script:histCache }
	return (Get-LatestHistory)
}

#----------------------------------------------------------------------
# ダウンロード履歴のキャッシュに新しいレコードを反映
#----------------------------------------------------------------------
function Add-LatestHistoryCache {
	<#
		.SYNOPSIS
			ダウンロード履歴のキャッシュに、履歴ファイルへ追記したレコードを反映します。

		.DESCRIPTION
			`$script:histCache`が設定されている場合に、同じビデオページのレコードを新しいレコードで置き換えます。
			キャッシュが設定されていない場合は何もしません。

		.PARAMETER Record
			履歴ファイルに追記したレコードを指定します。

		.OUTPUTS
			[Void]
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'スクリプト内のキャッシュ変数を更新するだけで、システムの状態は変更しない')]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $false)][AllowNull()][PSCustomObject]$Record)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-Path Variable:Script:histCache) -or ($null -eq $script:histCache) -or ($null -eq $Record)) { return }
	$script:histCache = @(@($script:histCache).Where({ $_ -and ($_.videoPage -ne $Record.videoPage) })) + @($Record)
	$script:histIdSet = $null	# ダウンロード済みIDのキャッシュは次回に作り直す
}

#----------------------------------------------------------------------
# ダウンロード対象外リストを取得(一括ダウンロード中はキャッシュを使用)
#----------------------------------------------------------------------
function Get-IgnoreListCached {
	<#
		.SYNOPSIS
			ダウンロード対象外番組のリストを取得します。キャッシュがあればキャッシュを返します。

		.DESCRIPTION
			`$script:ignoreCache`が設定されている場合は、ファイルを読み直さずにその内容を返します。
			設定されていない場合は`Read-IgnoreList`でファイルを読み込みます。

		.OUTPUTS
			[String[]] ダウンロード対象外番組名の配列

		.NOTES
			キャッシュは呼び出し元(download_bulk.ps1)が設定・破棄します。
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ((Test-Path Variable:Script:ignoreCache) -and ($null -ne $script:ignoreCache)) { return $script:ignoreCache }
	return (Read-IgnoreList)
}

#----------------------------------------------------------------------
# 字幕の有無の記録と再ダウンロードが有効かの判定
#----------------------------------------------------------------------
function Test-SubtitleTrackingEnabled {
	<#
		.SYNOPSIS
			字幕の有無の記録と、字幕が追加された番組の再ダウンロードが有効かを判定します。

		.DESCRIPTION
			`$script:redownloadWhenSubtitleAdded`が有効で、字幕の埋め込みが有効、かつ、mp4形式のときだけ有効とみなします。
			(字幕を埋め込まない場合は、字幕の有無を判定する意味がないため)

		.OUTPUTS
			[Boolean]
	#>
	[OutputType([Boolean])]
	Param ()
	return [Boolean]($script:redownloadWhenSubtitleAdded -and $script:embedSubtitle -and ($script:videoContainerFormat -eq 'mp4'))
}

#----------------------------------------------------------------------
# 番組の字幕の有無をyoutube-dlで確認
#----------------------------------------------------------------------
function Get-VideoSubtitleStatus {
	<#
		.SYNOPSIS
			TVerの番組に字幕が提供されているかを、ダウンロード前に確認します。

		.DESCRIPTION
			エピソードJSONのisSubtitle(Get-VideoInfoが取得済み)が渡されたときは、それをそのまま使います。
			渡されなかったとき(取得できなかったとき)は、
			`yt-dlp --skip-download --print %(subtitles)j`で字幕の一覧だけを取得します。
			字幕があれば`1`、字幕がなければ`0`を返します。
			取得に失敗した場合(配信終了や通信エラーなど)は、字幕の有無を判断できないため空文字を返します。

		.PARAMETER EpisodePageURL
			エピソードページのURLを指定します。

		.OUTPUTS
			[String]
			`1`: 字幕あり、`0`: 字幕なし、空文字: 不明
	#>
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $true)][String]$EpisodePageURL,
		[Object]$IsSubtitle = $null
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($IsSubtitle -is [Boolean]) { return $(if ($IsSubtitle) { '1' } else { '0' }) }
	$ytdlArgs = @('--skip-download', '--no-warnings', '--socket-timeout', '30', '--print', '%(subtitles)j')
	if ($script:proxyUrl) { $ytdlArgs += @('--geo-verification-proxy', $script:proxyUrl) }
	if (($script:ytdlRandomIp) -and (!$script:proxyUrl)) { $ytdlArgs += @('--xff', ('{0}/32' -f $script:jpIP)) }
	$ytdlArgs += $EpisodePageURL
	try {
		$output = @(& $script:ytdlPath @ytdlArgs 2>$null)
		if ($LASTEXITCODE -ne 0) { return '' }
		$text = ($output -join '').Trim()
		if (($text -eq 'NA') -or ($text -eq 'null')) { return '0' }	# 字幕がない番組はNAが返る
		$subtitles = $text | ConvertFrom-Json -ErrorAction Stop
		if ($subtitles -isnot [PSCustomObject]) { return '' }
		if (@($subtitles.PSObject.Properties).Count -gt 0) { return '1' }
		return '0'
	} catch { Write-Debug $_ ; return '' }
}

#----------------------------------------------------------------------
# 番組ファイルの字幕の有無をffprobeで確認
#----------------------------------------------------------------------
function Test-VideoFileHasSubtitle {
	<#
		.SYNOPSIS
			番組ファイルに字幕ストリームが含まれているかをffprobeで確認します。

		.PARAMETER VideoPath
			番組ファイルのパスを指定します。

		.OUTPUTS
			[Nullable[Boolean]]
			字幕があれば$true、なければ$false、確認できなければ$nullを返します。
	#>
	[OutputType([Object])]
	Param ([Parameter(Mandatory = $true)][String]$VideoPath)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-Path -LiteralPath $VideoPath -PathType Leaf)) { return $null }
	if (!(Test-Path -LiteralPath $script:ffprobePath -PathType Leaf)) { return $null }
	$probeOutPath = Join-Path ([IO.Path]::GetTempPath()) ('tverrec_subprobe_{0}.txt' -f [Guid]::NewGuid().ToString('N'))
	try {
		$probeArgs = ('-v error -select_streams s -show_entries stream=index -of csv=p=0 "{0}"' -f $VideoPath)
		$probe = Start-Process -FilePath $script:ffprobePath -ArgumentList $probeArgs -RedirectStandardOutput $probeOutPath -NoNewWindow -Wait -PassThru
		if (($probe.ExitCode -ne 0) -or !(Test-Path -LiteralPath $probeOutPath)) { return $null }
		return [Boolean](@(Get-Content -LiteralPath $probeOutPath -Encoding UTF8 | Where-Object { $_.Trim() -ne '' }).Count -gt 0)
	} catch { Write-Debug $_ ; return $null }
	finally { Remove-Item -LiteralPath $probeOutPath -Force -ErrorAction SilentlyContinue }
}

#----------------------------------------------------------------------
# ダウンロード履歴にsubtitle列があるかの判定
#----------------------------------------------------------------------
function Test-HistorySubtitleColumn {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルに字幕の有無を記録する列(subtitle)があるかを判定します。

		.OUTPUTS
			[Boolean]
	#>
	[OutputType([Boolean])]
	Param ()
	if ((Test-Path Variable:Script:histHasSubtitleColumn) -and $script:histHasSubtitleColumn) { return $true }
	try {
		$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
		try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
	} catch { return $false }
	$has = [Boolean]($header -and ($header -match '(^|,)"?subtitle"?(,|$)'))
	if ($has) { $script:histHasSubtitleColumn = $true }
	return $has
}

#----------------------------------------------------------------------
# ダウンロード履歴にsubtitle列を追加
#----------------------------------------------------------------------
function Add-HistorySubtitleColumn {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルに字幕の有無を記録する列(subtitle)を追加します。

		.DESCRIPTION
			既存の履歴の字幕の有無は不明なので、追加する列は空にします。
			すでに列がある場合は何もしません。
			追加前の履歴は`history.csv.bak`に退避します。

		.OUTPUTS
			[String]
			`Exists`: すでに列がある、`Added`: 追加した、`Failed`: 追加に失敗した
	#>
	[OutputType([String])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (Test-HistorySubtitleColumn) { return 'Exists' }
	$locked = $false
	$tempPath = $null
	try {
		Wait-FileLock $script:histLockFilePath
		$locked = $true
		# ロックを待つ間に他のプロセスが追加した場合
		if (Test-HistorySubtitleColumn) { return 'Exists' }
		$tempPath = '{0}.{1}.tmp' -f $script:histFilePath, [Guid]::NewGuid().ToString('N')
		$hists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -ErrorAction Stop)
		if ($hists.Count -gt 0) {
			$hists | Select-Object -Property *, @{ Name = 'subtitle' ; Expression = { '' } } | Export-Csv -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
		} else {
			$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
			try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
			if ([String]::IsNullOrWhiteSpace($header)) { throw 'History CSV header is missing.' }
			[IO.File]::WriteAllText($tempPath, ('{0},"subtitle"{1}' -f $header, [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
		}
		[IO.File]::Replace($tempPath, $script:histFilePath, ('{0}.bak' -f $script:histFilePath))
		$script:histHasSubtitleColumn = $true
		return 'Added'
	} catch { Write-Debug $_ ; return 'Failed' }
	finally {
		try { if ($null -ne $tempPath -and [IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) } }
		finally { if ($locked) { Unlock-File $script:histLockFilePath | Out-Null } }
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴の字幕の有無を更新
#----------------------------------------------------------------------
function Set-HistorySubtitleStatus {
	<#
		.SYNOPSIS
			ダウンロード履歴の字幕の有無を更新するレコードを追記します。

		.PARAMETER VideoHist
			更新対象の番組の履歴レコード(Get-LatestHistoryで取得したもの)を指定します。

		.PARAMETER Status
			`1`: 字幕あり、`0`: 字幕なし、空文字: 不明
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)]$VideoHist,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String]$Status
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-HistorySubtitleColumn)) { return }
	if (!$PSCmdlet.ShouldProcess($script:histFilePath, 'Update subtitle status')) { return }
	$record = $VideoHist.PSObject.Copy()
	$record.subtitle = $Status
	$record.downloadDate = Get-TimeStamp
	Wait-FileLock $script:histLockFilePath
	try { $record | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
	catch { Write-Warning ($script:msg.HistUpdateFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
}

#----------------------------------------------------------------------
# 字幕の再確認の対象をダウンロード済みから除外
#----------------------------------------------------------------------
function Remove-SubtitleRecheckTarget {
	<#
		.SYNOPSIS
			ダウンロード履歴から、字幕の再確認の対象になる番組(字幕なしで保存済み)を除きます。

		.DESCRIPTION
			ダウンロード済みの番組を判定する際に、字幕の再確認の対象を「ダウンロード済み」に含めないために使用します。
			字幕の再確認が有効でない場合は、履歴をそのまま返します。

		.PARAMETER Hist
			ダウンロード履歴のレコードを指定します。

		.OUTPUTS
			[Object[]]
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '履歴のレコードを絞り込んで返すだけで、システムの状態は変更しない')]
	[OutputType([Object[]])]
	Param ([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()][Object[]]$Hist)
	if (!(Test-SubtitleTrackingEnabled)) { return @($Hist) }
	return @($Hist.Where({ !($_.PSObject.Properties['subtitle'] -and ($_.subtitle -eq '0')) }))
}

#----------------------------------------------------------------------
# ダウンロード履歴データの成形
#----------------------------------------------------------------------
function Format-HistoryRecord {
	<#
		.SYNOPSIS
			ビデオ情報をダウンロード履歴レコードの形式に整形します。

		.DESCRIPTION
			ビデオ情報オブジェクトを参照で受け取り、ダウンロード履歴ファイルに
			保存するための形式に整形します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[PSCustomObject]
			ダウンロード履歴レコード。以下のプロパティを含みます：
			- videoPage: エピソードページのURL
			- videoSeriesPage: シリーズページのURL
			- genre: ジャンル
			- series: シリーズ名
			- season: シーズン名
			- title: エピソードタイトル
			- media: メディア名
			- broadcastDate: 放送日
			- downloadDate: ダウンロード日時
			- videoDir: ビデオディレクトリ
			- videoName: ビデオファイル名
			- videoPath: ビデオファイルの相対パス
			- videoValidated: 検証状態
			- subtitle: 字幕の有無(1:字幕あり、0:字幕なし、空:不明)

		.EXAMPLE
			$historyRecord = Format-HistoryRecord -videoInfo $videoInfo

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオ情報から必要なデータを抽出
			2. ダウンロード履歴レコードの形式に整形
			3. 整形したレコードを返す
	#>
	Param ([Parameter(Mandatory = $true)][PSCustomObject]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	return [PSCustomObject]@{
		videoPage       = $videoInfo.episodePageURL
		videoSeriesPage = $videoInfo.seriesPageURL
		genre           = $videoInfo.keyword
		series          = $videoInfo.seriesName
		season          = $videoInfo.seasonName
		title           = $videoInfo.episodeName
		media           = $videoInfo.mediaName
		broadcastDate   = $videoInfo.broadcastDate
		downloadDate    = Get-TimeStamp
		videoDir        = $videoInfo.fileDir
		videoName       = $videoInfo.fileName
		videoPath       = $videoInfo.fileRelPath
		videoValidated  = $videoInfo.validated
		subtitle        = if ($videoInfo.PSObject.Properties['subtitle']) { [String]$videoInfo.subtitle } else { '' }
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴ファイルの安全な保存(一時ファイル経由で置換)
#----------------------------------------------------------------------
function Save-HistoryFile {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルを、一時ファイル経由で安全に書き換えます。

		.DESCRIPTION
			履歴の内容をいったん一時ファイルに書き出し、書き出しが成功してから履歴ファイルと置換します。
			書き出し中に失敗したり、処理が強制停止されたりしても、元の履歴ファイルは変更されません。
			置換時には直前の履歴を「.bak」として退避します。
			呼び出し元で履歴ファイルのロック(Wait-FileLock)を取得した状態で使用してください。

		.PARAMETER Records
			CSV形式で保存するレコードを指定します。0件の場合は元のCSVヘッダーだけを残します。

		.PARAMETER Lines
			テキスト行として保存する内容を指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。失敗時は例外をスローします。
	#>
	[CmdletBinding(DefaultParameterSetName = 'Csv')]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Csv')][AllowEmptyCollection()][AllowNull()][Object[]]$Records,
		[Parameter(Mandatory = $true, ParameterSetName = 'Text')][AllowEmptyCollection()][AllowNull()][String[]]$Lines
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tempPath = '{0}.{1}.tmp' -f $script:histFilePath, [Guid]::NewGuid().ToString('N')
	try {
		if ($PSCmdlet.ParameterSetName -eq 'Text') {
			if ($Lines) { $Lines | Set-Content -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop }
			else { New-Item -ItemType File -Path $tempPath -Force -ErrorAction Stop | Out-Null }
		} elseif ($null -ne $Records -and @($Records).Count -gt 0) {
			$Records | Export-Csv -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
		} else {
			# 全件削除でもCSVヘッダーを残し、次回の追記を読み取れるようにする
			$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
			try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
			if ([String]::IsNullOrWhiteSpace($header)) { throw 'History CSV header is missing.' }
			[IO.File]::WriteAllText($tempPath, $header + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
		}
		# 共有フォルダやウイルス対策ソフトによる一時的なアクセス競合に備えて、置換を数回リトライする
		for ($retry = 1 ; $retry -le 5 ; $retry++) {
			try { [IO.File]::Replace($tempPath, $script:histFilePath, $script:histFilePath + '.bak') ; break }
			catch { if ($retry -ge 5) { throw } ; Start-Sleep -Milliseconds 200 }
		}
	} finally {
		try { if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) } } catch { Write-Debug $_.Exception.Message }
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function Optimize-HistoryFile {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルの不整合を解消します。

		.DESCRIPTION
			ダウンロード履歴ファイルの不整合を解消します。
			NULL文字を含む行を削除し、videoValidatedとdownloadDateの形式を検証します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 履歴ファイルをロック
			2. NULL文字を含む行を削除
			3. videoValidatedとdownloadDateの形式を検証
			4. 検証に合格したレコードのみを残す
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		Wait-FileLock $script:histLockFilePath
		$originalLists = @(Get-Content -LiteralPath $script:histFilePath -Encoding UTF8 -ErrorAction Stop)
		# NULL文字(0x00)を含む行をフィルタリング
		$cleanedHist = $originalLists.Where({ $_ -notmatch "`0" })
		# 一時ファイル経由で置換(途中で失敗・強制停止されても元の履歴は壊れない)
		try { Save-HistoryFile -Lines $cleanedHist }
		finally { Start-Sleep -Seconds 1 }
	} catch { Write-Warning ($script:msg.OptimizeHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	try {
		Wait-FileLock $script:histLockFilePath
		$originalLists = Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		# videoValidatedがNullでなく、整数に変換可能。downloadDateが日付に変換できるものを残す
		$cleanedHist = $originalLists.Where({
			($null -ne $_.videoValidated) `
					-and ([Int]::TryParse($_.videoValidated, [Ref]0)) `
					-and ([DateTime]::TryParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null, [System.Globalization.DateTimeStyles]::None, [Ref]([DateTime]::MinValue)))
			})
		# 一時ファイル経由で置換(途中で失敗・強制停止されても元の履歴は壊れない)
		try { Save-HistoryFile -Records $cleanedHist }
		finally { Start-Sleep -Seconds 1 }
	} catch {
		Write-Warning ($script:msg.OptimizeHistFailed)
	} finally {
		Unlock-File $script:histLockFilePath | Out-Null
		Remove-Variable -Name cleanedHist -ErrorAction SilentlyContinue
	}
}

#----------------------------------------------------------------------
# 指定日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function Limit-HistoryFile {
	<#
		.SYNOPSIS
			指定された期間より古いダウンロード履歴を削除します。

		.DESCRIPTION
			指定された期間より古いダウンロード履歴を削除します。
			保持期間を過ぎたレコードは履歴ファイルから削除されます。

		.PARAMETER retentionPeriod
			履歴を保持する期間（日数）を指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Limit-HistoryFile -retentionPeriod 30

		.NOTES
			この関数は以下の処理を行います：
			1. 履歴ファイルをロック
			2. 指定期間より古いレコードをフィルタリング
			3. フィルタリングされたレコードを履歴ファイルに保存
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][Int32]$retentionPeriod)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		Wait-FileLock $script:histLockFilePath
		$originalLists = Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		$purgedHist = $originalLists.Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt (Get-Date).AddDays(-1 * $retentionPeriod) })
		# 一時ファイル経由で置換(途中で失敗・強制停止されても元の履歴は壊れない)
		try { Save-HistoryFile -Records $purgedHist }
		finally { Start-Sleep -Seconds 1 }
	} catch {
		Write-Warning ($script:msg.CleanupHistFailed)
	} finally {
		Unlock-File $script:histLockFilePath | Out-Null
		Remove-Variable -Name retentionPeriod, purgedHist -ErrorAction SilentlyContinue
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function Repair-HistoryFile {
	<#
		.SYNOPSIS
			ダウンロード履歴から重複を削除します。

		.DESCRIPTION
			ダウンロード履歴から重複を削除します。
			videoPageごとに最新のdownloadDateを持つレコードを残し、
			videoValidatedが「3:チェック失敗」のものと同じvideoPageを持つレコードを削除します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. videoPageごとに最新のdownloadDateを持つレコードを取得
			2. videoValidatedが「3:チェック失敗」のものと同じvideoPageを持つレコードを削除
			3. 重複削除されたレコードを履歴ファイルに保存
	#>
	[OutputType([Void])]
	Param ()
	$locked = $false
	$tempPath = $null
	try {
		# 読み込みから置換まで同じロックを保持し、途中の追記を失わないようにする
		Wait-FileLock $script:histLockFilePath
		$locked = $true
		$latestHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -ErrorAction Stop |
			Group-Object -Property 'videoPage' |
			ForEach-Object { $_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1 })
		$uniquedHist = @($latestHists.Where({ $_.videoValidated -ne '3' }))
		$tempPath = '{0}.{1}.tmp' -f $script:histFilePath, [Guid]::NewGuid().ToString('N')
		if ($uniquedHist.Count -gt 0) {
			$uniquedHist | Export-Csv -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
		} else {
			# 全件削除でもCSVヘッダーを残し、次回の追記を読み取れるようにする
			$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
			try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
			if ([String]::IsNullOrWhiteSpace($header)) { throw 'History CSV header is missing.' }
			[IO.File]::WriteAllText($tempPath, $header + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
		}
		# 一時ファイルの保存失敗時は元履歴に触れず、置換時に直前の履歴を退避する
		[IO.File]::Replace($tempPath, $script:histFilePath, $script:histFilePath + '.bak')
	} catch {
		Write-Warning ($script:msg.DistinctHistFailed)
	} finally {
		try {
			if ($null -ne $tempPath -and [IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) }
		} finally {
			if ($locked) { Unlock-File $script:histLockFilePath | Out-Null }
		}
	}

}
#endregion ダウンロード履歴関連

#region ダウンロードリスト関連
#----------------------------------------------------------------------
# ダウンロードリストの読み込み
#----------------------------------------------------------------------
function Read-DownloadList {
	<#
		.SYNOPSIS
			ダウンロードリストファイルからダウンロード対象の情報を読み込みます。

		.DESCRIPTION
			ダウンロードリストファイルをCSV形式で読み込み、ダウンロード対象の
			情報を配列として返します。

		.OUTPUTS
			[PSCustomObject[]] ダウンロード対象の情報の配列

		.EXAMPLE
			$downloadList = Read-DownloadList

		.NOTES
			この関数は以下の処理を行います：
			1. リストファイルをロック
			2. CSVファイルとして読み込み
			3. ロックを解除
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$listFileData = @()
	try {
		Wait-FileLock $script:listLockFilePath
		$listFileData = Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8
	} catch { throw ($script:msg.LoadFailed -f $script:msg.ListFile) }
	finally { Unlock-File $script:listLockFilePath | Out-Null }
	return $listFileData
}

#----------------------------------------------------------------------
# ダウンロードリストからダウンロードリンクの読み込み
#----------------------------------------------------------------------
function Get-LinkFromDownloadList {
	<#
		.SYNOPSIS
			ダウンロードリストからTVerのエピソードリンクを取得します。

		.DESCRIPTION
			ダウンロードリストファイルからEpisodeIDを抽出し、TVerのエピソード
			リンクに変換して返します。

		.OUTPUTS
			[String[]] TVerのエピソードリンクの配列

		.EXAMPLE
			$videoLinks = Get-LinkFromDownloadList

		.NOTES
			この関数は以下の処理を行います：
			1. リストファイルをロック
			2. CSVファイルとして読み込み
			3. 空行とダウンロード対象外（#で始まる行）を除外
			4. EpisodeIDをTVerのエピソードリンクに変換
			5. ロックを解除
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (Test-Path $script:listFilePath -PathType Leaf) {
		try {
			Wait-FileLock $script:listLockFilePath
			# 空行とダウンロード対象外を除き、EpisodeIDのみを抽出
			$videoLinks = @((Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_.EpisodeID -cmatch '^#') }) | Select-Object episodeID)
		} catch { throw ($script:msg.LoadFailed -f $script:msg.ListFile) }
		finally { Unlock-File $script:listLockFilePath | Out-Null }
	} else { $videoLinks = @() }
	# 有効な行がない場合(ヘッダーのみ、またはすべてコメントアウト)は、StrictModeで空配列のプロパティ参照がエラーになるため、先に返す
	if ($videoLinks.Count -eq 0) { return @() }
	$episodeIDs = [string[]]$videoLinks.episodeID
	return @($episodeIDs)
}

#----------------------------------------------------------------------
# ダウンロードリストデータの成形
#----------------------------------------------------------------------
function Format-ListRecord {
	<#
		.SYNOPSIS
			ビデオ情報をダウンロードリストレコードの形式に整形します。

		.DESCRIPTION
			ビデオ情報オブジェクトを参照で受け取り、ダウンロードリストファイルに
			保存するための形式に整形します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[PSCustomObject]
			ダウンロードリストレコード。以下のプロパティを含みます：
			- seriesName: シリーズ名
			- seriesID: シリーズID
			- seriesPageURL: シリーズページのURL
			- seasonName: シーズン名
			- seasonID: シーズンID
			- episodeNo: エピソード番号
			- episodeName: エピソードタイトル
			- episodeID: エピソードID
			- episodePageURL: エピソードページのURL
			- media: メディア名
			- provider: プロバイダー名
			- broadcastDate: 放送日
			- endTime: 終了時間
			- keyword: キーワード
			- ignoreWord: 無視する単語
			- descriptionText: 説明文（オプション）

		.EXAMPLE
			$listRecord = Format-ListRecord -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオ情報から必要なデータを抽出
			2. ダウンロードリストレコードの形式に整形
			3. 説明文の有無に応じてプロパティを追加
			4. 整形したレコードを返す
	#>
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$downloadListItem = [PSCustomObject]@{
		seriesName     = $videoInfo.seriesName
		seriesID       = $videoInfo.seriesID
		seriesPageURL  = $videoInfo.seriesPageURL
		seasonName     = $videoInfo.seasonName
		seasonID       = $videoInfo.seasonID
		episodeNo      = $videoInfo.episodeNum
		episodeName    = $videoInfo.episodeName
		episodeID      = $videoInfo.episodeID
		episodePageURL = $videoInfo.episodePageURL
		media          = $videoInfo.mediaName
		provider       = $videoInfo.providerName
		broadcastDate  = $videoInfo.broadcastDate
		endTime        = $videoInfo.endTime
		keyword        = $videoInfo.keyword
		ignoreWord     = $videoInfo.ignoreWord
	}
	if ($script:extractDescTextToList) { $downloadListItem | Add-Member -NotePropertyName descriptionText -NotePropertyValue $videoInfo.descriptionText }
	else { $downloadListItem | Add-Member -NotePropertyName descriptionText -NotePropertyValue '' }
	return $downloadListItem
}

#----------------------------------------------------------------------
# TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function Update-VideoList {
	<#
		.SYNOPSIS
			TVer番組のダウンロードリストを作成します。

		.DESCRIPTION
			指定されたキーワードでTVer番組を検索し、ダウンロードリストを作成します。
			無視リストに登録されている番組は除外されます。

		.PARAMETER keyword
			検索キーワードを指定します。

		.OUTPUTS
			System.Void

		.EXAMPLE
			Update-VideoList -keyword "ドラマ"

		.NOTES
			処理の流れ:
			1. キーワードでTVer番組を検索
			2. 無視リストに登録されている番組を除外
			3. ダウンロードリストをCSVファイルに出力
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$keyword,
		[Parameter(Mandatory = $true)][String]$episodeID
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreWord = ''
	$newVideo = $null
	$ignore = $false
	# TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ($script:msg.EpisodeInfoRetrievalFailed) ; return }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	# ダウンロード対象外に入っている番組の場合はリスト出力しない
	$ignoreTitles = @(Read-IgnoreList)
	foreach ($ignoreTitle in $ignoreTitles) {
		if ($ignoreTitle) {
			if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.seriesName, $videoInfo.episodeName) -Mode Literal) {
				$ignoreWord = $ignoreTitle ; Update-IgnoreList $ignoreTitle ; $ignore = $true
				$videoInfo.episodeID = ('#{0}' -f $videoInfo.episodeID)
				break
			}
		}
	}
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'ignoreWord' -Value $ignoreWord
	# 番組情報のコンソール出力
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo ([Ref]$videoInfo) }
	# スキップフラグが立っているかチェック
	if ($ignore) { Write-Warning ($script:msg.ListIgnoredAdded) ; $newVideo = Format-ListRecord ([Ref]$videoInfo) }
	else { Write-Output ($script:msg.ListAdded) ; $newVideo = Format-ListRecord ([Ref]$videoInfo) }
	# ダウンロードリストCSV書き出し
	try {
		Wait-FileLock $script:listLockFilePath
		if ($PSCmdlet.ShouldProcess($script:listFilePath, 'Add to download list')) { $newVideo | Export-Csv -LiteralPath $script:listFilePath -Encoding UTF8 -Append }
		Write-Debug ($script:msg.ListWritten)
	} catch {
		Write-Warning ($script:msg.ListUpdateFailed) ; return
	} finally {
		Unlock-File $script:listLockFilePath | Out-Null
		Remove-Variable -Name keyword, videoLink, ignoreWord, newVideo, ignore, episodeID, ignoreTitles, ignoreTitle -ErrorAction SilentlyContinue
	}
}

#endregion ダウンロードリスト関連

#region ダウンロード対象外リスト関連
#----------------------------------------------------------------------
# ダウンロード対象外リストの1行が対象文字列にマッチするかを判定
#----------------------------------------------------------------------
function Test-IgnoreMatch {
	<#
		.SYNOPSIS
			ダウンロード対象外リストの1行が、いずれかの対象文字列にマッチするかを判定します。

		.DESCRIPTION
			行頭が`regex:`の行は、それ以降を.NETの正規表現として対象文字列に適用します。
			(部分一致。大文字小文字は区別します。区別しない場合は`regex:(?i)...`のように指定します)
			それ以外の行は、従来どおり呼び出し元ごとの方式で判定します。
			- Literal : 大文字小文字を区別する部分一致(ワイルドカードは通常の文字)。リスト作成時の判定
			- Wildcard: `-like '*行*'`によるワイルドカード判定。ダウンロード時・不要ファイル削除時の判定
			不正な正規表現の行は警告を1回だけ表示し、マッチしないものとして扱います。

		.PARAMETER Pattern
			ダウンロード対象外リストの1行を指定します。

		.PARAMETER Target
			判定対象の文字列(番組名、ファイル名など)を指定します。いずれかにマッチすれば$trueを返します。

		.PARAMETER Mode
			`regex:`で始まらない行の判定方式(Literal/Wildcard)を指定します。

		.OUTPUTS
			[Boolean]
			マッチした場合は$true、それ以外は$false。

		.EXAMPLE
			Test-IgnoreMatch -Pattern 'regex:冷凍庫に眠っている (第|最終)' -Target @($videoInfo.fileName) -Mode Wildcard
	#>
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $true)][String]$Pattern,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String[]]$Target,
		[Parameter(Mandatory = $true)][ValidateSet('Literal', 'Wildcard')][String]$Mode
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$targets = @($Target).Where({ $_ })
	if ($targets.Count -eq 0) { return $false }

	if ($Pattern -cmatch '^regex:(.*)$') {
		$body = $Matches[1].Normalize([Text.NormalizationForm]::FormC)
		if (!(Test-Path Variable:Script:ignoreRegexCache)) { $script:ignoreRegexCache = @{} }
		if (!$script:ignoreRegexCache.ContainsKey($Pattern)) {
			$regex = $null
			if ($body.Trim() -ne '') {
				try { $regex = [Regex]::new($body, [Text.RegularExpressions.RegexOptions]::None, [TimeSpan]::FromSeconds(1)) }
				catch { $regex = $null }
			}
			if ($null -eq $regex) { Write-Warning ($script:msg.IgnoreRegexInvalid -f $Pattern) }
			$script:ignoreRegexCache[$Pattern] = $regex
		}
		$regex = $script:ignoreRegexCache[$Pattern]
		if ($null -eq $regex) { return $false }
		foreach ($item in $targets) {
			try { if ($regex.IsMatch($item.Normalize([Text.NormalizationForm]::FormC))) { return $true } }
			catch [System.Text.RegularExpressions.RegexMatchTimeoutException] { Write-Warning ($script:msg.IgnoreRegexTimeout -f $Pattern) ; return $false }
		}
		return $false
	}

	foreach ($item in $targets) {
		switch ($Mode) {
			'Literal' { if ($item -cmatch [RegEx]::Escape($Pattern)) { return $true } }
			'Wildcard' { if ($item -like ('*{0}*' -f $Pattern)) { return $true } }
		}
	}
	return $false
}

#----------------------------------------------------------------------
# ダウンロード対象外番組の読み込み
#----------------------------------------------------------------------
function Read-IgnoreList {
	<#
		.SYNOPSIS
			ダウンロード対象外番組のリストを読み込みます。

		.DESCRIPTION
			ダウンロード対象外番組のリストファイルから、コメント行と空行を除いた
			番組名を読み込み、配列として返します。

		.OUTPUTS
			[String[]] ダウンロード対象外番組名の配列

		.EXAMPLE
			$ignoreTitles = Read-IgnoreList

		.NOTES
			この関数は以下の処理を行います：
			1. 無視ファイルをロック
			2. UTF8エンコーディングで読み込み
			3. コメント行（;で始まる行）と空行を除外
			4. ロックを解除
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreTitles = @()
	try {
		Wait-FileLock $script:ignoreLockFilePath
		# コメントと空行を除いて抽出
		$ignoreTitles = @((Get-Content $script:ignoreFilePath -Encoding UTF8 -ErrorAction Stop).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_ -cmatch '^;.*$') }))
	} catch { throw ($script:msg.LoadFailed -f $script:msg.IgnoreFile) }
	finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	return $ignoreTitles
}

#----------------------------------------------------------------------
# ダウンロード対象外番組のソート(使用したものを上に移動)
#----------------------------------------------------------------------
function Update-IgnoreList {
	<#
		.SYNOPSIS
			ダウンロード対象外番組リストを更新し、使用した番組をリストの先頭に移動します。

		.DESCRIPTION
			指定された番組名をダウンロード対象外リストに追加し、使用した番組を
			リストの先頭に移動します。リストの構造（コメント、対象番組、その他）を
			維持しながら更新します。

		.PARAMETER ignoreTitle
			ダウンロード対象外リストに追加する番組名を指定します。

		.EXAMPLE
			Update-IgnoreList -ignoreTitle "テスト番組"

		.NOTES
			この関数は以下の処理を行います：
			1. 無視ファイルをロック
			2. 既存のリストを読み込み
			3. コメント、対象番組、その他の行を分類
			4. 新しいリストを作成（コメント→対象番組→その他の順）
			5. リストを更新
			6. ロックを解除
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][String]$ignoreTitle)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreLists = @()
	$ignoreComment = @()
	$ignoreTarget = @()
	$ignoreElse = @()
	$ignoreListNew = @()
	if ((Test-Path $script:ignoreFilePath -PathType Leaf) -and $PSCmdlet.ShouldProcess($script:ignoreFilePath, 'Update ignore list')) {
		try {
			Wait-FileLock $script:ignoreLockFilePath
			$ignoreLists = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where( { $_ -notmatch '^\s*$|^(;;.*)$' }))
			$ignoreComment = @(Get-Content $script:ignoreFileSamplePath -Encoding UTF8)
			$ignoreTarget = @($ignoreLists.Where({ $_ -eq $ignoreTitle }) | Sort-Object -Unique)
			$ignoreElse = @($ignoreLists.Where({ $_ -notin $ignoreTitle }))
			if ($ignoreComment) { $ignoreListNew += $ignoreComment }
			if ($ignoreTarget) { $ignoreListNew += $ignoreTarget }
			if ($ignoreElse) { $ignoreListNew += $ignoreElse }
			# 改行コードLFを強制 + NFCで出力
			# 一時ファイルに書き出してから置換する(読み取り側が書き込み途中の不完全な内容を見ないようにする。失敗時は元ファイルに触れない)
			$tempPath = '{0}.{1}.tmp' -f $script:ignoreFilePath, [Guid]::NewGuid().ToString('N')
			try {
				$ignoreContent = (-join $ignoreListNew.ForEach({ '{0}{1}' -f $_, "`n" })).Normalize([Text.NormalizationForm]::FormC)
				[IO.File]::WriteAllText($tempPath, $ignoreContent, [Text.UTF8Encoding]::new($false))
				# 共有フォルダやウイルス対策ソフトによる一時的なアクセス競合に備えて、置換を数回リトライする
				for ($retry = 1 ; $retry -le 5 ; $retry++) {
					try { [IO.File]::Replace($tempPath, $script:ignoreFilePath, [NullString]::Value) ; break }
					catch { if ($retry -ge 5) { throw } ; Start-Sleep -Milliseconds 200 }
				}
				Start-Sleep -Seconds 1
				Write-Debug ($script:msg.IgnoreFileSortCompleted)
			} catch { Write-Warning ($script:msg.IgnoreFileSortFailed) }
			finally {
				try { if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) } } catch { Write-Debug $_.Exception.Message }
				Start-Sleep -Seconds 1
			}
		} catch { Write-Warning ($script:msg.IgnoreFileSortFailed) }
		finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	}
	Remove-Variable -Name ignoreTitle, ignoreLists, ignoreComment, ignoreTarget, ignoreElse, ignoreListNew -ErrorAction SilentlyContinue
}
#----------------------------------------------------------------------
# ダウンロード対象外リストにマッチする番組名(フォルダ名)の一括特定
#----------------------------------------------------------------------
function Find-IgnoreMatchedIndex {
	<#
		.SYNOPSIS
			ダウンロード対象外リストの各行にマッチする番組名の位置を一括で特定します。

		.DESCRIPTION
			Test-IgnoreMatch -Mode Wildcard を「リストの行数 x 番組名の数」回呼び出す処理の高速版です。
			(3,000行 x 1,000フォルダでは数百万回の関数呼び出しとなり、数分かかるため)
			判定結果は Test-IgnoreMatch -Mode Wildcard と同じです。
			- regex:で始まる行 : Test-IgnoreMatch に委ねる
			- *?[ ]を含む行 : -like '*行*' と同じワイルドカード判定(大文字小文字を区別しない)
			- その他の行 : 部分一致(大文字小文字を区別しない)。全番組名を連結した文字列で一次判定する

		.PARAMETER Name
			判定対象の番組名(フォルダ名)の配列を指定します。NFCに正規化して判定します。

		.PARAMETER IgnoreTitle
			ダウンロード対象外リストの行(コメント・空行を除いたもの)の配列を指定します。

		.OUTPUTS
			[PSCustomObject]
			Index     : マッチした番組名の位置(Nameの添字)の昇順配列
			UsedTitle : 1件以上マッチしたリストの行(NFC正規化後)の配列

		.EXAMPLE
			$result = Find-IgnoreMatchedIndex -Name $workDirEntities.Name -IgnoreTitle $ignoreTitles
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][String[]]$Name,
		[Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][String[]]$IgnoreTitle
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$names = @($Name.ForEach({ $_.Normalize([Text.NormalizationForm]::FormC) }))
	$allNames = [String]::Join("`n", $names)
	$matchedIdx = New-Object System.Collections.Generic.HashSet[Int]
	$usedTitles = New-Object System.Collections.Generic.List[String]
	foreach ($titleRaw in $IgnoreTitle) {
		$title = $titleRaw.Normalize([Text.NormalizationForm]::FormC)
		$hit = $false
		if ($title -cmatch '^regex:') {
			for ($i = 0 ; $i -lt $names.Count ; $i++) {
				if (Test-IgnoreMatch -Pattern $title -Target @($names[$i]) -Mode Wildcard) { [void]$matchedIdx.Add($i) ; $hit = $true }
			}
		} elseif ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($title)) {
			$wildcard = [Management.Automation.WildcardPattern]::new(('*{0}*' -f $title), [Management.Automation.WildcardOptions]::IgnoreCase)
			for ($i = 0 ; $i -lt $names.Count ; $i++) {
				if ($names[$i] -and $wildcard.IsMatch($names[$i])) { [void]$matchedIdx.Add($i) ; $hit = $true }
			}
		} elseif ($allNames.IndexOf($title, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
			for ($i = 0 ; $i -lt $names.Count ; $i++) {
				if ($names[$i] -and $names[$i].IndexOf($title, [StringComparison]::OrdinalIgnoreCase) -ge 0) { [void]$matchedIdx.Add($i) ; $hit = $true }
			}
		}
		if ($hit) { $usedTitles.Add($title) }
	}
	return [PSCustomObject]@{
		Index     = [Int[]]@($matchedIdx | Sort-Object)
		UsedTitle = [String[]]$usedTitles.ToArray()
	}
}
#endregion ダウンロード対象外リスト関連

#region ダウンロード対象判定処理
#----------------------------------------------------------------------
# ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function Read-KeywordList {
	<#
		.SYNOPSIS
			キーワードファイルからダウンロード対象のキーワードを読み込みます。

		.DESCRIPTION
			キーワードファイルからコメント行と空行を除いたキーワードを読み込み、
			配列として返します。

		.OUTPUTS
			[String[]] キーワードの配列

		.EXAMPLE
			$keywords = Read-KeywordList

		.NOTES
			この関数は以下の処理を行います：
			1. キーワードファイルをUTF8エンコーディングで読み込み
			2. コメント行（#で始まる行）と空行を除外
			3. 残りの行を配列として返す
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$keywords = @()
	# コメントと空行を除いて抽出
	try { $keywords = @((Get-Content $script:keywordFilePath -Encoding UTF8 -ErrorAction Stop).Where({ $_ -notmatch '^\s*$|^#.*$' })) }
	catch { throw ($script:msg.LoadFailed -f $script:msg.KeywordFile) }
	return $keywords
}

#----------------------------------------------------------------------
# URLが既にダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryMatchCheck {
	<#
		.SYNOPSIS
			指定されたエピソードIDがダウンロード履歴に存在するかチェックし、未ダウンロードのエピソードIDのみを返します。

		.DESCRIPTION
			指定されたエピソードIDのリストとダウンロード履歴を比較し、まだダウンロードされていない
			エピソードIDのみを返します。また、既にダウンロード済みのエピソードIDの数も返します。

		.PARAMETER episodeLinks
			チェック対象のエピソードIDのリストを指定します。

		.OUTPUTS
			[String[]]
			未ダウンロードのエピソードIDの配列と、既にダウンロード済みのエピソードIDの数を含む配列。

		.EXAMPLE
			$result = Invoke-HistoryMatchCheck -episodeLinks @("epXXXXXXXX", "epYYYYYYYY")

		.NOTES
			この関数は以下の処理を行います：
			1. 最新のダウンロード履歴を取得
			2. 履歴に存在するエピソードIDを抽出
			3. 指定されたエピソードIDのリストと履歴を比較
			4. 未ダウンロードのエピソードIDとダウンロード済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][String[]]$episodeLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロード履歴ファイルのデータを読み込み
	# 一括ダウンロード中(履歴キャッシュあり)は、ダウンロード済みのIDをHashSetにして使い回す(キーワードごとの全件処理を避けるため)
	if ((Test-Path Variable:Script:histCache) -and ($null -ne $script:histCache)) {
		if (!(Test-Path Variable:Script:histIdSet) -or ($null -eq $script:histIdSet)) {
			$histFileData = @(Remove-SubtitleRecheckTarget @(Get-LatestHistoryCached))	# 字幕の再確認の対象は「ダウンロード済み」に含めない
			$histIdList = [System.Collections.Generic.List[String]]::new()
			foreach ($histRecord in $histFileData.Where({ $_ })) { $histIdList.Add($histRecord.videoPage.Replace('https://tver.jp/episodes/', '')) }
			# * Compare-Objectと同様に大文字小文字を区別しない
			$script:histIdSet = [System.Collections.Generic.HashSet[String]]::new($histIdList, [System.StringComparer]::OrdinalIgnoreCase)
		}
		$videoLinks = [System.Collections.Generic.List[String]]::new()
		$processedCount = 0
		foreach ($episodeLink in $episodeLinks) {
			if ($script:histIdSet.Contains($episodeLink)) { $processedCount++ } else { $videoLinks.Add($episodeLink) }
		}
		return @($videoLinks.ToArray(), $processedCount)
	}
	$histFileData = @(Get-LatestHistoryCached)
	$histFileData = @(Remove-SubtitleRecheckTarget $histFileData)	# 字幕の再確認の対象は「ダウンロード済み」に含めない
	if ($histFileData.Count -eq 0) { $histVideoPages = @() } else { $histVideoPages = @($histFileData.videoPage.Replace('https://tver.jp/episodes/', '')) }
	# エピソードIDがすでにダウンロード履歴に存在する場合は検索結果から除外
	$histCompResult = @(Compare-Object -IncludeEqual $episodeLinks $histVideoPages)
	try { $processedCount = ($histCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($histCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	Remove-Variable -Name episodeLinks, histFileData, histVideoPages, histCompResult -ErrorAction SilentlyContinue
	return @($videoLinks, $processedCount)
}

#----------------------------------------------------------------------
# URLが既にダウンロードリストに存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-ListMatchCheck {
	<#
		.SYNOPSIS
			指定されたエピソードIDがダウンロードリストに存在するかチェックし、未登録のエピソードIDのみを返します。

		.DESCRIPTION
			指定されたエピソードIDのリストとダウンロードリストを比較し、まだ登録されていない
			エピソードIDのみを返します。また、既に登録済みのエピソードIDの数も返します。

		.PARAMETER resultLinks
			チェック対象のエピソードIDのリストを指定します。

		.OUTPUTS
			[String[]]
			未登録のエピソードIDの配列と、既に登録済みのエピソードIDの数を含む配列。

		.EXAMPLE
			$result = Invoke-ListMatchCheck -resultLinks @("epXXXXXXXX", "epYYYYYYYY")

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロードリストファイルを読み込み
			2. リストに存在するエピソードIDを抽出
			3. 指定されたエピソードIDのリストと比較
			4. 未登録のエピソードIDと登録済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	# エピソードIDで照合する(検索結果もダウンロードリストもエピソードID。#で始まるダウンロード対象外も登録済みとして扱う)
	$listVideoIDs = New-Object System.Collections.Generic.List[String]
	foreach ($item in $listFileData) { $listVideoIDs.Add($item.EpisodeID.Replace('#', '')) }
	# エピソードIDがすでにダウンロードリストに存在する場合は検索結果から除外
	$listCompResult = @(Compare-Object -IncludeEqual $resultLinks $listVideoIDs)
	try { $processedCount = ($listCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($listCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	Remove-Variable -Name resultLinks, listFileData, listVideoIDs, listFileLine, listCompResult -ErrorAction SilentlyContinue
	return @($videoLinks, $processedCount)
}

#----------------------------------------------------------------------
# URLが既にダウンロードリストまたはダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryAndListMatchCheck {
	<#
		.SYNOPSIS
			指定されたエピソードIDがダウンロードリストまたはダウンロード履歴に存在するかチェックし、未登録のエピソードIDのみを返します。

		.DESCRIPTION
			指定されたエピソードIDのリストとダウンロードリスト、ダウンロード履歴を比較し、
			まだ登録されていないエピソードIDのみを返します。また、既に登録済みのエピソードIDの数も返します。

		.PARAMETER resultLinks
			チェック対象のエピソードIDのリストを指定します。

		.OUTPUTS
			[String[]]
			未登録のエピソードIDの配列と、既に登録済みのエピソードIDの数を含む配列。

		.EXAMPLE
			$result = Invoke-HistoryAndListMatchCheck -resultLinks @("epXXXXXXXX", "epYYYYYYYY")

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロードリストファイルを読み込み
			2. ダウンロード履歴ファイルを読み込み
			3. 両方のリストをマージ
			4. 指定されたエピソードIDのリストと比較
			5. 未登録のエピソードIDと登録済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	$listVideoID = New-Object System.Collections.Generic.List[Object]
	foreach ($listFileLine in $listFileData) { $listVideoID.Add(@($listFileLine.EpisodeID.Replace('#', ''))) }
	# ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Get-LatestHistory)
	$histFileData = @(Remove-SubtitleRecheckTarget $histFileData)	# 字幕の再確認の対象は「ダウンロード済み」に含めない
	# 履歴が1件だけの場合に配列が文字列に展開されないよう、@()で包む
	$histVideoID = @(if ($histFileData.Count -eq 0) { @() } else { $histFileData.VideoPage.Replace('https://tver.jp/episodes/', '') })
	# ダウンロードリストとダウンロード履歴をマージ
	if ($histVideoID) { $listVideoID.AddRange($histVideoID) }
	# エピソードIDがすでにダウンロード履歴に存在する場合は検索結果から除外
	$listCompResult = Compare-Object -IncludeEqual $resultLinks $listVideoID
	try { $processedCount = ($listCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($listCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
}
#endregion ダウンロード対象判定処理

#region youtube-dl関連
#----------------------------------------------------------------------
# youtube-dlの共通引数の生成
#----------------------------------------------------------------------
function Get-YtdlCommonArgument {
	<#
		.SYNOPSIS
			TVer/TVer以外で共通のyoutube-dl引数を生成します。

		.PARAMETER BaseArgs
			呼び出し元ごとの基本引数を指定します。

		.PARAMETER SaveDir
			保存先ディレクトリ(home:付き)を指定します。

		.PARAMETER TempDir
			作業ディレクトリ(temp:付き)を指定します。

		.OUTPUTS
			[String[]]
			youtube-dlの引数の配列。
	#>
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()]$BaseArgs,
		[Parameter(Mandatory = $true)][String]$SaveDir,
		[Parameter(Mandatory = $true)][String]$TempDir
	)
	$ytdlCommonArgs = @(
		$BaseArgs
		('--concurrent-fragments {0}' -f $script:parallelDownloadNumPerFile)
		('--add-header {0}' -f $script:ytdlHttpHeader)
		('--paths "{0}"' -f $SaveDir)
		('--paths "{0}"' -f $TempDir)
		('--ffmpeg-location "{0}"' -f $script:ffmpegPath)
	)
	if ($script:proxyUrl) { $ytdlCommonArgs += ('--geo-verification-proxy {0}' -f $script:proxyUrl) }
	if (($script:ytdlRandomIp) -and (!$script:proxyUrl)) { $ytdlCommonArgs += ('--xff "{0}/32"' -f $script:jpIP) }
	if ($script:rateLimit -notin @(0, '')) {
		$rateLimit = [Int][Math]::Ceiling([Int]$script:rateLimit / [Int]$script:parallelDownloadNumPerFile / 8)
		$ytdlCommonArgs += ('--limit-rate {0}M' -f $rateLimit)
	}
	return $ytdlCommonArgs
}

#----------------------------------------------------------------------
# youtube-dlのmp4用(マージ・埋め込み)引数の生成
#----------------------------------------------------------------------
function Get-YtdlMp4Argument {
	<#
		.SYNOPSIS
			mp4出力時のマージ形式と、サムネイル・字幕・メタデータ埋め込みの引数を生成します。

		.OUTPUTS
			[String[]]
			youtube-dlの引数の配列。
	#>
	[OutputType([String[]])]
	Param ()
	$ytdlMp4Args = @('--merge-output-format mp4 --embed-chapters')
	if ($script:embedThumbnail) { $ytdlMp4Args += '--embed-thumbnail' }
	$ytdlMp4Args += @('subtitle', 'thumbnail', 'chapter', 'description').ForEach{ '--paths "{0}:{1}"' -f $_, $script:downloadWorkDir }
	if ($script:embedSubtitle) { $ytdlMp4Args += '--sub-langs all --convert-subs srt --embed-subs' }
	if ($script:embedMetatag) { $ytdlMp4Args += '--embed-metadata' }
	return $ytdlMp4Args
}

#----------------------------------------------------------------------
# youtube-dlプロセスの起動とタイムアウト監視(デバッグモード以外)
#----------------------------------------------------------------------
function Start-YtdlProcess {
	<#
		.SYNOPSIS
			youtube-dlプロセスを起動し、必要に応じてタイムアウト監視ジョブを開始します。

		.PARAMETER ArgumentString
			youtube-dlに渡す引数の文字列を指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][String]$ArgumentString)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$startProcessParams = @{
		FilePath     = $script:ytdlPath
		ArgumentList = $ArgumentString
		PassThru     = $true
	}
	if ($IsWindows -and ($script:windowShowStyle -ne 'Hidden')) { $startProcessParams.WindowStyle = $script:windowShowStyle }
	else {
		if ($IsWindows -and ($script:windowShowStyle -eq 'Hidden')) { $startProcessParams.WindowStyle = $script:windowShowStyle }
		$randomNum = -join (1..16 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
		$logFiles = @(
			@{ Path = $script:ytdlStdOutLogPath; Redirect = 'RedirectStandardOutput' },
			@{ Path = $script:ytdlStdErrLogPath; Redirect = 'RedirectStandardError' }
		)
		foreach ($logFile in $logFiles) {
			$logFilePath = $logFile.Path.Replace('.log', ('_{0}.log' -f $randomNum))
			try { New-Item -Path $logFilePath -ItemType File -Force -ErrorAction Stop | Out-Null }
			catch { Write-Warning ($script:msg.FfmpegErrFileInitializeFailed) ; return }
			$startProcessParams[$logFile.Redirect] = $logFilePath
		}
	}
	if ($script:ytdlTimeoutSec -ne 0) {
		try {
			# youtube-dl プロセスを起動
			$ytdlProcess = Start-Process @startProcessParams
			$processId = $ytdlProcess.Id
			$ytdlProcess.Handle | Out-Null
			Write-Debug ('youtube-dl Process ID: {0}' -f $processId)
			# タイムアウト監視ジョブを開始
			$monitorJob = Start-Job -ScriptBlock {
				Param ($processId, $timeoutSeconds, $timeoutMessage)
				$startTime = Get-Date
				while ((Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
					# 指定時間が経過したら強制終了
					if ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -ge $timeoutSeconds) {
						if ($IsWindows) { Start-Process -FilePath 'taskkill' -ArgumentList "/F /T /PID $processId" -NoNewWindow -Wait }
						else { Stop-Process -Id $processId -Force }
						Write-Warning $timeoutMessage
						break
					}
					Start-Sleep -Seconds 1
				}
				exit
			} -ArgumentList $processId, $script:ytdlTimeoutSec, ($script:msg.TerminateDueToTimeout -f 'youtube-dl', $script:ytdlTimeoutSec)
			# ジョブIDを変数に追加
			$script:jobList += $monitorJob.Id
		} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
	} else {
		try {
			$ytdlProcess = Start-Process @startProcessParams
			$processId = $ytdlProcess.Id
			$ytdlProcess.Handle | Out-Null
			Write-Debug ('youtube-dl Process ID: {0}' -f $processId)
		} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
	}
}

#----------------------------------------------------------------------
# youtube-dlプロセスの起動
#----------------------------------------------------------------------
function Invoke-Ytdl {
	<#
		.SYNOPSIS
			youtube-dlを使用してTVer番組をダウンロードします。

		.DESCRIPTION
			youtube-dlを使用してTVer番組をダウンロードし、指定された形式で保存します。
			プロキシ設定、レート制限、字幕埋め込みなどのオプションをサポートします。

		.PARAMETER videoInfo
			ダウンロードする番組の情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-Ytdl -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード用の一時ディレクトリと保存ディレクトリを設定
			2. youtube-dlの引数を構築（プロキシ、レート制限、字幕設定など）
			3. 既存ファイルの削除とリネーム用のコマンドを設定
			4. youtube-dlプロセスを起動し、タイムアウト監視を開始
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Invoke-StatisticsCheck -Operation 'download'
	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$saveDir = ('home:{0}' -f $videoInfo.fileDir)

	$ytdlArgs = @(Get-YtdlCommonArgument -BaseArgs $script:ytdlBaseArgs -SaveDir $saveDir -TempDir $tmpDir)
	if ($script:videoContainerFormat -eq 'mp4') { $ytdlArgs += Get-YtdlMp4Argument }

	$pwshRemoveIfExists = 'Remove-Item -LiteralPath ''{0}'' -Force -ErrorAction SilentlyContinue' -f $videoInfo.filePath.Replace("'", "''")
	$ytdlTempOutFile = ('{0}/{1}.{2}' -f $videoInfo.fileDir.Replace("'", "''"), $videoInfo.episodeID, $script:videoContainerFormat)
	$pwshRenameFile = 'Rename-Item -LiteralPath ''{0}'' -NewName ''{1}'' -Force -ErrorAction SilentlyContinue' -f $ytdlTempOutFile, $videoInfo.fileName.Replace("'", "''")
	$ytdlExecArg = 'pwsh -Command \"{0} ; {1}\"' -f $pwshRemoveIfExists, $pwshRenameFile
	$ytdlArgs += ('--exec "after_video:{0}"' -f $ytdlExecArg)
	$ytdlArgs += $script:ytdlOption, $videoInfo.episodePageURL, ('--output "{0}.{1}"' -f $videoInfo.episodeID, $script:videoContainerFormat)

	$ytdlArgsString = $ytdlArgs -join ' '
	Write-Debug ($script:msg.ExecCommand -f 'youtube-dl', $script:ytdlPath, $ytdlArgsString)

	if ((Test-Path Variable:Script:debugMode) -and $script:debugMode) {
		$startProcessParams = @{
			FilePath               = $script:ytdlPath
			ArgumentList           = $ytdlArgsString
			PassThru               = $true
			Wait                   = $true
			NoNewWindow            = $true
			RedirectStandardOutput = $script:ytdlStdOutLogPath
			RedirectStandardError  = $script:ytdlStdErrLogPath
		}
		Write-Output 'youtube-dlの実行中...'
		$ytdlProcess = $null ; $stdOutContent = $null ; $stdErrContent = $null	# * 起動に失敗したときもfinallyで参照できるようにする
		try {
			$ytdlProcess = Start-Process @startProcessParams
			$ytdlProcess.Handle | Out-Null
			if ($IsWindows) {
				$stdOutContent = [System.Text.Encoding]::GetEncoding(932).GetString([System.IO.File]::ReadAllBytes($script:ytdlStdOutLogPath))
				$stdErrContent = [System.Text.Encoding]::GetEncoding(932).GetString([System.IO.File]::ReadAllBytes($script:ytdlStdErrLogPath))
			} else {
				$stdOutContent = Get-Content -Path $script:ytdlStdOutLogPath -Encoding UTF8
				$stdErrContent = Get-Content -Path $script:ytdlStdErrLogPath -Encoding UTF8
			}
		} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') }
		finally {
			Write-Output $stdOutContent
			Write-Output $stdErrContent
			if ($ytdlProcess) { Write-Output ('Exit Code: {0}' -f $ytdlProcess.ExitCode) }
		}
	} else {
		Start-YtdlProcess -ArgumentString $ytdlArgsString
	}

	Remove-Variable -Name tmpDir, saveDir, ytdlArgs, ytdlArgsString, ytdlExecArg, pwshRemoveIfExists, pwshRenameFile, startProcessParams, ytdlProcess -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlプロセスの起動 (TVer以外のサイトへの対応)
#----------------------------------------------------------------------
function Invoke-NonTverYtdl {
	<#
		.SYNOPSIS
			youtube-dlを使用してTVer以外のサイトから動画をダウンロードします。

		.DESCRIPTION
			youtube-dlを使用してTVer以外のサイトから動画をダウンロードし、
			指定された形式で保存します。プロキシ設定やレート制限などの
			オプションをサポートします。

		.PARAMETER videoPageURL
			ダウンロードする動画のページURLを指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-NonTverYtdl -URL 'https://example.com/video'

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード用の一時ディレクトリと保存ディレクトリを設定
			2. youtube-dlの引数を構築（プロキシ、レート制限など）
			3. 既存ファイルの削除とリネーム用のコマンドを設定
			4. youtube-dlプロセスを起動
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][Alias('URL')][String]$videoPageURL)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Invoke-StatisticsCheck -Operation 'nontver'
	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$saveDir = ('home:{0}' -f $script:downloadBaseDir)
	$saveFile = ('{0}' -f $script:ytdlNonTVerFileName)

	$ytdlArgs = @(Get-YtdlCommonArgument -BaseArgs $script:nonTVerYtdlBaseArgs -SaveDir $saveDir -TempDir $tmpDir)
	$ytdlArgs += Get-YtdlMp4Argument
	$ytdlArgs += $script:ytdlOption, "$videoPageURL", "--output `"$saveFile`""
	$ytdlArgsString = $ytdlArgs -join ' '
	Write-Debug ($script:msg.ExecCommand -f 'youtube-dl', $script:ytdlPath, $ytdlArgsString)
	Start-YtdlProcess -ArgumentString $ytdlArgsString
	Remove-Variable -Name videoPageURL, tmpDir, saveDir, saveFile, ytdlArgs, ytdlArgsString -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 実行ファイルのパスごとのプロセス数を取得
#----------------------------------------------------------------------
function Get-ProcessCountByPath {
	<#
		.SYNOPSIS
			指定した実行ファイルから起動されているプロセスの数を取得します。

		.DESCRIPTION
			プロセス名ではなく実行ファイルのパスで絞り込んでプロセス数を数えます。
			TVerRec以外が起動している同名のプロセス(別途起動したyt-dlpやffmpegなど)を数えないために使用します。
			Windows: Get-Processの結果のPathが一致するものを数えます。
			Linux: /proc/<PID>/cmdlineのコマンドラインを参照します。(psコマンドが無い環境でも動作)
			macOS: ps -axo args= のコマンドラインを参照します。
			コマンドラインの先頭が実行ファイルのパスであるものだけを数え、
			他のプロセスの引数にパスが含まれているだけのものは数えません。

		.PARAMETER Path
			実行ファイルのパスを指定します。

		.PARAMETER AllowInterpreter
			指定すると、`python3 <Path>`のようにインタープリタ経由で起動されたプロセスも数えます。
			yt-dlpのようにPythonスクリプトとして実行される場合に使用します。

		.OUTPUTS
			[Int]
			該当するプロセスの数。取得できない場合は0。
	#>
	[OutputType([Int])]
	Param (
		[Parameter(Mandatory = $true)][String]$Path,
		[Switch]$AllowInterpreter
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		$fullPath = [IO.Path]::GetFullPath($Path)
		$processName = [IO.Path]::GetFileNameWithoutExtension($fullPath)
		if ($IsWindows) {
			return @(Get-Process -ErrorAction Ignore -Name $processName).Where({ $_.Path -and [String]::Equals($_.Path, $fullPath, [StringComparison]::OrdinalIgnoreCase) }).Count	# * @()で囲まないとプロセスが0/1個のときStrictModeで例外になる
		}
		if ($IsLinux) {
			$cmdLines = foreach ($procDir in [IO.Directory]::GetDirectories('/proc')) {
				if ([IO.Path]::GetFileName($procDir) -notmatch '^\d+$') { continue }
				try { [IO.File]::ReadAllText((Join-Path $procDir 'cmdline')).Replace([Char]0, ' ').TrimEnd() } catch { continue }	# * 取得中に終了したプロセスは無視する
			}
		} elseif ($IsMacOS) {
			$cmdLines = & ps -axo 'args=' 2>$null
		} else {
			Write-Debug ($script:msg.GetDownloadProcNumFailed)
			return 0
		}
		$candidates = @($Path, $fullPath | Select-Object -Unique)
		$count = 0
		foreach ($cmdLine in @($cmdLines)) {
			if (!$cmdLine) { continue }
			foreach ($candidate in $candidates) {
				if ($cmdLine -ceq $candidate -or $cmdLine.StartsWith($candidate + ' ', [StringComparison]::Ordinal)) { $count++ ; break }
				if ($AllowInterpreter -and $cmdLine -match ('^\S*python\S*\s+{0}(\s|$)' -f [RegEx]::Escape($candidate))) { $count++ ; break }
			}
		}
		return $count
	} catch { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
}

#----------------------------------------------------------------------
# youtube-dlのプロセスカウントを取得
#----------------------------------------------------------------------
function Get-YtdlProcessCount {
	<#
		.SYNOPSIS
			現在実行中のyoutube-dlプロセスの数を取得します。

		.DESCRIPTION
			現在実行中のyoutube-dlプロセスの数を取得します。
			TVerRecが使用する実行ファイル(`$script:ytdlPath`)から起動されたプロセスだけを数えます。

		.OUTPUTS
			[Int]
			実行中のyoutube-dlプロセスの数。

		.NOTES
			この関数は以下の処理を行います：
			1. Get-ProcessCountByPathで実行ファイルのパスが一致するプロセスをカウント
			2. Windows: プロセスの数を2で割って返す
			3. Linux/macOS: プロセスの数をそのまま返す
	#>
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		$count = Get-ProcessCountByPath -Path $script:ytdlPath -AllowInterpreter
		if ($IsWindows) { return [Int][Math]::Round($count / 2, [MidpointRounding]::AwayFromZero) }	# * Windowsでは1回の実行で2プロセス(親子)になる
		return $count
	} catch { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
}

#----------------------------------------------------------------------
# ffmpegプロセス数の取得
#----------------------------------------------------------------------
function Get-FfmpegProcessCount {
	<#
		.SYNOPSIS
			現在実行中のffmpegプロセスの数を取得します。

		.DESCRIPTION
			現在実行中のffmpegプロセスの数を取得します。
			TVerRecが使用する実行ファイル(`$script:ffmpegPath`)から起動されたプロセスだけを数えます。

		.OUTPUTS
			[Int]
			実行中のffmpegプロセスの数。

		.NOTES
			この関数は以下の処理を行います：
			1. Get-ProcessCountByPathで実行ファイルのパスが一致するプロセスをカウントして返す
	#>
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try { return Get-ProcessCountByPath -Path $script:ffmpegPath }
	catch { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
}

#----------------------------------------------------------------------
# youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function Wait-DownloadCompletion () {
	<#
		.SYNOPSIS
			youtube-dlプロセスが終了するまで待機します。

		.DESCRIPTION
			youtube-dlプロセスが終了するまで待機します。
			1分ごとにプロセス数を確認し、すべてのプロセスが終了するまで待機します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在のyoutube-dlプロセス数を取得
			2. プロセス数が0になるまで1分ごとに確認
			3. プロセス数をコンソールに表示
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ytdlCount = [Int](Get-YtdlProcessCount)
	<# * ffmpegでのダウンロード機能を有効化時に必要
		$ffmpegCount = [Int](Get-FfmpegProcessCount)
		while (($ytdlCount + $ffmpegCount) -ne 0) {
	#>
	while ($ytdlCount -ne 0) {
		# Write-Information ($script:msg.NumDownloadProc -f (Get-Date), ($ytdlCount + $ffmpegCount))
		Write-Information ($script:msg.NumDownloadProc -f (Get-Date), $ytdlCount)
		Start-Sleep -Seconds 60
		$ytdlCount = [Int](Get-YtdlProcessCount)
		<# * ffmpegでのダウンロード機能を有効化時に必要
			# $ffmpegCount = [Int](Get-FfmpegProcessCount)
		#>
	}
	Remove-Variable -Name ytdlCount -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function Wait-YtdlProcess {
	<#
		.SYNOPSIS
			youtube-dlプロセスの数を確認し、指定された数以下になるまで待機します。

		.DESCRIPTION
			youtube-dlプロセスの数を監視し、指定された並列ダウンロード数以下になるまで
			待機します。定期的にプロセス数を表示しながら、10秒間隔でチェックします。

		.PARAMETER parallelDownloadFileNum
			並列ダウンロードの最大数を指定します。

		.EXAMPLE
			Wait-YtdlProcess -parallelDownloadFileNum 3

		.NOTES
			この関数は以下の処理を行います：
			1. youtube-dlプロセスの数を取得
			2. 指定された数以下になるまで待機
			3. プロセス数を表示
			4. 10秒間隔でチェックを繰り返す
	#>
	[OutputType([Void])]
	Param ([Int32]$parallelDownloadFileNum)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# youtube-dlのプロセスが設定値を超えたら一時待機
	while ($true) {
		$ytdlCount = [Int](Get-YtdlProcessCount)
		# $ffmpegCount = [Int](Get-FfmpegProcessCount)
		# if (([Int]$ytdlCount + [Int]$ffmpegCount) -lt [Int]$parallelDownloadFileNum ) { break }
		if ([Int]$ytdlCount -lt [Int]$parallelDownloadFileNum ) { break }
		Write-Output ($script:msg.WaitingNumDownloadProc -f $parallelDownloadFileNum)
		# Write-Information ($script:msg.NumDownloadProc -f (Get-Date), ($ytdlCount + $ffmpegCount))
		Write-Information ($script:msg.NumDownloadProc -f (Get-Date), $ytdlCount)
		Start-Sleep -Seconds 10
	}
	Remove-Variable -Name parallelDownloadFileNum, ytdlCount -ErrorAction SilentlyContinue
}
#endregion youtube-dl関連

#region ダウンロード関連
#----------------------------------------------------------------------
# 「《」と「》」、「【」と「】」で挟まれた文字を除去
#----------------------------------------------------------------------
function Remove-SpecialNote {
	<#
		.SYNOPSIS
			特定の特殊文字で囲まれた文字列を削除します。

		.DESCRIPTION
			入力テキストから特定の特殊文字（《》、【】）で囲まれた文字列を削除します。
			ただし、文字列の長さが一定の閾値（10文字）を超える場合のみ削除を行います。

		.PARAMETER text
			処理対象のテキストを指定します。

		.OUTPUTS
			[String]
			特殊文字で囲まれた文字列が削除されたテキスト。

		.EXAMPLE
			$cleanedText = Remove-SpecialNote -text "これは【テスト】です"

		.NOTES
			この関数は以下の処理を行います：
			1. 《》と【】の各ペアの位置を検出
			2. 文字列の長さが閾値（10文字）を超える場合のみ削除
			3. 削除後、余分な空白を除去
			4. 処理後のテキストを返す
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param ([Parameter(Mandatory = $false)][String]$text = '')
	begin {
		Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
		# 特殊文字の位置を取得し、長さを計算
		$length1 = [Math]::Max(0, $text.IndexOf('》') - $text.IndexOf('《'))
		$length2 = [Math]::Max(0, $text.IndexOf('】') - $text.IndexOf('【'))
	}
	process {
		if ($PSCmdlet.ShouldProcess($text, 'Trim characters')) {
			# 10文字以上あれば特殊文字とその間を削除
			if (($length1 -gt 10) -or ($length2 -gt 10)) { $text = (($text -replace '《.*?》|【.*?】', '') -replace '\s+', ' ').Trim() }
		}
	}
	end {
		return $text
	}
}

#----------------------------------------------------------------------
# TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function Invoke-VideoDownload {
	<#
		.SYNOPSIS
			TVer番組のダウンロードを実行するメイン処理です。

		.DESCRIPTION
			指定されたURLからTVer番組をダウンロードし、必要な情報を記録します。
			ダウンロード履歴とダウンロードリストの両方を更新します。

		.PARAMETER keyword
			検索キーワードを参照で指定します。

		.PARAMETER videoLink
			ダウンロードするTVer番組のURLを参照で指定します。

		.PARAMETER force
			強制的にダウンロードを実行するかどうかを指定します。
			デフォルトは$falseです。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-VideoDownload -keyword $keyword -episodeID $episodeID -force $true

		.NOTES
			この関数は以下の処理を行います：
			1. 指定されたURLから番組情報を取得
			2. ダウンロード履歴とダウンロードリストを更新
			3. youtube-dlを使用して番組をダウンロード
			4. ダウンロード結果を記録

			状態の振り分け設定：
			- 履歴ファイルに存在する場合：
			- ID変更時のダウンロード設定あり：再ダウンロード
			- ID変更時のダウンロード設定なし：スキップ
			- 履歴ファイルに存在しない場合：
			- ファイルが存在する：検証のみ
			- ファイルが存在しない：
				- ダウンロード対象外リストに存在：無視
				- ダウンロード対象外リストに存在しない：ダウンロード
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$keyword,
		[Parameter(Mandatory = $true)][String]$episodeID,
		[Parameter(Mandatory = $false)][Boolean]$force = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$newVideo = $null
	$skipDownload = $false
	# TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ($script:msg.EpisodeInfoRetrievalFailed) ; return }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	# ダウンロードファイル名を生成
	Format-VideoFileInfo ([Ref]$videoInfo)
	# 番組タイトルが取得できなかった場合はスキップ次の番組へ
	if (($videoInfo.fileName -eq '.mp4') -or ($videoInfo.fileName -eq '.ts')) { Write-Warning ($script:msg.EpisodeTitleRetrievalFailed) ; return }
	# 番組情報のコンソール出力
	Show-VideoInfo ([Ref]$videoInfo)
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo ([Ref]$videoInfo) }
	# 字幕の有無の記録と、字幕が追加された番組の再ダウンロード判定
	$subtitleTracking = Test-SubtitleTrackingEnabled
	$subtitleStatus = $null
	$subtitleRecheck = $false
	$histFileData = $null
	if (!$force -and $subtitleTracking) {
		$histFileData = @(Get-LatestHistoryCached)
		$subtitleHists = @($histFileData.Where({ $_ -and $_.PSObject.Properties['subtitle'] }))
		$sameEpisodeHists = @($subtitleHists.Where({ $_.videoPage -eq $videoInfo.episodePageURL }))
		if (($sameEpisodeHists.Count -ne 0) -and ($sameEpisodeHists[0].subtitle -eq '0')) {
			# 字幕なしで保存済みの番組	→字幕が追加されたか確認する
			foreach ($ignoreTitle in @(Get-IgnoreListCached)) {
				if ($ignoreTitle -and (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard)) { return }
			}
			Write-Output ($script:msg.SubtitleRecheck)
			$subtitleStatus = Get-VideoSubtitleStatus -EpisodePageURL $videoInfo.episodePageURL -IsSubtitle $videoInfo.isSubtitle
			if ($subtitleStatus -ne '1') { Write-Output ($script:msg.SubtitleNotAdded) ; return }
			Write-Output ($script:msg.SubtitleAdded)
			$subtitleRecheck = $true
		}
	}
	if ($force -or $subtitleRecheck) {
		$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
		$newVideo = Format-HistoryRecord $videoInfo
	} else {
		<# * 状態の振り分け設定
			* ここまで来ているということはEpisodeIDでは履歴とマッチしなかったということ
			* 考えられる原因は履歴ファイルがクリアされてしまっていること、または、EpisodeIDが変更になったこと
				* 履歴ファイルに存在する	→番組IDが変更になったあるいは、番組名の重複
					* ID変更時のダウンロード設定あり
						検証済	→再ダウンロード
						検証中	→元々の番組IDとしてはそのうち検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
						未検証	→元々の番組IDとしては次回検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
					* ID変更時のダウンロード設定なし
						検証済	→元々の番組IDとしては問題ないのでSKIP
						検証中	→元々の番組IDとしてはそのうち検証されるのでSKIP
						未検証	→元々の番組IDとしては次回検証されるのでSKIP
				* 履歴ファイルに存在しない
					ファイルが存在する	→検証だけする
					ファイルが存在しない
						ダウンロード対象外リストに存在する	→無視
						ダウンロード対象外リストに存在しない	→ダウンロード
		#>
		#ダウンロード履歴ファイルのデータを読み込み(字幕の判定で読み込み済みの場合は再利用)
		if ($null -eq $histFileData) { $histFileData = @(Get-LatestHistoryCached) }
		if ($videoInfo.fileRelPath) { $histMatch = @($histFileData.Where({ $_.videoPath -eq $videoInfo.fileRelPath })) }
		else { Write-Warning ($script:msg.FileNameRetrievalFailed) ; return }

		if ($script:downloadWhenEpisodeIdChanged) {
			if (($histMatch.Count -ne 0) -or (Test-Path $videoInfo.filePath)) {
				$ignoreTitles = @(Get-IgnoreListCached)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard) {
						# エピソードIDが変更になったがダウンロード対象外リストと合致	→無視する
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
						$videoInfo.fileName = '-- IGNORED --'
						$videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
						break
					}
				}
				# エピソードIDが変更になった	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeIdChanged)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord $videoInfo
				}
			} else {
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストと合致	→無視する
				$ignoreTitles = @(Get-IgnoreListCached)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard) {
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
						$videoInfo.fileName = '-- IGNORED --'
						$videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
						break
					}
				}
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストとも合致しない	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeAdded)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord $videoInfo
				}
			}
		} else {
			if ($histMatch.Count -ne 0) {
				# 履歴ファイルに存在する	→スキップして次のファイルに
				Write-Warning ($script:msg.DownloadHistExists)
				$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '1' ; $videoInfo.fileName = '-- SKIPPED --'
				$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
			} elseif (Test-Path $videoInfo.filePath) {
				# 履歴ファイルに存在しないが、実ファイルが存在する	→検証だけする
				Write-Warning ($script:msg.DownloadFileExists)
				$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- SKIPPED --'
				$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
			} else {
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストと合致	→無視する
				$ignoreTitles = @(Get-IgnoreListCached)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard) {
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- IGNORED --' ; $videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
						break
					}
				}
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストとも合致しない	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeAdded)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord $videoInfo
				}
			}
		}
	}

	# ダウンロードする番組の字幕の有無を記録
	if ($subtitleTracking -and !$skipDownload -and $newVideo) {
		if ($null -eq $subtitleStatus) { $subtitleStatus = Get-VideoSubtitleStatus -EpisodePageURL $videoInfo.episodePageURL -IsSubtitle $videoInfo.isSubtitle }
		$newVideo.subtitle = $subtitleStatus
	}
	# ダウンロード履歴CSV書き出し
	Wait-FileLock $script:histLockFilePath
	try {
		$newVideo | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1
		Write-Debug ($script:msg.HistWritten)
		Add-LatestHistoryCache $newVideo
	} catch { Write-Warning ($script:msg.HistUpdateFailed) ; return }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	# スキップ対象やダウンロード対象外は飛ばして次のファイルへ
	if ($skipDownload) { return }
	# 番組ディレクトリがなければ作成
	if ($script:sortVideoBySeries -and !(Test-Path $videoInfo.fileDir -PathType Container)) {
		try { New-Item -ItemType Directory -Path $videoInfo.fileDir -Force -ErrorAction Stop | Out-Null }
		catch { Write-Warning ($script:msg.CreateEpisodeDirFailed) ; return }
	}
	# youtube-dl起動
	if ($script:ytdlRandomIp -and $script:proxyUrl) {
		Write-Output ($script:msg.MediumBoldBorder)
		Write-Output ($script:msg.NotifyYtdlOptions1)
		Write-Output ($script:msg.NotifyYtdlOptions2)
		Write-Output ($script:msg.NotifyYtdlOptions3)
		Write-Output ($script:msg.MediumBoldBorder)
	}
	try { Invoke-Ytdl ([Ref]$videoInfo) }
	catch { Write-Warning ($script:msg.InvokeYtdlFailed) }
	# 1秒待機
	Start-Sleep -Seconds 1
	Remove-Variable -Name keyword, videoLink, force, newVideo, skipDownload, episodeID, histFileData, histMatch, ignoreTitles, ignoreTitle, subtitleTracking, subtitleStatus, subtitleRecheck, subtitleHists, sameEpisodeHists -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 保存ファイル名を設定
#----------------------------------------------------------------------
function Format-VideoFileInfo {
	<#
		.SYNOPSIS
			ビデオファイルの保存情報を設定します。

		.DESCRIPTION
			ビデオ情報からファイル名、ディレクトリパス、相対パスなどの
			保存に必要な情報を生成します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Format-VideoFileInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. シリーズ名、シーズン名、エピソード番号などからファイル名を生成
			2. メディア名やシリーズ名に基づいてディレクトリパスを生成
			3. ファイル名の長さ制限を適用
			4. ビデオ情報オブジェクトに保存情報を追加
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$videoName = ''
	# ファイル名を生成
	if ($script:addSeriesName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seriesName) }
	if ($script:addSeasonName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seasonName) }
	if ($videoName.Trim() -ne $videoInfo.episodeName.Trim() ) {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate.replace('/', '-')) }	#きょうのわんこなど「2025/3/17週放送」のようなパターン
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
		$videoName = ('{0}{1}' -f $videoName, $videoInfo.episodeName)
	} else {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate.replace('/', '-')) }	#きょうのわんこなど「2025/3/17週放送」のようなパターン
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
	}
	# ファイル名にできない文字列を除去
	$videoName = ((Get-FileNameWoInvalidChar (Remove-SpecialCharacter $videoName)) -replace '\s+', ' ').Trim()
	# SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング。安全目の上限値としており、限界値は攻めていない
	$fileNameLimit = $script:fileNameLengthMax - 30
	if ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) {
		while ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) { $videoName = $videoName.Substring(0, $videoName.Length - 1) }
		$videoName = ('{0}……' -f $videoName)
	}
	$videoName = ('{0}.{1}' -f $videoName, $script:videoContainerFormat)
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileName' -Value $videoName

	# フォルダ名を生成
	$videoFileDir = @()
	if ($script:sortVideoByMedia) { $videoFileDir += Get-FileNameWoInvalidChar (Remove-SpecialCharacter ($videoInfo.mediaName).Trim(' ', '.')) }
	if ($script:sortVideoBySeries) {
		$seriesDirName = Get-FileNameWoInvalidChar (Remove-SpecialCharacter ('{0} {1}' -f $videoInfo.seriesName, $videoInfo.seasonName ).Trim(' ', '.'))
		# フォルダ名もSMBの255バイト制限があるため、長い場合はトリミング(末尾の空白・ピリオドはWindowsで使えないので除去)
		$dirNameLimit = $script:fileNameLengthMax - 30
		if ([System.Text.Encoding]::UTF8.GetByteCount($seriesDirName) -gt $dirNameLimit) {
			while ([System.Text.Encoding]::UTF8.GetByteCount($seriesDirName) -gt $dirNameLimit) { $seriesDirName = $seriesDirName.Substring(0, $seriesDirName.Length - 1) }
			$seriesDirName = ('{0}……' -f $seriesDirName.Trim(' ', '.'))
		}
		$videoFileDir += $seriesDirName
	}
	if ($videoFileDir) { $videoFileDir = Join-Path $script:downloadBaseDir @videoFileDir }		# 3コ以上行けるので配列のまま渡す
	else { $videoFileDir = $script:downloadBaseDir }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileDir' -Value $videoFileDir.Replace('\', '/')

	$videoFilePath = Join-Path $videoFileDir $videoInfo.fileName
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'filePath' -Value $videoFilePath.Replace('\', '/')
	$videoFileRelPath = $videoFilePath.Replace($script:downloadBaseDir, '')
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileRelPath' -Value $videoFileRelPath.Replace('\', '/').TrimStart('/')

	Remove-Variable -Name videoName, fileNameLimit, seriesDirName, dirNameLimit, videoFileDir, videoFilePath, videoFileRelPath -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 番組情報表示
#----------------------------------------------------------------------
function Show-VideoInfo {
	<#
		.SYNOPSIS
			番組の基本情報をコンソールに表示します。

		.DESCRIPTION
			指定されたビデオ情報から、番組名、放送日、メディア名、終了日時、
			エピソード詳細などの情報をコンソールに表示します。

		.PARAMETER videoInfo
			表示する番組情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Show-VideoInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の情報を表示します：
			1. エピソード名（ファイル名から拡張子を除いたもの）
			2. 放送日
			3. メディア名
			4. 終了日時
			5. エピソード詳細（説明文）
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Output ($script:msg.EpisodeName -f $videoInfo.fileName.Replace($script:videoContainerFormat, ''))
	Write-Output ($script:msg.BroadcastDate -f $videoInfo.broadcastDate)
	Write-Output ($script:msg.MediaName -f $videoInfo.mediaName)
	Write-Output ($script:msg.EndDate -f $videoInfo.endTime)
	<#
		Write-Output ($script:msg.IsBrightcove -f $videoInfo.isBrightcove)
		Write-Output ($script:msg.IsStreaks -f $videoInfo.isStreaks)
	#>
	Write-Output ($script:msg.EpisodeDetail -f $videoInfo.descriptionText)
}

#----------------------------------------------------------------------
# 番組情報デバッグ表示
#----------------------------------------------------------------------
function Show-VideoDebugInfo {
	<#
		.SYNOPSIS
			番組のデバッグ情報をコンソールに表示します。

		.DESCRIPTION
			指定されたビデオ情報から、デバッグ用の情報（エピソードページURL）を
			コンソールに表示します。

		.PARAMETER videoInfo
			表示する番組情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Show-VideoDebugInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の情報を表示します：
			1. エピソードページのURL
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Debug $videoInfo.episodePageURL
}

#----------------------------------------------------------------------
# ダウンロードスケジュールに合わせたスケジュール制御
#----------------------------------------------------------------------
function Suspend-Process () {
	<#
		.SYNOPSIS
			ダウンロードスケジュールに基づいてプロセスを一時停止します。

		.DESCRIPTION
			ダウンロードスケジュールに基づいてプロセスを一時停止します。
			指定された曜日と時間にダウンロードを停止し、次の正時まで待機します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在の日付と時刻を取得
			2. スケジュールに基づいて停止時間を確認
			3. 停止時間の場合は次の正時まで待機
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($script:scheduleStop) {
		Write-Debug ('Checking execution schedule')
		while ($true) {
			$currentDateTime = Get-Date
			$currentDay = ($currentDateTime).DayOfWeek.ToString().Substring(0, 3)
			$currentHour = ($currentDateTime).Hour
			if ($script:stopSchedule.ContainsKey($currentDay)) {
				if ($script:stopSchedule[$currentDay] -contains $currentHour) {
					Write-Output ($script:msg.WaitSuspendTime -f ($currentDateTime))
					# 次の正時までの時間差を計算
					$timeDifference = $currentDateTime.Date.AddHours($currentDateTime.Hour + 1) - $currentDateTime
					Start-Sleep -Seconds ([math]::Ceiling($timeDifference.TotalSeconds))
				} else { break }
			} else { break }
		}
	}
	Remove-Variable -Name currentDateTime, currentDay, currentHour, timeDifference -ErrorAction SilentlyContinue
}
#endregion ダウンロード関連


#region ダウンロード失敗ファイル削除関連
#----------------------------------------------------------------------
# 移動に失敗したファイルを削除(作業フォルダ)
#----------------------------------------------------------------------
<#
.SYNOPSIS
    作業フォルダ内の移動に失敗したファイルを削除します。

.DESCRIPTION
    作業フォルダ内の移動に失敗したファイルを削除します。
    ファイル名が特定のパターンに一致するファイルを削除します。

.OUTPUTS
    [Void]
    この関数は値を返しません。

.NOTES
    この関数は以下の処理を行います：
    1. 作業フォルダ内のファイルを検索
    2. ファイル名が特定のパターンに一致するファイルを削除
#>
function Remove-UnMovedTempFile {
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param ()
	begin {
		Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
		$targetFiles = (Get-ChildItem -Path $script:downloadWorkDir -File).Where({ $_.Name -match '^ep[a-z0-9]{8}\..*(\.)*(mp4|ts)$' })
	}
	process {
		foreach ($file in $targetFiles) {
			try {
				if ($PSCmdlet.ShouldProcess($file, 'Remove file')) {
					Write-Information ($script:msg.DeleteFile -f $file)
					Remove-Item -LiteralPath $file -Force -ErrorAction Stop
				}
			} catch { Write-Warning ('{0} : {1}' -f $file, $script:msg.FileCannotBeDeleted) }
		}
	}
}

#----------------------------------------------------------------------
# リネームに失敗したファイルを削除(ダウンロード先フォルダ)
#----------------------------------------------------------------------
function Remove-UnRenamedTempFile {
	<#
		.SYNOPSIS
			ダウンロード先フォルダ内のリネームに失敗したファイルを削除します。

		.DESCRIPTION
			ダウンロード先フォルダ内のリネームに失敗したファイルを削除します。
			ファイル名が特定のパターンに一致するファイルを削除します。
			`$script:deleteUnrenamedFile`が`$false`の場合は、削除せずに、残したファイルを警告として表示します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード先フォルダ内のファイルを検索
			2. 削除しない設定の場合は、見つけたファイルを警告として表示して終了
			3. ファイル名が特定のパターンに一致するファイルを削除
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param ()
	begin {
		Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
		if ($IsWindows) {
			$forCmd = "for %E in (mp4 ts) do for /r `"$script:downloadBaseDir`" %F in (ep*.%E) do @echo %F"
			$targetFiles = @(& cmd /c $forCmd).Where({ ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') })
		} else {
			$findCmd = "find `"$script:downloadBaseDir`" -type f -name 'ep*.mp4' -or -type f -name 'ep*.ts'"
			$targetFiles = @(& sh -c $findCmd).Where({ ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') })
		}
	}
	process {
		# 削除しない設定の場合は、削除せずに残したファイルを警告として表示する
		if (!$script:deleteUnrenamedFile) {
			foreach ($file in $targetFiles) { Write-Warning ($script:msg.UnrenamedFileKept -f $file) }
			return
		}
		Write-Output ($script:msg.DeleteFilesFailedToRename)
		foreach ($file in $targetFiles) {
			try {
				if ($PSCmdlet.ShouldProcess($file, 'Remove file')) {
					Write-Information ($script:msg.DeleteFile -f $file)
					Remove-Item -LiteralPath $file -Force -ErrorAction Stop
				}
			} catch { Write-Warning ('{0} : {1}' -f $file, $script:msg.FileCannotBeDeleted) }
		}
	}
}
#endregion ダウンロード失敗ファイル削除関連


#region 整合性チェック関連処理
#----------------------------------------------------------------------
# ダウンロードプロセスの待機
#----------------------------------------------------------------------
function Wait-DownloadProcess {
	<#
		.SYNOPSIS
			ダウンロードプロセスが完了するまで待機します。

		.DESCRIPTION
			現在実行中のダウンロードプロセス（yt-dlpとffmpeg）が
			すべて完了するまで待機します。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在のダウンロードプロセス数を取得
			2. プロセス数が0になるまで60秒ごとにチェック
			3. プロセス数が0になったら待機を終了
	#>
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ytdlCount = [Int](Get-YtdlProcessCount)
	# ffmpegでのダウンロード機能を有効化時に必要
	$ffmpegCount = [Int](Get-FfmpegProcessCount)
	while (($ytdlCount + $ffmpegCount) -ne 0) {
		Write-Output ($script:msg.WaitingDownloadProcess -f ($ytdlCount + $ffmpegCount))
		Start-Sleep -Seconds 60
		$ytdlCount = [Int](Get-YtdlProcessCount)
		# ffmpegでのダウンロード機能を有効化時に必要
		$ffmpegCount = [Int](Get-FfmpegProcessCount)
	}
}

#----------------------------------------------------------------------
# ffmpeg/ffprobeプロセスの起動
#----------------------------------------------------------------------
function Invoke-FFmpegProcess {
	<#
		.SYNOPSIS
			ffmpegまたはffprobeプロセスを起動します。

		.DESCRIPTION
			ffmpegまたはffprobeプロセスを起動し、指定された引数で実行します。
			エラーログを記録し、プロセスの終了コードを返します。

		.PARAMETER filePath
			実行するffmpegまたはffprobeのパスを指定します。

		.PARAMETER ffmpegArgs
			ffmpegまたはffprobeに渡す引数を指定します。

		.PARAMETER execName
			実行するコマンドの名前（'ffmpeg'または'ffprobe'）を指定します。

		.OUTPUTS
			[Int]
			プロセスの終了コードを返します。

		.EXAMPLE
			Invoke-FFmpegProcess -filePath 'ffmpeg' -ffmpegArgs '-i input.mp4 output.mp4' -execName 'ffmpeg'

		.NOTES
			この関数は以下の処理を行います：
			1. プロセス起動用のパラメータを設定
			2. エラーログの出力先を設定
			3. プロセスを起動し、終了を待機
			4. プロセスの終了コードを返す
	#>
	param (
		[String]$filePath,
		[String]$ffmpegArgs,
		[String]$execName
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$commonParams = @{
		FilePath              = $filePath
		ArgumentList          = $ffmpegArgs
		PassThru              = $true
		RedirectStandardError = $script:ffmpegErrorLogPath
		Wait                  = $true
	}
	Invoke-StatisticsCheck -Operation 'validate'
	if ($IsWindows) { $commonParams.WindowStyle = $script:windowShowStyle }
	else { $commonParams.RedirectStandardOutput = '/dev/null' }
	try {
		# プロセスの開始
		$process = Start-Process @commonParams
		$process.Handle | Out-Null  # プロセスハンドルをキャッシュ。PS7.4.0の終了コードを捕捉しないバグのために必要
		$process.WaitForExit()
	} catch { Write-Warning ($script:msg.ExecFailed -f $execName) ; return }
	return $process.ExitCode
}

#----------------------------------------------------------------------
# SRT字幕の「0秒字幕」を次の字幕にマージ
#----------------------------------------------------------------------
function Merge-ZeroDurationSubtitle {
	<#
		.SYNOPSIS
			SRT字幕の中で表示時間が0秒になっている字幕を、同時刻に始まる次の字幕へマージします。

		.DESCRIPTION
			yt-dlpで字幕をmp4に埋め込むと、同一タイミングの字幕(2行表示)のうち1つ目が
			「開始時刻 --> 開始時刻」の0秒字幕になり、表示されなくなることがあります。
			0秒字幕と、同じ開始時刻を持つ直後の字幕を1つにまとめ、テキストを改行でつなぎます。
			マージ対象がない場合は、内容を変更しません。

		.PARAMETER SrtText
			SRT形式の字幕テキスト全体を指定します。

		.OUTPUTS
			[PSCustomObject]
			Content: マージ後のSRTテキスト、MergedCount: マージした件数

		.EXAMPLE
			$result = Merge-ZeroDurationSubtitle -SrtText (Get-Content -LiteralPath 'a.srt' -Raw -Encoding UTF8)
	#>
	[OutputType([PSCustomObject])]
	Param ([Parameter(Mandatory = $true)][AllowEmptyString()][String]$SrtText)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$timePattern = '^\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{3})'
	$cues = [System.Collections.Generic.List[PSCustomObject]]::new()
	foreach ($block in ($SrtText.Trim() -split '(?:\r?\n){2,}')) {
		$lines = @($block -split '\r?\n')
		$timeLineIndex = -1
		for ($i = 0; $i -lt [Math]::Min($lines.Count, 2); $i++) {
			if ($lines[$i] -match $timePattern) { $timeLineIndex = $i ; break }
		}
		if ($timeLineIndex -lt 0) { continue }
		$null = $lines[$timeLineIndex] -match $timePattern
		$cues.Add([PSCustomObject]@{
				Start = $Matches[1]
				End   = $Matches[2]
				Text  = @($lines | Select-Object -Skip ($timeLineIndex + 1))
			})
	}

	$merged = [System.Collections.Generic.List[PSCustomObject]]::new()
	$mergedCount = 0
	$idx = 0
	while ($idx -lt $cues.Count) {
		$cue = $cues[$idx]
		# 0秒字幕が連続していても、同じ開始時刻の字幕であれば順にたぐり寄せる
		while (($cue.Start -eq $cue.End) -and (($idx + 1) -lt $cues.Count) -and ($cues[$idx + 1].Start -eq $cue.Start)) {
			$next = $cues[$idx + 1]
			$cue = [PSCustomObject]@{ Start = $cue.Start ; End = $next.End ; Text = @($cue.Text) + @($next.Text) }
			$mergedCount++
			$idx++
		}
		$merged.Add($cue)
		$idx++
	}

	$sb = [System.Text.StringBuilder]::new()
	$no = 1
	foreach ($cue in $merged) {
		$null = $sb.Append(('{0}' -f $no)).Append("`n")
		$null = $sb.Append(('{0} --> {1}' -f $cue.Start, $cue.End)).Append("`n")
		foreach ($line in $cue.Text) { $null = $sb.Append($line).Append("`n") }
		$null = $sb.Append("`n")
		$no++
	}
	return [PSCustomObject]@{ Content = $sb.ToString() ; MergedCount = $mergedCount }
}

#----------------------------------------------------------------------
# 番組ファイルに埋め込まれた字幕の「0秒字幕」を修復
#----------------------------------------------------------------------
function Repair-SubtitleTiming {
	<#
		.SYNOPSIS
			mp4に埋め込まれた字幕から0秒字幕を検出し、マージして埋め込み直します。

		.DESCRIPTION
			ffprobeで字幕ストリームを調べ、ffmpegでSRTとして取り出して0秒字幕をマージします。
			マージ対象があった場合のみ、映像・音声はコピーのまま字幕だけを差し替えます。
			いずれかの手順に失敗した場合は、元のファイルを変更しません。

		.PARAMETER VideoPath
			対象のmp4ファイルのフルパスを指定します。

		.OUTPUTS
			[Boolean]
			字幕を修復してファイルを差し替えた場合は$true、それ以外は$falseを返します。

		.NOTES
			この関数は以下の処理を行います：
			1. ffprobeで字幕ストリームと言語を取得
			2. 各字幕ストリームをSRTとして一時ディレクトリに書き出し
			3. 0秒字幕をマージ(対象がなければ終了)
			4. 映像・音声をコピーしつつ、マージ後の字幕で新しいmp4を作成
			5. 同じディレクトリに複製してから元のファイルを置き換え
	#>
	[OutputType([Boolean])]
	Param ([Parameter(Mandatory = $true)][String]$VideoPath)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-Path -LiteralPath $VideoPath -PathType Leaf)) { return $false }
	if (!(Test-Path -LiteralPath $script:ffprobePath -PathType Leaf)) { return $false }
	$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tverrec_sub_{0}' -f [Guid]::NewGuid().ToString('N'))
	$stagedPath = ('{0}.subfix.tmp' -f $VideoPath)
	try {
		New-Item -ItemType Directory -Path $workDir -Force | Out-Null

		# 字幕ストリームの一覧(出現順のindexと言語)を取得
		$probeOutPath = Join-Path $workDir 'probe.txt'
		$probeArgs = ('-v error -select_streams s -show_entries stream=index:stream_tags=language -of csv=p=0 "{0}"' -f $VideoPath)
		Write-Debug ($script:msg.ExecCommand -f 'ffprobe', $script:ffprobePath, $probeArgs)
		$probe = Start-Process -FilePath $script:ffprobePath -ArgumentList $probeArgs -RedirectStandardOutput $probeOutPath -NoNewWindow -Wait -PassThru
		if (($probe.ExitCode -ne 0) -or !(Test-Path -LiteralPath $probeOutPath)) { return $false }
		$languages = @(Get-Content -LiteralPath $probeOutPath -Encoding UTF8 | Where-Object { $_.Trim() -ne '' } | ForEach-Object { ($_ -split ',')[1] })
		if ($languages.Count -eq 0) { return $false }

		# 字幕を取り出して0秒字幕をマージ
		$totalMerged = 0
		for ($i = 0 ; $i -lt $languages.Count ; $i++) {
			$srtPath = Join-Path $workDir ('sub{0}.srt' -f $i)
			$extractArgs = ('-hide_banner -v error -y -i "{0}" -map 0:s:{1} -c:s srt "{2}"' -f $VideoPath, $i, $srtPath)
			Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $extractArgs)
			$extract = Start-Process -FilePath $script:ffmpegPath -ArgumentList $extractArgs -NoNewWindow -Wait -PassThru
			if (($extract.ExitCode -ne 0) -or !(Test-Path -LiteralPath $srtPath)) { return $false }
			$result = Merge-ZeroDurationSubtitle -SrtText (Get-Content -LiteralPath $srtPath -Raw -Encoding UTF8)
			[System.IO.File]::WriteAllText($srtPath, $result.Content, [System.Text.UTF8Encoding]::new($false))
			$totalMerged += $result.MergedCount
		}
		if ($totalMerged -eq 0) { return $false }

		# 映像・音声などはそのまま、字幕のみ差し替えた新しいmp4を作成
		$outPath = Join-Path $workDir 'out.mp4'
		$inputArgs = ('-i "{0}"' -f $VideoPath)
		# * チャプターはデータストリームとしても複製されるため、-map_chapters側に任せてデータストリームは除外する
		$mapArgs = '-map 0 -map -0:s -map -0:d'
		for ($i = 0 ; $i -lt $languages.Count ; $i++) {
			$inputArgs += (' -i "{0}"' -f (Join-Path $workDir ('sub{0}.srt' -f $i)))
			$mapArgs += (' -map {0}:0' -f ($i + 1))
		}
		$metaArgs = ''
		for ($i = 0 ; $i -lt $languages.Count ; $i++) {
			if ($languages[$i] -and ($languages[$i] -ne 'und')) { $metaArgs += (' -metadata:s:s:{0} language={1}' -f $i, $languages[$i]) }
		}
		$remuxArgs = ('-hide_banner -v error -y {0} {1} -map_metadata 0 -map_chapters 0 -c copy -c:s mov_text{2} "{3}"' -f $inputArgs, $mapArgs, $metaArgs, $outPath)
		Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $remuxArgs)
		$remux = Start-Process -FilePath $script:ffmpegPath -ArgumentList $remuxArgs -NoNewWindow -Wait -PassThru
		if (($remux.ExitCode -ne 0) -or !(Test-Path -LiteralPath $outPath)) { return $false }
		if ((Get-Item -LiteralPath $outPath).Length -lt ((Get-Item -LiteralPath $VideoPath).Length * 0.9)) { return $false }

		# 字幕ストリーム数が変わっていないことを確認してから置き換え
		$checkOutPath = Join-Path $workDir 'check.txt'
		$checkArgs = ('-v error -select_streams s -show_entries stream=index -of csv=p=0 "{0}"' -f $outPath)
		$check = Start-Process -FilePath $script:ffprobePath -ArgumentList $checkArgs -RedirectStandardOutput $checkOutPath -NoNewWindow -Wait -PassThru
		if (($check.ExitCode -ne 0) -or (@(Get-Content -LiteralPath $checkOutPath | Where-Object { $_.Trim() -ne '' }).Count -ne $languages.Count)) { return $false }

		Copy-Item -LiteralPath $outPath -Destination $stagedPath -Force
		Move-Item -LiteralPath $stagedPath -Destination $VideoPath -Force
		return $true
	} catch {
		Write-Warning ($script:msg.SubtitleTimingRepairFailed)
		Write-Verbose $_.Exception.Message
		return $false
	} finally {
		Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
		Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}

#----------------------------------------------------------------------
# 番組の整合性チェック
#----------------------------------------------------------------------
function Invoke-IntegrityCheck {
	<#
		.SYNOPSIS
			ダウンロードした番組の整合性をチェックします。

		.DESCRIPTION
			ダウンロードした番組の整合性をチェックします。
			ffmpegまたはffprobeを使用して、ビデオファイルのエラーを検出します。

		.PARAMETER videoHist
			チェックする番組の履歴情報を指定します。

		.PARAMETER decodeOption
			デコードオプションを指定します。デフォルトは空文字列です。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオファイルのパスを取得
			2. チェックステータスを確認
			3. ffmpegまたはffprobeを使用してエラーを検出
			4. エラー数に基づいてチェック結果を記録
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)]$videoHist,
		[Parameter(Mandatory = $false)][String]$decodeOption = ''
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ffmpegProcessExitCode = 0
	$errorCount = 0
	$videoFilePath = Join-Path (Convert-Path $script:downloadBaseDir) $videoHist.videoPath
	try { New-Item -Path $script:ffmpegErrorLogPath -ItemType File -Force -ErrorAction Stop | Out-Null }
	catch { Write-Warning ($script:msg.FfmpegErrFileInitializeFailed) ; return }

	# これからチェックする番組のステータスをチェック
	$latestHists = Get-LatestHistory
	$targetHist = $latestHists.Where({ $_.videoPage -eq $videoHist.videoPage }) | Select-Object -First 1
	if ($targetHist) {
		$checkStatus = $targetHist.videoValidated
		if ($null -ne $checkStatus) {
			# 0:未チェック、1:チェック済、2:チェック中、3:チェック失敗、レコードなしは履歴が削除済み
			switch ($checkStatus) {
				# 「0:未チェック」のレコードは「2:チェック中」に変更したレコードを追記。(downloadDateは現在日時)
				'0' {
					# 該当のレコードを複製
					$targetHist.downloadDate = Get-TimeStamp
					$targetHist.videoValidated = '2'
					Wait-FileLock $script:histLockFilePath
					try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
					catch { Write-Warning ($script:msg.HistUpdateFailed) ; return }
					finally { Unlock-File $script:histLockFilePath | Out-Null }
					break
				}
				# 「0:未チェック」以外のステータスの際はスキップして次を処理
				'1' { Write-Output ($script:msg.ValidationCompleted) ; return }
				'2' { Write-Output ($script:msg.ValidationInProgress) ; return }
				'3' { Write-Output ($script:msg.ValidationFailed) ; return }
				default { Write-Warning ($script:msg.HistRecordRemoved -f $videoHist.videoPage) ; return }
			}
		}
	}

	if ($script:simplifiedValidation) {
		# ffprobeを使った簡易検査
		$ffprobeArgs = ('-hide_banner -v error -err_detect explode -i "{0}"' -f $videoFilePath)
		Write-Debug ($script:msg.ExecCommand -f 'ffprobe', $script:ffprobePath, $ffprobeArgs)
		$ffmpegProcessExitCode = Invoke-FFmpegProcess -filePath $script:ffprobePath -ffmpegArgs $ffprobeArgs -execName 'ffprobe'
	} else {
		# ffmpegを使った完全検査
		$ffmpegArgs = ('-hide_banner -v error -xerror {0} -i "{1}" -f null - ' -f $decodeOption, $videoFilePath)
		Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $ffmpegArgs)
		$ffmpegProcessExitCode = Invoke-FFmpegProcess -filePath $script:ffmpegPath -ffmpegArgs $ffmpegArgs -execName 'ffmpeg'
	}
	# ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffmpegErrorLogPath) {
			$errorCount = (Get-Content -LiteralPath $script:ffmpegErrorLogPath -ErrorAction Stop | Measure-Object -Line).Lines
			Get-Content -LiteralPath $script:ffmpegErrorLogPath -Encoding UTF8 -ErrorAction Stop | Write-Debug
		}
	} catch { Write-Warning ($script:msg.ErrorCountFailed) ; $errorCount = 9999999 }
	# エラーをカウントしたらファイルを削除
	try { if (Test-Path $script:ffmpegErrorLogPath) { Remove-Item -LiteralPath $script:ffmpegErrorLogPath -Force -ErrorAction Stop | Out-Null } }
	catch { Write-Warning ($script:msg.DeleteErrorFailed) }

	$latestHists = Get-LatestHistory
	$targetHist = $latestHists.Where({ $_.videoPage -eq $videoHist.videoPage }) | Select-Object -First 1
	if ($targetHist) {
		# 終了コードが0以外 または エラーが一定以上
		if ( ($ffmpegProcessExitCode -ne 0) -or ($errorCount -gt 30)) {
			Write-Warning ($script:msg.ValidationNG) ; Write-Verbose ($script:msg.ErrorCount -f $ffmpegProcessExitCode, $errorCount)
			# 「3:チェック失敗」に変更したレコードを追記。(downloadDateは現在日時)
			$targetHist.downloadDate = Get-TimeStamp
			$targetHist.videoValidated = '3'
			Wait-FileLock $script:histLockFilePath
			try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
			catch { Write-Warning ($script:msg.HistUpdateFailed) }
			finally { Unlock-File $script:histLockFilePath | Out-Null }
			# ファイルを削除
			try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction Stop | Out-Null }
			catch { Write-Warning ($script:msg.DeleteVideoFailed -f $videoFilePath) }
		} else {
			# 終了コードが0のときはダウンロード履歴にチェック済フラグを立てる
			Write-Output ($script:msg.ValidationOK)
			$targetHist.downloadDate = Get-TimeStamp
			$targetHist.videoValidated = '1'
			Wait-FileLock $script:histLockFilePath
			try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
			catch { Write-Warning ($script:msg.HistUpdateFailed) }
			finally { Unlock-File $script:histLockFilePath | Out-Null }
		}
	} else {
		Write-Warning ($script:msg.HistRecordNotFound)
		# 該当のレコードがない場合は履歴が削除済み。念の為ファイルも消しておく
		try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction Stop | Out-Null }
		catch { Write-Warning ($script:msg.DeleteVideoFailed -f $videoFilePath) }
	}
	Remove-Variable -Name videoFilePath, ffmpegProcessExitCode, errorCount, targetHist, checkStatus, latestHists -ErrorAction SilentlyContinue
}
#endregion 整合性チェック関連処理


#region 環境
#----------------------------------------------------------------------
# システム情報取得
#----------------------------------------------------------------------
function Get-SysInfo {
	<#
		.SYNOPSIS
			システム情報を取得します。

		.DESCRIPTION
			システム情報を取得し、変数に格納します。
			OSのバージョン、アーキテクチャ、GUIDなどの情報を取得します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. OSのバージョン、アーキテクチャ、GUIDを取得
			2. システム情報を変数に格納
			3. GeoIP情報を取得
	#>
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:locale = (Get-Culture).Name
	$script:tz = [String][TimeZoneInfo]::Local.BaseUtcOffset
	$progressPreference = 'SilentlyContinue'
	$script:clientEnvs = @{}
	try {
		$geoIPValues = (Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=18030841' -TimeoutSec 5).psobject.properties
		foreach ($geoIPValue in $geoIPValues) { $script:clientEnvs.Add($geoIPValue.Name, $geoIPValue.Value) | Out-Null }
	} catch { Write-Debug ('Failed to check Geo IP') }
	$progressPreference = 'Continue'

	switch ($true) {
		$IsWindows {
			$osInfo = Get-CimInstance -Class Win32_OperatingSystem
			$script:os = $osInfo.Caption
			$script:kernel = $osInfo.Version
			$script:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()
			$script:guid = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
			# Toast用AppID取得に必要
			if (!$script:disableToastNotification) {
				try {
					Import-Module StartLayout -SkipEditionCheck
					$script:appId = (Get-StartApps).Where({ $_.Name -cmatch 'PowerShell*' }, 'First').AppId
				} catch { Write-Debug 'Failed to import StartLayout module' }
			}
			break
		}
		$IsLinux {
			$script:os = if (Test-Path '/etc/os-release') { (& grep 'PRETTY_NAME' /etc/os-release).Replace('PRETTY_NAME=', '').Replace('"', '') } else { (& uname -n) }
			$script:kernel = [String][System.Environment]::OSVersion.Version
			$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
			$script:guid = if (Test-Path '/etc/machine-id') { (Get-Content /etc/machine-id) } else { (New-Guid).ToString().Replace('-', '') }
			break
		}
		$IsMacOS {
			$script:os = ('{0} {1}' -f (& sw_vers -productName), (& sw_vers -productVersion))
			$script:kernel = (&  uname -r)
			$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
			$script:guid = (& system_profiler SPHardwareDataType | awk '/Hardware UUID/ { print $3 }').Replace('-', '')
			break
		}
		default {
			$script:os = [String][System.Environment]::OSVersion
			$script:kernel = 'Unknown'
			$script:arch = 'Unknown'
			$script:guid = 'Unknown'
		}
	}
	Remove-Variable -Name geoIPValues, geoIPValue, osInfo -ErrorAction SilentlyContinue
}
Get-SysInfo

#----------------------------------------------------------------------
# 設定取得
#----------------------------------------------------------------------
function Get-Setting {
	<#
		.SYNOPSIS
			システム設定とユーザー設定を取得します。

		.DESCRIPTION
			システム設定とユーザー設定を取得します。
			設定ファイルから設定値を読み込み、変数に格納します。

		.OUTPUTS
			[System.Collections.Generic.Dictionary[string, object]]
			設定のキーと値のペアを含む辞書。

		.NOTES
			この関数は以下の処理を行います：
			1. 設定ファイルのパスを取得
			2. 設定ファイルから設定値を読み込み
			3. 設定値を変数に格納
	#>
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$filePathList = @((Join-Path $script:confDir 'system_setting.ps1'), (Join-Path $script:confDir 'user_setting.ps1'))
	$configList = @{}
	foreach ($filePath in $filePathList) {
		if (Test-Path $filePath) {
			$configs = (Select-String $filePath -Pattern '^(\$.+)=(.+)(\s*)$').ForEach({ $_.line })
			$excludePattern = '(.*PSStyle.*|.*Base64)'
			foreach ($config in $configs) {
				$configParts = $config -split '='
				$key = $configParts[0].Replace('script:', '').Replace('$', '').Trim()
				if (!($key -match $excludePattern) -and (Get-Variable -Name $key)) { $configList[$key] = (Get-Variable -Name $key).Value }
			}
		}
	}
	return $configList.GetEnumerator() | Sort-Object -Property key
}
$script:clientSettings = Get-Setting

#----------------------------------------------------------------------
# 統計取得
#----------------------------------------------------------------------
function Invoke-StatisticsCheck {
	<#
		.SYNOPSIS
			統計情報を取得します。

		.DESCRIPTION
			統計情報を取得します。
			指定された操作の統計情報を収集し、必要に応じて送信します。

		.PARAMETER operation
			統計を取得する操作を指定します。

		.PARAMETER tverType
			TVerのタイプを指定します。デフォルトは'none'です。

		.PARAMETER tverID
			TVerのIDを指定します。デフォルトは'none'です。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 統計情報のベースURLを設定
			2. 指定された操作の統計情報を取得
			3. 必要に応じて統計情報を送信
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$operation,
		[Parameter(Mandatory = $false)][String]$tverType = 'none',
		[Parameter(Mandatory = $false)][String]$tverID = 'none'
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $operation)
	if (!$env:PESTER) {
		# 統計送信は待たずに非同期で投げる(ダウンロード処理を遅くしないため)。失敗しても無視する
		if (!(Test-Path Variable:Script:statisticsHttpClient) -or !$script:statisticsHttpClient) {
			Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
			$script:statisticsHttpClient = [System.Net.Http.HttpClient]::new()
			$script:statisticsHttpClient.Timeout = [TimeSpan]::FromSeconds(5)
		}
		$statisticsBase = 'https://hits.sh/github.com/dongaba/TVerRec/'
		try { $countTask = $script:statisticsHttpClient.GetAsync(('{0}{1}.svg' -f $statisticsBase, $operation)) }
		catch { Write-Debug ('Failed to collect count') }
		if ($operation -eq 'search') { return }
		$epochTime = [Int64]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000)
		$userProperties = @{	# max 25 properties, max 24 chars of property name, 36 chars of property value
			PSVersion    = @{ 'value' = $PSVersionTable.PSVersion.ToString() }
			AppName      = @{ 'value' = $script:appName }
			AppVersion   = @{ 'value' = $script:appVersion }
			OS           = @{ 'value' = $script:os }
			Kernel       = @{ 'value' = $script:kernel }
			Architecture = @{ 'value' = $script:arch }
			Locale       = @{ 'value' = $script:locale }
			TimeZone     = @{ 'value' = $script:tz }
		}
		foreach ($clientEnv in $script:clientEnvs.GetEnumerator() ) {
			$value = [String]$clientEnv.Value
			$userProperties[$clientEnv.Key] = @{ 'value' = $value.Substring(0, [Math]::Min($value.Length, 36)) }
		}
		$eventParams = @{}	# max 25 parameters, max 40 chars of property name, 100 chars of property value
		foreach ($clientSetting in $script:clientSettings) {
			if (!($clientSetting.Name -match '(.*Schedule|my.*|embed.*|.*Update.*|.*Dir|.*Path|app.*|timeout.*|.*Preference|.*Max|.*Period|parallel.*|.*BaseArgs|.*FileName)')) {
				$paramValue = [String]((Get-Variable -Name $clientSetting.Name).Value)
				$eventParams[$clientSetting.Key] = $paramValue.Substring(0, [Math]::Min($paramValue.Length, 99))
			}
		}
		$gaBody = [PSCustomObject]@{
			client_id            = $script:guid
			timestamp_micros     = $epochTime
			non_personalized_ads = $true
			user_properties      = $userProperties
			events               = @(	# max 25 events, 40 chars of event name
				@{
					name   = $operation
					params = $eventParams
				}
			)
		} | ConvertTo-Json -Depth 3
		if ($DebugPreference -eq 'Continue') { $gaURL = 'https://www.google-analytics.com/debug/mp/collect' }
		else { $gaURL = 'https://www.google-analytics.com/mp/collect' }
		$gaKey = 'api_secret=3URTslDhRVu4Qpb66nDyAA'
		$gaID = 'measurement_id=G-V9TJN18D5Z'
		try {
			$gaContent = [System.Net.Http.StringContent]::new($gaBody, [System.Text.Encoding]::UTF8, 'application/json')
			$gaTask = $script:statisticsHttpClient.PostAsync(('{0}?{1}&{2}' -f $gaURL, $gaKey, $gaID), $gaContent)
			# デバッグ時のみ応答を待って内容を表示する
			if ($DebugPreference -eq 'Continue') { Write-Debug ('GA Response: {0}' -f $gaTask.GetAwaiter().GetResult().Content.ReadAsStringAsync().GetAwaiter().GetResult()) }
		} catch { Write-Debug ('Failed to collect statistics') }
	}
	Remove-Variable -Name operation, tverType, tverID, statisticsBase, epochTime, userProperties, clientEnv, value, eventParams, clientSetting, paramValue, gaBody, gaURL, gaKey, gaID, gaContent, gaTask, countTask -ErrorAction SilentlyContinue
}
#endregion 環境

#region 番組ファイル移動関連
#----------------------------------------------------------------------
# ディレクトリのパスを末尾のフォルダ名ごとにグループ化
#----------------------------------------------------------------------
function Group-DirectoryPathByLeaf {
	<#
		.SYNOPSIS
			ディレクトリのパスを、末尾のフォルダ名ごとにまとめます。

		.DESCRIPTION
			番組の移動元と移動先を「末尾のフォルダ名」で突き合わせるために、パスをフォルダ名ごとに集約します。
			同じフォルダ名のディレクトリが複数ある場合は、すべてのパスを保持します。
			(後から見つかったもので上書きしたり、先に見つかったものだけを採用したりしません)
			同じパスが重複して渡された場合は1つにまとめます。パスの大文字小文字は区別しません。

		.PARAMETER Path
			ディレクトリのパスの配列を指定します。

		.OUTPUTS
			[Hashtable]
			キーがフォルダ名、値がそのフォルダ名のパスの配列。キーの大文字小文字は区別しません。
	#>
	[OutputType([Hashtable])]
	Param ([Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowNull()][AllowEmptyString()][String[]]$Path)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$groups = @{}
	foreach ($dirPath in $Path) {
		if ([String]::IsNullOrWhiteSpace($dirPath)) { continue }
		$trimmedPath = $dirPath.TrimEnd('\', '/')
		if (!$trimmedPath) { continue }
		$leaf = Split-Path -Leaf $trimmedPath
		if (!$leaf) { continue }
		if (!$groups.ContainsKey($leaf)) { $groups[$leaf] = [Collections.Generic.List[String]]::new() }
		if ($groups[$leaf] -inotcontains $trimmedPath) { $groups[$leaf].Add($trimmedPath) }
	}
	return $groups
}

#----------------------------------------------------------------------
# 番組ファイルの移動(移動先に同名ファイルがある場合の動作を指定可能)
#----------------------------------------------------------------------
function Move-VideoFileToDestination {
	<#
		.SYNOPSIS
			ファイルを移動先ディレクトリに移動します。移動先に同名ファイルがある場合の動作を指定できます。

		.DESCRIPTION
			ファイルを移動先ディレクトリに移動します。
			移動先に同名のファイルが既に存在する場合は、ConflictActionに従って動作します。
			- Overwrite: 上書きします(既定。従来の動作)
			            ただし、移動先のファイルに字幕があり、移動元のファイルに字幕がない場合は、字幕が失われるため上書きしません(Result=SubtitleKept)
			- Skip     : 移動せず、移動元にファイルを残します
			- Rename   : 「ファイル名 (1).mp4」のように、重複しない名前を付けて移動します
			上記以外の値はOverwriteとして扱います。

		.PARAMETER Path
			移動するファイルのパスを指定します。

		.PARAMETER DestinationDir
			移動先ディレクトリのパスを指定します。

		.PARAMETER ConflictAction
			移動先に同名ファイルがある場合の動作(Overwrite/Skip/Rename)を指定します。

		.OUTPUTS
			[PSCustomObject]
			Result(Moved/Overwritten/Skipped/Renamed/SubtitleKept)とDestination(移動後のパス。SkippedとSubtitleKeptの場合は$null)を持つオブジェクト。

		.EXAMPLE
			Move-VideoFileToDestination -Path '/download/番組/第1話.mp4' -DestinationDir '/save/番組' -ConflictAction 'Skip'
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $true)][String]$Path,
		[Parameter(Mandatory = $true)][String]$DestinationDir,
		[Parameter(Mandatory = $false)][String]$ConflictAction = 'Overwrite'
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$fileName = Split-Path -Leaf $Path
	$destPath = Join-Path $DestinationDir $fileName
	$result = 'Moved'
	if (Test-Path -LiteralPath $destPath) {
		if ($ConflictAction -eq 'Skip') { return [PSCustomObject]@{ Result = 'Skipped' ; Destination = $null } }
		elseif ($ConflictAction -eq 'Rename') {
			$baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
			$extension = [System.IO.Path]::GetExtension($fileName)
			$num = 1
			do {
				$destPath = Join-Path $DestinationDir ('{0} ({1}){2}' -f $baseName, $num, $extension)
				$num++
			} while (Test-Path -LiteralPath $destPath)
			$result = 'Renamed'
		} else {
			# 上書きの場合、移動先に字幕があり、移動元に字幕がなければ、字幕が失われるため上書きしない
			if (((Test-VideoFileHasSubtitle -VideoPath $destPath) -eq $true) -and ((Test-VideoFileHasSubtitle -VideoPath $Path) -eq $false)) {
				return [PSCustomObject]@{ Result = 'SubtitleKept' ; Destination = $null }
			}
			$result = 'Overwritten'
		}
	}
	Move-Item -LiteralPath $Path -Destination $destPath -Force -ErrorAction Stop
	return [PSCustomObject]@{ Result = $result ; Destination = $destPath }
}
#endregion 番組ファイル移動関連
