@echo off
powershell Set-WinUserLanguageList -Force ja-JP
powershell Set-WinSystemLocale -SystemLocale ja-JP
powershell Set-WinUILanguageOverride -Language ja-JP
powershell Set-WinHomeLocation 122
mshta vbscript:execute("MsgBox(""日本語化を完了するには再起動が必要です。"" & vbCRLF & ""OKを押すと自動的にWindowsサンドボックスを再起動します。""):close")
powershell Restart-Computer
