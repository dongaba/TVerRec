###################################################################################
#
#		TVerRec固有関数スクリプト(ダウンロード対象外リストの読み込み・判定・並べ替え)
#
###################################################################################
<#
	.SYNOPSIS
		ダウンロード対象外リストの読み込み・判定・並べ替えの関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region ダウンロード対象外リスト関連
#----------------------------------------------------------------------
# ダウンロード対象外リストの1行が対象文字列にマッチするかを判定
#----------------------------------------------------------------------
function Test-IgnoreMatch {
	<#
		.SYNOPSIS
			ダウンロード対象外リストの1行が、いずれかの対象文字列にマッチするかを判定します。

		.DESCRIPTION
			行頭が`regex:`の行は、それ以降を.NETの正規表現として対象文字列に適用します。
			(部分一致。大文字小文字は区別します。区別しない場合は`regex:(?i)...`のように指定します)
			それ以外の行は、従来どおり呼び出し元ごとの方式で判定します。
			- Literal : 大文字小文字を区別する部分一致(ワイルドカードは通常の文字)。リスト作成時の判定
			- Wildcard: `-like '*行*'`によるワイルドカード判定。ダウンロード時・不要ファイル削除時の判定
			不正な正規表現の行は警告を1回だけ表示し、マッチしないものとして扱います。

		.PARAMETER Pattern
			ダウンロード対象外リストの1行を指定します。

		.PARAMETER Target
			判定対象の文字列(番組名、ファイル名など)を指定します。いずれかにマッチすれば$trueを返します。

		.PARAMETER Mode
			`regex:`で始まらない行の判定方式(Literal/Wildcard)を指定します。

		.OUTPUTS
			[Boolean]
			マッチした場合は$true、それ以外は$false。

		.EXAMPLE
			Test-IgnoreMatch -Pattern 'regex:冷凍庫に眠っている (第|最終)' -Target @($videoInfo.fileName) -Mode Wildcard
	#>
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $true)][String]$Pattern,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String[]]$Target,
		[Parameter(Mandatory = $true)][ValidateSet('Literal', 'Wildcard')][String]$Mode
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$targets = @($Target).Where({ $_ })
	if ($targets.Count -eq 0) { return $false }

	if ($Pattern -cmatch '^regex:(.*)$') {
		$body = $Matches[1].Normalize([Text.NormalizationForm]::FormC)
		if (!(Test-Path Variable:Script:ignoreRegexCache)) { $script:ignoreRegexCache = @{} }
		if (!$script:ignoreRegexCache.ContainsKey($Pattern)) {
			$regex = $null
			if ($body.Trim() -ne '') {
				try { $regex = [Regex]::new($body, [Text.RegularExpressions.RegexOptions]::None, [TimeSpan]::FromSeconds(1)) }
				catch { $regex = $null }
			}
			if ($null -eq $regex) { Write-Warning ($script:msg.IgnoreRegexInvalid -f $Pattern) }
			$script:ignoreRegexCache[$Pattern] = $regex
		}
		$regex = $script:ignoreRegexCache[$Pattern]
		if ($null -eq $regex) { return $false }
		foreach ($item in $targets) {
			try { if ($regex.IsMatch($item.Normalize([Text.NormalizationForm]::FormC))) { return $true } }
			catch [System.Text.RegularExpressions.RegexMatchTimeoutException] { Write-Warning ($script:msg.IgnoreRegexTimeout -f $Pattern) ; return $false }
		}
		return $false
	}

	foreach ($item in $targets) {
		switch ($Mode) {
			'Literal' { if ($item -cmatch [RegEx]::Escape($Pattern)) { return $true } }
			'Wildcard' { if ($item -like ('*{0}*' -f $Pattern)) { return $true } }
		}
	}
	return $false
}

#----------------------------------------------------------------------
# ダウンロード対象外番組の読み込み
#----------------------------------------------------------------------
function Read-IgnoreList {
	<#
		.SYNOPSIS
			ダウンロード対象外番組のリストを読み込みます。

		.DESCRIPTION
			ダウンロード対象外番組のリストファイルから、コメント行と空行を除いた
			番組名を読み込み、配列として返します。

		.OUTPUTS
			[String[]] ダウンロード対象外番組名の配列

		.EXAMPLE
			$ignoreTitles = Read-IgnoreList

		.NOTES
			この関数は以下の処理を行います：
			1. 無視ファイルをロック
			2. UTF8エンコーディングで読み込み
			3. コメント行（;で始まる行）と空行を除外
			4. ロックを解除
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreTitles = @()
	try {
		Wait-FileLock $script:ignoreLockFilePath
		# コメントと空行を除いて抽出
		$ignoreTitles = @((Get-Content $script:ignoreFilePath -Encoding UTF8 -ErrorAction Stop).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_ -cmatch '^;.*$') }))
	} catch { throw ($script:msg.LoadFailed -f $script:msg.IgnoreFile) }
	finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	return $ignoreTitles
}

#----------------------------------------------------------------------
# ダウンロード対象外番組のソート(使用したものを上に移動)
#----------------------------------------------------------------------
function Update-IgnoreList {
	<#
		.SYNOPSIS
			ダウンロード対象外番組リストを更新し、使用した番組をリストの先頭に移動します。

		.DESCRIPTION
			指定された番組名をダウンロード対象外リストに追加し、使用した番組を
			リストの先頭に移動します。リストの構造（コメント、対象番組、その他）を
			維持しながら更新します。

		.PARAMETER ignoreTitle
			ダウンロード対象外リストに追加する番組名を指定します。

		.EXAMPLE
			Update-IgnoreList -ignoreTitle "テスト番組"

		.NOTES
			この関数は以下の処理を行います：
			1. 無視ファイルをロック
			2. 既存のリストを読み込み
			3. コメント、対象番組、その他の行を分類
			4. 新しいリストを作成（コメント→対象番組→その他の順）
			5. リストを更新
			6. ロックを解除
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][String]$ignoreTitle)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreLists = @()
	$ignoreComment = @()
	$ignoreTarget = @()
	$ignoreElse = @()
	$ignoreListNew = @()
	if ((Test-Path $script:ignoreFilePath -PathType Leaf) -and $PSCmdlet.ShouldProcess($script:ignoreFilePath, 'Update ignore list')) {
		try {
			Wait-FileLock $script:ignoreLockFilePath
			$ignoreLists = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where( { $_ -notmatch '^\s*$|^(;;.*)$' }))
			$ignoreComment = @(Get-Content $script:ignoreFileSamplePath -Encoding UTF8)
			$ignoreTarget = @($ignoreLists.Where({ $_ -eq $ignoreTitle }) | Sort-Object -Unique)
			$ignoreElse = @($ignoreLists.Where({ $_ -notin $ignoreTitle }))
			if ($ignoreComment) { $ignoreListNew += $ignoreComment }
			if ($ignoreTarget) { $ignoreListNew += $ignoreTarget }
			if ($ignoreElse) { $ignoreListNew += $ignoreElse }
			# 改行コードLFを強制 + NFCで出力
			# 一時ファイルに書き出してから置換する(読み取り側が書き込み途中の不完全な内容を見ないようにする。失敗時は元ファイルに触れない)
			$tempPath = '{0}.{1}.tmp' -f $script:ignoreFilePath, [Guid]::NewGuid().ToString('N')
			try {
				$ignoreContent = (-join $ignoreListNew.ForEach({ '{0}{1}' -f $_, "`n" })).Normalize([Text.NormalizationForm]::FormC)
				[IO.File]::WriteAllText($tempPath, $ignoreContent, [Text.UTF8Encoding]::new($false))
				# 共有フォルダやウイルス対策ソフトによる一時的なアクセス競合に備えて、置換を数回リトライする
				for ($retry = 1 ; $retry -le 5 ; $retry++) {
					try { [IO.File]::Replace($tempPath, $script:ignoreFilePath, [NullString]::Value) ; break }
					catch { if ($retry -ge 5) { throw } ; Start-Sleep -Milliseconds 200 }
				}
				Start-Sleep -Seconds 1
				Write-Debug ($script:msg.IgnoreFileSortCompleted)
			} catch { Write-Warning ($script:msg.IgnoreFileSortFailed) }
			finally {
				try { if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) } } catch { Write-Debug $_.Exception.Message }
				Start-Sleep -Seconds 1
			}
		} catch { Write-Warning ($script:msg.IgnoreFileSortFailed) }
		finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	}
	Remove-Variable -Name ignoreTitle, ignoreLists, ignoreComment, ignoreTarget, ignoreElse, ignoreListNew -ErrorAction SilentlyContinue
}
#----------------------------------------------------------------------
# ダウンロード対象外リストにマッチする番組名(フォルダ名)の一括特定
#----------------------------------------------------------------------
function Find-IgnoreMatchedIndex {
	<#
		.SYNOPSIS
			ダウンロード対象外リストの各行にマッチする番組名の位置を一括で特定します。

		.DESCRIPTION
			Test-IgnoreMatch -Mode Wildcard を「リストの行数 x 番組名の数」回呼び出す処理の高速版です。
			(3,000行 x 1,000フォルダでは数百万回の関数呼び出しとなり、数分かかるため)
			判定結果は Test-IgnoreMatch -Mode Wildcard と同じです。
			- regex:で始まる行 : Test-IgnoreMatch に委ねる
			- *?[ ]を含む行 : -like '*行*' と同じワイルドカード判定(大文字小文字を区別しない)
			- その他の行 : 部分一致(大文字小文字を区別しない)。全番組名を連結した文字列で一次判定する

		.PARAMETER Name
			判定対象の番組名(フォルダ名)の配列を指定します。NFCに正規化して判定します。

		.PARAMETER IgnoreTitle
			ダウンロード対象外リストの行(コメント・空行を除いたもの)の配列を指定します。

		.OUTPUTS
			[PSCustomObject]
			Index     : マッチした番組名の位置(Nameの添字)の昇順配列
			UsedTitle : 1件以上マッチしたリストの行(NFC正規化後)の配列

		.EXAMPLE
			$result = Find-IgnoreMatchedIndex -Name $workDirEntities.Name -IgnoreTitle $ignoreTitles
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][String[]]$Name,
		[Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][String[]]$IgnoreTitle
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$names = @($Name.ForEach({ $_.Normalize([Text.NormalizationForm]::FormC) }))
	$allNames = [String]::Join("`n", $names)
	$matchedIdx = New-Object System.Collections.Generic.HashSet[Int]
	$usedTitles = New-Object System.Collections.Generic.List[String]
	foreach ($titleRaw in $IgnoreTitle) {
		$title = $titleRaw.Normalize([Text.NormalizationForm]::FormC)
		$hit = $false
		if ($title -cmatch '^regex:') {
			for ($i = 0 ; $i -lt $names.Count ; $i++) {
				if (Test-IgnoreMatch -Pattern $title -Target @($names[$i]) -Mode Wildcard) { [void]$matchedIdx.Add($i) ; $hit = $true }
			}
		} elseif ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($title)) {
			$wildcard = [Management.Automation.WildcardPattern]::new(('*{0}*' -f $title), [Management.Automation.WildcardOptions]::IgnoreCase)
			for ($i = 0 ; $i -lt $names.Count ; $i++) {
				if ($names[$i] -and $wildcard.IsMatch($names[$i])) { [void]$matchedIdx.Add($i) ; $hit = $true }
			}
		} elseif ($allNames.IndexOf($title, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
			for ($i = 0 ; $i -lt $names.Count ; $i++) {
				if ($names[$i] -and $names[$i].IndexOf($title, [StringComparison]::OrdinalIgnoreCase) -ge 0) { [void]$matchedIdx.Add($i) ; $hit = $true }
			}
		}
		if ($hit) { $usedTitles.Add($title) }
	}
	return [PSCustomObject]@{
		Index     = [Int[]]@($matchedIdx | Sort-Object)
		UsedTitle = [String[]]$usedTitles.ToArray()
	}
}
#endregion ダウンロード対象外リスト関連
