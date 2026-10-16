@echo off
rem ed.ps1 installs missing spelling tools before launch; installed tools stay offline.
rem Version/hash pins: lib\Ed.Spelling.ps1. Emacs version: install.ps1.
setlocal
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ed.ps1" %*
) else (
  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ed.ps1" %*
)
exit /b %ERRORLEVEL%
