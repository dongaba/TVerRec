Write-Output 'ファイアウォールを無効化します...'
Set-NetFirewallProfile -Enabled False

#日本語化するためのショートカットをデスクトップに配置
$WsShell = New-Object -ComObject WScript.Shell
$Shortcut = $WsShell.CreateShortcut('C:\Users\WDAGUtilityAccount\Desktop\日本語化.lnk')
$Shortcut.TargetPath = 'C:\Users\WDAGUtilityAccount\Desktop\TVerRec\resources\wsb\setup\日本語化.cmd'
$Shortcut.Save()

#PowerShellインストール用のショートカットをデスクトップに配置
$WsShell = New-Object -ComObject WScript.Shell
$Shortcut = $WsShell.CreateShortcut('C:\Users\WDAGUtilityAccount\Desktop\PowerShellインストール.lnk')
$Shortcut.TargetPath = 'C:\Users\WDAGUtilityAccount\Desktop\TVerRec\resources\wsb\setup\PowerShellインストール.cmd'
$Shortcut.Save()

