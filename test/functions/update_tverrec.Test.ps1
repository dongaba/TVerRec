Import-Module Pester -MinimumVersion 5.0

BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot 'src/functions/update_tverrec.ps1'
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	# update_tverrec.ps1は読み込むと更新処理が走るスクリプトのため、dot-sourceせず、関数の定義だけを取り出して使う
	$tokens = $null ; $parseErrors = $null
	$ast = [System.Management.Automation.Language.Parser]::ParseFile($targetFile, [ref]$tokens, [ref]$parseErrors)
	$funcAst = $ast.Find({ param ($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq 'Move-Files' }, $true)
	if (-not $funcAst) { throw 'Move-Files の定義が見つかりません' }
	. ([ScriptBlock]::Create($funcAst.Extent.Text))
	Write-Host ('　テスト対象の関数を読み込みました')
}

#----------------------------------------------------------------------
# ディレクトリの上書き移動
#----------------------------------------------------------------------
Describe 'Move-Files' {
	BeforeEach {
		$script:mvRoot = Join-Path $TestDrive ('mv{0}' -f [Guid]::NewGuid().ToString('N'))
		$script:mvSrc = Join-Path $script:mvRoot 'src'
		$script:mvDst = Join-Path $script:mvRoot 'dst'
		New-Item -ItemType Directory -Path $script:mvSrc, $script:mvDst -Force | Out-Null
		function script:Set-TestText { Param ([String]$Path, [String]$Text) ; New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null ; Set-Content -LiteralPath $Path -Value $Text -NoNewline }
		function script:Get-TestText { Param ([String]$Path) ; [IO.File]::ReadAllText($Path) }
	}
	It 'ファイルを、移動先に存在しなければそのまま移動すること' {
		Set-TestText (Join-Path $script:mvSrc 'a.txt') 'new'
		Move-Files -source (Join-Path $script:mvSrc 'a.txt') -destination (Join-Path $script:mvDst 'a.txt') | Out-Null
		Test-Path -LiteralPath (Join-Path $script:mvSrc 'a.txt') | Should -BeFalse
		Get-TestText (Join-Path $script:mvDst 'a.txt') | Should -Be 'new'
	}
	It 'ファイルは、移動先に同名ファイルがあれば上書きすること' {
		Set-TestText (Join-Path $script:mvSrc 'a.txt') 'new'
		Set-TestText (Join-Path $script:mvDst 'a.txt') 'old'
		Move-Files -source (Join-Path $script:mvSrc 'a.txt') -destination (Join-Path $script:mvDst 'a.txt') | Out-Null
		Get-TestText (Join-Path $script:mvDst 'a.txt') | Should -Be 'new'
	}
	It 'ファイルの移動では「移動元 → 移動先」を出力すること' {
		Set-TestText (Join-Path $script:mvSrc 'a.txt') 'new'
		$out = @(Move-Files -source (Join-Path $script:mvSrc 'a.txt') -destination (Join-Path $script:mvDst 'a.txt'))
		$out.Count | Should -Be 1
		$out[0] | Should -BeLike '* → *'
	}
	It 'ディレクトリは、移動先に存在するなら中身を再帰的に上書きして統合し、移動元は削除すること' {
		Set-TestText (Join-Path $script:mvSrc 'a.txt') 'new-a'
		Set-TestText (Join-Path $script:mvSrc 'sub/b.txt') 'new-b'
		Set-TestText (Join-Path $script:mvSrc 'sub/deep/c.txt') 'new-c'
		Set-TestText (Join-Path $script:mvSrc 'only-new/d.txt') 'new-d'
		Set-TestText (Join-Path $script:mvDst 'a.txt') 'old-a'
		Set-TestText (Join-Path $script:mvDst 'keep.txt') 'keep'
		Set-TestText (Join-Path $script:mvDst 'sub/b.txt') 'old-b'
		Set-TestText (Join-Path $script:mvDst 'sub/keep2.txt') 'keep2'
		Move-Files -source $script:mvSrc -destination $script:mvDst | Out-Null
		Get-TestText (Join-Path $script:mvDst 'a.txt') | Should -Be 'new-a'
		Get-TestText (Join-Path $script:mvDst 'sub/b.txt') | Should -Be 'new-b'
		Get-TestText (Join-Path $script:mvDst 'sub/deep/c.txt') | Should -Be 'new-c'
		Get-TestText (Join-Path $script:mvDst 'only-new/d.txt') | Should -Be 'new-d'
		Get-TestText (Join-Path $script:mvDst 'keep.txt') | Should -Be 'keep'
		Get-TestText (Join-Path $script:mvDst 'sub/keep2.txt') | Should -Be 'keep2'
		Test-Path -LiteralPath $script:mvSrc | Should -BeFalse
	}
	It 'ディレクトリは、移動先に存在しなければディレクトリごと移動すること' {
		Set-TestText (Join-Path $script:mvSrc 'sub/b.txt') 'new-b'
		$newDst = Join-Path $script:mvRoot 'newdst'
		Move-Files -source $script:mvSrc -destination $newDst | Out-Null
		Get-TestText (Join-Path $newDst 'sub/b.txt') | Should -Be 'new-b'
		Test-Path -LiteralPath $script:mvSrc | Should -BeFalse
	}
	It 'アップデータ自身(update_tverrec.*)は移動せず、移動先の既存のアップデータも上書きしないこと' {
		Set-TestText (Join-Path $script:mvSrc 'update_tverrec.ps1') 'new-updater'
		Set-TestText (Join-Path $script:mvSrc 'update_tverrec.sh') 'new-updater-sh'
		Set-TestText (Join-Path $script:mvSrc 'other.txt') 'other'
		Set-TestText (Join-Path $script:mvDst 'update_tverrec.ps1') 'running-updater'
		Move-Files -source $script:mvSrc -destination $script:mvDst | Out-Null
		Get-TestText (Join-Path $script:mvDst 'update_tverrec.ps1') | Should -Be 'running-updater'
		Test-Path -LiteralPath (Join-Path $script:mvDst 'update_tverrec.sh') | Should -BeFalse
		Get-TestText (Join-Path $script:mvDst 'other.txt') | Should -Be 'other'
	}
	It '入れ子のディレクトリにあるアップデータ自身も移動しないこと' {
		Set-TestText (Join-Path $script:mvSrc 'sub/update_tverrec.ps1') 'new-updater'
		Set-TestText (Join-Path $script:mvSrc 'sub/x.txt') 'x'
		Set-TestText (Join-Path $script:mvDst 'sub/keep.txt') 'keep'
		Move-Files -source $script:mvSrc -destination $script:mvDst | Out-Null
		Test-Path -LiteralPath (Join-Path $script:mvDst 'sub/update_tverrec.ps1') | Should -BeFalse
		Get-TestText (Join-Path $script:mvDst 'sub/x.txt') | Should -Be 'x'
	}
	It '移動元が存在しなければ、-ErrorAction Stopを指定したときに例外になること' {
		{ Move-Files -source (Join-Path $script:mvRoot 'missing.txt') -destination (Join-Path $script:mvDst 'missing.txt') -ErrorAction Stop } | Should -Throw
	}
}
