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

Write-Debug $myInvocation.MyCommand.name

#region タイムスタンプ

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function getTimeStamp {
	[OutputType([System.Void])]
	Param ()

	Write-Debug $myInvocation.MyCommand.name

	$local:timeStamp = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'
	return $local:timeStamp
}

#----------------------------------------------------------------------
#UNIX時間をDateTime型に変換
#----------------------------------------------------------------------
function unixTimeToDateTime($unixTime) {
	Write-Debug $myInvocation.MyCommand.name

	$origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
	$origin.AddSeconds($unixTime)
}

#----------------------------------------------------------------------
#DateTime型をUNIX時間に変換
#----------------------------------------------------------------------
function dateTimeToUnixTime($dateTime) {
	Write-Debug $myInvocation.MyCommand.name

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

	Write-Debug $myInvocation.MyCommand.name

	$local:invalidChars = [IO.Path]::GetInvalidFileNameChars() -Join ''
	$local:result = '[{0}]' -f [RegEx]::Escape($local:invalidChars)
	$local:Name = $local:Name.Replace($local:result , '')

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
	Param ([String]$local:text)

	Write-Debug $myInvocation.MyCommand.name

	$local:wideKanaDaku = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ'
	$local:narrowKanaDaku = 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ'
	$local:wideKanaHanDaku = 'パピプペポ'
	$local:narrowKanaHanDaku = 'ﾊﾋﾌﾍﾎ'
	$local:wideKana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン゛゜ァィゥェォャュョッ'
	$local:narrowKana = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝﾞﾟｧｨｩｪｫｬｭｮｯ'
	$local:wideNum = '０１２３４５６７８９'
	$local:narrowNum = '0123456789'
	$local:wideAlpha = 'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ'
	$local:narrowAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
	$local:wideSimbol = '＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：．，'
	$local:narrowSimbol = '@#$%^&*-+_/[]{}()<> \\";:.,'

	for ($i = 0; $i -lt $local:narrowKanaDaku.Length; $i++) {
		$local:text = $local:text.Replace($local:narrowKanaDaku[$i] + 'ﾞ', $local:wideKanaDaku[$i])
	}
	for ($i = 0; $i -lt $local:narrowKanaHanDaku.Length; $i++) {
		$local:text = $local:text.Replace($local:narrowKanaHanDaku[$i] + 'ﾟ', $local:wideKanaHanDaku[$i])
	}
	for ($i = 0; $i -lt $local:narrowKana.Length; $i++) {
		$local:text = $local:text.Replace($local:narrowKana[$i], $local:wideKana[$i])
	}
	for ($i = 0; $i -lt $local:wideNum.Length; $i++) {
		$local:text = $local:text.Replace($local:wideNum[$i], $local:narrowNum[$i])
	}
	for ($i = 0; $i -lt $local:wideAlpha.Length; $i++) {
		$local:text = $local:text.Replace($local:wideAlpha[$i], $local:narrowAlpha[$i])
	}
	for ($i = 0; $i -lt $local:wideSimbol.Length; $i++) {
		$local:text = $local:text.Replace($local:wideSimbol[$i], $local:narrowSimbol[$i])
	}

	return $local:text
}

#----------------------------------------------------------------------
#いくつかの特殊文字を置換
#----------------------------------------------------------------------
function getSpecialCharacterReplaced {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$local:text)

	Write-Debug $myInvocation.MyCommand.name

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
	Param ([String]$local:text)

	Write-Debug $myInvocation.MyCommand.name

	return $local:text.Replace("`t", ' ').Replace('  ', ' ')
}

#----------------------------------------------------------------------
#設定ファイルの行末コメントを削除
#----------------------------------------------------------------------
function trimComment {
	[OutputType([String])]
	Param ([String]$local:text)

	Write-Debug $myInvocation.MyCommand.name

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

	Write-Debug $myInvocation.MyCommand.name

	if ($script:enableMultithread -eq $true) {
		#並列化が有効の場合は並列化
		try {
			$local:delConditions.Split(',').Trim() | ForEach-Object -Parallel {
				Write-Output ('　' + (Join-Path $using:local:basePath $_))
				$null = Get-ChildItem -LiteralPath $using:local:basePath -Recurse -File -Filter $_ -ErrorAction SilentlyContinue `
				| Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($using:local:delPeriod) } `
				| Remove-Item -Force -ErrorAction SilentlyContinue
			} -ThrottleLimit $script:multithreadNum
		} catch { Write-Warning '❗ 削除できないファイルがありました' }
	} else {
		#並列化が無効の場合は従来型処理
		try {
			foreach ($local:delCondition in $local:delConditions.Split(',').Trim()) {
				Write-Output ('　' + (Join-Path $local:basePath $local:delCondition))
				$null = Get-ChildItem -LiteralPath $local:basePath -Recurse -File -Filter $local:delCondition -ErrorAction SilentlyContinue `
				| Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($local:delPeriod) } `
				| Remove-Item -Force -ErrorAction SilentlyContinue
			}
		} catch { Write-Warning '❗ 削除できないファイルがありました' }
	}

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

	Write-Debug $myInvocation.MyCommand.name

	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipArchive, $path, $true)
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
		[String]$local:src,
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Destination')]
		[String]$local:dist
	)

	Write-Debug $myInvocation.MyCommand.name

	if ((Test-Path $local:dist) -And (Test-Path -PathType Container $local:src)) {
		# ディレクトリ上書き(移動先に存在 かつ ディレクトリ)は再帰的に moveItem 呼び出し
		foreach ($local:srcChild in (Get-ChildItem -Path $local:src)) {
			moveItem -Force -Path $local:srcChild.FullName -Destination ($local:dist + '/' + $local:srcChild.Name)
		}
		# 移動し終わったディレクトリを削除
		Remove-Item -Path $local:src -Recurse -Force
	} else {
		# 移動先に対象なし または ファイルの Move-Item に -Forece つけて実行
		Write-Output ($local:src + '  →  ' + $local:dist)
		Move-Item -Path $local:src -Destination $local:dist -Force
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

	Write-Debug ($myInvocation.MyCommand.name + ' - ' + $local:Path)

	try {
		$local:fileLocked = $false
		# attempt to open file and detect file lock
		$script:fileInfo = New-Object System.IO.FileInfo $local:Path
		$script:fileStream = $script:fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		$local:fileLocked = $true
	} catch { $local:fileLocked = $false
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

	Write-Debug ($myInvocation.MyCommand.name + ' - ' + $local:Path)

	try {
		# close stream if not lock
		if ($script:fileStream) { $script:fileStream.Close() }
		$local:fileLocked = $false
		$script:fileStream.Dispose()
		$script:fileInfo.Dispose()
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

	Write-Debug ($myInvocation.MyCommand.name + ' - ' + $local:Path)

	try {
		$local:isFileLocked = $false
		# attempt to open file and detect file lock
		$local:isLockedFileInfo = New-Object System.IO.FileInfo $local:isLockedPath
		$local:isLockedfileStream = $local:isLockedFileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
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

	Write-Debug $myInvocation.MyCommand.name

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
if (($script:disableToastNotification -ne $true) -And ($IsWindows)) { Import-Module StartLayout -SkipEditionCheck }

#----------------------------------------------------------------------
#Windows Application ID取得
#----------------------------------------------------------------------
function Get-WindowsAppId {
	[OutputType([String])]
	Param ()

	Write-Debug $myInvocation.MyCommand.name

	$local:appID = (Get-StartApps -Name 'PowerShell').where({ $_.Name -like 'PowerShell*' })[0].AppId

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

	Write-Debug $myInvocation.MyCommand.name

	if ($script:disableToastNotification -ne $true) {
		if ($IsWindows) {
			if ($local:toastSilent) { $local:toastSoundElement = '<audio silent="true" />' }
			else { $local:toastSoundElement = '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
			if (!($local:toastDuration)) { $local:toastDuration = 'short' }
			$local:toastAttribution = ''
			if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
				#For PowerShell Core v6.x & PowerShell v7+
				Add-Type -Path (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll')
				Add-Type -Path (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll')
				Add-Type -Path (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
			}
			$local:toastProgressContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$local:toastDuration">
	<visual>
		<binding template="ToastGeneric">
			<text>$script:appName</text>
			<text>$local:toastText1</text>
			<text>$local:toastText2</text>
			<image placement="appLogoOverride" src="$script:toastAppLogo"/>
			<text placement="attribution">$local:toastAttribution</text>
		</binding>
	</visual>
	$local:toastSoundElement
</toast>
"@
			$local:appID = Get-WindowsAppId
			$local:toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
			$local:toastXML.LoadXml($local:toastProgressContent)
			$local:toastText2 = New-Object Windows.UI.Notifications.ToastNotification $local:toastXML
			$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Show($local:toastText2)
		} elseif ($IsMacOS) {
			if (Get-Command osascript -ea SilentlyContinue) {
				$local:toastParams = 'display notification "' + $local:toastText2 + '" with title "' + $script:appName + '" subtitle "' + $local:toastText1 + '" sound name "Blow"'
				$local:toastParams | & osascript
			}
		} elseif ($IsLinux) {
			if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $local:toastText1 $local:toastText2 }
		}
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

	Write-Debug $myInvocation.MyCommand.name

	if ($script:disableToastNotification -ne $true) {
		if ($IsWindows) {
			if ($local:toastSilent) { $local:toastSoundElement = '<audio silent="true" />' }
			else { $local:toastSoundElement = '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
			if (!($local:toastDuration)) { $local:toastDuration = 'short' }
			$local:toastAttribution = ''
			if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
				#For PowerShell Core v6.x & PowerShell v7+
				Add-Type -Path (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll')
				Add-Type -Path (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll')
				Add-Type -Path (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
			}
			$local:toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$local:toastDuration">
	<visual>
		<binding template="ToastGeneric">
			<text>$script:appName</text>
			<text>$local:toastText1</text>
			<text>$local:toastText2</text>
			<image placement="appLogoOverride" src="$script:toastAppLogo"/>
			<progress value="{progressValue}" title="{progressTitle}" valueStringOverride="{progressValueString}" status="{progressStatus}" />
			<text placement="attribution">$local:toastAttribution</text>
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
			$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Show($local:toast)
		} elseif ($IsMacOS) {
			if (Get-Command osascript -ea SilentlyContinue) {
				$local:toastParams = 'display notification "' + $local:toastText2 + '" with title "' + $script:appName + '" subtitle "' + $local:toastText1 + '" sound name "Blow"'
				$local:toastParams | & osascript
			}
		} elseif ($IsLinux) {
			if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $local:toastText1 $local:toastText2 }
		}
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

	Write-Debug $myInvocation.MyCommand.name

	if ($script:disableToastNotification -ne $true) {
		if ($IsWindows) {
			$local:appID = Get-WindowsAppId
			$local:toastData = New-Object 'system.collections.generic.dictionary[String,string]'
			$local:toastData.add('progressTitle', $script:appName)
			$local:toastData.add('progressValue', $local:toastRate)
			$local:toastData.add('progressValueString', $local:toastRightText)
			$local:toastData.add('progressStatus', $local:toastLeftText)
			$local:toastProgressData = [Windows.UI.Notifications.NotificationData]::new($local:toastData)
			$local:toastProgressData.SequenceNumber = 2
			$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Update($local:toastProgressData, $local:toastTag , $local:toastGroup)
		} elseif ($IsMacOS) {
			#1ディレクトリ毎に出てしまうため表示しない(Delete時)
		} elseif ($IsLinux) {
			#1ディレクトリ毎に出てしまうため表示しない(Delete時)
		}
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

	Write-Debug $myInvocation.MyCommand.name

	if ($script:disableToastNotification -ne $true) {
		if ($IsWindows) {
			if ($local:toastSilent) { $local:toastSoundElement = '<audio silent="true" />' }
			else { $local:toastSoundElement = '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
			if (!($local:toastDuration)) { $local:toastDuration = 'short' }
			$local:toastAttribution = ''
			if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
				#For PowerShell Core v6.x & PowerShell v7+
				Add-Type -Path (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll')
				Add-Type -Path (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll')
				Add-Type -Path (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
			}
			$local:toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$local:toastDuration">
	<visual>
		<binding template="ToastGeneric">
			<text>$script:appName</text>
			<text>$local:toastText1</text>
			<text>$local:toastText2</text>
			<image placement="appLogoOverride" src="$script:toastAppLogo"/>
			<progress value="{progressValue1}" title="{progressTitle1}" valueStringOverride="{progressValueString1}" status="{progressStatus1}" />
			<progress value="{progressValue2}" title="{progressTitle2}" valueStringOverride="{progressValueString2}" status="{progressStatus2}" />
			<text placement="attribution">$local:toastAttribution</text>
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
			$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Show($local:toast)
		} elseif ($IsMacOS) {
			if (Get-Command osascript -ea SilentlyContinue) {
				$local:toastParams = 'display notification "' + $local:toastText2 + '" with title "' + $script:appName + '" subtitle "' + $local:toastText1 + '" sound name "Blow"'
				$local:toastParams | & osascript
			}
		} elseif ($IsLinux) {
			if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $local:toastText1 $local:toastText2 }
		}
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

	Write-Debug $myInvocation.MyCommand.name

	if ($script:disableToastNotification -ne $true) {
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
			$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Update($local:toastProgressData, $local:toastTag , $local:toastGroup)
		} elseif ($IsMacOS) {
			#1キーワード毎に出てしまうため表示しない(Bulk時)
		} elseif ($IsLinux) {
			#1キーワード毎に出てしまうため表示しない(Bulk時)
		}
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

	Write-Debug $myInvocation.MyCommand.name
	if ($script:disableToastNotification -ne $true) {
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

	Write-Debug $myInvocation.MyCommand.name

	if ($script:disableToastNotification -ne $true) {
		if ($local:secRemaining1 -eq -1 -Or $local:secRemaining1 -eq '' ) { $local:minRemaining1 = '計算中...' }
		else { $local:minRemaining1 = [String]([math]::Ceiling($local:secRemaining1 / 60)) + '分' }
		if ($local:secRemaining2 -eq -1 -Or $local:secRemaining2 -eq '' ) { $local:minRemaining2 = '計算中...' }
		else { $local:minRemaining2 = [String]([math]::Ceiling($local:secRemaining2 / 60)) + '分' }
		if ($local:secRemaining1 -ne '') { $local:secRemaining1 = '残り時間 ' + $local:minRemaining1 }
		if ($local:secRemaining2 -ne '') { $local:secRemaining2 = '残り時間 ' + $local:minRemaining2 }
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
}

#endregion トースト通知
