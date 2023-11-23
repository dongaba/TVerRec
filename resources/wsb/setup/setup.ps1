
#Download & Install WinGet
$progressPreference = 'silentlyContinue'
$latestWingetMsixBundleUri = (Invoke-RestMethod -Uri https://api.github.com/repos/microsoft/winget-cli/releases/latest).assets.browser_download_url | Where-Object { $_.EndsWith('.msixbundle') }
$latestWingetMsixBundle = $latestWingetMsixBundleUri.Split('/')[-1]
Write-Information 'Downloading winget to artifacts directory...'
Invoke-WebRequest -Uri $latestWingetMsixBundleUri -OutFile ('./{0}' -f $latestWingetMsixBundle)
Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
Add-AppxPackage $latestWingetMsixBundle

Start-Sleep 5

#Install Packages
winget install VideoLAN.VLC --accept-source-agreements --accept-package-agreements --silent
winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
winget install Microsoft.VisualStudioCode --scope machine --accept-source-agreements --accept-package-agreements --silent
winget install Git.Git --accept-source-agreements --accept-package-agreements --silent

Start-Sleep 5

Start-Process 'C:/Users/WDAGUtilityAccount/setup/tverrec.cmd'
