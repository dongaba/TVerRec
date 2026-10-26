###################################################################################
#
#		共通関数スクリプト(トースト通知)
#
###################################################################################
<#
	.SYNOPSIS
		トースト通知の表示と、進捗表示の更新の関数を定義します。

	.NOTES
		このファイルはcommon_functions.ps1から読み込まれます。
		単体で読み込まず、common_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region トースト通知
# モジュールのインポート
if ($IsWindows -and !$script:disableToastNotification -and (!('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type]))) {
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll') | Out-Null
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll') | Out-Null
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll') | Out-Null
}

#----------------------------------------------------------------------
# トースト表示
#----------------------------------------------------------------------
function Show-GeneralToast {
	<#
		.SYNOPSIS
			カスタムテキストと期間を指定してトースト通知を表示します。

		.DESCRIPTION
			この関数は、Windows、Linux、macOS の各プラットフォームで指定された内容のトースト通知を表示します。
			ユーザーは通知のメッセージ、期間、および音が鳴るかどうかを制御できます。
			通知の期間は「短い」または「長い」を選択できます。

		.PARAMETER text1
			トースト通知のメインコンテンツとなるテキストです。通知に表示される主要なテキストを指定します。

		.PARAMETER text2
			オプションで、通知の副次的なテキストを指定します。追加の詳細情報などを表示するために使用できます。

		.PARAMETER duration
			通知の表示時間を指定します。「短い」または「長い」のいずれかを選択できます。デフォルトは「短い」です。

		.PARAMETER silent
			このパラメータが$trueの場合、通知の音が鳴りません。デフォルトは$falseで、音が鳴ります。

		.EXAMPLE
			Show-GeneralToast -text1 "タスク完了" -text2 "すべての処理が完了しました！" -duration "Long"

			「長い」期間のトースト通知を指定されたメッセージで表示します。

		.EXAMPLE
			Show-GeneralToast -text1 "エラーが発生しました" -silent $true

			音なしでトースト通知を表示します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
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
				$toastXML = [Windows.Data.Xml.Dom.XmlDocument]::new()
				$toastXML.LoadXml($toastProgressContent)
				$toastNotification = [Windows.UI.Notifications.ToastNotification]::new($toastXML)
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toastNotification) | Out-Null
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ErrorAction SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 2> /dev/null }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ErrorAction SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript 2> /dev/null
				}
				break
			}
			default {}
		}
	}
	Remove-Variable -Name text1, text2, duration, silent, toastSoundElement, toastProgressContent, toastXML, toastNotification, toastParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗バー付きトースト表示
#----------------------------------------------------------------------
function Show-ProgressToast {
	<#
		.SYNOPSIS
			進行状況を示すトースト通知を表示します。

		.DESCRIPTION
			この関数は、Windows、Linux、macOS の各プラットフォームで進行状況を示すトースト通知を表示します。
			ユーザーは通知のメッセージ、進行状況の詳細、期間、および音の有無を制御できます。
			通知は「短い」または「長い」期間で表示できます。

		.PARAMETER text1
			トースト通知のメインテキストです。通常、処理が開始されたことや進行中のタスクに関する説明が表示されます。

		.PARAMETER text2
			オプションの副次的なテキストです。追加情報や補足的な説明を表示するために使用します。

		.PARAMETER workDetail
			進行中の作業の詳細情報です。進捗状況の説明を通知に追加するために使用します。

		.PARAMETER tag
			トースト通知のタグです。同じグループに属する通知を識別するために使用します。

		.PARAMETER group
			トースト通知のグループ名です。同じグループ内で通知を整理できます。

		.PARAMETER duration
			通知の表示時間を指定します。「短い」または「長い」のいずれかを選択できます。デフォルトは「短い」です。

		.PARAMETER silent
			音なしで通知を表示する場合は$trueを指定します。デフォルトは$falseで、音が鳴ります。

		.EXAMPLE
			Show-ProgressToast -text1 "処理中" -text2 "ファイルを読み込んでいます..." -workDetail "データのロード" -tag "fileLoad" -group "taskGroup" -duration "Long"

			長期間表示される進行状況を示すトースト通知を表示します。

		.EXAMPLE
			Show-ProgressToast -text1 "エラー発生" -silent $true -tag "errorTask" -group "errorGroup"

			音なしでエラー発生を通知する進行状況トーストを表示します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][String]$workDetail = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
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
				$toastXML = [Windows.Data.Xml.Dom.XmlDocument]::new()
				$toastXML.LoadXml($toastContent)
				$toast = [Windows.UI.Notifications.ToastNotification]::new($toastXML)
				$toast.Tag = $tag
				$toast.Group = $group
				$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
				$toastData.Add('progressTitle', $workDetail) | Out-Null
				$toastData.Add('progressValue', '') | Out-Null
				$toastData.Add('progressValueString', '') | Out-Null
				$toastData.Add('progressStatus', '') | Out-Null
				$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toast.Data.SequenceNumber = 1
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toast) | Out-Null
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ErrorAction SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 2> /dev/null }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ErrorAction SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				break
			}
			default {}
		}
	}
	Remove-Variable -Name text1, text2, workDetail, tag, group, duration, silent, toastSoundElement, toastContent, toastXML, toast, toastData, toastParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗バー付きトースト更新
#----------------------------------------------------------------------
function Update-ProgressToast {
	<#
		.SYNOPSIS
			進行状況の更新を行うトースト通知を更新します。

		.DESCRIPTION
			この関数は、Windows プラットフォームで進行状況を更新するためのトースト通知を更新します。
			進行中の作業の進捗率や状態を動的に更新するために使用できます。

		.PARAMETER title
			トースト通知のタイトルテキストです。主に作業の種類を示します。

		.PARAMETER rate
			進行状況の進捗率を指定します。通常は0〜100の範囲で指定されます。

		.PARAMETER leftText
			進行状況の左側に表示されるテキストです。作業のステータスや詳細情報を記載します。

		.PARAMETER rightText
			進行状況の右側に表示されるテキストです。作業の進捗状況に関連する追加情報を表示します。

		.PARAMETER tag
			トースト通知のタグです。同じグループ内の通知を識別するために使用します。

		.PARAMETER group
			トースト通知のグループ名です。同じグループ内で通知を整理できます。

		.EXAMPLE
			Update-ProgressToast -rate "50" -leftText "データ処理中" -rightText "進捗: 50%" -tag "dataProcessing" -group "taskGroup"

			進行中のデータ処理の進捗を50%に更新するトースト通知を表示します。

		.EXAMPLE
			Update-ProgressToast -rate "75" -leftText "ファイルの書き込み" -rightText "進捗: 75%" -tag "fileWrite" -group "taskGroup"

			ファイルの書き込み進捗を75%に更新するトースト通知を表示します。
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$title = '',
		[Parameter(Mandatory = $true )][String]$rate,
		[Parameter(Mandatory = $false)][String]$leftText = '',
		[Parameter(Mandatory = $false)][String]$rightText = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification -and $PSCmdlet.ShouldProcess($tag, 'Update toast')) {
		switch ($true) {
			$IsWindows {
				$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
				$toastData.Add('progressTitle', $title) | Out-Null
				$toastData.Add('progressValue', $rate) | Out-Null
				$toastData.Add('progressValueString', $rightText) | Out-Null
				$toastData.Add('progressStatus', $leftText) | Out-Null
				$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toastProgressData.SequenceNumber = 2
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Update($toastProgressData, $tag , $group) | Out-Null
				break
			}
			$IsLinux { break }
			$IsMacOS { break }
			default {}
		}
	}
	Remove-Variable -Name title, rate, leftText, rightText, tag, group, toastData, toastProgressData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗表示(2行進捗バー)
#----------------------------------------------------------------------
function Show-ProgressToast2Row {
	<#
		.SYNOPSIS
			2行の進行状況を示すトースト通知を表示します。

		.DESCRIPTION
			この関数は、Windows、Linux、macOS プラットフォームで2行の進行状況を示すトースト通知を表示します。
			各行に異なる進行状況を表示でき、ユーザーは通知のメッセージ、進行状況の詳細、期間、および音の有無を制御できます。

		.PARAMETER text1
			トースト通知のメインテキストです。通常、処理が開始されたことや進行中のタスクに関する説明が表示されます。

		.PARAMETER text2
			オプションで、副次的なテキストです。追加の詳細情報などを表示するために使用します。

		.PARAMETER detail1
			1行目の進行状況の詳細情報です。進捗状況に関連する詳細な説明を表示します。

		.PARAMETER detail2
			2行目の進行状況の詳細情報です。進捗状況に関連する追加情報を表示します。

		.PARAMETER tag
			トースト通知のタグです。同じグループに属する通知を識別するために使用します。

		.PARAMETER duration
			通知の表示時間を指定します。「Short」または「Long」を選択できます。デフォルトは「Short」です。

		.PARAMETER silent
			音なしで通知を表示する場合は$trueを指定します。デフォルトは$falseで、音が鳴ります。

		.PARAMETER group
			トースト通知のグループ名です。同じグループ内で通知を整理できます。

		.EXAMPLE
			Show-ProgressToast2Row -text1 "処理中" -text2 "ファイルを読み込んでいます..." -detail1 "データのロード" -detail2 "進捗: 50%" -tag "fileLoad" -group "taskGroup" -duration "Long"

			長期間表示される2行の進行状況を示すトースト通知を表示します。

		.EXAMPLE
			Show-ProgressToast2Row -text1 "エラー発生" -silent $true -tag "errorTask" -group "errorGroup"

			音なしでエラー発生を通知する2行の進行状況トーストを表示します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][String]$detail1 = '',
		[Parameter(Mandatory = $false)][String]$detail2 = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false,
		[Parameter(Mandatory = $true )][String]$group
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification) {
		$text2 = $text2 ?? ''
		$detail1 = $detail1 ?? ''
		$detail2 = $detail2 ?? ''
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' } else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
				$duration = if (!$duration) { 'short' } else { $duration }
				$toastAttribution = ''
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
				$toastXML = [Windows.Data.Xml.Dom.XmlDocument]::new()
				$toastXML.LoadXml($toastContent)
				$toast = [Windows.UI.Notifications.ToastNotification]::new($toastXML)
				$toast.Tag = $tag
				$toast.Group = $group
				$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
				$toastData.Add('progressTitle1', $detail1) | Out-Null
				$toastData.Add('progressValue1', '') | Out-Null
				$toastData.Add('progressValueString1', '') | Out-Null
				$toastData.Add('progressStatus1', '') | Out-Null
				$toastData.Add('progressTitle2', $detail2) | Out-Null
				$toastData.Add('progressValue2', '') | Out-Null
				$toastData.Add('progressValueString2', '') | Out-Null
				$toastData.Add('progressStatus2', '') | Out-Null
				$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toast.Data.SequenceNumber = 1
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toast) | Out-Null
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ErrorAction SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 2> /dev/null }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ErrorAction SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				break
			}
			default {}
		}
	}
	Remove-Variable -Name text1, text2, detail1, detail2, tag, duration, silent, group, toastSoundElement, toastAttribution, toastContent, toastXML, toast, toastData, toastParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗更新(2行進捗バー)
#----------------------------------------------------------------------
function Update-ProgressToast2Row {
	<#
		.SYNOPSIS
			2行の進行状況を示すトースト通知を更新します。

		.DESCRIPTION
			この関数は、Windows プラットフォームで進行状況を更新するためのトースト通知を更新します。
			2行の進行状況を表示するトースト通知を動的に更新するために使用できます。進捗率や詳細情報を含めた通知を更新します。

		.PARAMETER title1
			1行目の進行状況のタイトルテキストです。進行中の作業のタイトルや説明を示します。

		.PARAMETER rate1
			1行目の進行状況の進捗率を指定します。通常は0〜100の範囲で指定されます。

		.PARAMETER leftText1
			1行目の進行状況の左側に表示されるテキストです。作業のステータスや詳細情報を記載します。

		.PARAMETER rightText1
			1行目の進行状況の右側に表示されるテキストです。進捗の詳細情報や完了までの残り時間を示します。

		.PARAMETER title2
			2行目の進行状況のタイトルテキストです。2番目の進行状況の作業や詳細を示します。

		.PARAMETER rate2
			2行目の進行状況の進捗率を指定します。通常は0〜100の範囲で指定されます。

		.PARAMETER leftText2
			2行目の進行状況の左側に表示されるテキストです。作業のステータスや詳細情報を記載します。

		.PARAMETER rightText2
			2行目の進行状況の右側に表示されるテキストです。進捗の詳細情報や完了までの残り時間を示します。

		.PARAMETER tag
			トースト通知のタグです。同じグループ内で通知を識別するために使用します。

		.PARAMETER group
			トースト通知のグループ名です。同じグループ内で通知を整理できます。

		.EXAMPLE
			Update-ProgressToast2Row -title1 "データ処理中" -rate1 "50" -leftText1 "処理中" -rightText1 "残り10分" -title2 "ファイル書き込み" -rate2 "75" -leftText2 "書き込み中" -rightText2 "残り5分" -tag "dataProcessing" -group "taskGroup"

			2行の進行状況を示すトースト通知を表示し、データ処理とファイル書き込みの進捗を更新します。

		.EXAMPLE
			Update-ProgressToast2Row -title1 "タスク1" -rate1 "25" -leftText1 "進行中" -rightText1 "残り15分" -title2 "タスク2" -rate2 "50" -leftText2 "進行中" -rightText2 "残り10分" -tag "taskGroup1" -group "group1"

			2つのタスクの進捗を更新するトースト通知を表示します。
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$title1 = '',
		[Parameter(Mandatory = $true )][String]$rate1,
		[Parameter(Mandatory = $false)][String]$leftText1 = '',
		[Parameter(Mandatory = $false)][String]$rightText1 = '',
		[Parameter(Mandatory = $false)][String]$title2 = '',
		[Parameter(Mandatory = $true )][String]$rate2,
		[Parameter(Mandatory = $false)][String]$leftText2 = '',
		[Parameter(Mandatory = $false)][String]$rightText2 = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!($script:disableToastNotification) -and $PSCmdlet.ShouldProcess($tag, 'Update toast')) {
		$rightText1 = switch ($rightText1 ) {
			'' { '' ; break }
			'0' { $script:msg.Completed ; break }
			default { ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($rightText1 / 60))) }
		}
		$rightText2 = switch ($rightText2 ) {
			'' { '' ; break }
			'0' { $script:msg.Completed ; break }
			default { ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($rightText2 / 60))) }
		}
		if (!$script:disableToastNotification) {
			switch ($true) {
				$IsWindows {
					$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
					$toastData.Add('progressTitle1', $title1) | Out-Null
					$toastData.Add('progressValue1', $rate1) | Out-Null
					$toastData.Add('progressValueString1', $rightText1) | Out-Null
					$toastData.Add('progressStatus1', $leftText1) | Out-Null
					$toastData.Add('progressTitle2', $title2) | Out-Null
					$toastData.Add('progressValue2', $rate2) | Out-Null
					$toastData.Add('progressValueString2', $rightText2) | Out-Null
					$toastData.Add('progressStatus2', $leftText2)
					$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
					$toastProgressData.SequenceNumber = 2
					[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Update($toastProgressData, $tag , $group) | Out-Null
					break
				}
				$IsLinux { break }
				$IsMacOS { break }
				default {}
			}
		}
	}
	Remove-Variable -Name title1, rate1, leftText1, rightText1, title2, rate2, leftText2, rightText2, tag, group, toastData, toastProgressData -ErrorAction SilentlyContinue
}
#endregion トースト通知
