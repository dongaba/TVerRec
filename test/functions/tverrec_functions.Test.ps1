Import-Module Pester -MinimumVersion 5.0

BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	# * パスに「test」「src」を含むディレクトリ配下でも正しく解決できるよう、リポジトリルートから組み立てる
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot 'src/functions/tverrec_functions.ps1'
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:scriptRoot = Convert-Path (Join-Path $script:repoRoot 'src')
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:repoRoot 'conf')
	$script:msg = (Get-Content -Path (Join-Path $script:repoRoot 'resources/lang/messages.json') -Raw | ConvertFrom-Json).'ja-JP'
	. (Join-Path $script:scriptRoot 'functions/common_functions.ps1')
	. (Join-Path $script:confDir 'system_setting.ps1')
	# user_setting.ps1がない環境(クローン直後やCI)では一時的に作成し、テスト後に削除する
	$script:userSettingPath = Join-Path $script:confDir 'user_setting.ps1'
	$script:cleanupUserSetting = -not (Test-Path $script:userSettingPath)
	if ($script:cleanupUserSetting) {
		@(
			'$script:downloadBaseDir = "./download"'
			'$script:downloadWorkDir = "./work"'
			'$script:saveBaseDir = "./save"'
		) | Set-Content -LiteralPath $script:userSettingPath
	}
	. $script:userSettingPath
	. $targetFile
	Write-Host ('　テスト対象の読み込みを行いました')
	$script:downloadBaseDir = Join-Path $TestDrive 'download'
	$script:sortVideoByMedia = $false
	$script:sortVideoBySeries = $false
	$script:addSeriesName = $false
	$script:addSeasonName = $false
	$script:addBroadcastDate = $false
	$script:addEpisodeNumber = $false
	$script:videoContainerFormat = 'mp4'
	$script:fileNameLengthMax = 255
	New-Item -ItemType Directory -Path $script:downloadBaseDir -Force | Out-Null
}

Describe 'Format-VideoFileInfo' {
	It 'ベースディレクトリのみを返すこと' {
		$videoInfo = [PSCustomObject]@{
			mediaName     = 'Media'
			seriesName    = 'Series'
			seasonName    = 'Season1'
			episodeName   = 'Episode'
			broadcastDate = '2025-04-18'
			episodeNum    = 1
		}
		Format-VideoFileInfo -videoInfo ([ref]$videoInfo)
		$videoInfo.fileDir | Should -BeExactly $script:downloadBaseDir
	}
}

AfterAll {
	if ($script:cleanupUserSetting) { Remove-Item -LiteralPath $script:userSettingPath -ErrorAction SilentlyContinue }
}

Describe 'Merge-ZeroDurationSubtitle' {
	It '0秒字幕を同じ開始時刻の次の字幕にマージする' {
		$srt = "1`n00:00:05,000 --> 00:00:05,000`n字幕1`n`n2`n00:00:05,000 --> 00:00:09,000`n字幕2`n"
		$result = Merge-ZeroDurationSubtitle -SrtText $srt
		$result.MergedCount | Should -Be 1
		$result.Content | Should -Be "1`n00:00:05,000 --> 00:00:09,000`n字幕1`n字幕2`n`n"
	}
	It '0秒字幕が連続しても1つにまとめ、通し番号を振り直す' {
		$srt = "1`n00:00:01,000 --> 00:00:02,000`nA`n`n2`n00:00:05,000 --> 00:00:05,000`nB`n`n3`n00:00:05,000 --> 00:00:05,000`nC`n`n4`n00:00:05,000 --> 00:00:08,000`nD`n"
		$result = Merge-ZeroDurationSubtitle -SrtText $srt
		$result.MergedCount | Should -Be 2
		$result.Content | Should -Be "1`n00:00:01,000 --> 00:00:02,000`nA`n`n2`n00:00:05,000 --> 00:00:08,000`nB`nC`nD`n`n"
	}
	It 'マージ対象がなければ件数0を返す' {
		$srt = "1`n00:00:01,000 --> 00:00:03,000`nあ`n`n2`n00:00:05,000 --> 00:00:09,000`nい`n"
		(Merge-ZeroDurationSubtitle -SrtText $srt).MergedCount | Should -Be 0
	}
	It '次に同じ開始時刻の字幕がない0秒字幕は削除せず残す' {
		$srt = "1`n00:00:05,000 --> 00:00:05,000`n孤立`n`n2`n00:00:07,000 --> 00:00:09,000`n次`n"
		$result = Merge-ZeroDurationSubtitle -SrtText $srt
		$result.MergedCount | Should -Be 0
		$result.Content | Should -Match '孤立'
	}
	It '空文字列でもエラーにならない' {
		(Merge-ZeroDurationSubtitle -SrtText '').MergedCount | Should -Be 0
	}
}

Describe 'Test-YtdlCryptoModule' -Skip:$IsWindows {
	BeforeAll {
		# * 実際のPythonに依存しないよう、終了コードだけを返す偽のPythonを用意する
		$script:fakeBinDir = Join-Path $TestDrive 'fakebin'
		New-Item -ItemType Directory -Path $script:fakeBinDir -Force | Out-Null
		foreach ($case in @{ fakepyok = 0; fakepyng = 1 }.GetEnumerator()) {
			$fakePython = Join-Path $script:fakeBinDir $case.Key
			Set-Content -LiteralPath $fakePython -Value ("#!/bin/sh`nexit {0}`n" -f $case.Value) -NoNewline
			& chmod +x $fakePython
		}
		$script:newYtdl = {
			Param ([String]$Shebang)
			$ytdl = Join-Path $TestDrive 'yt-dlp'
			Set-Content -LiteralPath $ytdl -Value ("{0}`nprint(1)`n" -f $Shebang) -NoNewline
			return $ytdl
		}
		$script:originalPath = $env:PATH
		$script:originalYoutubedl = $script:preferredYoutubedl
		$script:hadYtdlPath = Test-Path Variable:Script:ytdlPath
		if ($script:hadYtdlPath) { $script:originalYtdlPath = $script:ytdlPath }
	}
	BeforeEach { $script:preferredYoutubedl = 'yt-dlp' }
	AfterAll {
		$env:PATH = $script:originalPath
		$script:preferredYoutubedl = $script:originalYoutubedl
		if ($script:hadYtdlPath) { $script:ytdlPath = $script:originalYtdlPath }
		else { Remove-Variable -Name ytdlPath -Scope Script -ErrorAction SilentlyContinue }
	}

	It 'importに失敗するPythonでは警告し、Pythonのパスを含める(shebangが絶対パス)' {
		$script:ytdlPath = & $script:newYtdl ('#!{0}' -f (Join-Path $script:fakeBinDir 'fakepyng'))
		Test-YtdlCryptoModule -WarningVariable warn -WarningAction SilentlyContinue
		$warn | Should -HaveCount 1
		$warn[0].Message | Should -BeLike ('*{0}*' -f (Join-Path $script:fakeBinDir 'fakepyng'))
		$warn[0].Message | Should -BeLike '*pycryptodomex*'
	}
	It 'importに失敗するPythonでは警告する(shebangが/usr/bin/env形式)' {
		$env:PATH = '{0}:{1}' -f $script:fakeBinDir, $script:originalPath
		$script:ytdlPath = & $script:newYtdl '#!/usr/bin/env fakepyng'
		Test-YtdlCryptoModule -WarningVariable warn -WarningAction SilentlyContinue
		$warn | Should -HaveCount 1
	}
	It 'importに成功するPythonでは警告しない' {
		$script:ytdlPath = & $script:newYtdl ('#!{0}' -f (Join-Path $script:fakeBinDir 'fakepyok'))
		Test-YtdlCryptoModule -WarningVariable warn -WarningAction SilentlyContinue
		$warn | Should -HaveCount 0
	}
	It 'Pythonを特定できない場合は警告しない' {
		$script:ytdlPath = & $script:newYtdl '#!/usr/bin/env nosuchpython'
		Test-YtdlCryptoModule -WarningVariable warn -WarningAction SilentlyContinue
		$warn | Should -HaveCount 0
	}
	It 'shebangがない場合は警告しない' {
		$script:ytdlPath = & $script:newYtdl 'not a shebang'
		Test-YtdlCryptoModule -WarningVariable warn -WarningAction SilentlyContinue
		$warn | Should -HaveCount 0
	}
	It 'yt-dlpが存在しない場合は警告しない' {
		$script:ytdlPath = Join-Path $TestDrive 'not-exist'
		Test-YtdlCryptoModule -WarningVariable warn -WarningAction SilentlyContinue
		$warn | Should -HaveCount 0
	}
	It 'yt-dlp系以外のツールでは確認しない' {
		$script:ytdlPath = & $script:newYtdl ('#!{0}' -f (Join-Path $script:fakeBinDir 'fakepyng'))
		$script:preferredYoutubedl = 'ytdl-patched'
		Test-YtdlCryptoModule -WarningVariable warn -WarningAction SilentlyContinue
		$warn | Should -HaveCount 0
	}
}

Describe 'Test-IgnoreMatch' {
	BeforeEach { $script:ignoreRegexCache = @{} }

	Context 'regex:で始まらない行(従来動作)' {
		It 'Literal: 部分一致する' {
			Test-IgnoreMatch -Pattern 'ちいかわ' -Target @('シリーズ', 'ちいかわ 第1話') -Mode Literal | Should -BeTrue
		}
		It 'Literal: 大文字小文字を区別する' {
			Test-IgnoreMatch -Pattern 'abc' -Target @('ABC') -Mode Literal | Should -BeFalse
		}
		It 'Literal: *やの[ ]を通常の文字として扱う' {
			Test-IgnoreMatch -Pattern 'あい*えお' -Target @('あいうえお') -Mode Literal | Should -BeFalse
			Test-IgnoreMatch -Pattern 'あい*えお' -Target @('あい*えお') -Mode Literal | Should -BeTrue
		}
		It 'Wildcard: *がワイルドカードとして働く' {
			Test-IgnoreMatch -Pattern 'あい*えお' -Target @('あいかきくけこえお') -Mode Wildcard | Should -BeTrue
		}
		It 'Wildcard: 大文字小文字を区別しない' {
			Test-IgnoreMatch -Pattern 'abc' -Target @('xxABCxx') -Mode Wildcard | Should -BeTrue
		}
		It 'いずれのTargetにもマッチしなければ$false、Targetが空・nullでも$false' {
			Test-IgnoreMatch -Pattern 'zzz' -Target @('abc', 'def') -Mode Wildcard | Should -BeFalse
			Test-IgnoreMatch -Pattern 'zzz' -Target @($null, '') -Mode Wildcard | Should -BeFalse
			Test-IgnoreMatch -Pattern 'zzz' -Target $null -Mode Literal | Should -BeFalse
		}
	}

	Context 'regex:で始まる行' {
		It '選択(a|b)で1行にまとめられる' {
			$p = 'regex:私の夫は冷凍庫に眠っている (第|最終)'
			Test-IgnoreMatch -Pattern $p -Target @('私の夫は冷凍庫に眠っている 第3話') -Mode Wildcard | Should -BeTrue
			Test-IgnoreMatch -Pattern $p -Target @('私の夫は冷凍庫に眠っている 最終話') -Mode Wildcard | Should -BeTrue
			Test-IgnoreMatch -Pattern $p -Target @('私の夫は冷凍庫に眠っている 特別編') -Mode Wildcard | Should -BeFalse
		}
		It 'どのモードでも同じ結果になる' {
			Test-IgnoreMatch -Pattern 'regex:^abc\d+$' -Target @('abc123') -Mode Literal | Should -BeTrue
			Test-IgnoreMatch -Pattern 'regex:^abc\d+$' -Target @('abc123') -Mode Wildcard | Should -BeTrue
		}
		It '大文字小文字を区別し、(?i)で区別しなくできる' {
			Test-IgnoreMatch -Pattern 'regex:abc' -Target @('ABC') -Mode Wildcard | Should -BeFalse
			Test-IgnoreMatch -Pattern 'regex:(?i)abc' -Target @('ABC') -Mode Wildcard | Should -BeTrue
		}
		It '[ ]は文字クラスとして働く(エスケープした[ ]は通常の文字)' {
			Test-IgnoreMatch -Pattern 'regex:大奥～誕生\[有功･家光篇\]' -Target @('大奥～誕生[有功･家光篇] 第1話') -Mode Wildcard | Should -BeTrue
		}
		It 'いずれかのTargetにマッチすれば$true' {
			Test-IgnoreMatch -Pattern 'regex:^シリーズA$' -Target @('エピソード.mp4', 'シリーズA') -Mode Wildcard | Should -BeTrue
		}
		It '不正な正規表現は警告して$false(警告は1回だけ)' {
			$r1 = Test-IgnoreMatch -Pattern 'regex:(' -Target @('abc') -Mode Wildcard -WarningVariable w1 -WarningAction SilentlyContinue
			$r2 = Test-IgnoreMatch -Pattern 'regex:(' -Target @('abc') -Mode Wildcard -WarningVariable w2 -WarningAction SilentlyContinue
			$r1 | Should -BeFalse
			$r2 | Should -BeFalse
			$w1 | Should -HaveCount 1
			$w2 | Should -HaveCount 0
		}
		It '本文が空の「regex:」はすべてにマッチさせず、警告して$false' {
			Test-IgnoreMatch -Pattern 'regex:' -Target @('abc') -Mode Wildcard -WarningVariable w -WarningAction SilentlyContinue | Should -BeFalse
			$w | Should -HaveCount 1
		}
		It '合成文字(NFD)の対象でもNFCの正規表現にマッチする' {
			$nfd = 'が'.Normalize([Text.NormalizationForm]::FormD)
			Test-IgnoreMatch -Pattern 'regex:が' -Target @($nfd) -Mode Wildcard | Should -BeTrue
		}
	}
}

Describe 'Update-IgnoreList' {
	BeforeEach {
		$script:fileInfo = @{}
		$script:fileStream = @{}
		$script:ignoreFilePath = Join-Path $TestDrive 'ignore.conf'
		$script:ignoreFileSamplePath = Join-Path $TestDrive 'ignore.sample.conf'
		$script:ignoreLockFilePath = Join-Path $TestDrive 'ignore.lock'
		New-Item -Path $script:ignoreLockFilePath -ItemType File -Force | Out-Null
		[IO.File]::WriteAllText($script:ignoreFileSamplePath, ";; sample`n", [Text.UTF8Encoding]::new($false))
		[IO.File]::WriteAllText($script:ignoreFilePath, "番組A`n番組B`n番組C`n", [Text.UTF8Encoding]::new($false))
	}

	It '使用した番組を先頭(コメントの直後)に移動し、LF・BOMなしで保存すること' {
		Update-IgnoreList -ignoreTitle '番組B' -WarningAction SilentlyContinue
		$bytes = [IO.File]::ReadAllBytes($script:ignoreFilePath)
		($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
		$text = [IO.File]::ReadAllText($script:ignoreFilePath)
		$text | Should -Be ";; sample`n番組B`n番組A`n番組C`n"
	}
	It '一時ファイルが残らず、ロックも解放されること' {
		Update-IgnoreList -ignoreTitle '番組C' -WarningAction SilentlyContinue
		@(Get-ChildItem -LiteralPath $TestDrive -Filter 'ignore.conf.*.tmp').Count | Should -Be 0
		$script:fileStream.ContainsKey($script:ignoreLockFilePath) | Should -BeFalse
		{ [IO.File]::Open($script:ignoreLockFilePath, 'Open', 'ReadWrite', 'None').Dispose() } | Should -Not -Throw
	}
}
