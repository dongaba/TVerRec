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
	$script:ytBackupNames = 'binDir', 'timeoutSec', 'preferredYoutubedl'
	$script:ytBackup = @{}
	foreach ($n in $script:ytBackupNames) { $script:ytBackup[$n] = if (Test-Path "Variable:Script:$n") { (Get-Variable -Name $n -Scope Script).Value } else { '__unset__' } }
	# Linux/macOSでは、バージョンを返すだけの実行ファイルを偽物として使う
	function script:New-FakeYtdl {
		Param ([String]$Path, [String]$Version)
		Set-Content -LiteralPath $Path -Value ("#!/bin/sh`necho {0}" -f $Version) -NoNewline
		if (!$IsWindows) { & chmod a+x $Path }
	}
}

AfterAll {
	foreach ($n in $script:ytBackupNames) {
		if ($script:ytBackup[$n] -is [String] -and $script:ytBackup[$n] -eq '__unset__') { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
		else { Set-Variable -Name $n -Scope Script -Value $script:ytBackup[$n] }
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
# youtube-dlの更新
#----------------------------------------------------------------------
Describe 'Update-Ytdl' {
	BeforeEach {
		$script:binDir = Join-Path $TestDrive ('bin{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $script:binDir -Force | Out-Null
		$script:timeoutSec = 5
		$script:preferredYoutubedl = 'yt-dlp'
		$script:ytLocal = Join-Path $script:binDir $(if ($IsWindows) { 'yt-dlp.exe' } else { 'yt-dlp' })
		$script:ytLatest = '2025.02.03'
		Mock Write-Warning {}
		Mock Invoke-RestMethod { @([PSCustomObject]@{ Tag_Name = $script:ytLatest }, [PSCustomObject]@{ Tag_Name = '2020.01.01' }) }
		# ダウンロードの代わりに、最新バージョンを返す偽物の実行ファイルを配置する
		Mock Invoke-WebRequest {
			$script:ytDownloadUri = $Uri
			$script:ytDownloadOut = $OutFile
			New-FakeYtdl -Path $OutFile -Version $script:ytLatest
		}
	}

	Context '共通' {
		It '対応していない種類が指定されたら、警告して終了し、GitHubに問い合わせないこと' {
			$script:preferredYoutubedl = 'unknown-ytdl'
			Update-Ytdl | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolInvalidSource -f 'unknown-ytdl') }
			Should -Invoke Invoke-RestMethod -Times 0 -Exactly
			Should -Invoke Invoke-WebRequest -Times 0 -Exactly
		}
		It '最新バージョンを取得できなければ、警告して終了し、ダウンロードしないこと' {
			Mock Invoke-RestMethod { throw 'network down' }
			Update-Ytdl | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolLatestNotIdentified -f 'yt-dlp') }
			Should -Invoke Invoke-WebRequest -Times 0 -Exactly
		}
		It 'ダウンロードに失敗したら、警告して終了すること' {
			Mock Invoke-WebRequest { throw 'download failed' }
			Update-Ytdl | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolDownloadFailed -f 'yt-dlp') }
		}
		It '最新リリースの一覧は、種類ごとのGitHubリポジトリに問い合わせること' -ForEach @(
			@{ Kind = 'yt-dlp' ; Repo = 'yt-dlp/yt-dlp' }
			@{ Kind = 'ytdl-patched' ; Repo = 'ytdl-patched/ytdl-patched' }
			@{ Kind = 'yt-dlp-nightly' ; Repo = 'yt-dlp/yt-dlp-nightly-builds' }
		) {
			$script:preferredYoutubedl = $Kind
			Update-Ytdl | Out-Null
			Should -Invoke Invoke-RestMethod -ParameterFilter { $Uri -eq ('https://api.github.com/repos/{0}/releases' -f $Repo) -and $TimeoutSec -eq 5 }
		}
		It '終了後に、処理中の変数を残さないこと' {
			Update-Ytdl | Out-Null
			Test-Path Variable:\ytdlPath | Should -BeFalse
		}
	}

	Context 'Linux/macOS' -Skip:$IsWindows {
		It '最新バージョンと同じなら、「最新です」と表示し、ダウンロードしないこと' {
			New-FakeYtdl -Path $script:ytLocal -Version $script:ytLatest
			$out = (Update-Ytdl) -join "`n"
			$out | Should -Match ([regex]::Escape(($script:msg.ToolUpToDate -f 'yt-dlp')))
			$out | Should -Match ([regex]::Escape(($script:msg.ToolLocalVersion -f $script:ytLatest)))
			Should -Invoke Invoke-WebRequest -Times 0 -Exactly
			Should -Invoke Write-Warning -Times 0 -Exactly
		}
		It '古ければ、警告して最新版をダウンロードし、実行権限を付けて、更新後のバージョンを表示すること' {
			New-FakeYtdl -Path $script:ytLocal -Version '2024.01.01'
			$out = (Update-Ytdl) -join "`n"
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq ($script:msg.ToolOutdated -f 'yt-dlp') }
			Should -Invoke Invoke-WebRequest -Times 1 -Exactly
			$script:ytDownloadUri | Should -Be ('https://github.com/yt-dlp/yt-dlp/releases/download/{0}/yt-dlp' -f $script:ytLatest)
			$script:ytDownloadOut | Should -Be $script:ytLocal
			& test -x $script:ytLocal
			$LASTEXITCODE | Should -Be 0
			$out | Should -Match ([regex]::Escape(($script:msg.ToolLocalVersion -f '2024.01.01')))
			$out | Should -Match ([regex]::Escape(($script:msg.ToolRemoteVersion -f $script:ytLatest)))
			$out | Should -Match ([regex]::Escape(($script:msg.ToolUpdated -f 'yt-dlp', $script:ytLatest)))
		}
		It 'ローカルになければ、バージョン空として最新版をダウンロードすること' {
			(Update-Ytdl) -join "`n" | Should -Match ([regex]::Escape(($script:msg.ToolUpdated -f 'yt-dlp', $script:ytLatest)))
			Should -Invoke Invoke-WebRequest -Times 1 -Exactly
		}
		It 'ytdl-patchedは、ytdl-patchedのファイルをダウンロードして、yt-dlpという名前で配置すること' {
			$script:preferredYoutubedl = 'ytdl-patched'
			Update-Ytdl | Out-Null
			$script:ytDownloadUri | Should -Be ('https://github.com/ytdl-patched/ytdl-patched/releases/download/{0}/ytdl-patched' -f $script:ytLatest)
			$script:ytDownloadOut | Should -Be $script:ytLocal
		}
		It 'yt-dlp-nightlyは、nightlyのリポジトリからyt-dlpのファイルをダウンロードすること' {
			$script:preferredYoutubedl = 'yt-dlp-nightly'
			Update-Ytdl | Out-Null
			$script:ytDownloadUri | Should -Be ('https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/download/{0}/yt-dlp' -f $script:ytLatest)
			$script:ytDownloadOut | Should -Be $script:ytLocal
		}
		It 'ダウンロードに失敗したときは、元の実行ファイルを変更しないこと' {
			New-FakeYtdl -Path $script:ytLocal -Version '2024.01.01'
			Mock Invoke-WebRequest { throw 'download failed' }
			Update-Ytdl | Out-Null
			(& $script:ytLocal --version) | Should -Be '2024.01.01'
		}
	}

	Context 'Windows' -Skip:(-not $IsWindows) {
		It 'ダウンロードするファイルと配置するファイルは、.exeを付けた名前になること' {
			Update-Ytdl | Out-Null
			$script:ytDownloadUri | Should -Be ('https://github.com/yt-dlp/yt-dlp/releases/download/{0}/yt-dlp.exe' -f $script:ytLatest)
			$script:ytDownloadOut | Should -Be (Join-Path $script:binDir 'yt-dlp.exe')
		}
		It 'ytdl-patchedは、ytdl-patched.exeをダウンロードして、yt-dlp.exeという名前で配置すること' {
			$script:preferredYoutubedl = 'ytdl-patched'
			Update-Ytdl | Out-Null
			$script:ytDownloadUri | Should -Be ('https://github.com/ytdl-patched/ytdl-patched/releases/download/{0}/ytdl-patched.exe' -f $script:ytLatest)
			$script:ytDownloadOut | Should -Be (Join-Path $script:binDir 'yt-dlp.exe')
		}
		It '配置した実行ファイルを起動できなければ、バージョン確認の失敗を警告すること' {
			# * 偽物のexeは実行できないため、更新後のバージョン確認に失敗する
			Mock Invoke-WebRequest { Set-Content -LiteralPath $OutFile -Value 'not an exe' -NoNewline }
			Update-Ytdl | Out-Null
			Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq $script:msg.ToolVersionCheckFailed }
		}
	}
}

#----------------------------------------------------------------------
# スクリプトとして実行したときの動作(環境設定と更新処理の呼び出し)
#----------------------------------------------------------------------
Describe 'update_youtube-dl.ps1をスクリプトとして実行したとき' {
	BeforeEach {
		# * 本物のbin・confに触れないよう、スクリプト・メッセージ・設定を一時ディレクトリにまとめて実行する
		$script:sbRoot = Join-Path $TestDrive ('sb{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path (Join-Path $script:sbRoot 'src/functions'), (Join-Path $script:sbRoot 'resources/lang'), (Join-Path $script:sbRoot 'conf'), (Join-Path $script:sbRoot 'bin') -Force | Out-Null
		Copy-Item -LiteralPath $targetFile -Destination (Join-Path $script:sbRoot 'src/functions/update_youtube-dl.ps1')
		Copy-Item -LiteralPath (Join-Path $script:repoRoot 'resources/lang/messages.json') -Destination (Join-Path $script:sbRoot 'resources/lang/messages.json')
		Set-Content -LiteralPath (Join-Path $script:sbRoot 'conf/system_setting.ps1') -Value "`$script:preferredLanguage = ''`n" -NoNewline
		$script:sbBin = (Join-Path $script:sbRoot 'bin').Replace("'", "''")
		Set-Content -LiteralPath (Join-Path $script:sbRoot 'conf/user_setting.ps1') -Value ("`$script:binDir = '{0}'`n`$script:timeoutSec = 5`n`$script:preferredYoutubedl = 'sandbox-unknown'`n" -f $script:sbBin)
		$script:sbScript = Join-Path $script:sbRoot 'src/functions/update_youtube-dl.ps1'
		Push-Location
		Mock Write-Warning {}
	}
	AfterEach { Pop-Location }
	It '設定ファイルを読み込んで、更新処理を実行すること' {
		& $script:sbScript | Out-Null
		Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*sandbox-unknown*' }
	}
	It 'スペースを含むディレクトリに置かれていたら、例外にすること' {
		$spaced = Join-Path $TestDrive ('with space{0}' -f [Guid]::NewGuid().ToString('N'))
		Copy-Item -LiteralPath $script:sbRoot -Destination $spaced -Recurse
		{ & (Join-Path $spaced 'src/functions/update_youtube-dl.ps1') } | Should -Throw -ExpectedMessage '*スペースを含むディレクトリ*'
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
	It 'ドット読み込みでは、更新処理を実行しないこと' {
		. $script:sbScript
		Should -Invoke Write-Warning -Times 0 -Exactly
	}
}
