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
