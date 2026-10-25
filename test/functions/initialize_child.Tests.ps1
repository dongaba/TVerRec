Import-Module Pester -MinimumVersion 5.0

# region BeforeAll

#----------------------------------------------------------------------
# テスト対象ファイルの読み込み
#----------------------------------------------------------------------
BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	# * パスに「test」「src」を含むディレクトリ配下でも正しく解決できるよう、リポジトリルートから組み立てる
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$script:targetFile = Join-Path $script:repoRoot 'src/functions/initialize_child.ps1'
	Write-Host ('　テスト対象: {0}' -f $script:targetFile)
	$script:scriptRoot = Convert-Path (Join-Path $script:repoRoot 'src')
	Set-Location $script:scriptRoot
	$script:guiMode = $null

	# user_setting.ps1がない環境(クローン直後やCI)では一時的に作成し、テスト後に削除する
	$script:userSettingPath = Join-Path $script:repoRoot 'conf/user_setting.ps1'
	$script:cleanupUserSetting = -not (Test-Path $script:userSettingPath)
	if ($script:cleanupUserSetting) {
		$tmpBase = (Join-Path $TestDrive 'tverrec').Replace("'", "''")
		@(
			('$script:downloadBaseDir = ''{0}/download''' -f $tmpBase)
			('$script:downloadWorkDir = ''{0}/work''' -f $tmpBase)
			('$script:saveBaseDir = ''{0}/save''' -f $tmpBase)
		) | Set-Content -LiteralPath $script:userSettingPath
	}
	. $script:targetFile
	Write-Host ('　テスト対象の読み込みを行いました')
}

AfterAll {
	if ($script:cleanupUserSetting) { Remove-Item -LiteralPath $script:userSettingPath -ErrorAction SilentlyContinue }
}

# endregion BeforeAll

Describe '子プロセス用の初期化スクリプト' {
	It 'メッセージ表が読み込まれること' {
		$script:msg | Should -Not -BeNullOrEmpty
		$script:msg.LoadFailed | Should -Not -BeNullOrEmpty
	}

	It '外部関数ファイルが読み込まれること' {
		Get-Command Get-VideoLinksFromKeyword -CommandType Function | Should -Not -BeNullOrEmpty
		Get-Command Invoke-VideoDownload -CommandType Function | Should -Not -BeNullOrEmpty
		Get-Command Get-JpIP -CommandType Function | Should -Not -BeNullOrEmpty
	}

	It '各種ファイルのパスが設定されること' {
		$script:keywordFilePath | Should -Be (Join-Path $script:confDir 'keyword.conf')
		$script:ignoreFilePath | Should -Be (Join-Path $script:confDir 'ignore.conf')
		$script:histFilePath | Should -Be (Join-Path $script:dbDir 'history.csv')
		$script:listFilePath | Should -Be (Join-Path $script:listDir 'list.csv')
		$script:ignoreLockFilePath | Should -Be (Join-Path $script:lockDir 'ignore.lock')
		$script:histLockFilePath | Should -Be (Join-Path $script:lockDir 'history.lock')
		$script:listLockFilePath | Should -Be (Join-Path $script:lockDir 'list.lock')
		$script:jpIPList | Should -Be (Join-Path $script:geoIPDir 'jp.csv')
	}

	It 'プロセスごとのログファイルのパスにPIDが入ること' {
		$script:ffmpegErrorLogPath | Should -Be (Join-Path $script:logDir ('ffmpeg_err_{0}.log' -f $PID))
		$script:ytdlStdOutLogPath | Should -Be (Join-Path $script:logDir ('ytdl_out_{0}.log' -f $PID))
		$script:ytdlStdErrLogPath | Should -Be (Join-Path $script:logDir ('ytdl_err_{0}.log' -f $PID))
	}

	It '実行ファイルのパスがOSごとの名前になること' {
		$ext = if ($IsWindows) { '.exe' } else { '' }
		$script:ytdlPath | Should -Be (Join-Path $script:binDir ('yt-dlp{0}' -f $ext))
		$script:ffmpegPath | Should -Be (Join-Path $script:binDir ('ffmpeg{0}' -f $ext))
		$script:ffprobePath | Should -Be (Join-Path $script:binDir ('ffprobe{0}' -f $ext))
	}

	It '共通HTTPヘッダーに日本のIPが設定されること' {
		$script:jpIP | Should -Match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
		$script:commonHttpHeader['x-tver-platform-type'] | Should -Be 'web'
		$script:commonHttpHeader['Origin'] | Should -Be 'https://tver.jp'
		foreach ($k in 'Forwarded', 'Forwarded-For', 'X-Forwarded', 'X-Forwarded-For', 'X-Originating-IP') { $script:commonHttpHeader[$k] | Should -Be $script:jpIP -Because $k }
	}

	It 'ロックファイル用の変数が空のハッシュテーブルで初期化されること' {
		$script:fileInfo | Should -BeOfType [Hashtable]
		$script:fileStream | Should -BeOfType [Hashtable]
	}

	It '進捗表示の設定がdetailedProgressに従うこと' {
		# * 設定ファイルは読み込みのたびに上書きされるため、後から読み込まれる開発環境用設定で値を差し替える
		$devDir = Join-Path $script:repoRoot 'dev'
		$devConf = Join-Path $devDir 'dev_setting.ps1'
		$hadDevDir = Test-Path $devDir
		$hadDevConf = Test-Path $devConf
		if ($hadDevConf) { Set-ItResult -Skipped -Because '既存のdev_setting.ps1を上書きしないため' ; return }
		try {
			if (-not $hadDevDir) { New-Item -ItemType Directory -Path $devDir | Out-Null }
			foreach ($v in '$true', '$false') {
				Set-Content -LiteralPath $devConf -Value ('$script:detailedProgress = {0}' -f $v)
				. $script:targetFile *> $null
				$expected = if ($v -eq '$true') { 'Continue' } else { 'SilentlyContinue' }
				"$InformationPreference" | Should -Be $expected
			}
		} finally {
			Remove-Item -LiteralPath $devConf -Force -ErrorAction SilentlyContinue
			if (-not $hadDevDir) { Remove-Item -LiteralPath $devDir -Recurse -Force -ErrorAction SilentlyContinue }
		}
	}

	It '言語設定(preferredLanguage)に従ってメッセージ表が切り替わること' {
		$orig = $script:preferredLanguage
		try {
			foreach ($lang in 'ja-JP', 'en-US', 'xx-XX') {
				$script:preferredLanguage = $lang
				. $script:targetFile *> $null
				$script:msg | Should -Not -BeNullOrEmpty -Because $lang
			}
		} finally { $script:preferredLanguage = $orig }
	}

	It '開発環境用の設定・関数ファイルがあれば読み込むこと' {
		$devDir = Join-Path $script:repoRoot 'dev'
		$created = @()
		try {
			if (-not (Test-Path $devDir)) { New-Item -ItemType Directory -Path $devDir | Out-Null ; $created += $devDir }
			foreach ($f in 'dev_setting.ps1', 'dev_functions.ps1') {
				$p = Join-Path $devDir $f
				if (-not (Test-Path $p)) { Set-Content -LiteralPath $p -Value '$script:devChildLoaded = $true' ; $created += $p }
			}
			$script:devChildLoaded = $false
			$out = . $script:targetFile
			$script:devChildLoaded | Should -BeTrue
			@($out) -contains $script:msg.DevConfLoaded | Should -BeTrue
		} finally {
			foreach ($p in ($created | Sort-Object -Descending)) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
			Remove-Variable -Name devChildLoaded -Scope Script -ErrorAction SilentlyContinue
		}
	}
}
