###################################################################################
#
#		共通関数スクリプト(文字列処理)
#
###################################################################################
<#
	.SYNOPSIS
		ファイル名の無効文字の除去、全角/半角の変換、特殊文字・コメントの処理の関数を定義します。

	.NOTES
		このファイルはcommon_functions.ps1から読み込まれます。
		単体で読み込まず、common_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region 文字列操作
#----------------------------------------------------------------------
# ファイル名・ディレクトリ名に禁止文字の削除
#----------------------------------------------------------------------
function Get-FileNameWoInvalidChar {
	<#
		.SYNOPSIS
			ファイル名に使用できない無効な文字を削除し、安全なファイル名を生成します。

		.DESCRIPTION
			この関数は、指定された文字列からファイル名として使用できない無効な文字を削除し、
			OS に依存せず適切なファイル名を生成します。
			Windows の `GetInvalidFileNameChars()` に加え、Linux/Mac で問題となる `*?<>|` などの記号や
			制御文字も削除します。

		.PARAMETER name
			ファイル名として使用したい文字列。デフォルトは空文字列 (`''`)。

		.INPUTS
			System.String
			- 無効な文字を除去する元のファイル名。

		.OUTPUTS
			System.String
			- 無効な文字を削除した後の安全なファイル名。

		.EXAMPLE
			PS> Get-FileNameWoInvalidChar -name "invalid:file*name?.txt"
			"invalid-filename-.txt"

			Windows のファイル名に使用できない `:` `*` `?` を削除または置換。

		.EXAMPLE
			PS> Get-FileNameWoInvalidChar -name "test/|<>file"
			"test-file"

			Linux/Mac で問題となる `/` `|` `<>` も削除。

		.EXAMPLE
			PS> Get-FileNameWoInvalidChar -name "file--name--test"
			"file-name-test"

			連続した `-` を一つに統一。

		.LINK
			https://learn.microsoft.com/en-us/dotnet/api/system.io.path.getinvalidfilenamechars

		.NOTES
			- `GetInvalidFileNameChars()` を使用して OS に応じた無効文字を取得。
			- `-replace` を使用して、追加の無効文字や制御文字も削除。
			- 連続する `-` を 1 つに統一し、より読みやすいファイル名を生成。
	#>
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$name = '')
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $name)
	# 使用する正規表現パターンを定義
	$invalidCharsPattern = '[{0}]' -f [RegEx]::Escape( [IO.Path]::GetInvalidFileNameChars() -Join '')
	$additionalReplaces = '[*\?<>|]'	# Linux/MacではGetInvalidFileNameChars()が不完全なため、ダメ押しで置換
	$nonPrintableChars = '[\x00-\x1F\x7F]'	# ASCII制御文字()
	# 追加の無効文字を先に「-」へ置換する(WindowsではGetInvalidFileNameChars()に*?<>|が含まれ、先に削除すると置換されずOSで結果が変わるため)
	# そのあと無効な文字を削除
	$name = $name -replace $additionalReplaces, '-' `
		-replace $invalidCharsPattern, '' `
		-replace $nonPrintableChars, '' `
		-replace '-+', '-'
	return $name
}

#----------------------------------------------------------------------
# 英数のみ全角→半角(カタカナは全角)
#----------------------------------------------------------------------
function Get-NarrowChar {
	<#
		.SYNOPSIS
			全角文字を半角に、半角カタカナを全角カタカナに変換します。

		.DESCRIPTION
			この関数は、以下の変換を行います:
			- 全角英数字を半角英数字に変換
			- 全角記号を半角記号に変換
			- 半角カタカナを全角カタカナに変換
			これにより、異なるフォーマットのテキストデータを統一し、検索や比較が容易になります。

		.PARAMETER text
			変換対象の文字列。デフォルトは空文字列 (`''`)。

		.INPUTS
			System.String
			- 変換前の文字列。

		.OUTPUTS
			System.String
			- 変換後の文字列。

		.EXAMPLE
			PS> Get-NarrowChar -text "Ｔｅｓｔ１２３"
			"Test123"

			全角英数字を半角に変換。

		.EXAMPLE
			PS> Get-NarrowChar -text "ｶﾀｶﾅ ﾃｽﾄ"
			"カタカナ テスト"

			半角カタカナを全角カタカナに変換。

		.EXAMPLE
			PS> Get-NarrowChar -text "＠＃＄％＾＆＊"
			"@#$%^&*"

			全角記号を半角記号に変換。

		.NOTES
			- 変換には `-replace` を使用せず `.Replace()` を用いて高速化。
			- `GetEnumerator()` を用いたループで各文字を効率的に変換。
	#>
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text = '')
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $text)
	$replaceChars = @{
		'０１２３４５６７８９'                                           = '0123456789'
		'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ' = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
		'＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼"；：．，'                          = '@#$%^&*-+_/[]{}()<> \\";:.,'
	}
	foreach ($entry in $replaceChars.GetEnumerator()) {
		for ($i = 0 ; $i -lt $entry.Name.Length ; $i++) {
			$text = $text.Replace($entry.Name[$i], $entry.Value[$i])
		}
	}
	$replacements = @{
		'ｱ'  = 'ア'
		'ｲ'  = 'イ'
		'ｳ'  = 'ウ'
		'ｴ'  = 'エ'
		'ｵ'  = 'オ'
		'ｶ'  = 'カ'
		'ｷ'  = 'キ'
		'ｸ'  = 'ク'
		'ｹ'  = 'ケ'
		'ｺ'  = 'コ'
		'ｻ'  = 'サ'
		'ｼ'  = 'シ'
		'ｽ'  = 'ス'
		'ｾ'  = 'セ'
		'ｿ'  = 'ソ'
		'ﾀ'  = 'タ'
		'ﾁ'  = 'チ'
		'ﾂ'  = 'ツ'
		'ﾃ'  = 'テ'
		'ﾄ'  = 'ト'
		'ﾅ'  = 'ナ'
		'ﾆ'  = 'ニ'
		'ﾇ'  = 'ヌ'
		'ﾈ'  = 'ネ'
		'ﾉ'  = 'ノ'
		'ﾊ'  = 'ハ'
		'ﾋ'  = 'ヒ'
		'ﾌ'  = 'フ'
		'ﾍ'  = 'ヘ'
		'ﾎ'  = 'ホ'
		'ﾏ'  = 'マ'
		'ﾐ'  = 'ミ'
		'ﾑ'  = 'ム'
		'ﾒ'  = 'メ'
		'ﾓ'  = 'モ'
		'ﾔ'  = 'ヤ'
		'ﾕ'  = 'ユ'
		'ﾖ'  = 'ヨ'
		'ﾗ'  = 'ラ'
		'ﾘ'  = 'リ'
		'ﾙ'  = 'ル'
		'ﾚ'  = 'レ'
		'ﾛ'  = 'ロ'
		'ﾜ'  = 'ワ'
		'ｦ'  = 'ヲ'
		'ﾝ'  = 'ン'
		'ｧ'  = 'ァ'
		'ｨ'  = 'ィ'
		'ｩ'  = 'ゥ'
		'ｪ'  = 'ェ'
		'ｫ'  = 'ォ'
		'ｬ'  = 'ャ'
		'ｭ'  = 'ュ'
		'ｮ'  = 'ョ'
		'ｯ'  = 'ッ'
		'ｰ'  = 'ー'
		'ｳﾞ' = 'ヴ'
		'ｶﾞ' = 'ガ'
		'ｷﾞ' = 'ギ'
		'ｸﾞ' = 'グ'
		'ｹﾞ' = 'ゲ'
		'ｺﾞ' = 'ゴ'
		'ｻﾞ' = 'ザ'
		'ｼﾞ' = 'ジ'
		'ｽﾞ' = 'ズ'
		'ｾﾞ' = 'ゼ'
		'ｿﾞ' = 'ゾ'
		'ﾀﾞ' = 'ダ'
		'ﾁﾞ' = 'ヂ'
		'ﾂﾞ' = 'ヅ'
		'ﾃﾞ' = 'デ'
		'ﾄﾞ' = 'ド'
		'ﾊﾞ' = 'バ'
		'ﾋﾞ' = 'ビ'
		'ﾌﾞ' = 'ブ'
		'ﾍﾞ' = 'ベ'
		'ﾎﾞ' = 'ボ'
		'ﾊﾟ' = 'パ'
		'ﾋﾟ' = 'ピ'
		'ﾌﾟ' = 'プ'
		'ﾍﾟ' = 'ペ'
		'ﾎﾟ' = 'ポ'
	}
	foreach ($replacement in $replacements.GetEnumerator()) {
		$text = $text.Replace($replacement.Name, $replacement.Value)
	}
	return $text
}

#----------------------------------------------------------------------
# いくつかの特殊文字を置換
#----------------------------------------------------------------------
function Remove-SpecialCharacter {
	<#
		.SYNOPSIS
			特殊文字を適切な文字に置換または削除する。

		.DESCRIPTION
			この関数は、以下の処理を行います:
			- `&amp;` を `&` に変換
			- 特定の特殊文字を全角に変換 (例: `*` → `＊`)
			- ダブルクォート (`"`) を削除
			- U+2018, U+2019 のシングルクォートを標準の `'` に変換

		.PARAMETER text
			変換対象の文字列。

		.INPUTS
			System.String
			- 変換前の文字列。

		.OUTPUTS
			System.String
			- 変換後の文字列。

		.EXAMPLE
			PS> Remove-SpecialCharacter -text "Test*File|Name:2024"
			"Test＊File｜Name：2024"

			アスタリスク `*`、パイプ `|`、コロン `:` を全角に変換。

		.EXAMPLE
			PS> Remove-SpecialCharacter -text "Hello"World""
			"HelloWorld"

			全角ダブルクォートを削除。

		.EXAMPLE
			PS> Remove-SpecialCharacter -text "Can't"
			"Can't"

			U+2019 のシングルクォートを標準の `'` に変換。

		.NOTES
			- 一部の特殊記号は削除されず全角に置き換え。
			- ダブルクォート (`"`) は削除。
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '文字列を置換して返すだけで、システムの状態は変更しない')]
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $text)
	$text = $text.Replace('&amp;', '&')
	# * 下記一部がUnicode指定なので、VScodeなどのIDEで勝手に変換されないようにするため
	$replacements = @{
		'*'        = '＊' # 全角
		'|'        = '｜' # 全角
		':'        = '：' # 全角
		';'        = '；' # 全角
		"`u{2018}" = "'" # * U+2018をU+0027に変換
		"`u{2019}" = "'" # * U+2019をU+0027に変換
		'"'        = '' # 削除
		"`u{201C}" = ''  # * 全角でもダブルクォートとして認識されるようなので削除
		"`u{201D}" = ''  # * 全角でもダブルクォートとして認識されるようなので削除
		'?'        = '？' # 全角
		'!'        = '！' # 全角
		'/'        = '／' # 全角
		'\'        = '＼' # 全角
		'<'        = '＜' # 全角
		'>'        = '＞' # 全角
	}
	foreach ($replacement in $replacements.GetEnumerator()) { $text = $text.Replace($replacement.Name, $replacement.Value) }
	return $text
}

#----------------------------------------------------------------------
# タブとスペースを詰めて半角スペース1文字に
#----------------------------------------------------------------------
function Remove-TabSpace {
	<#
		.SYNOPSIS
			タブや連続したスペースを単一スペースに置換する。

		.DESCRIPTION
			この関数は、以下の処理を行います:
			- タブ (`\t`) をスペース (` `) に変換。
			- 連続したスペース (`\s+`) を単一のスペース (` `) に置換。

		.PARAMETER text
			変換対象の文字列。

		.INPUTS
			System.String
			- 変換前の文字列。

		.OUTPUTS
			System.String
			- 変換後の文字列。

		.EXAMPLE
			PS> Remove-TabSpace -text "Hello`tWorld"
			"Hello World"

			タブがスペースに変換される。

		.EXAMPLE
			PS> Remove-TabSpace -text "This   is   a  test"
			"This is a test"

			連続したスペースが単一スペースに変換される。

		.NOTES
			- タブ (`\t`) はすべてスペースに変換される。
			- 複数のスペースは単一のスペースにまとめられる。
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '文字列を置換して返すだけで、システムの状態は変更しない')]
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $text)
	return $text.Replace("`t", ' ') -replace '\s+', ' '
}

#----------------------------------------------------------------------
# 設定ファイルの行末コメントを削除
#----------------------------------------------------------------------
function Get-ContentWoComment {
	<#
		.SYNOPSIS
			文字列からコメントや不要な空白を削除する。

		.DESCRIPTION
			この関数は、以下の処理を行います:
			- タブ (`\t`) で区切られた最初の要素を取得
			- スペース (` `) で区切られた最初の要素を取得
			- `#` 記号を含む場合、最初の `#` 以降の部分を削除

		.PARAMETER text
			変換対象の文字列。

		.INPUTS
			System.String
			- 変換前の文字列。

		.OUTPUTS
			System.String
			- コメントや不要な部分を削除した文字列。

		.EXAMPLE
			PS> Get-ContentWoComment -text "command # this is a comment"
			"command"

			`#` 以降のコメントを削除。

		.EXAMPLE
			PS> Get-ContentWoComment -text "command    argument    # comment"
			"command"

			スペースで区切られた最初の要素のみを取得。

		.EXAMPLE
			PS> Get-ContentWoComment -text "command`targument`tmore # comment"
			"command"

			タブで区切られた最初の要素のみを取得。

		.NOTES
			- `#` より前の文字列のみを取得する。
			- スペースやタブで区切られた最初の要素のみを保持する。
	#>
	[OutputType([String])]
	Param ([String]$text)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	return $text.Split("`t")[0].Split(' ')[0].Split('#')[0]
}
#endregion 文字列操作
