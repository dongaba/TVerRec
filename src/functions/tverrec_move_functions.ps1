###################################################################################
#
#		TVerRec固有関数スクリプト(番組ファイルの移動)
#
###################################################################################
<#
	.SYNOPSIS
		番組ファイルの移動の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region 番組ファイル移動関連
#----------------------------------------------------------------------
# ディレクトリのパスを末尾のフォルダ名ごとにグループ化
#----------------------------------------------------------------------
function Group-DirectoryPathByLeaf {
	<#
		.SYNOPSIS
			ディレクトリのパスを、末尾のフォルダ名ごとにまとめます。

		.DESCRIPTION
			番組の移動元と移動先を「末尾のフォルダ名」で突き合わせるために、パスをフォルダ名ごとに集約します。
			同じフォルダ名のディレクトリが複数ある場合は、すべてのパスを保持します。
			(後から見つかったもので上書きしたり、先に見つかったものだけを採用したりしません)
			同じパスが重複して渡された場合は1つにまとめます。パスの大文字小文字は区別しません。

		.PARAMETER Path
			ディレクトリのパスの配列を指定します。

		.OUTPUTS
			[Hashtable]
			キーがフォルダ名、値がそのフォルダ名のパスの配列。キーの大文字小文字は区別しません。
	#>
	[OutputType([Hashtable])]
	Param ([Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowNull()][AllowEmptyString()][String[]]$Path)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$groups = @{}
	foreach ($dirPath in $Path) {
		if ([String]::IsNullOrWhiteSpace($dirPath)) { continue }
		$trimmedPath = $dirPath.TrimEnd('\', '/')
		if (!$trimmedPath) { continue }
		$leaf = Split-Path -Leaf $trimmedPath
		if (!$leaf) { continue }
		if (!$groups.ContainsKey($leaf)) { $groups[$leaf] = [Collections.Generic.List[String]]::new() }
		if ($groups[$leaf] -inotcontains $trimmedPath) { $groups[$leaf].Add($trimmedPath) }
	}
	return $groups
}

#----------------------------------------------------------------------
# 番組ファイルの移動(移動先に同名ファイルがある場合の動作を指定可能)
#----------------------------------------------------------------------
function Move-VideoFileToDestination {
	<#
		.SYNOPSIS
			ファイルを移動先ディレクトリに移動します。移動先に同名ファイルがある場合の動作を指定できます。

		.DESCRIPTION
			ファイルを移動先ディレクトリに移動します。
			移動先に同名のファイルが既に存在する場合は、ConflictActionに従って動作します。
			- Overwrite: 上書きします(既定。従来の動作)
			            ただし、移動先のファイルに字幕があり、移動元のファイルに字幕がない場合は、字幕が失われるため上書きしません(Result=SubtitleKept)
			- Skip     : 移動せず、移動元にファイルを残します
			- Rename   : 「ファイル名 (1).mp4」のように、重複しない名前を付けて移動します
			上記以外の値はOverwriteとして扱います。

		.PARAMETER Path
			移動するファイルのパスを指定します。

		.PARAMETER DestinationDir
			移動先ディレクトリのパスを指定します。

		.PARAMETER ConflictAction
			移動先に同名ファイルがある場合の動作(Overwrite/Skip/Rename)を指定します。

		.OUTPUTS
			[PSCustomObject]
			Result(Moved/Overwritten/Skipped/Renamed/SubtitleKept)とDestination(移動後のパス。SkippedとSubtitleKeptの場合は$null)を持つオブジェクト。

		.EXAMPLE
			Move-VideoFileToDestination -Path '/download/番組/第1話.mp4' -DestinationDir '/save/番組' -ConflictAction 'Skip'
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $true)][String]$Path,
		[Parameter(Mandatory = $true)][String]$DestinationDir,
		[Parameter(Mandatory = $false)][String]$ConflictAction = 'Overwrite'
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$fileName = Split-Path -Leaf $Path
	$destPath = Join-Path $DestinationDir $fileName
	$result = 'Moved'
	if (Test-Path -LiteralPath $destPath) {
		if ($ConflictAction -eq 'Skip') { return [PSCustomObject]@{ Result = 'Skipped' ; Destination = $null } }
		elseif ($ConflictAction -eq 'Rename') {
			$baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
			$extension = [System.IO.Path]::GetExtension($fileName)
			$num = 1
			do {
				$destPath = Join-Path $DestinationDir ('{0} ({1}){2}' -f $baseName, $num, $extension)
				$num++
			} while (Test-Path -LiteralPath $destPath)
			$result = 'Renamed'
		} else {
			# 上書きの場合、移動先に字幕があり、移動元に字幕がなければ、字幕が失われるため上書きしない
			if (((Test-VideoFileHasSubtitle -VideoPath $destPath) -eq $true) -and ((Test-VideoFileHasSubtitle -VideoPath $Path) -eq $false)) {
				return [PSCustomObject]@{ Result = 'SubtitleKept' ; Destination = $null }
			}
			$result = 'Overwritten'
		}
	}
	Move-Item -LiteralPath $Path -Destination $destPath -Force -ErrorAction Stop
	return [PSCustomObject]@{ Result = $result ; Destination = $destPath }
}
#endregion 番組ファイル移動関連
