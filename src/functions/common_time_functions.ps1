###################################################################################
#
#		共通関数スクリプト(時間処理)
#
###################################################################################
<#
	.SYNOPSIS
		タイムスタンプの生成と、UNIX時間とDateTime型の相互変換の関数を定義します。

	.NOTES
		このファイルはcommon_functions.ps1から読み込まれます。
		単体で読み込まず、common_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region タイムスタンプ
#----------------------------------------------------------------------
# タイムスタンプ更新
#----------------------------------------------------------------------
function Get-TimeStamp {
	<#
		.SYNOPSIS
			現在のタイムスタンプを "yyyy-MM-dd HH:mm:ss" の形式で取得します。

		.DESCRIPTION
			この関数は現在の日時を取得し、"yyyy-MM-dd HH:mm:ss" 形式の文字列として返します。
			ログ記録やファイル名のタイムスタンプなどに利用できます。

		.INPUTS
			なし

		.OUTPUTS
			System.String
			- 現在の日時を "yyyy-MM-dd HH:mm:ss" の形式で表した文字列。

		.EXAMPLE
			PS> Get-TimeStamp
			2025-04-02 15:30:45

			現在のタイムスタンプを取得し、"yyyy-MM-dd HH:mm:ss" の形式で表示します。

		.LINK
			https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date

		.NOTES
			- PowerShell の `Get-Date` を使用して現在の日時を取得しています。
			- `ToString('yyyy-MM-dd HH:mm:ss')` により、カスタムフォーマットで日時を出力します。
			- ログファイルの命名規則やスクリプト内のタイムスタンプ生成などに便利です。
	#>
	[CmdletBinding()]
	[OutputType([String])]
	Param ()
	return (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}

#----------------------------------------------------------------------
# UNIX時間をDateTime型に変換
#----------------------------------------------------------------------
function ConvertFrom-UnixTime {
	<#
		.SYNOPSIS
			Unix タイムスタンプをローカル日時に変換します。

		.DESCRIPTION
			この関数は、Unix エポック (1970-01-01 00:00:00 UTC) からの秒数を受け取り、
			ローカル時刻に変換して返します。

		.PARAMETER UnixTime
			変換する Unix タイムスタンプ (1970年1月1日 00:00:00 UTC からの経過秒数) を指定します。

		.INPUTS
			System.Int64
			- 変換する Unix タイムスタンプ (秒単位)。

		.OUTPUTS
			System.DateTime
			- 変換後のローカル日時。

		.EXAMPLE
			PS> ConvertFrom-UnixTime -UnixTime 1712050000
			2024年4月2日 15:06:40

			Unix タイムスタンプ 1712050000 をローカル時刻に変換します。

		.LINK
			https://learn.microsoft.com/en-us/dotnet/api/system.datetime

		.NOTES
			- `UnixTime` は 1970年1月1日 00:00:00 UTC からの経過秒数として扱われます。
			- `.ToLocalTime()` を使用して、現在のタイムゾーンの時刻に変換します。
			- `Remove-Variable` は変数の明示的な削除を試みますが、影響は限定的です。
	#>
        [CmdletBinding()]
        [OutputType([datetime])]
        Param ([Parameter(Mandatory = $true)][int64]$UnixTime)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$EpochDate = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -AsUTC
	return ($EpochDate.AddSeconds($UnixTime).ToLocalTime())
}

#----------------------------------------------------------------------
# DateTime型をUNIX時間に変換
#----------------------------------------------------------------------
function ConvertTo-UnixTime {
	<#
		.SYNOPSIS
			指定した日時を Unix タイムスタンプ (1970年1月1日 00:00:00 UTC からの経過秒数) に変換します。

		.DESCRIPTION
			この関数は、入力された `DateTime` 値を UTC に変換し、Unix エポック (1970-01-01 00:00:00 UTC) からの
			経過秒数として返します。Unix タイムスタンプは、システムログや API のタイムスタンプとして
			よく使用されます。

		.PARAMETER InputDate
			変換する日時 (DateTime 型)。ローカル時刻として渡された場合、自動的に UTC に変換されます。

		.INPUTS
			System.DateTime
			- 変換する日時。

		.OUTPUTS
			System.Int64
			- Unix タイムスタンプ (1970年1月1日 00:00:00 UTC からの経過秒数)。

		.EXAMPLE
			PS> ConvertTo-UnixTime -InputDate (Get-Date)
			1712050000

			現在の日時を Unix タイムスタンプに変換します。

		.EXAMPLE
			PS> ConvertTo-UnixTime -InputDate "2025-04-02 12:34:56"
			1743593696

			指定した日時を Unix タイムスタンプに変換します。

		.LINK
			https://learn.microsoft.com/en-us/dotnet/api/system.datetime

		.NOTES
			- Unix タイムスタンプは UTC を基準とするため、入力日時は `.ToUniversalTime()` で UTC に変換されます。
			- `New-TimeSpan` を使用して Unix エポック (1970-01-01 00:00:00 UTC) からの経過秒数を計算します。
			- `Math.Round()` を使用して、秒単位で切り捨てまたは四捨五入します。
	#>
	[CmdletBinding()]
	[OutputType([int64])]
	Param ([Parameter(Mandatory = $true)][DateTime]$InputDate)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$unixTime = New-TimeSpan -Start '1970-01-01' -End $InputDate.ToUniversalTime()
	return [int64][math]::Round($unixTime.TotalSeconds)
}
#endregion タイムスタンプ
