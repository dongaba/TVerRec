###################################################################################
#
#		共通関数スクリプト(ファイル操作)
#
###################################################################################
<#
	.SYNOPSIS
		ファイルの削除、ZIPの展開、ファイルロックの制御の関数を定義します。

	.NOTES
		このファイルはcommon_functions.ps1から読み込まれます。
		単体で読み込まず、common_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region ファイル操作
#----------------------------------------------------------------------
# 指定したPath配下の指定した条件でファイルを削除
#----------------------------------------------------------------------
function Remove-File {
	<#
		.SYNOPSIS
			指定した条件に基づいて古いファイルを削除します。

		.DESCRIPTION
			この関数は、以下の2つの方法でファイル削除を実行します：

			1. 条件指定による削除:
			- 指定したディレクトリ (`basePath`) 内のファイルを、指定した条件 (`conditions`) に基づいて検索
			- 指定した削除期間 (`delPeriod`) よりも古いファイルを削除

			2. パイプライン入力による削除:
			- パイプラインから直接ファイルオブジェクトを受け取り
			- 指定した削除期間よりも古いファイルを削除

			パフォーマンス最適化:
			- マルチスレッド処理をサポート (`$script:enableMultithread` が `$true` の場合)
			- 並列処理数は `$script:multithreadNum` で制御
			- メモリ効率を考慮した動的なファイルリスト管理
			- パイプライン処理の最適化

			進捗表示:
			- `Write-Information` を使用して処理状況を表示
			- 検索条件、削除対象ファイル、実際の削除操作を表示

		.PARAMETER basePath
			検索対象のディレクトリまたはファイルを指定します。
			パイプライン入力の場合は、FileInfo オブジェクトとして受け取ります。

		.PARAMETER conditions
			削除対象のファイル名パターン（ワイルドカード可）の配列。
			パイプライン入力の場合は不要です。

		.PARAMETER delPeriod
			削除対象となるファイルの最終更新日時の閾値（日数単位）。
			この日数よりも古いファイルが削除されます。

		.INPUTS
			System.IO.FileInfo
			- パイプラインからファイルオブジェクトを受け取ることができます。
			- ファイルの LastWriteTime プロパティを使用して経過日数を判定します。

		.OUTPUTS
			なし（[Void]）

		.EXAMPLE
			PS> Remove-File -basePath "C:\Logs" -conditions @("*.log", "*.tmp") -delPeriod 30

			`C:\Logs` 内の `*.log` および `*.tmp` ファイルのうち、
			最終更新日時が 30 日よりも古いファイルを削除します。

		.EXAMPLE
			PS> Get-ChildItem -Path "C:\Logs" -Recurse -File | Remove-File -delPeriod 7

			パイプラインを使用して、`C:\Logs` 内のすべてのファイルから
			7日以上経過したものを削除します。

		.NOTES
			- マルチスレッド処理を有効にする場合は、`$script:enableMultithread` を `$true` に設定
			- 並列処理数は `$script:multithreadNum` で調整可能
			- 処理状況は `Write-Information` で確認可能 (-InformationAction Continue を指定)
			- エラー発生時は Warning として記録
			- ShouldProcess をサポートしており、-WhatIf で削除前の確認が可能
	#>
	[CmdletBinding(SupportsShouldProcess = $true, SupportsPaging = $true)]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[System.IO.FileInfo]$basePath,

		[Parameter(Mandatory = $false)]
		[String[]]$conditions,

		[Parameter(Mandatory = $true)]
		[int32]$delPeriod
	)
	begin {
		Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
		$limitDateTime = (Get-Date).AddDays(-1 * $delPeriod)
		$targetFiles = [System.Collections.Generic.List[string]]::new()
	}

	process {
		if ($conditions) {
			# 条件指定がある場合の処理
			if ($script:enableMultithread) {
				Write-Debug ('Multithread Processing Enabled')
				try {
					# 並列処理のrunspaceでは$script:が参照できないため、$using:で渡せるようローカル変数に退避
					$parallelMsg = $script:msg
					# 並列処理で見つかったファイルを一時的に格納
					$parallelResults = $conditions | ForEach-Object -ThrottleLimit $script:multithreadNum -Parallel {
						Write-Debug ($using:parallelMsg.DeleteCondition -f $_)
						Get-ChildItem -LiteralPath $using:basePath -Recurse -File -Filter $_ -ErrorAction SilentlyContinue |
							Where-Object { $_.LastWriteTime -lt $using:limitDateTime } |
							ForEach-Object { Write-Debug ($using:parallelMsg.DeleteTarget -f $_.FullName) ; $_.FullName }
						}
						# 並列処理の結果をまとめてリストに追加
						if ($parallelResults) { $targetFiles.AddRange([String[]]@($parallelResults)) }	# * Object[]や単一のStringのままではList[String].AddRangeに渡せず例外になる
					} catch { Write-Warning ($script:msg.FileCannotBeDeleted) }
				} else {
					try {
						foreach ($condition in $conditions) {
							Write-Debug ($script:msg.DeleteCondition -f $condition)
							$files = Get-ChildItem -LiteralPath $basePath -Recurse -File -Filter $condition -ErrorAction SilentlyContinue |
								Where-Object { $_.LastWriteTime -lt $limitDateTime } |
								ForEach-Object { Write-Debug ($script:msg.DeleteTarget -f $_.FullName) ; $_.FullName }
						if ($files) { $targetFiles.AddRange([String[]]@($files)) }	# * Object[]や単一のStringのままではList[String].AddRangeに渡せず例外になる
					}
				} catch { Write-Warning ($script:msg.FileCannotBeDeleted) }
			}
		} else {
			# パイプライン入力の場合の処理
			if ($basePath.LastWriteTime -lt $limitDateTime) { Write-Debug ($script:msg.DeleteTarget -f $basePath.FullName) ; $targetFiles.Add($basePath.FullName) }
		}
	}

	end {
		# ファイル削除の実行
		$targetFiles | ForEach-Object {
			try {
				if ($PSCmdlet.ShouldProcess($_, 'Remove file')) { Write-Information ($script:msg.DeleteFile -f $_) ; Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue }
			} catch { Write-Warning $script:msg.FileCannotBeDeleted }
		}

		Remove-Variable -Name basePath, conditions, delPeriod, limitDateTime, targetFiles, parallelResults -ErrorAction SilentlyContinue
	}
}

#----------------------------------------------------------------------
# Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	<#
		.SYNOPSIS
			ZIPファイルを指定したディレクトリに展開する。

		.DESCRIPTION
			指定したZIPファイル (`path`) を、指定した展開先 (`destination`) に解凍する。
			すでに展開先に同名のファイルが存在する場合は、上書きする。

		.PARAMETER path
			展開するZIPファイルのパス。

		.PARAMETER destination
			ZIPファイルを展開するディレクトリのパス。

		.INPUTS
			System.String
			- ZIPファイルのパスと展開先ディレクトリ。

		.OUTPUTS
			なし（[Void]）

		.EXAMPLE
			PS> Expand-Zip -path "C:\Backup\data.zip" -destination "C:\ExtractedData"

			`C:\Backup\data.zip` を `C:\ExtractedData` に展開する。

		.EXAMPLE
			PS> Expand-Zip -path "/home/user/archive.zip" -destination "/home/user/unpacked"

			`/home/user/archive.zip` を `/home/user/unpacked` に展開する（Linux環境）。

		.NOTES
			- ZIPファイルが存在しない場合、エラーをスローする。
			- すでに展開先にファイルが存在する場合は上書きされる。
			- .NET の `[System.IO.Compression.ZipFile]::ExtractToDirectory` を利用して展開を実施。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$path,
		[Parameter(Mandatory = $true)][String]$destination
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	if (Test-Path -Path $path) {
		Write-Verbose ('Extracting {0} into {1}' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('Extracted {0}' -f $path)
	} else { throw ($script:msg.FileNotFound -f $path) }
	Remove-Variable -Name path, destination -ErrorAction SilentlyContinue
}
#endregion ファイル操作

#region ファイルロック
#----------------------------------------------------------------------
# ファイルのロック
#----------------------------------------------------------------------
function Lock-File {
	<#
		.SYNOPSIS
			指定したファイルをロックする。

		.DESCRIPTION
			指定したファイル (`path`) を開き、読み書きロックを設定することで、他のプロセスによるアクセスを防ぐ。

		.PARAMETER path
			ロックするファイルのパス。

		.INPUTS
			System.String
			- ロックするファイルのパス。

		.OUTPUTS
			PSCustomObject
			- `path` : 指定されたファイルパス
			- `result` : ロックの成否（`$true` または `$false`）

		.EXAMPLE
			PS> Lock-File -path "C:\Temp\test.txt"

			`C:\Temp\test.txt` をロックする。

		.EXAMPLE
			PS> $lockResult = Lock-File -path "/home/user/data.log"
			PS> $lockResult.result

			`/home/user/data.log` をロックし、結果 (`$true` または `$false`) を取得。

		.NOTES
			- `[System.IO.FileInfo]` を使用してファイル情報を取得し、`Open` メソッドでロックを確立。
			- `FileShare.None` を指定することで、他のプロセスがファイルにアクセスできないようにする。
			- ロックに失敗すると `$false` を返す。
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param ([parameter(Mandatory = $true)][String]$path)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	try {
		# ファイルを開こうとしファイルロックを検出
		$script:fileInfo[$path] = [System.IO.FileInfo]::new($path)
		$script:fileStream[$path] = $script:fileInfo[$path].Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		$result = $true
		$errorMessage = ''
	} catch {
		# 失敗理由(他プロセス/他ホストによる保持、権限不足など)を呼び出し元で参照できるよう保持
		$result = $false
		$errorMessage = $_.Exception.Message
		Write-Debug ('{0} - Failed to lock {1}: {2}' -f $MyInvocation.MyCommand.Name, $path, $errorMessage)
	}
	# 結果の返却
	return [PSCustomObject]@{
		path         = $path
		result       = $result
		errorMessage = $errorMessage
	}
}

#----------------------------------------------------------------------
# ファイルロックの取得待ち(タイムアウト付き)
#----------------------------------------------------------------------
function Wait-FileLock {
	<#
		.SYNOPSIS
			ファイルのロックが取得できるまで待機する。上限時間を超えた場合は例外をスローする。

		.PARAMETER path
			ロックするファイルのパス。

		.PARAMETER timeoutSeconds
			待機の上限秒数(既定: 60)。

		.NOTES
			- `Lock-File` を100〜500ミリ秒のランダムな間隔で再試行する(他プロセスが短い間隔でロックを取り直す場合でも、解放の隙間に入りやすくするため)。
			- 上限を超えるとロック対象のパスと直近の失敗理由を警告に出し、例外をスローする。
			- 呼び出し元は try/catch/finally で囲み、finally で `Unlock-File` を呼ぶこと。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[parameter(Mandatory = $true)][String]$path,
		[Int32]$timeoutSeconds = 60
	)
	$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
	$lastNoticeSeconds = -1
	while ($true) {
		$lockResult = Lock-File $path
		if ($lockResult.result) { return }
		if ($stopwatch.Elapsed.TotalSeconds -ge $timeoutSeconds) {
			Write-Warning ($script:msg.LockWaitTimeout -f $timeoutSeconds, $path, $lockResult.errorMessage)
			throw ($script:msg.LockWaitTimeout -f $timeoutSeconds, $path, $lockResult.errorMessage)
		}
		# 待機メッセージは再試行間隔が短くなっても約1秒に1回だけ表示する
		if (($stopwatch.Elapsed.TotalSeconds - $lastNoticeSeconds) -ge 1) {
			Write-Information ($script:msg.WaitingLock)
			$lastNoticeSeconds = $stopwatch.Elapsed.TotalSeconds
		}
		Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 501)
	}
}

#----------------------------------------------------------------------
# ファイルのアンロック
#----------------------------------------------------------------------
function Unlock-File {
	<#
		.SYNOPSIS
			指定したファイルのロックを解除する。

		.DESCRIPTION
			`Lock-File` 関数でロックされたファイルを解放し、他のプロセスがアクセスできるようにする。

		.PARAMETER path
			ロックを解除するファイルのパス。

		.INPUTS
			System.String
			- ロックを解除するファイルのパス。

		.OUTPUTS
			PSCustomObject
			- `path` : 指定されたファイルパス
			- `result` : ロック解除の成否（`$true` または `$false`）

		.EXAMPLE
			PS> Unlock-File -path "C:\Temp\test.txt"

			`C:\Temp\test.txt` のロックを解除する。

		.EXAMPLE
			PS> $unlockResult = Unlock-File -path "/home/user/data.log"
			PS> $unlockResult.result

			`/home/user/data.log` のロックを解除し、結果 (`$true` または `$false`) を取得。

		.NOTES
			- `Lock-File` 関数でロックしたファイルを開放するために使用する。
			- `$script:fileStream` からエントリを削除し、リソースを解放する。
			- すでにロックが解除されている場合は何もしない。
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param ([parameter(Mandatory = $true)][String]$path)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	if (Test-Path $path) {
		if ($script:fileStream[$path]) {
			# ロックされていなければストリームを閉じる
			$script:fileStream[$path].Close()
			$script:fileStream[$path].Dispose()
			$script:fileStream[$path] = $null
			$script:fileStream.Remove($path)
		}
		$result = $true
	} else { $result = $false }
	# 結果の返却
	return [PSCustomObject]@{
		path   = $path
		result = $result
	}
}
#endregion ファイルロック
