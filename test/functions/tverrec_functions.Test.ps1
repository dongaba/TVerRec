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

Describe 'Move-VideoFileToDestination' {
	BeforeEach {
		$script:srcDir = Join-Path $TestDrive 'src'
		$script:dstDir = Join-Path $TestDrive 'dst'
		Remove-Item -LiteralPath $script:srcDir, $script:dstDir -Recurse -Force -ErrorAction SilentlyContinue
		New-Item -ItemType Directory -Path $script:srcDir, $script:dstDir -Force | Out-Null
		$script:srcFile = Join-Path $script:srcDir '番組 第1話.mp4'
		$script:dstFile = Join-Path $script:dstDir '番組 第1話.mp4'
		Set-Content -LiteralPath $script:srcFile -Value 'new' -NoNewline
		# ffprobeが存在しない場合は字幕の有無を確認できず(null)、従来どおりの動作になる
		$script:ffprobePath = Join-Path $TestDrive 'ffprobe-not-exist'
	}

	It '同名ファイルがなければ、どの設定でも移動する' {
		foreach ($action in @('Overwrite', 'Skip', 'Rename')) {
			Set-Content -LiteralPath $script:srcFile -Value 'new' -NoNewline
			Remove-Item -LiteralPath $script:dstFile -Force -ErrorAction SilentlyContinue
			$r = Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction $action
			$r.Result | Should -Be 'Moved'
			$r.Destination | Should -Be $script:dstFile
			Test-Path -LiteralPath $script:srcFile | Should -BeFalse
			Get-Content -LiteralPath $script:dstFile -Raw | Should -Be 'new'
		}
	}
	It 'Overwrite: 同名ファイルを上書きする' {
		Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
		$r = Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite'
		$r.Result | Should -Be 'Overwritten'
		Get-Content -LiteralPath $script:dstFile -Raw | Should -Be 'new'
		Test-Path -LiteralPath $script:srcFile | Should -BeFalse
	}
	It '既定値と未知の値はOverwriteとして扱う' {
		Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
		(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir).Result | Should -Be 'Overwritten'
		Set-Content -LiteralPath $script:srcFile -Value 'new' -NoNewline
		Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
		(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Unknown').Result | Should -Be 'Overwritten'
	}
	It 'Skip: 移動せず、移動先も移動元も変更しない' {
		Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
		$r = Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Skip'
		$r.Result | Should -Be 'Skipped'
		$r.Destination | Should -BeNullOrEmpty
		Get-Content -LiteralPath $script:dstFile -Raw | Should -Be 'old'
		Get-Content -LiteralPath $script:srcFile -Raw | Should -Be 'new'
	}
	It 'Rename: 既存ファイルを残し、連番を付けて移動する' {
		Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
		$r = Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Rename'
		$r.Result | Should -Be 'Renamed'
		$r.Destination | Should -Be (Join-Path $script:dstDir '番組 第1話 (1).mp4')
		Get-Content -LiteralPath $script:dstFile -Raw | Should -Be 'old'
		Get-Content -LiteralPath $r.Destination -Raw | Should -Be 'new'
		Test-Path -LiteralPath $script:srcFile | Should -BeFalse
	}
	It 'Rename: 連番も重複している場合は次の番号を使う' {
		Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
		Set-Content -LiteralPath (Join-Path $script:dstDir '番組 第1話 (1).mp4') -Value 'old1' -NoNewline
		$r = Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Rename'
		$r.Destination | Should -Be (Join-Path $script:dstDir '番組 第1話 (2).mp4')
		Get-Content -LiteralPath (Join-Path $script:dstDir '番組 第1話 (1).mp4') -Raw | Should -Be 'old1'
	}
	Context '字幕の有無による上書き防止' {
		BeforeEach {
			Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
			Mock Test-VideoFileHasSubtitle { $script:subtitleMap[$VideoPath] }
		}
		It 'Overwrite: 移動先に字幕があり、移動元に字幕がなければ上書きしない' {
			$script:subtitleMap = @{ $script:dstFile = $true ; $script:srcFile = $false }
			$r = Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite'
			$r.Result | Should -Be 'SubtitleKept'
			$r.Destination | Should -BeNullOrEmpty
			Get-Content -LiteralPath $script:dstFile -Raw | Should -Be 'old'
			Get-Content -LiteralPath $script:srcFile -Raw | Should -Be 'new'
		}
		It 'Overwrite: 移動先と移動元の両方に字幕があれば上書きする' {
			$script:subtitleMap = @{ $script:dstFile = $true ; $script:srcFile = $true }
			(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite').Result | Should -Be 'Overwritten'
			Get-Content -LiteralPath $script:dstFile -Raw | Should -Be 'new'
		}
		It 'Overwrite: 移動先に字幕がなく、移動元に字幕があれば上書きする' {
			$script:subtitleMap = @{ $script:dstFile = $false ; $script:srcFile = $true }
			(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite').Result | Should -Be 'Overwritten'
		}
		It 'Overwrite: 両方とも字幕がなければ上書きする' {
			$script:subtitleMap = @{ $script:dstFile = $false ; $script:srcFile = $false }
			(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite').Result | Should -Be 'Overwritten'
		}
		It 'Overwrite: 字幕の有無を確認できない(ffprobeが使えないなど)場合は従来どおり上書きする' {
			$script:subtitleMap = @{ $script:dstFile = $null ; $script:srcFile = $null }
			(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite').Result | Should -Be 'Overwritten'
			Set-Content -LiteralPath $script:srcFile -Value 'new' -NoNewline
			Set-Content -LiteralPath $script:dstFile -Value 'old' -NoNewline
			$script:subtitleMap = @{ $script:dstFile = $true ; $script:srcFile = $null }
			(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite').Result | Should -Be 'Overwritten'
		}
		It 'Rename: 既存ファイルは上書きされないため、字幕の確認をせず別名で移動する' {
			$script:subtitleMap = @{ $script:dstFile = $true ; $script:srcFile = $false }
			(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Rename').Result | Should -Be 'Renamed'
			Should -Invoke Test-VideoFileHasSubtitle -Times 0 -Exactly
		}
		It '同名ファイルがなければ字幕の確認をせず移動する' {
			Remove-Item -LiteralPath $script:dstFile -Force
			$script:subtitleMap = @{}
			(Move-VideoFileToDestination -Path $script:srcFile -DestinationDir $script:dstDir -ConflictAction 'Overwrite').Result | Should -Be 'Moved'
			Should -Invoke Test-VideoFileHasSubtitle -Times 0 -Exactly
		}
	}
	It 'ファイル名に[ ]などを含んでも移動できる' {
		$src = Join-Path $script:srcDir '大奥[有功] 第1話.mp4'
		Set-Content -LiteralPath $src -Value 'x' -NoNewline
		$r = Move-VideoFileToDestination -Path $src -DestinationDir $script:dstDir -ConflictAction 'Skip'
		$r.Result | Should -Be 'Moved'
		Test-Path -LiteralPath (Join-Path $script:dstDir '大奥[有功] 第1話.mp4') | Should -BeTrue
	}
	It '移動元がなければ例外にする(呼び出し側で警告)' {
		{ Move-VideoFileToDestination -Path (Join-Path $script:srcDir 'none.mp4') -DestinationDir $script:dstDir } | Should -Throw
	}
}

Describe 'サムネイル埋め込み設定(embedThumbnail)' {
	BeforeAll {
		# * 実際にはyt-dlpを起動せず、Start-Processに渡された引数だけを捕捉する
		Mock Invoke-StatisticsCheck {}
		Mock Start-Process {
			$script:capturedYtdlArgs = $ArgumentList
			return [PSCustomObject]@{ Id = 1 ; ExitCode = 0 ; Handle = 0 }
		}
		$script:backup = @{}
		foreach ($name in @('debugMode', 'ytdlTimeoutSec', 'ytdlPath', 'ytdlStdOutLogPath', 'ytdlStdErrLogPath', 'videoContainerFormat', 'downloadWorkDir', 'ffmpegPath', 'embedThumbnail', 'embedSubtitle', 'embedMetatag', 'jobList')) {
			$script:backup[$name] = if (Test-Path ('Variable:Script:{0}' -f $name)) { (Get-Variable -Name $name -Scope Script).Value } else { '__UNDEFINED__' }
		}
		$script:debugMode = $true	# * ログファイルを作る分岐を避ける
		$script:ytdlTimeoutSec = 0
		$script:ytdlPath = 'yt-dlp'
		$script:ytdlStdOutLogPath = Join-Path $TestDrive 'stdout.log'
		$script:ytdlStdErrLogPath = Join-Path $TestDrive 'stderr.log'
		New-Item -ItemType File -Path $script:ytdlStdOutLogPath, $script:ytdlStdErrLogPath -Force | Out-Null
		$script:videoContainerFormat = 'mp4'
		$script:downloadWorkDir = Join-Path $TestDrive 'work'
		$script:ffmpegPath = 'ffmpeg'
		$script:embedSubtitle = $true
		$script:embedMetatag = $true
		$script:jobList = @()
		$script:videoInfo = [PSCustomObject]@{
			fileDir        = (Join-Path $TestDrive 'download').Replace('\', '/')
			filePath       = (Join-Path $TestDrive 'download/番組 第1話.mp4').Replace('\', '/')
			fileName       = '番組 第1話.mp4'
			episodeID      = 'epabcd1234'
			episodePageURL = 'https://tver.jp/episodes/epabcd1234'
		}
	}
	AfterAll {
		foreach ($name in $script:backup.Keys) {
			if ($script:backup[$name] -is [String] -and $script:backup[$name] -eq '__UNDEFINED__') { Remove-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $name -Scope Script -Value $script:backup[$name] }
		}
	}
	BeforeEach { $script:capturedYtdlArgs = $null }

	It 'system_setting.ps1の既定値は$true(従来どおり埋め込む)' {
		$setting = Get-Content -LiteralPath (Join-Path $script:confDir 'system_setting.ps1') -Raw
		$setting | Should -Match '(?m)^\$script:embedThumbnail = \$true\s*$'
	}
	It 'Invoke-Ytdl: $trueなら--embed-thumbnailを渡す' {
		$script:embedThumbnail = $true
		$videoInfo = $script:videoInfo
		Invoke-Ytdl -videoInfo ([ref]$videoInfo) 6>$null 3>$null
		$script:capturedYtdlArgs | Should -Match '--embed-thumbnail'
		$script:capturedYtdlArgs | Should -Match '--embed-chapters'
		$script:capturedYtdlArgs | Should -Match '--merge-output-format mp4'
	}
	It 'Invoke-Ytdl: $falseなら--embed-thumbnailを渡さず、他の埋め込みは維持する' {
		$script:embedThumbnail = $false
		$videoInfo = $script:videoInfo
		Invoke-Ytdl -videoInfo ([ref]$videoInfo) 6>$null 3>$null
		$script:capturedYtdlArgs | Should -Not -Match '--embed-thumbnail'
		$script:capturedYtdlArgs | Should -Match '--embed-chapters'
		$script:capturedYtdlArgs | Should -Match '--embed-subs'
		$script:capturedYtdlArgs | Should -Match '--embed-metadata'
	}
	It 'Invoke-NonTverYtdl: $trueなら--embed-thumbnailを渡す' {
		$script:embedThumbnail = $true
		Invoke-NonTverYtdl -videoPageURL 'https://example.com/video' 6>$null 3>$null
		$script:capturedYtdlArgs | Should -Match '--embed-thumbnail'
		$script:capturedYtdlArgs | Should -Match '--embed-chapters'
	}
	It 'Invoke-NonTverYtdl: $falseなら--embed-thumbnailを渡さず、他の埋め込みは維持する' {
		$script:embedThumbnail = $false
		Invoke-NonTverYtdl -videoPageURL 'https://example.com/video' 6>$null 3>$null
		$script:capturedYtdlArgs | Should -Not -Match '--embed-thumbnail'
		$script:capturedYtdlArgs | Should -Match '--embed-chapters'
		$script:capturedYtdlArgs | Should -Match '--embed-subs'
	}
}

Describe 'Test-WorkDirOverlap' {
	BeforeAll {
		$script:root = Join-Path ([IO.Path]::GetTempPath()) 'TVerRecOverlapTest'
		$script:base = Join-Path $script:root 'Video'
	}
	It '同じフォルダならtrue' {
		Test-WorkDirOverlap -BaseDir $script:base -WorkDir $script:base | Should -BeTrue
	}
	It '末尾の区切り文字の有無が違っても同じフォルダならtrue' {
		Test-WorkDirOverlap -BaseDir ($script:base + [IO.Path]::DirectorySeparatorChar) -WorkDir $script:base | Should -BeTrue
	}
	It '..を含む表記でも同じフォルダならtrue' {
		$indirect = Join-Path (Join-Path $script:base 'sub') '..'
		Test-WorkDirOverlap -BaseDir $script:base -WorkDir $indirect | Should -BeTrue
	}
	It '作業ディレクトリがダウンロード先を含むフォルダならtrue' {
		Test-WorkDirOverlap -BaseDir $script:base -WorkDir $script:root | Should -BeTrue
	}
	It '作業ディレクトリがダウンロード先の配下ならfalse' {
		Test-WorkDirOverlap -BaseDir $script:base -WorkDir (Join-Path $script:base 'work') | Should -BeFalse
	}
	It '別フォルダならfalse' {
		Test-WorkDirOverlap -BaseDir $script:base -WorkDir (Join-Path $script:root 'Work') | Should -BeFalse
	}
	It '名前の先頭が同じだけの別フォルダならfalse' {
		Test-WorkDirOverlap -BaseDir (Join-Path $script:root 'Video2') -WorkDir (Join-Path $script:root 'Video') | Should -BeFalse
	}
	It 'WindowsとmacOSでは大文字小文字を区別しない' -Skip:(-not ($IsWindows -or $IsMacOS)) {
		Test-WorkDirOverlap -BaseDir $script:base -WorkDir $script:base.ToUpper() | Should -BeTrue
	}
	It 'Linuxでは大文字小文字を区別する' -Skip:($IsWindows -or $IsMacOS) {
		Test-WorkDirOverlap -BaseDir $script:base -WorkDir $script:base.ToUpper() | Should -BeFalse
	}
}

Describe 'Get-ProcessCountByPath / Get-YtdlProcessCount / Get-FfmpegProcessCount' -Skip:$IsWindows {
	BeforeAll {
		$script:procDir = Join-Path ([IO.Path]::GetTempPath()) ('TVerRecProc{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:procDir | Out-Null
		$sleepSrc = (Get-Command sleep -CommandType Application | Select-Object -First 1).Source
		$script:fakeFfmpeg = Join-Path $script:procDir 'ffmpeg'
		Copy-Item -LiteralPath $sleepSrc -Destination $script:fakeFfmpeg
		$script:otherFfmpeg = Join-Path $script:procDir 'other-bin/ffmpeg'
		New-Item -ItemType Directory -Path (Split-Path $script:otherFfmpeg) | Out-Null
		Copy-Item -LiteralPath $sleepSrc -Destination $script:otherFfmpeg
		$script:fakeYtdl = Join-Path $script:procDir 'yt-dlp'
		Set-Content -LiteralPath $script:fakeYtdl -Value "#!/usr/bin/env python3`nimport time`ntime.sleep(60)`n"
		chmod +x $script:fakeYtdl
		$script:started = @()
		$script:saveFfmpegPath = if (Test-Path Variable:Script:ffmpegPath) { $script:ffmpegPath } else { $null }
		$script:saveYtdlPath = if (Test-Path Variable:Script:ytdlPath) { $script:ytdlPath } else { $null }
	}
	AfterAll {
		foreach ($p in $script:started) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { Write-Debug $_ } }
		Remove-Item -LiteralPath $script:procDir -Recurse -Force -ErrorAction SilentlyContinue
		$script:ffmpegPath = $script:saveFfmpegPath
		$script:ytdlPath = $script:saveYtdlPath
	}
	AfterEach {
		foreach ($p in $script:started) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { Write-Debug $_ } }
		$script:started = @()
		Start-Sleep -Milliseconds 300
	}
	It 'プロセスがなければ0' {
		Get-ProcessCountByPath -Path $script:fakeFfmpeg | Should -Be 0
	}
	It '指定した実行ファイルのプロセスだけを数える(別パスの同名プロセスは数えない)' {
		$script:started += Start-Process -FilePath $script:fakeFfmpeg -ArgumentList '60' -PassThru
		$script:started += Start-Process -FilePath $script:otherFfmpeg -ArgumentList '60' -PassThru
		Start-Sleep -Milliseconds 500
		Get-ProcessCountByPath -Path $script:fakeFfmpeg | Should -Be 1
		Get-ProcessCountByPath -Path $script:otherFfmpeg | Should -Be 1
	}
	It '引数にパスが含まれているだけのプロセスは数えない' {
		$script:started += Start-Process -FilePath 'sh' -ArgumentList @('-c', '"sleep 60"', ('"{0}"' -f $script:fakeFfmpeg)) -PassThru
		Start-Sleep -Milliseconds 500
		$script:started[-1].HasExited | Should -BeFalse	# 起動直後に終了して素通りしていないことの確認
		Get-ProcessCountByPath -Path $script:fakeFfmpeg | Should -Be 0
	}
	It '-AllowInterpreter指定時はpython経由のスクリプトも数える' -Skip:(-not (Get-Command python3 -ErrorAction Ignore)) {
		$script:started += Start-Process -FilePath $script:fakeYtdl -PassThru
		Start-Sleep -Milliseconds 800
		Get-ProcessCountByPath -Path $script:fakeYtdl -AllowInterpreter | Should -Be 1
		Get-ProcessCountByPath -Path $script:fakeYtdl | Should -Be 0
	}
	It 'Get-FfmpegProcessCountは$script:ffmpegPathのプロセスだけを数える' {
		$script:ffmpegPath = $script:fakeFfmpeg
		$script:started += Start-Process -FilePath $script:fakeFfmpeg -ArgumentList '60' -PassThru
		$script:started += Start-Process -FilePath $script:otherFfmpeg -ArgumentList '60' -PassThru
		Start-Sleep -Milliseconds 500
		Get-FfmpegProcessCount | Should -Be 1
	}
	It 'Get-YtdlProcessCountは$script:ytdlPathのプロセスだけを数える' -Skip:(-not (Get-Command python3 -ErrorAction Ignore)) {
		$script:ytdlPath = $script:fakeYtdl
		Get-YtdlProcessCount | Should -Be 0
		$script:started += Start-Process -FilePath $script:fakeYtdl -PassThru
		Start-Sleep -Milliseconds 800
		Get-YtdlProcessCount | Should -Be 1
	}
}

Describe 'Group-DirectoryPathByLeaf' {
	It '同じフォルダ名のパスをすべて保持する' {
		$r = Group-DirectoryPathByLeaf -Path @('/lib/ドラマ/地獄先生', '/lib/アニメ/地獄先生', '/lib/ドラマ/別番組')
		@($r['地獄先生']).Count | Should -Be 2
		$r['地獄先生'] | Should -Contain '/lib/ドラマ/地獄先生'
		$r['地獄先生'] | Should -Contain '/lib/アニメ/地獄先生'
		@($r['別番組']).Count | Should -Be 1
	}
	It '同じパスの重複や末尾の区切り文字の違いは1つにまとめる' {
		$r = Group-DirectoryPathByLeaf -Path @('/lib/番組', '/lib/番組/', '/LIB/番組')
		@($r['番組']).Count | Should -Be 1
	}
	It 'キーの大文字小文字は区別しない' {
		$r = Group-DirectoryPathByLeaf -Path @('/lib/Show')
		$r.ContainsKey('show') | Should -BeTrue
	}
	It '空文字・$null・空配列でも例外にならず空を返す' {
		(Group-DirectoryPathByLeaf -Path @()).Count | Should -Be 0
		(Group-DirectoryPathByLeaf -Path @('', $null)).Count | Should -Be 0
		(Group-DirectoryPathByLeaf -Path $null).Count | Should -Be 0
	}
}

Describe 'Invoke-PowerShellUpdateCheck' {
	BeforeEach {
		$script:saveLogDir = if (Test-Path Variable:Script:logDir) { $script:logDir } else { $null }
		$script:saveDisable = if (Test-Path Variable:Script:disableCheckPowerShellUpdate) { $script:disableCheckPowerShellUpdate } else { $null }
		$script:logDir = Join-Path $TestDrive ('log{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:logDir | Out-Null
		$script:cacheFile = Join-Path $script:logDir 'powershell_update_check.txt'
		$script:disableCheckPowerShellUpdate = $false
		$script:timeoutSec = 5
		$script:restCalls = 0
		$script:restVersion = 'v99.0.0'
		Mock Invoke-RestMethod { $script:restCalls++ ; [PSCustomObject]@{ tag_name = $script:restVersion } }
	}
	AfterEach {
		$script:logDir = $script:saveLogDir
		$script:disableCheckPowerShellUpdate = $script:saveDisable
	}
	It '新しいバージョンがあれば案内を表示し、結果をキャッシュする' {
		$out = Invoke-PowerShellUpdateCheck 3>&1 6>&1 | Out-String
		$out | Should -Match '99\.0\.0'
		$script:restCalls | Should -Be 1
		(Get-Content -LiteralPath $script:cacheFile)[1] | Should -Be '99.0.0'
	}
	It '同じか古いバージョンなら案内を表示しない' {
		$script:restVersion = 'v1.0.0'
		$out = Invoke-PowerShellUpdateCheck 3>&1 6>&1 | Out-String
		$out | Should -Not -Match 'PowerShell'
	}
	It '24時間以内ならGitHubに問い合わせずキャッシュで判定する' {
		Set-Content -LiteralPath $script:cacheFile -Value @([DateTime]::UtcNow.AddHours(-1).ToString('o'), '99.0.0')
		$out = Invoke-PowerShellUpdateCheck 3>&1 6>&1 | Out-String
		$script:restCalls | Should -Be 0
		$out | Should -Match '99\.0\.0'
	}
	It '24時間を超えていたら再度問い合わせる' {
		Set-Content -LiteralPath $script:cacheFile -Value @([DateTime]::UtcNow.AddHours(-25).ToString('o'), '1.0.0')
		Invoke-PowerShellUpdateCheck 3>&1 6>&1 | Out-Null
		$script:restCalls | Should -Be 1
	}
	It '無効化設定なら何もしない' {
		$script:disableCheckPowerShellUpdate = $true
		Invoke-PowerShellUpdateCheck 3>&1 6>&1 | Out-Null
		$script:restCalls | Should -Be 0
	}
	It '取得に失敗しても例外にならず何も表示しない' {
		Mock Invoke-RestMethod { throw 'network error' }
		{ Invoke-PowerShellUpdateCheck 3>&1 6>&1 | Out-Null } | Should -Not -Throw
	}
	It '壊れたキャッシュや想定外のバージョン文字列でも例外にならない' {
		Set-Content -LiteralPath $script:cacheFile -Value @('not-a-date', 'x.y.z')
		$script:restVersion = 'nightly'
		{ Invoke-PowerShellUpdateCheck 3>&1 6>&1 | Out-Null } | Should -Not -Throw
	}
}

Describe '字幕の有無の記録と再ダウンロード(#312)' {
	BeforeAll {
		$script:subSaved = @{}
		foreach ($n in 'redownloadWhenSubtitleAdded', 'embedSubtitle', 'videoContainerFormat', 'ytdlPath', 'histFilePath', 'histLockFilePath', 'histHasSubtitleColumn', 'proxyUrl', 'ytdlRandomIp') {
			$script:subSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		$script:subDir = Join-Path ([IO.Path]::GetTempPath()) ('TVerRecSub{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:subDir | Out-Null
	}
	AfterAll {
		foreach ($n in $script:subSaved.Keys) {
			if ($script:subSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:subSaved[$n] }
		}
		Remove-Item -LiteralPath $script:subDir -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item Env:FAKE_YTDL_OUT, Env:FAKE_YTDL_EXIT -ErrorAction SilentlyContinue
	}
	BeforeEach {
		$script:redownloadWhenSubtitleAdded = $true
		$script:embedSubtitle = $true
		$script:videoContainerFormat = 'mp4'
		$script:histHasSubtitleColumn = $false
		$script:proxyUrl = ''
		$script:ytdlRandomIp = $false
	}

	Context 'Test-SubtitleTrackingEnabled' {
		It '設定が有効・字幕埋め込み有効・mp4なら有効' { Test-SubtitleTrackingEnabled | Should -BeTrue }
		It '設定が無効なら無効' { $script:redownloadWhenSubtitleAdded = $false ; Test-SubtitleTrackingEnabled | Should -BeFalse }
		It '字幕を埋め込まない設定なら無効' { $script:embedSubtitle = $false ; Test-SubtitleTrackingEnabled | Should -BeFalse }
		It 'mp4以外なら無効' { $script:videoContainerFormat = 'ts' ; Test-SubtitleTrackingEnabled | Should -BeFalse }
	}

	Context 'Get-VideoSubtitleStatus' -Skip:$IsWindows {
		BeforeAll {
			$script:ytdlPath = Join-Path $script:subDir 'yt-dlp'
			Set-Content -LiteralPath $script:ytdlPath -Value "#!/bin/sh`nprintf '%s' `"`$FAKE_YTDL_OUT`"`nexit `${FAKE_YTDL_EXIT:-0}`n"
			chmod +x $script:ytdlPath
		}
		It '字幕のJSONが返れば1' {
			$env:FAKE_YTDL_OUT = '{"ja": [{"url": "https://example.com/a.vtt", "ext": "vtt"}]}' ; $env:FAKE_YTDL_EXIT = '0'
			Get-VideoSubtitleStatus -EpisodePageURL 'https://tver.jp/episodes/epx' | Should -Be '1'
		}
		It 'NAが返れば0' {
			$env:FAKE_YTDL_OUT = 'NA' ; $env:FAKE_YTDL_EXIT = '0'
			Get-VideoSubtitleStatus -EpisodePageURL 'https://tver.jp/episodes/epx' | Should -Be '0'
		}
		It '空のJSONオブジェクトなら0' {
			$env:FAKE_YTDL_OUT = '{}' ; $env:FAKE_YTDL_EXIT = '0'
			Get-VideoSubtitleStatus -EpisodePageURL 'https://tver.jp/episodes/epx' | Should -Be '0'
		}
		It 'yt-dlpが失敗した場合は不明(空文字)' {
			$env:FAKE_YTDL_OUT = '' ; $env:FAKE_YTDL_EXIT = '1'
			Get-VideoSubtitleStatus -EpisodePageURL 'https://tver.jp/episodes/epx' | Should -Be ''
		}
		It '想定外の出力は不明(空文字)' {
			$env:FAKE_YTDL_OUT = 'unexpected output' ; $env:FAKE_YTDL_EXIT = '0'
			Get-VideoSubtitleStatus -EpisodePageURL 'https://tver.jp/episodes/epx' | Should -Be ''
		}
		It '出力がない場合は不明(空文字)' {
			$env:FAKE_YTDL_OUT = '' ; $env:FAKE_YTDL_EXIT = '0'
			Get-VideoSubtitleStatus -EpisodePageURL 'https://tver.jp/episodes/epx' | Should -Be ''
		}
	}

	Context '履歴ファイルの列追加' {
		BeforeEach {
			$script:histFilePath = Join-Path $script:subDir ('history{0}.csv' -f [Guid]::NewGuid().ToString('N'))
			$script:histLockFilePath = Join-Path $script:subDir 'history.lock'
			Mock Wait-FileLock {}
			Mock Unlock-File {}
			$header = '"videoPage","videoSeriesPage","genre","series","season","title","media","broadcastDate","downloadDate","videoDir","videoName","videoPath","videoValidated"'
			@($header, '"https://tver.jp/episodes/ep1","","tag/drama","番組A","","第1話","局","2026年01月01日放送","2026-01-01 00:00:00","d","a.mp4","a/a.mp4","1"') | Set-Content -LiteralPath $script:histFilePath -Encoding UTF8
		}
		It '列がなければTest-HistorySubtitleColumnは$false' { Test-HistorySubtitleColumn | Should -BeFalse }
		It 'Add-HistorySubtitleColumn: 列を追加し、既存の行の値は変えず、空の列を持たせる' {
			Add-HistorySubtitleColumn | Should -Be 'Added'
			Test-HistorySubtitleColumn | Should -BeTrue
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 1
			$rows[0].series | Should -Be '番組A'
			$rows[0].videoValidated | Should -Be '1'
			$rows[0].subtitle | Should -Be ''
			Test-Path ('{0}.bak' -f $script:histFilePath) | Should -BeTrue
		}
		It 'Add-HistorySubtitleColumn: すでに列があれば何もしない(冪等)' {
			Add-HistorySubtitleColumn | Out-Null
			$before = Get-Content -LiteralPath $script:histFilePath -Raw
			$script:histHasSubtitleColumn = $false
			Add-HistorySubtitleColumn | Should -Be 'Exists'
			Get-Content -LiteralPath $script:histFilePath -Raw | Should -Be $before
		}
		It 'Add-HistorySubtitleColumn: ヘッダーだけの履歴にも列を追加できる' {
			(Get-Content -LiteralPath $script:histFilePath -TotalCount 1) | Set-Content -LiteralPath $script:histFilePath -Encoding UTF8
			Add-HistorySubtitleColumn | Should -Be 'Added'
			Test-HistorySubtitleColumn | Should -BeTrue
			(Get-Content -LiteralPath $script:histFilePath -TotalCount 1) | Should -Match '"subtitle"$'
		}
		It 'Add-HistorySubtitleColumn: 追加後は新しい形式のレコードを追記できる' {
			Add-HistorySubtitleColumn | Out-Null
			$videoInfo = [PSCustomObject]@{ episodePageURL = 'https://tver.jp/episodes/ep2' ; seriesPageURL = '' ; keyword = 'k' ; seriesName = 's' ; seasonName = '' ; episodeName = 'e' ; mediaName = 'm' ; broadcastDate = 'b' ; fileDir = 'd' ; fileName = 'f.mp4' ; fileRelPath = 'd/f.mp4' ; validated = '0' ; subtitle = '1' }
			$record = Format-HistoryRecord $videoInfo
			$record.subtitle | Should -Be '1'
			{ $record | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append } | Should -Not -Throw
			@(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Count | Should -Be 2
		}
		It 'Format-HistoryRecord: 字幕の再確認の設定にかかわらず、常にsubtitle列を持つ(videoInfoにsubtitleがなければ空)' {
			$videoInfo = [PSCustomObject]@{ episodePageURL = 'u' ; seriesPageURL = '' ; keyword = 'k' ; seriesName = 's' ; seasonName = '' ; episodeName = 'e' ; mediaName = 'm' ; broadcastDate = 'b' ; fileDir = 'd' ; fileName = 'f.mp4' ; fileRelPath = 'd/f.mp4' ; validated = '0' }
			$script:redownloadWhenSubtitleAdded = $false
			(Format-HistoryRecord $videoInfo).PSObject.Properties['subtitle'] | Should -Not -BeNullOrEmpty
			(Format-HistoryRecord $videoInfo).subtitle | Should -Be ''
			$script:redownloadWhenSubtitleAdded = $true
			(Format-HistoryRecord $videoInfo).subtitle | Should -Be ''
		}
		It 'Format-HistoryRecord: レコードの列の並びは履歴ファイルの列の並びと一致する' {
			$videoInfo = [PSCustomObject]@{ episodePageURL = 'u' ; seriesPageURL = '' ; keyword = 'k' ; seriesName = 's' ; seasonName = '' ; episodeName = 'e' ; mediaName = 'm' ; broadcastDate = 'b' ; fileDir = 'd' ; fileName = 'f.mp4' ; fileRelPath = 'd/f.mp4' ; validated = '0' }
			$sampleHeader = (Get-Content -LiteralPath (Join-Path $script:repoRoot 'resources/sample/history.sample.csv') -TotalCount 1) -replace '"', ''
			(Format-HistoryRecord $videoInfo).PSObject.Properties.Name -join ',' | Should -Be $sampleHeader
		}
	}

	Context '字幕の再確認の対象を「ダウンロード済み」から除く' {
		BeforeAll {
			$script:subHists = @(
				[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_has' ; subtitle = '1' },
				[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_none' ; subtitle = '0' },
				[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_unknown' ; subtitle = '' }
			)
		}
		It 'Remove-SubtitleRecheckTarget: 有効なら字幕なし(0)の行だけ除く' {
			$r = @(Remove-SubtitleRecheckTarget $script:subHists)
			$r.Count | Should -Be 2
			$r.videoPage | Should -Not -Contain 'https://tver.jp/episodes/ep_none'
		}
		It 'Remove-SubtitleRecheckTarget: 無効なら何も除かない' {
			$script:redownloadWhenSubtitleAdded = $false
			@(Remove-SubtitleRecheckTarget $script:subHists).Count | Should -Be 3
		}
		It 'Remove-SubtitleRecheckTarget: subtitle列がない履歴は何も除かない' {
			$old = @([PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_old' })
			@(Remove-SubtitleRecheckTarget $old).Count | Should -Be 1
		}
		It 'Invoke-HistoryMatchCheck: 字幕なしの番組は未ダウンロードとして返し、字幕あり・不明は除外する' {
			Mock Get-LatestHistory { $script:subHists }
			$videoLinks, $processedCount = Invoke-HistoryMatchCheck @('ep_has', 'ep_none', 'ep_unknown', 'ep_new')
			@($videoLinks) | Should -Contain 'ep_none'
			@($videoLinks) | Should -Contain 'ep_new'
			@($videoLinks) | Should -Not -Contain 'ep_has'
			@($videoLinks) | Should -Not -Contain 'ep_unknown'
			$processedCount | Should -Be 2
		}
		It 'Invoke-HistoryMatchCheck: 設定が無効なら従来どおり履歴にある番組はすべて除外する' {
			$script:redownloadWhenSubtitleAdded = $false
			Mock Get-LatestHistory { $script:subHists }
			$videoLinks, $processedCount = Invoke-HistoryMatchCheck @('ep_has', 'ep_none', 'ep_unknown', 'ep_new')
			@($videoLinks) | Should -Be @('ep_new')
			$processedCount | Should -Be 3
		}
	}
}

Describe 'Invoke-VideoDownloadの字幕の分岐(#312)' {
	BeforeAll {
		$script:vdSaved = @{}
		foreach ($n in 'redownloadWhenSubtitleAdded', 'downloadWhenEpisodeIdChanged', 'embedSubtitle', 'videoContainerFormat', 'histFilePath', 'histLockFilePath', 'histHasSubtitleColumn', 'downloadBaseDir', 'sortVideoBySeries', 'sortVideoByMedia') {
			$script:vdSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		$script:vdDir = Join-Path ([IO.Path]::GetTempPath()) ('TVerRecVd{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:vdDir | Out-Null
		# Get-VideoInfoはtver_functions.ps1にあり、このテストでは読み込まないため、Mockできるようにスタブを用意する
		if (-not (Get-Command Get-VideoInfo -ErrorAction Ignore)) { function script:Get-VideoInfo { Param ($episodeID) } }
		function script:New-TestVideoInfo {
			Param ([String]$Id)
			[PSCustomObject]@{ episodeID = $Id ; episodePageURL = "https://tver.jp/episodes/$Id" ; seriesPageURL = 'https://tver.jp/series/sr1' ; seriesName = 'テスト番組' ; seasonName = '' ; episodeName = '第1話' ; episodeNum = '1' ; mediaName = 'テスト局' ; broadcastDate = '2026年01月01日放送' ; isSubtitle = $null }
		}
		$script:histHeader = '"videoPage","videoSeriesPage","genre","series","season","title","media","broadcastDate","downloadDate","videoDir","videoName","videoPath","videoValidated","subtitle"'
	}
	AfterAll {
		foreach ($n in $script:vdSaved.Keys) {
			if ($script:vdSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:vdSaved[$n] }
		}
		Remove-Item -LiteralPath $script:vdDir -Recurse -Force -ErrorAction SilentlyContinue
	}
	BeforeEach {
		$script:redownloadWhenSubtitleAdded = $true
		$script:downloadWhenEpisodeIdChanged = $true
		$script:embedSubtitle = $true
		$script:videoContainerFormat = 'mp4'
		$script:histHasSubtitleColumn = $false
		$script:sortVideoBySeries = $true
		$script:sortVideoByMedia = $false
		$script:downloadBaseDir = Join-Path $script:vdDir 'dl'
		$script:histFilePath = Join-Path $script:vdDir ('history{0}.csv' -f [Guid]::NewGuid().ToString('N'))
		$script:histLockFilePath = Join-Path $script:vdDir 'history.lock'
		$script:videoInfoToReturn = New-TestVideoInfo 'ep00000001'
		$script:ytdlCalls = 0
		$script:subtitleStatusToReturn = '1'
		$script:subtitleProbeCalls = 0
		$tmp = New-TestVideoInfo 'ep00000001'
		Format-VideoFileInfo ([Ref]$tmp)
		$script:expectedRelPath = $tmp.fileRelPath
		Set-Content -LiteralPath $script:histFilePath -Value $script:histHeader -Encoding UTF8
		Mock Invoke-StatisticsCheck {}
		Mock Show-VideoInfo {}
		Mock Wait-FileLock {}
		Mock Unlock-File {}
		Mock Start-Sleep {}
		Mock Read-IgnoreList { @() }
		Mock Get-VideoInfo { $script:videoInfoToReturn }
		Mock Invoke-Ytdl { $script:ytdlCalls++ }
		Mock Get-VideoSubtitleStatus { $script:subtitleProbeCalls++ ; $script:subtitleStatusToReturn }
	}
	It '新規のダウンロード: ダウンロード前に字幕の有無を確認し、履歴に記録する' {
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 1
		$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		$rows.Count | Should -Be 1
		$rows[0].subtitle | Should -Be '1'
		$rows[0].videoValidated | Should -Be '0'
	}
	It '新規のダウンロード: 設定が無効なら字幕の確認をしない' {
		$script:redownloadWhenSubtitleAdded = $false
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 1
		$script:subtitleProbeCalls | Should -Be 0
	}
	It '字幕なしで保存済みの番組: まだ字幕がなければダウンロードせず、履歴も変えない' {
		Add-Content -LiteralPath $script:histFilePath -Value ('"https://tver.jp/episodes/ep00000001","","k","テスト番組","","第1話","テスト局","b","2026-01-01 00:00:00","d","n.mp4","{0}","1","0"' -f $script:expectedRelPath) -Encoding UTF8
		$script:subtitleStatusToReturn = '0'
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 0
		@(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Count | Should -Be 1
	}
	It '字幕なしで保存済みの番組: 確認に失敗(不明)した場合もダウンロードしない' {
		Add-Content -LiteralPath $script:histFilePath -Value ('"https://tver.jp/episodes/ep00000001","","k","テスト番組","","第1話","テスト局","b","2026-01-01 00:00:00","d","n.mp4","{0}","1","0"' -f $script:expectedRelPath) -Encoding UTF8
		$script:subtitleStatusToReturn = ''
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 0
	}
	It '字幕なしで保存済みの番組: 字幕が追加されていれば再ダウンロードし、字幕ありとして記録する' {
		Add-Content -LiteralPath $script:histFilePath -Value ('"https://tver.jp/episodes/ep00000001","","k","テスト番組","","第1話","テスト局","b","2026-01-01 00:00:00","d","n.mp4","{0}","1","0"' -f $script:expectedRelPath) -Encoding UTF8
		$script:subtitleStatusToReturn = '1'
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 1
		$script:subtitleProbeCalls | Should -Be 1	# 再確認の1回だけで、ダウンロード前の確認を重ねない
		$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		$rows.Count | Should -Be 2
		$rows[1].subtitle | Should -Be '1'
		$rows[1].videoValidated | Should -Be '0'
	}
	It '字幕付きで保存済みの同名番組が別のエピソードIDで再配信: ダウンロードする(上書き防止は番組移動時に行う)' {
		Add-Content -LiteralPath $script:histFilePath -Value ('"https://tver.jp/episodes/ep_old","","k","テスト番組","","第1話","テスト局","b","2026-01-01 00:00:00","d","n.mp4","{0}","1","1"' -f $script:expectedRelPath) -Encoding UTF8
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 1
	}
	It '字幕なしで保存済みの同名番組が別のエピソードIDで再配信: 従来どおりダウンロードする' {
		Add-Content -LiteralPath $script:histFilePath -Value ('"https://tver.jp/episodes/ep_old","","k","テスト番組","","第1話","テスト局","b","2026-01-01 00:00:00","d","n.mp4","{0}","1","0"' -f $script:expectedRelPath) -Encoding UTF8
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 1
	}
	It '新規のダウンロード: yt-dlp起動後の待機は1秒(5秒待たない)' {
		Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
		$script:ytdlCalls | Should -Be 1
		Should -Invoke Start-Sleep -Times 0 -Exactly -ParameterFilter { $Seconds -eq 5 }
		Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 1 }
	}
	It '履歴・無視リストのキャッシュがあるとき: ファイルを読み直さず、ダウンロードした番組の履歴をキャッシュに反映する' {
		$script:histCache = @()
		$script:ignoreCache = @()
		Mock Get-LatestHistory { throw 'キャッシュがあるのに履歴ファイルを読んだ' }
		Mock Read-IgnoreList { throw 'キャッシュがあるのに無視リストを読んだ' }
		try {
			Invoke-VideoDownload -Keyword 'k' -episodeID 'ep00000001' -Force $false 6>$null 3>$null
			$script:ytdlCalls | Should -Be 1
			Should -Invoke Get-LatestHistory -Times 0 -Exactly
			Should -Invoke Read-IgnoreList -Times 0 -Exactly
			@($script:histCache).Count | Should -Be 1
			@($script:histCache)[0].videoPage | Should -Be 'https://tver.jp/episodes/ep00000001'
			@(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Count | Should -Be 1	# 履歴ファイルにも書かれている
		} finally { Remove-Variable -Name histCache, histIdSet, ignoreCache -Scope Script -ErrorAction SilentlyContinue }
	}
}

#----------------------------------------------------------------------
# 一括ダウンロード用のキャッシュ(履歴・無視リスト)
# * download_bulk.ps1が実行開始時に$script:histCache/$script:ignoreCacheを設定し、番組ごとの全件読み込みを避ける
#----------------------------------------------------------------------
Describe '一括ダウンロード用のキャッシュ' {
	BeforeAll {
		$script:cacheSaved = @{}
		foreach ($n in 'redownloadWhenSubtitleAdded', 'embedSubtitle', 'videoContainerFormat') {
			$script:cacheSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		function script:Remove-TestCacheVariable { Remove-Variable -Name histCache, histIdSet, ignoreCache -Scope Script -ErrorAction SilentlyContinue }
	}
	AfterAll {
		Remove-TestCacheVariable
		foreach ($n in $script:cacheSaved.Keys) {
			if ($script:cacheSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:cacheSaved[$n] }
		}
	}
	BeforeEach {
		Remove-TestCacheVariable
		$script:redownloadWhenSubtitleAdded = $true
		$script:embedSubtitle = $true
		$script:videoContainerFormat = 'mp4'
		$script:cacheHists = @(
			[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_has' ; subtitle = '1' },
			[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_none' ; subtitle = '0' },
			[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_unknown' ; subtitle = '' }
		)
		Mock Get-LatestHistory { $script:cacheHists }
		Mock Read-IgnoreList { @('ignoreA', 'ignoreB') }
	}
	AfterEach { Remove-TestCacheVariable }

	Context 'Get-LatestHistoryCached' {
		It 'キャッシュがなければ履歴ファイルを読む' {
			@(Get-LatestHistoryCached).Count | Should -Be 3
			Should -Invoke Get-LatestHistory -Times 1 -Exactly
		}
		It 'キャッシュがあれば履歴ファイルを読まずにキャッシュを返す' {
			$script:histCache = @([PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_cached' ; subtitle = '1' })
			$r = @(Get-LatestHistoryCached)
			$r.Count | Should -Be 1
			$r[0].videoPage | Should -Be 'https://tver.jp/episodes/ep_cached'
			Should -Invoke Get-LatestHistory -Times 0 -Exactly
		}
		It '空のキャッシュでも履歴ファイルを読まない(履歴が空の環境)' {
			$script:histCache = @()
			@(Get-LatestHistoryCached).Count | Should -Be 0
			Should -Invoke Get-LatestHistory -Times 0 -Exactly
		}
	}

	Context 'Add-LatestHistoryCache' {
		It 'キャッシュがなければ何もしない(キャッシュ変数を作らない)' {
			Add-LatestHistoryCache ([PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_x' })
			Test-Path Variable:Script:histCache | Should -BeFalse
		}
		It '同じvideoPageのレコードは置き換え、なければ追加し、ダウンロード済みIDのキャッシュを破棄する' {
			$script:histCache = @(
				[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_a' ; subtitle = '0' },
				[PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_b' ; subtitle = '1' }
			)
			$script:histIdSet = [System.Collections.Generic.HashSet[String]]::new()
			Add-LatestHistoryCache ([PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_a' ; subtitle = '1' })
			Add-LatestHistoryCache ([PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_c' ; subtitle = '0' })
			@($script:histCache).Count | Should -Be 3
			@($script:histCache).Where({ $_.videoPage -eq 'https://tver.jp/episodes/ep_a' }).Count | Should -Be 1
			@($script:histCache).Where({ $_.videoPage -eq 'https://tver.jp/episodes/ep_a' })[0].subtitle | Should -Be '1'
			$script:histIdSet | Should -BeNullOrEmpty
		}
		It 'レコードがnullなら何もしない' {
			$script:histCache = @([PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_a' ; subtitle = '0' })
			Add-LatestHistoryCache $null
			@($script:histCache).Count | Should -Be 1
		}
	}

	Context 'Get-IgnoreListCached' {
		It 'キャッシュがなければ無視リストのファイルを読む' {
			@(Get-IgnoreListCached) | Should -Be @('ignoreA', 'ignoreB')
			Should -Invoke Read-IgnoreList -Times 1 -Exactly
		}
		It 'キャッシュがあればファイルを読まずにキャッシュを返す' {
			$script:ignoreCache = @('cached')
			@(Get-IgnoreListCached) | Should -Be @('cached')
			Should -Invoke Read-IgnoreList -Times 0 -Exactly
		}
		It '空のキャッシュでもファイルを読まない(無視リストが空の環境)' {
			$script:ignoreCache = @()
			@(Get-IgnoreListCached).Count | Should -Be 0
			Should -Invoke Read-IgnoreList -Times 0 -Exactly
		}
	}

	Context 'Invoke-HistoryMatchCheck(履歴キャッシュあり)' {
		It 'キャッシュなしと同じ結果を返す(字幕なしは未ダウンロード扱い)' {
			$noCacheLinks, $noCacheCount = Invoke-HistoryMatchCheck @('ep_has', 'ep_none', 'ep_unknown', 'ep_new')
			$script:histCache = $script:cacheHists
			$links, $count = Invoke-HistoryMatchCheck @('ep_has', 'ep_none', 'ep_unknown', 'ep_new')
			@($links) | Should -Be @($noCacheLinks)
			$count | Should -Be $noCacheCount
			@($links) | Should -Be @('ep_none', 'ep_new')
			$count | Should -Be 2
		}
		It '設定が無効なら、字幕なしも含めて履歴にある番組をすべて除外する' {
			$script:redownloadWhenSubtitleAdded = $false
			$script:histCache = $script:cacheHists
			$links, $count = Invoke-HistoryMatchCheck @('ep_has', 'ep_none', 'ep_unknown', 'ep_new')
			@($links) | Should -Be @('ep_new')
			$count | Should -Be 3
		}
		It '履歴ファイルを読まず、ダウンロード済みIDのHashSetを使い回す' {
			$script:histCache = $script:cacheHists
			Invoke-HistoryMatchCheck @('ep_new') | Out-Null
			$first = $script:histIdSet
			($first -is [System.Collections.Generic.HashSet[String]]) | Should -BeTrue
			Invoke-HistoryMatchCheck @('ep_has') | Out-Null
			[Object]::ReferenceEquals($first, $script:histIdSet) | Should -BeTrue
			Should -Invoke Get-LatestHistory -Times 0 -Exactly
		}
		It '大文字小文字を区別しない(Compare-Objectと同じ)' {
			$script:histCache = $script:cacheHists
			$links, $count = Invoke-HistoryMatchCheck @('EP_HAS')
			@($links).Count | Should -Be 0
			$count | Should -Be 1
		}
		It 'Add-LatestHistoryCacheで追加した番組は、次の判定でダウンロード済みになる' {
			$script:histCache = $script:cacheHists
			$links, $count = Invoke-HistoryMatchCheck @('ep_new')
			@($links) | Should -Be @('ep_new')
			Add-LatestHistoryCache ([PSCustomObject]@{ videoPage = 'https://tver.jp/episodes/ep_new' ; subtitle = '1' })
			$links, $count = Invoke-HistoryMatchCheck @('ep_new')
			@($links).Count | Should -Be 0
			$count | Should -Be 1
		}
		It '履歴が空のキャッシュなら、すべて未ダウンロードとして返す' {
			$script:histCache = @()
			$links, $count = Invoke-HistoryMatchCheck @('ep_a', 'ep_b')
			@($links) | Should -Be @('ep_a', 'ep_b')
			$count | Should -Be 0
		}
	}
}

#----------------------------------------------------------------------
# youtube-dlプロセスの空き待ち
#----------------------------------------------------------------------
Describe 'Wait-YtdlProcess' {
	It '同時実行数が上限に達している間は、10秒間隔で空きを確認する' {
		$script:ytdlCountQueue = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(5, 5, 0))
		Mock Get-YtdlProcessCount { $script:ytdlCountQueue.Dequeue() }
		Mock Start-Sleep {}
		Wait-YtdlProcess 5 6>$null | Out-Null
		Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 10 }
	}
	It '上限未満なら待たない' {
		Mock Get-YtdlProcessCount { 4 }
		Mock Start-Sleep {}
		Wait-YtdlProcess 5 6>$null | Out-Null
		Should -Invoke Start-Sleep -Times 0 -Exactly
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴の安全な保存・字幕の有無の更新
#----------------------------------------------------------------------
Describe 'ダウンロード履歴の書き込み' {
	BeforeAll {
		$script:wSaved = @{}
		foreach ($n in 'histFilePath', 'histLockFilePath', 'histHasSubtitleColumn') {
			$script:wSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		$script:wHeader = '"videoPage","videoSeriesPage","genre","series","season","title","media","broadcastDate","downloadDate","videoDir","videoName","videoPath","videoValidated","subtitle"'
		$script:wHeaderNoSubtitle = '"videoPage","videoSeriesPage","genre","series","season","title","media","broadcastDate","downloadDate","videoDir","videoName","videoPath","videoValidated"'
		function script:Get-TestWriteRow {
			Param ([String]$Id, [String]$Subtitle = '0')
			return ('"https://tver.jp/episodes/{0}"' -f $Id) + (',""' * 7) + ',"2026-01-01 00:00:00"' + (',""' * 3) + (',"1","{0}"' -f $Subtitle)
		}
	}
	AfterAll {
		foreach ($n in $script:wSaved.Keys) {
			if ($script:wSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:wSaved[$n] }
		}
	}
	BeforeEach {
		Mock Wait-FileLock {}
		Mock Unlock-File {}
		Mock Start-Sleep {}
		Mock Write-Warning {}
		Remove-Variable -Name histHasSubtitleColumn -Scope Script -ErrorAction SilentlyContinue	# 列の有無はファイルごとに判定し直す
		$script:wDir = Join-Path $TestDrive ('write{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:wDir -Force | Out-Null
		$script:histFilePath = Join-Path $script:wDir 'history.csv'
		$script:histLockFilePath = Join-Path $script:wDir 'history.lock'
	}

	Context 'Save-HistoryFile' {
		It 'レコードをCSVで保存し、直前の履歴を.bakに退避すること' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader, (Get-TestWriteRow 'epAAAAAAAA'), (Get-TestWriteRow 'epBBBBBBBB'))
			$records = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 | Where-Object { $_.videoPage -like '*epAAAAAAAA' })
			Save-HistoryFile -Records $records
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 1
			$rows[0].videoPage | Should -Be 'https://tver.jp/episodes/epAAAAAAAA'
			$bak = $script:histFilePath + '.bak'
			Test-Path -LiteralPath $bak | Should -BeTrue
			@(Import-Csv -LiteralPath $bak -Encoding UTF8).Count | Should -Be 2
		}
		It '保存後に一時ファイルが残らないこと' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader, (Get-TestWriteRow 'epAAAAAAAA'))
			Save-HistoryFile -Records @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			@(Get-ChildItem -LiteralPath $script:wDir -Filter '*.tmp').Count | Should -Be 0
		}
		It 'レコードが0件なら、元のCSVヘッダーだけを残すこと' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader, (Get-TestWriteRow 'epAAAAAAAA'))
			Save-HistoryFile -Records @()
			@(Get-Content -LiteralPath $script:histFilePath).Count | Should -Be 1
			(Get-Content -LiteralPath $script:histFilePath -TotalCount 1) | Should -Be $script:wHeader
			@(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Count | Should -Be 0
		}
		It 'レコードが$nullでも、元のCSVヘッダーだけを残すこと' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader, (Get-TestWriteRow 'epAAAAAAAA'))
			Save-HistoryFile -Records $null
			(Get-Content -LiteralPath $script:histFilePath -TotalCount 1) | Should -Be $script:wHeader
			@(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Count | Should -Be 0
		}
		It 'ヘッダーだけに整理したあとも、新しいレコードを追記して読み取れること' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader, (Get-TestWriteRow 'epAAAAAAAA'))
			Save-HistoryFile -Records @()
			Add-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value (Get-TestWriteRow 'epNEW00001')
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 1
			$rows[0].videoPage | Should -Be 'https://tver.jp/episodes/epNEW00001'
		}
		It 'テキスト行で保存できること' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader)
			Save-HistoryFile -Lines @('line1', 'line2')
			@(Get-Content -LiteralPath $script:histFilePath) | Should -Be @('line1', 'line2')
		}
		It 'テキスト行が空なら、空のファイルになること' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader)
			Save-HistoryFile -Lines @()
			(Get-Item -LiteralPath $script:histFilePath).Length | Should -Be 0
		}
		It '履歴ファイルのヘッダーが読めず保存に失敗したときは、例外にして元の履歴を変更しないこと' {
			Set-Content -LiteralPath $script:histFilePath -Value ''	# ヘッダーのない履歴
			$before = [IO.File]::ReadAllText($script:histFilePath)
			{ Save-HistoryFile -Records @() } | Should -Throw
			[IO.File]::ReadAllText($script:histFilePath) | Should -Be $before
			@(Get-ChildItem -LiteralPath $script:wDir -Filter '*.tmp').Count | Should -Be 0
		}
	}

	Context 'Set-HistorySubtitleStatus' {
		BeforeEach {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeader, (Get-TestWriteRow 'epAAAAAAAA' '0'))
			$script:wHist = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)[0]
		}
		It '履歴のレコードをコピーして、字幕の有無とダウンロード日時を更新したレコードを追記すること' {
			Set-HistorySubtitleStatus -VideoHist $script:wHist -Status '1'
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 2
			$rows[0].subtitle | Should -Be '0'	# 元のレコードは変わらない
			$rows[1].subtitle | Should -Be '1'
			$rows[1].videoPage | Should -Be 'https://tver.jp/episodes/epAAAAAAAA'
			$rows[1].downloadDate | Should -Not -Be '2026-01-01 00:00:00'
			[DateTime]::TryParse($rows[1].downloadDate, [Ref][DateTime]::MinValue) | Should -BeTrue
		}
		It '渡したレコード自体は変更しないこと' {
			Set-HistorySubtitleStatus -VideoHist $script:wHist -Status '1'
			$script:wHist.subtitle | Should -Be '0'
			$script:wHist.downloadDate | Should -Be '2026-01-01 00:00:00'
		}
		It '字幕の有無が不明(空文字)でも記録できること' {
			Set-HistorySubtitleStatus -VideoHist $script:wHist -Status ''
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 2
			$rows[1].subtitle | Should -Be ''
		}
		It '履歴ファイルのロックを取得して、処理後に解放すること' {
			Set-HistorySubtitleStatus -VideoHist $script:wHist -Status '1'
			Should -Invoke Wait-FileLock -Times 1 -Exactly
			Should -Invoke Unlock-File -Times 1 -Exactly
		}
		It 'subtitle列がない履歴には何も追記しないこと' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:wHeaderNoSubtitle, ('"https://tver.jp/episodes/epAAAAAAAA"' + (',""' * 7) + ',"2026-01-01 00:00:00"' + (',""' * 3) + ',"1"'))
			$before = [IO.File]::ReadAllText($script:histFilePath)
			Set-HistorySubtitleStatus -VideoHist $script:wHist -Status '1'
			[IO.File]::ReadAllText($script:histFilePath) | Should -Be $before
			Should -Invoke Wait-FileLock -Times 0 -Exactly
		}
		It '-WhatIfでは追記しないこと' {
			$before = [IO.File]::ReadAllText($script:histFilePath)
			Set-HistorySubtitleStatus -VideoHist $script:wHist -Status '1' -WhatIf
			[IO.File]::ReadAllText($script:histFilePath) | Should -Be $before
		}
		It '追記に失敗したときは警告を出し、例外にせず、ロックも解放すること' {
			Mock Export-Csv { throw 'disk full' }
			{ Set-HistorySubtitleStatus -VideoHist $script:wHist -Status '1' } | Should -Not -Throw
			Should -Invoke Write-Warning -Times 1 -Exactly
			Should -Invoke Unlock-File -Times 1 -Exactly
		}
	}
}

#----------------------------------------------------------------------
# ダウンロードリストへの追加
#----------------------------------------------------------------------
Describe 'Update-VideoList' {
	BeforeAll {
		$script:ulSaved = @{}
		foreach ($n in 'listFilePath', 'listLockFilePath', 'extractDescTextToList') {
			$script:ulSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		# Get-VideoInfoはtver_functions.ps1にあり、このテストでは読み込まないため、Mockできるようにスタブを用意する
		if (-not (Get-Command Get-VideoInfo -ErrorAction Ignore)) { function script:Get-VideoInfo { Param ($episodeID) } }
		function script:New-TestListVideoInfo {
			Param ([String]$Id = 'epLIST0001')
			[PSCustomObject]@{
				seriesName = 'テスト番組' ; seriesID = 'sr1' ; seriesPageURL = 'https://tver.jp/series/sr1'
				seasonName = '' ; seasonID = 'ss1' ; episodeNum = '03' ; episodeName = '第3話'
				episodeID = $Id ; episodePageURL = "https://tver.jp/episodes/$Id"
				mediaName = 'テスト局' ; providerName = 'テスト提供' ; broadcastDate = '2026年10月24日放送' ; endTime = '2026/11/01 00:00'
				descriptionText = '説明文です'
			}
		}
	}
	AfterAll {
		foreach ($n in $script:ulSaved.Keys) {
			if ($script:ulSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:ulSaved[$n] }
		}
	}
	BeforeEach {
		Mock Invoke-StatisticsCheck {}
		Mock Wait-FileLock {}
		Mock Unlock-File {}
		Mock Write-Warning {}
		Mock Update-IgnoreList {}
		Mock Read-IgnoreList { @() }
		Mock Get-VideoInfo { New-TestListVideoInfo }
		$script:ulDir = Join-Path $TestDrive ('ul{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:ulDir -Force | Out-Null
		$script:listFilePath = Join-Path $script:ulDir 'list.csv'
		$script:listLockFilePath = Join-Path $script:ulDir 'list.lock'
		$script:extractDescTextToList = $false
	}
	It '対象外ではない番組は、キーワードを付けてダウンロードリストに追加すること' {
		Update-VideoList -keyword 'tag/drama' -episodeID 'epLIST0001' | Out-Null
		$rows = @(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)
		$rows.Count | Should -Be 1
		$rows[0].episodeID | Should -Be 'epLIST0001'
		$rows[0].seriesName | Should -Be 'テスト番組'
		$rows[0].episodeName | Should -Be '第3話'
		$rows[0].keyword | Should -Be 'tag/drama'
		$rows[0].ignoreWord | Should -Be ''
		Should -Invoke Update-IgnoreList -Times 0 -Exactly
		Should -Invoke Write-Warning -Times 0 -Exactly
	}
	It '呼ぶたびに追記され、ヘッダーは1回だけになること' {
		Mock Get-VideoInfo { New-TestListVideoInfo $episodeID }
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' | Out-Null
		Update-VideoList -keyword 'k' -episodeID 'epLIST0002' | Out-Null
		$rows = @(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)
		$rows.episodeID | Should -Be @('epLIST0001', 'epLIST0002')
		@(Get-Content -LiteralPath $script:listFilePath).Count | Should -Be 3
	}
	It 'ダウンロード対象外に合致する番組は、エピソードIDの先頭に#を付け、合致した語を記録し、無視リストを更新すること' {
		Mock Read-IgnoreList { @('テスト番組') }
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' 3>$null | Out-Null
		$rows = @(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)
		$rows.Count | Should -Be 1
		$rows[0].episodeID | Should -Be '#epLIST0001'
		$rows[0].ignoreWord | Should -Be 'テスト番組'
		Should -Invoke Update-IgnoreList -Times 1 -Exactly -ParameterFilter { $ignoreTitle -eq 'テスト番組' }
		Should -Invoke Write-Warning -Times 1 -Exactly
	}
	It 'エピソード名だけに合致する場合も対象外として扱うこと' {
		Mock Read-IgnoreList { @('第3話') }
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' 3>$null | Out-Null
		(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)[0].episodeID | Should -Be '#epLIST0001'
	}
	It '空の行や合致しない語は無視し、対象外にしないこと' {
		Mock Read-IgnoreList { @('', '別の番組') }
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' | Out-Null
		(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)[0].episodeID | Should -Be 'epLIST0001'
		Should -Invoke Update-IgnoreList -Times 0 -Exactly
	}
	It '説明文の出力が有効なら、説明文もリストに含めること' {
		$script:extractDescTextToList = $true
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' | Out-Null
		(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)[0].descriptionText | Should -Be '説明文です'
	}
	It '番組情報が取得できなかったときは警告を出し、リストに追加しないこと' {
		Mock Get-VideoInfo { $null }
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' | Out-Null
		Test-Path -LiteralPath $script:listFilePath | Should -BeFalse
		Should -Invoke Write-Warning -Times 1 -Exactly
		Should -Invoke Wait-FileLock -Times 0 -Exactly
	}
	It 'リストへの書き込みに失敗したときは警告を出し、例外にせず、ロックも解放すること' {
		Mock Export-Csv { throw 'disk full' }
		{ Update-VideoList -keyword 'k' -episodeID 'epLIST0001' | Out-Null } | Should -Not -Throw
		Should -Invoke Write-Warning -Times 1 -Exactly
		Should -Invoke Unlock-File -Times 1 -Exactly
	}
	It '-WhatIfではリストに追加しないこと' {
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' -WhatIf | Out-Null
		Test-Path -LiteralPath $script:listFilePath | Should -BeFalse
	}
	It 'リストファイルのロックを取得して、処理後に解放すること' {
		Update-VideoList -keyword 'k' -episodeID 'epLIST0001' | Out-Null
		Should -Invoke Wait-FileLock -Times 1 -Exactly
		Should -Invoke Unlock-File -Times 1 -Exactly
	}
}

#----------------------------------------------------------------------
# バージョン比較
#----------------------------------------------------------------------
Describe 'Compare-Version' {
	It 'remote=<remote> と local=<local> を比較すると <expected>' -ForEach @(
		@{ remote = '1.2.3' ; local = '1.2.3' ; expected = 0 }
		@{ remote = '1.2.4' ; local = '1.2.3' ; expected = 1 }
		@{ remote = '1.2.3' ; local = '1.2.4' ; expected = -1 }
		@{ remote = '1.10' ; local = '1.9' ; expected = 1 }	# 文字列ではなく数値として比較する
		@{ remote = '1.9' ; local = '1.10' ; expected = -1 }
		@{ remote = '3.4.10' ; local = '3.4.9' ; expected = 1 }
		@{ remote = '2' ; local = '1.9.9' ; expected = 1 }
		@{ remote = '1.2' ; local = '1.2.3' ; expected = -1 }	# 前半が同じなら、ユニット数が多い方が新しい
		@{ remote = '1.2.3' ; local = '1.2' ; expected = 1 }
	) {
		Compare-Version -remote $remote -local $local | Should -Be $expected
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴ファイルの整理(Optimize / Limit / Repair)
#----------------------------------------------------------------------
Describe 'ダウンロード履歴ファイルの整理' {
	BeforeAll {
		$script:histSaved = @{}
		foreach ($n in 'histFilePath', 'histLockFilePath') {
			$script:histSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		$script:histTestHeader = '"videoPage","videoSeriesPage","genre","series","season","title","media","broadcastDate","downloadDate","videoDir","videoName","videoPath","videoValidated","subtitle"'
		function script:Get-TestHistRow {
			Param ([String]$Id, [String]$Date, [String]$Validated = '1')
			return ('"https://tver.jp/episodes/{0}"' -f $Id) + (',""' * 7) + (',"{0}"' -f $Date) + (',""' * 3) + (',"{0}"' -f $Validated) + ',""'
		}
		$script:dateFormat = 'yyyy-MM-dd HH:mm:ss'
	}
	AfterAll {
		foreach ($n in $script:histSaved.Keys) {
			if ($script:histSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:histSaved[$n] }
		}
	}
	BeforeEach {
		Mock Wait-FileLock {}
		Mock Unlock-File {}
		Mock Start-Sleep {}
		$script:histTestDir = Join-Path $TestDrive ('hist{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:histTestDir -Force | Out-Null
		$script:histFilePath = Join-Path $script:histTestDir 'history.csv'
		$script:histLockFilePath = Join-Path $script:histTestDir 'history.lock'
		$script:now = Get-Date
	}

	Context 'Optimize-HistoryFile' {
		It 'NULL文字を含む行を取り除く' {
			$good1 = Get-TestHistRow -Id 'epAAAAAAAA' -Date $script:now.ToString($script:dateFormat)
			$good2 = Get-TestHistRow -Id 'epBBBBBBBB' -Date $script:now.ToString($script:dateFormat)
			Set-Content -LiteralPath $script:histFilePath -Value @($script:histTestHeader, $good1, "broken`0line", $good2) -Encoding UTF8
			Optimize-HistoryFile 3>$null
			(Get-Content -LiteralPath $script:histFilePath -Raw) | Should -Not -Match "`0"
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 2
			$rows.videoPage | Should -Be @('https://tver.jp/episodes/epAAAAAAAA', 'https://tver.jp/episodes/epBBBBBBBB')
		}
		It 'videoValidatedが整数でない行と、downloadDateが日付でない行を取り除く' {
			$date = $script:now.ToString($script:dateFormat)
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @(
				$script:histTestHeader
				(Get-TestHistRow -Id 'epOK000001' -Date $date -Validated '1')
				(Get-TestHistRow -Id 'epBadVal01' -Date $date -Validated 'abc')
				(Get-TestHistRow -Id 'epEmptyVal' -Date $date -Validated '')
				(Get-TestHistRow -Id 'epBadDate1' -Date 'invalid')
				(Get-TestHistRow -Id 'epBadDate2' -Date '2026-13-45 00:00:00')
			)
			Optimize-HistoryFile 3>$null
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 1
			$rows[0].videoPage | Should -Be 'https://tver.jp/episodes/epOK000001'
		}
		It '問題のない履歴は内容を変えない' {
			$date = $script:now.ToString($script:dateFormat)
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:histTestHeader, (Get-TestHistRow -Id 'epAAAAAAAA' -Date $date -Validated '0'), (Get-TestHistRow -Id 'epBBBBBBBB' -Date $date -Validated '3'))
			Optimize-HistoryFile 3>$null
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 2
			$rows[0].videoValidated | Should -Be '0'
			$rows[1].videoValidated | Should -Be '3'
			$rows[0].downloadDate | Should -Be $date
		}
		It '処理の前後でロックを取得・解除する' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:histTestHeader, (Get-TestHistRow -Id 'epAAAAAAAA' -Date $script:now.ToString($script:dateFormat)))
			Optimize-HistoryFile 3>$null
			Should -Invoke Wait-FileLock -Times 2 -Exactly
			Should -Invoke Unlock-File -Times 2 -Exactly
		}
	}

	Context 'Limit-HistoryFile' {
		It '指定日数より前の履歴を取り除き、期間内の履歴は残す' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @(
				$script:histTestHeader
				(Get-TestHistRow -Id 'epRecent01' -Date $script:now.AddDays(-10).ToString($script:dateFormat))
				(Get-TestHistRow -Id 'epOld00001' -Date $script:now.AddDays(-40).ToString($script:dateFormat))
				(Get-TestHistRow -Id 'epToday001' -Date $script:now.ToString($script:dateFormat))
			)
			Limit-HistoryFile -retentionPeriod 30 3>$null
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.videoPage | Should -Be @('https://tver.jp/episodes/epRecent01', 'https://tver.jp/episodes/epToday001')
		}
		It '保持期間が短ければ、より新しい履歴も取り除く' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @(
				$script:histTestHeader
				(Get-TestHistRow -Id 'epRecent01' -Date $script:now.AddDays(-10).ToString($script:dateFormat))
				(Get-TestHistRow -Id 'epToday001' -Date $script:now.ToString($script:dateFormat))
			)
			Limit-HistoryFile -retentionPeriod 5 3>$null
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 1
			$rows[0].videoPage | Should -Be 'https://tver.jp/episodes/epToday001'
		}
		It '日付を解釈できない行がある場合は、履歴を変更しない' {
			$lines = @($script:histTestHeader, (Get-TestHistRow -Id 'epRecent01' -Date $script:now.AddDays(-10).ToString($script:dateFormat)), (Get-TestHistRow -Id 'epBadDate1' -Date 'invalid'))
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value $lines
			$before = Get-Content -LiteralPath $script:histFilePath -Raw
			{ Limit-HistoryFile -retentionPeriod 30 3>$null } | Should -Not -Throw
			Get-Content -LiteralPath $script:histFilePath -Raw | Should -Be $before
		}
		It '失敗してもロックを解除する' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:histTestHeader, (Get-TestHistRow -Id 'epBadDate1' -Date 'invalid'))
			Limit-HistoryFile -retentionPeriod 30 3>$null
			Should -Invoke Unlock-File -Times 1 -Exactly
		}
	}

	Context 'Repair-HistoryFile' {
		It 'videoPageが重複している場合は、最新のdownloadDateのレコードだけ残す' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @(
				$script:histTestHeader
				(Get-TestHistRow -Id 'epAAAAAAAA' -Date '2026-01-01 00:00:00' -Validated '0')
				(Get-TestHistRow -Id 'epBBBBBBBB' -Date '2026-01-02 00:00:00' -Validated '1')
				(Get-TestHistRow -Id 'epAAAAAAAA' -Date '2026-01-03 00:00:00' -Validated '1')
			)
			Repair-HistoryFile 3>$null
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 2
			($rows.Where({ $_.videoPage -like '*epAAAAAAAA' })).downloadDate | Should -Be '2026-01-03 00:00:00'
			($rows.Where({ $_.videoPage -like '*epAAAAAAAA' })).videoValidated | Should -Be '1'
		}
		It '最新のレコードがvideoValidated=3(検証失敗)の番組は、履歴から取り除く' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @(
				$script:histTestHeader
				(Get-TestHistRow -Id 'epAAAAAAAA' -Date '2026-01-01 00:00:00' -Validated '1')
				(Get-TestHistRow -Id 'epAAAAAAAA' -Date '2026-01-02 00:00:00' -Validated '3')
				(Get-TestHistRow -Id 'epBBBBBBBB' -Date '2026-01-02 00:00:00' -Validated '1')
			)
			Repair-HistoryFile 3>$null
			$rows = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			$rows.Count | Should -Be 1
			$rows[0].videoPage | Should -Be 'https://tver.jp/episodes/epBBBBBBBB'
		}
		It '全件が取り除かれても、CSVのヘッダーを残す' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:histTestHeader, (Get-TestHistRow -Id 'epAAAAAAAA' -Date '2026-01-01 00:00:00' -Validated '3'))
			Repair-HistoryFile 3>$null
			@(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Count | Should -Be 0
			(Get-Content -LiteralPath $script:histFilePath -TotalCount 1) | Should -Match 'videoPage'
			# 次の追記を読み取れること
			Add-Content -LiteralPath $script:histFilePath -Value (Get-TestHistRow -Id 'epCCCCCCCC' -Date '2026-02-01 00:00:00') -Encoding UTF8
			@(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)[0].videoPage | Should -Be 'https://tver.jp/episodes/epCCCCCCCC'
		}
		It '直前の履歴を.bakに退避し、一時ファイルを残さない' {
			$lines = @($script:histTestHeader, (Get-TestHistRow -Id 'epAAAAAAAA' -Date '2026-01-01 00:00:00' -Validated '1'), (Get-TestHistRow -Id 'epAAAAAAAA' -Date '2026-01-02 00:00:00' -Validated '1'))
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value $lines
			$before = Get-Content -LiteralPath $script:histFilePath -Raw
			Repair-HistoryFile 3>$null
			Get-Content -LiteralPath ($script:histFilePath + '.bak') -Raw | Should -Be $before
			@(Get-ChildItem -LiteralPath $script:histTestDir -Filter '*.tmp').Count | Should -Be 0
		}
		It '履歴ファイルがない場合は例外にせず、警告だけ出してロックを解除する' {
			{ Repair-HistoryFile 3>$null } | Should -Not -Throw
			Test-Path -LiteralPath $script:histFilePath | Should -BeFalse
			Should -Invoke Unlock-File -Times 1 -Exactly
		}
	}
}

#----------------------------------------------------------------------
# ダウンロードリスト・キーワードリストの読み込み
#----------------------------------------------------------------------
Describe 'ダウンロードリストとキーワードリスト' {
	BeforeAll {
		$script:listSaved = @{}
		foreach ($n in 'listFilePath', 'listLockFilePath', 'keywordFilePath', 'extractDescTextToList') {
			$script:listSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		$script:listHeader = '"seriesName","seriesID","seriesPageURL","seasonName","seasonID","episodeNo","episodeName","episodeID","episodePageURL","media","provider","broadcastDate","endTime","keyword","ignoreWord","descriptionText"'
		function script:Get-TestListRow { Param ([String]$Id) return '"s"' + (',""' * 6) + (',"{0}"' -f $Id) + (',""' * 8) }
	}
	AfterAll {
		foreach ($n in $script:listSaved.Keys) {
			if ($script:listSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:listSaved[$n] }
		}
	}
	BeforeEach {
		Mock Wait-FileLock {}
		Mock Unlock-File {}
		$script:listTestDir = Join-Path $TestDrive ('list{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:listTestDir -Force | Out-Null
		$script:listFilePath = Join-Path $script:listTestDir 'list.csv'
		$script:listLockFilePath = Join-Path $script:listTestDir 'list.lock'
		$script:keywordFilePath = Join-Path $script:listTestDir 'keyword.conf'
	}

	Context 'Read-DownloadList' {
		It 'ダウンロードリストのレコードを返す' {
			Set-Content -LiteralPath $script:listFilePath -Encoding UTF8 -Value @($script:listHeader, (Get-TestListRow 'epAAAAAAAA'), (Get-TestListRow '#epBBBBBBBB'))
			$rows = @(Read-DownloadList)
			$rows.Count | Should -Be 2
			$rows.episodeID | Should -Be @('epAAAAAAAA', '#epBBBBBBBB')
		}
		It 'ファイルがない場合は例外にして、ロックを解除する' {
			{ Read-DownloadList } | Should -Throw
			Should -Invoke Unlock-File -Times 1 -Exactly
		}
	}

	Context 'Get-LinkFromDownloadList' {
		It '#で始まるダウンロード対象外を除き、エピソードIDだけを返す' {
			Set-Content -LiteralPath $script:listFilePath -Encoding UTF8 -Value @($script:listHeader, (Get-TestListRow 'epAAAAAAAA'), (Get-TestListRow '#epBBBBBBBB'), (Get-TestListRow 'epCCCCCCCC'))
			Get-LinkFromDownloadList | Should -Be @('epAAAAAAAA', 'epCCCCCCCC')
		}
		It 'リストファイルがなければ空を返す' {
			@(Get-LinkFromDownloadList).Count | Should -Be 0
		}
		It '有効な行がない(ヘッダーのみ)場合も、例外にせず空を返す' {
			Set-Content -LiteralPath $script:listFilePath -Encoding UTF8 -Value @($script:listHeader)
			@(Get-LinkFromDownloadList).Count | Should -Be 0
		}
		It 'すべての行がダウンロード対象外(#)の場合も、例外にせず空を返す' {
			Set-Content -LiteralPath $script:listFilePath -Encoding UTF8 -Value @($script:listHeader, (Get-TestListRow '#epAAAAAAAA'), (Get-TestListRow '#epBBBBBBBB'))
			@(Get-LinkFromDownloadList).Count | Should -Be 0
		}
	}

	Context 'Format-ListRecord' {
		BeforeEach {
			$script:testVideoInfo = [PSCustomObject]@{
				seriesName = 'テスト番組' ; seriesID = 'sr1' ; seriesPageURL = 'https://tver.jp/series/sr1'
				seasonName = 'シーズン1' ; seasonID = 'ss1' ; episodeNum = '3' ; episodeName = '第3話'
				episodeID = 'epAAAAAAAA' ; episodePageURL = 'https://tver.jp/episodes/epAAAAAAAA'
				mediaName = 'テスト局' ; providerName = 'テスト提供' ; broadcastDate = '10/24(土) 放送分' ; endTime = '2026/11/01 00:00'
				keyword = 'k' ; ignoreWord = '' ; descriptionText = '説明文です'
			}
		}
		It 'ビデオ情報をダウンロードリストの列に対応付ける' {
			$script:extractDescTextToList = $false
			$r = Format-ListRecord ([Ref]$script:testVideoInfo)
			$r.seriesName | Should -Be 'テスト番組'
			$r.episodeNo | Should -Be '3'
			$r.episodeID | Should -Be 'epAAAAAAAA'
			$r.media | Should -Be 'テスト局'
			$r.provider | Should -Be 'テスト提供'
			$r.keyword | Should -Be 'k'
		}
		It '説明文の出力が無効なら、説明文の列は空にする' {
			$script:extractDescTextToList = $false
			(Format-ListRecord ([Ref]$script:testVideoInfo)).descriptionText | Should -Be ''
		}
		It '説明文の出力が有効なら、説明文を含める' {
			$script:extractDescTextToList = $true
			(Format-ListRecord ([Ref]$script:testVideoInfo)).descriptionText | Should -Be '説明文です'
		}
		It 'ダウンロードリストのヘッダーと同じ列の並びになる' {
			$script:extractDescTextToList = $true
			(Format-ListRecord ([Ref]$script:testVideoInfo)).PSObject.Properties.Name -join ',' | Should -Be (($script:listHeader -replace '"', '') )
		}
	}

	Context 'Read-KeywordList' {
		It 'コメント行と空行を除き、キーワードだけを返す' {
			Set-Content -LiteralPath $script:keywordFilePath -Encoding UTF8 -Value @('# コメント', '', 'tag/ドラマ', '   ', 'series/sr1', '#tag/無効', 'episodes/epAAAAAAAA')
			Read-KeywordList | Should -Be @('tag/ドラマ', 'series/sr1', 'episodes/epAAAAAAAA')
		}
		It 'ファイルがない場合は例外にする' {
			{ Read-KeywordList } | Should -Throw
		}
	}
}

#----------------------------------------------------------------------
# ダウンロード済み・リスト登録済みの番組の除外
#----------------------------------------------------------------------
Describe 'ダウンロード済み・リスト登録済みの番組の除外' {
	BeforeAll {
		$script:matchSaved = @{}
		foreach ($n in 'listFilePath', 'listLockFilePath', 'histFilePath', 'histLockFilePath', 'redownloadWhenSubtitleAdded') {
			$script:matchSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
		$script:matchListHeader = '"episodeID","seriesName"'
		$script:matchHistHeader = '"videoPage","videoSeriesPage","genre","series","season","title","media","broadcastDate","downloadDate","videoDir","videoName","videoPath","videoValidated","subtitle"'
		function script:Get-TestMatchHistRow { Param ([String]$Id) return ('"https://tver.jp/episodes/{0}"' -f $Id) + (',""' * 7) + ',"2026-01-01 00:00:00"' + (',""' * 3) + ',"1",""' }
	}
	AfterAll {
		foreach ($n in $script:matchSaved.Keys) {
			if ($script:matchSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:matchSaved[$n] }
		}
	}
	BeforeEach {
		Mock Wait-FileLock {}
		Mock Unlock-File {}
		$script:redownloadWhenSubtitleAdded = $false
		$script:matchTestDir = Join-Path $TestDrive ('match{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:matchTestDir -Force | Out-Null
		$script:listFilePath = Join-Path $script:matchTestDir 'list.csv'
		$script:listLockFilePath = Join-Path $script:matchTestDir 'list.lock'
		$script:histFilePath = Join-Path $script:matchTestDir 'history.csv'
		$script:histLockFilePath = Join-Path $script:matchTestDir 'history.lock'
		Set-Content -LiteralPath $script:listFilePath -Encoding UTF8 -Value @($script:matchListHeader, '"epAAAAAAAA","s1"', '"#epBBBBBBBB","s2"')
	}

	Context 'Invoke-ListMatchCheck' {
		It 'ダウンロードリストにない番組だけを返し、登録済みの件数を数える(#で始まる対象外の番組も登録済みとして扱う)' {
			$videoLinks, $processedCount = Invoke-ListMatchCheck -resultLinks @('epAAAAAAAA', 'epBBBBBBBB', 'epNEW00001')
			@($videoLinks) | Should -Be @('epNEW00001')
			$processedCount | Should -Be 2
		}
		It 'すべてが未登録なら、すべて返し、件数は0' {
			$videoLinks, $processedCount = Invoke-ListMatchCheck -resultLinks @('epNEW00001', 'epNEW00002')
			@($videoLinks) | Should -Be @('epNEW00001', 'epNEW00002')
			$processedCount | Should -Be 0
		}
		It 'すべてが登録済みなら、何も返さず、件数だけ数える' {
			$videoLinks, $processedCount = Invoke-ListMatchCheck -resultLinks @('epAAAAAAAA', 'epBBBBBBBB')
			@($videoLinks).Count | Should -Be 0
			$processedCount | Should -Be 2
		}
		It 'ダウンロード履歴は見ない(履歴にあってもリストになければ未登録として返す)' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:matchHistHeader, (Get-TestMatchHistRow 'epHIST00001'))
			$videoLinks, $processedCount = Invoke-ListMatchCheck -resultLinks @('epHIST00001')
			@($videoLinks) | Should -Be @('epHIST00001')
			$processedCount | Should -Be 0
		}
		It 'ダウンロードリストが1件だけでも動作する' {
			Set-Content -LiteralPath $script:listFilePath -Encoding UTF8 -Value @($script:matchListHeader, '"epAAAAAAAA","s1"')
			$videoLinks, $processedCount = Invoke-ListMatchCheck -resultLinks @('epAAAAAAAA', 'epNEW00001')
			@($videoLinks) | Should -Be @('epNEW00001')
			$processedCount | Should -Be 1
		}
	}

	Context 'Invoke-HistoryAndListMatchCheck' {
		It 'ダウンロードリストにもダウンロード履歴にもない番組だけを返す' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:matchHistHeader, (Get-TestMatchHistRow 'epHIST00001'), (Get-TestMatchHistRow 'epHIST00002'))
			$videoLinks, $processedCount = Invoke-HistoryAndListMatchCheck -resultLinks @('epAAAAAAAA', 'epBBBBBBBB', 'epHIST00001', 'epHIST00002', 'epNEW00001')
			@($videoLinks) | Should -Be @('epNEW00001')
			$processedCount | Should -Be 4
		}
		It 'ダウンロード履歴が1件だけでも動作する' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:matchHistHeader, (Get-TestMatchHistRow 'epHIST00001'))
			$videoLinks, $processedCount = Invoke-HistoryAndListMatchCheck -resultLinks @('epHIST00001', 'epNEW00001')
			@($videoLinks) | Should -Be @('epNEW00001')
			$processedCount | Should -Be 1
		}
		It 'ダウンロード履歴が空でも、ダウンロードリストだけで判定できる' {
			Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 -Value @($script:matchHistHeader)
			$videoLinks, $processedCount = Invoke-HistoryAndListMatchCheck -resultLinks @('epAAAAAAAA', 'epNEW00001')
			@($videoLinks) | Should -Be @('epNEW00001')
			$processedCount | Should -Be 1
		}
	}
}

#----------------------------------------------------------------------
# リネームに失敗したファイルの削除(#297)
# * ファイルの検索にcmd(Windows)またはfind(それ以外)を使うため、Linux/macOSでのみ検証する
#----------------------------------------------------------------------
Describe 'Remove-UnRenamedTempFile(#297)' -Skip:$IsWindows {
	BeforeAll {
		$script:unrenSaved = @{}
		foreach ($n in 'deleteUnrenamedFile', 'downloadBaseDir') {
			$script:unrenSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
	}
	AfterAll {
		foreach ($n in $script:unrenSaved.Keys) {
			if ($script:unrenSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:unrenSaved[$n] }
		}
	}
	BeforeEach {
		$script:unrenDir = Join-Path $TestDrive ('unren{0}' -f [Guid]::NewGuid().ToString('N'))
		$script:unrenSub = Join-Path $script:unrenDir 'ドラマ'
		New-Item -ItemType Directory -Path $script:unrenSub -Force | Out-Null
		$script:downloadBaseDir = $script:unrenDir
		$script:unrenTargets = @((Join-Path $script:unrenSub 'epa1b2c3d4.mp4'), (Join-Path $script:unrenDir 'epz9y8x7w6.ts'))
		$script:unrenKeeps = @((Join-Path $script:unrenSub '番組 第1話.mp4'), (Join-Path $script:unrenDir 'episode.mp4'), (Join-Path $script:unrenSub 'epshort.mp4'))
		foreach ($f in ($script:unrenTargets + $script:unrenKeeps)) { Set-Content -LiteralPath $f -Value 'x' -NoNewline }
	}

	It '削除する設定(既定)では、エピソードIDのままのファイルを削除し、通常のファイルは残す' {
		$script:deleteUnrenamedFile = $true
		$out = @(Remove-UnRenamedTempFile 3>&1)
		foreach ($f in $script:unrenTargets) { Test-Path -LiteralPath $f | Should -BeFalse }
		foreach ($f in $script:unrenKeeps) { Test-Path -LiteralPath $f | Should -BeTrue }
		$out | Should -Contain $script:msg.DeleteFilesFailedToRename
	}
	It '削除しない設定では、ファイルを削除せず、残したファイルごとに警告を出す' {
		$script:deleteUnrenamedFile = $false
		$out = @(Remove-UnRenamedTempFile 3>&1)
		foreach ($f in ($script:unrenTargets + $script:unrenKeeps)) { Test-Path -LiteralPath $f | Should -BeTrue }
		$warnings = @($out.Where({ $_ -is [Management.Automation.WarningRecord] }))
		$warnings.Count | Should -Be 2
		foreach ($f in $script:unrenTargets) { ($warnings.Message -join "`n") | Should -Match ([regex]::Escape((Split-Path -Leaf $f))) }
	}
	It '削除しない設定では、「削除しています」というメッセージを出さない' {
		$script:deleteUnrenamedFile = $false
		$out = @(Remove-UnRenamedTempFile 3>&1)
		$out | Should -Not -Contain $script:msg.DeleteFilesFailedToRename
	}
	It '削除しない設定で対象のファイルがなければ、何も警告しない' {
		$script:deleteUnrenamedFile = $false
		foreach ($f in $script:unrenTargets) { Remove-Item -LiteralPath $f -Force }
		@(Remove-UnRenamedTempFile 3>&1).Where({ $_ -is [Management.Automation.WarningRecord] }).Count | Should -Be 0
	}
	It '-WhatIfでは、削除する設定でも削除しない' {
		$script:deleteUnrenamedFile = $true
		Remove-UnRenamedTempFile -WhatIf | Out-Null
		foreach ($f in $script:unrenTargets) { Test-Path -LiteralPath $f | Should -BeTrue }
	}
}

#----------------------------------------------------------------------
# ダウンロードスケジュールに合わせた一時停止
#----------------------------------------------------------------------
Describe 'Suspend-Process' {
	BeforeAll {
		$script:spSaved = @{}
		foreach ($n in 'scheduleStop', 'stopSchedule') {
			$script:spSaved[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' }
		}
	}
	AfterAll {
		foreach ($n in $script:spSaved.Keys) {
			if ($script:spSaved[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
			else { Set-Variable -Name $n -Scope Script -Value $script:spSaved[$n] }
		}
	}
	BeforeEach {
		$script:scheduleStop = $true
		$script:stopSchedule = @{ 'Mon' = @(10) ; 'Sat' = @(23) }
		$script:spNow = [DateTime]'2026-10-26 10:30:00'	# 月曜日
		Mock Get-Date { $script:spNow }
		Mock Start-Sleep { $script:spNow = $script:spNow.AddSeconds($Seconds) }	# 待機した分だけ時刻を進める
	}
	It 'スケジュール停止が無効なら、待機しない' {
		$script:scheduleStop = $false
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 0 -Exactly
	}
	It '停止時間帯なら、次の正時まで待機し、停止時間外になったら戻ること' {
		$out = @(Suspend-Process)
		Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1800 }
		$out.Count | Should -Be 1	# 待機中のメッセージを1回表示
		$script:spNow | Should -Be ([DateTime]'2026-10-26 11:00:00')
	}
	It '停止時間帯でなければ、待機しない' {
		$script:stopSchedule = @{ 'Mon' = @(9) }
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 0 -Exactly
	}
	It '曜日が停止スケジュールになければ、待機しない' {
		$script:stopSchedule = @{ 'Tue' = @(10) }
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 0 -Exactly
	}
	It '停止時間帯が連続する場合は、停止時間外になるまで1時間ずつ待機すること' {
		$script:stopSchedule = @{ 'Mon' = @(10, 11) }
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 2 -Exactly
		Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1800 }
		Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 3600 }
	}
	It '正時ちょうどなら、1時間待機すること' {
		$script:spNow = [DateTime]'2026-10-26 10:00:00'
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 3600 }
	}
	It '待機秒数は切り上げること' {
		$script:spNow = [DateTime]'2026-10-26 10:59:30.5'
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 30 }
	}
	It '23時台が停止時間帯でも、翌日0時までの時間だけ待機すること' {
		$script:spNow = [DateTime]'2026-10-24 23:30:00'	# 土曜日
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1800 }
		$script:spNow | Should -Be ([DateTime]'2026-10-25 00:00:00')
	}
	It '日をまたいで停止時間帯が続く場合は、翌日の停止時間帯も考慮すること' {
		$script:stopSchedule = @{ 'Sat' = @(23) ; 'Sun' = @(0, 1) }
		$script:spNow = [DateTime]'2026-10-24 23:30:00'
		Suspend-Process | Out-Null
		Should -Invoke Start-Sleep -Times 3 -Exactly
		$script:spNow | Should -Be ([DateTime]'2026-10-25 02:00:00')
	}
}

#----------------------------------------------------------------------
# youtube-dl / ffmpegのプロセスが終わるまで待機
#----------------------------------------------------------------------
Describe 'Wait-DownloadCompletion' {
	BeforeEach {
		Mock Start-Sleep {}
		Mock Write-Information {}
	}
	It 'プロセスがなければ待機しない' {
		Mock Get-YtdlProcessCount { 0 }
		Wait-DownloadCompletion
		Should -Invoke Start-Sleep -Times 0 -Exactly
		Should -Invoke Write-Information -Times 0 -Exactly
	}
	It 'プロセスが0になるまで、60秒ごとに確認し、プロセス数を表示すること' {
		$script:wdcQueue = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(3, 2, 0))
		Mock Get-YtdlProcessCount { $script:wdcQueue.Dequeue() }
		Wait-DownloadCompletion
		Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 60 }
		Should -Invoke Write-Information -Times 2 -Exactly
		Should -Invoke Get-YtdlProcessCount -Times 3 -Exactly
	}
}

Describe 'Wait-DownloadProcess' {
	BeforeEach {
		Mock Start-Sleep {}
		Mock Get-YtdlProcessCount { $script:wdpYtdl.Dequeue() }
		Mock Get-FfmpegProcessCount { $script:wdpFfmpeg.Dequeue() }
	}
	It 'yt-dlpもffmpegもなければ、待機も表示もしない' {
		$script:wdpYtdl = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(0))
		$script:wdpFfmpeg = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(0))
		$out = @(Wait-DownloadProcess)
		$out.Count | Should -Be 0
		Should -Invoke Start-Sleep -Times 0 -Exactly
	}
	It 'yt-dlpとffmpegの合計数を表示し、60秒ごとに確認して、両方0になったら終了すること' {
		$script:wdpYtdl = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(2, 0))
		$script:wdpFfmpeg = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(1, 0))
		$out = @(Wait-DownloadProcess)
		$out.Count | Should -Be 1
		$out[0] | Should -Be ($script:msg.WaitingDownloadProcess -f 3)
		Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 60 }
	}
	It 'yt-dlpが先に終わっても、ffmpegが残っている間は待機を続けること' {
		$script:wdpYtdl = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(1, 0, 0))
		$script:wdpFfmpeg = [System.Collections.Generic.Queue[Int32]]::new([Int32[]]@(0, 1, 0))
		Wait-DownloadProcess | Out-Null
		Should -Invoke Start-Sleep -Times 2 -Exactly
	}
}

#----------------------------------------------------------------------
# 移動に失敗したファイルの削除(作業フォルダ)
#----------------------------------------------------------------------
Describe 'Remove-UnMovedTempFile' {
	BeforeAll {
		$script:unmSaved = if (Test-Path Variable:Script:downloadWorkDir) { $script:downloadWorkDir } else { '__unset__' }
	}
	AfterAll {
		if ($script:unmSaved -eq '__unset__') { Remove-Variable -Name downloadWorkDir -Scope Script -ErrorAction SilentlyContinue }
		else { $script:downloadWorkDir = $script:unmSaved }
	}
	BeforeEach {
		Mock Write-Information {}
		$script:downloadWorkDir = Join-Path $TestDrive ('unm{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path (Join-Path $script:downloadWorkDir 'sub') -Force | Out-Null
		$script:unmTargets = @('epa1b2c3d4.mp4', 'epa1b2c3d4.ts', 'epa1b2c3d4.f137.mp4', 'epz9y8x7w6.temp.ts')
		$script:unmKeeps = @('番組 第1話.mp4', 'episode.mp4', 'epshort.mp4', 'epa1b2c3d4.mp4.part', 'epa1b2c3d4.jpg', 'epa1b2c3d4.mkv')
		foreach ($f in ($script:unmTargets + $script:unmKeeps)) { Set-Content -LiteralPath (Join-Path $script:downloadWorkDir $f) -Value 'x' -NoNewline }
		Set-Content -LiteralPath (Join-Path $script:downloadWorkDir 'sub/epa1b2c3d4.mp4') -Value 'x' -NoNewline	# サブフォルダは対象外
	}
	It 'エピソードIDのままの.mp4/.tsだけを削除し、それ以外のファイルは残すこと' {
		Remove-UnMovedTempFile
		foreach ($f in $script:unmTargets) { Test-Path -LiteralPath (Join-Path $script:downloadWorkDir $f) | Should -BeFalse -Because $f }
		foreach ($f in $script:unmKeeps) { Test-Path -LiteralPath (Join-Path $script:downloadWorkDir $f) | Should -BeTrue -Because $f }
		Should -Invoke Write-Information -Times 4 -Exactly
	}
	It 'サブフォルダの中のファイルは削除しないこと' {
		Remove-UnMovedTempFile
		Test-Path -LiteralPath (Join-Path $script:downloadWorkDir 'sub/epa1b2c3d4.mp4') | Should -BeTrue
	}
	It '-WhatIfでは削除しないこと' {
		Remove-UnMovedTempFile -WhatIf
		foreach ($f in $script:unmTargets) { Test-Path -LiteralPath (Join-Path $script:downloadWorkDir $f) | Should -BeTrue -Because $f }
	}
	It '対象のファイルがなければ、例外にならず何もしないこと' {
		foreach ($f in $script:unmTargets) { Remove-Item -LiteralPath (Join-Path $script:downloadWorkDir $f) }
		{ Remove-UnMovedTempFile } | Should -Not -Throw
		Should -Invoke Write-Information -Times 0 -Exactly
	}
	It '作業フォルダが空でも、例外にならないこと' {
		Get-ChildItem -LiteralPath $script:downloadWorkDir -Recurse -File | Remove-Item
		{ Remove-UnMovedTempFile } | Should -Not -Throw
	}
}
