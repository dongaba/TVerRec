Import-Module Pester -MinimumVersion 5.0

BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot 'src/gui/user_setting_functions.ps1'
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:msg = (Get-Content -Path (Join-Path $script:repoRoot 'resources/lang/messages.json') -Raw | ConvertFrom-Json).'ja-JP'
	. $targetFile
	Write-Host ('　テスト対象の読み込みを行いました')
}

#----------------------------------------------------------------------
# 設定項目の表示用文字列への変換
#----------------------------------------------------------------------
Describe 'ConvertTo-SettingDisplayText' {
	It '文字列の値は、前後の空白と単一引用符を除いて返すこと' {
		ConvertTo-SettingDisplayText -Attribute '$script:downloadBaseDir' -Content @('$script:downloadBaseDir = ''D:\Videos''  ') | Should -Be 'D:\Videos'
	}
	It '数値は、そのまま返すこと' {
		ConvertTo-SettingDisplayText -Attribute '$script:loopCycle' -Content @('$script:loopCycle = 3600') | Should -Be '3600'
	}
	It '$trueと$falseは、「する」「しない」の表示にすること' {
		ConvertTo-SettingDisplayText -Attribute '$script:detailedProgress' -Content @('$script:detailedProgress = $true') | Should -Be $script:msg.SettingTrue
		ConvertTo-SettingDisplayText -Attribute '$script:detailedProgress' -Content @('$script:detailedProgress = $false') | Should -Be $script:msg.SettingFalse
	}
	It '項目の行がなければ、「デフォルト値」を返すこと' {
		ConvertTo-SettingDisplayText -Attribute '$script:loopCycle' -Content @('$script:other = 1') | Should -Be $script:msg.SettingDefault
	}
	It '既定値を持たない項目は、行がなければ「未設定」を返すこと' {
		foreach ($name in 'downloadBaseDir', 'downloadWorkDir', 'saveBaseDir', 'myPlatformUID', 'myPlatformToken', 'myMemberSID', 'proxyUrl') {
			ConvertTo-SettingDisplayText -Attribute ('$script:{0}' -f $name) -Content @('$script:other = 1') | Should -Be $script:msg.SettingUndefined
		}
	}
	It '内容が空($null・空の配列)でも、例外にならず「デフォルト値」を返すこと' {
		ConvertTo-SettingDisplayText -Attribute '$script:loopCycle' -Content $null | Should -Be $script:msg.SettingDefault
		ConvertTo-SettingDisplayText -Attribute '$script:loopCycle' -Content @() | Should -Be $script:msg.SettingDefault
	}
	It 'コメントアウトされた行は、無視すること' {
		ConvertTo-SettingDisplayText -Attribute '$script:loopCycle' -Content @('#$script:loopCycle = 5') | Should -Be $script:msg.SettingDefault
	}
	It '言語は、ja-JPを「日本語」、en-USを「English」、それ以外を「デフォルト値」の表示にすること' {
		ConvertTo-SettingDisplayText -Attribute '$script:preferredLanguage' -Content @('$script:preferredLanguage = ''ja-JP''') | Should -Be '日本語'
		ConvertTo-SettingDisplayText -Attribute '$script:preferredLanguage' -Content @('$script:preferredLanguage = ''en-US''') | Should -Be 'English'
		ConvertTo-SettingDisplayText -Attribute '$script:preferredLanguage' -Content @('$script:preferredLanguage = ''fr-FR''') | Should -Be $script:msg.SettingDefault
	}
	It '等号のない行は、値の指定がないものとして扱うこと' {
		ConvertTo-SettingDisplayText -Attribute '$script:loopCycle' -Content @('$script:loopCycle') | Should -Be $script:msg.SettingDefault
	}
	It '値に等号が含まれていても、最初の等号で分けること' {
		ConvertTo-SettingDisplayText -Attribute '$script:ytdlOption' -Content @('$script:ytdlOption = ''--a=b''') | Should -Be '--a=b'
	}
}

#----------------------------------------------------------------------
# 画面の入力からuser_setting.ps1の行への変換
#----------------------------------------------------------------------
Describe 'ConvertTo-UserSettingLine' {
	It '空・「デフォルト値」・「未設定」は、行を作らないこと' {
		ConvertTo-UserSettingLine -Attribute '$script:loopCycle' -Text '' | Should -BeNullOrEmpty
		ConvertTo-UserSettingLine -Attribute '$script:loopCycle' -Text $script:msg.SettingDefault | Should -BeNullOrEmpty
		ConvertTo-UserSettingLine -Attribute '$script:loopCycle' -Text $script:msg.SettingUndefined | Should -BeNullOrEmpty
		ConvertTo-UserSettingLine -Attribute '$script:loopCycle' -Text $null | Should -BeNullOrEmpty
	}
	It '「する」「しない」は、$true・$falseにすること' {
		ConvertTo-UserSettingLine -Attribute '$script:detailedProgress' -Text $script:msg.SettingTrue | Should -Be '$script:detailedProgress = $true'
		ConvertTo-UserSettingLine -Attribute '$script:detailedProgress' -Text $script:msg.SettingFalse | Should -Be '$script:detailedProgress = $false'
	}
	It '数値は、引用符なしで書き出すこと' {
		ConvertTo-UserSettingLine -Attribute '$script:loopCycle' -Text '3600' | Should -Be '$script:loopCycle = 3600'
	}
	It '$・{・}を含む値(変数や式)は、引用符なしで書き出すこと' {
		ConvertTo-UserSettingLine -Attribute '$script:downloadWorkDir' -Text '$env:TEMP' | Should -Be '$script:downloadWorkDir = $env:TEMP'
		ConvertTo-UserSettingLine -Attribute '$script:ytdlOption' -Text '{a}' | Should -Be '$script:ytdlOption = {a}'
	}
	It 'それ以外の文字列は、単一引用符で囲んで書き出すこと' {
		ConvertTo-UserSettingLine -Attribute '$script:downloadBaseDir' -Text 'D:\Videos' | Should -Be '$script:downloadBaseDir = ''D:\Videos'''
	}
	It '言語は、「日本語」「English」からja-JP・en-USにし、それ以外は行を作らないこと' {
		ConvertTo-UserSettingLine -Attribute '$script:preferredLanguage' -Text '日本語' | Should -Be '$script:preferredLanguage = ''ja-JP'''
		ConvertTo-UserSettingLine -Attribute '$script:preferredLanguage' -Text 'English' | Should -Be '$script:preferredLanguage = ''en-US'''
		ConvertTo-UserSettingLine -Attribute '$script:preferredLanguage' -Text $script:msg.SettingDefault | Should -BeNullOrEmpty
	}
	It '値に含まれる単一引用符は、二重にエスケープして書き出し、PowerShellとして正しく解釈できること' {
		$line = ConvertTo-UserSettingLine -Attribute '$script:ytdlOption' -Text "it's"
		$line | Should -Be '$script:ytdlOption = ''it''''s'''
		$errors = $null
		[System.Management.Automation.Language.Parser]::ParseInput($line, [Ref]$null, [Ref]$errors) | Out-Null
		@($errors).Count | Should -Be 0
	}
	It '単一引用符を含む値は、書き出して読み込むと、元の値に戻ること(往復)' {
		foreach ($value in "it's", "'quoted'", "ends with '", "''", "a''b") {
			$line = ConvertTo-UserSettingLine -Attribute '$script:ytdlOption' -Text $value
			ConvertTo-SettingDisplayText -Attribute '$script:ytdlOption' -Content @($line) | Should -Be $value
		}
	}
	It '読み込んだ表示文字列をそのまま書き出すと、元の行に戻ること(往復)' {
		$lines = @(
			'$script:downloadBaseDir = ''D:\Videos''',
			'$script:loopCycle = 3600',
			'$script:detailedProgress = $true',
			'$script:disableValidation = $false',
			'$script:preferredLanguage = ''ja-JP'''
		)
		foreach ($line in $lines) {
			$attribute = $line.Split(' ')[0]
			$display = ConvertTo-SettingDisplayText -Attribute $attribute -Content $lines
			ConvertTo-UserSettingLine -Attribute $attribute -Text $display | Should -Be $line
		}
	}
}

#----------------------------------------------------------------------
# 自動生成の区間の差し替え
#----------------------------------------------------------------------
Describe 'Merge-UserSettingContent' {
	BeforeAll {
		$script:mscStart = '##Start Setting Generated from GUI'
		$script:mscEnd = '##End Setting Generated from GUI'
	}
	It '既存の内容がなければ、開始マーカー・新しい行・終了マーカーだけにすること' {
		@(Merge-UserSettingContent -ExistingContent @() -GeneratedLines @('a = 1', 'b = 2')) | Should -Be @($script:mscStart, 'a = 1', 'b = 2', $script:mscEnd)
		@(Merge-UserSettingContent -ExistingContent $null -GeneratedLines @('a = 1')) | Should -Be @($script:mscStart, 'a = 1', $script:mscEnd)
	}
	It '自動生成の区間だけを差し替え、前後のユーザーの行は残すこと' {
		$existing = @('# 手書きの設定', '$script:x = 1', $script:mscStart, 'old = 1', 'old = 2', $script:mscEnd, '# 後ろの手書き', '$script:y = 2')
		$result = @(Merge-UserSettingContent -ExistingContent $existing -GeneratedLines @('new = 1'))
		$result | Should -Be @('# 手書きの設定', '$script:x = 1', $script:mscStart, 'new = 1', $script:mscEnd, '# 後ろの手書き', '$script:y = 2')
	}
	It '自動生成の区間が先頭にあれば、前の行はなく、後ろの行だけを残すこと' {
		$existing = @($script:mscStart, 'old = 1', $script:mscEnd, '$script:y = 2')
		@(Merge-UserSettingContent -ExistingContent $existing -GeneratedLines @('new = 1')) | Should -Be @($script:mscStart, 'new = 1', $script:mscEnd, '$script:y = 2')
	}
	It '自動生成の区間が末尾にあれば、後ろの行はないこと' {
		$existing = @('$script:x = 1', $script:mscStart, 'old = 1', $script:mscEnd)
		@(Merge-UserSettingContent -ExistingContent $existing -GeneratedLines @('new = 1')) | Should -Be @('$script:x = 1', $script:mscStart, 'new = 1', $script:mscEnd)
	}
	It '同じ内容で差し替えを繰り返しても、結果が変わらないこと(冪等)' {
		$existing = @('$script:x = 1', $script:mscStart, 'old = 1', $script:mscEnd, '$script:y = 2')
		$once = @(Merge-UserSettingContent -ExistingContent $existing -GeneratedLines @('new = 1'))
		$twice = @(Merge-UserSettingContent -ExistingContent $once -GeneratedLines @('new = 1'))
		$twice | Should -Be $once
	}
	It 'マーカーのない既存の内容は、生成した区間の後ろに、全行を残すこと' {
		$existing = @('$script:x = 1', '$script:y = 2')
		@(Merge-UserSettingContent -ExistingContent $existing -GeneratedLines @('new = 1')) | Should -Be @($script:mscStart, 'new = 1', $script:mscEnd, '$script:x = 1', '$script:y = 2')
	}
	It '生成する行がなければ、マーカーだけの区間にすること' {
		@(Merge-UserSettingContent -ExistingContent @('$script:x = 1') -GeneratedLines @()) | Should -Be @($script:mscStart, $script:mscEnd, '$script:x = 1')
	}
}

#----------------------------------------------------------------------
# 動作停止スケジュールの書き出しと読み取り
#----------------------------------------------------------------------
Describe '動作停止スケジュール' {
	BeforeAll {
		$script:ssDays = @('Mon', 'Tue', 'Wed')
	}
	It 'ConvertTo-StopScheduleLine: 曜日の順に、時間を「, 」区切りで書き出すこと' {
		$lines = @(ConvertTo-StopScheduleLine -StopHours @{ Mon = @(1, 2, 23) ; Wed = @(5) } -Days $script:ssDays)
		$lines | Should -Be @('$script:stopSchedule = @{', "`t'Mon' = @(1, 2, 23)", "`t'Tue' = @()", "`t'Wed' = @(5)", '}')
	}
	It 'Get-StopScheduleFromSetting: 曜日ごとの時間を整数の配列として読み取ること' {
		$content = @('$script:x = 1', '$script:stopSchedule = @{', "`t'Mon' = @(1, 2, 23)", "`t'Tue' = @()", "`t'Wed' = @(5)", '}', '$script:y = 2')
		$result = Get-StopScheduleFromSetting -Content $content -Days $script:ssDays
		@($result['Mon']) | Should -Be @(1, 2, 23)
		$result.ContainsKey('Tue') | Should -BeFalse
		@($result['Wed']) | Should -Be @(5)
		$result['Mon'][0] | Should -BeOfType [Int]
	}
	It 'Get-StopScheduleFromSetting: 設定がなければ、空のハッシュテーブルを返すこと' {
		(Get-StopScheduleFromSetting -Content @('$script:x = 1') -Days $script:ssDays).Count | Should -Be 0
		(Get-StopScheduleFromSetting -Content $null -Days $script:ssDays).Count | Should -Be 0
	}
	It 'Get-StopScheduleFromSetting: 解釈できない値があっても、例外にならず、そこまでの分を返すこと' {
		$content = @('$script:stopSchedule = @{', "`t'Mon' = @(1, 2)", "`t'Tue' = @(x)", "`t'Wed' = @(5)", '}')
		{ Get-StopScheduleFromSetting -Content $content -Days $script:ssDays } | Should -Not -Throw
		@((Get-StopScheduleFromSetting -Content $content -Days $script:ssDays)['Mon']) | Should -Be @(1, 2)
	}
	It '書き出した行を読み取ると、元の時間に戻ること(往復)' {
		$hours = @{ Mon = @(0, 1, 2) ; Tue = @(23) }
		$lines = @(ConvertTo-StopScheduleLine -StopHours $hours -Days $script:ssDays)
		$back = Get-StopScheduleFromSetting -Content $lines -Days $script:ssDays
		@($back['Mon']) | Should -Be @(0, 1, 2)
		@($back['Tue']) | Should -Be @(23)
		$back.ContainsKey('Wed') | Should -BeFalse
	}
}
