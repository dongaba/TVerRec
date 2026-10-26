###################################################################################
#
#		GUI部品のラベル設定関数スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		GUI(WPF)の部品に、言語別のラベルを設定するための関数を定義します。

	.DESCRIPTION
		XAMLのName属性を持つ要素のうち、メッセージファイル(messages.json)に同名のキーがあるものに、
		そのメッセージを、要素の種類に応じたプロパティ(Header・Content・Text)として設定します。
		設定する要素を一覧で持たず、XAMLとメッセージから決めるため、GUI部品を増やすときは、
		XAMLと、messages.jsonの両言語に、同じ名前を追加するだけでよくなります。
		対応関係を決める処理は、WPFに依存しないため、WPFの無い環境でもテストできます。

	.NOTES
		このファイルは、gui_main.ps1とgui_setting.ps1から読み込まれます。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#----------------------------------------------------------------------
# XAMLのName属性を持つ要素の一覧を取得
#----------------------------------------------------------------------
function Get-XamlNamedElement {
	<#
		.SYNOPSIS
			XAMLから、Name属性を持つ要素の名前と種類の一覧を返します。

		.PARAMETER Xaml
			XAMLを読み込んだXmlオブジェクトを指定します。

		.OUTPUTS
			[PSCustomObject[]]
			Name(Name属性の値)とType(要素の種類。例: Button、TextBlock)を持つオブジェクト。

		.EXAMPLE
			Get-XamlNamedElement -Xaml ([Xml](Get-Content ./resources/xaml/TVerRecMain.xaml -Raw))
	#>
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $true)][Xml]$Xaml
	)
	foreach ($node in $Xaml.SelectNodes('//*[@Name]')) {
		[PSCustomObject]@{ Name = $node.GetAttribute('Name') ; Type = $node.LocalName }
	}
}

#----------------------------------------------------------------------
# 要素ごとの、設定するプロパティとメッセージの対応の決定
#----------------------------------------------------------------------
function Get-GuiLabelAssignment {
	<#
		.SYNOPSIS
			要素の一覧とメッセージから、どの要素のどのプロパティに、どの文字列を設定するかを返します。

		.DESCRIPTION
			要素の種類から、設定するプロパティを決めます。
			Expander・TabItemはHeader、Button・LabelはContent、TextBlockはTextです。
			メッセージのキーは、要素のName属性と同じ名前(大文字小文字は区別しない)を使います。
			ただし、動作停止スケジュールの曜日などは、Name属性とキーが異なるため、対応表で読み替えます。
			キーがメッセージに無い要素と、上記以外の種類の要素は、対象外です。

		.PARAMETER Element
			Get-XamlNamedElementで取得した、要素の名前と種類の一覧を指定します。

		.PARAMETER Message
			言語別のメッセージ($script:msg)を指定します。

		.OUTPUTS
			[PSCustomObject[]]
			Name(要素名)、Property(設定するプロパティ)、Text(設定する文字列)を持つオブジェクト。

		.EXAMPLE
			Get-GuiLabelAssignment -Element (Get-XamlNamedElement -Xaml $xaml) -Message $script:msg
	#>
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $true)][AllowEmptyCollection()][PSCustomObject[]]$Element,
		[Parameter(Mandatory = $true)][PSCustomObject]$Message
	)
	# 要素の種類ごとに、ラベルを設定するプロパティ
	$propertyByType = @{
		Expander  = 'Header'
		TabItem   = 'Header'
		Button    = 'Content'
		Label     = 'Content'
		TextBlock = 'Text'
	}
	# 要素のName属性と、メッセージのキーが異なるもの
	$keyByName = @{
		scheduleStopTime = 'scheduleStopTextTime'
		scheduleStopWeek = 'scheduleStopTextWeek'
		scheduleStopMon  = 'scheduleStopTextMon'
		scheduleStopTue  = 'scheduleStopTextTue'
		scheduleStopWed  = 'scheduleStopTextWed'
		scheduleStopThu  = 'scheduleStopTextThu'
		scheduleStopFri  = 'scheduleStopTextFri'
		scheduleStopSat  = 'scheduleStopTextSat'
		scheduleStopSun  = 'scheduleStopTextSun'
		scheduleStopDay  = 'scheduleStopTextDay'
	}
	$messageKeys = @($Message.PSObject.Properties.Name)
	foreach ($item in $Element) {
		if (!$propertyByType.ContainsKey($item.Type)) { continue }
		$key = if ($keyByName.ContainsKey($item.Name)) { $keyByName[$item.Name] } else { $item.Name }
		if ($key -notin $messageKeys) { continue }
		[PSCustomObject]@{ Name = $item.Name ; Property = $propertyByType[$item.Type] ; Text = $Message.$key }
	}
}

#----------------------------------------------------------------------
# GUI部品へのラベルの設定
#----------------------------------------------------------------------
function Set-GuiLabel {
	<#
		.SYNOPSIS
			ウィンドウの各部品に、言語別のラベルを設定します。

		.PARAMETER Window
			読み込み済みのWPFのウィンドウを指定します。

		.PARAMETER Xaml
			ウィンドウの元になったXAMLのXmlオブジェクトを指定します。

		.PARAMETER Message
			言語別のメッセージ($script:msg)を指定します。

		.OUTPUTS
			System.Void

		.EXAMPLE
			Set-GuiLabel -Window $mainWindow -Xaml $mainXaml -Message $script:msg
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)]$Window,
		[Parameter(Mandatory = $true)][Xml]$Xaml,
		[Parameter(Mandatory = $true)][PSCustomObject]$Message
	)
	$elements = @(Get-XamlNamedElement -Xaml $Xaml)
	foreach ($assignment in @(Get-GuiLabelAssignment -Element $elements -Message $Message)) {
		$target = $Window.FindName($assignment.Name)
		if ($null -eq $target) { Write-Debug ('{0} is null' -f $assignment.Name) ; continue }
		$target.($assignment.Property) = $assignment.Text
	}
}
