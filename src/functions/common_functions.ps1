###################################################################################
#
#		共通関数スクリプト
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
Add-Type -AssemblyName System.IO.Compression.FileSystem

#region 環境

#----------------------------------------------------------------------
#GUID取得
#----------------------------------------------------------------------
$progressPreference = 'silentlyContinue'
switch ($true) {
	$IsWindows {
		#		$script:os = [String][System.Environment]::OSVersion
		$script:os = (Get-CimInstance -Class Win32_OperatingSystem).Caption
		$script:kernel = (Get-CimInstance -Class Win32_OperatingSystem).Version
		$script:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()
		$script:guid = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
		break
	}
	$IsLinux {
		if ((Test-Path '/etc/os-release')) {
			$script:os = (& grep 'PRETTY_NAME' /etc/os-release).replace('PRETTY_NAME=', '').Replace('"', '')
		} else { $script:os = (& uname -n) }
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = (Get-Content /etc/machine-id)
		if ((Test-Path '/etc/machine-id')) { $script:guid = (Get-Content /etc/machine-id) }
		else { $script:guid = [guid]::NewGuid() }
		break
	}
	$IsMacOS {
		$script:os = (& sw_vers -productName)
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		if ((Test-Path '/etc/machine-id')) { $script:guid = (Get-Content /etc/machine-id) }
		else { $script:guid = [guid]::NewGuid() }
		break
	}
	default {
		$script:os = [String][System.Environment]::OSVersion
		break
	}
}
$script:locale = (Get-Culture).Name
$script:tz = [String][TimeZoneInfo]::Local.BaseUtcOffset
$script:ipapi = ''
$script:clientEnv = @{}
try {
	$script:ipapi = `
		Invoke-RestMethod `
		-Uri 'https://ipapi.co/jsonp/' `
		-TimeoutSec $script:timeoutSec
	$script:ipapi = $script:ipapi.Replace('callback(', '').Replace(');', '')
	$script:ipapi = $script:ipapi.Replace('{', "{`n").Replace('}', "`n}")
	$script:ipapi = $script:ipapi.Replace(', ', ",`n")
	$(ConvertFrom-Json $script:ipapi).psobject.properties `
	| ForEach-Object { $script:clientEnv[$_.Name] = $_.Value }
} catch { Write-Debug 'Geo IPのチェックに失敗しました' }
$script:clientEnv.Add('AppName', $script:appName)
$script:clientEnv.Add('AppVersion', $script:appVersion)
$script:clientEnv.Add('PSEdition', $PSVersionTable.PSEdition)
$script:clientEnv.Add('PSVersion', $PSVersionTable.PSVersion)
$script:clientEnv.Add('OS', $script:os)
$script:clientEnv.Add('Kernel', $script:kernel)
$script:clientEnv.Add('Arch', $script:arch)
$script:clientEnv.Add('Locale', $script:locale)
$script:clientEnv.Add('TZ', $script:tz)
$script:clientEnv.Add('GUID', $script:guid)
$script:clientEnv = $script:clientEnv.GetEnumerator() | Sort-Object -Property key
$progressPreference = 'Continue'

#----------------------------------------------------------------------
#統計取得
#----------------------------------------------------------------------
function goAnal {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Event')]
		[String]$local:event,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Type')]
		[String]$local:type,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('ID')]
		[String]$local:id
	)

	if (!($local:type)) { $local:type = '' }
	if (!($local:id)) { $local:id = '' }
	$local:epochTime = [decimal]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000)

	$progressPreference = 'silentlyContinue'
	$local:statisticsBase = 'https://hits.sh/github.com/dongaba/TVerRec/'
	try {
		$null = Invoke-WebRequest `
			-Uri "$($local:statisticsBase)$($local:event).svg" `
			-TimeoutSec $script:timeoutSec
	} catch { Write-Debug 'Failed to collect statistics' }
	finally { $progressPreference = 'Continue' }

	if ($local:event -eq 'search') { return }
	$local:gaURL = 'https://www.google-analytics.com/mp/collect'
	$local:gaKey = 'api_secret=UZ3InfgkTgGiR4FU-in9sw'
	$local:gaID = 'measurement_id=G-NMSF9L531G'
	$local:gaHeaders = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
	$local:gaHeaders.Add('HOST', 'www.google-analytics.com')
	$local:gaHeaders.Add('Content-Type', 'application/json')
	$local:gaBody = "{ `"client_id`" : `"$script:guid`", "
	$local:gaBody += "`"timestamp_micros`" : `"$local:epochTime`", "
	$local:gaBody += "`"non_personalized_ads`" : false, "
	$local:gaBody += "`"user_properties`":{ "
	foreach ($item in $script:clientEnv) {
		$local:gaBody += "`"$($item.Key)`" : {`"value`" : `"$($item.Value)`"}, "
	}
	$local:gaBody += "`"DisableValidation`" : {`"value`" : `"$($script:disableValidation)`"}, "
	$local:gaBody += "`"SortwareDecode`" : {`"value`" : `"$($script:forceSoftwareDecodeFlag)`"}, "
	$local:gaBody += "`"DecodeOption`" : {`"value`" : `"$($script:ffmpegDecodeOption)`"}, "
	$local:gaBody = $local:gaBody.Trim(',', ' ')		#delete last comma
	$local:gaBody += "}, `"events`" : [ { "
	$local:gaBody += "`"name`" : `"$local:event`", "
	$local:gaBody += "`"params`" : {"
	$local:gaBody += "`"Type`" : `"$local:type`", "
	$local:gaBody += "`"ID`" : `"$local:id`", "
	$local:gaBody += "`"Target`" : `"$local:type/$local:id`", "
	foreach ($item in $script:clientEnv) {
		$local:gaBody += "`"$($item.Key)`" : `"$($item.Value)`", "
	}
	$local:gaBody += "`"DisableValidation`" : `"$($script:disableValidation)`", "
	$local:gaBody += "`"SortwareDecode`" : `"$($script:forceSoftwareDecodeFlag)`", "
	$local:gaBody += "`"DecodeOption`" : `"$($script:ffmpegDecodeOption)`", "
	$local:gaBody = $local:gaBody.Trim(',', ' ')		#delete last comma
	$local:gaBody += '} } ] }'

	$progressPreference = 'silentlyContinue'
	try {
		$null = Invoke-RestMethod `
			-Uri "$($local:gaURL)?$($local:gaKey)&$($local:gaID)" `
			-Method 'POST' -Headers $local:gaHeaders `
			-Body $local:gaBody `
			-TimeoutSec $script:timeoutSec
	} catch { Write-Debug 'Failed to collect statistics'
	} finally { $progressPreference = 'Continue' }

}

#endregion 環境

#region タイムスタンプ

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function getTimeStamp {
	[OutputType([System.Void])]
	Param ()

	$local:timeStamp = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'
	return $local:timeStamp
}

#----------------------------------------------------------------------
#UNIX時間をDateTime型に変換
#----------------------------------------------------------------------
function unixTimeToDateTime($unixTime) {
	$origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
	$origin.AddSeconds($unixTime)
}

#----------------------------------------------------------------------
#DateTime型をUNIX時間に変換
#----------------------------------------------------------------------
function dateTimeToUnixTime($dateTime) {
	$origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
	[Int]($dateTime - $origin).TotalSeconds
}

#endregion タイムスタンプ

#region 文字列操作

#----------------------------------------------------------------------
#ファイル名・ディレクトリ名に禁止文字の削除
#----------------------------------------------------------------------
function getFileNameWoInvChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[String]$local:Name
	)

	$local:invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
	$local:result = '[{0}]' -f [RegEx]::Escape($local:invalidChars)
	$local:Name = $local:Name -replace $local:result , ''

	#Linux/MacではGetInvalidFileNameChars()が不完全なため、ダメ押しで置換
	$local:Name = $local:Name.Replace('*', '-')
	$local:Name = $local:Name.Replace('?', '-')
	$local:Name = $local:Name.Replace('\', '-')
	$local:Name = $local:Name.Replace('/', '-')
	$local:Name = $local:Name.Replace('"', '-')
	$local:Name = $local:Name.Replace(':', '-')
	$local:Name = $local:Name.Replace('<', '-')
	$local:Name = $local:Name.Replace('>', '-')
	$local:Name = $local:Name.Replace('|', '-')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')
	$local:Name = $local:Name.Replace('', '')

	return $local:Name
}

#----------------------------------------------------------------------
#英数のみ全角→半角(カタカナは全角)
#----------------------------------------------------------------------
function getNarrowChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$local:text)		#変換元テキストを引数に指定

	$local:wideKanaDaku = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ'
	$local:narrowKanaDaku = 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ'
	$local:wideKanaHanDaku = 'パピプペポ'
	$local:narrowKanaHanDaku = 'ﾊﾋﾌﾍﾎ'
	$local:wideKana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホ'
	$local:wideKana += 'マミムメモヤユヨラリルレロワヲン゛゜ァィゥェォャュョッ'
	$local:narrowKana = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝﾞﾟｧｨｩｪｫｬｭｮｯ'
	$local:wideNum = '０１２３４５６７８９'
	$local:narrowNum = '0123456789'
	$local:wideAlpha = 'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ'
	$local:wideAlpha += 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ'
	$local:narrowAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
	$local:wideSimbol = '＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：．，'
	$local:narrowSimbol = '@#$%^&*-+_/[]{}()<> \\";:.,'
	for ($i = 0; $i -lt $local:wideKanaDaku.Length; $i++) {
		$local:text = $local:text.Replace(
			$local:narrowKanaDaku[$i] + 'ﾞ', $local:wideKanaDaku[$i]
		)
	}
	for ($i = 0; $i -lt $local:wideKanaHanDaku.Length; $i++) {
		$local:text = $local:text.Replace(
			$local:narrowKanaHanDaku[$i] + 'ﾟ', $local:narrowKanaHanDaku[$i]
		)
	}
	for ($i = 0; $i -lt $local:wideKana.Length; $i++) {
		$local:text = $local:text.Replace(
			$local:narrowKana[$i], $local:wideKana[$i]
		)
	}
	for ($i = 0; $i -lt $local:narrowNum.Length; $i++) {
		$local:text = $local:text.Replace(
			$local:wideNum[$i], $local:narrowNum[$i]
		)
	}
	for ($i = 0; $i -lt $local:narrowAlpha.Length; $i++) {
		$local:text = $local:text.Replace(
			$local:wideAlpha[$i], $local:narrowAlpha[$i]
		)
	}
	for ($i = 0; $i -lt $local:narrowSimbol.Length; $i++) {
		$local:text = $local:text.Replace(
			$local:wideSimbol[$i], $local:narrowSimbol[$i]
		)
	}
	return $local:text
}

#----------------------------------------------------------------------
#いくつかの特殊文字を置換
#----------------------------------------------------------------------
function getSpecialCharacterReplaced {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$local:text)		#変換元テキストを引数に指定

	$local:text = $local:text.Replace('&amp;', '&')
	$local:text = $local:text.Replace('*', '＊')
	$local:text = $local:text.Replace('|', '｜')
	$local:text = $local:text.Replace(':', '：')
	$local:text = $local:text.Replace(';', '；')
	$local:text = $local:text.Replace('"', '')	#削除
	$local:text = $local:text.Replace('“', '')	#削除
	$local:text = $local:text.Replace('”', '')	#削除
	$local:text = $local:text.Replace(',', '')	#削除
	$local:text = $local:text.Replace('?', '？')
	$local:text = $local:text.Replace('!', '！')
	$local:text = $local:text.Replace('/', '-')	#代替文字
	$local:text = $local:text.Replace('\', '-')	#代替文字
	$local:text = $local:text.Replace('<', '＜')
	$local:text = $local:text.Replace('>', '＞')
	return $local:text
}

#----------------------------------------------------------------------
#タブとスペースを詰めて半角スペース1文字に
#----------------------------------------------------------------------
function trimTabSpace {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$local:text)		#変換元テキストを引数に指定

	return $local:text.Replace("`t", ' ').Replace('  ', ' ')
}

#----------------------------------------------------------------------
#設定ファイルの行末コメントを削除
#----------------------------------------------------------------------
function trimComment {
	[OutputType([String])]
	Param ([String]$local:text)		#変換元テキストを引数に指定

	return $local:text.Split("`t")[0].Split(' ')[0].Split('#')[0]
}

#endregion 文字列操作

#region ファイル操作

#----------------------------------------------------------------------
#指定したPath配下の指定した条件でファイルを削除
#----------------------------------------------------------------------
function deleteFiles {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[parameter(Mandatory = $true, Position = 0)]
		[Alias('Path')]
		[System.IO.FileInfo]$local:basePath,

		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Conditions')]
		[Object]$local:delConditions,

		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('DatePast')]
		[int32]$local:delPeriod
	)

	try {
		foreach ($local:delCondition in $local:delConditions.Split(',').Trim()) {
			Write-Output "$($local:basePath) - $($local:delCondition)"
			$null = Get-ChildItem -LiteralPath $local:basePath -Recurse -File -Filter $local:delCondition `
			| Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($local:delPeriod) } `
			| Remove-Item -Force -ErrorAction SilentlyContinue `

  }
	} catch { Write-Warning '　削除できないファイルがありました' }

}

#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
function unZip {
	[CmdletBinding()]
	[OutputType([System.Void])]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('File')]
		[String]$zipArchive,
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('OutPath')]
		[String]$path
	)
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipArchive, $path)
}

#----------------------------------------------------------------------
#ディレクトリの上書き
#----------------------------------------------------------------------
function moveItem() {
	[CmdletBinding()]
	[OutputType([System.Void])]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Path')]
		[String]$src,
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Destination')]
		[String]$dist
	)

	if ((Test-Path $dist) -And (Test-Path -PathType Container $src)) {
		# ディレクトリ上書き(移動先に存在 かつ ディレクトリ)は再帰的に moveItem 呼び出し
		Get-ChildItem `
			-Path $src `
		| ForEach-Object { moveItem $_.FullName $($dist + '\' + $_.Name) }
		# 移動し終わったディレクトリを削除
		Remove-Item `
			-Path $src `
			-Recurse `
			-Force
	} else {
		# 移動先に対象なし または ファイルの Move-Item に -Forece つけて実行
		Write-Output "$src  →  $dist"
		Move-Item `
			-Path $src `
			-Destination $dist `
			-Force
	}
}

#endregion ファイル操作

#region ファイルロック

#----------------------------------------------------------------------
#ファイルのロック
#----------------------------------------------------------------------
function fileLock {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true, Position = 0)]
		[Alias('Path')]
		[System.IO.FileInfo]$local:Path
	)

	try {
		$local:fileLocked = $false
		# attempt to open file and detect file lock
		$script:fileInfo = New-Object System.IO.FileInfo $local:Path
		$script:fileStream = $script:fileInfo.Open(
			[System.IO.FileMode]::OpenOrCreate, `
				[System.IO.FileAccess]::ReadWrite, `
				[System.IO.FileShare]::None
		)
		$local:fileLocked = $true
	} catch { $fileLocked = $false
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $local:Path
			fileLocked = $local:fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのアンロック
#----------------------------------------------------------------------
function fileUnlock {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true, Position = 0)]
		[Alias('Path')]
		[System.IO.FileInfo]$local:Path
	)

	try {
		# close stream if not lock
		if ($script:fileStream) { $script:fileStream.Close() }
		$local:fileLocked = $false
	} catch { $local:fileLocked = $true
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $local:Path
			fileLocked = $local:fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのロック確認
#----------------------------------------------------------------------
function isLocked {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true, Position = 0)]
		[Alias('Path')]
		[String]$local:isLockedPath
	)

	try {
		$local:isFileLocked = $false
		# attempt to open file and detect file lock
		$local:isLockedFileInfo = New-Object System.IO.FileInfo $local:isLockedPath
		$local:isLockedfileStream = $local:isLockedFileInfo.Open(
			[System.IO.FileMode]::OpenOrCreate, `
				[System.IO.FileAccess]::ReadWrite, `
				[System.IO.FileShare]::None
		)
		# close stream if not lock
		if ($local:isLockedfileStream) { $local:isLockedfileStream.Close() }
		$local:isFileLocked = $false
	} catch { $local:isFileLocked = $true
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $local:isLockedPath
			fileLocked = $local:isFileLocked
		}
	}
}

#endregion ファイルロック

#region コンソール出力

#----------------------------------------------------------------------
#色付きWrite-Output
#----------------------------------------------------------------------
function Out-Msg-Color {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('Text')]
		[Object]$local:text,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Fg')]
		[ConsoleColor]$local:foregroundColor,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Bg')]
		[ConsoleColor]$local:backgroundColor,

		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('NoNL')]
		[Boolean]$local:noLF
	)

	# Save previous colors
	$local:prevForegroundColor = $host.UI.RawUI.ForegroundColor
	$local:prevBackgroundColor = $host.UI.RawUI.BackgroundColor

	# Set colors if available
	if ($local:backgroundColor -ne $null) {	$host.UI.RawUI.BackgroundColor = $local:backgroundColor }
	if ($local:foregroundColor -ne $null) {	$host.UI.RawUI.ForegroundColor = $local:foregroundColor	}

	# Always write (if we want just a NewLine)
	if ($null -eq $local:text) { $local:text = '' }

	if ($local:noLF -eq $true) { Write-Host -NoNewline $local:text }
	else { Write-Host $local:text }

	# Restore previous colors
	$host.UI.RawUI.ForegroundColor = $local:prevForegroundColor
	$host.UI.RawUI.BackgroundColor = $local:prevBackgroundColor
}

#endregion コンソール出力

#region トースト通知

#Toast用AppID取得に必要
if ($IsWindows) { Import-Module StartLayout -SkipEditionCheck }

#----------------------------------------------------------------------
#Windows Application ID取得
#----------------------------------------------------------------------
function Get-WindowsAppId {
	[OutputType([String])]
	Param ()

	$local:appID = (Get-StartApps -Name 'PowerShell').`
		where({ $_.Name -like 'PowerShell*' })[0].AppId

	return $local:appID
}

#----------------------------------------------------------------------
#トースト表示
#----------------------------------------------------------------------
function showToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Text1')]
		[String]$local:toastText1,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Text2')]
		[String]$local:toastText2,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Duration')]
		[ValidateSet('Short', 'Long')]
		[String]$local:toastDuration,

		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('Silent')]
		[Boolean]$local:toastSilent
	)

	if ($IsWindows) {
		if ($local:toastSilent) {
			$local:toastSoundElement = `
				'<audio silent="true" />'
		} else {
			$local:toastSoundElement = `
				'<audio src="ms-winsoundevent:Notification.Default" loop="false"/>'
		}

		if (!($local:toastDuration)) { $local:toastDuration = 'short' }
		$local:toastTitle = $script:appName
		$local:toastAttribution = ''
		$local:toastAppLogo = $script:toastAppLogo

		if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
			#For PowerShell Core v6.x & PowerShell v7+
			Add-Type -Path (Join-Path $script:libDir './win/core/Microsoft.Windows.SDK.NET.dll')
			Add-Type -Path (Join-Path $script:libDir './win/core/WinRT.Runtime.dll')
			Add-Type -Path (Join-Path $script:libDir './win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
		}

		$local:toastProgressContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$local:toastDuration">
	<visual>
		<binding template="ToastGeneric">
			<text>$local:toastTitle</text>
			<text>$local:toastText1</text>
			<text>$local:toastText2</text>
			<image placement="appLogoOverride" src="$local:toastAppLogo"/>
			<text placement="attribution">$local:toastAttribution</text>
		</binding>
	</visual>
	$local:toastSoundElement
</toast>
"@

		$local:appID = Get-WindowsAppId
		$local:toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
		$local:toastXML.LoadXml($local:toastProgressContent)
		$local:toastBody = New-Object Windows.UI.Notifications.ToastNotification $local:toastXML
		$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).`
			Show($local:toastBody)
	}
}


#----------------------------------------------------------------------
#進捗バー付きトースト表示
#----------------------------------------------------------------------
function showProgressToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Text1')]
		[String]$local:toastText1,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Text2')]
		[String]$local:toastText2,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('WorkDetail')]
		[String]$local:toastWorkDetail,

		[Parameter(Mandatory = $true, Position = 3)]
		[Alias('Tag')]
		[String]$local:toastTag,

		[Parameter(Mandatory = $true, Position = 4)]
		[Alias('Group')]
		[String]$local:toastGroup,

		[Parameter(Mandatory = $false, Position = 5)]
		[ValidateSet('Short', 'Long')]
		[Alias('Duration')]
		[String]$local:toastDuration,

		[Parameter(Mandatory = $false, Position = 6)]
		[Alias('Silent')]
		[Boolean]$local:toastSilent
	)

	if ($IsWindows) {
		if ($local:toastSilent) {
			$local:toastSoundElement = '<audio silent="true" />'
		} else {
			$local:toastSoundElement = '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>'
		}

		if (!($local:toastDuration)) { $local:toastDuration = 'short' }
		$local:toastTitle = $script:appName
		$local:toastAttribution = ''
		$local:toastAppLogo = $script:toastAppLogo

		if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
			#For PowerShell Core v6.x & PowerShell v7+
			Add-Type -Path (Join-Path $script:libDir './win/core/Microsoft.Windows.SDK.NET.dll')
			Add-Type -Path (Join-Path $script:libDir './win/core/WinRT.Runtime.dll')
			Add-Type -Path (Join-Path $script:libDir './win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
		}

		$local:toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$local:toastDuration">
	<visual>
		<binding template="ToastGeneric">
			<text>$local:toastTitle</text>
			<text>$local:toastText1</text>
			<text>$local:toastText2</text>
			<image placement="appLogoOverride" src="$local:toastAppLogo"/>
			<progress value="{progressValue}" title="{progressTitle}" valueStringOverride="{progressValueString}" status="{progressStatus}" />
			<text placement="attribution">$($local:toastAttribution)</text>
		</binding>
	</visual>
	$local:toastSoundElement
</toast>
"@

		$local:appID = Get-WindowsAppId
		$local:toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
		$local:toastXML.LoadXml($local:toastContent)
		$local:toast = New-Object Windows.UI.Notifications.ToastNotification $local:toastXML
		$local:toast.Tag = $local:toastTag
		$local:toast.Group = $local:toastGroup
		$local:toastData = New-Object 'system.collections.generic.dictionary[String,string]'
		$local:toastData.add('progressTitle', $local:toastWorkDetail)
		$local:toastData.add('progressValue', '')
		$local:toastData.add('progressValueString', '')
		$local:toastData.add('progressStatus', '')
		$local:toast.Data = [Windows.UI.Notifications.NotificationData]::new($local:toastData)
		$local:toast.Data.SequenceNumber = 1
		$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).`
			Show($local:toast)
	}
}

#----------------------------------------------------------------------
#進捗バー付きトースト更新
#----------------------------------------------------------------------
function updateProgressToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('Title')]
		[String]$local:toastTitle,

		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Rate')]
		[String]$local:toastRate,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('LeftText')]
		[String]$local:toastLeftText,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('RightText')]
		[String]$local:toastRightText,

		[Parameter(Mandatory = $true, Position = 4)]
		[Alias('Tag')]
		[String]$local:toastTag,

		[Parameter(Mandatory = $true, Position = 5)]
		[Alias('Group')]
		[String]$local:toastGroup
	)

	if ($IsWindows) {
		$local:appID = Get-WindowsAppId
		$local:toastData = New-Object 'system.collections.generic.dictionary[String,string]'
		$local:toastData.add('progressTitle', $local:toastTitle)
		$local:toastData.add('progressValue', $local:toastRate)
		$local:toastData.add('progressValueString', $local:toastRightText)
		$local:toastData.add('progressStatus', $local:toastLeftText)
		$local:toastProgressData = [Windows.UI.Notifications.NotificationData]::new($local:toastData)
		$local:toastProgressData.SequenceNumber = 2
		$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).`
			Update($local:toastProgressData, $local:toastTag , $local:toastGroup)
	}
}

#----------------------------------------------------------------------
#進捗バー付きトースト表示
#----------------------------------------------------------------------
function showProgressToast2 {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Text1')]
		[String]$local:toastText1,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Text2')]
		[String]$local:toastText2,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('WorkDetail1')]
		[String]$local:toastWorkDetail1,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('WorkDetail2')]
		[String]$local:toastWorkDetail2,

		[Parameter(Mandatory = $true, Position = 4)]
		[Alias('Tag')]
		[String]$local:toastTag,

		[Parameter(Mandatory = $true, Position = 5)]
		[Alias('Group')]
		[String]$local:toastGroup,

		[Parameter(Mandatory = $false, Position = 6)]
		[ValidateSet('Short', 'Long')]
		[Alias('Duration')]
		[String]$local:toastDuration,

		[Parameter(Mandatory = $false, Position = 7)]
		[Alias('Silent')]
		[Boolean]$local:toastSilent
	)

	if ($IsWindows) {
		if ($local:toastSilent) {
			$local:toastSoundElement = '<audio silent="true" />'
		} else {
			$local:toastSoundElement = '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>'
		}

		if (!($local:toastDuration)) { $local:toastDuration = 'short' }
		$local:toastTitle = $script:appName
		$local:toastAttribution = ''
		$local:toastAppLogo = $script:toastAppLogo

		if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
			#For PowerShell Core v6.x & PowerShell v7+
			Add-Type -Path (Join-Path $script:libDir './win/core/Microsoft.Windows.SDK.NET.dll')
			Add-Type -Path (Join-Path $script:libDir './win/core/WinRT.Runtime.dll')
			Add-Type -Path (Join-Path $script:libDir './win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
		}

		$local:toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$local:toastDuration">
	<visual>
		<binding template="ToastGeneric">
			<text>$local:toastTitle</text>
			<text>$local:toastText1</text>
			<text>$local:toastText2</text>
			<image placement="appLogoOverride" src="$local:toastAppLogo"/>
			<progress value="{progressValue1}" title="{progressTitle1}" valueStringOverride="{progressValueString1}" status="{progressStatus1}" />
			<progress value="{progressValue2}" title="{progressTitle2}" valueStringOverride="{progressValueString2}" status="{progressStatus2}" />
			<text placement="attribution">$($local:toastAttribution)</text>
		</binding>
	</visual>
	$local:toastSoundElement
</toast>
"@

		$local:appID = Get-WindowsAppId
		$local:toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
		$local:toastXML.LoadXml($local:toastContent)
		$local:toast = New-Object Windows.UI.Notifications.ToastNotification $local:toastXML
		$local:toast.Tag = $local:toastTag
		$local:toast.Group = $local:toastGroup
		$local:toastData = New-Object 'system.collections.generic.dictionary[String,string]'
		$local:toastData.add('progressTitle1', $local:toastWorkDetail1)
		$local:toastData.add('progressValue1', '')
		$local:toastData.add('progressValueString1', '')
		$local:toastData.add('progressStatus1', '')
		$local:toastData.add('progressTitle2', $local:toastWorkDetail2)
		$local:toastData.add('progressValue2', '')
		$local:toastData.add('progressValueString2', '')
		$local:toastData.add('progressStatus2', '')
		$local:toast.Data = [Windows.UI.Notifications.NotificationData]::new($local:toastData)
		$local:toast.Data.SequenceNumber = 1
		$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).`
			Show($local:toast)
	}
}

#----------------------------------------------------------------------
#進捗バー付きトースト更新
#----------------------------------------------------------------------
function updateProgressToast2 {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('Title1')]
		[String]$local:toastTitle1,

		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Rate1')]
		[String]$local:toastRate1,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('LeftText1')
		][String]$local:toastLeftText1,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('RightText1')]
		[String]$local:toastRightText1,

		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('Title2')]
		[String]$local:toastTitle2,

		[Parameter(Mandatory = $true, Position = 5)]
		[Alias('Rate2')]
		[String]$local:toastRate2,

		[Parameter(Mandatory = $false, Position = 6)]
		[Alias('LeftText2')]
		[String]$local:toastLeftText2,

		[Parameter(Mandatory = $false, Position = 7)]
		[Alias('RightText2')]
		[String]$local:toastRightText2,

		[Parameter(Mandatory = $true, Position = 8)]
		[Alias('Tag')]
		[String]$local:toastTag,

		[Parameter(Mandatory = $true, Position = 9)]
		[Alias('Group')]
		[String]$local:toastGroup
	)

	if ($IsWindows) {
		$local:appID = Get-WindowsAppId
		$local:toastData = New-Object 'system.collections.generic.dictionary[String,string]'
		$local:toastData.add('progressTitle1', $local:toastTitle1)
		$local:toastData.add('progressValue1', $local:toastRate1)
		$local:toastData.add('progressValueString1', $local:toastRightText1)
		$local:toastData.add('progressStatus1', $local:toastLeftText1)
		$local:toastData.add('progressTitle2', $local:toastTitle2)
		$local:toastData.add('progressValue2', $local:toastRate2)
		$local:toastData.add('progressValueString2', $local:toastRightText2)
		$local:toastData.add('progressStatus2', $local:toastLeftText2)
		$local:toastProgressData = [Windows.UI.Notifications.NotificationData]::new($local:toastData)
		$local:toastProgressData.SequenceNumber = 2
		$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).`
			Update($local:toastProgressData, $local:toastTag , $local:toastGroup)
	}
}

#----------------------------------------------------------------------
#進捗表示
#----------------------------------------------------------------------
function showProgress2Row {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('ProgressText1')]
		[String]$local:progressText1,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('ProgressText2')]
		[String]$local:progressText2,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('WorkDetail1')]
		[String]$local:toastWorkDetail1,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('WorkDetail2')]
		[String]$local:toastWorkDetail2,

		[Parameter(Mandatory = $false, Position = 4)]
		[ValidateSet('Short', 'Long')]
		[Alias('Duration')]
		[String]$local:toastDuration,

		[Parameter(Mandatory = $false, Position = 5)]
		[Alias('Silent')]
		[Boolean]$local:toastSilent,

		[Parameter(Mandatory = $true, Position = 6)]
		[Alias('Group')]
		[String]$local:toastGroup
	)

	if (!($local:progressText2)) { $local:progressText2 = '' }
	if (!($local:toastWorkDetail1)) { $local:toastWorkDetail1 = '' }
	if (!($local:toastWorkDetail2)) { $local:toastWorkDetail2 = '' }

	showProgressToast2 `
		-Text1 $local:progressText1 `
		-Text2 $local:progressText2 `
		-WorkDetail1 $local:toastWorkDetail1 `
		-WorkDetail2 $local:toastWorkDetail2 `
		-Tag $script:appName `
		-Group $local:toastGroup `
		-Duration $local:toastDuration `
		-Silent $local:toastSilent
}

#----------------------------------------------------------------------
#進捗更新
#----------------------------------------------------------------------
function updateProgress2Row {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('ProgressActivity1')]
		[String]$local:progressActivity1,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('CurrentProcessing1')]
		[String]$local:currentProcessing1,

		[Parameter(Mandatory = $true, Position = 2)]
		[Alias('Rate1')]
		[String]$local:progressRatio1,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('SecRemaining1')]
		[String]$local:secRemaining1,

		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('ProgressActivity2')]
		[String]$local:progressActivity2,

		[Parameter(Mandatory = $false, Position = 5)]
		[Alias('CurrentProcessing2')]
		[String]$local:currentProcessing2,

		[Parameter(Mandatory = $true, Position = 6)]
		[Alias('Rate2')]
		[String]$local:progressRatio2,

		[Parameter(Mandatory = $false, Position = 7)]
		[Alias('SecRemaining2')]
		[String]$local:secRemaining2,

		[Parameter(Mandatory = $true, Position = 8)]
		[Alias('Group')]
		[String]$local:toastGroup
	)

	if ($local:secRemaining1 -eq -1 -Or $local:secRemaining1 -eq '' ) { $local:minRemaining1 = '計算中...' }
	else { $local:minRemaining1 = "$([String]([math]::Ceiling($local:secRemaining1 / 60)))分" }

	if ($local:secRemaining2 -eq -1 -Or $local:secRemaining2 -eq '' ) { $local:minRemaining2 = '計算中...' }
	else { $local:minRemaining2 = "$([String]([math]::Ceiling($local:secRemaining2 / 60)))分" }

	if ($local:secRemaining1 -ne '') { $local:secRemaining1 = "残り時間 $local:minRemaining1" }
	if ($local:secRemaining2 -ne '') { $local:secRemaining2 = "残り時間 $local:minRemaining2" }

	updateProgressToast2 `
		-Title1 $local:currentProcessing1 `
		-Rate1 $local:progressRatio1 `
		-LeftText1 $local:progressActivity1 `
		-RightText1 $local:minRemaining1 `
		-Title2 $local:currentProcessing2 `
		-Rate2 $local:progressRatio2 `
		-LeftText2 $local:progressActivity2 `
		-RightText2 $local:secRemaining2 `
		-Tag $script:appName `
		-Group $local:toastGroup
}

#endregion トースト通知
