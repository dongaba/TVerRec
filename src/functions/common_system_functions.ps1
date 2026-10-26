###################################################################################
#
#		共通関数スクリプト(メモリ・ディスク・その他)
#
###################################################################################
<#
	.SYNOPSIS
		ガベージコレクション、ディスク容量の確認、Base64画像の展開、GUI更新間隔の取得の関数を定義します。

	.NOTES
		このファイルはcommon_functions.ps1から読み込まれます。
		単体で読み込まず、common_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region ガーベッジコレクション
#----------------------------------------------------------------------
# ガーベッジコレクション
#----------------------------------------------------------------------
function Invoke-GarbageCollection() {
	<#
		.SYNOPSIS
			強制的にガベージコレクション (GC) を実行し、不要なメモリを解放します。

		.DESCRIPTION
			この関数は、.NET のガベージコレクタ ([System.GC]) を手動で実行し、
			メモリ管理を最適化するために 2 回の GC サイクルを実施します。
			1 回目の GC 実行後、保留中のファイナライザを処理し、
			再度 GC を実行することで、不要なメモリを最大限解放します。

		.INPUTS
			なし

		.OUTPUTS
			なし

		.EXAMPLE
			PS> Invoke-GarbageCollection
			強制的にガベージコレクションを実行し、不要なメモリを解放します。

		.LINK
			https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/

		.NOTES
			- この関数は通常の PowerShell スクリプト実行時には不要です。
			- 高メモリ使用状態が続くアプリケーションなど、明示的に GC を実行する必要がある場合に使用してください。
			- [System.GC]::Collect() は、.NET のメモリ管理によって自動的に実行されるため、過度に使用しないよう注意してください。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Verbose -Message 'Starting garbage collection ...' ; [System.GC]::Collect()
	Write-Verbose -Message 'Waiting for pending finalizers ...' ; [System.GC]::WaitForPendingFinalizers()
	Write-Verbose -Message 'Performing a final pass of garbage collection ...' ; [System.GC]::Collect()
	Write-Verbose -Message 'Garbage collection completed.'
}
#endregion ガーベッジコレクション

#region ディスク監視
#----------------------------------------------------------------------
# ディレクトリの空き容量確認(MB)
#----------------------------------------------------------------------
function Get-RemainingCapacity {
	<#
		.SYNOPSIS
			指定したディレクトリの空き容量を取得する。

		.DESCRIPTION
			指定したディレクトリのあるドライブやファイルシステムの空き容量をMB単位で返す。

		.PARAMETER targetDir
			空き容量を取得する対象ディレクトリ。

		.INPUTS
			System.String
			- チェックするディレクトリのパス。

		.OUTPUTS
			System.Int64
			- 指定したディレクトリのあるドライブの空き容量（MB単位）。

		.EXAMPLE
			PS> Get-RemainingCapacity -targetDir "C:\Users"

			`C:\Users` のあるドライブの空き容量を取得。

		.EXAMPLE
			PS> Get-RemainingCapacity -targetDir "/home/user"

			`/home/user` のあるファイルシステムの空き容量を取得。

		.NOTES
			- Windows では `Get-CimInstance` を使用。
			- Linux/macOS では `df` コマンドを実行。
			- UNC パス (`\\server\share`) の場合は `dir` コマンドを利用。
	#>
	[CmdletBinding()]
	[OutputType([int64])]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$targetDir
	)
	process {
		Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $targetDir)
		if ($IsWindows) {
			try {
				switch -Regex ($targetDir) {
					'^[a-zA-Z]:' {
						# ローカルディスクまたはマウントされたネットワークドライブ (例: "C:\", "Z:\")
						$targetDrive = $targetDir.Substring(0, 2)  # "C:" or "Z:"
						$freeSpace = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$targetDrive'").FreeSpace
						break
					}
					'^\\\\' {
						# UNC パス (例: "\\server\share")
						$targetRoot = ($targetDir -replace '(^\\\\[^\\]+\\[^\\]+).*', '$1')  # \\server\share
						$freeSpace = (& cmd /c dir $targetRoot) | Select-Object -Last 1 | ForEach-Object { $_ -replace ',' -split '\s+' } | Select-Object -Index 3
						break
					}
					default { Write-Information ($script:msg.CapacityUnknown -f $targetDir) ; $freeSpace = 9999999999 }
				}
			} catch { Write-Information ($script:msg.CapacityUnknown -f $targetDir) ; $freeSpace = 9999999999 }
		} else {
			try {
				$dfCmd = "df -P `"$targetDir`""
				$freeSpace = [int64](((& sh -c $dfCmd) | Select-Object -Skip 1) -split '\s+')[3] * 1024
			} catch { Write-Information ($script:msg.CapacityUnknown -f $targetDir) ; $freeSpace = 9999999999 }
		}
		return [int64]($freeSpace / 1MB)
	}
}
#endregion ディスク監視

#----------------------------------------------------------------------
# Base64画像の展開
#----------------------------------------------------------------------
function ConvertFrom-Base64 {
	<#
		.SYNOPSIS
			Base64エンコードされた文字列を画像に変換します。

		.DESCRIPTION
			この関数は、Base64形式でエンコードされた文字列を受け取り、その文字列を画像オブジェクトに変換します。
			主に画像データをBase64でエンコードして保存し、後でそのデータを画像として表示したい場合に使用されます。

		.PARAMETER base64
			Base64形式でエンコードされた文字列です。この文字列は画像のデータを表しており、通常は長い文字列になります。

		.OUTPUTS
			この関数は、変換された画像オブジェクト（`System.Windows.Media.Imaging.BitmapImage`）を返します。

		.EXAMPLE
			$base64String = "iVBORw0KGgoAAAANSUhEUgAAA..."
			$image = ConvertFrom-Base64 -base64 $base64String
			$image  # 画像オブジェクトが返されます。

			Base64エンコードされた文字列を画像オブジェクトに変換して表示する例です。
	#>
	Param (
		[Parameter(Mandatory = $true)][String]$base64
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		$img = [System.Windows.Media.Imaging.BitmapImage]::new()
		$img.BeginInit()
		$img.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64)
		$img.EndInit()
		$img.Freeze()
		return $img
	} catch { Write-Error "Base64文字列から画像を変換する際にエラーが発生しました: $_" ; return $null }
	finally { Remove-Variable -Name base64, img -ErrorAction SilentlyContinue }
}

#region GUI更新間隔
#----------------------------------------------------------------------
# GUIの更新間隔(ミリ秒)の取得
#----------------------------------------------------------------------
function Get-GuiRefreshInterval {
	<#
		.SYNOPSIS
			GUIのメイン画面がイベントを処理する間隔(ミリ秒)を取得します。

		.DESCRIPTION
			設定`$script:guiRefreshIntervalMs`の値を返します。
			設定が未定義、数値以外、または1～1000の範囲外の場合は既定値の10を返します。

		.OUTPUTS
			[Int]
			GUIの更新間隔(ミリ秒)。

		.EXAMPLE
			Start-Sleep -Milliseconds (Get-GuiRefreshInterval)
	#>
	[CmdletBinding()]
	[OutputType([Int])]
	Param ()
	$defaultInterval = 10
	if (!(Test-Path Variable:Script:guiRefreshIntervalMs)) { return $defaultInterval }
	$interval = 0
	if (![Int]::TryParse([String]$script:guiRefreshIntervalMs, [Ref]$interval)) { return $defaultInterval }
	if (($interval -lt 1) -or ($interval -gt 1000)) { return $defaultInterval }
	return $interval
}
#endregion GUI更新間隔
