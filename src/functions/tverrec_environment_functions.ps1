###################################################################################
#
#		TVerRec固有関数スクリプト(環境情報・設定・統計情報の取得)
#
###################################################################################
<#
	.SYNOPSIS
		環境情報・設定・統計情報の取得(読み込み時にGet-SysInfoとGet-Settingを実行)の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

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
