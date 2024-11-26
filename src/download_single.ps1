###################################################################################
#
#		個別ダウンロード処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path .// }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません') }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if (!$?) { Throw ('❌️ TVerRecの初期化処理に失敗しました') }
} catch { Throw ('❌️ 関数の読み込みに失敗しました') }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Invoke-RequiredFileCheck
Get-Token
$keyword = '個別指定'

#GUI起動を判定
if (!$script:guiMode) { $script:guiMode = $false }

#----------------------------------------------------------------------
#無限ループ
while ($true) {
	#いろいろ初期化
	$videoPageURL = ''
	#移動先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (!(Test-Path $script:downloadBaseDir -PathType Container)) { Throw ('❌️ 番組ダウンロード先ディレクトリにアクセスできません。終了します') }
	#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	Wait-YtdlProcess $script:parallelDownloadFileNum
	
	#複数アドレス入力用配列
	$script:videoPageList = @()

	if (!$script:guiMode) {
		$script:videoPageList = (Read-Host '番組URLを入力してください。何も入力しないで Enter を押すと終了します。スペースで区切って複数入力可能です。').Trim().Split()
	} else {
		# アセンブリの読み込み
		[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
		[void][System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')

		# フォームの作成
		$inputForm = New-Object System.Windows.Forms.Form -Property @{
			Text            = 'TVerRec個別ダウンロード'
			Size            = New-Object System.Drawing.Size(480, 300)
			StartPosition   = 'CenterScreen'
			MaximizeBox     = $False
			MinimizeBox     = $False
			FormBorderStyle = 'Fixed3D'
			KeyPreview      = $True
			TopLevel        = $true
			ShowIcon        = $False
		}
		$inputForm.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { $inputForm.Close() } })
		$inputForm.Add_Shown({ $inputForm.Activate() })

		# OKボタンの作成
		$okButton = New-Object System.Windows.Forms.Button -Property @{
			Location = New-Object System.Drawing.Size(380, 10)
			Size     = New-Object System.Drawing.Size(75, 20)
			Text     = 'OK'
		}
		$okButton.Add_Click({ $script:videoPageList = $inputTextBox.Text.Split("`r`n").Split(); $inputForm.Close() })
		$inputForm.Controls.Add($okButton)

		# テキストラベルの作成
		$inputTextLabel = New-Object System.Windows.Forms.Label -Property @{
			Location = New-Object System.Drawing.Size(10, 10)
			Size     = New-Object System.Drawing.Size(440, 20)
			Text     = '番組URLを入力してください。改行で区切って複数入力可能です。'
		}
		$inputForm.Controls.Add($inputTextLabel)

		# テキストボックスの作成
		$inputTextBox = New-Object System.Windows.Forms.TextBox -Property @{
			Location   = New-Object System.Drawing.Size(10, 40)
			Size       = New-Object System.Drawing.Size(445, 200)
			Multiline  = $true
			ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
		}
		$inputForm.Controls.Add($inputTextBox)

		# ダイアログの表示
		[void]$inputForm.ShowDialog()
	}

	#配列の空白要素を削除
	$script:videoPageList = $script:videoPageList -ne ""
	if (-not $script:videoPageList) { break }

	#複数入力されていたら全てダウンロード
	foreach ($videoPageURL in  $script:videoPageList) {
		switch -Regex ($videoPageURL) {
			'^https://tver.jp/(/?.*)' { #TVer番組ダウンロードのメイン処理
				Write-Output ('{0}' -f $videoPageURL)
				Invoke-VideoDownload -Keyword $keyword -EpisodePage $videoPageURL -Force $script:forceSingleDownload
				continue
			}
			'^.*://' { #TVer以外のサイトへの対応
				Write-Output ('ダウンロード：{0}' -f $videoPageURL)
				Invoke-NonTverYtdl $videoPageURL
				Start-Sleep -Seconds 1
				continue
			}
			default { Write-Warning ('URLではありません: {0}' -f $videoPageURL); continue }
		}
	}

}

Remove-Variable -Name args, keyword, videoPageURL -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('ダウンロード処理を終了しました。')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
