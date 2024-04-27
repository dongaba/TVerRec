
#Download & Install WinGet
$progressPreference = 'silentlyContinue'
Write-Information 'Downloading WinGet and its dependencies...'
Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile Microsoft.UI.Xaml.2.8.x64.appx
Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
Add-AppxPackage Microsoft.UI.Xaml.2.8.x64.appx
Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

Start-Sleep 5

#Install Packages
winget install VideoLAN.VLC --accept-source-agreements --accept-package-agreements --silent
winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
winget install Microsoft.VisualStudioCode --scope machine --accept-source-agreements --accept-package-agreements --silent
winget install Git.Git --accept-source-agreements --accept-package-agreements --silent

Start-Sleep 5

Start-Process 'C:/Users/WDAGUtilityAccount/setup/tverrec.cmd'
