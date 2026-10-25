Import-Module Pester -MinimumVersion 5.0

# region BeforeAll

#----------------------------------------------------------------------
# テスト対象ファイルの読み込み
#----------------------------------------------------------------------
BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	# * パスに「test」「src」を含むディレクトリ配下でも正しく解決できるよう、リポジトリルートから組み立てる
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot 'src/functions/initialize.ps1'
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:scriptRoot = Convert-Path (Join-Path $script:repoRoot 'src')
	Set-Location $script:scriptRoot
	$script:guiMode = $null

	# user_setting.ps1がない環境(クローン直後やCI)では一時的に作成し、テスト後に削除する
	# * ツールの自動更新はテストの目的外かつ時間がかかるため無効化する
	$script:userSettingPath = Join-Path $script:repoRoot 'conf/user_setting.ps1'
	$script:cleanupUserSetting = -not (Test-Path $script:userSettingPath)
	if ($script:cleanupUserSetting) {
		$tmpBase = (Join-Path $TestDrive 'tverrec').Replace("'", "''")
		@(
			('$script:downloadBaseDir = ''{0}/download''' -f $tmpBase)
			('$script:downloadWorkDir = ''{0}/work''' -f $tmpBase)
			('$script:saveBaseDir = ''{0}/save''' -f $tmpBase)
			'$script:disableUpdateYoutubedl = $true'
			'$script:disableUpdateFfmpeg = $true'
		) | Set-Content -LiteralPath $script:userSettingPath
	}
	. $targetFile
	Write-Host ('　テスト対象の読み込みを行いました')
}

AfterAll {
	if ($script:cleanupUserSetting) { Remove-Item -LiteralPath $script:userSettingPath -ErrorAction SilentlyContinue }
}

# endregion BeforeAll

Describe '関数読み込みスクリプトテスト' {
	It '設定ファイルが存在するか確認' {
		Test-Path (Join-Path $script:confDir 'system_setting.ps1') | Should -BeTrue
		Test-Path (Join-Path $script:confDir 'user_setting.ps1') | Should -BeTrue
	}

	It '外部関数ファイルが読み込まれるか確認' {
		{ . (Join-Path $script:scriptRoot 'functions/common_functions.ps1') } | Should -Not -Throw
		{ . (Join-Path $script:scriptRoot 'functions/tver_functions.ps1') } | Should -Not -Throw
		{ . (Join-Path $script:scriptRoot 'functions/tverrec_functions.ps1') } | Should -Not -Throw
	}

	It '主要な関数と変数が初期化されること' {
		Get-Command Get-VideoLinksFromKeyword -CommandType Function | Should -Not -BeNullOrEmpty
		Get-Command Invoke-VideoDownload -CommandType Function | Should -Not -BeNullOrEmpty
		$script:msg | Should -Not -BeNullOrEmpty
		$script:commonHttpHeader['x-tver-platform-type'] | Should -Be 'web'
		$script:jpIP | Should -Match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
	}

	It '開発環境用設定が正しく上書きされるか確認' {
		$devConfFile = Join-Path $script:devDir 'dev_setting.ps1'
		# 開発環境用設定ファイルがある場合のみテスト
		if (Test-Path $devConfFile) { { . $devConfFile } | Should -Not -Throw }
	}
}

#----------------------------------------------------------------------
# 設定ファイル・関数ファイルの読み込みに失敗した場合や、アップデータの更新
# * 実環境のconfやsrcを壊さないよう、読み込み失敗は一時フォルダに作った最小構成で確認する
#----------------------------------------------------------------------
Describe '読み込み失敗時の動作とアップデータの更新' {
	BeforeAll {
		$script:ldRealScriptRoot = $script:scriptRoot
		$script:ldTarget = Join-Path $script:repoRoot 'src/functions/initialize.ps1'
		# メッセージ表の全言語から、指定キーの文言を集める
		function script:Get-AllMessage {
			Param ([String]$Key)
			$langs = Get-Content -Path (Join-Path $script:repoRoot 'resources/lang/messages.json') -Raw | ConvertFrom-Json
			return @($langs.PSObject.Properties.Value | ForEach-Object { $_.$Key })
		}
		# 最小構成の一時フォルダを作る(関数ファイルは空、設定ファイルは指定の内容)
		function script:New-InitSandbox {
			Param ([String]$SystemSetting = '# stub', $UserSetting = '# stub', [Hashtable]$Functions = @{})
			$root = Join-Path $TestDrive ('sb{0}' -f [Guid]::NewGuid().ToString('N'))
			foreach ($d in 'src/functions', 'conf', 'resources/lang', 'dev') { New-Item -ItemType Directory -Path (Join-Path $root $d) -Force | Out-Null }
			Copy-Item -LiteralPath (Join-Path $script:repoRoot 'resources/lang/messages.json') -Destination (Join-Path $root 'resources/lang')
			Set-Content -LiteralPath (Join-Path $root 'conf/system_setting.ps1') -Value $SystemSetting
			if ($null -ne $UserSetting) { Set-Content -LiteralPath (Join-Path $root 'conf/user_setting.ps1') -Value $UserSetting }
			foreach ($f in 'common_functions.ps1', 'tver_functions.ps1', 'tverrec_functions.ps1') {
				$body = if ($Functions.ContainsKey($f)) { $Functions[$f] } else { '# stub' }
				Set-Content -LiteralPath (Join-Path $root "src/functions/$f") -Value $body
			}
			return $root
		}
		# 一時フォルダを対象にinitialize.ps1を読み込み、投げられた例外のメッセージを返す
		function script:Get-InitThrownMessage {
			Param ([String]$Root)
			$script:scriptRoot = Join-Path $Root 'src'
			Set-Location $script:scriptRoot
			try { . $script:ldTarget *> $null } catch { return $_.Exception.Message }
			return $null
		}
	}
	AfterAll {
		# 後続のテストに影響しないよう、実環境の設定で読み込み直す
		$script:scriptRoot = $script:ldRealScriptRoot
		Set-Location $script:scriptRoot
		. $script:ldTarget *> $null
	}
	BeforeEach {
		Mock Write-Error {}
		Mock Write-Warning {}
	}
	AfterEach {
		$script:scriptRoot = $script:ldRealScriptRoot
		Set-Location $script:scriptRoot
	}

	It 'システム設定ファイルの読み込みで例外になったら、読み込み失敗として例外にする' {
		$root = New-InitSandbox -SystemSetting 'throw "bad system setting"'
		Get-AllMessage 'LoadSystemSettingFailed' | Should -Contain (Get-InitThrownMessage $root)
		Should -Invoke Write-Error -Times 2 -Exactly
	}

	It 'システム設定ファイルがなければ例外にする' {
		$root = New-InitSandbox
		Remove-Item -LiteralPath (Join-Path $root 'conf/system_setting.ps1')
		Get-AllMessage 'SystemSettingNotFound' | Should -Contain (Get-InitThrownMessage $root)
	}

	It 'ユーザー設定ファイルの読み込みで例外になったら、読み込み失敗として例外にする' {
		$root = New-InitSandbox -UserSetting 'throw "bad user setting"'
		Get-AllMessage 'LoadUserSettingFailed' | Should -Contain (Get-InitThrownMessage $root)
		Should -Invoke Write-Error -Times 2 -Exactly
	}

	It 'ユーザー設定ファイルがなければ、設定未完了として例外にする(macOS/Linux)' -Skip:$IsWindows {
		$root = New-InitSandbox -UserSetting $null
		Get-AllMessage 'UserSettingNotCompleted' | Should -Contain (Get-InitThrownMessage $root)
	}

	It '言語設定(preferredLanguage)に従った言語のメッセージで例外にし、未対応の言語は英語にする' {
		$langs = Get-Content -Path (Join-Path $script:repoRoot 'resources/lang/messages.json') -Raw | ConvertFrom-Json
		foreach ($case in @(@('ja-JP', 'ja-JP'), @('en-US', 'en-US'), @('xx-XX', 'en-US'))) {
			$root = New-InitSandbox -UserSetting ('$script:preferredLanguage = ''{0}''' -f $case[0]) -Functions @{ 'common_functions.ps1' = 'throw "x"' }
			Get-InitThrownMessage $root | Should -Be $langs.($case[1]).LoadCommonFuncFailed -Because $case[0]
		}
	}

	It '関数ファイルの読み込みで例外になったら、ファイルごとの読み込み失敗として例外にする' {
		foreach ($case in @(@('common_functions.ps1', 'LoadCommonFuncFailed'), @('tver_functions.ps1', 'LoadTVerFuncFailed'), @('tverrec_functions.ps1', 'LoadTVerRecFuncFailed'))) {
			$root = New-InitSandbox -Functions @{ $case[0] = 'throw "bad"' }
			Get-AllMessage $case[1] | Should -Contain (Get-InitThrownMessage $root) -Because $case[0]
		}
	}

	It '開発環境用の設定ファイルで例外になったら、読み込み失敗として例外にする' {
		$root = New-InitSandbox
		Set-Content -LiteralPath (Join-Path $root 'dev/dev_setting.ps1') -Value 'throw "bad dev"'
		Get-AllMessage 'LoadDevFilesFailed' | Should -Contain (Get-InitThrownMessage $root)
	}

	Context 'アップデータの更新(updater_update.txt)' {
		BeforeEach {
			$script:ldFlag = Join-Path $script:repoRoot 'log/updater_update.txt'
			if (Test-Path $script:ldFlag) { Set-ItResult -Skipped -Because '既存のupdater_update.txtを消さないため' ; return }
			New-Item -ItemType Directory -Path (Split-Path $script:ldFlag) -Force | Out-Null
			Set-Content -LiteralPath $script:ldFlag -Value 'x'
		}
		AfterEach {
			Remove-Item -LiteralPath $script:ldFlag -Force -ErrorAction SilentlyContinue
		}

		It 'フラグファイルがあれば、アップデータ2種を取得してフラグファイルを削除する' {
			Mock Invoke-WebRequest {}
			. $script:ldTarget *> $null
			Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -match 'unix/update_tverrec\.sh$' -and $OutFile -match 'update_tverrec\.sh$' } -Times 1 -Exactly
			Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -match 'win/update_tverrec\.cmd$' -and $OutFile -match 'update_tverrec\.cmd$' } -Times 1 -Exactly
			Test-Path -LiteralPath $script:ldFlag | Should -BeFalse
		}

		It '取得に失敗したら警告を出し、フラグファイルを残す' {
			Mock Invoke-WebRequest { throw 'offline' }
			. $script:ldTarget *> $null
			Should -Invoke Write-Warning -ParameterFilter { $Message -eq $script:msg.UpdateUpdaterFailed } -Times 1 -Exactly
			Test-Path -LiteralPath $script:ldFlag | Should -BeTrue
		}
	}
}
