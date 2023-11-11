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

Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
#GC
#----------------------------------------------------------------------
function Invoke-GarbageCollection() {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	Write-Verbose -Message 'Starting garbage collection...'
	[System.GC]::Collect()
	Write-Verbose -Message 'Waiting for pending finalizers...'
	[System.GC]::WaitForPendingFinalizers()
	Write-Verbose -Message 'Performing a final pass of garbage collection...'
	[System.GC]::Collect()
	Write-Verbose -Message 'Garbage collection completed.'
}

#region タイムスタンプ

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function Get-TimeStamp {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	return (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}

#----------------------------------------------------------------------
#UNIX時間をDateTime型に変換
#----------------------------------------------------------------------
function ConvertFrom-UnixTime {
	[CmdletBinding()]
	[OutputType([System.Void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][int64]$UnixTime
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$EpochDate = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0

	return ($EpochDate.AddSeconds($UnixTime).ToLocalTime())
}

#----------------------------------------------------------------------
#DateTime型をUNIX時間に変換
#----------------------------------------------------------------------
function ConvertTo-UnixTime {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)][DateTime]$InputDate
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$EpochDate = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0

	return ([Math]::Floor(($InputDate.ToUniversalTime() - $EpochDate).TotalSeconds))
}

#endregion タイムスタンプ

#region 文字列操作

#----------------------------------------------------------------------
#ファイル名・ディレクトリ名に禁止文字の削除
#----------------------------------------------------------------------
function Get-FileNameWithoutInvalidChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$Name
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$invalidChars = [IO.Path]::GetInvalidFileNameChars() -Join ''
	$resultPattern = '[{0}]' -f [Regex]::Escape($invalidChars)
	$Name = $Name.Replace($resultPattern , '')

	#Linux/MacではGetInvalidFileNameChars()が不完全なため、ダメ押しで置換
	$additionalReplaces = '[*\?<>|]'
	$additionalValidChar = '-'
	$Name = $Name -replace $additionalReplaces, $additionalValidChar
	$additionalReplaces = '[]'
	$additionalValidChar = ''
	$Name = $Name -replace $additionalReplaces, $additionalValidChar

	return $Name
}

#----------------------------------------------------------------------
#英数のみ全角→半角(カタカナは全角)
#----------------------------------------------------------------------
function Get-NarrowChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[String]$text
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$replaceChars = @{
		'０１２３４５６７８９'                                           = '0123456789'
		'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ' = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
		'＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：．，'                          = '@#$%^&*-+_/[]{}()<> \\";:.,'
	}
	foreach ($entry in $replaceChars.GetEnumerator()) {
		for ($i = 0; $i -lt $entry.Name.Length; $i++) {
			$text = $text.Replace($entry.Name[$i], $entry.Value[$i])
		}
	}

	$replacements = @{
		'ｱ'  = 'ア'
		'ｲ'  = 'イ'
		'ｳ'  = 'ウ'
		'ｴ'  = 'エ'
		'ｵ'  = 'オ'
		'ｶ'  = 'カ'
		'ｷ'  = 'キ'
		'ｸ'  = 'ク'
		'ｹ'  = 'ケ'
		'ｺ'  = 'コ'
		'ｻ'  = 'サ'
		'ｼ'  = 'シ'
		'ｽ'  = 'ス'
		'ｾ'  = 'セ'
		'ｿ'  = 'ソ'
		'ﾀ'  = 'タ'
		'ﾁ'  = 'チ'
		'ﾂ'  = 'ツ'
		'ﾃ'  = 'テ'
		'ﾄ'  = 'ト'
		'ﾅ'  = 'ナ'
		'ﾆ'  = 'ニ'
		'ﾇ'  = 'ヌ'
		'ﾈ'  = 'ネ'
		'ﾉ'  = 'ノ'
		'ﾊ'  = 'ハ'
		'ﾋ'  = 'ヒ'
		'ﾌ'  = 'フ'
		'ﾍ'  = 'ヘ'
		'ﾎ'  = 'ホ'
		'ﾏ'  = 'マ'
		'ﾐ'  = 'ミ'
		'ﾑ'  = 'ム'
		'ﾒ'  = 'メ'
		'ﾓ'  = 'モ'
		'ﾔ'  = 'ヤ'
		'ﾕ'  = 'ユ'
		'ﾖ'  = 'ヨ'
		'ﾗ'  = 'ラ'
		'ﾘ'  = 'リ'
		'ﾙ'  = 'ル'
		'ﾚ'  = 'レ'
		'ﾛ'  = 'ロ'
		'ﾜ'  = 'ワ'
		'ｦ'  = 'ヲ'
		'ﾝ'  = 'ン'
		'ｧ'  = 'ァ'
		'ｨ'  = 'ィ'
		'ｩ'  = 'ゥ'
		'ｪ'  = 'ェ'
		'ｫ'  = 'ォ'
		'ｬ'  = 'ャ'
		'ｭ'  = 'ュ'
		'ｮ'  = 'ョ'
		'ｯ'  = 'ッ'
		'ｰ'  = 'ー'
		'ｳﾞ' = 'ヴ'
		'ｶﾞ' = 'ガ'
		'ｷﾞ' = 'ギ'
		'ｸﾞ' = 'グ'
		'ｹﾞ' = 'ゲ'
		'ｺﾞ' = 'ゴ'
		'ｻﾞ' = 'ザ'
		'ｼﾞ' = 'ジ'
		'ｽﾞ' = 'ズ'
		'ｾﾞ' = 'ゼ'
		'ｿﾞ' = 'ゾ'
		'ﾀﾞ' = 'ダ'
		'ﾁﾞ' = 'ヂ'
		'ﾂﾞ' = 'ヅ'
		'ﾃﾞ' = 'デ'
		'ﾄﾞ' = 'ド'
		'ﾊﾞ' = 'バ'
		'ﾋﾞ' = 'ビ'
		'ﾌﾞ' = 'ブ'
		'ﾍﾞ' = 'ベ'
		'ﾎﾞ' = 'ボ'
		'ﾊﾟ' = 'パ'
		'ﾋﾟ' = 'ピ'
		'ﾌﾟ' = 'プ'
		'ﾍﾟ' = 'ペ'
		'ﾎﾟ' = 'ポ'
	}
	foreach ($replacement in $replacements.GetEnumerator()) {
		$text = $text.Replace($replacement.Name, $replacement.Value)
	}

	return $text
}

#----------------------------------------------------------------------
#いくつかの特殊文字を置換
#----------------------------------------------------------------------
function Remove-SpecialCharacter {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$replacements = @{
		'&amp;' = '&'
		'*'     = '＊'
		'|'     = '｜'
		':'     = '：'
		';'     = '；'
		'"'     = '' #削除
		'“'     = '' #削除
		'”'     = '' #削除
		','     = '' #削除
		'?'     = '？'
		'!'     = '！'
		'/'     = '-' #代替文字
		'\'     = '-' #代替文字
		'<'     = '＜'
		'>'     = '＞'
	}
	foreach ($replacement in $replacements.GetEnumerator()) {
		$text = $text.Replace($replacement.Name, $replacement.Value)
	}

	return $text
}

#----------------------------------------------------------------------
#タブとスペースを詰めて半角スペース1文字に
#----------------------------------------------------------------------
function Remove-TabSpace {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	return $text.Replace("`t", ' ').Replace('  ', ' ')
}

#----------------------------------------------------------------------
#設定ファイルの行末コメントを削除
#----------------------------------------------------------------------
function Remove-Comment {
	[OutputType([String])]
	Param ([String]$text)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	return $text.Split("`t")[0].Split(' ')[0].Split('#')[0]
}

#endregion 文字列操作

#region ファイル操作

#----------------------------------------------------------------------
#指定したPath配下の指定した条件でファイルを削除
#----------------------------------------------------------------------
function Remove-Files {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[parameter(Mandatory = $true, Position = 0)][System.IO.FileInfo]$basePath,
		[Parameter(Mandatory = $true, Position = 0)][Object]$conditions,
		[Parameter(Mandatory = $true, Position = 0)][int32]$delPeriod
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$limiteDateTime = (Get-Date).AddDays(-1 * $delPeriod)
	if ($script:enableMultithread) {
		Write-Debug ('Multithread Processing Enabled')
		#並列化が有効の場合は並列化
		try {
			$conditions.Split(',').Trim() | ForEach-Object -Parallel {
				Write-Output ('　{0}' -f (Join-Path $using:basePath $_))
				$null = (Get-ChildItem -LiteralPath $using:basePath -Recurse -File -Filter $_ -ErrorAction SilentlyContinue).Where({ $_.LastWriteTime -lt $using:limiteDateTime }) | Remove-Item -Force -ErrorAction SilentlyContinue
			} -ThrottleLimit $script:multithreadNum
		} catch { Write-Warning ('❗ 削除できないファイルがありました') }
	} else {
		#並列化が無効の場合は従来型処理
		try {
			foreach ($condition in $conditions.Split(',').Trim()) {
				Write-Output ('　{0}' -f (Join-Path $basePath $condition))
				$null = (Get-ChildItem -LiteralPath $basePath -Recurse -File -Filter $condition -ErrorAction SilentlyContinue).Where({ $_.LastWriteTime -lt $limiteDateTime }) | Remove-Item -Force -ErrorAction SilentlyContinue
			}
		} catch { Write-Warning ('❗ 削除できないファイルがありました') }
	}

}

#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	[CmdletBinding()]
	[OutputType([void])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)][string]$path,
		[Parameter(Mandatory = $true, Position = 1)][string]$destination
	)

	if (Test-Path -Path $path) {
		Write-Verbose ('{0}を{1}に展開します' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('{0}を展開しました' -f $path)
	} else {
		Write-Error ('{0}が見つかりません' -f $path)
	}
}

#----------------------------------------------------------------------
#ディレクトリの上書き
#----------------------------------------------------------------------
function Move-Files() {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)][String]$source,
		[Parameter(Mandatory = $true, Position = 1)][String]$destination
	)

	if ((Test-Path $destination) -and (Test-Path -PathType Container $source)) {
		# ディレクトリ上書き(移動先に存在 かつ ディレクトリ)は再帰的に Move-Files 呼び出し
		Get-ChildItem $source | ForEach-Object {
			if ($_.Name -inotlike '*update_tverrec.ps1') {
				Move-Files -Source $_.FullName -Destination ('{0}/{1}' -f $destination, $_.Name)
			}
		}
		# 移動し終わったディレクトリを削除
		Remove-Item -LiteralPath $source -Recurse -Force
	} else {
		# 移動先に対象なし または ファイルの Move-Item に -Forece つけて実行
		Write-Output ('{0} → {1}' -f $source, $destination)
		Move-Item -LiteralPath $source -Destination $destination -Force
	}
}

#endregion ファイル操作

#region ファイルロック

#----------------------------------------------------------------------
#ファイルのロック
#----------------------------------------------------------------------
function Lock-File {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true, Position = 0)][System.IO.FileInfo]$path
	)

	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)

	$fileLocked = $false
	try {
		# attempt to open file and detect file lock
		$script:fileInfo = New-Object System.IO.FileInfo $path
		$script:fileStream = $script:fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		$fileLocked = $true
	} catch { $fileLocked = $false
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $path
			fileLocked = $fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのアンロック
#----------------------------------------------------------------------
function Unlock-File {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true, Position = 0)][System.IO.FileInfo]$path
	)

	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)

	$fileLocked = $true
	try {
		# close stream if not lock
		if ($script:fileStream) { $script:fileStream.Close() }
		$script:fileStream.Dispose()
		$fileLocked = $false
	} catch { $fileLocked = $true
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $path
			fileLocked = $fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのロック確認
#----------------------------------------------------------------------
function Get-FileLockStatus {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true, Position = 0)][System.IO.FileInfo]$path
	)

	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)

	$fileLocked = $true
	try {
		# attempt to open file and detect file lock
		$fileInfo = New-Object System.IO.FileInfo $path
		$fileStream = $fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		# close stream if not lock
		if ($fileStream) { $fileStream.Close() }
		$fileLocked = $false
	} catch { $fileLocked = $true
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $path
			fileLocked = $fileLocked
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
		[Parameter(Mandatory = $false, Position = 0)][Object]$text,
		[Parameter(Mandatory = $false, Position = 1)][ConsoleColor]$fg,
		[Parameter(Mandatory = $false, Position = 2)][ConsoleColor]$bg,
		[Parameter(Mandatory = $false, Position = 3)][Boolean]$noNL
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$prevFg = $host.UI.RawUI.ForegroundColor
	$prevBg = $host.UI.RawUI.BackgroundColor

	if ($foregroundColor) { $host.UI.RawUI.ForegroundColor = $fg }
	if ($backgroundColor) { $host.UI.RawUI.BackgroundColor = $bg }

	if ($null -eq $text) { $text = '' }

	$writeHostParams = @{
		Object    = $text
		NoNewline = $noNL
	}
	Write-Host @writeHostParams

	$host.UI.RawUI.ForegroundColor = $prevFg
	$host.UI.RawUI.BackgroundColor = $prevBg
}

#endregion コンソール出力

#region トースト通知

#Toast用AppID取得に必要
if (($script:disableToastNotification -ne $true) -and ($IsWindows)) { Import-Module StartLayout -SkipEditionCheck }

#----------------------------------------------------------------------
#Windows Application ID取得
#----------------------------------------------------------------------
function Get-WindowsAppId {
	[OutputType([String])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$appId = (Get-StartApps | Where-Object { $_.Name -cmatch 'PowerShell*' })[0].AppId

	return $appId
}


#----------------------------------------------------------------------
#トースト表示
#----------------------------------------------------------------------
function Show-Toast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$text1,
		[Parameter(Mandatory = $false, Position = 1)][String]$text2,
		[Parameter(Mandatory = $false, Position = 2)][ValidateSet('Short', 'Long')][String]$duration = 'short',
		[Parameter(Mandatory = $false, Position = 4)][Boolean]$silent
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if (!$script:disableToastNotification) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }

				if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
					Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll')
					Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll')
					Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
				}
				$toastProgressContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
    <visual>
        <binding template="ToastGeneric">
            <text>$script:appName</text>
            <text>$text1</text>
            <text>$text2</text>
            <image placement="appLogoOverride" src="$script:toastAppLogo"/>
        </binding>
    </visual>
    $toastSoundElement
</toast>
"@
				$appID = Get-WindowsAppId
				$toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
				$toastXML.LoadXml($toastProgressContent)
				$toastNotification = New-Object Windows.UI.Notifications.ToastNotification $toastXML
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appID).Show($toastNotification)
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ea SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				break
			}
			default { break }
		}
	}
}



#----------------------------------------------------------------------
#進捗バー付きトースト表示
#----------------------------------------------------------------------
function Show-ProgressToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$text1,
		[Parameter(Mandatory = $false, Position = 1)][String]$text2,
		[Parameter(Mandatory = $false, Position = 2)][String]$workDetail,
		[Parameter(Mandatory = $true, Position = 3)][String]$tag,
		[Parameter(Mandatory = $true, Position = 4)][String]$group,
		[Parameter(Mandatory = $false, Position = 5)][ValidateSet('Short', 'Long')][String]$duration = 'short',
		[Parameter(Mandatory = $false, Position = 6)][Boolean]$silent
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if ($script:disableToastNotification -ne $true) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }

				if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
					Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll')
					Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll')
					Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
				}
				$toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
    <visual>
        <binding template="ToastGeneric">
            <text>$script:appName</text>
            <text>$text1</text>
            <text>$text2</text>
            <image placement="appLogoOverride" src="$script:toastAppLogo"/>
            <progress value="{progressValue}" title="{progressTitle}" valueStringOverride="{progressValueString}" status="{progressStatus}" />
            <text placement="attribution"></text>
        </binding>
    </visual>
    $toastSoundElement
</toast>
"@
				$appID = Get-WindowsAppId
				$toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
				$toastXML.LoadXml($toastContent)
				$toast = New-Object Windows.UI.Notifications.ToastNotification $toastXML
				$toast.Tag = $tag
				$toast.Group = $group
				$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
				$toastData.Add('progressTitle', $workDetail)
				$toastData.Add('progressValue', '')
				$toastData.Add('progressValueString', '')
				$toastData.Add('progressStatus', '')
				$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toast.Data.SequenceNumber = 1
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appID).Show($toast)
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ea SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				break
			}
			default { break }
		}
	}
}


#----------------------------------------------------------------------
#進捗バー付きトースト更新
#----------------------------------------------------------------------
function Update-ProgressToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$title,
		[Parameter(Mandatory = $true, Position = 1)][String]$rate,
		[Parameter(Mandatory = $false, Position = 2)][String]$leftText,
		[Parameter(Mandatory = $false, Position = 3)][String]$rightText,
		[Parameter(Mandatory = $true, Position = 4)][String]$tag,
		[Parameter(Mandatory = $true, Position = 5)][String]$group
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if ($script:disableToastNotification -ne $true) {
		switch ($true) {
			$IsWindows {
				$appID = Get-WindowsAppId
				$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
				$toastData.Add('progressTitle', $script:appName)
				$toastData.Add('progressValue', $rate)
				$toastData.Add('progressValueString', $rightText)
				$toastData.Add('progressStatus', $leftText)
				$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toastProgressData.SequenceNumber = 2
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appID).Update($toastProgressData, $tag , $group)
				break
			}
			$IsLinux { break }
			$IsMacOS { break }
			default { break }
		}
	}
}


#----------------------------------------------------------------------
#進捗バー付きトースト表示
#----------------------------------------------------------------------
function Show-ProgressToast2 {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$text1,
		[Parameter(Mandatory = $false, Position = 1)][String]$text2,
		[Parameter(Mandatory = $false, Position = 2)][String]$detail1,
		[Parameter(Mandatory = $false, Position = 3)][String]$detail2,
		[Parameter(Mandatory = $true, Position = 4)][String]$tag,
		[Parameter(Mandatory = $true, Position = 5)][String]$group,
		[Parameter(Mandatory = $false, Position = 6)][ValidateSet('Short', 'Long')][String]$duration,
		[Parameter(Mandatory = $false, Position = 7)][Boolean]$silent
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	switch ($true) {
		$IsWindows {
			$toastSoundElement = if ($silent) { '<audio silent="true" />' } else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
			$duration = if (!$duration) { 'short' } else { $duration }
			$toastAttribution = ''
			if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
				#For PowerShell Core v6.x & PowerShell v7+
				Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll')
				Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll')
				Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
			}
			$toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
	<visual>
		<binding template="ToastGeneric">
			<text>$script:appName</text>
			<text>$text1</text>
			<text>$text2</text>
			<image placement="appLogoOverride" src="$script:toastAppLogo"/>
			<progress value="{progressValue1}" title="{progressTitle1}" valueStringOverride="{progressValueString1}" status="{progressStatus1}" />
			<progress value="{progressValue2}" title="{progressTitle2}" valueStringOverride="{progressValueString2}" status="{progressStatus2}" />
			<text placement="attribution">$toastAttribution</text>
		</binding>
	</visual>
	$toastSoundElement
</toast>
"@
			$appID = Get-WindowsAppId
			$toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
			$toastXML.LoadXml($toastContent)
			$toast = New-Object Windows.UI.Notifications.ToastNotification $toastXML
			$toast.Tag = $tag
			$toast.Group = $group
			$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
			$toastData.Add('progressTitle1', $detail1)
			$toastData.Add('progressValue1', '')
			$toastData.Add('progressValueString1', '')
			$toastData.Add('progressStatus1', '')
			$toastData.Add('progressTitle2', $detail2)
			$toastData.Add('progressValue2', '')
			$toastData.Add('progressValueString2', '')
			$toastData.Add('progressStatus2', '')
			$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
			$toast.Data.SequenceNumber = 1
			$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appID).Show($toast)
			break
		}
		$IsLinux {
			if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 }
			break
		}
		$IsMacOS {
			if (Get-Command osascript -ea SilentlyContinue) {
				$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
				$toastParams | & osascript
			}
			break
		}
		default { break }
	}
}

#----------------------------------------------------------------------
#進捗バー付きトースト更新
#----------------------------------------------------------------------
function Update-ProgressToast2 {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$title1,
		[Parameter(Mandatory = $true, Position = 1)][String]$rate1,
		[Parameter(Mandatory = $false, Position = 2)][String]$leftText1,
		[Parameter(Mandatory = $false, Position = 3)][String]$rightText1,
		[Parameter(Mandatory = $false, Position = 4)][String]$title2,
		[Parameter(Mandatory = $true, Position = 5)][String]$rate2,
		[Parameter(Mandatory = $false, Position = 6)][String]$leftText2,
		[Parameter(Mandatory = $false, Position = 7)][String]$rightText2,
		[Parameter(Mandatory = $true, Position = 8)][String]$tag,
		[Parameter(Mandatory = $true, Position = 9)][String]$group
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if ($script:disableToastNotification -ne $true) {
		switch ($true) {
			$IsWindows {
				$appID = Get-WindowsAppId
				$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
				$toastData.Add('progressTitle1', $title1)
				$toastData.Add('progressValue1', $rate1)
				$toastData.Add('progressValueString1', $rightText1)
				$toastData.Add('progressStatus1', $leftText1)
				$toastData.Add('progressTitle2', $title2)
				$toastData.Add('progressValue2', $rate2)
				$toastData.Add('progressValueString2', $rightText2)
				$toastData.Add('progressStatus2', $leftText2)
				$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toastProgressData.SequenceNumber = 2
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appID).Update($toastProgressData, $tag , $group)
				break
			}
			$IsLinux { break }
			$IsMacOS { break }
			default { break }
		}
	}
}


#----------------------------------------------------------------------
#進捗表示
#----------------------------------------------------------------------
function Show-Progress2Row {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$text1,
		[Parameter(Mandatory = $false, Position = 1)][String]$text2,
		[Parameter(Mandatory = $false, Position = 2)][String]$detail1,
		[Parameter(Mandatory = $false, Position = 3)][String]$detail2,
		[Parameter(Mandatory = $true, Position = 4)][String]$tag,
		[Parameter(Mandatory = $false, Position = 5)][ValidateSet('Short', 'Long')][String]$duration,
		[Parameter(Mandatory = $false, Position = 6)][Boolean]$silent,
		[Parameter(Mandatory = $true, Position = 7)][String]$group
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($script:disableToastNotification -ne $true) {
		$text2 = $text2 ?? ''
		$detail1 = $detail1 ?? ''
		$detail2 = $detail2 ?? ''

		Show-ProgressToast2 `
			-Text1 $text1 `
			-Text2 $text2 `
			-Detail1 $detail1 `
			-Detail2 $detail2 `
			-Tag $tag `
			-Group $group `
			-Duration $duration `
			-Silent $silent
	}
}


#----------------------------------------------------------------------
#進捗更新
#----------------------------------------------------------------------
function Update-Progress2Row {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$activity1,
		[Parameter(Mandatory = $false, Position = 1)][String]$processing1,
		[Parameter(Mandatory = $true, Position = 2)][String]$rate1,
		[Parameter(Mandatory = $false, Position = 3)][String]$secRemaining1,
		[Parameter(Mandatory = $false, Position = 4)][String]$activity2,
		[Parameter(Mandatory = $false, Position = 5)][String]$processing2,
		[Parameter(Mandatory = $true, Position = 6)][String]$rate2,
		[Parameter(Mandatory = $false, Position = 7)][String]$secRemaining2,
		[Parameter(Mandatory = $true, Position = 8)][String]$tag,
		[Parameter(Mandatory = $true, Position = 9)][String]$group
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if ($script:disableToastNotification -ne $true) {
		$minRemaining1 = ($secRemaining1 -eq -1 -or $secRemaining1 -eq '' ) ? '' : ('残り時間 {0}分' -f ([Int][Math]::Ceiling($secRemaining1 / 60)))
		$minRemaining2 = ($secRemaining2 -eq -1 -or $secRemaining2 -eq '' ) ? '' : ('残り時間 {0}分' -f ([Int][Math]::Ceiling($secRemaining2 / 60)))

		Update-ProgressToast2 `
			-Title1 $processing1 `
			-Rate1 $rate1 `
			-LeftText1 $activity1 `
			-RightText1 $minRemaining1 `
			-Title2 $processing2 `
			-Rate2 $rate2 `
			-LeftText2 $activity2 `
			-RightText2 $minRemaining2 `
			-Tag $tag `
			-Group $group
	}
}
#endregion トースト通知

function ConvertFrom-Base64 {
	param ($base64)
	$img = New-Object System.Windows.Media.Imaging.BitmapImage
	$img.BeginInit()
	$img.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64)
	$img.EndInit()
	$img.Freeze()
	return $img
}