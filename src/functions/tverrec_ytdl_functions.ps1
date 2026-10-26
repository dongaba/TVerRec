###################################################################################
#
#		TVerRec固有関数スクリプト(youtube-dlの起動、プロセス数の取得、終了待機)
#
###################################################################################
<#
	.SYNOPSIS
		youtube-dlの起動、プロセス数の取得、終了待機の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

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
# スクリプト終了時にバックグラウンドジョブを停止する処理の登録
#----------------------------------------------------------------------
function Register-JobCleanup {
	<#
		.SYNOPSIS
			ジョブ一覧($script:jobList)を初期化し、PowerShellの終了時にバックグラウンドジョブを停止・削除する処理を登録します。

		.DESCRIPTION
			PowerShellの終了時(PowerShell.Exitingイベント)に、このセッションのジョブ(youtube-dlのタイムアウト監視ジョブなど)を強制停止して削除します。
			* -Actionのスクリプトブロックは別モジュールのスコープで実行され、$script:jobListを参照できないため、Get-Jobで対象を取得します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Register-JobCleanup
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:jobList = @()
	Register-EngineEvent PowerShell.Exiting -Action {
		Get-Job | Stop-Job -ErrorAction SilentlyContinue
		Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
	} | Out-Null
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
			ダウンロードする番組の情報を含むオブジェクトを指定します。この関数は内容を読み取るだけで、変更しません。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-Ytdl -videoInfo $videoInfo

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード用の一時ディレクトリと保存ディレクトリを設定
			2. youtube-dlの引数を構築（プロキシ、レート制限、字幕設定など）
			3. 既存ファイルの削除とリネーム用のコマンドを設定
			4. youtube-dlプロセスを起動し、タイムアウト監視を開始
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject]$videoInfo)
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
