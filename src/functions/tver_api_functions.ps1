################################################################################
#
#		TVer固有関数スクリプト(TVer APIの利用準備)
#
################################################################################
<#
	.SYNOPSIS
		TVerのAPIトークンの取得と、日本のIPアドレスの取得(地域制限への対応)の関数を定義します。

	.NOTES
		このファイルはtver_functions.ps1から読み込まれます。
		単体で読み込まず、tver_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#----------------------------------------------------------------------
# TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function Get-Token () {
	<#
		.SYNOPSIS
			TVerのAPIトークンを取得します。

		.DESCRIPTION
			TVerのプラットフォームAPIを使用するために必要なトークンを取得します。
			この関数は匿名ユーザーとしてのトークンを取得します。

		.EXAMPLE
			Get-Token

		.NOTES
			この関数は内部で使用される変数$script:platformUIDと$script:platformTokenを設定します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$httpHeader = @{
		'Content-Type'     = 'application/x-www-form-urlencoded'
		'Forwarded'        = $script:jpIP
		'Forwarded-For'    = $script:jpIP
		'X-Forwarded'      = $script:jpIP
		'X-Forwarded-For'  = $script:jpIP
		'X-Originating-IP' = $script:jpIP
	}
	$requestBody = 'device_type=pc'
	try {
		$tokenResponse = Invoke-RestMethod -Uri $tverTokenURL -Method 'POST' -Headers $httpHeader -Body $requestBody -TimeoutSec $script:timeoutSec
		$script:platformUID = $tokenResponse.Result.platform_uid
		$script:platformToken = $tokenResponse.Result.platform_token
		Write-Debug	('Platform UID: {0}' -f $script:platformUID)
		Write-Debug	('Platform Token: {0}' -f $script:platformToken)
	} catch { throw ($script:msg.TokenRetrievalFailed) }
	Remove-Variable -Name tverTokenURL, httpHeader, requestBody, tokenResponse -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# Geo IP関連
#----------------------------------------------------------------------
function Get-JpIP {
	<#
		.SYNOPSIS
			日本のIPアドレスをランダムに取得します。

		.DESCRIPTION
			日本に割り当てられているIPアドレスレンジから、
			ランダムにIPアドレスを選択して返します。
			IP-API.comを使用して、選択したIPアドレスが実際に日本に割り当てられていることを確認します。

		.EXAMPLE
			Get-JpIP

		.OUTPUTS
			String
			日本のIPアドレスを返します。

		.NOTES
			この関数はTVerのAPIアクセス時に使用されるIPアドレスを取得するために使用されます。
			日本国内のIPアドレスを使用することで、地域制限のあるコンテンツにアクセスできるようになります。
	#>
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# 日本に割り当てられているIPアドレスレンジの取得
	$allCIDR = Import-Csv $script:jpIPList
	# * ip-api.comに接続できない/レート制限(45req/min)にかかった場合に無限ループしないよう上限を設ける (#277)
	$maxAttempts = 5
	$attempt = 0
	Do {
		$attempt++
		# ランダムなIPアドレスの取得
		$randomCIDR = $allCIDR | Get-Random
		$startIPArray = [System.Net.IPAddress]::Parse($randomCIDR[0].start).GetAddressBytes()
		[Array]::Reverse($startIPArray) ; $startIPInt = [BitConverter]::ToUInt32($startIPArray, 0)
		$endIPArray = [System.Net.IPAddress]::Parse($randomCIDR[0].end).GetAddressBytes()
		[Array]::Reverse($endIPArray) ; $endIPInt = [BitConverter]::ToUInt32($endIPArray, 0)
		# CIDR範囲の先頭と末尾を除く。範囲が極小(/31,/32)だとGet-Randomが例外になるため先頭IPを使う
		$randomIPInt = if (($endIPInt - $startIPInt) -le 1) { $startIPInt } else { $startIPInt + [UInt32](Get-Random -Maximum ($endIPInt - $startIPInt - 1)) + 1 }
		$randomIPArray = [System.BitConverter]::GetBytes($randomIPInt)
		[Array]::Reverse($randomIPArray) ; $jpIP = [System.Net.IPAddress]::new($randomIPArray).ToString()
		try { $check = Invoke-RestMethod -Uri ('http://ip-api.com/json/{0}?fields=16785410' -f $jpIP) -TimeoutSec $script:timeoutSec }
		catch {
			$check = [pscustomobject]@{ CountryCode = '' }
			# * 接続できない場合はip-api.comによる検証を諦め、日本のIPレンジから選んだIPをそのまま使用する
			if ($attempt -ge $maxAttempts) { Write-Debug 'ip-api.com verification skipped' ; break }
			Start-Sleep -Seconds ([Math]::Min(2 * $attempt, 10))
		}
	} While (($check.CountryCode -ne 'JP') -and ($attempt -lt $maxAttempts * 4))
	return $jpIP
}
