Import-Module Pester -MinimumVersion 5.0

# region BeforeAll

#----------------------------------------------------------------------
# テスト対象ファイルの読み込み
#----------------------------------------------------------------------
BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$targetfile = $PSCommandPath.replace('test', 'src').replace('.Test.ps1', '.ps1')
	Write-Host ('　テスト対象: {0}' -f $targetfile)
	$script:scriptRoot = Convert-Path ./src
	Set-Location $script:scriptRoot
	$script:guiMode = $null
	. $targetfile
	Write-Host ('　テスト対象の読み込みを行いました')
}

# endregion BeforeAll

Describe '関数読み込みスクリプトテスト' {
	It '設定ファイルが存在するか確認' {
		# 設定ファイルのパスを定義
		$systemSettingPath = Join-Path $script:confDir 'system_setting.ps1'
		$userSettingPath = Join-Path $script:confDir 'user_setting.ps1'

		# 設定ファイルが存在するかテスト
		Test-Path $systemSettingPath | Should -BeTrue
		Test-Path $userSettingPath | Should -BeTrue
	}

	It '外部関数ファイルが読み込まれるか確認' {
		# 外部関数ファイルのパスを定義
		$commonFunctionsPath = Join-Path $script:scriptRoot 'functions/common_functions.ps1'
		$tverFunctionsPath = Join-Path $script:scriptRoot 'functions/tver_functions.ps1'
		$tverrecFunctionsPath = Join-Path $script:scriptRoot 'functions/tverrec_functions.ps1'

		# 外部関数ファイルが読み込まれているかテスト
		{ . $commonFunctionsPath } | Should -Not -Throw
		{ . $tverFunctionsPath } | Should -Not -Throw
		{ . $tverrecFunctionsPath } | Should -Not -Throw
	}

	It '開発環境用設定が正しく上書きされるか確認' {
		# 開発環境用設定ファイルのパスを定義
		$devConfFile = Join-Path $script:devDir 'dev_setting.ps1'

		# 開発環境用設定ファイルがある場合のみテスト
		if (Test-Path $devConfFile) {
			{ . $devConfFile } | Should -Not -Throw
		}
	}
}
