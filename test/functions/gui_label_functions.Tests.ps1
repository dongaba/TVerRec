Import-Module Pester -MinimumVersion 5.0

BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot 'src/gui/gui_label_functions.ps1'
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:langFile = Get-Content -Path (Join-Path $script:repoRoot 'resources/lang/messages.json') -Raw | ConvertFrom-Json
	. $targetFile
	Write-Host ('　テスト対象の読み込みを行いました')
}

#----------------------------------------------------------------------
# XAMLのName属性を持つ要素の取得
#----------------------------------------------------------------------
Describe 'Get-XamlNamedElement' {
	It 'Name属性を持つ要素だけを、名前と種類(要素名)で返すこと' {
		$xaml = [Xml]'<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Grid><Button Name="btnA"/><TextBlock/><TextBlock Name="txtB"/></Grid></Window>'
		$result = @(Get-XamlNamedElement -Xaml $xaml)
		$result.Count | Should -Be 2
		$result[0].Name | Should -Be 'btnA'
		$result[0].Type | Should -Be 'Button'
		$result[1].Name | Should -Be 'txtB'
		$result[1].Type | Should -Be 'TextBlock'
	}
	It 'Name属性を持つ要素がなければ、空を返すこと' {
		@(Get-XamlNamedElement -Xaml ([Xml]'<Window><Grid/></Window>')).Count | Should -Be 0
	}
}

#----------------------------------------------------------------------
# ラベルの対応の決定
#----------------------------------------------------------------------
Describe 'Get-GuiLabelAssignment' {
	BeforeAll {
		$script:glaMessage = [PSCustomObject]@{
			btnSave          = '保存'
			tabOperation     = '動作'
			fooHeader        = 'フォー'
			fooText          = 'フォーの説明'
			lblTitle         = 'タイトル'
			comboNoLabel     = 'コンボ'
			scheduleStopMon  = '使われないキー'
			scheduleStopTextMon = '月'
		}
		$script:glaElement = @(
			[PSCustomObject]@{ Name = 'btnSave' ; Type = 'Button' },
			[PSCustomObject]@{ Name = 'tabOperation' ; Type = 'TabItem' },
			[PSCustomObject]@{ Name = 'fooHeader' ; Type = 'Expander' },
			[PSCustomObject]@{ Name = 'fooText' ; Type = 'TextBlock' },
			[PSCustomObject]@{ Name = 'lblTitle' ; Type = 'Label' },
			[PSCustomObject]@{ Name = 'comboNoLabel' ; Type = 'ComboBox' },
			[PSCustomObject]@{ Name = 'noMessage' ; Type = 'Button' },
			[PSCustomObject]@{ Name = 'scheduleStopMon' ; Type = 'TextBlock' }
		)
		$script:glaResult = @(Get-GuiLabelAssignment -Element $script:glaElement -Message $script:glaMessage)
	}
	It '要素の種類に応じて、Header・Content・Textのプロパティを選ぶこと' {
		($script:glaResult | Where-Object Name -EQ 'btnSave').Property | Should -Be 'Content'
		($script:glaResult | Where-Object Name -EQ 'lblTitle').Property | Should -Be 'Content'
		($script:glaResult | Where-Object Name -EQ 'tabOperation').Property | Should -Be 'Header'
		($script:glaResult | Where-Object Name -EQ 'fooHeader').Property | Should -Be 'Header'
		($script:glaResult | Where-Object Name -EQ 'fooText').Property | Should -Be 'Text'
	}
	It '名前と同じキーのメッセージを、設定する文字列にすること' {
		($script:glaResult | Where-Object Name -EQ 'btnSave').Text | Should -Be '保存'
		($script:glaResult | Where-Object Name -EQ 'fooText').Text | Should -Be 'フォーの説明'
	}
	It 'メッセージにキーが無い要素と、対象外の種類の要素は、含めないこと' {
		$script:glaResult.Name | Should -Not -Contain 'noMessage'
		$script:glaResult.Name | Should -Not -Contain 'comboNoLabel'
	}
	It '動作停止スケジュールの曜日などは、対応表で読み替えたキーを使うこと' {
		$item = $script:glaResult | Where-Object Name -EQ 'scheduleStopMon'
		$item.Text | Should -Be '月'
		$item.Property | Should -Be 'Text'
	}
	It '名前とキーの大文字小文字は、区別しないこと' {
		$result = @(Get-GuiLabelAssignment -Element @([PSCustomObject]@{ Name = 'VideoContainerFormatHeader' ; Type = 'Expander' }) -Message ([PSCustomObject]@{ videoContainerFormatHeader = '形式' }))
		$result.Count | Should -Be 1
		$result[0].Text | Should -Be '形式'
	}
	It '要素が空でも、例外にならず空を返すこと' {
		@(Get-GuiLabelAssignment -Element @() -Message $script:glaMessage).Count | Should -Be 0
	}
}

#----------------------------------------------------------------------
# 実際のXAMLとメッセージファイルでの確認
#----------------------------------------------------------------------
Describe 'XAMLとmessages.json(実ファイル)の対応' -ForEach @(
	@{ Xaml = 'TVerRecMain.xaml' ; MinCount = 20 },
	@{ Xaml = 'TVerRecSetting.xaml' ; MinCount = 150 }
) {
	BeforeAll {
		$script:xamlDoc = [Xml](Get-Content -LiteralPath (Join-Path $script:repoRoot ('resources/xaml/{0}' -f $Xaml)) -Raw)
		$script:elements = @(Get-XamlNamedElement -Xaml $script:xamlDoc)
	}
	It '<Xaml>: 両言語で、設定対象が<MinCount>件以上あり、設定する文字列が空でないこと' {
		foreach ($lang in 'ja-JP', 'en-US') {
			$result = @(Get-GuiLabelAssignment -Element $script:elements -Message $script:langFile.$lang)
			$result.Count | Should -BeGreaterOrEqual $MinCount
			foreach ($item in $result) { [String]::IsNullOrEmpty($item.Text) | Should -BeFalse -Because ('{0}の{1}' -f $item.Name, $lang) }
		}
	}
	It '<Xaml>: 対象は、日本語と英語で同じ要素であること' {
		$ja = @(Get-GuiLabelAssignment -Element $script:elements -Message $script:langFile.'ja-JP').Name | Sort-Object
		$en = @(Get-GuiLabelAssignment -Element $script:elements -Message $script:langFile.'en-US').Name | Sort-Object
		$en | Should -Be $ja
	}
}
