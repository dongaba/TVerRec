Import-Module Pester -MinimumVersion 5.0

#region BeforeAll

#----------------------------------------------------------------------
#テスト対象ファイルの読み込み
#----------------------------------------------------------------------
BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$targetfile = $PSCommandPath.replace('test', 'src').replace('.Test.ps1', '.ps1')
	Write-Host ('　テスト対象: {0}' -f $targetfile)
	$script:libDir = Split-Path(Split-Path $targetfile.replace('src', 'resources/lib') -Parent) -Parent
	$script:disableToastNotification = $false
	. $targetfile
	Write-Host ('　テスト対象の読み込みを行いました')
}

#endregion BeforeAll

#region ガーベッジコレクション

#----------------------------------------------------------------------
#ガーベッジコレクション
#----------------------------------------------------------------------
Describe 'ガーベッジコレクション' {
	It 'OutputType 属性が System.Void として定義されているべき' {
		$function = Get-Command Invoke-GarbageCollection
		$expectedOutputType = 'Void'
		$attributes = $function.OutputType
		$attributes.Type.Name | Should -BeExactly $expectedOutputType
	}
	# It 'メモリ使用量が削減すること(しないことも多いのでFailすることも多々ある)' {
	# 	$before = (Get-Process -Id $PID).ws
	# 	Invoke-GarbageCollection
	# 	$after = (Get-Process -Id $PID).ws
	# 	#Write-Host $before
	# 	#Write-Host $after
	# 	$before - $after | Should -BeGreaterOrEqual 0
	# }
}

#endregion ガーベッジコレクション

#region タイムスタンプ

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
Describe 'タイムスタンプ更新' {
	It 'タイムスタンプを取得できること' {
		Mock Get-Date { return [DateTime]'2023-04-01 12:34:56' }
		$expectedTimeStamp = '2023-04-01 12:34:56'
		Get-TimeStamp | Should -BeExactly $expectedTimeStamp
	}
	It 'タイムスタンプが "yyyy-MM-dd HH:mm:ss" 形式であること' {
		Mock Get-Date { return [DateTime]'2021-01-01 12:34:56' }
		Get-TimeStamp | Should -BeExactly '2021-01-01 12:34:56'
	}
	It 'String型で返ってくること' {
		Get-TimeStamp | Should -BeOfType String
	}
}

#----------------------------------------------------------------------
#UNIX時間をDateTime型に変換
#----------------------------------------------------------------------
Describe 'UNIX時間をDateTime型に変換' {
	It 'Converts a given Unix time to the correct local datetime object' {
		Mock Get-Date { return [DateTime]'1970-01-01T00:00:00Z' }
		$unixTime = 0
		$expectedDateTime = (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0)
		ConvertFrom-UnixTime -UnixTime $unixTime | Should -BeExactly $expectedDateTime
	}
	It '整数以外の値が渡された場合、エラーをスローすること' {
		{ ConvertFrom-UnixTime -UnixTime 'NotAnInteger' } | Should -Throw
	}
	It 'DateTime型で返ってくること' {
		ConvertFrom-UnixTime 1712174580 | Should -BeOfType DateTime
	}
}

#----------------------------------------------------------------------
#DateTime型をUNIX時間に変換
#----------------------------------------------------------------------
Describe 'DateTime型をUNIX時間に変換' {
	It 'UNIX時間の0の定義が正しいこと' {
		$inputDate = [DateTime]'1970-01-01T00:00:00Z'
		$expectedUnixTime = 0
		ConvertTo-UnixTime -InputDate $inputDate | Should -BeExactly $expectedUnixTime
	}
	It '既知の日付を正しいUnixタイムスタンプに変換すること' {
		Mock Get-Date { return [DateTime]'2021-01-01T00:00:00Z' }
		$expectedUnixTime = 1609459200 # Unix time for 2021-01-01T00:00:00Z
		$actualUnixTime = ConvertTo-UnixTime -InputDate (Get-Date).ToUniversalTime()
		$actualUnixTime | Should -BeExactly $expectedUnixTime
	}
	It 'うるう年の正しいUnixタイムスタンプを返すこと' {
		Mock Get-Date { return [DateTime]'2020-02-29T00:00:00Z' }
		$expectedUnixTime = 1582934400 # Unix time for 2020-02-29T00:00:00Z
		$actualUnixTime = ConvertTo-UnixTime -InputDate (Get-Date).ToUniversalTime()
		$actualUnixTime | Should -BeExactly $expectedUnixTime
	}
	It 'int64型で返ってくること' {
		ConvertTo-UnixTime (Get-Date) | Should -BeOfType Long
	}
}

#endregion タイムスタンプ

#region 文字列操作
#----------------------------------------------------------------------
#ファイル名・ディレクトリ名に禁止文字の削除
#----------------------------------------------------------------------
Describe 'ファイル名・ディレクトリ名に禁止文字の削除' {
	It 'String型で返ってくること' {
		Get-FileNameWithoutInvalidChars 'Test\Path/File\Name' | Should -BeOfType String
	}
	It 'ファイル名から無効な文字を取り除くこと' {
		$fileNameWithInvalidChars = 'test<file>|name?.txt'
		$expectedResult = 'test-file-name-.txt'
		Get-FileNameWithoutInvalidChars -Name $fileNameWithInvalidChars | Should -BeExactly $expectedResult
	}
	It '無効な文字がなければ同じ名前を返すこと' {
		$validName = 'valid-file_name.txt'
		Get-FileNameWithoutInvalidChars -Name $validName | Should -BeExactly $validName
	}
	It '無効なファイル名文字をすべて削除すること' {
		$nameWithInvalidChars = 'Invalid:Name*/?<>|'
		$result = Get-FileNameWithoutInvalidChars -Name $nameWithInvalidChars
		$invalidChars = [IO.Path]::GetInvalidFileNameChars()
		# Assert that none of the invalid characters are present in the result
		foreach ($char in $invalidChars) {
			$charString = [string]$char
			if ($charString.Trim() -ne '') { # Exclude empty or whitespace characters
				$result | Should -Not -Contain $charString
			}
		}
	}
	It '特定の無効なファイル名文字をハイフンに置き換えること' {
		$nameWithSpecificChars = 'NameWith*Question?Mark<Greater>Than|Pipe'
		Get-FileNameWithoutInvalidChars -Name $nameWithSpecificChars | Should -BeExactly 'NameWith-Question-Mark-Greater-Than-Pipe'
	}
	It '名前から印字不可能な文字を取り除くこと' {
		$nameWithNonPrintables = 'NameWith[]'
		Get-FileNameWithoutInvalidChars -Name $nameWithNonPrintables | Should -BeExactly 'NameWith[]'
	}
	It 'ファイル名の*と?を-に置き換えること' {
		$fileNameWithStarAndQuestion = 'file*name?.txt'
		$expectedResult = 'file-name-.txt'
		Get-FileNameWithoutInvalidChars -Name $fileNameWithStarAndQuestion | Should -BeExactly $expectedResult
	}
	It '名前から印字不可能な文字を取り除くこと' {
		$fileNameWithNonPrintableChars = "test`u{0016}file`u{0019}name.txt"
		$expectedResult = 'testfilename.txt'
		Get-FileNameWithoutInvalidChars -Name $fileNameWithNonPrintableChars | Should -BeExactly $expectedResult
	}
	It '空文字列入力を処理すること' {
		$emptyName = ''
		Get-FileNameWithoutInvalidChars -Name $emptyName  | Should -BeExactly $emptyName
	}
}

#----------------------------------------------------------------------
#英数のみ全角→半角(カタカナは全角)
#----------------------------------------------------------------------
Describe '英数のみ全角→半角(カタカナは全角)' {
	It 'String型で返ってくること' {
		Get-NarrowChars 'ﾃｽﾄ' | Should -BeOfType String
	}
	It '全角英数が半角となること' -TestCases @(
		@{Target = '０１２３４５６７８９' ; Expected = '0123456789' }
		@{Target = 'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ' ; Expected = 'abcdefghijklmnopqrstuvwxyz' }
		@{Target = 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ' ; Expected = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' }
	) {
		Param ($Target, $Expected)
		Get-NarrowChars $Target | Should -Be $Expected
	}
	It '半角英数はそのまま返却されること' -TestCases @(
		@{Target = '0123456789' ; Expected = '0123456789' }
		@{Target = 'abcdefghijklmnopqrstuvwxyz' ; Expected = 'abcdefghijklmnopqrstuvwxyz' }
		@{Target = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' ; Expected = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' }
	) {
		Param ($Target, $Expected)
		Get-NarrowChars $Target | Should -Be $Expected
	}
	It '全角記号が半角記号になること' -TestCases @(
		@{
			Target   = '＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：．，'
			Expected = '@#$%^&*-+_/[]{}()<> \\";:.,'
		}
	) {
		Param ($Target, $Expected)
		Get-NarrowChars $Target | Should -Be $Expected
	}
	It '半角記号はそのまま返却されること' -TestCases @(
		@{Target = '@#$%^&*-+_/[]{}()<> \\";:.,' ; Expected = '@#$%^&*-+_/[]{}()<> \\";:.,' }
	) {
		Param ($Target, $Expected)
		Get-NarrowChars $Target | Should -Be $Expected
	}

	It '全角カタカナはそのまま返却されること' -TestCases @(
		@{
			Target   = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヰヱヲ'
			Expected = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヰヱヲ'
		}
		@{
			Target   = 'ァィゥェォャュョッーヴガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ'
			Expected = 'ァィゥェォャュョッーヴガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ'
		}
	) {
		Param ($Target, $Expected)
		Get-NarrowChars $Target | Should -Be $Expected
	}
	It '半角カタカナは全角となること' -TestCases @(
		@{
			Target   = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦ'
			Expected = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲ'
		}
		@{
			Target   = 'ｧｨｩｪｫｬｭｮｯｰｳﾞｶﾞｷﾞｸﾞｹﾞｺﾞｻﾞｼﾞｽﾞｾﾞｿﾞﾀﾞﾁﾞﾂﾞﾃﾞﾄﾞﾊﾞﾋﾞﾌﾞﾍﾞﾎﾞﾊﾟﾋﾟﾌﾟﾍﾟﾎﾟ'
			Expected = 'ァィゥェォャュョッーヴガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ'
		}
	) {
		Param ($Target, $Expected)
		Get-NarrowChars $Target | Should -Be $Expected
	}
}

#----------------------------------------------------------------------
#いくつかの特殊文字を置換
#----------------------------------------------------------------------
Describe 'いくつかの特殊文字を置換' {
	It 'String型で返ってくること' {
		Remove-SpecialCharacter 'テスト' | Should -BeOfType String
	}
	It '特殊文字を置換または削除すること' -TestCases @(
		@{Target = '&amp;' ; Expected = '&' }
		@{Target = '*'     ; Expected = '＊' }
		@{Target = '|'     ; Expected = '｜' }
		@{Target = ':'     ; Expected = '：' }
		@{Target = ';'     ; Expected = '；' }
		@{Target = '"'     ; Expected = '' }
		@{Target = '“'     ; Expected = '' }
		@{Target = '”'     ; Expected = '' }
		@{Target = ','     ; Expected = '' }
		@{Target = '?'     ; Expected = '？' }
		@{Target = '!'     ; Expected = '！' }
		@{Target = '/'     ; Expected = '-' }
		@{Target = '\'     ; Expected = '-' }
		@{Target = '<'     ; Expected = '＜' }
		@{Target = '>'     ; Expected = '＞' }
	) {
		Param ($Target, $Expected)
		Remove-SpecialCharacter $Target | Should -Be $Expected
	}
	It '文字列から指定された文字を取り除くこと' {
		$text = 'This is a "test" string, right?'
		$expectedResult = 'This is a test string right？'
		Remove-SpecialCharacter -text $text | Should -BeExactly $expectedResult
	}
	It '空の文字列を扱えること' {
		$text = ''
		$expectedResult = ''
		Remove-SpecialCharacter -text $text | Should -BeExactly $expectedResult
	}
	It '入力がNULLの場合、NULLを返すこと' {
		$text = $null
		Remove-SpecialCharacter -text $text | Should -Be ''
	}
}

#----------------------------------------------------------------------
#タブとスペースを詰めて半角スペース1文字に
#----------------------------------------------------------------------
Describe 'タブとスペースを詰めて半角スペース1文字に' {
	It 'String型で返ってくること' {
		Remove-TabSpace 'テスト' | Should -BeOfType String
	}
	It 'タブとスペースを詰めて半角スペース1文字に置換すること' -TestCases @(
		@{Target = "`t"       ; Expected = ' ' }
		@{Target = "`t`t"     ; Expected = ' ' }
		@{Target = "`t "      ; Expected = ' ' }
		@{Target = " `t"      ; Expected = ' ' }
		@{Target = '	'     ; Expected = ' ' }
		@{Target = ' 	'     ; Expected = ' ' }
		@{Target = '	 '    ; Expected = ' ' }
		@{Target = '		' ; Expected = ' ' }
		@{Target = '  '       ; Expected = ' ' }
	) {
		Param ($Target, $Expected)
		Remove-TabSpace $Target | Should -Be $Expected
	}
}

#----------------------------------------------------------------------
#設定ファイルの行末コメントを削除
#----------------------------------------------------------------------
Describe '設定ファイルの行末コメントを削除' {
	It 'String型で返ってくること' {
		Remove-Comment 'テスト' | Should -BeOfType String
	}
	It '設定ファイルの行末コメントを削除すること' -TestCases @(
		@{Target = 'series/srz38rt0a3		#情熱大陸' ; Expected = 'series/srz38rt0a3' }
		@{Target = 'series/srz38rt0a3	#情熱大陸' ; Expected = 'series/srz38rt0a3' }
		@{Target = 'series/srz38rt0a3  #情熱大陸' ; Expected = 'series/srz38rt0a3' }
		@{Target = 'series/srz38rt0a3 #情熱大陸' ; Expected = 'series/srz38rt0a3' }
		@{Target = 'toppage		#トップページに表示される動画' ; Expected = 'toppage' }
		@{Target = 'toppage	#トップページに表示される動画' ; Expected = 'toppage' }
		@{Target = 'toppage  #トップページに表示される動画' ; Expected = 'toppage' }
		@{Target = 'toppage #トップページに表示される動画' ; Expected = 'toppage' }
	) {
		Param ($Target, $Expected)
		Remove-Comment $Target | Should -Be $Expected
	}
}

#endregion 文字列操作

#region ファイル操作

#----------------------------------------------------------------------
#指定したPath配下の指定した条件でファイルを削除
#----------------------------------------------------------------------
Describe 'Remove-Files Tests' {
	Context 'シングルスレッド' {
		BeforeAll {
			Function Get-TestDrive {}
			Mock Get-TestDrive { return 'TestPath' }

			$testFolderPath = Join-Path (Get-TestDrive) 'TestFolder'
			Remove-Item -Path (Get-TestDrive) -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
			New-Item -ItemType Directory -Path $testFolderPath | Out-Null
			$script:enableMultithread = $false

			1..2 | ForEach-Object {
				$filePath = Join-Path $testFolderPath "$_.txt"
				New-Item -ItemType File -Path $filePath | Out-Null
				(Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(-2)
			}
			3..4 | ForEach-Object {
				$filePath = Join-Path $testFolderPath "$_.txt"
				New-Item -ItemType File -Path $filePath | Out-Null
				(Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(0)
			}
			5..6 | ForEach-Object {
				$filePath = Join-Path $testFolderPath "$_.csv"
				New-Item -ItemType File -Path $filePath | Out-Null
				(Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(-2)
			}
		}

		It '指定された期間より古いファイルを削除すること' {
			$basePath = [System.IO.FileInfo]::new($testFolderPath)
			$conditions = '*.txt'
			$delPeriod = 1

			{ Remove-Files -basePath $basePath -conditions $conditions -delPeriod $delPeriod } | Should -Not -Throw

			$existingFiles = Get-ChildItem -Path $testFolderPath -File
			$existingFiles.Count | Should -Be 4
		}

		AfterAll {
			Remove-Item -Path (Get-TestDrive) -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-Variable -Name enableMultithread, condition, delPeriod -ErrorAction SilentlyContinue
		}
	}

	Context 'マルチスレッド' -Tag 'Multithread' {
		BeforeAll {
			Function Get-TestDrive {}
			Mock Get-TestDrive { return 'TestPath' }

			$testFolderPath = Join-Path (Get-TestDrive) 'TestFolder'
			Remove-Item -Path (Get-TestDrive) -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
			New-Item -ItemType Directory -Path $testFolderPath | Out-Null
			$script:enableMultithread = $true
			$script:multithreadNum = 10

			1..19 | ForEach-Object {
				$filePath = Join-Path $testFolderPath "$_.txt"
				New-Item -ItemType File -Path $filePath | Out-Null
				(Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(-2)
			}
			20..39 | ForEach-Object {
				$filePath = Join-Path $testFolderPath "$_.txt"
				New-Item -ItemType File -Path $filePath | Out-Null
				(Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(0)
			}
			40..59 | ForEach-Object {
				$filePath = Join-Path $testFolderPath "$_.csv"
				New-Item -ItemType File -Path $filePath | Out-Null
				(Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(-2)
			}
		}

		It '指定された期間より古いファイルを削除すること' {
			$basePath = [System.IO.FileInfo]::new($testFolderPath)
			$conditions = '*.txt'
			$delPeriod = 1

			{ Remove-Files -basePath $basePath -conditions $conditions -delPeriod $delPeriod } | Should -Not -Throw

			$existingFiles = Get-ChildItem -LiteralPath $testFolderPath -File
			$existingFiles.Count | Should -Be 40
		}

		AfterAll {
			Remove-Item -Path (Get-TestDrive) -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		}
	}
}


#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
Describe 'Expand-Zip Tests' {
	BeforeAll {
		Function Get-TestDrive {}
		Mock Get-TestDrive { return 'TestPath' }

		$testPath = Join-Path (Get-TestDrive) 'sample.zip'
		$destinationPath = Join-Path (Get-TestDrive) 'Extracted'
		Remove-Item -Path $destinationPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		New-Item -ItemType Directory -Path (Get-TestDrive) -Force | Out-Null

		# Create a dummy zip file using ZipArchive class
		$zipFileStream = [System.IO.FileStream]::new($testPath, [System.IO.FileMode]::Create)
		$zipArchive = [System.IO.Compression.ZipArchive]::new($zipFileStream, [System.IO.Compression.ZipArchiveMode]::Create)
		$zipEntry = $zipArchive.CreateEntry('dummy.txt')
		$streamWriter = [System.IO.StreamWriter]::new($zipEntry.Open())
		$streamWriter.WriteLine('Dummy content')
		$streamWriter.Dispose()
		$zipArchive.Dispose()
		$zipFileStream.Dispose()
	}

	It 'パスが指定された場所にファイルを解凍すること' {
		Expand-Zip -Path $testPath -Destination $destinationPath
		Test-Path -Path "$destinationPath\dummy.txt" | Should -BeTrue
	}
	It '解凍したファイルの中身が正しいこと' {
		Expand-Zip -Path $testPath -Destination $destinationPath
		Get-Content "$destinationPath\dummy.txt" | Should -Be 'Dummy content'
	}
	It 'すでにファイルが存在するときに上書きすること' {
		$zipFileStream = [System.IO.FileStream]::new($testPath, [System.IO.FileMode]::Create)
		$zipArchive = [System.IO.Compression.ZipArchive]::new($zipFileStream, [System.IO.Compression.ZipArchiveMode]::Create)
		$zipEntry = $zipArchive.CreateEntry('dummy.txt')
		$streamWriter = [System.IO.StreamWriter]::new($zipEntry.Open())
		$streamWriter.WriteLine('Overwrite content')
		$streamWriter.Dispose()
		$zipArchive.Dispose()
		$zipFileStream.Dispose()
		Expand-Zip -Path $testPath -Destination $destinationPath
		Get-Content "$destinationPath\dummy.txt" | Should -Be 'Overwrite content'
	}
	It 'zipファイルが存在しない場合はエラーを投げること' {
		$nonExistingPath = 'NonExisting\sample.zip'
		{ Expand-Zip -Path $nonExistingPath -Destination $destinationPath } | Should -Throw ('❌️ {0}が見つかりません' -f $nonExistingPath)
	}

	AfterAll {
		Remove-Item -Path (Get-TestDrive) -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
	}
}

#endregion ファイル操作

#region ファイルロック

#----------------------------------------------------------------------
#ファイルのロック関連
#----------------------------------------------------------------------
Describe 'ファイルのロック' {
	BeforeAll {
		$script:fileInfo = @{}
		$script:fileStream = @{}
		$testPath = 'test.lock'
		New-Item -Path $testPath -ItemType File -Force | Out-Null
	}

	AfterEach {
		if (Test-Path $testPath) {
			Remove-Item -Path $testPath -Force -ErrorAction SilentlyContinue | Out-Null
		}
	}

	It 'ロックを取得すること' {
		$result = Lock-File -Path $testPath
		$result | Should -BeOfType [PSCustomObject]
		$result.result | Should -BeTrue
		$result.path | Should -Be $testPath
		$script:fileStream[$testPath] | Should -Not -BeNullOrEmpty
	}
	It '既に自プロセスでロック取得済みの場合はロックを取得できないこと(Mac/Windows)' -Skip:($IsLinux) {
		Lock-File -Path $testPath
		$result = Lock-File -Path $testPath
		$result | Should -BeOfType [PSCustomObject]
		$result.result | Should -BeFalse
	}
	It '既に自プロセスでロック取得済みの場合はロックを取得できること(Linux)' -Skip:(!$IsLinux) {
		Lock-File -Path $testPath
		$result = Lock-File -Path $testPath
		$result | Should -BeOfType [PSCustomObject]
		$result.result | Should -BeTrue
	}
	It '存在しないファイルのロック取得はできないこと' {
		$nonExistentPath = 'NonExistentFile.txt'
		$result = Lock-File -path $nonExistentPath
		$result.result | Should -BeFalse
		$result.path | Should -Be $nonExistentPath
	}
	It '他プロセスでロック取得している場合はロック取得できないこと' {
		Start-Job -ScriptBlock {
			$lockFilePath = 'multiple.lock'
			$fileStream = [System.IO.File]::Open($lockFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
			Start-Sleep -Seconds 60  #keep lock for 5 seconds
			$fileStream.Close()
		}
		$result = Lock-File -path 'multiple.lock'
		$result.result | Should -BeFalse
		$result.path | Should -Be 'multiple.lock'

		Wait-Job -State Completed
		Unlock-File -path 'multiple.lock'
	}

	AfterAll {
		Remove-Item -Path $testPath -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'multiple.lock' -Force -ErrorAction SilentlyContinue | Out-Null
	}
}

#----------------------------------------------------------------------
#ファイルのアンロック
#----------------------------------------------------------------------
Describe 'ファイルのアンロック' {
	BeforeAll {
		$script:fileInfo = @{}
		$script:fileStream = @{}
	}

	BeforeEach {
		$testPath = 'test.lock'
		if (!(Test-Path $testPath)) {
			New-Item -Path $testPath -ItemType File -Force | Out-Null
		}
	}

	AfterEach {
		if (Test-Path $testPath) {
			Remove-Item -Path $testPath -Force -ErrorAction SilentlyContinue | Out-Null
		}
	}

	It '自プロセスが取得したロックを解除できること' {
		Lock-File -Path $testPath
		$result = Unlock-File -Path $testPath
		$result.result | Should -BeTrue
		$result.path | Should -Be $testPath
		$script:fileStream[$testPath] | Should -BeNullOrEmpty
	}
	It 'ロックファイルがない場合はエラーとすること' {
		$result = Unlock-File -Path 'nonexistent.lock'
		$result.result | Should -BeFalse
	}
	It '他プロセスでロック取得したロックは解除できないこと' {
		Start-Job -ScriptBlock {
			$lockFilePath = 'multiple.lock'
			$fileStream = [System.IO.File]::Open($lockFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
			Start-Sleep -Seconds 60  #keep lock for 5 seconds
			$fileStream.Close()
		}
		$result = Unlock-File -path 'multiple.lock'
		$result.result | Should -BeFalse
		$result.path | Should -Be 'multiple.lock'

		Wait-Job -State Completed
		Unlock-File -path 'multiple.lock'
	}

	AfterAll {
		Remove-Item -Path 'multiple.lock' -Force -ErrorAction SilentlyContinue | Out-Null
	}
}

#endregion ファイルロック

#region コンソール出力

#----------------------------------------------------------------------
#色付きWrite-Output
#----------------------------------------------------------------------
Describe 'Out-Msg-Color テスト' {
	BeforeAll {
		Mock Write-Host {}
	}

	It '正しいテキストでWrite-Hostを呼び出す' {
		Out-Msg-Color -text 'Hello, World!'
		Assert-MockCalled -CommandName Write-Host -Times 1 -Scope It -ParameterFilter {
			$Object -eq 'Hello, World!'
		}
	}
	It 'noNLがtrueの場合、改行を出力しない。' {
		Out-Msg-Color -text 'Hello, World!' -noNL $true
		Assert-MockCalled -CommandName Write-Host -Times 1 -Scope It -ParameterFilter {
			$NoNewline -eq $true
		}
	}
}

#endregion コンソール出力

#region トースト通知

#----------------------------------------------------------------------
#トースト表示
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#進捗バー付きトースト表示
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#進捗バー付きトースト更新
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#進捗表示(2行進捗バー)
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#進捗更新(2行進捗バー)
#----------------------------------------------------------------------

#endregion トースト通知

#----------------------------------------------------------------------
#Base64画像の展開
#----------------------------------------------------------------------
Describe 'Base64画像の展開' {
	It '無効なBase64文字列の場合は例外を投げる' {
		$invalidBase64 = 'thisIsNotBase64'
		{ ConvertFrom-Base64 -base64 $invalidBase64 } | Should -Throw
	}

	It '空の文字列が渡された場合は例外を投げる' {
		$emptyBase64 = ''
		{ ConvertFrom-Base64 -base64 $emptyBase64 } | Should -Throw
	}
}
