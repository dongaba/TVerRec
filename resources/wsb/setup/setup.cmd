@echo off

powershell Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

rem Download and Install WinGet & some more packages
powershell "C:\users\WDAGUtilityAccount\Desktop\TVerRec\resources\wsb\setup\setup.ps1"
