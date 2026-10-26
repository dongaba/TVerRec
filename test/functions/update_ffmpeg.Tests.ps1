Import-Module Pester -MinimumVersion 5.0

BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot ('src/functions/{0}' -f (Split-Path $PSCommandPath -Leaf).Replace('.Tests.ps1', '.ps1'))
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:msgAll = Get-Content -Path (Join-Path $script:repoRoot 'resources/lang/messages.json') -Raw | ConvertFrom-Json
	$script:msg = $script:msgAll.'ja-JP'
	# * ドット読み込みでは関数の定義だけを行い、更新処理は実行されない
	. $targetFile
	Write-Host ('　テスト対象の読み込みを行いました')
	# 変数の退避
	$script:ffBackupNames = 'binDir', 'timeoutSec'
	$script:ffBackup = @{}
	foreach ($n in $script:ffBackupNames) { $script:ffBackup[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' } }

	# 偽物のffmpeg/ffprobe(Linux/macOS): ffmpegはバージョンを表示するだけのシェルスクリプト
	function script:New-FakeFfTool {
		Param ([String]$Path, [String]$Text)
		New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
		# * 本物のffmpegと同じく、複数行を出力する(先頭行からバージョンを取り出すため)
		Set-Content -LiteralPath $Path -Value ("#!/bin/sh`necho `"{0}`"`necho `"built with test`"" -f $Text) -NoNewline
		if (!$IsWindows) { & chmod a+x $Path }
	}
	# 実行権限はあるが起動できないファイル(Linux/macOS)。存在しないインタプリタを指すshebangにする
	# * 実行権限のないファイルを&で起動すると、PowerShellがxdg-open/openに渡して関連付けられたアプリが開いてしまうため使わない
	function script:New-BrokenFfTool {
		Param ([String]$Path)
		New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
		Set-Content -LiteralPath $Path -Value "#!/nonexistent/interpreter`n" -NoNewline
		& chmod a+x $Path
	}
	# GitHub(Windows/Linux)の最新ビルド一覧ページの代わり。URLは実際と同じく1行に1つ
	$script:ffWikiLatest = @'
https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2025-01-02-12-34/ffmpeg-N-118000-gabcdef-linux64-gpl.tar.xz
https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2025-01-02-12-34/ffmpeg-N-118000-gabcdef-linuxarm64-gpl.tar.xz
https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2025-01-02-12-34/ffmpeg-N-118000-gabcdef-win64-gpl.zip
https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2025-01-02-12-34/ffmpeg-N-118000-gabcdef-winarm64-gpl.zip
https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2025-01-02-12-34/ffmpeg-N-118000-gabcdef-win32-gpl.zip
'@
}

AfterAll {
	foreach ($n in $script:ffBackupNames) {
		if ($script:ffBackup[$n] -is [String] -and $script:ffBackup[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
		else { Set-Variable -Name $n -Scope Script -Value $script:ffBackup[$n] }
	}
}

#----------------------------------------------------------------------
# Zipファイルを解凍
#----------------------------------------------------------------------
Describe 'Expand-Zip' {
	BeforeEach {
		$script:zRoot = Join-Path $TestDrive ('z{0}' -f [Guid]::NewGuid().ToString('N'))
		$script:zSrc = Join-Path $script:zRoot 'src'
		$script:zDst = Join-Path $script:zRoot 'dst'
		New-Item -ItemType Directory -Path $script:zSrc, $script:zDst -Force | Out-Null
		Set-Content -LiteralPath (Join-Path $script:zSrc 'a.txt') -Value 'new' -NoNewline
		$script:zZip = Join-Path $script:zRoot 'test.zip'
		[IO.Compression.ZipFile]::CreateFromDirectory($script:zSrc, $script:zZip)
	}
	It 'Zipファイルの中身を、解凍先に展開すること' {
		Expand-Zip -Path $script:zZip -Destination $script:zDst
		[IO.File]::ReadAllText((Join-Path $script:zDst 'a.txt')) | Should -Be 'new'
	}
	It '解凍先に同名のファイルがあれば、上書きすること' {
		Set-Content -LiteralPath (Join-Path $script:zDst 'a.txt') -Value 'old' -NoNewline
		Expand-Zip -Path $script:zZip -Destination $script:zDst
		[IO.File]::ReadAllText((Join-Path $script:zDst 'a.txt')) | Should -Be 'new'
	}
	It 'Zipファイルがなければ、ファイルが見つからないという例外にすること' {
		{ Expand-Zip -Path (Join-Path $script:zRoot 'nothing.zip') -Destination $script:zDst } | Should -Throw -ExpectedMessage ($script:msg.FileNotFound -f (Join-Path $script:zRoot 'nothing.zip'))
	}
}

#----------------------------------------------------------------------
# ffmpegの更新
#----------------------------------------------------------------------
Describe 'Update-Ffmpeg' {
	BeforeEach {
		$script:binDir = Join-Path $TestDrive ('bin{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:binDir -Force | Out-Null
		$script:timeoutSec = 5
		$script:ffLocal = Join-Path $script:binDir $(if ($IsWindows) { 'ffmpeg.exe' } else { 'ffmpeg' })
		$script:ffDownloads = [System.Collections.Generic.List[String]]::new()
		Mock Write-Warning {}
		Mock Invoke-RestMethod { $script:ffWikiLatest }
	}

	Context 'Linux' -Skip:(-not $IsLinux) {
		BeforeAll {
			# 実際の配布物と同じ構成の、偽物のtar.xz(ffmpeg-*-gpl/bin/ff*)
			$script:ffStage = Join-Path $TestDrive 'ffstage'
			$dirName = 'ffmpeg-N-118000-gabcdef-linux64-gpl'
			New-FakeFfTool -Path (Join-Path $script:ffStage "$dirName/bin/ffmpeg") -Text 'ffmpeg version N-118000-gabcdef Copyright (c) test'
			New-FakeFfTool -Path (Join-Path $script:ffStage "$dirName/bin/ffprobe") -Text 'ffprobe version N-118000-gabcdef'
			$script:ffArchive = Join-Path $TestDrive 'ffmpeg-dist.tar.xz'
			& tar cJf $script:ffArchive -C $script:ffStage $dirName
		}
		BeforeEach {
			Mock Invoke-WebRequest { $script:ffDownloads.Add($Uri) ; Copy-Item -LiteralPath $script:ffArchive -Destination $OutFile }
		}
		It '最新バージョンを取得できなければ、警告して終了し、ダウンロードしないこと' {
			Mock Invoke-RestMethod { throw 'network down' }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolLatestNotIdentified -f 'ffmpeg') }
			Should -Invoke Invoke-WebRequest -Times 0 -Exactly
		}
		It '最新バージョンと同じなら、「最新です」と表示し、ダウンロードしないこと' {
			New-FakeFfTool -Path $script:ffLocal -Text 'ffmpeg version N-118000-gabcdef Copyright (c) test'
			$out = (Update-Ffmpeg) -join "`n"
			$out | Should -Match ([regex]::Escape(($script:msg.ToolUpToDate -f 'ffmpeg')))
			$out | Should -Match ([regex]::Escape(($script:msg.ToolLocalVersion -f '118000')))
			Should -Invoke Invoke-WebRequest -Times 0 -Exactly
			Should -Invoke Write-Warning -Times 0 -Exactly
		}
		It '古ければ、警告して最新版を取得し、ffmpegとffprobeを配置して実行権限を付け、作業ファイルを片付けること' {
			New-FakeFfTool -Path $script:ffLocal -Text 'ffmpeg version N-100000-gold Copyright (c) test'
			$out = (Update-Ffmpeg) -join "`n"
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolOutdated -f 'ffmpeg') }
			$out | Should -Match ([regex]::Escape(($script:msg.ToolLocalVersion -f '100000')))
			$out | Should -Match ([regex]::Escape(($script:msg.ToolRemoteVersion -f '118000')))
			$out | Should -Match ([regex]::Escape(($script:msg.ToolUpdated -f 'ffmpeg', '118000')))
			$script:ffDownloads.Count | Should -Be 1
			$expectedCpu = if ((& uname -m).ToLower() -in 'aarch64', 'armv8') { 'arm64' } else { '64' }
			$script:ffDownloads[0] | Should -Be ('https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2025-01-02-12-34/ffmpeg-N-118000-gabcdef-linux{0}-gpl.tar.xz' -f $expectedCpu)
			foreach ($f in 'ffmpeg', 'ffprobe') {
				& test -x (Join-Path $script:binDir $f)
				$LASTEXITCODE | Should -Be 0
			}
			((& $script:ffLocal -version) -join "`n") | Should -Match 'N-118000'
			@(Get-ChildItem -LiteralPath $script:binDir | Where-Object { $_.Name -like 'ffmpeg-*' -or $_.Name -like '*.tar.xz' }).Count | Should -Be 0
		}
		It 'ローカルのffmpegのバージョン表記が想定外の形式でも、例外にならずバージョン不明として更新すること' {
			# * ディストリビューション版などは「ffmpeg version 6.1.1-3ubuntu5」のような表記で、-(数字)の形式に合わない
			New-FakeFfTool -Path $script:ffLocal -Text 'ffmpeg version 6.1.1-3ubuntu5 Copyright (c) test'
			{ Update-Ffmpeg | Out-Null } | Should -Not -Throw
			Should -Invoke Invoke-WebRequest -Times 1 -Exactly
			((& $script:ffLocal -version) -join "`n") | Should -Match 'N-118000'
		}
		It 'ローカルになければ、バージョン空として最新版を取得すること' {
			(Update-Ffmpeg) -join "`n" | Should -Match ([regex]::Escape(($script:msg.ToolUpdated -f 'ffmpeg', '118000')))
			Test-Path -LiteralPath (Join-Path $script:binDir 'ffprobe') | Should -BeTrue
		}
		It '前回の作業ファイルが残っていても、最初に削除すること' {
			New-Item -ItemType Directory -Path (Join-Path $script:binDir 'ffmpeg-old-gpl/bin') -Force | Out-Null
			Set-Content -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Value 'stale'
			Mock Invoke-RestMethod { throw 'network down' }
			Update-Ffmpeg | Out-Null
			Test-Path -LiteralPath (Join-Path $script:binDir 'ffmpeg-old-gpl') | Should -BeFalse
			Test-Path -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') | Should -BeFalse
		}
		It 'ダウンロードに失敗したら、警告して終了し、元のffmpegを変更しないこと' {
			New-FakeFfTool -Path $script:ffLocal -Text 'ffmpeg version N-100000-gold Copyright (c) test'
			Mock Invoke-WebRequest { throw 'download failed' }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -ParameterFilter { $Message -eq ($script:msg.ToolDownloadFailed -f 'ffmpeg') } -Times 1 -Exactly
			((& $script:ffLocal -version) -join "`n") | Should -Match 'N-100000'
		}
		It 'ローカルのffmpegを実行できなくても、例外にならずバージョン不明として更新すること' {
			# * 起動に失敗すると、バージョン取得の例外処理に入る
			New-BrokenFfTool -Path $script:ffLocal
			{ Update-Ffmpeg | Out-Null } | Should -Not -Throw
			Should -Invoke Invoke-WebRequest -Times 1 -Exactly
		}
		It '更新に成功したときは、エラーを出力しないこと' {
			$records = @(Update-Ffmpeg 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
			$records.Count | Should -Be 0
		}
		It 'CPUの種類を判別できなければ、警告して終了し、ダウンロードしないこと' {
			Mock uname { 'mips' }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolArchitectureNotIdentified1 -f 'ffmpeg') }
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolArchitectureNotIdentified2 -f 'mips', 'ffmpeg') }
			Should -Invoke Invoke-WebRequest -Times 0 -Exactly
		}
		It '展開に失敗したら、警告して終了すること' {
			Mock tar { throw 'tar failed' }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolExtractFailed -f 'ffmpeg') }
			Test-Path -LiteralPath $script:ffLocal | Should -BeFalse
		}
		It '配布物にffmpegが含まれていなければ、配置の失敗を警告して終了すること' {
			$emptyStage = Join-Path $TestDrive ('nobin{0}' -f [Guid]::NewGuid().ToString('N'))
			New-Item -ItemType Directory -Path (Join-Path $emptyStage 'ffmpeg-N-118000-gabcdef-linux64-gpl') -Force | Out-Null
			Set-Content -LiteralPath (Join-Path $emptyStage 'ffmpeg-N-118000-gabcdef-linux64-gpl/README') -Value 'x'
			$script:ffEmptyArchive = Join-Path $TestDrive ('nobin{0}.tar.xz' -f [Guid]::NewGuid().ToString('N'))
			& tar cJf $script:ffEmptyArchive -C $emptyStage 'ffmpeg-N-118000-gabcdef-linux64-gpl'
			Mock Invoke-WebRequest { Copy-Item -LiteralPath $script:ffEmptyArchive -Destination $OutFile }
			$out = (Update-Ffmpeg) -join "`n"
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolDeployFailed -f 'ffmpeg') }
			$out | Should -Not -Match ([regex]::Escape(($script:msg.ToolUpdated -f 'ffmpeg', '')))
		}
		It '配置したffmpegを起動できなければ、バージョン確認の失敗を警告すること' {
			$badStage = Join-Path $TestDrive ('bad{0}' -f [Guid]::NewGuid().ToString('N'))
			$badDir = Join-Path $badStage 'ffmpeg-N-118000-gabcdef-linux64-gpl/bin'
			New-Item -ItemType Directory -Path $badDir -Force | Out-Null
			foreach ($n in 'ffmpeg', 'ffprobe') { New-BrokenFfTool -Path (Join-Path $badDir $n) }
			$script:ffBadArchive = Join-Path $TestDrive ('bad{0}.tar.xz' -f [Guid]::NewGuid().ToString('N'))
			& tar cJf $script:ffBadArchive -C $badStage 'ffmpeg-N-118000-gabcdef-linux64-gpl'
			Mock Invoke-WebRequest { Copy-Item -LiteralPath $script:ffBadArchive -Destination $OutFile }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq $script:msg.ToolVersionCheckFailed }
		}
	}

	Context 'macOS' -Skip:(-not $IsMacOS) {
		BeforeAll {
			$script:ffMacArch = (& uname -m | tr '[:upper:]' '[:lower:]').Replace('x86_64', 'amd64')
			# ffmpeg.zip/ffprobe.zip/ffplay.zip: それぞれ同名の実行ファイル1つを含む偽物
			$script:ffMacZips = @{}
			foreach ($n in 'ffmpeg', 'ffprobe', 'ffplay') {
				$dir = Join-Path $TestDrive "mac-$n"
				New-FakeFfTool -Path (Join-Path $dir $n) -Text ('{0} version 7.1 Copyright (c) test' -f $n)
				$zip = Join-Path $TestDrive "$n.zip"
				[IO.Compression.ZipFile]::CreateFromDirectory($dir, $zip)
				$script:ffMacZips[$n] = $zip
			}
		}
		BeforeEach {
			$arch = $script:ffMacArch
			Mock Invoke-WebRequest {
				$script:ffDownloads.Add($Uri)
				if ($OutFile) { Copy-Item -LiteralPath $script:ffMacZips[([IO.Path]::GetFileNameWithoutExtension($OutFile))] -Destination $OutFile }
				elseif ($Uri -match '/history/') {
					[PSCustomObject]@{ links = @([PSCustomObject]@{ href = ('/info/release/macos/{0}/release/{0}/1700000000_7.1' -f $script:ffMacArch) }, [PSCustomObject]@{ href = ('/info/release/macos/{0}/release/{0}/1600000000_7.0' -f $script:ffMacArch) }) }
				} else {
					$links = foreach ($n in 'ffmpeg', 'ffprobe', 'ffplay') {
						[PSCustomObject]@{ href = ('/download/macos/{0}/1700000000_7.1/{1}.zip' -f $script:ffMacArch, $n) ; outerHTML = ('<a href="x">{0}.zip</a>' -f $n) }
						[PSCustomObject]@{ href = ('/download/macos/{0}/1700000000_7.1/{1}.zip.sha256' -f $script:ffMacArch, $n) ; outerHTML = ('<a href="x">{0}.zip</a>' -f $n) }
					}
					[PSCustomObject]@{ links = @($links) }
				}
			}
		}
		It '最新バージョンと同じなら、「最新です」と表示し、ダウンロードしないこと' {
			New-FakeFfTool -Path $script:ffLocal -Text 'ffmpeg version 7.1 Copyright (c) test'
			$out = (Update-Ffmpeg) -join "`n"
			$out | Should -Match ([regex]::Escape(($script:msg.ToolUpToDate -f 'ffmpeg')))
			$script:ffDownloads.Count | Should -Be 1   # 最新ビルドの確認だけ
		}
		It '古ければ、3つのzipを取得して展開・配置し、実行権限を付け、作業ファイルを片付けること' {
			New-FakeFfTool -Path $script:ffLocal -Text 'ffmpeg version 6.0 Copyright (c) test'
			$out = (Update-Ffmpeg) -join "`n"
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolOutdated -f 'ffmpeg') }
			$out | Should -Match ([regex]::Escape(($script:msg.ToolUpdated -f 'ffmpeg', '7.1')))
			foreach ($n in 'ffmpeg', 'ffprobe', 'ffplay') {
				Test-Path -LiteralPath (Join-Path $script:binDir $n) | Should -BeTrue
				Test-Path -LiteralPath (Join-Path $script:binDir "$n.zip") | Should -BeFalse
			}
			foreach ($n in 'ffmpeg', 'ffprobe') {
				& test -x (Join-Path $script:binDir $n)
				$LASTEXITCODE | Should -Be 0
			}
			# sha256のリンクは取得しないこと
			@($script:ffDownloads | Where-Object { $_ -match 'sha256' }).Count | Should -Be 0
		}
		It '最新ビルドの確認に失敗したら、警告して終了すること' {
			Mock Invoke-WebRequest { throw 'network down' }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolLatestNotIdentified -f 'ffmpeg') }
		}
		It 'ダウンロードに失敗したら、警告して終了すること' {
			Mock Invoke-WebRequest {
				if ($OutFile) { throw 'download failed' }
				[PSCustomObject]@{ links = @([PSCustomObject]@{ href = ('/info/release/macos/{0}/release/{0}/1700000000_7.1' -f $script:ffMacArch) }, [PSCustomObject]@{ href = 'x' }) }
			}
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -ParameterFilter { $Message -eq ($script:msg.ToolDownloadFailed -f 'ffmpeg') } -Times 1 -Exactly
		}
		It 'ローカルのffmpegのバージョン表記が想定外の形式でも、例外にならずバージョン不明として更新すること' {
			New-FakeFfTool -Path $script:ffLocal -Text 'ffmpeg version abc Copyright (c) test'
			{ Update-Ffmpeg | Out-Null } | Should -Not -Throw
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolOutdated -f 'ffmpeg') }
		}
		It 'ローカルのffmpegを実行できなくても、例外にならずバージョン不明として更新すること' {
			New-BrokenFfTool -Path $script:ffLocal
			{ Update-Ffmpeg | Out-Null } | Should -Not -Throw
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolOutdated -f 'ffmpeg') }
		}
		It '展開に失敗したら、警告して終了すること' {
			Mock Invoke-WebRequest {
				if ($OutFile) { Set-Content -LiteralPath $OutFile -Value 'not a zip' -NoNewline }
				elseif ($Uri -match '/history/') { [PSCustomObject]@{ links = @([PSCustomObject]@{ href = ('/info/release/macos/{0}/release/{0}/1700000000_7.1' -f $script:ffMacArch) }) } }
				else {
					$links = foreach ($n in 'ffmpeg', 'ffprobe', 'ffplay') { [PSCustomObject]@{ href = ('/download/macos/{0}/1700000000_7.1/{1}.zip' -f $script:ffMacArch, $n) ; outerHTML = ('<a href="x">{0}.zip</a>' -f $n) } }
					[PSCustomObject]@{ links = @($links) }
				}
			}
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolExtractFailed -f 'ffmpeg') }
		}
		It '配置したffmpegを起動できなければ、バージョン確認の失敗を警告すること' {
			$badDir = Join-Path $TestDrive ('macbad{0}' -f [Guid]::NewGuid().ToString('N'))
			New-Item -ItemType Directory -Path $badDir -Force | Out-Null
			New-BrokenFfTool -Path (Join-Path $badDir 'ffmpeg')
			$script:ffMacBadZip = Join-Path $TestDrive ('macbad{0}.zip' -f [Guid]::NewGuid().ToString('N'))
			[IO.Compression.ZipFile]::CreateFromDirectory($badDir, $script:ffMacBadZip)
			$orig = $script:ffMacZips['ffmpeg']
			$script:ffMacZips['ffmpeg'] = $script:ffMacBadZip
			try { Update-Ffmpeg | Out-Null } finally { $script:ffMacZips['ffmpeg'] = $orig }
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq $script:msg.ToolVersionCheckFailed }
		}
	}

	Context 'Windows' -Skip:(-not $IsWindows) {
		BeforeAll {
			# ffmpeg-*-gpl/bin/ff*.exe を含む偽物のzip(中身は実行できない)
			$script:ffStage = Join-Path $TestDrive 'ffstage'
			foreach ($n in 'ffmpeg.exe', 'ffprobe.exe') {
				New-Item -ItemType Directory -Path (Join-Path $script:ffStage 'ffmpeg-N-118000-gabcdef-win64-gpl/bin') -Force | Out-Null
				Set-Content -LiteralPath (Join-Path $script:ffStage "ffmpeg-N-118000-gabcdef-win64-gpl/bin/$n") -Value 'not an exe' -NoNewline
			}
			$script:ffArchive = Join-Path $TestDrive 'ffmpeg-dist.zip'
			[IO.Compression.ZipFile]::CreateFromDirectory($script:ffStage, $script:ffArchive)
		}
		BeforeEach {
			Mock Invoke-WebRequest { $script:ffDownloads.Add($Uri) ; Copy-Item -LiteralPath $script:ffArchive -Destination $OutFile }
		}
		It '最新バージョンを取得できなければ、警告して終了し、ダウンロードしないこと' {
			Mock Invoke-RestMethod { throw 'network down' }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolLatestNotIdentified -f 'ffmpeg') }
			Should -Invoke Invoke-WebRequest -Times 0 -Exactly
		}
		It 'ダウンロードに失敗したら、警告して終了すること' {
			Mock Invoke-WebRequest { throw 'download failed' }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -ParameterFilter { $Message -eq ($script:msg.ToolDownloadFailed -f 'ffmpeg') } -Times 1 -Exactly
		}
		It 'アーキテクチャに合ったzipを取得し、ffmpeg.exeとffprobe.exeを配置して、作業ファイルを片付けること' {
			Update-Ffmpeg | Out-Null
			$script:ffDownloads.Count | Should -Be 1
			$script:ffDownloads[0] | Should -Match 'ffmpeg-N-118000-gabcdef-win(64|arm64|32)-gpl\.zip$'
			Test-Path -LiteralPath (Join-Path $script:binDir 'ffmpeg.exe') | Should -BeTrue
			Test-Path -LiteralPath (Join-Path $script:binDir 'ffprobe.exe') | Should -BeTrue
			@(Get-ChildItem -LiteralPath $script:binDir | Where-Object { $_.Name -like 'ffmpeg-*' -or $_.Name -eq 'ffmpeg.zip' }).Count | Should -Be 0
		}
		It '配置したffmpeg.exeを起動できなければ、バージョン確認の失敗を警告すること' {
			# * 偽物のexeは実行できないため、更新後のバージョン確認に失敗する
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -ParameterFilter { $Message -eq $script:msg.ToolVersionCheckFailed } -Times 1 -Exactly
		}
		It 'ローカルのffmpeg.exeを実行できなくても、例外にならずバージョン不明として更新すること' {
			Set-Content -LiteralPath $script:ffLocal -Value 'not an exe' -NoNewline
			{ Update-Ffmpeg | Out-Null } | Should -Not -Throw
			Should -Invoke Invoke-WebRequest -Times 1 -Exactly
		}
		It '展開に失敗したら、警告して終了すること' {
			Mock Invoke-WebRequest { Set-Content -LiteralPath $OutFile -Value 'not a zip' -NoNewline }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolExtractFailed -f 'ffmpeg') }
		}
		It '配布物にffmpeg.exeが含まれていなければ、配置の失敗を警告して終了すること' {
			$emptyStage = Join-Path $TestDrive ('nobin{0}' -f [Guid]::NewGuid().ToString('N'))
			New-Item -ItemType Directory -Path (Join-Path $emptyStage 'ffmpeg-N-118000-gabcdef-win64-gpl') -Force | Out-Null
			Set-Content -LiteralPath (Join-Path $emptyStage 'ffmpeg-N-118000-gabcdef-win64-gpl/README') -Value 'x'
			$script:ffEmptyArchive = Join-Path $TestDrive ('nobin{0}.zip' -f [Guid]::NewGuid().ToString('N'))
			[IO.Compression.ZipFile]::CreateFromDirectory($emptyStage, $script:ffEmptyArchive)
			Mock Invoke-WebRequest { Copy-Item -LiteralPath $script:ffEmptyArchive -Destination $OutFile }
			Update-Ffmpeg | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolDeployFailed -f 'ffmpeg') }
		}
	}
}

#----------------------------------------------------------------------
# スクリプトとして実行したときの動作(環境設定と更新処理の呼び出し)
#----------------------------------------------------------------------
Describe 'update_ffmpeg.ps1をスクリプトとして実行したとき' {
	BeforeEach {
		# * 本物のbin・confに触れないよう、スクリプト・メッセージ・設定を一時ディレクトリにまとめて実行する
		$script:sbRoot = Join-Path $TestDrive ('sb{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path (Join-Path $script:sbRoot 'src/functions'), (Join-Path $script:sbRoot 'resources/lang'), (Join-Path $script:sbRoot 'conf'), (Join-Path $script:sbRoot 'bin') -Force | Out-Null
		Copy-Item -LiteralPath $targetFile -Destination (Join-Path $script:sbRoot 'src/functions/update_ffmpeg.ps1')
		Copy-Item -LiteralPath (Join-Path $script:repoRoot 'resources/lang/messages.json') -Destination (Join-Path $script:sbRoot 'resources/lang/messages.json')
		Set-Content -LiteralPath (Join-Path $script:sbRoot 'conf/system_setting.ps1') -Value "`$script:preferredLanguage = ''`n" -NoNewline
		$script:sbBin = (Join-Path $script:sbRoot 'bin').Replace("'", "''")
		Set-Content -LiteralPath (Join-Path $script:sbRoot 'conf/user_setting.ps1') -Value ("`$script:binDir = '{0}'`n`$script:timeoutSec = 5`n" -f $script:sbBin)
		$script:sbScript = Join-Path $script:sbRoot 'src/functions/update_ffmpeg.ps1'
		Push-Location
		Mock Write-Warning {}
	}
	AfterEach { Pop-Location }
	It '設定ファイルを読み込んで、更新処理を実行すること' {
		Mock Invoke-RestMethod { throw 'network down' }
		Mock Invoke-WebRequest { throw 'network down' }
		& $script:sbScript | Out-Null
		# * ネットワークに出られないため、最新バージョンを特定できないという警告が出れば、更新処理まで到達している
		Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*ffmpeg*' }
	}
	It 'スペースを含むディレクトリに置かれていたら、例外にすること' {
		$spaced = Join-Path $TestDrive ('with space{0}' -f [Guid]::NewGuid().ToString('N'))
		Copy-Item -LiteralPath $script:sbRoot -Destination $spaced -Recurse
		{ & (Join-Path $spaced 'src/functions/update_ffmpeg.ps1') } | Should -Throw -ExpectedMessage '*スペースを含むディレクトリ*'
	}
	It 'system_setting.ps1がなければ、例外にすること' {
		Remove-Item -LiteralPath (Join-Path $script:sbRoot 'conf/system_setting.ps1') -Force
		# * スクリプトは実行環境の言語でメッセージを出すため、日本語・英語のどちらでもよい
		$err = try { & $script:sbScript ; '' } catch { $_.Exception.Message }
		@($script:msgAll.'ja-JP'.SystemSettingNotFound, $script:msgAll.'en-US'.SystemSettingNotFound) | Should -Contain $err
	}
	It 'user_setting.ps1がなければ(Windows以外)、設定が完了していないとして例外にすること' -Skip:$IsWindows {
		Remove-Item -LiteralPath (Join-Path $script:sbRoot 'conf/user_setting.ps1') -Force
		$err = try { & $script:sbScript ; '' } catch { $_.Exception.Message }
		@($script:msgAll.'ja-JP'.UserSettingNotCompleted, $script:msgAll.'en-US'.UserSettingNotCompleted) | Should -Contain $err
	}
	It '実際のスクリプトを-WhatIfで実行しても、設定ファイルを読み込んで更新処理まで到達し、何も変更しないこと' {
		# * 一時ディレクトリ内のコピーではカバレッジが取れないため、実物を直接実行する。-WhatIfで更新処理の中身は実行しない
		$userSetting = Join-Path $script:repoRoot 'conf/user_setting.ps1'
		$created = -not (Test-Path $userSetting)
		if ($created) { Set-Content -LiteralPath $userSetting -Value ('$script:binDir = ''{0}''' -f $script:sbBin) }
		Mock Invoke-RestMethod {}
		Mock Invoke-WebRequest {}
		try {
			$WhatIfPreference = $true
			{ & $targetFile *> $null } | Should -Not -Throw
		} finally {
			$WhatIfPreference = $false
			if ($created) { Remove-Item -LiteralPath $userSetting -Force -ErrorAction SilentlyContinue }
		}
		Should -Invoke Invoke-RestMethod -Times 0 -Exactly
		Should -Invoke Invoke-WebRequest -Times 0 -Exactly
	}
	It 'ドット読み込みでは、更新処理を実行しないこと' {
		. $script:sbScript
		Should -Invoke Write-Warning -Times 0 -Exactly
	}
}
